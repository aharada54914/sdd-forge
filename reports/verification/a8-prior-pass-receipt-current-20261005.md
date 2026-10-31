# A8 prior-PASS receipt boundary — 2026-10-05

Supplemental fixture evidence only. No formal verdict, fresh implementation report, native allocation, reservation, protected apply, or lifecycle transition.

## Scope and current observation

Owner: A8 release-sync worktree. Read-only git status confirmed 11 existing tracked dirty files and existing untracked recovery evidence; no external Git operation was performed. The owner AGENTS.md and tester / sdd-verification-apply skills were read. No source or existing artifact was edited.

Current tasks.md still records T-004 Approved / Implementation Complete (lines 675–677); the other seven tasks are Approved / Planned. Existing boundary, context-isolation and empty-phase results were not rerun. The selected additional check covers old PASS receipt reuse after changed evidence, a relevant boundary for current provenance recovery. The test driver and implementation were read fully before execution: they use disposable fixture trees and synthetic identities, not the actual identity ledger or a model session.

## Execution

Owner cwd, login=false:

```text
rtk proxy python3 -B tests/task-prior-pass-receipt.tests.py -v
```

Exit 0; 9 tests passed. Complete merged tool stdout/stderr:

```text
test_provenance_launch_rejects_missing_receipt (__main__.ReceiptLaunchTests.test_provenance_launch_rejects_missing_receipt) ... ok
test_current_future_and_substituted_sources_rejected (__main__.ReceiptUnitTests.test_current_future_and_substituted_sources_rejected) ... ok
test_each_changed_input_prevents_identity_claim (__main__.ReceiptUnitTests.test_each_changed_input_prevents_identity_claim) ... ok
test_launch_rejects_receipt_regenerated_after_input_change (__main__.ReceiptUnitTests.test_launch_rejects_receipt_regenerated_after_input_change) ... ok
test_launch_rejects_stale_or_modified_receipt (__main__.ReceiptUnitTests.test_launch_rejects_stale_or_modified_receipt) ... ok
test_missing_and_duplicate_json_rejected (__main__.ReceiptUnitTests.test_missing_and_duplicate_json_rejected) ... ok
test_same_inputs_have_exact_source_hashes_without_new_verdict (__main__.ReceiptUnitTests.test_same_inputs_have_exact_source_hashes_without_new_verdict) ... ok
test_verdict_counts_require_integers (__main__.ReceiptUnitTests.test_verdict_counts_require_integers) ... ok
test_wrong_identity_nonpass_and_mismatch_rejected (__main__.ReceiptUnitTests.test_wrong_identity_nonpass_and_mismatch_rejected) ... ok

----------------------------------------------------------------------
Ran 9 tests in 0.344s

OK
```

This proves the tested receipt parser rejects missing/stale/modified receipts, changed-input regenerated receipts, current/future or substituted historical sources, identity/outcome mismatch, noninteger counts, and duplicate JSON; exact unchanged sources produce a hash receipt, not a new verdict. It does not establish permission to recover changed inputs or validate any real A8 launch.

## Input pins and preservation

```text
619eedbb4ea142aff2a2d6095067a3a4504a60bd74975f4f0ecbb9003fba5847  tests/task-prior-pass-receipt.tests.py
0dbf6ce090d3da6afe012039fce0f2ae53279b1ab336994ec7204550ef18de6c  tests/task-prior-pass-receipt.tests.sh
52bc01ad07f930d3dffd3788e6a44e506b3a041a502fcc0ffa3a814262ef9e53  plugins/sdd-review-loop/scripts/task-prior-pass-receipt.py
```

Normal shasum before and after execution returned identical:
- identity-ledger.json: 722081ffaa0b21d5cf63abbb0eff4aa85d902f634d378239896da9e260b67143
- canonical T-004.md: 48bf3519745073238f230199b9f5dafdb52fdf1108b5e05071931209fc7c928f

## Remaining boundary

The current owner handoffs still identify the regular proxy-cat classification refusal and missing genuine fresh implementation report. This run did not retry or route around that refusal, and did not independently re-attest the installed guard state. See a8-caller-cat-current-refusal-20261005.md for exact prior command/refusal and a8-recovery-contract-dependencies-20261005.md for the formal shared read-policy prerequisites.

Next meaningful native recovery requires a corrected authorized normal caller read path, actual fresh identities, complete admitted-input manifest/snapshot and a distinct recovery implementation report, followed by independent evaluation. Do not treat this fixture result as fresh implementation, changed-input contract approval, native activation, cross-model completion, CI, or Done. External Git/CI operations remain with the parent. Only this non-frozen note was added.

