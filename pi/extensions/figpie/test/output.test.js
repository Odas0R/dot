import test from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, readdir, readFile, rm, stat } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { formatOutput, MAX_INLINE_BYTES, MAX_INLINE_LINES, MAX_INLINE_NODE_IDS } from "../output.js";

async function directory(t) {
	const path = await mkdtemp(join(tmpdir(), "figpie-output-test-"));
	t.after(() => rm(path, { recursive: true, force: true }));
	return path;
}
function assertBounded(result) {
	assert.ok(Buffer.byteLength(result.text) <= MAX_INLINE_BYTES);
	assert.ok(result.text.split("\n").length <= MAX_INLINE_LINES);
}

test("small results are unchanged and create no artifact", async t => {
	const path = await directory(t);
	for (const text of ["", "undefined", "hello\nworld", "42", '{"rootId":"1:2","issues":[]}', '{"createdNodeIds":["1:2"],"mutatedNodeIds":[]}']) {
		const result = await formatOutput(text, { directory: path });
		assert.deepEqual(result, { text, abbreviated: false });
	}
	assert.deepEqual(await readdir(path), []);
});

test("large ID lists retain root, refs, issues, other fields and a lossless private artifact", async t => {
	const path = await directory(t);
	const original = {
		rootId: "1:1", refs: { header: "1:2", content: "1:3" },
		createdNodeIds: Array.from({ length: 1000 }, (_, i) => `1:${i}`),
		mutatedNodeIds: ["2:1"], issues: [{ nodeId: "1:2", reason: "check wrapping" }],
		status: "built", nodeIdCounts: "user field must survive", fullResultFile: "user field",
	};
	const text = JSON.stringify(original);
	const result = await formatOutput(text, { directory: path });
	const compact = JSON.parse(result.text);
	assert.equal(compact.summary.rootId, original.rootId);
	assert.deepEqual(compact.summary.refs, original.refs);
	assert.deepEqual(compact.summary.issues, original.issues);
	assert.equal(compact.summary.status, original.status);
	assert.equal(compact.summary.nodeIdCounts, original.nodeIdCounts);
	assert.equal(compact.summary.fullResultFile, original.fullResultFile);
	assert.equal(compact.summary.createdNodeIds, undefined);
	assert.deepEqual(compact.nodeIdCounts, { createdNodeIds: 1000, mutatedNodeIds: 1 });
	assert.equal(compact.fullResultFile, result.outputFile);
	assert.equal(await readFile(result.outputFile, "utf8"), text);
	assert.ok(result.text.length < text.length / 4, "large manifests should yield materially smaller inline output");
	assertBounded(result);
	if (process.platform !== "win32") {
		assert.equal((await stat(result.outputFile)).mode & 0o777, 0o600);
		assert.equal((await stat(dirname(result.outputFile))).mode & 0o777, 0o700);
	}
});

test("ID threshold is combined across fields and does not silently deduplicate IDs", async t => {
	const path = await directory(t);
	const value = { createdNodeIds: Array(MAX_INLINE_NODE_IDS / 2).fill("1:1"), mutatedNodeIds: Array(MAX_INLINE_NODE_IDS / 2).fill("2:2") };
	assert.equal((await formatOutput(JSON.stringify(value), { directory: path })).abbreviated, false);
	value.createdNodeIds.push("1:1");
	const result = await formatOutput(JSON.stringify(value), { directory: path });
	assert.deepEqual(result.nodeIdCounts, { createdNodeIds: 26, mutatedNodeIds: 25 });
	assert.deepEqual(JSON.parse(await readFile(result.outputFile, "utf8")), value);
});

test("malformed or non-string ID fields are not interpreted as manifests", async t => {
	const path = await directory(t);
	for (const text of ['{"createdNodeIds":', JSON.stringify({ createdNodeIds: Array(60).fill(1) }), JSON.stringify({ createdNodeIds: Array(60).fill("1:1"), mutatedNodeIds: "not an array" }), JSON.stringify({ createdNodeIds: Array(60).fill("") })]) {
		assert.deepEqual(await formatOutput(text, { directory: path }), { text, abbreviated: false });
	}
});

test("oversized single-line JSON has a useful UTF-8-safe preview and exact full output", async t => {
	const path = await directory(t);
	const text = JSON.stringify({ data: "🎨".repeat(6000), issues: ["not visible in preview"] });
	const result = await formatOutput(text, { directory: path });
	assertBounded(result);
	assert.ok(result.text.startsWith('{"data":"🎨'));
	assert.equal(result.text.includes("\uFFFD"), false);
	assert.match(result.text, /Output abbreviated/);
	assert.match(result.text, /Inspect omitted data before assuming no issues/);
	assert.ok(result.text.includes(result.outputFile));
	assert.equal(await readFile(result.outputFile, "utf8"), text);
});

test("line and byte boundaries include the artifact notice", async t => {
	const path = await directory(t);
	for (const text of ["x".repeat(MAX_INLINE_BYTES), Array(MAX_INLINE_LINES).fill("x").join("\n")]) {
		assert.equal((await formatOutput(text, { directory: path })).abbreviated, false);
	}
	for (const text of ["x".repeat(MAX_INLINE_BYTES + 1), Array(MAX_INLINE_LINES + 1).fill("x").join("\n")]) {
		const result = await formatOutput(text, { directory: path });
		assert.equal(result.abbreviated, true);
		assertBounded(result);
		assert.equal(await readFile(result.outputFile, "utf8"), text);
	}
});

test("oversized summaries still retain a visible full-result path", async t => {
	const path = await directory(t);
	const text = JSON.stringify({ createdNodeIds: Array(60).fill("1:1"), issues: ["long issue ".repeat(2000)] });
	const result = await formatOutput(text, { directory: path });
	assertBounded(result);
	assert.ok(result.text.includes(result.outputFile));
	assert.deepEqual(result.nodeIdCounts, { createdNodeIds: 60 });
	assert.equal(await readFile(result.outputFile, "utf8"), text);
});

test("deep literal JSON falls back safely if the summary cannot be stringified", async t => {
	const path = await directory(t);
	const text = `{"createdNodeIds":${JSON.stringify(Array(60).fill("1:1"))},"data":${"[".repeat(20000)}0${"]".repeat(20000)}}`;
	const result = await formatOutput(text, { directory: path });
	assertBounded(result);
	assert.ok(result.text.includes(result.outputFile));
	assert.match(result.text, /Output abbreviated/);
	assert.equal(await readFile(result.outputFile, "utf8"), text);
});

test("artifact write failure reports uncertainty instead of pretending IDs were saved", async t => {
	const path = await directory(t);
	await assert.rejects(formatOutput(JSON.stringify({ createdNodeIds: Array(60).fill("1:1") }), { directory: join(path, "missing") }), /Could not save full Figpie output.*Changes may remain/);
});
