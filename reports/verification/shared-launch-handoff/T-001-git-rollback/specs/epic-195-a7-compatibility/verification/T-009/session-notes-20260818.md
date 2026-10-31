# T-009 Independent Verification Session Notes (2026-08-18)

Run ID: `a7-t009-run-2026-08-18-01`

## Context

`--capability-enforcement`/`--capability-block-id` parsing (gated by a new
`emit_capability` flag independent of `emit_v2`), the additive `capability`
object in the both-flags case, the capability-only usage error, and the
`AC-011`/`AC-012`/`AC-033` matrix cases in
`tests/emit-run-record-feature-scope.tests.{sh,ps1}` were already present
on this branch before this session started. `git log --oneline --
plugins/sdd-quality-loop/scripts/emit-run-record.sh
plugins/sdd-quality-loop/scripts/emit-run-record.ps1
tests/emit-run-record-feature-scope.tests.sh
tests/emit-run-record-feature-scope.tests.ps1` shows all four of T-009's
own Planned Files last touched by commit `45dda57f` ("feat(epic-195-a7):
T-001 fixture matrix builder, implemented by Codex") — the same
scope-leaked commit T-005's own verification session
(`session-notes-20260818.md` in `specs/epic-195-a7-compatibility/verification/T-005/`)
already documented, whose own commit message discloses it spans 23 paths
beyond T-001's own Planned Files, naming `emit-run-record` explicitly
("emit-run-record, loop-driver and run-all twins are also touched").
`git show 45dda57f -- plugins/sdd-quality-loop/scripts/emit-run-record.sh`
confirms the `+capability`/`+emit_capability`/`+require_capability_enforcement_value`
diff lines land inside that commit, not an unrelated earlier one. No
commit after `45dda57f` touched any of the four files, so the content
this report's Outputs table hashes is exactly what that commit produced.
`reports/implementation/epic-195-a7-compatibility/T-009.md` was, until
this session, an unfinished stub from the same leaked commit's own
originating (Codex) session — every Outputs hash a 64-zero placeholder,
Test Result `NOT RUN`, `Current Status: In Progress` — and `tasks.md`
T-009 `Status` had never been flipped past `Planned`. This session's own
contribution is: independently re-verifying the pre-existing
implementation against T-009's own Done When and design.md's own API /
Contract Plan (rather than trusting it), reconstructing genuine RED
against a pre-implementation state, reproducing genuine GREEN against the
current tree, and completing the report, `CHANGELOG.md` entry, and status
flip — not authoring the flag-parsing/capability-object diff itself,
which this note discloses rather than silently re-claiming as new work.

## Reconstruction method (mutation-kill scratch-copy technique)

1. `git archive HEAD` extracted into a scratch directory outside the repo
   (`/private/tmp/claude-501/.../scratchpad/t009-red`; the real worktree
   was untouched throughout).
2. The two emitter scripts, `plugins/sdd-quality-loop/scripts/emit-run-record.sh`
   and `.ps1`, were overwritten in the scratch copy with their content at
   `45dda57f^` (the commit immediately before the leaked commit that
   introduced the capability flags) — confirmed byte-identical to
   `git show 45dda57f^:<path>` by `diff` before running anything. The two
   test files, `tests/emit-run-record-feature-scope.tests.{sh,ps1}`, were
   left at their **current** (post-implementation) content, so the
   reconstructed state is exactly "tests written, implementation missing"
   — the TDD RED precondition per T-009's own Required Workflow: `tdd`.
3. `bash tests/emit-run-record-feature-scope.tests.sh` and
   `pwsh -NoProfile -File tests/emit-run-record-feature-scope.tests.ps1`
   were run against that scratch tree with `TZ=UTC LC_ALL=C` (Global
   Constraints "Fixed environment").

## RED (reconstructed pre-implementation state)

- Bash: exit 1, 40 passed / 5 failed — `red-sh.log`.
- PowerShell: exit 1, 40 passed / 5 failed — `red-ps1.log`.
- Failures in both runtimes, isolated to exactly T-009's own new
  assertions:
  - `AC-033 matrix capability-only` — the pre-task script has no
    `--capability-enforcement` flag at all, so it fails with `unknown
    argument` (bash) / a PowerShell parameter-binding error, not the
    documented usage-error diagnostic the test expects; still exit 1, so
    this case is the one row of the five where the reconstructed old
    script's *incidental* fail-closed behavior (unrecognized flag) most
    resembles, but does not equal, the finished contract.
  - `AC-033 matrix both`, `AC-012 block_id escaping`,
    `AC-012 optional block_id` — no output record is produced at all
    (same unknown-argument/parameter-binding failure), so every
    `capability.*` field assertion fails.
  - `case-sensitivity: mis-cased capability value` — same failure; the
    old script has no enum validation to reject against.
  - All five failures are the reconstructed old script rejecting the new
    flag outright, not a partial/incorrect capability implementation —
    consistent with "implementation missing," not "implementation wrong."
- All other assertions (the pre-existing `--effort-*` matrix rows,
  `AC-025`, `AC-026`, and the `AC-033`/no-flags/effort-only rows) still
  pass at this stage, because they assert properties that hold
  independently of the new capability flags — confirming the RED is
  isolated to T-009's own new surface, not a broad regression.
- A pre-existing, never-finalized capture from the original abandoned
  attempt (`specs/epic-195-a7-compatibility/verification/T-009/red.log`,
  file-dated 2026-08-09, predating `45dda57f`'s 2026-08-11 commit date)
  recorded 40 passed / 4 failed in both runtimes against what was then a
  slightly different draft of the test file — four of this session's five
  failing case names match exactly (`AC-033 matrix capability-only`,
  `AC-033 matrix both`, `AC-012 optional block_id`,
  `case-sensitivity: mis-cased capability value`); `AC-012 block_id
  escaping` is present in this session's failing set but absent from that
  older capture, consistent with that specific assertion having been
  added to the test file later, between the 2026-08-09 draft capture and
  the final content `45dda57f` committed on 2026-08-11 (this session
  hashes and verifies only the final, committed test file — see Outputs).
  This is corroborating evidence, not this session's own RED evidence;
  this session's own RED is the freshly reconstructed capture described
  above.

## GREEN (current tree)

- Bash: exit 0, 50 passed / 0 failed — `green-sh.log`.
- PowerShell: exit 0, 50 passed / 0 failed — `green-ps1.log`.

## Additional checks performed this session (design.md contract, line-by-line)

- **No-flag `v1` heredoc byte-identity (AC-011).** `plugins/sdd-quality-loop/scripts/emit-run-record.sh`'s
  no-flag heredoc (current `:367-387`) diffed byte-for-byte against
  `git show 45dda57f^:plugins/sdd-quality-loop/scripts/emit-run-record.sh`'s
  own pre-task v1 heredoc (`:279-303`): identical. The PowerShell twin's
  `v1` record-construction branch (current `:254-269`) diffed against the
  pre-task `:218-239` branch: identical. Both confirm design.md's own "no-
  flag path's heredoc is untouched (byte-identical, AC-011)" clause.
- **Four-combination outcome table (design.md's API / Contract Plan).**
  Read `emit-run-record.sh` top-to-bottom against the table:
  - no/no -> `v1`, unchanged heredoc: confirmed above.
  - yes/no -> `v2` with `effort` only, no `capability` key: confirmed by
    the untouched effort-only heredoc (`:328-360`), still gated solely by
    `emit_v2` and never referencing `emit_capability`.
  - no/yes -> usage error, non-zero exit, no `$out` file: confirmed by
    `:113-116` (`emit_capability=1 && emit_v2!=1` exits 1 with a
    diagnostic to stderr before `$out` is ever computed, `:118` onward)
    and its PowerShell twin (`:88-90`, before `$out`/`$record` are built).
  - yes/yes -> `v2` with both `effort` and the additive `capability`
    sibling: confirmed by the both-flags heredoc (`:288-324`) and the
    PowerShell twin's `$record.Insert(7, "capability", ...)` (`:241-246`),
    both gated by `emit_capability` independent of `emit_v2`'s own gating.
  - The exact `{enforcement, block_id}` shape (design.md's `jsonc`
    example, `:650-655`) matches both twins' output structurally
    (mechanically confirmed by GREEN's own `AC-012` assertions, which
    check the exact key set via `keys | sort`).
- **`require_capability_enforcement_value`'s fail-closed style
  (design.md "matching the script's own existing
  `require_effort_control_value` fail-closed pattern, `:45-54`").**
  `require_capability_enforcement_value` (`:61-70`) is structurally
  identical to `require_effort_control_value` (`:50-59`): a `case`
  statement enumerating the exact valid set, one `printf`-to-stderr plus
  `exit 1` default arm. The PowerShell twin (`:66-72`) uses a
  case-sensitive `HashSet[string]` membership check constructed with an
  explicit `[System.StringComparer]::Ordinal` (`:66-68`) — not
  `-eq`/`-contains`, which would silently accept mis-cased values per
  this repository's own known PowerShell case-insensitivity pitfall);
  GREEN's `case-sensitivity: mis-cased -CapabilityEnforcement is rejected
  fail-closed` assertion is the mechanical confirmation this is not
  vacuous.
- **`emit_capability`/`emit_v2` independence.** `grep -n emit_capability
  plugins/sdd-quality-loop/scripts/emit-run-record.sh` shows it is set
  only by the two new flags (`:97`, `:99`) and never by any `--effort-*`
  flag; `grep -n emit_v2` shows the reverse — `emit_v2` is never set by
  either capability flag. The two gates are independent, as design.md's
  "independent of the existing `emit_v2`" clause requires.
- **One divergence found and disclosed (not a Done-When blocker):**
  design.md's four-combination table names only two axes (`--effort-*`
  supplied / `--capability-enforcement` supplied). The implementation adds
  a third, undocumented internal gate not named anywhere in design.md:
  supplying `--capability-block-id` alone (no `--capability-enforcement`,
  regardless of `--effort-*`) is rejected before the table's own row 3
  check even runs (`:109-112`, `"--capability-block-id requires
  --capability-enforcement"`; PowerShell twin `:84-86`). No test in
  `tests/emit-run-record-feature-scope.tests.{sh,ps1}` exercises this
  specific case (block-id-only), so it is untested as well as
  undocumented. It does not contradict any row of the documented table
  (that table is silent on block-id-supplied-alone, since `block_id` is
  described only as an optional field *within* the both-flags row, design
  `:634-639`) and does not change any of the four documented outcomes'
  own behavior, so it is not a Done-When violation — but it is
  implementation behavior beyond what design.md specifies, and beyond
  what any test locks down. Flagged for the independent quality-gate
  and/or a follow-on design.md/test addition, not fixed by this session
  (T-009's own Scope is TDD Red->Green for the *documented* four
  combinations; inventing a new test for undocumented behavior is outside
  that scope, and this session made no production-code change either
  way).

## Not in this task's scope (confirmed absent, per tasks.md Out of Scope)

- `tests/loops/loop-inventory.json`/`tests/lib/loop-driver.sh` (T-005) —
  untouched by this session, a separate shared file with its own task
  (already independently verified and flipped by the prior T-005
  session).
- The REQ-007 allowlist manifest (T-010) — untouched; not named among
  T-009's own Planned Files.
