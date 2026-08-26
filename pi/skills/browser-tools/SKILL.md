---
name: browser-tools
description: Interactive browser automation via Chrome DevTools Protocol. Use when you need to interact with web pages, test frontends, or require user interaction with a visible browser.
---

# Browser Tools

These scripts connect to Chrome on `:9222`. Resolve all `./...` paths relative to this skill directory, and use the resolved absolute paths in shell commands.

Browser Tools automatically isolates each pi session. Tabs in the same session share authentication and storage until Chrome stops.

## Setup

Run once from this skill directory:

```bash
npm install
```

## Start Chrome

```bash
./browser-start.js
```

Run it in the foreground. It exits when Chrome is ready and leaves Chrome running. Do not add `&` or a startup delay.

## Navigate

```bash
./browser-nav.js https://example.com
./browser-nav.js https://example.com --new
./browser-nav.js https://example.com --reload
```

Navigation reuses the session's latest tab. `--new` creates a tab in the same isolated session. `--reload` navigates without cache.

## Evaluate JavaScript

```bash
./browser-eval.js 'document.title'
./browser-eval.js 'Array.from(document.querySelectorAll("button"), e => ({text: e.textContent.trim(), disabled: e.disabled}))'
```

The argument must be one JavaScript expression. Use an IIFE for multiple statements:

```bash
./browser-eval.js '(() => { const button = document.querySelector("button"); button.click(); return {text: button.textContent}; })()'
```

### Complex Scripts in Single Calls

Combine related inspection, interaction, and state collection in one evaluation. This reduces browser round trips and keeps each operation consistent with one page state.

Wrap multiple statements in an IIFE and return structured data:

```javascript
(() => {
  const target = document.querySelector("#target");
  const buttons = Array.from(document.querySelectorAll("button"));

  target?.click();

  return {
    targetText: target?.textContent.trim(),
    buttonCount: buttons.length,
    disabledButtons: buttons.filter(button => button.disabled).length
  };
})()
```

When an interaction updates the DOM asynchronously, wait inside the same evaluation:

```javascript
(async () => {
  document.querySelector("#submit")?.click();
  await new Promise(resolve => setTimeout(resolve, 500));
  return {
    status: document.querySelector("[role='status']")?.textContent.trim()
  };
})()
```

## Screenshot

```bash
./browser-screenshot.js
```

Returns the path to a viewport screenshot. Use it for visual or layout checks, not basic page-state inspection.

## Pick Elements

```bash
./browser-pick.js "Select the submit button"
```

Use this when the user must select elements. The picker returns compact CSS selectors and text. Use Cmd/Ctrl+click for multiple elements, Enter to finish, or Escape to cancel. Run only one picker at a time.

## Cookies

```bash
./browser-cookies.js
```

Displays application cookies visible to the session's latest tab.

## Extract Page Content

```bash
./browser-content.js https://example.com
```

Navigates to the URL and returns readable Markdown. Output is limited to 30,000 characters.

## Recovery

If a command cannot connect, run `./browser-start.js` once and retry the command. Do not kill Chrome unless startup also fails.

## Efficiency

1. Inspect the DOM before taking a screenshot.
2. Batch related interactions and reads in one evaluation.
3. Limit returned HTML and text with `slice()`.

Example inspection:

```javascript
({
  title: document.title,
  buttons: Array.from(document.querySelectorAll("button"), element => ({
    text: element.textContent.trim(),
    disabled: element.disabled
  })),
  main: document.querySelector("main")?.innerText.slice(0, 3000)
})
```
