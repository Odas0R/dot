import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { MAX_INLINE_BYTES, MAX_INLINE_LINES, MAX_INLINE_NODE_IDS } from "../output.js";

const extension = readFileSync(new URL("../index.js", import.meta.url), "utf8");
const skill = readFileSync(new URL("../../../skills/figma-use/SKILL.md", import.meta.url), "utf8");
const readme = readFileSync(new URL("../README.md", import.meta.url), "utf8");

test("skill and tool agree on session-scoped loading and invalidation", () => {
	for (const source of [extension, skill, readme]) {
		assert.match(source, /once per agent session/);
		assert.match(source, /[Rr]eload after/);
		assert.match(source, /context/);
	}
	assert.doesNotMatch(skill, /BEFORE every `figma_use`|Before anything, load/);
	assert.doesNotMatch(extension, /Keep figma_use calls small/);
});

test("upstream section structure remains while fixed-count batching is replaced", () => {
	assert.deepEqual([...skill.matchAll(/^## (\d+)\./gm)].map(match => Number(match[1])), Array.from({ length: 11 }, (_, i) => i + 1));
	assert.match(skill, /inspect → build → validate → correct/);
	assert.match(skill, /No fixed operation-count limit/);
	assert.match(skill, /preflight/i);
	assert.match(skill, /Inspect partial changes|partial changes/);
	assert.doesNotMatch(skill, /At most 10 logical operations/);
});

test("documented compact-output thresholds match the formatter", () => {
	for (const source of [skill, readme]) {
		assert.ok(source.includes(`${MAX_INLINE_BYTES / 1024} KiB`));
		assert.ok(source.includes(`${MAX_INLINE_LINES} lines`));
		assert.ok(source.includes(`${MAX_INLINE_NODE_IDS} IDs`));
		assert.ok(source.includes("fullResultFile"));
	}
});
