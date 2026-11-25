# Concurrency verification of the quality plugin

The review follows [Pstack’s maintenance skill at the inspected revision](https://github.com/cursor/plugins/blob/41e400932eca14f289e7db717a70455256b6d388/pstack/skills/maintain-formal-verification-skill/SKILL.md). Each property has a bounded model, a source mapping, a mutation expected to violate it, and an observation through the implementation.

| Property | Counterexample or regression | Repair and result |
|---|---|---|
| A stale release must preserve the successor’s lock. | A release reads the old owner, another process reclaims the lock, then the release removes the new owner. | At `c7f22ad69`, mutations publish unique exclusive intents before touching the lock and clean up dead local intents. An actual release/reacquire regression checks the successor’s ownership. A refused gate preserves the running owner’s execution evidence. |
| Ordinary release requires a verifiable owner. | Malformed JSON allowed ordinary release to delete the record. | At `a3d9a7574`, malformed, missing, empty, null and non-string owners preserve the lock and lease. Explicit force is the recovery path. |
| At most one ledger reservation succeeds against a given initial hash. | A hosted Ubuntu run reported success for one actor but published the other actor’s record. A success-count-only test would miss this. | At `f288bbaf6`, acquisition uses the result of the OS directory creation directly. Both contenders start together. The intact path admits one entrant and publishes only that caller’s record. Removing the guard admits both callers. [Replay receipt](reservation-bridge.json) · [Failing hosted job](https://github.com/aharada54914/sdd-forge/actions/runs/45672579283/job/139411513199) |

## Model and implementation checks

| Model | Baseline | Deliberate failure |
|---|---|---|
| TaskLock | TLC explored 5 distinct states to depth 3. | Removing exclusive acquisition violated SingleOwner. Apalache independently checked the bounded lock and replay. |
| TaskLockMutation | TLC explored 54 distinct states to depth 7 with three workers and local crash cleanup. | Removing the peer check violated OneWriter at depth 5 (27 distinct states). |
| GateLifecycle | TLC explored 38 distinct states to depth 12. | Mutations independently triggered DoneRequiresGatePass, RetryBound, EscalationRequiresOQ, NoTamperRepair and NoDriftPass. |
| Reservation | The intact model exited 0. The two-process replay observed agreement between critical-section entry, successful exit and persisted identity. | The lock-removed model exited 12 on OneAccepted. Both processes succeeded in the corresponding real-code replay. |

The TLC/Apalache suite at `a3d9a7574` passed 11/11 with zero skips. The related integration suites passed 52/52. The commands are `node --test tests/v2-formal-gate.test.mjs` with the pinned checker runtimes and `python3 tests/verify-review-reservation.py --jar <pinned-tla2tools.jar> --output <new-directory>`. Machine-readable mappings specify the source digests, actions and bounds.

These safety results assume coherent local filesystem operations, participating writers using the same protocol, and a common PID namespace for local crash cleanup. They establish neither fairness nor progress guarantees under continual contention. Network filesystems and operator overrides remain outside the model.
