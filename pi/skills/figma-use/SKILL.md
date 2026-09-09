---
name: figma-use
description: "Load once per agent session before the first figma_use call for scripted Figma inspection or edits: nodes, components, variables, styles, and layout. Reuse across calls; reload after skill/runtime changes or lost guidance. Uses stage-based batching and compact results."
disable-model-invocation: false
---

# figma-use — Figma Plugin API Skill

Use the `figma_use` tool to execute JavaScript in Figma files via Figpie's local Plugin API bridge. Adapted from [Figma's official skill](https://github.com/figma/mcp-server-guide/tree/main/skills/figma-use); see [provenance and intentional differences](README.md). All detailed reference docs live in `references/`.

**Loading policy:** load this skill once before the first `figma_use` call in each agent session, then reuse it across calls and tasks. Independently spawned agents load it in their own context. Reload after a skill/runtime update or compaction/context loss that removes the needed guidance. Switching Figma files requires fresh target inspection, not another skill read.

Consult [plugin-api-standalone.index.md](references/plugin-api-standalone.index.md) when the relevant API is unfamiliar, then grep [plugin-api-standalone.d.ts](references/plugin-api-standalone.d.ts) for exact signatures. Load only the references needed for the current operation and reuse them while their guidance remains in context; do not read the full typings file.

## Runtime differences

Figpie-specific execution rules (the applicable sections below and local references follow these rules):

- `node.placeholder` and `figma.io` are unavailable.
- Failed scripts are not atomic. Errors, timeouts, cancellation, disconnection, and output failures may leave changes. Follow [Error Recovery](#7-error-recovery--self-correction) before retrying.
- **Work in the background by default.** Do not assign `figma.currentPage.selection`, change `figma.viewport.center` or `figma.viewport.zoom`, or call `figma.viewport.scrollAndZoomIntoView()` unless the user explicitly asks. Use node IDs and `node.screenshot()` for validation. Load and edit pages directly when possible; call `figma.setCurrentPageAsync()` only when the operation requires a visible page switch, and warn the user before that switch.
- **Preflight every lookup before mutation.** `getNodeByIdAsync()`, `findOne()`, and query helpers can return `null`. Resolve all required IDs first, check every result and required method or node type, and return structured diagnostics for missing or incompatible nodes before making any change. Never call a method directly on an unchecked lookup result, and do not reuse stale IDs after failed, destructive, or replacement operations.
- `figma.currentPage` persists between calls. The shared broker executes calls sequentially within each plugin session; separate sessions can run concurrently. Before reading `children` from another page, call `await page.loadAsync()` or, for genuinely document-wide work, `await figma.loadAllPagesAsync()`.
- With dynamic page access, never read `instance.mainComponent`. Use `await instance.getMainComponentAsync()`. A synchronous `node.query()` selector cannot filter on `mainComponent`; discover instances first, then resolve their components asynchronously.
- Use `return` for output. Do not call `figma.closePlugin()` or replace the plugin UI. Keep async work within the call; event handlers registered through Figpie's adapter are removed at completion.
- If no session is connected, ask the user to pair through `/figpie-pair`; keep credentials out of tool output and conversation context. Setup and troubleshooting belong in the [Figpie README](../../extensions/figpie/README.md#install-and-pair). When multiple sessions are listed, match the requested file/page and specify `connectionId`; ask only if ambiguous.

IMPORTANT: On the first design-system task in the session, consult [working-with-design-systems/wwds.md](references/working-with-design-systems/wwds.md) for the key concepts and guidelines. Load the specific component, variable, text-style, or effect-style reference only when needed, and reuse previously loaded guidance.

## 1. Critical Rules

1.  **Use `return` to send data back.** The return value is JSON-serialized automatically (objects, arrays, strings, numbers). Do NOT call `figma.closePlugin()` or wrap code in an async IIFE — this is handled for you.
2.  **Write plain JavaScript with top-level `await` and `return`.** Code is automatically wrapped in an async context. Do NOT wrap in `(async () => { ... })()`.
3.  `figma.notify()` displays a native Figma notification, not agent output. Prefer `return` to avoid interrupting the user.
3a. **Return node IDs and keep workflow state outside the Figma file.** Put human-readable component purpose and usage in the component's `description`.
4.  `console.log()` is NOT returned — use `return` for output
5.  **Batch by coherent stage: inspect → build → validate → correct.** Preflight before mutation, use loops for repeated elements, and validate stage boundaries. Split for uncertainty, dependencies, deadline risk, or output size—not a fixed number of nodes. See [Incremental Workflow](#6-incremental-workflow-how-to-avoid-bugs).
6.  Colors are **0–1 range** (not 0–255): `{r: 1, g: 0, b: 0}` = red
7.  Fills/strokes are **read-only arrays** — clone, modify, reassign
8.  **Every text edit follows the canonical recipe: load font → `await` → mutate → return affected node IDs.** Skipping the load throws `Cannot write to node with unloaded font "<family> <style>"`. The rule covers more than `characters` — it applies to any operation on nodes with unloaded fonts (`appendChild`, `insertChild`, `setBoundVariable`, `setExplicitVariableModeForCollection`, `setValueForMode`, `findAll` callbacks touching text). When mutating existing text, load the node's *current* fonts via `getStyledTextSegments(['fontName'])`, not a hardcoded default. Inter is preloaded in most environments so other families surface this bug more often — the recipe is the same for every font. Use `await figma.listAvailableFontsAsync()` first if the style string is unverified. See [Canonical text-edit recipe](references/gotchas.md#canonical-text-edit-recipe-font-load--await--mutate--return-ids).
9.  **Pages load incrementally** — prefer `await page.loadAsync()` to load content in the background. If a visible switch is required, warn the user and use `await figma.setCurrentPageAsync(page)`. The sync setter `figma.currentPage = page` does **NOT** work with dynamic page access (see Page Rules below).
10. `setBoundVariableForPaint` returns a **NEW** paint — must capture and reassign
11. `createVariable` accepts collection **object or ID string** (object preferred)
12. **`layoutSizingHorizontal/Vertical` is value-restricted by structural context — `FIXED` always works, `HUG` and `FILL` do not.** `'HUG'` is valid only on an auto-layout frame itself OR on a **TEXT** child of one. `'FILL'` is valid only on a child of an auto-layout frame that is also not absolute-positioned, not inside an immutable frame, and not a canvas-grid child. Practical consequence: append to an auto-layout parent FIRST, then set `HUG`/`FILL` — a newly-created or unparented node can't satisfy the rule yet. The property itself exists on every `SceneNode`; the error is value-rejection, not "no such property". See [Gotchas](references/gotchas.md#layoutsizinghorizontallayoutsizingvertical-value-rules-fixed-hug-fill).
12a. **Use auto-layout for containers that hold related children.** When children have a structural relationship — stacked, side-by-side, aligned, gapped, hugged — wrap them in `figma.createAutoLayout()`, not `figma.createFrame()` with absolute `x`/`y`. Absolute coordinates govern where a container sits on the canvas; auto-layout governs how its children relate inside it. Skipping the container leaves no protection against text reflow, content changes, or overlap.
12b. **`layoutSizing*` and `*AxisSizingMode` are different enums — don't cross them.** `layoutSizingHorizontal`/`layoutSizingVertical` (set on a **child**) take `'FIXED'|'HUG'|'FILL'`; `primaryAxisSizingMode`/`counterAxisSizingMode` (set on the **frame** itself) take `'FIXED'|'AUTO'`. So `layoutSizingVertical = 'AUTO'` is invalid (use `'HUG'`), and `counterAxisSizingMode = 'FILL'` throws `Expected 'FIXED' | 'AUTO', received 'FILL'` (use `'FIXED'`/`'AUTO'`). Two more errors from the same setter — `Error: in set_layoutSizingHorizontal: node must be an auto-layout frame or a child of an auto-layout frame` and `Error: in set_layoutSizingHorizontal: FILL can only be set on children of auto-layout frames` — mean the node isn't in an auto-layout context yet; **recommendation: make the parent auto-layout (`figma.createAutoLayout()`) and `appendChild` the node before setting** (see Rule 12). See [Gotchas](references/gotchas.md#layoutsizing-vs-axissizingmode-two-different-sizing-enums).
13. **Position new top-level nodes away from (0,0).** Nodes appended directly to the page default to (0,0). Scan `figma.currentPage.children` to find a clear position (e.g., to the right of the rightmost node). This only applies to page-level nodes — nodes nested inside other frames or auto-layout containers are positioned by their parent. See [Gotchas](references/gotchas.md).
14. **On `figma_use` error, STOP. Do NOT immediately retry.** Failed scripts may have partially executed. Wait for any still-running work to finish, inspect affected nodes, and correct only the remaining work. See [Error Recovery](#7-error-recovery--self-correction).
15. **Preserve all affected IDs, but keep inline output compact.** Collect and return complete `createdNodeIds`/`mutatedNodeIds` arrays with a root ID, named references, and issues. Figpie saves large ID lists in a local artifact and returns counts plus a summary; the IDs are still available for validation and cleanup. See [Output](#3-return-is-your-output-channel).
16. **Always set `variable.scopes` explicitly when creating variables.** The default `ALL_SCOPES` pollutes every property picker — almost never what you want. Use specific scopes like `["FRAME_FILL", "SHAPE_FILL"]` for backgrounds, `["TEXT_FILL"]` for text colors, `["GAP"]` for spacing, etc. See [variable-patterns.md](references/variable-patterns.md) for the full list.
17. **`await` every Promise.** Never leave a Promise unawaited — unawaited async calls (e.g. `figma.loadFontAsync(...)` without `await`, or `figma.setCurrentPageAsync(page)` without `await`) will fire-and-forget, causing silent failures or race conditions. The script may return before the async operation completes, leading to missing data or half-applied changes.
18. **Never read `componentPropertyDefinitions` from a variant component.** Narrow the owner first: use the node itself when it is a `COMPONENT_SET`, use a `COMPONENT` only when its parent is not a `COMPONENT_SET`, and otherwise promote a variant `COMPONENT` to its parent set. Optional chaining does not make the getter safe. See [Component-property owner narrowing](references/component-patterns.md#component-property-owner-narrowing).
19. **Set `componentPropertyReferences` only on a component sublayer after appending it to its owning component.** Never set it on the component root, component set, or an arbitrary page node. Capture the exact key returned by `addComponentProperty()`.
20. **An empty local-variable list does not prove that the design system has no variables.** Inventory local collection names, existing node bindings, and available library collections before assuming an exact name, creating variables, or falling back to direct styles. Return the inventory instead of throwing when a requested collection name has no exact match.
> For detailed WRONG/CORRECT examples of each rule, see [Gotchas & Common Mistakes](references/gotchas.md).

## 2. Page Rules (Critical)

**Page context persists between `figma_use` calls** and can also change through user interaction. Resolve the intended page explicitly rather than assuming the first or previously visible page.

### Switching pages

Prefer loading a page without switching the user's view:

```js
const targetPage = figma.root.children.find((p) => p.name === "My Page");
if (!targetPage) return { missingPage: "My Page" };
await targetPage.loadAsync();
// Read or edit targetPage directly; the visible page stays unchanged.
```

If the operation requires a visible switch, warn the user and use `await figma.setCurrentPageAsync(targetPage)`. The sync setter `figma.currentPage = page` does **NOT work** with dynamic page access.

### Multi-page work — scope calls and avoid unnecessary page switches

Scope each stage to known pages or subtrees and split only where dependencies, risk, or result size justify it. Repeated work can share one prepared build call. Figpie executes calls sequentially within one plugin session, even when submitted in parallel; waiting in the queue consumes the execution deadline. There is no execution-speed benefit from same-session parallel fan-out and no one-page-switch-per-call runtime restriction.

```js
// Discover page IDs first; inspect each relevant page in a small call.
const page = await figma.getNodeByIdAsync(PAGE_ID);
if (!page || page.type !== "PAGE") return { missingPageId: PAGE_ID };
await page.loadAsync();
return { pageId: page.id, children: page.children.map(n => ({ id: n.id, name: n.name })) };
```

See [gotchas.md → Multi-page work](references/gotchas.md#multi-page-work-in-figpie) for traversal guidance.

### Across script runs

Use explicit page and node IDs across calls. Re-resolve the required nodes and load the target page before accessing its children; a previous call's page selection is not a reliable target identifier.

You can call `figma_use` multiple times to incrementally build on the file state, or to retrieve information before writing another script. For example, write a script to get metadata about existing nodes, `return` that data, then use it in a subsequent script to modify those nodes.

## 3. `return` Is Your Output Channel

Use `return` for text/data output. Awaited `node.screenshot()` calls also attach images; `console.log()` is not captured.

- **Preserve affected IDs:** return complete `createdNodeIds` and/or `mutatedNodeIds` arrays. Also return `rootId`, a small `refs` map for likely follow-up targets, and `issues`. Figpie formats the result compactly; scripts still supply the complete IDs, not merely counts.
- **Progress reporting:** report one concise stage result instead of one message per element.
- **Error info**: Thrown errors are automatically captured and returned — just let them propagate or `throw` explicitly.
- `console.log()` output is **never** returned to the agent
- Always return actionable data (IDs, counts, status) so subsequent calls can reference created objects
- Nodes serialize to `{id, type, name}`. Use explicit mappings or query `.values()` for richer properties; real cycles become `[Circular]`, while repeated references are preserved.
- Structured results use compact JSON. Text delivered to the model is capped at 8 KiB/200 lines, including any abbreviation notice. Whenever output is abbreviated, the complete received text is saved to a private temporary file first.
- When the top-level `createdNodeIds`/`mutatedNodeIds` string arrays contain more than 50 IDs combined, Figpie returns `{summary, nodeIdCounts, fullResultFile}`. `summary` retains the other properties, including `rootId`, `refs`, and `issues`; the file retains the original full result. Larger summaries are also explicitly abbreviated. Read only the fields/IDs needed from the artifact, not the entire result by default. Saved output is not automatic mutation tracking and is not guaranteed after a thrown script error or disconnect; inspect partial changes during recovery.
- The complete response must still fit the 16 MiB transport budget (with a small routing reserve), including at most 10 images and 8 MiB aggregate base64 image data. Local artifacts are created after receipt, so they do not bypass transport limits. Output failures do not roll back earlier mutations.

```js
// Return only actionable fields; collect IDs during the build, not by dumping the tree.
return {
  rootId: screen.id,
  refs: { header: header.id, content: content.id },
  createdNodeIds,
  mutatedNodeIds,
  issues,
};
```

## 4. Editor Mode

Figpie's current manifest supports **Figma Design only** (editorType `"figma"`). The FigJam/Slides distinctions below are retained as Plugin API reference, not a promise that Figpie connects to those editors. FigJam (`"figjam"`) and Slides (`"slides"`) have different sets of available node types — most design nodes are blocked in FigJam, and FigJam-only nodes are blocked in Slides.

**Tell the editor from the URL:** Design = `figma.com/design/...`, FigJam = `figma.com/board/...`, Slides = `figma.com/slides/...`. Confirm before assuming an API is available.

Available in design mode: Rectangle, Frame, Component, Text, Ellipse, Star, Line, Vector, Polygon, BooleanOperation, Slice, Page, Section, TextPath.

**Blocked** in design mode: Sticky, Connector, ShapeWithText, CodeBlock, Slide, SlideRow, SlideGrid, InteractiveSlideElement, Webpage.

Available in Slides mode: Rectangle, Frame, Component, Text, Ellipse, Star, Line, Vector, Polygon, BooleanOperation, Slice, Section, TextPath, Slide, SlideRow, SlideGrid, InteractiveSlideElement.

**Blocked** in Slides mode: Sticky, Connector, ShapeWithText, CodeBlock, Webpage, Page.

**Design-only APIs (not just node types):** `figma.createPage()` is available only in Design files (`figma.com/design/...`). In both FigJam (`figma.com/board/...`) and Slides (`figma.com/slides/...`) it throws `TypeError: figma.createPage no such property 'createPage' on the figma global object`. Do not emit `figma.createPage()` in FigJam or Slides workflows.

> **Slides note:** Slides workflows require a separately available integration and its own runtime guidance; the current Figpie plugin cannot be run in Slides files.

## 5. Efficient APIs — Prefer These Over Verbose Alternatives

These APIs reduce boilerplate, eliminate ordering errors, and compress token output. **Always prefer them over the verbose alternatives.**

### `node.query(selector)` — CSS-like node search

Find nodes within a subtree using CSS-like selectors. Replaces verbose `findAll` + filter loops.

```js
// BEFORE — verbose traversal
const texts = frame.findAll(n => n.type === 'TEXT' && n.name === 'Title')

// AFTER — one-liner with query
const texts = frame.query('TEXT[name=Title]')
```

**Selector syntax:**
- Type: `FRAME`, `TEXT`, `RECTANGLE`, `ELLIPSE`, `COMPONENT`, `INSTANCE`, `SECTION` (case-insensitive)
- Attribute exact: `[name=Card]`, `[visible=true]`, `[opacity=0.5]`
- Attribute substring: `[name*=art]` (contains), `[name^=Header]` (starts-with), `[name$=Nav]` (ends-with)
- Dot-path traversal: `[fills.0.type=SOLID]`, `[fills.*.type=SOLID]` (wildcard index)
- Instance matching: discover `INSTANCE` nodes, then use `await instance.getMainComponentAsync()`; `mainComponent` selectors are unavailable with dynamic page access.
- Combinators: `FRAME > TEXT` (direct child), `FRAME TEXT` (any descendant), `A + B` (adjacent sibling), `A ~ B` (general sibling)
- Pseudo-classes: `:first-child`, `:last-child`, `:nth-child(2)`, `:not(TYPE)`, `:is(FRAME, RECTANGLE)`, `:where(TEXT, ELLIPSE)`
- Node ID: `#12:34`, `#12-34`, or bare `12:34`; use `[id="..."]` for unusual IDs.
- Comma: `TEXT, RECTANGLE` (union)
- Wildcard: `*` (any type)

**QueryResult methods:**
| Method | Description |
|---|---|
| `.length` | Number of matched nodes |
| `.first()` | First matched node (or `null`) |
| `.last()` | Last matched node (or `null`) |
| `.toArray()` | Convert to regular array |
| `.each(fn)` | Iterate with callback, returns `this` for chaining |
| `.map(fn)` | Map to new array |
| `.filter(fn)` | Filter to new QueryResult |
| `.values(keys)` | Extract property values: `.values(['name', 'x', 'y'])` → `[{name, x, y}, ...]` |
| `.set(props)` | Set properties on all matched nodes (see `node.set()` below) |
| `.query(selector)` | Sub-query within matched nodes |
| `for...of` | Iterable — works in `for` loops |

**Scope:** `node.query()` searches within that node's subtree. To search the whole page: `figma.currentPage.query('...')`. There is no global `figma.query()`.

Selectors are validated before traversal, including empty subtrees. Quote attribute values containing spaces, quotes, or parentheses; `:nth-child()` supports positive integers only. For async work on query results, use an awaited loop or `await Promise.all(result.map(async ...))`, not `.each(async ...)`.

**Examples:**
```js
// Recolor all text inside cards
figma.currentPage.query('FRAME[name^=Card] TEXT').set({
  fills: [{type: 'SOLID', color: {r: 0.2, g: 0.2, b: 0.8}}]
})

// Get names and positions of all frames
return figma.currentPage.query('FRAME').values(['name', 'x', 'y'])

// Find the first component named "Button"
const btn = figma.currentPage.query('COMPONENT[name=Button]').first()

// Find all instances of a specific component with dynamic page access
const matchingInstanceIds = [];
for (const instance of figma.currentPage.query('INSTANCE')) {
  const component = await instance.getMainComponentAsync();
  if (component && component.id === compId) matchingInstanceIds.push(instance.id);
}

// Find nodes with solid fills using dot-path traversal
figma.currentPage.query('[fills.0.type=SOLID]')
```

### `node.set(props)` — batch property updates

Set multiple properties in one call. Returns `this` for chaining.

```js
// BEFORE — one line per property
frame.opacity = 0.5
frame.cornerRadius = 8
frame.name = "Card"

// AFTER — single call
frame.set({ opacity: 0.5, cornerRadius: 8, name: "Card" })
```

**Priority key ordering:** `layoutMode` is always applied before other properties (like `width`/`height`) regardless of object key order. This prevents the common bug where `resize()` behaves differently depending on whether `layoutMode` is set.

**Width/height handling:** `width` and `height` are routed through `node.resize()` automatically — setting `{ width: 200 }` calls `resize(200, currentHeight)`.

**Chaining with query:**
```js
// Find all rectangles named "Divider" and update them
figma.currentPage.query('RECTANGLE[name=Divider]').set({
  fills: [{type: 'SOLID', color: {r: 0.9, g: 0.9, b: 0.9}}],
  cornerRadius: 2
})
```

### `figma.createAutoLayout(direction?, props?)` — auto-layout frames

Creates a frame with auto-layout already enabled and both axes hugging content. **This is the default container whenever children have a structural relationship to each other (see Rule 12a).**

```js
// BEFORE — manual setup, easy to get ordering wrong
const frame = figma.createFrame()
frame.layoutMode = 'VERTICAL'
frame.primaryAxisSizingMode = 'AUTO'
frame.counterAxisSizingMode = 'AUTO'
frame.layoutSizingHorizontal = 'HUG'
frame.layoutSizingVertical = 'HUG'

// AFTER — one call, layout ready
const frame = figma.createAutoLayout('VERTICAL')
```

Children can immediately use `layoutSizingHorizontal/Vertical = 'FILL'` after being appended — no need to set sizing modes manually.

Accepts an optional props object as the first or second argument:
```js
figma.createAutoLayout({ name: 'Card', itemSpacing: 12 })               // HORIZONTAL + props
figma.createAutoLayout('VERTICAL', { name: 'Column', itemSpacing: 8 })  // VERTICAL + props
```

### `node.placeholder` — unavailable in Figpie

Figpie does not implement the upstream shimmer helper. Build ordinary containers first, return their IDs, and populate them incrementally; report progress through returned data rather than assigning a `placeholder` property.

### `await node.screenshot(opts?)` — inline screenshots

Capture a node as a PNG and return it inline in the response. Eliminates the need for a separate `get_screenshot` call.

```js
// Take a screenshot of a frame (returned inline in the tool response)
await frame.screenshot()

// Custom scale (default auto-scales: 0.5x or capped so max dimension ≤ 1024px)
await frame.screenshot({ scale: 2 })

// Include overlapping content from sibling nodes
await frame.screenshot({ contentsOnly: false })
```

**When to use:** Capture an overview at the validate stage after the main build, then cropped screenshots only for questionable areas or visual corrections. It can be in the build call if the completed stage is ready to inspect. Avoid a screenshot per node or repeated element; keep lightweight structural checks inside the build.

**Auto-naming:** Figpie records image names such as `"Card (300x150).png"` in tool-result details. Return node IDs and position metadata explicitly when the agent needs spatial context.

**Default scaling:** Uses 0.5x scale, but automatically caps so the largest output dimension never exceeds 1024px. Explicit `{ scale: N }` bypasses the dimension cap, not the [output budget](#3-return-is-your-output-channel).

## 6. Incremental Workflow (How to Avoid Bugs)

Use **stage-based batching** to reduce agent turns without weakening preflight or recovery. A prepared full screen or a loop creating 40 similar cards can fit one build call; unrelated or uncertain mutations should be split. Node count alone does not measure risk.

### Key rules

- **No fixed operation-count limit.** Batch repeated elements with loops/data arrays and shared style definitions. Resolve existing targets, verify methods/types, and load deduplicated fonts before mutation. Await independent async preflight work together where safe.
- **Split at real boundaries:** a needed inspection result, an unfamiliar API experiment, a complex/destructive dependency, a likely deadline overrun, or a transport/output limit. Use a modest inspection/prototype call to resolve uncertainty before a larger build.
- **Build top-down within a stage.** Create containers before children and apply layout sizing after parenting. Keep cheap structural checks in the same call; preserve complete affected IDs for the result/artifact.

### The pattern

1. **Inspect.** Discover the target page, usable components/variables/fonts, and occupied canvas space in a scoped read-only call. Return only relevant IDs and conventions. Completion: an unambiguous target and enough information to preflight the build.
2. **Build.** Preflight every existing dependency and required font, then create the coherent layout/content stage in one call where practical. Reuse loops and shared properties; collect complete affected IDs and named references. Completion: a compact result with the root, follow-up references, and issues—not a full node dump.
3. **Validate.** Check expected counts, hierarchy, bounds, bindings, and text layout. Capture one overview screenshot and inspect questionable areas only as needed. This can share the build call when checks are straightforward. Completion: structural and relevant visual checks agree with the request.
4. **Correct.** Apply targeted fixes only when validation reveals a discrepancy, then re-check affected areas. If a stage fails, follow recovery before further mutation. Completion: no unresolved issues for the requested stage.

### Suggested step order for complex tasks

In the workflow and table below, `get_metadata` and `get_screenshot` mean separately available tools. Figpie itself registers only `figma_use`; use read-only Plugin API inspection and `await node.screenshot()` respectively when those tools are absent.

```
Inspect  → relevant target/assets/fonts, not a document dump
Build    → prepared tokens/components/layout/content in coherent batches
Validate → structural checks + one overview screenshot
Correct  → targeted changes and revalidation only if needed

Split the build into prerequisite stages when necessary (for example, validate
an unfamiliar component pattern before instantiating it throughout the page).
```

### What to validate at each step

| After... | Check with `get_metadata` | Check with `get_screenshot` |
|---|---|---|
| Creating variables | Collection count, variable count, mode names | — |
| Creating components | Child count, variant names, property definitions | Variants visible, not collapsed, grid readable |
| Binding variables | Node properties reflect bindings | Colors/tokens resolved correctly |
| Composing layouts | Instances resolve components via `getMainComponentAsync()`, hierarchy correct | No cropped/clipped text, no overlapping elements, correct spacing |

## 7. Error Recovery & Self-Correction

**Figpie scripts are not atomic.** Earlier changes can remain after a script, screenshot export, or output serialization fails. Undo checkpoints separate completed calls, including partial failures, but do not roll back changes automatically.

**Cancellation and deadlines:** queued requests are removed on cancellation/expiry. Already-running work may continue; deadlines include connection and queue time. Figpie keeps the session blocked until execution completes. If it stays busy, ask the user to restart the plugin before inspecting partial changes; synchronous infinite loops may require Figma's plugin termination controls.

### When `figma_use` returns an error

1. **STOP.** Do not immediately fix the code and retry.
2. **Read the error message carefully.** Determine whether work never started, partially executed, or is still running/unknown. Wait for completion or ask the user to restart a stuck plugin.
3. **Inspect affected nodes read-only**, even if the error is clear. Use `figma_use` once the session is idle, or separately available metadata/screenshot tools. Re-resolve required IDs and account for partial changes.
4. **Fix only the missing or incorrect work**, avoiding duplicate creations or replay of completed mutations.
5. **Retry** the targeted correction, return affected IDs, and validate again.

### Common self-correction patterns
| Error message | Likely cause | How to fix |
|---|---|---|
| `"not implemented"` / unavailable API | API is unsupported by the current editor, Figma version, or Figpie adapter | Verify the API and runtime support; use `return` for agent output |
| `Error: in set_layoutSizingHorizontal: node must be an auto-layout frame or a child of an auto-layout frame` / `Error: in set_layoutSizingHorizontal: FILL can only be set on children of auto-layout frames` / `"HUG can only be set on auto-layout frames or text children of auto-layout frames"` / `"FILL cannot be set on absolute positioned auto-layout children"` / `"FILL cannot be set on canvas grid children"` | Tried to assign `HUG`/`FILL` to a node whose structural context doesn't allow it (e.g. parent isn't auto-layout, ran before `appendChild`, non-text child trying to `HUG`, absolute-positioned child trying to `FILL`) | Make the parent auto-layout via `figma.createAutoLayout()`; `appendChild` first; reserve `HUG` for the auto-layout frame itself or for TEXT children; for absolute/immutable/grid children use `FIXED` + `resize()`. See [gotchas.md](references/gotchas.md#layoutsizinghorizontallayoutsizingvertical-value-rules-fixed-hug-fill) |
| `"Setting figma.currentPage is not supported"` | Used sync page setter (`figma.currentPage = page`) which does NOT work | Use `await figma.setCurrentPageAsync(page)` — the only way to switch pages |
| `Error: in get_componentPropertyDefinitions: Can only get component property definitions of a component set or non-variant component` | Read `componentPropertyDefinitions` from a variant `COMPONENT` | Read from its parent `COMPONENT_SET` instead. Narrow the owner before touching the getter; optional chaining does not prevent this error. See [component-property owner narrowing](references/component-patterns.md#component-property-owner-narrowing). |
| Property value out of range | Color channel > 1 (used 0–255 instead of 0–1) | Divide by 255 |
| `"Cannot read properties of null"` | Node doesn't exist (wrong ID, wrong page) | Check page context, verify ID |
| Script hangs / no response | Infinite loop or unresolved promise | Wait for completion; ask the user to restart a stuck plugin, inspect partial changes, and correct the script before retrying |
| `"The node with id X does not exist"` | Parent instance was implicitly detached by a child `detachInstance()`, changing IDs | Re-discover nodes by traversal from a stable (non-instance) parent frame |

### When the script succeeds but the result looks wrong

1. Use a read-only `figma_use` call or separately available `get_metadata` to check structural correctness (hierarchy, counts, positions).
2. Use `await node.screenshot()` or separately available `get_screenshot` to check visual correctness. Look closely for cropped/clipped text (line heights cutting off content) and overlapping elements — these are common and easy to miss.
3. Identify the discrepancy — is it structural (wrong hierarchy, missing nodes) or visual (wrong colors, broken layout, clipped content)?
4. Write a targeted fix script that modifies only the broken parts — don't recreate everything.

> For the full validation workflow, see [Validation & Error Recovery](references/validation-and-recovery.md).

## 8. Pre-Flight Checklist

Before submitting ANY `figma_use` call, verify:
- [ ] Code uses `return` to send data back (NOT `figma.closePlugin()`)
- [ ] Code is NOT wrapped in an async IIFE (auto-wrapped for you)
- [ ] `return` value includes structured data with actionable info (IDs, counts)
- [ ] NO usage of `figma.notify()` anywhere
- [ ] NO usage of `console.log()` as output (use `return` instead)
- [ ] All colors use 0–1 range (not 0–255)
- [ ] Paint `color` objects use `{r, g, b}` only — no `a` field (opacity goes at the paint level: `{ type: 'SOLID', color: {...}, opacity: 0.5 }`)
- [ ] Fills/strokes are reassigned as new arrays (not mutated in place)
- [ ] Page switches use `await figma.setCurrentPageAsync(page)` (sync setter `figma.currentPage = page` does NOT work)
- [ ] `layoutSizingVertical/Horizontal = 'FILL'` is set AFTER `parent.appendChild(child)`
- [ ] Wrapping TEXT blocks set `textAutoResize = 'HEIGHT'` and an explicit width (`'FIXED'` + `resize()`) — NOT `FILL` alone, which the default `WIDTH_AND_HEIGHT` mode ignores, collapsing the node to a near-zero-width thread. Verify `node.width > 0`
- [ ] Every text mutation follows the [canonical recipe](references/gotchas.md#canonical-text-edit-recipe-font-load--await--mutate--return-ids): `loadFontAsync` → `await` → mutate `characters`/font/size/etc. → return affected node IDs. Works for ANY font family/style, not just Inter (which only happens to be preloaded).
- [ ] Style names have already been verified via `listAvailableFontsAsync()` — NOT guessed from memory (`"SemiBold"` vs `"Semi Bold"` is a common footgun)
- [ ] For `FONT_FAMILY`-scoped variables: every value across every relevant mode is loaded before `setBoundVariable("fontFamily", …)`, `setValueForMode`, or `setExplicitVariableModeForCollection`
- [ ] `lineHeight`/`letterSpacing` use `{unit, value}` format (not bare numbers)
- [ ] `resize()` is called BEFORE setting sizing modes (resize resets them to FIXED)
- [ ] Every `componentPropertyDefinitions` read is performed only after narrowing to a `COMPONENT_SET` or a non-variant `COMPONENT`; variant components are promoted to their parent set first
- [ ] For multi-step workflows: IDs from previous calls are passed as string literals (not variables)
- [ ] New top-level nodes are positioned away from (0,0) to avoid overlapping existing content
- [ ] Containers with structurally-related children use `figma.createAutoLayout()`, not absolute x/y (see Rule 12a)
- [ ] Complete affected-ID arrays are included in the return value; inline output focuses on root/named references/issues, with large lists saved by Figpie
- [ ] This call has a coherent stage goal, preflight is complete, and its deadline/output budget is realistic
- [ ] Every async call (`loadFontAsync`, `setCurrentPageAsync`, `importComponentByKeyAsync`, etc.) is `await`ed — no fire-and-forget Promises

## 9. Discover Conventions Before Creating

**Always inspect the Figma file before creating anything.** Different files use different naming conventions, variable structures, and component patterns. Your code should match what's already there, not impose new conventions.

When in doubt about any convention (naming, scoping, structure), check the Figma file first, then the user's codebase. Only fall back to common patterns when neither exists.

### Quick inspection scripts

**List all pages and top-level nodes:**
```js
await figma.loadAllPagesAsync();
return figma.root.children.map((page) => ({
  id: page.id,
  name: page.name,
  children: page.children.map((node) => ({ id: node.id, name: node.name, type: node.type })),
}));
```

**List existing components across all pages:**

Step 1: one read-only `figma_use` to get page IDs:
```js
return figma.root.children.map(p => ({ id: p.id, name: p.name }));
```

Step 2: inspect each relevant page in a small call. Same-session calls run sequentially; load the page without switching the user's view:
```js
const page = await figma.getNodeByIdAsync(PAGE_ID);
if (!page || page.type !== 'PAGE') return { missingPageId: PAGE_ID };
await page.loadAsync();
// findAllWithCriteria uses an indexed type lookup — hundreds of times faster
// than the findAll(n => n.type === '…') side-effect-in-predicate antipattern.
const matches = page.findAllWithCriteria({ types: ['COMPONENT', 'COMPONENT_SET'] });
return matches.map(n => ({ page: page.name, name: n.name, type: n.type, id: n.id }));
```

**List existing variable collections and their conventions:**
```js
const collections = await figma.variables.getLocalVariableCollectionsAsync();
const results = collections.map(c => ({
  name: c.name, id: c.id,
  varCount: c.variableIds.length,
  modes: c.modes.map(m => m.name)
}));
return results;
```

## 10. Reference Docs

Load these as needed based on what your task involves:

| Doc | When to load | What it covers |
|-----|-------------|----------------|
| [gotchas.md](references/gotchas.md) | An unfamiliar operation, relevant pitfall, or error; reuse loaded guidance | Every known pitfall with WRONG/CORRECT code examples — start with the [canonical text-edit recipe](references/gotchas.md#canonical-text-edit-recipe-font-load--await--mutate--return-ids) |
| [common-patterns.md](references/common-patterns.md) | Need working code examples | Script scaffolds: shapes, text, auto-layout, variables, components, multi-step workflows |
| [plugin-api-patterns.md](references/plugin-api-patterns.md) | Creating/editing nodes | Fills, strokes, Auto Layout, effects, grouping, cloning, styles |
| [api-reference.md](references/api-reference.md) | Need exact API surface | Node creation, variables API, core properties, what works and what doesn't |
| [validation-and-recovery.md](references/validation-and-recovery.md) | Multi-step writes or error recovery | `get_metadata` vs `get_screenshot` workflow, mandatory error recovery steps |
| [component-patterns.md](references/component-patterns.md) | Creating components/variants | combineAsVariants, component properties, INSTANCE_SWAP, variant layout, discovering existing components, metadata traversal |
| [variable-patterns.md](references/variable-patterns.md) | Creating/binding variables | Collections, modes, scopes, aliasing, binding patterns, discovering existing variables |
| [text-style-patterns.md](references/text-style-patterns.md) | Creating/applying text styles | Type ramps, font discovery via `listAvailableFontsAsync`, listing styles, applying styles to nodes |
| [effect-style-patterns.md](references/effect-style-patterns.md) | Creating/applying effect styles | Drop shadows, listing styles, applying styles to nodes |
| [plugin-api-standalone.index.md](references/plugin-api-standalone.index.md) | Need to understand the full API surface | Index of all types, methods, and properties in the Plugin API |
| [plugin-api-standalone.d.ts](references/plugin-api-standalone.d.ts) | Need exact type signatures | Full typings file — grep for specific symbols, don't load all at once |

## 11. Snippet examples

You will see snippets throughout documentation here. These snippets contain useful plugin API code that can be repurposed. Use them as is, or as starter code as you go. If there are key concepts that are best documented as generic snippets, call them out and write to disk so you can reuse in the future.
