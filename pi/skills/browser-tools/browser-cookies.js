#!/usr/bin/env node

import { getAgentPage } from "./browser-session.js";

const { browser, page } = await getAgentPage();
const cookies = await page.cookies();

for (const cookie of cookies) {
	console.log(
		`${cookie.name}=${cookie.value}; domain=${cookie.domain}; path=${cookie.path}; httpOnly=${cookie.httpOnly}; secure=${cookie.secure}`,
	);
}

await browser.disconnect();
