# T-001 Quality-Gate Deterministic Evidence

Run: 2026-07-15T06:16:37Z

All commands below were executed from the repository root against the
human-published protected targets. Each completed with exit code 0.

```text
> powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/phase2-guard-tokenizer.tests.ps1
ok: legal: quoted regex escaped alternation plus standalone fd duplicate (all exit 0)
ok: legal: fd duplicate on protected inspection (all exit 0)
ok: legal: ls protected inspection (all exit 0)
ok: legal: cat protected inspection (all exit 0)
ok: legal: find protected inspection (all exit 0)
ok: deny: unquoted backslash changes token boundary (all exit 2)
ok: deny: unclosed quoted regex (all exit 2)
ok: deny: regex plus protected redirect (all exit 2)
ok: deny: tee writes protected target (all exit 2)
ok: deny: cp writes protected target (all exit 2)
ok: deny: rm protected target (all exit 2)
ok: PowerShell candidate is ASCII-only without BOM
phase2-guard-tokenizer.tests.ps1: 12 passed, 0 failed

> bash tests/phase2-guard-tokenizer.tests.sh
ok: 18 manifest-bound candidate hashes matched their exact protected targets
ok: cross-runtime tokenizer corpus passed
phase2-guard-tokenizer.tests.sh: 19 passed, 0 failed

> powershell.exe -NoProfile -ExecutionPolicy Bypass -File plugins/sdd-quality-loop/scripts/check-risk.ps1 specs/epic-136-phase2-gates/tasks.md -TaskId T-001
Risk check passed for task T-001.

> powershell.exe -NoProfile -ExecutionPolicy Bypass -File plugins/sdd-quality-loop/scripts/check-placeholders.ps1 plugins/sdd-quality-loop/scripts/sdd-hook-guard.py plugins/sdd-quality-loop/scripts/sdd-hook-guard.js plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1
Placeholder scan passed.

> powershell.exe -NoProfile -ExecutionPolicy Bypass -File plugins/sdd-quality-loop/scripts/check-traceability.ps1 -TracePath specs/epic-136-phase2-gates/traceability.json -RepoRoot . -RequireEvidence
Traceability check passed for epic-136-phase2-gates: 5 link(s).

> powershell.exe -NoProfile -ExecutionPolicy Bypass -File plugins/sdd-quality-loop/scripts/check-task-state.ps1 specs/epic-136-phase2-gates/tasks.md -RepoRoot .
Task state check passed for 6 task(s).

> powershell.exe -NoProfile -ExecutionPolicy Bypass -File plugins/sdd-quality-loop/scripts/check-workflow-state.ps1
workflow-state: ok
```

## Review-Fix Publication Recheck

Run: 2026-07-15T06:31:00Z

The human publication runner completed before this recheck. The current
immutable manifest matched all 18 installed targets, including
`sdd-hook-guard.js` at
`edc7cd292dd3e01836660eb86dd3ee6c9d156f0ac203c59e63c564f0618937e1`.

```text
> powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/phase2-guard-tokenizer.tests.ps1
phase2-guard-tokenizer.tests.ps1: 13 passed, 0 failed

> bash tests/phase2-guard-tokenizer.tests.sh
ok: 18 manifest-bound candidate hashes matched their exact protected targets
ok: cross-runtime tokenizer corpus passed
phase2-guard-tokenizer.tests.sh: 19 passed, 0 failed

> check-risk.ps1 ... -TaskId T-001
Risk check passed for task T-001.
> check-placeholders.ps1 <three guard twins>
Placeholder scan passed.
> check-traceability.ps1 ... -RequireEvidence
Traceability check passed for epic-136-phase2-gates: 5 link(s).
> check-task-state.ps1 ...
Task state check passed for 6 task(s).
> check-workflow-state.ps1
workflow-state: ok
```
