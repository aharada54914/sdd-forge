# Issue 137 — LockV1 test-only RED

Date: 2026-09-29
Checkpoint: `0e246666c23bd48b484fef5483aadb0fc76f2170`

Approved PID definition: `issue137-contract-completion-addendum-20260929.md:38` specifies a positive safe integer, inclusive 1..Number.MAX_SAFE_INTEGER. Existing closed five-field schema: `specs/sdd-context-continuity/design.md:95`; opaque identifiers: approved addendum line 14.

Replaced the obsolete unsupported-PID control with invalid-PID cases and appended 7 Lock-specific cases in `tests/sdd-context/validation.test.mjs`. The other 104 previous bodies are byte-preserved. No production change.

Executed once:

```text
rtk proxy node --test --test-reporter=spec --test-name-pattern=^LOCK-V1- tests/sdd-context/validation.test.mjs
8 tests / 6 pass / 2 fail / 0 skip; Node exit 1
```

The PID 1 and MAX_SAFE_INTEGER acceptance cases fail with content-free `validation-rejected`: Lock dispatch remains unimplemented (`plugins/sdd-context/validation.mjs:171`). Rejection cases passing while the entire type is unsupported do not prove field-specific validators. Previous 104 unchanged bodies and the 31 JSON/privacy regression bodies were excluded.

Test SHA-256: `1d4f267df42b80de82c89cda5d6176654633e8e82265f27a74c55d372e9f41d0`
Actual command/counts/exit/UTC times, raw logs, input hashes and unchanged-state checks are private task evidence under `specs/sdd-context-continuity/verification/T-001/lock-red-20260929-01a0ebb9/`.

Stop for the root RED checkpoint. No Git mutation, approval/status, frozen specification, ledger/registry, review verdict or formal quality gate was performed. JournalRecord, OwnerRegistry, Outcome, persistence, native process proof and lock acquisition/removal remain outside this slice. T-001 remains incomplete.
