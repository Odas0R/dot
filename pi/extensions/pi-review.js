import { spawn } from "node:child_process";
import { randomUUID } from "node:crypto";
import { createServer } from "node:net";

function ensureSafeExArgs(args) {
	const trimmed = args.trim();
	if (/[\r\n|]/.test(trimmed)) {
		throw new Error("Arguments cannot contain newlines or |.");
	}
	return trimmed;
}

function exec(command, args, options = {}) {
	return new Promise((resolve, reject) => {
		const child = spawn(command, args, {
			...(options.env ? { env: options.env } : {}),
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

			reject(
				new Error(
					(stderr || stdout || `${command} exited with ${code}`).trim(),
				),
			);
		});
	});
}

function listen(server) {
	return new Promise((resolve, reject) => {
		const onError = (error) => {
			server.off("listening", onListening);
			reject(error);
		};
		const onListening = () => {
			server.off("error", onError);
			resolve();
		};

		server.once("error", onError);
		server.once("listening", onListening);
		server.listen(0, "127.0.0.1");
	});
}

function serverAddress(server) {
	const address = server.address();
	if (!address || typeof address === "string") {
		throw new Error("Pi review bridge did not get a TCP port");
	}
	return `${address.address}:${address.port}`;
}

function close(server) {
	return new Promise((resolve) => {
		server.close(() => resolve());
	});
}

