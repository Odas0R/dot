#!/usr/bin/env node

import { getAgentPage } from "./browser-session.js";

const message = process.argv.slice(2).join(" ");
if (!message) {
	console.log("Usage: browser-pick.js 'message'");
	console.log("\nExample:");
	console.log('  browser-pick.js "Click the submit button"');
	process.exit(1);
}

const { browser, page } = await getAgentPage();
await page.bringToFront();

const result = await page.evaluate((prompt) => {
	return new Promise((resolve) => {
		const selections = [];
		const selectedElements = new Set();
		const originalOutlines = new Map();

		const overlay = document.createElement("div");
		overlay.style.cssText =
			"position:fixed;inset:0;z-index:2147483646;pointer-events:none";

		const highlight = document.createElement("div");
		highlight.style.cssText =
			"position:fixed;border:2px solid #3b82f6;background:rgba(59,130,246,0.1);transition:all 0.1s";
		overlay.appendChild(highlight);

		const banner = document.createElement("div");
		banner.style.cssText =
			"position:fixed;bottom:20px;left:50%;transform:translateX(-50%);background:#1f2937;color:white;padding:12px 24px;border-radius:8px;font:14px sans-serif;box-shadow:0 4px 12px rgba(0,0,0,0.3);pointer-events:auto;z-index:2147483647";

		const updateBanner = () => {
			banner.textContent = `${prompt} (${selections.length} selected, Cmd/Ctrl+click to add, Enter to finish, ESC to cancel)`;
		};
		updateBanner();
		document.body.append(overlay, banner);

		const uniqueSelector = (element) => {
			if (element.id) {
				const selector = `#${CSS.escape(element.id)}`;
				const matches = document.querySelectorAll(selector);
				if (matches.length === 1 && matches[0] === element) return selector;
			}

			const parts = [];
			let current = element;
			while (current) {
				let part = current.localName;
				if (!part) break;

				const parent = current.parentElement;
				if (parent) {
					const siblings = Array.from(parent.children).filter(
						(sibling) => sibling.localName === current.localName,
					);
					if (siblings.length > 1) {
						part += `:nth-of-type(${siblings.indexOf(current) + 1})`;
					}
				}

				parts.unshift(part);
				const selector = parts.join(" > ");
				const matches = document.querySelectorAll(selector);
				if (matches.length === 1 && matches[0] === element) return selector;
				current = parent;
			}

			return parts.join(" > ");
		};

		const elementInfo = (element) => ({
			selector: uniqueSelector(element),
			text:
				element.textContent?.trim().replace(/\s+/g, " ").slice(0, 200) || null,
		});

		const cleanup = () => {
			document.removeEventListener("mousemove", onMove, true);
			document.removeEventListener("click", onClick, true);
			document.removeEventListener("keydown", onKey, true);
			overlay.remove();
			banner.remove();
			for (const [element, outline] of originalOutlines) {
				element.style.outline = outline;
			}
		};

		const onMove = (event) => {
			const element = document.elementFromPoint(event.clientX, event.clientY);
			if (!element || banner.contains(element)) return;
			const rect = element.getBoundingClientRect();
			highlight.style.top = `${rect.top}px`;
			highlight.style.left = `${rect.left}px`;
			highlight.style.width = `${rect.width}px`;
			highlight.style.height = `${rect.height}px`;
		};

		const onClick = (event) => {
			if (banner.contains(event.target)) return;
			event.preventDefault();
			event.stopPropagation();
			const element = document.elementFromPoint(event.clientX, event.clientY);
			if (!element || banner.contains(element)) return;

			if (event.metaKey || event.ctrlKey) {
				if (!selectedElements.has(element)) {
					selectedElements.add(element);
					originalOutlines.set(element, element.style.outline);
					element.style.outline = "3px solid #10b981";
					selections.push(elementInfo(element));
					updateBanner();
				}
				return;
			}

			const info = elementInfo(element);
			cleanup();
			resolve(selections.length > 0 ? selections : info);
		};

		const onKey = (event) => {
			if (event.key === "Escape") {
				event.preventDefault();
				cleanup();
				resolve(null);
			} else if (event.key === "Enter" && selections.length > 0) {
				event.preventDefault();
				cleanup();
				resolve(selections);
			}
		};

		document.addEventListener("mousemove", onMove, true);
		document.addEventListener("click", onClick, true);
		document.addEventListener("keydown", onKey, true);
	});
}, message);

console.log(JSON.stringify(result));
await browser.disconnect();
