import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { createHash } from "node:crypto";
import { createReadStream, constants } from "node:fs";
import { access, lstat, readFile, readdir, readlink, realpath } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import http from "node:http";
import { APP_PATH, CDP_PORT, STATE_DIR } from "../config.js";

export const run = promisify(execFile);
export const ORIGINAL = Buffer.from('removeSwitch("remote-debugging-port")');
export const PATCHED = Buffer.from('removeSwitch("remote-debugXing-port")');
export const permissionGuidance =
	"Quit Figma normally before repair or restore. If macOS denies app changes, grant the host terminal App Management in System Settings → Privacy & Security. Full Disk Access alone may not suffice. No sudo, SIP, or Gatekeeper changes are used. The connect confirmation explains the app-specific signing changes.";

export function desktopPaths() {
	const appPath = resolve(APP_PATH);
	const key = createHash("sha256").update(appPath).digest("hex").slice(0, 20);
	const statePath = join(STATE_DIR, `desktop-${key}`);
	return {
		appPath,
		statePath,
		manifestPath: join(statePath, "current.json"),
		asarPath: join(appPath, "Contents/Resources/app.asar"),
	};
}

export function signature(bytes) {
	const count = (needle) => {
		let total = 0;
		for (let offset = bytes.indexOf(needle); offset !== -1; offset = bytes.indexOf(needle, offset + needle.length))
			total++;
		return total;
	};
	const original = count(ORIGINAL);
	const patched = count(PATCHED);
	return {
		state: original + patched !== 1 ? "unsupported" : original === 1 ? "unpatched" : "patched",
		known: original + patched === 1,
		counts: { original, patched },
		hash: createHash("sha256").update(bytes).digest("hex"),
	};
}

// Hash every file, relative name, mode and symlink target, not merely app.asar:
// an updater may replace the executable/signature without changing the archive.
export async function hashBundle(root) {
	if (!(await lstat(root)).isDirectory()) throw new Error(`Expected a real bundle directory: ${root}`);
	const canonicalRoot = await realpath(root);
	const hash = createHash("sha256");
	async function visit(relative) {
		const path = relative ? join(root, relative) : root;
		const stat = await lstat(path);
		const kind = stat.isSymbolicLink()
			? "link"
			: stat.isDirectory()
				? "directory"
				: stat.isFile()
					? "file"
					: "unsupported";
		if (kind === "unsupported") throw new Error(`Unsupported bundle entry: ${path}`);
		hash.update(JSON.stringify([relative, kind, stat.mode & 0o7777, kind === "file" ? stat.size : null]) + "\n");
		if (kind === "link") {
			const target = await realpath(path);
			if (target !== canonicalRoot && !target.startsWith(`${canonicalRoot}/`))
				throw new Error(`Bundle symlink escapes the app: ${path}`);
			hash.update(JSON.stringify(await readlink(path)) + "\n");
		} else if (kind === "directory") {
			for (const name of (await readdir(path)).sort()) await visit(relative ? join(relative, name) : name);
		} else {
			for await (const chunk of createReadStream(path)) hash.update(chunk);
			hash.update("\n");
		}
	}
	await visit("");
	return hash.digest("hex");
}

export async function inspectApp() {
	const paths = desktopPaths();
	const stat = await lstat(paths.appPath);
	const canonicalPath = await realpath(paths.appPath);
	const { stdout } = await run(
		"/usr/bin/plutil",
		["-convert", "json", "-o", "-", "--", join(canonicalPath, "Contents/Info.plist")],
		{ timeout: 10000, maxBuffer: 1024 * 1024 },
	);
	const plist = JSON.parse(stdout);
	const bundleId = plist.CFBundleIdentifier;
	const supportedIdentity = bundleId === "com.figma.Desktop" || bundleId === "com.figma.Desktop.Beta";
	// Do not follow an archive symlink when writing the staged app either.
	const archive = join(canonicalPath, "Contents/Resources/app.asar");
	const archiveStat = await lstat(archive);
	if (!archiveStat.isFile() || (await realpath(archive)) !== archive)
		throw new Error("The app archive must be a regular file inside the bundle (no symlinked parents).");
	return {
		path: paths.appPath,
		canonicalPath,
		symlink: stat.isSymbolicLink(),
		bundleId,
		version: plist.CFBundleShortVersionString ?? null,
		build: plist.CFBundleVersion ?? null,
		supportedIdentity,
		patch: signature(await readFile(archive)),
	};
}

