# Issue #137 — JournalRecordV1 selected RED

Root checkpoint: `7e75329c31d64dbc8e231d9b276f99dfb4edc376`.

Command (one execution):
```text
rtk proxy node --test --test-reporter=spec --test-name-pattern=^JOURNAL- tests/sdd-context/validation.test.mjs
```

UTC: `2026-09-29T14:02:18.440400+00:00`–`2026-09-29T14:02:18.729654+00:00`. Node `v24.13.0`, Darwin arm64, `login:false`. Actual exit **1**: **13 tests, 5 pass, 8 fail, 0 skipped**. Six kind admissions, optional admission and redacted-record preservation fail at the existing default rejection. Rejection-only passes do not establish JournalRecord support; sequence maxima and later grouped positive branches are not reached in this RED.

Synthetic inputs only. Raw stdout: 3,076 bytes, SHA-256 `56bdcfcb4a4e8d23881e7c9b1a4ef339576e4805f6107535c7140dd45b1ceabe`; stderr: empty. Private run metadata SHA-256 `f8a8d51fa049ed66b78345a33475511623b63f4e4faedfbb7f0bcbfe10a8b248`.

Production, fixed privacy tests, frozen artifacts, state/approval/ledger/registry and prior proof hashes match the prepared inputs. Original 112 validation bodies retain their exact 47,787-byte prefix; only JournalRecord tests were appended. HEAD and all 27 inputs stayed unchanged during the run; all 33 prior proof identities remain unchanged. T-001 remains incomplete. Stop before production for root's RED review/checkpoint; no worker commit or push.
