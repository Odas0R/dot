import fs from "node:fs";
import path from "node:path";
import { complete } from "@earendil-works/pi-ai/compat";
import {
	BorderedLoader,
	convertToLlm,
	serializeConversation,
} from "@earendil-works/pi-coding-agent";
import { humanKittyError, launchKitty } from "./lib/kitty.js";
import { errorMessage, exec } from "./lib/shell.js";

const SYSTEM_PROMPT = `You are preparing a context handoff for a fresh coding-agent session.

Given the current conversation, repository state, and the user's goal, write a self-contained prompt that the new agent can execute immediately in a fresh git worktree.

Requirements:
- Preserve decisions, constraints, relevant findings, and next steps.
- List relevant files, commands, tests, docs, branches, issues, or URLs mentioned.
- Clearly state the exact implementation task to perform now.
- Mention any suggested skills the new agent should invoke, if relevant.
- Do not duplicate large artifacts; reference paths/URLs instead.
- Redact secrets, API keys, tokens, passwords, and private personal data.
- Be concise, but include enough context that the new session does not need the old conversation.
- Output only the prompt, with no preamble.`;

const TITLE_SYSTEM_PROMPT = `Generate a short title for a coding-agent branch-out session.

Rules:
- 2 to 5 words
- lowercase kebab-case
- max 36 characters
- no quotes
- no prefix like "pi" or "branch"
- return only the title.`;

const TITLE_MODEL_PROVIDER = "openai-codex";
const TITLE_MODEL_ID = "gpt-5.5";

function slugify(value, maxLength = 48) {
	const slug = String(value)
		.toLowerCase()
		.normalize("NFKD")
		.replace(/[\u0300-\u036f]/g, "")
		.replace(/[^a-z0-9._-]+/g, "-")
		.replace(/-+/g, "-")
		.replace(/^[.-]+|[.-]+$/g, "")
		.slice(0, maxLength)
		.replace(/[.-]+$/g, "");

	return slug || "handoff";
}

function getWtCommand() {
	return process.env.PI_BRANCH_OUT_WT || "wt";
}

function getPiInvocation(args) {
	const scriptPath = process.argv[1];
	if (scriptPath && fs.existsSync(scriptPath)) {
		return { command: process.execPath, args: [scriptPath, ...args] };
	}

	return { command: "pi", args };
}

function responseText(response) {
	return response.content
		.filter((part) => part.type === "text")
		.map((part) => part.text)
		.join("\n")
		.trim();
}

async function withLoader(ctx, message, task) {
	let taskError;
	const result = await ctx.ui.custom((tui, theme, _kb, done) => {
		const loader = new BorderedLoader(tui, theme, message);
		loader.onAbort = () => done(null);
		task(loader.signal)
			.then(done)
			.catch((error) => {
				taskError = error;
				done(null);
			});
		return loader;
	});

	if (result !== null) return result;
	if (taskError) throw taskError;
	throw new Error(`${message.replace(/\.+$/, "")} cancelled`);
}

function entryToMessage(entry) {
	if (entry.type === "message") return entry.message;
	if (entry.type === "compaction") {
		return {
			role: "compactionSummary",
			summary: entry.summary,
			tokensBefore: entry.tokensBefore,
			timestamp: new Date(entry.timestamp).getTime(),
		};
	}
	return undefined;
}

function getHandoffMessages(branch) {
	let compactionIndex = -1;
	for (let i = branch.length - 1; i >= 0; i -= 1) {
		if (branch[i].type === "compaction") {
			compactionIndex = i;
			break;
		}
	}

	if (compactionIndex < 0) {
		return branch.map(entryToMessage).filter(Boolean);
	}

	const compaction = branch[compactionIndex];
	const firstKeptIndex =
		compaction.type === "compaction"
			? branch.findIndex((entry) => entry.id === compaction.firstKeptEntryId)
			: -1;
	const compactedBranch = [
		compaction,
		...(firstKeptIndex >= 0 ? branch.slice(firstKeptIndex, compactionIndex) : []),
		...branch.slice(compactionIndex + 1),
	];

	return compactedBranch.map(entryToMessage).filter(Boolean);
}

