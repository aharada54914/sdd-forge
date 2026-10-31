# Current delivery evidence — 2026-10-12

This addendum supersedes only the disposition of the unresolved PowerShell failure in `premerge-authority-20261011.md`. The user now requires investigation to completion rather than acceptance as an unexplained risk. Historical records and verdicts remain unchanged.

Public candidate: `be9c13829581cf5e80ed8abcece74a718eadf14c`, PR #558. The preparation helper verifies the clean checkout and retrieves run `38150318997`, requiring the exact candidate head and success for all 37 jobs. Its separately pinned CI summary is the executed CI evidence, not this prose.

On 2026-10-12, the public candidate's installer integration, idempotency, and install/uninstall matrix suites ran sequentially in separate PowerShell processes. All succeeded; the matrix reported 21 passed, 0 failed. Local log: `/tmp/sdd-pr558-installer-sequence-20261012.log`, SHA-256 `c580a0af0c866f30f14c020c419f95eecd425f32051d8d70a5ac69d89dd0e7c9`. These are isolated fixture installations, not production installation evidence.

This successful sequence does not identify the cause of the historical 20-pass/1-fail matrix result. The original assertion remains unavailable in the examined truncated tool output. Root cause is not yet established; this condition must not be represented as resolved or waived.

Pre-merge evaluation and post-merge Done remain separate. Current GitHub observation: OPEN, REVIEW_REQUIRED, BLOCKED. No merge or post-merge verification has occurred. A pre-merge finding must distinguish unfulfilled post-merge criteria from defects that block merging; it must not grant Done.

## Follow-up evidence and blocking conditions

Live GitHub recheck on 2026-10-12 confirmed that run `38150318997` completed successfully for the exact public head above: all 37 jobs, including `required-checks`, succeeded. PR #558 remains OPEN / BLOCKED / REVIEW_REQUIRED. Both existing reviews have state COMMENTED, not APPROVED; one refers to the older head `2f1ea5bab59609af66323f053a356a45f0666e49`. Neither constitutes the required approval of this delivery.

The historical failure is associated with tool call `call_d71d1aa17ed745cab3fd53c6f2bdc79e`, output chunk `9a9701`, process session `98200`. Its stored output reports 20 passed / 1 failed for `tests/install-uninstall-matrix.tests.ps1`, but the assertion is inside a 715-token omitted span. The final process output, chunk `251cbc`, confirms exit 1 without restoring that assertion. The inspected later matrix, full-run, installer-sequence and diagnostic logs do not recover it. No particular target or root cause can therefore be asserted from this record.

Do not replace the historical failed verdict with a later successful run or describe the omitted assertion as fixed. Further root-cause proof requires recovering the untruncated assertion or reproducing a specific failure against the historical candidate and demonstrating its correction. Current successful regressions are separate evidence. Required third-party approval is also still absent. Until these conditions and the fresh pre-merge evaluation are satisfied, do not merge, mark Done, or start the four-part successor architecture change whose sequencing requires completed delivery first.

## Superseding user decision and merge observation — 2026-10-12

Scope: T-004 delivery acceptance evidence only. Owner checkout HEAD is `9ce19abe90df0cb83e385f96855e4843318a8807`; this previously untracked addendum is updated without changing implementation, frozen reports, approvals or task status. Existing dirty changes remain untouched. Validation is the live PR/run API and the already recorded exact-head regressions; this is not an independent verdict.

The user explicitly authorized bypass merge of PR #558 and accepted later successful runs as resolution of the earlier PowerShell failure for delivery purposes ("558についてはバイパスマージして良い 後続で成功してるなら原因解消してるでよい"). This supersedes the earlier acceptance disposition above: historical root-cause reconstruction is no longer a delivery blocker. The historical failed run remains failed; the missing assertion is not reconstructed and no specific technical cause is claimed. The later exact-head CI and successful installer sequence are the positive acceptance evidence.

GitHub reports PR #558 MERGED at `2026-10-11T23:46:38Z`, with source head `be9c13829581cf5e80ed8abcece74a718eadf14c` and merge commit `9b16ffba39a090cd3cf2305e986341e24096b835`. The authority/evidence record is https://github.com/aharada54914/sdd-forge/pull/558#issuecomment-6115254249. The prior OPEN/BLOCKED observations above are historical, not current.

Post-merge run https://github.com/aharada54914/sdd-forge/actions/runs/38185550821 targets that exact merge commit. The subsequent live API check confirmed completed/success with all 37 jobs successful, including required-checks, and no pending or failed jobs. This supersedes the earlier queued observation. Fresh quality-gate acceptance remains required before Done; no task status or old review verdict is changed by this addendum.
