import { randomBytes, randomUUID, timingSafeEqual } from "node:crypto";
import { constants } from "node:fs";
import { mkdir, lstat, open, link, unlink } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";

export const STATE_DIR = join(homedir(), ".config", "figpie");
export const TOKEN_FILE = join(STATE_DIR, "pairing-token");
export const TOKEN_PATTERN = /^[a-f0-9]{64}$/;

export function tokenMatches(candidate, token) {
	return typeof candidate === "string" && TOKEN_PATTERN.test(candidate) &&
		TOKEN_PATTERN.test(token) && timingSafeEqual(Buffer.from(candidate), Buffer.from(token));
}

function assertPrivate(stat, path, directory = false) {
	if ((directory ? !stat.isDirectory() : !stat.isFile()) || stat.isSymbolicLink() ||
		(process.getuid && stat.uid !== process.getuid()) || (process.platform !== "win32" && (stat.mode & 0o077))) {
		throw new Error(`Figpie requires a private ${directory ? "directory (0700)" : "file (0600)"}: ${path}`);
	}
}

export async function ensureToken(directory = STATE_DIR) {
	await mkdir(directory, { recursive: true, mode: 0o700 });
	assertPrivate(await lstat(directory), directory, true);
	const path = join(directory, "pairing-token");
	// Publish only a fully written token. Concurrent Pi startups cannot read a partial file.
	const temporary = join(directory, `.token-${randomUUID()}`);
	const file = await open(temporary, "wx", 0o600);
	try {
		await file.writeFile(randomBytes(32).toString("hex"));
		await file.close();
		try { await link(temporary, path); } catch (error) { if (error.code !== "EEXIST") throw error; }
	} finally {
		await file.close();
		await unlink(temporary).catch(() => {});
	}
	const stored = await open(path, constants.O_RDONLY | (constants.O_NOFOLLOW || 0));
	try {
		const stat = await stored.stat();
		assertPrivate(stat, path);
		if (stat.size !== 64) throw new Error(`Invalid Figpie pairing token: ${path}`);
		const token = await stored.readFile("utf8");
		if (!TOKEN_PATTERN.test(token)) throw new Error(`Invalid Figpie pairing token: ${path}`);
		return token;
	} finally { await stored.close(); }
}
