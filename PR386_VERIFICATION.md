# PR #386 Verification Packet

## Post-merge addendum — 2026-09-05

The user subsequently transferred integration ownership and explicitly approved a #386-only administrator bypass of the one-review requirement. All named hosted checks were revalidated; the exact head was merged as `bdfe69955e5acf8e27aae0b969272f9a3cfef3aa` at 02:10:25 UTC, with rules and branches preserved. See EXECUTION_HANDOFF.md for the audit record.

A later complete `npm test` at the exact PR head passed **247/247**, with 0 failures/cancellations/skips, including all four deep-verify parity cases. The only change was a process-scoped PATH selecting macOS system Bash before Homebrew Bash 5.3.9. No test or product code was changed. The original exception below describes the historical pre-merge execution, not an outstanding exclusion from this newly recorded full run. Other historical no-merge statements below likewise describe the original verification phase.

## Scope and identity

- Pull request: `#386` (`fix/npm-audit-fasturi-qs-20260903` -> `main`)
- Verified head: `1bd368aa3584a6a435e9b7ad4849dfb7019e3ec7`
- Verified base: `3749a252` (`origin/main` at the start of this run)
- Remote ref `refs/pull/386/head` matched the verified head before testing.
- The branch is occupied by an existing owner worktree. No reconstruction, commit, push, merge, issue edit, or owner-worktree mutation was performed.
- Verification ran in disposable detached worktree `/Users/jrmag/.local/share/sdd-forge-verify-pr386`.

## Change boundary

The PR contains one commit and changes only dependency locks and generated bundles for:

- `mcp/ci-mcp`
- `mcp/local-env-mcp`
- `mcp/sdd-forge-mcp`

The locally non-terminating test and its helper are byte-identical to the base branch; the PR does not modify them or the invoked evidence-check script.

## Local verification

| Package/check | Result |
|---|---|
| `mcp/ci-mcp`: clean install, production audit, typecheck | PASS |
| `mcp/ci-mcp`: unit tests | PASS — 148/148 |
| `mcp/ci-mcp`: rebuild vs committed `dist`/lock | PASS — no diff |
| `mcp/local-env-mcp`: clean install, production audit, typecheck | PASS |
| `mcp/local-env-mcp`: unit tests | PASS — 51/51 |
| `mcp/local-env-mcp`: rebuild vs committed `dist`/lock | PASS — no diff |
| `mcp/sdd-forge-mcp`: clean install, production audit, typecheck | PASS |
| `mcp/sdd-forge-mcp`: all discovered tests excluding one baseline parity file | PASS — 243/243 |
| `mcp/sdd-forge-mcp`: `golden/deep-verify-parity.test.js` | LOCAL LIMITATION — non-terminating at PR head and base alike |
| `mcp/sdd-forge-mcp`: rebuild vs committed `dist`/lock | PASS — no diff |
| Repository `tests/validate-repository.sh` | PASS |

## Explicit exception

`mcp/sdd-forge-mcp/dist-test/tests/golden/deep-verify-parity.test.js` does not terminate locally. In an isolated run Node reports a cancelled test with `Promise resolution is still pending but the event loop has already resolved`; the remaining golden tests pass. A second detached worktree at base `3749a252af31c504387c4cb8855342261c41dbbd` reproduces the same non-termination and diagnostic after compiling the tests. This is therefore a baseline/environment limitation rather than a PR #386 regression. The base clean install also reproduces the vulnerabilities targeted by this PR (one high and one moderate), whereas the PR head production audit is clean. The limitation remains explicit rather than being counted as a local pass.

## Remote evidence

At the verified head, all GitHub checks shown for PR #386 were green, including the repository OS matrix and CodeRabbit. Remote evidence supplements but does not replace the local checks above.

## Gate recommendation

This packet authorizes no merge. An independent reviewer must inspect the exact head and this exception. Integration remains subject to current-head revalidation, owner handoff, repository SDD policy, and explicit human authorization for any commit/merge/push action.

Independent review gate: PASS (0 Critical, 0 Warning). Independent QA gate: PASS (243 passed, 0 failed, 0 cancelled; the base-reproduced parity file remains explicitly unexecuted).
