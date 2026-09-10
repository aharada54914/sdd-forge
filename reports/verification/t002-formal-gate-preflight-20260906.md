# T-002 formal gate entry preflight

Target: `specs/epic-136-phase4-docs/tasks.md#T-002`
Repository HEAD: `8fa3eb8561d6f59b692ec574900f87e181145928`
This is a preflight record, not a quality-gate verdict.

## Executed checks

- `scripts/check-sdd-structure.sh`: exit 0, `check-sdd-structure: OK` (5f2061).
- Advisory `get_next_sdd_command` without arguments returned multiple active
  features. The explicit T-002 selector governs; no other feature was selected.
- `check-hook-activation-handshake.py --emit-challenge` was denied by the
  PreToolUse protection hook. No nonce was issued, no canary attempted and no
  alternate launcher used. This is not HOOK_ACTIVE.
- Physical presence check: `sdd/project-context.yaml` does not exist (99e649
  companion output 9a81e4); acceptance-tests.md and traceability.md exist.
  Installed ship gate G4 therefore permits DISABLED_LEGACY, not Capability Mode.
- Deterministic T-002 feature-scoped cycle check returned `continue`, exit 0
  (c164e9). This does not reset ticket repair cycle 4 or permit a fifth repair.

## Remaining entry mismatch

The current task is historically `Status: Done`, `Risk: high`,
`Security-Sensitive: true`, and `Cross-Model: not enabled` (99e649).
Installed ship Step 4 requires a same-invocation cross-model run for sensitive
tasks, independently of the optional Cross-Model flag. Installed
cross-model-verify prerequisites and prepare-panelist-input require
`Cross-Model: enabled` or a valid SDD_SUDO token. No root SDD_SUDO exists
(7099e5); no waiver has been established. No approval field, waiver, sudo
token, frozen report or task status was modified.

Before gate invocation, enable cross-model verification through an authorized
task-contract update and its required provenance review; do not silently waive
the verification or manufacture a panel result. Complete ticket-specific tests
on the fresh CI head before resolving the ticket and returning the task to
Implementation Complete. The current CI run is 34033392134 and remains live:
18 successful jobs, 6 running, no failures at observation 1489e3.

## Parallel PR 371 finding

Fresh PR 371 head is `9e39c396f4ca8f9abe3c9aabb090868ada17b53f` (133359).
Primary `git merge-tree --write-tree` against main
`4366438f3b243210a4ece5a17f873ca2d920600a` returned exit 0 and tree
`c3999b8f3d62ebe5346ce7d78e1adda41e300b82` (f9930c).
This proves conflict-free synthesis, not correctness or merge readiness.
The independent explorer corrected its previous reversed comparison: main
contains e72e4dcd affecting the golden comparison that failed in PR 371.
However the existing pr371-pr381-evidence-preflight record also identifies
PR 371 schema/producer defects repaired in PR 381. A main-only refresh must
not be represented as resolving those defects or issue 346's human disposition.
No branch was pushed, no PR merged, and no issue closed by this preflight.

## Fresh Windows CI completion

At the same PR400 head/run, Windows test job 101486988389 completed successfully
(19aa51). Its cross-model PowerShell step ran 12:37:41–12:38:23 UTC and succeeded;
the complete Windows job finished 12:40:44 UTC. This establishes execution of
the required Windows step on the refreshed head, not resolution of the original
intermittent deadline cause. `gh run view --job --log` remained unavailable
until the whole run finishes (f0cb38); a direct job-log read was rejected for
terminal escape sequences (e2e621). No raw log counts are inferred from those
unsuccessful reads. At observation 7b4aac, 19 jobs succeeded and five remained
in progress; the run was not yet an all-CI PASS. Later live step observation
64e881 showed only four jobs still in progress. No rerun was requested.

## Terminal CI result

Run 34033392134 completed successfully on the same exact head (6f2903).
All 24 workload jobs succeeded. The additional `required-checks` aggregation
also succeeded. `gh pr checks 400 --required` exited 0 and reported all four
required checks passing (51bc2a). PR read f4d5d8 confirms head
`8fa3eb8561d6f59b692ec574900f87e181145928`, all 25 Actions checks successful,
CodeRabbit successful, PR OPEN, and REVIEW_REQUIRED / BLOCKED.

The T002 formal cross-model/task-contract prerequisites above remain
unresolved. No merge or ticket resolution was performed. The existing
run-specific heartbeat was paused after this terminal result; there is no
new run to monitor. This does not complete the overall integration goal.

## Completed-run log verification

The previously unavailable job logs are now readable. Primary reads bind the
following results to run 34033392134, not the older green diagnostic variant:

| CI host | Job ID | PowerShell suite | Bash suite |
|---|---|---|---|
| Windows | 101486988389 | 64 passed, 0 failed | Not asserted here |
| macOS | 101486988404 | 64 passed, 0 failed | 70 passed, 0 failed |
| Ubuntu | 101486988432 | 64 passed, 0 failed | 70 passed, 0 failed |

Sources: primary completed-log reads 90eac5, 2d688b, 1e13ef. Commands use
`gh run view 34033392134 --repo aharada54914/sdd-forge --job <ID> --log`
with a complete-output-consuming filter for the cross-model result lines.

Windows TEST-004(c) emitted all ten measurement records (five per runner),
each exit=0 and verdict=1. The logged elapsed milliseconds were:

- GPT: 1890, 1863, 1842, 1850, 1887.
- Gemini: 1819, 1818, 1785, 1810, 1897.

