#!/usr/bin/env node

import { mkdir, rm, stat } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import puppeteer from "puppeteer-core";

const BROWSER_URL = "http://localhost:9222";
const MARKER_URL = "https://browser-tools.invalid/";
const MARKER_NAME = "__browser_tools_pi_session";
const LOCKS_DIR = join(homedir(), ".cache", "browser-tools", "locks");
const LOCK_WAIT_MS = 50;
const LOCK_TIMEOUT_MS = 5000;
const STALE_LOCK_MS = 10000;

function getSessionId() {
	return process.env.PI_SESSION_ID || "manual";
}

function getLockPath(sessionId) {
	const safeId = sessionId.replace(/[^a-zA-Z0-9_-]/g, "_").slice(0, 100);
	return join(LOCKS_DIR, `${safeId || "manual"}.lock`);
}

async function acquireContextLock(sessionId) {
	await mkdir(LOCKS_DIR, { recursive: true });
	const lockPath = getLockPath(sessionId);
	const deadline = Date.now() + LOCK_TIMEOUT_MS;

	while (true) {
		try {
			await mkdir(lockPath);
			return async () => await rm(lockPath, { recursive: true, force: true });
		} catch (error) {
			if (error.code !== "EEXIST") throw error;

			try {
				const lockStat = await stat(lockPath);
				if (Date.now() - lockStat.mtimeMs > STALE_LOCK_MS) {
					await rm(lockPath, { recursive: true, force: true });
					continue;
				}
			} catch (statError) {
				if (statError.code === "ENOENT") continue;
				throw statError;
			}

			if (Date.now() >= deadline) {
				throw new Error(`Timed out waiting for browser context lock: ${sessionId}`);
			}
			await new Promise((resolve) => setTimeout(resolve, LOCK_WAIT_MS));
		}
	}
}

async function connectBrowser() {
	try {
		return await Promise.race([
			puppeteer.connect({
				browserURL: BROWSER_URL,
				defaultViewport: null,
			}),
			new Promise((_, reject) => {
				setTimeout(() => reject(new Error("timeout")), 5000).unref();
			}),
		]);
	} catch (error) {
		const connectionError = new Error(error.message);
		connectionError.code = "BROWSER_CONNECTION";
		throw connectionError;
	}
}

async function findAgentContexts(browser, sessionId) {
	const defaultContext = browser.defaultBrowserContext();
	const matches = [];

	for (const context of browser.browserContexts()) {
		if (context === defaultContext) continue;

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
				matches.push(context);
			}
		} catch {
			// The context can close while contexts are inspected.
		}
	}

	return matches;
}

async function getAgentContext(browser, sessionId) {
	const matches = await findAgentContexts(browser, sessionId);
	if (matches.length > 0) {
		const [context, ...duplicates] = matches;
		await Promise.all(
			duplicates.map((duplicate) => duplicate.close().catch(() => {})),
		);
		return context;
	}

	const context = await browser.createBrowserContext();
	try {
		await context.setCookie({
			name: MARKER_NAME,
			value: sessionId,
			url: MARKER_URL,
			httpOnly: true,
			secure: true,
			sameSite: "Strict",
		});
		return context;
	} catch (error) {
		await context.close().catch(() => {});
		throw error;
	}
}

async function openAgentPage(options) {
	const sessionId = getSessionId();
	const releaseLock = await acquireContextLock(sessionId);
	let browser;

	try {
		browser = await connectBrowser();
		const context = await getAgentContext(browser, sessionId);
		const pages = await context.pages();
		const page = options.newPage
			? await context.newPage()
			: pages.at(-1) || (await context.newPage());
		return { browser, context, page };
	} catch (error) {
		await browser?.disconnect().catch(() => {});
		throw error;
	} finally {
		await releaseLock();
	}
}

export async function getAgentPage({ newPage = false } = {}) {
	try {
		return await openAgentPage({ newPage });
	} catch (error) {
		if (error.code === "BROWSER_CONNECTION") {
			console.error("✗ Could not connect to browser:", error.message);
			console.error("  Run: browser-start.js");
			process.exit(1);
		}
		throw error;
	}
}
