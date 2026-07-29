---
name: figma-design-to-code
description: Workflow for implementing or translating Figma designs into production code with the Figma MCP tools. Use when the user asks to implement a Figma frame, component, screen, or section.
---

# Figma Design to Code

Use this skill to read a Figma design and implement it in the current repository. Do not use it to write changes back to Figma or for requests that only inspect or troubleshoot Figma.

## Target resolution

When the user supplies an explicit node ID, directly or through a node-specific Figma URL:

1. Treat it as the `rootTargetId` and use it for the first design-context call.
2. Pass an explicit `nodeId` to every Figma read.
3. Use explicit child node IDs discovered from the root when reading descendants.
4. Never fall back to the current desktop selection. A URL target always takes precedence over the selection.

Only use selection-based access when the user supplied neither a URL nor a node ID. The desktop MCP server reads the currently open Figma file. If an explicit node is not found, ask the user to open the file containing that node instead of using another selection.

## Scope model

Use these terms consistently:

- **Root target**: the exact node supplied by the user and the starting point for discovery.
- **Implementation scope**: the root node itself, or every top-level Frame represented by a Section root.
- **Section**: a grouping container whose direct child Frames define the implementation scope. A Section is not rendered.
- **Frame**: a visual reference for a page, state, and breakpoint. Frames nested inside a top-level Frame are implementation details, not additional scope items.
- **Page**: a route or distinct view.
- **State**: a runtime visual variation such as default, empty, loading, success, or error.
- **Breakpoint**: the viewport variant of a page and state, such as desktop, tablet, or mobile.
- **Frame family**: Frames for the same page across states and breakpoints.
- **Frame inventory**: the complete list of top-level Frames in a Section, recording node ID, semantic name, page, state, and breakpoint.

### Semantic Frame names

For a Section, use each top-level Frame name as the source of its page, state, and breakpoint semantics. Prefer this human-readable convention:

```text
<Page> / <State> / <Breakpoint>
```

Examples:

```text
Checkout / Default / Desktop
Checkout / Error / Desktop
Checkout / Default / Mobile
Checkout / Error / Mobile
```

Equivalent semantic naming is acceptable. Use Frame dimensions to verify the named breakpoint, not to invent one. Do not derive page, state, or breakpoint meaning from canvas order or position.

If a Frame name is missing or too ambiguous to map to a page, state, and breakpoint, list all naming ambiguities together and ask one focused clarification before implementing the affected Frames.

Apply these scope rules:

- A Frame, Component, or Instance target normally scopes implementation to that node.
- A Section target includes every direct child Frame unless the user explicitly narrows the request.
- Inventory all top-level Frames; do not classify them as `reference` or `exclude`.
- Ignore non-Frame Section children when determining implementation scope.
- A set of sibling Frames does not imply sequence, navigation, or transitions. It defines visual variants only.
- Treat Frames with the same page and state at different breakpoints as one responsive implementation.
- Treat Frames with the same page and breakpoint in different states as one implementation with explicit runtime state where practical.
- Never silently omit an in-scope Frame, state, or breakpoint.

## Required workflow

Follow these steps in order.

### 1. Discover the root target

Call `figma_get_design_context` for the root target before writing code. This is the primary design-to-code tool and must not be replaced by metadata or a screenshot.

Determine scope from the root node type:

- A Frame, Component, or Instance root is a single-node scope. Implement that node without searching for sibling variants.
- A Section root is a multi-Frame scope defined by all of its direct child Frames.

For a Section or any target containing multiple top-level Frames:

1. Treat sparse root context as a scope inventory, not sufficient implementation detail.
2. Identify every direct child Frame and build a concise Frame inventory.
3. Record each Frame's `nodeId`, full semantic name, page, state, and breakpoint.
4. Call `figma_get_metadata` on the root only when the inventory is incomplete, truncated, or too large to understand reliably.
5. Resolve semantic naming ambiguities before implementing affected Frames.

