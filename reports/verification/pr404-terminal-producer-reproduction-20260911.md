# A7 terminal producer: executable reproduction

Source commit: e603dc93b268980ffbc51bf7e2aae53b24815c4b
Issue: #195, OQ-004 / AC-026; also affects AC-009's frozen function contract.
Status: reproduced, NOT fixed and NOT a passing acceptance result.

## Actual code and results

Both original shared libraries were loaded directly from this checkout; no
library copying, patching, mock collector, fixture-directory creation, or
external provider invocation was used. The trace and sequence were reset in
memory before each call. `spec-review` has terminal state `PASS` in
`tests/loops/loop-inventory.json`; `quality-gate` instead expects
`Escalate-Human`, so it must not be used as a PASS control.

| Runtime | Observed | Function result | Trace value |
| --- | --- | --- | --- |
| Bash | PASS | exit 0 | PASS |
| Bash | BLOCKED | exit 1 | BLOCKED |
| Bash | pass | exit 1 | pass |
| PowerShell | PASS | True | PASS |
| PowerShell | BLOCKED | False | BLOCKED |
| PowerShell | pass | True | pass |

Every listed trace contains exactly one `done-transition` event, producer
`done-transition:assert-terminal`, sequence 1. Failed comparisons must not
produce a successful transition. The PowerShell lowercase case additionally
exposes a return-value parity defect, independent of trace collection.

Reproduction from this checkout:

```bash
rtk proxy bash -c 'source tests/lib/loop-driver.sh; for observed in PASS BLOCKED pass; do _LOOP_EVENT_TRACE="[]"; _LOOP_EVENT_SEQ=0; code=0; assert_terminal spec-review "$observed" || code=$?; printf "observed=%s exit=%s trace=%s\n" "$observed" "$code" "$_LOOP_EVENT_TRACE"; done'
rtk proxy pwsh -NoProfile -Command '. ./tests/lib/loop-driver.ps1; foreach ($observed in @("PASS", "BLOCKED", "pass")) { $script:_LOOP_EVENT_TRACE="[]"; $script:_LOOP_EVENT_SEQ=0; $result=Test-LoopTerminal -LoopId spec-review -Observed $observed; Write-Output "observed=$observed result=$result trace=$script:_LOOP_EVENT_TRACE" }'
```

The diagnostic commands themselves exit zero because they print observations;
that is NOT a test-suite success or a product verdict.

## Root cause and bounded repair

`tests/lib/loop-driver.sh:1558` emits before comparing expected and observed.
`tests/lib/loop-driver.ps1:1245` does the same and uses case-insensitive `-eq`.
The bounded repair is to reject a nonmatching state before trace emission,
using case-sensitive comparison in both runtimes. Preserve the exit-code
precondition, collector-failure propagation, public signatures, and existing
valid terminal states. Do not redefine every terminal as PASS: several loops
legitimately terminate with BLOCKED or Escalate-Human.

Regression coverage must include each registered loop's exact terminal,
mis-cased and nonmatching states, nonzero exit, unknown loop, unchanged trace
and sequence on rejection, and a successful call following a rejected call.
Existing TEST-018/TEST-019 must still assert terminal-event ordering.

## Contract boundary

`acceptance-tests.md:13` pins both function hashes and comparison semantics;
line 30 explicitly records the unsatisfied producer condition. T-005's
approved scope permits only its sanctioned collector call, not a semantic
rewrite. A repair therefore needs the corresponding AC-009 hash contract,
OQ-004 disposition and TEST-026 coverage reconciled and reviewed together.
Do not silently rebaseline the hashes or mark the old review PASS.

The separate three-document human batch addresses the current attempt-5
round-1 findings; it does not implement this producer repair or close OQ-004.
Recheck line references and source hash before consuming this report after
subsequent branch changes.
