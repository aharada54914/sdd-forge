# T-002 stage timing verification

## Approved stdin consumption follow-up — 2026-09-06

The user explicitly approved adding stdin-to-EOF consumption to the test CLI
and regression verification. This supersedes the pending-approval sentence
in the historical diagnosis below. RT-20260906-001 records the bounded scope.
Worker `collector_human_candidate` added only
`$null = [Console]::In.ReadToEnd()` to the generated worker, after the diagnostic
start/PID markers and before the hang/normal branches. Primary Astra inspected
the exact diff: no Critical or Warning found in this bounded fixture change;
production runners, deadlines, 800 ms margin, repetitions and assertions are
unchanged. The finite fixture input is discarded, not printed or evaluated.
Worker syntax parse and primary `git diff --check` passed. Independent tester
`stdin_regression` ran `rtk pwsh -NoProfile -File tests/cross-model.tests.ps1`
once: **64 passed, 0 failed, exit 0**. Primary read the saved complete output
at `/tmp/cross-model-tests.XXXXXX.log` (SHA-256
`b86eb476755735bf34d95b8a50a8e21b4a07d1d99e6b85fc60a1883a6f53784b`).
Test source SHA-256:
`2b5d30c064c43b5acd4116f582be2b1f7a124f0a38e8472269aa9f8b44c040dc`.
All GPT configuration cases and all ten GPT/Gemini boundary repetitions passed;
the prior local Broken pipe exception did not occur. Both hung cases still
exited 1, emitted no verdict, and left neither stub nor child alive. Boundary
outer elapsed times were 2816–2880 ms; these include runner overhead and are
not the child invocation's 2000 ms deadline clock. Windows execution of the
new stdin-draining source remains pending; old-head CI is not new-head evidence.
This is not a formal quality-gate PASS or a Windows timeout resolution.

## Subsequent bounded stdin diagnosis — 2026-09-06

Primary read the stub generator and both runners. The PowerShell stub emits a verdict but has no stdin-draining call. GPT redirects a combined prompt plus bundle; Gemini redirects the smaller bundle-only input. This leaves a test-double contract hypothesis open; GPT-only failure does not prove a GPT production defect.

Primary ran two small subprocess probes without modifying any repository file or rerunning the suite. `Start-Process /usr/bin/true` with `/dev/null` stdin exited 0; with the existing `tests/cross-model.tests.ps1` as stdin it raised `Broken pipe`. A controlled second probe used that same existing input and `/dev/null` stdout: `/usr/bin/true` again raised `Broken pipe`, whereas `/bin/cat` exited 0. This demonstrates that early stdin closure can produce the observed local exception on this host. It does not prove that every historical GPT failure shares that cause, and does not explain Windows boundary timeouts.

Requested explicit scope extension for a stub-only stdin drain plus regression verification. Existing authorization remains diagnostic timestamps only until answered; production timeout, margin, repetitions and assertions are unchanged. No protected edit or bypass attempted. The CI workflow at main `10ad36e` remains live (run `34008874163`), so waiting is not treated as an impasse.

Run date: 2026-09-06

Commands

- `rtk proxy pwsh -NoProfile -File tests/cross-model.tests.ps1`
- `rtk proxy git diff --check -- tests/cross-model.tests.ps1`
- `rtk proxy pwsh -NoProfile -Command '$null = $null; $errs = $null; [System.Management.Automation.Language.Parser]::ParseFile("tests/cross-model.tests.ps1", [ref]$null, [ref]$errs) | Out-Null; if ($errs.Count -gt 0) { $errs | ForEach-Object { $_.Message }; exit 1 } else { "parse-ok" }'`

Results

- Full suite run: `54 passed, 10 failed`, exit `1`
- `git diff --check`: passed
- PowerShell parse: `parse-ok`

Observed timing lines from the live suite run

