// SPDX-License-Identifier: Apache-2.0
// Adapted from Armin Ronacher's agent-stuff/extensions/subagent.ts:
// https://github.com/mitsuhiko/agent-stuff/blob/main/extensions/subagent.ts
// Modified: JavaScript, with Kitty remote control replacing the tmux backend.

import { spawnSync } from "node:child_process";
import { randomUUID } from "node:crypto";
import { existsSync } from "node:fs";
import { mkdir, readFile, rename, stat, writeFile } from "node:fs/promises";
import * as path from "node:path";
import { fileURLToPath } from "node:url";

import { StringEnum } from "@earendil-works/pi-ai";
import {
	DEFAULT_MAX_BYTES,
	DEFAULT_MAX_LINES,
	getAgentDir,
	getMarkdownTheme,
	getShellConfig,
	keyHint,
	SessionManager,
	SettingsManager,
	truncateHead,
} from "@earendil-works/pi-coding-agent";
import {
	Markdown,
	stripTerminalSequences,
	Text,
	truncateToWidth,
} from "@earendil-works/pi-tui";
import { Type } from "typebox";
import {
	checkKittyConnection,
	currentKittyWindowId,
	humanKittyError,
	kittyArgs,
	kittySocketAddress,
	launchKitty,
} from "../lib/kitty.js";

const ATTACH_FLAG = "attach-subagent";
const CHILD_ENV = "PI_KITTY_SUBAGENT_CHILD";
const RESULT_ENV = "PI_KITTY_SUBAGENT_RESULT";
const RUNS_DIR = "kitty-subagents";
const POLL_INTERVAL_MS = 500;
const PANE_PREVIEW_LINES = 18;
const REMOTE_TIMEOUT_MS = 5_000;
const THINKING_LEVELS = [
	"off",
	"minimal",
	"low",
	"medium",
	"high",
	"xhigh",
	"max",
];
const EXTENSION_PATH = fileURLToPath(import.meta.url);
const SESSION_ID_PATTERN =
	/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function shellQuote(value) {
	return `'${value.replace(/'/g, `'"'"'`)}'`;
}

function kittySessionName(sessionId) {
	return `pi-agent-${sessionId}`;
}

function attachmentPath(sessionId) {
	return path.join(getAgentDir(), RUNS_DIR, `${sessionId}.json`);
}

function attachFlagValue(argv) {
	const flag = `--${ATTACH_FLAG}`;
	for (let index = 2; index < argv.length; index++) {
		const argument = argv[index];
		if (argument === "--") break;
		if (argument === flag) {
			const value = argv[index + 1];
			return !value || value.startsWith("--") ? "" : value;
		}
		if (argument.startsWith(`${flag}=`)) return argument.slice(flag.length + 1);
	}
	return undefined;
}

function updateKittyCommands(spec) {
	const prefix = ["env", ...kittyArgs(spec.kittyAddress)]
		.map(shellQuote)
		.join(" ");
	spec.attachCommand = `pi --${ATTACH_FLAG} ${shellQuote(spec.attachmentId)}`;
	spec.captureCommand = `${prefix} get-text --extent all --match ${shellQuote(spec.kittyTarget)}`;
	spec.killCommand = `${prefix} close-window --match ${shellQuote(spec.kittyTarget)}`;
}

