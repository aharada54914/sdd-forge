# PR #381 stale workflow candidate audit

Read-only investigation against `/private/tmp/pr381-verify.7id2mX/worktree`, HEAD 3971c93a5705dc15f86ba56cc62118613e4b19db with existing approved dirty repairs preserved.

The generator suite's unexpected FAIL is distinct from its DESIGNED-RED counter. The live workflow includes `posix-regression` at `.github/workflows/test.yml:24-36`; the draft `specs/epic-190-a2-capability-registry/drafts/human-copy-candidate/.github/workflows/test.yml.candidate` omits it. The live-job superset check in `tests/generate-gate-capabilities.tests.sh:451-517` correctly rejects that omission. The investigator's earlier unsupported classification as pre-existing designed-red is not accepted.

Primary comparison of the entire draft against the live file (git diff --no-index, output 837ee1) shows additional stale content: the draft lacks all 22 Bash/PowerShell steps for the eleven issue #194 suites, retains version-gates timeout 20 rather than 45 minutes, and specifies Node 20 rather than 22 in all three MCP jobs. Thus copying only the missing job would satisfy a narrow check while still rolling back unrelated current functionality. No such patch was applied.

Required correction scope: reconcile the workflow candidates against the complete current live workflow, retaining all current jobs, steps, runtime settings and both capability generation/vendoring drift checks; update affected bundle manifests and freshness documentation; verify both shell and PowerShell suites and negative removal controls. Do not change assertions, hide DESIGNED-RED, or infer task Done from a passing local suite.

RT-20260809-002 remains open at review_cycles 3 and explicitly describes protected application as a human action. Its historical proposed resolution does not alone establish approval for this newly identified whole-workflow refresh. The latest consuming-grep approval covers a different one-line test change, not this scope. Follow the sanctioned protected-file path; do not use the draft suffix to evade a denied operation. No protected edits, bundle application, formal extra review attempt, commit, push or merge performed by this audit.
