# T-010 current working-tree regression observation — 2026-10-04

Status: local regression observation only. This is not a formal review, quality-gate verdict, native-host proof, or completion decision. Existing dirty changes were preserved; this run changed no implementation, protected file, frozen specification, task status, or repository review identity.

Owner: `/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge`. HEAD: `d64cffcb22b114779202847be33e41700c4ba11f`; local `origin/main`: `3a1afcab243fcebb769dc4314599999af4545050`. No remote refresh is claimed. Commands used `rtk proxy` with a non-login shell. PowerShell ran on macOS, not native Windows.

## Executed regression

Every script below used its existing original repository path. Bash rows use `rtk proxy bash tests/<name>.tests.sh`; PowerShell rows use `rtk proxy pwsh -NoLogo -NoProfile -File tests/<name>.tests.ps1`.

| Suite | Bash result / exit | PowerShell result / exit |
|---|---|---|
| skip-allowlist-manifest | 29 passed, 0 failed / 0 | 32 passed, 0 failed / 0 |
| loop-escalation | 36 passed, 1 failed / 1 | 35 passed, 1 failed / 1 |
| structural-compatibility | 60 passed, 1 failed / 1 | 67 passed, 1 failed / 1 |
| loop-consistency | 34 passed, 0 failed / 0 | 38 passed, 0 failed / 0 |
| compatibility-byte-identical | 25 passed, 0 failed / 0 | 25 passed, 0 failed / 0 |

`rtk proxy bash tests/escalation-skip-activation.tests.sh` passed all 12 cases, exit 0. In both runtimes the original consumer succeeds before the dependency merge, fails after merge, and still fails after addition of a caller marker. Its corresponding allowlist audit accepts the pre-merge line and rejects activated and invalid evidence. This verifies the fail-closed consumer boundary; it does not execute a native interviewer host.

`rtk proxy bash -n tests/lib/skip-allowlist-evaluator.sh tests/skip-allowlist-manifest.tests.sh tests/escalation-skip-activation.tests.sh tests/loop-escalation.tests.sh` and `rtk proxy git diff --check` exited 0. `rtk proxy bash plugins/sdd-quality-loop/scripts/check-workflow-state.sh --feature epic-195-a7-compatibility` exited 0 with `workflow-state: ok`, plus its existing investigation amendment-growth tolerance diagnostic. Fixture `REVIEW_CONTEXT_OK` outputs from loop suites are synthetic test results, not live review reservations or gate results.

## Actual failures and ownership

Both escalation suites fail with the same observed line:

```text
FAIL: TEST-019.10b: merged resolver dependency is active but no real interviewer invocation was driven
```

This is the unresolved T-008 AC-004/AC-021 obligation exposed by the corrected merge-only activation. Zero spy calls from fixture construction do not establish non-invocation after a real host decision. The existing `verification/T-008/path-spy-repair-20261004.md` documents why explicit-path dispatch can bypass a PATH spy, and why its synthetic positive self-call is not native proof. That host denial was not retried by this run.

Both structural suites fail with:

```text
ERROR: AC-042 emitted after activation condition became true
FAIL: emitted dependency skips remain allowed on origin/main
```

`tests/structural-compatibility.tests.sh:268` still unconditionally emits the F3/AC-042 line, while only F4 has a merge-aware activation branch at lines 260–267. The PowerShell twin emits the same F3 line. T-004 owns these structural assertions (`tasks.md:585-696`); T-010 explicitly excludes authoring the gated assertions (`tasks.md:1498-1503`). Earlier 61/0 and 68/0 structural results are historical and are not the result against these current integration receipts. Do not remove the audit or change merge truth to recover green.

Remaining: T-004 F3 activation/assertion completion; T-008 actual host positive control and F1/F3/F4 negative evidence; the A5 citation semantic reconciliation and formal re-review described in `prospective-contract-repair-20261004.md`; current candidate CI and independent quality verification. Full aggregate CI was not run here; it cannot be claimed green while these required consumers fail. No failing command was rerun unchanged.

## Tested dirty-source hashes

| Path | SHA-256 |
|---|---|
| tests/escalation-skip-activation.tests.sh | 8f67b3e31bb9e4845c07edeb0afe81071599ba6d7fd462b6a19e6015d630e6ed |
| tests/fixtures/skip-allowlist-manifest.json | 7bf84702a21059211f0b4d43189fbb88fc6a1decb933a59fb04206df8b1dc15a |
| tests/lib/skip-allowlist-evaluator.ps1 | 27cb8ac6b1974614a9c8908cf3a7a8f28624480b81ca0b5b19255f6eeee1af7b |
| tests/lib/skip-allowlist-evaluator.sh | ac68f74849237b00739c37028e745b9a2ee3ec5eca00dda4abc2e94c314cb5c3 |
| tests/loop-escalation.tests.ps1 | d212322fec9b98853403bfef170dc35be87ef8034b0c384e5020eced0e0a6775 |
| tests/loop-escalation.tests.sh | 6fddc557873d8d1062baca55c1ea2959e2244412e1d6e1f7d1c20c94c131f44d |
| tests/skip-allowlist-manifest.tests.ps1 | e5fc5b574b6bf625fdf434057db3afe6a75b238f531db8ae8584d8a53a4d8e82 |
| tests/skip-allowlist-manifest.tests.sh | fc5f203d5f278430435d237bf66d141fc455834d04430376a818be1f737765a1 |
