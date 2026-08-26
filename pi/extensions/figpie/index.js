import { randomUUID } from "node:crypto";
import { spawn } from "node:child_process";
import { mkdir, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import {
	DEFAULT_MAX_BYTES,
	DEFAULT_MAX_LINES,
	formatSize,
	truncateHead,
} from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { WebSocket } from "ws";

const HOST = "127.0.0.1";
const PORT = Number.parseInt(
	process.env.PI_FIGPIE_PORT || process.env.PI_FIGMA_USE_PORT || "3846",
	10,
);
const PATH = "/figma-use";
const BROKER_FILE = join(dirname(fileURLToPath(import.meta.url)), "broker.js");
const MAX_PAYLOAD_BYTES = 20 * 1024 * 1024;

function errorMessage(error) {
	return error instanceof Error ? error.message : String(error);
}

function bridgeUrl() {
	return `ws://${HOST}:${PORT}${PATH}`;
}

function parseMessage(data) {
	const text = typeof data === "string" ? data : data.toString("utf8");
	return JSON.parse(text);
}

function delay(milliseconds) {
	return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

async function formatOutput(text) {
	const truncation = truncateHead(text, {
		maxBytes: DEFAULT_MAX_BYTES,
		maxLines: DEFAULT_MAX_LINES,
	});
	if (!truncation.truncated) return { text, outputFile: undefined };

	const outputDir = join(tmpdir(), "pi-figpie");
	await mkdir(outputDir, { recursive: true });
	const outputFile = join(outputDir, `${randomUUID()}.txt`);
	await writeFile(outputFile, text, "utf8");
	const notice =
		`[Output truncated: ${truncation.outputLines} of ${truncation.totalLines} lines ` +
		`(${formatSize(truncation.outputBytes)} of ${formatSize(truncation.totalBytes)}). ` +
		`Full output saved to: ${outputFile}]`;
	return {
		text: truncation.content ? `${truncation.content}\n\n${notice}` : notice,
		outputFile,
	};
}

/** @param {import("@earendil-works/pi-coding-agent").ExtensionAPI} pi */
export default function figpieExtension(pi) {
	const sessionId = randomUUID();
	const pending = new Map();
	let broker;
	let hostBroker;
	let connections = [];
	let initializingCount = 0;
	let connectionPromise;
	let hostConnectionPromise;
	let reconnectTimer;
	let hostReconnectTimer;
	let stopping = false;
	let hostStopping = false;

	function rejectPending(reason) {
		for (const request of pending.values()) {
			clearTimeout(request.timer);
			request.reject(new Error(reason));
		}
		pending.clear();
	}

	function handleBrokerMessage(data) {
		let message;
		try {
			message = parseMessage(data);
		} catch {
			return;
		}
		if (message.type === "connections-status") {
			connections = Array.isArray(message.connections) ? message.connections : [];
			initializingCount = Number.isInteger(message.initializingCount)
				? message.initializingCount
				: 0;
			return;
		}
		if (typeof message.id !== "string") return;
		const request = pending.get(message.id);
		if (!request) return;
		pending.delete(message.id);
		clearTimeout(request.timer);
		if (message.type === "result") {
			request.resolve({
				text: typeof message.text === "string" ? message.text : "undefined",
				images: Array.isArray(message.images)
					? message.images.filter((image) =>
						typeof image?.data === "string" && typeof image?.mimeType === "string")
					: [],
				connection: request.connection,
			});
		} else if (message.type === "error") {
			const stack = typeof message.stack === "string" ? `\n${message.stack}` : "";
			request.reject(new Error(`${message.message || "Figma execution failed"}${stack}`));
		}
	}

	function connectOnce(timeoutMilliseconds = 1000) {
		return new Promise((resolve, reject) => {
			const socket = new WebSocket(bridgeUrl(), { maxPayload: MAX_PAYLOAD_BYTES });
			let settled = false;
			const timer = setTimeout(() => {
				if (settled) return;
				settled = true;
				socket.close();
				reject(new Error("Timed out while connecting to the Figpie broker"));
			}, timeoutMilliseconds);

			socket.once("open", () => {
				socket.send(JSON.stringify({ type: "hello", role: "agent", sessionId }));
			});
			socket.on("message", (data) => {
				let message;
				try {
					message = parseMessage(data);
				} catch {
					return;
				}
				if (!settled && message.type === "connections-status") {
					settled = true;
					clearTimeout(timer);
					broker = socket;
					connections = Array.isArray(message.connections) ? message.connections : [];
					initializingCount = Number.isInteger(message.initializingCount)
						? message.initializingCount
						: 0;
					resolve();
					return;
				}
				handleBrokerMessage(data);
			});
			socket.on("close", () => {
				clearTimeout(timer);
				if (!settled) {
					settled = true;
					reject(new Error("Figpie broker is not available"));
				}
				if (broker === socket) {
					broker = undefined;
					connections = [];
					initializingCount = 0;
					if (!stopping) {
						rejectPending("Figpie broker disconnected");
						clearTimeout(reconnectTimer);
						reconnectTimer = setTimeout(() => ensureBroker().catch(() => {}), 250);
					}
				}
			});
			socket.on("error", () => {});
		});
	}

	function launchBroker() {
		const child = spawn(process.execPath, [BROKER_FILE], {
			detached: true,
			stdio: "ignore",
			env: process.env,
		});
		child.unref();
	}

	function connectHostOnce(timeoutMilliseconds = 1000) {
		return new Promise((resolve, reject) => {
			const socket = new WebSocket(bridgeUrl(), { maxPayload: MAX_PAYLOAD_BYTES });
			let settled = false;
			const timer = setTimeout(() => {
				if (settled) return;
				settled = true;
				socket.close();
				reject(new Error("Timed out while hosting the Figpie broker"));
			}, timeoutMilliseconds);

			socket.once("open", () => {
				socket.send(JSON.stringify({ type: "hello", role: "host", sessionId }));
			});
			socket.on("message", (data) => {
				let message;
				try {
					message = parseMessage(data);
				} catch {
					return;
				}
				if (!settled && message.type === "host-status") {
					settled = true;
					clearTimeout(timer);
					hostBroker = socket;
					resolve();
				}
			});
			socket.on("close", () => {
				clearTimeout(timer);
				if (!settled) {
					settled = true;
					reject(new Error("Figpie broker host is not available"));
				}
				if (hostBroker === socket) {
					hostBroker = undefined;
					if (!hostStopping) {
						clearTimeout(hostReconnectTimer);
						hostReconnectTimer = setTimeout(() => ensureHostBroker().catch(() => {}), 250);
					}
				}
			});
			socket.on("error", () => {});
		});
	}

	async function ensureHostBroker() {
		if (hostBroker?.readyState === WebSocket.OPEN) return;
		if (hostConnectionPromise) return hostConnectionPromise;
		hostConnectionPromise = (async () => {
			try {
				await connectHostOnce(300);
				return;
			} catch {
				launchBroker();
			}
			let lastError;
			for (let attempt = 0; attempt < 30; attempt += 1) {
				await delay(100);
				try {
					await connectHostOnce(500);
					return;
				} catch (error) {
					lastError = error;
				}
			}
			throw lastError || new Error("Could not host the Figpie broker");
		})().finally(() => {
			hostConnectionPromise = undefined;
		});
		return hostConnectionPromise;
	}

	async function ensureBroker() {
		if (broker?.readyState === WebSocket.OPEN) return;
		if (connectionPromise) return connectionPromise;
		connectionPromise = (async () => {
			try {
				await connectOnce(300);
				return;
			} catch {
				launchBroker();
			}
			let lastError;
			for (let attempt = 0; attempt < 30; attempt += 1) {
				await delay(100);
				try {
					await connectOnce(500);
					return;
				} catch (error) {
					lastError = error;
				}
			}
			throw lastError || new Error("Could not start the Figpie broker");
		})().finally(() => {
			connectionPromise = undefined;
		});
		return connectionPromise;
	}

	async function closeClient() {
		stopping = true;
		clearTimeout(reconnectTimer);
		rejectPending("The Figpie client stopped");
		const socket = broker;
		broker = undefined;
		connections = [];
		initializingCount = 0;
		if (socket?.readyState === WebSocket.OPEN) {
			await new Promise((resolve) => {
				socket.once("close", resolve);
				socket.close(1000, "Pi session stopped");
				setTimeout(resolve, 500);
			});
		}
	}

	function describeConnection(connection) {
		const fileKey = connection.fileKey ? ` [fileKey=${connection.fileKey}]` : "";
		return `${connection.connectionId} — ${connection.fileName || "unknown file"} / ${connection.pageName || "unknown page"}${fileKey}`;
	}

	function assertFigmaSessionAvailable() {
		if (connections.length > 0) return;
		if (initializingCount > 0) {
			throw new Error(
				`${initializingCount} Figma plugin session${initializingCount === 1 ? " is" : "s are"} connected but still initializing. Wait briefly, then retry. Restart Figpie in Figma if this continues.`,
			);
		}
		throw new Error(
			"No Figma plugin sessions are connected. Run Figpie in the target Figma file.",
		);
	}

	function selectConnection(requestedId) {
		assertFigmaSessionAvailable();
		if (requestedId) {
			const normalized = requestedId.trim().toUpperCase();
			const match = connections.find((connection) => connection.connectionId === normalized);
			if (match) return match;
			throw new Error(
				`Figma session ${requestedId} was not found. Available sessions:\n${connections.map(describeConnection).join("\n")}`,
			);
		}
		if (connections.length === 1) return connections[0];
		throw new Error(
			[
				"Multiple Figma sessions are connected.",
				"Match the requested file or page to this list, then retry with connectionId. Ask the user only if the target is ambiguous:",
				...connections.map(describeConnection),
			].join("\n"),
		);
	}

	async function executeCode(code, timeoutSeconds, requestedConnectionId) {
		await ensureBroker();
		const connection = selectConnection(requestedConnectionId);
		if (Buffer.byteLength(code, "utf8") > MAX_PAYLOAD_BYTES) {
			throw new Error(`Figma JavaScript exceeds the ${MAX_PAYLOAD_BYTES}-byte limit`);
		}

		const id = randomUUID();
		return new Promise((resolve, reject) => {
			const timer = setTimeout(() => {
				pending.delete(id);
				reject(new Error(`Figma JavaScript timed out after ${timeoutSeconds} seconds`));
			}, timeoutSeconds * 1000);
			pending.set(id, { resolve, reject, timer, connection });
			broker.send(JSON.stringify({ type: "execute", id, code, connectionId: connection.connectionId }), (error) => {
				if (!error) return;
				pending.delete(id);
				clearTimeout(timer);
				reject(error);
			});
		});
	}

	pi.registerTool({
		name: "figma_use",
		label: "Execute Figma JavaScript",
		description:
			"Execute arbitrary JavaScript in a connected Figma session through the Figma Plugin API. Figpie connects automatically. If more than one session is connected, discover the available connection IDs from the ambiguity error, match the user's requested file or page, and retry with connectionId. Ask the user only when the target remains ambiguous. The code runs inside an async function with `figma` in scope, so top-level `await` and `return` are supported. Enhanced helpers include figma.createAutoLayout(), node.query(), node.matches(), node.set(), and node.screenshot(). Return JSON-serializable data. This tool can read, create, modify, or delete Figma content and can leave partial changes when code fails.",
		promptSnippet: "Execute Figma Plugin API JavaScript in the connected local Figma file",
		promptGuidelines: [
			"Use figma_use only after loading the figma-use skill for Figma write or scripted inspection tasks.",
			"When multiple Figma sessions exist, self-discover their IDs, select by the file or page named by the user, and ask only if the match is ambiguous.",
			"Keep figma_use calls small, inspect before mutation, and return all created or changed node IDs.",
		],
		parameters: Type.Object({
			code: Type.String({
				description:
					"JavaScript function body. `figma` is in scope. Use top-level await and an explicit return value. Do not wrap the code in an async IIFE.",
			}),
			connectionId: Type.Optional(
				Type.String({
					description: "Target Figma session ID, such as K7M4-P2. Omit when only one session is connected.",
				}),
			),
			timeoutSeconds: Type.Optional(
				Type.Integer({
					description: "Execution timeout in seconds, including time spent waiting behind other Pi sessions",
					minimum: 1,
					maximum: 120,
					default: 30,
				}),
			),
		}),
		async execute(_toolCallId, params, signal, onUpdate) {
			if (signal?.aborted) throw new Error("Figma execution cancelled");
			onUpdate?.({
				content: [{ type: "text", text: "Waiting to execute JavaScript in Figma..." }],
				details: { connections },
			});

			const timeoutSeconds = params.timeoutSeconds ?? 30;
			let abortHandler;
			const execution = executeCode(params.code, timeoutSeconds, params.connectionId);
			const cancelled = new Promise((_, reject) => {
				abortHandler = () => reject(new Error("Figma execution cancelled"));
				signal?.addEventListener("abort", abortHandler, { once: true });
			});
			try {
				const result = await (signal ? Promise.race([execution, cancelled]) : execution);
				const output = await formatOutput(result.text);
				return {
					content: [
						{ type: "text", text: output.text },
						...result.images.map((image) => ({
							type: "image",
							data: image.data,
							mimeType: image.mimeType,
						})),
					],
					details: {
						connection: result.connection,
						outputFile: output.outputFile,
						imageNames: result.images.map((image) => image.name).filter(Boolean),
					},
				};
			} finally {
				if (abortHandler) signal?.removeEventListener("abort", abortHandler);
			}
		},
	});

	pi.registerCommand("figpie-status", {
		description: "Show this Pi session's Figpie status",
		handler: async (_args, ctx) => {
			ctx.ui.notify(
				[
					`Figpie connected: ${broker?.readyState === WebSocket.OPEN ? "yes" : "no"}`,
					`Broker: ${bridgeUrl()}`,
					`Ready Figma sessions: ${connections.length}`,
					`Initializing Figma sessions: ${initializingCount}`,
					...connections.map(describeConnection),
				].join("\n"),
				broker?.readyState === WebSocket.OPEN ? "info" : "warning",
			);
		},
	});

	pi.on("session_start", async (_event, ctx) => {
		hostStopping = false;
		stopping = false;
		try {
			await ensureHostBroker();
			await ensureBroker();
			assertFigmaSessionAvailable();
		} catch (error) {
			ctx.ui.notify(`Could not connect to Figpie: ${errorMessage(error)}`, "error");
		}
	});

	pi.on("session_shutdown", async () => {
		hostStopping = true;
		clearTimeout(hostReconnectTimer);
		await closeClient().catch(() => {});
		const socket = hostBroker;
		hostBroker = undefined;
		if (socket?.readyState === WebSocket.OPEN) socket.close(1000, "Pi host session stopped");
	});
}
