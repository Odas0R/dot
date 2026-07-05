---
description: Create a simple GitHub issue in agile story format
argument-hint: "<issue idea>"
---
Create a new GitHub issue from this request: $ARGUMENTS

Guidelines:
1. If the request is missing the user/persona, goal, benefit, or enough context for acceptance criteria, ask concise clarifying questions before creating the issue.
2. Keep the issue simple, actionable, and free of implementation details unless they are explicitly requested.
3. Draft the issue with this body format exactly:

```md
## Motivation
<why this matters>

## Story
As a <user/persona>, I want <capability/change>, so that <benefit/outcome>.

## Acceptance Criteria
- [ ] <observable outcome>
- [ ] <observable outcome>
```

4. Use a short, clear title.
5. Preview the title and body before creating the issue, and ask for confirmation unless I explicitly say to create it without confirmation.
6. Create the issue with GitHub CLI, preferably using `gh issue create --title "<title>" --body-file <temp-file>`.
7. After creation, return the issue URL.
