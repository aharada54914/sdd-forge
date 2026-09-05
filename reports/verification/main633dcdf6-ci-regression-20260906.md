# Main post-merge CI failure

Date: 2026-09-06 JST
Status: CI completed with failure; diagnostic-only remediation approved and under review; no CI rerun yet
Commit: 633dcdf6d3289054f832ebbed066e6680e25d645
Run: https://github.com/aharada54914/sdd-forge/actions/runs/33975094357
Failed job: https://github.com/aharada54914/sdd-forge/actions/runs/33975094357/job/101330280640

## Authoritative observation

At the initial observation the workflow remained in progress, but `test (windows-latest)` had completed with failure in step 18, `Test cross-model gate (pwsh)`. At that time `gh run view --job --log-failed` refused logs until the whole workflow completed; the completed job's direct GitHub API log endpoint was available. Its terminal control sequences were stripped before inspection.

Relevant raw log values:

```
2026-09-05T15:39:17.7523405Z measurement: TEST-004(c) runner=gemini iteration=5 elapsed_ms=2776 deadline_ms=2000 runner_deadline_epoch_ms=1788622757403 stub_launch_ms=789 exit=1 verdict=0
2026-09-05T15:39:17.7534854Z FAIL: TEST-004(c): gemini near-boundary completion iteration 5 (exit=1 verdict=0 stub_launch_ms=789 budget_ms=2000)
2026-09-05T15:39:17.8237926Z Results: 63 passed, 1 failed
2026-09-05T15:39:19.3437046Z ##[error]Process completed with exit code 1.
```

The log also reports Gemini iteration 4 passing and GPT iteration 1 elapsed 1895ms, exit 0, verdict 1. Earlier timeout/descendant-liveness and missing-verdict gate checks pass. These are fixture results, not live provider results.

## Diagnosis boundaries

The observed nonzero runner exit is real; a timeout is not yet proven. The harness captures stderr/stdout into `$script:panelistOutput` (`tests/cross-model.tests.ps1:136`) but never prints that value, including at this failure. A timeout, child nonzero exit, launch/wait exception, or later verdict-validation failure can therefore produce the observed exit/verdict pair. Distinguish these before attributing the failure to scheduler/startup overhead, an overconstrained fixture, or a runner defect. Do not relax the production timeout, skip the assertion or repeatedly rerun until green without this distinction and contract review.

A bounded read-only diagnosis was assigned to the existing lightweight agent, with no product edits, protected-file workaround, CI rerun or fabricated approval authorized by that assignment. Main monitors the same existing run (watch session 3605), not a replacement execution.

PR 363's pre-merge success does not establish post-merge main success. No issue was closed based on this still-failing run. Current main's loops-routing jobs pass across all three OSes; PR 381's historical four-registration failure is a separate integration concern.

## Identical-tree control comparison

`git diff --stat f507ecf32e25719a27b19c298dd812570a8b3ab8 633dcdf6d3289054f832ebbed066e6680e25d645` is empty. The PR head whose run 33973516462 passed and the failing main run therefore have identical tracked content. Relative to the previous main 1e32a69c20f05f02bb9a00fa669013939f1f654f, the merge adds only the 244-line Draft WFI-057 document.

Prior successful Windows job 101326119016 reports all ten near-boundary iterations passing and suite total 64/0. Its GPT iteration 4 has elapsed_ms=2372, deadline_ms=2000, stub_launch_ms=928, exit=0, verdict=1; Gemini iteration 5 has elapsed_ms=1830, stub_launch_ms=738, exit=0, verdict=1. These measurements demonstrate different test outcomes on identical source trees. They do not by themselves prove which portion of elapsed time is inside the runner deadline, or whether the production runner or the fixture owns the defect. Do not attribute this failure to a code modification in the documentation-only merge.

## Primary review of the diagnostic hypothesis

The lightweight reviewer suggested fixture scheduling jitter, runner deadline accounting, and a success-case/expiry-case mismatch. These remain hypotheses, not a confirmed cause. In particular:

