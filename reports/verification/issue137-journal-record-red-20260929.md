# Issue #137 — JournalRecordV1 selected RED

Root checkpoint: `7e75329c31d64dbc8e231d9b276f99dfb4edc376`.

Command (one execution):
```text
rtk proxy node --test --test-reporter=spec --test-name-pattern=^JOURNAL- tests/sdd-context/validation.test.mjs
```

UTC: `2026-09-29T14:02:18.440400+00:00`–`2026-09-29T14:02:18.729654+00:00`. Node `v24.13.0`, Darwin arm64, `login:false`. Actual exit **1**: **13 tests, 5 pass, 8 fail, 0 skipped**. Six kind admissions, optional admission and redacted-record preservation fail at the existing default rejection. Rejection-only passes do not establish JournalRecord support; sequence maxima and later grouped positive branches are not reached in this RED.

Synthetic inputs only. Raw stdout: 3,076 bytes, SHA-256 `56bdcfcb4a4e8d23881e7c9b1a4ef339576e4805f6107535c7140dd45b1ceabe`; stderr: empty. Private run metadata SHA-256 `f8a8d51fa049ed66b78345a33475511623b63f4e4faedfbb7f0bcbfe10a8b248`.

Production, fixed privacy tests, frozen artifacts, state/approval/ledger/registry and prior proof hashes match the prepared inputs. Original 112 validation bodies retain their exact 47,787-byte prefix; only JournalRecord tests were appended. HEAD and all 27 inputs stayed unchanged during the run; all 33 prior proof identities remain unchanged. T-001 remains incomplete. Stop before production for root's RED review/checkpoint; no worker commit or push.

## GREEN after root RED checkpoint

Root checkpoint: `6f7a737cb6160ae6c4ddcb4ae092d05d70876744`. Only a JournalRecordV1 switch case was added using existing validation helpers. Already-redacted text is compared with shared scanner output and rejected if changed; admitted text/hash/omission remain exact.

Fixed commands, each executed once:
```text
rtk proxy node --test --test-reporter=spec tests/sdd-context/validation.test.mjs
rtk proxy node --test --test-reporter=spec tests/sdd-context/json-admission.test.mjs tests/sdd-context/privacy.test.mjs tests/sdd-context/privacy-grammar.test.mjs
```

Actual validation: **125/125**, exit 0, skipped 0, UTC `2026-09-29T14:08:48.784496+00:00`–`2026-09-29T14:08:59.278680+00:00`; privacy/JSON: **34/34**, exit 0, skipped 0, UTC `2026-09-29T14:08:59.294081+00:00`–`2026-09-29T14:08:59.377076+00:00`. Same Node v24.13.0 / Darwin arm64 / login:false. Both stderr streams are empty. Validation stdout SHA-256 `091c9952fe4a6fa04276c3b481e44c0c06721166dcd7caf4791b929b1e8f5626`; privacy stdout SHA-256 `9321fac0a35e27e27c5c0ec9fc6c20f8ba52ad319c11dd806e3cbfaa6d92bc4d`.

Current validation source SHA-256 `a4e062c8d22d60e901ba152719ce960d0d6f5978d01e4c03ae8a0ae434c3a777`. Fixed tests, other production, frozen/state/approval/ledger/registry and all 40 earlier proof identities are unchanged. No digest/chain verification or persistence was added. T-001 remains incomplete; handed to root ordinary independent review without worker commit/push or quality-gate verdict.
