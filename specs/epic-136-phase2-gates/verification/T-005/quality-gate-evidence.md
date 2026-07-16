# T-005 Quality-Gate Deterministic Evidence

Run: 2026-07-15T08:30:00Z. All commands ran from the repository root against
the human-published protected files and completed with exit code 0 unless
explicitly noted below.

```text
> bash tests/phase2-guard-invariants.tests.sh
phase2-guard-invariants.tests.sh: 33 passed, 0 failed

> powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/phase2-guard-invariants.tests.ps1
phase2-guard-invariants.tests.ps1: 68 passed, 0 failed

> bash tests/phase2-guard-tokenizer.tests.sh
phase2-guard-tokenizer.tests.sh: 19 passed, 0 failed
> powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/phase2-guard-tokenizer.tests.ps1
phase2-guard-tokenizer.tests.ps1: 13 passed, 0 failed
> powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/phase2-sudo-signature.tests.ps1
phase2-sudo-signature.tests.ps1: 7 passed, 0 failed
> bash tests/phase2-sudo-signature-static.tests.sh
candidate is ASCII/no-BOM and uses the PS5.1 64-hex full-XOR comparator

> python.exe plugins/sdd-quality-loop/scripts/generate-guard-invariants.py --check
exit 0
> check-risk.ps1 specs/epic-136-phase2-gates/tasks.md -TaskId T-005
Risk check passed for task T-005.
> check-placeholders.ps1 <T-005 live production files>
Placeholder scan passed.
> check-traceability.ps1 specs/epic-136-phase2-gates/traceability.json -RepoRoot . -RequireEvidence
Traceability check passed for epic-136-phase2-gates: 5 link(s).
> check-task-state.ps1 specs/epic-136-phase2-gates/tasks.md -RepoRoot .
Task state check passed for 6 task(s).
> check-workflow-state.ps1
workflow-state: ok
```

The focused invariant suites cover TEST-010 through TEST-012: deterministic
generation and exact v1 exports; stale, missing, malformed, wrong-type,
wrong-version, and read-I/O `--check` denials without mutation; CI ordering;
fixed-directory loaders; ignored CWD/PYTHONPATH/NODE_PATH shadows; and
fail-closed missing or invalid fixed modules. The preserved RED/GREEN logs and
integrated regression addendum bind the TDD sequence.

Cross-model collection now has fresh OpenAI and Anthropic PASS verdicts over
the same input digest `853a20c16192b826dbbbf736a0a4787e3f4701e918009275f18f0fe70824cc78`.
`check-cross-model.ps1 --task T-005 --feature epic-136-phase2-gates
--evaluator PASS` returned `consensus PASS for T-005 (2 panelists, 2 distinct
vendors)`.
