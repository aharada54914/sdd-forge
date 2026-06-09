# Mock Policy

AI-generated tests often overuse mocks. This project avoids mock-heavy tests.

## Rules

- Do not mock domain logic.
- Do not use mocks to bypass important business rules.
- Mock external APIs, email, payment, filesystem, and network calls when needed.
- Prefer real domain objects in unit tests.
- Prefer integration tests for repository and database behavior when feasible.
- A test that only verifies a mock was called is not sufficient for important requirements.
- Every important business rule must have at least one test that validates behavior, not implementation detail.
