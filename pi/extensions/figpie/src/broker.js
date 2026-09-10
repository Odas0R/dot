import net from "node:net";
import { randomUUID } from "node:crypto";
import { setTimeout as delay } from "node:timers/promises";
import { chmod, lstat, mkdir, rm, unlink, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { Channel } from "./ipc.js";
import { Targets, describeTarget } from "./cdp/targets.js";
import { diagnoseDesktop } from "./desktop/diagnose.js";
import { restoreDesktop } from "./desktop/patch.js";
import { connectDesktop } from "./desktop/connect.js";
import { brokerTrace as trace, errorDetails } from "./log.js";
import {
	APP_PATH,
	CDP_PORT,
	STATE_DIR,
	SOCKET_PATH,
	VERSION,
	MAX_CODE_BYTES,
	UNCERTAIN,
	ensureStateDir,
} from "./config.js";

const SETUP_ACTIONS = {
	status: diagnoseDesktop,
	connect: connectDesktop,
	restore: restoreDesktop,
};

const isId = (value) => typeof value === "string" && value.length > 0 && value.length <= 128;

const SCRIPTING_CONNECTION_GRACE_MS = 10_000;
const SCRIPTING_CONNECTION_POLL_MS = 500;
const SCRIPTING_STARTUP_STATUSES = new Set(["already-running", "launched", "cdp-not-ready"]);

export async function waitForScriptingConnection(
	refresh,
	{
		deadline,
		graceMs = SCRIPTING_CONNECTION_GRACE_MS,
		pollMs = SCRIPTING_CONNECTION_POLL_MS,
		isCancelled = () => false,
		now = Date.now,
		sleep = delay,
	} = {},
) {
	let inventory = await refresh();
	const stopAt = Math.min(deadline ?? Infinity, now() + graceMs);
	const hasUsableConnection = () => inventory.connections.some((connection) => !connection.blocked);
	while (!hasUsableConnection() && !isCancelled()) {
		const remaining = stopAt - now();
		if (remaining <= 0) break;
		await sleep(Math.min(pollMs, remaining));
		if (isCancelled() || stopAt - now() <= 0) break;
		inventory = await refresh();
	}
	return inventory;
}

// Only the process holding this short-lived startup lock may remove a stale
// socket. Concurrent Pi startups otherwise risk unlinking a live broker.
async function listen(server) {
	await ensureStateDir();
	const lock = join(STATE_DIR, "broker-start.lock");
	try {
		await mkdir(lock, { mode: 0o700 });
	} catch (error) {
		if (error.code === "EEXIST")
			throw new Error(`Broker startup is already in progress. If interrupted, inspect ${lock} before removing it.`);
		throw error;
	}
	try {
		await writeFile(join(lock, "owner.json"), JSON.stringify({ pid: process.pid, time: new Date().toISOString() }), {
			mode: 0o600,
		});
		const existing = await lstat(SOCKET_PATH).catch((error) => {
			if (error.code !== "ENOENT") throw error;
		});
		if (existing) {
			if (!existing.isSocket() || existing.uid !== process.getuid())
				throw new Error(`Refusing to replace an unexpected socket path: ${SOCKET_PATH}`);
			const alive = await new Promise((resolve, reject) => {
				const probe = net.createConnection(SOCKET_PATH);
				probe.setTimeout(1000, () => probe.destroy(new Error("Existing broker did not respond")));
				probe.once("connect", () => {
					probe.destroy();
					resolve(true);
				});
				probe.once("error", (error) =>
					["ECONNREFUSED", "ENOENT"].includes(error.code) ? resolve(false) : reject(error),
				);
			});
			if (alive) return false;
			await unlink(SOCKET_PATH).catch((error) => {
				if (error.code !== "ENOENT") throw error;
			});
		}
		await new Promise((resolve, reject) => {
			server.once("error", reject);
			server.listen(SOCKET_PATH, () => {
				server.off("error", reject);
				resolve();
			});
		});
		await chmod(SOCKET_PATH, 0o600);
		return true;
	} finally {
		await rm(lock, { recursive: true });
	}
}

export async function startBroker() {
	const targets = new Targets();
	const peers = new Set();
	const requests = new Map();
	let idleTimer;
	let setupTask;
	let closing = false;
	const server = net.createServer((socket) => {
		if (closing) {
			socket.destroy();
			return;
		}
		const peer = new Channel(socket);
		peers.add(peer);
		requests.set(peer, new Map());
		clearTimeout(idleTimer);
		peer.on("message", (message) => {
			if (!isId(message.id)) {
				peer.close();
				return;
			}
			if (message.type === "retire") {
				const busy =
					setupTask ||
					[...requests.values()].some((pending) => pending.size) ||
					[...targets.entries.values()].some((entry) => entry.active || entry.queue.length || entry.info.busyId);
				if (busy)
					send(peer, {
						type: "error",
						id: message.id,
						message: `Figpie broker ${process.pid} still has work in progress. Wait for it to finish before updating; nothing was stopped.`,
					});
				else void close(); // No caller work is cancelled by an idle-only replacement.
				return;
			}
			if (message.type === "cancel") {
				const item = requests.get(peer)?.get(message.id);
				if (item) cancel(item, "Request cancelled.");
				return;
			}
			if (requests.get(peer).has(message.id)) {
				peer.close();
				return;
			}
			const item = {
				peer,
				id: message.id,
				runId: randomUUID(),
				message,
				receivedAt: Date.now(),
				finished: false,
				stage: "preflight",
			};
			requests.get(peer).set(item.id, item);
			void handle(item).catch((error) => finish(item, { type: "error", message: error.message, stack: error.stack }));
		});
		peer.once("close", () => {
			for (const item of requests.get(peer)?.values() || []) cancel(item, "Pi disconnected.");
			requests.delete(peer);
			peers.delete(peer);
			scheduleIdle();
		});
		send(peer, {
			type: "hello",
			version: VERSION,
			appPath: APP_PATH,
			cdpPort: CDP_PORT,
			pid: process.pid,
			retireWhenIdle: true,
		});
	});

	function send(peer, message) {
		try {
			peer.send(message);
		} catch (error) {
			trace.write("ipc.send-error", { error: errorDetails(error) });
			peer.close();
		}
	}
	function context(item) {
		return { requestId: item.id, runId: item.runId, connectionId: item.entry?.id, toolCallId: item.message.toolCallId };
	}
	function finish(item, response) {
		trace.write(item.finished ? "request.late-result" : `request.${response.type}`, {
			...context(item),
			durationMs: Date.now() - item.receivedAt,
			message: response.message,
			stack: response.stack,
			text: response.text,
			images: response.images?.map(({ name, mimeType }) => ({ name, mimeType })),
		});
		if (item.finished) return;
		item.finished = true;
		clearTimeout(item.timer);
		requests.get(item.peer)?.delete(item.id);
		send(item.peer, { ...response, id: item.id });
	}
	function failQueue(entry, reason) {
		for (const item of entry.queue.splice(0)) finish(item, { type: "error", message: reason });
	}
	function cancel(item, reason) {
		if (item.finished) return;
		trace.write("request.cancel", { ...context(item), reason, stage: item.stage });
		if (item.entry?.active === item) {
			// Cancellation stops the caller's wait, not the underlying execution.
			finish(item, { type: "error", message: `${reason} ${UNCERTAIN}` });
			void targets.cancel(item.entry, item.runId);
			failQueue(item.entry, `Previous execution has not stopped. ${UNCERTAIN}`);
		} else {
			if (item.entry) item.entry.queue = item.entry.queue.filter((queued) => queued !== item);
			const suffix =
				item.stage === "setup"
					? "Desktop management may continue; run /figpie-status before retrying."
					: "Document execution was not started.";
			finish(item, { type: "error", message: `${reason} ${suffix}` });
		}
	}
	async function handle(item) {
		const message = item.message;
		if (!["setup", "execute"].includes(message.type)) throw new Error("Unknown Figpie request");
		const maxTime = message.type === "setup" ? 180_000 : 120_000;
		if (
			!Number.isSafeInteger(message.deadline) ||
			message.deadline > Date.now() + maxTime ||
			message.deadline <= Date.now()
		)
			throw new Error("Invalid or expired request deadline; execution was not started");
		item.timer = setTimeout(() => cancel(item, "Request deadline exceeded."), message.deadline - Date.now());
		trace.write("request.received", {
			...context(item),
			type: message.type,
			code: message.code,
			action: message.action,
			deadline: message.deadline,
		});
		if (message.type === "setup") {
			if (!Object.hasOwn(SETUP_ACTIONS, message.action)) throw new Error("Unknown desktop command action");
			if (message.allowPatch !== undefined && typeof message.allowPatch !== "boolean")
				throw new Error("Invalid patch confirmation");
			if (setupTask) {
				if (message.action !== "status")
					throw new Error("Desktop management is already running; wait before trying again");
				finish(item, {
					type: "result",
					data: {
						action: "status",
						desktop: { status: "busy", guidance: "Desktop management is still running; do not repeat the operation." },
						...targets.inventory(),
					},
				});
				return;
			}
			if (
				message.action !== "status" &&
				[...targets.entries.values()].some((entry) => entry.active || entry.queue.length || entry.info.busyId)
			)
				throw new Error("Figma has pending work; wait for completion before desktop management");
			item.stage = "setup";
			setupTask = SETUP_ACTIONS[message.action]({
				allowPatch: message.allowPatch === true,
				deadline: message.deadline,
			});
			try {
				const desktop = await setupTask;
				// No debugger is expected after a successful restore or startup rollback.
				const restored = (message.action === "restore" && desktop.ok) || desktop.rollback?.ok;
				let inventory;
				if (restored) inventory = { connections: [], issues: [] };
				else if (message.action === "connect" && SCRIPTING_STARTUP_STATUSES.has(desktop.status))
					inventory = await waitForScriptingConnection(() => targets.refresh(), {
						deadline: message.deadline,
						isCancelled: () => item.finished,
					});
				else inventory = await targets.refresh();
				finish(item, { type: "result", data: { action: message.action, desktop, ...inventory } });
			} finally {
				setupTask = null;
				scheduleIdle();
			}
			return;
		}
		if (
			typeof message.code !== "string" ||
			Buffer.byteLength(message.code) > MAX_CODE_BYTES ||
			(message.connectionId !== undefined && !isId(message.connectionId))
		)
			throw new Error("Invalid Figpie execution arguments");
		if (setupTask) throw new Error("Desktop management is running; document execution was not started");
		await targets.refresh();
		if (item.finished) return;
		if (setupTask) throw new Error("Desktop management started during discovery; document execution was not started");
		const entry = targets.select(message.connectionId);
		if (entry.statusError || entry.info.busyId || entry.active?.finished)
			throw new Error(`Figma target is busy or its state is uncertain. ${UNCERTAIN}`);
		if (entry.queue.length >= 32) throw new Error("Figma execution queue is full; execution was not started");
		item.entry = entry;
		item.stage = "queued";
		entry.queue.push(item);
		dispatch(entry);
	}
	function dispatch(entry) {
		if (entry.active || entry.retired) return;
		const item = entry.queue.shift();
		if (!item) {
			scheduleIdle();
			return;
		}
		if (item.finished) {
			dispatch(entry);
			return;
		}
		if (item.message.deadline <= Date.now() || item.peer.closed) {
			cancel(item, "Request expired or Pi disconnected before execution.");
			dispatch(entry);
			return;
		}
		entry.active = item;
		item.stage = "running";
		trace.write("execute.dispatch", { ...context(item), target: entry.info, queueMs: Date.now() - item.receivedAt });
		void targets
			.execute(entry, { id: item.runId, code: item.message.code, deadline: item.message.deadline })
			.then((result) => {
				if (!result || !["result", "error"].includes(result.type) || result.id !== item.runId)
					throw new Error("Invalid Figma execution response");
				finish(item, { ...result, connection: describeTarget(entry, { completed: item }) });
			})
			.catch((error) => {
				finish(item, { type: "error", message: `${error.message}\n${UNCERTAIN}`, stack: error.stack });
				// A failed CDP response is not proof that Figma stopped. Reconnect and
				// consult its persistent runtime lock before accepting more work.
				targets.retire(entry);
			})
			.finally(() => {
				entry.active = null;
				entry.info.busyId = null;
				dispatch(entry);
				scheduleIdle();
			});
	}
	targets.on("retired", (entry) =>
		failQueue(entry, "Figma target changed or disconnected before queued execution started."),
	);
	function scheduleIdle() {
		clearTimeout(idleTimer);
		if (closing || peers.size || setupTask || [...targets.entries.values()].some((entry) => entry.active)) return;
		idleTimer = setTimeout(() => void close(), 30_000);
	}
	async function close() {
		if (closing) return;
		closing = true;
		clearTimeout(idleTimer);
		for (const peer of peers) peer.close();
		targets.close();
		await setupTask?.catch(() => {});
		await new Promise((resolve) => server.close(resolve));
		trace.write("broker.stop");
	}
	try {
		if (!(await listen(server))) return null;
	} catch (error) {
		server.close();
		throw error;
	}
	server.on("error", (error) => {
		trace.write("broker.error", { error: errorDetails(error) });
		void close();
	});
	trace.write("broker.start", { socketPath: SOCKET_PATH, cdpPort: CDP_PORT, version: VERSION });
	scheduleIdle();
	return { close };
}
