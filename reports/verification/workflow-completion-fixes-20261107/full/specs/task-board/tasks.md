# Tasks: task-board

Task-Review-Status: Passed

## Lifecycle
Draft -> Approved -> In Progress -> Implementation Complete -> Done. Parent owns human approval fixture provenance; only quality-gate sets Done.

## Shared Execution Contract
Implement the approved new local Python standard-library + HTML/CSS/JS task board without scope expansion. Requirements and acceptance-tests retain every original condition; image reference SHA, whitespace/long-title/keyboard/loading/error cases, atomic persistence, restart, Host/Origin/path/body limits, pending duplicate prevention and actual mobile/desktop Chromium remain mandatory. No previous fixture app reuse. Tests use fresh temporary stores and real HTTP; fault injection only at filesystem/network boundary. No external runtime dependency. No multi-process/power-loss/public/auth guarantees. Frozen specification bodies stay unchanged; permitted traceability delivery Status cells may advance only with actual evidence.

Execution is sequential: store -> HTTP; tokens -> UI, with final complete acceptance after all implementation. Component tasks establish testable deliverables; final task owns combined acceptance criteria, avoiding duplicate AC ownership. Each task has its own report and independent quality gate. High tasks require TDD: write/run scoped failing tests before implementation, then green, including Red/Green evidence for each test-type gate, independent verdict and provenance with spec_revision and environment. Parent must supply an authorized disposable git baseline and commit permission with approval fixture provenance; do not create commits without that authorization. No declared high task can omit tier-required checks.

## T-001 Implement transactional task storage

Source Issue: User-supplied integration-test requirements.

Approval: Approved

Status: Done

Risk: high

Risk Rationale: Data mutation or trust-boundary controls require high assurance.

Required Workflow: tdd

Requirements: REQ-001, REQ-002, REQ-003, REQ-004

Planned Files: store.py, tests/test_store.py

Data Migration: None — new app; no existing schema conversion.

Breaking API: No — implement existing reviewed design contract.

### Goal
Provide a standalone typed snapshot/mutation store with atomic persistence.

### Must Read
- specs/task-board/requirements.md
- specs/task-board/design.md
- specs/task-board/acceptance-tests.md
- specs/task-board/traceability.md
- specs/task-board/ux-spec.md
- specs/task-board/frontend-spec.md
- specs/task-board/infra-spec.md
- specs/task-board/security-spec.md
- contracts/task-board.md
- design-system/design-tokens.json
- design-system/design-system.md
- design-system/ui-patterns.md
- specs/task-board/mockups/imagegen-reference.png


### Scope
Own JSON version/validation, UUID, trim/length/bool checks, lock, candidate copy, fsync/replace commit and no publish on precommit failure. Tests cover append, explicit completion assignment, deletion and all storage negative paths. No HTTP/UI.

### Done When
- [ ] A failing scoped test is committed before implementation; record its commit hash and failing output, then implementation commit/hash and passing output. Independent review verdict identifies a named second reviewer distinct from the implementing agent; preserve reviewer identity and actual verdict, plus spec_revision/environment provenance.
- [ ] Scoped unit and persistence tests fail before implementation and pass afterward; save exact Red/Green logs under reports/implementation/task-board/T-001/.
- [ ] Tests prove process restart recovery (TEST-005 component), malformed/version/duplicate-id preservation, missing-store first-save and controlled pre-replace failures (TEST-011).
- [ ] Independent quality gate passes all high-tier checks; report records input manifest, implementation identity, spec_revision/environment, modified artifacts and regression results.

### Out of Scope
All other task-owned files; publication/auth/sharing/edit/due dates/search/filter/nav/counts, cloud/DB/framework, multi-process writes. Do not edit frozen spec bodies.

### Rollback
Stop server before restoring prior verified source; retain original JSON. First-run synthetic test stores may be discarded only by their owning test. No automatic corrupt-store reset. Retest scoped checks after restoration.

### Blockers
None

## T-002 Implement loopback HTTP and API boundary

Source Issue: User-supplied integration-test requirements.

Approval: Approved

Status: Done

Risk: high

Risk Rationale: Data mutation or trust-boundary controls require high assurance.

Required Workflow: tdd

Requirements: REQ-001, REQ-002, REQ-003, REQ-004, REQ-007

Planned Files: server.py, tests/test_http.py

Data Migration: None — new app; no existing schema conversion.

Breaking API: No — implement existing reviewed design contract.

### Goal
Expose reviewed HTTP contract over the tested store.

