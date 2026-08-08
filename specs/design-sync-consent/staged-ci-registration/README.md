# Staged CI registration patch (R-OQ-8 part (c), AC-024 / TEST-039)

This directory holds the CI-registration change that `tasks.md:69-75` keeps
outside the design-sync-consent decomposition as "a separately staged,
human-applied patch". Until 2026-08-08 that patch was referenced by the specs
but had never been authored — `MANIFEST.sha256` covered only T-004's
lite-spec candidate, and no workflow draft existed anywhere under
`specs/design-sync-consent/`. This directory closes that gap.

## Why a human has to apply it

`.github/workflows/test.yml` is protected twice over: it is on the guard's
protected list (`plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4`)
and on `PHASE2_HUMAN_COPY_TARGETS` (`:18`). The suffix match in
`sdd-hook-guard.py:1001-1015` has no `human-copy/` carve-out, so unlike
T-004's lite-spec candidate this one cannot even be staged into
`human-copy/` — an agent can only leave the patch at a non-protected path
such as this one, and a human applies it.

## What it changes

Two steps are added to the `test` job of `.github/workflows/test.yml`,
following the file's existing conventions exactly:

| Step | Shell | OS legs | Placement |
|---|---|---|---|
| `Test design-system contract suite (pwsh)` | `pwsh` | all three | after `Test cross-runtime scenario suite (pwsh)` |
| `Test design-system contract suite (bash)` | `bash` | non-Windows (`if: runner.os != 'Windows'`) | after `Test branch-protection script (bash)` |

The pwsh/bash split, the `runner.os != 'Windows'` guard on the bash leg, and
the `2>&1 | tee "${{ runner.temp }}/...-tests.log"` form on the bash leg all
mirror the surrounding steps, so the failure-artifact upload at the end of
the job picks the log up unchanged.

## Human steps

1. From the repository root, apply the patch:

   ```
   git apply specs/design-sync-consent/staged-ci-registration/test-yml-ci-registration.patch
   ```

   (`git apply --check <same path>` first if you want a dry run; it was
   verified to exit 0 against the tree this patch was authored on.)

2. Confirm the workflow still parses and the two steps landed where intended:

   ```
   git diff .github/workflows/
   ```

3. Re-run both suites. **Both must now be fully green** — TEST-039 is the
   only assertion either suite still fails before this patch lands:

   ```
   sh tests/design-system-contract.tests.sh
   pwsh -NoProfile -File tests/design-system-contract.tests.ps1
   ```

   Expected after the apply: `PASS: 121 / FAIL: 0` (`.sh`) and
   `PASS: 51 / FAIL: 0` (`.ps1`). Before the apply the same commands read
   `120/1` and `50/1`, the single failure being TEST-039 itself.

## Newly-reachable branch declaration

`acceptance-tests.md` (TEST-039 notes) requires this to be named explicitly:
applying this patch makes the entire `DS-001`…`DS-017` assertion block —
which has **never executed on a CI runner** — reachable for the first time,
on every OS leg of the matrix, in the same run. A failure appearing there on
the first post-apply CI run is most likely traceable to that first execution
rather than to an unrelated regression.

What was checked in advance, on macOS, at authoring time:

- **Exit-code propagation is real, not vacuous.** Both suites currently exit
  `1` (`.sh` ends in `[ "$FAIL" -eq 0 ]`; `.ps1` ends in
  `if ($Script:TestFail -gt 0) { exit 1 }`), so a regression genuinely fails
  the job. GitHub's `shell: bash` default includes `-o pipefail`, so the
  `| tee` on the bash leg does not mask a non-zero suite exit.
- **CRLF is not a hazard for the hash-based assertions.** TEST-037 and
  TEST-038 compare SHA-256 digests over file content, which would break on a
  CRLF checkout; `.gitattributes` pins `* text=auto eol=lf` plus an explicit
  `*.md text eol=lf`, so every OS leg gets LF and the recorded digests hold.
- **The `.ps1` leg runs under PowerShell 7** (`shell: pwsh`), matching the
  runtime the suite was verified against locally.

What could **not** be checked from here: actual execution on the
`windows-latest` and `ubuntu-latest` runners. The `.sh` suite is skipped on
Windows by the same convention every other bash step in the file uses, so
the Windows exposure is the `.ps1` suite plus `DS-001`…`DS-017` only.
