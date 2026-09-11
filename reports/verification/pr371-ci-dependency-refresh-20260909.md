# PR371 CI dependency refresh

Checked PR head: 9e39c396f4ca8f9abe3c9aabb090868ada17b53f.
GitHub main and local origin/main agree at
4366438f3b243210a4ece5a17f873ca2d920600a.

## Exact failed jobs

Run 33256788058 used historical merge b9608d4b68295bd5a741efbed8ff3ffac745d6f4,
not today's main. Linux job 99111814881 and macOS job 99111814858 both failed
test 52, live shell comparison, with:

    risk-adaptive-layer: verdict mismatch (shell exit 1)
    'pass' !== 'fail'

The assertion is in task-state-golden.test.js:51, called from line 72.
Linux reports 241 passes / 1 failure / 0 skipped. This is a deterministic
comparison failure in these logs, not evidence of an ongoing CI job or timeout.
The assertion does not expose the underlying shell detail; the historical
orphaned-commit explanation is supported by the subsequent fix history, not
independently proven by this assertion alone.

Commit e72e4dcd adds checkout-dependent evidence handling and is included in
main. PR371 lacks those changes. The current local RT005 mixed-failure repair
must also be preserved: hashes still match the recorded verified sources:

- shell-runner.ts: a5c1f8a86bb5731499b9ad657631aa7d56fff962f6125db6db252b13aabdb814
- environment-dependence.test.ts: 233032beb6496589799c8a9cf3d925db3d29d427fb8e57a7e6f5e8abad5feb36

See rt005-mixed-failure-fix-20260908.md for existing 251-pass package evidence,
ordinary independent review, and the outstanding formal lifecycle gate. No
new test run or formal PASS is claimed here. Do not weaken the strict mixed
content/environment failure comparison to obtain green CI.

## Integration feasibility

git merge-tree --write-tree of the exact main and PR heads exited 0 with tree
c3999b8f3d62ebe5346ce7d78e1adda41e300b82. This wrote only Git objects: no branch,
index or checkout was changed. The prospective diff from main has 10 files,
953 insertions and 19 deletions. There are no textual conflicts for these exact
heads; this does not establish semantic compatibility or CI success.

The historical Windows test job 99111814795 remains a separate failure:
its final suite reports 60 passed / 4 failed, followed by exit 1. No Windows
fix or successful rerun is established here.

## Next integration actions

Complete RT005's formal gate and retain its negative controls before declaring
MCP comparison remediation complete. Reconcile PR371's ten adversarial-review
files with PR381's stricter schemas and corresponding producers/tests; neither
PR is redundant merely because file names overlap. Then validate a combined
exact-head candidate and rerun every required CI job. Do not rerun the old
historical merge and mistake it for current-base integration evidence.

No commit, push, merge, review-verdict change or issue closure performed.
