# Existing workflow-state regressions after human application

Date: 2026-09-09
Checkout: /Users/jrmag/sdd-forge

| Command (prefixed with rtk proxy) | Exit | Result |
|---|---:|---|
| bash tests/workflow-state-registry.tests.sh | 0 | registry and bounded migration records valid |
| bash tests/workflow-state.tests.sh | 0 | Shell workflow-state validation fixtures passed |
| pwsh -NoProfile -File tests/workflow-state.tests.ps1 | 1 | canonical repository workflow state failed at line 11 |

The two successful suites emit one summary each, not a case count. No
invented count is attached. The separate 96-subcase reopening matrix is
recorded in `rt005-reopening-green-20260909.md`.

The PowerShell suite stops at its canonical-repository prerequisite, before
its malformed-registry and accumulation fixtures. Its primary diagnostic:

```text
workflow-state: epic-136-phase4-docs: stage-provenance: impl integrated verdict is not a valid PASS
Exception: /Users/jrmag/sdd-forge/tests/workflow-state.tests.ps1:11
Line |
  11 |      throw "not ok: canonical repository workflow state failed"
     |      ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | not ok: canonical repository workflow state failed
```

It also emits two A8 and three A7 investigation amendment-growth tolerance
notices; those are not the failing condition and are not suppressed.
Full raw output is retained in this thread's exec output for session 45640.
The successful Bash suite runs isolated fixture data, while PowerShell begins
with the live repository, so their exit difference does not establish a
runtime-parity bug. Restoring valid phase4-docs formal provenance remains
necessary; weakening its validator would not satisfy this test.

No implementation, test, registry, historical review verdict, task status,
commit, push, merge, or issue closure was changed during this run. All three
processes are terminal. Native Windows execution and formal quality-gate
approval remain unproven. These results do not establish merge readiness.
