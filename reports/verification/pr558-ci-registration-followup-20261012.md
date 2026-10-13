# PR #558 CI registration follow-up

- Owner checkout: public integration checkout, branch `codex/shared-launch-public-integration`.
- Base HEAD: `2f1ea5bab59609af66323f053a356a45f0666e49`; working tree clean before this repair.
- Scope: register the existing workflow conditional-input regression in the hosted shared-launch job. Existing local Bash and PowerShell aggregate runners already include it.
- Classification: protected CI configuration; existing approved T-004 integration scope. No acceptance criteria, authorization, frozen evidence, or test assertions change.
- Required validation: existing conditional-input suite, traceability-freeze suite, independent diff review, exact final-head CI.
- Review comment 4242016154: the persisted-binding test passed locally. The upstream spec/implementation fixture records do not bind traceability; the task-stage record does and is rebound. Do not change historical fixtures merely to satisfy an unconfirmed finding.
- Historical PowerShell matrix failure: investigation remains open; later successful runs alone do not establish its cause.

This is a development record, not a formal verdict or Done decision.

## Executed verification

- Parent execution: conditional-input suite 9 passed; traceability-freeze suite 2 passed, including Bash/PowerShell persisted and launch-time checks.
- Independent read-only diff review: no findings on the CI registration. Independent reruns: 9 passed (61.337 s) and 2 passed (53.547 s); whitespace check passed.
- P1 finding not reproduced: `tests/workflow-state.tests.sh:880-936` rebuilds task precheck, contract and both reviewer hashes after the fixture column change. The upstream spec/implementation records contain no traceability binding. Known statuses pass; unknown statuses, body/Evidence changes and stale launch-time raw hashes are rejected.
- Hosted CI and formal quality evaluation must still run against the new commit; these local results do not replace them.
