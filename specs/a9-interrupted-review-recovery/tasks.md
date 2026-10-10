# Tasks: a9-interrupted-review-recovery

Task-Review-Status: Passed

## Lifecycle

Draft -> Approved -> In Progress -> Implementation Complete -> Done. Humans approve; only quality-gate sets Done. All tasks below are proposed high risk, not approved implementation authority. Full profile remains resolved; Phase2 continues the existing bootstrap, not a fresh track-selection invocation.

## T-001 Closed recovery admission and source evidence validation

Source Issue: Approved separate A9 interrupted-review recovery scope
Approval: Draft
Status: Planned
Risk: high
Risk Rationale: Authorization/provenance admission and persisted review-state mutation must fail closed (REQ-002, REQ-003).
Required Workflow: tdd
Blockers: None
Requirements: REQ-002, REQ-003
Acceptance Criteria: AC-002, AC-003
Test IDs: TEST-008–083 and all expanded F/H/P/A cases belonging to these IDs, excluding saved precheck.recovery cases TEST-057-H15/TEST-083-P15 assigned to T-003
Planned Files: plugins/sdd-review-loop/scripts/spec-review-precheck.sh; plugins/sdd-review-loop/scripts/spec-review-precheck.ps1; tests/spec-review-interrupted-recovery.tests.sh; tests/spec-review-interrupted-recovery.tests.ps1
Data Migration: None; no backfill/deletion/history rewrite.
Breaking API: No; additive explicit CLI/provenance contract, preserve ordinary reset.
Rollback: Revert only this task's code changes in a disposable fixture; ordinary reset retains its original terminal-contract behavior. Never delete historical evidence or partial targets; partial publication remains quarantined and unusable until separate authorized remediation.

### Bugfix Reproduction / Root Cause
Reproduce interrupted A-before-B evidence admission using source3/round3 and prior3/round2 NEEDS_WORK fixtures; diagnose exact terminal-contract/reset rejection and record source function/line plus failing TEST-016–083 counterpart. Identify closed-schema/identity/authorization cause before changing validation; regression covers each independently mutated field and later valid ledger records.

### Goal / Scope
Implement bounded closed-record validation in existing precheck twins, reusing own-stage contract validation and persisted identity verifier without reservation. Unit-test decoded duplicate keys/types/canonical digest/eight authorization bindings/repeated pins/source predicates and real contained paths with no mocks. Integrate actual prior NEEDS_WORK, A interruption inventory/ledger/receipts and B absence in disposable fixtures; no mock contract or identity verifier. Orchestrator must establish trusted original human approval plus application report; reject agent/file/log-only origin.

### Must Read
- specs/a9-interrupted-review-recovery/requirements.md
- specs/a9-interrupted-review-recovery/design.md
- specs/a9-interrupted-review-recovery/acceptance-tests.md
- specs/a9-interrupted-review-recovery/traceability.md
- specs/a9-interrupted-review-recovery/ux-spec.md#scope-and-user-journeys
- specs/a9-interrupted-review-recovery/frontend-spec.md#technology-stack
- specs/a9-interrupted-review-recovery/infra-spec.md#deployment-topology
- specs/a9-interrupted-review-recovery/security-spec.md#trust-boundaries
- contracts/spec-review-interrupted-recovery.v1.data-contract.md

### Evidence / High-risk Preflight
Before implementation, record in reports/implementation/a9-interrupted-review-recovery/T-001.md every persisted evidence field, its sibling-contract/traceability counterpart and a named failing mismatch test. Include recovery record fields and eight authorization bindings, repeated pins/inventory/identity, saved recovery.record_path/record_sha256, report Run ID/Task Attempt Count, verdict/counts/identity/provenance/spec_revision and traceability claims. No persisted field may lack all three entries; no implementation until complete. Existing actual human user-channel approval/application origin is orchestrator-owned; validator checks content/hash/binding only. AUTH-001 blocks actual recovery if unavailable, not writing this implementation.

