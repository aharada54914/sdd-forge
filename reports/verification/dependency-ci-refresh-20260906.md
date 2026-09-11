# Dependency CI refresh — 2026-09-06

## Latest verified results

Queue cleanup: a repository-wide check found stale workflow_dispatch run31123738887, created2026-08-06 for docs/wfi-021-gate-masking at393181283b1d8db5186897dd9b01d261ec0a94a3, still queued with zero jobs. Primary verified corresponding PR223 merged2026-08-07 (merge bfaec376e79877c18450334c387f1f97eab29dec) and the remote branch no longer exists. Canceled only that obsolete queued run; GitHub confirmed status completed / conclusion cancelled / jobs empty. No branches, history, or evidence were deleted. This cleanup is not successful CI evidence for any current PR.

Final primary verification: PR400 run33998162792 at head0898a27a8549eed768c762878f832dad3e1eb28d completed FAILURE, with 23 successful jobs and two failed jobs: test (windows-latest), job101392202970, and required-checks, job101395529815. No pending jobs remain. The Windows version-gates job succeeded. This supersedes the live observations below. The same-run checks also confirmed PR399 run33994414714 SUCCESS and PR396 run33994318684 / PR398 run33994410347 FAILURE. No rerun, merge, quality-gate PASS, or issue closure follows from these observations. All monitored runs are terminal; stop their existing heartbeat rather than polling completed runs indefinitely.

Run 33994414714 (PR399 head ccba716fc8c4f0e865f3beb00ce4be54c55f581c) completed SUCCESS, with no failed or pending jobs. This supersedes the live observations below; it does not establish SDD approval or main integration.

PR400 run33998162792 Windows job101392202970 completed FAILURE: cross-model suite 60 passed / 4 failed. New diagnostic output explicitly reports the 2-second CLI timeout for GPT TEST-004(c) iterations 1/2/3 and Gemini iteration 5. GPT elapsed/launch measurements were 2503/511, 2650/614, 2582/506 ms; Gemini was 2420/530 ms. This establishes the failure classification for this run only, not the scheduling root cause or equivalence with previous Windows failures or macOS Broken pipe. Remaining workflow jobs were live at observation. No rerun, merge, ticket resolution or gate PASS occurred. Read-only explorer windows_deadline_diagnosis is examining the test/runner timing contract; behavioral changes remain outside the diagnostic-only ticket.

Issue66 remains open after primary verification of knowledge-mcp main39177299f7692a72066ae20cb8fde1299400e58c. Its pinned USERGUIDE lines28–43 expressly support manual registration only and no automatic installer, while Issue66's 2026-07-10 addition requires install-time Claude Code and Codex marker-block registration. Primary posted this concrete unmet condition on the issue; open status itself is not a blocker or evidence. Existing implementation and earlier gates do not prove the later addition.

Primary review of explorer windows_deadline_diagnosis rejected relaxing the Windows assertion: tests/cross-model.tests.ps1 lines217–235 already derive the wake target from the absolute deadline minus 800 ms and subtract startup from the remaining wait. Launch cost alone therefore does not establish exhaustion of the margin. The explorer's shell-based explanation of macOS Broken pipe was also not applicable to the observed PowerShell Start-Process failure. No implementation or acceptance change was made. Still-unproven timing hypotheses are kernel-wait scheduling overshoot, post-wake JSON/output work, and wrapper/process shutdown latency. Distinguishing them requires stage timestamps, not weakened assertions or a larger timeout. The approved diagnostic-only change has demonstrated error classification, not root-cause repair.

## Diagnostic CI publication

Subsequent live check: run33998162792 is executing the Windows test job101392202970, currently Validate repository, on the published exact head. Run33994318684 (PR396) has now completed FAILURE, with ci-mcp-tests (ubuntu-latest) and required-checks failed and no pending jobs; this supersedes all earlier live observations for that run. PR399 run33994414714 still has macOS version-gates and test running, with no failures at this observation.

