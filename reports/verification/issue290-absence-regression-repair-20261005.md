# Issue #290 absence-regression test repair (non-formal)

Date: 2026-10-05 (Asia/Tokyo)

Scope: `tests/sdd-domain/absence-regression.Tests.ps1` only. No task status, review verdict, reservation, protected specification, or Git operation was changed.

## Input identity

| File | SHA-256 |
|---|---|
| `tests/sdd-domain/absence-regression.Tests.ps1` | `4ee9884c16358837c02d56d695a347c5943b80eeafcf18fe99788ac40383e70a` |
| `plugins/sdd-quality-loop/scripts/check-domain-conformance.sh` | `fd3297986a682b619fcfe45fc03e8b2eef12b29dfd86bacfc4c736212139a8c7` |
| `plugins/sdd-quality-loop/scripts/check-domain-conformance.ps1` | `609b457dab5854420f171d398b1b23f0aec8ac018c9d175fdf56e04678472a97` |

## Result and boundary

- Before repair: 14 Pester cases, 3 failures. The failures measured deleted lines and hunk count against historical commit `7fc0534`, not absent-domain behavior. The bootstrap skill accumulated unrelated committed edits.
- The repair replaces those Git-diff-shape assertions and a self-returning test double with execution of the actual shell and PowerShell domain-conformance gates on a temporary project lacking `domain/`. Each gate must exit zero, emit exactly one skip line, preserve both input artifact SHA-256 values, and create no additional file. The file inventory uses `-Force`; a negative fixture with `.unexpected-artifact` verifies that the exact inventory assertion rejects a hidden extra file.
- `rtk proxy pwsh -NoProfile -Command 'Import-Module Pester; $r = Invoke-Pester -Script tests/sdd-domain/absence-regression.Tests.ps1 -PassThru -Show Summary; Write-Host "RESULT:$($r.PassedCount)/$($r.FailedCount)/$($r.InconclusiveCount)"; if ($r.FailedCount -gt 0) { exit 1 }'`: exit 0; 9 passed, 0 failed, 0 inconclusive.
- `rtk proxy git diff --check -- tests/sdd-domain/absence-regression.Tests.ps1`: exit 0.

The bootstrap and domain-sync skills are agent instruction documents, not executable unit-test programs. Their textual contract checks remain static; this report does **not** establish real-host bootstrap behavior, byte identity of every generated artifact, all of AC-010, a formal review result, or task completion.
