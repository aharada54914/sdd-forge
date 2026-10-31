# QG cycle-1 remediation -- mutation-kill evidence (design-sync-scan)

Scope: Wave 9 QG cycle-1 Major findings on `design-sync-scan` (scan feature
only; `design-sync-standing-consent` files are untouched). Fixes landed in
`tests/design-sync-scan.tests.sh` and `.tests.ps1` (new assertions
TEST-014d, TEST-087, TEST-053) and `reports/implementation/design-sync-scan/
T-001.md` / `T-005.md` (disclosure/consistency corrections). No production
script (`plugins/sdd-bootstrap/scripts/design-sync-scan.{sh,ps1}`) or
`tests/run-all.{sh,ps1}` file in the real repository was modified by this
remediation -- those are only mutated inside disposable scratch copies below,
to prove the new assertions detect the drift/regression they are meant to
catch.

## Method

Each trial:

1. Copies a full baseline snapshot (`plugins/`, `tests/`, `specs/
   design-sync-scan/`, `specs/design-sync-consent/`) from the real repo into
   an isolated scratch tree (outside the repo, under the session scratchpad).
2. Applies exactly one mutation to exactly one file via a `sed` expression.
3. Records the target file's SHA-256 before and after the edit (proves the
   mutation was actually applied, not a no-op).
4. Runs the relevant suite (`tests/design-sync-scan.tests.sh` under `bash`,
   or `.tests.ps1` under `pwsh`) inside the mutated tree.
5. Captures the target Test ID's PASS/FAIL line and the suite's overall
   `Results:` line.

The harness script itself is not preserved here (scratch-only, disposable);
its logic is summarized in this file and the raw per-trial console output is
preserved in each `trial-*.log`.

## Trials and results

| Trial log | Mutated file | Mutation | Target file SHA-256 changed | Target Test ID | Result |
|---|---|---|---|---|---|
| `trial-m1-xxx-add.log` | `design-sync-scan.sh` | `placeholder_pattern_cs` gets a leading `XXX\|` alternative | yes (`00e98f...` -> `e7c3b6...`) | TEST-014d | **FAIL** (killed) |
| `trial-m2-remove-todoreplace.log` | `design-sync-scan.sh` | `\|TODO_REPLACE_WITH_PROJECT_COMMANDS` removed from `placeholder_pattern_cs` | yes (`00e98f...` -> `4552a9...`) | TEST-014d | **FAIL** (killed) |
| `trial-m3-hack-noboundary.log` | `design-sync-scan.sh` | `HACK\b` -> `HACK` (word-boundary anchor dropped) | yes (`00e98f...` -> `71a1ef...`) | TEST-014d | **FAIL** (killed) |
| `trial-m4-remove-notimplemented.log` | `design-sync-scan.sh` | `not[ _-]implemented\|` removed from `placeholder_pattern_ci` | yes (`00e98f...` -> `8a25cb...`) | TEST-014d | **FAIL** (killed) |
| `trial-m1ps1-xxx-add.log` | `design-sync-scan.ps1` | `$placeholderPatternCs` gets a leading `XXX\|` alternative | yes (`f496d9...` -> `9e6dd7...`) | TEST-014d | **FAIL** (killed) |
| `trial-m5sh-edu-excluded.log` | `design-sync-scan.sh` | `is_reserved_domain`'s `case` gains a `*.edu\|...)` arm | yes (`00e98f...` -> `3fcd09...`) | TEST-087 | **FAIL** (killed) |
| `trial-m5ps1-edu-excluded.log` | `design-sync-scan.ps1` | `Test-ReservedDomain`'s `switch` gains a `'*.edu' { return $true }` arm | yes (`f496d9...` -> `38628e...`) | TEST-087 | **FAIL** (killed) |
| `trial-m6sh-unregister.log` | `tests/run-all.sh` | `tests/design-sync-scan.tests.sh` registration line deleted | yes (`585466...` -> `1b4c2a...`) | TEST-053 | **FAIL** (killed) |
| `trial-m6ps1-unregister.log` | `tests/run-all.ps1` | `tests/design-sync-scan.tests.ps1` registration line deleted | yes (`f0a1e3...` -> `b0d9c0...`) | TEST-053 | **FAIL** (killed) |

Every trial's target Test ID FAILs under its mutation, and every trial's
file-hash comparison confirms the mutation was genuinely applied (not a
silently-unmatched `sed` no-op). Each trial log also carries one unrelated,
pre-existing `FAIL: TEST-046` line -- an artifact of the scratch tree not
including every file `design-system-contract.tests.sh`'s own baseline
comparison reads (unrelated to any change in this remediation); it is
present identically whether or not the trial's own mutation is applied, and
does not appear in `post-fix-{sh,ps1}-full.log` below, which run against the
real, complete repository.

## Post-fix, unmutated GREEN evidence

- `post-fix-sh-full.log` -- `bash tests/design-sync-scan.tests.sh` against
  the real repository post-fix: `Results: 101 passed, 0 failed` (exit 0).
- `post-fix-ps1-full.log` -- `pwsh -File tests/design-sync-scan.tests.ps1`
  against the real repository post-fix: `Results: 136 passed, 0 failed`
  (exit 0).

97 -> 101 (`.sh`) and 132 -> 136 (`.ps1`) reflects the four new assertions
per runtime: TEST-014d (two rows, `-setup` + comparison), TEST-087 (one
row), TEST-053 (one row).
