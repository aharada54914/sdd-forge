# Parallel dependency package verification

Status: package evidence only; not integration approval.

## PR 393 exact-head evidence

Primary follow-up reran unchanged `npm test` directly in the pinned ci-mcp worktree to resolve the blank exit-marker uncertainty: tool exit code 0, 148 pass, zero fail/cancelled/skipped/todo, 449.28975 ms. Full output was retained in primary tool chunk `0c59f0`, including both real Inspector stdio smoke cases. This resolves local test exit-status uncertainty only; it does not substitute for updated-head required CI.

Primary confirmed detached HEAD `8359f6390ad1d3fc1b479c2dcb72eb3983621644` and clean status in `/tmp/sdd-forge-pr393.4CAGMt`. The worker's reported log directory `/tmp/pr393-logs.Izjv1U` does not exist and was rejected; the actual pointer `/tmp/pr393-logdir.txt` names `/tmp/pr393-logs.LjdECR`. Primary read that directory's test log: 148 pass, zero fail/cancelled/skipped/todo, 686.618292 ms; audit reports zero vulnerabilities and parity log reports tracked dist parity. The `EXIT test`/`EXIT audit` marker values are blank, so those markers themselves are not exit-code evidence. Worker reports successful command completion. Install/typecheck/build logs are in the same actual directory. Fresh updated-base CI and final review remain outstanding.

## Protocol smoke coverage confirmation

Primary read the actual PR 396 test log at lines 130–131: both Inspector CLI cases passed, exercising the bundled server over stdio (`tools/list` with five ci-mcp tools, and the auth-missing `tools/call` envelope). Primary read PR 398 log lines 47–48: both Inspector CLI cases passed (`tools/list` with three local-env tools, and `get_os_info`). These are part of the existing full test runs, not additional reruns or inferred successes.

For PR 394, primary inspected `mcp/sdd-forge-mcp/scripts/run-tests.mjs`: lines 10–34 recursively collect compiled `.test.js` files without a smoke exclusion. The smoke source invokes the tracked `dist/index.js` through Inspector and covers tools/list, resources and tools/call. This confirms suite inclusion by code inspection; its raw test output remains in the worker session as described below, not in a newly claimed log file.

Parallel follow-up dispatched: one agent verifies another dependency PR among 393/395/397 in an isolated exact-head worktree; one investigates Issue 288 pushed-branch/task correspondence read-only; another refreshes PR 390 readiness. None is authorized by this dispatch to alter protection, merge, close issues or delete branches. Primary retains final integration review.

## Additional PR 395 package evidence

Primary subsequently read the complete manifest/lock diff for the exact head below against `10ad36e76f5279c1d3689211f3b1feb3700864ca`: @types/node 26.2.0 to 26.4.1 plus removed peer metadata flags; undici-types remains ~8.3.0. No other package version, source, bundle or CI change occurs in that diff. Updated-base CI is still required.

PR 395 exact head `b414a328960b31adf231c3574243d669e7869874`, detached worktree `/private/tmp/pr395-verify.fhaigU/worktree`. Worker reports install with scripts disabled, typecheck, audit (zero vulnerabilities), full tests and two identical builds successful. Primary independently read `/tmp/pr395-test.log`: 148 pass, zero fail/cancelled/skipped/todo, 441.41975 ms; independently confirmed exact HEAD, clean tracked status and ci-mcp bundle SHA256 `8bdc4d5581dcb6342770b3ee206df534a5f2c24bc72bad35f5a111ed5c5b10ba`. Build logs `/tmp/pr395-build-1.log`, `/tmp/pr395-build-2.log`. No updated-base CI or merge claimed.

## PR 397 exact-head evidence

Worker verified `6760a2a1e0673ea2bdb9493d87ae969462eaa50e` in `/private/tmp/pr397-verify.Q6yeDA/worktree`: install with scripts disabled, typecheck, 51 tests, zero audit vulnerabilities and two identical builds. Primary independently confirmed the live GitHub head, two-file local-env-mcp Inspector manifest/lock scope, detached HEAD, clean status and bundle SHA256 `0397bf3509c5cc7141222a146c7ec1aab7a18f083eb629d5618da5578f68aa29`. Build logs are `/tmp/pr397-build-1.log` and `/tmp/pr397-build-2.log`; test success is worker tool evidence, not a primary-read raw log. Updated-base CI and final review remain pending.

## PR 398 exact-head evidence

Exact head: `0d7ffa456049da8065f743c8d07003e1f027bbec`.
Detached worktree: `/tmp/pr398.sh2MYy`.

Worker reports npm ci with scripts disabled, typecheck, 51 tests, audit with zero vulnerabilities, and two identical builds successful. The primary independently read `/tmp/pr398.test.log`: 51 pass, zero fail/cancelled/skipped/todo, 10239.556959 ms. Primary verified full HEAD, clean porcelain status and bundle SHA256 `0bf1845fe17fa4ea70ce4da06ae948d3ab7516c45f0eb7224746754f83ac8137`.

Raw logs: `/tmp/pr398.npm-ci.log`, `/tmp/pr398.typecheck.log`, `/tmp/pr398.test.log`, `/tmp/pr398.audit.log`, `/tmp/pr398.build1.log`, `/tmp/pr398.build2.log`.

This validates the existing head, not a future updated-base combination. Live PR is behind main. Required CI and final updated-head review remain mandatory. No merge, branch deletion or issue closure was performed.

## PR 396 and PR 394

### Fresh exact-head package results

