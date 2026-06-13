import { spawn } from "node:child_process";
import { readFile, writeFile } from "node:fs/promises";
import { join } from "node:path";

function ensureSafeExArgs(args) {
	const trimmed = args.trim();
	if (/[\r\n|]/.test(trimmed)) {
		throw new Error("Arguments cannot contain newlines or |.");
	}
	return trimmed;
}

function exec(command, args) {
	return new Promise((resolve, reject) => {
		const child = spawn(command, args, {
			stdio: ["ignore", "pipe", "pipe"],
		});

		let stdout = "";
		let stderr = "";
		child.stdout.on("data", (chunk) => {
			stdout += String(chunk);
		});
		child.stderr.on("data", (chunk) => {
			stderr += String(chunk);
		});
		child.on("error", reject);
		child.on("close", (code) => {
			if (code === 0) {
				resolve();
				return;
			}

			reject(new Error((stderr || stdout || `${command} exited with ${code}`).trim()));
		});
	});
}

async function openDiffviewInKittyOverlay(cwd, diffArgs) {
	const command = diffArgs ? `DiffviewOpen --imply-local ${diffArgs}` : "DiffviewOpen --imply-local";
	const listenOn = process.env.PI_KITTY_LISTEN_ON || process.env.KITTY_LISTEN_ON;
	const launchArgs = ["@"];

	if (listenOn) {
		launchArgs.push("--to", listenOn);
	}

	launchArgs.push(
		"launch",
		"--type=overlay",
		"--cwd",
		cwd,
		"--copy-env",
		"--title",
		"Pi review diff",
	);

	if (process.env.KITTY_WINDOW_ID) {
		launchArgs.push("--self");
	}

	launchArgs.push("nvim", "-c", command);
	await exec("kitty", launchArgs);
}

/** @param {import("@earendil-works/pi-coding-agent").ExtensionAPI} pi */
export default function piReviewExtension(pi) {
	pi.registerCommand("review-diff", {
		description: "Open diffview-plus.nvim in a kitty overlay pane for this repo",
		getArgumentCompletions: (prefix) => {
			const examples = ["", "origin/main...HEAD", "HEAD~1", "--cached", "-- ."];
			const filtered = examples.filter((item) => item.startsWith(prefix));
			return filtered.length > 0 ? filtered.map((value) => ({ value, label: value || "working tree" })) : null;
		},
		handler: async (args, ctx) => {
			try {
				const diffArgs = ensureSafeExArgs(args);
				await openDiffviewInKittyOverlay(ctx.cwd, diffArgs);
				ctx.ui.notify("Opened Diffview in a kitty overlay pane", "info");
			} catch (error) {
				const message = error instanceof Error ? error.message : String(error);
				ctx.ui.notify(
					message.includes("Remote control is disabled")
						? "Kitty remote control is disabled. Add `allow_remote_control yes` to kitty.conf, then fully restart kitty. If Pi is not running in a kitty-controlled TTY, set PI_KITTY_LISTEN_ON to a socket started with kitty --listen-on."
						: message,
					"error",
				);
			}
		},
	});

	pi.registerCommand("review-clean", {
		description: "Clear .pi/review.md after review comments are no longer needed",
		getArgumentCompletions: (prefix) => ("--force".startsWith(prefix) ? [{ value: "--force", label: "--force" }] : null),
		handler: async (args, ctx) => {
			const reviewPath = join(ctx.cwd, ".pi", "review.md");
			let text;

			try {
				text = await readFile(reviewPath, "utf8");
			} catch {
				ctx.ui.notify("No .pi/review.md file found", "info");
				return;
			}

			if (text.trim() === "") {
				ctx.ui.notify(".pi/review.md is already clean", "info");
				return;
			}

			if (!args.trim().includes("--force")) {
				const ok = await ctx.ui.confirm(
					"Clear review comments?",
					"This will empty .pi/review.md. Use /review-apply first if any comments still need implementation.",
				);
				if (!ok) {
					return;
				}
			}

			await writeFile(reviewPath, "", "utf8");
			ctx.ui.notify("Cleared .pi/review.md", "info");
		},
	});

	pi.registerCommand("review-apply", {
		description: "Send unchecked .pi/review.md comments to Pi for implementation",
		handler: async (_args, ctx) => {
			const reviewPath = join(ctx.cwd, ".pi", "review.md");
			let text;

			try {
				text = await readFile(reviewPath, "utf8");
			} catch {
				ctx.ui.notify("No .pi/review.md file found. Add comments from Diffview with <leader>c.", "warning");
				return;
			}

			const unchecked = text
				.split("\n")
				.filter((line) => /^\s*- \[ \]/.test(line))
				.length;

			if (unchecked === 0) {
				ctx.ui.notify("No unchecked review comments found in .pi/review.md", "info");
				return;
			}

			const message = [
				"Apply every unchecked review comment in `.pi/review.md`.",
				"Preserve checked comments. Mark an item checked only after you have fixed it.",
				"Do not remove reviewer notes unless they are obsolete because of the fix.",
				"",
				text,
			].join("\n");

			if (ctx.isIdle()) {
				pi.sendUserMessage(message);
			} else {
				pi.sendUserMessage(message, { deliverAs: "followUp" });
				ctx.ui.notify("Queued review comments as a follow-up", "info");
			}
		},
	});
}
