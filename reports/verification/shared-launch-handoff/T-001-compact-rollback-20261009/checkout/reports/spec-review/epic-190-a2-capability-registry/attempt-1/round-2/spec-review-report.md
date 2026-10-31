# Specification Review Report: epic-190-a2-capability-registry

- Attempt: 1
- Round: 2
- Input hashes: requirements `abdc2d073b7f491da5b5efcb4da251145978095169f1360804da0c165062bd16`, acceptance tests `ff4874720b1c145321e422ac8f0dbe75c2a93f30964e99002a3a2182ba9011ac`
- Reviewer A: run `RUN-epic-190-a2-capability-registry-spec-spec-reviewer-a-seq0322`, host session `SESS-spec-spec-reviewer-a-epic-190-a2-capability-registry-0322`
- Reviewer B: run `RUN-epic-190-a2-capability-registry-spec-spec-reviewer-b-seq0323`, host session `SESS-spec-spec-reviewer-b-epic-190-a2-capability-registry-0323`
- Verdict: `NEEDS_WORK`
- Warning count: `0`
- Finding counts: Critical 0 / Major 3 / Minor 0

## Integrated Summary

| Reviewer | Check | Result | Severity |
|---|---|---|---|
| A | REQ-TESTABILITY | PASS | Critical |
| A | GOAL-AC-TRACE | PASS | Major |
| A | AC-OBSERVABLE | PASS | Major |
| A | SCOPE-BOUNDARY | PASS | Major |
| A | CONSTRAINTS-EXPLICIT | PASS | Major |
| A | RISK-VALIDATION-SURFACE | PASS | Major |
| B | AMBIGUITY | FAIL | Major |
| B | CONTRADICTION | PASS | Critical |
| B | EDGE-CASE-COVERAGE | FAIL | Major |
| B | ASSUMPTIONS-RESOLVABLE | PASS | Major |
| B | APPROVAL-BOUNDARY | PASS | Critical |
| B | DOWNSTREAM-READINESS | FAIL | Major |

Reviewer A passed all six checks and confirmed round 1's `minimum_enforcement`
contradiction and `required_facets`/`conditional_facets[]` ambiguity are both
resolved. Reviewer B independently confirmed the same two round-1 fixes (both
now PASS: CONTRADICTION, and no residual ambiguity on those two fields) but
found two new Major gaps of the same category, not raised in round 1:
`review_check_ids` (a required `capabilities[]` field) has no stated type/
shape anywhere, and `capabilities[].id` uniqueness is never required or
tested (only `gates[].id` uniqueness is, via AC-014/TEST-014).
DOWNSTREAM-READINESS FAILs as a direct consequence. `finding_counts`
(critical: 0, major: 3, minor: 0) drives the round-2 `NEEDS_WORK` verdict
per the state-transition table.

## Transition

`Spec-Review-Status` remains `Pending`. The proposed changes are recorded in
`spec-round-2-proposed-changes.md`. A third and final round requires
`--edit-summary` identifying the fix; per the state-transition table, round 3
produces `PASS` (with `warningCount` set to any Minor count) or `BLOCKED` if a
Critical/Major finding remains.
