# T-005 Panelist Clarification and Deterministic Evidence

Date: 2026-07-15

This non-frozen addendum resolves the two evidence-interpretation findings from
the first blind OpenAI panelist attempt. It does not alter the passed task-plan
or acceptance-test documents.

## TEST-012 terminology

TEST-012 has two deliberately distinct poisoning cases:

1. A same-name CWD/PYTHONPATH/NODE_PATH shadow is an **ignored shadow**. The
   loader must resolve its module only from the guard's own script directory,
   ignore the shadow, and preserve the known read-only decision.
2. The required module at that fixed script-directory location is a **fixed
   module**. A missing module or a malformed module containing an unconsumed
   v1 export is an invalid authoritative input and must fail closed.

The same distinction applies to Python, Node, and PowerShell; the POSIX
dispatcher is limited to schema/provenance sourcing and makes no guard
decision. This is the distinction already described in the native loading
contract and executed by the focused suites.

## Current deterministic evidence

The acceptance-test table remains `Planned` because it is a frozen planning
artifact. Execution status is established by saved test evidence and the
quality gate, not by rewriting that table.

Commands executed from the repository root on 2026-07-15:

```text
> bash tests/phase2-guard-invariants.tests.sh
phase2-guard-invariants.tests.sh: 33 passed, 0 failed

> powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/phase2-guard-invariants.tests.ps1
phase2-guard-invariants.tests.ps1: 68 passed, 0 failed
```

The shell suite covers deterministic generation, non-mutating stale/missing/
malformed input rejection, staged CI ordering, fixed-directory loading,
CWD/PYTHONPATH/NODE_PATH shadow resistance, and invalid fixed Python/Node
module denial. The PowerShell suite additionally covers the exact native-module
exports, PowerShell fixed-module denial, and the complete isolated human-copy
fixture contract. The preserved RED/GREEN logs and integrated regression
addendum remain the detailed TDD evidence.
