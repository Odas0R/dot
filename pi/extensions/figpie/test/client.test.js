import test from "node:test";
import assert from "node:assert/strict";
import { WebSocketServer } from "ws";
import { BrokerClient } from "../client.js";
import { startBroker } from "../broker.js";
import { TOKEN, setup, sleep, until } from "./helpers.js";

function clientFor(t, url, options = {}) {
	const client = new BrokerClient({ tokenLoader: async () => TOKEN, url, retryMs: 5, maxRetryMs: 10, ...options });
	t.after(() => client.stop());
	client.start();
	return client;
}

test("successful round trip preserves text, images and selected connection", async t => {
	const { connect, url } = await setup(t);
	const plugin = await connect("plugin");
	const client = clientFor(t, url);
	await client.waitReady(AbortSignal.timeout(2000));
	const execution = client.execute("return 'hello'", 2, plugin.connectionId.toLowerCase());
	const request = await plugin.find(m => m.type === "execute");
	plugin.send({ type: "result", id: request.id, text: "hello", images: [{ mimeType: "image/png", data: "AQID", name: "test.png" }] });
	const result = await execution;
	assert.equal(result.text, "hello");
	assert.equal(result.connection.connectionId, plugin.connectionId);
	assert.deepEqual(result.images, [{ mimeType: "image/png", data: "AQID", name: "test.png" }]);
	assert.equal(client.pending.size, 0);
});

test("client sends queue cancellation and cleans pending entries/listeners", async t => {
	const { connect, url } = await setup(t);
	const plugin = await connect("plugin");
	const blocker = await connect("agent");
	blocker.send({ type: "execute", id: "blocker", connectionId: plugin.connectionId, code: "block", deadline: Date.now() + 5000 });
	const active = await plugin.find(m => m.type === "execute");
	const client = clientFor(t, url);
	await client.waitReady(AbortSignal.timeout(2000));
	const controller = new AbortController();
	const execution = client.execute("cancelled code", 3, undefined, controller.signal);
	const rejection = assert.rejects(execution, /cancelled/);
	await until(() => client.connections[0]?.queueLength === 1);
	controller.abort();
	await rejection;
	await until(() => client.connections[0]?.queueLength === 0);
	plugin.send({ type: "result", id: active.id, text: "done", images: [] });
	await sleep(30);
	assert.equal(plugin.messages.filter(m => m.type === "execute").length, 1);
	assert.equal(client.pending.size, 0);
	assert.equal(client.listenerCount("ready"), 0);
});

test("timeout includes connection establishment; abort before readiness never submits code", async t => {
	const server = new WebSocketServer({ port: 0, host: "127.0.0.1" });
	await new Promise(resolve => server.once("listening", resolve));
	const messages = [];
	server.on("connection", socket => socket.on("message", data => messages.push(JSON.parse(data))));
	t.after(async () => { for (const socket of server.clients) socket.terminate(); await new Promise(resolve => server.close(resolve)); });
	const client = clientFor(t, `ws://127.0.0.1:${server.address().port}/figma-use`);
	const started = Date.now();
	await assert.rejects(client.execute("return 1", 1), /timed out/);
	assert.ok(Date.now() - started < 1600);
	const controller = new AbortController(); controller.abort();
	await assert.rejects(client.execute("return 2", 1, undefined, controller.signal), /cancelled/);
	assert.equal(messages.some(m => m.type === "execute"), false);
	await client.stop();
	assert.equal(client.socket, undefined);
});

test("shutdown during hello cannot resurrect sockets", async t => {
	const server = new WebSocketServer({ port: 0, host: "127.0.0.1" });
	await new Promise(resolve => server.once("listening", resolve));
	t.after(async () => { for (const socket of server.clients) socket.terminate(); await new Promise(resolve => server.close(resolve)); });
	const client = clientFor(t, `ws://127.0.0.1:${server.address().port}/figma-use`);
	await until(() => server.clients.size === 1);
	await client.stop();
	await sleep(40);
	assert.equal(server.clients.size, 0);
	assert.equal(client.connected, false);
	assert.equal(client.lifecycle, undefined);
});

test("keeps retrying beyond 31 failures and recovers when broker becomes available", async t => {
	const reservation = await startBroker({ token: TOKEN, port: 0 });
	const port = reservation.port;
	await reservation.close();
	let attempts = 0;
	const client = clientFor(t, `ws://127.0.0.1:${port}/figma-use`, { retryMs: 1, maxRetryMs: 1 });
	client.on("status", () => attempts++);
	await until(() => attempts > 70);
	const broker = await startBroker({ token: TOKEN, port });
	t.after(() => broker.close());
	await client.waitReady(AbortSignal.timeout(2000));
	assert.equal(client.connected, true);
});

test("legacy broker is rejected before any execution is sent", async t => {
	const server = new WebSocketServer({ port: 0, host: "127.0.0.1" });
	await new Promise(resolve => server.once("listening", resolve));
	const messages = [];
	server.on("connection", socket => socket.on("message", data => { messages.push(JSON.parse(data)); socket.send(JSON.stringify({ type: "connections-status", connections: [], initializingCount: 0 })); }));
	t.after(async () => { for (const socket of server.clients) socket.terminate(); await new Promise(resolve => server.close(resolve)); });
	const client = clientFor(t, `ws://127.0.0.1:${server.address().port}/figma-use`);
	await assert.rejects(client.execute("must not run", 2), /Incompatible/);
	assert.equal(messages.some(m => m.type === "execute"), false);
});

test("shutdown while token loading does not open a socket", async t => {
	let release;
	const loaded = new Promise(resolve => { release = resolve; });
	const client = clientFor(t, "ws://127.0.0.1:1", { tokenLoader: () => loaded });
	const stopping = client.stop();
	release(TOKEN);
	await stopping;
	assert.equal(client.socket, undefined);
});
