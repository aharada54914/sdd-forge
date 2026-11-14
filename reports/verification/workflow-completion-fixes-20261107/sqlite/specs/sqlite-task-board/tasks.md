# Tasks: SQLite Task Board

Task-Review-Status: Passed

## Shared Contract
All tasks remain Approval Draft and Status Planned until the parent fixture. Only quality-gate sets Done. User-authorized agent corrections split the oversized task into storage/unit, HTTP/integration and UI/browser concerns. These are not human-authored approvals. Shared AC references differ by test level; no acceptance case is dropped.

Each high-risk task requires committed Red tests: commit its failing scoped tests before production implementation begins; record actual commit SHA, failed command/log/test bytes and corresponding Green. Parent fixture must include that scoped Red test commit authorization. No commits during specification/review; no production commit/push/merge/publication without separate authority.

Must Read for every task: all seven Phase1 specs and traceability.md under specs/sqlite-task-board/, docs/adr/0001-local-stdlib-sqlite.md, design-system/design-system.md, design-system/design-tokens.json, design-system/ui-patterns.md. T-003 also reads actual specs/sqlite-task-board/mockups/imagegen-reference.png. Frozen spec/design/layer/ADR/visual/traceability bodies are inputs, not completion edits. Actual result mappings belong in non-frozen reports/implementation/sqlite-task-board/verification-addendum.md and task reports; only permitted lifecycle/status normalization changes frozen statuses.

## T-001 Implement task storage with unit verification

Source Issue: User-supplied disposable Japanese task-board requirements.

Approval: Approved

Status: Done

Risk: high

Risk Rationale: SQLite initial schema creation and task data mutation are sensitive data surfaces.

Required Workflow: tdd

Requirements: REQ-002, REQ-003, REQ-004, REQ-005, AC-005

Planned Files: schema.py, repository.py, tests/test_schema.py, tests/test_repository.py, reports/implementation/sqlite-task-board/T-001.md, reports/implementation/sqlite-task-board/verification-addendum.md

Data Migration: Initial schema v1 only; no existing-data upgrade or destructive recovery.

Breaking API: None; internal store consumed by T-002.

Blockers: None

### Goal
Provide the durable local store with a passing storage-unit completion boundary.

### Scope
Implement schema.py::initialize_database and repository.py per design.md#data-plan: initial v1, exclusive publication, read-only existing-file validation/preservation, parameterized CRUD, stable order, bounded connection ownership and commit/rollback/close. Own AC-005 storage/unit level; T-003 owns final browser/process persistence. No HTTP/UI code. Read shared Must Read list.

### Done When
- [ ] tests/test_schema.py and tests/test_repository.py pass with real temporary SQLite/files for creation/reuse/schema mismatch, rollback, close/reopen persistence, CRUD ordering/missing IDs and SQL-like titles; mocks only inject reviewed failures.
- [ ] Red→Green evidence captured with actual failing-test commit before storage implementation, SHA/logs/test versions under reports/implementation/sqlite-task-board/T-001/.
- [ ] Rollback tested per design.md#data-plan/infra-spec.md#rollback: failed first creation leaves target absent; existing mismatched/corrupt DB is byte-identical; restart never deletes/recreates data.
- [ ] Named distinct independent evaluator verdict and high-risk quality-gate report/contract pass with actual environment/spec_revision; only quality-gate sets Done.
- [ ] T-001 report and non-frozen verification-addendum.md map storage evidence to requirements/AC-005 without editing frozen traceability body.

### Out of Scope
HTTP/UI, remote services, destructive recovery, frozen-input edits. No implementation before fixture.

## T-002 Implement local HTTP API with integration verification

Source Issue: User-supplied disposable Japanese task-board requirements.

Approval: Approved

Status: Done

Risk: high

Risk Rationale: HTTP access/input boundaries dispatch SQLite mutations.

Required Workflow: tdd

Requirements: REQ-002, REQ-003, REQ-004, REQ-005, REQ-008, AC-008

Planned Files: validation.py, app.py, tests/test_validation.py, tests/test_app.py, tests/test_http_integration.py, reports/implementation/sqlite-task-board/T-002.md, reports/implementation/sqlite-task-board/verification-addendum.md

Data Migration: Consume T-001 schema; no schema changes.

Breaking API: None; new admitted local v1 DTO/routes.

Blockers: T-001

### Goal
Expose reviewed API over T-001 store, ending at passing real HTTP integration.

### Scope
Implement validation.py/app.py: admitted routes/request/DTO/error/framing mapping, SQL integer→JSON boolean, bounded threading/connections/timeouts, local static allowlist and initialization-before-bind. Assets arrive in T-003; no UI stub claimed as completion. Own AC-008 unit/HTTP level; T-003 adds browser level. No schema/repository edits except approved fix tickets. Read shared Must Read list.

### Done When
- [ ] tests/test_validation.py and tests/test_app.py pass reviewed pure validation, bounded synthetic streams, serializer and mocked-repository assertions that rejected input never mutates.
- [ ] Real loopback tests/test_http_integration.py passes admitted protocol/security cases: 200-codepoint/astral success, 4096-byte JSON success, 4097/withheld-body 413, framing/Host/Origin/ID/method/path negatives, exact DTO/status, no error mutation, timeout/resource cleanup and storage regressions.
- [ ] Red→Green evidence captured with actual failing-test commit before HTTP implementation, SHA/logs/test bytes under reports/implementation/sqlite-task-board/T-002/.
- [ ] Local startup/stop/restart/error integration tests preserve acknowledged data and safe rollback under design.md#data-plan/infra-spec.md#rollback; never delete existing DB.
- [ ] Named distinct independent evaluator verdict/high-risk quality-gate contract/report pass with environment/spec_revision before Done.
- [ ] T-002 report/non-frozen verification-addendum.md map HTTP/unit evidence to requirements/AC-008, with frozen traceability body unchanged.

