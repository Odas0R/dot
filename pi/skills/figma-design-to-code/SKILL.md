---
name: figma-design-to-code
description: Workflow for implementing, building, or translating Figma designs into production code with the Figma MCP tools. Use when the user asks to implement a Figma frame, component, screen, section, or flow.
---

# Figma Design to Code

Use this skill for the design-to-code direction: read a Figma design and implement it in the current repository. Do not use it for writing changes back to the Figma canvas or for requests that only discuss, inspect, or troubleshoot Figma.

## Target resolution

When the user supplies an explicit node ID, directly or through a node-specific Figma URL:

1. Treat the resolved ID as the `rootTargetId` and use it for the first design-context call and the scope overview.
2. Descendant reads may use explicit child node IDs discovered from the root target.
3. Pass an explicit `nodeId` to every Figma read. Never omit it and silently fall back to the current selection.
4. A URL target always takes precedence over the current Figma desktop selection.

Only use selection-based access when the user supplied neither a URL nor a node ID. The desktop MCP server reads from the currently open Figma file; if an explicit node is not found, ask the user to open the file containing the shared URL rather than using another selection.

## Design vocabulary and scope

Use these terms consistently:

- **Root target**: the exact node supplied by the user and the starting point for discovery.
- **Implementation scope**: every node and behavior the root target asks you to implement.
- **Section**: a Figma grouping container. It defines scope but is not normally rendered.
- **Screen**: a top-level frame representing a route or distinct view.
- **Screen family**: screens or states representing the same route or feature. Names such as `Portal/OTP/Empty` and `Portal/OTP/Error` commonly share the `Portal/OTP` family.
- **State**: a runtime visual variation of a screen, such as empty, editing, submitting, success, or error.
- **Breakpoint**: the same screen and state at another viewport size. It is responsive behavior, not a runtime application state.
- **Flow**: a directed graph of screens or states and their transitions. A flow may branch and is not necessarily linear.
- **Transition**: a trigger and optional condition connecting a source screen or state to a destination, possibly with a side effect.
- **Confirmed transition**: a transition supported by explicit design evidence or confirmed by the user.
- **Unresolved transition**: a transition whose trigger, condition, destination, or side effect is missing or contradictory.
- **Shared shell**: UI common to multiple screens or states in a family.
- **Annotation**: connectors, labels, notes, and documentation that guide implementation but are not rendered.
- **Coverage manifest**: an inventory classifying every top-level node as `implement`, `reference`, or `exclude`, with a reason.
- **Transition manifest**: an inventory of flow edges recording source, trigger, condition, destination, side effect, evidence, and confirmation status.

Apply these scope rules:

- A Frame, Component, or Instance target normally scopes implementation to that node.
- A Section target includes every top-level screen and state in the Section unless the user explicitly narrows the request.
- Treat connectors, action labels, condition labels, and prototype relationships as flow references, not implementation targets. Do not request implementation-oriented design context for annotation nodes or render them as product UI.
- Derive flow behavior from explicit prototype relationships, readable labels, screen names, visible state differences, and user confirmation. Do not infer semantics from connector geometry or canvas position alone.
- Treat responsive variants as breakpoints of one implementation where project conventions support it.
- Treat states in the same screen family as one implementation with explicit runtime state where practical, not as duplicated independent pages.
- Classify a node as `exclude` only when the user excluded it or the design explicitly marks it as archived, deprecated, or non-product material. Ask before excluding any apparent screen or state.
- Never silently omit an in-scope screen, state, breakpoint, or flow branch.
- Implement every visual state and every confirmed transition. Never invent unresolved behavior.

## Required workflow

Follow these steps in order.

### 1. Discover the root target and scope

Call `figma_get_design_context` for the root target before writing code. This is the primary design-to-code tool and must not be replaced by metadata or a screenshot.

For a Section or any target containing multiple top-level screens:

1. Treat sparse root context as a scope inventory, not sufficient implementation detail.
2. Call `figma_get_metadata` on the root target only if the inventory is incomplete, truncated, or too large to understand reliably.
3. Build a concise coverage manifest containing every top-level child node.
4. Classify each child as `implement`, `reference`, or `exclude`, and record the reason.
5. Apply the exclusion rules above; do not self-authorize removal of an apparent screen or state.

For any other root response that is incomplete or truncated, use metadata to identify the descendants that require detailed context later.

On an error, read and address the error. Do not silently implement from a screenshot alone.

### 2. Inspect the target project

Before requesting detailed implementation context or creating components, inspect the repository for:

