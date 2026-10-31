# Specification Review Report: epic-190-a2-capability-registry

- Attempt: 1
- Round: 3 (final round under this attempt's round cap)
- Input hashes: requirements `925d139290a9ea2b4b042068eb9b438505063875fff663681b56584ae67c3112`, acceptance tests `13f6ec1f63fa86424a80ab5cde151c2f8b5afc31b5b57d90956ed9aa0df8c85c`
- Reviewer A: run `RUN-epic-190-a2-capability-registry-spec-spec-reviewer-a-seq0324`, host session `SESS-spec-spec-reviewer-a-epic-190-a2-capability-registry-0324`
- Reviewer B: run `RUN-epic-190-a2-capability-registry-spec-spec-reviewer-b-seq0325`, host session `SESS-spec-spec-reviewer-b-epic-190-a2-capability-registry-0325`
- Verdict: `BLOCKED`
- Warning count: `0`
- Finding counts: Critical 0 / Major 1 / Minor 0

## Integrated Summary

| Reviewer | Check | Result | Severity |
|---|---|---|---|
| A | REQ-TESTABILITY | PASS | Critical |
| A | GOAL-AC-TRACE | PASS | Major |
| A | AC-OBSERVABLE | PASS | Major |
| A | SCOPE-BOUNDARY | PASS | Major |
| A | CONSTRAINTS-EXPLICIT | PASS | Major |
| A | RISK-VALIDATION-SURFACE | PASS | Major |
| B | AMBIGUITY | PASS | Major |
| B | CONTRADICTION | PASS | Critical |
| B | EDGE-CASE-COVERAGE | FAIL | Major |
| B | ASSUMPTIONS-RESOLVABLE | PASS | Major |
| B | APPROVAL-BOUNDARY | PASS | Critical |
| B | DOWNSTREAM-READINESS | PASS | Major |

Reviewer A passed all six checks and confirmed both round-1 and round-2
findings are resolved. Reviewer B independently confirmed the same, and
found no ambiguity, contradiction, or downstream-readiness gap remaining —
but found one new Major EDGE-CASE-COVERAGE gap: REQ-004 states the
`registry_digest` generator's fragment-selection input requires "at least
one" of `--capability-ids`/`--gate-ids`/`--whole`, but `acceptance-tests.md`
has no AC/TEST row naming the expected behavior when no selector flag is
supplied, nor a fixture combining `--capability-ids` and `--gate-ids`
together (the explicitly permitted "or both" case).

Per the state-transition table, round 3 with any Critical/Major FAIL
produces `BLOCKED` (not `NEEDS_WORK`) — this attempt has exhausted its
3-round cap. `Spec-Review-Status` remains `Pending`.

## Transition

`Spec-Review-Status` remains `Pending`. This attempt (attempt 1) is
terminal at `BLOCKED`. The only permitted next step under this SKILL is
`--reset` to start attempt 2, round 1, once the remaining finding is fixed
and committed; `--reset` preserves this attempt's evidence. The proposed fix
is recorded in `spec-round-3-proposed-changes.md`. The orchestrator is
stopping here to report this outcome rather than unilaterally opening a new
attempt.
