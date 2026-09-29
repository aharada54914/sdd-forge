# Issue #137: JournalHeader / Decision admission

Partial T-001 implementation; not a formal review or completion record.

## Fixed RED

On macOS 27 arm64 / Node 24.13, executed once:
`rtk proxy node --test tests/sdd-context/validation.test.mjs`.
91 tests: 88 passed, 3 failed, 0 skipped; exit 1. All original 79 passed.
HEADER-VALID, DECISION-VALID and DECISION-REDACTION failed because the shared
admission function rejects the two unimplemented types. Passing negative
controls alone do not prove their field checks.

| Artifact | SHA-256 |
|---|---|
| Fixed test | `19567de75dba7197f3d968a905b49f5a71462d7628a9ab7899521578f05788cc` |
| Pre-fix source | `5dccf1bf3d739a10b2fd565122771ce4e69c22e41562dd1ac4200f33aca7e9d6` |
| RED stdout | `76a56ca158ad4ea6ffdc57f86975da55bd9f03123d32d25d55edac5817cb5bc5` |

LockV1 remains unsupported: the approved design does not define PID type/range
(`specs/sdd-context-continuity/design.md:95`). Header coverage requires a
non-null digest; it introduces no chain-start convention. Persistence, native
activation, full CI and quality-gate completion remain unverified.
