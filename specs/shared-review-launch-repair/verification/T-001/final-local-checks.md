# T-001 local deterministic checks

Owner: shared-review-launch-integration. These commands were executed against the owner checkout and their outputs inspected. They are not an independent verdict, CI result, or Done decision.

| Command (all through `rtk proxy`) | Observed result |
|---|---|
| `bash plugins/sdd-quality-loop/scripts/check-task-state.sh specs/shared-review-launch-repair/tasks.md reports/quality-gate reports/implementation .` | Exit 0; 5 tasks passed |
| `bash plugins/sdd-quality-loop/scripts/check-traceability.sh specs/shared-review-launch-repair/verification/T-001/traceability.json . require-evidence` | Exit 0; 1 scoped requirement link passed |
| `bash plugins/sdd-quality-loop/scripts/check-placeholders.sh plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py plugins/sdd-review-loop/scripts/preflight-host-review.py plugins/sdd-review-loop/scripts/probe-nontty-review.py plugins/sdd-review-loop/scripts/launch-impl-review.py plugins/sdd-quality-loop/scripts/preflight-evaluator-delivery.py` | Exit 0 |
| `bash plugins/sdd-quality-loop/scripts/check-workflow-state.sh` | Exit 0; workflow-state: ok |
| `python3 -B plugins/sdd-quality-loop/scripts/check-component-coverage.py --repo-root .` | Exit 0; `not-applicable (disabled-legacy)`, manifest not consulted, no failures or warnings; producer SHA-256 `d6505e2909ea988384c0694c3f4b865e8f4539ba25eb71dab85d21ed447882fd` |
| `python3 -B tests/quality-nontty-transport.tests.py` | Current owner rerun: 19 tests, OK |
| `python3 -B tests/unified-task-launch.tests.py` | Current owner rerun: 9 tests, OK |

The contract revision is SHA-256 of each filename followed by LF and its raw bytes, in order: requirements.md, design.md, acceptance-tests.md, tasks.md, traceability.md under this feature. This records the current corpus after T-001 entered Implementation Complete, not a claim that dirty inputs are committed. Value: `5205efb23545cc35c606061d5833db32031fcdce24402184d10b438317aac897`.

`sdd/project-context.yaml` is absent in this checkout; component coverage is disabled-legacy, not a successful coverage test. Local regression/static logs and native diagnostics remain separate evidence. Windows, full CI, independent quality evaluation and merge are not established by this record.