### Done When
- [ ] Before production implementation, create the named failing-test checkpoint commit and record its exact commit ID plus failing command/output in the implementation report; this task plan does not authorize committing now.
- [ ] Independent named reviewer distinct from implementer records verdict and identity; no self-review.
- [ ] Tested rollback evidence shows code revert restores ordinary reset behavior, historical bytes unchanged and existing partial target still quarantined/unusable in a safe disposable fixture.
- [ ] Assigned concrete TEST-ID cases and every listed parameter/variant have Red then Green evidence; unit, acceptance and related regression runs have existing path-safe evidence in both runtimes.
- [ ] Implementation report includes Run ID, Task Attempt Count, spec_revision and environment; no planned evidence is presented as executed proof.
- [ ] Independent review verdict and requirement-traceability/component-coverage evidence recorded; quality-gate passes before Done.
- [ ] Frozen traceability/AC/design/layers are not edited; execution results and T-001 → REQ/AC/TEST evidence mapping are recorded in specs/a9-interrupted-review-recovery/verification/T-001.md and implementation/quality reports.
- [ ] Unavailable PowerShell/newly reachable SKIP remains explicitly unverified/pending real execution, never PASS; mandatory checks not waived.

### Out of Scope
Live A9 recovery/reservations, historical evidence edits, generic approval/crypto frameworks, new dependencies, global sidecars, guard changes, unrelated refactors, self-approval and frozen specification edits.

### Start Conditions
Human task approval and independent task-review gate pending. Actual recovery additionally requires AUTH-001 original human approval/application provenance.

## T-002 Explicit recovery transition and locked publication

Source Issue: Approved separate A9 interrupted-review recovery scope
Approval: Draft
Status: Planned
Risk: high
Risk Rationale: Authorization/provenance admission and persisted review-state mutation must fail closed (REQ-001, REQ-004).
Required Workflow: tdd
Blockers: T-001
Requirements: REQ-001, REQ-004
Acceptance Criteria: AC-001, AC-004
Test IDs: TEST-001–007, TEST-084–096 with expanded symlink path cases TEST-086-P01–P14/TEST-088-P01–P14; exclude TEST-086-P15/TEST-088-P15 saved precheck.recovery consumption assigned to T-003
Planned Files: plugins/sdd-review-loop/scripts/spec-review-precheck.sh; plugins/sdd-review-loop/scripts/spec-review-precheck.ps1; tests/spec-review-interrupted-recovery.tests.sh; tests/spec-review-interrupted-recovery.tests.ps1
Data Migration: None; no backfill/deletion/history rewrite.
Breaking API: No; additive explicit CLI/provenance contract, preserve ordinary reset.
Rollback: Revert only this task's code changes in a disposable fixture; ordinary reset retains its original terminal-contract behavior. Never delete historical evidence or partial targets; partial publication remains quarantined and unusable until separate authorized remediation.

### Bugfix Reproduction / Root Cause
Reproduce missing explicit recovery transition for target4/round1 and reset failure against the exact interrupted source fixture; diagnose option dispatch and existing lock/publication lines before editing. Capture failing TEST-001/004 and races TEST-091–095; corresponding regression preserves reset rejection and partial-target quarantine.

### Goal / Scope
Add exclusive exact-case recovery options and target N+1/1 admission, reuse existing single-writer lock and under-lock revalidation/writer. Actual integration tests race pins/latest source/target and two writers without mocks. Distinguish pre-publication rejection (no target) from TEST-095 interrupted publication (nonzero partial target quarantined, no automatic cleanup/reuse/reset/PASS). Persist only new Pending precheck and blank report with exact recovery provenance; all old bytes/status/ledger invariant.

### Must Read
- specs/a9-interrupted-review-recovery/requirements.md
- specs/a9-interrupted-review-recovery/design.md
- specs/a9-interrupted-review-recovery/acceptance-tests.md
- specs/a9-interrupted-review-recovery/traceability.md
- specs/a9-interrupted-review-recovery/ux-spec.md#scope-and-user-journeys
- specs/a9-interrupted-review-recovery/frontend-spec.md#technology-stack
- specs/a9-interrupted-review-recovery/infra-spec.md#deployment-topology
- specs/a9-interrupted-review-recovery/security-spec.md#trust-boundaries
- contracts/spec-review-interrupted-recovery.v1.data-contract.md

