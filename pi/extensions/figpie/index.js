import { spawn } from "node:child_process";
import { open } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { Type } from "typebox";
import { ensureToken, STATE_DIR, TOKEN_FILE } from "./auth.js";
import { BRIDGE_URL, validatePortEnvironment } from "./protocol.js";
import { BrokerClient, describeConnection } from "./client.js";
import { formatOutput, MAX_INLINE_BYTES, MAX_INLINE_LINES, MAX_INLINE_NODE_IDS } from "./output.js";

const BROKER_FILE = join(dirname(fileURLToPath(import.meta.url)), "broker.js");
const LOG_FILE = join(STATE_DIR, "broker.log");

async function launchBroker(signal) {
	signal.throwIfAborted();
	const log = await open(LOG_FILE, "a", 0o600);
	try {
		signal.throwIfAborted();
		const child = spawn(process.execPath, [BROKER_FILE], { detached: true, stdio: ["ignore", log.fd, log.fd], env: process.env });
		await new Promise((resolve, reject) => { child.once("spawn", resolve); child.once("error", reject); });
		child.unref();
	} finally { await log.close(); }
}

/** @param {import("@earendil-works/pi-coding-agent").ExtensionAPI} pi */
export default function figpieExtension(pi) {
	const client = new BrokerClient({ tokenLoader: async () => { validatePortEnvironment(); return ensureToken(); }, launchBroker });
	pi.registerTool({
		name: "figma_use",
		label: "Execute Figma JavaScript",
		description: `Execute Figma Plugin API JavaScript in a paired local session. Code is an async function body with figma in scope: use top-level await and return, not an IIFE. Helpers: figma.createAutoLayout(), node.query(), node.matches(), node.set(), node.screenshot(). Multiple sessions produce an inventory error; match the file/page and retry with connectionId. Batch coherent inspect/build/validate/correct stages; same-session calls are sequential. Failures and cancellation may leave changes or running work: inspect before retrying. Return compact summaries with rootId, refs, issues and complete createdNodeIds/mutatedNodeIds arrays. More than ${MAX_INLINE_NODE_IDS} IDs are saved locally with counts/summary inline. Text is capped at ${MAX_INLINE_BYTES / 1024} KiB/${MAX_INLINE_LINES} lines with full received output saved when abbreviated.`,
		promptSnippet: "Execute Figma Plugin API JavaScript in the paired local Figma file",
		promptGuidelines: [
			"For figma_use, load the figma-use skill once per agent session; reuse it across calls. Reload after a skill/runtime update or loss of the guidance from context. Load specialized references only as needed.",
			"When figma_use finds multiple sessions, match the requested file/page to the inventory and specify connectionId; ask only if ambiguous.",
			"Batch figma_use by coherent stages: inspect → build → validate → correct. Preflight lookups/fonts before mutation; use loops for repeated elements instead of a fixed node-count limit. Validate stage boundaries and inspect partial changes before retries.",
			"Return concise figma_use summaries, named references, issues, and complete affected-ID arrays; large lists are preserved in a local artifact. Read only needed fields from that artifact, not the entire result by default.",
		],
		parameters: Type.Object({
			code: Type.String({ description: "JavaScript async function body. figma is in scope. Use top-level await and an explicit return; no IIFE." }),
			connectionId: Type.Optional(Type.String({ description: "Target session ID, such as K7M4-P2Q8. Omit when only one session exists." })),
			timeoutSeconds: Type.Optional(Type.Integer({ description: "Deadline in seconds, including connection, queue, and execution time", minimum: 1, maximum: 120, default: 30 })),
		}),
		async execute(_toolCallId, params, signal, onUpdate) {
			signal?.throwIfAborted();
			onUpdate?.({ content: [{ type: "text", text: "Waiting to execute JavaScript in Figma..." }], details: { connections: client.connections } });
			let result;
			try { result = await client.execute(params.code, params.timeoutSeconds ?? 30, params.connectionId, signal); }
			catch (error) {
				if (signal?.aborted || error?.name === "AbortError") throw error;
				const output = await formatOutput(error instanceof Error ? error.message : String(error));
				if (!output.abbreviated) throw error;
				throw new Error(output.text);
			}
			const output = await formatOutput(result.text);
			return {
				content: [{ type: "text", text: output.text }, ...result.images.map(image => ({ type: "image", data: image.data, mimeType: image.mimeType }))],
				details: { connection: result.connection, outputFile: output.outputFile, abbreviated: output.abbreviated, nodeIdCounts: output.nodeIdCounts, imageNames: result.images.map(image => image.name).filter(Boolean) },
			};
		},
	});
	pi.registerCommand("figpie-status", {
		description: "Show broker, Figma sessions, and recovery status",
		handler: async (_args, ctx) => {
			if (!ctx.hasUI) return;
			ctx.ui.notify([
				`Figpie connected: ${client.connected ? "yes" : "no"}`,
				`Broker: ${BRIDGE_URL}`,
				`Initializing sessions: ${client.initializingCount}`,
				...client.connections.map(describeConnection),
				...(client.lastError ? [`Last error: ${client.lastError.message}`] : []),
				`Broker log: ${LOG_FILE}`,
			].join("\n"), client.connected ? "info" : "warning");
		},
	});
	pi.registerCommand("figpie-pair", {
		description: "Show the private pairing token to paste into the Figma plugin",
		handler: async (_args, ctx) => {
			if (!ctx.hasUI) throw new Error(`Pair interactively, or read your private token at ${TOKEN_FILE} outside the agent conversation.`);
			const token = await ensureToken();
			// A UI-only dialog keeps the credential out of tool results and model context.
			await ctx.ui.select(`Paste this token into Figpie in Figma (keep it private):\n${token}`, ["Done"]);
		},
	});
	let unavailable;
	pi.on("session_start", (_event, ctx) => {
		unavailable = error => { if (ctx.hasUI) ctx.ui.notify(`Figpie: ${error.message}. See /figpie-status.`, "error"); };
		client.on("unavailable", unavailable);
		client.start(); // Background connection attempts do not block Pi startup.
	});
	pi.on("session_shutdown", async () => {
		if (unavailable) client.off("unavailable", unavailable);
		await client.stop();
	});
}
