# Task Review Report: epic-193-a5-capability-resolver — Round 2 / Attempt 2

## Verdict: NEEDS_WORK

| Field | Value |
|---|---|
| Feature | epic-193-a5-capability-resolver |
| Round | 2 of 3 |
| Attempt | 2 |
| Reviewer-A Verdict | NEEDS_WORK |
| Reviewer-B Verdict | PASS |
| Critical Findings | 0 |
| Major Findings | 1 |
| Minor Findings | 0 |
| Generated | see task-review-contract.json `timestamp` |

## Reviewer-A Findings (Structural Coverage)

13/14 checks PASS. Round-1's TASK-SIZE remedy (T-005 split, ten-task
renumbering) confirmed to introduce no new structural defects:
PREREQ-AC-IDS, REQ-COVERAGE, AC-COVERAGE, DEPENDENCY-COMPLETE,
DEPENDENCY-CYCLE (23 edges, no cycle), TRACEABILITY-SYNC, and
SINGLE-CONCERN (T-004's new title) all clean. One FAIL:

- **OBSERVABLE-DONE (Major, T-003/T-004)**: T-003's Done When item 2
  ("Union-match and WARN evaluation logic implemented") and T-004's Done
  When item 2 ("Production logic complete and ready for downstream
  exercise") each assert internal implementation-correctness with no
  concrete test ID, command, or artifact of their own — verification is
  entirely deferred to T-005's future suite, so a quality-gate reviewer
  closing T-003 or T-004 has no observable check to run against this
  specific criterion, only the implementer's own unverified claim.
  Reviewer's own suggested remedy: (a) remove the item (its own TDD-
  evidence item already provides the task's own independently-checkable
  criterion), or (b) replace it with a concrete, task-local check.

## Reviewer-B Findings (Quality/Risk)

9/9 checks evaluated: 8 PASS, 1 SKIP (BUGFIX-DIAGNOSTIC-PATH — no
bugfix/debugging task in scope), `findings: []`. Reviewer-b's own
round-1 TASK-SIZE finding is confirmed resolved: T-004 (steps 10-13
only, 5 Done-When items) and T-005 (match suite only, 5 Done-When
items) are each independently sized in line with sibling tasks.
SCOPE-DISJOINT and DEPENDENCY-OVERLAP re-verified clean for both
shared-file chains (block-suite: T-002→T-003→T-004→T-007;
CI-registration: T-001→T-002→T-005→T-006→T-008→T-009→T-010) — every
consecutive pair confirmed to carry a direct Blockers edge.

## Proposed Changes

A single, minimal, non-structural remedy: remove the two flagged Done
When items (T-003's own item 2, "Union-match and WARN evaluation logic
implemented", and T-004's own item 2, "Production logic complete and
ready for downstream exercise") from `specs/epic-193-a5-capability-
resolver/tasks.md`. Neither item is replaced with a task-local check
(reviewer-a's own remedy option (a), not (b)) because each task's own
retained Done-When items (the Block-diagnostic matrix item plus the TDD
evidence item, both already present) already give T-003/T-004 their own
independently-checkable completion criteria — the removed item added no
verifiable content beyond a restatement of "the code is correct," which
is exactly what the TDD-evidence item (RED fixtures against a
deliberately broken implementation, GREEN against the correct one)
already establishes with a concrete, observable mechanism. No task
renumbering, no Blockers change, no new requirement/AC/test-suite
mapping — `traceability.md` is unaffected by this remedy and is not
re-derived.

## Next Steps

Remove the two flagged Done When bullets, verify green (`check-
workflow-state.sh`, `validate-layer-traceability.py`, `check-risk.sh`),
commit, then re-invoke the task-review-loop for round 3 (the final
round of this attempt) with `--edit-summary` describing the change.
