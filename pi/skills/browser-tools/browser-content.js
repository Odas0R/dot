#!/usr/bin/env node

import { Readability } from "@mozilla/readability";
import { JSDOM } from "jsdom";
import TurndownService from "turndown";
import { gfm } from "turndown-plugin-gfm";
import { getAgentPage } from "./browser-session.js";

const TIMEOUT_MS = 30000;
const MAX_CONTENT_LENGTH = 30000;
const timeoutId = setTimeout(() => {
	console.error("✗ Timeout after 30s");
	process.exit(1);
}, TIMEOUT_MS).unref();

const url = process.argv[2];
if (!url) {
	console.log("Usage: browser-content.js <url>");
	console.log("\nExtracts readable content from a URL as markdown.");
	process.exit(1);
}

function htmlToMarkdown(html) {
	const turndown = new TurndownService({
		headingStyle: "atx",
		codeBlockStyle: "fenced",
	});
	turndown.use(gfm);
	turndown.addRule("removeEmptyLinks", {
		filter: (node) => node.nodeName === "A" && !node.textContent?.trim(),
		replacement: () => "",
	});
	return turndown
		.turndown(html)
		.replace(/\[\\?\[\s*\\?\]\]\([^)]*\)/g, "")
		.replace(/\s+,/g, ",")
		.replace(/\s+\./g, ".")
		.replace(/\n{3,}/g, "\n\n")
		.trim();
}

let browser;
let page;
try {
	({ browser, page } = await getAgentPage());

	await page.goto(url, {
		waitUntil: "domcontentloaded",
		timeout: 10000,
	});
	try {
		await page.waitForNetworkIdle({ idleTime: 500, timeout: 5000 });
	} catch (error) {
		if (error.name !== "TimeoutError") throw error;
	}

	const outerHTML = await page.content();
	const finalUrl = page.url();
	const doc = new JSDOM(outerHTML, { url: finalUrl });
	const article = new Readability(doc.window.document).parse();

	let content;
	if (article?.content) {
		content = htmlToMarkdown(article.content);
	} else {
		const fallbackDoc = new JSDOM(outerHTML, { url: finalUrl });
		const fallbackBody = fallbackDoc.window.document;
		fallbackBody
			.querySelectorAll("script, style, noscript, nav, header, footer, aside")
			.forEach((element) => element.remove());
		const main =
			fallbackBody.querySelector(
				"main, article, [role='main'], .content, #content",
			) || fallbackBody.body;
		const fallbackHtml = main?.innerHTML || "";
		content =
			fallbackHtml.trim().length > 100
				? htmlToMarkdown(fallbackHtml)
				: "(Could not extract content)";
	}

	if (content.length > MAX_CONTENT_LENGTH) {
		content = `${content.slice(0, MAX_CONTENT_LENGTH)}\n\n[Content truncated at ${MAX_CONTENT_LENGTH} characters]`;
	}

	console.log(`URL: ${finalUrl}`);
	if (article?.title) console.log(`Title: ${article.title}`);
	console.log("");
	console.log(content);
} finally {
	clearTimeout(timeoutId);
	await browser?.disconnect().catch(() => {});
}
