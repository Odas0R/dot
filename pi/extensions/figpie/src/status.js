import { CDP_PORT } from "./config.js";

export const DETAILS_HINT = "Details: /figpie-status --verbose";

export const brief = (value) =>
	String(value || "Unknown error")
		.split("\n")[0]
		.replace(/^Error:\s*/, "")
		.slice(0, 240);

export function summarize(action, { desktop = {}, connections = [], issues = [] }) {
	if (action === "restore" && desktop.ok)
		return {
			text: desktop.changed ? "Original Figma app restored." : "Figma is already original; nothing changed.",
			level: "info",
		};
	if (desktop.rollback?.ok)
		return { text: `Figma failed to connect; the original app was restored.\n${DETAILS_HINT}`, level: "warning" };
	if (desktop.recoveryRequired || (desktop.rollback && !desktop.rollback.ok))
		return {
			text: `Figma recovery needs attention. Do not launch or patch it again yet.\n${DETAILS_HINT}`,
			level: "error",
		};
	const blocked = connections.filter((connection) => connection.blocked).length;
	const usable = connections.length - blocked;
	if (desktop.restartRequired && usable === 0)
		return {
			text: `Save your work and quit Figma, then run /figpie-${action === "restore" ? "restore" : "connect"}.`,
			level: "warning",
		};
	if (desktop.status === "busy")
		return { text: "Another Figpie desktop operation is running. Please wait.", level: "info" };
	if (desktop.ok === false && desktop.status !== "cdp-not-ready")
		return {
			text: `${brief(desktop.error || desktop.issues?.[0] || desktop.guidance || desktop.status)}\n${DETAILS_HINT}`,
			level: "warning",
		};

	// A launched app is not necessarily a usable scripting connection. Conversely,
	// a late successful discovery supersedes an earlier startup probe timeout.
	const connected = connections.length > 0;
	// A usable file is the primary health signal. Other open windows may still be
	// loading or may not expose a compatible API context; report those as a note
	// instead of making the entire connection look unhealthy.
	const warning = usable === 0 || blocked > 0;
	let text;
	if (action === "status") {
		text = [
			`Figma: ${desktop.running?.running ? "running" : desktop.running?.known ? "stopped" : "unknown"} · ${desktop.app?.patch?.state || "unknown patch state"}`,
			`CDP: 127.0.0.1:${CDP_PORT} · ${desktop.port?.state || "unknown"}`,
			`Figpie: ${connected ? `${connections.length} file${connections.length === 1 ? "" : "s"} connected` : "no scripting connection"}${blocked ? ` · ${blocked} blocked` : ""}`,
		].join("\n");
	} else {
		text = connected
			? `Connected to Figma on 127.0.0.1:${CDP_PORT}.${blocked ? ` ${blocked} target(s) are blocked.` : ""}`
			: `Figma ${desktop.running?.running ? "is running, but its scripting connection isn't ready" : "is not connected"}.`;
	}
	if (issues.length && connected)
		text += `\nNote: ${issues.length === 1 ? "1 other Figma window is" : `${issues.length} other Figma windows are`} still loading or unavailable.`;
	return {
		text: warning || issues.length ? `${text}\n${DETAILS_HINT}` : text,
		level: warning ? "warning" : "info",
	};
}
