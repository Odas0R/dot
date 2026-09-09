import net from "node:net";
import { randomUUID } from "node:crypto";
import { Channel } from "./ipc.js";
import { clientTrace as trace, errorDetails } from "./log.js";
import {
	SOCKET_PATH,
	APP_PATH,
	CDP_PORT,
	VERSION,
	MAX_CODE_BYTES,
	UNCERTAIN,
	ensureStateDir,
} from "./config.js";

function waitFor(promise, signal) {
	return new Promise((resolve, reject) => {
		const abort = () => reject(signal.reason);
		signal.addEventListener("abort", abort, { once: true });
		if (signal.aborted) abort();
		promise
			.then(resolve, reject)
			.finally(() => signal.removeEventListener("abort", abort));
	});
}

export class BrokerClient {
	constructor() {
		this.pending = new Map();
		this.generation = 0;
		this.stopped = false;
	}
	async openChannel({ allowVersionMismatch = false } = {}) {
		await ensureStateDir({ create: false });
		const channel = new Channel(net.createConnection(SOCKET_PATH));

		const hello = await new Promise((resolve, reject) => {
			const timer = setTimeout(() => {
				channel.close();
				reject(new Error("Figpie broker handshake timed out"));
			}, 2000);
			const cleanup = () => {
				clearTimeout(timer);
				channel.off("message", received);
				channel.off("close", failed);
			};
			const failed = (error) => {
				cleanup();
				reject(Object.assign(error, { code: error.code || "ECONNRESET" }));
			};
			const received = (message) => {
				cleanup();
				resolve(message);
			};
			channel.once("message", received);
			channel.once("close", failed);
		});
		if (hello.type !== "hello") {
			channel.close();
			throw new Error("Unexpected Figpie broker handshake");
		}
		if (hello.cdpPort !== CDP_PORT || hello.appPath !== APP_PATH) {
			channel.close();
			throw new Error(
				`Figpie broker configuration differs: expected ${APP_PATH} on port ${CDP_PORT}, received ${hello.appPath} on port ${hello.cdpPort}. Align PI_FIGPIE_APP_PATH and PI_FIGPIE_CDP_PORT across Pi sessions before connecting. No app operation was sent.`,
			);
		}
		if (hello.version !== VERSION && !allowVersionMismatch) {
			channel.close();
			throw new Error(
				`Figpie broker protocol ${hello.version} differs from ${VERSION}. Run /figpie-connect to replace it only when idle. Restart Pi completely after source updates; /reload may retain cached modules.`,
			);
		}
		channel.broker = hello;
		return channel;
	}
	async retireBroker(channel, pid) {
		// Only the broker can atomically decide whether all clients' work is idle.
		// Only explicit connect/restore commands may call this primitive.
		await new Promise((resolve, reject) => {
			const id = randomUUID();
			const timer = setTimeout(
				() =>
					finish(
						new Error(
							`Figpie broker ${pid} did not retire; wait for its work to finish.`,
						),
					),
				3000,
			);
			const closed = () => finish();
			const received = (message) => {
				if (message.id === id && message.type === "error")
					finish(new Error(message.message));
			};
			function finish(error) {
				clearTimeout(timer);
				channel.off("message", received);
				channel.off("close", closed);
				if (error) {
					channel.close();
					reject(error);
				} else resolve();
			}
			channel.on("message", received);
			channel.once("close", closed);
			try {
				channel.send({ type: "retire", id });
			} catch (error) {
				finish(error);
			}
		});
	}
	connect() {
		if (this.stopped) return Promise.reject(new Error("Figpie session stopped"));
		if (this.channel && !this.channel.closed)
			return Promise.resolve(this.channel);

		if (this.connecting) return this.connecting;

		const generation = this.generation;

		const task = (async () => {
			let channel;
			try {
				channel = await this.openChannel();
			} catch (error) {
				throw new Error(`Figpie broker is unavailable. Run /figpie-connect. ${error.message}`, { cause: error });
			}

			if (generation !== this.generation) {
				channel.close();
				throw new Error("Figpie session stopped");
			}

			this.channel = channel;

			trace.write("connection.open", {
				socketPath: SOCKET_PATH,
				brokerPid: channel.broker.pid,
				version: channel.broker.version,
				appPath: channel.broker.appPath,
				cdpPort: channel.broker.cdpPort,
			});

			channel.on("message", (message) => {
				const request = this.pending.get(message.id);
				if (!request || request.channel !== channel) return;
				if (message.type === "error") {
					const error = new Error(message.message);
					if (message.stack) error.stack = `${error.stack}\nBroker stack:\n${message.stack}`;
					request.reject(error);
				} else if (message.type === "result") request.resolve(message);
				else request.reject(new Error("Invalid Figpie broker response"));
			});

			channel.once("close", (error) => {
				trace.write("connection.close", { error: errorDetails(error) });
				if (this.channel === channel) this.channel = null;
				for (const request of this.pending.values())
					if (request.channel === channel)
						request.reject(new Error(`${error.message}. ${UNCERTAIN}`));
			});

			return channel;
		})();

		this.connecting = task;

		void task
			.finally(() => {
				if (this.connecting === task) this.connecting = null;
			})
			.catch(() => {});

		return task;
	}
	async request(type, payload, timeoutMs, signal) {
		if (this.stopped) throw new Error("Figpie session stopped");
		const id = randomUUID();
		const deadline = Date.now() + timeoutMs;
		const controller = new AbortController();
		const abort = () =>
			controller.abort(
				new Error(
					type === "setup"
						? "Desktop operation cancelled; it may continue. Run /figpie-status before retrying."
						: `Figpie request cancelled. ${UNCERTAIN}`,
				),
			);
		const timer = setTimeout(
			() =>
				controller.abort(
					new Error(
						type === "setup"
							? "Desktop operation timed out; it may continue. Run /figpie-status before retrying."
							: `Figpie request timed out. ${UNCERTAIN}`,
					),
				),
			timeoutMs,
		);
		signal?.addEventListener("abort", abort, { once: true });
		if (signal?.aborted) abort();
		let cancel;
		const started = Date.now();
		trace.write("request.submitted", {
			requestId: id,
			type,
			...payload,
			deadline,
		});
		try {
			const channel = await waitFor(this.connect(), controller.signal);

			controller.signal.throwIfAborted();

			const result = await new Promise((resolve, reject) => {
				this.pending.set(id, { channel, resolve, reject });
				cancel = () => {
					try {
						channel.send({ type: "cancel", id });
					} catch {}
					reject(controller.signal.reason);
				};
				controller.signal.addEventListener("abort", cancel, { once: true });
				if (controller.signal.aborted) {
					cancel();
					return;
				}
				// Requests are never replayed after sending, including disconnects.
				channel.send({ type, id, ...payload, deadline });
			});

			trace.write("request.result", {
				requestId: id,
				durationMs: Date.now() - started,
				connection: result.connection,
				text: result.text,
				data: result.data,
				images: result.images?.map(({ name, mimeType }) => ({
					name,
					mimeType,
				})),
			});

			return { ...result, requestId: id, traceFile: trace.file };
		} catch (error) {
			trace.write("request.error", {
				requestId: id,
				durationMs: Date.now() - started,
				error: errorDetails(error),
			});
			throw new Error(
				`${error.message}\nFigpie trace: ${trace.file} (request ${id})`,
				{ cause: error },
			);
		} finally {
			clearTimeout(timer);
			signal?.removeEventListener("abort", abort);
			if (cancel) controller.signal.removeEventListener("abort", cancel);
			this.pending.delete(id);
		}
	}
	execute(code, timeoutSeconds = 30, connectionId, signal, toolCallId) {
		if (
			typeof code !== "string" ||
			Buffer.byteLength(code) > MAX_CODE_BYTES ||
			!Number.isInteger(timeoutSeconds) ||
			timeoutSeconds < 1 ||
			timeoutSeconds > 120
		)
			throw new Error("Invalid Figpie execution arguments");
		return this.request(
			"execute",
			{ code, connectionId, toolCallId },
			timeoutSeconds * 1000,
			signal,
		);
	}
	async setup(action, { signal, allowPatch = false } = {}) {
		return (
			await this.request("setup", { action, allowPatch }, 180_000, signal)
		).data;
	}
	async stop() {
		if (this.stopped) return;
		this.stopped = true;
		this.generation++;
		for (const request of this.pending.values())
			request.reject(new Error(`Figpie session stopped. ${UNCERTAIN}`));
		this.channel?.close();
		this.channel = null;
		await this.connecting?.catch(() => {});
	}
}