- framework, language, and styling conventions
- existing components matching the design
- design tokens and semantic CSS variables
- routing, state-management, and data-fetching patterns
- test structure and conventions
- development, test, type-check, lint, and build commands
- existing assets and icon components

Prefer extending or composing existing project primitives over creating duplicates. Record accurate `clientLanguages` and `clientFrameworks` values for subsequent Figma context calls.

### 3. Fetch implementation context and visual references

For a multi-screen scope:

1. Call `figma_get_design_context` with the explicit child node ID for every node classified as `implement`.
2. Pass the project language, framework, and appropriate artifact or task hints when the tool supports them.
3. Do not call `figma_get_design_context` on nodes classified as `reference`.
4. If the scope is large, process implementation nodes in manageable groups while preserving the complete coverage manifest.

For a single-node scope, use the root context already fetched. If it is incomplete, truncated, or recommends inspecting implementation descendants, fetch detailed context for the relevant explicit descendant IDs.

Capture visual references as follows:

- Call `figma_get_screenshot` with the explicit `rootTargetId` for a scope overview.
- Capture a screenshot with the explicit child node ID for every screen and state classified as `implement`.
- Use screenshots to understand visual intent and validate the implementation, never as a substitute for structured context.
- Use `figma_get_variable_defs` when variables or styles need to be mapped to project tokens.
- If motion is relevant, call `figma_get_motion_context` with the explicit node ID whose motion is being implemented.

Understand reference nodes from the root context, metadata, readable prototype information, and overview screenshot. Do not generate or implement connector code.

### 4. Confirm flow behavior

When the scope represents multiple states or a flow, build a concise transition manifest before implementation. For each proposed transition, record:

- source screen or state
- user or system trigger
- condition or guard, if any
- destination screen or state
- side effect, if any
- supporting design evidence
- status: `confirmed` or `needs confirmation`

Treat a transition as confirmed only when its semantics are explicit in the available design evidence or the user confirms them. If any required transition remains unresolved:

1. Present one consolidated transition manifest containing all ambiguities.
2. Ask focused questions that let the user confirm or correct the unresolved behavior.
3. Wait for the answer before implementing the affected interactions.
4. Treat the user's answer as confirmed flow semantics and continue the implementation.

Do not wait for confirmation when the behavior is already explicit. Do not silently guess when it is not.

### 5. Implement using project conventions

Treat Figma's generated code as a reference, not final code to paste verbatim.

- Adapt it to the repository's framework, component library, and styling system.
- Prefer existing project components when they match the required semantics and behavior.
- Map Figma variables to project tokens where possible.
- Reuse existing design tokens and semantic CSS variables instead of hard-coded values.
- Preserve layout, typography, responsive behavior, interaction states, transitions, and accessibility.
- Compose shared shells and explicit runtime states for screens in the same family instead of duplicating the full screen implementation.
- Implement every confirmed flow branch and state change.
- Do not invent backend behavior that neither Figma, the project, nor the user specifies; ask when it is required to complete a transition.
- Use assets returned by Figma; do not invent replacements or add an icon package when the exact asset is available.
- Download expiring remote assets before committing them when necessary.
- Add or update tests for state and transition behavior when the project normally tests comparable functionality.

### 6. Validate

Render and exercise the implementation before declaring completion:

1. Start the application using its documented project conventions.
2. Render every implemented screen and state at the corresponding Figma viewport dimensions.
3. Capture the implementation and compare it with each per-screen Figma screenshot.
4. Exercise every confirmed transition and flow branch, including loading, error, success, and retry paths.
5. For web targets, load the `browser-tools` skill and use browser automation for rendering and interaction validation.
6. Run the relevant project tests, type checking, linting, and build commands.

Check:

- dimensions, spacing, alignment, and responsive behavior
- typography, colors, borders, radii, and effects
- image and icon fidelity
- hover, focus, active, disabled, loading, error, success, and motion states
- confirmed transitions and flow branches
- accessibility and keyboard behavior
- coverage manifest completion, including a valid reason for every excluded node
- transition manifest completion with no unresolved implemented behavior

Document any intentional deviation caused by project conventions or accessibility requirements.

## Connection troubleshooting

If the desktop MCP connection is unavailable, ask the user to:

1. Open the Figma desktop app and the file containing the target node.
2. Enable the desktop MCP server in the inspect panel.
3. Confirm `http://127.0.0.1:3845/mcp` is available.
4. Run `/figma-mcp-connect` in Pi.
