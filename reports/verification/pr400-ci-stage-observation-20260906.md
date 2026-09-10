# PR400 diagnostic CI observation — 2026-09-06

## Fresh cycle-4 terminal check

### Refreshed head pushed; new CI pending

PR400 now points to `8fa3eb8561d6f59b692ec574900f87e181145928` after the
main-reconciliation merge commit (`30ed7d`) and successful push (`04964d`).
New run `34033392134` was observed queued for that exact head (`3317f4`).
The existing 15-minute CI heartbeat was updated to this run and reactivated.
The PR remains Draft; no main merge, formal quality-gate PASS, or issue
closure is implied.

The delegated MCP checks reported ci-mcp 148/0, local-env-mcp 51/0, and
all three typechecks successful. Its sdd-forge-mcp process did not finish;
the original session handle could not be recovered. Primary sampled child
PID 96121 (`432d39`): the stack was blocked in Bash `heredoc_write` / `write`
before executing the Python here-document. `lsof` resolved that executable
to Homebrew Bash 5.3.9 (`1c86d2`); the script's stdin was `/dev/null`
(`397e5d`). This identifies the sampled wait site, not a Windows timeout
root cause. Primary terminated only this test's verified process chain
(`c3bc45`); that interrupted run is not counted as passed.

Primary reran unchanged `npm test` with the same Node 24.13.0 and explicit
PATH selecting `/bin/bash`: 247 passed, 0 failed, 0 skipped, exit 0
(`b85ab4`), log `/tmp/pr400-main436-mcp-node24-system-bash.log`.
No production code, fixture, timeout or assertion changed. Together with
the merged-state cross-model 64/0 result below, this supports publishing
the refreshed branch for CI, not completion of the task gate.
Before commit, primary rechecked staged whitespace (`c5b6f1`), exact two
parents (`9aa25a`), no unstaged MCP changes (`f4108e`), and byte identity
of all staged MCP paths to main (`fa519e`). Only those nine staged paths
were committed; unrelated unstaged and untracked files remain untouched.

### Subsequent main reconciliation

Fresh GitHub API reads on 2026-09-06 (`e943a7`, `977929`) resolve main to
`4366438f3b243210a4ece5a17f873ca2d920600a`; the ae4dc main reference below is
historical. Compare PR head 913dec to main 4366438 (`8343d6`) reports main
37 commits ahead and 4 behind that PR head, with nine MCP package/lock/bundle
files changed on the main side. Do not reverse the base/head comparison.

Primary verified the index was empty and existing unstaged/untracked changes
were outside those nine incoming paths, then ran `git merge --no-commit
--no-ff 4366438f3b243210a4ece5a17f873ca2d920600a` (`970dae`): automatic merge
succeeded, stopped before commit. The nine staged files are byte-identical
to that main commit (`bf6034`), and staged diff whitespace check passed
(`e4a1ae`). Existing unrelated changes are preserved and not staged.
Merged-state verification is now running; no merge commit or push yet.
The old PR-head CI result is not a CI result for this new merged state.

Primary merged-state local check: `pwsh -NoProfile -File
tests/cross-model.tests.ps1` with redirected stdin `/dev/null` completed
64 passed, 0 failed, exit 0 (`a8053d`), log
`/tmp/pr400-main436-cross-model.log`. Test source SHA-256 remains
`30d834639e5ec0de077018bcbe999d601dde8879f96f3ae58a577f546c626947`
(`15df11`). This is macOS PowerShell, not native Windows or fresh CI.
MCP checks are delegated separately; no new diagnostic repair cycle began.

Formal gate preparation must also honor current T-002
`Security-Sensitive: true` (`084934`): the ship skill requires same-invocation
cross-model verification before quality-gate even though `Cross-Model: not
enabled`. Existing `Status: Done` is historical; the open review-ticket fix
must follow the prescribed return-to-Implementation-Complete transition,
without silently bypassing that precondition or modifying frozen evidence.

On 2026-09-06, GitHub confirmed run 34016430635 completed successfully at exact head 913dec2b1bf15dbd5a09650c663771975679f461: all 25 jobs succeeded (d7976a). CodeRabbit status is also SUCCESS (973471). These results supersede the in-progress observations for that same head below, not historical failure evidence. Current main is now ae4dc095ecde352f980ef06dec469b9b286ad10c after PR #376 (4e7f93). Latest-main refresh and independent quality verification still remain; this is not proof of historical Windows timeout root-cause resolution, task Done, or merge readiness. No suite rerun, ticket closure or PR mutation performed in this observation.

## Cycle-4 candidate — current observation