function safeFenceLanguage(filetype) {
	return String(filetype || "").replace(/[^\w#+.-]/g, "");
}

function markdownCodeFence(code, filetype) {
	let longestRun = 0;
	for (const match of String(code).matchAll(/`+/g)) {
		longestRun = Math.max(longestRun, match[0].length);
	}

	const fence = "`".repeat(Math.max(3, longestRun + 1));
	const language = safeFenceLanguage(filetype);
	return `${fence}${language}\n${code}\n${fence}`;
}

function requiredString(value, name) {
	if (typeof value !== "string" || value.trim() === "") {
		throw new Error(`Review payload is missing ${name}`);
	}
	return value;
}

function optionalString(value) {
	return typeof value === "string" ? value : "";
}

function normalizeReviewComment(payload, index) {
	if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
		throw new Error(`Review comment ${index + 1} must be a JSON object`);
	}

	const label = `review comment ${index + 1}`;
	const scope = payload.scope === "file" ? "file" : "lines";
	const file = requiredString(payload.file, `${label} file`);
	const comment = requiredString(payload.comment, `${label} comment`).trim();
	const location = optionalString(payload.location).trim() || file;
	const filetype = optionalString(payload.filetype).trim();
	const code = optionalString(payload.code);
	const id = Number.isInteger(payload.id) ? payload.id : undefined;
	const line1 = Number.isInteger(payload.line1) ? payload.line1 : undefined;
	const line2 = Number.isInteger(payload.line2) ? payload.line2 : undefined;

	return { id, scope, file, comment, location, filetype, code, line1, line2 };
}

function normalizeReviewPayload(payload, token) {
	if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
		throw new Error("Review payload must be a JSON object");
	}
	if (payload.token !== token) {
		throw new Error("Review bridge token did not match");
	}

	if (payload.scope === "batch") {
		if (!Array.isArray(payload.comments)) {
			throw new Error("Review batch payload is missing comments");
		}
		const comments = payload.comments.map((comment, index) =>
			normalizeReviewComment(comment, index),
		);
		if (comments.length === 0) {
			throw new Error("Review batch payload has no comments");
		}
		return { scope: "batch", comments };
	}

	return normalizeReviewComment(payload, 0);
}

function pushReviewCommentPrompt(lines, comment, index) {
	const title = comment.id ? `Comment #${comment.id}` : `Comment ${index + 1}`;
	const locationLabel = comment.scope === "file" ? "File" : "Location";
	lines.push(
		`## ${title}`,
		"",
		`${locationLabel}: \`${comment.location}\`${comment.scope === "file" ? " (entire file)" : ""}`,
		"",
		"Reviewer comment:",
		comment.comment,
	);

	if (comment.scope === "lines" && comment.code.trim() !== "") {
		lines.push(
			"",
			"Selected code:",
			markdownCodeFence(comment.code, comment.filetype),
		);
	}
}

function buildBatchReviewPrompt(payload) {
	const lines = [
		"Apply these code review comments.",
		"",
		`There ${payload.comments.length === 1 ? "is" : "are"} ${payload.comments.length} review ${plural(payload.comments.length, "comment")}.`,
		payload.comments.length === 1
			? "Address it in one pass."
			: "Address all of them in one pass.",
		"",
	];

	payload.comments.forEach((comment, index) => {
		if (index > 0) {
			lines.push("");
		}
		pushReviewCommentPrompt(lines, comment, index);
	});

	lines.push(
		"",
		"Instructions:",
		"- Inspect each file and surrounding context as needed before editing.",
		"- Make the minimal code changes needed to satisfy every review comment.",
		"- If a comment is already satisfied, verify it and mention that in your final response.",
		"- Update tests or docs only if a review comment requires it.",
		"- In your final response, summarize the outcome for each comment number.",
	);

	return lines.join("\n");
}

function buildReviewPrompt(payload) {
	if (payload.scope === "batch") {
		return buildBatchReviewPrompt(payload);
	}

	const intro =
		payload.scope === "file"
			? "Apply this file-level code review comment."
			: "Apply this inline code review comment.";
	const lines = [intro, ""];
	pushReviewCommentPrompt(lines, payload, 0);
	lines.push(
		"",
		"Instructions:",
		"- Inspect the file and surrounding context as needed before editing.",
		"- Make the minimal code change needed to satisfy the review comment.",
		"- Update tests or docs only if the review comment requires it.",
		"- In your final response, summarize what changed.",
	);

	return lines.join("\n");
}

function plural(count, singular, pluralWord = `${singular}s`) {
	return count === 1 ? singular : pluralWord;
}

function payloadDescription(payload) {
	if (payload.scope === "batch") {
		return `${payload.comments.length} review ${plural(payload.comments.length, "comment")}`;
	}
	return `review comment for ${payload.location}`;
}

function writeReviewPayloadToEditor(ctx, payload) {
	const message = buildReviewPrompt(payload);
	const description = payloadDescription(payload);
	const currentText = ctx.ui.getEditorText?.() ?? "";
	const nextText =
		currentText.trim() === ""
			? message
			: `${currentText.replace(/\s+$/, "")}\n\n${message}`;

	ctx.ui.setEditorText(nextText);
	ctx.ui.notify(`Wrote ${description} to Pi input`, "info");
}

function humanKittyError(message) {
	if (message.includes("Remote control is disabled")) {
		return "Kitty remote control is disabled. Add `allow_remote_control yes` to kitty.conf, then fully restart kitty. If Pi is not running in a kitty-controlled TTY, set PI_KITTY_LISTEN_ON to a socket started with kitty --listen-on.";
	}
	if (message.includes("i/o timeout")) {
		return "Kitty remote control timed out while opening Diffview. Pi tried to contact Kitty but no Kitty instance answered. If you are inside Kitty, this is usually a stale KITTY_LISTEN_ON/PI_KITTY_LISTEN_ON from tmux or an old shell; unset it or set PI_KITTY_LISTEN_ON to a live socket from `kitty --listen-on`.";
	}
	return message;
}

function errorMessage(error) {
	return error instanceof Error ? error.message : String(error);
}

function cleanKittyRemoteEnv() {
	const env = { ...process.env };
	delete env.KITTY_LISTEN_ON;
	return env;
}

function buildKittyLaunchArgs(cwd, diffArgs, reviewBridge, listenOn) {
	const command = diffArgs
		? `DiffviewOpen --imply-local ${diffArgs}`
		: "DiffviewOpen --imply-local";
	const launchArgs = ["@"];

	if (listenOn) {
		launchArgs.push("--to", listenOn);
	}

	launchArgs.push(
		"launch",
		"--no-response",
		"--type=overlay",
		"--cwd",
		cwd,
		"--copy-env",
		"--env",
		`PI_REVIEW_ADDRESS=${reviewBridge.address}`,
		"--env",
		`PI_REVIEW_TOKEN=${reviewBridge.token}`,
		"--env",
		"PI_REVIEW_OVERLAY=1",
		"--title",
		"Pi review diff",
	);

	if (process.env.KITTY_WINDOW_ID) {
		launchArgs.push("--self");
	}

	launchArgs.push("nvim", "-c", command);
	return launchArgs;
}

async function execKittyLaunch(cwd, diffArgs, reviewBridge, listenOn) {
	await exec(
		"kitty",
		buildKittyLaunchArgs(cwd, diffArgs, reviewBridge, listenOn),
		{
			env: cleanKittyRemoteEnv(),
		},
	);
}

async function openDiffviewInKittyOverlay(cwd, diffArgs, reviewBridge) {
	const explicitListenOn = process.env.PI_KITTY_LISTEN_ON;
	if (explicitListenOn) {
		await execKittyLaunch(cwd, diffArgs, reviewBridge, explicitListenOn);
		return;
	}

	const errors = [];
	try {
		await execKittyLaunch(cwd, diffArgs, reviewBridge, undefined);
		return;
	} catch (error) {
		errors.push(`controlling terminal: ${errorMessage(error)}`);
	}

	if (process.env.KITTY_LISTEN_ON) {
		try {
			await execKittyLaunch(
				cwd,
				diffArgs,
				reviewBridge,
				process.env.KITTY_LISTEN_ON,
			);
			return;
		} catch (error) {
			errors.push(`KITTY_LISTEN_ON: ${errorMessage(error)}`);
		}
	}

	throw new Error(errors.join("\n"));
}

/** @param {import("@earendil-works/pi-coding-agent").ExtensionAPI} pi */
export default function piReviewExtension(pi) {
	let activeCtx;
	let reviewServer;
	let reviewBridge;

	async function stopReviewServer() {
		const server = reviewServer;

		reviewServer = undefined;
		reviewBridge = undefined;

		if (server) {
			await close(server).catch(() => {});
		}
	}

	async function ensureReviewServer(ctx) {
		activeCtx = ctx;
		if (reviewServer && reviewBridge) {
			return reviewBridge;
		}

		const token = randomUUID();
		const server = createServer((socket) => {
			let body = "";
			socket.setEncoding("utf8");
			socket.on("data", (chunk) => {
				body += chunk;
			});
			socket.on("error", () => {});
			socket.on("end", () => {
				void (async () => {
					try {
						const payload = normalizeReviewPayload(JSON.parse(body), token);
						const ctx = activeCtx;
						if (!ctx) {
							throw new Error("Pi review session is not available");
						}

						writeReviewPayloadToEditor(ctx, payload);
						socket.end();
					} catch (error) {
						const message =
							error instanceof Error ? error.message : String(error);
						activeCtx?.ui.notify(`Review comment failed: ${message}`, "error");
						socket.end();
					}
				})();
			});
		});

		server.on("error", (error) => {
			activeCtx?.ui.notify(`Pi review bridge error: ${error.message}`, "error");
		});

		try {
			await listen(server);
		} catch (error) {
			await close(server).catch(() => {});
			throw error;
		}

		reviewServer = server;
		reviewBridge = { address: serverAddress(server), token };
		return reviewBridge;
	}

	pi.on("session_start", async (_event, ctx) => {
		activeCtx = ctx;
	});

	pi.on("session_shutdown", async () => {
		activeCtx = undefined;
		await stopReviewServer();
	});

	pi.registerCommand("review-diff", {
		description:
			"Open diffview-plus.nvim in a kitty overlay pane with live Pi review comments",
		getArgumentCompletions: (prefix) => {
			const examples = ["", "origin/main...HEAD", "HEAD~1", "--cached", "-- ."];
			const filtered = examples.filter((item) => item.startsWith(prefix));
			return filtered.length > 0
				? filtered.map((value) => ({ value, label: value || "working tree" }))
				: null;
		},
		handler: async (args, ctx) => {
			try {
				const diffArgs = ensureSafeExArgs(args);
				const reviewBridge = await ensureReviewServer(ctx);
				await openDiffviewInKittyOverlay(ctx.cwd, diffArgs, reviewBridge);
				ctx.ui.notify("Opened Diffview with live Pi review comments", "info");
			} catch (error) {
				const message = error instanceof Error ? error.message : String(error);
				ctx.ui.notify(humanKittyError(message), "error");
			}
		},
	});
}
