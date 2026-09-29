# Issue #137: Reconcile request admission

Scope: approved T-001, shared in-memory input validation only. No persistence, native activation, task completion or issue closure is claimed.

The design's `ReconcileV1` request was rejected by the shared validator's unimplemented-contract default. Existing real-Git fixtures and Observation validation remain unchanged.

Before production changes, `rtk proxy node --test tests/sdd-context/validation.test.mjs` exited 1: 66 tests, 51 passed, 15 failed, 0 skipped. All 37 pre-existing tests and the new owner/Git/path fixture control passed. The 15 failures were valid Reconcile requests rejected with `validation-rejected`, including nested-text redaction. Negative cases alone do not prove the unimplemented checks.

RED source SHA-256: `ff9f7b869ebc439efb809924a5ae19f42476d036824715a2faad990b232c2678`.
Fixed regression suite SHA-256: `110387cc3c1f56b9995b6792e8c39282059b080445a7c0a7a64a6f1bf69e2a9f`.
RED stdout SHA-256: `7c6512bd01edf70f90a31a9530b48f984bbe88f145a20b982663d18af2e82d6e`.

The fix shares the existing Observation validator between standalone and nested inputs, enforcing the Reconcile closed schema and conditional records requirement before the existing redaction and owner/path/Git checks. No new persisted fields or dependencies were added.

The unchanged suite then passed 66/66; the existing JSON-admission and privacy suites passed 31/31. Both commands exited 0, with no skipped tests and empty stderr, on macOS with Node v24.13.0. Production fix attempt: 1.
GREEN source SHA-256: `2eaa0ea4adb0ae972569aa7df896c61210da99bd267b98bba843d5c1a1e74f17`.
GREEN stdout SHA-256: `e83bcd60018c37ff4064f835d322da5a06ea094129491d424964ebe5f9a24143`.
Regression stdout SHA-256: `716b7124e978b7c0e0f1ae8cddccf502286e6daedb8168678d45eb0b4aaa3550`.

Independent read-only review: `/root/rt002_envelope_review`, ordinary Reconcile review following RED commit `653678caaabe4397e4525617669fd6a4e38ee3ad`; Critical 0, Major 0, Minor 0. The reviewer verified source/test/log hashes without rerunning or changing files. This is not a formal quality-gate verdict.

Remaining T-001 contracts, current-head CI, native host activation, independent quality gate and main integration are not established by this record. Task and Issue completion remain pending.
