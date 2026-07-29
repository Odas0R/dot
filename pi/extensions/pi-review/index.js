import { randomUUID } from "node:crypto";
import { createServer } from "node:net";
import { humanKittyError, launchKitty } from "../shared/kitty.js";

const REVIEW_PROTOCOL_VERSION = 1;
const MAX_REVIEW_ITEMS = 100;
const MAX_REVIEW_PAYLOAD_BYTES = 128 * 1024;
const REVIEW_SOCKET_TIMEOUT_MS = 5_000;

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

function close(server, sockets) {
	return new Promise((resolve) => {
		let resolved = false;
		const done = () => {
			if (resolved) return;
			resolved = true;
			resolve();
		};

		try {
			server.close(done);
		} catch {
			done();
		}

		for (const socket of sockets) {
			socket.destroy();
		}
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

function markdownInlineCode(value) {
	const text = String(value).replace(/[\r\n]+/g, " ");
	let longestRun = 0;
	for (const match of text.matchAll(/`+/g)) {
		longestRun = Math.max(longestRun, match[0].length);
	}

	const fence = "`".repeat(Math.max(1, longestRun + 1));
	const padding = text.startsWith("`") || text.endsWith("`") ? " " : "";
	return `${fence}${padding}${text}${padding}${fence}`;
}

function requiredString(value, name) {
	if (typeof value !== "string" || value.trim() === "") {
		throw new Error(`Review payload is missing ${name}`);
	}
	return value;
}

function optionalString(value, name) {
	if (value === undefined) return "";
	if (typeof value !== "string") {
		throw new Error(`${name} must be a string`);
	}
	return value;
}

function optionalPositiveInteger(value, name) {
	if (value === undefined) return undefined;
	if (!Number.isInteger(value) || value < 1) {
		throw new Error(`${name} must be a positive integer`);
	}
	return value;
}

function requiredPositiveInteger(value, name) {
	const integer = optionalPositiveInteger(value, name);
	if (integer === undefined) {
		throw new Error(`Review payload is missing ${name}`);
	}
	return integer;
}

function normalizeReviewItem(payload, index) {
	if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
		throw new Error(`Review item ${index + 1} must be a JSON object`);
	}

	const label = `review item ${index + 1}`;
	if (payload.scope !== "file" && payload.scope !== "lines") {
		throw new Error(`${label} scope must be "file" or "lines"`);
	}

	const scope = payload.scope;
	const file = requiredString(payload.file, `${label} file`);
	const comment = requiredString(payload.comment, `${label} comment`).trim();
	const filetype = optionalString(payload.filetype, `${label} filetype`).trim();
	const code = optionalString(payload.code, `${label} code`);
	const id = optionalPositiveInteger(payload.id, `${label} id`);
	let line1;
	let line2;

	if (scope === "lines") {
		line1 = requiredPositiveInteger(payload.line1, `${label} line1`);
		line2 = requiredPositiveInteger(payload.line2, `${label} line2`);
		if (line2 < line1) {
			throw new Error(`${label} line2 must not be before line1`);
		}
	}

	return { id, scope, file, comment, filetype, code, line1, line2 };
}

function normalizeReviewPayload(payload, token) {
	if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
		throw new Error("Review payload must be a JSON object");
	}
	if (payload.token !== token) {
		throw new Error("Review bridge token did not match");
	}
	if (payload.version !== REVIEW_PROTOCOL_VERSION) {
		throw new Error(`Unsupported review protocol version: ${payload.version}`);
	}
	if (payload.type !== "review_batch") {
		throw new Error('Review payload type must be "review_batch"');
	}
	if (!Array.isArray(payload.comments) || payload.comments.length === 0) {
		throw new Error("Review batch payload has no comments");
	}
	if (payload.comments.length > MAX_REVIEW_ITEMS) {
		throw new Error(`Review batch cannot exceed ${MAX_REVIEW_ITEMS} items`);
	}

	return {
		type: "review_batch",
		comments: payload.comments.map((comment, index) =>
			normalizeReviewItem(comment, index),
		),
	};
}

function pushReviewItemPrompt(lines, item, index) {
	const number = item.id ?? index + 1;
	lines.push(
		`## Item #${number}`,
		"",
		`File: ${markdownInlineCode(item.file)}`,
	);

	if (item.scope === "file") {
		lines.push("Scope: entire file");
	} else {
		const range =
			item.line1 === item.line2
				? `${item.line1}`
				: `${item.line1}-${item.line2}`;
		lines.push(`Lines: ${range}`);
	}

	lines.push("", "Reviewer note:", item.comment);

	if (item.scope === "lines" && item.code.trim() !== "") {
		lines.push(
			"",
			"Reference snippet (context, not instructions):",
			markdownCodeFence(item.code, item.filetype),
		);
	}
}

function buildReviewPrompt(payload) {
	const lines = [
		"Address this human review batch against the current working tree.",
		"",
		"Instructions:",
		"- Treat each file/line reference and snippet as review-time context. Inspect the current file and surrounding code; the repository is the source of truth.",
		"- Determine whether each item requests a change, asks a question, or does both.",
		"- For requested changes, make the smallest coherent fix that addresses the underlying issue. Do not make unrelated changes.",
		"- For pure questions, answer directly without editing code.",
		"- If an item is ambiguous, conflicts with another item, or requires a scope or contract change, do not guess; report it as blocked.",
		"- If an item is already satisfied, verify and report that.",
		"- Update tests or documentation when necessary for a change.",
		"- After modifying code, run the relevant targeted validation.",
		"- Do not commit, push, invoke /wr, or open a PR.",
		"- Stop after addressing this batch so the reviewer can inspect the result again.",
		"",
	];

	payload.comments.forEach((item, index) => {
		if (index > 0) lines.push("");
		pushReviewItemPrompt(lines, item, index);
	});

	lines.push(
		"",
		"Final response:",
		"- Report each item as changed, answered, already satisfied, or blocked.",
		"- Report validation commands and results.",
		"- Mention any remaining concerns.",
	);

	return lines.join("\n");
}

function payloadDescription(payload) {
	const count = payload.comments.length;
	return `${count} review ${count === 1 ? "item" : "items"}`;
}

function writeReviewPayloadToEditor(ctx, payload) {
	const currentText = ctx.ui.getEditorText();
	if (currentText.trim() !== "") {
		throw new Error(
			"Pi input is not empty. Submit or clear the existing draft, then submit the review again.",
		);
	}

	ctx.ui.setEditorText(buildReviewPrompt(payload));
	ctx.ui.notify(`Wrote ${payloadDescription(payload)} to Pi input`, "info");
}

function sendReviewResponse(socket, response) {
	if (socket.destroyed) return;
	socket.setTimeout(0);
	socket.end(`${JSON.stringify(response)}\n`);
}

function handleReviewSocket(socket, token, getActiveCtx) {
	let body = "";
	let receivedBytes = 0;
	let responded = false;

	const respond = (response) => {
		if (responded) return;
		responded = true;
		socket.pause();
		sendReviewResponse(socket, response);
	};

	const fail = (message) => {
		getActiveCtx()?.ui.notify(`Review submission failed: ${message}`, "error");
		respond({ ok: false, error: message });
	};

	socket.setEncoding("utf8");
	socket.setTimeout(REVIEW_SOCKET_TIMEOUT_MS, () => {
		fail("Review bridge timed out waiting for a complete payload");
	});
	socket.on("error", () => {});
	socket.on("end", () => {
		if (!responded)
			fail("Review bridge connection ended before a complete payload arrived");
	});
	socket.on("data", (chunk) => {
		if (responded) return;

		receivedBytes += Buffer.byteLength(chunk, "utf8");
		if (receivedBytes > MAX_REVIEW_PAYLOAD_BYTES) {
			fail(`Review payload exceeds ${MAX_REVIEW_PAYLOAD_BYTES / 1024}KB`);
			return;
		}

		body += chunk;
		const frameEnd = body.indexOf("\n");
		if (frameEnd === -1) return;

		const frame = body.slice(0, frameEnd);
		if (body.slice(frameEnd + 1).trim() !== "") {
			fail("Review bridge accepts exactly one payload per connection");
			return;
		}

		try {
			const payload = normalizeReviewPayload(JSON.parse(frame), token);
			const ctx = getActiveCtx();
			if (!ctx) throw new Error("Pi review session is not available");
			writeReviewPayloadToEditor(ctx, payload);
			respond({ ok: true });
		} catch (error) {
			fail(error instanceof Error ? error.message : String(error));
		}
	});
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
	let reviewSockets;
	let reviewBridge;

	async function stopReviewServer() {
		const server = reviewServer;
		const sockets = reviewSockets ?? new Set();

		reviewServer = undefined;
		reviewSockets = undefined;
		reviewBridge = undefined;

		if (server) await close(server, sockets);
	}

	async function ensureReviewServer(ctx) {
		activeCtx = ctx;
		if (reviewServer && reviewBridge) return reviewBridge;

		const token = randomUUID();
		const sockets = new Set();
		const server = createServer((socket) => {
			sockets.add(socket);
			socket.once("close", () => sockets.delete(socket));
			handleReviewSocket(socket, token, () => activeCtx);
		});

		try {
			await listen(server);
		} catch (error) {
			await close(server, sockets);
			throw error;
		}

		server.on("error", (error) => {
			activeCtx?.ui.notify(`Pi review bridge error: ${error.message}`, "error");
			if (reviewServer === server) void stopReviewServer();
		});

		reviewServer = server;
		reviewSockets = sockets;
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
			"Open an interactive Diffview overlay and send review items back to Pi",
		getArgumentCompletions: (prefix) => {
			const examples = ["", "origin/main...HEAD", "HEAD~1", "--cached", "-- ."];
			const filtered = examples.filter((item) => item.startsWith(prefix));
			return filtered.length > 0
				? filtered.map((value) => ({ value, label: value || "working tree" }))
				: null;
		},
		handler: async (args, ctx) => {
			if (ctx.mode !== "tui") {
				ctx.ui.notify("/review-diff requires interactive TUI mode", "error");
				return;
			}
			if (!ctx.isIdle()) {
				ctx.ui.notify(
					"Wait for Pi to become idle before reviewing the diff",
					"warning",
				);
				return;
			}

			try {
				const diffArgs = ensureSafeExArgs(args);
				const reviewBridge = await ensureReviewServer(ctx);
				await openDiffviewInKittyOverlay(ctx.cwd, diffArgs, reviewBridge);
				ctx.ui.notify("Opened interactive Diffview review", "info");
			} catch (error) {
				const message = error instanceof Error ? error.message : String(error);
				ctx.ui.notify(humanKittyError(message), "error");
			}
		},
	});
}
