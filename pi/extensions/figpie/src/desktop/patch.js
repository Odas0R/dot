import { randomUUID } from "node:crypto";
import { lstat, mkdir, mkdtemp, open, readFile, rename, rm } from "node:fs/promises";
import { dirname, join } from "node:path";
import { ensureStateDir } from "../config.js";
import {
	SIGNING_NOTICE,
	SIGNING_PROFILE,
	signPatchedBundle,
	verifyPatchedSignature,
	verifySignature,
} from "./signing.js";
import {
	desktopPaths,
	hashBundle,
	inspectApp,
	ORIGINAL,
	PATCHED,
	permissionGuidance,
	readBackup,
	run,
	runningState,
	signature,
} from "./diagnose.js";

async function atomicWrite(path, content, mode = 0o600) {
	const temporary = `${path}.${randomUUID()}.tmp`;
	let handle;
	try {
		handle = await open(temporary, "wx", mode);
		await handle.writeFile(content);
		await handle.chmod(mode);
		await handle.sync();
		await handle.close();
		handle = null;
		await rename(temporary, path);
	} finally {
		if (handle) await handle.close();
		await rm(temporary, { force: true });
	}
}

async function saveRecord(record) {
	const json = JSON.stringify(record, null, 2) + "\n";
	await atomicWrite(join(dirname(record.backupPath), "manifest.json"), json);
	await atomicWrite(desktopPaths().manifestPath, json);
}

export async function assertStopped() {
	const running = await runningState();
	if (!running.known || running.running) {
		const error = new Error(
			running.known
				? "Quit this Figma app normally, then retry. It will not be force-quit."
				: "Cannot confidently rule out a running Figma instance; no app changes were made.",
		);
		error.status = running.known ? "restart-required" : "running-state-unknown";
		error.running = running;
		throw error;
	}
}

// A persistent exclusive lock also prevents launch from racing our own repair.
// A crashed owner leaves the lock behind intentionally: do not guess that a
// possibly interrupted two-rename bundle swap is safe to continue.
export async function withDesktopLock(action, operation) {
	if (process.platform !== "darwin")
		return { ok: false, action, status: "unsupported-platform", platform: process.platform };
	const { statePath } = desktopPaths();
	const lockPath = join(statePath, "operation.lock");
	let locked = false;
	let result;
	try {
		await ensureStateDir();
		await mkdir(statePath, { recursive: true, mode: 0o700 });
		try {
			await mkdir(lockPath, { mode: 0o700 });
		} catch (error) {
			if (error.code === "EEXIST")
				return {
					ok: false,
					action,
					status: "busy-or-interrupted",
					lockPath,
					guidance:
						"Another desktop operation owns this lock, or one was interrupted. Inspect current.json and its recovery paths before manually removing an abandoned lock.",
				};
			throw error;
		}
		locked = true;
		await atomicWrite(
			join(lockPath, "owner.json"),
			JSON.stringify({ pid: process.pid, action, startedAt: new Date().toISOString() }),
		);
		result = await operation();
	} catch (error) {
		result = {
			ok: false,
			action,
			status: error.status ?? "failed",
			error: error.message,
			...(error.running ? { running: error.running, restartRequired: true } : {}),
			guidance: permissionGuidance,
		};
	} finally {
		if (locked) {
			try {
				await rm(lockPath, { recursive: true });
			} catch (error) {
				if (result) result.lockCleanupError = { path: lockPath, error: error.message };
			}
		}
	}
	return result;
}

async function copyBundle(source, destination) {
	// ditto preserves resource forks, extended attributes, ACLs and the original
	// signature. Never use codesign on the live bundle or the recovery backup.
	await run("/usr/bin/ditto", ["--rsrc", "--extattr", "--acl", source, destination], {
		timeout: 300000,
		maxBuffer: 1024 * 1024,
	});
}

async function exists(path) {
	try {
		await lstat(path);
		return true;
	} catch (error) {
		if (error.code === "ENOENT") return false;
		throw error;
	}
}

