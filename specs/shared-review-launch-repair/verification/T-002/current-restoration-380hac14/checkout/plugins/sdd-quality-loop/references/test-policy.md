# Test Policy

- Map every acceptance criterion to at least one behavior-focused test.
- Use unit tests for domain rules, integration tests for API, repository, and
  database behavior, and E2E tests for critical workflows.
- Test empty, null, invalid, boundary, duplicate, permission, not-found,
  conflict, and validation cases when applicable.
- Do not mock domain logic or bypass business rules.
- Mock external APIs, email, payments, filesystem, and network only when needed.
- Prefer real domain objects and integration tests over interaction-only mocks.

## Universal Testing Principles (Technology-Neutral)

1. **Define Observable Boundaries**: Verify contracts that callers, consumers, or adjacent systems rely upon. Observation boundaries include function/CLI inputs and outputs, published events, state transitions, IaC plans, user interfaces, and domain invariants.
2. **Independent Expected Results**: Base test expectations on explicit requirements, acceptance criteria, independently computed values, reference implementations, or invariant properties. Avoid self-referential tests that copy the implementation's exact calculation into the assertion. Snapshot or auto-generated outputs must not be treated as automated approval without independent verification.
3. **Demonstrate Failure Sensitivity**: Verify that tests fail when the targeted defect or regression is introduced (e.g. reproducing issues before fixing, introducing negative cases, boundary violations, or simulated faults).
4. **Resilience to Internal Refactoring**: Tests should focus on observable behavior so that internal implementation refactoring does not break existing valid contracts.
5. **Right-Sized Verification**: Test at the smallest reliable boundary that proves the requirement, complemented by integration or acceptance verification where needed. Avoid enforcing fixed toolchains (e.g., npm/pytest/Playwright/Terraform) as universal requirements.
6. **Isolation and Limitations**: Explicitly account for test environment boundaries (time, randomness, external dependencies). Replacing external systems with mocks or fakes does not prove live production integration; record unverified scope rather than equating mock success with environment-complete verification. Distinguish design-only verification from running system execution.

## Risk-tiered test depth

The required test set scales with the task's risk tier (`risk-gate-matrix.md`):

- `low` — `test-after` is acceptable; `unit-tests` may be `required: false`
  only with a non-empty `waiver_reason`.
- `medium` — unit, acceptance, and regression tests are all required.
- `high` / `critical` — `tdd` is mandatory: every test-type check must carry
  `red_evidence` (the test failing first) and `green_evidence` (passing after).
  `check-contract` enforces the Red→Green evidence; `check-risk` rejects a
  `high`/`critical` task that does not declare `Required Workflow: tdd`.
