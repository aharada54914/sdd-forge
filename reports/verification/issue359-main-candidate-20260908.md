# Issue #359 main-based candidate verification

Date: 2026-09-08
Status: Scoped local checks passed; formal acceptance and integration pending.

## Candidate and approved scope

Worktree: `/Users/jrmag/.local/share/sdd-forge-issue359-recovery-20260908`

Base: `4366438f3b243210a4ece5a17f873ca2d920600a` (detached).

Only the approved collection-test repairs were applied: PowerShell fixture stdin draining and CL-012c/CL-012e expectation corrections (RT-20260906-002), and Bash CL-021b full-output grep consumption (RT-20260908-001). Production runners, timeout values, and workflow files were not changed. A standalone regression reads and tests the actual CL-021b assertion.

## Executed verification

All commands ran in the candidate worktree. Each command was prefixed with `rtk proxy env -u SDD_PANELIST_CODEX_CMD -u SDD_PANELIST_TIMEOUT -u SDD_PANELIST_DEADLINE_EPOCH_MS`.

| Command | Passed | Failed | Exit | Full output |
| --- | ---: | ---: | ---: | --- |
| `bash tests/collection-layer.tests.sh` | 52 | 0 | 0 | issue359-main-bash-collection-20260908.log |
| `pwsh -NoProfile -File tests/collection-layer.tests.ps1` | 47 | 0 | 0 | issue359-main-ps-collection-20260908.log |
| `bash tests/run-panelist-effort.tests.sh` | 28 | 0 | 0 | issue359-main-bash-effort-20260908.log |
| `pwsh -NoProfile -File tests/run-panelist-effort.tests.ps1` | 28 | 0 | 0 | issue359-main-ps-effort-20260908.log |
| `node reports/verification/issue359-grep-regression-20260908.cjs` | 4 | 0 | 0 | issue359-main-grep-regression-20260908.log |

`rtk proxy git diff --check` also exited 0. All executions above were local on macOS with stub CLIs, not live model acceptance tests. Coverage percentage was not measured. Suite counts overlap in behavior and are not unique requirement counts.

## Source stability

These SHA-256 values matched before and after the candidate verification:

- `tests/collection-layer.tests.sh`: `f1b0e10596f75a21c50fbeb16541137def98306b44b6438de40918256402faeb`
- `tests/collection-layer.tests.ps1`: `1bc5bbea3c1f601efb954a7a8ffbb1bfa148562694e08bb89613f6c4eda5fbd3`
- `reports/verification/issue359-grep-regression-20260908.cjs`: `0b82561526bbd47919317dc564d678bab379f1ff6834e49d57cf0c18140af6be`

## Decision, unresolved conditions, and next action

The candidate passes these scoped checks. This is not an independent quality-gate verdict and does not close either repair ticket or Issue #359. Historical failures remain failures. No task status was changed, and no commit, push, merge, or issue closure was performed for this candidate.

Actual Windows execution is still needed for the Windows-only PowerShell stub-worker paths. The standalone regression is not yet registered in mandatory CI. Formal fix-report/provenance preparation, independent gate verification, and required CI on the integration commit remain outstanding. Next: complete those conditions without weakening assertions or bypassing protected-file enforcement. Ordinary work stays with the main agent; fresh-context review is reserved for mandatory independent gates.
