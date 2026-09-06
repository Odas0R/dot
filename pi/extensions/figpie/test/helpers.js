import { WebSocket } from "ws";
import { startBroker } from "../broker.js";
import { PROTOCOL_VERSION } from "../protocol.js";

export const TOKEN = "a".repeat(64);
export const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
export async function until(predicate, timeout = 3000) {
	const deadline = Date.now() + timeout;
	while (!predicate()) {
		if (Date.now() >= deadline) throw new Error("Condition timed out");
		await sleep(5);
	}
	return predicate();
}
export async function setup(t, options = {}) {
	const broker = await startBroker({ token: TOKEN, port: 0, ...options });
	const url = `ws://127.0.0.1:${broker.port}/figma-use`;
	const clients = [];
	t.after(async () => { for (const client of clients) client.socket.terminate(); await broker.close(); });
	async function connect(role, extra = {}, wsOptions) {
		const socket = new WebSocket(url, wsOptions);
		const messages = [];
		const client = { socket, messages, send: message => socket.send(JSON.stringify(message)), find: predicate => until(() => messages.find(predicate)) };
		clients.push(client);
		socket.on("error", () => {});
		socket.on("message", data => messages.push(JSON.parse(data)));
		await new Promise((resolve, reject) => { socket.once("open", resolve); socket.once("error", reject); });
		if (role) client.send({ type: "hello", version: PROTOCOL_VERSION, role, token: TOKEN, ...(role === "plugin" ? { fileName: "Test", pageName: "Page", busyId: null } : {}), ...extra });
		if (role && extra.token === undefined && extra.version === undefined) {
			const hello = await client.find(m => m.type === (role === "plugin" ? "session-status" : "connections-status"));
			client.connectionId = hello.connectionId;
		}
		return client;
	}
	return { broker, url, connect };
}
