# A8 T-004: existing recovery contract dependency

## Superseding correction and actual application refusal

The earlier seven-file candidate and its SHA below are INVALID and must not be applied. Its generation used the wrong reference-document directory (`sdd-quality-loop` instead of `sdd-review-loop`) and included a diagnostic line. `git apply --check` alone did not expose this missing-file omission. The corrected eight-file candidate is `reports/verification/a8-t004-recovery-reviewed-v2.patch`, SHA-256 `8753ffcec3c8735791160ac5cddc225449b2e8f40961b850484d9e8a0493fe88` (386 additions / 59 deletions), with before/after SHA-256 pins in `a8-t004-recovery-v2-pins.json`. Its applicability check exited 0. No claim that the boundary reference already matched remains current.

A normal `apply_patch` attempt was rejected before execution:

> SDD決定論ゲート: エージェントはゲートスクリプト・フック設定・テストファイルを書き換えられません。これらのファイルは強制チェーンの一部です。sudo でもバイパスできません。

All attempted targets remained clean. No alternate writer or isolated-copy application was used. Consequently the four regression suites and reserve fixture have NOT run against the candidate in A8. Historical reports, IDs, ledger and verdicts remain unchanged.

Human-only command (agent has not executed it):

```sh
cd /Users/jrmag/.codex/worktrees/a8-release-sync-oct01/sdd-forge
rtk proxy node reports/verification/a8-t004-recovery-human-apply.mjs --apply
```

The helper verifies owner, patch digest and every before hash; stops on any overlapping change; checks applicability; copies all eight originals into a fresh single backup with pinned metadata; applies only this patch; and reads every resulting hash back. It does not alter the historical implementation report. `node --check` passed. It does not change evaluator read-only semantics or add an evaluator-self canary requirement. Any separate startup-contract edit must be reconciled through a newly reviewed/pinned candidate if its before hash changes.

The helper also parses every diff/file/index/hunk header, counts hunk old/new lines, rejects nonpatch text, and requires exactly the ordered eight pinned targets. Its check-only invocation (without `--apply`) exited 0: `CHECK ONLY: all before hashes and patch applicability verified`. A separate read/hash audit read all eight source files successfully and matched every after hash (eight `SOURCE_READ_HASH_OK` rows). The corrected generation admitted only successful file diffs beginning with `diff --git` and rejected diagnostic text; file-diff exit 1 denotes differences, not an execution failure. No human application was executed. An initial helper-parser check rejected a section-separating newline; this parser-only issue was corrected before the successful check-only run.

The reserve fixture was read completely before reuse; only its owner path and introductory comment changed. Source SHA-256: `1c4474c42b37ed8b6c1ae4fd9f36599576b24bc6f1590b8a85bb1ba9ace23d75`. A8 file `reports/verification/a8-t004-recovery-reserve-fixture.sh` SHA-256: `8a08d619a91d099fd59fb639c53ce14be39f861d18f8cb53a58c1f706c5408bf`. `bash -n` passed. It uses freshly allocated disposable ledgers and exercises both shell validators; no production reservation occurs. After human application, run this fixture in addition to the four suites listed below and retain complete output.

This is a candidate preparation record, not an applied contract, implementation recovery, evaluator reservation, or quality verdict.

## Current observations

- Owner: `/Users/jrmag/.codex/worktrees/a8-release-sync-oct01/sdd-forge`; HEAD `495c88d67af44530687ecea3ce9fb0a90a336539`.
- Remote main observed with `git ls-remote`: `164767d998240b33f8622849729fb46f55e0a3d3`. GitHub contents at that exact SHA contain neither `implementation_manifest` / `task-input-manifest` in the Bash validator nor the pre-reservation archive/recovery contract in quality-gate SKILL. Updating from main alone does not supply this dependency. Local `origin/main` was older (`3a1afcab243fcebb769dc4314599999af4545050`).
- Source: current files in `/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge`, HEAD `3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9`. Source changes are working-tree changes, not claimed committed content. This reuses the existing issue #423 repair, including its later identity/citation and authorization-boundary corrections; the original historical candidate was not applied.
- Candidate: `reports/verification/a8-t004-issue423-recovery-candidate-20261004.patch`, SHA-256 `b0e4883e9585ef2c0d4d1660954c094b5224dc0a920d0985cb346a7154b27713`.
- Seven changed files, 361 insertions / 41 deletions: quality-gate SKILL, both validators, boundary tests, scratch-isolation tests, scratch-history tests, agent-isolation tests. The boundary reference already matches the source and needs no diff.
- `rtk proxy git apply --check reports/verification/a8-t004-issue423-recovery-candidate-20261004.patch`: exit 0. This is applicability only; no patch application was performed.
- The seven targets had clean `git status --short` output at preparation time. Recheck before applying, especially alongside the separate evaluator-startup contract work.
- Historical implementation report remains unchanged: `reports/implementation/epic-196-a8-integration/T-004.md`, SHA-256 `48bf3519745073238f230199b9f5dafdb52fdf1108b5e05071931209fc7c928f`.

## Preserved contract boundaries

The candidate requires a pinned implementation task manifest for new evaluator reservations, report/task/run/session agreement and exact manifest citation, while rejecting identity reuse. Merely declaring an implementation input does not authorize arbitrary evaluator source access: source artifacts still require exact Outputs or sanctioned gate-report declarations. Existing peer, path, symlink and hash checks remain in force.

Recovery preserves historical bytes in an archive and requires newly observed isolated execution, actual identifiers and canonical scratch root. Canonical adoption is allowed only after independent verification of the old and new reports and their hashes. This preparation does not archive, overwrite, adopt, or retrofit any historical report or ID. No evaluator-self canary requirement is added. T-004 synthetic behavior is not T-005 native activation proof.

## Required candidate regressions

Run against the correctly applied candidate, not against the unchanged A8 validator and not as evidence from another feature:

```sh
rtk proxy bash tests/review-context-boundary.tests.sh
rtk proxy python3 tests/issue311-scratch-isolation.tests.py --repo .
rtk proxy python3 tests/review-scratch-history.tests.py --repo .
rtk proxy bash tests/review-agent-isolation.tests.sh
rtk proxy git diff --check
```

The source owner additionally provides `reports/verification/issue423-quality-launch-reserve-fixture.sh`, covering manifest/report identity negatives and undeclared-versus-declared archive admission in disposable ledgers. Its current bytes should be reviewed and pinned before reuse in A8; it is not implicitly part of this seven-file candidate. Existing source-owner results are historical dependency evidence, not an A8 rerun.

After contract adoption and the required regressions, perform fresh isolated T-004 revalidation against hash-pinned current inputs, preserve full logs, write a new noncanonical recovery report and task manifest with observed Run/Session/Scratch identity, and independently verify both report hashes before any sanctioned canonical adoption. No native handshake, evaluator identity, consensus PASS, evidence bundle PASS, or Done may be inferred from these steps alone.