### Evidence / High-risk Preflight
Before implementation, record in reports/implementation/a9-interrupted-review-recovery/T-002.md every persisted evidence field, its sibling-contract/traceability counterpart and a named failing mismatch test. Include recovery record fields and eight authorization bindings, repeated pins/inventory/identity, saved recovery.record_path/record_sha256, report Run ID/Task Attempt Count, verdict/counts/identity/provenance/spec_revision and traceability claims. No persisted field may lack all three entries; no implementation until complete. Existing actual human user-channel approval/application origin is orchestrator-owned; validator checks content/hash/binding only. AUTH-001 blocks actual recovery if unavailable, not writing this implementation.

### Done When
- [ ] Before production implementation, create the named failing-test checkpoint commit and record its exact commit ID plus failing command/output in the implementation report; this task plan does not authorize committing now.
- [ ] Independent named reviewer distinct from implementer records verdict and identity; no self-review.
- [ ] Tested rollback evidence shows code revert restores ordinary reset behavior, historical bytes unchanged and existing partial target still quarantined/unusable in a safe disposable fixture.
- [ ] Changed defect and negative-mutation TEST-ID cases/variants have recorded Red then Green evidence; already-correct compatibility cases/variants have a passing pre-change baseline and passing post-change regression, not fabricated Red evidence. Record each assigned TEST-ID/variant's evidence category and exact outputs in specs/a9-interrupted-review-recovery/verification/T-002.md; unit, acceptance and related regression runs have existing path-safe evidence in both runtimes.
- [ ] Implementation report includes Run ID, Task Attempt Count, spec_revision and environment; no planned evidence is presented as executed proof.
- [ ] Independent review verdict and requirement-traceability/component-coverage evidence recorded; quality-gate passes before Done.
- [ ] Frozen traceability/AC/design/layers are not edited; execution results and T-002 → REQ/AC/TEST evidence mapping are recorded in specs/a9-interrupted-review-recovery/verification/T-002.md and implementation/quality reports.
- [ ] Unavailable PowerShell/newly reachable SKIP remains explicitly unverified/pending real execution, never PASS; mandatory checks not waived.

### Out of Scope
Live A9 recovery/reservations, historical evidence edits, generic approval/crypto frameworks, new dependencies, global sidecars, guard changes, unrelated refactors, self-approval and frozen specification edits.

### Start Conditions
Human task approval and independent task-review gate pending. Actual recovery additionally requires AUTH-001 original human approval/application provenance.

## T-003 Provenance consumption and compatibility proof

Source Issue: Approved separate A9 interrupted-review recovery scope
Approval: Draft
Status: Planned
Risk: high
Risk Rationale: Authorization/provenance admission and persisted review-state mutation must fail closed (REQ-005).
Required Workflow: tdd
Blockers: T-001, T-002
Requirements: REQ-005
Acceptance Criteria: AC-005
Test IDs: TEST-097–107 plus TEST-057-H15/TEST-083-P15/TEST-086-P15/TEST-088-P15 and all saved precheck.recovery key/path/hash variants
Planned Files: plugins/sdd-review-loop/scripts/impl-review-precheck.sh; plugins/sdd-review-loop/scripts/impl-review-precheck.ps1; plugins/sdd-review-loop/scripts/task-review-precheck.sh; plugins/sdd-review-loop/scripts/task-review-precheck.ps1; tests/spec-review-interrupted-recovery.tests.sh; tests/spec-review-interrupted-recovery.tests.ps1; existing downstream/reset/parity/loop/guard/calibration suites
Data Migration: None; no backfill/deletion/history rewrite.
Breaking API: No; additive explicit CLI/provenance contract, preserve ordinary reset.
Rollback: Revert only this task's code changes in a disposable fixture; ordinary reset retains its original terminal-contract behavior. Never delete historical evidence or partial targets; partial publication remains quarantined and unusable until separate authorized remediation.

