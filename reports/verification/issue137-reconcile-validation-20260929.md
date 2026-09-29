# Issue #137: Reconcile request admission

Scope: approved T-001, shared in-memory input validation only. No persistence, native activation, task completion or issue closure is claimed.

The design's `ReconcileV1` request was rejected by the shared validator's unimplemented-contract default. Existing real-Git fixtures and Observation validation remain unchanged.

Before production changes, `rtk proxy node --test tests/sdd-context/validation.test.mjs` exited 1: 66 tests, 51 passed, 15 failed, 0 skipped. All 37 pre-existing tests and the new owner/Git/path fixture control passed. The 15 failures were valid Reconcile requests rejected with `validation-rejected`, including nested-text redaction. Negative cases alone do not prove the unimplemented checks.

RED source SHA-256: `ff9f7b869ebc439efb809924a5ae19f42476d036824715a2faad990b232c2678`.
Fixed regression suite SHA-256: `110387cc3c1f56b9995b6792e8c39282059b080445a7c0a7a64a6f1bf69e2a9f`.
RED stdout SHA-256: `7c6512bd01edf70f90a31a9530b48f984bbe88f145a20b982663d18af2e82d6e`.

Implementation and GREEN validation are pending. Current-head CI, native host activation, independent quality gate and main integration are not established by this record.
