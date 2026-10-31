# #137 T-001 — JournalHeader / Decision RED

Executed once: `rtk proxy node --test tests/sdd-context/validation.test.mjs`.
**91 tests / 88 pass / 3 fail / 0 skip; Node exit 1**. Original 79 all pass; added 12: 9 pass / 3 fail.

Failures `HEADER-VALID`, `DECISION-VALID`, `DECISION-REDACTION` are default rejection of unimplemented types (`validation-rejected`; `plugins/sdd-context/validation.mjs:160`). Passing negative controls do not yet prove per-field enforcement.

| Artifact | SHA-256 |
|---|---|
| Fixed expanded suite | `19567de75dba7197f3d968a905b49f5a71462d7628a9ab7899521578f05788cc` |
| Unchanged production | `5dccf1bf3d739a10b2fd565122771ce4e69c22e41562dd1ac4200f33aca7e9d6` |
| RED stdout | `76a56ca158ad4ea6ffdc57f86975da55bd9f03123d32d25d55edac5817cb5bc5` |

LockV1 remains unsupported: PID has no defined type/range (`specs/sdd-context-continuity/design.md:95`). Header covers non-null hashes only; no null chain-start convention is introduced. No lock acquisition/death proof/persistence or task completion/native/CI/quality-gate success is claimed.

Stop for root's RED commit and GREEN instruction. Production/Git/reservations/approval/status remain unchanged.
