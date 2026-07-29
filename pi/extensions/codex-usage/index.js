const PROVIDER_ID = "openai-codex";
const UI_KEY = "codex-usage";
const USAGE_URL = "https://chatgpt.com/backend-api/wham/usage";
const OPENAI_AUTH_CLAIM = "https://api.openai.com/auth";
const REFRESH_INTERVAL_MS = 60_000;
const REQUEST_TIMEOUT_MS = 10_000;
const FIVE_HOURS_SECONDS = 5 * 60 * 60;
const DAY_SECONDS = 24 * 60 * 60;
const WEEK_SECONDS = 7 * DAY_SECONDS;

function finiteNumber(value) {
	const number = typeof value === "string" && value.trim() !== "" ? Number(value) : value;
	return typeof number === "number" && Number.isFinite(number) ? number : undefined;
}

function unixTimeMs(value) {
	const number = finiteNumber(value);
	if (number === undefined) return undefined;
	return number < 1_000_000_000_000 ? number * 1000 : number;
}

function normalizeWindow(value) {
	if (!value || typeof value !== "object") return undefined;

	const usedPercent = finiteNumber(value.used_percent ?? value.usedPercent);
	if (usedPercent === undefined) return undefined;

	return {
		usedPercent,
		durationSeconds: finiteNumber(
			value.limit_window_seconds ?? value.limitWindowSeconds ?? value.windowDurationSeconds,
		),
		resetAtMs: unixTimeMs(value.reset_at ?? value.resetsAt),
	};
}

function classifyRateLimit(rateLimit) {
	if (!rateLimit || typeof rateLimit !== "object") {
		return { fiveHour: undefined, weekly: undefined };
	}

	const windows = [
		{ slot: "primary", value: normalizeWindow(rateLimit.primary_window ?? rateLimit.primaryWindow) },
		{ slot: "secondary", value: normalizeWindow(rateLimit.secondary_window ?? rateLimit.secondaryWindow) },
	].filter(({ value }) => value !== undefined);

	let fiveHour;
	let weekly;
	const unclassified = [];

	for (const window of windows) {
		const duration = window.value.durationSeconds;
		if (
			duration === FIVE_HOURS_SECONDS ||
			(duration !== undefined && duration > 0 && duration <= DAY_SECONDS)
		) {
			fiveHour ??= window.value;
		} else if (duration === WEEK_SECONDS || (duration !== undefined && duration >= 5 * DAY_SECONDS)) {
			weekly ??= window.value;
		} else {
			unclassified.push(window);
		}
	}

	for (const window of unclassified) {
		if (window.slot === "primary" && !fiveHour) fiveHour = window.value;
		else if (window.slot === "secondary" && !weekly) weekly = window.value;
	}

	return { fiveHour, weekly };
}

function parseUsage(payload) {
	if (!payload || typeof payload !== "object") {
		throw new Error("Codex usage response was not a JSON object");
	}

	const windows = classifyRateLimit(payload.rate_limit ?? payload.rateLimit);
	const fiveHour = windows.fiveHour ?? normalizeWindow(payload.five_hour_limit);
	const weekly = windows.weekly ?? normalizeWindow(payload.weekly_limit);

	if (!fiveHour && !weekly) {
		throw new Error("Codex usage response did not include a 5-hour or weekly limit");
	}

	return { fiveHour, weekly };
}

function headerValue(headers, name) {
	if (!headers || typeof headers !== "object") return undefined;
	const target = name.toLowerCase();
	for (const [key, value] of Object.entries(headers)) {
		if (key.toLowerCase() === target) return Array.isArray(value) ? value[0] : value;
	}
	return undefined;
}

function parseUsageHeaders(headers, now = Date.now()) {
	function parseWindow(prefix) {
		const usedPercent = finiteNumber(headerValue(headers, `x-codex-${prefix}-used-percent`));
		if (usedPercent === undefined) return undefined;

		const windowMinutes = finiteNumber(
			headerValue(headers, `x-codex-${prefix}-window-minutes`),
		);
		const resetAfterSeconds = finiteNumber(
			headerValue(headers, `x-codex-${prefix}-reset-after-seconds`),
		);
		const resetAt = finiteNumber(headerValue(headers, `x-codex-${prefix}-reset-at`));
		return {
			used_percent: usedPercent,
			limit_window_seconds:
				windowMinutes === undefined ? undefined : windowMinutes * 60,
			reset_at:
				resetAt ??
				(resetAfterSeconds === undefined
					? undefined
					: Math.floor(now / 1000) + resetAfterSeconds),
		};
	}

	const windows = classifyRateLimit({
		primary_window: parseWindow("primary"),
		secondary_window: parseWindow("secondary"),
	});
	return windows.fiveHour || windows.weekly ? windows : undefined;
}