Candidate `913dec2b1bf15dbd5a09650c663771975679f461`, run
`34016430635`, Windows job `101440895481`: the job API reports
`Test cross-model gate (pwsh)` successful, started 2026-09-06T06:34:18Z,
completed 2026-09-06T06:34:57Z (primary chunk d948ee). The Windows job
itself is still running; its Bash cross-model step is still pending.
This is a step-status observation only, not a count or a completed-log
inspection. No failure was reproduced in this step, so it cannot resolve
the historical timeout cause. The older heads and failures below remain
historical evidence, not the current candidate's status. Full mandatory CI,
exact current-base reconciliation and the independent gate remain pending.

The same Windows job subsequently completed successfully. Primary read the
completed job log through the GitHub API, stripping terminal control codes
before displaying only measurement/result lines (chunk e318ab, exit 0).
At 06:34:57.2646110Z the PowerShell cross-model suite reports 64 passed,
0 failed. All ten boundary cases have exit=0, verdict=1 and both scalar
timestamps present. Gemini iteration 5 records deadline=1788676497818,
wait-end=1788676497024, output-complete=1788676497061,
runner-exit-observed=1788676497217. The output interval is 37 ms in this
sample; it is not evidence about the earlier failing main sample.
The Windows Bash cross-model step was skipped, not passed. Keep the suite,
platform and candidate distinctions when aggregating acceptance evidence.

## Later-head failure comparison — primary log inspection

### Missing-sidecar limits, verified against the correct source

Fresh GitHub PR400 head remains `c3b3dd21f56a923baf0ca5ac3c8b9ec6f359398d`, OPEN/Draft. Primary directly read `tests/cross-model.tests.ps1:190-277` and the Gemini runner `plugins/sdd-quality-loop/scripts/run-panelist-gemini.ps1:148-187`. The stub captures wait-end in memory, then emits its verdict via ConvertTo-Json, captures output-complete, and only then serializes both fields to a sidecar. Its write catch intentionally suppresses diagnostic failures. The outer reader also converts missing or malformed sidecars to null and reports -1 (`tests/cross-model.tests.ps1:678-686`). Thus absent values cannot distinguish interrupted work, serialization/write failure, or malformed output. The actual runner's timeout message uniquely selects its WaitForExit-false / kill-tree branch at lines 172-176, but does not identify the stub's unfinished stage.

A delegated report cited collection-layer.tests.ps1 and unrelated GPT line ranges instead of the requested cross-model/Gemini paths; those citations and its proposed new stdin-probe fields are not accepted as task evidence or approved scope. The existing ticket allows wait-end/output-complete/outer-return timestamps only, not arbitrary extra stage fields. A possible next diagnostic within that vocabulary is persisting wait-end independently at its observation point, preserving all timeout and success assertions; it still needs scoped preflight/review because the additional I/O changes measurement overhead. No diagnostic implementation, task status change or resolution is claimed here.

The historical green run below is not the current head's result. Primary read sanitized completed-job logs through the job-log API on 2026-09-06. PR390 job `101421310980` reports 56 passed / 8 failed: GPT boundary iterations 1–5 and Gemini 2, 4, 5 fail. No captured runner reason appears in those measurement lines. Primary also inspected PR400 job `101424396065` (run `34010138792`): 62 passed / 2 failed, Gemini boundary iterations 4 and 5. Both captured diagnostics explicitly say the CLI exceeded SDD_PANELIST_TIMEOUT=2s and was terminated. Both sidecar fields are -1; this does not establish the child never finished waiting because timing persistence happens later.

The preceding successful Gemini iteration 3 records wait end 1788668182965, output complete 1788668183694, deadline 1788668183755, outer return 1788668183886. Thus the observed output interval was 729 ms and completion preceded the runner deadline by only 61 ms; outer return after the deadline still passed. This is evidence of tight timing in that successful sample, not proof of the subsequent failures' cause. Read-only source analysis is assigned to determine the limits of absent-sidecar evidence and any smallest diagnostic-only remedy. No timeout/margin/assertion change or CI retry was performed.

The first raw-log request refused terminal escape sequences. The subsequent request passed output only through a control-sanitizing Node filter and selected measurement/diagnostic/result lines; it did not display the unsanitized log. Primary tool chunks: 424f72 (PR390), 2480e1 (PR400).

Target head: `588ff2809e6085a84f0deebb9384aa57c7cb1d90`.
Run: https://github.com/aharada54914/sdd-forge/actions/runs/34003924105

The primary observed the existing run through `rtk proxy gh run view 34003924105 --json status,conclusion,jobs`. No retry was requested.

