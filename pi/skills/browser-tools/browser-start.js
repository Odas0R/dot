#!/usr/bin/env node

import { spawn } from "node:child_process";
import { existsSync, mkdirSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import puppeteer from "puppeteer-core";

if (process.argv.length > 2) {
	console.log("Usage: browser-start.js");
	process.exit(1);
}

const BROWSER_URL = "http://localhost:9222";
const CHROME_PATH = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const PROFILE_DIR = join(homedir(), ".cache", "browser-tools");

async function tryConnect() {
	return await puppeteer.connect({
		browserURL: BROWSER_URL,
		defaultViewport: null,
	});
}

try {
	const browser = await tryConnect();
	await browser.disconnect();
	console.log("✓ Chrome already running on :9222 and ready");
	process.exit(0);
} catch {}

if (!existsSync(CHROME_PATH)) {
	console.error(`✗ Google Chrome not found at: ${CHROME_PATH}`);
	process.exit(1);
}

mkdirSync(PROFILE_DIR, { recursive: true });

spawn(
	CHROME_PATH,
	[
		"--remote-debugging-port=9222",
		`--user-data-dir=${PROFILE_DIR}`,
		"--no-first-run",
		"--no-default-browser-check",
		"--disable-extensions",
		"--disable-sync",
		"--disable-default-apps",
		"--disable-background-networking",
		"--disable-search-engine-choice-screen",
		"--hide-crash-restore-bubble",
		"--noerrdialogs",
		"--password-store=basic",
		"--use-mock-keychain",
	],
	{ detached: true, stdio: "ignore" },
).unref();

let connected = false;
for (let attempt = 0; attempt < 30; attempt++) {
	try {
		const browser = await tryConnect();
		await browser.disconnect();
		connected = true;
		break;
	} catch {
		await new Promise((resolve) => setTimeout(resolve, 500));
	}
}

if (!connected) {
	console.error("✗ Failed to connect to Chrome on :9222");
	process.exit(1);
}

console.log("✓ Chrome started on :9222");
