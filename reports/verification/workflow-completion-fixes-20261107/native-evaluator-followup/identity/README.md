# Evaluator native identity wording follow-up (#731)

A real SQLite evaluator rejected an invocation whose `run_id` and `host_session_id` correctly used the same reserved native thread ID. Its Critical finding is preserved in `original-native-rejection.txt`. The role's shared receipt section already permits this, but its introduction and output placeholder still demanded a “distinct” host-session ID. The quality skill repeated that ambiguous phrase.

The fix removes contradictory introductions and placeholders, including matching reviewer examples, while keeping the complete shared receipt procedure unchanged. Codex and Copilot evaluator definitions now explicitly permit the same real native ID in both fields. Every identity must still be unused by other implementation/review/evaluation contexts. No identity validator, ledger rule, reservation gate, or output authority was relaxed.

Validation:

- Bash and PowerShell role/reference parity: 65 passed each, zero failed. Both reject the former ambiguous intro/example phrases and verify the runtime evaluator identity guidance.
- Canonical implementation-binding suite: 48 passed, zero failed across both runtimes. New controls prove same-context equality succeeds, reuse of the implementation ID cannot reserve, and reuse of a ledger identity fails preview and reservation. Rejected reservations leave the ledger unchanged.
- Review-prompt calibration and quality calibration: passed.
- Repository structure/reference validation: passed, 10 protected targets with zero drift.
- Human-copy mirror check: exit 0, no stale mirrors; pending/frozen bundles left unchanged.

The issue follow-up is https://github.com/aharada54914/sdd-forge/issues/731#issuecomment-6706836572 . The separate missing bare-command runtime guidance is handled by the parent. Normal native application retries remain separate from these deterministic checks.
