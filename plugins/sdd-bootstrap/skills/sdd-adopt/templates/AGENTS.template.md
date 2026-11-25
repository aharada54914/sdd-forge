# AGENTS.md

This project follows the SDD Core Spec-Anchored AI Development workflow.

## Required Workflow

1. Run `/sdd-bootstrap:bootstrap <mode> <source>` (internally delegates to `sdd-core-spec` and risk-scaled `spec-check`) to create specifications (`requirements.md`, `design.md`, `tasks.md`) with `Approval: Draft` tasks.
2. A human reviews the specification and open questions, and changes selected tasks in `specs/<feature>/tasks.md` from `Approval: Draft` to `Approval: Approved`.
3. Run `/sdd-ship:ship specs/<feature>/tasks.md` (or `specs/<feature>/tasks.md#T-NNN` for a single task). Internally, `ship` records the spec baseline, delegates implementation to `implement-task` / `implement-tasks` up to `Status: Implementation Complete`, and runs `sdd-gate` for independent verification and the `Status: Done` transition. Optionally pass `--retro` to run `workflow-retrospective` once all selected tasks reach `Status: Done`.
4. For unresolved findings under `docs/review-tickets/*.yml`, run `/sdd-quality-loop:fix-by-review-ticket` to apply a scoped fix and return the task to `Status: Implementation Complete`, then re-verify only that ticket's task with `/sdd-ship:ship specs/<feature>/tasks.md#<task-id>` so `sdd-gate` decides `Done` without starting other `Planned` tasks in the same feature.

## Sources Of Truth

- `specs/<feature>/requirements.md`: requirements (`REQ-NNN`), acceptance criteria (`AC-NNN`), open questions (`OQ-NNN`), and `## Spec Amendments`
- `specs/<feature>/design.md`: architecture approach, contracts, rejected alternatives, and `## Spec Amendments`
- `specs/<feature>/tasks.md`: task approval (`Approval:`), execution order (`### Blockers`), scope, risk tier, and work status (`Status:`)
- `docs/review-tickets/*.yml`: unresolved quality findings

## Active Spec Directories

Update this list whenever a new spec directory is bootstrapped:
- `specs/<feature>/`

## Source Artifact Locations

- `specs/<feature>/requirements.md`
- `specs/<feature>/design.md`
- `specs/<feature>/tasks.md`
- `docs/adr/NNNN-*.md` — all ADRs; no other ADR location is valid
- `contracts/` — API and data contracts
- `docs/architecture/` — architecture diagrams and context documents
- `reports/spec-check/<feature>.md`
- `reports/implementation/<feature>/<task-id>.md`
- `reports/quality-gate/<feature>-<task-id>.md` and `reports/quality-gate/<feature>-<task-id>.execution.json`
- `docs/review-tickets/*.yml`

## Rules

- Do not implement Draft tasks.
- Only a human may set `Approval: Approved` in `specs/<feature>/tasks.md`; agents must never self-approve tasks.
- Do not guess ambiguous requirements or design decisions; record unresolved items as `OQ-NNN` for human decision.
- Do not edit approved specification bodies without human agreement and a `## Spec Amendments` entry.
- Preserve unrelated user changes.
- API changes require contract updates; architecture changes require ADRs.
- Only `sdd-gate` (invoked via `/sdd-ship:ship`) may set a task to `Status: Done`.
- Do not commit, push, or create PRs/MRs unless explicitly requested.
