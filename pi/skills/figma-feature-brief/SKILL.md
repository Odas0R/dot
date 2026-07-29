---
name: figma-feature-brief
description: Analyze a Figma Frame, Component, Instance, or Section into an evidence-backed feature brief covering domain language, requirements, application capabilities, backend implications, repository fit, acceptance criteria, and open questions. Use for feature discovery or clean-session handoff, not implementation.
---

# Figma Feature Brief

Use this skill to discover and document a feature represented by Figma and the current repository. Produce a self-contained brief that another clean agent session can use without the discovery conversation.

Do not implement the feature or modify production code. Do not treat Figma as a complete product or backend specification.

## Target resolution

When the user supplies an explicit node ID, directly or through a node-specific Figma URL:

1. Treat it as the `rootTargetId` and use it for the first design-context call.
2. Pass an explicit `nodeId` to every Figma read.
3. Use explicit child node IDs discovered from the root when reading descendants.
4. Never fall back to the current desktop selection. A URL target always takes precedence over the selection.

Only use selection-based access when the user supplied neither a URL nor a node ID. If an explicit node is not found, ask the user to open the file containing that node instead of using another selection.

## Scope model

Determine feature evidence from the root node type:

- A Frame, Component, or Instance root is a single-node scope. Analyze that node without searching for sibling variants. Explicitly note that one node may represent only part of the feature.
- A Section root is a multi-Frame scope defined by every direct child Frame. Frames nested inside a top-level Frame are implementation details, not additional scope items.
- Ignore non-Frame Section children when determining scope.

For a Section, build a concise Frame inventory containing each direct child Frame's node ID, full semantic name, page, state, and breakpoint. Use semantic Frame names as the primary source for page, state, and breakpoint meaning. Use dimensions to verify a named breakpoint, not to invent one.

A collection of Frames represents observable variants, not an inherent sequence. Do not derive feature order, navigation, lifecycle, or causality from canvas position or sibling order. Visible actions and differences may support candidate behavior, but unconfirmed behavior must remain a candidate or unknown.

Keep these distinctions explicit:

- A breakpoint is a presentation variant, not a domain state.
- Loading, open-menu, focused, and similar UI conditions are not automatically domain lifecycle states.
- A visible control demonstrates an available user action, not all of its permissions, rules, side effects, or failure behavior.
- Missing screens do not prove that a state or requirement is out of scope.

## Evidence model

Label substantive statements in the brief as one of:

- **Observed**: directly visible in Figma or present in the repository. Cite the Frame/node or repository path.
- **Required**: confirmed by the user or established by an existing system contract.
- **Candidate**: a plausible domain, requirement, or architecture interpretation that still needs confirmation.
- **Unknown**: missing information that cannot be responsibly inferred.

Never promote a Candidate to Required. Preserve contradictions and uncertainty instead of silently resolving them.

Use exact visible product language before normalizing it into technical terminology. When Figma and the repository use different terms, record both and flag whether they appear equivalent.

## Required workflow

Follow these steps in order.

### 1. Discover the Figma scope

Call `figma_get_design_context` for the explicit root target before inspecting descendants or writing the brief. This is the primary source and must not be replaced by metadata or a screenshot.

For a Section:

1. Identify every direct child Frame and build the complete Frame inventory.
2. Call `figma_get_metadata` on the root only when the inventory is incomplete, truncated, or too large to understand reliably.
3. Call `figma_get_design_context` with the explicit child `nodeId` for every Frame in the inventory.
4. Capture a screenshot with the explicit child `nodeId` for every Frame.
5. Process large inventories in manageable groups without losing coverage.

For a Frame, Component, or Instance root, use the root design context and capture a screenshot with the explicit root `nodeId`. If the response is incomplete, fetch only the relevant implementation descendants with explicit IDs; do not expand to siblings outside the root scope.

On an error, address the error. Do not continue from screenshots alone.

### 2. Inspect the repository

Inspect the current repository before proposing domain or backend boundaries. Do not change files.

Identify:

- current branch and HEAD
- architecture and module boundaries
- existing domain vocabulary, entities, value objects, statuses, and policies
- application services, commands, queries, handlers, or use-case conventions
- API, event, queue, job, integration, and persistence patterns
- authentication, authorization, tenancy, and audit conventions
- frontend routing, state management, data fetching, and error handling
- relevant schemas, migrations, contracts, tests, and documentation
- development and validation commands

Prefer extending an existing domain or capability when repository evidence supports it. Describe a new domain or boundary only as a Candidate until its ownership and invariants are established.

