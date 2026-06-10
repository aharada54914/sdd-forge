# Auto-fix Policy

## Auto-fix Allowed

- lint errors
- type errors
- formatting
- missing tests for clear requirements
- small test expectation updates
- minor OpenAPI / JSON Schema mismatch
- traceability updates
- fixes explicitly allowed by a review ticket

## Auto-fix Forbidden

- requirement changes
- major architecture changes
- database redesign
- auth/authz policy changes
- breaking API changes
- large refactoring
- unrelated changes
- ambiguous business decisions

When forbidden, create a review ticket. Do not set the task to `Done`.
