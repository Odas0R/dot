#!/usr/bin/env node

import { tmpdir } from "node:os";
import { join } from "node:path";
import { getAgentPage } from "./browser-session.js";

const { browser, page } = await getAgentPage();
const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
const filepath = join(tmpdir(), `screenshot-${timestamp}.png`);

await page.screenshot({ path: filepath });
console.log(filepath);
await browser.disconnect();