At the latest observation, both `test (windows-latest)` and `test (ubuntu-latest)` reported their `Test cross-model gate (pwsh)` step as completed with conclusion `success`. The corresponding macOS step remained pending. Overall run status was `in_progress`, with 17 successful jobs and seven running jobs; no job had concluded failure.

This is a step-status observation, not a raw-log review, test-count assertion, full mandatory-CI PASS, or proof of a product fix. This head changes only diagnostic timestamps and preserves the known failing local result (54 passed / 10 failed). A successful timing-sensitive run cannot by itself resolve the earlier failures. Inspect the completed job logs for the recorded timing measurements and retain the historical failures before judging the remaining diagnosis and merge conditions.

The existing 15-minute heartbeat `sdd-forge-ci` monitors this exact run. A7 collector scope expansion remains unanswered; this observation is not authorization to change it. No merge or issue closure occurred.

## Completed Windows job log — later observation

Subsequent status correction: A7 collector repair and regression-test scope expansion was explicitly approved by the user. The unanswered-approval sentence above is historical, not a current blocker. A later same-run observation records 22 successful jobs and two running jobs (`test (macos-latest)` and `version-gates (windows-latest)`), no failures; the macOS cross-model PowerShell step has now also succeeded. This is not yet full required-CI completion.

Job `101407598990` completed successfully. While `gh run view --log` refused logs until the entire run completed, the documented GitHub job-log API returned this completed job's log. ANSI/control characters were stripped before displaying only measurement/result lines. No run was restarted.

At `2026-09-06T01:34:00.3617104Z`, the cross-model suite reported `Results: 64 passed, 0 failed`. All ten TEST-004(c) measurements (five GPT and five Gemini) reported `exit=0 verdict=1`, with wait-end, output-complete and runner-exit-observed timestamps present. The observed outer return preceded the runner's absolute deadline by 414–581 ms. The timestamps retain their documented limitations: output pipeline return is not OS flush, and outer return is not the exact OS process-exit event.

One particularly discriminating measurement at `01:33:58.3089924Z` was Gemini iteration 4: `elapsed_ms=2034`, `deadline_ms=2000`, `runner_deadline_epoch_ms=1788658438738`, `stub_launch_ms=807`, `wait_end_ms=1788658437961`, `output_complete_ms=1788658438136`, `runner_exit_observed_ms=1788658438306`, `exit=0 verdict=1`. The outer elapsed interval exceeding 2000 ms did not mean the runner exceeded its own absolute deadline: return was observed 432 ms before that deadline. Do not equate these differently anchored clocks when diagnosing historical failures.

This supplies a fresh Windows passing observation, not a reproduction or root-cause explanation of the prior Windows failures. No failure-stage timestamps were produced in these ten successful cases. Local 54/10 failure evidence remains valid and unresolved. At this observation the overall run was still in progress (18 successful jobs, six running), so required-CI completion and merge readiness remain unproven.

## Completed macOS and Ubuntu logs — subsequent observation

The same sanitized job-log API inspection confirmed `Results: 64 passed, 0 failed` for macOS job `101407598939` at `2026-09-06T01:40:07.0004410Z` and Ubuntu job `101407598981` at `2026-09-06T01:34:48.0353522Z`. Thus the PowerShell cross-model suite passed on all three CI hosts at this head, while the unchanged local 54/10 failure remains unresolved.

All ten macOS PowerShell boundary measurements had `exit=0 verdict=1` and populated stage timestamps. For example, GPT iteration 1 recorded deadline `1788658780257`, wait end `1788658779475`, output complete `1788658779522`, and outer runner return `1788658780665`: output completed 735 ms before the deadline, but outer return was observed 408 ms after it. These outer-return measurements include runner post-processing and must not be interpreted as the child's exact process-exit time or a proven missed child deadline. The Windows-only return-before-deadline range above does not generalize to other hosts.

The current overall observation is 23 successful jobs and one running Windows version-gates job. No full-CI conclusion, merge, issue closure, or product repair is claimed.

## Terminal observation

Run `34003924105` completed with conclusion `success`: all 24 matrix jobs and the aggregate `required-checks` job succeeded (25 jobs total). A fresh PR query confirmed head `588ff2809e6085a84f0deebb9384aa57c7cb1d90`, matching this run, and all named checks successful. PR #400 remains Draft and reports merge state BLOCKED. This is full CI success for the diagnostic change, not resolution of the historical local 54/10 failures or completion of its independent task gate. No merge or issue closure was performed. With the sole monitored run terminal and no replacement target, the dedicated `sdd-forge-ci` heartbeat was paused.
