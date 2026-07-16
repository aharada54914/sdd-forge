# T-002 Quality-Gate Deterministic Evidence

Run: 2026-07-15T06:40:00Z

All commands were executed from the repository root against the human-published
PowerShell guard and completed with exit code 0.

```text
> powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/phase2-sudo-signature.tests.ps1
ok: valid 64-hex HMAC activates sudo (exit 0)
ok: 63-character signature stays inactive (exit 2)
ok: 65-character signature stays inactive (exit 2)
ok: malformed 64-character non-hex signature stays inactive (exit 2)
ok: first-byte signature mutation stays inactive (exit 2)
ok: middle-byte signature mutation stays inactive (exit 2)
ok: last-byte signature mutation stays inactive (exit 2)
phase2-sudo-signature.tests.ps1: 7 passed, 0 failed

> bash tests/phase2-sudo-signature-static.tests.sh
ok: candidate is ASCII/no-BOM and uses the PS5.1 64-hex full-XOR comparator

> check-risk.ps1 ... -TaskId T-002
Risk check passed for task T-002.
> check-placeholders.ps1 plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1
Placeholder scan passed.
> check-traceability.ps1 ... -RequireEvidence
Traceability check passed for epic-136-phase2-gates: 5 link(s).
> check-task-state.ps1 ...
Task state check passed for 6 task(s).
> check-workflow-state.ps1
workflow-state: ok
```
