# Implementation Report Addendum: T-005 Remedy 1

- Task ID: T-005
- Model: Claude Sonnet 5
- Effort: high

Report Schema: implementation-report/v2 (remedy addendum)

This is a remedy addendum, not a revision of
`reports/implementation/epic-191-a3-path-ownership/T-005.md`, per
`quality-gate/SKILL.md`'s own guidance not to edit a frozen implementation
report to reconcile post-gate findings. The original report's narrative
stands as the record of that authoring run; this addendum records the
remedy work done in response to the quality-gate's findings.

## Source Finding

`reports/quality-gate/epic-191-a3-path-ownership/T-005.md` (Verdict:
NEEDS_WORK, Done Decision: Blocked), Major finding 1: `check_inventory_conformance`
(bash) / `Test-InventoryConformance` (PowerShell) performed only a
fixed-string/regex-escaped substring match, which caught a missing entry
and the one specific extra `contracts/**` case, but did not reject (a) an
arbitrary extra cross-cutting entry ("no more") or (b) a canonical entry
wrongly classified as bounded instead of cross-cutting ("no differently
classified") — both explicitly required by AC-042. This gap is independent
of Epic A1's template landing and was actionable immediately.

## Remedy

Rewrote both check functions to parse the actual `shared_paths` entry
structure and assert **set equality** between the template's cross-cutting
patterns and the canonical six-entry set — one assertion that catches
missing, extra, AND misclassified entries simultaneously (a canonical
pattern declared bounded is neither absent from `shared_paths` nor
cross-cutting, so it fails the same equality check either way).

- **Bash** (`tests/component-path-resolver.tests.sh`): reuses
  `resolve-component-paths.py`'s own restricted-YAML parser
  (`parse_minimal_yaml`) via a `python3 -` invocation, rather than a
  second, potentially-diverging parser implementation.
- **PowerShell** (`tests/component-path-resolver.tests.ps1`): a small,
  purpose-built line-based parser scoped to exactly the `shared_paths`
  entry shape (dot-sourcing `resolve-component-paths.ps1` was rejected as
  an approach — its CLI dispatch/`exit` logic sits at script scope, so
  dot-sourcing it with no bound parameters would execute that logic and
  terminate the calling test script too).

Added two new `TEST-042-negative` sub-cases the quality-gate specifically
named as unexercised: `.2` (all six canonical entries present and
correctly classified, PLUS one arbitrary extra `vendor/**` entry — a pure
"no more" violation) and `.3` (a canonical entry, `specs/**`, declared
bounded via `components:` instead of `classification: cross-cutting` — a
pure "no differently classified" violation). Verified both new sub-cases
are rejected as expected on both runtimes, and re-verified a genuinely
conformant fixture is still accepted (no regression toward over-rejection).

## Outputs

Population: this addendum's own commit (`347f2f70`). The hashes below are
refreshed to the current on-disk value — the file was edited again after
this addendum's own authoring run, by T-001's unblock commit (`01df4cbd`),
per the epic-level Outputs repair (RT-20260809-001). Same current hash as
declared in `T-005.md`'s own Outputs table (both reports declare the same
shared file). Excluded as not-an-implementation-output:
`reports/quality-gate/epic-191-a3-path-ownership/T-005.md` (the finding this
addendum responds to — a review artifact) and
`specs/epic-191-a3-path-ownership/verification/T-005/*` (evidence logs) and
this report itself; `specs/epic-191-a3-path-ownership/tasks.md`
(Approval/Status only) is excluded as hash-bound.

| Path | SHA-256 |
|---|---|
| `tests/component-path-resolver.tests.ps1` | `dc1829b2364edc5fb34ec5188aa4cd2b3ae97b0253eed611140e714c022b66d4` |
| `tests/component-path-resolver.tests.sh` | `53246b9d1d550a9275625820070592dafbceefa96d37ac1f30364dead0fd67cb` |

## Test Evidence

- **Test Command**: `bash tests/component-path-resolver.tests.sh` and
  `pwsh -NoProfile -File tests/component-path-resolver.tests.ps1`
- **Test Result**: 40 passed / 3 failed on both runtimes (up from 38/3 —
  the two new TEST-042-negative sub-cases both pass; the three pre-existing
  failures, TEST-011.3/TEST-042/TEST-044, remain the same documented,
  designed Epic A1 external-dependency red state, unaffected by this
  remedy).
- **Test Evidence Path**:
  `specs/epic-191-a3-path-ownership/verification/T-005/component-path-resolver.GREEN.log`
  and
  `specs/epic-191-a3-path-ownership/verification/T-005/component-path-resolver-ps1.GREEN.log`
  (both refreshed to reflect this remedy's 40/3 state)

## Status After Remedy

Task remains `Blocked` — this remedy closes the one actionable-now Major
finding, but the task's Done state is still gated on Epic A1 shipping
`contracts/project-context.template.yaml` matching the six-entry set
(TEST-042/TEST-044), per the second Major finding and `tasks.md` T-005's
own Blockers note. Not resubmitted for quality-gate re-review in this
session (task is not being moved toward Done); recorded here for the next
quality-gate pass once Epic A1's artifact lands.
