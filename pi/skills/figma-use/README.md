# /skill:figma-use

Copied and adapted from Figma’s official `figma-use` skill: <https://github.com/figma/mcp-server-guide/tree/main/skills/figma-use>

This is an upstream-derived skill adapted for our [Figpie implementation](../../extensions/figpie/README.md), not a verbatim mirror. Preserve the upstream section structure, Plugin API recipes, examples, and design-system references wherever they apply. The exact upstream commit used for the original import was not recorded; do not infer it from this repository's commit history.

## Intentional runtime differences

| Area | Figpie-specific guidance | Where maintained |
|---|---|---|
| Failure and cancellation | Partial changes can remain; running work may outlive the caller's wait. Inspect before targeted retries. Undo checkpoints are not rollback. | Skill §7; `references/validation-and-recovery.md` |
| Page state and concurrency | Page state persists. Load pages in the background; calls are sequential per plugin session, not parallel per page. | Skill §2; page examples in `references/gotchas.md`, `component-patterns.md`, and `plugin-api-patterns.md` |
| Editor support | The plugin manifest supports Design only; other editors' API distinctions are retained as reference, not advertised support. | Skill §4 |
| Helpers and native APIs | No shimmer/`figma.io`; main components require async resolution. Native notifications are not agent output, and Figpie owns the plugin UI/lifecycle. | Skill §1/§5; `references/api-reference.md` and `plugin-api-standalone.index.md` |
| Skill loading | Load once per agent session; reload after skill/runtime changes or lost guidance. Specialized references are on demand. | Skill opening/frontmatter; extension `index.js` prompt guidance |
| Batching and validation | Coherent inspect/build/validate/correct stages, not a ten-operation limit; preflight and structural/visual validation remain required. | Skill §2/§6; `plugin-api-patterns.md`, `common-patterns.md`, validation reference |
| Compact output | Minified JSON, 8 KiB/200-line inline budget, and private full-result artifacts for large ID lists or other abbreviated output. Scripts still return complete affected-ID arrays and concise named references/issues. | Skill §3/§5; `gotchas.md`; extension `output.js` |
| Pairing and operations | Pairing is user-managed; credentials stay out of agent context. | Brief pointer in the skill; setup, upgrades, and troubleshooting in the plugin README |

## Updating from upstream

1. Record the upstream commit when importing a future update so subsequent comparisons have a known base.
2. Bring over applicable API guidance without wholesale replacement of the local adaptation.
3. Reconcile runtime claims and examples in place against Figpie's implementation/tests. Keep the skill and affected references consistent; do not leave contradictory instructions behind an introductory override.
4. Preserve unrelated API recipes and the main section structure. Keep operational setup in the plugin README, and update this difference map only when the contract changes.
5. Check local Markdown links, stale runtime claims, and the plugin's regression tests before considering the update complete.