### Must Read
- specs/task-board/requirements.md
- specs/task-board/design.md
- specs/task-board/acceptance-tests.md
- specs/task-board/traceability.md
- specs/task-board/ux-spec.md
- specs/task-board/frontend-spec.md
- specs/task-board/infra-spec.md
- specs/task-board/security-spec.md
- contracts/task-board.md
- design-system/design-tokens.json
- design-system/design-system.md
- design-system/ui-patterns.md
- specs/task-board/mockups/imagegen-reference.png


### Scope
Own CLI, constant IPv4 loopback binding, static allowlist, JSON envelopes/status, strict request parsing and Host/Origin rules. Use real ephemeral-port server and temporary store; read store API delivered by T-001, never modify store files.

### Done When
- [ ] A failing scoped test is committed before implementation; record its commit hash and failing output, then implementation commit/hash and passing output. Independent review verdict identifies a named second reviewer distinct from the implementing agent; preserve reviewer identity and actual verdict, plus spec_revision/environment provenance.
- [ ] Real-server integration tests have saved Red/Green evidence before/after implementation; all method/path/request/status/envelope contracts match design.
- [ ] Negative tests cover wrong JSON/types/duplicate keys/UUID/length/body/content type/Host/Origin/traversal/unknown-id/method, storage failure and API snapshot/restart behavior (TEST-001/002/005/009/011 components).
- [ ] Independent quality gate passes high-tier checks; T-002 report records identity/input manifest, spec_revision/environment, commands/exit codes and rollback smoke outcome.

### Out of Scope
All other task-owned files; publication/auth/sharing/edit/due dates/search/filter/nav/counts, cloud/DB/framework, multi-process writes. Do not edit frozen spec bodies.

### Rollback
Stop server before restoring prior verified source; retain original JSON. First-run synthetic test stores may be discarded only by their owning test. No automatic corrupt-store reset. Retest scoped checks after restoration.

### Blockers
T-001

## T-003 Generate design token CSS

Source Issue: User-supplied integration-test requirements.

Approval: Approved

Status: Done

Risk: medium

Risk Rationale: Token transformation and validation are behavioral internal tooling.

Required Workflow: acceptance-first

Requirements: REQ-006

Planned Files: scripts/generate_tokens.py, design-system/build/tokens.css, tests/test_tokens.py

Data Migration: None — new app; no existing schema conversion.

Breaking API: No — implement existing reviewed design contract.

### Goal
Produce deterministic CSS variables from the existing design-system contract.

### Must Read
- specs/task-board/requirements.md
- specs/task-board/design.md
- specs/task-board/acceptance-tests.md
- specs/task-board/traceability.md
- specs/task-board/ux-spec.md
- specs/task-board/frontend-spec.md
- specs/task-board/infra-spec.md
- specs/task-board/security-spec.md
- contracts/task-board.md
- design-system/design-tokens.json
- design-system/design-system.md
- design-system/ui-patterns.md
- specs/task-board/mockups/imagegen-reference.png


### Scope
Write expected token transformation/invalid-input acceptance tests before implementation. Own stdlib token-to-CSS transformation, validate token shapes, fail for invalid input, no raw visual values outside token source/build. Existing design-system source remains unchanged. Generator test uses a synthetic invalid token file, not policy fixtures.

### Done When
- [ ] Generator produces expected CSS variable values from version 0.1.0 and rerun is deterministic; invalid token input fails visibly.
- [ ] python3 -m unittest discover -s tests -p test_tokens.py -v passes with saved command/output and generated artifact hash.
- [ ] Independent quality gate passes; T-003 report records artifacts and verification without claiming integrated visual acceptance.

### Out of Scope
All other task-owned files; publication/auth/sharing/edit/due dates/search/filter/nav/counts, cloud/DB/framework, multi-process writes. Do not edit frozen spec bodies.

### Rollback
Stop server before restoring prior verified source; retain original JSON. First-run synthetic test stores may be discarded only by their owning test. No automatic corrupt-store reset. Retest scoped checks after restoration.

### Blockers
None

## T-004 Implement Japanese responsive interactive view

Source Issue: User-supplied integration-test requirements.

Approval: Approved

Status: Done

Risk: high

Risk Rationale: Data mutation or trust-boundary controls require high assurance.

Required Workflow: tdd

Requirements: REQ-001, REQ-002, REQ-003, REQ-005, REQ-006, REQ-008

Planned Files: web/index.html, web/app.js, web/styles.css, tests/browser_checks.py

Data Migration: None — new app; no existing schema conversion.

Breaking API: No — implement existing reviewed design contract.

### Goal
Connect the single view to the real API with safe mutation interactions.

### Must Read
- specs/task-board/requirements.md
- specs/task-board/design.md
- specs/task-board/acceptance-tests.md
- specs/task-board/traceability.md
- specs/task-board/ux-spec.md
- specs/task-board/frontend-spec.md
- specs/task-board/infra-spec.md
- specs/task-board/security-spec.md
- contracts/task-board.md
- design-system/design-tokens.json
- design-system/design-system.md
- design-system/ui-patterns.md
- specs/task-board/mockups/imagegen-reference.png


