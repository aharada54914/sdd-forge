# A7 remaining regression and dependencies — 2026-10-06

Diagnostic only; no formal review, reservation, permission approval or task-state decision.

Owner: `/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge`.
HEAD independently read with `rtk proxy git rev-parse HEAD`: `25813ee4baf8ae8fff344a6c979da61fbd23d2c7`. Dirty work remains separate from this commit identity.

## Executed

- `rtk proxy git diff --check`: exit 0, no output.
- `rtk proxy bash plugins/sdd-quality-loop/scripts/check-workflow-state.sh --feature epic-195-a7-compatibility`: exit 1:

```text
workflow-state: epic-195-a7-compatibility: stage-provenance: impl reviewer manifest input hash is stale
```

This is the current unresolved implementation-policy provenance boundary. A22 spec success does not satisfy it. No status was changed and no attempt was reserved.

## Duplicate regression avoided

The 2026-10-04 `verification/T-010/current-working-tree-regression-20261004.md` already records PowerShell allowlist 32/0, Bash/PowerShell consistency 34/0 and 38/0, byte-identical 25/0 each, and escalation activation 12/0. The initially suspected unrun PowerShell allowlist was therefore not rerun.

Read-only SHA-256 checks matched the earlier records exactly for these six sources:

- `tests/skip-allowlist-manifest.tests.ps1`: `e5fc5b574b6bf625fdf434057db3afe6a75b238f531db8ae8584d8a53a4d8e82`
- `tests/lib/skip-allowlist-evaluator.ps1`: `27cb8ac6b1974614a9c8908cf3a7a8f28624480b81ca0b5b19255f6eeee1af7b`
- `tests/lib/skip-allowlist-evaluator.sh`: `ac68f74849237b00739c37028e745b9a2ee3ec5eca00dda4abc2e94c314cb5c3`
- `tests/escalation-skip-activation.tests.sh`: `8f67b3e31bb9e4845c07edeb0afe81071599ba6d7fd462b6a19e6015d630e6ed`
- `tests/loop-consistency.tests.sh`: `15c8a87ed706a7c1476fde5695e5a7720498d9f34f8903c9fbe3ce4dcd3b7ba1`
- `tests/compatibility-byte-identical.tests.sh`: `eff2a7e26bf46db943d834b9188da5d6cac47076e794593add6a28ff6635ac62`

These comparisons do not re-establish all transitive inputs or final-head CI, and macOS PowerShell is not Windows proof. The newer structural success and A21 original-path 53-case success remain separately recorded; neither was repeated here.

## Remaining dependencies

- T-008: real interviewer invocation remains missing. `a7-t008-normal-resume-20261006.md` preserves actual host approval refusal and absent genuine signed positive input. Do not retry, weaken activation, or count a zero-call fixture as native proof.
- T-010 depends on T-003/T-004/T-006/T-007/T-008 (`tasks.md:1411`). T-013 depends on T-002/T-003/T-004/T-010 (`tasks.md:1908`); T-011 depends on T-001 through T-010 plus T-013 (`tasks.md:1563`). Native evidence, provenance re-review, task lifecycle and quality gate remain distinct obligations.
- Current printable-command candidate remains unapplied, SHA `2cef5ab667de9aac60d0dc4bff2c1cc19a7156c789fa9ebade4ebd80b53127cf`. Its four pure-string test groups are not native allow acceptance. No allow rule replacement, child restart, executor change, formal reservation or protected edit occurred.

No additional unrun local functional case was identified that would close the remaining native/provenance obligations under the current restrictions. This is not a claim that every repository test has run.
