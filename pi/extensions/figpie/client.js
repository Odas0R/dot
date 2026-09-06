import { randomUUID } from "node:crypto";
import { EventEmitter } from "node:events";
import { setTimeout as delay } from "node:timers/promises";
import { WebSocket } from "ws";
import {
	BRIDGE_URL, PROTOCOL_VERSION, MAX_PAYLOAD_BYTES, MAX_CODE_BYTES, isConnectionId,
	parseMessage, encodeMessage, isRecord, isText, validResult,
} from "./protocol.js";

const UNCERTAIN = "If execution already started, it may continue and changes may remain. Inspect before retrying; restart Figpie in Figma if it stays busy.";
const fatal = (message) => Object.assign(new Error(message), { fatal: true });

export function describeConnection(connection) {
	return `${connection.connectionId} — ${connection.fileName || "unknown file"} / ${connection.pageName || "unknown page"}${connection.blocked ? " [blocked: restart plugin if stuck]" : connection.busy ? " [busy]" : ""} [queued=${connection.queueLength || 0}]`;
}

export class BrokerClient extends EventEmitter {
	constructor({ tokenLoader, launchBroker = () => {}, url = BRIDGE_URL, WebSocketImpl = WebSocket, retryMs = 250, maxRetryMs = 10_000, handshakeMs = 2000 } = {}) {
		super();
		Object.assign(this, { tokenLoader, launchBroker, url, WebSocketImpl, retryMs, maxRetryMs, handshakeMs });
		this.connections = [];
		this.initializingCount = 0;
		this.pending = new Map();
	}
	get connected() { return this.ready && this.socket?.readyState === WebSocket.OPEN; }
	start() {
		if (this.lifecycle) return;
		this.lastError = undefined;
		const lifecycle = new AbortController();
		this.lifecycle = lifecycle;
		this.task = this.loop(lifecycle.signal).catch(error => {
			if (!lifecycle.signal.aborted) {
				error.fatal = true;
				this.lastError = error;
				this.emit("unavailable", error);
			}
		});
	}
	async stop() {
		const lifecycle = this.lifecycle;
		if (!lifecycle) return;
		lifecycle.abort(new Error("Figpie session stopped"));
		this.socket?.terminate(); // Includes sockets whose hello has not completed.
		this.emit("unavailable", lifecycle.signal.reason);
		this.rejectPending(`Figpie session stopped. ${UNCERTAIN}`);
		await this.task;
		this.lifecycle = undefined;
		this.ready = false;
		this.connections = [];
		this.initializingCount = 0;
	}
	rejectPending(reason) {
		for (const request of this.pending.values()) request.reject(new Error(reason));
		this.pending.clear();
	}
	async loop(signal) {
		const token = await this.tokenLoader();
		signal.throwIfAborted();
		let failures = 0;
		let lastLaunch = 0;
		while (!signal.aborted) {
			try {
				await this.connect(token, signal);
				failures = 0;
			} catch (error) {
				if (signal.aborted) break;
				this.lastError = error;
				if (error.fatal) throw error;
				this.emit("status");
				// Launch only when the endpoint refused a connection, not on auth/version errors.
				if (error.code === "ECONNREFUSED" && Date.now() - lastLaunch >= 10_000) {
					lastLaunch = Date.now();
					try { await this.launchBroker(signal); } catch (launchError) { this.lastError = launchError; }
				}
			}
			if (signal.aborted) break;
			const backoff = Math.min(this.maxRetryMs, this.retryMs * 2 ** Math.min(failures++, 10));
			await delay(backoff * (0.8 + Math.random() * 0.4), undefined, { signal });
		}
	}
	connect(token, signal) {
		return new Promise((resolve, reject) => {
			signal.throwIfAborted();
			const socket = new this.WebSocketImpl(this.url, { maxPayload: MAX_PAYLOAD_BYTES });
			this.socket = socket;
			let connected = false;
			let failure;
			const timer = setTimeout(() => { failure = new Error("Figpie hello timed out; check the broker on port 3846"); socket.terminate(); }, this.handshakeMs);
			const abort = () => socket.terminate();
			signal.addEventListener("abort", abort, { once: true });
			socket.once("open", () => {
				if (signal.aborted) { socket.terminate(); return; }
				socket.send(encodeMessage({ type: "hello", version: PROTOCOL_VERSION, role: "agent", token }));
			});
			socket.on("message", data => {
				if (signal.aborted || this.socket !== socket) return;
				try {
					const message = parseMessage(data);
					if (message.type === "protocol-error") throw fatal(isText(message.message) ? message.message : "Figpie protocol rejected");
					if (message.type === "connections-status") {
						if (message.version !== PROTOCOL_VERSION) throw fatal("Incompatible Figpie broker. Stop the old broker on port 3846 and restart Figpie in Figma, then /reload Pi.");
						if (!Array.isArray(message.connections) || !Number.isInteger(message.initializingCount) || message.initializingCount < 0 || !message.connections.every(c => isRecord(c) && isConnectionId(c.connectionId) && ["fileName", "pageName", "fileKey", "editorType"].every(k => c[k] === undefined || isText(c[k])) && typeof c.busy === "boolean" && typeof c.blocked === "boolean" && Number.isInteger(c.queueLength) && c.queueLength >= 0)) throw fatal("Invalid broker connection inventory");
						this.connections = message.connections;
						this.initializingCount = message.initializingCount;
						clearTimeout(timer);
						connected = true;
						this.ready = true;
						this.lastError = undefined;
						this.emit("ready");
						this.emit("status");
						return;
					}
					if (!connected || !validResult(message)) throw fatal("Invalid broker response");
					const request = this.pending.get(message.id);
					if (!request) return;
					this.pending.delete(message.id);
					if (message.type === "error") request.reject(new Error(`${message.message}${message.stack ? `\n${message.stack}` : ""}`));
					else request.resolve(message);
				} catch (error) { failure = error; socket.terminate(); }
			});
			socket.on("error", error => { failure ||= error; });
			socket.once("close", () => {
				clearTimeout(timer);
				signal.removeEventListener("abort", abort);
				if (this.socket === socket) {
					this.socket = undefined;
					this.ready = false;
					this.connections = [];
					this.initializingCount = 0;
					this.rejectPending(`Figpie broker disconnected. ${UNCERTAIN}`);
					this.emit("status");
				}
				if (failure) reject(failure);
				else if (connected) resolve();
				else reject(new Error("Figpie disconnected before its hello completed"));
			});
		});
	}
	waitReady(signal) {
		return new Promise((resolve, reject) => {
			const cleanup = () => { this.off("ready", ready); this.off("unavailable", unavailable); signal.removeEventListener("abort", abort); };
			const ready = () => { cleanup(); resolve(); };
			const unavailable = error => { cleanup(); reject(error); };
			const abort = () => unavailable(signal.reason);
			this.on("ready", ready);
			this.on("unavailable", unavailable);
			signal.addEventListener("abort", abort, { once: true });
			if (signal.aborted) abort();
			else if (this.connected) ready();
			else if (!this.lifecycle || this.lifecycle.signal.aborted) unavailable(new Error("Figpie session is not running"));
			else if (this.lastError?.fatal) unavailable(this.lastError);
		});
	}
	selectConnection(requestedId) {
		if (!this.connections.length) throw new Error(this.initializingCount ? "Figma sessions are still initializing; wait briefly and retry." : "No Figma sessions connected. Run Figpie in Figma and pair it using /figpie-pair.");
		if (requestedId) {
			const match = this.connections.find(c => c.connectionId === requestedId.trim().toUpperCase());
			if (match) return match;
			throw new Error(`Figma session ${requestedId} was not found. Available sessions:\n${this.connections.map(describeConnection).join("\n")}`);
		}
		if (this.connections.length === 1) return this.connections[0];
		throw new Error(`Multiple Figma sessions are connected. Match the requested file/page and retry with connectionId; ask the user only if ambiguous:\n${this.connections.map(describeConnection).join("\n")}`);
	}
	async execute(code, timeoutSeconds = 30, requestedId, signal) {
		if (typeof code !== "string" || !Number.isInteger(timeoutSeconds) || timeoutSeconds < 1 || timeoutSeconds > 120 || (requestedId !== undefined && typeof requestedId !== "string")) throw new Error("Invalid Figpie execution arguments");
		const deadline = Date.now() + timeoutSeconds * 1000;
		const controller = new AbortController();
		const abort = () => controller.abort(new Error(`Figma execution cancelled. ${UNCERTAIN}`));
		const timer = setTimeout(() => controller.abort(new Error(`Figma execution timed out after ${timeoutSeconds} seconds. ${UNCERTAIN}`)), timeoutSeconds * 1000);
		signal?.addEventListener("abort", abort, { once: true });
		if (signal?.aborted) abort();
		let cancel;
		let id;
		try {
			await this.waitReady(controller.signal);
			controller.signal.throwIfAborted();
			const connection = this.selectConnection(requestedId);
			if (connection.blocked) throw new Error(`Figma session is blocked. ${UNCERTAIN}`);
			id = randomUUID();
			const encoded = encodeMessage({ type: "execute", id, code, deadline, connectionId: connection.connectionId }, MAX_CODE_BYTES);
			const socket = this.socket;
			if (socket.bufferedAmount + Buffer.byteLength(encoded) > MAX_PAYLOAD_BYTES) throw new Error("Figpie send buffer is full; wait for pending calls before submitting more work.");
			const result = await new Promise((resolve, reject) => {
				this.pending.set(id, { resolve, reject });
				cancel = () => {
					this.pending.delete(id);
					if (socket.readyState === WebSocket.OPEN) socket.send(encodeMessage({ type: "cancel", id }), () => {});
					reject(controller.signal.reason);
				};
				controller.signal.addEventListener("abort", cancel, { once: true });
				if (controller.signal.aborted) { cancel(); return; }
				socket.send(encoded, error => { if (error) reject(error); });
			});
			return { ...result, connection };
		} finally {
			clearTimeout(timer);
			signal?.removeEventListener("abort", abort);
			if (cancel) controller.signal.removeEventListener("abort", cancel);
			if (id) this.pending.delete(id);
		}
	}
}
