import { randomBytes, randomUUID } from "node:crypto";
import { pathToFileURL } from "node:url";
import { WebSocket, WebSocketServer } from "ws";
import { ensureToken, tokenMatches, TOKEN_PATTERN } from "./auth.js";
import {
	PROTOCOL_VERSION, HOST, PORT, PATH, MAX_PAYLOAD_BYTES, MAX_CODE_BYTES,
	isConnectionId, parseMessage, encodeMessage, isId, isDeadline, validTarget, validResult,
	validatePortEnvironment,
} from "./protocol.js";

// Figma's sandboxed iframe may have an opaque origin. The token remains mandatory.
const ALLOWED_ORIGINS = new Set(["null", "https://www.figma.com", "https://figma.com"]);
const UNCERTAIN = "Execution may still be running and changes may remain. Inspect before retrying; restart Figpie in Figma if it stays busy.";

export async function startBroker({ token, port = PORT, maxQueue = 32, helloMs = 3000, heartbeatMs = 15_000, idleMs = 10_000, log = console.error } = {}) {
	if (!TOKEN_PATTERN.test(token || "")) throw new Error("A valid pairing token is required");
	const agents = new Set();
	const plugins = new Map();
	const requests = new Map(); // Per-agent IDs; plugin executions get independent broker-generated IDs.
	let idleTimer;
	let closing = false;
	const server = new WebSocketServer({
		host: HOST, port, path: PATH, maxPayload: MAX_PAYLOAD_BYTES,
		verifyClient: ({ origin }) => origin === undefined || origin === "" || ALLOWED_ORIGINS.has(origin),
	});

	function send(socket, message) {
		if (socket?.readyState !== WebSocket.OPEN) return false;
		try {
			const encoded = encodeMessage(message);
			if (socket.bufferedAmount + Buffer.byteLength(encoded) > MAX_PAYLOAD_BYTES) {
				socket.terminate();
				return false;
			}
			socket.send(encoded, (error) => { if (error) socket.terminate(); });
			return true;
		} catch { socket.terminate(); return false; }
	}
	function info(session) {
		return { connectionId: session.id, ...session.info, busy: Boolean(session.active || session.busyId), blocked: session.blocked, queueLength: session.queue.length };
	}
	function status() {
		const sessions = [...plugins.values()];
		return { type: "connections-status", version: PROTOCOL_VERSION, connections: sessions.filter(s => s.info.fileName).map(info), initializingCount: sessions.filter(s => !s.info.fileName).length };
	}
	function broadcast() {
		for (const agent of agents) send(agent, status());
	}
	function agentStatus() {
		for (const session of plugins.values()) send(session.socket, { type: "agent-status", count: agents.size });
	}
	function finish(item, response) {
		if (item.finished) return;
		item.finished = true;
		clearTimeout(item.timer);
		requests.get(item.agent)?.delete(item.id);
		send(item.agent, { ...response, id: item.id, connectionId: item.session.id });
	}
	function fail(item, message) { finish(item, { type: "error", message }); }
	function failQueue(session, reason) {
		for (const item of session.queue.splice(0)) fail(item, reason);
	}
	function dispatch(session) {
		if (session.active || session.busyId || session.blocked || session.socket.readyState !== WebSocket.OPEN) return;
		while (session.queue.length) {
			const item = session.queue.shift();
			if (item.finished) continue;
			if (item.agent.readyState !== WebSocket.OPEN || item.deadline <= Date.now()) {
				fail(item, "Request expired or its Pi session disconnected before execution; it was not started.");
				continue;
			}
			session.active = item;
			send(session.socket, { type: "execute", id: item.runId, code: item.code, deadline: item.deadline });
			break;
		}
		broadcast();
	}
	function cancel(item, reason) {
		if (item.finished) return;
		const session = item.session;
		if (session.active === item) {
			// Never unlock a running script just because its caller stopped waiting.
			session.blocked = true;
			fail(item, `${reason} ${UNCERTAIN}`);
			send(session.socket, { type: "cancel", id: item.runId });
			failQueue(session, `Previous execution has not stopped. ${UNCERTAIN}`);
		} else {
			session.queue = session.queue.filter(queued => queued !== item);
			fail(item, `${reason} It was removed from the queue and was not started.`);
		}
		broadcast();
	}
	function newId() {
		let id;
		do { const hex = randomBytes(4).toString("hex").toUpperCase(); id = `${hex.slice(0, 4)}-${hex.slice(4)}`.replace(/0/g, "G").replace(/1/g, "H"); } while (plugins.has(id));
		return id;
	}
	function updateTarget(session, message) {
		session.info = Object.fromEntries(["fileKey", "fileName", "pageName", "editorType"].map(key => [key, message[key]]));
		// Only a terminal response may unlock an execution owned by this broker.
		if (!session.active) {
			session.busyId = message.busyId;
			session.blocked = Boolean(message.busyId);
		}
	}
	function scheduleIdle() {
		clearTimeout(idleTimer);
		if (closing || server.clients.size) return;
		idleTimer = setTimeout(() => void close(), idleMs);
		idleTimer.unref();
	}
	async function close() {
		if (closing) return;
		closing = true;
		clearTimeout(idleTimer);
		clearInterval(heartbeat);
		for (const socket of server.clients) socket.terminate();
		await new Promise(resolve => server.close(resolve));
	}

	server.on("connection", (socket) => {
		clearTimeout(idleTimer);
		let role;
		let session;
		socket.alive = true;
		socket.on("pong", () => { socket.alive = true; });
		const helloTimer = setTimeout(() => socket.terminate(), helloMs);
		function invalid(reason) {
			send(socket, { type: "protocol-error", version: PROTOCOL_VERSION, message: reason });
			socket.close(1008, reason.slice(0, 100));
		}
		socket.on("message", (data, binary) => {
			let message;
			try {
				if (binary) throw new Error("Binary messages are not supported");
				message = parseMessage(data);
				if (!role) {
					if (message.type !== "hello" || !["agent", "plugin"].includes(message.role)) throw new Error("Authenticated hello required");
					if (message.version !== PROTOCOL_VERSION) throw new Error("Protocol mismatch; restart the broker and update the plugin");
					if (!tokenMatches(message.token, token)) throw new Error("Pairing rejected; use /figpie-pair in Pi");
					if (message.role === "plugin" && (!validTarget(message) || (message.connectionId !== undefined && !isConnectionId(message.connectionId)))) throw new Error("Invalid plugin hello");
					clearTimeout(helloTimer);
					role = message.role;
					if (role === "agent") {
						agents.add(socket);
						requests.set(socket, new Map());
						send(socket, status());
						agentStatus();
					} else {
						const id = message.connectionId && !plugins.has(message.connectionId) ? message.connectionId : newId();
						session = { id, socket, queue: [], active: null, busyId: null, blocked: false, info: {} };
						updateTarget(session, message);
						plugins.set(id, session);
						send(socket, { type: "session-status", version: PROTOCOL_VERSION, ...info(session), agentCount: agents.size });
						broadcast();
					}
					return;
				}
				if (role === "agent") {
					if (message.type === "cancel" && isId(message.id)) {
						const item = requests.get(socket).get(message.id);
						if (item) cancel(item, "Request cancelled.");
						return;
					}
					if (message.type !== "execute" || !isId(message.id) || typeof message.code !== "string" || !isConnectionId(message.connectionId) || !isDeadline(message.deadline) || message.deadline > Date.now() + 120_000) throw new Error("Invalid execute request");
					const target = plugins.get(message.connectionId);
					const reject = (reason) => send(socket, { type: "error", id: message.id, message: reason });
					if (requests.get(socket).has(message.id)) throw new Error("Duplicate request ID");
					try { encodeMessage(message, MAX_CODE_BYTES); } catch (error) { reject(error.message); return; }
					if (!target) { reject("Figma connection not found; refresh the connection inventory."); return; }
					if (message.deadline <= Date.now()) { reject("Request expired before execution; it was not started."); return; }
					if (target.blocked || target.busyId) { reject(`Figma is busy with a previous execution. ${UNCERTAIN}`); return; }
					if (target.queue.length >= maxQueue) { reject("Figma request queue is full; retry after pending calls finish."); return; }
					const item = { agent: socket, session: target, id: message.id, runId: randomUUID(), code: message.code, deadline: message.deadline, finished: false };
					item.timer = setTimeout(() => cancel(item, "Request deadline exceeded."), message.deadline - Date.now());
					requests.get(socket).set(item.id, item);
					target.queue.push(item);
					dispatch(target);
					broadcast();
					return;
				}
				if (message.type === "target" && validTarget(message)) {
					updateTarget(session, message);
					if (session.busyId) failQueue(session, `Figma is still busy. ${UNCERTAIN}`);
					dispatch(session);
					broadcast();
					return;
				}
				if (!validResult(message)) throw new Error("Invalid plugin response");
				if (!session.active || message.id !== session.active.runId) return; // Late response from a previous transport.
				finish(session.active, message);
				session.active = null;
				session.busyId = null;
				session.blocked = false;
				dispatch(session);
			} catch (error) { invalid(error.message); }
		});
		socket.on("close", () => {
			clearTimeout(helloTimer);
			if (role === "agent") {
				agents.delete(socket);
				for (const item of requests.get(socket)?.values() || []) cancel(item, "Pi disconnected.");
				requests.delete(socket);
				agentStatus();
			}
			if (session) {
				plugins.delete(session.id);
				if (session.active) fail(session.active, `Figma disconnected. ${UNCERTAIN}`);
				failQueue(session, "Figma disconnected before queued work started.");
				broadcast();
			}
			scheduleIdle();
		});
		socket.on("error", () => {});
	});
	const heartbeat = setInterval(() => {
		for (const socket of server.clients) {
			if (!socket.alive) { socket.terminate(); continue; }
			socket.alive = false;
			socket.ping();
		}
	}, heartbeatMs);
	heartbeat.unref();
	try {
		await new Promise((resolve, reject) => { server.once("listening", resolve); server.once("error", reject); });
	} catch (error) { clearInterval(heartbeat); throw error; }
	server.on("error", error => log(`Figpie broker: ${error.message}`));
	scheduleIdle();
	return { port: server.address().port, close };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
	try {
		validatePortEnvironment();
		const broker = await startBroker({ token: await ensureToken() });
		for (const signal of ["SIGTERM", "SIGINT"]) process.once(signal, () => void broker.close());
	} catch (error) {
		console.error(`Figpie broker could not start: ${error.message}`);
		process.exitCode = 1;
	}
}
