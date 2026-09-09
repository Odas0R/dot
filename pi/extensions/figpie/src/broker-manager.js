import { spawn } from "node:child_process";
import { open } from "node:fs/promises";
import { join } from "node:path";
import { setTimeout as delay } from "node:timers/promises";
import { fileURLToPath } from "node:url";
import { BrokerClient } from "./client.js";
import { STATE_DIR, VERSION, ensureStateDir } from "./config.js";
import { clientTrace } from "./log.js";

const BROKER_ENTRY_FILE = fileURLToPath(new URL("./broker-entry.js", import.meta.url));

export const BROKER_LOG_FILE = join(STATE_DIR, "broker.log");

const STARTUP_TIMEOUT_MS = 5_000;
const RETRY_DELAY_MS = 100;
const RETRYABLE_CONNECTION_ERRORS = new Set(["ENOENT", "ECONNREFUSED", "ECONNRESET"]);
const MISSING_BROKER_ERRORS = new Set(["ENOENT", "ECONNREFUSED"]);

export class BrokerManager {
	#startup = null;

	ensureRunning() {
		if (this.#startup) return this.#startup;
		this.#startup = this.#ensureRunning().finally(() => {
			this.#startup = null;
		});
		return this.#startup;
	}

	async #ensureRunning() {
		const probe = new BrokerClient();
		const deadline = Date.now() + STARTUP_TIMEOUT_MS;
		let launched = false;

		while (Date.now() < deadline) {
			let channel;
			try {
				// Identity is checked before protocol retirement so this manager can
				// never replace a broker for another app or debugging port.
				channel = await probe.openChannel({ allowVersionMismatch: true });
			} catch (error) {
				if (!RETRYABLE_CONNECTION_ERRORS.has(error.code)) throw error;
				if (!launched && MISSING_BROKER_ERRORS.has(error.code)) {
					await this.#launch();
					launched = true;
				}
				await delay(RETRY_DELAY_MS);
				continue;
			}

			try {
				if (channel.broker.version === VERSION) return;
				if (channel.broker.version > VERSION) {
					throw new Error(
						`Figpie broker protocol ${channel.broker.version} is newer than this Pi extension (${VERSION}). Restart Pi completely to load the current extension; the broker was left running.`,
					);
				}
				if (!channel.broker.retireWhenIdle) {
					throw new Error(
						`Legacy Figpie broker (protocol ${channel.broker.version}) cannot retire safely. Close other Pi sessions and wait 30 seconds, then retry. Restart Pi completely after source updates, not just /reload.`,
					);
				}
				await probe.retireBroker(channel, channel.broker.pid);
			} finally {
				channel.close();
			}
			await delay(RETRY_DELAY_MS);
		}

		throw new Error(`Figpie broker did not become ready. See ${BROKER_LOG_FILE}. Inspect before retrying.`);
	}

	async #launch() {
		await ensureStateDir();
		const log = await open(BROKER_LOG_FILE, "a", 0o600);
		try {
			clientTrace.write("broker.launch");
			const child = spawn(process.execPath, [BROKER_ENTRY_FILE], {
				detached: true,
				stdio: ["ignore", log.fd, log.fd],
				env: process.env,
			});
			await new Promise((resolve, reject) => {
				child.once("spawn", resolve);
				child.once("error", reject);
			});
			child.unref();
		} finally {
			await log.close();
		}
	}
}

// This deduplicates startup inside one Pi process. The broker's filesystem
// startup lock performs the corresponding election across separate Pi processes.
export const brokerManager = new BrokerManager();
