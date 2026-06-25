# AGENTS.md

This project follows a three-stage Spec-Anchored AI Development workflow.

## Required Workflow

1. Use `sdd-bootstrap-interviewer` Phase 1 to create requirements, design, and acceptance tests.
2. Run `spec-review-loop` with its independent reviewers; resolve findings until `Spec-Review-Status: Passed`.
3. Run `impl-review-loop` with separate independent reviewers; resolve findings until `Impl-Review-Status: Passed`.
4. Use `sdd-bootstrap-interviewer` Phase 2 to create Draft tasks, then run `task-review-loop` with separate independent reviewers until `Task-Review-Status: Passed`.
5. A human reviews the specification and changes selected tasks to Approved.
6. Use `implement-task` for one Approved task.
7. Use `quality-gate` for independent verification and the Done decision.
8. Use `fix-by-review-ticket` for approved review-ticket fixes, then rerun `quality-gate`.

## Sources Of Truth

- `tasks.md`: task approval, execution order, and work status
- `traceability.md`: requirements, design, contracts, code, tests, and final status
- `docs/review-tickets/*.yml`: unresolved quality findings

## Active Spec Directories

Update this list whenever a new spec directory is bootstrapped:
- `specs/sdd-forge-refactor/`
- `specs/claude-workflow-compatibility/`

## Source Artifact Locations

- `specs/<feature>/requirements.md`
- `specs/<feature>/design.md`
- `specs/<feature>/tasks.md`
- `specs/<feature>/acceptance-tests.md`
- `specs/<feature>/traceability.md`
- `docs/adr/NNNN-*.md` — all ADRs; no other ADR location is valid
- `contracts/` — API and data contracts
- `docs/architecture/` — architecture diagrams and context documents
- `reports/implementation/<task-id>.md`
- `reports/quality-gate/<timestamp>.md` (names the task id)
- `docs/review-tickets/*.yml`

## Rules

- Do not implement Draft tasks.
- Do not guess ambiguous requirements or design decisions.
- Preserve unrelated user changes.
- Implement one task at a time.
- API changes require contract updates; architecture changes require ADRs.
- Only `quality-gate` may set a task to Done.
- Do not commit, push, or create PRs/MRs unless explicitly requested.
