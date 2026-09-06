# Validation Workflow & Error Recovery

> Part of the [figma_use skill](../SKILL.md). How to debug, validate, and recover from errors.

## Contents

- `get_metadata` vs `get_screenshot`
- Error Recovery After Failed `figma_use`
- Recommended Workflow


## `get_metadata` vs `get_screenshot`

Validate coherent stage boundaries using the right tool for the job. Keep cheap structural checks in the build call where practical; avoid a separate inspection turn or screenshot for each repeated element. Capture one overview at the validate stage, then crop questionable areas only as needed.

**Figpie compatibility:** `get_metadata` and `get_screenshot` below refer to separately available tools, not tools supplied by Figpie. When absent, use a read-only `figma_use` call returning explicit node properties for metadata, and `await node.screenshot()` for images. Keep both scoped to the affected subtree.

### `get_metadata` — Use for intermediate validation (preferred)

When available, `get_metadata` provides node structure; otherwise return IDs, types, names, positions, and sizes from read-only Plugin API code. Use either approach to confirm:

- **Structure & hierarchy**: correct parent-child relationships, component nesting, section contents
- **Node counts**: expected number of variants created, children present
- **Naming**: variant property names follow the `property=value` convention
- **Positioning & alignment**: x/y coordinates, width/height values match expectations
- **Layout properties**: auto-layout direction, sizing mode, padding, spacing
- **Component set membership**: all expected variants are inside the ComponentSet

```
Example: After creating a ComponentSet with 120 variants, call get_metadata on the
ComponentSet node to verify all 120 children exist with correct names, sizes, and positions
— without waiting for a full render.
```

**When to use `get_metadata`:**
- After creating/modifying nodes — to verify structure, counts, and names
- After layout operations — to verify positions and dimensions
- After combining variants — to confirm all components are in the ComponentSet
- After binding variables — to verify node properties (use figma_use to read bound variables if needed)
- Between multi-step workflows — to confirm step N succeeded before starting step N+1

### `get_screenshot` — Use after each major creation milestone

Use `await node.screenshot()` or a separately available `get_screenshot` to verify visual correctness (colors, typography rendering, effects, variable mode resolution). Screenshots are slower and produce large responses, so capture them after major milestones rather than every call. Follow the [skill's output limits](../SKILL.md#3-return-is-your-output-channel); an export or output failure can occur after mutations have succeeded.

**When to use `get_screenshot`:**
- **After creating a component set** — verify variants look correct, grid is readable, nothing is collapsed or overlapping
- **After composing a layout** — verify overall structure and spacing
- **After binding variables/modes** — verify colors and tokens resolved correctly
- **After any fix or recovery** — verify the fix didn't introduce new visual issues
- **Before reporting results to the user** — final visual proof

**What to look for in screenshots** — these are the most commonly missed issues:
- **Cropped/clipped text** — line heights or frame sizing cutting off descenders, ascenders, or entire lines
- **Overlapping content** — elements stacking on top of each other due to incorrect sizing or missing auto-layout
- **Placeholder text** still showing ("Title", "Heading", "Button") instead of actual content

## Error Recovery After Failed `figma_use`

**Figpie scripts are not atomic.** Earlier changes may remain after errors, timeouts, cancellation, disconnection, or output failures. Undo checkpoints do not provide automatic rollback. Follow the [skill's execution and recovery rules](../SKILL.md#7-error-recovery--self-correction), accounting for partial changes before retrying.

**Recovery steps when `figma_use` returns an error:**
1. **STOP — do NOT immediately fix the code and retry.** Read the error message carefully first.
2. **Understand the outcome.** Determine whether work never started, partially executed, or is still running/unknown. Wait for completion; if stuck, ask the user to restart Figpie in Figma before further execution.
3. **Inspect affected nodes read-only**, even when the error is clear. Use Plugin API inspection or separately available metadata/screenshot tools once execution is idle; re-resolve IDs and identify partial changes.
4. **Fix only the remaining or incorrect work** based on the error and observed state. Avoid duplicate creations or replaying completed mutations.
5. **Retry** the targeted correction, return affected IDs, and validate again.

## Recommended Workflow

```
1. Inspect  →  Resolve the target and dependencies; return a focused inventory
2. Build    →  Preflight, then create a coherent stage with structural checks
3. Validate →  Review checks and one overview screenshot; inspect details if needed
4. Correct  →  Targeted fixes and revalidation only when issues remain

Keep root/named references and issues inline. Complete affected-ID arrays are
preserved in the result or its local artifact; retrieve only fields needed next.

⚠️ ON ERROR at any step:
   a. Read the error; wait for running work or ask the user to restart a stuck plugin
   b. Read-only inspection / screenshot  →  Account for partial changes and re-resolve IDs
   c. Correct only missing or incorrect work
   d. Return affected IDs and validate the targeted correction
```
