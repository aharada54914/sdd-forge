# CI performance investigation — 2026-09-06

Status: implementation and concrete first-increment design authorized by the user on 2026-09-06. Required SDD preparation/review remains pending. No optimization implemented or performance PASS claimed.

## Baseline and current integration constraints

Inspected main SHA: `10ad36e76f5279c1d3689211f3b1feb3700864ca`.
GitHub run: https://github.com/aharada54914/sdd-forge/actions/runs/34008874163

The jobs API measured Windows version-gates at 1,821 seconds. Its two bump-version prerequisite steps consumed 444 seconds (Bash) and 608 seconds (PowerShell), 1,052 seconds combined. These are whole-step measurements, not evidence that copying alone caused the duration. Profiling fixture copy, baseline creation and actual execution separately is still needed. A single run does not establish a distribution or a speedup.

The same run's 24 matrix jobs succeeded. A subsequent live API check confirmed required-checks job 101424398790 completed successfully at 2026-09-06T04:08:09Z, and the entire run concluded success on the inspected main SHA. This supersedes its earlier queued observation. PR400 run 34010138792 at c3b3dd21f56a923baf0ca5ac3c8b9ec6f359398d is still incomplete: one Windows local-env job was in progress and the remaining matrix jobs queued. Queue delay and execution duration must be measured separately; a queued job is not a stopped or failed job.

The branch rules endpoint requires the three test OS contexts and required-checks, with strict required status checks. Do not infer absence of protection from the legacy protection endpoint returning 404. Re-read the actual rules and exact PR head immediately before integration.

## Current primary-source research

Sources accessed 2026-09-06; these are living documents, not pinned release contracts.

