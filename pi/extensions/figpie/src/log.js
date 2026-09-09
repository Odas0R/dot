import { appendFileSync, constants, lstatSync, mkdirSync, renameSync, statSync } from "node:fs";
import { randomUUID } from "node:crypto";
import { join } from "node:path";
import { STATE_DIR } from "./config.js";

export const LOG_DIR = join(STATE_DIR, "logs");

export function errorDetails(error) {
	return { name: error?.name, message: String(error?.message || error), stack: error?.stack, code: error?.code };
}

// One writer per file: concurrent Pi processes and brokers cannot race rotation.
// Keep image bytes out of traces; scripts and returned text may contain private data.
export function createTrace(
	source,
	{ directory = LOG_DIR, maxBytes = 32 * 1024 * 1024, backups = 2, warn = (message) => console.error(message) } = {},
) {
	const file = join(directory, `${source}-${process.pid}-${randomUUID()}.jsonl`);
	let initialized = false;
	let bytes = 0;
	let lastError;
	let warned = false;
	function write(event, fields = {}) {
		try {
			if (!initialized) {
				mkdirSync(directory, { recursive: true, mode: 0o700 });
				const stat = lstatSync(directory);
				if (
					!stat.isDirectory() ||
					stat.isSymbolicLink() ||
					(process.getuid && stat.uid !== process.getuid()) ||
					(process.platform !== "win32" && stat.mode & 0o077)
				)
					throw new Error("Log directory must be private (0700)");
				initialized = true;
			}
			const line =
				JSON.stringify({ ...fields, time: new Date().toISOString(), pid: process.pid, source, event }) + "\n";
			const size = Buffer.byteLength(line);
			if (bytes && bytes + size > maxBytes) {
				for (let index = backups; index >= 1; index--) {
					try {
						renameSync(index === 1 ? file : `${file}.${index - 1}`, `${file}.${index}`);
					} catch (error) {
						if (error.code !== "ENOENT") throw error;
					}
				}
				bytes = 0;
			}
			appendFileSync(file, line, {
				mode: 0o600,
				flag: constants.O_WRONLY | constants.O_CREAT | constants.O_APPEND | (constants.O_NOFOLLOW || 0),
			});
			bytes = statSync(file).size;
			lastError = undefined;
			return true;
		} catch (error) {
			lastError = String(error.message || error);
			if (!warned) {
				warned = true;
				try {
					warn(`Figpie tracing unavailable (${file}): ${lastError}`);
				} catch {}
			}
			return false; // Observability must never change execution/retry semantics.
		}
	}
	return {
		file,
		write,
		get lastError() {
			return lastError;
		},
	};
}

export const clientTrace = createTrace("client");
export const brokerTrace = createTrace("broker");
