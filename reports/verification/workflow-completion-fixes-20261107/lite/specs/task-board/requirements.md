# 要件（lite）: Task board

- **Issue/出典**: source.txt (complete brief copied below)
- **目的**: 日本語で個人のタスクを簡単に管理する。

## ユーザーストーリー / 要求
- REQ-001: Add a task; complete/reopen and delete it with keyboard-accessible controls.
- REQ-002: Persist every change using localStorage. Reject empty/whitespace input. Render titles literally as text.
- REQ-003: Malformed or unavailable storage must leave the current session usable with a visible Japanese notice; never silently overwrite malformed stored data during initial load.
- REQ-004: Responsive desktop/mobile Japanese UI using the supplied off-white/navy/teal visual reference; no extra nonfunctional sidebar/features.

## Complete source (verbatim)
# Task board
Create a simple Japanese personal task board UI. Add, complete/reopen and delete tasks. Persist all changes via localStorage. Validate empty input, render task titles as literal text, handle malformed/unavailable storage without losing current session usability. Support keyboard and desktop/mobile layouts.

## Scope exclusions
- Accounts, authentication, server, sharing, sync, editing, priorities, drag and drop, deployment and remote publication.

## Open Questions
- None within the explicit minimal scope. Storage schema and implementation details are defined in design.md.
