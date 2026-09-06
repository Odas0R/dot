# Figpie

One Pi tool, `figma_use`, executes JavaScript in a local Figma Design development plugin:

```text
Pi sessions → authenticated loopback broker → plugin UI → plugin sandbox → Figma Plugin API
```

The detached broker listens only on `127.0.0.1:3846`. The plugin connects through `ws://localhost:3846/figma-use`: Figma's manifest validator rejects the numeric loopback URL, so its allowlist uses `ws://localhost:3846` with a local-access explanation. Pi still connects directly to `127.0.0.1`. Multiple Pi sessions and Figma plugin sessions can connect. Each plugin gets a connection ID. Calls are sequential within a plugin session and concurrent across different sessions.

## Install and pair

```bash
cd pi/extensions/figpie
npm install
```

1. In Figma Desktop, open **Plugins → Development → Import plugin from manifest…** and select `plugin/manifest.json` from this directory.
2. Run **Figpie** in the target Design file.
3. Reload Pi. Run **`/figpie-pair`** and paste the displayed private token into the plugin's pairing field.
4. Click **Connect** and keep the plugin window open.

The compact panel uses Figma's official light/dark theme CSS variables with styled semantic HTML controls (no external UI framework). Once paired, it shows the file/page, routing ID, and connected Pi-session count; credentials collapse into **Connection settings**. Dropped connections retry automatically. Use **Retry** in the pairing form when needed, or open settings to update/forget the token. Connection-changing controls are disabled while an execution is busy.

The token is stored in `~/.config/figpie/pairing-token` (0600, parent directory 0700) and in Figma's plugin client storage. Treat it as a local credential; do not paste it into an agent conversation or commit it. **Forget token** removes the Figma-side copy. To rotate credentials, stop the broker, remove the local token file, reload Pi, and pair each plugin again.

Pi starts the broker on demand and retries transient connection failures with bounded exponential backoff. Startup is non-blocking; either Pi or the Figma plugin may start first. `/figpie-status` shows connection inventory, busy/blocked state, queue lengths, and the last connection error. Broker launch diagnostics go to `~/.config/figpie/broker.log`.

### Pairing diagnostics

`Figpie connected: yes` in `/figpie-status` means **Pi is connected to the broker**, not that Figma has paired. A paired Figma plugin also appears as a session/file/page entry. The plugin UI reports the stages separately: reaching the broker, receiving Figma file context, and authenticating.

If it reaches the broker but cannot obtain file context, close and reopen the entire Figpie plugin with the updated `code.js` and `ui.html`. Pi's `/reload` does not refresh an already-open Figma plugin. The UI/sandbox channel uses a fresh per-window handshake key rather than assuming host messages come from `window.parent`; that key is automatic, stays off the broker wire, and is separate from the user-managed pairing token.

### Upgrade from the unauthenticated broker

Protocol v2 deliberately rejects old clients/brokers. Updating files or `/reload` does not replace an already-running detached broker.

1. Close existing Figpie plugin windows and Pi sessions using the old extension.
2. If port 3846 is still occupied, identify the listener with `lsof -nP -iTCP:3846 -sTCP:LISTEN`. Stop **only the identified old Figpie broker process**, not an unrelated service. Do not use a blanket port-kill command.
3. Start/reload Pi, reopen Figpie in Figma, and pair it using `/figpie-pair`.

Custom port environment overrides were removed because they never configured the Figma UI/manifest. Remove `PI_FIGPIE_PORT` or `PI_FIGMA_USE_PORT` overrides that differ from 3846. Using a different endpoint requires changing both the protocol configuration and plugin UI/manifest together.

## Tool code

Supply an async function body with top-level `await` and `return`; `figma` is in scope. Do not add an IIFE. The bridge owns the plugin UI and lifecycle.

```js
return figma.currentPage.selection.map(node => ({ id: node.id, name: node.name, type: node.type }));
```

Helpers: `figma.createAutoLayout()`, `node.query()`, `node.matches()`, `node.set()`, and `node.screenshot()`. Load the repository's [`figma-use` skill](../../skills/figma-use/SKILL.md) once per agent session before the first call, then reuse its preflight, selector, font, and recovery guidance. Reload after skill/runtime updates or loss of the relevant guidance from context; load specialized references only as needed. This is agent guidance, not a persistent "skill loaded" flag that could become stale across compaction or independent agents.

Node values serialize to `{id, type, name}`; return explicit summaries or use query `.values()` for other properties. Event callbacks are scoped to a call and automatically removed at completion. Await all async operations rather than scheduling background work.

When several Figma sessions exist, the tool returns the inventory in its ambiguity error. Match the file/page and retry with `connectionId`. Page context persists between calls; prefer loading and editing the intended page directly instead of changing the user's selection or viewport.

## Efficient workflow and compact results

