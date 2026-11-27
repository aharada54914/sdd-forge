Task ID: T-008
Feature: verification-first-factory
Run ID: 9cd2d2ab-5c4d-4ba9-8bf0-11e3c47b8f7a
VERDICT: NEEDS_WORK
Critical: 0
Major: 2
Minor: 0

- **VERDICT**: NEEDS_WORK

# Independent quality gate for T-008

Evaluators verified all 44 admitted hashes at `33a9733b2573660a1380e41263ce45093eae39ff`. G1/G2/G5 were reviewed by `9cd2d2ab-5c4d-4ba9-8bf0-11e3c47b8f7a` (ledger 1214) and G3/G4 by `ab3d4e4c-6bb9-4d9c-8a0f-d8bce5f6ef23` (ledger 1215). Machine execution `f61488ac-b3e9-400e-a83b-c89f01fdb637` returned PASS.

| Perspective | Result | Observation |
|---|---|---|
| G1 Acceptance | PASS | The ordinary integrated gate passed 58/58 without skips. Changes to output, exit codes and p95 budgets were exercised for AC-010, with contention covered through both public entry points for AC-011. |
| G2 Scope | NEEDS_WORK | The shipped gate imports a new production file, `rebuild-differential.mjs`. The approved task lists two gate files and the ship plugin, and the implementation introduced this path without an amendment. Test files and shared dependencies were accounted for separately. |
| G3 Regression | NEEDS_WORK | Both commands generated the same 2 MiB output. The reviewer confirmed that the subprocess capture failed with ENOBUFS on both sides and the comparison reported a mismatch. The default buffer bound makes otherwise valid commands fail. The repair needs to compare output through completion and distinguish a capture error from a command exit. |
| G4 Non-functional | PASS | The reviewed lock and write-scope behavior, plus the existing CLI regressions, support the task's NFR-005 claim. The separate output-size finding limits rebuild coverage. |
| G5 Contract | PASS | The inspected command entry points, lock outcome and ship workflow agree. No task-specific domain model or design system is declared. |

Two Major findings remain. Restoring scope requires bringing the implementation into an approved path or explicitly approving and recording an amendment. The regression needs a behavioral repair and a new independent gate.
