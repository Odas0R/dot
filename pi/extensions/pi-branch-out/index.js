import fs from "node:fs";
import path from "node:path";
import { complete } from "@earendil-works/pi-ai/compat";
import {
	BorderedLoader,
	convertToLlm,
	serializeConversation,
} from "@earendil-works/pi-coding-agent";
import { humanKittyError, launchKitty } from "../shared/kitty.js";
import { errorMessage, exec } from "../shared/shell.js";

const BRANCH_PREFIX = "agent/";

const SYSTEM_PROMPT = `You are preparing a scoped implementation handoff from an orchestrating coding-agent session to a branch agent.

Given the current conversation, repository state, and requested task, write a self-contained implementation prompt with these sections when relevant:
- Responsibility: the branch's single clear task.
- Context: only findings and decisions needed for that task.
- Requirements and acceptance criteria.
- Constraints and shared contracts that must not change.
- Out of scope.
- Relevant files, commands, tests, docs, issues, PRs, or URLs.
- Required validation.

Requirements:
- Preserve established decisions and exact technical details.
- Keep the task independent and within the requested scope.
- Clearly distinguish fixed shared contracts from local implementation choices.
- Do not duplicate large artifacts; reference paths or URLs instead.
- Redact secrets, API keys, tokens, passwords, and private personal data.
- Be concise, but include enough context that the branch agent does not need the old conversation.
- Output only the implementation prompt, with no preamble.`;

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

	return slug || "task";
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

function canonicalPath(value) {
	return fs.realpathSync.native(value);
}

async function getRepoContext(cwd) {
	const topLevel = canonicalPath(
		(await exec("git", ["rev-parse", "--show-toplevel"], { cwd })).stdout.trim(),
	);
	const canonicalCwd = canonicalPath(cwd);
	const branch = (await exec("git", ["branch", "--show-current"], { cwd, allowFailure: true })).stdout.trim();
	const head = (await exec("git", ["rev-parse", "HEAD"], { cwd })).stdout.trim();
	const shortHead = (await exec("git", ["rev-parse", "--short", "HEAD"], { cwd })).stdout.trim();
	const status = (await exec("git", ["status", "--porcelain"], { cwd: topLevel })).stdout.trim();

	return {
		topLevel,
		repoName: path.basename(topLevel),
		branch,
		head,
		shortHead,
		status,
		isDirty: status.length > 0,
		relativeCwd: path.relative(topLevel, canonicalCwd),
	};
}

function parseArgs(rawArgs) {
	let rest = String(rawArgs || "").trim();
	let copyEnv;

	while (rest) {
		const match = rest.match(/^(--env|--no-env)(?=\s|$)/);
		if (!match) break;
		copyEnv = match[1] === "--env";
		rest = rest.slice(match[0].length).trimStart();
	}

	if (rest === "--") {
		rest = "";
	} else if (rest.startsWith("-- ")) {
		rest = rest.slice(3);
	} else if (rest.startsWith("-")) {
		throw new Error(`Unknown option '${rest.split(/\s+/, 1)[0]}'`);
	}

	return { copyEnv, goal: rest.trim() };
}

function fallbackPrompt(goal, repo) {
	return `## Responsibility
${goal}

## Context
This branch starts from ${repo.branch} at ${repo.shortHead} in ${repo.repoName}.

## Acceptance criteria
- Implement only the stated responsibility.
- Run the relevant validation and report the results.`;
}

async function generateHandoffPrompt(ctx, goal, repo) {
	const messages = ctx.sessionManager.buildSessionContext().messages;
	if (messages.length === 0) return fallbackPrompt(goal, repo);
	if (!ctx.model) throw new Error("No model selected");

	const conversationText = serializeConversation(convertToLlm(messages));
	const repoText = [
		`cwd: ${ctx.cwd}`,
		`repo root: ${repo.topLevel}`,
		`repo: ${repo.repoName}`,
		`source branch: ${repo.branch}`,
		`source HEAD: ${repo.head}`,
	].join("\n");

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
								text: `## Requested branch task\n\n${goal}\n\n## Repository state\n\n${repoText}\n\n## Current conversation\n\n${conversationText}`,
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

		if (response.stopReason === "aborted") return null;
		if (response.stopReason === "error") {
			throw new Error(response.errorMessage || "Handoff generation failed");
		}

		const text = responseText(response);
		if (!text) throw new Error("Handoff generation returned an empty prompt");
		return text;
	});
}

function makeWorktreePlan(goal) {
	const slug = slugify(goal, 36);
	const branchName = `${BRANCH_PREFIX}${slug}`;
	return {
		branchName,
		title: `pi: ${slug}`,
		worktreePath: undefined,
		cwd: undefined,
	};
}

async function createWorktree(ctx, copyEnv, branchName, baseHead) {
	const args = ["new", branchName, baseHead];
	if (copyEnv) args.push("--env");

	const result = await exec(getWtCommand(), args, { cwd: ctx.cwd });
	const lines = result.stdout
		.trim()
		.split(/\r?\n/)
		.filter(Boolean);
	if (lines.length !== 1) {
		throw new Error("wt new did not print exactly one worktree path");
	}
	return lines[0];
}