Use **inspect → build → validate → correct** stages, not a fixed number of operations per call. Inspect the intended subtree and existing assets once; preflight lookups and deduplicated fonts before mutation; build repeated elements with loops and shared properties. Split when dependencies need inspection, uncertainty is high, or deadlines/output budgets are at risk. Keep cheap structural checks in the build call and capture one overview screenshot at validation, with targeted checks/corrections as needed.

Return actionable fields and complete affected-ID arrays:

```js
return {
  rootId: screen.id,
  refs: { header: header.id, content: content.id },
  createdNodeIds, // complete list collected during the build
  mutatedNodeIds,
  issues,
};
```

- Structured results are minified JSON; literal string formatting is preserved unless abbreviated.
- Up to **8 KiB / 200 lines** of text goes inline, including any abbreviation notice. Images retain their separate budgets.
- If the top-level `createdNodeIds`/`mutatedNodeIds` string arrays contain **more than 50 IDs combined**, the tool returns `{summary, nodeIdCounts, fullResultFile}`. `summary` preserves other fields, including root/named references and issues. The original full result is saved first in a private temporary artifact (directory 0700, file 0600); no IDs are deduplicated or discarded.
- Other oversized text, including large errors, also gets a full-output artifact and an explicitly abbreviated preview. Large summaries are bounded too; omitted content is not evidence that there are no issues. Successful tool results also include the artifact path and recognized ID counts in details; errors include their artifact path in the message.
- Artifacts contain the original received text; for JSON, use a focused query such as `jq '.createdNodeIds[0:20]' /path/to/result.txt` rather than loading the whole result into context. Root/named references usually make that extra read unnecessary.
- This is output formatting, **not automatic mutation tracking**. Scripts still collect IDs. A thrown error, disconnect, or transport-limit failure may leave changes without a manifest; inspect partial state before retrying. Artifacts cannot bypass the transport budget because formatting happens after receipt.

Reload Pi for updated tool/skill guidance; reopen the Figma plugin for updated serialization. This change does not require a new pairing protocol or broker restart if protocol v2 is already running.

## Cancellation, failures, and recovery

**Scripts are not transactional.** Earlier changes remain when later code, screenshot export, or result serialization fails. Each completed call creates an undo checkpoint, including partial failures; checkpoints are not automatic rollback.

Deadlines include connection establishment, queueing, and execution. Queued requests are removed on cancellation/expiry. For running work, Figpie requests cooperative cancellation and blocks further dispatch until the plugin confirms completion. API guards prevent many late mutations but cannot preempt an infinite loop or cancel all native async work.

A transport reconnect first reconciles the sandbox's busy state. Old responses are not replayed onto a new transport, and execution requests are not automatically retried.

If a call times out or disconnects:
1. Wait for it to finish; inspect `/figpie-status`.
2. If the session remains blocked, restart Figpie in Figma. An infinite synchronous loop may require Figma's plugin termination controls.
3. Inspect partial changes read-only and re-resolve affected IDs before retrying only the remaining work.

## Limits and security

- Every client authenticates before receiving file metadata or executing code. Browser origins are restricted; Figma's opaque `null` origin is supported but still requires the token.
- The credential grants access to **all paired sessions on this broker**. This is not isolation between mutually untrusted agents, OS users with access to the credential, or scripts. Only use trusted agent instructions. Arbitrary plugin code can read, modify, or delete file content and invoke native APIs.
- The protocol validates message envelopes and rejects malformed clients without crashing other sessions. Ping/pong heartbeats detect dead connections; bounded queues and send buffers limit accumulation.
- At most 32 queued requests per Figma session; the serialized execute envelope is limited to 1 MiB.
- Results are limited to a 16 MiB envelope, with a small routing reserve, including at most 10 images and 8 MiB aggregate base64 image data. Oversized outputs return useful errors rather than disconnecting normal sessions. Reduce screenshot scale or split inspection calls.
- Inline text is capped at 8 KiB/200 lines; large ID arrays are summarized earlier as described above. Full received text is saved privately whenever abbreviated. Temporary outputs and broker logs are not automatically deleted.

## Development

```bash
npm test
npm run check
```

Tests use temporary-port brokers and mocked Figma/plugin UI APIs; they do not modify live Figma files. After updating the plugin, manually verify pairing, node creation, screenshots, and cancellation in a disposable Design file.

Runtime layers:
- `protocol.js`: wire constants and validators
- `auth.js`: private token creation/loading
- `broker.js`: routing, deadlines, queues, liveness
- `client.js`: abortable Pi connection lifecycle and request handling
- `index.js`: Pi tool, commands, workflow guidance
- `output.js`: compact text/ID summaries and private full-output artifacts
- `plugin/code.js` / `plugin/ui.html`: sandbox execution and paired transport

`plugin/icon.svg` is the editable icon and `plugin/icon.png` is the 128×128 publishing asset. Figma's publishing UI selects the icon; it is not a manifest field.
