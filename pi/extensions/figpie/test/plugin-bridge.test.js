import test from "node:test";
import assert from "node:assert/strict";
import { webcrypto } from "node:crypto";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import { WebSocket } from "ws";
import { setup, until, TOKEN } from "./helpers.js";

const pluginCode = readFileSync(new URL("../plugin/code.js", import.meta.url), "utf8");
const html = readFileSync(new URL("../plugin/ui.html", import.meta.url), "utf8");
const uiCode = html.match(/<script>([\s\S]*?)<\/script>/)[1];

for (const sender of ["parent", "self", "null"]) {
	test(`UI/sandbox/broker handshake and results work with ${sender} host message source`, async t => {
		const { url, connect } = await setup(t);
		const agent = await connect("agent");
		const sockets = [];
		const timers = new Set();
		const elements = new Map();
		const window = {};
		let disposed = false;
		const parent = { postMessage({ pluginMessage }) { if (!disposed) void figma.ui.onmessage(pluginMessage); } };
		const document = { body: {}, getElementById(id) { if (!elements.has(id)) elements.set(id, { value: "", attributes: {}, setAttribute(name, value) { this.attributes[name] = value; }, focus() { document.activeElement = this; } }); return elements.get(id); } };
		const figma = {
			root: { id: "0:0", type: "DOCUMENT", name: "Bridge test" },
			currentPage: { id: "0:1", type: "PAGE", name: "Page" },
			editorType: "figma", showUI() {}, on() {}, commitUndo() {},
			clientStorage: { async getAsync() { return TOKEN; }, async setAsync() {} },
			ui: { postMessage(pluginMessage) {
				if (!disposed) window.onmessage?.({ source: sender === "parent" ? parent : sender === "self" ? window : null, data: { pluginMessage } });
			} },
		};
		class Socket extends WebSocket {
			constructor(requestedURL) {
				assert.equal(requestedURL, "ws://localhost:3846/figma-use");
				super(url); // Isolated ephemeral-port broker; never connect to live Figma.
				sockets.push(this);
				this.on("error", () => {});
			}
		}
		const trackTimer = schedule => (fn, ms) => {
			if (disposed) return;
			const timer = schedule(() => { if (!disposed) fn(); }, ms);
			timers.add(timer);
			return timer;
		};
		t.after(() => {
			disposed = true;
			for (const timer of timers) { clearTimeout(timer); clearInterval(timer); }
			for (const socket of sockets) socket.terminate();
		});
		vm.runInContext(pluginCode, vm.createContext({ figma, __html__: html, console }), { filename: "plugin/code.js" });
		vm.runInContext(uiCode, vm.createContext({ window, parent, document, console, crypto: webcrypto, TextEncoder, WebSocket: Socket,
			setTimeout: trackTimer(setTimeout), clearTimeout, setInterval: trackTimer(setInterval),
		}), { filename: "plugin/ui.html" });

		await until(() => document.getElementById("status").textContent === "Connected to Pi");
		assert.equal(document.getElementById("target").textContent, "Bridge test / Page");
		assert.match(document.getElementById("session").textContent, /Session [A-Z2-9]{4}-[A-Z2-9]{4}/);
		assert.equal(document.body.className, "connected");
		const inventory = await agent.find(m => m.connections?.length === 1);
		agent.send({ type: "execute", id: "bridge-read", connectionId: inventory.connections[0].connectionId,
			code: "return figma.currentPage.name;", deadline: Date.now() + 5000 });
		const result = await agent.find(m => m.id === "bridge-read");
		assert.equal(result.type, "result", result.message);
		assert.equal(result.text, "Page");
		assert.equal(result.bridgeId, undefined, "UI handshake key must not reach broker results");
	});
}
