# PR381 ordered registration and final simple consumer repairs

Recovery checkout: `/Users/jrmag/.local/share/sdd-forge-pr381-recovery-20260908`
Base: `3971c93a5705dc15f86ba56cc62118613e4b19db`

## Changes and verification

- `tests/generate-registry-digest.tests.sh`: actual successful Bash listing, exact lines, exactly one each and T-004 < T-005 < T-006. This implements the existing serialized constraint in `specs/epic-190-a2-capability-registry/tasks.md:92` instead of retaining a success message that claimed ordering while checking only membership. Full suite 17 passed / 0 failed, exit 0. SHA256 `f98879e6bb5de6e21960be4a22859c7d45f3d5780a993bb8692b6c9aa0c57e3c`.
- `tests/human-copy-runner-contract.tests.ps1`: consume successful Bash listing as an array, case-sensitive exact string indices, preserve the two suites' order and both existing PowerShell ordering predicates. Staged CI checks unchanged. POSIX wrapper invokes the real PowerShell suite: 56 passed / 0 failed, exit 0. SHA256 `89e38c8e88534d49731d345e32d6c35212727e69f75da5e27e3e60884ade36df`.
- `tests/design-sync-standing-consent.tests.sh`: actual successful Bash listing with full-line matching, PowerShell registration conjunct unchanged. Counted tests: 55 passed / 0 failed, exit 0. **Deferred TEST-054 CI reachability still prints FAIL and remains unresolved; it is not included in the suite's totals or exit status.** SHA256 `b4acca0c7509f0d2165613dafe384214bae38d6c5e9ac832ba2d5e157941c1db`.

Logs: `/tmp/pr381-posix-20260909.WaPopD/{generate-registry-digest,human-copy-runner-contract,design-sync-standing-consent}-after-registration.log`.
All sessions terminal: 30935 (digest), 45308 (expected RED controls), 34837 (GREEN controls), 85649 (human-copy wrapper). Do not poll or restart these handles.

Standalone actual-block diagnostics (not inventory-wired regression suites):
- `pr381-digest-order-controls-20260909.cjs`: before repair 12 passed / 2 failed (valid real/dynamic inventory rejected); after 14 passed / 0 failed. Includes both order inversions; missing, near and duplicate variants of all three members; failed listing with valid-looking output.
- `pr381-human-copy-order-controls-20260909.cjs`: before repair 10 passed / 2 failed; after 12 passed / 0 failed. Includes failed listing, reversed order, each missing/near/mis-cased member and missing/reversed PowerShell registration.
- `pr381-three-registration-controls-20260909.cjs ... design-sync-standing-consent`: 6 passed / 0 failed, including missing, near, failed listing and missing PowerShell registration.

Primary review: no Critical findings; no product verifier, CI workflow or frozen artifact edited. Ordering was not discarded, string matching remains case-sensitive, and native exit code is captured immediately. Windows execution of the newly executed Bash listing from PowerShell remains pending native CI; macOS execution is not Windows proof. Formal independent review/QG is not replaced by this primary review. Bash syntax and checkout `git diff --check` exit 0.

## Remaining work

Three original baseline suites still fail by exit status: human-copy-mirror-freshness, deterministic-lane-selfcheck, design-system-contract. Additionally, design-sync-standing-consent's deferred TEST-054 remains FAIL despite its now-successful exit code. Thus four suites still have known unresolved checks. Full baseline rerun, formal independent review/QG, and mandatory native CI remain outstanding. No commit/push/merge, issue closure, or Done transition performed.
