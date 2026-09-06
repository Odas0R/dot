import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { webcrypto } from "node:crypto";
import vm from "node:vm";
import { PROTOCOL_VERSION, MAX_MESSAGE_BYTES, MAX_PAYLOAD_BYTES } from "../protocol.js";
import { TOKEN } from "./helpers.js";

const html = readFileSync(new URL("../plugin/ui.html", import.meta.url), "utf8");
const script = html.match(/<script>([\s\S]*?)<\/script>/)[1];
function ui() {
	const sockets = [];
	const posts = [];
	const wirePosts = [];
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
	const parent = { postMessage: ({ pluginMessage }) => { wirePosts.push(pluginMessage); posts.push(pluginMessage.message); } };
	const document = { body: {}, getElementById(id) { if (!elements.has(id)) elements.set(id, { value: "", attributes: {}, setAttribute(name, value) { this.attributes[name] = value; }, focus() { document.activeElement = this; } }); return elements.get(id); } };
	const window = {};
	const context = vm.createContext({ parent, document, window, WebSocket: Socket, TextEncoder, crypto: webcrypto,
		setTimeout(fn, ms) { const id = ++sequence; timers.set(id, { fn, ms }); return id; },
		clearTimeout(id) { timers.delete(id); }, setInterval() {},
	});
	vm.runInContext(script, context, { filename: "plugin/ui.html" });
	const receive = (message, source = parent, bridgeId = wirePosts[0].bridgeId) => window.onmessage({ source, data: { pluginMessage: { bridgeId, message } } });
	const target = busyId => receive({ type: "target", version: PROTOCOL_VERSION, requestId: posts.filter(m => m.type === "ready").at(-1)?.requestId, fileName: "Test", pageName: "Page", busyId });
	const authenticate = socket => socket.message({ type: "session-status", version: PROTOCOL_VERSION, connectionId: "ABCD-EFGH", agentCount: 1 });
	return { sockets, posts, wirePosts, timers, document, context, receive, target, authenticate };
}

