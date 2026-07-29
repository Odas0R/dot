import { StringEnum } from "@earendil-works/pi-ai";
import { Container, Text } from "@earendil-works/pi-tui";
import { createMemory, formatResult, memoryInstructions } from "optmem-js";
import { Type } from "typebox";

const TOOL_NAME = "optmem";
const CONTEXT_TYPE = "optmem-wake";
const ACTION_FORMAT = Object.freeze({
	interface: "action",
	toolName: TOOL_NAME,
	fields: Object.freeze({ summary: "text" }),
});

function optMemDisabled(env = process.env, argv = process.argv) {
	return /^(?:1|true|yes)$/i.test(env.PI_OPTMEM_DISABLED || "") || argv.includes("--no-session");
}

function required(value, label) {
	if (typeof value !== "string" || value.trim() === "") {
		throw new Error(`optmem ${label} is required`);
	}
	return value.trim();
}

function formatStartupContext(output) {
	return `## OptMem startup context\n\n${output}\n\nFollow any OptMem instruction above before continuing other work.`;
}

function isOptMemContextMessage(message) {
	return message?.role === "custom" && message.customType === CONTEXT_TYPE;
}

function latestOptMemContextOnly(messages) {
	const latest = messages.findLastIndex(isOptMemContextMessage);
	if (latest < 0) return messages;
	return messages.filter(
		(message, index) => !isOptMemContextMessage(message) || index === latest,
	);
}

function notifyError(ctx, error) {
	const message = error instanceof Error ? error.message : String(error);
	ctx.ui.notify(message, "error");
}

function textOutput(result) {
	return result.content.find((item) => item.type === "text")?.text || "";
}

function renderOptMemCall(args, theme) {
	if (!args?.action || args.action === "wake") return new Container();
	return new Text(
		`${theme.fg("toolTitle", theme.bold("OptMem"))} ${theme.fg("muted", args.action)}`,
		0,
		0,
	);
}

function renderOptMemResult(result, _options, theme, context) {
	if (context.args?.action !== "wake") {
		return new Text(theme.fg(context.isError ? "error" : "toolOutput", textOutput(result)), 0, 0);
	}

	if (context.isError) {
		return new Text(theme.fg("error", textOutput(result)), 0, 0);
	}

	const wake = result.details?.result;
	if (wake?.awake) return new Container();

	let message = "OptMem wake is incomplete";
	if (wake?.missingBlock) message = `OptMem wake requires compression of #${wake.missingBlock}`;
	else if (wake?.nextPage) message = `OptMem wake is awaiting part ${wake.nextPage.part}`;
	return new Text(theme.fg("warning", message), 0, 0);
}

function executeAction(memory, params) {
	switch (params.action) {
		case "wake":
			return memory.wake({ part: params.part, snapshot: params.snapshot });
		case "note":
			return memory.note(required(params.text, "note text"));
		case "nap": {
			if (params.block === undefined && params.text === undefined) return memory.nap();
			return memory.nap({
				block: required(params.block, "nap block"),
				summary: required(params.text, "nap summary"),
			});
		}
		case "recall":
			return memory.recall(required(params.query, "recall query"));
		case "zoom":
			return memory.zoom(required(params.block, "zoom block"));
		case "forget":
			return memory.forget(required(params.block, "forget block"));
		default:
			throw new Error(`Unknown optmem action: ${params.action}`);
	}
}

