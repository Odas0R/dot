import { diagnoseDesktop, runningState } from "./diagnose.js";
import { repairDesktop, restoreDesktop } from "./patch.js";
import { launchDesktop } from "./launch.js";
import { SIGNING_NOTICE } from "./signing.js";

// The broker holds its desktop-operation lock for this entire workflow.
// Repair and launch still recheck the app state before making any changes.
export async function connectDesktop({ allowPatch = false, deadline = Infinity } = {}) {
	const diagnosis = await diagnoseDesktop();
	if (!diagnosis.ok) return diagnosis;
	let repair;
	if (diagnosis.app.patch.state === "unpatched" && diagnosis.port.state !== "ready") {
		if (diagnosis.port.state !== "free")
			return {
				...diagnosis,
				ok: false,
				status: "port-unavailable",
				guidance:
					"The debugging port is occupied or cannot be verified. Resolve the port conflict before running /figpie-connect again; no app changes were made.",
			};
		if (diagnosis.running.running)
			return {
				ok: false,
				status: "restart-required",
				restartRequired: true,
				guidance: "Save your work and quit Figma normally, then run /figpie-connect again. No app changes were made.",
			};
		if (allowPatch !== true) return { ok: false, status: "confirmation-required", guidance: SIGNING_NOTICE };
		if (Date.now() >= deadline)
			return {
				ok: false,
				status: "deadline-exceeded",
				guidance: "Connection deadline expired before patching; no app changes were made.",
			};
		repair = await repairDesktop({ allowPatch: true });
		if (!repair.ok) return repair;
	}
	const launched =
		Date.now() >= deadline
			? {
					ok: false,
					status: "deadline-exceeded",
					launched: false,
					guidance: "The connection deadline expired before launch.",
				}
			: await launchDesktop();
	let rollback;
	if (repair?.changed && !launched.ok) {
		// Recover only the app changed by this invocation, and never quit a running
		// app to make rollback possible. Restore verifies the entire bundle hash.
		const running = await runningState();
		if (running.known && !running.running) rollback = await restoreDesktop();
	}
	return {
		...launched,
		...(repair ? { repair } : {}),
		...(rollback ? { rollback } : {}),
		...(rollback?.ok
			? {
					guidance:
						"Connection failed; the original Figma app was restored. Inspect the launch error before attempting another patch.",
				}
			: {}),
	};
}