async function installStage(record, previousRecord, action) {
	const { appPath, manifestPath } = desktopPaths();
	const { stagedPath, displacedPath, workPath, beforeHash, afterHash } = record.transaction;
	let displaced = false;
	let installed = false;
	try {
		await saveRecord(record); // durable recovery paths before the first rename
		await assertStopped();
		if ((await hashBundle(record.backupPath)) !== record.originalHash)
			throw new Error("Original recovery backup changed during preparation; refusing the swap.");
		if ((await hashBundle(appPath)) !== beforeHash)
			throw new Error("Figma changed during preparation; refusing the swap.");
		await assertStopped();
		await rename(appPath, displacedPath);
		displaced = true;
		await rename(stagedPath, appPath);
		installed = true;
		if ((await hashBundle(appPath)) !== afterHash) throw new Error("Installed bundle validation failed.");
		if (action === "repair") await verifyPatchedSignature(appPath);
		else await verifySignature(appPath);
		record.phase = action === "repair" ? "installed" : "restored";
		record.completedAt = new Date().toISOString();
		await saveRecord(record);
		const result = {
			ok: true,
			action,
			status: action === "repair" ? "repaired" : "restored",
			changed: true,
			appPath,
			backupPath: record.backupPath,
			restartRequired: action === "repair",
			launched: false,
		};
		try {
			await rm(workPath, { recursive: true });
		} catch (error) {
			result.cleanupWarning = { path: workPath, error: error.message };
		}
		return result;
	} catch (error) {
		let rollback = "not-needed";
		let rollbackError;
		try {
			if (displaced) {
				await assertStopped();
				if ((await hashBundle(displacedPath)) !== beforeHash)
					throw new Error("Displaced original changed; manual recovery required.");
				if (installed) {
					if ((await hashBundle(appPath)) !== afterHash)
						throw new Error("Live app changed after the swap; refusing to overwrite it during rollback.");
					await assertStopped();
					await rename(appPath, join(workPath, "failed.app"));
				} else if (await exists(appPath))
					throw new Error("An app appeared at the destination; refusing to overwrite it during rollback.");
				await rename(displacedPath, appPath);
				if ((await hashBundle(appPath)) !== beforeHash) throw new Error("Rollback validation failed.");
				rollback = "restored";
			}
			// Preserve this attempt in its backup directory, but reinstate the prior
			// active backup association only after the original app is safe again.
			await atomicWrite(
				join(dirname(record.backupPath), "attempt.json"),
				JSON.stringify({ ...record, phase: "interrupted", rollback, error: error.message }, null, 2),
			);
			if (previousRecord) await saveRecord(previousRecord);
			else await rm(manifestPath, { force: true });
		} catch (failure) {
			rollback = "failed";
			rollbackError = failure.message;
		}
		return {
			ok: false,
			action,
			status: rollback === "failed" ? "partial-failure" : (error.status ?? "failed"),
			error: error.message,
			...(error.running ? { running: error.running, restartRequired: true } : {}),
			changed: rollback === "failed",
			rollback,
			rollbackError,
			recoveryRequired: rollback === "failed",
			backupPath: record.backupPath,
			transaction: record.transaction,
			guidance: `${permissionGuidance} Recovery bundles have been retained; never copy an old backup over a newer app.`,
		};
	}
}