async function getRepoContext(cwd) {
	const topLevel = (await exec("git", ["rev-parse", "--show-toplevel"], { cwd })).stdout.trim();
	const branch = (await exec("git", ["branch", "--show-current"], { cwd, allowFailure: true })).stdout.trim();
	const head = (await exec("git", ["rev-parse", "--short", "HEAD"], { cwd })).stdout.trim();
	const status = (await exec("git", ["status", "--porcelain"], { cwd })).stdout.trim();
	const untracked = (await exec("git", ["ls-files", "--others", "--exclude-standard"], { cwd })).stdout
		.trim()
		.split(/\r?\n/)
		.filter(Boolean);

	return {
		topLevel,
		repoName: path.basename(topLevel),
		branch,
		head,
		status,
		isDirty: status.length > 0,
		untracked,
	};
}

function parseArgs(rawArgs) {
	const tokens = rawArgs.match(/(?:[^\s"']+|"[^"]*"|'[^']*')+/g) ?? [];
	const flags = {
		copyEnv: undefined,
		applyDiff: undefined,
	};
	const goalParts = [];

	for (const token of tokens) {
		const unquoted = token.replace(/^(["'])(.*)\1$/, "$2");
		if (unquoted === "--env") {
			flags.copyEnv = true;
			continue;
		}
		if (unquoted === "--no-env") {
			flags.copyEnv = false;
			continue;
		}
		if (unquoted === "--apply-diff") {
			flags.applyDiff = true;
			continue;
		}
		if (unquoted === "--no-diff") {
			flags.applyDiff = false;
			continue;
		}
		goalParts.push(unquoted);
	}

	return { ...flags, goal: goalParts.join(" ").trim() };
}

async function selectDirtyBehavior(ctx, repo, parsed) {
	if (!repo.isDirty) return "clean";
	if (parsed.applyDiff === true) return "apply";
	if (parsed.applyDiff === false) return "ignore";

	const choice = await ctx.ui.select("Current git worktree is dirty. Include changes?", [
		"Apply tracked diff to the new worktree",
		"Start new worktree from HEAD only",
		"Cancel",
	]);

	if (choice === "Apply tracked diff to the new worktree") return "apply";
	if (choice === "Start new worktree from HEAD only") return "ignore";
	return "cancel";
}

async function generateHandoffPrompt(ctx, goal, repo, dirtyBehavior) {
	const messages = getHandoffMessages(ctx.sessionManager.getBranch());
	if (messages.length === 0) {
		return `## Context\nThis is a new branch-out session from ${repo.repoName} at ${repo.head}.\n\n## Task\n${goal}\n\nExecute the task in this worktree. Inspect the repository first, make the necessary changes, and summarize what changed and how you verified it.`;
	}

	if (!ctx.model) {
		throw new Error("No model selected");
	}

	const llmMessages = convertToLlm(messages);
	const conversationText = serializeConversation(llmMessages);
	const repoText = [
		`cwd: ${ctx.cwd}`,
		`repo root: ${repo.topLevel}`,
		`repo: ${repo.repoName}`,
		`branch: ${repo.branch || "(detached)"}`,
		`HEAD: ${repo.head}`,
		`dirty: ${repo.isDirty ? "yes" : "no"}`,
		repo.isDirty ? `dirty handoff behavior: ${dirtyBehavior}` : undefined,
		repo.untracked.length > 0
			? `untracked files present in original worktree: ${repo.untracked.slice(0, 20).join(", ")}${repo.untracked.length > 20 ? ", ..." : ""}`
			: undefined,
	]
		.filter(Boolean)
		.join("\n");

	return withLoader(ctx, "Generating branch-out handoff prompt...", async (signal) => {
		const auth = await ctx.modelRegistry.getApiKeyAndHeaders(ctx.model);
		if (!auth.ok || !auth.apiKey) {
			throw new Error(auth.ok ? `No API key for ${ctx.model.provider}` : auth.error);
		}

		const response = await complete(
			ctx.model,
			{
				systemPrompt: SYSTEM_PROMPT,
				messages: [
					{
						role: "user",
						content: [
							{
								type: "text",
								text: `## User goal for new session\n\n${goal}\n\n## Repository state\n\n${repoText}\n\n## Current conversation\n\n${conversationText}`,
							},
						],
						timestamp: Date.now(),
					},
				],
			},
			{
				apiKey: auth.apiKey,
				headers: auth.headers,
				env: auth.env,
				signal,
			},
		);

		return response.stopReason === "aborted" ? null : responseText(response);
	});
}

function normalizeGeneratedTitle(text, fallback) {
	const firstLine = String(text || "")
		.split(/\r?\n/)
		.map((line) => line.trim())
		.find(Boolean);
	const withoutPrefix = (firstLine || "").replace(/^title\s*:\s*/i, "").trim();
	return withoutPrefix ? slugify(withoutPrefix, 36) : slugify(fallback, 36);
}

async function generateBranchTitle(ctx, goal, prompt, repo) {
	const fallback = slugify(goal, 36);
	const model = ctx.modelRegistry.find(TITLE_MODEL_PROVIDER, TITLE_MODEL_ID);
	if (!model) return fallback;

	try {
		const auth = await ctx.modelRegistry.getApiKeyAndHeaders(model);
		if (!auth.ok || !auth.apiKey) return fallback;

		const result = await withLoader(ctx, "Generating branch-out title...", async (signal) => {
			const response = await complete(
				model,
				{
					systemPrompt: TITLE_SYSTEM_PROMPT,
					messages: [
						{
							role: "user",
							content: [
								{
									type: "text",
									text: `Repo: ${repo.repoName}\nGoal: ${goal}\n\nHandoff prompt excerpt:\n${prompt.slice(0, 4000)}`,
								},
							],
							timestamp: Date.now(),
						},
					],
				},
				{
					apiKey: auth.apiKey,
					headers: auth.headers,
					env: auth.env,
					reasoningEffort: "low",
					signal,
				},
			);

			return response.stopReason === "aborted" ? null : responseText(response);
		});

		return normalizeGeneratedTitle(result, fallback);
	} catch (error) {
		console.error("Branch-out title generation failed:", error);
		return fallback;
	}
}

function makeWorktreePlan(title) {
	return { worktreePath: undefined, title: `pi: ${slugify(title, 36)}` };
}

async function createWorktree(ctx, copyEnv) {
	const args = ["tmp"];
	if (copyEnv) args.push("--env");
	const result = await exec(getWtCommand(), args, { cwd: ctx.cwd });
	const worktreePath = result.stdout
		.trim()
		.split(/\r?\n/)
		.filter(Boolean)
		.at(-1);
	if (!worktreePath) {
		throw new Error("wt tmp did not print a worktree path");
	}
	return worktreePath;
}

async function applyTrackedDiff(ctx, worktreePath) {
	const diff = (await exec("git", ["diff", "--binary", "HEAD"], { cwd: ctx.cwd })).stdout;
	if (!diff.trim()) return false;

	await exec("git", ["apply", "--binary", "-"], { cwd: worktreePath, input: diff });
	return true;
}

function buildFinalPrompt(prompt, plan, repo, dirtyBehavior, diffApplied, copyEnv) {
	const notes = [
		"",
		"---",
		"",
		"## Branch-out execution notes",
		`- Temporary worktree: ${plan.worktreePath}`,
		"- This worktree starts detached; no branch has been created yet.",
		`- Parent repo: ${repo.topLevel}`,
		`- Parent branch: ${repo.branch || "(detached)"}`,
		`- Parent HEAD: ${repo.head}`,
		`- .env files copied: ${copyEnv ? "yes" : "no"}`,
	];

	if (dirtyBehavior === "apply") {
		notes.push(`- Tracked uncommitted diff applied to this worktree: ${diffApplied ? "yes" : "no tracked diff found"}`);
		if (repo.untracked.length > 0) {
			notes.push(
				`- Original worktree had untracked files that were not copied: ${repo.untracked.slice(0, 20).join(", ")}${repo.untracked.length > 20 ? ", ..." : ""}`,
			);
		}
	} else if (dirtyBehavior === "ignore") {
		notes.push("- Original worktree had uncommitted changes, but this temporary worktree starts from HEAD only.");
	}

	return `${prompt.trim()}\n${notes.join("\n")}`;
}

async function openPiInKitty(plan, prompt, sessionName) {
	const invocation = getPiInvocation(["--name", sessionName, prompt]);

	await launchKitty({
		type: "tab",
		cwd: plan.worktreePath,
		title: plan.title,
		tabTitle: plan.title,
		copyEnv: true,
		command: [invocation.command, ...invocation.args],
	});
}

/** @param {import("@earendil-works/pi-coding-agent").ExtensionAPI} pi */
export default function branchOutExtension(pi) {
	pi.registerCommand("branch-out", {
		description: "Create a handoff prompt, temporary git worktree, and new Kitty Pi tab",
		getArgumentCompletions: (prefix) => {
			const examples = [
				"--env implement the next slice",
				"--apply-diff continue this refactor in parallel",
				"--no-diff explore an alternative from HEAD",
			];
			const filtered = examples.filter((item) => item.startsWith(prefix));
			return filtered.length > 0 ? filtered.map((value) => ({ value, label: value })) : null;
		},
		handler: async (args, ctx) => {
			if (ctx.mode !== "tui") {
				ctx.ui.notify("/branch-out requires interactive TUI mode", "error");
				return;
			}

			await ctx.waitForIdle();

			const parsed = parseArgs(args);
			let goal = parsed.goal;
			if (!goal) {
				const input = await ctx.ui.input("Goal for the new branch-out session", "Implement ...");
				if (!input?.trim()) {
					ctx.ui.notify("Cancelled", "info");
					return;
				}
				goal = input.trim();
			}

			let repo;
			try {
				repo = await getRepoContext(ctx.cwd);
			} catch (error) {
				ctx.ui.notify(`Not inside a git worktree: ${errorMessage(error)}`, "error");
				return;
			}

			const dirtyBehavior = await selectDirtyBehavior(ctx, repo, parsed);
			if (dirtyBehavior === "cancel") {
				ctx.ui.notify("Cancelled", "info");
				return;
			}

			const copyEnv =
				parsed.copyEnv ??
				(await ctx.ui.confirm("Copy .env files?", "Copy .env files from the current worktree into the new temporary worktree?"));

			let generatedPrompt;
			try {
				generatedPrompt = await generateHandoffPrompt(ctx, goal, repo, dirtyBehavior);
			} catch (error) {
				ctx.ui.notify(errorMessage(error), "error");
				return;
			}

			const title = await generateBranchTitle(ctx, goal, generatedPrompt, repo);
			const plan = makeWorktreePlan(title);
			const sessionName = `branch-out: ${title}`.slice(0, 80);
			let diffApplied = false;
			let finalPrompt;

			try {
				plan.worktreePath = await createWorktree(ctx, copyEnv);
				if (dirtyBehavior === "apply") {
					diffApplied = await applyTrackedDiff(ctx, plan.worktreePath);
				}

				finalPrompt = buildFinalPrompt(generatedPrompt, plan, repo, dirtyBehavior, diffApplied, copyEnv);
			} catch (error) {
				ctx.ui.notify(`Failed to prepare branch-out worktree: ${errorMessage(error)}`, "error");
				return;
			}

			try {
				await openPiInKitty(plan, finalPrompt, sessionName);
				ctx.ui.notify(`Launched ${plan.title} in ${plan.worktreePath}`, "info");
			} catch (error) {
				ctx.ui.notify(humanKittyError(errorMessage(error)), "error");
			}
		},
	});
}
