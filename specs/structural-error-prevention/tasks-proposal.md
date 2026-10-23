# Proposed Tasks: Structural Error Prevention

Proposal-Status: Draft (not tasks.md; not reviewed)

## Planning Boundary

Preliminary Codex-authored proposal, following the existing #594/#614 `tasks-proposal.md` convention. Formal `tasks.md` remains absent: the current workflow-state checker requires specification and implementation-policy reviews to pass before that file exists. After those gates, Phase 2 converts these proposals into Draft/Planned tasks for task review and human approval. The fields and T-identifiers below are proposed values, not formal lifecycle state or execution authorization. All tasks require independent specification/design/task reviews and human approval before implementation. Existing task lifecycle and quality-gate authority remain unchanged. Future implementation evidence belongs in non-frozen implementation reports/verification addenda; do not edit frozen spec bodies to record results.

## T-001 Register the existing focused mirror suite

Source Issue: #601

Approval: Draft

Status: Planned

Risk: medium

Risk Rationale: Changes executable CI coverage without changing mirror/approval policy.

Required Workflow: full

Requirements: REQ-002, REQ-005, REQ-006

Planned Files: tests/verification-catalog.json; tests/verification-catalog.tests.py only if existing registration/execution assertions cannot cover the new entry

Data Migration: none

Breaking API: no

### Goal

Remove the confirmed excluded-suite execution gap through existing catalog profiles, preserving all safety checks.

### Must Read

- requirements.md, design.md#registration-and-regression-integration, acceptance-tests.md, traceability.md and all four layer specifications in this directory.
- tests/verification-catalog.json, tests/verification.py, tests/human-copy-mirrors-classification.tests.py and existing local/CI callers.

### Scope

Perform design.md#shared-state-reverification at current HEAD before selecting a delta. Register the existing Python suite directly in existing compatible local and CI profiles following neighboring registrations; no new wrapper, runner, dependency or classifier. Confirm actual selection/execution rather than accepting metadata alone. Reuse existing catalog regression coverage; any necessary extension stays in that suite.

### Done When

- [ ] TEST-002a, TEST-002b, TEST-002c, TEST-006a, TEST-006b, TEST-006c, TEST-006d, TEST-006e, TEST-006f, TEST-006g, TEST-006h, TEST-006i, TEST-006j, TEST-006k, TEST-006l, TEST-006m, TEST-007a, TEST-007b, TEST-007c, TEST-007d, TEST-007e, TEST-007f evidence shows actual execution and isolated failure propagation, catalog validity and preserved applicable mirror/generator checks.
- [ ] Existing local and CI routes select the suite; required runtimes remain required and skips remain explicit.
- [ ] Implementation report and verification addendum map this task to its requirements; independent quality gate evaluates completion.

### Out of Scope

Classifier behavior changes, automatic mirror sync, historical evidence edits, catalog schema changes and approval relaxation.

### Blockers

Formal reviews and human task approval pending; no dependency on #600.

## T-002 Complete bounded negative and legitimate-operation coverage

Source Issue: #601

Approval: Draft

Status: Planned

Risk: medium

Risk Rationale: Fixtures must preserve existing safety semantics and avoid counterfeit runtime evidence.

Required Workflow: full

Requirements: REQ-001, REQ-003, REQ-004, REQ-005, REQ-006

Planned Files: tests/human-copy-mirrors-classification.tests.py only for uncovered second-edit control; tests/cross-model-encoding.tests.ps1 only for the missing synthetic BOM consumer negative; specs/structural-error-prevention/verification/T-002/ for new non-frozen execution evidence

Data Migration: none

Breaking API: no

### Goal

Demonstrate the three selected classes through existing mechanisms and isolate any remaining evidence limits.

### Must Read

- requirements.md, design.md#source-map and #registration-and-regression-integration, acceptance-tests.md, traceability.md and all four layer specifications.
- Existing focused classifier, cross-model encoding, self-improvement guard and verification catalog suites; #619 corrected version explanation.

### Scope

Depends on T-001's registration for focused CI execution. Reverify the shared helper/delegation and case inventory at current HEAD as required by design.md#shared-state-reverification. Reuse existing cases for C1/C2/C3. If absent, add the synthetic second-edit ambiguity control to the existing focused suite; preserve the existing diagnostic/classification and demonstrate no write. Also add the missing BOM-prefixed temporary-copy negative to the existing delegated encoding helper, separately asserting nonzero exits from its unchanged Python and Node consumers while retaining the valid unprefixed controls (TEST-004e, TEST-004f). This synthetic case must run without Desktop; it is not producer Red evidence. Capture actual runtime/version and strict consumer results through existing producer tests. Use existing completion and catalog mutations for C3; interpretation cases are handed off by T-003, not a new grader here. Surface unsupported/unavailable environments honestly; native Desktop evidence comes from the existing Windows route, never a fabricated Core Red.

