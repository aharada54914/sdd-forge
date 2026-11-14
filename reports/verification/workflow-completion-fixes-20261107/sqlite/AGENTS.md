# AGENTS.md

This project follows a three-stage Spec-Anchored AI Development workflow.

## Required Workflow

1. Use `sdd-bootstrap-interviewer` to create specifications and Draft tasks.
2. A human reviews the specification and changes selected tasks to Approved.
3. Use `implement-task` for one Approved task.
4. Use `quality-gate` for independent verification and the Done decision.
5. Use `fix-by-review-ticket` for approved review-ticket fixes, then rerun `quality-gate`.

## Sources Of Truth

- `tasks.md`: task approval, execution order, and work status
- `traceability.md`: requirements, design, contracts, code, tests, and final status
- `docs/review-tickets/*.yml`: unresolved quality findings

## Active Spec Directories

Update this list whenever a new spec directory is bootstrapped:
- `specs/sqlite-task-board/`

## Source Artifact Locations

- `specs/sqlite-task-board/requirements.md`
- `specs/sqlite-task-board/design.md`
- `specs/sqlite-task-board/tasks.md`
- `specs/sqlite-task-board/acceptance-tests.md`
- `specs/sqlite-task-board/traceability.md`
- `docs/adr/NNNN-*.md` — all ADRs; no other ADR location is valid
- `contracts/` — API and data contracts
- `docs/architecture/` — architecture diagrams and context documents
- `reports/implementation/<feature>/<task-id>.md`
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

## Project Settings

spec_profile: full
ds_profile: custom

## Product and Runtime

Disposable Japanese local single-user task page. Python standard library, SQLite, plain HTML/JS. No deployment, authentication, cloud or sharing. Browser CRUD and process-restart persistence verification required. No product questions remain.
