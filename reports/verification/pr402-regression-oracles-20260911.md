# PR 402 regression oracle reconciliation

Status: read-only source investigation; no implementation or runtime PASS.
Pinned PR head: f6e7427c9648085ca86a0d0835fa28df8e5ff300.

The head and open PR body were rechecked through GitHub on 2026-09-11.
Run 34285985088 remains terminal FAILURE, not an active wait. The three
native test jobs fail the WFI-016 staged/live comparison. No retry was issued.

## Additional test gap established from the contribution

`git show <head> -- tests/guards.tests.sh tests/hooks.tests.ps1` shows that
the added Python/Node assertions use exit 0 and `grep -qF` over raw output;
the added PowerShell assertion uses exit 0 and a wildcard over raw output.
None of these three new assertions parses permissionDecision. They could
accept an allow result containing the expected reason text. The current
production implementation is not claimed to emit that invalid combination;
this is a weakness in what the regression proves.

The actual emitters at the pinned head establish the oracle:
`sdd-hook-guard.py:291`, `sdd-hook-guard.js:685`, and
`sdd-hook-guard.ps1:282` emit a JSON object in copilot mode, with exit 0 even
on denial. Exit mode instead uses exit 2 for denial. Consequently exit 0
alone is not evidence of allow, and must not be changed to expected exit 2
for copilot tests.

## Required assertion matrix for the existing fix

Apply every row to Python, Node and PowerShell. Use isolated fixtures without
an active sudo flag; do not mutate real task approvals. Preserve the existing
separate sudo-denial tests unchanged.

| Command payload | copilot decision | Reason class | exit-mode code |
|---|---|---|---|
| Primary approval only | deny | primary approval | 2 |
| Second approval only | deny | second approval | 2 |
| Both approvals | deny | primary approval (existing precedence) | 2 |

All copilot rows also require process exit 0 and one parsed JSON object.
Assert the reason against an independently supplied expected message/class,
not by importing the implementation's own constant. Consume the entire output
before evaluating it; do not introduce early-exit grep pipelines. In new test
source, assemble guarded approval literals from noncontiguous pieces per WFI-012.

Mixed input must not be expected to report the second reason merely because
it contains that field: the Python checks at lines 1626–1642 and Node checks
at lines 1630–1652 run the primary denial before the second denial when sudo
is inactive. Changing that precedence is not part of this repair.

## Next action

Implement these assertions in the existing approved PR repair path after its
recovery-entry restriction is cleared, alongside exact two-file mirror and
manifest synchronization. Run actual original guard tests on the reconciled
integration tree, then independent verification and all mandatory CI. Do not
merge solely on mirror synchronization, and do not close issues 295/380 solely
on this one finding. No guard copy was executed during this investigation.
