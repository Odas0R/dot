import test from "node:test";
import assert from "node:assert/strict";
import { WebSocket } from "ws";
import { setup, until, sleep } from "./helpers.js";

const execute = (id, connectionId, ms = 5000) => ({ type: "execute", id, connectionId, code: `return '${id}'`, deadline: Date.now() + ms });
const result = id => ({ type: "result", id, text: "done", images: [] });

test("requires authentication/version and rejects arbitrary browser origins", async t => {
	const { connect } = await setup(t);
	await assert.rejects(connect(null, {}, { origin: "https://untrusted.example" }), /401/);
	const denied = await connect("agent", { token: "b".repeat(64) });
	assert.match((await denied.find(m => m.type === "protocol-error")).message, /Pairing rejected/);
	assert.equal(denied.messages.some(m => m.connections), false);
	const old = await connect("agent", { version: 1 });
	assert.match((await old.find(m => m.type === "protocol-error")).message, /Protocol mismatch/);
	const opaque = await connect("plugin", {}, { origin: "null" });
	assert.ok(opaque.connectionId);
});

test("null, binary and malformed messages close only the offending socket", async t => {
	const { connect } = await setup(t);
	for (const payload of ["null", "[]", "{", '{"type":"execute"}']) {
		const bad = await connect("agent");
		bad.socket.send(payload);
		await until(() => bad.socket.readyState === WebSocket.CLOSED);
		assert.ok((await connect("agent")).messages.some(m => m.type === "connections-status"));
	}
	const binary = await connect("agent");
	binary.socket.send(Buffer.from("null"));
	await binary.find(m => m.type === "protocol-error");
});

test("cancelled and expired queued work is never dispatched", async t => {
	const { connect } = await setup(t);
	const plugin = await connect("plugin");
	const agent = await connect("agent");
	agent.send(execute("blocker", plugin.connectionId));
	const blocker = await plugin.find(m => m.type === "execute");
	agent.send(execute("cancelled", plugin.connectionId));
	agent.send({ type: "cancel", id: "cancelled" });
	agent.send(execute("expired", plugin.connectionId, 60));
	assert.match((await agent.find(m => m.id === "cancelled")).message, /not started/);
	assert.match((await agent.find(m => m.id === "expired")).message, /not started/);
	plugin.send(result(blocker.id));
	await agent.find(m => m.id === "blocker");
	await sleep(40);
	assert.equal(plugin.messages.filter(m => m.type === "execute").length, 1);
});

test("active cancellation blocks the session until the plugin confirms completion", async t => {
	const { connect } = await setup(t);
	const plugin = await connect("plugin");
	const agent = await connect("agent");
	agent.send(execute("active", plugin.connectionId));
	const active = await plugin.find(m => m.type === "execute");
	agent.send(execute("queued", plugin.connectionId));
	agent.send({ type: "cancel", id: "active" });
	assert.match((await agent.find(m => m.id === "active")).message, /may still be running/);
	assert.match((await agent.find(m => m.id === "queued")).message, /has not stopped/);
	plugin.send({ type: "target", fileName: "Test", busyId: null }); // Cannot unlock an active broker-owned request.
	agent.send(execute("blocked", plugin.connectionId));
	assert.match((await agent.find(m => m.id === "blocked")).message, /busy/);
	plugin.send(result(active.id));
	await sleep(20);
	agent.send(execute("next", plugin.connectionId));
	assert.ok(await plugin.find(m => m.type === "execute" && m.code.includes("next")));
});

test("active deadline blocks instead of dispatching overlapping work", async t => {
	const { connect } = await setup(t);
	const plugin = await connect("plugin");
	const agent = await connect("agent");
	agent.send(execute("active", plugin.connectionId, 60));
	await plugin.find(m => m.type === "execute");
	agent.send(execute("queued", plugin.connectionId));
	assert.match((await agent.find(m => m.id === "active")).message, /deadline exceeded/);
	await agent.find(m => m.id === "queued");
	assert.equal(plugin.messages.filter(m => m.type === "execute").length, 1);
});

test("reconnected plugin advertises previous execution and stays unavailable until idle", async t => {
	const { connect } = await setup(t);
	const plugin = await connect("plugin", { busyId: "old-broker-run" });
	const agent = await connect("agent");
	agent.send(execute("blocked", plugin.connectionId));
	assert.match((await agent.find(m => m.id === "blocked")).message, /busy/);
	plugin.send({ type: "target", fileName: "Test", busyId: null });
	await sleep(20);
	agent.send(execute("next", plugin.connectionId));
	await plugin.find(m => m.type === "execute");
});

test("queues are bounded; sessions run independently; agent IDs cannot collide in the plugin", async t => {
	const { connect } = await setup(t, { maxQueue: 1 });
	const p1 = await connect("plugin");
	const p2 = await connect("plugin");
	const a1 = await connect("agent");
	const a2 = await connect("agent");
	a1.send(execute("same-id", p1.connectionId));
	a2.send(execute("same-id", p2.connectionId));
	const r1 = await p1.find(m => m.type === "execute");
	const r2 = await p2.find(m => m.type === "execute");
	assert.notEqual(r1.id, r2.id);
	a1.send(execute("queued", p1.connectionId));
	a1.send(execute("overflow", p1.connectionId));
	assert.match((await a1.find(m => m.id === "overflow")).message, /queue is full/);
	p2.send(result(r2.id));
	assert.equal((await a2.find(m => m.id === "same-id")).text, "done");
});

test("envelope size, not raw code size, controls the code budget", async t => {
	const { connect } = await setup(t);
	const plugin = await connect("plugin");
	const agent = await connect("agent");
	agent.send({ ...execute("oversized", plugin.connectionId), code: '"'.repeat(600_000) });
	assert.match((await agent.find(m => m.id === "oversized")).message, /exceeds/);
	assert.equal(plugin.messages.some(m => m.type === "execute"), false);
});

test("agent disconnect cancels active work and drops queued work", async t => {
	const { connect } = await setup(t);
	const plugin = await connect("plugin");
	const agent = await connect("agent");
	agent.send(execute("active", plugin.connectionId));
	const active = await plugin.find(m => m.type === "execute");
	agent.send(execute("queued", plugin.connectionId));
	agent.socket.close();
	await plugin.find(m => m.type === "cancel");
	plugin.send(result(active.id));
	await sleep(30);
	assert.equal(plugin.messages.filter(m => m.type === "execute").length, 1);
});