Record relevant paths and symbols so the handoff agent can verify findings without repeating broad discovery.

### 3. Extract feature evidence

Extract only what the available evidence supports:

- intended user and business outcomes
- actors and visible roles
- exact nouns, verbs, labels, statuses, and error language
- pages, named states, breakpoints, visible actions, and displayed data
- input fields, validation messages, filters, tables, summaries, and confirmations
- empty, loading, success, failure, disabled, and retry experiences when represented
- observable preconditions and outcomes
- existing repository capabilities that appear reusable

Build a UI evidence matrix when multiple Frames are present. Record the page, state, breakpoint, actor or trigger if known, required displayed data, available actions, and visible errors for each Frame.

Do not turn visual differences into business rules unless the relationship is explicit or user-confirmed.

### 4. Model domain and system implications

Using Figma evidence together with repository conventions, identify:

- ubiquitous-language terms and conflicting terminology
- candidate domain ownership or bounded-context impact
- candidate entities, value objects, lifecycle states, policies, and invariants
- candidate commands, queries, and application use cases
- actors, inputs, outputs, authorization needs, failures, and side effects for each capability
- backend capabilities needed to supply data or support visible actions
- persistence, API, event, background-job, integration, notification, idempotency, audit, and observability implications when relevant
- frontend/backend contracts implied by the represented states

Keep requirements separate from proposed mechanisms. For example, “an invitation must not be accepted twice” may be a Candidate invariant; a unique database constraint is an architecture Candidate, not the requirement itself.

Do not prescribe class names, module layouts, endpoints, tables, or events unless they already exist as Required repository contracts.

### 5. Resolve material unknowns

Before producing the final brief, collect all unknowns that could materially change domain ownership, data contracts, security, persistence, side effects, or acceptance criteria.

Typical areas include:

- actors, permissions, and tenancy
- source of truth and data ownership
- lifecycle and state-transition rules
- validation and business invariants
- concurrency, duplicate actions, and idempotency
- notifications, integrations, and background work
- audit, privacy, retention, and security requirements
- error recovery and partial failure
- behavior not represented by the supplied Frame or Section

Ask one consolidated set of focused questions. Wait for answers when an unknown would materially alter the feature boundary or required contracts. If the user intentionally defers an answer, preserve it as Unknown and state its implementation impact.

Do not ask for information already explicit in Figma, the repository, or the user's feature intent.

### 6. Produce the handoff brief

Produce one self-contained Markdown brief. Do not assume the receiving agent can access this conversation.

Use this structure, omitting only sections that are genuinely irrelevant:

```markdown
# Feature Brief: <name>

## Handoff readiness
Ready, ready with recorded unknowns, or blocked; include the reason.

## Objective
User outcome, business outcome, actors, and feature boundary.

## Source and scope
Figma URL and root node, analyzed Frame inventory, repository branch/HEAD,
represented states, scope limitations, and evidence legend.

## Ubiquitous language
Term, meaning, evidence, existing repository equivalent, and status.

## Actors and permissions
Observed or required actors, capabilities, ownership, and unknowns.

## UI evidence and state matrix
Page, state, breakpoint, visible data, actions, errors, and evidence.

## Requirements and business rules
Stable IDs, requirement or invariant, status, evidence, and acceptance impact.

## Domain model candidates
Existing domain fit, candidate boundaries, entities, value objects,
lifecycle states, policies, and unresolved ownership.

## Application capabilities
Command/query/use case, actor, inputs, outcome, failures, side effects,
and status.

## Backend implications
Data contracts, authorization, persistence, APIs, events, jobs,
integrations, idempotency, audit, observability, and failure handling.

## Existing-system fit
Relevant paths, symbols, reusable capabilities, fixed contracts,
and likely impact areas.

## Acceptance criteria
Evidence-backed and Required, testable outcomes. Keep Candidate behavior
out of acceptance criteria until confirmed.

## Open questions
Unknown, why it matters, affected contracts, and who must decide.

## Out of scope
Explicit exclusions and unsupported assumptions.

## Validation expectations
Relevant tests, checks, and represented UI states the implementation must verify.
```

The brief must be concise enough to hand off but complete enough that the receiving agent does not need the discovery conversation. Reference Figma node IDs and repository paths instead of duplicating large artifacts.

## Connection troubleshooting

If the desktop MCP connection is unavailable, ask the user to:

1. Open the Figma desktop app and the file containing the target node.
2. Enable the desktop MCP server in the inspect panel.
3. Confirm `http://127.0.0.1:3845/mcp` is available.
4. Run `/figma-mcp-connect` in Pi.
