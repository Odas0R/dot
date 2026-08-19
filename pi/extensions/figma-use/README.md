# Pi Figma Use Bridge

This Pi extension registers one tool, `figma_use`. The tool sends JavaScript to a development plugin running in the open Figma Design file.

```text
Pi sessions → shared local broker → plugin UI → plugin sandbox → Figma Plugin API
```

A detached broker listens only on `localhost:3846`. It accepts multiple Pi sessions and one active Figma plugin. Requests from all sessions run sequentially to prevent shared page and document state from racing. It does not expose an HTTP execution endpoint.

## Install

```bash
cd pi/extensions/figma-use
npm install
```

In Figma Desktop:

1. Open a Figma Design file.
2. Open **Plugins → Development → Import plugin from manifest…**.
3. Select `pi/extensions/figma-use/plugin/manifest.json` from this repository.
4. Run **Pi Figma Use Bridge** from the Development plugins menu.
5. Keep the small plugin window open while Pi uses `figma_use`. It shows the connection state and active file.

Reload Pi after the initial extension installation. Use `/figma-use-status` to check the shared broker and active file. Additional Pi sessions connect to the same broker automatically.

## Tool code format

The code is an async function body. `figma` is in scope.

```js
const nodes = figma.currentPage.selection;
return nodes.map((node) => ({ id: node.id, name: node.name, type: node.type }));
```

Do not add an async IIFE. Do not call `figma.closePlugin()`.

## Security

`figma_use` permits arbitrary Figma Plugin API JavaScript. It can read, create, change, or delete content in the open file. Only run this extension and plugin with trusted agent instructions.

Scripts are not transactional. If code changes a node and then throws, the earlier change can remain.