### Bugfix Reproduction / Root Cause
Reproduce legacy/no-recovery and new exact recovery provenance consumption in actual downstream disposable fixtures; diagnose current consumer field/hash handling before any code edit. Capture failing provenance mutation TEST-097/098 and compatibility oracle TEST-099–107; if an existing behavior is already correct record its passing baseline and add a failing negative mutation test rather than inventing a defect.

### Goal / Scope
Test-first minimal existing consumer validation of optional legacy vs mandatory new-route exact recovery record_path/hash. Recovery alone never grants PASS; preserve normal reset, downstream PASS/hash/identity and layer/calibration behavior. Execute entire acceptance matrix including prior-task cases in both actual runtimes and named existing regression inventory. Independently sweep PowerShell operators and cmdlet/language behavior with mis-cased negatives; no contiguous banned-marker false positives. Do not modify consumer code when existing behavior already satisfies the tests; report exact executed evidence.

### Must Read
- specs/a9-interrupted-review-recovery/requirements.md
- specs/a9-interrupted-review-recovery/design.md
- specs/a9-interrupted-review-recovery/acceptance-tests.md
- specs/a9-interrupted-review-recovery/traceability.md
- specs/a9-interrupted-review-recovery/ux-spec.md#scope-and-user-journeys
- specs/a9-interrupted-review-recovery/frontend-spec.md#technology-stack
- specs/a9-interrupted-review-recovery/infra-spec.md#deployment-topology
- specs/a9-interrupted-review-recovery/security-spec.md#trust-boundaries
- contracts/spec-review-interrupted-recovery.v1.data-contract.md

### Evidence / High-risk Preflight
Before implementation, record in reports/implementation/a9-interrupted-review-recovery/T-003.md every persisted evidence field, its sibling-contract/traceability counterpart and a named failing mismatch test. Include recovery record fields and eight authorization bindings, repeated pins/inventory/identity, saved recovery.record_path/record_sha256, report Run ID/Task Attempt Count, verdict/counts/identity/provenance/spec_revision and traceability claims. No persisted field may lack all three entries; no implementation until complete. Existing actual human user-channel approval/application origin is orchestrator-owned; validator checks content/hash/binding only. AUTH-001 blocks actual recovery if unavailable, not writing this implementation.

### Done When
- [ ] Before production implementation, create the named failing-test checkpoint commit and record its exact commit ID plus failing command/output in the implementation report; this task plan does not authorize committing now.
- [ ] Independent named reviewer distinct from implementer records verdict and identity; no self-review.
- [ ] Tested rollback evidence shows code revert restores ordinary reset behavior, historical bytes unchanged and existing partial target still quarantined/unusable in a safe disposable fixture.
- [ ] Changed defect and negative-mutation TEST-ID cases/variants have recorded Red then Green evidence; already-correct compatibility cases/variants (including TEST-099/100) have a passing pre-change baseline and passing post-change regression, not fabricated Red evidence. Record each assigned TEST-ID/variant's evidence category and exact outputs in specs/a9-interrupted-review-recovery/verification/T-003.md; unit, acceptance and related regression runs have existing path-safe evidence in both runtimes.
- [ ] Implementation report includes Run ID, Task Attempt Count, spec_revision and environment; no planned evidence is presented as executed proof.
- [ ] Independent review verdict and requirement-traceability/component-coverage evidence recorded; quality-gate passes before Done.
- [ ] Frozen traceability/AC/design/layers are not edited; execution results and T-003 → REQ/AC/TEST evidence mapping are recorded in specs/a9-interrupted-review-recovery/verification/T-003.md and implementation/quality reports.
- [ ] Unavailable PowerShell/newly reachable SKIP remains explicitly unverified/pending real execution, never PASS; mandatory checks not waived.

### Out of Scope
Live A9 recovery/reservations, historical evidence edits, generic approval/crypto frameworks, new dependencies, global sidecars, guard changes, unrelated refactors, self-approval and frozen specification edits.

### Start Conditions
Human task approval and independent task-review gate pending. Actual recovery additionally requires AUTH-001 original human approval/application provenance.