/** @param {import("@earendil-works/pi-coding-agent").ExtensionAPI} pi */
export default function optMemExtension(pi) {
	const memory = createMemory();
	let disabled = false;
	let systemGuidance = memoryInstructions(memory.directory, 280, ACTION_FORMAT);

	function ensureMemory() {
		const initialized = memory.init();
		systemGuidance = memoryInstructions(
			memory.directory,
			initialized.sizes.ENTRY_CHARS,
			ACTION_FORMAT,
		);
		return initialized;
	}

	pi.on("session_start", () => {
		disabled = optMemDisabled();
		if (disabled) {
			pi.setActiveTools(pi.getActiveTools().filter((name) => name !== TOOL_NAME));
			return;
		}

		try {
			ensureMemory();
		} catch {
			// The explicit wake tool call will report initialization errors to the agent.
		}
	});

	pi.on("before_agent_start", (event) => {
		if (disabled) return undefined;
		return { systemPrompt: `${event.systemPrompt}\n\n${systemGuidance}` };
	});

	pi.on("context", (event) => {
		const messages = latestOptMemContextOnly(event.messages);
		return messages === event.messages ? undefined : { messages };
	});

	pi.registerTool({
		name: TOOL_NAME,
		label: "OptMem",
		description:
			"Use permanent append-only memory. Actions: wake loads memory (part/snapshot continue pagination); note records one lasting factual line (text); nap requests the next compression or saves one (block and text); recall searches raw memories by regex (query); zoom opens a summary block (block); forget discards an incorrect summary cache block without deleting raw memories (block). Follow every compression or pagination instruction in the output before other work.",
		promptSnippet: "Load, record, search, and progressively compress permanent memory",
		promptGuidelines: [
			"Use optmem note for non-redundant facts, preferences, decisions, results, and events with lasting value.",
			"When optmem output requests a nap or another wake page, complete those optmem actions before using non-memory tools.",
			"Never use optmem from a subagent and never edit OptMem storage files directly.",
		],
		executionMode: "sequential",
		renderShell: "self",
		renderCall: renderOptMemCall,
		renderResult: renderOptMemResult,
		parameters: Type.Object({
			action: StringEnum(["wake", "note", "nap", "recall", "zoom", "forget"]),
			text: Type.Optional(
				Type.String({ description: "Memory text for note, or one-line summary for nap" }),
			),
			block: Type.Optional(
				Type.String({ description: "Tree block id exactly as printed, for example 0-3" }),
			),
			query: Type.Optional(Type.String({ description: "Case-insensitive regex for recall" })),
			part: Type.Optional(Type.Integer({ minimum: 1, description: "Wake page number" })),
			snapshot: Type.Optional(
				Type.Integer({ minimum: 0, description: "Wake snapshot T printed by the previous page" }),
			),
		}),
		async execute(_toolCallId, params) {
			if (disabled) throw new Error("OptMem is disabled for --no-session/subagent runs");
			ensureMemory();
			const result = executeAction(memory, params);
			return {
				content: [{ type: "text", text: formatResult(result, ACTION_FORMAT) }],
				details: { action: params.action, directory: memory.directory, result },
			};
		},
	});

	pi.registerCommand("memory", {
		description: "Wake OptMem and add the latest persistent memory to this session",
		handler: async (_args, ctx) => {
			try {
				ensureMemory();
				const result = memory.wake();
				pi.sendMessage({
					customType: CONTEXT_TYPE,
					content: formatStartupContext(formatResult(result, ACTION_FORMAT)),
					display: true,
					details: { directory: memory.directory, loadedAt: Date.now() },
				});
				ctx.ui.notify(result.awake ? "OptMem context refreshed" : "OptMem needs attention", result.awake ? "info" : "warning");
			} catch (error) {
				notifyError(ctx, error);
			}
		},
	});

	pi.registerCommand("memory-note", {
		description: "Record one permanent memory: /memory-note <one factual line>",
		handler: async (args, ctx) => {
			try {
				ensureMemory();
				const result = memory.note(required(args, "note text"));
				const output = formatResult(result, ACTION_FORMAT);
				if (result.compression) {
					pi.sendMessage({
						customType: "optmem-maintenance",
						content: `## OptMem maintenance required\n\n${output}`,
						display: true,
						details: { directory: memory.directory },
					});
				} else {
					ctx.ui.notify(output, "info");
				}
			} catch (error) {
				notifyError(ctx, error);
			}
		},
	});

	pi.registerCommand("memory-recall", {
		description: "Search permanent raw memories: /memory-recall <regex>",
		handler: async (args, ctx) => {
			try {
				ensureMemory();
				const result = memory.recall(required(args, "recall query"));
				pi.sendMessage({
					customType: "optmem-recall",
					content: `## OptMem recall\n\n${formatResult(result, ACTION_FORMAT)}`,
					display: true,
					details: { directory: memory.directory, query: result.query },
				});
			} catch (error) {
				notifyError(ctx, error);
			}
		},
	});
}

export {
	executeAction,
	formatStartupContext,
	latestOptMemContextOnly,
	optMemDisabled,
};
