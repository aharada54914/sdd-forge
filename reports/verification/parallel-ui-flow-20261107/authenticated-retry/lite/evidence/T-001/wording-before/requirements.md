# Requirements (lite): Task board

- Source: [complete user request](../../evidence/source.txt).
- Purpose: A minimal browser task board for a single person to manage tasks on this device.

## User stories / requirements
- REQ-001: Enter a task title and submit with the Add task button or Enter. Trim whitespace, reject empty titles with visible feedback, and clear/refocus the input after success.
- REQ-002: Show each task title and a labeled completion checkbox. Checking marks the task complete with a visible style; unchecking restores it. Show all tasks in creation order.
- REQ-003: Each task has an accessible Delete button that removes only that task immediately.
- REQ-004: Add, completion changes and deletion persist in localStorage and survive reload on the same origin. A new browser storage context starts empty.
- REQ-005: Provide a usable responsive UI with a heading, labeled input, empty state, keyboard-operable controls and visible focus. Treat task titles as text.
- REQ-006: Malformed saved data must not crash the UI. If storage cannot be read or written, show a clear persistence warning and allow current-session task management.

## Scope exclusions
- Accounts, authentication, server, sharing, sync, editing, priorities, drag and drop, deployment and remote publication.

## Open Questions
None. The user authorized reasonable defaults; this scope uses one local list without accounts.
