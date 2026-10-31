# T-005 evaluation admission status

Owner: shared-review-launch-integration/sdd-forge
HEAD: 9ce19abe90df0cb83e385f96855e4843318a8807
Scope: approved T-005 input admission; high risk. Existing dirty implementation, evidence, approvals, verdicts and ledger were preserved. This record changes none of them.

## Executed local regressions

Commands ran through `rtk proxy python3 -B` in the owner checkout:

| Test | Result |
|---|---|
| tests/quality-nontty-transport.tests.py | 19 passed, exit 0 |
| tests/unified-task-launch.tests.py | 9 passed, exit 0 |
| tests/unified-launch-order.tests.py | 9 passed, exit 0 |
| tests/review-conditional-inputs.tests.py | 16 passed, exit 0 |
| tests/spec-review-verify-inputs.tests.py | 2 passed, exit 0 |

55 local tests passed. These results are not formal evaluation, CI, native-host proof, or merge evidence. Console results were observed; no separate raw transcript was saved for these executions.

## Admission blocker

The frozen canonical T-005 implementation report declares 44 evidence outputs, not the product source/test dependency closure required for meaningful evaluation. A snapshot containing those files does not itself authorize reading them.

`plugins/sdd-quality-loop/skills/quality-gate/SKILL.md:160` permits exact path/hash declarations from the implementation report or a genuine preceding gate report's Post-Fix Artifacts table. `plugins/sdd-quality-loop/agents/evaluator.md:50` permits only the implementation report. This is a contract mismatch, not a failed behavioral regression.

Do not fabricate a prior gate result, rewrite the frozen report, silently expand a manifest, or reserve an evaluator before resolving this mismatch. The T-005 planned-file list does not include the evaluator role; it belongs to the already-Done T-001 scope. T-002 depends on T-005, so it is not ready to start.

## Required bounded decision

Authorize a supplemental, hash-pinned delivery declaration for the existing T-005 implementation, without replacing historical reports or verdicts. Specify it consistently in the task contract, gate instructions, evaluator instructions and deterministic admission checks. Require exact canonical path/hash pairs, task/report binding, rejection of missing/changed/unlisted inputs, and unchanged ledger on pre-reservation rejection. No automatic PASS or Done transition is authorized by this proposal.

After the contract decision and required re-review: prepare the source/test/dependency closure, run positive and negative admission regressions, independently review the repair, then use the existing normal reservation and formal evaluation path. Current-head CI and merge remain pending.
