---
name: fix-by-review-ticket
description: Fix only the scope described in a structured review ticket for Spec-Anchored AI Development. Updates tests, runs checks, and updates traceability without unrelated changes.
---

# Fix By Review Ticket

Use this skill to address one structured review ticket.

This skill is intentionally scoped. It fixes only what the ticket explicitly requests.

## Invocation

Codex:

```txt
Use the fix-by-review-ticket skill for docs/review-tickets/RT-0001.yml
```

Claude Code:

```txt
/sdd-quality-loop:fix-by-review-ticket docs/review-tickets/RT-0001.yml
```

## Required Reading

Read:

- The specified review ticket
- `AGENTS.md`
- Target feature `requirements.md`
- Target feature `design.md`
- Target feature `tasks.md`
- Target feature `traceability.md`
- Target code files
- Target test files

If the ticket does not identify the feature or target files clearly enough, stop and ask for clarification or create a human-decision note. Do not guess broad scope.

## Process

1. Read the review ticket.
2. Classify the issue type and severity.
3. Determine the smallest safe fix scope.
4. Fix only the range described in the ticket.
5. Add or update required tests.
6. Run CI-equivalent checks that are available in the repository.
7. Update `traceability.md`.
8. Produce a fix report.

## Forbidden

- Do not perform improvements that are not in the ticket.
- Do not perform large refactoring.
- Do not finalize requirement changes silently.
- Do not introduce breaking API changes without explicit approval.
- Do not make unrelated file changes.

## Completion Report

Report:

- Ticket ID
- Files changed
- Fix summary
- Tests added or updated
- Commands run
- Traceability updates
- Remaining risks
