# Manual Precheck Note: epic-136-phase2-gates / attempt 2 / round 1

Date: 2026-07-13T23:29:45Z

## Deviation

The automated reset command
`spec-review-precheck.sh epic-136-phase2-gates 2 1 --reset` stopped before
creating the round with `previous terminal contract is invalid`. Attempt 1 has
a persisted PASS verdict and contract, but the shipped validator rejects that
legacy/manual-fallback evidence shape. This is the review launch precheck defect
tracked in issue #61; no gate finding is waived.

## Human authorization

The human selected option A, authorized the frozen specification amendment,
invoked `sdd-sudo` for 24 hours, and instructed continuous execution through
Phase 2 Done. That is explicit authorization for this narrowly scoped issue-#61
manual-precheck deviation. Independent reviewers, identity reservations,
deterministic validation, and all quality decisions remain mandatory.

## Manual checks performed

- The repository structure check passed; only existing advisory entries for
  `CLAUDE.md` and `docs/architecture` were reported.
- Requirements, acceptance tests, calibration, report roots, feature slug,
  attempt 2, round 1, and non-replay destination were checked directly.
- Attempt 1 contains a terminal PASS integrated verdict and
  `spec-review-contract.json`; it is retained unchanged.
- `Spec-Review-Status` was restored to `Pending` as the reset transition.
- Current requirements, acceptance, calibration, and composite hashes are
  recorded in `precheck-result.json` beside this note.
- Reviewer identities will be reserved sequentially in the canonical identity
  ledger immediately before their fresh isolated launches.

## Result

Manual precheck passed under the temporary issue-#61 fallback.