function currentWindow(window, now) {
	return window && (!window.resetAtMs || window.resetAtMs > now) ? window : undefined;
}

function mergeUsage(preferred, fallback, now = Date.now()) {
	const fiveHour =
		currentWindow(preferred?.fiveHour, now) ?? currentWindow(fallback?.fiveHour, now);
	const weekly =
		currentWindow(preferred?.weekly, now) ?? currentWindow(fallback?.weekly, now);
	return { fiveHour, weekly };
}

function accountIdFromToken(token) {
	try {
		const parts = token.split(".");
		if (parts.length !== 3) throw new Error("invalid JWT");
		const payload = JSON.parse(Buffer.from(parts[1], "base64url").toString("utf8"));
		const accountId = payload?.[OPENAI_AUTH_CLAIM]?.chatgpt_account_id;
		if (typeof accountId !== "string" || accountId === "") throw new Error("missing account id");
		return accountId;
	} catch {
		throw new Error("Could not read the ChatGPT account ID from the OpenAI Codex login");
	}
}

function formatPercent(window) {
	if (!window) return "—";
	const value = window.usedPercent;
	return `${Number.isInteger(value) ? value : value.toFixed(1)}%`;
}

function formatReset(window, now = Date.now()) {
	if (!window?.resetAtMs) return undefined;

	const remainingSeconds = Math.max(0, Math.ceil((window.resetAtMs - now) / 1000));
	if (remainingSeconds === 0) return "resetting";
	if (remainingSeconds < 60) return "resets in <1m";

	const days = Math.floor(remainingSeconds / DAY_SECONDS);
	const hours = Math.floor((remainingSeconds % DAY_SECONDS) / 3600);
	const minutes = Math.floor((remainingSeconds % 3600) / 60);
	if (days > 0) return `resets in ${days}d${hours > 0 ? ` ${hours}h` : ""}`;
	if (hours > 0) return `resets in ${hours}h${minutes > 0 ? ` ${minutes}m` : ""}`;
	return `resets in ${minutes}m`;
}

function formatUsage(usage) {
	const windows = [];
	if (usage.fiveHour) windows.push(`5h ${formatPercent(usage.fiveHour)} used`);
	if (usage.weekly) windows.push(`week ${formatPercent(usage.weekly)} used`);
	return windows.length > 0 ? `Codex · ${windows.join(" · ")}` : "Codex · no limits reported";
}

function usageColor(window) {
	if (window.usedPercent >= 90) return "error";
	if (window.usedPercent >= 75) return "warning";
	return "success";
}

function compactReset(window, now) {
	const reset = formatReset(window, now);
	if (!reset) return "";
	if (reset === "resetting") return "now";
	return reset.replace(/^resets in /, "");
}

function renderStatusLane(theme, label, window, now) {
	const color = usageColor(window);
	const barWidth = 10;
	const used = Math.max(0, Math.min(100, window.usedPercent));
	const filled = Math.round((used / 100) * barWidth);
	const bar =
		theme.fg(color, "█".repeat(filled)) +
		theme.fg("dim", "░".repeat(barWidth - filled));
	const reset = compactReset(window, now);
	return (
		theme.fg("muted", `${label} `) +
		bar +
		` ${theme.fg(color, formatPercent(window))}` +
		(reset ? theme.fg("dim", ` ↻${reset}`) : "")
	);
}

function renderStatus(theme, usage, error, now = Date.now()) {
	if (!usage) {
		return theme.fg(error ? "warning" : "dim", error ? "Codex usage unavailable" : "Codex usage …");
	}

	const windows = [];
	if (usage.fiveHour) windows.push(renderStatusLane(theme, "5h", usage.fiveHour, now));
	if (usage.weekly) windows.push(renderStatusLane(theme, "Week", usage.weekly, now));
	if (windows.length === 0) return theme.fg("dim", "Codex usage not reported");

	const stale = error ? theme.fg("warning", " !") : "";
	return (
		theme.fg("accent", theme.bold("Codex")) +
		" " +
		windows.join(theme.fg("dim", " · ")) +
		stale
	);
}