async function attachToSubagentAndExit(pi, rawTarget) {
	try {
		const target = rawTarget.trim();
		if (!target)
			throw new Error(
				`--${ATTACH_FLAG} requires the session id printed by the subagent tool.`,
			);

		let sessionId = target;
		let address;
		if (target.startsWith("v1.")) {
			// Retain the encoded attachment form; p now identifies a Kitty remote-control address.
			const legacy = JSON.parse(
				Buffer.from(target.slice(3), "base64url").toString("utf8"),
			);
			if (typeof legacy.s !== "string" || typeof legacy.p !== "string") {
				throw new Error("Invalid legacy subagent target.");
			}
			sessionId = legacy.s.replace(/^pi-agent-/, "");
			address = legacy.p;
		}
		if (!SESSION_ID_PATTERN.test(sessionId))
			throw new Error(`Invalid subagent session id: ${sessionId}`);

		const savedJson = await readOptionalFile(attachmentPath(sessionId));
		const saved = savedJson === undefined ? undefined : JSON.parse(savedJson);
		address = kittySocketAddress(address || saved?.address);
		const name = kittySessionName(sessionId);
		const match = `var:pi_subagent=${name}`;
		const windows = await pi.exec(
			"env",
			kittyArgs(address, "ls", "--match", match),
			{ timeout: REMOTE_TIMEOUT_MS },
		);
		const missing =
			!windows.killed &&
			windows.code !== 0 &&
			windows.stderr.includes(`No matching windows for expression: ${match}`);
		if ((windows.code !== 0 || windows.killed) && !missing) {
			throw new Error(
				humanKittyError(windows.stderr.trim() || "Could not contact Kitty."),
			);
		}
		const exists =
			!missing &&
			JSON.parse(windows.stdout).some((osWindow) =>
				osWindow.tabs.some((tab) => tab.windows.length > 0),
			);
		if (exists) {
			const result = await pi.exec(
				"env",
				kittyArgs(address, "focus-window", "--match", match),
				{ timeout: REMOTE_TIMEOUT_MS },
			);
			if (result.code === 0 && !result.killed) process.exit(0);
			throw new Error(
				humanKittyError(
					result.stderr.trim() || "Could not focus the subagent window.",
				),
			);
		}
		if (!saved?.sessionFile || !existsSync(saved.sessionFile)) {
			throw new Error(
				`No Kitty window or saved session found for subagent ${sessionId}.`,
			);
		}
		process.exit(await resumeInCurrentTerminal(pi, saved, sessionId));
	} catch (error) {
		console.error(
			`Failed to attach to subagent: ${error instanceof Error ? error.message : String(error)}`,
		);
		process.exit(1);
	}
}

async function resumeInCurrentTerminal(pi, saved, sessionId) {
	if (!process.stdin.isTTY || !process.stdout.isTTY) {
		throw new Error(
			"Run --attach-subagent from an interactive terminal to resume a saved session.",
		);
	}
	const env = { ...process.env, PI_CODING_AGENT_DIR: getAgentDir() };
	delete env[CHILD_ENV];
	delete env[RESULT_ENV];
	const [command, ...args] = getPiInvocationParts();
	args.push(
		"--session",
		saved.sessionFile,
		saved.trusted ? "--approve" : "--no-approve",
		"--extension",
		EXTENSION_PATH,
	);

	// Track the caller's Kitty window so another attach focuses this resumed Pi.
	const address = process.env.KITTY_LISTEN_ON;
	const match =
		address && process.env.KITTY_WINDOW_ID
			? `id:${process.env.KITTY_WINDOW_ID}`
			: undefined;
	let previousTag;
	if (match) {
		const windows = await pi.exec(
			"env",
			kittyArgs(address, "ls", "--match", match),
			{ timeout: REMOTE_TIMEOUT_MS },
		);
		if (windows.code !== 0 || windows.killed) {
			throw new Error(
				humanKittyError(
					windows.stderr.trim() ||
						"Could not inspect the current Kitty window.",
				),
			);
		}
		const window = JSON.parse(windows.stdout).flatMap((osWindow) =>
			osWindow.tabs.flatMap((tab) => tab.windows),
		)[0];
		previousTag = window?.user_vars?.pi_subagent;
		const tagged = await pi.exec(
			"env",
			kittyArgs(
				address,
				"set-user-vars",
				"--match",
				match,
				`pi_subagent=${kittySessionName(sessionId)}`,
			),
			{ timeout: REMOTE_TIMEOUT_MS },
		);
		if (tagged.code !== 0 || tagged.killed) {
			throw new Error(
				humanKittyError(
					tagged.stderr.trim() || "Could not mark the current Kitty window.",
				),
			);
		}
	}

	try {
		if (match)
			await writeJsonAtomic(attachmentPath(sessionId), { ...saved, address });
		// pi.exec captures output; interactive resume must inherit this terminal instead.
		const result = spawnSync(command, args, {
			cwd: saved.cwd,
			env,
			stdio: "inherit",
		});
		if (result.error) throw result.error;
		return result.status ?? 1;
	} finally {
		if (match) {
			const restored = await pi.exec(
				"env",
				kittyArgs(
					address,
					"set-user-vars",
					"--match",
					match,
					previousTag === undefined
						? "pi_subagent"
						: `pi_subagent=${previousTag}`,
				),
				{ timeout: REMOTE_TIMEOUT_MS },
			);
			if (restored.code !== 0 || restored.killed) {
				console.error(
					`Could not restore Kitty's attachment tag: ${restored.stderr.trim() || "remote control failed"}`,
				);
			}
		}
	}
}