async function manageDesktop(action) {
	return withDesktopLock(action, async () => {
		const { appPath, asarPath, statePath } = desktopPaths();
		await assertStopped();
		const app = await inspectApp();
		if (app.symlink || !app.supportedIdentity || !app.patch.known)
			return {
				ok: false,
				action,
				status: "unsupported-app",
				app,
				error: "Repair requires a real Figma app bundle and exactly one known original or patched signature.",
			};
		const previousRecord = await readBackup();
		if (previousRecord && ["prepared", "interrupted"].includes(previousRecord.phase))
			return {
				ok: false,
				action,
				status: "recovery-required",
				backup: previousRecord,
				error: "An interrupted transaction must be inspected before another desktop operation.",
			};
		const currentHash = await hashBundle(appPath);
		if (action === "restore" && app.patch.state === "unpatched")
			return {
				ok: true,
				action,
				status: "already-original",
				changed: false,
				backupState:
					previousRecord && currentHash !== previousRecord.originalHash
						? "stale"
						: previousRecord
							? "original-installed"
							: "none",
			};
		if (action === "repair" && app.patch.state === "patched") {
			await verifyPatchedSignature(appPath);
			const managed = previousRecord?.patchedHash === currentHash;
			const recoverable =
				managed && (await hashBundle(previousRecord.backupPath).catch(() => null)) === previousRecord.originalHash;
			return {
				ok: recoverable,
				action,
				status: recoverable ? "already-repaired" : "unmanaged-patch",
				changed: false,
				restartRequired: true,
				backupPath: previousRecord?.backupPath ?? null,
				...(recoverable
					? {}
					: {
							error:
								"The app is already patched, but no matching intact full-bundle backup is available. No further changes were made.",
						}),
			};
		}
		if (action === "restore" && (!previousRecord || currentHash !== previousRecord.patchedHash))
			return {
				ok: false,
				action,
				status: previousRecord ? "stale-backup" : "backup-missing",
				changed: false,
				error:
					"No backup matches the entire installed patched bundle. Figma may have updated; restoring an older app is refused.",
				backupPath: previousRecord?.backupPath ?? null,
			};

		let workPath;
		let backupPath = previousRecord?.backupPath;
		try {
			await verifySignature(appPath);
			if (action === "restore" && (await hashBundle(backupPath)) !== previousRecord.originalHash)
				throw new Error("Original backup is missing or damaged; restore refused.");
			await assertStopped();
			workPath = await mkdtemp(join(dirname(appPath), ".figpie-"));
			const stagedPath = join(workPath, "Figma.app");
			let record;
			if (action === "repair") {
				const id = randomUUID();
				const backupDir = join(statePath, "backups", id);
				await mkdir(backupDir, { recursive: true, mode: 0o700 });
				backupPath = join(backupDir, "Figma.app");
				await copyBundle(appPath, backupPath);
				if ((await hashBundle(backupPath)) !== currentHash || (await hashBundle(appPath)) !== currentHash)
					throw new Error("Figma changed while backing up, or backup validation failed.");
				await verifySignature(backupPath);
				// Leave provenance even if staging/signing fails before current.json.
				await atomicWrite(
					join(backupDir, "original.json"),
					JSON.stringify(
						{ appPath, originalHash: currentHash, version: app.version, createdAt: new Date().toISOString() },
						null,
						2,
					),
				);
				await copyBundle(backupPath, stagedPath);
				if ((await hashBundle(stagedPath)) !== currentHash)
					throw new Error("Staged copy does not match the original backup.");
				await assertStopped();
				const stagedAsar = join(stagedPath, "Contents/Resources/app.asar");
				const bytes = await readFile(stagedAsar);
				if (signature(bytes).state !== "unpatched" || signature(bytes).hash !== app.patch.hash)
					throw new Error("Staged archive signature changed.");
				if (ORIGINAL.length !== PATCHED.length) throw new Error("Patch length mismatch.");
				PATCHED.copy(bytes, bytes.indexOf(ORIGINAL));
				const mode = (await lstat(asarPath)).mode & 0o7777;
				await atomicWrite(stagedAsar, bytes, mode);
				const written = await readFile(stagedAsar);
				if (!written.equals(bytes) || signature(written).state !== "patched")
					throw new Error("Patched archive validation failed.");
				await signPatchedBundle(stagedPath);
				if (!(await readFile(stagedAsar)).equals(bytes))
					throw new Error("Signing unexpectedly changed the patched archive.");
				record = {
					schema: 1,
					id,
					appPath,
					backupPath,
					originalHash: currentHash,
					patchedHash: await hashBundle(stagedPath),
					signingProfile: SIGNING_PROFILE,
					version: app.version,
					originalAsarHash: app.patch.hash,
					patchedAsarHash: signature(bytes).hash,
					createdAt: new Date().toISOString(),
				};
			} else {
				await copyBundle(backupPath, stagedPath);
				if ((await hashBundle(stagedPath)) !== previousRecord.originalHash)
					throw new Error("Staged restore does not match the original backup.");
				await verifySignature(stagedPath);
				record = { ...previousRecord };
			}
			record.phase = "prepared";
			record.transaction = {
				action,
				workPath,
				stagedPath,
				displacedPath: join(workPath, "previous.app"),
				beforeHash: currentHash,
				afterHash: action === "repair" ? record.patchedHash : record.originalHash,
			};
			return await installStage(record, previousRecord, action);
		} catch (error) {
			// Nothing touched the live app: all writes/signing were to fresh copies.
			// Keep the full backup; only the disposable staging directory is removed.
			let cleanupError;
			if (workPath) {
				try {
					await rm(workPath, { recursive: true });
				} catch (failure) {
					cleanupError = failure.message;
				}
			}
			return {
				ok: false,
				action,
				status: error.status ?? "preparation-failed",
				changed: false,
				error: error.message,
				backupPath: backupPath ?? null,
				...(cleanupError ? { cleanupError, workPath } : {}),
				...(error.running ? { running: error.running, restartRequired: true } : {}),
				guidance: permissionGuidance,
			};
		}
	});
}

/** Explicit repair only; never launches or quits Figma. */
export async function repairDesktop({ allowPatch = false } = {}) {
	if (allowPatch !== true)
		return { ok: false, action: "repair", status: "confirmation-required", guidance: SIGNING_NOTICE };
	return manageDesktop("repair");
}

/** Restore the matching complete original bundle and its signature, not just ASAR. */
export async function restoreDesktop() {
	return manageDesktop("restore");
}
