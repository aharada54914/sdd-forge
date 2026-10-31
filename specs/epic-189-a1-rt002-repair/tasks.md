# Tasks: A1 RT002 bounded repair

Task-Review-Status: Passed

Authorized amendment (2026-09-28, limited extra1): exact two-envelope contract adopted for formal re-review. Existing review/status/approval lines remain historical, not a PASS of these changed bytes. No implementation, execution proof, task-attempt reset or correction-budget reset. Governing dated precedence: [amendment addendum](verification/T-001/two-envelope-extra1-20260928/candidate-precedence-20260928.md).

## Lifecycle

Draft → Approved → In Progress → Implementation Complete → Done. Only a human changes Approval; only quality-gate sets Done. Historical A1 T-008 and failed review attempts remain unchanged.

Task-size amendment proposal (2026-09-29): attempt 2 round 1 returned NEEDS_WORK (TASK-SIZE, Major). Human adoption of this two-task split is required before round 2. The existing T-001 Approval/Status and Task-Review-Status lines are retained as historical lifecycle records; they do not certify this amended plan. T-002 remains Draft/Planned. No budget, attempt or verdict is reset. This paragraph supersedes only the old single-task ownership statements in the dated candidate addendum.

## T-001 Repair the shared verifier and prove installed activation

Source Issue: https://github.com/aharada54914/sdd-forge/issues/189

Approval: Approved

Status: Implementation Complete

Risk: high

Risk Rationale: Evidence acceptance controls permission to resume ordinary agent execution; false acceptance crosses an access-control boundary. The original high tier is unchanged.

Required Workflow: tdd

Requirements: REQ-001, REQ-002, REQ-003, REQ-004, AC-001, AC-002, AC-003, AC-004, AC-005

Prerequisites: AC-001, AC-002, AC-003, AC-004, AC-005, AC-006

Dependencies: None

Planned Files: plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py; tests/check-hook-activation-handshake.tests.sh; tests/check-hook-activation-handshake.tests.ps1; reports/implementation/epic-189-a1-rt002-repair-T-001.md; specs/epic-189-a1-rt002-repair/verification/T-001/; specs/epic-189-a1-rt002-repair/verification/T-001-results.md

Data Migration: None

Breaking API: None; additive selector, intentional duplicate-member rejection and exactly one additional bare-envelope form only.

### Goal

Complete the authorized three-file repair and its installed-activation proof. T-001 supplies the exact reviewed candidate and TEST-089 evidence consumed by T-002; it does not claim final REQ-005/AC-006 acceptance or release completion. One bounded PR, no second verifier or new CI lane.

### Must Read

- specs/epic-189-a1-rt002-repair/requirements.md
- specs/epic-189-a1-rt002-repair/design.md
- specs/epic-189-a1-rt002-repair/acceptance-tests.md
- specs/epic-189-a1-rt002-repair/traceability.md
- specs/epic-189-a1-rt002-repair/ux-spec.md
- specs/epic-189-a1-rt002-repair/frontend-spec.md
- specs/epic-189-a1-rt002-repair/infra-spec.md
- specs/epic-189-a1-rt002-repair/security-spec.md
- docs/review-tickets/RT-20260909-002.yml
- reports/verification/hook-recovery-entry-contract-20260909.md
- specs/epic-189-a1-rt002-repair/verification/T-001/two-envelope-extra1-20260928/candidate-precedence-20260928.md (adopted two-envelope precedence; historical generation state is not current review evidence)

### Scope

1. Recheck current main, the three-file delta and source hashes; preserve unrelated dirty changes. Before new production changes record WFI-001 field/counterpart/failing-mismatch preflight, actual reproduction, failing call path, root cause and affected callers.
2. Reuse the original wrappers, shared verifier and existing fixture helpers. Add both-shell TEST-079/080 cleanup-schema independence, TEST-084/085 complete unchanged Claude/Copilot templates, TEST-090/091 exact envelope positives and TEST-092–097 malformed-wrapper negatives. Preserve TEST-001–078/081–083/086 and the entire both-envelope negative matrix; no sampling, mock verifier or removed check.
3. Commit the focused failing regression before the minimum shared-predicate fix: exact optional P, whole-string fullmatch and one nonce capture. Unknown host/tool/nonce, executed true, missing/wrong types, duplicates and added bytes remain refusals. Already-correct paths use the same committed regression against the genuine pre-repair differential baseline for RED, then the candidate for GREEN; record source commits, original-path commands and exits. Mutation-only failures are sensitivity checks, not required RED. Without a genuine failing baseline remain Blocked.
4. Prepare a hash-pinned permitted application/restoration batch only where protected application requires it. Repair-specific provenance reviews alone may use recovery item 4; ordinary implementation/quality-gate still require fresh actual installed activation. A refused operation is never rerouted. Apply only through the permitted maintainer path, record backup/prior hash and restoration command, test restoration/refusal behavior in isolation, and retain the real backup. Fresh nonce, one actual native dispatch, unchanged response and installed verifier HOOK_ACTIVE must prove TEST-089.
5. Run both full original-path local suites and obtain independent quality-gate verification of this exact candidate after activation. Record results in non-frozen T-001 evidence. Native Windows/latest-head CI, merge, post-merge checks and final acceptance belong to dependent T-002, not this task's completion.

