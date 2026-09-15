# PR #400: approved five-file CI repair

Status: local scoped regressions passed; formal review, latest-head CI and merge remain pending.

## Authorization and boundary

On 2026-09-15 the user explicitly approved adding the two loop-driver test helpers, the epic-191 Bash/PowerShell precheck mirrors, and their manifest (five implementation files). This extends the RT-20260908-004 fixture compatibility repair and synchronizes the already-applied investigation-only precheck remedy. No production validator, acceptance criterion, historical verdict, or task status was changed in this repair.

## Cause and correction

The helpers emitted obsolete reviewer check IDs and omitted the ADR extension now emitted by the real precheck. Once those were repaired, downstream task precheck still rejected absolute design/precheck manifest paths. Both helpers now emit the canonical ordered A/B check sets, consistent summary counts, repository-relative evidence paths, and the actual precheck ADR set. The production checks remain unchanged.

The two epic-191 mirrors were stale relative to the already-applied live prechecks. They now match live byte-for-byte; the manifest was updated using the computed hashes.

## Actual local verification

All commands ran through `rtk proxy` from the repository on macOS. PowerShell here is not native Windows evidence.

| Command | Result |
| --- | --- |
| `bash tests/loop-consistency.tests.sh` | 33 passed, 0 failed; 17 seconds |
| `pwsh -NoProfile -File tests/loop-consistency.tests.ps1` | 37 passed, 0 failed; 47 seconds |
| `bash tests/check-component-coverage.tests.sh` | 46 passed, 0 failed |
| `pwsh -NoProfile -File tests/check-component-coverage.tests.ps1` | 47 passed, 0 failed |
| `bash tests/human-copy-mirror-freshness.tests.sh` | 6 passed, 0 failed, 15 informational pending |
| `pwsh -NoProfile -File tests/human-copy-mirror-freshness.tests.ps1` | 6 passed, 0 failed, 15 informational pending |
| `shasum -a 256 -c MANIFEST.sha256` in epic-191 human-copy | All 12 entries OK |
| `cmp` of each changed mirror against live | Both exit 0 |
| `git diff --check` | Exit 0 |

Loop baseline was 29 passed / 4 failed. Intermediate repairs reached 32 passed / 1 failed; the final correction passed the downstream task leg without weakening the validator. The existing unauthorized-input negative assertion still rejects its mutation. The loop suites retain their named A5 integration skip; Bash fixture risk-check warnings and the 15 informational unapplied mirrors are not claimed as verified production coverage.

## Content pins

- `tests/lib/loop-driver.sh`: `31048bae33c9a413bc77dc45165abdca9dec835ba096772c1a614af728fd17b4`
- `tests/lib/loop-driver.ps1`: `3dedde2523cc57cf7f80c60aab0e2d9b896a578752d906261ac6156a527cb6cb`
- epic-191 `human-copy/MANIFEST.sha256`: `05b37c58d3aee041640cdea35b2b9f3d2c924355552037fa1a1804b613445717`
- mirrored `spec-review-precheck.sh`: `6e1d117ea7a67653962a7654851529168ab86b36accc858ecb5e9b59451bd1f4`
- mirrored `spec-review-precheck.ps1`: `cfbaad2db2f3a44a5ed6cbcf40808e049b1d13267e17acd11ae9d9ba0bbb1f76`

## Remaining work

Preserve the existing A1 attempt-6 round-1 NEEDS_WORK. The separately human-applied design amendment permits a fresh round-2 precheck and independent review; that has not been run by these tests. The other real repository workflow-state and MCP lifecycle failures are not resolved by this fixture repair. Do not close the review ticket or claim PR/main acceptance from these local suites. Obtain latest-head CI, including Windows, after the remaining blocking conditions and PR conflicts are resolved. No live host activation is proved here.
