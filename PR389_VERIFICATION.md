# PR #389 combined-tree review and verification

## Main integration completed — 2026-09-05

This section supersedes the historical pending-CI and unmerged snapshots below. Fresh run [33962847954](https://github.com/aharada54914/sdd-forge/actions/runs/33962847954) completed successfully with all 25 jobs, including required-checks, passing. Immediately before merge, remote head was `ec0bfe248c88667a22a78571dbcb9b839c81e5ea` and base was `bdfe69955e5acf8e27aae0b969272f9a3cfef3aa`; the exact-head Astra review conditions were satisfied. [Final checkpoint](https://github.com/aharada54914/sdd-forge/pull/389#issuecomment-5551564632) records evidence and owner authority.

The normal expected-head merge API succeeded without a separate browser override at 2026-09-05T11:48:06Z. GitHub confirms MERGED at `ca023cc85d9db5d44f63ec77e4d3ff73f3f9bfdf`. Local main was fast-forwarded to that commit. Its tree `9c7f19c7ffe37ca7bd3e71cd285778de5412c355` exactly equals the reviewed candidate tree. Primary reran WFI-058 (3/3) and WFI-059 (4/4) on the actual main checkout, both exit 0. Pre/post tracked dirty-diff SHA-256 remains `a4ee4be38fed4ad3dfaddf92e9a271a5658497039dac957e5a6595e26dbaa5ec`; unrelated README and learning edits are preserved. No protection rule, task status or approval was changed, and no branch was deleted. This integration is not a claim that all open issues or the separate dependency bootstrap blocker are resolved.

## Assertion correction pushed — 2026-09-05

Final independent GPT-6 Astra merge-readiness follow-up: **conditional PASS**, no additional blocker in this PR scope. Reviewer independently verified clean head/tree and only the four expected substitutions; reviewed primary runtime evidence without claiming independent execution. Remaining conditions are current mandatory CI success and unchanged remote head/base immediately before merge. The new dependency bootstrap's hook denial is separate, not a PR389 blocker.

Current head `ec0bfe248c88667a22a78571dbcb9b839c81e5ea`, tree `9c7f19c7ffe37ca7bd3e71cd285778de5412c355`, base main `bdfe69955e5acf8e27aae0b969272f9a3cfef3aa`. The owner's latest instruction to resolve remaining conditions authorizes the test-only extension in `PR389_REMEDIATION_PLAN.md`. This supersedes historical statements below that assertion scope is pending or the shell failures remain unresolved. No other scope, guard, fixture, approval mark or task status changed.

Exactly four grep consumers across TEST-049b, TEST-055b and both TEST-075c clauses now consume all finite input instead of using quiet mode; original patterns, flags, conjunction and negatives remain. Independent GPT-6 Astra actual-diff review PASS with no findings, bound to test-file SHA-256 `d09db07b5caa19077f5e190c2efa6ad1a8f8f016bd7ad18bbad1106f570bccba`.

Primary ran all commands with explicit cwd `/Users/jrmag/.local/share/sdd-forge-consolidation-wave1-20260905` and prefix `rtk proxy env PATH=/usr/bin:/bin:/usr/sbin:/sbin /bin/bash`: prepare-panelist 186 PASS / 0 FAIL (exit 0); WFI-058 3/3; WFI-059 4/4. A 100000-line finite diagnostic control produced old pipeline 141 versus corrected 0; absent message 1. The two-message conjunction returned 0 for both, 1 for max-only, counts-only and neither. These retain fail-closed message checks without increasing timeout or suppressing failures.

Delegation evidence correction: the worker edited the main checkout instead of the assigned candidate. Primary removed only those known four worker edits from main and applied the reviewed four changes to the correct candidate with apply_patch. The independent tester also used the wrong cwd and later offered unrelated suite controls; all its runtime claims are excluded. The numbers above are direct primary executions, not those delegated results. Main's test-file diff is empty.

The single-file correction was committed and pushed normally via existing strict-host SSH transport. Fresh Actions run [33962847954](https://github.com/aharada54914/sdd-forge/actions/runs/33962847954) is running; it has not yet passed. [Audit comment](https://github.com/aharada54914/sdd-forge/pull/389#issuecomment-5551393018) records the actual evidence. PR body now labels old human-apply commands historical. No merge yet. The owner's broader conditional administrator approval-review exception applies, but does not waive CI or alter repository protection.

Unchanged product-byte evidence below (native golden 30/30, regression 9/9, PS prepare 179/179, mirror/validator and MCP checks) remains applicable; the new commit changes only the shell test. No Windows PowerShell 5.1/junction execution is newly claimed.

## Owner authorization update — 2026-09-05

The owner explicitly authorized the PR #389 administrator bypass of the required approval review **only after remaining verification problems are resolved and all required CI succeeds**. This is new PR389-specific authority, not an extension inferred from PR386. It does not waive shell failures, authorize branch-protection edits, approve unrelated PRs, or replace exact-head checks. Current reviewed head remains `25304d3b842d76e5da152e659af0d678d537e026`; hosted run33960178745 is still running. Diagnose the local shell result without changing tests or global runtimes before deciding whether additional scoped authorization is needed.

Latest diagnosis: the read-only explorer identified early-terminating message-search pipelines at `tests/prepare-panelist.tests.sh:1750-1752`, `2026-2028`, and `2893-2895`. An inert producer/search reproduction on both installed Bash versions yielded pipeline status 141 with producer 141 and matching grep 0. This supports a SIGPIPE test-harness explanation; it is not a new full-suite run or a waiver of the recorded 183 PASS / 3 FAIL. A proposed minimal extension would change only these output assertions to avoid early-reader termination while preserving expected messages and negative controls. `PR389_REMEDIATION_PLAN.md` explicitly excludes these assertions, so the extension requires an explicit scope decision before authoring. Protected-file human-application requirements remain unchanged.

Latest hosted snapshot: 20 completed-success jobs and 4 running (three version-gates platforms plus macOS test); required-checks is not yet complete. No merge has occurred. The new owner authorization supersedes historical requests for a separate PR389 admin exception below.

One read-only Bash-support search was rejected by PreToolUse. It was not retried, reformulated, or delegated to bypass the rejection; no supported-runtime claim was inferred from it. No product or test files were changed during this diagnosis.

## Remediation committed and pushed — 2026-09-05

### Native golden-case follow-up

The standalone test adapter `docs/ci-staging/pr389-native-golden.ps1` (SHA-256 `e04a2775a89e874ed0fcb3e941a2666b6e9531b4e2a583dcd1bec86db2df71e9`) reuses the original 3-field x 10-case definitions and compares native live-checker exit/stdout/stderr against all 30 frozen JSON expectations, with only the original LF normalization. Both the new lightweight tester and primary independent rerun passed 30/30. Primary inspected the complete adapter and original harness: no changed expectations, copied product implementation, Windows emulation or fixture regeneration. The adapter's space-joined arguments are suitable only for these verified space-free paths; it is a scoped local verification artifact, not a portable replacement for the repository test harness. Product worktree remains clean.

Primary command, with cwd explicitly set to `/Users/jrmag/.local/share/sdd-forge-consolidation-wave1-20260905`:

```bash
rtk proxy env PATH=/bin:/usr/bin:/usr/sbin:/Users/jrmag/.nvm/versions/node/v24.13.0/bin:/opt/homebrew/bin /opt/homebrew/bin/pwsh -NoLogo -NoProfile -File /Users/jrmag/sdd-forge/docs/ci-staging/pr389-native-golden.ps1 -RepositoryRoot /Users/jrmag/.local/share/sdd-forge-consolidation-wave1-20260905
```

This supplies native-runtime golden-case evidence for the narrow change. It does not claim Windows PowerShell 5.1, junction or final-file reparse-point execution. Independent Astra follow-up confirmed local scoped readiness PASS with no new blocking findings and that these 30 native cases satisfy the plan's relevant golden-case requirement for A1/A3. The reviewer independently inspected the clean head/tree, unchanged live hashes, adapter, and fixture definitions; it relied on the separately reported 30/30 execution and did not claim another execution. Windows-specific limitations remain explicit rather than expanding the narrow remediation scope.

Merge remains blocked: SH prepare's 183 PASS / 3 FAIL is not waived, fresh required CI is still running, and actual GitHub approval remains absent (only a historical COMMENTED review). Latest snapshot contains 16 successful completed jobs and 8 running, no returned failures; required-checks has not completed. The owner must give separate explicit direction if PR389 should use a review-requirement administrator exception; the existing PR386-only exception cannot be inferred to apply.

The exact reviewed six files were committed as `25304d3b842d76e5da152e659af0d678d537e026`, tree `51f7aa786fe9c7e00fd68e1e7eaf6d59893b94de`. Candidate worktree is clean. Normal HTTPS push failed with `could not read Username`; existing SSH transport then succeeded using batch mode and strict existing-host checking, without changing credential settings, exporting credentials or bypassing any hook. Remote PR metadata confirms this exact head. No force push or merge was performed.

Fresh [Actions run 33960178745](https://github.com/aharada54914/sdd-forge/actions/runs/33960178745) is queued; this supersedes the earlier statement that the post-application bytes were uncommitted. [Audit comment](https://github.com/aharada54914/sdd-forge/pull/389#issuecomment-5551115022) records provenance, passing checks, excluded wrong-worktree tester evidence, unwaived shell failures, incomplete Windows golden coverage and the required actual approval. Native-runtime golden verification is being assessed separately without modifying product code or frozen expectations.

## Human application received — 2026-09-05

The maintainer ran the reviewed remediation on the dedicated candidate and supplied successful output for all four ContractLocationTests and all five AnchorTemporaryFileTests. The first operator command stopped before application because `rg` was unavailable in the operator's PATH; the candidate was confirmed unchanged. The corrected operator command used macOS `/usr/bin/grep` and completed application, two mirror copies, two manifest-line updates and all nine regressions. This is human-executed evidence, not agent-executed test output.

Primary read-only verification now confirms exactly six modified tracked files (26 insertions, 11 deletions), no untracked additions, unchanged HEAD `c5d3230714dd064b3e5a48ac79fb179f45ae3a76`, and a clean `git diff --check`. The two live-file changes match A-1/A-2/A-3; both manifests change only their `plugins/sdd-quality-loop/scripts/check-contract.ps1` hash line. No MCP files differ from this HEAD.

- Applied PowerShell gate SHA-256: `ac18c5324a3d0bffd1a94cb825bfc02fddf286968ab8f5341c3df619ad2d92e6`.
- Applied shell preparer SHA-256: `2dcb217c370cdde48c7d3f172fa8ae4ed830c3185ac46c0a86b1810951bec91e`.
- epic-136-phase2-gates manifest SHA-256: `af104768f81e23259ca338c4eeb2e2fe0d932737da8d0b08c9a6a32c3205dd76`.
- epic-191-a3-path-ownership manifest SHA-256: `ee733f682b85dc75010a9fb95bf53cd9f13e721253b1472acbdadfdf2de43791`.

Independent Astra reviewer `/root/pr389_postapply_review` returned actual-tree scoped PASS: Critical 0, Major 0, Minor 0. The reviewer confirmed all hashes above, both mirror byte comparisons, exact manifest-line scope, and independently reran both regression harnesses (4/4 and 5/5 PASS). No protected code was changed by the reviewer. This scoped PASS is not a merge approval or SDD Done decision.

### Post-application verification correction and primary results

The delegated tester executed suites in `/Users/jrmag/sdd-forge`, not the specified candidate. Its runtime results are excluded from post-application evidence, including its 184/2 shell result and unrelated golden-baseline failures. Primary reran the required established suites with explicit working directory `/Users/jrmag/.local/share/sdd-forge-consolidation-wave1-20260905` and the scoped PATH documented below. No test or product edits were used to obtain these results.

| Actual candidate check | Post-apply result |
|---|---|
| WFI-058 SH / PS | 3 passed, 0 failed each |
| WFI-059 SH / PS | 4 passed, 0 failed each |
| prepare-panelist PS | 179 passed, 0 failed |
| prepare-panelist SH | 183 passed, 3 failed, exit 1; not waived |
| Mirror freshness SH / PS | 6 passed, 0 failed, 15 pending each |
| Repository validator SH / PS | Both passed; 10 targets, 0 drift |
| phase2-contract-path-helper PS | Incomplete: 9 static checks then process-start error; Windows `powershell.exe` is unavailable on this Mac |

The shell rerun retains the historical 183/3 count; the output again includes a broken-pipe message assertion failure at TEST-075c. The Windows golden harness was not rewritten or rerouted, and neither its golden cases nor Windows junction tests are claimed passed. No workflow reference to that harness was found under `.github/workflows`; ordinary hosted Windows job success alone will not establish execution of it. Remaining golden-case coverage must be resolved before merge. MCP files are unchanged, so the earlier 446-test/package evidence below remains tied to unchanged bytes rather than a new test run.

Existing hosted CI success below is for the pre-remediation commit, not these uncommitted bytes. No post-apply commit or push is claimed by this entry. This section supersedes earlier statements that the remediation is unapplied; it does not rewrite the frozen staged-package provenance.

## Latest remote recheck — 2026-09-05

The GitHub connector confirms the open PR remains at `c5d3230714dd064b3e5a48ac79fb179f45ae3a76`, targeting main `bdfe69955e5acf8e27aae0b969272f9a3cfef3aa`. [Actions run 33938647223](https://github.com/aharada54914/sdd-forge/actions/runs/33938647223) completed successfully: all 25 returned jobs, including `required-checks`, succeeded. This supersedes the earlier pending hosted-CI statement below, not the independent NEEDS_WORK merge verdict. Job success includes platform-conditioned skipped steps; it is not proof every step ran on every host. The workflow connector returns the first page of PR-triggered runs/jobs; no broader all-provider status completeness is claimed.

There is one COMMENTED review on historical commit `ab009a3e57`, not an approval of the current head. The PR body's original staged-WFI instructions are historical: the original WFI fixes were already human-applied in commits recorded below. The still-unapplied work is specifically the later A-1/A-2/A-3 remediation, not the original WFI patches. The local candidate was rechecked clean at the exact current PR head. Do not reapply the old PR-body patches.

Local `gh pr checks` and `gh pr list` returned HTTP 401; authenticated connector reads succeeded without changing credentials. No protected application, push, merge, review submission or branch deletion occurred in this refresh.

Date: 2026-09-05
Candidate commit: `c5d3230714dd064b3e5a48ac79fb179f45ae3a76`
Candidate tree: `e677808be1a9df76573978a853626c86c180b996`
Base main: `bdfe69955e5acf8e27aae0b969272f9a3cfef3aa`
Original PR head: `cfa81def37a59b7b288f9092f603c801fdea7b1b`

This is an integration review record, not an SDD quality-gate report or task Done decision.

## Decision

Independent GPT-6 Astra reviewer `/root/astra_wave1_review`: **NEEDS_WORK for merge; PASS for ordinary fast-forward push to the existing PR for CI.** Critical 0, Major 1, Minor 2. Both original PR head and main are candidate ancestors; the candidate worktree is clean. Fast-forward push completed without changing owner worktrees, force-pushing, or deleting branches. Audit comment: https://github.com/aharada54914/sdd-forge/pull/389#issuecomment-5548683447. Hosted CI run `33938647223` started on the candidate; its outcome is pending.

## Findings

- A-1 Major: `plugins/sdd-quality-loop/scripts/check-contract.ps1:115` resolves a relative contract against .NET process CWD rather than PowerShell location. Independent reproduction started PowerShell from `/Users/jrmag`, changed location to the candidate, and invoked the actual epic-194 T-003 contract relatively: exit 1 with 10 missing-evidence failures based at `/Users/jrmag`. The same absolute contract path passed with exit 0. Use PowerShell path resolution and add a changed-location regression.
- A-2 Minor/security: `plugins/sdd-quality-loop/scripts/prepare-panelist-input.sh:901-907` adds a predictable temporary path with ordinary output redirection. In an attacker-writable temporary directory a precreated symlink could redirect the write; private report content may also inherit overly broad permissions. This review did not demonstrate compromise of the current Mac. Allocate an exclusive private temporary file and handle cleanup/failure without admitting a fallback anchor. The pre-existing similar sink outside the changed history scan is not claimed fixed.
- A-3 Minor/parity: `plugins/sdd-quality-loop/scripts/check-contract.ps1:122` compares `specs` with case-insensitive `-eq`, unlike Python. Read-only invocation confirmed `Specs` discovers a root on PowerShell but falls back on Python. Use exact matching and a mis-cased negative test.

An earlier lightweight review erroneously inferred the local candidate was behind from the unpushed remote PR state. Both ancestry checks disproved that claim. Its later lack-of-targeted-test claim is superseded by the main agent's complete WFI test runs below. These statements were not treated as valid merge blockers or evidence of passing tests.

## Completed local checks

Scoped PATH selected `/bin/bash` before Homebrew tools; no global environment change or test weakening. Commands used PATH `/bin:/usr/bin:/usr/sbin:/Users/jrmag/.nvm/versions/node/v24.13.0/bin:/opt/homebrew/bin`, Node 24.13.0, and `/opt/homebrew/bin/pwsh` where applicable.

| Check | Result |
|---|---|
| All three MCP packages: clean install, production audit, typecheck, rebuild and tracked artifact parity | PASS; no audit findings and no tracked build drift |
| ci-mcp tests | 148 passed |
| local-env-mcp tests | 51 passed |
| sdd-forge-mcp complete `npm test` | 247 passed, 0 failed/cancelled/skipped; includes all four deep-verify parity cases |
| WFI-058 SH / PS | 3 passed, 0 failed in each runtime |
| WFI-059 SH / PS | 4 passed, 0 failed in each runtime |
| prepare-panelist PS | 179 passed, 0 failed |
| prepare-panelist SH | 183 passed, 3 failed; see baseline limitation |
| Human-copy freshness SH / PS | 6 passed, 0 failed, 15 pending informational in each runtime |
| Deterministic-lane selfcheck SH | 25 passed, 0 failed, 4 explicitly designed-red pre-human-copy cases |
| Repository validator PS | Passed; 10 targets, 0 mirror drift |

## Baseline limitations and resolved exception

The identical SH suite run at untouched PR #386 head returned 183 passed and 3 failed under the same environment. The current run's failed message assertions TEST-049b/055b/075c have the expected text but exhibit `echo | grep -q` early-exit broken pipes under pipefail. BSD grep is installed; no GNU grep comparison was available. This does not establish a passing full shell suite, and the tests were not modified or suppressed.

Homebrew Bash 5.3.9 nontermination was independently isolated; standard `/bin/bash` 3.2.57 allowed model-freshness to pass 40/40 and deep-verify parity 4/4. Fresh complete sdd-forge-mcp runs passed 247/247 at BOTH this combined tree and the exact PR #386 head. The earlier parity-file exclusion is therefore no longer necessary for these newly recorded runs, but remains part of the truthful historical pre-merge record.

## Governance and next step

Commit `87ce3baf` records human application of the exact protected WFI patches after both agent tool paths were denied. Commit `cfa81def` records the three stale mirror copies and two manifest updates while preserving 15 pending mirrors. These are historical commit assertions, not independently recovered approval transcripts. Current integration authority comes from this session's owner handoff.

`PR389_REMEDIATION_PLAN.md` received independent Astra PASS for staged patch/regression authoring only. The final package in `docs/ci-staging/pr389-review-remediation/` then received independent Astra PASS for human handoff, with all four hashes confirmed; see its REVIEW.md. Patch `778cb1f58ac4d4be66551ee60b62af35c4cd8732e21b0b67e915656a544f4e33` passes `git apply --check` against the clean candidate but is NOT applied. Nine baseline regressions ran: two passing controls and seven intended failures; no post-apply GREEN is claimed. Initial delegated test drafts were rejected for not exercising the actual A-3 function and replaced before recording evidence.

Live protected scripts remain unchanged until the sanctioned human-apply step. Even read-only prediction of a future gate hash was rejected by the deterministic hook; that calculation was not retried via another tool. Human instructions name only the two PS mirrors and two manifest entries; the current origin/main-based classifier could mark those PENDING, so no broad automatic synchronization is authorized. Re-review and actual in-tree validation are required after application. PR #386's specific administrator exception is not extended to this PR.
