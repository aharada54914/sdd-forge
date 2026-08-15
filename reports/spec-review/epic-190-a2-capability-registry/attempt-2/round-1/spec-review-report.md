# Specification Review Report: epic-190-a2-capability-registry

- Attempt: 2 (reset after attempt 1 BLOCKED at round 3)
- Round: 1
- Input hashes: requirements `704313265ee92a7eb81f842dc967ef9452ff52a34c3a8ff7b43f81a748d8be78`, acceptance tests `ce543ba950a65466f9c2a016929ee64e688d340612015f49361e41868418eeee`
- Reviewer A: run `RUN-epic-190-a2-capability-registry-spec-spec-reviewer-a-seq0326`, host session `SESS-spec-spec-reviewer-a-epic-190-a2-capability-registry-0326`
- Reviewer B: run `RUN-epic-190-a2-capability-registry-spec-spec-reviewer-b-seq0327`, host session `SESS-spec-spec-reviewer-b-epic-190-a2-capability-registry-0327`
- Verdict: `NEEDS_WORK`
- Warning count: `0`
- Finding counts: Critical 0 / Major 2 / Minor 0

## Integrated Summary

| Reviewer | Check | Result | Severity |
|---|---|---|---|
| A | REQ-TESTABILITY | PASS | Critical |
| A | GOAL-AC-TRACE | PASS | Major |
| A | AC-OBSERVABLE | PASS | Major |
| A | SCOPE-BOUNDARY | PASS | Major |
| A | CONSTRAINTS-EXPLICIT | PASS | Major |
| A | RISK-VALIDATION-SURFACE | FAIL | Major |
| B | AMBIGUITY | PASS | Major |
| B | CONTRADICTION | PASS | Critical |
| B | EDGE-CASE-COVERAGE | FAIL | Major |
| B | ASSUMPTIONS-RESOLVABLE | PASS | Major |
| B | APPROVAL-BOUNDARY | PASS | Critical |
| B | DOWNSTREAM-READINESS | PASS | Major |

Both reviewers independently converged on the same underlying gap from
different checks: REQ-002 states that every operator forbidden by ADR-0020
(regex, arbitrary JSONPath, shell, JS, Python, dynamic code, Provider API
calls, time-/network-dependent conditions) "must be structurally
inexpressible in the DSL's own grammar, not merely undocumented," but no
AC/TEST in acceptance-tests.md's evaluate-predicate suite (TEST-007..013)
asserts that an out-of-grammar/forbidden operator token is rejected. All
other REQ-002 checks (round 1/2's fixed contradiction and ambiguity
notwithstanding) pass cleanly, and no attempt-1 finding recurred.

## Transition

`Spec-Review-Status` remains `Pending`. The proposed change is recorded in
`spec-round-1-proposed-changes.md`. A new round requires `--edit-summary`
identifying the fix.
