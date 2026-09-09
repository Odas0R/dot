import { mkdtemp, writeFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

export const MAX_INLINE_BYTES = 8 * 1024;
export const MAX_INLINE_LINES = 200;
export const MAX_INLINE_NODE_IDS = 50;

const ID_FIELDS = ["createdNodeIds", "mutatedNodeIds"];

function fits(text) {
	return (
		Buffer.byteLength(text, "utf8") <= MAX_INLINE_BYTES &&
		text.split("\n", MAX_INLINE_LINES + 1).length <= MAX_INLINE_LINES
	);
}

// A minified JSON response can be one very long line. Keep a useful prefix rather
// than dropping that entire line; never split a UTF-8 character.
function prefix(text, maxBytes, maxLines) {
	let bytes = 0;
	let lines = 1;
	let end = 0;
	for (const character of text) {
		const size = Buffer.byteLength(character, "utf8");
		if (bytes + size > maxBytes || (character === "\n" && lines === maxLines)) break;
		bytes += size;
		if (character === "\n") lines++;
		end += character.length;
	}
	return text.slice(0, end);
}

function compactManifest(text) {
	if (!text.trimStart().startsWith("{")) return;
	let value;
	try {
		value = JSON.parse(text);
	} catch {
		return;
	}
	if (!value || Array.isArray(value) || typeof value !== "object") return;
	const fields = ID_FIELDS.filter((key) => Object.hasOwn(value, key));
	if (
		!fields.length ||
		fields.some(
			(key) => !Array.isArray(value[key]) || !value[key].every((id) => typeof id === "string" && id.length > 0),
		)
	)
		return;
	const nodeIdCounts = Object.fromEntries(fields.map((key) => [key, value[key].length]));
	if (Object.values(nodeIdCounts).reduce((sum, count) => sum + count, 0) <= MAX_INLINE_NODE_IDS) return;
	// Retain all other properties, including issues/errors and named references.
	// Wrap the summary instead of changing the type of the caller's ID fields.
	const summary = Object.fromEntries(Object.entries(value).filter(([key]) => !fields.includes(key)));
	return { summary, nodeIdCounts };
}

async function saveOutput(text, directory) {
	const outputDir = await mkdtemp(join(directory, "pi-figpie-"));
	try {
		const outputFile = join(outputDir, "result.txt");
		await writeFile(outputFile, text, { mode: 0o600 });
		return outputFile;
	} catch (error) {
		await rm(outputDir, { recursive: true, force: true }).catch(() => {});
		throw error;
	}
}

export async function formatOutput(text, { directory = tmpdir() } = {}) {
	if (typeof text !== "string") throw new TypeError("Figpie output must be text");
	const manifest = compactManifest(text);
	if (!manifest && fits(text)) return { text, abbreviated: false };

	// Save the original received bytes before abbreviating anything. This is not
	// an automatic mutation tracker: IDs must be supplied by the script.
	let outputFile;
	try {
		outputFile = await saveOutput(text, directory);
	} catch (error) {
		throw new Error(
			`Could not save full Figpie output: ${error.message}. Changes may remain; inspect Figma before retrying.`,
		);
	}

	let preview = text;
	let summarized = false;
	if (manifest) {
		try {
			preview = JSON.stringify({ ...manifest, fullResultFile: outputFile });
			summarized = true;
		} catch {
			// A literal JSON string can be deeper than JSON.stringify's stack
			// limit. Still deliver a bounded preview and the saved-result path.
		}
	}
	if (summarized && fits(preview))
		return { text: preview, outputFile, abbreviated: true, nodeIdCounts: manifest.nodeIdCounts };

	const notice = `\n\n[Output abbreviated. Full result: ${outputFile}. Inspect omitted data before assuming no issues.]`;
	const excerpt = prefix(preview, MAX_INLINE_BYTES - Buffer.byteLength(notice), MAX_INLINE_LINES - 2);
	return { text: excerpt + notice, outputFile, abbreviated: true, nodeIdCounts: manifest?.nodeIdCounts };
}
