# Task Review Report: epic-191-a3-path-ownership — Round 1 / Attempt 1

## Verdict: NEEDS_WORK

| Field | Value |
|---|---|
| Feature | epic-191-a3-path-ownership |
| Round | 1 of 3 |
| Attempt | 1 |
| Reviewer-A Verdict | PASS |
| Reviewer-B Verdict | NEEDS_WORK |
| Critical Findings | 0 |
| Major Findings | 1 |
| Minor Findings | 0 |
| Generated | 2026-07-22T00:36:41Z |

## Reviewer-A Findings (Structural Coverage)

All 14 checks PASS, 0 findings. No structural coverage defects.

## Reviewer-B Findings (Quality/Risk)

- **TASK-SIZE (Major)**: T-001's Done When list has 12 distinct verifiable
  bullet items and its Scope spans 5 distinct implementation areas
  (glob-compiler+classification resolver core; the test suite; the base
  fixture tree; ADR-0025 authorship; tests/run-all + human-copy/test.yml CI
  registration) — both indicators this check names for oversizing. T-004's
  Done When list is larger still at 14 items and spans 6 distinct areas
  (three-state Gate logic + six Fail conditions; the `--diagnose`
  subcommand; direct risk-gate-matrix.md/SKILL.md edits; Bundle A human-copy
  staging of six protected files; Bundle B human-copy staging of three
  protected files; tests/run-all registration). T-002 similarly carries 11
  Done-When items, exceeding the eight-item indicator.

## Proposed Changes

Consolidate the Done-When checklists of T-001, T-002, and T-004 by grouping
closely-related verification bullets into fewer compound items (same
verification content, fewer list entries), without splitting any task's
identity or file ownership — design.md's own Technical Summary, API/Contract
Plan section headers, and Global Constraints ("T-004 is the sole editor")
explicitly anchor exactly six deliverables to T-001..T-006, so no task is
split or renumbered as part of this remedy.

## Next Steps

Edit `specs/epic-191-a3-path-ownership/tasks.md` to consolidate T-001,
T-002, and T-004's Done When lists, then re-invoke task-review-loop for
round 2 with an `--edit-summary` describing the consolidation.
