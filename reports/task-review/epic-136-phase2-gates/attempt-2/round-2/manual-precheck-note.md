# Manual Precheck Note: task provenance re-review attempt 2 round 2

Date: 2026-07-14T01:30:14Z

## Deviation

The PowerShell precheck accepted provenance mode and reached input hashing, but
Windows PowerShell 5.1 lacks the script's `SHA256.HashData` call. Canonical
workflow state is intentionally non-PASS after round 1 NEEDS_WORK. The same
issue-#61 manual launch fallback is therefore used.

## Human authorization

The human authorized specification/task reflection and continuous Sudo-mode
execution. The round-1 reviewer finding is not waived.

## Manual checks performed

- Round 1 has two ledger-reserved reviewers, persisted outputs, NEEDS_WORK
  verdict, and hash-bound contract.
- T-005 changed and is now one canonical-generation/runtime-loading concern.
  New T-006 is one handle-relative publication/rollback concern, is Approved by
  the active sudo audit mark, remains Planned, and depends only on T-005.
- All six tasks have lifecycle-valid approval/status fields, valid high or
  critical risk with `tdd`, canonical Blockers syntax, and an acyclic graph.
- Traceability maps T-005 to TEST-010..012 and T-006 to TEST-013; the full layer
  traceability validator passed.
- Exact current hashes and composite input are persisted beside this note.

## Result

Manual precheck passed under the issue-#61 fallback for provenance round 2.
