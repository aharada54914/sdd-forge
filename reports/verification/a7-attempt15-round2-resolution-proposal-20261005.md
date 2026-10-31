# A7 attempt 15 round 2: bounded resolution proposal

Candidate only. Historical reviewer outputs and frozen inputs remain unchanged.

## AC-OBSERVABLE

Proposed clarification for AC-026 and TEST-026:

The Bash and PowerShell inventory suites must exercise all four local producer branches: a successful terminal comparison emits exactly once and last in its round; mismatch, nonzero exit, and missing expected state each emit nothing. No upstream dependency or skip allowlist can waive these four assertions. TEST-018 retains its successful-transition golden-trace assertion. TEST-019 retains its successful-transition golden-trace assertion when its context-present integration is applicable; only that integration follows AC-010 and AC-034. A skipped integration is not evidence that it passed, and local inventory success does not prove integration success.

Before submitting the next review, sweep AC-026, TEST-026, TEST-019, AC-010 and AC-034 across all admitted feature documents. Resolve normative contradictions without changing the four mandatory branches or weakening completion evidence.

## APPROVAL-BOUNDARY

Keep the historical broad-approval transcription and its unavailable original timestamp truthful. Do not backdate a new approval. A new explicit scoped response may be recorded with its actual observation date and exact text, then bound to the amended input hashes and amendment checkpoint. Until that response exists, this proposal supplies no approval and does not resolve the Critical finding.

## Delivery boundary

The applied history-caller hashes match the supplied values. Existing post-application evidence records 56 successful Bash/PowerShell fixture cases. Both independent review first turns completed, but their integrated result remains NEEDS_WORK. This proposal does not change task status, reservations, verdicts, Git history, CI state or installation state.