function buildFinalPrompt(prompt, plan, repo, copyEnv) {
	return `${prompt.trim()}

---

## Branch rules

- You own only the responsibility and acceptance criteria above.
- Do not broaden the task or improve unrelated code.
- Treat shared contracts and constraints as fixed. If one must change, stop and report that scope change to the orchestrating agent.
- Keep local implementation discoveries in this branch when they do not alter scope or shared contracts.
- Run the relevant validation for every change you make.
- When implementation and validation are complete, stop and wait for manual review.
- Before manual review, do not push, rebase, merge, open a PR, post GitHub comments, close issues, or remove this worktree.

## Branch-out execution notes

- Worktree: ${plan.worktreePath}
- Branch: ${plan.branchName}
- Source worktree: ${repo.topLevel}
- Source branch: ${repo.branch}
- Source HEAD: ${repo.head}
- .env files copied: ${copyEnv ? "yes" : "no"}`;
}

function childWorkingDirectory(plan, repo) {
	if (!repo.relativeCwd) return plan.worktreePath;
	const candidate = path.join(plan.worktreePath, repo.relativeCwd);
	return fs.existsSync(candidate) ? candidate : plan.worktreePath;
}

async function openPiInKitty(plan, prompt, sessionName, model, thinkingLevel, sourceBranch) {
	const piArgs = [
		"--name",
		sessionName,
		"--provider",
		model.provider,
		"--model",
		model.id,
		"--thinking",
		thinkingLevel,
		prompt,
	];
	const invocation = getPiInvocation(piArgs);

	await launchKitty({
		type: "tab",
		cwd: plan.cwd,
		title: plan.title,
		tabTitle: plan.title,
		copyEnv: true,
		env: {
			PI_BRANCH_OUT: "1",
			PI_BRANCH_OUT_BRANCH: plan.branchName,
			PI_BRANCH_OUT_SOURCE_BRANCH: sourceBranch,
		},
		command: [invocation.command, ...invocation.args],
	});
}

function sourceChanged(original, current) {
	return (
		original.topLevel !== current.topLevel ||
		original.branch !== current.branch ||
		original.head !== current.head ||
		current.isDirty
	);
}

/** @param {import("@earendil-works/pi-coding-agent").ExtensionAPI} pi */
export default function branchOutExtension(pi) {
	pi.registerCommand("branch-out", {
		description: "Create a scoped agent branch in a new git worktree and Pi tab",
		getArgumentCompletions: (prefix) => {
			const examples = ["--env implement the next task", "--no-env implement the next task"];
			const filtered = examples.filter((item) => item.startsWith(prefix));
			return filtered.length > 0 ? filtered.map((value) => ({ value, label: value })) : null;
		},
		handler: async (args, ctx) => {
			if (ctx.mode !== "tui") {
				ctx.ui.notify("/branch-out requires interactive TUI mode", "error");
				return;
			}
			if (process.env.PI_BRANCH_OUT === "1") {
				ctx.ui.notify("Nested /branch-out is not allowed", "error");
				return;
			}

			await ctx.waitForIdle();

			let parsed;
			try {
				parsed = parseArgs(args);
			} catch (error) {
				ctx.ui.notify(errorMessage(error), "error");
				return;
			}

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

			if (!repo.branch) {
				ctx.ui.notify("/branch-out requires a named source branch", "error");
				return;
			}
			if (repo.branch.startsWith(BRANCH_PREFIX)) {
				ctx.ui.notify(`Nested /branch-out is not allowed from ${repo.branch}`, "error");
				return;
			}
			if (repo.isDirty) {
				ctx.ui.notify("/branch-out requires a clean source worktree", "error");
				return;
			}
			if (!ctx.model) {
				ctx.ui.notify("No model selected", "error");
				return;
			}

			const copyEnv =
				parsed.copyEnv ??
				(await ctx.ui.confirm("Copy .env files?", "Copy .env files into the new branch worktree?"));

			let generatedPrompt;
			try {
				generatedPrompt = await generateHandoffPrompt(ctx, goal, repo);
			} catch (error) {
				ctx.ui.notify(errorMessage(error), "error");
				return;
			}

			const editedPrompt = await ctx.ui.editor("Edit branch-out prompt", generatedPrompt);
			if (editedPrompt === undefined) {
				ctx.ui.notify("Cancelled", "info");
				return;
			}
			if (!editedPrompt.trim()) {
				ctx.ui.notify("Cancelled: prompt was empty", "info");
				return;
			}

			let currentRepo;
			try {
				currentRepo = await getRepoContext(ctx.cwd);
			} catch (error) {
				ctx.ui.notify(`Could not recheck source worktree: ${errorMessage(error)}`, "error");
				return;
			}
			if (sourceChanged(repo, currentRepo)) {
				ctx.ui.notify("Source branch, HEAD, or worktree changed while preparing the handoff; run /branch-out again", "error");
				return;
			}

			const plan = makeWorktreePlan(goal);
			const sessionName = `branch-out: ${plan.branchName.slice(BRANCH_PREFIX.length)}`.slice(0, 80);
			let finalPrompt;

			try {
				plan.worktreePath = await createWorktree(ctx, copyEnv, plan.branchName, repo.head);
				plan.cwd = childWorkingDirectory(plan, repo);
				finalPrompt = buildFinalPrompt(editedPrompt, plan, repo, copyEnv);
			} catch (error) {
				ctx.ui.notify(`Failed to create branch-out worktree: ${errorMessage(error)}`, "error");
				return;
			}

			try {
				await openPiInKitty(plan, finalPrompt, sessionName, ctx.model, ctx.thinkingLevel, repo.branch);
				ctx.ui.notify(`Launched ${plan.branchName} in ${plan.cwd}`, "info");
			} catch (error) {
				ctx.ui.notify(
					`${humanKittyError(errorMessage(error))}\nWorktree remains at ${plan.worktreePath}`,
					"error",
				);
			}
		},
	});
}
