# T-001 final-byte evidence follow-up

This addendum preserves the frozen implementation report and the historical NEEDS_WORK evaluation (run 028aa5f2-3d0d-4eb7-b37e-f5514cc32173). It does not change approval, task status or any verdict.

## Final-byte native binding

That launch's dependencies.json pins the implementation before the native probe. The launcher rechecks those same dependencies after the probe and before reservation (launch-impl-review.py:310-382). The observed native probe succeeded before sequence 1200 was reserved; the subsequent evaluator delivery succeeded but returned NEEDS_WORK. Delivery is not evaluation success.

Final source hashes in that dependency record:

| Source | SHA256 |
| --- | --- |
| validate-nontty-spec-launch.py | a6c7c49fe568b7fbd539a23a03e9ab591844dae201dbb2120bb27f09183036f1 |
| probe-nontty-review.py | 13b20038c62d67a63d90b7c7fbbcb15f87b69f6789e0d9984dc5b08a17d263f9 |
| preflight-host-review.py | 562a12aa016456dabf215af524f453d7713878dc47f5de58d964dc2626831a67 |
| launch-impl-review.py | 180259940e5cb050f95cfde64e1557faf57cb1b64202a6873fd171a157659775 |
| preflight-evaluator-delivery.py | 5fb9aa083ece03502365e1a145ba1074c2b25dd5548c427814a799708942753e |
| review-conditional-inputs.py | 269aa324700d52e147ff5fbee2abc523d0edcf9329abc625738bd2c1d456e2bd |

The observed native result confirmed admitted reads, control reads, original invocation read, outside-read denial, compound-Bash denial and existing-session collision rejection. The diagnostic session was b72a5c8b-7ceb-41c3-8863-4b811a0c26f6; it made no reservation. Raw transcript SHA256: f98ecf89ea8f7fe01154e4ab23bb0b3fc4591b9d4c3da7787b3d66cef2f7b69b. These are caller observations, not a substitute for independent evaluation.

## Independent diff review and scope

The independent final_scope_audit agent checked all 30 Outputs hashes and executed 72 tests with zero skips: quality transport 19, host preflight 7, ordering 8, structured output 13, conditional inputs 16, task launch 9. It reported no blocking correctness finding in the final six-source narrowing and related test/configuration scope. It did not rerun static checks, build, native delivery or CI. This review supplements, rather than replaces, the older three-file review.

T-005 still owns conditional-input completeness and ordering acceptance. Their helpers/tests are pre-existing dependencies used by T-001; their inclusion in an input inventory does not complete T-005. The quality helper and ordering suite were byte-identical to their implementation snapshot. The conditional helper's change was a two-line missing-loader narrowing, not a new input-selection policy. The bounded lint/typecheck/build scope and authorization are recorded in reports/verification/shared-launch-python-validation-blocker.md. Permanent CI completion belongs to T-004. No task is declared Done here.

## Limits and historical clarification

The implementation report's later Implementation Complete heading is current; earlier In Progress text and malformed historical table cells are retained history. Its canonical Outputs contains 30 unique entries, checked against disk by the preparer. The rollback's later reverse check succeeded (43 tests plus one build); this does not prove pristine-HEAD or native-host rollback. Seven isolated-baseline PowerShell failures remain assigned to T-005. Python 3.9 runtime, Windows, full CI and merge remain unverified. Quality-stage reject-before-reservation and shared-builder linkage have line-level inspection evidence, not a dedicated native failure injection. No frozen evidence is rewritten to erase these limits.
