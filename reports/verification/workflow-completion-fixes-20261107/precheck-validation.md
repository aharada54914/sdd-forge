# Review precheck installed-root repair (#726)

Runtime code resolves independently from the consumer project. The three prechecks and shared foundation accept explicit project roots; flat/versioned installations default to the invoking working directory, while a Git source checkout keeps its prior root default. Sibling runtime helpers are resolved from the current trusted installed release, without ambient discovery or fallback to another source checkout.

Only required review reference data is projected to the canonical consumer plugin-reference paths. The projection compares trusted installed bytes, rejects existing differing bytes and linked/reparse paths, creates files exclusively, and does no repair in verify-only mode. Executable runtime code is never copied. Existing hash/schema/identity, transition, replay, drift, and fixed-input gates remain in place.

Validation completed:
- tests/installed-review-precheck.tests.py: 4 test methods PASS; six spec invocation layouts, four implementation/task verify-input routes, drift/layer/reference mismatch, linked destination, collision/no-overwrite, installation/source output isolation.
- tests/spec-review-loop.tests.sh with PowerShell wrapper on PATH: PASS, including state/hash/replay/reset/path controls.
- tests/task-review-precheck.tests.sh with PowerShell wrapper on PATH: PASS, including foreign checkout, hash tamper, anchorless absolute path, and Bash/PowerShell twin behavior.
- tests/review-contract-foundation.tests.sh: PASS.
- tests/review-contract-foundation-parity.tests.sh with PowerShell wrapper: PASS.
- tests/fixed-review-inputs.tests.py: 36/36 PASS.
- Ruff on new Python runtime/test: PASS.
- bash -n on touched shell entry points: PASS.
- git diff --check: PASS at check time.

- tests/impl-review-adr-inputs.tests.sh with PowerShell wrapper: PASS (exit 0); broad Bash/PowerShell history, reviewer input, generation and downstream mutation matrix; final downstream summary 32 passed, 0 failed, 0 inconclusive. Log: /tmp/full-impl-adr.log.

This verifies deterministic gates and packaged layouts, not a completed authenticated full application run. The fresh native run is separately recorded under verification-workspace/full-task-board-fixed. Linux PowerShell execution is not Windows-native proof.
