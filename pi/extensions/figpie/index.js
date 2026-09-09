import { Type } from "typebox";
import { BROKER_LOG_FILE, brokerManager } from "./src/broker-manager.js";
import { BrokerClient } from "./src/client.js";
import { SOCKET_PATH, CDP_PORT } from "./src/config.js";
import { clientTrace, LOG_DIR, errorDetails } from "./src/log.js";
import { formatOutput, MAX_INLINE_BYTES, MAX_INLINE_LINES, MAX_INLINE_NODE_IDS } from "./src/output.js";

const DETAILS_HINT = "Details: /figpie-status --verbose";

const brief = (value) =>
	String(value || "Unknown error")
		.split("\n")[0]
		.replace(/^Error:\s*/, "")
		.slice(0, 240);

async function withFormattedErrors(operation, signal) {
	try {
		return await operation();
	} catch (error) {
		if (signal?.aborted || error?.name === "AbortError") throw error;
		const output = await formatOutput(error instanceof Error ? error.message : String(error));
		if (!output.abbreviated) throw error;
		throw new Error(output.text);
	}
}

function summarize(action, { desktop = {}, connections = [], issues = [] }) {
	if (action === "restore" && desktop.ok)
		return {
			text: desktop.changed ? "Original Figma app restored." : "Figma is already original; nothing changed.",
			level: "info",
		};
	if (desktop.rollback?.ok)
		return { text: `Figma failed to connect; the original app was restored.\n${DETAILS_HINT}`, level: "warning" };
	if (desktop.recoveryRequired || (desktop.rollback && !desktop.rollback.ok))
		return {
			text: `Figma recovery needs attention. Do not launch or patch it again yet.\n${DETAILS_HINT}`,
			level: "error",
		};
	if (desktop.restartRequired)
		return {
			text: `Save your work and quit Figma, then run /figpie-${action === "restore" ? "restore" : "connect"}.`,
			level: "warning",
		};
	if (desktop.status === "busy")
		return { text: "Another Figpie desktop operation is running. Please wait.", level: "info" };
	if (desktop.ok === false && desktop.status !== "cdp-not-ready")
		return {
			text: `${brief(desktop.error || desktop.issues?.[0] || desktop.guidance || desktop.status)}\n${DETAILS_HINT}`,
			level: "warning",
		};

	// A launched app is not necessarily a usable scripting connection. Conversely,
	// a late successful discovery supersedes an earlier startup probe timeout.
	const connected = connections.length > 0;
	const blocked = connections.filter((connection) => connection.blocked).length;
	const warning = !connected || blocked > 0 || issues.length > 0;
	let text;
	if (action === "status") {
		text = [
			`Figma: ${desktop.running?.running ? "running" : desktop.running?.known ? "stopped" : "unknown"} · ${desktop.app?.patch?.state || "unknown patch state"}`,
			`CDP: 127.0.0.1:${CDP_PORT} · ${desktop.port?.state || "unknown"}`,
			`Figpie: ${connected ? `${connections.length} file${connections.length === 1 ? "" : "s"} connected` : "no scripting connection"}${blocked ? ` · ${blocked} blocked` : ""}`,
		].join("\n");
	} else {
		text = connected
			? `Connected to Figma on 127.0.0.1:${CDP_PORT}.${blocked ? ` ${blocked} target(s) are blocked.` : ""}`
			: `Figma ${desktop.running?.running ? "is running, but its scripting connection isn't ready" : "is not connected"}.`;
	}
	if (issues.length && connected) text += "\nSome Figma windows are unavailable.";
	return { text: warning ? `${text}\n${DETAILS_HINT}` : text, level: warning ? "warning" : "info" };
}

