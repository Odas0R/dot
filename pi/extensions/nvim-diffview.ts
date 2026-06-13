import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { spawn } from "node:child_process";
import { mkdir, readFile } from "node:fs/promises";
import { join } from "node:path";

function vimString(value: string): string {
	return `'${value.replace(/'/g, "''")}'`;
}

function ensureSafeDiffviewArgs(args: string): string {
	const trimmed = args.trim();
	if (/[\r\n|]/.test(trimmed)) {
		throw new Error("Diffview arguments cannot contain newlines or |.");
	}
	return trimmed;
}

function nvimRemote(server: string, expr: string): Promise<void> {
	return new Promise((resolve, reject) => {
		const child = spawn("nvim", ["--server", server, "--remote-expr", expr], {
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

			reject(new Error((stderr || stdout || `nvim exited with ${code}`).trim()));
		});
	});
}

async function openInParentNvim(cwd: string, exCommand: string): Promise<void> {
	const server = process.env.NVIM;
	if (!server) {
		throw new Error("$NVIM is not set; run pi inside a Neovim terminal or start Neovim with --listen.");
	}

	const expr = `execute('tcd ' . fnameescape(${vimString(cwd)}) . ' | ' . ${vimString(exCommand)})`;
	await nvimRemote(server, expr);
}

export default function nvimDiffviewExtension(pi: ExtensionAPI) {
	pi.registerCommand("diffview", {
		description: "Open diffview-plus.nvim in the parent Neovim server for this repo",
		getArgumentCompletions: (prefix) => {
			const examples = ["", "origin/main...HEAD", "HEAD~1", "--cached", "-- ."];
			const filtered = examples.filter((item) => item.startsWith(prefix));
			return filtered.length > 0 ? filtered.map((value) => ({ value, label: value || "working tree" })) : null;
		},
		handler: async (args, ctx) => {
			try {
				const diffArgs = ensureSafeDiffviewArgs(args);
				const command = diffArgs ? `DiffviewOpen --imply-local ${diffArgs}` : "DiffviewOpen --imply-local";
				await openInParentNvim(ctx.cwd, command);
				ctx.ui.notify("Opened Diffview in parent Neovim", "info");
			} catch (error) {
				ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
			}
		},
	});

	pi.registerCommand("review-open", {
		description: "Open .pi/review.md in the parent Neovim server",
		handler: async (_args, ctx) => {
			try {
				await mkdir(join(ctx.cwd, ".pi"), { recursive: true });
				await openInParentNvim(ctx.cwd, "edit .pi/review.md");
				ctx.ui.notify("Opened .pi/review.md", "info");
			} catch (error) {
				ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
			}
		},
	});

	pi.registerCommand("review-apply", {
		description: "Send unchecked .pi/review.md comments to Pi for implementation",
		handler: async (_args, ctx) => {
			const reviewPath = join(ctx.cwd, ".pi", "review.md");
			let text: string;

			try {
				text = await readFile(reviewPath, "utf8");
			} catch {
				ctx.ui.notify("No .pi/review.md file found. Add comments from Neovim with <leader>pc.", "warning");
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
