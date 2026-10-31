# PR #513 mirror synchronization checkpoint

CI run 36896966697 at c04a8d80edd26a6be9d62a2149dd1238eef12ef2 failed Windows Phase 2 invariants and POSIX shard 3. The completed job logs (110486269643 and 110486269431) identify the same cause: four stale guard mirrors, not a runtime guard assertion failure.

The existing sync-human-copy-mirrors.py first reported exactly four stale mirrors, then synchronized them and four entries in two manifests. All 17 pending entries were preserved. No production guard, test, workflow, approval, or verdict was changed by this synchronization.

Local checks on macOS:
- human-copy-mirror-freshness.tests.sh: exit 0, 6 passed, 0 failed, 17 informational pending.
- phase2-guard-invariants.tests.ps1: exit 0, 55 passed, 0 failed, 1 pre-existing skipped install-path assertion.
- git diff --check and staged diff check: exit 0.

Six synchronization files were committed as 3a06933f6f9b5f51781dca4dc4c0f40b94f6382f and pushed normally to codex/a8-copilot-tool-names. New CI run 36898163621 is pending, not successful. PR remains draft; independent formal review and actual host acceptance remain unproved. Do not reuse old-head CI as current proof.

## Follow-up observation

The same run advanced to in_progress: 22 jobs succeeded, 14 remained unfinished,
and none had failed at this observation. This is not an overall CI success.
Review request comment 5936723434 pins the exact head above; CodeRabbit response
5936725563 confirms "Review triggered." A completed review verdict is still
pending. No task status, approval, or merge state was changed.

## Current-head review finding

CodeRabbit completed its review of `3a06933f6f9b5f51781dca4dc4c0f40b94f6382f`
with state COMMENTED and one actionable finding: `Object.hasOwn` in native
Copilot input checks may violate the supported Node.js version contract.
This is an unverified review finding, not an accepted fix or formal gate verdict.
A local read-only source search was denied by PreToolUse before execution;
no alternate route was used to repeat that protected-source read or apply a fix.
The same CI run currently has 29 successful jobs, seven unfinished, zero failed.
PR remains draft; do not merge while the finding and acceptance gaps are open.
