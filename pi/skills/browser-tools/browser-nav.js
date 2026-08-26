#!/usr/bin/env node

import { getAgentPage } from "./browser-session.js";

const args = process.argv.slice(2);
const newTab = args.includes("--new");
const reload = args.includes("--reload");
const url = args.find((arg) => !arg.startsWith("--"));

if (!url) {
	console.log("Usage: browser-nav.js <url> [--new] [--reload]");
	console.log("\nExamples:");
	console.log("  browser-nav.js https://example.com          # Navigate current tab");
	console.log("  browser-nav.js https://example.com --new    # Open in new tab");
	console.log("  browser-nav.js https://example.com --reload # Navigate without cache");
	process.exit(1);
}

const { browser, page } = await getAgentPage({ newPage: newTab });

if (reload) await page.setCacheEnabled(false);
try {
	await page.goto(url, { waitUntil: "domcontentloaded" });
} finally {
	if (reload) await page.setCacheEnabled(true).catch(() => {});
}

console.log(newTab ? "✓ Opened:" : "✓ Navigated to:", url);
await browser.disconnect();
