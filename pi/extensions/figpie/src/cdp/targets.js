import { createHash } from "node:crypto";
import { EventEmitter } from "node:events";
import { CdpClient, listTargets } from "./client.js";
import { installationExpression, runtimeExpression } from "../runtime/index.js";

const PROBE = `typeof figma !== "undefined" && typeof figma.getNodeByIdAsync === "function" && typeof figma.createFrame === "function" && figma.editorType === "figma"`;

export function describeTarget(entry, { completed } = {}) {
	const active = entry.active === completed ? null : entry.active;
	return {
		connectionId: entry.id,
		...entry.info,
		busy: Boolean(active || entry.info.busyId || entry.queue.length),
		blocked: Boolean(entry.statusError || active?.finished || (!active && entry.info.busyId)),
		queueLength: entry.queue.length,
		...(entry.statusError ? { issue: entry.statusError } : {}),
	};
}

export class Targets extends EventEmitter {
	constructor() {
		super();
		this.entries = new Map();
		this.issues = [];
	}
	refresh() {
		if (this.closed) return Promise.resolve(this.inventory());
		if (!this.refreshing)
			this.refreshing = this.discover().finally(() => {
				this.refreshing = null;
			});
		return this.refreshing;
	}
	async discover() {
		let pages;
		try {
			pages = await listTargets();
		} catch (error) {
			this.issues = [
				`Cannot discover Figma on the local debugging port: ${error.message}. Ask the user to run /figpie-connect or /figpie-status.`,
			];
			for (const entry of [...this.entries.values()]) this.retire(entry);
			return this.inventory();
		}
		if (this.closed) return this.inventory();
		this.issues = [];
		for (const entry of [...this.entries.values()]) {
			if (
				!pages.some(
					(page) => page.id === entry.targetId && page.webSocketDebuggerUrl === entry.address && page.url === entry.url,
				)
			)
				this.retire(entry);
		}
		await Promise.all(
			pages.map(async (page) => {
				let entry = this.entries.get(page.id);
				try {
					if (!entry) {
						const cdp = new CdpClient();
						entry = {
							targetId: page.id,
							address: page.webSocketDebuggerUrl,
							url: page.url,
							cdp,
							queue: [],
							active: null,
							info: {},
						};
						this.entries.set(page.id, entry);
						cdp.once("close", () => this.retire(entry));
						cdp.on("context-destroyed", (id) => {
							if (entry.context && (id === null || id === entry.context.id)) this.retire(entry);
						});
						await cdp.connect(entry.address);
						const contexts = [...cdp.contexts.values()];
						const matches = (
							await Promise.all(
								contexts.map(async (context) => {
									try {
										return (await cdp.evaluate(PROBE, context, 1500)) === true ? context : null;
									} catch {
										return null;
									} // Most frames do not expose Figma's API.
								}),
							)
						).filter(Boolean);
						if (matches.length !== 1)
							throw new Error(
								matches.length
									? "Multiple Figma API contexts found; close legacy plugins and refresh the file"
									: "No compatible Figma API context found; the file may still be loading or this Figma version is unsupported",
							);
						entry.context = matches[0];
						entry.info = await cdp.evaluate(installationExpression(), entry.context);
						const hex = createHash("sha256").update(entry.info.instanceId).digest("hex").slice(0, 8).toUpperCase();
						entry.id = `${hex.slice(0, 4)}-${hex.slice(4)}`;
					} else if (!entry.active) {
						entry.info = await entry.cdp.evaluate(runtimeExpression("status"), entry.context);
					}
					entry.statusError = null;
				} catch (error) {
					this.issues.push(`${page.title || page.url}: ${error.message}`);
					if (entry?.id && !entry.retired) entry.statusError = error.message;
					else if (entry) this.retire(entry);
				}
			}),
		);
		if (!pages.length)
			this.issues.push(
				"No Figma Design file is open on this debugging endpoint. Ask the user to open a file in Figma; /figpie-status shows connection diagnostics.",
			);
		return this.inventory();
	}
	inventory() {
		return {
			connections: [...this.entries.values()].filter((entry) => entry.id && !entry.retired).map(describeTarget),
			issues: this.issues,
		};
	}
	select(requestedId) {
		const entries = [...this.entries.values()].filter((entry) => entry.id && !entry.retired);
		if (requestedId) {
			const entry = entries.find((candidate) => candidate.id === requestedId.trim().toUpperCase());
			if (entry) return entry;
		} else if (entries.length === 1) return entries[0];
		const inventory = JSON.stringify(this.inventory());
		if (!entries.length)
			throw new Error(
				`No Figma targets are available. Ask the user to run /figpie-connect or /figpie-status. ${inventory}`,
			);
		throw new Error(
			`${requestedId ? "Requested Figma target was not found." : "Multiple Figma targets are available."} Match the requested file/page and retry with connectionId; ask only if ambiguous. ${inventory}`,
		);
	}
	execute(entry, request) {
		// No CDP timeout: the caller can stop waiting, but the broker retains the
		// execution lock until the actual completion or context destruction.
		return entry.cdp.evaluate(runtimeExpression("execute", request), entry.context, 0);
	}
	cancel(entry, id) {
		return entry.cdp.evaluate(runtimeExpression("cancel", id), entry.context, 1500).catch(() => {});
	}
	retire(entry) {
		if (entry.retired) return;
		entry.retired = true;
		if (this.entries.get(entry.targetId) === entry) this.entries.delete(entry.targetId);
		entry.cdp.close();
		this.emit("retired", entry);
	}
	close() {
		this.closed = true;
		for (const entry of [...this.entries.values()]) this.retire(entry);
	}
}