- The stub targets the **end of its wait**, not actual process completion: `tests/cross-model.tests.ps1:190-209` waits until deadline minus 800ms, then assembles and serializes JSON through line 222, then exits through a `.cmd` wrapper on Windows. The comment at lines 598-602 claiming completion cannot move is stronger than the implementation guarantees. Actual wake, output and process-exit timestamps are missing.
- `$script:panelistOutput` is assigned at line 136 and has no read site in the suite. The failure report cannot distinguish `run-panelist-gemini.ps1:172-185` timeout, child error and exception branches. Existing elapsed/launch measurements do not supply this missing classification.
- The owning original task is `epic-136-phase4-docs/T-002`, already Done, high risk (`tasks.md:230-258`). The A7 T-004 retry authorization is not evidence of authorization to reopen this different frozen task. No matching current remediation ticket was found by the scoped boundary/timeout/suite-name search in `docs/review-tickets/*.yml`; this is not a claim that all task plans were exhaustively searched.

Next diagnostic change should expose the captured failure reason and distinguish intended wake from observed completion while retaining the same timeout, assertion and repetition count. It requires the applicable review-ticket/specification route and protection checks before editing the test. No test or runner has been modified in this investigation.

At the initial diagnostic check, Windows main test failed while Ubuntu main test succeeded; macOS main test plus all three version-gates jobs were still running. No replacement CI execution was launched.

## Wait audit at 2026-09-05 15:48:53 UTC

The same run remains in progress. Only `version-gates (windows-latest)` is still running. Its `Test bump-version.sh loop-gate prerequisite (pwsh)` step began at 15:40:12 UTC (8m41s elapsed at this observation). In the identical-tree prior green run 33973516462, that step ran from 15:10:45 to 15:18:53 UTC (8m08s), and the whole Windows version-gates job took 27m53s. This supports continued observation; it is not evidence that the current step is hung. No cancellation or restart is warranted solely from these timings.

The prior green macOS portable-precheck step took 1m36s (15:13:10–15:14:46 UTC). A separate terminal-state query confirms current `test (macos-latest)` completed successfully, including that step from 15:44:30 to 15:46:58 UTC (2m28s). Success was checked directly, not inferred from disappearance from the running-job list.

## Terminal audit on 2026-09-06 JST

`gh run view 33975094357 --json status,conclusion,jobs` now reports `status: completed`, `conclusion: failure`, 23 successful jobs, zero running jobs, and two failed jobs: `test (windows-latest)` and the aggregate `required-checks`. The Windows version-gates job completed successfully. This execution is terminal and must no longer be described as a live wait.

The unresolved source failure remains the cross-model fixture result recorded above; aggregate failure is not a second independently diagnosed product defect. Ticket `docs/review-tickets/RT-20260906-001.yml` records the proposed diagnostic-only change with `requires_human_decision: true`. No human approval of that ticket has been received, and no protected test edit, rerun, additional merge, or issue closure was performed on the strength of this failed run.

## Subsequent human approval and remediation review

On 2026-09-06 the user explicitly approved safely printing failure error text and adding diagnostic logs only to the already-Done T-002 test. This supersedes the approval-wait state above. The ticket now records the genuine human decision; the previously proposed comment correction was removed from its scope. Timeout, margin, repetition, assertions, runner behavior and CI requirements remain unchanged. Issue 194's evidence exception is not included in this approval.

Worker `/root/t002_failure_diagnostic` added failure-only logging in `tests/cross-model.tests.ps1`. Primary review cycle 1 found the custom control-character sanitizer omitted U+061C (Arabic Letter Mark), and requested a smaller, bounded, single-line escaped representation covering all non-ASCII controls. This is a review finding, not a PASS. The worker reports test session 51591 encountered TEST-003 failures and emitted diagnostics for failing TEST-004(c); the final suite result and saved evidence remain unverified. Primary's attempt to read that session returned `Unknown process id 51591`, so the owning worker was asked to check it, without launching a duplicate suite or inferring success.

## Final diagnostic-only diff and local verification (2026-09-06)

Review cycle 2 removed an unused sanitizer helper. The final test-only diff adds one `Write-SafeDiagnostic` helper and one call in the existing TEST-004(c) failure branch. It uses JSON EscapeNonAscii, a fixed diagnostic prefix, a 2048-character input cap and a 4096-character escaped-payload cap (plus truncation marker and fixed label). Raw control characters, newlines and Unicode direction controls cannot become terminal commands or independent CI workflow-command lines. Only the captured fixture runner output is passed; no environment dump or credential collection was added. This is control-character escaping, not a general-purpose secret-redaction guarantee.

