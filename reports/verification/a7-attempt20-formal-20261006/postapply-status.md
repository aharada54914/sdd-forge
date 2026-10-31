# A20 post-application verification

Owner: A7, `a7-t005-intake/sdd-forge`.
Protected launch-helper application was performed by the human. This record does not change a verdict, approval, task status, or Git history.

## Executed

- Loaded the applied original `plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py` with `importlib.util.spec_from_file_location`, substituted that module into the existing `receipt_prompt.tests.py` suite in memory, and ran all eight tests. Actual original path was printed. Result: 8 passed, exit 0; candidate-only tests are not being substituted for this result.
- Prepared A20 recovery contract and authority audit, preserving historical evidence, adding the A19 interrupted artifacts and invocation hashes. No reviewer identity was created or reserved.
- Ordinary command: `rtk proxy bash plugins/sdd-review-loop/scripts/spec-review-precheck.sh epic-195-a7-compatibility 20 1 --reset --fresh-review-contract=reports/verification/a7-attempt20-formal-20261006/fresh-review-contract-attempt20.json`.
- Result: exit 1, `fresh-review recovery: invalid interrupted evidence inventory`, then admission/validation failed. Earlier incorrectly specified feature/attempt commands failed argument validation only.

## Remaining blocker

`fresh-review-recovery.py:237` permits the inventory extension only when the new attempt is exactly 19, while its inventory is fixed to attempt 18. It cannot admit the new A20 attempt. Removing only the attempt-19 predicate would still reject A19's eleven preserved native transport artifacts at the later inventory check. Old artifacts must not be deleted or repackaged to evade this check.

The bounded next repair should extend validated interrupted-transport inventories without weakening exact path sets, pinned hashes, old invocation/session checks, authority binding, or diagnostic-only historical disposition. Fresh formal review remains unlaunched; A19 PASS remains inadmissible. No new ledger reservation occurred.
