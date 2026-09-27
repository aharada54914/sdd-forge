# PR #512 Windows receipt repair

User authorization: additional Windows repair and validation, 2026-09-27.
Prior head: `9f0628cf70af5940fd03614cedb224fcfbb4937c`.

## Observed failure

[Run 36320614469, Windows-heavy job 108623599924](https://github.com/aharada54914/sdd-forge/actions/runs/36320614469/job/108623599924) failed after the synthetic Gemini runner timed out. Its empty phase receipt caused `Regex.Matches` to throw on a null input, aborting subsequent cases. The timeout remains a separate failure; its exact cause is not established by an empty receipt.

## Bounded repair

Only `tests/cross-model.tests.ps1` changes. Read the phase receipt once and normalize empty content to an empty string; missing or duplicate records still cannot satisfy boundary timing. Add empty/complete/duplicate/partial parser regression cases. Drain redirected stdin, open the diagnostic file before the near-deadline wait, and remove a redundant final stage-file write. No production runner changes.

Preserved: 2-second timeout; 5 iterations per runner; 200ms target margin; deadline-minus-300ms lower bound; deadline-bound child output; successful process wait; exit 0; verdict presence; no forced kill. Parent log-capture time is not proof of the child's exact exit time.

## Local verification

macOS, PowerShell 7.6.2:

- Old parser with actual empty-file `Get-Content -Raw` input: reproduced `Value cannot be null. (Parameter 'input')`.
- PowerShell parser: no syntax errors.
- `pwsh -NoProfile -File tests/cross-model.tests.ps1`: **89 passed, 0 failed**, exit 0. Both runners completed all 5 boundary repetitions with successful waits and no cleanup kills. All vendor CLIs were synthetic fixtures; no external panelist was invoked.
- `git diff --check`: exit 0.
- Independent read-only reviewer `/root/windows_fixture_review`: no findings; confirmed unchanged success criteria. This is a diff review, not the formal quality gate.
- Latest fetched main `3b155fb21aa5cf10ac0811865dc8815b6f103cc3` is an ancestor of the prior head.

Windows verification remains pending on the new commit. This report does not claim timeout recovery, formal gate success, live-host activation, task completion, merge, or Issue closure.
