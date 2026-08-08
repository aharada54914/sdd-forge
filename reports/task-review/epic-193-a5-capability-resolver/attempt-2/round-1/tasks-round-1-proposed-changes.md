# Task Review Report: epic-193-a5-capability-resolver — Round 1 / Attempt 2

## Verdict: NEEDS_WORK

| Field | Value |
|---|---|
| Feature | epic-193-a5-capability-resolver |
| Round | 1 of 3 |
| Attempt | 2 |
| Reviewer-A Verdict | PASS |
| Reviewer-B Verdict | NEEDS_WORK |
| Critical Findings | 0 |
| Major Findings | 1 |
| Minor Findings | 0 |
| Generated | see task-review-contract.json `timestamp` |

## Reviewer-A Findings (Structural Coverage)

14/14 checks PASS. `findings: []`. No issues.

## Reviewer-B Findings (Quality/Risk)

8/9 checks PASS, 1 SKIP (BUGFIX-DIAGNOSTIC-PATH — no bugfix/debugging task
in scope), 1 FAIL:

- **TASK-SIZE (Major, T-004)**: T-004's own title ("...track-branch and
  Evidence-assembly stage (steps 10-13), and its `match` suite")
  explicitly joins two deliverables with "and," matching this check's own
  multi-phase-title indicator. T-004's combined scope bundles (a) four
  production sub-steps (10a/10b track branch, 11 Evidence assembly, 12
  output-schema self-validation with its own B3 exception case, 13 TOCTOU
  pre-publication recheck), (b) an entirely new `resolve-project-context-
  match` suite spanning 11 TEST IDs (TEST-003/004/005/006/007/008/016/
  043/044/052/056) covering 12 acceptance criteria (AC-003 through
  AC-008, AC-016, AC-043, AC-044, AC-052, AC-056), (c) 3 more block-suite
  fixtures, and (d) new suite/CI registration — materially larger than
  any sibling task (T-002/T-003 each own only 5 block fixtures; T-001/
  T-005/T-007/T-008 each author only 4 tests).

Both of round-3's other two findings (SCOPE-DISJOINT, DEPENDENCY-OVERLAP)
are independently re-verified clean PASS this round: reviewer-b confirmed
the shared-file chains (block-suite file across T-002/T-003/T-004/T-006,
`resolve-project-context.{py,sh,ps1}` across the same four, and the
seven-task CI-registration chain) each carry a direct Blockers edge for
every consecutive pair, with no uncoordinated overlap.

## Proposed Changes

Isolate the `match` suite out of T-004 into its own downstream task
blocked by T-004 — the identical by-first-reachable-step mechanism
already used successfully to split the block-suite fixtures across
T-002/T-003/T-004/T-006. T-004 itself keeps only its own production code
(steps 10-13) and its own 3 block-suite fixtures, remaining independently
TDD-verified without the `match` suite. A new task (numbered immediately
after T-004; every task from the former "cli/discovery/lite" task onward
renumbers up by one) owns the `resolve-project-context-match` suite,
registers it in the fixed CI-registration order (appending directly
after T-002's own staged candidate, since neither T-003 nor T-004 touches
that shared file), and is Blocked by T-004 (needs the complete,
schema-self-validated engine to run full-pipeline subprocess fixtures)
and by T-002 (the immediately preceding CI-registering task, since T-003/
T-004 do not touch the shared registration file). Every downstream task's
Blockers/Depends-On text is updated to a direct edge to its new correct
predecessor, both functionally and for CI-registration ordering, and
`traceability.md` is fully re-derived. No requirement, acceptance
criterion, or test suite is dropped, added, or renamed.

## Next Steps

Apply the remedy above to `specs/epic-193-a5-capability-resolver/
tasks.md` and re-derive `traceability.md`, verify green (`check-
workflow-state.sh`, `validate-layer-traceability.py`, `check-risk.sh`),
commit, then re-invoke the task-review-loop for round 2 with
`--edit-summary` describing the change.
