# A8 PR513 current boundary verification — 2026-10-05

Non-frozen supporting evidence only; not an implementation report, native activation receipt, formal evaluator verdict, or Done decision.

Owner: `/Users/jrmag/.codex/worktrees/a8-release-sync-oct01/sdd-forge`
Local HEAD: `495c88d67af44530687ecea3ce9fb0a90a336539` with existing dirty recovery changes preserved.

## Current input and execution

The eight applied recovery files were rehashed with `rtk proxy shasum -a 256 --` and matched every after pin recorded in `a8-t004-recovery-current-limited-regression-20261005.md`. No source, skill, contract, task state or ledger was edited.

Executed in owner, login=false:

```text
rtk proxy bash tests/review-context-boundary.tests.sh
```

Exit 0. This run closes the earlier truncated boundary-output capture gap, rather than treating the older green result as current proof. Full merged tool stdout/stderr (no tool truncation marker) is preserved in `a8-pr513-boundary-full-20261005.log`, SHA-256 `e172866fec189d1cc1408e7f4de524297514aeda761e7b4b6eddcaeea9003bb4`.

- 32 citation anchors verified.
- TEST-RCB-001..010 and 005b succeeded in Bash and PowerShell, including verify-after-reserve, unrelated ledger extension, field mismatch, double reservation and partial identity collision rejection.
- Runtime unit tests: 3, OK.
- Investigation completeness: regular 116 PASS / 0 FAIL; hardlink 84 PASS / 0 FAIL; symlink 84 PASS / 0 FAIL. The earlier note's final 84 count alone was not the whole-suite count.
- Tests use disposable fixture ledgers; no real reviewer identity was reserved. macOS pwsh execution is not Windows-native proof.

Before and after execution, actual owner ledger remained `722081ffaa0b21d5cf63abbb0eff4aa85d902f634d378239896da9e260b67143`; historical canonical T-004 report remained `48bf3519745073238f230199b9f5dafdb52fdf1108b5e05071931209fc7c928f`.

## Current GitHub CI

Read-only `gh pr view 513 --repo aharada54914/sdd-forge --json headRefOid,state,statusCheckRollup` observed OPEN, latest head `ac97422d6e347f4899a32d16fa9ceddc51b10416`, 38 of 38 checks/statuses SUCCESS, including required-checks. Run: https://github.com/aharada54914/sdd-forge/actions/runs/37162860278 . Latest completion was 2026-10-04T00:08:12Z. This published head differs from local HEAD and excludes uncommitted changes; it does not certify the local recovery delta. No CI rerun, fetch, commit or push was performed.

## Remaining formal boundary

T-004 remains Approved / Implementation Complete (`tasks.md:675,677`), not Done. The latest handoff `a8-t004-recovery-current-limited-regression-20261005.md` records an unresolved caller proxy-cat refusal; this run did not retry the refused role read or substitute another executor. A corrected normal caller read path must be established before native launch. Then a genuinely fresh implementation context must receive observed identity, validated complete manifest/snapshot and current inputs, emit a distinct recovery report, and undergo independent evaluation. This long-lived coordinating context is not that fresh implementer. Old panel verdicts bind the old digest and cannot certify current admitted evidence. No formal evaluator, panel, aggregate or evidence bundle was created.

An auxiliary rg command placed `-g` after `--` and returned ordinary missing-file errors; it was not a protective refusal, and made no change. Verification operations encountered no new protective refusal.

Only this note and its full log were added. Existing historical evidence remains unchanged. The verification-apply and tester skills were used to separate applied bytes, local fixture regression, published-head CI, and outstanding formal gates.
