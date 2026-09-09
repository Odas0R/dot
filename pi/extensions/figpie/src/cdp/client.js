import { EventEmitter } from "node:events";
import { WebSocket } from "ws";
import { CDP_PORT, MAX_MESSAGE_BYTES } from "../config.js";
import { inspectPort, runningState } from "../desktop/diagnose.js";

export async function listTargets() {
	if (process.platform !== "darwin") throw new Error("Figpie currently supports Figma Desktop on macOS only");
	const endpoint = await inspectPort(await runningState());
	if (endpoint.state !== "ready")
		throw new Error(endpoint.error || `Figma's CDP port ${CDP_PORT} is ${endpoint.state}`);
	return endpoint.targets.filter((target) => /^\/(design|file)\//.test(new URL(target.url).pathname));
}

export class CdpClient extends EventEmitter {
	constructor() {
		super();
		this.contexts = new Map();
		this.pending = new Map();
		this.nextId = 0;
	}
	get closed() {
		return this.socket?.readyState !== WebSocket.OPEN;
	}
	async connect(address) {
		// Never follow a debugger URL to another host or port, even if discovery
		// was local. CDP grants arbitrary execution in the destination process.
		const url = new URL(address);
		if (
			url.protocol !== "ws:" ||
			!["127.0.0.1", "localhost", "[::1]"].includes(url.hostname) ||
			Number(url.port) !== CDP_PORT ||
			url.username ||
			url.password
		) {
			throw new Error("Refusing a non-local CDP debugger URL");
		}
		url.hostname = "127.0.0.1";
		const socket = new WebSocket(url, { maxPayload: MAX_MESSAGE_BYTES + 1024 * 1024, handshakeTimeout: 2500 });
		this.socket = socket;
		socket.on("message", (data) => {
			try {
				const message = JSON.parse(data.toString());
				if (message.method === "Runtime.executionContextCreated")
					this.contexts.set(message.params.context.id, message.params.context);
				if (message.method === "Runtime.executionContextDestroyed") {
					this.contexts.delete(message.params.executionContextId);
					this.emit("context-destroyed", message.params.executionContextId);
				}
				if (message.method === "Runtime.executionContextsCleared") {
					this.contexts.clear();
					this.emit("context-destroyed", null);
				}
				const request = this.pending.get(message.id);
				if (request) {
					this.pending.delete(message.id);
					clearTimeout(request.timer);
					if (message.error) request.reject(new Error(message.error.message));
					else request.resolve(message.result);
				}
			} catch (error) {
				socket.close(1002, "Invalid CDP response");
				this.failPending(error);
			}
		});
		socket.on("error", (error) => {
			this.error = error;
		});
		socket.once("close", () => {
			this.failPending(this.error || new Error("CDP disconnected; execution status is unknown"));
			this.contexts.clear();
			this.emit("close");
		});
		await new Promise((resolve, reject) => {
			socket.once("open", resolve);
			socket.once("error", reject);
			socket.once("close", () => reject(this.error || new Error("CDP closed before connecting")));
		});
		await this.send("Runtime.enable");
	}
	failPending(error) {
		for (const request of this.pending.values()) {
			clearTimeout(request.timer);
			request.reject(error);
		}
		this.pending.clear();
	}
	send(method, params = {}, timeoutMs = 3000) {
		if (this.closed) return Promise.reject(new Error("CDP is disconnected"));
		return new Promise((resolve, reject) => {
			const id = ++this.nextId;
			const timer = timeoutMs
				? setTimeout(() => {
						this.pending.delete(id);
						reject(new Error(`CDP ${method} timed out`));
					}, timeoutMs)
				: undefined;
			this.pending.set(id, { resolve, reject, timer });
			this.socket.send(JSON.stringify({ id, method, params }), (error) => {
				if (!error) return;
				clearTimeout(timer);
				this.pending.delete(id);
				reject(error);
			});
		});
	}
	async evaluate(expression, context, timeoutMs = 3000) {
		if (this.contexts.get(context.id) !== context)
			throw new Error("Figma execution context changed; refresh the target inventory");
		const result = await this.send(
			"Runtime.evaluate",
			{
				expression,
				returnByValue: true,
				awaitPromise: true,
				...(context.uniqueId ? { uniqueContextId: context.uniqueId } : { contextId: context.id }),
			},
			timeoutMs,
		);
		if (result.exceptionDetails) {
			const error = result.exceptionDetails;
			throw new Error(
				error.exception?.description || error.exception?.value || error.text || "Figma evaluation failed",
			);
		}
		return result.result?.value;
	}
	close() {
		this.socket?.terminate();
	}
}
