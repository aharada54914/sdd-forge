# PR381: additional PowerShell registration failure reproduced

Checkout: `/Users/jrmag/.local/share/sdd-forge-pr381-recovery-20260908`.
Base: `3971c93a5705dc15f86ba56cc62118613e4b19db`, with existing recovery changes.
Executed on macOS, not native Windows.

Command: `rtk proxy pwsh -NoProfile -File tests/design-sync-scan.tests.ps1`
(wrapped in Bash pipefail with tee to retain the complete output).
Log: `/tmp/pr381-ps-scan.cxQ97M`.
Process handle: `63300`, terminal exit 1; do not restart on observation timeout.
Result: **135 passed, 1 failed**, specifically TEST-053.
Source SHA256: `446de48c439111c190dbe78ddeea19852b6354c99edb368e69277d4ba35246ae`.

## Cause isolation

The predicate at tests/design-sync-scan.tests.ps1:825-827 reads Bash runner
source and looks for a literal suite path. The runner now obtains membership
from an inventory. Actual `bash tests/run-all.sh --list` completed with exit 0
and the exact `tests/design-sync-scan.tests.sh` entry. The PowerShell runner
still includes the PowerShell twin. Thus missing executable membership and a
failed listing command are contradicted by observation; a stale source-text
predicate explains TEST-053. Runtime scan and cross-runtime case fixtures
completed with no other counted failure.

TEST-046 only proves no new failure relative to its declared design-system
baseline; it does not turn the nested TEST-039 designed-red into a pass.

No source was edited. This adds design-sync-scan to the demonstrated stale
PowerShell consumer set, alongside the four consumers already identified in
pr381-powershell-three-suite-baseline-20260909.md. Bind a limited repair scope
before changing these completed-feature test consumers; preserve the
PowerShell conjunction, exact case, unsuccessful-list rejection and actual
full-suite verification. Do not amend historical PASS records.

## Integration state

Fresh GitHub queries still show seven open PRs and 26 open issues. PR381 head
is unchanged and its required-checks result remains failure. An in-progress
Actions query returned no runs; this is not a live CI wait. No merge or issue
closure is justified by this execution.

RT-20260909-001 separately requires explicit approval of the frozen needs
contract amendment: keep all existing mandatory dependencies and add mandatory
POSIX success. Its requires_human_decision flag remains true. Other approved
ADR remediation work remains open, so the overall goal is not declared blocked
or complete.
