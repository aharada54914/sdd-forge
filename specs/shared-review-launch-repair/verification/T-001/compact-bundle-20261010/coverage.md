# Fresh T-001 compact repair evidence

Owner HEAD: 9ce19abe90df0cb83e385f96855e4843318a8807 (dirty integration checkout).

Nine suites executed in this evidence collection: host-review-preflight 7, quality-nontty-transport 20, shared-launch-build 1, task-structured-output 13, unified-launch-order 9, unified-task-launch 9, t001-evaluation-preparation 16, review-conditional-inputs 16, supplemental-delivery-declaration 17. Total: 108 successful checks, zero failures. Full individual logs are adjacent. FilesOnly assembly is not installed-host activation.

Ruff and mypy passed for the six configured shared launch modules. Placeholder, requirement traceability and component applicability outputs are preserved separately. Component coverage is disabled-legacy/not-applicable, NOT PASS.

The retrospective-red.py reproduction loads the exact precompact transport SHA-256 18dc0655daf286053ce884809a3aa0d935140d094b3d8521a0592b0d913f0bca from the retained rollback checkout. It adapts only the added fixture-root argument and runs the current 640-input regression, which fails with missing compact_command. Current transport passes all 20 tests. This was executed AFTER implementation: it establishes behavioral discrimination, not pre-implementation TDD chronology. The original native 300-second failure is separately preserved at reports/verification/shared-launch-handoff/t005-native-transport-blocker-20261009.md.

Existing independent formal compact PASS is reports/quality-gate/20261009-shared-review-launch-repair-T-001-compact.md, run 01a989f0-ff77-4890-b86b-8af32c9a1708. Its 100-check admitted snapshot is distinct from this later 108-check collection (the fixture-preparation tests expanded). It does not automatically review this new evidence contract. Old nested T-001/T-001.contract.json and canonical T-001.evidence.json remain unchanged.

Required remaining decision: independently assess the retrospective RED chronology limitation against required_workflow=tdd before adopting the repair as complete. No ticket closure, task transition, ledger write, CI, native Windows/Python 3.9, installation, commit or merge is performed here.