function getPiInvocationParts() {
	const currentScript = process.argv[1];
	if (currentScript && existsSync(currentScript))
		return [process.execPath, currentScript];
	const execName = path.basename(process.execPath).toLowerCase();
	if (!/^(node|bun)(\.exe)?$/.test(execName)) return [process.execPath];
	return ["pi"];
}

function textFromAssistant(message) {
	const content = message.content;
	if (typeof content === "string") return content;
	if (!Array.isArray(content)) return "";
	return content
		.filter(
			(part) => part && part.type === "text" && typeof part.text === "string",
		)
		.map((part) => part.text)
		.join("\n");
}

function findLastAssistant(ctx) {
	const branch = ctx.sessionManager.getBranch();
	for (let index = branch.length - 1; index >= 0; index--) {
		const entry = branch[index];
		if (entry.type === "message" && entry.message.role === "assistant")
			return entry.message;
	}
	return undefined;
}

async function writeJsonAtomic(filePath, value) {
	const temporaryPath = `${filePath}.${process.pid}.${randomUUID()}.tmp`;
	await writeFile(temporaryPath, `${JSON.stringify(value)}\n`, {
		encoding: "utf8",
		mode: 0o600,
	});
	await rename(temporaryPath, filePath);
}

async function readOptionalFile(filePath) {
	try {
		return await readFile(filePath, "utf8");
	} catch (error) {
		if (error.code === "ENOENT") return undefined;
		throw error;
	}
}

function registerChildReporter(pi, resultPath) {
	let reported = false;
	const report = async (ctx, fallbackError) => {
		if (reported) return;
		reported = true;

		const assistant = findLastAssistant(ctx);
		const stopReason = assistant?.stopReason;
		const failed =
			!assistant ||
			stopReason === "error" ||
			stopReason === "aborted" ||
			Boolean(fallbackError);
		const result = {
			version: 1,
			status: failed ? "failed" : "completed",
			output: assistant ? textFromAssistant(assistant) : "",
			error:
				fallbackError ??
				assistant?.errorMessage ??
				(!assistant
					? "Subagent exited without an assistant response."
					: undefined),
			stopReason,
			sessionFile: ctx.sessionManager.getSessionFile(),
			provider: assistant?.provider ?? ctx.model?.provider,
			model: assistant?.model ?? ctx.model?.id,
			thinking: pi.getThinkingLevel(),
			finishedAt: Date.now(),
		};

		try {
			await writeJsonAtomic(resultPath, result);
		} catch (error) {
			console.error(
				`[kitty-subagent] Failed to write result: ${error instanceof Error ? error.message : String(error)}`,
			);
		}
	};

	pi.on("agent_settled", async (_event, ctx) => {
		await report(ctx);
		ctx.shutdown();
	});
	pi.on("session_shutdown", async (_event, ctx) => {
		if (!reported)
			await report(ctx, "Subagent session shut down before the task settled.");
	});
}

function trimPane(output) {
	const lines = output.replace(/\r/g, "").split("\n");
	while (lines.length > 0 && !lines[0]?.trim()) lines.shift();
	while (lines.length > 0 && !lines[lines.length - 1]?.trim()) lines.pop();
	return lines.slice(-PANE_PREVIEW_LINES).join("\n");
}

function formatDuration(startedAt, finishedAt = Date.now()) {
	if (startedAt === undefined) return undefined;
	const seconds = Math.max(0, Math.round((finishedAt - startedAt) / 1000));
	if (seconds < 60) return `${seconds}s`;
	return `${Math.floor(seconds / 60)}m ${seconds % 60}s`;
}

