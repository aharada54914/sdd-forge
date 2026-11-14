# Requirements: SQLite Task Board

Spec-Review-Status: Passed

## Overview
Disposable Japanese task UI for one local user. FULL profile. One root page, Python standard library, SQLite and plain HTML/JS.

## Requirements and User Stories
- REQ-001: Open `/` directly to 今日のタスク, a named title input, 追加 button and task list.
- REQ-002: Add a trimmed nonblank title of 1–200 Unicode codepoints using Enter or 追加. Count after trimming; each astral character counts once, independently of UTF-16 code units and UTF-8 bytes. Exactly 200 codepoints including astral characters must succeed without truncation. New tasks are unchecked. Duplicate titles allowed; oldest first.
- REQ-003: Checkbox toggles completion both ways. Completed titles have a strike-through. Reload retains saved state.
- REQ-004: Visible 削除 on each row opens Japanese confirmation; cancel preserves the row, confirm deletes only that task.
- REQ-005: All acknowledged adds, toggles and deletes survive Python process restart with the same SQLite path.
- REQ-006: Japanese UI, white background, blue accents, custom design contract. Responsive at 375px and 1280px without horizontal overflow. Supplied ImageGen reference guides spacing and rows.
- REQ-007: Accessible labels, keyboard operation, visible focus, 44px action targets and loading/empty/error/success feedback. Read failures offer retry; write failures retain draft and last saved list without claiming success.
- REQ-008: Loopback only, no external assets. Validate JSON/types/title bounds server-side, parameterize SQL and render title text literally. Reject foreign Host/Origin writes. API mutations require a single valid nonnegative decimal Content-Length and no Transfer-Encoding. Missing length returns 411; malformed/negative/duplicate length or any Transfer-Encoding returns 400 before mutation. Maximum body is 4096 raw transmitted UTF-8 JSON bytes including syntax, escapes and whitespace, excluding HTTP headers, measured before decoding/parsing. Reject a declared size above 4096 with 413 before reading the body or mutating data. Exactly 4096 bytes is supported for otherwise valid JSON/input. Require the complete declared body with bounded read timeout; truncation returns 400 without mutation. POST/PATCH require JSON bodies; DELETE uses Content-Length: 0 and no body. Transport byte limits and title codepoint limits are separate.

## Acceptance Criteria
AC-001–008 in acceptance-tests.md correspond respectively to REQ-001–008.

## Non-goals
No deploy, auth, cloud, sharing, multi-user, editing, filters, dashboard, sidebar or due dates. Reference counts and decorative controls add no requirements.

## Roles and Workflow
One local user may list/add/toggle/delete all tasks. Open root, load, add, toggle, confirm deletion. Successful writes are acknowledged only after commit.

## Edge Cases and Boundaries
Reject blank/overlong titles and malformed requests without insertion. Handle Japanese, duplicate titles and HTML-like text. Unknown task IDs fail without mutation. Local task text remains in SQLite until logical deletion; OS file access controls apply. No encryption or secure-erasure claim.

## Assumptions
Python 3 and writable local disk available. Disposable data, no hosted availability or backup service.

## Risks
Persistence loss: actual process-restart test. UI regressions: real browser CRUD and responsive screenshots. Injection/cross-site writes: negative boundary tests.

## Open Questions
No product questions. The parent fixture (evidence/parent-design-fixture.json) grants Phase 1 visual design-system consent ONLY for this disposable test. It does not approve architecture, implementation policy, task contracts or implementation. Spec-Review and Impl-Review remain Pending; tasks remain unapproved and have not been generated. No implementation exists. All functional requirements and acceptance tests remain required.
