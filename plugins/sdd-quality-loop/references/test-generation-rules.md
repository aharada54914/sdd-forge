# Test Generation Rules

## Required Test Types

- Unit tests for domain rules and pure logic
- Integration tests for API, repository, and database behavior
- E2E tests for critical user workflows

## Coverage Expectations

Each acceptance criterion should map to at least one test.

## Boundary Cases

Always consider:

- empty values
- null values
- invalid types
- min/max values
- duplicate data
- permission errors
- not found
- conflict
- validation failure

## Naming

Test names should describe behavior, not implementation.
