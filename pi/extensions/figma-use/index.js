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

const HOST = "localhost";
const PORT = Number.parseInt(process.env.PI_FIGMA_USE_PORT || "3846", 10);
const PATH = "/figma-use";
const BROKER_FILE = join(dirname(fileURLToPath(import.meta.url)), "broker.js");
const MAX_PAYLOAD_BYTES = 2 * 1024 * 1024;

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

	const outputDir = join(tmpdir(), "pi-figma-use");
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
export default function figmaUseExtension(pi) {
	const sessionId = randomUUID();
	const pending = new Map();
	let broker;
	let brokerInfo;
	let pluginConnected = false;
	let connectionPromise;
	let stopping = false;

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
		if (message.type === "plugin-status") {
			pluginConnected = message.connected === true;
			brokerInfo = message.pluginInfo;
			return;
		}
		if (typeof message.id !== "string") return;
		const request = pending.get(message.id);
		if (!request) return;
		pending.delete(message.id);
		clearTimeout(request.timer);
		if (message.type === "result") {
			request.resolve(typeof message.text === "string" ? message.text : "undefined");
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
				reject(new Error("Timed out while connecting to the Figma Use broker"));
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
				if (!settled && message.type === "plugin-status") {
					settled = true;
					clearTimeout(timer);
					broker = socket;
					pluginConnected = message.connected === true;
					brokerInfo = message.pluginInfo;
					resolve();
					return;
				}
				handleBrokerMessage(data);
			});
			socket.on("close", () => {
				clearTimeout(timer);
				if (!settled) {
					settled = true;
					reject(new Error("Figma Use broker is not available"));
				}
				if (broker === socket) {
					broker = undefined;
					brokerInfo = undefined;
					pluginConnected = false;
					if (!stopping) rejectPending("Figma Use broker disconnected");
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
			throw lastError || new Error("Could not start the Figma Use broker");
		})().finally(() => {
			connectionPromise = undefined;
		});
		return connectionPromise;
	}

	async function stopClient() {
		stopping = true;
		rejectPending("Figma Use session stopped");
		const socket = broker;
		broker = undefined;
		brokerInfo = undefined;
		pluginConnected = false;
		if (socket?.readyState === WebSocket.OPEN) {
			await new Promise((resolve) => {
				socket.once("close", resolve);
				socket.close(1000, "Pi session stopped");
				setTimeout(resolve, 500);
			});
		}
	}

	async function executeCode(code, timeoutSeconds) {
		await ensureBroker();
		if (!pluginConnected) {
			throw new Error(
				"Figma Use Bridge is not connected. Open Figma Desktop, open the target file, and run the development plugin at pi/extensions/figma-use/plugin/manifest.json.",
			);
		}
		if (Buffer.byteLength(code, "utf8") > MAX_PAYLOAD_BYTES) {
			throw new Error(`Figma JavaScript exceeds the ${MAX_PAYLOAD_BYTES}-byte limit`);
		}

		const id = randomUUID();
		return new Promise((resolve, reject) => {
			const timer = setTimeout(() => {
				pending.delete(id);
				reject(new Error(`Figma JavaScript timed out after ${timeoutSeconds} seconds`));
			}, timeoutSeconds * 1000);
			pending.set(id, { resolve, reject, timer });
			broker.send(JSON.stringify({ type: "execute", id, code }), (error) => {
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
			"Execute arbitrary JavaScript in the currently connected Figma file through the Figma Plugin API. The code runs inside an async function with `figma` in scope, so top-level `await` and `return` are supported. Return JSON-serializable data. This tool can read, create, modify, or delete Figma content and can leave partial changes when code fails.",
		promptSnippet: "Execute Figma Plugin API JavaScript in the connected local Figma file",
		promptGuidelines: [
			"Use figma_use only after loading the figma-use skill for Figma write or scripted inspection tasks.",
			"Keep figma_use calls small, inspect before mutation, and return all created or changed node IDs.",
		],
		parameters: Type.Object({
			code: Type.String({
				description:
					"JavaScript function body. `figma` is in scope. Use top-level await and an explicit return value. Do not wrap the code in an async IIFE.",
			}),
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
				details: { pluginInfo: brokerInfo },
			});

			const timeoutSeconds = params.timeoutSeconds ?? 30;
			let abortHandler;
			const execution = executeCode(params.code, timeoutSeconds);
			const cancelled = new Promise((_, reject) => {
				abortHandler = () => reject(new Error("Figma execution cancelled"));
				signal?.addEventListener("abort", abortHandler, { once: true });
			});
			try {
				const text = await (signal ? Promise.race([execution, cancelled]) : execution);
				const output = await formatOutput(text);
				return {
					content: [{ type: "text", text: output.text }],
					details: { pluginInfo: brokerInfo, outputFile: output.outputFile },
				};
			} finally {
				if (abortHandler) signal?.removeEventListener("abort", abortHandler);
			}
		},
	});

	pi.registerCommand("figma-use-status", {
		description: "Show the shared local Figma Use Bridge status",
		handler: async (_args, ctx) => {
			try {
				await ensureBroker();
				const target = brokerInfo
					? `${brokerInfo.fileName || "unknown file"} / ${brokerInfo.pageName || "unknown page"}`
					: "none";
				ctx.ui.notify(
					[
						`Broker: ${bridgeUrl()}`,
						`Plugin connected: ${pluginConnected ? "yes" : "no"}`,
						`Target: ${target}`,
					].join("\n"),
					pluginConnected ? "info" : "warning",
				);
			} catch (error) {
				ctx.ui.notify(errorMessage(error), "error");
			}
		},
	});

	pi.on("session_start", async (_event, ctx) => {
		try {
			await ensureBroker();
		} catch (error) {
			ctx.ui.notify(`Could not connect to Figma Use broker: ${errorMessage(error)}`, "error");
		}
	});

	pi.on("session_shutdown", async () => {
		await stopClient().catch(() => {});
	});
}