async function fetchUsage(ctx, signal) {
	const resolved = await ctx.modelRegistry.getProviderAuth(PROVIDER_ID);
	const token = resolved?.auth?.apiKey;
	if (!token) {
		throw new Error("OpenAI Codex is not logged in; use /login and select OpenAI Codex");
	}

	const response = await fetch(USAGE_URL, {
		signal,
		headers: {
			accept: "application/json",
			authorization: `Bearer ${token}`,
			"chatgpt-account-id": accountIdFromToken(token),
			originator: "pi",
		},
	});

	if (!response.ok) {
		const hint = response.status === 401 || response.status === 403 ? "; log in to OpenAI Codex again" : "";
		throw new Error(`Codex usage request failed with HTTP ${response.status}${hint}`);
	}

	return parseUsage(await response.json());
}

function errorMessage(error) {
	return error instanceof Error ? error.message : String(error);
}

/** @param {import("@earendil-works/pi-coding-agent").ExtensionAPI} pi */
export default function codexUsageExtension(pi) {
	let activeCtx;
	let interval;
	let requestController;
	let inFlight;
	let usage;
	let lastError;

	function updateStatus(ctx) {
		ctx.ui.setStatus(UI_KEY, renderStatus(ctx.ui.theme, usage, lastError));
	}

	function refresh(ctx) {
		if (inFlight) return inFlight;

		const controller = new AbortController();
		const timeout = setTimeout(() => controller.abort(new Error("Codex usage request timed out")), REQUEST_TIMEOUT_MS);
		requestController = controller;

		const request = fetchUsage(ctx, controller.signal)
			.then((nextUsage) => {
				const mergedUsage = mergeUsage(nextUsage, usage);
				if (activeCtx === ctx) {
					usage = mergedUsage;
					lastError = undefined;
					updateStatus(ctx);
				}
				return mergedUsage;
			})
			.catch((error) => {
				if (activeCtx === ctx) {
					lastError = error;
					updateStatus(ctx);
				}
				throw error;
			})
			.finally(() => {
				clearTimeout(timeout);
				if (requestController === controller) requestController = undefined;
				if (inFlight === request) inFlight = undefined;
			});

		inFlight = request;
		return request;
	}

	pi.on("session_start", (_event, ctx) => {
		activeCtx = ctx;
		usage = undefined;
		lastError = undefined;
		if (interval) clearInterval(interval);
		interval = undefined;

		if (!ctx.hasUI) return;
		ctx.ui.setWidget(UI_KEY, undefined);
		updateStatus(ctx);
		void refresh(ctx).catch(() => {});

		interval = setInterval(() => {
			if (activeCtx) void refresh(activeCtx).catch(() => {});
		}, REFRESH_INTERVAL_MS);
		interval.unref?.();
	});

	pi.on("after_provider_response", (event) => {
		const headerUsage = parseUsageHeaders(event.headers);
		if (!activeCtx || !headerUsage) return;

		usage = mergeUsage(headerUsage, usage);
		lastError = undefined;
		updateStatus(activeCtx);
	});

	pi.on("session_shutdown", (_event, ctx) => {
		activeCtx = undefined;
		if (interval) clearInterval(interval);
		interval = undefined;
		requestController?.abort();
		requestController = undefined;
		inFlight = undefined;
		ctx.ui.setStatus(UI_KEY, undefined);
		ctx.ui.setWidget(UI_KEY, undefined);
	});

	pi.registerCommand("codex-usage", {
		description: "Refresh and show ChatGPT Codex 5-hour and weekly plan usage",
		handler: async (_args, ctx) => {
			try {
				const current = await refresh(ctx);
				ctx.ui.notify(formatUsage(current), "info");
			} catch (error) {
				ctx.ui.notify(errorMessage(error), "error");
			}
		},
	});
}

export {
	accountIdFromToken,
	classifyRateLimit,
	formatReset,
	formatUsage,
	mergeUsage,
	parseUsage,
	parseUsageHeaders,
	renderStatus,
};
