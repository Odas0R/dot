import { setTimeout as delay } from "node:timers/promises";
import { CDP_PORT } from "../config.js";
import { desktopPaths, inspectApp, inspectPort, readBackup, run, runningState } from "./diagnose.js";
import { withDesktopLock } from "./patch.js";
import { verifyPatchedSignature } from "./signing.js";

/** Launch only on explicit request; never patches, quits, or starts a browser. */
export async function launchDesktop() {
	return withDesktopLock("launch", async () => {
		const { appPath } = desktopPaths();
		const record = await readBackup();
		if (record && ["prepared", "interrupted"].includes(record.phase))
			return {
				ok: false,
				action: "launch",
				status: "recovery-required",
				launched: false,
				error: "An interrupted bundle swap must be resolved before launch.",
				backup: record,
			};
		const app = await inspectApp();
		if (!app.supportedIdentity || app.symlink)
			return {
				ok: false,
				action: "launch",
				status: "unsupported-app",
				launched: false,
				app,
			};
		if (app.patch.state === "patched") {
			try {
				await verifyPatchedSignature(appPath);
			} catch (error) {
				return {
					ok: false,
					action: "launch",
					status: "restore-required",
					launched: false,
					error: error.message,
					guidance:
						"Run /figpie-restore before reconnecting. This patched app failed signing checks and will not be launched.",
				};
			}
		}
		let running = await runningState();
		let port = await inspectPort(running);
		if (!running.known)
			return {
				ok: false,
				action: "launch",
				status: "running-state-unknown",
				launched: false,
				running,
				port,
			};
		if (port.state === "ready")
			return {
				ok: true,
				action: "launch",
				status: "already-running",
				launched: false,
				restartRequired: false,
				running,
				port,
			};
		if (running.running)
			return {
				ok: false,
				action: "launch",
				status: "restart-required",
				launched: false,
				restartRequired: true,
				running,
				port,
				guidance:
					"This Figma app is already running without verified local CDP. Quit it normally, then run /figpie-connect again. If it is still starting, open a Figma window and run /figpie-status first.",
			};
		if (port.state !== "free")
			return {
				ok: false,
				action: "launch",
				status: "port-unavailable",
				launched: false,
				port,
				guidance:
					"The configured CDP port is occupied or cannot be verified. Choose a free port or close its owner yourself; no process will be terminated.",
			};
		if (app.patch.state !== "patched")
			return {
				ok: false,
				action: "launch",
				status: app.patch.known ? "repair-required" : "unsupported-app",
				launched: false,
				app,
				guidance: "Run /figpie-connect again to recheck the desktop patch. Launch itself never modifies the app.",
			};
		// Check again immediately before open, including ownership of any listener
		// that appeared during diagnosis. Do not pass -n (force a new instance).
		running = await runningState();
		port = await inspectPort(running);
		if (!running.known || running.running || port.state !== "free")
			return {
				ok: false,
				action: "launch",
				status: "state-changed",
				launched: false,
				restartRequired: running.running === true,
				running,
				port,
				guidance: "Desktop or port state changed; retry diagnosis.",
			};
		await run(
			"/usr/bin/open",
			["-a", appPath, "--args", "--remote-debugging-address=127.0.0.1", `--remote-debugging-port=${Number(CDP_PORT)}`],
			{
				timeout: 15000,
				maxBuffer: 1024 * 1024,
			},
		);
		const deadline = Date.now() + 15000;
		do {
			await delay(500);
			running = await runningState();
			port = await inspectPort(running);
			if (port.state === "ready")
				return {
					ok: true,
					action: "launch",
					status: "launched",
					launched: true,
					restartRequired: false,
					running,
					port,
				};
			if (["occupied", "unsafe", "invalid"].includes(port.state)) break;
		} while (Date.now() < deadline);
		return {
			ok: false,
			action: "launch",
			status: running.known && !running.running ? "launch-failed" : "cdp-not-ready",
			launched: true,
			restartRequired: running.running === true && port.state === "free",
			running,
			port,
			guidance:
				running.known && !running.running
					? "Figma did not remain running after launch. Inspect its crash report; do not keep retrying /figpie-connect. Use /figpie-restore if the app was not automatically restored."
					: "Figma is running, but local CDP is not verified yet. Open a Figma window and run /figpie-status. If a restart is needed, quit Figma normally; no automatic relaunch will occur.",
		};
	});
}
