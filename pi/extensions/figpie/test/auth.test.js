import test from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, rm, stat, chmod, symlink, writeFile, readdir } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { ensureToken, tokenMatches } from "../auth.js";
import { validatePortEnvironment, BRIDGE_URL } from "../protocol.js";
import { readFileSync } from "node:fs";

async function directory(t) {
	const path = await mkdtemp(join(tmpdir(), "figpie-auth-test-"));
	t.after(() => rm(path, { recursive: true, force: true }));
	return path;
}
test("concurrent starts share one fully published private token", async t => {
	const path = await directory(t);
	const tokens = await Promise.all(Array.from({ length: 12 }, () => ensureToken(path)));
	assert.equal(new Set(tokens).size, 1);
	assert.match(tokens[0], /^[a-f0-9]{64}$/);
	assert.equal(tokenMatches(tokens[0], tokens[0]), true);
	assert.equal(tokenMatches("bad", tokens[0]), false);
	assert.deepEqual(await readdir(path), ["pairing-token"]);
	if (process.platform !== "win32") assert.equal((await stat(join(path, "pairing-token"))).mode & 0o777, 0o600);
});
test("rejects public credentials and symlink token files", { skip: process.platform === "win32" }, async t => {
	const path = await directory(t);
	await ensureToken(path);
	await chmod(join(path, "pairing-token"), 0o644);
	await assert.rejects(ensureToken(path), /private file/);
	await rm(join(path, "pairing-token"));
	await writeFile(join(path, "other"), "a".repeat(64), { mode: 0o600 });
	await symlink(join(path, "other"), join(path, "pairing-token"));
	await assert.rejects(ensureToken(path));
});
test("fixed endpoint matches UI/manifest and rejects unsupported overrides", () => {
	const ui = readFileSync(new URL("../plugin/ui.html", import.meta.url), "utf8");
	const manifest = JSON.parse(readFileSync(new URL("../plugin/manifest.json", import.meta.url), "utf8"));
	assert.ok(ui.includes(`const URL = "${BRIDGE_URL}"`));
	assert.ok(manifest.networkAccess.allowedDomains.includes(new URL(BRIDGE_URL).origin));
	validatePortEnvironment({ PI_FIGPIE_PORT: "3846" });
	for (const value of ["0", "bad", "3846foo", "4000"]) assert.throws(() => validatePortEnvironment({ PI_FIGPIE_PORT: value }), /no longer supported/);
});
