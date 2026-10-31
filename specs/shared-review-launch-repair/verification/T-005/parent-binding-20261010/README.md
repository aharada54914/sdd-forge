# T-005 current-owner evidence binding (2026-10-10 JST)

This is an evidence addendum, not a formal quality verdict, task transition, reservation, or approval. Only this new directory was authored. Existing production, task status, ledger and Git state were not edited by this work.

## Scope and instructions

Owner: `/Users/jrmag/.codex/worktrees/shared-review-launch-integration/sdd-forge`; observed HEAD `9ce19abe90df0cb83e385f96855e4843318a8807`. The checkout already contained extensive tracked and untracked work; it was preserved. Risk: high-risk contract evidence verification only, no production repair. Applicable owner `AGENTS.md` and the tester skill were read. `docs/development-policy.md` is absent in this owner. The current request expressly authorizes this non-frozen evidence-only addendum and relevant tests; it does not authorize a lifecycle transition.

## Historical byte binding

Source: `../attempt-6/input-and-source-hashes.json`, SHA-256 `5717e2fdd2f3ee08fb48b7c4283bab373531a1c55e27253eb1a4302df7909f6f`.

`comparison.json` lists every one of 620 historical copied inputs, its recorded hash, the independently read historical copy hash, the current owner hash and both modes. All 620 historical copies still match their recorded hashes. Exactly 614 current owner files match those historical copied bytes; 6 differ. Modes match for all 620. No missing files or evidence/output-only mismatches were found in this 620-path set. This does not inventory files outside that set.

The six differences are:

| Classification | Path |
|---|---|
| Production source/control | plugins/sdd-review-loop/scripts/launch-impl-review.py |
| Production source/control | plugins/sdd-review-loop/scripts/probe-nontty-review.py |
| Production source/control | plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py |
| Test-only | tests/quality-nontty-transport.tests.py |
| Test-only | tests/task-structured-output.tests.py |
| Test-only | tests/unified-launch-order.tests.py |

Exact old/new SHA-256 values are in `comparison.json` → `mismatches`. These are not merely output-file differences. The 614 rows with `bytes_match: true` preserve historical **file-byte identity only**. Historical staged test executions remain executions of that staged tree, not of owner. In particular no historical suite importing one of the three changed production scripts is promoted to a current-owner success solely because its test driver is unchanged.

## Newly executed current-owner tests

`run-current.py` imports the archived attempt-6 capture runner but explicitly supplies current owner as cwd and this directory as destination. TMP/XDG/.NET locations are confined beneath this directory; Python bytecode is disabled. Tests operate on temporary fixture ledgers, not the owner identity ledger. No native review/model launch or real identity reservation was performed.

Each command was `rtk proxy python3 -B tests/<suite>.tests.py -v`, executed 2026-10-09 15:21 UTC (2026-10-10 00:21 JST). Full combined stdout/stderr is preserved in the corresponding `.log`, and exact cwd, argv, selected environment, times and exit code in `.json`.

| Suite | Tests | Exit |
|---|---:|---:|
| quality-nontty-transport | 20 | 0 |
| task-structured-output | 13 | 0 |
| unified-launch-order | 9 | 0 |
| unified-task-launch | 9 | 0 |

All 51 tests succeeded, with no reported skips. This covers changed compact receipt/permission transport, structure/output validation and shared launcher regressions, including actual Bash/PowerShell fixture validator append/fail-closed/retry checks in launch ordering. The unified-task suite exercises the shared helper caller. Probe pure/contract behavior is covered; its live native CLI workflow was not executed.

`comparison-after.json` records the same 620 hashes after all four suites. `binding-summary.json` records comparison stability and exact test-source bindings. The initial six current hashes were observed before tests; the enriched full comparison (including historical-copy verification) was captured during the run and the after comparison after completion. These are not an atomic filesystem snapshot.

## Limits

No full baseline suite rerun, CI, Windows execution, formal independent quality gate, native model/session proof, or task Done decision occurred. Historical 614-file identity does not establish dynamic coverage of all 614 files. Current tests retain their documented mocks; local fixture success is not full native-host delivery. A future source change invalidates this current-byte binding and requires fresh comparison and risk-proportionate tests. Historical evidence has not been rewritten.
