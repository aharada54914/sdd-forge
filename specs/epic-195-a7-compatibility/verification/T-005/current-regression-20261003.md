# T-005 current-head regression observation (2026-10-03)

This is a supplemental observation at commit `a1bf96a6d7348dc6c4f48494d68b964dfe56fa20`, not a replacement for the historical T-005 Red/Green evidence or implementation report. Each command was run separately from the repository root with `TZ=UTC LC_ALL=C`; all returned exit code 0. The figures below are the suites' exact final summary lines, transcribed from this run's tool output.

| Command | Final summary |
|---|---|
| `bash tests/loop-inventory.tests.sh` | `loop-inventory.tests.sh: 76 passed, 0 failed, 0s elapsed` |
| `pwsh -NoProfile -File tests/loop-inventory.tests.ps1` | `loop-inventory.tests.ps1: 75 passed, 0 failed, 3s elapsed` |
| `bash tests/loop-consistency.tests.sh` | `loop-consistency.tests.sh: 34 passed, 0 failed, 20s elapsed` |
| `pwsh -NoProfile -File tests/loop-consistency.tests.ps1` | `loop-consistency.tests.ps1: 38 passed, 0 failed, 33s elapsed` |
| `bash tests/loop-escalation.tests.sh` | `loop-escalation.tests.sh: 37 passed, 0 failed, 3s elapsed` |
| `pwsh -NoProfile -File tests/loop-escalation.tests.ps1` | `loop-escalation.tests.ps1: 36 passed, 0 failed, 7s elapsed` |

Both escalation lanes still print `SKIP: TEST-019.11c` because an executable interviewer caller invocation is not exercised by that fixture guard. Both print `TEST-019.10b` as deferred, despite reporting zero resolver invocations in their F1/F3/F4 fixtures. Neither assertion is counted here as live caller proof. PowerShell also prints two TEST-013 SKIPs for runtime-degradation scenarios.

This run did not rederive T-005's historical Red evidence, run the full repository suite, renew the implementation report, or execute a quality gate.
