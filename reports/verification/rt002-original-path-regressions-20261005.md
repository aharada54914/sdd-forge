# RT002 original-path regression verification

Date: 2026-10-05

After the human-applied shared-launch repair, the orchestrator ran both existing
handshake suites from this owner checkout, without copying the validator.

| Command | Observed result |
| --- | --- |
| `rtk proxy bash tests/check-hook-activation-handshake.tests.sh` | Exit 0; PASS 984, FAIL 0 |
| `rtk proxy pwsh -NoLogo -NoProfile -File tests/check-hook-activation-handshake.tests.ps1` | Exit 0; PASS 985, FAIL 0 |

These are local behavioral regressions, not native-host activation or a formal
independent verdict. Tool output was truncated; final totals and exit codes were
observed, but this report is not a full captured transcript.

Installed-state verification, fresh evaluator admission, CI, merge and Done
remain unverified by these executions. No task status or historical verdict was
changed.