function detailsFor(spec, status, extra = {}) {
	return {
		status,
		task: spec.task,
		cwd: spec.cwd,
		kittySession: spec.kittySession,
		kittyWindowId: spec.kittyWindowId,
		attachCommand: spec.attachCommand,
		captureCommand: spec.captureCommand,
		killCommand: spec.killCommand,
		provider: spec.provider,
		model: spec.model,
		thinking: spec.thinking,
		...extra,
	};
}

function partialText(details) {
	const duration = formatDuration(details.startedAt);
	return [
		`Subagent ${details.status}${duration ? ` · ${duration}` : ""}.`,
		`Model: ${details.provider}/${details.model} (${details.thinking})`,
		`Attach: ${details.attachCommand}`,
	].join("\n");
}

function truncateToolText(text) {
	const truncated = truncateHead(text, {
		maxBytes: DEFAULT_MAX_BYTES,
		maxLines: DEFAULT_MAX_LINES,
	});
	if (!truncated.truncated) return truncated.content;
	return `${truncated.content}\n\n[Output truncated. Full output is available in the child session file.]`;
}

function resultText(details) {
	const duration = formatDuration(details.startedAt, details.finishedAt);
	const lines = [
		`Subagent ${details.status}${duration ? ` after ${duration}` : ""}.`,
		`Model: ${details.provider}/${details.model} (${details.thinking})`,
		`Kitty: ${details.kittySession}${details.windowClosed ? " (window closed)" : ""}`,
		`Attach: ${details.attachCommand}`,
	];
	if (details.cleanupError)
		lines.push(`Window cleanup failed: ${details.cleanupError}`);
	if (details.sessionFile) lines.push(`Child session: ${details.sessionFile}`);
	if (details.output) lines.push("", details.output);
	return truncateToolText(lines.join("\n"));
}

async function abortableDelay(ms, signal) {
	if (signal?.aborted) throw new Error("Subagent aborted.");
	await new Promise((resolve, reject) => {
		const cleanup = () => signal?.removeEventListener("abort", onAbort);
		const timer = setTimeout(() => {
			cleanup();
			resolve();
		}, ms);
		const onAbort = () => {
			clearTimeout(timer);
			cleanup();
			reject(new Error("Subagent aborted."));
		};
		signal?.addEventListener("abort", onAbort, { once: true });
	});
}

async function validateCwd(cwd) {
	let info;
	try {
		info = await stat(cwd);
	} catch {
		throw new Error(`Subagent working directory does not exist: ${cwd}`);
	}
	if (!info.isDirectory())
		throw new Error(`Subagent working directory is not a directory: ${cwd}`);
}

function isSameOrDescendant(base, candidate) {
	const relative = path.relative(base, candidate);
	return (
		relative === "" ||
		(relative !== ".." &&
			!relative.startsWith(`..${path.sep}`) &&
			!path.isAbsolute(relative))
	);
}

function resolveModel(ctx, providerOverride, modelOverride) {
	const explicitProvider = providerOverride?.trim();
	const explicitModel = modelOverride?.trim();
	let provider = explicitProvider || ctx.model?.provider || "";
	let model = explicitModel || ctx.model?.id || "";

	// Only split explicitly supplied ids: inherited ids can contain provider-local slashes.
	const slashIndex = explicitModel?.indexOf("/") ?? -1;
	if (explicitModel && slashIndex > 0) {
		const modelProvider = explicitModel.slice(0, slashIndex);
		if (!explicitProvider) {
			provider = modelProvider;
			model = explicitModel.slice(slashIndex + 1);
		} else if (explicitProvider === modelProvider) {
			model = explicitModel.slice(slashIndex + 1);
		}
	}
	if (!provider || !model)
		throw new Error(
			"No model is active. Pass both provider and model to the subagent tool.",
		);
	return { provider, model };
}

