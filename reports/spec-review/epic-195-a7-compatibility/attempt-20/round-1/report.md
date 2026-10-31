# A7 specification review — attempt 20, round 1

VERDICT: NEEDS_WORK
Critical: 1
Major: 0
Minor: 0

Both independent native reviewer deliveries completed. Reviewer A returned PASS;
reviewer B returned BLOCKED. The round-1 integration rule maps the one Critical
finding to NEEDS_WORK, not PASS. Original reviewer outputs and reservations are
retained unchanged.

## Finding requiring correction

Reviewer B's APPROVAL-BOUNDARY finding concerns the amendment evidence, not a
failed reviewer launch. The investigation records a standing human authorization
as an agent transcription, without an original approval timestamp, and identifies
the existing checkpoint hashes as historical rather than the currently amended
specification. This does not meet the calibration's Amendment Re-Review Context
exception for later-phase artifacts. See reviewer-b.json for the full finding.

Do not invent a timestamp, imply an old commit contains current bytes, or treat
the launch-recovery authorization as proof of a different specification amendment.
Reconcile the durable approval record and amendment snapshot before round 2.
No new reviewer reservation was made while recording this result.

## Evidence and limits

- reviewer-a.json and reviewer-b.json: native reviewer results.
- integrated-summary.json: restricted reviewer-A summary supplied to reviewer B.
- spec-review-contract.json and integrated-verdict.json: bound inputs, identities,
  counts and deterministic round result.
- Reviewer delivery proofs and reservation receipts remain in this directory.
- Original-path recovery regression success does not establish specification
  approval, native product activation, CI success, merge, or task completion.

Working checkout HEAD at integration: 654ce55d2b23b3a0cd0d72c3e45e46144399e90e.
Existing dirty work was preserved. No task status, approval, commit, push or merge
was changed by this integration.