### Scope
Own semantic UI, shared pending, confirmation, focus, Japanese live/error states, layout and executable Playwright harness. Consume T-002 API and T-003 token CSS. Browser harness uses actual Chromium/server and supports all TEST-001..012 observations needed by T-005. Do not add nav/count/filter or reference PNG as a runtime background.

### Done When
- [ ] A failing scoped test is committed before implementation; record its commit hash and failing output, then implementation commit/hash and passing output. Independent review verdict identifies a named second reviewer distinct from the implementing agent; preserve reviewer identity and actual verdict, plus spec_revision/environment provenance.
- [ ] Browser interaction cases have saved Red/Green evidence before/after UI implementation, including add/check/uncheck/delete/cancel, whitespace rejection and reload.
- [ ] Tests demonstrate exactly one delayed mutation, disabled competing controls, input preservation/no auto-retry on save failure, GET-error recovery, keyboard/focus and literal HTML-title rendering.
- [ ] Actual Chromium renders at 1440/390/320px with long-title reflow and selected hash-verified ImageGen attributes; save screenshots, console/page-error results and timing.
- [ ] Independent quality gate passes high-tier checks; T-004 report records identity/input manifest, spec_revision/environment and test Red/Green/provenance evidence.

### Out of Scope
All other task-owned files; publication/auth/sharing/edit/due dates/search/filter/nav/counts, cloud/DB/framework, multi-process writes. Do not edit frozen spec bodies.

### Rollback
Stop server before restoring prior verified source; retain original JSON. First-run synthetic test stores may be discarded only by their owning test. No automatic corrupt-store reset. Retest scoped checks after restoration.

### Blockers
T-002, T-003

## T-005 Verify integrated acceptance and document operation

Source Issue: User-supplied integration-test requirements.

Approval: Approved

Status: Done

Risk: medium

Risk Rationale: Read-only final acceptance verifies the integrated local app and preserves evidence.

Required Workflow: acceptance-first

Requirements: REQ-001, REQ-002, REQ-003, REQ-004, REQ-005, REQ-006, REQ-007, REQ-008

Planned Files: README.md, reports/implementation/task-board/T-005.md, reports/visual-evidence/task-board/

Data Migration: None — new app; no existing schema conversion.

Breaking API: No — implement existing reviewed design contract.

### Goal
Establish complete actual acceptance evidence for the assembled app.

### Must Read
- specs/task-board/requirements.md
- specs/task-board/design.md
- specs/task-board/acceptance-tests.md
- specs/task-board/traceability.md
- specs/task-board/ux-spec.md
- specs/task-board/frontend-spec.md
- specs/task-board/infra-spec.md
- specs/task-board/security-spec.md
- contracts/task-board.md
- design-system/design-tokens.json
- design-system/design-system.md
- design-system/ui-patterns.md
- specs/task-board/mockups/imagegen-reference.png


### Scope
Own final acceptance plan/results and README; execute existing tests, do not rewrite code or tests in this task. Enumerate expected observations before execution. T-001..004 provide tested artifacts; any failure opens a scoped approved repair rather than editing another task silently. Final acceptance ownership: AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-007, AC-008, AC-009, AC-010, AC-011, AC-012, AC-013.

### Done When
- [ ] All AC-001..013 have saved actual TEST-001..012 outcomes: creation/blank rejection, bidirectional checkbox and deletion/cancel/reload, restart, pending duplicates, failures, responsive reference comparison, security, keyboard and corruption integrity. No unverified case marked PASS.
- [ ] Run python3 -m unittest discover -s tests -v and python3 tests/browser_checks.py; save exact exit codes/versions/API/request-count/timing/console and screenshot evidence; preserve all original acceptance conditions.
- [ ] TEST-012 records actual PID/listen sockets: only 127.0.0.1, loopback GET=200 and direct proxy-free real nonloopback TCP refusal. No interface means AC-013 unverified and gate cannot pass.
- [ ] README documents startup, JSON location, tests, recovery/restart and limits; independent quality gate passes, report links acceptance matrix; permitted traceability Status cells reflect verified delivery without frozen body changes.

### Out of Scope
All other task-owned files; publication/auth/sharing/edit/due dates/search/filter/nav/counts, cloud/DB/framework, multi-process writes. Do not edit frozen spec bodies.

### Rollback
Stop server before restoring prior verified source; retain original JSON. First-run synthetic test stores may be discarded only by their owning test. No automatic corrupt-store reset. Retest scoped checks after restoration.

### Blockers
T-001, T-002, T-003, T-004

