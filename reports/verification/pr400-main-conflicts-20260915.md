# PR 400 current-main conflict inspection

Read-only merge simulation: `git merge-tree --write-tree --name-only HEAD fcefbdf0`.
Branch head: `1b80901ade48258afe94538e53719e496b87b851`.
Result: exit 1, three conflicted paths. No checkout/index/branch change.

1. `plugins/sdd-review-loop/references/review-context-boundary.md`: numeric
   validator citations changed on both sides. Main additionally documents the
   scratch-declaration receipt extension; preserve it, not just the branch's
   line-number table. Recompute citations from the final merged validator.
2. `tests/review-context-boundary.tests.sh`: paired citation fixtures conflict
   for the same reason. Regenerate exact anchors without removing assertions;
   retain the branch's content-snapshot hash assertion and main's scratch coverage.
3. `tests/cross-model.tests.ps1`: preserve the branch's stdin drain, and main's
   raw .NET receipt writes and precomputed response. Do not reintroduce cold JSON
   serialization after the timed wait. Both timing-observer channels currently
   overlap; retain evidence semantics without weakening the two-second deadline,
   800ms margin, five iterations per runner or success assertions. Re-run on
   native Windows; a clean textual resolution alone is not proof of correctness.

The remaining validator changes auto-merge textually, which is not a behavioral
PASS. They need ADR, scratch-boundary and reservation regressions after merging.
The pending human five-document application is pinned to the current branch;
do not move its source files underneath that outstanding application request.
No conflict has been marked resolved and PR 400 is not merge-ready.
