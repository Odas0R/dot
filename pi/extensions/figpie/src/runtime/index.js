import { randomUUID } from "node:crypto";
import { createSelectors } from "./selectors.js";
import { createHelpers } from "./helpers.js";
import { VERSION, MAX_MESSAGE_BYTES, MAX_IMAGE_BYTES, MAX_IMAGES } from "../config.js";

export const RUNTIME_KEY = "__figpieRuntime";

// This object lives in Figma, not the broker. Its lock survives CDP reconnects
// and broker crashes; replacing the socket must never permit overlapping work.
function createRuntime(figma, instanceId, version, limits, createHelpers, selectors) {
	let active;
	return {
		version,
		status() {
			return {
				instanceId,
				fileKey: figma.fileKey,
				fileName: figma.root.name,
				pageName: figma.currentPage.name,
				editorType: figma.editorType,
				busyId: active?.id || null,
			};
		},
		cancel(id) {
			if (active?.id === id) active.cancelled = true;
		},
		async execute(request) {
			if (active)
				throw new Error(
					"Figma is still running a previous Figpie request. Wait for completion; do not replay mutations.",
				);
			if (Date.now() >= request.deadline) throw new Error("Request expired before execution; it was not started.");
			const run = { id: request.id, deadline: request.deadline, cancelled: false, finished: false };
			active = run;
			let helpers;
			try {
				helpers = createHelpers(figma, run, limits, selectors);
				const sourceName = `figpie-run-${run.id.replace(/[^a-zA-Z0-9_-]/g, "_")}.js`;
				const execute = new Function(
					"figma",
					`return (async () => {\n${request.code}\n})();\n//# sourceURL=${sourceName}`,
				);
				return helpers.result(await execute(helpers.figma));
			} catch (error) {
				const message = String(error?.message || error);
				const hint = /node .*does not exist/i.test(message)
					? "\nFigma rejected a stale node reference. Re-fetch the owning instance and rediscover its children. Earlier changes may remain; do not replay the script."
					: "";
				return {
					type: "error",
					id: run.id,
					message: message.slice(0, 8192 - hint.length) + hint,
					stack: String(error?.stack || "").slice(0, 32768),
				};
			} finally {
				try {
					await helpers?.dispose();
				} finally {
					run.finished = true;
					active = null;
				}
			}
		},
	};
}

export function installationExpression() {
	const limits = { MAX_MESSAGE_BYTES, MAX_IMAGE_BYTES, MAX_IMAGES };
	return `(() => {
		const key = ${JSON.stringify(RUNTIME_KEY)};
		const previous = globalThis[key];
		if (previous?.version === ${VERSION}) return previous.status();
		if (previous?.status().busyId) throw new Error("An older Figpie runtime is still busy; wait for completion before upgrading.");
		globalThis[key] = (${createRuntime.toString()})(figma, ${JSON.stringify(randomUUID())}, ${VERSION}, ${JSON.stringify(limits)}, (${createHelpers.toString()}), (${createSelectors.toString()})());
		return globalThis[key].status();
	})()`;
}

export function runtimeExpression(method, argument) {
	return `globalThis[${JSON.stringify(RUNTIME_KEY)}].${method}(${argument === undefined ? "" : JSON.stringify(argument)})`;
}
