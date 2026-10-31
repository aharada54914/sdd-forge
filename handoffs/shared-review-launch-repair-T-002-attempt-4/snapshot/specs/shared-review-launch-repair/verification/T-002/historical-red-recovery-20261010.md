# T-002 historical RED evidence recovery

Date: 2026-10-10
Feature: shared-review-launch-repair
Task: T-002
Owning checkout: /Users/jrmag/.codex/worktrees/shared-review-launch-integration/sdd-forge
Observed HEAD: 9ce19abe90df0cb83e385f96855e4843318a8807

This non-frozen addendum records a read-only recovery of original session evidence, authorized after the independent diff review. It is not an implementation report, identity reservation, formal verdict, or task-state transition. The checkout already contains extensive tracked and untracked candidate/evidence changes; all are preserved. The sole write in this follow-up is this document. Risk: evidence-provenance reporting; no runtime, authorization, hash recipe, or acceptance contract is changed. Validation consists of direct JSONL call/output inspection and in-memory comparison of historical patch bytes against current files.

## Sources and recovered extraction chronology

Source A: `/Users/jrmag/.codex/sessions/2026/10/06/rollout-2026-10-06T20-16-55-01a110ee-4c5e-78e0-9743-404725070352.jsonl`.
All timestamps below are UTC event timestamps. Original execution checkout was `/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge`. Raw session contents are not copied into this record.

| Call timestamp | Call ID | Direct observation |
|---|---|---|
| 2026-10-06T16:02:24.038Z | `call_cb8026ed2a274f8683c24cbe9779c72c` | Added `tests/review-hash-normalization.tests.ps1`, including an assertion that both callers load the shared helper instead of defining their own function. |
| 2026-10-06T16:02:27.754Z | `call_bffac143e77a4fd7a81edc06c5c8527e` | Ran `rtk proxy pwsh -NoProfile -File tests/review-hash-normalization.tests.ps1`. Output at 16:02:28.529Z: exit 1, `impl must load the shared hash recipe, not define its own`. |
| 2026-10-06T16:02:36.953Z | `call_5c384ef84843490fbe84ff34f3e70459` | Added `review-hash-normalization.ps1`; replaced duplicate `Get-ReviewedHash` definitions in impl/task prechecks with helper dot-sourcing. |
| 2026-10-06T16:02:38.657Z | `call_cdfbb31b6e4240f8a9902c881aa5879e` | Ran the same test. Output at 16:02:39.236Z: exit 0, `ok: shared impl/task reviewed-hash recipe matches baseline for CRLF, case, and invalid inputs`. |

This is authentic pre-extraction RED followed by GREEN for the structural shared-helper requirement. It is not reconstructed after the fact. It does not show a pre-fix hash-output mismatch: the successful test compares the extracted function against the preserved old recipe, intentionally checking unchanged behavior. The first run stopped at the structural assertion before those equivalence cases.

## Current-candidate mapping

On 2026-10-10, the two Source A Add File payloads were decoded in memory, their added lines reconstructed with the recorded trailing newline, SHA-256 hashed, and compared with the owning checkout. No historical files were recreated on disk.

| Artifact | Historical SHA-256 | Current SHA-256 | Comparison |
|---|---|---|---|
| `plugins/sdd-review-loop/scripts/review-hash-normalization.ps1` | `06c8e58f2256f6b8c2ff698a73e6d1308caf5ab73ec2e20e7c8074ea8d991e42` | `06c8e58f2256f6b8c2ff698a73e6d1308caf5ab73ec2e20e7c8074ea8d991e42` | Exact byte equality. |
| `tests/review-hash-normalization.tests.ps1` | `931f507d7ae2cda109689b8cbe35ddec86d3d80028f0fee0f47af26c6e304a47` | `5d922dca8a6d92828315c5349e4b40bd657a9ddeb0388bad77c14e41574220d1` | Only two added cases: `impl-status-lf` and `impl-status-crlf`. Original failing structural assertion and original cases remain unchanged. |

This maps the original extraction/test to the current helper and test, not every byte of the current precheck callers or all T-002 outputs. Existing current execution and baseline-recipe comparisons remain in `independent-verification-20261010.md`; they are separate from the historical execution above.

## Traceability failures are fixture errors, not product RED

Source B: `/Users/jrmag/.codex/sessions/2026/10/06/rollout-2026-10-06T23-42-24-01a111aa-6f79-7640-8803-c95e9297ed35.jsonl`.

| Timestamp | Call ID | Direct observation |
|---|---|---|
| 2026-10-06T16:14:44.991Z | `call_db6607a2004c45fcbeca89b36001d3ad` | Started `rtk proxy python3 -B tests/traceability-freeze-contract.tests.py`; returned session 91387. |
| 2026-10-06T16:15:35.320Z (output) | `call_a12db4aefe7a4a1ea99b765c23102e13` | Polled session 91387: exit 1, 2 tests in 36.093 seconds, 3 failures. Relevant errors: `Evidence fixture cell not found` and `feature specification directory must be a real directory`. |
| 2026-10-06T16:16:12.816Z | `call_fb085aae66e04f979cfd4b00391b9e84` | Patched only the new test driver: supplied an Evidence column and copied the script tree byte-for-byte into the disposable fixture to respect PowerShell script-root resolution. Reran test; session 98581. |
| 2026-10-06T16:17:32.859Z (output) | `call_0f44f7f6de36405ba4f6ce23e64601b6` | Polled session 98581: exit 0, 2 tests in 40.363 seconds, `OK`. |

These failures did not motivate a validator implementation change and must not be counted as product RED. The successful run verifies the existing persisted-normalization/raw-prelaunch boundary, not a newly repaired product behavior.

## Narrow correction and remaining acceptance boundary

The earlier statement in `independent-verification-20261010.md` that authentic T-002 pre-fix RED was not located reflected the evidence then inspected. This addendum supersedes that statement only for the shared-helper structural extraction. The earlier record and all its limitations are preserved unchanged.

This recovery does not itself establish full T-002 acceptance. Outstanding proof/admission boundaries include the complete approved Done When mapping, final admitted implementation contract/snapshot and source/test hashes, formal independent quality-gate evaluation, and applicable final-head CI. No authentic product RED for the traceability clarification or every other T-002 output is established here; the approved workflow must decide their applicable evidence requirements without relabeling fixture errors. Native/installed rollback or installed-host baseline trust is not claimed. The T-001-only RT-20261009-001 substitute authorization is not extended to T-002. No new post-hoc RED was generated, and no source, task, approval, ledger, reservation, historical verdict, or status was changed.