PR 396 was verified in `/tmp/pr396.wbMhrM` at `caf7a161627c887f3cb6a28cf5347bcebaa0141e`. Primary independently verified full HEAD, clean status, raw `/tmp/pr396.test.log` (148 pass; zero fail/cancelled/skipped/todo; 402.634625 ms), audit log (zero vulnerabilities), typecheck log, and two successful build logs. Current bundle SHA256 is `42e180944dd731e52ab41ee1128552f751b2bbc911d7dd885cfe43d41d9c60fe`; worker reports both builds reproduced the tracked bundle. Logs use `/tmp/pr396.{npm-ci,typecheck,test,audit,build1,build2}.log`.

PR 394 was verified in `/private/tmp/pr394-verify.mbwNrN/worktree` at `7e14b7de0c0da69c97f5d38d6ba9251d89ec1f36`. Worker reports install, typecheck, 247 tests (zero fail/cancelled/skipped), audit (zero vulnerabilities), and two builds successful. Test output was retained in the worker's tool session 42494, not a file log; do not claim a raw test-log file exists. Primary independently verified full HEAD, clean status and bundle SHA256 `eaaf009ae1bd7c0d50a4f6231e08c3a2f0d1a2b9eeb2eaacc20d939837de77cf`. Build logs: `/tmp/pr394-build-1.log` and `/tmp/pr394-build-2.log`.

Primary inspected the complete PR 396/398 manifest and lock deltas. They change zod 4.4.3 to 4.5.4; PR 396 also removes peer metadata flags without changing those packages' versions. Main's intervening PR 392 changes only sdd-forge-mcp files. This is evidence about file overlap, not a substitute for strict updated-head CI or an assertion that future merges have passed tests.

Primary confirmed PR 396 live head `caf7a161627c887f3cb6a28cf5347bcebaa0141e` changes exactly the ci-mcp manifest, lock and generated bundle. Agent claims about an older head or local-env-mcp were rejected. Isolated package verification assigned to the agent whose PR 398 raw evidence was independently checked.

PR 394 live head is `7e14b7de0c0da69c97f5d38d6ba9251d89ec1f36`. A stale worktree at `eb226288...` does not establish current readiness; that compatibility conclusion was rejected. Both PRs require updated-base verification before integration.

## PR 376 local verification — 2026-09-06

### Upstream reconciliation and differential probe

Primary read official https://raw.githubusercontent.com/nodeca/js-yaml/master/CHANGELOG.md lines 8–41, covering BOTH 5.4.0 and 5.4.1. Reject delegated claims of an exact manifest pin (it is `^5.4.1`) and merge-only upgrade effects: 5.4.0 also fixes BOM document handling and changes low-level AST/dump APIs. The consumer uses only load/YAMLException, not those AST/dump APIs. Primary read the actual review-ticket test suite: ordinary valid tickets, invalid syntax, missing fields, scalar documents and mixed scans are covered; BOM cases are not explicitly covered there.

Primary compared installed 5.3.0 from the PR391 worktree with installed 5.4.1 from PR376 using identical in-memory inputs, no repository edits (tool output chunk 5518bf, exit 0). Both load a plain ticket identically; both reject ordinary and BOM-separated multiple documents as YAMLException. A single BOM-prefixed ticket fails with 5.3.0 but succeeds with 5.4.1, consistent with the upstream fix. Both treat a plain `<<` key as data with default load options, not inherited mapping fields. An initial assertion probe (chunk fcd831, exit 1) incorrectly expected the old BOM case to succeed; this was an investigation assumption failure, not a new-version regression, and is retained here rather than counted as a passing test. These probes validate library behavior, not a new end-to-end parser test or fresh-main CI.

Primary read the complete three-file delta against `10ad36e76f5279c1d3689211f3b1feb3700864ca`. Manifest/lock changes js-yaml 5.3.0 to 5.4.1 and removes peer flags without other dependency-version changes. The generated bundle changes YAML merge-work accounting (including empty sources and a 100-entry merge sequence limit), BOM document boundaries, and presenter scalar-style internals. These are runtime parser changes, not a dev-only update. Primary read the consumer `mcp/sdd-forge-mcp/src/parsers/review-ticket.ts:14,73-81`: load errors remain converted to the cannot-parse envelope with an optional line. An official-upstream compatibility/coverage investigation is assigned independently; no final integration approval is claimed yet. Primary also read both existing build logs.

Worker verified exact head `26c06d1524ce8d40f2e60e093473ee835471b609` in `/private/tmp/pr376-verify.8Fy1pW/worktree`. Worker reports npm ci with scripts disabled, typecheck, zero audit vulnerabilities and two reproducible builds. Primary independently verified HEAD, clean status, bundle SHA256 `0fba99ddacc6c0b7ec49f4f7e511e52cbadf9d2cc71679fe5b7da240dcd97313`, and read `/tmp/pr376-test.log`: 247 pass, zero fail/cancelled/skipped/todo, 10276.608792 ms. Build logs are `/tmp/pr376-build-1.log` and `/tmp/pr376-build-2.log`. This is local exact-head evidence, not updated-main integration or mandatory CI success.

## Pushed-only branch qualification

`chore/withdraw-agy-panelist` has no OPEN PR, but primary GitHub query found CLOSED, unmerged PR 383. It must not be described as never-PR'd. Its two-file delta withdraws a staged patch and records an environment-specific evaluation. The report is absent from current origin/main. Neither its historical findings nor mere branch presence authorizes resurrecting a withdrawn experiment or deleting branches.
