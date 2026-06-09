---
name: quality-gate
description: Run the post-implementation Spec-Anchored AI Development quality gate for a scoped task. Adds or updates tests, runs CI-equivalent checks, creates review tickets for non-auto-fixable issues, and updates traceability.
---

# Quality Gate

Use this skill after an implementation task is complete.

This skill verifies that the target task remains aligned with requirements, design, tasks, contracts, ADRs, and traceability. It may make small scoped fixes, but it does not perform broad new feature implementation.

## Invocation

Codex:

```txt
Use the quality-gate skill for specs/<feature>/tasks.md#T-001
```

Claude Code:

```txt
/sdd-quality-loop:quality-gate specs/<feature>/tasks.md#T-001
```

## Required Reading

Read:

- `AGENTS.md`
- `CLAUDE.md` if it exists
- `specs/<feature>/requirements.md`
- `specs/<feature>/design.md`
- `specs/<feature>/tasks.md`
- `specs/<feature>/traceability.md`
- `contracts/openapi/*.yaml`
- `contracts/schemas/*.json`
- `docs/adr/*.md`
- `references/test-generation-rules.md`
- `references/mock-policy.md`
- `references/auto-fix-policy.md`
- `references/spec-drift-rules.md`

If a required file is missing, report the gap and continue only when the task can be evaluated safely.

## Process

1. Identify the target task.
2. Inspect the current change scope with `git diff`.
3. Compare the implementation against requirements, design, contracts, ADRs, and traceability.
4. Extract missing tests for requirements, acceptance criteria, contracts, and edge cases.
5. Add necessary unit, integration, or e2e tests.
6. Avoid mock-heavy tests.
7. Detect executable CI-equivalent commands from project files.
8. Run lint, typecheck, test, build, and OpenAPI lint when available.
9. Classify failures by root cause.
10. Fix only auto-fixable issues.
11. Create `docs/review-tickets/RT-xxxx.yml` for non-auto-fixable issues.
12. Update `traceability.md`.
13. Create `reports/quality-gate/<timestamp>.md`.

## Auto-fix Allowed

- lint violations
- type errors
- clear missing tests
- clear test expectation mismatches
- minor OpenAPI or JSON Schema mismatches
- traceability updates
- fixes explicitly scoped by a review ticket

## Auto-fix Forbidden

- requirement changes
- major architecture changes
- major database design changes
- authentication or authorization policy changes
- breaking API changes
- large refactoring
- unrelated file changes
- implementation decisions where the specification is ambiguous

When a forbidden change is needed, create a review ticket instead of applying the change.

## CI Command Detection

Detect commands from existing project files. Do not invent commands.

JavaScript / TypeScript:

- `package.json` scripts: `lint`, `typecheck`, `test`, `test:unit`, `test:integration`, `test:e2e`, `build`, `api:lint`

Python:

- `pyproject.toml`
- `Makefile`
- `justfile`
- `pytest`
- `ruff`
- `mypy`
- `pyright`

Fallback:

- If no commands are detected, create a report explaining what is missing.

## Output

Create a quality report under:

- `reports/quality-gate/<timestamp>.md`

Report:

- Target task
- Summary
- Tests added or updated
- CI commands and results
- Traceability updates
- Review tickets created
- Remaining risks
- Next recommended action