For another root response that is incomplete or truncated, use metadata to locate the implementation descendants that require detailed context.

On an error, address the error. Do not silently implement from a screenshot alone.

### 2. Inspect the target project

Before requesting detailed implementation context or creating components, inspect the repository for:

- framework, language, and styling conventions
- existing components matching the design
- design tokens and semantic CSS variables
- routing, state-management, and data-fetching patterns
- test structure and conventions
- development, test, type-check, lint, and build commands
- existing assets and icon components

Prefer extending or composing existing project primitives over creating duplicates. Record accurate `clientLanguages` and `clientFrameworks` values for subsequent Figma calls.

### 3. Fetch implementation context and visual references

For a Section:

1. Call `figma_get_design_context` with the explicit child `nodeId` for every Frame in the inventory.
2. Pass the project language, framework, and appropriate artifact and task hints when supported.
3. Process large sets in manageable groups without losing inventory coverage.
4. If a Frame response is incomplete or recommends descendant reads, fetch the relevant descendants with explicit IDs.
5. Do not request implementation context for non-Frame Section children.

For a single-node scope, use the root context already fetched. If it is incomplete, fetch the relevant descendants with explicit IDs.

Capture visual references as follows:

- Capture a screenshot with the explicit child `nodeId` for every Frame in a Section inventory.
- For a single-node scope, capture a screenshot with the explicit root `nodeId`.
- Use screenshots to understand visual intent and validate implementation, never as a substitute for structured context.
- Use `figma_get_variable_defs` when Figma variables or styles need mapping to project tokens.
- Use `figma_get_motion_context` with an explicit node ID when motion is relevant.

### 4. Implement using project conventions

Treat Figma-generated code as a reference, not final code to paste verbatim.

- Adapt it to the repository's framework, component library, and styling system.
- Prefer existing project components when they match the required semantics and behavior.
- Map Figma variables to project tokens where possible.
- Reuse existing design tokens and semantic CSS variables instead of hard-coded values.
- Group the Frame inventory by page, then model named states explicitly and breakpoints responsively.
- Compose shared page shells instead of duplicating complete implementations for each state or breakpoint.
- Preserve layout, typography, responsive behavior, visual states, motion, and accessibility.
- Do not infer navigation or state transitions from sibling Frame order.
- Implement behavior explicitly required by the user or established by the target project. Ask a focused question when required behavior is otherwise unspecified.
- Do not invent backend behavior that neither the Frames, project, nor user specifies.
- Use assets returned by Figma; do not invent replacements or add an icon package when the exact asset is available.
- Download expiring remote assets before committing them when necessary.
- Add or update tests when the project normally tests comparable state or responsive behavior.

### 5. Validate

Render and exercise the implementation before declaring completion:

1. Start the application using its documented project conventions.
2. Render every Frame inventory entry at its corresponding Figma viewport dimensions.
3. Compare the implementation with every per-Frame Figma screenshot.
4. Verify every named state and breakpoint, including responsive changes between represented breakpoints.
5. Exercise interactions explicitly required by the user or target project.
6. For web targets, load the `browser-tools` skill and use browser automation for rendering and interaction validation.
7. Run relevant tests, type checking, linting, and build commands.

Check:

- Frame inventory coverage
- dimensions, spacing, alignment, and responsive behavior
- typography, colors, borders, radii, and effects
- image and icon fidelity
- named default, hover, focus, active, disabled, loading, error, and success states when represented
- motion when represented
- accessibility and keyboard behavior

Document intentional deviations caused by project conventions or accessibility requirements.

## Connection troubleshooting

If the desktop MCP connection is unavailable, ask the user to:

1. Open the Figma desktop app and the file containing the target node.
2. Enable the desktop MCP server in the inspect panel.
3. Confirm `http://127.0.0.1:3845/mcp` is available.
4. Run `/figma-mcp-connect` in Pi.
