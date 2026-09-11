# PR #402: native Windows staging failure

Status: diagnosed; not fixed, not ready to merge.

PR head: f6e7427c9648085ca86a0d0835fa28df8e5ff300
Base tested: 4366438f3b243210a4ece5a17f873ca2d920600a
Actual CI merge commit: 53f75aac029e1a9e8e3f93dadc93ef9b56c63db5
Run: https://github.com/aharada54914/sdd-forge/actions/runs/34285985088
Windows job: https://github.com/aharada54914/sdd-forge/actions/runs/34285985088/job/102261582219

The completed Windows job log was retrieved through the job logs API while
the overall run was still active. The normal run-log command declined to
return logs until run completion. Terminal control sequences were stripped
for inspection; GitHub's raw job log remains the primary evidence.

At 2026-09-08T22:32:17Z the Phase 2 suite reported:

    out of sync: plugins/sdd-quality-loop/scripts/sdd-hook-guard.py
    out of sync: plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1
    FAIL: WFI-016 staged targets are byte-identical to live (no stale staging)
    phase2-guard-invariants.tests.ps1: 50 passed, 1 failed, 1 skipped

The source of this assertion is tests/phase2-guard-invariants.tests.ps1:1027
through its final assertion at line 1055 in the current checkout: it hashes
each bundle target and its live counterpart and rejects unequal hashes.
The PR's merge-base diff changes the Python and PowerShell primary-approval
heuristics but has no changes under specs/epic-136-phase2-gates/human-copy.
Thus the observed stale-staging failure has direct source/diff support.
Do not confuse a two-tip diff against newer main with this contribution diff;
replacing the bundle with the old branch snapshot would regress newer changes.

This is not evidence of the near-boundary timeout failure seen on #394:
both runners completed all five TEST-004(c) iterations in this run, with
exit 0 and verdict 1. Those successes do not erase #394's historical failures
or establish that its fixture repair is unnecessary.

## Scoped repair and verification

1. Reconcile the selected guard change against current main; preserve all
   newer safety changes. Do not copy the old branch's entire bundle.
2. Through the applicable approved task and protected publication path,
   synchronize both changed guard mirrors and their exact manifest entries.
   Determine whether the existing bundle also tracks each changed test;
   synchronize those only where the bundle contract requires it.
3. Keep the WFI-016 comparison and all existing tests unchanged in strength.
   Require exact bundle hashes, full guard parity / reason assertions,
   existing Phase 2 suites and fresh native mandatory CI success.
4. Complete formal review and quality verification before changing Draft or
   merging. Keep #295 and #380 open for their remaining independent findings.

No protected files were changed, no job was retried, and no review verdict
was changed by this investigation. Repair implementation attempts: zero.

## Subsequent native POSIX observations

Ubuntu job 102261582294 failed at 2026-09-08T22:35:01Z and macOS job
102261582543 failed at 2026-09-08T22:39:50Z. Both raw job logs identify the
same two Python/PowerShell live-versus-staged guard paths and the same
WFI-016 byte-identity assertion, followed by exit 1. This establishes the
failure on all three native platforms, not just a Windows-specific issue.
At this observation 18 jobs succeeded, three failed, and the three
version-gates jobs were still running. The overall run was not complete.

## Exact integration-tree manifest audit (2026-09-09)

Fetched `refs/pull/402/merge` and read the immutable tested tree
`53f75aac029e1a9e8e3f93dadc93ef9b56c63db5` directly with `git show`.
No checkout, candidate execution or protected publication was performed.
All 12 manifest entries match their staged bytes. Exactly two live targets
differ from their staged copies; the other ten are identical, including
`tests/guard-parity.tests.sh` and the protected-file application helper.

| Target | Existing staged / manifest SHA-256 | Tested live SHA-256 |
|---|---|---|
| sdd-hook-guard.py | 0202c8f32f8810d77ba438a965f6b57213fb907f1a3c724f318cda9fd7b19d90 | 651b34cf0fe150f1b8dfedc61a567ec97b39b13ed8e907c0f1a7fb1e8c301444 |
| sdd-hook-guard.ps1 | 8a20021958d84e1ae7e5a239a2500dc73f15289158a68e905c90d3d5f317d7e1 | 3002dc8eb662c98f5b6645a115bd9faf85ece005bc5acc0a1991ca3dc0eb3794 |

Thus the minimal synchronization scope for this exact tested tree is two
mirror files plus their two entries in one manifest. These hashes must be
recomputed if the integration base or guard implementation changes; they
are not authorization to publish the old branch snapshot wholesale.
This byte audit does not replace behavioral tests or formal review.

Later observation: 20 jobs succeeded, three failed, and Windows
version-gates remained in progress. No re-run or merge was requested.

## Terminal run observation

Run 34285985088 is now completed with conclusion failure. Windows
version-gates job 102261582182 completed successfully. All 21 non-test
component jobs succeeded; the three native test jobs failed, followed by
the required-checks aggregate failure (25 total jobs). Thus waiting for
Windows did not clear the diagnosed staging defects. No automatic retry
was requested; synchronization repair, formal review and fresh CI remain.
