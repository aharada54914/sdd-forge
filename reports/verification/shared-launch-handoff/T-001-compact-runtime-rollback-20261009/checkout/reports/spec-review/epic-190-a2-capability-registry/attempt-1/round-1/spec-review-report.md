# Specification Review Report: epic-190-a2-capability-registry

- Attempt: 1
- Round: 1
- Input hashes: requirements `4862e4d930af03159ff9e6eb550b0d37c60be2d5514bac8654b03382b731a0a0`, acceptance tests `0f2f2e8891d26e066d64fcf28e2a523f3acbe95401550d22d651e8c60e78a964`
- Reviewer A: run `RUN-epic-190-a2-capability-registry-spec-spec-reviewer-a-seq0320`, host session `SESS-spec-spec-reviewer-a-epic-190-a2-capability-registry-0320`
- Reviewer B: run `RUN-epic-190-a2-capability-registry-spec-spec-reviewer-b-seq0321`, host session `SESS-spec-spec-reviewer-b-epic-190-a2-capability-registry-0321`
- Verdict: `NEEDS_WORK`
- Warning count: `0`
- Finding counts: Critical 1 / Major 2 / Minor 0

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
| B | CONTRADICTION | FAIL | Critical |
| B | EDGE-CASE-COVERAGE | PASS | Major |
| B | ASSUMPTIONS-RESOLVABLE | PASS | Major |
| B | APPROVAL-BOUNDARY | PASS | Critical |
| B | DOWNSTREAM-READINESS | FAIL | Major |

Reviewer A passed all six Phase 1 readiness checks. Reviewer B independently
found one Critical and two Major gaps: (1) a same-document contradiction over
whether `minimum_enforcement` is a `capabilities[]` field (as REQ-001 states
twice) or a `gates[]` field (as AC-005/TEST-005 tests it); (2) the concrete
entry shape of `required_facets[]` and `conditional_facets[]` (beyond the
documented `.when` key) is never defined in any reviewed artifact; (3) as a
direct consequence of (1) and (2), the package is not yet ready to hand to
implementation-policy review without the design reviewer inventing missing
schema-shape decisions. `integrated-verdict.json`'s `finding_counts` (critical:
1, major: 2, minor: 0) drives the round-1 `NEEDS_WORK` verdict per the
state-transition table (any Critical/Major FAIL before round 3 yields
NEEDS_WORK).

## Transition

`Spec-Review-Status` remains `Pending`. The proposed changes are recorded in
`spec-round-1-proposed-changes.md`. A new round requires human/orchestrator
reviewed edits and `--edit-summary` identifying them.