export async function runningState(appPath = desktopPaths().appPath) {
	try {
		const canonical = await realpath(appPath).catch(() => appPath);
		const { stdout } = await run("/bin/ps", ["-ww", "-axo", "pid=,comm="], {
			timeout: 10000,
			maxBuffer: 8 * 1024 * 1024,
		});
		const processes = stdout.split("\n").flatMap((line) => {
			const match = line.trim().match(/^(\d+)\s+(.+)$/);
			return match ? [{ pid: Number(match[1]), executable: match[2] }] : [];
		});
		if (!processes.length) throw new Error("Empty process listing");
		const matches = processes.filter(({ executable }) =>
			[appPath, canonical].some((root) => executable.startsWith(`${root}/`)),
		);
		// A truncated/bare Figma command or an App Translocation instance cannot be
		// safely attributed to a different installation. Refuse writes in that case.
		const uncertain = processes.filter(
			({ executable }) =>
				!matches.some((p) => p.executable === executable) &&
				(/^Figma(?: Helper.*)?$/.test(executable) ||
					(/AppTranslocation\//.test(executable) && /\/Figma[^/]*\.app\//.test(executable))),
		);
		return { known: uncertain.length === 0, running: matches.length > 0, processes: matches, uncertain };
	} catch (error) {
		return { known: false, running: null, processes: [], uncertain: [], error: error.message };
	}
}

function getJSON(port, path) {
	return new Promise((resolveRequest, reject) => {
		const request = http.get({ hostname: "127.0.0.1", port, path, agent: false }, (response) => {
			let bytes = 0;
			const chunks = [];
			response.on("data", (chunk) => {
				bytes += chunk.length;
				if (bytes > 1024 * 1024) request.destroy(new Error("CDP response exceeds 1 MiB"));
				else chunks.push(chunk);
			});
			response.on("error", reject);
			response.on("end", () => {
				try {
					if (response.statusCode !== 200) throw new Error(`HTTP ${response.statusCode} at ${path}`);
					resolveRequest(JSON.parse(Buffer.concat(chunks).toString("utf8")));
				} catch (error) {
					reject(error);
				}
			});
		});
		const timer = setTimeout(() => request.destroy(new Error("CDP probe timed out")), 2000);
		request.on("close", () => clearTimeout(timer));
		request.on("error", reject);
	});
}

function localWebSocket(value, port) {
	try {
		const url = new URL(value);
		return (
			url.protocol === "ws:" &&
			["127.0.0.1", "localhost", "[::1]"].includes(url.hostname) &&
			Number(url.port) === port &&
			!url.username &&
			!url.password
		);
	} catch {
		return false;
	}
}

export async function inspectPort(running) {
	const port = Number(CDP_PORT);
	const base = { host: "127.0.0.1", port };
	if (!Number.isInteger(port) || port < 1 || port > 65535)
		return { ...base, state: "invalid", error: "CDP_PORT must be an integer between 1 and 65535." };
	try {
		let output = "";
		try {
			output = (
				await run("/usr/sbin/lsof", ["-nP", `-iTCP:${port}`, "-sTCP:LISTEN", "-Fpn"], {
					timeout: 10000,
					maxBuffer: 1024 * 1024,
				})
			).stdout;
		} catch (error) {
			if (error.code !== 1 || error.stdout?.trim() || error.stderr?.trim()) throw error;
		}
		const pids = [...new Set([...output.matchAll(/^p(\d+)$/gm)].map((match) => Number(match[1])))];
		const addresses = [...output.matchAll(/^n(.+)$/gm)].map((match) => match[1]);
		const owned = pids.length > 0 && running.known && pids.every((pid) => running.processes.some((p) => p.pid === pid));
		if (pids.length && !owned)
			return {
				...base,
				state: "occupied",
				pids,
				addresses,
				error: "The listener is not verified as this Figma installation.",
			};
		if (
			owned &&
			(!addresses.length || addresses.some((address) => ![`127.0.0.1:${port}`, `[::1]:${port}`].includes(address)))
		) {
			return {
				...base,
				state: "unsafe",
				pids,
				addresses,
				error:
					"CDP is not bound exclusively to loopback. Quit Figma normally and launch again with the local-only flags.",
			};
		}
		let version;
		try {
			version = await getJSON(port, "/json/version");
		} catch (error) {
			if (!pids.length && error.code === "ECONNREFUSED") return { ...base, state: "free", pids: [] };
			return { ...base, state: owned ? "unverified" : "occupied", pids, addresses, error: error.message };
		}
		const targets = await getJSON(port, "/json/list");
		const validVersion =
			typeof version?.Browser === "string" &&
			/(?:Chrome|Chromium|Electron|Figma)\//i.test(version.Browser) &&
			typeof version["Protocol-Version"] === "string" &&
			localWebSocket(version.webSocketDebuggerUrl, port);
		const figmaTargets = Array.isArray(targets)
			? targets.filter((target) => {
					try {
						const url = new URL(target.url);
						return (
							target.type === "page" &&
							url.protocol === "https:" &&
							(url.hostname === "figma.com" || url.hostname.endsWith(".figma.com")) &&
							localWebSocket(target.webSocketDebuggerUrl, port)
						);
					} catch {
						return false;
					}
				})
			: [];
		const ready = owned && validVersion && figmaTargets.length > 0;
		return {
			...base,
			state: ready ? "ready" : owned ? "unverified" : "occupied",
			pids,
			addresses,
			browser: version?.Browser ?? null,
			targets: figmaTargets.map(({ id, title, url, webSocketDebuggerUrl }) => ({
				id,
				title,
				url,
				webSocketDebuggerUrl,
			})),
			...(ready
				? {}
				: {
						error:
							"CDP must belong to the target desktop app and expose a valid version and Figma page target. Open a Figma window and retry.",
					}),
		};
	} catch (error) {
		return { ...base, state: "unknown", error: error.message };
	}
}

export async function readBackup() {
	const { appPath, statePath, manifestPath } = desktopPaths();
	let record;
	try {
		record = JSON.parse(await readFile(manifestPath, "utf8"));
	} catch (error) {
		if (error.code === "ENOENT") return null;
		throw new Error(`Unreadable desktop backup manifest: ${error.message}`);
	}
	if (
		record.schema !== 1 ||
		record.appPath !== appPath ||
		!/^[a-f0-9-]{36}$/.test(record.id) ||
		record.backupPath !== join(statePath, "backups", record.id, "Figma.app") ||
		!/^[a-f0-9]{64}$/.test(record.originalHash) ||
		!/^[a-f0-9]{64}$/.test(record.patchedHash) ||
		!["prepared", "installed", "restored", "interrupted"].includes(record.phase)
	)
		throw new Error("Invalid desktop backup manifest; manual recovery is required.");
	return record;
}

async function writable(path) {
	try {
		await access(path, constants.W_OK);
		return true;
	} catch {
		return false;
	}
}

export async function diagnoseDesktop() {
	const { appPath, statePath } = desktopPaths();
	if (process.platform !== "darwin")
		return {
			ok: false,
			platform: process.platform,
			status: "unsupported-platform",
			app: { path: appPath },
			guidance: "Desktop repair and launch currently support macOS only.",
		};
	const running = await runningState();
	const port = await inspectPort(running);
	const permissions = {
		appWritable: await writable(appPath),
		parentWritable: await writable(dirname(appPath)),
		stateWritable: await writable(statePath),
		guidance: permissionGuidance,
	};
	let operation = null;
	try {
		operation = {
			state: "active-or-interrupted",
			lockPath: join(statePath, "operation.lock"),
			owner: JSON.parse(await readFile(join(statePath, "operation.lock/owner.json"), "utf8")),
		};
	} catch (error) {
		try {
			await lstat(join(statePath, "operation.lock"));
			operation = { state: "active-or-interrupted", lockPath: join(statePath, "operation.lock"), error: error.message };
		} catch (missing) {
			if (missing.code !== "ENOENT") operation = { state: "unknown", error: missing.message };
		}
	}
	let app;
	let backup = { state: "none", statePath };
	const issues = [];
	try {
		app = await inspectApp();
	} catch (error) {
		issues.push(error.message);
		app = { path: appPath, patch: { state: "unsupported", known: false }, error: error.message };
	}
	try {
		const record = await readBackup();
		if (record) {
			const currentHash = await hashBundle(appPath).catch(() => null);
			const backupHash = await hashBundle(record.backupPath).catch(() => null);
			backup = {
				state:
					backupHash !== record.originalHash
						? "invalid"
						: ["prepared", "interrupted"].includes(record.phase)
							? "recovery-required"
							: currentHash === record.patchedHash
								? "restorable"
								: currentHash === record.originalHash
									? "original-installed"
									: "stale",
				path: record.backupPath,
				phase: record.phase,
				originalHash: record.originalHash,
				patchedHash: record.patchedHash,
				currentHash,
				transaction: record.transaction ?? null,
			};
		}
	} catch (error) {
		backup = { state: "invalid", statePath, error: error.message };
		issues.push(error.message);
	}
	if (!running.known) issues.push("Cannot confidently exclude a running Figma instance.");
	if (app.supportedIdentity === false) issues.push("Unsupported app bundle identity.");
	if (app.symlink)
		issues.push("The configured app bundle is a symlink; repair and launch require a direct bundle path.");
	if (app.patch.state === "unsupported") issues.push("Expected exactly one known patch signature.");
	if (["invalid", "recovery-required"].includes(backup.state))
		issues.push("The backup requires inspection before repair or restore.");
	return {
		ok: issues.length === 0,
		platform: "darwin",
		status: port.state === "ready" ? "ready" : "diagnosed",
		app,
		running,
		backup,
		operation,
		port,
		permissions,
		issues,
	};
}
