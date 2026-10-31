# Specification Review Report: epic-193-a5-capability-resolver

- Attempt: 1
- Round: 2
- Edit summary: Remedy round-1 findings: fixed REQ-006 arithmetic contradiction (eleven->ten, matching design.md's 10-item Test Strategy and acceptance-tests.md's ten-suites text); reworded REQ-002 project-context-validation-failed to specify this feature's own JSON-Schema-conformance check against contracts/project-context.schema.json rather than an unreachable Epic A1 CLI; added a closed diagnostics[] severity block/warn cardinality rule (REQ-004); fixed AC-012 and added AC-055/AC-056 to close the EDGE-CASE-COVERAGE and AMBIGUITY findings.
- Input hashes: requirements `d5343f2f74181021daf7de3c0501ffaf95a9948f33688f10e94d0996b9c8e7c5`, acceptance tests `f8537d190ed9885dd2c8eef161f10f48fbacfc5a34e97e38b12a34ad9c5150a6`
- Reviewer A: run `RUN-epic-193-a5-capability-resolver-spec-spec-reviewer-a-seq0322`, host session `SESS-spec-spec-reviewer-a-epic-193-a5-capability-resolver-0322`
- Reviewer B: run `RUN-epic-193-a5-capability-resolver-spec-spec-reviewer-b-seq0323`, host session `SESS-spec-spec-reviewer-b-epic-193-a5-capability-resolver-0323`
- Verdict: `NEEDS_WORK`
- Warning count: `0`

## Integrated Summary

Reviewer A (checks REQ-TESTABILITY, GOAL-AC-TRACE, AC-OBSERVABLE, SCOPE-BOUNDARY,
CONSTRAINTS-EXPLICIT, RISK-VALIDATION-SURFACE): 5/6 PASS, 1 FAIL.

Reviewer B (checks AMBIGUITY, CONTRADICTION, EDGE-CASE-COVERAGE,
ASSUMPTIONS-RESOLVABLE, APPROVAL-BOUNDARY, DOWNSTREAM-READINESS): 5/6 PASS,
1 FAIL.

Finding counts (both reviewers combined): 0 Critical, 2 Major, 0 Minor.

All four round-1 findings (1 Critical CONTRADICTION, 3 Major: AMBIGUITY,
EDGE-CASE-COVERAGE, DOWNSTREAM-READINESS) are confirmed resolved by both
independent reviewers. Round 2 surfaced two new, narrower Major findings:

- GOAL-AC-TRACE (Major, reviewer A): the round-1 remedy added AC-055/AC-056
  to acceptance-tests.md's own table but did not mirror them into
  requirements.md's own separate "Acceptance Criteria" table (which stops
  at AC-054), breaking the documented 1:1 AC-numbering contract between the
  two files outside its one recorded exception class.
- CONTRADICTION (Major, reviewer B): requirements.md's own AC-010 row
  states "no other condition produces a non-zero exit" beyond the sixteen
  REQ-002 Block rows, but the same table's AC-013 row confirms a CLI usage
  error (AC-001) also produces a non-zero exit (2) — a wording defect
  internal to requirements.md's own Acceptance Criteria table (not present
  in acceptance-tests.md's parallel TEST-010 description).

Round 2 < round 3, so despite two Major findings, the merged verdict is
`NEEDS_WORK`, not `BLOCKED`.

## Transition

The orchestrator records the validated contract and is the sole writer of
`Spec-Review-Status`. `Spec-Review-Status` remains `Pending`. Remedy is
required against the 2 failed checks above before round 3 may run with
`--edit-summary`.
