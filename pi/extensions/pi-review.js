import { randomUUID } from "node:crypto";
import { createServer } from "node:net";
import { launchKitty } from "./lib/kitty.js";

function ensureSafeExArgs(args) {
	const trimmed = args.trim();
	if (/[\r\n|]/.test(trimmed)) {
		throw new Error("Arguments cannot contain newlines or |.");
	}
	return trimmed;
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

function looksLikeReviewQuestion(comment) {
	const text = String(comment || "").trim();
	if (text === "") {
		return false;
	}

	if (/[?？](?:\s|$)/u.test(text)) {
		return true;
	}

	const firstLine = text.split(/\r?\n/, 1)[0].trim();
	return /^(?:why|what|when|where|who|which|how|is|are|was|were|do|does|did|has|have)\b/i.test(
		firstLine,
	);
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
	const isQuestion =
		payload.isQuestion === true || looksLikeReviewQuestion(comment);
	const id = Number.isInteger(payload.id) ? payload.id : undefined;
	const line1 = Number.isInteger(payload.line1) ? payload.line1 : undefined;
	const line2 = Number.isInteger(payload.line2) ? payload.line2 : undefined;

	return {
		id,
		scope,
		file,
		comment,
		location,
		filetype,
		code,
		isQuestion,
		line1,
		line2,
	};
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
	const itemName = comment.isQuestion ? "Question" : "Comment";
	const title = comment.id
		? `${itemName} #${comment.id}`
		: `${itemName} ${index + 1}`;
	const locationLabel = comment.scope === "file" ? "File" : "Location";
	lines.push(
		`## ${title}`,
		"",
		`${locationLabel}: \`${comment.location}\`${comment.scope === "file" ? " (entire file)" : ""}`,
		"",
		`Reviewer ${comment.isQuestion ? "question" : "comment"}:`,
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

function batchReviewIntro(commentCount, questionCount) {
	if (commentCount === 0) {
		return "Answer these code review questions.";
	}
	if (questionCount === 0) {
		return "Apply these code review comments.";
	}
	return "Address these code review comments and questions.";
}

function batchReviewCountLine(commentCount, questionCount) {
	const parts = [];
	if (commentCount > 0) {
		parts.push(`${commentCount} review ${plural(commentCount, "comment")}`);
	}
	if (questionCount > 0) {
		parts.push(`${questionCount} review ${plural(questionCount, "question")}`);
	}

	const count = commentCount + questionCount;
	return `There ${count === 1 ? "is" : "are"} ${parts.join(" and ")}.`;
}

function buildBatchReviewPrompt(payload) {
	const questionCount = payload.comments.filter(
		(comment) => comment.isQuestion,
	).length;
	const commentCount = payload.comments.length - questionCount;
	const action = commentCount === 0 ? "Answer" : "Address";
	const lines = [
		batchReviewIntro(commentCount, questionCount),
		"",
		batchReviewCountLine(commentCount, questionCount),
		payload.comments.length === 1
			? `${action} it in one pass.`
			: `${action} all of them in one pass.`,
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
		"- Inspect each file and surrounding context as needed before responding.",
		"- For comments that request a change, make the minimal code changes needed.",
		"- For questions, answer clearly in your final response; do not edit code unless the question reveals a concrete issue or clearly asks for a change.",
		"- If a requested change is already satisfied, verify it and mention that in your final response.",
		"- Update tests or docs only if a review item requires it.",
		"- In your final response, summarize the outcome for each item number, including answers for questions.",
	);

	return lines.join("\n");
}

function buildReviewPrompt(payload) {
	if (payload.scope === "batch") {
		return buildBatchReviewPrompt(payload);
	}

	const intro = payload.isQuestion
		? payload.scope === "file"
			? "Answer this file-level code review question."
			: "Answer this inline code review question."
		: payload.scope === "file"
			? "Apply this file-level code review comment."
			: "Apply this inline code review comment.";
	const lines = [intro, ""];
	pushReviewCommentPrompt(lines, payload, 0);

	if (payload.isQuestion) {
		lines.push(
			"",
			"Instructions:",
			"- Inspect the file and surrounding context as needed before answering.",
			"- Answer the reviewer's question clearly in your final response.",
			"- Do not edit code unless the question reveals a concrete issue or clearly asks for a change.",
			"- If you do edit code, keep the change minimal and summarize both the answer and what changed.",
		);
		return lines.join("\n");
	}

	lines.push(
		"",
		"Instructions:",
		"- Inspect the file and surrounding context as needed before editing.",
		"- Make the minimal code change needed to satisfy the review comment.",
		"- If the comment is actually asking a question rather than requesting a change, answer it in your final response instead of editing.",
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
		return `${payload.comments.length} review ${plural(payload.comments.length, "item")}`;
	}
	return `review ${payload.isQuestion ? "question" : "comment"} for ${payload.location}`;
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

async function openDiffviewInKittyOverlay(cwd, diffArgs, reviewBridge) {
	const command = diffArgs
		? `DiffviewOpen --imply-local ${diffArgs}`
		: "DiffviewOpen --imply-local";

	await launchKitty({
		type: "overlay",
		cwd,
		title: "Pi review diff",
		copyEnv: true,
		env: {
			PI_REVIEW_ADDRESS: reviewBridge.address,
			PI_REVIEW_TOKEN: reviewBridge.token,
			PI_REVIEW_OVERLAY: "1",
		},
		command: ["nvim", "-c", command],
	});
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
				ctx.ui.notify(message, "error");
			}
		},
	});
}
