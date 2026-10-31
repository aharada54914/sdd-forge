# Current integration attribution — T-005

This addendum addresses the two Major findings of evaluator `85d6d84c-eb23-481f-8940-91bb5e436ad9`. It does not amend the attempt-6 implementation report, its source snapshot, either historical NEEDS_WORK verdict, approvals or task state.

Owner checkout: shared-review-launch-integration/sdd-forge; base HEAD `9ce19abe90df0cb83e385f96855e4843318a8807`. This is evidence-only integration accounting for existing high-risk changes, not a new implementation or an attribution of historical authorship.

## Task boundary

The user approved the T-001 limited repair replacing diagnostic/formal verification commands with one source-pinned command while retaining every input check. `docs/review-tickets/RT-20261009-001.yml` records that scope. The three production paths `launch-impl-review.py`, `probe-nontty-review.py` and `validate-nontty-spec-launch.py`, and `tests/quality-nontty-transport.tests.py`, belong to that T-001 transport repair, not to a newly expanded T-005. T-001's independent result is recorded in `reports/quality-gate/20261009-shared-review-launch-repair-T-001-compact.md`; its existing result is not a substitute for this integration evaluation.

The other two differences, `tests/task-structured-output.tests.py` and `tests/unified-launch-order.tests.py`, adapt downstream mocks/fixtures to that same compact receipt command and settings-based exact permission contract. They preserve structured-output sequencing and actual-validator post-append/retry assertions; they do not authorize another production behavior change. Their complete old/current diffs and hashes are in `diff-attribution.json` and its six adjacent `.diff` files.

T-005 still owns the common formal dispatch ordering, second validation after reservation and failure-before-child semantics. Its attempt-6 proof remains proof of the historical bytes only. The present evaluation is of those semantics integrated with the approved T-001 repair. No changed current byte is represented as having been executed in attempt 6.

## Evidence that closes the coverage gap

`../parent-binding-20261010/` supplies 51 current-owner checks: quality transport 20, structured output 13, unified order 9 and unified task launch 9. `binding-summary.json` here supplies the remaining six complete current-owner suites, all exit 0 without reported skips: host preflight, spec input verification, conditional inputs, review boundary, supplemental declaration and reviewer isolation. The recorded before/after comparisons bind all 620 source/test inputs unchanged, and match all 620 inputs of the prior current-owner run. Six differ from attempt 6; all six are accounted for above. Logs, command/environment records and complete diffs are included as reviewer inputs.

The copied historical attempt-2 report supplies pre-implementation mismatch/preflight and RED history without changing its original claims. Historical rollback evidence remains historical, not a fresh installed-host rollback claim. Local fixtures, including PowerShell on macOS, do not prove Windows-native CI or live-host activation. Formal evaluation, exact-head CI, merge and post-merge checks remain separate gates.