The primary independently checked PowerShell parse errors and exercised the actual TEST-004(c) AST branch with synthetic failure and success inputs. Exit 91 remained 91, the failure counter incremented, and the error reason was emitted safely; the success branch incremented the success counter and emitted no diagnostic. ESC, U+061C, C1 controls, Unicode line separators, CR/LF and a workflow-command-shaped payload were covered, along with empty and oversized input. An initial probe selected a different existing branch with the same condition and failed its harness assertion; selecting the branch containing the new diagnostic call corrected that harness error. It is not product regression evidence or pre-implementation TDD RED evidence. No verified pre-implementation RED record is available.

After the worker confirmed both its executions were terminal, the primary ran the final source independently:

```sh
rtk proxy pwsh -NoProfile -File tests/cross-model.tests.ps1
```

Session 80674 completed with **54 passed, 10 failed, exit 1**. Failures were four GPT TEST-003 valid-timeout cases, GPT TEST-004(a) wall-clock bound (32274ms versus 10000ms; stub and child both no longer alive), and all five GPT TEST-004(c) near-boundary iterations. All five Gemini near-boundary iterations passed. Each failing GPT boundary iteration now exposed `run-panelist-gpt: failed to start codex: Broken pipe` as a bounded single-line diagnostic while retaining the original FAIL. These are stub-based local results, not live-provider authentication checks. No same-host baseline comparison proves the failures pre-existing, and they do not establish the cause of the original Windows Gemini failure.

`rtk proxy git diff --check -- tests/cross-model.tests.ps1` passed. Timeout, 800ms margin, repetition count, assertions, production runners and required CI were not changed. No persisted contract/verdict/traceability fields were added by the code change. Windows verification and the independent quality gate remain pending. No new CI execution, commit, push, merge, Done transition or issue closure is claimed. The ticket remains open; diagnostic visibility is improved, not the original failure resolved.

## Read-only Broken-pipe isolation (2026-09-06 continuation)

Host: PowerShell 7.6.2, macOS 26.5.2. Two independent probes used `Start-Process -RedirectStandardInput /Users/jrmag/sdd-forge/README.md -RedirectStandardOutput /dev/null -PassThru -NoNewWindow`, without modifying repository files or invoking a vendor CLI:

| Child | Observation |
| --- | --- |
| `/usr/bin/true` (does not consume stdin) | `System.IO.IOException: Broken pipe`, 192ms |
| `/bin/cat` (consumes stdin) | exit 0, 15ms |
| `/bin/sleep 1` (does not consume stdin) | `System.IO.IOException: Broken pipe`, 1232ms; `Start-Process` never returned a process to the caller before the exception |

The current GPT runner invokes `Start-Process` with redirected input before reaching its bounded `WaitForExit` (`plugins/sdd-quality-loop/scripts/run-panelist-gpt.ps1:247`). The test worker records timestamps, optionally waits/spawns a child, and emits JSON without consuming stdin (`tests/cross-model.tests.ps1:190`). This supports a local stdin/child-lifecycle interaction rather than a real Codex authentication failure. It also supplies a concrete explanation to investigate for the 32274ms lifecycle case: synchronous launch/input handling can precede the bounded wait. These minimal probes do not prove every failing suite case has that cause or explain Windows Gemini's original failure. No fixture behavior or production runner was changed; such a repair is outside the diagnostic-only ticket scope.

Fresh remote observation also found Dependabot PRs #390–#399 and new CI, replacing several old dependency PRs. Run 33994414714 (#399, head ccba716fc8c4f0e865f3beb00ce4be54c55f581c) has live macOS jobs; run 33994410347 (#398, head 317fc58525b317e92e9fdf48073d0d3d9e372e08) has a failed Ubuntu local-env MCP job and a still-running macOS test. These are specific live executions, not reruns launched by this diagnostic work. The prior claim that no CI is live is historical and is superseded by this observation.
