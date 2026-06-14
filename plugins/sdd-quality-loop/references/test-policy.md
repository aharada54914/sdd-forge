# Test Policy

- Map every acceptance criterion to at least one behavior-focused test.
- Use unit tests for domain rules, integration tests for API, repository, and
  database behavior, and E2E tests for critical workflows.
- Test empty, null, invalid, boundary, duplicate, permission, not-found,
  conflict, and validation cases when applicable.
- Do not mock domain logic or bypass business rules.
- Mock external APIs, email, payments, filesystem, and network only when needed.
- Prefer real domain objects and integration tests over interaction-only mocks.

## Risk-tiered test depth

The required test set scales with the task's risk tier (`risk-gate-matrix.md`):

- `low` — `test-after` is acceptable; `unit-tests` may be `required: false`
  only with a non-empty `waiver_reason`.
- `medium` — unit, acceptance, and regression tests are all required.
- `high` / `critical` — `tdd` is mandatory: every test-type check must carry
  `red_evidence` (the test failing first) and `green_evidence` (passing after).
  `check-contract` enforces the Red→Green evidence; `check-risk` rejects a
  `high`/`critical` task that does not declare `Required Workflow: tdd`.
