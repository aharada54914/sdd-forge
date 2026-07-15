# T-004 Quality-Gate Deterministic Evidence

Run: 2026-07-15T07:20:00Z. All commands ran from the repository root against
the human-published protected files and completed with exit code 0.

```text
> bash tests/phase2-risk-upgrade.tests.sh
phase2-risk-upgrade.tests.sh: 33 passed, 0 failed

> powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/phase2-risk-upgrade.tests.ps1
phase2-risk-upgrade.tests.ps1: 33 passed, 0 failed

> check-risk.ps1 specs/epic-136-phase2-gates/tasks.md -TaskId T-004
Risk check passed for task T-004.
> check-placeholders.ps1 <five T-004 live production files>
Placeholder scan passed.
> check-traceability.ps1 specs/epic-136-phase2-gates/traceability.json -RepoRoot . -RequireEvidence
Traceability check passed for epic-136-phase2-gates: 5 link(s).
> check-task-state.ps1 specs/epic-136-phase2-gates/tasks.md -RepoRoot .
Task state check passed for 6 task(s).
> check-workflow-state.ps1
workflow-state: ok
> check-sdd-structure.ps1 -RepositoryRoot .
check-sdd-structure: OK
```

The focused suites exercise TEST-007, TEST-008, and TEST-009 in both native
runtimes: ordered risk triggers, documented exclusions and boundaries,
malformed-input fail-closed behavior, no lite artifact on a hit or unavailable
input, `--lite` full escalation, `--full` bypass, and missing full-track input
diagnostics.
