# PR512 local main integration

- PR head / unchanged local HEAD: `4fbc6bf09fa571dd162b1627123ecf37b6869484`.
- Fetched main / MERGE_HEAD: `977a87e4da38905d8e237cbb79acf9159959e773`.
- Merge command: `rtk proxy git merge --no-commit --no-ff origin/main`.
- Only conflicted file: `tests/cross-model.tests.ps1`; resolved and staged. No merge commit, push, native model launch, task/status/approval edit, or quality verdict was performed. Automatically merged main files and the two pre-existing untracked PR517 notes were preserved.

Main #531 retains normal completion (4-second budget, 2000ms slack, 500ms delayed output), separate deterministic deadline evidence, actual timed-wait/HasExited recheck with success/nonzero/incomplete-output cases, and the empty-phase regression. A7 retains synthetic worker stdin consumption, pre-opened diagnostic receipts, extended bounded diagnostic fields, and empty/complete/duplicate/partial receipt fixtures. The production receipt reader remains main's safe string-cast reader so its AST-based empty-phase regression exercises the actual block unchanged in structure. The old 200ms-margin live completion loop was not restored.

## Actual macOS regression results

Commands ran through rtk with login shell disabled; vendor CLI names resolve to suite-created synthetic Python workers, not live vendors.

| Command | Exit | Result | Local log SHA-256 |
|---|---:|---|---|
| `rtk proxy pwsh -NoProfile -File tests/cross-model.tests.ps1` | 0 | 104 passed, 0 failed | `f5eb4bc1b4d237f97cf1cd795378c979bcffd12ee2d4c28ce6c1bad784c25e9b` |
| `rtk proxy bash tests/cross-model.tests.sh` | 0 | 76 passed, 0 failed | `6c33401301f7d08e32f52e4cf192924ff740de8665b7e600befa0feffdbd8a59` |

Logs: `/private/tmp/pr512-main-integration-cross-model-20260929.log` and `/private/tmp/pr512-main-integration-cross-model-bash-20260929.log` respectively. Both process completions returned exit 0. `git diff --cached --check` returned 0; unmerged-path query returned no paths. This is local synthetic regression evidence, not native canary, Windows, new CI, independent review, or Done evidence.

## File digests

- PR-head file: `3f1665c839c94f939404ff2a3c3211de0ee34a403dc27d623f5cc9ac02557d07`.
- Main file: `fddbaacfc4a9f8d41d1d44f8a07f22c8728a847291dfe0600c8beb7126b8ab18`.
- Resolved file: `ae99a81ad29447830389d405f72da17450b9fcc2d4e99a0b24e96049d1e27b7c`.
- Preserved PR517 macOS note: `ce96daa871cfc0b15041acfecdd6c6eddab37481157d10f283843fb5b1a5d714`.
- Preserved PR517 Python note: `7093bed66ef6395311869689c44fe9023b23b9631de4b4776b65f1e513c08669`.

Next action belongs to the main owner: review the resolved merge before any commit or push. T-013 and other task completion work is outside this integration slice.

## Subsequent verification (supersedes the integration-only Git state above)

- Independent ordinary review found 0 Critical, 0 Major, 0 Minor findings for the merge resolution; this is not a formal quality-gate verdict.
- Root committed the resolved merge as `5ebe7df0ab78a0c7e7a01b0f20667194e7eb5936` and pushed it to PR #512. Both parents are `4fbc6bf09fa571dd162b1627123ecf37b6869484` and `977a87e4da38905d8e237cbb79acf9159959e773`.
- Latest-head [CI run 36557040942](https://github.com/aharada54914/sdd-forge/actions/runs/36557040942) completed SUCCESS: all 37 workflow jobs succeeded, including Windows/macOS/Ubuntu suites and required-checks. The separate CodeRabbit check also succeeded. No older-head green result was substituted.
- PR remains Draft and REVIEW_REQUIRED. The authorized approval-review-only exception does not waive mandatory native activation, task quality-gate, latest-main, or post-merge verification. No GitHub merge, Done transition or Issue #195 closure was performed.
- Original A7 challenge startup was denied by PreToolUse before execution. No challenge, nonce, native activation or evaluator identity was produced. This startup refusal is distinct from the already-tested RT002 denial-envelope parser repair.

## Release 1.18.0 synchronization — 2026-10-01

- Merge commit `a1bf96a6d7348dc6c4f48494d68b964dfe56fa20` was pushed without force to `codex/a7-issue195-closeout`. Parents: prior PR head `3a9141eece88695612831a82336e53a8688cb779` and main `49e1602459108fd8ef318b644b51301a3b61d0b1`.
- The conflict-free first-parent diff contains only the 27 main release files. A7 specifications, implementation/quality reports and structural-compatibility tests were unchanged. Five existing untracked notes remained outside the commit.
- `git diff --cached --check`, PowerShell repository validation and the release-validation Bash driver returned exit 0. Repository validation reported 10 role targets with zero drift; release validation passed all 8 parity checks. This macOS PowerShell result is not native Windows evidence.
- Independent ordinary Sol review reported no Critical, Major or Minor findings; it is not a formal quality-gate result.
- Exact-head [CI run 36806893798](https://github.com/aharada54914/sdd-forge/actions/runs/36806893798) was queued when recorded. Earlier-head CI success does not prove this commit. Draft, native-activation and formal-quality conditions remain unchanged; no main merge or Issue closure was performed.

### Terminal CI confirmation

- Run `36806893798` completed SUCCESS on exact head `a1bf96a6d7348dc6c4f48494d68b964dfe56fa20`: all 37 workflow jobs, including required-checks, succeeded. The original run was followed without a rerun.
- Native host activation and formal quality-gate acceptance remain unverified. No Draft change, merge, task Done transition or Issue closure was performed.
