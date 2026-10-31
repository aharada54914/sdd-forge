# Issue #423 owner regression addendum — 2026-10-04

Local verification record only. This is not a formal quality-gate verdict or current-head CI evidence. Paths below are repository-relative. Raw tool output was not persisted to files; therefore every command has `Log path: none (ephemeral tool output)`. No skipped test is counted as a pass.

| Command (`rtk proxy` prefix) | Exit | Observed result |
| --- | ---: | --- |
| `python3 -B specs/sdd-domain-multitarget/verification/T-001/consumer-inventory.tests.py --repo-root . -q` | 0 | 18 tests, OK |
| `python3 -B specs/sdd-domain-multitarget/verification/T-002/contract-boundaries.tests.py --repo-root . -q` | 0 | 28 tests, OK |
| `bash tests/validate-capability-registry.tests.sh` | 0 | 27 pass, 0 fail |
| `bash tests/install.tests.sh` | 0 | 43 pass, 0 fail |
| `bash tests/review-context-boundary.tests.sh` | 0 | 84 pass, 0 fail; 32 citation anchors |
| `python3 -B tests/issue311-scratch-isolation.tests.py --repo .` | 0 | 60 pass, 0 fail |
| `python3 -B tests/review-scratch-history.tests.py --repo .` | 0 | 26 pass, 0 fail |
| `bash tests/review-agent-isolation.tests.sh` | 0 | Sequential isolation passed; underlying history 26 pass, 0 fail |
| `python3 -B specs/sdd-domain-multitarget/verification/T-002/registry-registration.tests.py -q` | 0 | 5 tests, OK; 2 expected candidate-only skips |
| `python3 -B specs/sdd-domain-multitarget/verification/T-002/registry-migration-20261001/registry-migration.tests.py -q` | 0 | 11 tests, OK |
| `bash tests/registry-migration-cli.tests.sh` | 0 | 6 tests, OK |
| `bash plugins/sdd-quality-loop/scripts/check-task-state.sh specs/sdd-domain-multitarget/tasks.md reports/quality-gate reports/implementation .` | 0 | Task-state check passed (6 tasks); dirty-tree warning retained |
| `bash plugins/sdd-quality-loop/scripts/check-risk.sh specs/sdd-domain-multitarget/tasks.md T-002` | 0 | Risk check passed |
| `git diff --check` | 0 | No whitespace errors |

Log path for all rows: none (ephemeral tool output only). The registration suite's two skips are guarded by `VERIFY_CANDIDATE` and `@unittest.skipUnless` in `specs/sdd-domain-multitarget/verification/T-002/registry-registration.tests.py`; this run did not pass `--candidate`, so the candidate-only checks did not execute. Two first attempts with an unsupported `--repo-root .` argument to the registration and migration suites exited 2 at argument parsing; both were corrected to the commands above and exited 0. These were CLI usage errors, not permission or security refusals.

The T-002 independent evaluator remains unlaunched/unreserved. Its prior protected read denial is recorded in `specs/sdd-domain-multitarget/verification/T-002/qg-prep-20261003/evaluator-launch-blocked.md`; no alternate execution route was used here. Native Windows and current-head CI are not established by these local runs. Existing dirty worktree changes were preserved.

## T-003 independent preparation (not implementation)

`bash scripts/check-sdd-structure.sh` (through `rtk proxy`) exited 0: `check-sdd-structure: OK`. The following existing resolver baseline suites were run from this owner checkout; raw log path for each is none (ephemeral tool output only):

| Command (`rtk proxy` prefix) | Exit | Observed result |
| --- | ---: | --- |
| `bash tests/resolve-project-context-cli.tests.sh` | 0 | 13 pass, 0 fail |
| `bash tests/resolve-project-context-match.tests.sh` | 0 | 125 pass, 0 fail |
| `bash tests/resolve-project-context-block.tests.sh` | 0 | 407 pass, 0 fail |

The task plan has `T-003` Approved/Planned, high risk, TDD, `Blockers: T-002`; `T-002` is Implementation Complete. The installed `implement-tasks` dependency rule admits a blocker whose status is Implementation Complete or Done, so T-002's pending quality gate does not itself prevent T-003 preparation/implementation. This check does not transition task status. Formal implementation still requires the prescribed fresh-agent immutable snapshot/manifest and, before any implementation change, a high-risk preflight in the implementation report mapping each persisted resolver/evidence field to its sibling contract or traceability counterpart and a demonstrably failing mismatch test. That preflight and T-003 RED tests have not yet been executed; the three suites above are legacy baseline evidence, not T-003 acceptance evidence. No implementation or protected task-plan/state edits were made.
