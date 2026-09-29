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

## GREEN

Added five dispatch lines: Header reuses closed/owner/opaque/integer/hash;
standalone Decision reuses the existing decision helper and final redaction.
Fixed 91-case suite: 91 passed, 0 failed, 0 skipped; exit 0.
Existing JSON/privacy regressions: 31 passed, 0 failed, 0 skipped; exit 0.
Each command ran once in the same environment; fixed tests are unchanged.

| Artifact | SHA-256 |
|---|---|
| GREEN source | `5e083fe7165247b4716cf06dba2b87ac730e829830aa4b7b97362278bbd151f7` |
| GREEN stdout | `e7d9603843750b3847373c4c718552ecd31c9d745c9bdbbb73f791a6dd831e8a` |
| Regression stdout | `80a3e991d2a9dc426d3b9aa7fadc40c84b99b801a2391a2803961b8c320c3705` |