### Done When

- [ ] REQ-001–004/AC-001–005 and TEST-001–086/090–097 have branch-specific original-path evidence; TEST-079/080/084/085/090–097 exist in both suites, the full both-envelope negative matrix remains refusing, all legacy checks remain, and both full local suites pass.
- [ ] The high-risk preflight and reproduction/root-cause/caller diagnosis precede production changes. Committed regression-before-fix and genuine pre-fix/differential-baseline RED plus candidate GREEN have source commits, original-path commands and exits; already-correct code or mutation-only failures are not historical TDD. Missing RED blocks completion.
- [ ] TEST-089 records installed candidate path/version/hash, fresh nonce, one actual native dispatch, unchanged response and installed verifier HOOK_ACTIVE. No stale capture or fixture substitutes. This supplies T-002's live prerequisite, not final AC-006 acceptance.
- [ ] For the currently installed candidate SHA-256 `1057d1fcd1a8307c1fe55b961f3b37af2576683887f1c4ec2ce5138065e8fe0d`, verify the current-hash-pinned permitted restoration procedure, the retained maintainer-owned backup with prior SHA-256 `bb388dfba366a9f300f1c0060fa6282468d7a896dc7e72986f3bf3452f08c3d5`, and successful isolated restoration/refusal tests. Failed activation follows Rollback and remains unavailable. Human-authorized limited amendment (2026-10-02): this condition does not claim that the restoration command was recorded before the historical application; that chronology remains unverified. Future applications retain the advance backup/restoration preparation requirement in Scope 4 and Rollback. Historical verdicts remain unchanged; this amendment requires independent re-review.
- [ ] The implementation report carries Run ID and Task Attempt Count; provenance has current spec_revision/environment; required high-risk checks, task-scoped traceability/component coverage and the exact candidate handoff hashes are recorded in verification/T-001-results.md.
- [ ] Independent quality-gate PASS for T-001 carries canonical identity/count fields; only that gate sets Done. T-002's unresolved release conditions are explicitly pending, not waived by this PASS.

### Out of Scope

Native Windows/latest-head CI, release/merge/post-merge confirmation (T-002); A1/A8/A9 completion; guard/parser redesign; authentication/replay services; new workflows/dependencies; approval/CI bypass beyond the user's review-approval exception; historical verdict changes.

### Rollback

Owner: maintainer. Follow infra-spec.md §Rollback: preserve and hash the prior installed backup before application; if validation or activation fails stop ordinary execution and restore only through the same permitted application path. Record restored hash and refusal behavior. No guard disabling, automatic cache rewrite or claim that restoration completes RT002.

### Blockers

None

### Execution Preconditions

- Human adoption/re-approval of the amended body, passed task re-review and confirmed unchanged high risk; the retained historical approval alone is not a new plan approval.
- Fresh installed-candidate activation before ordinary execution/quality-gate; refused protected application remains human-only.
- No native Windows, integration, final acceptance or quality-gate success is assumed.

## T-002 Verify and integrate the exact T-001 candidate

Source Issue: https://github.com/aharada54914/sdd-forge/issues/189

Approval: Draft

Status: Planned

Risk: medium

Risk Rationale: Verification and release coordination only; no verifier, protected artifact, test, workflow or authorization behavior is changed. T-001 retains all high-risk production checks; this task cannot downgrade or waive them.

Required Workflow: acceptance-first

Requirements: REQ-005, AC-006

Prerequisites: AC-006

Dependencies: T-001

Planned Files: reports/implementation/epic-189-a1-rt002-repair-T-002.md; specs/epic-189-a1-rt002-repair/verification/T-002/; specs/epic-189-a1-rt002-repair/verification/T-002-results.md

Data Migration: None

Breaking API: None

### Goal

Consume T-001's immutable candidate/hash/activation/quality evidence, prove existing native Windows and latest-head mandatory CI, safely integrate that exact repair and verify post-merge CI. Own final REQ-005/AC-006 acceptance without new source or test changes.

