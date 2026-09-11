# RT004 human application results — 2026-09-10

Status: Bash scoped regressions GREEN; PowerShell workflow regressions RED.
Not formal gate PASS, CI success, native Windows proof or merge approval evidence.

## Received evidence

User-supplied complete transcript:
`/Users/jrmag/.codex/attachments/33bb55d1-e796-4d06-ab65-00988c9d5767/pasted-text.txt`
SHA-256: `6099b86283d9e19612fb52662cf36ee1986dd452ccb94482d4d71ab98a75e7d8`.
Reported backup/log directory: `/tmp/sdd-rt004-stage-snapshot.foGZI9`.
Reported applied Bash validator SHA-256:
`0bffcea97568257c86997245aa72542860ac9ef5cff9836efd4411d80dd6104a`.
This receipt records human execution, not a new agent execution or direct
protected-source hash verification.

## Results and scope

- `--late-contract-only`: 5 passed / 0 failed, test and log exits 0.
  The late-contract-rescue receipt records an actual fixture mutation, and the
  rejection assertion now passes. This supersedes the earlier 4/1 RED for this
  scoped case only; the original failure record is preserved.
- `--history-pin-only`: 6 passed / 0 failed, test and log exits 0.
- `--workflow-only`: 73 passed / 52 failed, test exit 1, log exit 0.
  Transcript line-count audit: Bash 64 passed; PowerShell 9 passed / 52 failed.
  Do not sum the selectors as independent coverage: their cases overlap.

All 52 failures are PowerShell negatives accepting input (exit 0) where the
fixture requires rejection (exit 1). They cover malformed/missing prechecks,
ADR sets and paths, interrupted outputs, conflicting layers, duplicate JSON
members, invalid UTF-8, output/summary bindings, and required check identities.
The overall script correctly reports failed flag 1. No commit, push, merge or
official review-state mutation was performed by the human script.

## Next action

The supplied application script targets Bash only. Existing PowerShell repair
slices must not be blindly applied in sequence: the composition report records
overlapping insertion anchors and incomplete independent/runtime verification.
Current composed PowerShell candidate SHA-256 observed as data:
`9763f14b18310c9f83cd29788c849a3e272608e380f4ff65596d5bf4fe3cbfb1`.
The older composition report hashes are historical, not proof of the current
candidate's review. Inspect the current composition and source provenance,
complete independent review, then obtain human application if still protected.
Do not rerun the already-applied Bash human script: its original-source hash
precondition is intentionally no longer satisfied.

Remaining snapshot lifecycle/platform checks and full RT004 scope remain open.
No historical FAIL is rewritten, and no task is marked Done.