All ten records carried wait_end_ms, output_complete_ms and
runner_exit_observed_ms. Every record ordered these three timestamps before
its recorded runner deadline. These are the documented observations, not
claims of OS-flush completion or exact child-process exit. The suite still
records deadline_ms=2000 and five iterations per runner. This successful run
does not exercise a new failing boundary diagnostic and does not retrospectively
classify the original intermittent failure. RT-20260906-001 remains open;
its stale pending-CI prose is superseded by this non-frozen verification
addendum, not by silently rewriting historical evidence or declaring Done.

## Subsequent explicit scope approval and local validation

The human explicitly authorized changes beyond the previously presented scope
for Issue #288, PR #245, and PR #400. This does not waive required CI,
independent review, protected-file enforcement, or frozen-artifact re-binding.

For PR #400, T-002's `Cross-Model` declaration in
`specs/epic-136-phase4-docs/tasks.md` was changed from `not enabled` to
`enabled`; primary diff inspection confirmed that single-line delta (647a75).
The prior missing-declaration observation is superseded by this local change.
The old head's green CI does not validate this uncommitted amendment.
Provenance task-review attempt 3, round 1 was launched using the prescribed
`--provenance-rereview` precheck. At observation 35af34 it had not terminated
after 12 minutes, with `check-workflow-state.sh` child processes still present.
No successful precheck or reviewer launch is asserted. Diagnosis is in progress.

For PR #245, the authorized archive-pipeline replacement in the separate
worktree `/private/tmp/pr245-verify.mAAGWT/worktree` passed the primary
independent `/bin/bash tests/review-agent-isolation.tests.sh` execution:
exit 0 and `ok: sequential reviewer and evaluator contexts are distinct,
authorized, and hash-chained` (05d3cc). The primary diff review found one
hunk only: archive to a temporary file, require a nonempty archive, validate
its table, then extract; producer/extractor failures remain errors (9db1c2).
`git diff --check` exited 0 (bae7f8). This is scoped regression evidence,
not the formal quality-gate verdict or main-integration validation.

For PR #381 T-006, the human reported the generated-capabilities suites
successful with Bash and PowerShell exit 0 and 24 checks. Independent local
reruns also reported 24 passes, zero failures, zero designed-red checks on
both hosts. The correct mirror is
`specs/epic-190-a2-capability-registry/human-copy/`, not the pillar-C mirror.
Its seven manifest entries passed checksum verification (f722b1), and the
delegated byte comparison found all seven identical to the live worktree.
The manifest SHA-256 is
`cb7eb6800d988664e934bda35e62ce62efc421dc518a226bed66377d02be5025`.
Logs are `/private/tmp/pr381-verify.7id2mX/generate-gate-capabilities.sh.log`
and `/private/tmp/pr381-verify.7id2mX/generate-gate-capabilities.ps1.log`.
The earlier agent observation about the pillar-C mirror was a wrong-target
inspection and is not evidence about T-006. Formal review remains outstanding.

No task was marked Done, ticket resolved, issue closed, or PR merged by these
local validations.

### Precheck terminal result supersedes the pending observation

Only this invocation's identified processes (40765, 40780, 40964, 40965,
40966) were terminated after the prolonged wait. The original process exited
143 (518cf7); it was not a validation success. Running the same unchanged
precheck with system Bash also selected for child scripts
(`PATH=/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/Users/jrmag/.local/bin`)
terminated with exit 1 (ddad4d). The output was:

```text
workflow-state: epic-136-phase4-docs: stage-provenance: task plan hash is stale
NOTE: task-review-precheck: canonical workflow-state validation failed; proceeding under --provenance-rereview (task-stage evidence re-binding in progress).
ERROR: task-review-precheck: persisted spec contract does not match canonical current inputs
```

Thus the currently proven blocker is predecessor-spec contract validation,
not an indefinitely running task precheck. No gate script or check was changed.
The differing Bash outcomes do not, by themselves, establish the underlying
shell hang's root cause. Per task-review-loop STEP 1, reviewer invocation is
halted on this nonzero result while the exact predecessor mismatch is diagnosed.

Primary inspection found a concrete failing conjunct at
`plugins/sdd-review-loop/scripts/lib/review-precheck-common.sh:176`: both
reviewers must bind the current stage-specific calibration digest.
For the selected spec attempt 2 / round 2 contract, both recorded
`spec-review-calibration.md` digests are
`1ddd4ed250e30c0eb78a3d644adfefd21d0af5ea311444b526c8d840fc0649b8`;
the current file digest is
`537f776558cf4b4a99ee455a974857a67e249242dce5806e23d37d6802f2a385`
(primary comparison 21410d). This is evidence of at least one failed predicate,
not proof that every other predicate passes. An agent returned task-stage
calibration hashes instead; those are not evidence for this spec-stage error.
No historical contract hash was overwritten to manufacture agreement.

### Specification recovery precheck passed

The ordinary spec-review reset command was executed with system Bash:
`spec-review-precheck.sh epic-136-phase4-docs 3 1 --reset`.
It exited 0 (403f90), verified the preceding terminal evidence, preserved
attempts 1 and 2, and created the new attempt 3 / round 1 precheck.
The script performed its prescribed `Passed` to `Pending` transition for
`requirements.md`; no substantive requirement or acceptance-test content
was amended. New precheck input digest:
`695c692edeaf78ead6fc3a88b886516734af43f8798ae11ef468c4ee52ab4e8f`.
This is successful precheck evidence only; the two independent spec reviewers
have not yet been launched and specification PASS has not been re-established.

GitHub refresh ff9ff8 still shows six open PRs (245, 371, 381, 390, 394, 400)
at their prior heads. Latest run read 700d24 contains completed runs, including
PR400 success and PR394 failure; no active CI wait is claimed for either.