The approved diagnostic-only repair was committed as 0898a27a8549eed768c762878f832dad3e1eb28d on codex/t002-failure-diagnostics and published as [Draft PR400](https://github.com/aharada54914/sdd-forge/pull/400). Primary verified exactly three files: tests/cross-model.tests.ps1, open ticket RT-20260906-001.yml, and its verification report. Existing unrelated changes were excluded. Run33998162792 was observed queued for that exact head, and the existing heartbeat was updated to include it. This is verification publication, not integration, ticket resolution, or quality-gate PASS. Read-only investigator diagnostic_windows_path and primary confirmed pull_request triggers Windows CI; non-main branch push alone does not. Local 54/10 failure evidence remains disclosed in the PR body. No protection bypass or repeated CI launch was used.

Remote main: `633dcdf6d3289054f832ebbed066e6680e25d645`.
This is a CI observation, not a quality-gate PASS or merge authorization.

| PR | Exact head | Observation |
| --- | --- | --- |
| 392 | c426b93344a880e2fab0d59e83604d314ffd3206 | Investigator verified all checks successful, including required-checks |
| 393 | 3691b98390b6645176556937a8d6e42b488f359f | Investigator verified all checks successful, including required-checks |
| 397 | 1ad580a063aae228159a85299e647b80d52bb248 | Primary independently verified 25 successful checks; REVIEW_REQUIRED |
| 396 | 658f1fa1b13ae9ca1657dd1f7281dc48ffad7819 | Ubuntu ci-mcp rebuild/dist-parity step failed; two macOS jobs still live |
| 398 | 317fc58525b317e92e9fdf48073d0d3d9e372e08 | Ubuntu local-env MCP rebuild/dist-parity step failed; primary latest snapshot has only macOS test still live |
| 399 | ccba716fc8c4f0e865f3beb00ce4be54c55f581c | Latest checked run has live/queued macOS jobs, no failed job at that observation |

PRs 392, 393, 396, 397 and 398 report the current main SHA above as base. Other newly opened PRs 390, 391, 394 and 395 require further individual review; no completion inferred for them. The investigator verified old PRs 377, 378 and 379 are closed; this work did not close them. Closure is not evidence that their changes merged.

Evidence: [PR 397](https://github.com/aharada54914/sdd-forge/pull/397), [PR 392](https://github.com/aharada54914/sdd-forge/pull/392), [PR 393](https://github.com/aharada54914/sdd-forge/pull/393), [396 failed job](https://github.com/aharada54914/sdd-forge/actions/runs/33994318684/job/101381990693), [398 failed job](https://github.com/aharada54914/sdd-forge/actions/runs/33994410347/job/101382244575).

Read-only investigator: `/root/new_dependency_ci_audit`. Primary verified the current PR listing, PR397 exact base/head/checks, and live run snapshots for 396/398/399. No CI rerun or merge was performed. Existing SDD bootstrap preflight prerequisites remain unresolved as recorded in `docs/ci-staging/dependency-bootstrap-preflight-20260905.md`; administrator approval-count bypass does not bypass those prerequisites.

Created thread heartbeat `sdd-forge-ci` at 15-minute intervals for live runs 33994414714, 33994410347, and 33994318684, quiet on unchanged/non-actionable state, with instructions to stop when all targets are terminal and no new target exists. This is separate from the existing weekly audit automation, which was not modified.

## Primary failure-log confirmation

Primary retrieved the completed failed jobs through the GitHub job-log endpoint and stripped terminal controls before displaying excerpts. Both show `npm run build`, then `git diff --exit-code -- dist/`, a changed tracked `dist/index.js` containing bundled `zod/v4` updates, and exit 1. PR file inventories independently show only package.json and package-lock.json changes. Thus the parity mismatch is concretely established, not inferred solely from the step name. Log excerpts were deliberately bounded; a pipeline using head exited 141 from truncation, not from a new CI execution or build failure.

Remediation: after satisfying the applicable SDD prerequisites, regenerate each package's tracked bundle from its exact updated lockfile, review the generated diff, and run required checks against the resulting head. Preserve the parity assertion. No product edit or CI rerun was performed by this diagnosis. At this continuation's poll, all three monitored run IDs still had live/queued jobs; observation is a verified wait, not terminal failure of the whole workflow.

## Subsequent terminal-state observation

### Remaining new PRs: primary read-only triage

- PR390 head `6b4efce008f2c4ba54e884cce9048ac749c1ee59`: all 25 checks successful at observation.
- PR391 head `e084192b66d1d4dbeb651b8b407e244108e0ce60`: all 25 checks successful at observation.
- PR394 head `27cd17dd476a57b89c5bcd4b416ff8ca1a7b1aaf`: Ubuntu mcp-tests and required-checks failed. Sanitized [job log](https://github.com/aharada54914/sdd-forge/actions/runs/33994310466/job/101381968368) establishes npm build followed by git diff exit-code checking, changes to mcp/sdd-forge-mcp/dist/index.js including bundled zod/v4, and exit 1. Treat as the same bundle-parity remediation category as PR396/398, not as proof that regeneration alone passes all checks.
- PR395 head `11227e9435dc1c464e0b990b5fc6d301eb46fa32`: 23 checks successful; Windows test and required-checks failed. Only ci-mcp package.json/package-lock.json changed. [Windows job log](https://github.com/aharada54914/sdd-forge/actions/runs/33994313772/job/101381976572) reports cross-model suite 62 passed / 2 failed: Gemini TEST-004(c) iterations 2 and 3, elapsed 2802/2771 ms, launch 521/531 ms, deadline budget 2000 ms, exit 1 and no verdict. GPT iterations all passed. Captured runner errors are absent, so timeout is not conclusively proven. Candidate explanations remain deadline/scheduling behavior, output/validation failure, or process-launch environment behavior; the approved failure-only diagnostics should distinguish them. This differs from the locally reproduced GPT Broken pipe; no equivalence claimed and no retry used to manufacture green.

These successful check observations are not SDD approval or merge/closure evidence. Latest live poll of PR396 has only version-gates (macos-latest) running; PR399 still has three running macOS jobs and one queued. No new CI runs started.

Run 33994410347 (PR398) subsequently completed with failure: local-env-mcp-tests (ubuntu-latest) and required-checks failed, with no pending jobs. This supersedes its live-run observation above. Run 33994318684 (PR396) still has two macOS jobs running and the previously confirmed Ubuntu failure. Run 33994414714 (PR399) has three macOS jobs running and one queued, with no failed jobs at this observation. No reruns, merges, or issue closures were performed. Issue closure requires verified acceptance evidence and main integration; a closed or green PR alone is insufficient.
