# T-001 final three-file rollback verification

Disposable checkout: `reports/verification/shared-launch-handoff/T-001-git-rollback`.
Base HEAD: `9ce19abe90df0cb83e385f96855e4843318a8807`; baseline includes 26 inventoried pre-task inputs, not pristine HEAD alone.

Both task patches were applied, final candidate suites passed 43 tests, and both patches were reversed with apply_patch. SHA-256 comparison against before-hashes.json restored all 26 inputs with zero mismatches. Restored baseline results follow; no ledger or historical evidence was restored.

## quality-nontty-transport

Command: `rtk proxy python3 -B tests/quality-nontty-transport.tests.py`
Exit: 0

```text
..................
----------------------------------------------------------------------
Ran 18 tests in 0.473s

OK
```

## host-review-preflight

Command: `rtk proxy python3 -B tests/host-review-preflight.tests.py`
Exit: 0

```text
.......
----------------------------------------------------------------------
Ran 7 tests in 0.037s

OK
```

## unified-task-launch

Command: `rtk proxy python3 -B tests/unified-task-launch.tests.py`
Exit: 0

```text
.........
----------------------------------------------------------------------
Ran 9 tests in 0.164s

OK
```

## unified-launch-order

Command: `rtk proxy python3 -B tests/unified-launch-order.tests.py`
Exit: 0

```text
........
----------------------------------------------------------------------
Ran 8 tests in 0.205s

OK
```

Total restored-baseline tests: 42 passed. This proves disposable code rollback only, not installed-host rollback, formal evaluation, CI or release.

