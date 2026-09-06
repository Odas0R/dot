import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import { PROTOCOL_VERSION, MAX_MESSAGE_BYTES, MAX_PAYLOAD_BYTES } from "../protocol.js";
import { TOKEN } from "./helpers.js";

const html = readFileSync(new URL("../plugin/ui.html", import.meta.url), "utf8");
const script = html.match(/<script>([\s\S]*?)<\/script>/)[1];
function ui() {
	const sockets = [];
	const posts = [];
	const timers = new Map();
	const elements = new Map();
	let sequence = 0;
	class Socket {
		static OPEN = 1;
		constructor() { this.readyState = 0; this.bufferedAmount = 0; this.sent = []; sockets.push(this); }
		open() { this.readyState = 1; this.onopen?.(); }
		close() { if (this.readyState === 3) return; this.readyState = 3; this.onclose?.(); }
		send(message) { this.sent.push(JSON.parse(message)); }
		message(message) { this.onmessage?.({ data: JSON.stringify(message) }); }
	}
	const parent = { postMessage: message => posts.push(message.pluginMessage) };
	const document = { body: {}, getElementById(id) { if (!elements.has(id)) elements.set(id, { value: "" }); return elements.get(id); } };
	const window = {};
	const context = vm.createContext({ parent, document, window, WebSocket: Socket, TextEncoder,
		setTimeout(fn, ms) { const id = ++sequence; timers.set(id, { fn, ms }); return id; },
		clearTimeout(id) { timers.delete(id); }, setInterval() {},
	});
	vm.runInContext(script, context, { filename: "plugin/ui.html" });
	const receive = (message, source = parent) => window.onmessage({ source, data: { pluginMessage: message } });
	const target = busyId => receive({ type: "target", version: PROTOCOL_VERSION, requestId: posts.filter(m => m.type === "ready").at(-1)?.requestId, fileName: "Test", pageName: "Page", busyId });
	const authenticate = socket => socket.message({ type: "session-status", version: PROTOCOL_VERSION, connectionId: "ABCD-EFGH", agentCount: 1 });
	return { sockets, posts, timers, document, context, receive, target, authenticate };
}

test("UI constants are synchronized and pairing requires the parent message source", () => {
	const state = ui();
	for (const [key, value] of Object.entries({ PROTOCOL_VERSION, MAX_MESSAGE_BYTES, MAX_PAYLOAD_BYTES })) assert.equal(vm.runInContext(key, state.context), value);
	state.receive({ type: "pairing", token: TOKEN }, {});
	assert.equal(state.sockets.length, 0);
	state.receive({ type: "pairing", token: TOKEN });
	assert.equal(state.sockets.length, 1);
});

test("fresh sandbox busy state is required before hello; broker must authenticate before execution", () => {
	const state = ui();
	state.receive({ type: "pairing", token: TOKEN });
	const socket = state.sockets[0];
	socket.open();
	assert.equal(socket.sent.length, 0);
	state.receive({ type: "target", version: PROTOCOL_VERSION, fileName: "stale", busyId: null });
	assert.equal(socket.sent.length, 0, "stale context must not authenticate a new transport");
	state.target("old-run");
	assert.equal(socket.sent[0].type, "hello");
	assert.equal(socket.sent[0].busyId, "old-run");
	assert.equal(socket.sent[0].token, TOKEN);
	socket.message({ type: "execute", id: "bad", code: "return 1", deadline: Date.now() + 1000 });
	assert.equal(state.posts.some(m => m.type === "execute"), false);
});

test("transport loss cancels sandbox work and drops old results after reconnect", () => {
	const state = ui();
	state.receive({ type: "pairing", token: TOKEN });
	const first = state.sockets[0]; first.open(); state.target(null); state.authenticate(first);
	first.message({ type: "execute", id: "old-run", code: "wait", deadline: Date.now() + 5000 });
	assert.ok(state.posts.some(m => m.type === "execute"));
	first.close();
	assert.ok(state.posts.some(m => m.type === "transport-lost"));
	state.document.getElementById("pairing").onsubmit({ preventDefault() {} });
	const second = state.sockets[1]; second.open(); state.target("old-run"); state.authenticate(second);
	state.receive({ type: "result", id: "old-run", text: "done", images: [] });
	assert.equal(second.sent.some(m => m.type === "result"), false);
	state.target(null);
	assert.ok(second.sent.some(m => m.type === "target" && m.busyId === null));
});

test("legacy session-status pauses rather than accepting unauthenticated broker execution", () => {
	const state = ui(); state.receive({ type: "pairing", token: TOKEN });
	const socket = state.sockets[0]; socket.open(); state.target(null);
	socket.message({ type: "session-status", connectionId: "ABCD-EFGH", agentCount: 1 });
	assert.match(state.document.getElementById("detail").textContent, /Incompatible broker/);
	assert.equal(state.timers.size, 0);
});

test("forgetting a token wins over a delayed storage response", () => {
	const state = ui();
	state.document.getElementById("forget").onclick();
	state.receive({ type: "pairing", token: TOKEN });
	assert.equal(vm.runInContext("token", state.context), "");
	assert.equal(state.sockets.length, 0);
});
