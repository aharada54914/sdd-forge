# Test Policy

- Map every acceptance criterion to at least one behavior-focused test.
- Use unit tests for domain rules, integration tests for API, repository, and
  database behavior, and E2E tests for critical workflows.
- Test empty, null, invalid, boundary, duplicate, permission, not-found,
  conflict, and validation cases when applicable.
- Do not mock domain logic or bypass business rules.
- Mock external APIs, email, payments, filesystem, and network only when needed.
- Prefer real domain objects and integration tests over interaction-only mocks.
