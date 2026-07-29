import { randomUUID } from "node:crypto";
import { mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";

import {
	CONFIG_DIR_NAME,
	DEFAULT_MAX_BYTES,
	DEFAULT_MAX_LINES,
	formatSize,
	getAgentDir,
	truncateHead,
} from "@earendil-works/pi-coding-agent";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";
import { Type } from "typebox";

const DEFAULT_SERVER_URL = "http://127.0.0.1:3845/mcp";
const CONFIG_FILE = "figma-mcp.json";
const STATUS_KEY = "figma-mcp";
const CLIENT_INFO = { name: "pi-figma-mcp", version: "0.1.0" };
const FIGMA_PROMPT_PATTERN = /\b(figma|design|frame|layer|ui)\b/i;
const FIGMA_HINT =
	"Figma desktop MCP tools are available. For design-to-code work, call figma_get_design_context first. Use screenshots only as visual references, never as a substitute for structured design context.";
const FIGMA_IMPLEMENT_USAGE =
	"Usage: /figma-implement <figma-design-url-with-node-id> [instructions]";

function errorMessage(error) {
	return error instanceof Error ? error.message : String(error);
}

function getProjectConfigPath(cwd) {
	return join(cwd, CONFIG_DIR_NAME, CONFIG_FILE);
}

function getGlobalConfigPath() {
	return join(getAgentDir(), CONFIG_FILE);
}

function parseServerUrl(value) {
	let url;
	try {
		url = new URL(value);
	} catch {
		throw new Error(`Invalid Figma MCP URL: ${value}`);
	}

	if (url.protocol !== "http:" && url.protocol !== "https:") {
		throw new Error("Figma MCP URL must use http:// or https://");
	}

	return url;
}

function normalizeNodeId(value) {
	const nodeId = value.trim();
	const dashed = nodeId.match(/^(\d+)-(\d+)$/);
	return dashed ? `${dashed[1]}:${dashed[2]}` : nodeId;
}

function extractFigmaTarget(prompt) {
	const urls = prompt.match(/https?:\/\/(?:www\.)?figma\.com\/[^\s<>"']+/gi) ?? [];
	for (const candidate of urls) {
		let url;
		try {
			url = new URL(candidate.replace(/[),.;!?]+$/, ""));
		} catch {
			continue;
		}

		const nodeId = url.searchParams.get("node-id");
		if (nodeId?.trim()) {
			return { nodeId: normalizeNodeId(nodeId), url: url.href };
		}
	}
	return undefined;
}

function parseFigmaImplementArgs(args) {
	const input = args.trim();
	if (!input) throw new Error(FIGMA_IMPLEMENT_USAGE);

	const match = input.match(/^(\S+)(?:\s+([\s\S]*))?$/);
	if (!match) throw new Error(FIGMA_IMPLEMENT_USAGE);

	let url;
	try {
		url = new URL(match[1]);
	} catch {
		throw new Error(`Invalid Figma URL. ${FIGMA_IMPLEMENT_USAGE}`);
	}

	const hostname = url.hostname.toLowerCase();
	if (
		url.protocol !== "https:" ||
		(hostname !== "figma.com" && hostname !== "www.figma.com") ||
		!/^\/design\/[^/]+(?:\/|$)/.test(url.pathname)
	) {
		throw new Error(
			`Expected a node-specific https://www.figma.com/design/... URL. ${FIGMA_IMPLEMENT_USAGE}`,
		);
	}

	const rawNodeId = url.searchParams.get("node-id");
	const nodeId = rawNodeId ? normalizeNodeId(rawNodeId) : "";
	if (!/^\d+:\d+$/.test(nodeId)) {
		throw new Error(`The Figma Design URL must contain a valid node-id. ${FIGMA_IMPLEMENT_USAGE}`);
	}

	return {
		url: url.href,
		nodeId,
		instructions: match[2]?.trim() || undefined,
	};
}

function buildFigmaImplementPrompt({ url, instructions }) {
	const lines = [
		`Implement the complete Figma target at ${url}.`,
		"",
		"Load and follow the `figma-design-to-code` skill. Treat the URL node as the root target and implement its complete scope. The URL is mandatory; never fall back to the current Figma desktop selection.",
	];

	if (instructions) lines.push("", "Additional instructions:", instructions);
	return lines.join("\n");
}

async function readConfiguredUrl(path) {
	let content;
	try {
		content = await readFile(path, "utf8");
	} catch (error) {
		if (error?.code === "ENOENT") return undefined;
		throw new Error(`Could not read ${path}: ${errorMessage(error)}`);
	}

	let config;
	try {
		config = JSON.parse(content);
	} catch (error) {
		throw new Error(`Invalid JSON in ${path}: ${errorMessage(error)}`);
	}

	if (typeof config.serverUrl !== "string" || !config.serverUrl.trim()) {
		throw new Error(`${path} must contain a non-empty "serverUrl" string`);
	}

	return parseServerUrl(config.serverUrl.trim()).href;
}

async function resolveServerConfig(ctx) {
	const envUrl = process.env.FIGMA_MCP_URL?.trim();
	if (envUrl) {
		return { url: parseServerUrl(envUrl).href, source: "env" };
	}

	if (ctx.isProjectTrusted()) {
		const projectPath = getProjectConfigPath(ctx.cwd);
		const projectUrl = await readConfiguredUrl(projectPath);
		if (projectUrl) {
			return { url: projectUrl, source: "project", path: projectPath };
		}
	}

	const globalPath = getGlobalConfigPath();
	const globalUrl = await readConfiguredUrl(globalPath);
	if (globalUrl) {
		return { url: globalUrl, source: "global", path: globalPath };
	}

	return { url: DEFAULT_SERVER_URL, source: "default" };
}

async function writeConfiguredUrl(path, value) {
	const url = parseServerUrl(value).href;
	await mkdir(dirname(path), { recursive: true });
	await writeFile(path, `${JSON.stringify({ serverUrl: url }, null, 2)}\n`, "utf8");
	return url;
}

async function removeConfiguredUrl(path) {
	await rm(path, { force: true });
}

function parseScopedArgs(args) {
	const match = args.trim().match(/^(?:(--global|--project)(?:\s+|$))?(.*)$/s);
	return {
		scope: match?.[1] === "--global" ? "global" : "project",
		value: match?.[2]?.trim() || undefined,
	};
}

function configPathForScope(scope, cwd) {
	return scope === "global" ? getGlobalConfigPath() : getProjectConfigPath(cwd);
}

function baseToolName(mcpToolName) {
	const normalized = mcpToolName
		.trim()
		.toLowerCase()
		.replace(/[^a-z0-9_]+/g, "_")
		.replace(/^_+|_+$/g, "");
	const name = normalized || "tool";
	return name.startsWith("figma_") ? name : `figma_${name}`;
}

function toolLabel(tool) {
	return (tool.title?.trim() || tool.annotations?.title?.trim() || tool.name)
		.replace(/[_-]+/g, " ")
		.replace(/\b\w/g, (character) => character.toUpperCase());
}

function jsonStringify(value) {
	try {
		return JSON.stringify(value, null, 2);
	} catch {
		return String(value);
	}
}

function schemaOptions(schema) {
	const options = {};
	for (const key of [
		"description",
		"default",
		"minimum",
		"maximum",
		"exclusiveMinimum",
		"exclusiveMaximum",
		"minLength",
		"maxLength",
		"pattern",
		"format",
		"minItems",
		"maxItems",
	]) {
		if (schema[key] !== undefined) options[key] = schema[key];
	}
	return options;
}

function schemaToTypeBox(schema) {
	if (!schema || typeof schema !== "object" || Array.isArray(schema)) {
		return Type.Any();
	}

	if (schema.const === null) {
		return Type.Null(schemaOptions(schema));
	}
	if (["string", "number", "boolean"].includes(typeof schema.const)) {
		return Type.Literal(schema.const, schemaOptions(schema));
	}

	const enumValues = Array.isArray(schema.enum)
		? schema.enum.filter((value) =>
			["string", "number", "boolean"].includes(typeof value),
		)
		: [];
	if (enumValues.length > 0) {
		return Type.Union(
			enumValues.map((value) => Type.Literal(value)),
			schemaOptions(schema),
		);
	}

	for (const unionKey of ["oneOf", "anyOf"]) {
		if (Array.isArray(schema[unionKey]) && schema[unionKey].length > 0) {
			return Type.Union(
				schema[unionKey].map(schemaToTypeBox),
				schemaOptions(schema),
			);
		}
	}

	const options = schemaOptions(schema);
	const type = schema.type ?? (schema.properties ? "object" : undefined);
	switch (type) {
		case "string":
			return Type.String(options);
		case "integer":
			return Type.Integer(options);
		case "number":
			return Type.Number(options);
		case "boolean":
			return Type.Boolean(options);
		case "null":
			return Type.Null(options);
		case "array":
			return Type.Array(schemaToTypeBox(schema.items), options);
		case "object": {
			const properties =
				schema.properties && typeof schema.properties === "object"
					? schema.properties
					: {};
			const required = new Set(
				Array.isArray(schema.required)
					? schema.required.filter((name) => typeof name === "string")
					: [],
			);
			const mapped = {};
			for (const [name, propertySchema] of Object.entries(properties)) {
				const property = schemaToTypeBox(propertySchema);
				mapped[name] = required.has(name) ? property : Type.Optional(property);
			}
			return Type.Object(mapped, {
				...options,
				additionalProperties: schema.additionalProperties !== false,
			});
		}
		default:
			return Type.Any(options);
	}
}

function summarizeSchema(schema) {
	if (!schema?.properties || Object.keys(schema.properties).length === 0) {
		return undefined;
	}

	const required = new Set(schema.required ?? []);
	return Object.entries(schema.properties)
		.map(([name, value]) => {
			const type = Array.isArray(value.type)
				? value.type.join(" | ")
				: typeof value.type === "string"
					? value.type
					: "any";
			const description =
				typeof value.description === "string" ? ` — ${value.description}` : "";
			return `- ${name}: ${type} (${required.has(name) ? "required" : "optional"})${description}`;
		})
		.join("\n");
}

function toolDescription(tool) {
	const parts = [tool.description?.trim() || `Figma MCP tool: ${tool.name}`];
	const schemaSummary = summarizeSchema(tool.inputSchema);
	if (schemaSummary) parts.push(`Arguments:\n${schemaSummary}`);
	return parts.join("\n\n");
}

function promptGuidelines(mcpToolName, piToolName) {
	switch (mcpToolName) {
		case "get_design_context":
			return [
				`Always prefer ${piToolName} as the primary tool for design-to-code work.`,
				`When the user shares a node-specific Figma URL, extract its node-id, normalize 1-2 to 1:2, and pass it as nodeId to ${piToolName}; the URL target overrides the desktop selection.`,
			];
		case "get_metadata":
			return [
				`Use ${piToolName} to orient within a large frame or after design context is too large or truncated; it is not a substitute for figma_get_design_context.`,
			];
		case "get_screenshot":
			return [
				`Use ${piToolName} only as a visual reference or validation aid, not as a substitute for figma_get_design_context.`,
				`When the user supplied a node-specific Figma URL, pass the same explicit nodeId to ${piToolName} and never fall back to the current selection.`,
			];
		default:
			return [
				`Use ${piToolName} when the user asks for the corresponding information from Figma desktop.`,
			];
	}
}

function summarizeCallResult(result) {
	if (!result || typeof result !== "object") return jsonStringify(result);

	const blocks = [];
	for (const item of result.content ?? []) {
		if (item.type === "text" && typeof item.text === "string") {
			blocks.push(item.text);
		} else if (item.type === "image") {
			blocks.push(`[image content: ${item.mimeType || "unknown MIME type"}]`);
		} else if (item.type === "audio") {
			blocks.push(`[audio content: ${item.mimeType || "unknown MIME type"}]`);
		} else if (item.type === "resource" && item.resource) {
			const resource = item.resource;
			const header = `[resource: ${resource.uri || "embedded"}${resource.mimeType ? `, ${resource.mimeType}` : ""}]`;
			blocks.push(`${header}${typeof resource.text === "string" ? `\n${resource.text}` : ""}`);
		} else {
			blocks.push(jsonStringify(item));
		}
	}

	if (result.structuredContent !== undefined) {
		blocks.push(`Structured content:\n${jsonStringify(result.structuredContent)}`);
	}

	return blocks.length > 0 ? blocks.join("\n\n") : jsonStringify(result);
}

function extractImages(result) {
	if (!Array.isArray(result?.content)) return [];
	return result.content
		.filter(
			(item) =>
				item.type === "image" &&
				typeof item.data === "string" &&
				typeof item.mimeType === "string",
		)
		.map(({ data, mimeType }) => ({ type: "image", data, mimeType }));
}

async function formatToolOutput(result, toolName) {
	const text = summarizeCallResult(result);
	const truncation = truncateHead(text, {
		maxBytes: DEFAULT_MAX_BYTES,
		maxLines: DEFAULT_MAX_LINES,
	});

	if (!truncation.truncated) {
		return { text, outputFile: undefined, truncation };
	}

	const outputDir = join(tmpdir(), "pi-figma-mcp");
	await mkdir(outputDir, { recursive: true });
	const outputFile = join(
		outputDir,
		`${toolName.replace(/[^a-z0-9_-]+/gi, "-")}-${randomUUID()}.json`,
	);
	await writeFile(outputFile, `${jsonStringify(result)}\n`, "utf8");

	const notice =
		`[Output truncated: ${truncation.outputLines} of ${truncation.totalLines} lines ` +
		`(${formatSize(truncation.outputBytes)} of ${formatSize(truncation.totalBytes)}). ` +
		`Full MCP result saved to: ${outputFile}]`;
	return {
		text: truncation.content ? `${truncation.content}\n\n${notice}` : notice,
		outputFile,
		truncation,
	};
}

function toolLines(toolInfoByPiName) {
	if (toolInfoByPiName.size === 0) {
		return ["No Figma MCP tools discovered yet."];
	}

	return [...toolInfoByPiName.values()]
		.sort((left, right) => left.piToolName.localeCompare(right.piToolName))
		.map(({ piToolName, mcpToolName }) => `${piToolName} → ${mcpToolName}`);
}

/** @param {import("@earendil-works/pi-coding-agent").ExtensionAPI} pi */
export default function figmaMcpExtension(pi) {
	let client;
	let connection;
	let connectedConfig;
	let promptFigmaTarget;
	const registeredPiToolNames = new Set();
	const toolInfoByPiName = new Map();

	function setStatus(ctx, text) {
		ctx.ui.setStatus(STATUS_KEY, text);
	}

	function getToolInfo(mcpToolName) {
		const existing = [...toolInfoByPiName.values()].find(
			(info) => info.mcpToolName === mcpToolName,
		);
		if (existing) return existing;

		const baseName = baseToolName(mcpToolName);
		let piToolName = baseName;
		let suffix = 2;
		while (toolInfoByPiName.has(piToolName)) {
			piToolName = `${baseName}_${suffix}`;
			suffix += 1;
		}

		const info = { piToolName, mcpToolName };
		toolInfoByPiName.set(piToolName, info);
		return info;
	}

	async function disconnect() {
		const activeClient = client;
		client = undefined;
		connectedConfig = undefined;
		if (activeClient) await activeClient.close();
	}

	function registerTool(tool) {
		const info = getToolInfo(tool.name);
		info.acceptsNodeId = Boolean(tool.inputSchema?.properties?.nodeId);
		if (registeredPiToolNames.has(info.piToolName)) return;
		registeredPiToolNames.add(info.piToolName);

		pi.registerTool({
			name: info.piToolName,
			label: toolLabel(tool),
			description: toolDescription(tool),
			promptSnippet: `Read Figma desktop data with ${info.piToolName}`,
			promptGuidelines: promptGuidelines(tool.name, info.piToolName),
			parameters: schemaToTypeBox(tool.inputSchema),
			async execute(_toolCallId, params, signal, onUpdate, ctx) {
				onUpdate?.({
					content: [
						{ type: "text", text: `Calling Figma MCP tool: ${tool.name}...` },
					],
					details: { mcpTool: tool.name },
				});

				const activeClient = await ensureConnected(ctx);
				let result;
				try {
					result = await activeClient.callTool(
						{ name: tool.name, arguments: params ?? {} },
						undefined,
						{ signal },
					);
				} catch (error) {
					if (client === activeClient) await disconnect().catch(() => {});
					setStatus(ctx, "figma mcp: offline");
					throw error;
				}

				const output = await formatToolOutput(result, info.piToolName);
				if (result.isError) throw new Error(output.text);

				return {
					content: [
						{ type: "text", text: output.text },
						...extractImages(result),
					],
					details: {
						serverUrl: connectedConfig?.url,
						serverSource: connectedConfig?.source,
						mcpTool: tool.name,
						outputFile: output.outputFile,
						truncated: output.truncation.truncated,
					},
				};
			},
		});
	}

	async function openConnection(ctx, config) {
		const nextClient = new Client(CLIENT_INFO);
		const nextTransport = new StreamableHTTPClientTransport(new URL(config.url));
		nextClient.onclose = () => {
			if (client === nextClient) {
				client = undefined;
				connectedConfig = undefined;
			}
		};

		try {
			await nextClient.connect(nextTransport);
			const listed = await nextClient.listTools(undefined, { signal: ctx.signal });
			for (const tool of listed.tools) registerTool(tool);

			const previousClient = client;
			if (previousClient) await previousClient.close().catch(() => {});
			client = nextClient;
			connectedConfig = config;

			setStatus(ctx, `figma mcp: ${listed.tools.length} tools`);
			ctx.ui.notify(
				`Connected to Figma desktop MCP (${listed.tools.length} tools, ${config.source} URL)`,
				"info",
			);
			return nextClient;
		} catch (error) {
			await nextClient.close().catch(() => {});
			throw error;
		}
	}

	async function connect(ctx, { force = false } = {}) {
		const config = await resolveServerConfig(ctx);
		if (client && !force && connectedConfig?.url === config.url) return client;
		if (force && client) await disconnect();
		if (!connection) {
			setStatus(ctx, "figma mcp: connecting...");
			connection = openConnection(ctx, config).finally(() => {
				connection = undefined;
			});
		}
		return connection;
	}

	async function ensureConnected(ctx) {
		try {
			return await connect(ctx);
		} catch (error) {
			setStatus(ctx, "figma mcp: offline");
			throw error;
		}
	}

	pi.on("session_start", async (_event, ctx) => {
		setStatus(ctx, "figma mcp: idle");
		try {
			await ensureConnected(ctx);
		} catch (error) {
			ctx.ui.notify(
				"Figma MCP is offline. Start Figma, enable its desktop MCP server, " +
					`then run /figma-mcp-connect. (${errorMessage(error)})`,
				"warning",
			);
		}
	});

	pi.on("before_agent_start", (event) => {
		promptFigmaTarget = extractFigmaTarget(event.prompt);
		if (!FIGMA_PROMPT_PATTERN.test(event.prompt) || toolInfoByPiName.size === 0) {
			return undefined;
		}

		const targetHint = promptFigmaTarget
			? ` The user supplied rootTargetId="${promptFigmaTarget.nodeId}". This explicit URL target overrides the current Figma desktop selection. Pass nodeId="${promptFigmaTarget.nodeId}" to figma_get_design_context first. Descendant reads may use explicit child node IDs discovered from that root. Every related Figma read, including figma_get_screenshot, must include an explicit nodeId; never omit it or silently use the current selection.`
			: "";
		return {
			systemPrompt: `${event.systemPrompt}\n\n${FIGMA_HINT}${targetHint}`,
		};
	});

	pi.on("tool_call", (event) => {
		if (!promptFigmaTarget) return undefined;
		const info = toolInfoByPiName.get(event.toolName);
		if (!info?.acceptsNodeId || !event.input || typeof event.input !== "object") {
			return undefined;
		}
		if (typeof event.input.nodeId !== "string" || !event.input.nodeId.trim()) {
			return {
				block: true,
				reason:
					`The prompt supplied Figma root node ${promptFigmaTarget.nodeId}. ` +
					`Pass an explicit nodeId to ${event.toolName}: use ${promptFigmaTarget.nodeId} ` +
					"for the root target or an explicit child node ID discovered from it.",
			};
		}
		return undefined;
	});

	pi.registerCommand("figma-implement", {
		description:
			"Prepare an implementation prompt from a node-specific Figma Design URL",
		handler: async (args, ctx) => {
			let target;
			try {
				target = parseFigmaImplementArgs(args);
			} catch (error) {
				ctx.ui.notify(errorMessage(error), "warning");
				return;
			}

			if (!ctx.hasUI) {
				throw new Error("/figma-implement requires an interactive or RPC editor");
			}

			ctx.ui.setEditorText(buildFigmaImplementPrompt(target));
			ctx.ui.notify(`Prepared Figma implementation prompt for ${target.nodeId}`, "info");
		},
	});

	pi.registerCommand("figma-mcp-status", {
		description: "Show the Figma MCP connection and discovered tools",
		handler: async (_args, ctx) => {
			const config = await resolveServerConfig(ctx);
			ctx.ui.setWidget(STATUS_KEY, [
				`Server URL: ${config.url}`,
				`URL source: ${config.source}${config.path ? ` (${config.path})` : ""}`,
				`Connected: ${client ? "yes" : "no"}`,
				`Discovered tools: ${toolInfoByPiName.size}`,
				...toolLines(toolInfoByPiName),
			]);
			ctx.ui.notify(
				`Figma MCP ${client ? "connected" : "offline"}`,
				client ? "info" : "warning",
			);
		},
	});

	pi.registerCommand("figma-mcp-list-tools", {
		description: "List Pi tools mirrored from the Figma MCP server",
		handler: async (_args, ctx) => {
			ctx.ui.setWidget(STATUS_KEY, toolLines(toolInfoByPiName));
			ctx.ui.notify(`Listed ${toolInfoByPiName.size} Figma MCP tools`, "info");
		},
	});

	pi.registerCommand("figma-mcp-connect", {
		description: "Connect or reconnect to the Figma desktop MCP server",
		handler: async (_args, ctx) => {
			try {
				await connect(ctx, { force: true });
			} catch (error) {
				setStatus(ctx, "figma mcp: offline");
				ctx.ui.notify(`Failed to connect to Figma MCP: ${errorMessage(error)}`, "error");
			}
		},
	});

	pi.registerCommand("figma-mcp-set-url", {
		description:
			"Set the project Figma MCP URL; pass --global to set it for all projects",
		handler: async (args, ctx) => {
			const { scope, value } = parseScopedArgs(args);
			if (!value) {
				ctx.ui.notify(
					"Usage: /figma-mcp-set-url [--project|--global] <url>",
					"warning",
				);
				return;
			}
			if (scope === "project" && !ctx.isProjectTrusted()) {
				ctx.ui.notify("Cannot write project config for an untrusted project", "error");
				return;
			}

			try {
				const path = configPathForScope(scope, ctx.cwd);
				const url = await writeConfiguredUrl(path, value);
				await connect(ctx, { force: true });
				ctx.ui.notify(`Saved ${scope} Figma MCP URL: ${url}`, "info");
			} catch (error) {
				ctx.ui.notify(errorMessage(error), "error");
			}
		},
	});

	pi.registerCommand("figma-mcp-reset-url", {
		description:
			"Reset the project Figma MCP URL; pass --global to reset it for all projects",
		handler: async (args, ctx) => {
			const { scope } = parseScopedArgs(args);
			if (scope === "project" && !ctx.isProjectTrusted()) {
				ctx.ui.notify("Cannot write project config for an untrusted project", "error");
				return;
			}

			try {
				await removeConfiguredUrl(configPathForScope(scope, ctx.cwd));
				await connect(ctx, { force: true });
				ctx.ui.notify(`Removed ${scope} Figma MCP URL override`, "info");
			} catch (error) {
				ctx.ui.notify(errorMessage(error), "error");
			}
		},
	});

	pi.on("session_shutdown", async () => {
		await disconnect().catch(() => {});
	});
}
