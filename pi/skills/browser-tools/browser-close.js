#!/usr/bin/env node

import puppeteer from "puppeteer-core";

if (process.argv.length > 2) {
	console.log("Usage: browser-close.js");
	process.exit(1);
}

const BROWSER_URL = "http://localhost:9222";
const MARKER_NAME = "__browser_tools_pi_session";

const sessionId = process.env.PI_SESSION_ID || "manual";
let browser;

try {
	browser = await puppeteer.connect({
		browserURL: BROWSER_URL,
		defaultViewport: null,
	});
} catch {
	console.log("✓ Chrome is not running");
	process.exit(0);
}

const defaultContext = browser.defaultBrowserContext();
const contexts = browser.browserContexts().filter(
	(context) => context !== defaultContext,
);
const matchingContexts = [];

for (const context of contexts) {
	try {
		const cookies = await context.cookies();
		if (
			cookies.some(
				(cookie) =>
					cookie.name === MARKER_NAME &&
					cookie.domain === "browser-tools.invalid" &&
					cookie.value === sessionId,
			)
		) {
			matchingContexts.push(context);
		}
	} catch {
		// The context can close while contexts are inspected.
	}
}

await Promise.all(matchingContexts.map((context) => context.close()));

const otherContexts = browser
	.browserContexts()
	.filter((context) => context !== defaultContext);

if (otherContexts.length === 0) {
	await browser.close();
	console.log("✓ Browser session closed; Chrome stopped");
} else {
	await browser.disconnect();
	console.log("✓ Browser session closed; Chrome kept open for other sessions");
}
