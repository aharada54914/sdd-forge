# T-005 current-owner remaining-suite binding

Evidence-only follow-up to formal evaluation `85d6d84c` NEEDS_WORK. This document does not supersede that verdict or change task status. Owner: `/Users/jrmag/.codex/worktrees/shared-review-launch-integration/sdd-forge`. No production change, owner reservation, ledger write or Git mutation is authorized/performed by this verification. Fixture-local writes and reservations remain under this new output's temporary directory.

## Method and byte scope

`run.py` reuses `attempt-6/harness/run-verification.py` for complete combined stdout/stderr and JSON command/cwd/environment/timestamps/exit capture, supplying current owner cwd and this output directory explicitly. Python runs with `-B`; TMP/XDG/.NET paths point beneath this directory. Git-history checks read owner history through `T005_SOURCE_GIT_ROOT`; they do not modify it. Existing `parent-binding-20261010/` is untouched.

`comparison-before.json` and `comparison-after.json` compare all 620 attempt-6 copied paths with current owner and actual historical work copies, including exact SHA-256 and modes. This is byte binding, not proof that every compared file was dynamically executed. Historical staged tests are never characterized as owner execution. `summary.json` records row stability and actual owner ledger before/after hashes.

## Source/test difference attribution

`diff-attribution.json` records six differences, with exact old/new hashes and complete corresponding `.diff` files. These are substantive source changes and test adaptations, not evidence-output-only changes. Attribution here describes behavior; it does not invent author, authorization or task ownership.

| Path | Difference and relevant verification |
|---|---|
| plugins/sdd-review-loop/scripts/launch-impl-review.py | Passes root into receipt-control generation, selecting the source-pinned compact verifier. Prior current-owner unified launch/task and quality transport suites cover caller integration. |
| plugins/sdd-review-loop/scripts/probe-nontty-review.py | Compact verifier invocation/result/order replaces separate batch and receipt hashes; formats fixture invocation JSON; reports stderr presence instead of a rate-limit substring; updates verified hash count. Prior current-owner structured-output/quality transport tests cover pure contract portions, not live probe/model execution. |
| plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py | Adds safe compact-path/raw-digest/verifier/result routines; pins verifier source and every input/control hash; moves allow rules from CLI to settings; updates prompt, policy and transcript checks; explicitly requires substantive evaluator reads. Prior current-owner transport/structured-output/launch suites cover these paths. This is production contract behavior, not a test-only fix. |
| tests/quality-nontty-transport.tests.py | Adds actual 640-input compact-verifier mutation rejection and updates permission, source/prompt and compact-result assertions. Prior current-owner execution: 20 tests. |
| tests/task-structured-output.tests.py | Updates CLI absence and policy fixtures plus compact transcript control fixture while retaining structured-output sequencing negatives. Prior current-owner execution: 13 tests. |
| tests/unified-launch-order.tests.py | Adds compact verifier/boundary fixture paths and accepts receipt-control keyword arguments. Real validator append/retry assertions remain. Prior current-owner execution: 9 tests. |

The prior four current-owner suites (51 tests, including unchanged unified-task caller) are recorded in `../parent-binding-20261010/`, not rerun or rewritten here. Their byte bindings must match this before/after inventory to be reused. The remaining six suites here extend coverage to common preflight, canonical conditional binding, shared ledger boundaries, supplemental declaration and reviewer isolation. They do not transform mocked native calls into native execution.

## Results and limits

All six suites completed with exit 0 on 2026-10-09 15:33–15:38 UTC (2026-10-10 JST); no reported skips or retries. Host preflight: 7 tests; spec inputs: 2; conditional inputs: 16; supplemental declaration: 17. Boundary: 3 unittests plus check summaries 116/0, 84/0, 84/0 (PASS/FAIL). Agent isolation: 26/0, including Bash/PowerShell scratch-history cases.

All 620 compared rows stayed byte/mode-identical before/after. All 620 also match the prior current-owner parent binding. Current owner matches 614 of 620 historical copied bytes, with the six attributed changes above. All actual historical copies still match their recorded hashes. Owner identity ledger SHA-256 stayed `767cb5fd9c4d909e5cf19beb34266cf1ffc7aea6819b0de1bf368f9abbb42c21`. `binding-summary.json` binds these results and evidence file hashes.

Exact per-suite result is authoritative in `<suite>.json` and complete `<suite>.log`; aggregate completion is in `results.json` and `summary.json`. See those files for failures as well as successes. No failures are silently replaced by retry logs.

Formal quality gate, native model/session execution, Windows and CI are NOT RUN by this work. Current-owner local success cannot establish these separately required outcomes. No Done decision is made.