- `TEST-004(c) runner=gpt iteration=1`: `elapsed_ms=2822`, `deadline_ms=2000`, `stub_launch_ms=795`, `wait_end_ms=1788656515096`, `output_complete_ms=1788656515130`, `runner_exit_observed_ms=1788656516217`, `exit=1`, `verdict=0`
- `TEST-004(c) runner=gpt iteration=2`: `elapsed_ms=2867`, `deadline_ms=2000`, `stub_launch_ms=861`, `wait_end_ms=1788656517972`, `output_complete_ms=1788656518010`, `runner_exit_observed_ms=1788656519093`, `exit=1`, `verdict=0`
- `TEST-004(c) runner=gpt iteration=3`: `elapsed_ms=2857`, `deadline_ms=2000`, `stub_launch_ms=797`, `wait_end_ms=1788656520794`, `output_complete_ms=1788656520855`, `runner_exit_observed_ms=1788656521951`, `exit=1`, `verdict=0`
- `TEST-004(c) runner=gpt iteration=4`: `elapsed_ms=2850`, `deadline_ms=2000`, `stub_launch_ms=786`, `wait_end_ms=1788656523649`, `output_complete_ms=1788656523710`, `runner_exit_observed_ms=1788656524801`, `exit=1`, `verdict=0`
- `TEST-004(c) runner=gpt iteration=5`: `elapsed_ms=2839`, `deadline_ms=2000`, `stub_launch_ms=784`, `wait_end_ms=1788656526496`, `output_complete_ms=1788656526557`, `runner_exit_observed_ms=1788656527641`, `exit=1`, `verdict=0`
- `TEST-004(c) runner=gemini iteration=1`: `elapsed_ms=2846`, `deadline_ms=2000`, `stub_launch_ms=778`, `wait_end_ms=1788656529333`, `output_complete_ms=1788656529399`, `runner_exit_observed_ms=1788656530490`, `exit=0`, `verdict=1`
- `TEST-004(c) runner=gemini iteration=2`: `elapsed_ms=2841`, `deadline_ms=2000`, `stub_launch_ms=791`, `wait_end_ms=1788656532182`, `output_complete_ms=1788656532235`, `runner_exit_observed_ms=1788656533332`, `exit=0`, `verdict=1`
- `TEST-004(c) runner=gemini iteration=3`: `elapsed_ms=2836`, `deadline_ms=2000`, `stub_launch_ms=790`, `wait_end_ms=1788656535023`, `output_complete_ms=1788656535071`, `runner_exit_observed_ms=1788656536168`, `exit=0`, `verdict=1`
- `TEST-004(c) runner=gemini iteration=4`: `elapsed_ms=2854`, `deadline_ms=2000`, `stub_launch_ms=785`, `wait_end_ms=1788656537865`, `output_complete_ms=1788656537912`, `runner_exit_observed_ms=1788656539024`, `exit=0`, `verdict=1`
- `TEST-004(c) runner=gemini iteration=5`: `elapsed_ms=2856`, `deadline_ms=2000`, `stub_launch_ms=791`, `wait_end_ms=1788656540732`, `output_complete_ms=1788656540782`, `runner_exit_observed_ms=1788656541880`, `exit=0`, `verdict=1`

Preserved failure evidence visible in the captured run output

- `TEST-003: gpt accepts unset timeout` failed with `exit=1 verdict=False`
- `TEST-003: gpt accepts empty timeout` failed with `exit=1 verdict=False`
- `TEST-003: gpt accepts huge timeout` failed with `exit=1 verdict=False`
- `TEST-003: gpt accepts its source-derived default` failed with `exit=1 verdict=False`
- `TEST-004(c)` GPT iterations 1-5 failed with `Broken pipe`

Limitations

- I do not have a separate saved transcript artifact for the full suite output beyond the live tool output captured in this session, so I am not reconstructing any additional fail lines that were not explicitly emitted here.
- I did not rerun the full suite.
- I did not modify product code or ticket state.

## Primary reviewer follow-up

The full-suite result above was reported by the independent tester, not a second execution by the primary reviewer. The primary reviewer performed these additional read-only checks without rerunning the suite:

- Executed the actual three diagnostic assignment AST nodes from the test source in memory under StrictMode Latest and ErrorAction Stop. Missing sidecar and truncated JSON both produced `-1` markers; valid JSON produced the supplied `100`/`120` timestamps. All three cases preserved the original runner exit value `91`.
- Parsed `docs/review-tickets/RT-20260906-001.yml` with Ruby YAML: PASS.
- Reviewed the diagnostic change: no verdict assertions, timeout limits, repetition counts, or product runners were changed. This is scoped diagnostic review, not a quality-gate PASS.

Reviewed test source SHA-256: `7698acf3f2dcbabe9af14eafcebf883dbe5bbedac8cbebf6ba83cd76c5b99b82`.

`output_complete_ms` records return from the stub's JSON pipeline, not an OS flush; `runner_exit_observed_ms` records return from the outer runner invocation, not the precise child-process exit. Sidecar serialization can add overhead. These measurements alone do not establish the failure's root cause.

Windows validation of this timestamp change remains pending. The existing failures remain unresolved, and the ticket remains open.
