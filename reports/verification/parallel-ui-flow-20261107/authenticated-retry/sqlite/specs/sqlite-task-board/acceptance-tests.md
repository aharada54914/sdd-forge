# Acceptance Tests: SQLite Task Board

| Acceptance Criterion | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001 | REQ-001 | TEST-001 | integration/browser | add/list/validation | Planned |
| AC-002 | REQ-002 | TEST-002 | integration/browser | completion/idempotency | Planned |
| AC-003 | REQ-003 | TEST-003 | integration/browser | deletion/stale IDs | Planned |
| AC-004 | REQ-004 | TEST-004 | actual restart e2e | browser + new server process + same DB | Planned |
| AC-005 | REQ-005 | TEST-005 | browser/accessibility | keyboard, state feedback and responsive reflow | Planned |
| AC-006 | REQ-006 | TEST-006 | negative integration/browser | hostile requests, SQL and HTML-like titles | Planned |
| AC-007 | REQ-006 | TEST-007 | execution/timing | launch, unittest, asset size and list timings | Planned |

## UI Integration Checklist
- [ ] AC-005: Root shell http://127.0.0.1:8000/ exposes the input, Add and row actions without console commands or hidden routes.
- [ ] AC-001/AC-005: Invalid/pending Add is disabled; submit handler and server independently validate input.
- [ ] AC-002/AC-005: Complete is absent for completed rows. Pending row actions are disabled.
- [ ] AC-003: Delete targets the selected saved ID only.

## Execution and Evidence
Use temporary isolated data. Record commands, versions, exit codes, server logs, database path and both process IDs. TEST-004 uses actual browser clicks and assertions, a real process stop and a newly launched process using the same file. Screenshot empty, populated, completed and post-restart states under reports/visual-evidence/sqlite-task-board/. Save other evidence under reports/implementation/sqlite-task-board/. Never substitute fixtures or API-only checks for browser/restart evidence.

TEST-005 covers tab order, Enter submission, accessible names, focus restoration, associated errors, live-region announcements, visible focus and contrast. TEST-006 covers invalid JSON, oversized bodies, wrong media type, foreign Host/Origin, missing/nonpositive/nonnumeric IDs, literal HTML and SQL-like input. Assert unchanged rows after rejected mutations.
