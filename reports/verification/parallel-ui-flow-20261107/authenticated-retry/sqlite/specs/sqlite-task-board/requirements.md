# Requirements: SQLite Task Board

Spec-Review-Status: Pending

## Overview
Single-user local browser task manager. Python standard-library runtime, SQLite persistence and plain HTML/JS. Draft proposal using authorized reasonable defaults.

## Target Users
One trusted local OS user.

## Problems
Work items must remain available across process restarts without external services.

## Goals
REQ-001: Add and list tasks with trimmed titles of 1–200 characters in ascending creation ID order.
REQ-002: Complete tasks; completed rows remain visible and completion is idempotent.
REQ-003: Permanently delete an individual saved task.
REQ-004: Commit every successful mutation to a local SQLite file that survives restart.
REQ-005: Provide a keyboard-accessible single page with empty/loading/error/success states.
REQ-006: Use loopback-only hosting, bounded validated requests, parameterized SQL and safe text rendering.

## Non-goals
Accounts, multiuser access, editing, undo, due dates, attachments, cloud hosting and publishing. No encryption or forensic-erasure claim.

## User Stories
The local user records work, lists outstanding and completed work, completes work and removes unwanted rows, including after application restart.

## Acceptance Criteria
AC-001 (REQ-001): Adding ' Buy milk ' shows exactly one 'Buy milk' row without reload. Reload preserves it. Blank and >200-character titles are rejected without a write. Duplicate valid titles are allowed.
AC-002 (REQ-002): Completing an open task visibly marks only that task completed. Repeated completion leaves it completed.
AC-003 (REQ-003): Deleting a task removes only its row. Absent IDs return 404 and preserve other tasks.
AC-004 (REQ-004): In the actual UI add A/B/C, complete A and delete B; stop the server and restart using the same database. Reload shows completed A and open C, no B, retaining IDs and titles.
AC-005 (REQ-005): Root page exposes labeled input and Add, with Complete for open rows and Delete for saved rows. Keyboard activates all actions. Invalid/pending Add and pending row actions are disabled. Empty, loading, failure and success states are visible and announced. At 320px and 1280px no horizontal scrolling hides actions.
AC-006 (REQ-006): Bind only 127.0.0.1. Reject foreign Host and cross-origin mutations, malformed JSON, >4096-byte bodies, wrong content types and invalid IDs without data changes. HTML-like titles display literally; SQL-like titles cannot alter schema. Request logs omit task titles.
AC-007 (REQ-006): Documented launch and unittest commands need no third-party runtime packages. UI assets total <=100 KiB uncompressed. List 100 tasks in <=1 second for each of 20 requests on the verification host; retain timings.

## Roles and Permissions
All local users/processes able to access loopback may access all tasks. No login, authorization roles or tenant separation. Document this limitation.

## Main Workflows
Open root, load list, add, complete/delete, reload, restart and verify durable state.

## Edge Cases
Empty store, duplicate titles, stale IDs, locked/unwritable DB and disconnected server. Failure never displays successful mutation; preserve entered text for recovery.

## Security Boundaries
| Trust Boundary | Auth/Authz Requirement | PII / Data Classification | Regulatory Constraints |
|---|---|---|---|
| Browser/server | Loopback, Host and Origin checks; no login | Local personal task text | No compliance claim |
| Server/database | Fixed file path and parameterized SQL | Same task text | OS file access |

## Assumptions
Python 3.12+, modern browser, writable local disk, one user and up to 1000 tasks. Proposed defaults: single root page, permanent deletion and ds_profile none.

## Open Questions
Human was explicitly asked to confirm shell reachability/safety and design profile. Explicit responses pending; confirm proposed defaults during review before implementation.

## Risks
Deletion and disk failure can lose data. Document offline backup and local access limitations. Real browser/restart evidence is mandatory; API-only verification is insufficient.
