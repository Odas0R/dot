#!/usr/bin/env node

import { getAgentPage } from "./browser-session.js";

const code = process.argv.slice(2).join(" ");
if (!code) {
	console.log("Usage: browser-eval.js 'code'");
	console.log("\nExamples:");
	console.log('  browser-eval.js "document.title"');
	console.log("  browser-eval.js \"document.querySelectorAll('a').length\"");
	process.exit(1);
}

const { browser, page } = await getAgentPage();

const result = await page.evaluate((source) => {
	const AsyncFunction = (async () => {}).constructor;
	return new AsyncFunction(`return (${source})`)();
}, code);

if (typeof result === "string") {
	console.log(result);
} else if (result === undefined) {
	console.log("undefined");
} else {
	console.log(
		JSON.stringify(result, (_, value) =>
			typeof value === "bigint" ? value.toString() : value,
		),
	);
}

await browser.disconnect();
