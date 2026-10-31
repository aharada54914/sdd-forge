# Issue 423: quality launch contract audit

This is a read-only contract audit, not a quality-gate verdict or reservation.
PR #535 head: `3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9`.

The canonical Registry dispatcher now passes all nine checks. The five Registry diagnostics recorded on September 30 are historical, not current failures. The old review ticket remains open because it also requires a fresh complete quality gate.

## Current launch blockers

- `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md:183-195` requires the invoking implementation identity in the review identity ledger. `plugins/sdd-quality-loop/scripts/validate-review-context-set.sh:414-416` admits reviewer/evaluator roles, not an implementation actor. `plugins/sdd-implementation/skills/implement-tasks/SKILL.md:128-149` instead allocates implementation task/run/session identities through `task-input-manifest/v1`. No supported implementation-to-review-ledger registration path was found. A design reviewer role is not a substitute.
- T-001 and T-002 reports declare relative Scratch Root values (lines 48 and 60). New evaluator reservations require a scratch root; validator lines 637-644 require the implementation scratch root to be canonical and absolute. Resolving a relative string now would not itself prove where the original worker ran.
- `tests/loop-escalation.tests.sh:543` validates its fixture without `--reserve`; its invocation lacks scratch_root and its ledger starts with only genesis. That fixture does not prove a real evaluator reservation succeeds.

## Pinned identity evidence

| Artifact | SHA-256 |
|---|---|
| `handoffs/issue423-t001-20260928/manifest.json` | `5a7b2d9e42be7ecc91f05aa68efe5f55d7347a8fa20939312f08a586cd642fae` |
| `handoffs/issue423-t002-20260928/manifest.json` | `de0ee63808fec9bcafaea2363c3ffba7a95f1c16f1ef1b78033b2c4c112205c4` |
| `reports/implementation/sdd-domain-multitarget/T-001.md` | `c0c126c812a308baed537e9f734522d02642346e2e08f6a5adc456c6e11993d8` |
| `reports/implementation/sdd-domain-multitarget/T-002.md` | `5bc3d169918ab875e36f138e3e9ed2083045dc5ccf95a4b500b4755d39e02b05` |

The task/run/session fields agree between the respective handoff manifests and reports. This is identity consistency evidence, not a historical ledger reservation.

## Proposed bounded repair

Use the existing hash-pinned implementation manifest to establish implementation identity, compare task/run/session with the implementation report, and reject identity reuse against the canonical review ledger. Keep independent evaluator reservation and scratch isolation. Exercise the real reserve path and reject missing/altered manifests, mismatched identities, reused identities, and relative/overlapping scratch paths in both shells.

The human approved this bounded launch-contract repair and the subsequent
recovery path that preserves historical reports and requires newly observed,
isolated, hash-pinned revalidation. The current implementation and fixture
results are recorded in `issue423-launch-repair-status-20261002.md`.
Fresh recovery execution remains blocked at read-only input collection;
formal review, current-head CI, and merge are not complete. No historical
implementation identity was fabricated or inserted into the review ledger.
