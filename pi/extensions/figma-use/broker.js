import { WebSocket, WebSocketServer } from "ws";

const HOST = "localhost";
const PORT = Number.parseInt(process.env.PI_FIGMA_USE_PORT || "3846", 10);
const PATH = "/figma-use";
const MAX_PAYLOAD_BYTES = 2 * 1024 * 1024;

let plugin;
let pluginInfo;
let active;
let idleTimer;
const agents = new Set();
const queue = [];

function send(socket, message) {
	if (socket?.readyState === WebSocket.OPEN) {
		socket.send(JSON.stringify(message));
	}
}

function pluginStatus() {
	return { type: "plugin-status", connected: Boolean(plugin), pluginInfo };
}

function broadcastStatus() {
	const status = pluginStatus();
	for (const agent of agents) send(agent, status);
}

function failItem(item, message) {
	send(item.agent, { type: "error", id: item.message.id, message });
}

function failAll(message) {
	if (active) {
		failItem(active, message);
		active = undefined;
	}
	while (queue.length > 0) failItem(queue.shift(), message);
}

function dispatch() {
	if (active || !plugin || plugin.readyState !== WebSocket.OPEN) return;
	while (queue.length > 0) {
		const item = queue.shift();
		if (item.agent.readyState !== WebSocket.OPEN) continue;
		active = item;
		send(plugin, item.message);
		return;
	}
}

function removeAgent(agent) {
	agents.delete(agent);
	for (let index = queue.length - 1; index >= 0; index -= 1) {
		if (queue[index].agent === agent) queue.splice(index, 1);
	}
}

function scheduleIdleExit(server) {
	clearTimeout(idleTimer);
	if (agents.size > 0 || plugin) return;
	idleTimer = setTimeout(() => server.close(() => process.exit(0)), 10_000);
	idleTimer.unref();
}

const server = new WebSocketServer({
	host: HOST,
	port: PORT,
	path: PATH,
	maxPayload: MAX_PAYLOAD_BYTES,
});

server.on("connection", (socket) => {
	let role;
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
			if (message.type !== "hello" || !["agent", "plugin"].includes(message.role)) {
				socket.close(1008, "Client role is required");
				return;
			}
			clearTimeout(helloTimer);
			role = message.role;
			clearTimeout(idleTimer);
			if (role === "agent") {
				agents.add(socket);
				send(socket, pluginStatus());
				return;
			}
			if (plugin && plugin !== socket) plugin.close(1012, "A newer Figma plugin connected");
			plugin = socket;
			pluginInfo = {
				fileName: typeof message.fileName === "string" ? message.fileName : undefined,
				pageName: typeof message.pageName === "string" ? message.pageName : undefined,
				editorType: typeof message.editorType === "string" ? message.editorType : undefined,
			};
			broadcastStatus();
			dispatch();
			return;
		}

		if (role === "agent") {
			if (message.type !== "execute" || typeof message.id !== "string" || typeof message.code !== "string") return;
			if (!plugin) {
				send(socket, { type: "error", id: message.id, message: "Figma plugin is not connected" });
				return;
			}
			queue.push({ agent: socket, message });
			dispatch();
			return;
		}

		if (socket !== plugin) return;
		if (message.type === "hello") {
			pluginInfo = {
				fileName: typeof message.fileName === "string" ? message.fileName : undefined,
				pageName: typeof message.pageName === "string" ? message.pageName : undefined,
				editorType: typeof message.editorType === "string" ? message.editorType : undefined,
			};
			broadcastStatus();
			return;
		}
		if (!active || message.id !== active.message.id || !["result", "error"].includes(message.type)) return;
		send(active.agent, message);
		active = undefined;
		dispatch();
	});

	socket.on("close", () => {
		clearTimeout(helloTimer);
		if (role === "agent") removeAgent(socket);
		if (role === "plugin" && plugin === socket) {
			plugin = undefined;
			pluginInfo = undefined;
			failAll("Figma plugin disconnected");
			broadcastStatus();
		}
		scheduleIdleExit(server);
	});

	socket.on("error", () => {});
});

server.on("error", (error) => {
	if (error.code === "EADDRINUSE") process.exit(0);
	process.exit(1);
});
