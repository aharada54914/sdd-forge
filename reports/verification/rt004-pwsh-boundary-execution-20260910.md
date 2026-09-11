# RT004 PowerShell boundary observer execution

Date: 2026-09-10. Verification only; no production edits or verdict changes.

## Human application and verified inputs

The human reported application with backup `/tmp/sdd-rt004-observer.PUui0f`.
Agent-side SHA-256 checks matched all reported applied files:

- `tests/impl-review-adr-inputs.tests.sh`: `f8969898f43cdbca3a3c98101a57a1047242d097d4974f668ef91616cb105896`
- `tests/fixtures/adr-pwsh-boundary-receipt.py`: `7d029dcdae2f864dcc3b284713a7912afcc57b471f7dc0757b16b6de7f1fbedc`
- `tests/fixtures/adr-pwsh-read-boundary.ps1`: `8873bb25b2cf0ce706e66ad3c27bcf92dc9e0fc7423c626814198739a5912799`
- Original production PowerShell validator: `291ee7531594757d6ebc04c144bb8b35938f7715ae76665c9bdf723df09b1ff5`.

## Original-path execution

Command: `rtk proxy bash tests/impl-review-adr-inputs.tests.sh --pwsh-boundary-only`

Exec session 13230 completed with exit 0:
`ADR workflow history: passed=7 failed=0`.
The complete emitted diagnostics and JSON receipts are in the thread tool
outputs; this document is a summary, not a substitute raw transcript.

Both Bash and PowerShell legacy/current-singleton controls passed. The three
PowerShell observer runs completed and passed receipt validation, including
negative checks rejecting incomplete receipts:

| Mode | Breakpoint hits | Target changed | Validator exit |
|---|---:|---|---:|
| control | 1 | false | 0 |
| early-poison | 0 | true | 1 |
| poison | 1 | true | 0 |

All receipts bound the original validator hash above and breakpoint line 2138.
Early corruption produced `stage-provenance: ADR impl review evidence validation failed`.
Corruption at the later breakpoint did not change the accepted outcome.
This establishes the tested temporal boundary for these inputs, not general
filesystem race safety or native Windows behavior. In particular, it does not
prove the incomplete admission acquisition candidate safe.

`git diff --check` scoped to the three applied test files exited 0.

## Remaining scope

The original-path full workflow-history selection was also rerun:
`rtk proxy bash tests/impl-review-adr-inputs.tests.sh --workflow-only`.
Session 69716 completed with exit 0:
`ADR workflow history: passed=140 failed=0` (the prior 137 cases plus three
new observer cases). The seven-case focused run overlaps this selection;
it is not 147 distinct tests. Post-run SHA-256 checks confirmed all four
listed files unchanged.
Formal review, admission repair, canonical repository state, mandatory CI and
main integration are not satisfied by this seven-case result. No commit,
push, merge, issue closure or task Done transition occurred.
