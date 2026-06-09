# AGENTS.md

This file is the canonical shared instruction file for all AI coding agents.

This project follows Spec-Anchored AI Development.

## Required Workflow

1. Write requirements
2. Write technical design
3. Record architecture decisions as ADRs
4. Write API / data contracts
5. Split work into small tasks
6. Implement one task at a time
7. Generate or update tests
8. Run CI-equivalent checks
9. Human reviews PR/MR
10. Fix by review tickets
11. Update traceability

## Core Rules

- Do not implement code before requirements and design exist.
- Do not implement large features in one task.
- Do not modify unrelated files.
- Every implementation task must include tests.
- Every implementation task must update traceability.
- API changes must update OpenAPI or JSON Schema.
- Architecture decisions must be recorded as ADRs.
- Review feedback must be recorded as review tickets.
- Do not rely on free-form chat instructions when a standard skill or template exists.

## Required Source Artifacts

Before implementation, read:

- specs/<feature>/requirements.md
- specs/<feature>/design.md
- specs/<feature>/tasks.md
- specs/<feature>/traceability.md
- docs/adr/
- contracts/openapi/
- contracts/schemas/

## Quality Loop

After each implementation task, run:

1. quality gate
2. human review
3. fix by review ticket when needed
4. update traceability

## Review Ticket Workflow

Review feedback must be written as structured review tickets under:

- docs/review-tickets/

Do not leave important review feedback only in chat.

## Done When

A task is done only when:

- implementation is complete
- tests are added or updated
- lint/typecheck/test/build pass when available
- API contracts are updated when applicable
- traceability.md is updated
- remaining risks are reported