export default async function subagentExtension(pi) {
	pi.registerFlag(ATTACH_FLAG, {
		description:
			"Attach using the child session id printed by the subagent tool",
		type: "string",
	});
	const attachTarget = attachFlagValue(process.argv);
	if (attachTarget !== undefined)
		await attachToSubagentAndExit(pi, attachTarget);

	if (process.env[CHILD_ENV] === "1") {
		const resultPath = process.env[RESULT_ENV];
		if (!resultPath) {
			console.error(
				`[kitty-subagent] ${RESULT_ENV} is required in child mode.`,
			);
			return;
		}
		registerChildReporter(pi, resultPath);
		return;
	}

	let queueTail = Promise.resolve();
	let queueDepth = 0;
	let activeSpec;
	const shutdown = new AbortController();

	const withSerialExecution = async (signal, onQueued, fn) => {
		const queued = queueDepth > 0;
		queueDepth++;
		const previous = queueTail;
		let release;
		queueTail = new Promise((resolve) => {
			release = resolve;
		});
		if (queued) onQueued();
		try {
			await previous;
			if (signal.aborted)
				throw new Error("Subagent aborted while waiting in the serial queue.");
			return await fn();
		} finally {
			queueDepth--;
			release();
		}
	};

	pi.on("session_shutdown", async () => {
		shutdown.abort();
		if (!activeSpec) return;
		await pi.exec(
			"env",
			kittyArgs(
				activeSpec.kittyAddress,
				"close-window",
				"--match",
				activeSpec.kittyTarget,
				"--ignore-no-match",
			),
			{ timeout: REMOTE_TIMEOUT_MS },
		);
		activeSpec = undefined;
	});

	pi.registerTool({
		name: "subagent",
		label: "Subagent",
		description:
			"Run one delegated task in a separate interactive Pi process inside tmux. Calls are serialized: only one child works at a time, even if several calls are requested together. The child inherits the current provider, model, and thinking level unless overridden. Live pane output and a copy/paste pi --attach-subagent command are shown while it runs. Output is capped at 50KB or 2000 lines; the complete child session is preserved on disk.",
		promptSnippet:
			"Run one delegated task in an observable, tmux-backed Pi session",
		promptGuidelines: [
			"Use subagent once per delegated task; subagent calls are serialized automatically, so prefer multiple simple calls over asking one child to orchestrate other children.",
		],
		parameters: Type.Object({
			task: Type.String({
				description: "The complete task for the child Pi process",
			}),
			cwd: Type.Optional(
				Type.String({
					description: "Working directory. Defaults to the current project.",
				}),
			),
			provider: Type.Optional(
				Type.String({
					description: "Provider override. Defaults to the current provider.",
				}),
			),
			model: Type.Optional(
				Type.String({
					description:
						"Model id or provider/model override. Defaults to the current model.",
				}),
			),
			thinking: Type.Optional(
				StringEnum(THINKING_LEVELS, {
					description:
						"Thinking level override. Defaults to the current thinking level.",
				}),
			),
		}),

		async execute(_toolCallId, params, signal, onUpdate, ctx) {
			if (!params.task.trim())
				throw new Error("Subagent task must not be empty.");
			const runSignal = signal
				? AbortSignal.any([signal, shutdown.signal])
				: shutdown.signal;
			const cwd = path.resolve(ctx.cwd, params.cwd?.trim() || ".");
			const selectedModel = resolveModel(ctx, params.provider, params.model);
			const thinking = params.thinking ?? pi.getThinkingLevel();
			const childSessionId = randomUUID();
			const runDir = path.join(
				getAgentDir(),
				RUNS_DIR,
				ctx.sessionManager.getSessionId(),
				childSessionId,
			);
			const resultPath = path.join(runDir, "result.json");
			const exitPath = path.join(runDir, "exit-code");
			const kittySession = kittySessionName(childSessionId);
			const spec = {
				task: params.task,
				cwd,
				attachmentId: childSessionId,
				kittySession,
				kittyTarget: `var:pi_subagent=${kittySession}`,
				kittyAddress: kittySocketAddress(),
				kittySourceWindowId: currentKittyWindowId(),
				attachCommand: "",
				captureCommand: "",
				killCommand: "",
				provider: selectedModel.provider,
				model: selectedModel.model,
				thinking,
				trusted:
					isSameOrDescendant(path.resolve(ctx.cwd), cwd) &&
					ctx.isProjectTrusted(),
			};
			updateKittyCommands(spec);

			return withSerialExecution(
				runSignal,
				() => {
					const details = detailsFor(spec, "queued");
					onUpdate?.({
						content: [
							{
								type: "text",
								text: "Waiting for the active subagent to finish...",
							},
						],
						details,
					});
				},
				async () => {
					await validateCwd(cwd);
					const settings = SettingsManager.create(cwd, getAgentDir(), {
						projectTrusted: spec.trusted,
					});
					const { shell, args: shellArgs } = getShellConfig(
						settings.getShellPath(),
					);
					await checkKittyConnection(
						pi,
						spec.kittyAddress,
						spec.kittySourceWindowId,
						runSignal,
						{ timeout: REMOTE_TIMEOUT_MS },
					);
					await mkdir(runDir, { recursive: true, mode: 0o700 });
					const promptPath = path.join(runDir, "task.md");
					const sessionDir = path.join(runDir, "session");
					await mkdir(sessionDir, { recursive: true, mode: 0o700 });
					await writeFile(promptPath, `# Delegated task\n\n${params.task}\n`, {
						encoding: "utf8",
						mode: 0o600,
					});
					// Seed a valid empty session, then open its path. --session-id searches first
					// and warns for every new id. Do not append through this manager after writing.
					const session = SessionManager.create(cwd, sessionDir, {
						id: childSessionId,
					});
					const sessionFile = session.getSessionFile();
					await writeJsonAtomic(sessionFile, session.getHeader());
					await writeJsonAtomic(attachmentPath(childSessionId), {
						version: 1,
						address: spec.kittyAddress,
						sessionFile,
						cwd,
						trusted: spec.trusted,
					});

					const piArgs = [
						...getPiInvocationParts(),
						"--provider",
						selectedModel.provider,
						"--model",
						selectedModel.model,
						"--thinking",
						thinking,
						"--session-dir",
						sessionDir,
						"--session",
						sessionFile,
						"--name",
						kittySession,
						spec.trusted ? "--approve" : "--no-approve",
						"--extension",
						EXTENSION_PATH,
						`@${promptPath}`,
					];
					// Load the configured shell's interactive startup files, as a normal Kitty shell does.
					// Keep failures inspectable with --hold; the parent closes successful runs.
					// Record exit separately so it can wait for Pi's graceful shutdown first.
					const childCommand = [
						shell,
						"-i",
						...shellArgs,
						'exit_file=$1; shift; "$@"; status=$?; printf "%s\\n" "$status" > "$exit_file"; exit "$status"',
						"pi-subagent",
						exitPath,
						"env",
						`${CHILD_ENV}=1`,
						`${RESULT_ENV}=${resultPath}`,
						`PI_CODING_AGENT_DIR=${getAgentDir()}`,
						...piArgs,
					];

					const startedAt = Date.now();
					let launched = false;
					activeSpec = spec;
					try {
						runSignal.throwIfAborted();
						const created = await launchKitty(pi, {
							type: "tab",
							cwd,
							title: kittySession,
							tabTitle: kittySession,
							copyEnv: true,
							env: { SHELL: shell },
							vars: { pi_subagent: kittySession },
							command: childCommand,
							address: spec.kittyAddress,
							sourceWindowId: spec.kittySourceWindowId,
							keepFocus: true,
							hold: true,
							response: true,
							signal: runSignal,
							timeout: REMOTE_TIMEOUT_MS,
						});
						if (created.code !== 0 || created.killed) {
							throw new Error(
								humanKittyError(
									created.stderr.trim() ||
										"Failed to launch the Kitty subagent.",
								),
							);
						}
						spec.kittyWindowId = Number(created.stdout.trim());
						if (
							!Number.isSafeInteger(spec.kittyWindowId) ||
							spec.kittyWindowId < 1
						) {
							throw new Error(
								"Kitty did not return a valid subagent window id.",
							);
						}
						launched = true;
						const initialDetails = detailsFor(spec, "running", { startedAt });
						onUpdate?.({
							content: [{ type: "text", text: partialText(initialDetails) }],
							details: initialDetails,
						});

						let lastPane = "";
						let lastUpdateAt = startedAt;
						let childResult;
						while (!childResult) {
							runSignal.throwIfAborted();
							const resultJson = await readOptionalFile(resultPath);
							if (resultJson !== undefined) {
								childResult = JSON.parse(resultJson);
								break;
							}

							const paneResult = await pi.exec(
								"env",
								kittyArgs(
									spec.kittyAddress,
									"get-text",
									"--match",
									spec.kittyTarget,
								),
								{ signal: runSignal, timeout: REMOTE_TIMEOUT_MS },
							);
							const pane =
								paneResult.code === 0 && !paneResult.killed
									? trimPane(paneResult.stdout)
									: "";
							const changed = pane && pane !== lastPane;
							if (pane) lastPane = pane;
							// Keep elapsed time moving even when the child's terminal is unchanged.
							if (changed || Date.now() - lastUpdateAt >= 1000) {
								lastUpdateAt = Date.now();
								const details = detailsFor(spec, "running", {
									pane: lastPane,
									startedAt,
								});
								onUpdate?.({
									content: [{ type: "text", text: partialText(details) }],
									details,
								});
							}

							const exitCode = await readOptionalFile(exitPath);
							const windows = await pi.exec(
								"env",
								kittyArgs(spec.kittyAddress, "ls", "--match", spec.kittyTarget),
								{ signal: runSignal, timeout: REMOTE_TIMEOUT_MS },
							);
							const alive =
								windows.code === 0 &&
								!windows.killed &&
								JSON.parse(windows.stdout).some((osWindow) =>
									osWindow.tabs.some((tab) => tab.windows.length > 0),
								);
							if (exitCode !== undefined || !alive) {
								await abortableDelay(100, runSignal);
								const finalJson = await readOptionalFile(resultPath);
								if (finalJson !== undefined) {
									childResult = JSON.parse(finalJson);
									break;
								}
								throw new Error(
									`Child Pi exited or its Kitty window became unavailable before reporting a result.${exitCode !== undefined ? ` Exit code: ${exitCode.trim()}.` : ""}` +
										`\n\n${lastPane || windows.stderr.trim() || "No terminal output."}\n\nAttach: ${spec.attachCommand}`,
								);
							}
							await abortableDelay(POLL_INTERVAL_MS, runSignal);
						}

						const finalPaneResult = await pi.exec(
							"env",
							kittyArgs(
								spec.kittyAddress,
								"get-text",
								"--match",
								spec.kittyTarget,
							),
							{ signal: runSignal, timeout: REMOTE_TIMEOUT_MS },
						);
						runSignal.throwIfAborted();
						const finalPane =
							finalPaneResult.code === 0
								? trimPane(finalPaneResult.stdout)
								: lastPane;
						const status =
							childResult.status === "completed" ? "completed" : "failed";
						let rawOutput = childResult.output.trim();
						if (childResult.status === "failed" && childResult.error?.trim()) {
							rawOutput += `${rawOutput ? "\n\n" : ""}Error: ${childResult.error.trim()}`;
						}
						const output = truncateToolText(rawOutput || "(no text output)");
						const details = detailsFor(spec, status, {
							pane: finalPane,
							output,
							sessionFile: childResult.sessionFile,
							provider: childResult.provider ?? spec.provider,
							model: childResult.model ?? spec.model,
							thinking: childResult.thinking ?? spec.thinking,
							startedAt,
							finishedAt: childResult.finishedAt,
						});
						if (childResult.status === "failed")
							throw new Error(resultText(details));
						const shutdownDeadline = Date.now() + REMOTE_TIMEOUT_MS;
						while (
							(await readOptionalFile(exitPath)) === undefined &&
							Date.now() < shutdownDeadline
						) {
							await abortableDelay(100, runSignal);
						}
						const closed = await pi.exec(
							"env",
							kittyArgs(
								spec.kittyAddress,
								"close-window",
								"--match",
								spec.kittyTarget,
								"--ignore-no-match",
							),
							{ signal: runSignal, timeout: REMOTE_TIMEOUT_MS },
						);
						runSignal.throwIfAborted();
						details.windowClosed = closed.code === 0 && !closed.killed;
						if (!details.windowClosed)
							details.cleanupError =
								closed.stderr.trim() || "Could not close the Kitty window.";
						return {
							content: [{ type: "text", text: resultText(details) }],
							details,
						};
					} catch (error) {
						if (runSignal.aborted || !launched) {
							await pi.exec(
								"env",
								kittyArgs(
									spec.kittyAddress,
									"close-window",
									"--match",
									spec.kittyTarget,
									"--ignore-no-match",
								),
								{ timeout: REMOTE_TIMEOUT_MS },
							);
						}
						throw error;
					} finally {
						if (activeSpec === spec) activeSpec = undefined;
					}
				},
			);
		},

		renderCall(args, theme) {
			const task = args.task?.trim() || "...";
			const firstLine = task.split("\n", 1)[0] ?? task;
			const preview =
				firstLine.length > 100 ? `${firstLine.slice(0, 100)}…` : firstLine;
			let text =
				theme.fg("toolTitle", theme.bold("subagent ")) +
				theme.fg("dim", preview);
			const overrides = [args.provider, args.model, args.thinking].filter(
				Boolean,
			);
			if (overrides.length > 0)
				text += `\n  ${theme.fg("muted", overrides.join(" · "))}`;
			return new Text(text, 0, 0);
		},

		renderResult(result, { expanded, isPartial }, theme) {
			const details = result.details;
			if (!details?.kittySession || !details?.status) {
				const content = result.content.find((part) => part.type === "text");
				return new Text(
					content?.type === "text" ? content.text : "(no output)",
					0,
					0,
				);
			}
			const running =
				isPartial ||
				details.status === "queued" ||
				details.status === "running";
			const label =
				details.status === "queued"
					? "Queued"
					: running
						? "Running"
						: details.status === "completed"
							? "Completed"
							: "Failed";
			const markdown = new Markdown(
				details.output || "",
				0,
				0,
				getMarkdownTheme(),
			);

			return {
				invalidate() {
					markdown.invalidate();
				},
				render(width) {
					if (width <= 0) return [];
					const icon = running
						? theme.fg("warning", details.status === "queued" ? "◦" : "●")
						: details.status === "completed"
							? theme.fg("success", "✓")
							: theme.fg("error", "✗");
					const duration = formatDuration(
						details.startedAt,
						details.finishedAt,
					);
					const summary =
						`${icon} ${theme.fg("toolTitle", theme.bold(label))}` +
						theme.fg(
							"muted",
							`${duration ? ` · ${duration}` : ""} · ${details.model} · ${details.thinking}`,
						);
					const lines = [truncateToWidth(summary, width)];
					lines.push(
						...new Text(theme.fg("accent", details.attachCommand), 0, 0).render(
							width,
						),
					);

					if (expanded) {
						lines.push(
							...new Text(
								theme.fg(
									"dim",
									`Provider: ${details.provider} · Cwd: ${details.cwd}`,
								),
								0,
								0,
							).render(width),
						);
						if (details.sessionFile)
							lines.push(
								...new Text(
									theme.fg("dim", `Session: ${details.sessionFile}`),
									0,
									0,
								).render(width),
							);
					}
					if (running) {
						if (expanded && details.pane) {
							lines.push("", theme.fg("muted", "Terminal preview (cropped)"));
							const available = Math.max(0, width - 2);
							for (const line of details.pane
								.split("\n")
								.slice(-PANE_PREVIEW_LINES)) {
								const text = truncateToWidth(
									stripTerminalSequences(line).replace(/\t/g, "    "),
									available,
								);
								lines.push(
									theme.fg("borderMuted", "│ ") + theme.fg("dim", text),
								);
							}
						} else if (!expanded) {
							lines.push(
								keyHint("app.tools.expand", "for details and terminal preview"),
							);
						}
					} else if (details.output) {
						const body = markdown.render(width);
						lines.push("", ...(expanded ? body : body.slice(0, 8)));
						if (!expanded && body.length > 8)
							lines.push(keyHint("app.tools.expand", "for full result"));
					}
					if (details.windowClosed)
						lines.push("", theme.fg("dim", "Window closed · attach to resume"));
					if (details.cleanupError)
						lines.push(
							...new Text(
								theme.fg("warning", details.cleanupError),
								0,
								0,
							).render(width),
						);
					return lines.map((line) => truncateToWidth(line, width));
				},
			};
		},
	});
}