/** @param {import("@earendil-works/pi-coding-agent").ExtensionAPI} pi */
export default function figpieExtension(pi) {
	// Socket communication is lazy; only connect/restore may start a broker.
	const client = new BrokerClient();
	pi.registerTool({
		name: "figma_use",
		label: "Execute Figma JavaScript",
		description: `Execute Figma Plugin API JavaScript in a local Figma Desktop target via CDP. Code is an async function body with figma in scope: use top-level await and return, not an IIFE. Helpers: figma.createAutoLayout(), node.query(), node.matches(), node.set(), node.screenshot(). Multiple targets produce an inventory error; match the file/page and retry with connectionId. Batch coherent inspect/build/validate/correct stages; same-target calls are sequential. Failures and cancellation may leave changes or running work: inspect before retrying, never replay mutations after a timeout or disconnect. For connection failures, ask the user to run /figpie-connect or /figpie-status; desktop setup is user-controlled. Return compact summaries with rootId, refs, issues and complete createdNodeIds/mutatedNodeIds arrays. More than ${MAX_INLINE_NODE_IDS} IDs are saved locally with counts/summary inline. Text is capped at ${MAX_INLINE_BYTES / 1024} KiB/${MAX_INLINE_LINES} lines with full received output saved when abbreviated.`,
		promptSnippet: "Execute Figma Plugin API JavaScript in a local Figma Desktop CDP target",
		promptGuidelines: [
			"For figma_use, load the figma-use skill once per agent session; reuse it across calls. Reload after a skill/runtime update or loss of the guidance from context. Load specialized references only as needed.",
			"When figma_use finds multiple targets, match the requested file/page to the inventory and specify connectionId; ask only if ambiguous.",
			"For connection failures, ask the user to run /figpie-connect or /figpie-status. Do not patch, launch, or restore Figma through tools; desktop management belongs to user-invoked commands.",
			"Batch figma_use by coherent stages: inspect → build → validate → correct. Preflight lookups/fonts before mutation; use loops for repeated elements instead of a fixed node-count limit. Validate stage boundaries and inspect partial changes before retries.",
			"Return concise figma_use summaries, named references, issues, and complete affected-ID arrays; large lists are preserved in a local artifact. Read only needed fields from that artifact, not the entire result by default.",
		],
		parameters: Type.Object({
			code: Type.String({
				description:
					"JavaScript async function body. figma is in scope. Use top-level await and an explicit return; no IIFE.",
			}),
			connectionId: Type.Optional(
				Type.String({
					description: "Local Figma CDP target ID from the connection inventory. Omit when only one target exists.",
				}),
			),
			timeoutSeconds: Type.Optional(
				Type.Integer({
					description: "Deadline in seconds, including connection, queue, and execution time",
					minimum: 1,
					maximum: 120,
					default: 30,
				}),
			),
		}),
		async execute(toolCallId, params, signal, onUpdate) {
			signal?.throwIfAborted();
			onUpdate?.({ content: [{ type: "text", text: "Waiting to execute JavaScript in Figma..." }], details: {} });
			const result = await withFormattedErrors(
				() => client.execute(params.code, params.timeoutSeconds ?? 30, params.connectionId, signal, toolCallId),
				signal,
			);
			const output = await formatOutput(result.text);
			return {
				content: [
					{ type: "text", text: output.text },
					...result.images.map((image) => ({ type: "image", data: image.data, mimeType: image.mimeType })),
				],
				details: {
					connection: result.connection,
					requestId: result.requestId,
					traceFile: result.traceFile,
					outputFile: output.outputFile,
					abbreviated: output.abbreviated,
					nodeIdCounts: output.nodeIdCounts,
					imageNames: result.images.map((image) => image.name).filter(Boolean),
				},
			};
		},
	});

	async function notifyCommandError(ctx, action, error, verbose = false) {
		clientTrace.write("command.error", { action, error: errorDetails(error) });
		const message = error instanceof Error ? error.message : String(error);
		try {
			ctx.ui.notify(verbose ? (await formatOutput(message)).text : `${brief(message)}\n${DETAILS_HINT}`, "error");
		} catch {
			ctx.ui.notify(`Figpie command failed. See ${clientTrace.file}`, "error");
		}
	}

	pi.registerCommand("figpie-connect", {
		description: "Connect to Figma: diagnose, patch if needed, launch, and verify",
		handler: async (args, ctx) => {
			if (!ctx.hasUI) throw new Error("Figpie commands require an interactive Pi session.");
			if (args.trim()) {
				ctx.ui.notify("Usage: /figpie-connect", "warning");
				return;
			}
			try {
				await ctx.waitForIdle();
				ctx.ui.notify("Connecting to Figma…", "info");
				await brokerManager.ensureRunning();
				let result = await client.setup("connect");
				if (result.desktop?.status === "confirmation-required") {
					if (!(await ctx.ui.confirm("Enable local debugging for Figma Desktop?", result.desktop.guidance))) {
						ctx.ui.notify("Connection cancelled; Figma was not modified.", "info");
						return;
					}
					ctx.ui.notify("Preparing the desktop patch and original-app backup…", "info");
					result = await client.setup("connect", { allowPatch: true });
				}
				const report = summarize("connect", result);
				ctx.ui.notify(report.text, report.level);
			} catch (error) {
				await notifyCommandError(ctx, "connect", error);
			}
		},
	});

	pi.registerCommand("figpie-status", {
		description: "Report status without starting a broker or Figma; --verbose includes full diagnostics",
		handler: async (args, ctx) => {
			if (!ctx.hasUI) throw new Error("Figpie commands require an interactive Pi session.");
			const verbose = args.trim() === "--verbose";
			if (args.trim() && !verbose) {
				ctx.ui.notify("Usage: /figpie-status [--verbose]", "warning");
				return;
			}
			try {
				const result = await client.setup("status");
				const report = summarize("status", result);
				if (verbose) {
					const output = await formatOutput(JSON.stringify(result, null, 2));
					ctx.ui.notify(
						[
							output.text,
							`Broker socket: ${SOCKET_PATH}`,
							`Broker log: ${BROKER_LOG_FILE}`,
							`Execution logs: ${LOG_DIR}`,
							`Client trace: ${clientTrace.file}`,
							...(clientTrace.lastError ? [`Logging error: ${clientTrace.lastError}`] : []),
						].join("\n"),
						report.level,
					);
				} else ctx.ui.notify(report.text, report.level);
			} catch (error) {
				await notifyCommandError(ctx, "status", error, verbose);
			}
		},
	});

	pi.registerCommand("figpie-restore", {
		description: "Restore the matching original Figma app backup and code signature",
		handler: async (args, ctx) => {
			if (!ctx.hasUI) throw new Error("Figpie commands require an interactive Pi session.");
			if (args.trim()) {
				ctx.ui.notify("Usage: /figpie-restore", "warning");
				return;
			}
			try {
				await ctx.waitForIdle();
				if (
					!(await ctx.ui.confirm(
						"Restore Figma Desktop?",
						"Restore the matching original app backup and remove the CDP patch. Figma must be closed; a newer installation will never be overwritten. Continue?",
					))
				)
					return;
				ctx.ui.notify("Restoring Figma…", "info");
				await brokerManager.ensureRunning();
				const result = await client.setup("restore");
				const report = summarize("restore", result);
				ctx.ui.notify(report.text, report.level);
			} catch (error) {
				await notifyCommandError(ctx, "restore", error);
			}
		},
	});
	pi.on("session_shutdown", async () => {
		await client.stop();
	});
}