### Must Read

- The same feature requirements, design, acceptance tests, traceability and all four layer specifications listed for T-001.
- docs/review-tickets/RT-20260909-002.yml
- reports/implementation/epic-189-a1-rt002-repair-T-001.md
- specs/epic-189-a1-rt002-repair/verification/T-001-results.md
- T-001's canonical independent quality-gate report and exact source/installed hash handoff.

### Scope

1. Before executing release acceptance, record the existing TEST-087–089 checks/commands, exact candidate head and T-001 prerequisite evidence. T-001 must be Done with fresh actual activation and both full local suites; a report, fixture or older success cannot substitute.
2. Run the existing native Windows checks and every required latest-head CI check, correlate run/head identities and diagnose any failure. No new lane, dependency, source/test/workflow change or check relaxation is authorized by this task. A source fix invalidates this exact-candidate handoff and returns to T-001's approved correction boundary without resetting its budget.
3. Review current-main ancestry, conflicts, findings and mandatory checks before safe pinned-head merge. Only the separately authorized approval-count exception may apply; latest-main/CI rules remain. Verify merged bytes and the actual post-merge run; failed integration remains incomplete.
4. Aggregate all REQ-001–005, AC-001–006 and TEST-001–097 evidence, preserving historical failures and frozen documents. T-002 owns final REQ-005/AC-006 acceptance; T-001's TEST-089 is supporting prerequisite evidence, not duplicated acceptance ownership. Obtain independent task-scoped quality verification after integration.

### Done When

- [ ] T-001's exact candidate hashes, installed TEST-089 activation, full local suites and independent quality-gate PASS are verified; TEST-087 review evidence and the acceptance checks were recorded before release execution.
- [ ] TEST-088 has real native Windows and all mandatory CI successes for the latest candidate head; no old head, skipped, queued or unobserved check is a success.
- [ ] The reviewed exact repair is safely merged after current-main/conflict/approval checks, merged bytes are verified, and the actual related post-merge CI succeeds.
- [ ] verification/T-002-results.md maps all REQ-001–005/AC-001–006 to TEST-001–097 and real evidence. Frozen specification/traceability and parent history remain unchanged; parent ticket/Issue closes only if its own exit conditions are satisfied.
- [ ] The implementation report carries Run ID and Task Attempt Count and current provenance; independent quality-gate PASS has canonical identity/count fields. Only that gate sets T-002 Done.

### Out of Scope

New implementation, test/workflow edits, protected installation changes, authorization exceptions, new features, historical PASS rewriting, correction-budget reset, or claiming broader A1/A8/A9 completion.

### Rollback

Owner: maintainer. If pre-merge checks fail do not merge. If post-merge checks fail preserve the actual failure and keep this task incomplete; diagnose within the original correction authority and use the repository's permitted reviewed revert/fix process, never disable checks. T-001's installed rollback remains its maintainer-owned procedure.

### Blockers

T-001

### Execution Preconditions

- Passed amended task review and explicit human approval of this new Draft task.
- T-001 Done; candidate/head/installed hashes still match at consumption.
- Existing native Windows/latest-head/post-merge checks remain mandatory.

## Preservation of the original nine Done When obligations

This allocation changes execution ownership, not acceptance strength. No requirement, branch, historical failure, attempt, approval boundary or risk check is deleted.

| Original T-001 item | New owner / evidence |
|---|---|
| 1: all requirements, ACs and 97 tests | T-001 Done When 1 supplies functional evidence; T-002 Done When 4 owns complete final mapping |
| 2: original assertions, both envelopes, full local and native Windows | T-001 Done When 1 preserves every original-suite branch/full local run; T-002 Done When 2 proves native Windows |
| 3: high-risk preflight, diagnosis, committed RED/GREEN | T-001 Done When 2, unchanged genuine-baseline rule |
| 4: fresh installed actual activation | T-001 Done When 3; exact supporting evidence rechecked by T-002 Done When 1 |
| 5: report identity, provenance, risk, traceability/component checks | T-001 Done When 5 and T-002 Done When 5, each at its exact candidate/task scope |
| 6: independent quality-gate PASS / exclusive Done authority | T-001 Done When 6 and T-002 Done When 5 |
| 7: latest-head native Windows, reviewed merge and post-merge CI | T-002 Done When 2–3 |
| 8: maintainer backup, hash, restoration/refusal checks, failed activation rollback | T-001 Done When 4 and Rollback |
| 9: final addendum, frozen history, parent exit conditions | T-002 Done When 4 |