test("UI constants match and host replies require this window's random handshake key", () => {
	const state = ui();
	for (const [key, value] of Object.entries({ PROTOCOL_VERSION, MAX_MESSAGE_BYTES, MAX_PAYLOAD_BYTES })) assert.equal(vm.runInContext(key, state.context), value);
	assert.match(state.wirePosts[0].bridgeId, /^[a-f0-9]{32}$/);
	assert.notEqual(state.wirePosts[0].bridgeId, ui().wirePosts[0].bridgeId);
	for (const key of [null, "wrong", "b".repeat(32)]) {
		state.receive({ type: "pairing", token: TOKEN }, undefined, key);
		state.receive({ type: "target", version: PROTOCOL_VERSION, fileName: "forged", busyId: null }, null, key);
	}
	assert.equal(state.document.getElementById("target").textContent, "Waiting for file context");
	assert.equal(state.sockets.length, 0);
	state.receive({ type: "pairing", token: TOKEN }, null);
	assert.equal(state.sockets.length, 1, "valid replies need not originate from window.parent");
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

test("handshake diagnostics distinguish broker, file-context and authentication failures", () => {
	for (const phase of ["broker", "context", "auth"]) {
		const state = ui();
		state.receive({ type: "pairing", token: TOKEN });
		const socket = state.sockets[0];
		assert.match(state.document.getElementById("detail").textContent, /Connecting to the local broker/);
		if (phase !== "broker") {
			socket.open();
			assert.match(state.document.getElementById("detail").textContent, /Waiting for Figma file context/);
		}
		if (phase === "auth") {
			state.target(null);
			assert.match(state.document.getElementById("detail").textContent, /Authenticating with the broker/);
			assert.equal(socket.sent[0].bridgeId, undefined);
		}
		// The broker can close before the UI's own hello timeout fires.
		socket.close();
		const expected = phase === "broker" ? /Cannot reach the local broker/ : phase === "context" ? /Figma did not return file context/ : /Broker pairing did not complete/;
		assert.match(state.document.getElementById("detail").textContent, expected);
		assert.equal(state.document.getElementById("detail").textContent.includes(TOKEN), false);
	}
});

test("WebSocket errors are visible and stale socket errors do not overwrite current status", () => {
	const state = ui();
	state.receive({ type: "pairing", token: TOKEN });
	const first = state.sockets[0];
	first.onerror();
	assert.match(state.document.getElementById("detail").textContent, /Local WebSocket connection failed/);
	state.document.getElementById("pairing").onsubmit({ preventDefault() {} });
	const second = state.sockets[1]; second.open(); state.target(null); state.authenticate(second);
	const paired = state.document.getElementById("detail").textContent;
	first.onerror();
	assert.equal(state.document.getElementById("detail").textContent, paired);
});

test("connected view collapses credentials and exposes session count and settings", () => {
	const state = ui();
	const element = id => state.document.getElementById(id);
	assert.equal(element("pairing").hidden, false);
	assert.equal(element("pair-submit").disabled, true);
	state.receive({ type: "pairing", token: TOKEN });
	const socket = state.sockets[0]; socket.open(); state.target(null); state.authenticate(socket);
	assert.equal(element("pairing").hidden, true);
	assert.equal(element("token").value, "");
	assert.equal(element("agents").textContent, "1 Pi session");
	assert.equal(element("connection-meta").hidden, false);
	assert.doesNotMatch(html, /id="reconnect"/);
	element("settings").onclick();
	assert.equal(element("pairing").hidden, false);
	assert.equal(element("settings").attributes["aria-expanded"], "true");
	assert.equal(element("pair-submit").disabled, true, "updating requires a new token");
	assert.equal(state.document.activeElement, element("token"));
	element("token").value = "draft";
	element("cancel-settings").onclick();
	assert.equal(element("token").value, "");
	assert.equal(element("pairing").hidden, true);
	assert.equal(state.document.activeElement, element("settings"));
	assert.equal(state.sockets.length, 1, "opening settings must not reconnect");
	socket.message({ type: "agent-status", count: 3 });
	assert.equal(element("agents").textContent, "3 Pi sessions");
	socket.message({ type: "agent-status", count: 0 });
	assert.match(element("detail").textContent, /Open Pi/);
});

test("invalid input is accessible and active typing wins over delayed stored credentials", () => {
	const state = ui();
	const element = id => state.document.getElementById(id);
	element("token").value = "short";
	element("token").oninput();
	state.receive({ type: "pairing", token: TOKEN });
	assert.equal(state.sockets.length, 0);
	assert.equal(element("token").value, "short");
	element("pairing").onsubmit({ preventDefault() {} });
	assert.equal(element("token").attributes["aria-invalid"], "true");
	assert.match(element("pairing-error").textContent, /64-character/);
	assert.equal(element("pairing-error").hidden, false);
	assert.equal(state.posts.some(m => m.type === "save-pairing"), false);
	element("token").value = TOKEN;
	element("token").oninput();
	assert.equal(element("pairing-error").hidden, true);
	element("token").focus();
	element("pairing").onsubmit({ preventDefault() {} });
	assert.equal(element("token").value, "");
	const socket = state.sockets[0]; socket.open(); state.target(null); state.authenticate(socket);
	assert.equal(state.document.activeElement, element("settings"));
});

test("busy work disables connection changes and storage errors remain visible after pairing", () => {
	const state = ui();
	const element = id => state.document.getElementById(id);
	state.receive({ type: "pairing", token: TOKEN });
	const socket = state.sockets[0]; socket.open(); state.target(null); state.authenticate(socket);
	state.target("active-task");
	const posts = state.posts.length;
	for (const id of ["forget", "pair-submit", "token"]) assert.equal(element(id).disabled, true);
	element("forget").onclick(); element("pairing").onsubmit({ preventDefault() {} });
	assert.equal(state.posts.length, posts);
	assert.equal(state.sockets.length, 1);
	assert.match(element("detail").textContent, /one at a time/);
	state.receive({ type: "pairing-error", message: "Storage is unavailable." });
	assert.equal(element("detail").textContent, "Storage is unavailable.");
	assert.equal(state.document.body.className, "attention");
	state.target(null);
	assert.equal(element("forget").disabled, false);
});

test("forgetting a token wins over a delayed storage response", () => {
	const state = ui();
	state.document.getElementById("forget").onclick();
	state.receive({ type: "pairing", token: TOKEN });
	assert.equal(vm.runInContext("token", state.context), "");
	assert.equal(state.sockets.length, 0);
});
