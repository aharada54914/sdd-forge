# RT004 Bash workflow historical-binding candidate

Date: 2026-09-09
Status: partial patch data; NOT ready for human application; not executed.
Ticket: RT-20260908-004, existing approved scope.

Candidate: `adr-workflow-bash-history-candidate-20260909.patch`
SHA-256: `890cf2e4c3ee99292f3b2c4a8db76cc866cdb655122fa2454facca1dab211144`

Actual target remains unchanged this turn:
`plugins/sdd-quality-loop/scripts/check-workflow-state.sh`
SHA-256: `15a4ef0a72c8be78c40b38e692ee7a46d8664d825e61ab99915086dae0f02d1e`

## Candidate behavior

- Calls saved-state ADR validation before the current verified-opening early
  return (actual Bash source line 826), not after it.
- Distinguishes absent extensions from null, malformed, and one-sided fields.
  Neither extension grants no ADR permission, including relocated ADR aliases.
- Checks exact-case non-symlink regular evidence paths and hashes all six
  saved round inputs before and after validation.
- Binds canonical ADR sets, precheck raw hash, design/requirements/acceptance
  pins, layer material, and deterministic input digest. It compares both
  contract reviewer manifests and actual reviewer output manifests.
- Preserves existing role-based non-ADR path restrictions and the four-layer
  manifest-superset carve-out. ADR paths are checked in raw form before legacy
  relocation. It requires calibration and B's current summary binding.
- Checks contract, precheck, integrated verdict identity; reviewer run/session
  correspondence and separation; check IDs/results; summary counts; severity
  counts and aggregated verdict agreement, including failed historical rounds.
- Does not read today's design or ADR content for a failed historical round.

These are candidate design/code properties, not proven runtime outcomes.

## Verification performed

Read the actual current workflow consumer and its existing manifest and output
validation before drafting. In-memory inspection of patch DATA verified both
hunk old/new counts, cumulative offsets, and removed-line anchors against that
actual source: 2 hunks, 239 inserted lines. Repository `git diff --check`: exit 0.
No candidate shell/jq code was executed or extracted into an executable test
copy. The actual validator hash above remains the previous RED baseline.

Primary review caught and corrected a draft jq `-e` use that would treat the
valid legacy `false` extension-presence result as an error. This correction
was made before any runtime application. Additional required core manifest
pins and B's raw summary hash were included during primary review.

## Remaining work / review cautions

This is not a complete workflow-consumer patch: the verified ADR result is
currently saved but not connected to the existing PASS-only path allowlist or
current-ADR hash/declaration validation. Consequently a valid extended PASS
would still fail later. Finish that path without broadening freshness tolerance.
Do not merge or ask a human to apply this partial candidate.

Complete the PowerShell equivalent using PS5.1-compatible primitives. Verify
the historical aggregate-verdict rules against the integration contract,
including terminal/cycle-cap states; do not assume this candidate's severity
formula is the complete terminal-state specification. Review prior-summary
binding/existence and all required historical non-ADR input relationships;
current regular-file checks alone do not prove every historical relationship.
Filesystem race and Windows reparse behavior remain independently unproven.

The real focused regression remains 2 passed / 6 failed (exit 1), as recorded
in `rt004-workflow-history-red-20260909.md`; it has not become green. Add valid
extended historical and PASS controls, divergent output/identity/count tests,
and native Windows coverage. Independent security/contract review and approved
human application are still required before testing modified protected code.
No old FAIL, reservation, task status, commit, PR, merge or issue state changed.