### Out of Scope
UI, schema/repository rewrites, deploy/auth/cloud/sharing, frozen-input edits. No implementation before fixture.

## T-003 Implement Japanese task UI with browser verification

Source Issue: User-supplied disposable Japanese task-board requirements.

Approval: Approved

Status: Done

Risk: high

Risk Rationale: Browser mutation controls integrate acknowledged local data persistence.

Required Workflow: tdd

Requirements: REQ-001, REQ-002, REQ-003, REQ-004, REQ-005, REQ-006, REQ-007, REQ-008, AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-007, AC-008

Planned Files: static/index.html, static/app.js, static/styles.css, design-system/build/tokens.css, tests/browser_task_board.py, README.md, reports/implementation/sqlite-task-board/T-003.md, reports/implementation/sqlite-task-board/verification-addendum.md, reports/visual-evidence/sqlite-task-board/

Data Migration: None; consume approved persistence, verify browser restart behavior.

Breaking API: None; consume admitted v1 TaskDTO exactly.

Blockers: T-002

### Goal
Deliver Japanese single-page journey against completed API, ending at real browser/visual/restart verification.

### Scope
Plain Japanese input/Add, checkbox, confirmed delete; accessible loading/empty/error/success/retry/focus and responsive white/blue styling. Generate local CSS from approved tokens. Own browser-level AC-001–008, distinct from storage-unit T-001 and HTTP-integration T-002. README and browser suite support this same UI concern; no backend rewrites except approved fixes. Read shared Must Read list/reference.

### Done When
- [ ] Actual browser TEST-001–004 pass button/Enter add, checkbox/reload, cancel/confirm delete, duplicate/Japanese/literal titles and exact 200-codepoint/astral boundaries.
- [ ] TEST-005 records old/new server PIDs, same fresh SQLite path and exact surviving/complete/deleted state after actual restart/browser reload; no reused fixtures/localStorage substitute.
- [ ] TEST-006/007 pass real 375×812/1280×900 screenshots, ImageGen/token comparison, no overflow, 200% zoom, keyboard/names/focus/targets/contrast, announcements and forced read/write recovery retaining draft/saved rows.
- [ ] Browser TEST-008 verifies literal rendering/local assets/loopback and actual framing; storage/HTTP regressions pass and every complete acceptance-plan case below remains required.
- [ ] Red→Green evidence captured with actual failing browser-test commit before UI implementation, SHA/logs/test versions under reports/implementation/sqlite-task-board/T-003/.
- [ ] README documents exact local start/test/restart/rollback commands/browser prerequisites and tested safe rollback/preservation per design.md#data-plan/infra-spec.md#rollback; no deploy/auth/cloud/sharing.
- [ ] Named distinct independent evaluator verdict and high-risk quality-gate contract/report pass with environment/spec_revision before Done.
- [ ] T-003 report and non-frozen verification-addendum.md contain final REQ/AC/TEST→task→actual evidence maps/logs/screenshots; frozen traceability body receives no evidence edits.

### Out of Scope
Backend rewrites, decorative reference controls, extra features, deploy/auth/cloud/sharing or frozen-input edits. No implementation before fixture.

## Complete Acceptance Plan
All details in acceptance-tests.md remain mandatory without narrowing; the following assigns concrete artifacts:
- TEST-001–004: tests/browser_task_board.py uses a real installed browser to open root, add by button/Enter, toggle/reload both ways and cancel/confirm deletion. Check exact Japanese text, literal HTML/SQL-like titles, duplicates and no false success. No HTTP-only substitute.
- TEST-002/008: tests/test_validation.py and tests/test_http_integration.py verify trim/blank/201 rejection, successful exactly-200 titles including astral characters independently of UTF-16 units; real browser repeats successful boundaries and reloads exact titles. Valid JSON padded to exactly 4096 bytes succeeds; 4097 returns 413 before body read/mutation, including oversized declaration with no body. Literal/escaped Unicode representations use independently measured raw byte counts. Missing length 411; invalid/negative/duplicate length and Transfer-Encoding 400; short body/timeout 400; empty DELETE has Content-Length: 0; compare saved rows after every rejection.
- TEST-005: browser adds survivors, completes one and deletes another; tests/browser_task_board.py stops the real Python process, starts a new PID against the same fresh temporary SQLite path and reloads the browser to verify exact durable state and deleted-task absence. Save both PIDs, commands and observations. Never reuse earlier app fixtures or a browser-local persistence substitute.
- TEST-006/007: browser screenshots at 375×812 and 1280×900, no horizontal overflow, long-title reflow and 200% zoom; compare actual ImageGen reference and tokens. Verify named controls, keyboard add/toggle/delete, focus restoration/visible focus, target sizes/contrast, announcements, empty/loading, forced read failure/retry and forced write failure retaining draft/saved rows. Save screenshots and actual observations in reports/visual-evidence/sqlite-task-board/.
- Unit plan: tests/test_repository.py uses real temporary SQLite for SQL/transaction/ordering behavior with mocks only for deterministic failures; tests/test_app.py checks serializer/status/bounded reads/no invalid mutation and resource cleanup with synthetic streams/mock repository as specified; tests/test_schema.py uses real files for initial-create/reuse/preservation and failure injection only at defined create/commit/publication points. Related regressions run with full unittest discovery.
- Security/operations: real loopback binding/static allowlist, foreign Host/Origin, malformed input, unknown IDs/routes/methods, body limits, SQL parameterization/text rendering, bounded concurrency/timeout and rollback checks per design/security/infra specs. README documents exact commands and test-only browser prerequisites, local-only limitations and no deploy/auth/cloud/sharing.

