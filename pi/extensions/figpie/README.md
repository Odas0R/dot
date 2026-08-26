# Figpie

This Pi extension registers one tool, `figma_use`. The tool sends JavaScript to a development plugin running in the open Figma Design file.

```text
Pi sessions → shared local broker → plugin UI → plugin sandbox → Figma Plugin API
```

A detached broker listens only on `127.0.0.1:3846`. It accepts multiple Pi sessions and multiple Figma plugin sessions. Each plugin receives a generated connection ID. Requests run sequentially within one Figma session and can run concurrently across different sessions. The broker does not expose an HTTP execution endpoint.

## Install

```bash
cd pi/extensions/figpie
npm install
```

In Figma Desktop:

1. Open a Figma Design file.
2. Open **Plugins → Development → Import plugin from manifest…**.
3. Select `pi/extensions/figpie/plugin/manifest.json` from this repository.
4. Run **Figpie** from the Development plugins menu.
5. Keep the small plugin window open while Pi uses `figma_use`. It shows the connection state and active file.

Reload Pi after the initial extension installation. The extension starts the local broker and connects the Pi session automatically. Start the Figpie plugin in Figma before Pi starts. If the automatic connection fails, Pi reports an error and continues to reconnect automatically. Use `/figpie-status` to inspect the connection. Closing a Pi session closes its client connection automatically. When multiple Figma sessions are connected, `figma_use` accepts an optional `connectionId`; agents discover and select it from the file/page inventory.

## Icon

`plugin/icon.svg` is the editable Figpie icon and `plugin/icon.png` is the 128 × 128 publishing asset. Figma plugin manifests do not have an icon field. Select `icon.png` in Figma's publishing modal if the plugin is published.

## Tool code format

The code is an async function body. `figma` is in scope.

```js
const nodes = figma.currentPage.selection;
return nodes.map((node) => ({ id: node.id, name: node.name, type: node.type }));
```

Do not add an async IIFE. Do not call `figma.closePlugin()`.

The bridge includes Figma's enhanced helpers:

```js
const frame = figma.createAutoLayout("VERTICAL")
const labels = frame.query("TEXT[name=Label]")
labels.set({ opacity: 0.5 })
await frame.screenshot()
return { frameId: frame.id, labelIds: labels.values(["id"]) }
```

Supported enhancements are `figma.createAutoLayout()`, `node.query()`, `node.matches()`, `node.set()`, and `node.screenshot()`.

## Security

`figma_use` permits arbitrary Figma Plugin API JavaScript. It can read, create, change, or delete content in the open file. Only run this extension and plugin with trusted agent instructions.

Scripts are not transactional. If code changes a node and then throws, the earlier change can remain.
