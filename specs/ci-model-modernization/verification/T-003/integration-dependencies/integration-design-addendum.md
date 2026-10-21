# T-003 integration design addendum (pre-product)

Actor: work-agent:root:t003_implementation. This non-frozen addendum implements the approved design; it does not edit specification bodies or activate categories.

## Caller identity and acyclic flow

The frozen example producer `plan` maps to the accepted concrete job `ci-plan`. Conditions retain exactly the generated producer/output identifier and lowercase comparison `needs.ci-plan.outputs.run_<group> == 'true'`, optionally conjoined with already-supported native OS/matrix predicates. No arbitrary Actions expressions establish coverage. Output keys must correspond to declared groups, point to the same plan step output, and remain collision-free after hyphen-to-underscore normalization. Missing values and wrong casing cannot authorize a selected group.

`ci-plan` checks out the tested SHA into subject and, for PRs, the exact base SHA into trusted with full history and persisted credentials disabled. It runs the trusted base planner for PRs, passing the subject path and exact API-head/tested/base/head identities. First adoption explicitly invokes accepted FULL fallback when the base lacks a planner. Non-PR events remain FULL, and force-full is passed conservatively. The original planning run/attempt artifact name is a job output; failed-job reruns use that original value instead of constructing a new name from the aggregate attempt.

Every selection-controlled workload job depends on ci-plan; the two A9 jobs retain their exact accepted dependency graph. The native test wrapper remains `test` with its original three OS matrix rows and `always()` so its cheap integrity checks can execute when planning fails. Expensive workload predicates consume only bounded outputs. No missing or failed plan becomes aggregate success. Initial inactive categories preserve FULL behavior; local affected fixtures test interpretation only.

The terminal required-checks job uses the exact accepted five-step owner contract: pinned tested checkout, structural parser installation, original plan download, actual same-run collect, sole aggregate argv. It needs every other job and remains always-running with literal five-minute timeout and exact read permissions/env scopes. Its four run steps are typed owner controls; no new collector job or general control exemption is added. The collector observes all completed predecessor jobs and ignores only this accepted verifier self-observation. The DAG therefore has no collector/aggregate wait cycle.

## Receipts and caller compatibility

Keep existing direct suite arguments, shell, OS, and assertions. Add the existing runner's --receipt metadata option to stdout-only callers: portable-prechecks, Windows A7 profile, and version-gates-windows-bump direct-suite matrix caller. Keep the existing cloud receipt. Each runner job uploads receipts even after failure using the C-required name hash of its actual expanded Actions job display name, run ID and original attempt; uploads never overwrite prior attempts. Explicit matrix labels disambiguate the six existing named matrix callers without changing the four required check contexts. Existing C source-attempt and original-plan tests remain authoritative.

Update required-checks-posix tests to exercise real aggregate CLI failure fixtures as well as the exact prepared shape; retain all A9/native/transport/failure assertions. Adapt only the accepted plan test's live ci-plan fixture comparison so it compares non-planner workload on both sides. No P/C/R algorithm repair is authorized.

## Measured independent partition

Admitted actual historical run 39161543135 at 2aaac49c528d0dfe28437082d54fb86a32f04a15 supplies API step intervals. The first attempt's successful cloud-suite steps took Windows 270s, Linux 671s, macOS 675s; Linux tool setup took 8s. The second attempt repeats these successful jobs, so these are not independent repeated samples. Windows A7 took 517s. Move the cloud suite and its Linux pinned tool setup together into an independent cloud-native OS matrix; retain the direct cloud command, pwsh shell, CLOUD_REQUIRE_NATIVE environment and all three OS obligations. Keep remaining native suites in the required wrappers. This removes a measured 270–683s serial segment but does not claim equalized groups, hosted speedup, CPU savings, billing savings, or p95. Additional checkout/setup cost is unmeasured.

before-inventory.json records the entire parsed workflow, 415 expanded run obligations, one legacy verifier control, and 42 expanded jobs. The final after-inventory and mapping must account for every old suite and opaque run obligation. Changed job labels, moved cloud setup, metadata-only receipt arguments, new planner/artifact/cache setup, and changed dependency acquisition must be explicit differences; do not claim identical whole run-body hashes. The suite multiset regression already compares expanded underlying argv, shell and OS.

## Dependency reuse and retry boundaries

Use the admitted pinned cache action only for package archive bytes (npm download cache and fixed Pester .nupkg). Keys include runner OS, runtime, exact lock/package digest, event and PR number, with no broad fallback key. PR-created entries cannot populate trusted event keys. npm ci continues to validate lock integrity and installs fresh node_modules; Pester validates archive SHA on every hit and installs a fresh safely extracted module tree with pinned manifest and file-byte checks. Assertions, receipts, worktrees, installed module trees and credentials are never cached. Only acquisition is retried, at most three attempts with each failure logged; never wrap test assertions or suite invocations in retry.

The helper is optional infrastructure justified by PowerShell module version alone being inadequate cache integrity. Claude is currently drafting isolated tests only; no helper implementation exists. Its draft will be pinned/admitted and run Red before any helper implementation is integrated after Root GO.

## Validation and rollback

Current Red is local protocol evidence only. After Root's test commit and explicit product GO: run new tests to green, all current catalog/planner/C/required-checks suites, workflow structural check, schema/field tests, static checks and inventory equality; record exact commands/exits. Validate full/affected fixtures, plan/artifact mismatches and rerun lineage. No native inference, credential access, cloud writes, hosted candidate acceptance or category activation.

Rollback must restore accepted dirty snapshot product bytes, especially W ed1d819170ef861563f2d9a403bde4f702e54cf151f26ad3e08d31ec4686da32 and owner plan tests d795a6db0d815c580d5013ec22518d858c4a60019035b823844bea4e5cf12f04. Raw HEAD is not this baseline. Historical attempt-1 boundary artifacts and accepted T001/T002 evidence remain immutable.

Root additionally authorized the second live caller test to change its legacy one-control expectation to exactly four ordered accepted preparation controls. The initial current planner suite had 49 passing methods and this one outdated live assertion failure (legacy-live-control-red.log). The legacy single aggregate positive fixture, all hidden-work negatives and arbitrary-job nonexemption remain covered.
