# Research review lifecycle follow-up

The earlier checkpoint exposed two actual integration failures: repairing a packet after NEEDS_WORK prevented the next round, and the ordinary requirements Pending-to-Passed status change invalidated a CLM-to-REQ packet. Both actual Bash/PowerShell paths now succeed while preserving changed-body and reviewer-identity rejection.

- `workflow.txt`: 20 tests, including real next-round prechecks, repaired-packet continuation, rejected forged Passed status, omitted/changed actual reviewer pins and requirements status-only preservation versus body changes.
- `owners.txt`: 8 tests, including exact original raw hash preservation, unchanged packet bytes and changed-body/duplicate-status negatives.
- `resolver.txt`: 18 existing conditional-input tests. `consumers.txt`: original research consumer tests.
- `independent-negative-cases.json`: independent failed-history resolver review, 14 cases. Only consistent failed history is admitted; wrong stage, path traversal, mixed modes, PASS, identity mismatch, missing/duplicate/mismatched pins and unlisted inputs are rejected.
- `failed-history-red.json` preserves the independent reproduction before the fix; `failed-history-green.json` reruns actual original/repaired cases after the fix. `status-transition-green.json` is a Green rerun, not a retained Red transcript.
- `guard-parity.txt`: 419 passed, zero failed across the existing runtime parity paths; the chain-invoked planner is now in the exact protection inventory.
- `caller-contract.txt`: original capability/full-profile caller contract preserved. `mirrors.txt`: frozen evidence remains intact.

Historical mode reads canonical saved failed-review records and returns a history-only marker. It establishes saved identity/pin agreement, not current-source or old semantic verification. PASS and new-review admission keep live checks. Requirements status handling reconstructs exactly one canonical Passed-to-Pending line and still requires the original raw digest; it cannot ignore body changes.

Hosted predecessor run 40196921354 had four failed jobs: two interviewer-anchor failures, one caller-heading adjacency failure, and one missing protection inventory entry for the newly invoked research planner. The interviewer placement was already corrected; this follow-up adds the planner to the exact guard inventory and regenerates runtime modules. That obsolete run was cancelled to release CI concurrency and is not counted as PASS. Final-source hosted CI remains separate.
