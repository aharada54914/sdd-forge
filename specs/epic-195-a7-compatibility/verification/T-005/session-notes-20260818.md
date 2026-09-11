# T-005 Independent Verification Session Notes (2026-08-18)

Run ID: `a7-t005-run-2026-08-17-01`

## Context

The three functions (`_loop_trace_emit`/`Write-LoopTraceEvent`,
`assert_capability_applicability`/`Test-CapabilityApplicability`,
`assert_event_trace`/`Test-EventTrace`), the `quality-gate` entry's
`capability_applicability` field, and the `TEST-008`/`TEST-009` cases in
`tests/loop-inventory.tests.{sh,ps1}` were already present on this branch
before this session started, landed as part of commit `45dda57f`
("feat(epic-195-a7): T-001 fixture matrix builder, implemented by Codex")
— a commit whose own message discloses that it spans 23 paths beyond
T-001's own Planned Files, including `tests/lib/loop-driver.{sh,ps1}` and
`tests/loops/loop-inventory.json`. `git log --oneline -- tests/lib/loop-driver.sh`
shows no commit after `45dda57f` touched that file, so the driver content
this report's Outputs table hashes is exactly what that commit produced.
The T-005 implementation report (`reports/implementation/epic-195-a7-compatibility/T-005.md`)
was, until this session, an unfinished stub ("In progress" throughout,
Test Result `NOT RUN`), and `tasks.md` T-005 Status had never been flipped
past `Planned`. This session's own contribution is: independently
reproducing genuine RED against a reconstructed pre-implementation state,
reproducing GREEN against the current tree, and completing the report,
CHANGELOG entry, and status flip — not authoring the driver/registry
changes themselves, which this note discloses rather than silently
re-claiming as new work.

## Reconstruction method (mutation-kill scratch-copy technique)

1. `git archive HEAD` extracted into a scratch directory outside the repo
   (`git worktree`/real-tree untouched throughout).
2. The five T-005-owned files were overwritten in the scratch copy with
   their content at `45dda57f^` (the commit immediately before the leaked
   T-001 commit that introduced them) — `tests/loops/loop-inventory.json`,
   `tests/lib/loop-driver.sh`, `tests/lib/loop-driver.ps1` — while
   `tests/loop-inventory.tests.sh`/`.ps1` were kept at their **current**
   (post-implementation) content, so the reconstructed state is exactly
   "tests written, implementation missing" — the TDD RED precondition per
   T-005's own Required Workflow: `tdd`.
3. `bash tests/loop-inventory.tests.sh` and
   `pwsh -NoProfile -File tests/loop-inventory.tests.ps1` were run against
   that scratch tree with `TZ=UTC LC_ALL=C` (Global Constraints "Fixed
   environment").

## RED (reconstructed pre-implementation state)

- Bash: exit 1, 54 passed / 4 failed — `red-sh.log`.
- PowerShell: exit 1, 54 passed / 4 failed — `red-ps1.log`.
- Failures in both runtimes: `TEST-008.2` (quality-gate entry lacks the
  three-state `capability_applicability` mapping) and `TEST-009.4` ×3
  (`_loop_trace_emit`/`assert_capability_applicability`/`assert_event_trace`
  — `Write-LoopTraceEvent`/`Test-CapabilityApplicability`/`Test-EventTrace`
  on the PowerShell side — unavailable). `TEST-008.1`, `TEST-008.3`,
  `TEST-009.1`–`.3` still pass at this stage because they assert properties
  that hold independently of the new field/functions (legacy-copy
  validity, the not-yet-exercised negative self-check plumbing, and the
  pre-task byte-identity of `assert_terminal`/`assert_artifacts_schema`,
  which the reconstructed old driver trivially satisfies against itself).
  This 54/4 split is byte-for-byte consistent with the pre-existing
  `red-summary.md` (dated 2026-08-08) recorded by the original,
  never-finalized implementation attempt, corroborating that both captures
  observed the same genuine precondition.

## GREEN (current tree)

- Bash: exit 0, 71 passed / 0 failed — `green-sh.log`.
- PowerShell: exit 0, 71 passed / 0 failed — `green-ps1.log`.

## Additional checks performed this session

- `assert_terminal`/`assert_artifacts_schema` byte-identity: confirmed by
  `TEST-009.1`/`TEST-009.2` (SHA-256 of the extracted function bodies
  against the pre-task baseline) passing in both RED and GREEN, and by the
  suite's own `TEST-009.3` negative self-check (a deliberately mutated
  `assert_terminal` body is rejected) passing in both states, proving the
  check is not vacuous.
- Mechanical confirmation that `capability_applicability` is read by
  exactly one function per runtime: `grep -n capability_applicability
  tests/lib/loop-driver.sh tests/lib/loop-driver.ps1` returns only the
  doc-comment line and `assert_capability_applicability`/
  `Test-CapabilityApplicability`'s own body in each file (AC-039's
  mechanical half, per T-005's own Out of Scope note).
- `assert_event_trace` purity: `TEST-009.12` statically confirms its
  function body never calls `_loop_trace_emit`; `TEST-009.10` confirms it
  does not mutate `_LOOP_EVENT_TRACE`/`_LOOP_EVENT_SEQ` as a side effect.
- Full mismatch coverage: `TEST-009.11` iterates `kind`/`producer`/`value`/
  `count` mutations of a golden trace and confirms each is independently
  rejected by `assert_event_trace` (Data Plan "Trace identity", all four
  required dimensions).

## Not in this task's scope (confirmed absent, per tasks.md Out of Scope)

- No producer call site was added inside `assert_terminal`,
  `drive_review_round`, `_loop_reserve_review_context`,
  `check-quality-gate-cycle-limit.sh`, `select-agent-model.sh`, or
  `loop_validator_skip` — design.md's own per-kind producer table
  describes the full, eventual wiring, but T-005's own Done When requires
  `assert_terminal`/`assert_artifacts_schema` to stay byte-identical, and
  T-005's own Out of Scope excludes `TEST-018`/`TEST-019` (T-006/T-007) —
  the cases that will actually drive rounds through those call sites.
  `assert_capability_applicability` is written as its own producer call
  site for the `quality-gate-outcome:capability-applicability` event
  (design.md API / Contract Plan), which is the one producer wiring that
  is inside a T-005-owned function.
