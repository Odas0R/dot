---
name: figma-design-to-code
description: Mandatory workflow for implementing, building, translating, or porting a Figma design into production code with the Figma MCP tools. Load this skill before calling figma_get_design_context for a design-to-code task.
---

# Implement a Figma Design as Code

Use this skill only for the read-from-Figma direction: get design context from Figma, then adapt it to the current codebase. Do not use it to write changes to Figma.

## Workflow

### 1. Resolve the target

When the user gives a node-specific Figma URL, extract its `node-id`, normalize `1-2` to `1:2`, and pass it as `nodeId` to every related Figma read. The URL target overrides the current desktop selection. Use selection-based access only when the user gives no URL or node ID.

### 2. Get design context first

Call `figma_get_design_context` for the exact target before you write code. This is the primary tool. Its result contains reference code, a screenshot, and contextual hints.

Do not use metadata or a separate screenshot as a substitute:

- Use `figma_get_metadata` only to find relevant child nodes when the target is too large, incomplete, or truncated. Then call `figma_get_design_context` for those explicit child IDs.
- Use `figma_get_screenshot` only when you need another visual reference or final validation.
- On an error, read and address the error. Do not silently implement from a screenshot alone.

### 3. Inspect the project

Before you create code, inspect the repository for its framework, styling system, components, tokens, routing, state patterns, assets, tests, and validation commands. Pass accurate `clientLanguages` and `clientFrameworks` values in later Figma calls when supported.

### 4. Treat Figma output as a reference

The returned code is a structured design representation, often React and Tailwind. Do not paste it as final code. Adapt it to the project's language, framework, component library, styling system, and conventions.

Apply Figma hints in this order:

1. Code Connect snippets and mapped project components
2. Component documentation
3. Design annotations
4. Figma variables and project design tokens
5. Raw values and visual intent

Use `figma_get_variable_defs` when token mapping needs more data. Use `figma_get_motion_context` after design context when the target contains relevant motion.

### 5. Reuse project code and exact assets

- Reuse or extend matching project components and tokens before you create equivalents.
- Preserve layout, typography, responsive behavior, states, accessibility, and motion shown by the design.
- Use the exact image and icon assets returned by Figma. Do not add an icon package or create a placeholder when the correct asset is available.
- Asset URLs can expire. Download and commit exact asset bytes when the repository must keep them. For dynamic content, use the project's normal data source.
- Do not invent behavior, navigation, data, or backend work that the design, project, or user does not specify.

### 6. Validate

Run the implementation and compare it with the Figma visual reference at the target viewport size. Check layout, spacing, typography, colors, borders, effects, assets, states, responsive behavior, motion, and keyboard accessibility.

For a web UI, use the `browser-tools` skill when browser rendering or interaction checks are practical. Run the project's relevant tests, type checks, lint checks, and build. Report any intentional design deviation.