1. [GitHub dependency caching](https://docs.github.com/en/actions/concepts/workflows-and-actions/dependency-caching): caches and artifacts serve different purposes; untrusted fork workflows can read accessible caches. Cache plans must exclude secrets and must not replace execution evidence.
2. [setup-node](https://github.com/actions/setup-node): package-manager caching does not cache node_modules. Existing npm caching in this repository means adding another cache is not automatically a useful change. Keep dependency installation and verification semantics intact.
3. [Matrix controls](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/run-job-variations): max-parallel controls concurrent matrix jobs; fail-fast and continue-on-error alter failure handling. Neither matrix reduction nor relaxed failure handling is within the requested check-preserving optimization scope.
4. [Required status checks](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks): latest applicable commit must pass; conditional skipped jobs can appear successful, and dependent required jobs need always() plus needs. Preserve the repository's explicit all-success aggregate, rather than assuming a green or skipped individual context proves coverage.
5. [checkout](https://github.com/actions/checkout): fetch-depth defaults to one; zero fetches all history and branches/tags. Changing it requires evidence that no gate consumes historical anchors, tags or merge ancestry. Sparse checkout can likewise change the inspected inventory and is not a free optimization.
6. [Secure use](https://docs.github.com/en/actions/reference/security/secure-use): full-length action commit SHA pinning provides immutable action references. Any action change needs reviewed upstream provenance and runner compatibility, not an unqualified latest-tag upgrade.
7. [Workflow concurrency](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency), rechecked 2026-09-06: group names must distinguish workflows to avoid unintended cancellation. Cancellation and queueing are not execution-time improvements. Any proposal to cancel superseded PR runs must preserve validation for the latest applicable SHA and distinguish PR validation from release/deployment runs. Do not cancel the current queued runs as an optimization experiment.

## Evidence needed before selecting an implementation

- Complete command/OS/condition/assertion inventory for before and after, including failure, cancellation and missing-output paths.
- More than one comparable baseline run, with queue time, critical path and total runner time reported separately. Predeclare comparison rules before claiming improvement.
- Component timings for the heavy fixture setup and execution; preserve isolated mutable fixtures, complete relevant repository content and real prerequisite invocation.
- Check cold and warm cache behavior if caching changes; no cross-PR verification-result reuse, credential exposure or trust-boundary widening.
- Independent review, required SDD approvals and scoped test authorization before protected changes. Do not work around a denied hook through another filename, tool or agent.

## Pending decisions

The user confirmed proceeding with check-preserving CI optimization: “CI 高速化の実装を承認する”. This records implementation authorization and confirmation of the previously presented scope; it does not invent acceptance of an unpresented concrete design. The user additionally required current best-practice research before implementation. No approach has been selected and no CI or test behavior changed by this report. Existing approved issue/PR work continues independently.

## Decision log

- 2026-09-06: preserve every existing OS, test command, failure assertion, required-check dependency and trust boundary. Do not reduce coverage to obtain a faster green result. Implementation authorization is recorded above and need not be requested again for the same scope.
- Candidate A: reduce repeated test-fixture preparation, with fresh isolated mutable fixtures for every case. Requires component profiling and equivalent content/metadata evidence before selecting a copy strategy.
- Candidate B: split independent expensive suites into additional jobs. Can shorten a critical path but may increase runner minutes and queue delay; existing required contexts and fail-closed aggregation must remain.
- Candidate C: cache additional immutable setup inputs. Existing npm caching already applies; setup was not the dominant measured cost. Never cache verification results or share mutable fixtures across jobs.
- Preferred investigation order: A, then B if measurements justify it; C is lower priority. This is not a claim that A's bottleneck or final implementation is proven.

## Integration refresh

PR #392 has merged at `e5ff39d95adadb7c0628132313392ec03c7f21c4`. Its new main run 34011092133 is incomplete; successful CI on predecessor `10ad36e...` is not evidence of success for this run. PR #400 run 34010138792 now has a failed Windows test job despite the earlier local 64-pass result; read-only diagnosis is delegated separately. No merge or retry is authorized by a pending/failed result alone.

## Second baseline and reviewed proposal

Successful main run 33973490639 at `1e32a69c20f05f02bb9a00fa669013939f1f654f` measured Windows version-gates at 2,016 seconds, with the Bash prerequisite at 574 seconds and PowerShell at 626 seconds (1,200 seconds combined). `git diff` between this SHA and `10ad36e...` was empty for test.yml and both bump-version-gate test files. Repository contents and runner conditions may differ; these are comparable diagnostic observations, not controlled benchmark trials.

Primary source inspection at `origin/main=e5ff39d...`:

- `.github/workflows/test.yml:455-484` retains both prerequisite shells on all three OSes.
- `tests/bump-version-gate.tests.sh:76-88`: each fixture creates a new temporary directory, copies the repository with pre-copy exclusions, then initializes Git.
- `tests/bump-version-gate.tests.ps1:37-58`: each fixture copies the full repository first, then removes `.git` and exactly two named node_modules directories, then initializes Git with long-path support. Bash uses a broader wildcard exclusion; changing the PowerShell exclusion scope is not automatically equivalent.
- `tests/bump-version-gate.tests.ps1:112-122` and Bash `commit_fixture_baseline` create the baseline after case-specific setup. Sharing a mutable fixture would require a new isolation proof; existing assertions do not provide it.
- The independent explorer's claim of four fixture cases and already-safe shared fixture reuse was rejected by primary review. The files identify TEST-001..003 as fixture-driven cases; do not treat its recommendation as a safety PASS.

Proposed first increment: keep job topology and test assertions unchanged; measure copy, Git baseline and real invocation separately. If copy is material, avoid copying only the already-excluded inputs before applying the same per-case setup. Preserve source bytes, hidden files, symlinks/modes where supported, long paths, per-case directories, setup failure handling, baseline timing, and cleanup. No shared mutable fixture, hard links, tracked-files-only substitute, newly broadened exclusion or cached test result.

Validation proposal: same assertion and SKIP inventory on Windows/macOS/Ubuntu; deliberate copy/setup failures must fail closed; fixture content and metadata comparison; isolation check proving case A mutations cannot affect case B; at least three paired measurements on each affected OS, with queue delay, suite runtime and total runner work reported separately. No performance PASS without actual runner evidence. Review the concrete patch independently, then run every required CI check before merge. If setup is not material, do not land an unproven copying rewrite; return to the job-partitioning alternative with measured evidence.

The user explicitly accepted the concrete first-increment design above: “具体的な設計案を承認する” (2026-09-06). The same design and implementation approval must not be requested again. Required SDD specification/task gates remain applicable (the user's dependency-only exception does not cover this change).

Decision: proceed with the measured, isolated-fixture first increment, not job partitioning or additional caching. Retain the stated fallback if copy/setup is not a material contributor. Source behavior, checks, OS coverage and trust boundaries remain unchanged; review and runner evidence are required before declaring completion.

## Bootstrap preflight — actual attempt after design approval

The required `sdd-bootstrap-interviewer` handshake challenge now launched successfully, nonce `27bad78e7edb82fabc909719299ff536`. The prescribed real canary apply_patch attempt was blocked by the host's PreToolUse hook. Raw denial is preserved in `reports/verification/ci-performance-handshake-20260906.json`; no canary write succeeded.

The host exposed denial text, not the Codex-specific `plugin_hooks_enabled` and `denied_by_plugin_hooks` fields required by the verifier (`plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py:105-112`). Those fields were not fabricated. Actual verification returned exit 65, `CAPABILITY_RUNTIME_UNAVAILABLE`, reason `PLUGIN_HOOKS_DISABLED`. This is the validator's classification of missing fields, NOT evidence that no hook fired: the real tool attempt was denied.

Per sdd-bootstrap-interviewer Track Detection, any result other than HOOK_ACTIVE stops bootstrap; no Phase 1 artifacts or optimization implementation were generated. This is an evidence-format/runtime compatibility blocker, not a missing design approval. Do not ask the user to approve this same design again. Do not silently switch runtime labels, bypass the hook, or mark handshake passed. Existing dependency-only work continues independently.
