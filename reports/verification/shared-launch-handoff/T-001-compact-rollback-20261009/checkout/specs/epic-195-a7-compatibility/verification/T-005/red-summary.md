# T-005 TDD Red Evidence

- Run ID: `epic-195-a7-compatibility-t005-20260808T164005Z`
- Captured before edits to `tests/loops/loop-inventory.json`, `tests/lib/loop-driver.sh`, or `tests/lib/loop-driver.ps1`.

| Command | Result | Expected failures |
|---|---|---|
| `bash tests/loop-inventory.tests.sh` | exit 1; 54 passed, 4 failed | missing quality-gate `capability_applicability`; missing `_loop_trace_emit`, `assert_capability_applicability`, and `assert_event_trace` |
| `pwsh -NoProfile -File tests/loop-inventory.tests.ps1` | exit 1; 54 passed, 4 failed | missing quality-gate `capability_applicability`; missing `Write-LoopTraceEvent`, `Test-CapabilityApplicability`, and `Test-EventTrace` |

The complete command output is retained in `red-bash.log` and
`red-powershell.log` in this directory.
