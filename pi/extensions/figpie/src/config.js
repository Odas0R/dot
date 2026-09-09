import { lstat, mkdir } from "node:fs/promises";
import { homedir } from "node:os";
import { join, resolve } from "node:path";

export const STATE_DIR = join(homedir(), ".config", "figpie");
export const SOCKET_PATH = join(STATE_DIR, "broker.sock");
export const APP_PATH = resolve(process.env.PI_FIGPIE_APP_PATH || "/Applications/Figma.app");
// Dedicated to Figpie; keep clear of the usual browser-debugging ports.
export const CDP_PORT = Number(process.env.PI_FIGPIE_CDP_PORT || 3847);
// Bump when changing the IPC contract or injected runtime; old brokers must not be reused.
export const VERSION = 5;
export const MAX_MESSAGE_BYTES = 16 * 1024 * 1024;
export const MAX_CODE_BYTES = 1024 * 1024;
export const MAX_IMAGE_BYTES = 8 * 1024 * 1024;
export const MAX_IMAGES = 10;
export const UNCERTAIN =
	"Execution may still be running and changes may remain. Inspect before retrying. If stuck, ask the user to close/reopen the Figma file; never replay the script blindly.";

// The directory is the authentication boundary for our Unix socket and backups.
export async function ensureStateDir({ create = true } = {}) {
	if (process.platform === "win32")
		throw new Error("Figpie requires Unix-domain sockets; desktop repair currently supports macOS only.");
	if (!Number.isInteger(CDP_PORT) || CDP_PORT < 1 || CDP_PORT > 65535)
		throw new Error("PI_FIGPIE_CDP_PORT must be an integer from 1 to 65535.");
	if (create) await mkdir(STATE_DIR, { recursive: true, mode: 0o700 });
	const stat = await lstat(STATE_DIR);
	if (!stat.isDirectory() || stat.isSymbolicLink() || stat.uid !== process.getuid() || stat.mode & 0o077) {
		throw new Error(`Figpie state directory must be owned by you with mode 0700: ${STATE_DIR}`);
	}
}
