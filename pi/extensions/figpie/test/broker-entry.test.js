import test from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtemp, rm, symlink } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const brokerURL = new URL("../broker.js", import.meta.url);
const brokerFile = fileURLToPath(brokerURL);

function run(args) {
	// Fail before credential access or socket binding if the entry point runs.
	return spawnSync(process.execPath, args, {
		env: { ...process.env, PI_FIGPIE_PORT: "4000" },
		encoding: "utf8", timeout: 5000,
	});
}

test("broker CLI starts through real and symlinked extension paths", async t => {
	const directory = await mkdtemp(join(tmpdir(), "figpie-entry-test-"));
	t.after(() => rm(directory, { recursive: true, force: true }));
	const alias = join(directory, "extensions");
	await symlink(dirname(brokerFile), alias, process.platform === "win32" ? "junction" : "dir");
	for (const args of [[brokerFile], [join(alias, "broker.js")], ["--preserve-symlinks-main", join(alias, "broker.js")]]) {
		const result = run(args);
		assert.ifError(result.error);
		assert.equal(result.status, 1, `CLI must run its preflight: ${args.join(" ")}`);
		assert.match(result.stderr, /Figpie broker could not start: PI_FIGPIE_PORT is no longer supported/);
	}
});

test("importing the broker stays side-effect-free with absent or nonexistent argv entry paths", () => {
	for (const args of [[], ["/nonexistent/figpie-import-label.js"]]) {
		const result = run(["--input-type=module", "--eval", `await import(${JSON.stringify(brokerURL.href)})`, ...args]);
		assert.ifError(result.error);
		assert.equal(result.status, 0, result.stderr);
		assert.equal(result.stderr, "");
	}
});