### Done When

- [ ] TEST-003a, TEST-003b, TEST-003c, TEST-003d, TEST-003e, TEST-003f, TEST-003g, TEST-003h, TEST-003i, TEST-003j, TEST-003k, TEST-004a, TEST-004b, TEST-004c, TEST-004d, TEST-004e, TEST-004f, TEST-005a, TEST-005b, TEST-005c, TEST-005d, TEST-005e, TEST-005f, TEST-005g, TEST-005h, TEST-005i, TEST-005j, TEST-006a, TEST-006b, TEST-006c, TEST-006d, TEST-006e, TEST-006f, TEST-006g, TEST-006h, TEST-006i, TEST-006j, TEST-006k, TEST-006l, TEST-006m, TEST-007a, TEST-007b, TEST-007c, TEST-007d, TEST-007e, TEST-007f evidence distinguishes negative/control, actual reproduction, synthetic rejection and unexecuted environments.
- [ ] Existing cases are reused; any new focused classifier case is isolated and executed through T-001 registration. The BOM negative is isolated and executed through the existing CM-016 helper delegation, not a new catalog entry.
- [ ] Applicable native parity/mirror checks retain behavior. No frozen or pending artifact changes occur.
- [ ] Implementation report and verification addendum record evidence/limitations; independent quality gate evaluates completion without claiming unobserved platform results.

### Out of Scope

Encoding writer implementation owned by #619; new audit/grader engine, causal inference from PASS totals and editing historical reports.

### Blockers

T-001 integration, formal reviews and human approval. Actual platform evidence may require CI; #600 is not a blocker.

## T-003 Append the source-backed correction and #600 handoff

Source Issue: #601

Approval: Draft

Status: Planned

Risk: medium

Risk Rationale: Incorrect attribution or promotion language could turn incomplete evidence into a false claim.

Required Workflow: full

Requirements: REQ-001, REQ-004, REQ-005, REQ-007

Planned Files: docs/contributor/issue-601-structural-prevention.md; CHANGELOG.md; specs/structural-error-prevention/verification/T-003/ for new non-frozen evidence/handoff records

Data Migration: none

Breaking API: no

### Goal

Finish one readable enforcement/cause map and three-case #600 delivery without duplicating rules or claiming retention results.

### Must Read

- requirements.md, design.md#evidence-and-handoff and #duplicate-validator-assessment, acceptance-tests.md, traceability.md and all four layer specifications.
- Existing contributor map, tests/golden/README.md, existing why-why/Horizon/Retention/Meta-Change conventions, and actual duplicate-parser/approval consumers cited by the map.

### Scope

Reverify current duplicate-validator consumers and policy boundaries under design.md#shared-state-reverification. Append a dated current-tree correction and result links after T-001/T-002 evidence is available; retain the historical preparation text. Document #619 corrected runtime facts and unknown historical origin, #620 process/findings separation, and the two bounded deduplication candidates with consumer policy boundaries. Deliver C1/C2/C3 case pairs and grader mutations in the existing contributor handoff, using #600's golden conventions without creating a model runner or claiming held-out execution. Synchronize CHANGELOG for the actual registration/coverage changes; no public API or product skill text changes are expected.

### Done When

- [ ] TEST-001a, TEST-001b, TEST-001c, TEST-005a, TEST-005b, TEST-005c, TEST-005d, TEST-005e, TEST-005f, TEST-005g, TEST-005h, TEST-005i, TEST-005j, TEST-006a, TEST-006b, TEST-006c, TEST-006d, TEST-006e, TEST-006f, TEST-006g, TEST-006h, TEST-006i, TEST-006j, TEST-006k, TEST-006l, TEST-006m, TEST-008a, TEST-008b, TEST-008c, TEST-008d, TEST-009a, TEST-009b, TEST-009c, TEST-009d, TEST-009e establish exact three-class coverage, truthful corrections and preserved consumer boundaries.
- [ ] #600 handoff identifies sources, negatives/controls, expected artifact/tool traces and grader mutations; delivery is complete while #600 integration/behavior results remain pending.
- [ ] Retention is explicitly Not evaluated until subsequent observations under the existing Horizon/Retention process; cause unknown remains allowed and Meta-Change review authority unchanged.
- [ ] Implementation report and verification addendum record task-to-requirement evidence; independent quality gate evaluates completion. No frozen document body is rewritten to finalize status.

### Out of Scope

Validator extraction/deletion, duplicated SKILL.md rules, new state/schema, independent held-out runs, approval/measurement policy changes and retention success claims.

### Blockers

Formal reviews and human approval; final evidence links depend on T-001/T-002. #600 acceptance of the handoff and future retention observations are external follow-up, not prerequisites for deterministic #601 completion.
