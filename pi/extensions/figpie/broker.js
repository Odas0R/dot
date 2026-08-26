import { randomBytes } from "node:crypto";

import { WebSocket, WebSocketServer } from "ws";

const HOSTS = ["127.0.0.1", "::1"];
const PORT = Number.parseInt(
	process.env.PI_FIGPIE_PORT || process.env.PI_FIGMA_USE_PORT || "3846",
	10,
);
const PATH = "/figma-use";
const MAX_PAYLOAD_BYTES = 20 * 1024 * 1024;

const agents = new Set();
const hosts = new Set();
const plugins = new Map();
let idleTimer;

function send(socket, message) {
	if (socket?.readyState === WebSocket.OPEN) socket.send(JSON.stringify(message));
}

function createConnectionId() {
	const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
	for (;;) {
		const bytes = randomBytes(8);
		let id = "";
		for (let index = 0; index < 8; index += 1) id += alphabet[bytes[index] % alphabet.length];
		id = `${id.slice(0, 4)}-${id.slice(4)}`;
		if (!plugins.has(id)) return id;
	}
}

function sessionInfo(session) {
	return {
		connectionId: session.connectionId,
		fileKey: session.info.fileKey,
		fileName: session.info.fileName,
		pageName: session.info.pageName,
		editorType: session.info.editorType,
	};
}

function connectionsStatus() {
	const sessions = [...plugins.values()];
	const ready = sessions.filter((session) => Boolean(session.info.fileName));
	return {
		type: "connections-status",
		connections: ready.map(sessionInfo),
		initializingCount: sessions.length - ready.length,
	};
}

function broadcastConnections() {
	const status = connectionsStatus();
	for (const agent of agents) send(agent, status);
}

function sendAgentStatus() {
	for (const session of plugins.values()) {
		send(session.socket, { type: "agent-status", count: agents.size });
	}
}

function failItem(item, message) {
	send(item.agent, {
		type: "error",
		id: item.message.id,
		connectionId: item.message.connectionId,
		message,
	});
}

function failSession(session, message) {
	if (session.active) {
		failItem(session.active, message);
		session.active = undefined;
	}
	while (session.queue.length > 0) failItem(session.queue.shift(), message);
}

function dispatch(session) {
	if (session.active || session.socket.readyState !== WebSocket.OPEN) return;
	while (session.queue.length > 0) {
		const item = session.queue.shift();
		if (item.agent.readyState !== WebSocket.OPEN) continue;
		session.active = item;
		send(session.socket, item.message);
		return;
	}
}

function removeAgent(agent) {
	agents.delete(agent);
	for (const session of plugins.values()) {
		for (let index = session.queue.length - 1; index >= 0; index -= 1) {
			if (session.queue[index].agent === agent) session.queue.splice(index, 1);
		}
	}
	sendAgentStatus();
}

function scheduleIdleExit() {
	clearTimeout(idleTimer);
	if (agents.size > 0 || hosts.size > 0 || plugins.size > 0) return;
	idleTimer = setTimeout(() => {
		let remaining = servers.length;
		for (const server of servers) {
			server.close(() => {
				remaining -= 1;
				if (remaining === 0) process.exit(0);
			});
		}
	}, 10_000);
	idleTimer.unref();
}

function readPluginInfo(message) {
	return {
		fileKey: typeof message.fileKey === "string" ? message.fileKey : undefined,
		fileName: typeof message.fileName === "string" ? message.fileName : undefined,
		pageName: typeof message.pageName === "string" ? message.pageName : undefined,
		editorType: typeof message.editorType === "string" ? message.editorType : undefined,
	};
}

const servers = HOSTS.map((host) => new WebSocketServer({
	host,
	port: PORT,
	path: PATH,
	maxPayload: MAX_PAYLOAD_BYTES,
}));

function handleConnection(socket) {
	let role;
	let connectionId;
	const helloTimer = setTimeout(() => socket.close(1008, "Client hello timed out"), 3000);

	socket.on("message", (data) => {
		let message;
		try {
			message = JSON.parse(data.toString("utf8"));
		} catch {
			socket.close(1003, "Invalid JSON");
			return;
		}

		if (!role) {
			if (message.type !== "hello" || !["agent", "host", "plugin"].includes(message.role)) {
				socket.close(1008, "Client role is required");
				return;
			}
			clearTimeout(helloTimer);
			clearTimeout(idleTimer);
			role = message.role;
			if (role === "agent") {
				agents.add(socket);
				send(socket, connectionsStatus());
				for (const session of plugins.values()) {
					if (!session.info.fileName) send(session.socket, { type: "request-target" });
				}
				sendAgentStatus();
				return;
			}
			if (role === "host") {
				hosts.add(socket);
				send(socket, { type: "host-status" });
				return;
			}

			const preferred = typeof message.connectionId === "string" ? message.connectionId : undefined;
			connectionId = preferred && !plugins.has(preferred) ? preferred : createConnectionId();
			const session = {
				connectionId,
				socket,
				info: readPluginInfo(message),
				queue: [],
				active: undefined,
			};
			plugins.set(connectionId, session);
			send(socket, { type: "session-status", ...sessionInfo(session), agentCount: agents.size });
			broadcastConnections();
			return;
		}

		if (role === "host") return;

		if (role === "agent") {
			if (message.type !== "execute" || typeof message.id !== "string" || typeof message.code !== "string") return;
			const session = plugins.get(message.connectionId);
			if (!session) {
				send(socket, {
					type: "error",
					id: message.id,
					connectionId: message.connectionId,
					message: `Figma connection not found: ${message.connectionId || "none"}`,
				});
				return;
			}
			session.queue.push({ agent: socket, message });
			dispatch(session);
			return;
		}

		const session = plugins.get(connectionId);
		if (!session || session.socket !== socket) return;
		if (message.type === "hello" || message.type === "target") {
			session.info = readPluginInfo(message);
			send(socket, { type: "session-status", ...sessionInfo(session), agentCount: agents.size });
			broadcastConnections();
			return;
		}
		if (!session.active || message.id !== session.active.message.id || !["result", "error"].includes(message.type)) return;
		send(session.active.agent, { ...message, connectionId });
		session.active = undefined;
		dispatch(session);
	});

	socket.on("close", () => {
		clearTimeout(helloTimer);
		if (role === "agent") removeAgent(socket);
		if (role === "host") hosts.delete(socket);
		if (role === "plugin" && connectionId) {
			const session = plugins.get(connectionId);
			if (session?.socket === socket) {
				plugins.delete(connectionId);
				failSession(session, `Figma connection ${connectionId} disconnected`);
				broadcastConnections();
			}
		}
		scheduleIdleExit();
	});

	socket.on("error", () => {});
}

for (const server of servers) {
	server.on("connection", handleConnection);
	server.on("error", () => process.exit(1));
}
