# PR integration check — 2026-11-14

Merged `origin/main` at `0f4e3268` into the existing work branch without rebasing or rewriting the recorded execution commits. Six textual conflicts were resolved: four generated guard files, the successor publication fixture and the verification catalog. Both sets of canonical guard additions and registered suites are retained. Generated guard outputs were rebuilt using the existing generator. Successor pins describe the merged live bytes and the actual already-applied predecessor copies; frozen predecessors were not rewritten. Six stale candidate mirrors equal to main's applied bytes were updated by the existing synchronization tool; pending human changes were left alone.

Checks on the merged tree:

| Check | Result |
|---|---|
| Guard generator `--check` | PASS |
| Verification catalog | 15 tests, 1 skip, no failures |
| SQL development contracts | 2 tests PASS |
| Ship track selection Bash / PowerShell | 164 / 170 PASS |
| Phase 2 guard invariants Bash / PowerShell | 42 / 55 PASS; PowerShell has 1 existing installed-runner skip |
| Native review-launcher controls | 17 tests, 1 opt-in native permission probe skipped, no failures |
| Bash loop driver | 26 PASS |
| Mirror freshness | PASS after synchronizing six stale candidate mirrors; pending copies preserved |
| Repository validator | PASS using `/workspace/.tools/sdd-forge-dev/bin/pwsh` on PATH |
| Changed source whitespace check | PASS |

The first mirror check identified the stale generated candidates and was repaired by synchronization. The first repository wrapper attempt found no `pwsh` on the shell PATH; it was rerun with the environment's prescribed binary path and passed. These are not concealed all-green first runs.

Historical native/browser/provider results remain bound to their original recorded source/runtime revisions. This merge check does not rerun all registered suites, repeat authenticated external Design or visitor-browser flows, or establish Windows behavior from Linux PowerShell.
