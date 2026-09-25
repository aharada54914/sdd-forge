# Task Review Report: epic-193-a5-capability-resolver — Round 2 / Attempt 1

## Verdict: NEEDS_WORK

| Field | Value |
|---|---|
| Feature | epic-193-a5-capability-resolver |
| Round | 2 of 3 |
| Attempt | 1 |
| Reviewer-A Verdict | PASS |
| Reviewer-B Verdict | NEEDS_WORK |
| Critical Findings | 0 |
| Major Findings | 2 |
| Minor Findings | 0 |
| Generated | 2026-07-22T12:40:00Z |

## Reviewer-A Findings (Structural Coverage)

None — 14/14 checks PASS, `findings: []`.

## Reviewer-B Findings (Quality/Risk)

- **TASK-SIZE** (Major, `T-002`): the round-1 remedy only reduced the
  count of test suites bundled into T-002 (five to two); the entire
  12+-stage core evaluation engine (argument validation through the
  pre-publication snapshot recheck) remains completely undivided, still
  bundled with authoring two full TDD suites in the same task
  (`resolve-project-context-match` and the twelve-fixture
  `resolve-project-context-block`), roughly twenty TEST-ids to author
  Red-then-Green. Recommends a further split isolating the core engine
  from the match/block suites, or at minimum isolating the twelve-fixture
  block suite into its own task.
- **DEPENDENCY-OVERLAP** (Major, `T-005`/`T-007`): T-005's own Blockers
  field (`T-001, T-004`) and T-007's own Blockers field
  (`T-002, T-004, T-005`) each omit T-003, despite each genuinely
  depending on T-003 having already landed — T-005's own Scope text
  says its CI-registration step is "appended after T-003's own," and
  T-007's own Done When requires "every one of the nine suites
  T-001..T-007 build" (including T-003's own cli/discovery/lite suites)
  to exist. T-006's Blockers field correctly includes T-003, confirming
  the dependency is real; T-005/T-007 are inconsistent with T-006's own
  correct pattern.

## Proposed Changes

1. **Split T-002 once more, taking reviewer-b's own stated minimum-
   sufficient option** ("at minimum isolating the twelve-fixture block
   suite into its own task") rather than the more aggressive alternative
   (isolating both suites) — the minimum option is chosen deliberately:
   removing the `resolve-project-context-match` suite from T-002 as well
   would leave T-002 with no test suite of its own, which would
   conflict with its own `Required Workflow: tdd` (RED-before-GREEN
   evidence must exist within the task that carries `tdd`) and likely
   trade TASK-SIZE for a new HIGH-CRITICAL-EVIDENCE finding at round 3,
   the final round. Concretely:
   - **T-002 (narrowed)**: the core evaluation engine (steps 0-13) plus
     the `resolve-project-context-match` suite only (its own RED→GREEN
     TDD evidence) — the twelve-fixture non-transactional Block suite
     moves out.
   - **T-003 (new)**: "Author `resolve-project-context`'s non-
     transactional Block-diagnostic test suite" — the twelve-fixture
     `resolve-project-context-block` (non-transactional REQ-002 rows),
     exercising T-002's already-authored engine. `Risk: medium` /
     `Required Workflow: acceptance-first` (a test-only task adding no
     new production code path, matching T-003's/T-004's own precedent
     from round 1's remedy).
   - Every task from round 2's own T-003 onward renumbers up by one:
     T-003→T-004 (CLI/discovery/lite), T-004→T-005 (transactional —
     which now appends its own four fixtures to the NEW T-003's block
     suite file, not T-002's, and gains T-003 as an additional Blockers
     entry for exactly that reason), T-005→T-006 (validator),
     T-006→T-007 (parity — gains the new T-003 as an additional
     Blockers entry, since design.md Test Strategy item 5 requires
     parity coverage across every fixture from suites 1-4, which
     includes the block suite), T-007→T-008 (metamorphic, unchanged
     dependency targets, renumbered only).
2. **Re-derive the full Blockers/transitive-closure graph from scratch
   for all eight tasks** rather than patching only the two tasks
   reviewer-b named — the renumbering itself is a fresh opportunity to
   introduce the identical class of gap, and reviewer-b's own finding
   was specifically that a prior "patch two things and move on" pass
   left an inconsistent pattern (T-006 correct, T-005/T-007 not).

## Next Steps

Apply the further split and the corrected Blockers graph to
`tasks.md`/`traceability.md`, re-run `task-review-precheck.sh` for round
3 (the final round under the SKILL's own three-round limit — a clean
result reaches `Task-Review-Status: Passed`; any remaining Critical or
Major finding at round 3 reaches `BLOCKED`, requiring `--reset` for a new
attempt), and re-invoke both reviewers fresh.
