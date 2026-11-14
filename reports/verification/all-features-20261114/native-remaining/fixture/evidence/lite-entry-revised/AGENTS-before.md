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
- `specs/inclusive-calendar-days/` — bugfix investigation; Lite specification pending.

## Source Artifact Locations

- `specs/<feature>/requirements.md`
- `specs/<feature>/design.md`
- `specs/<feature>/tasks.md`
- `specs/<feature>/acceptance-tests.md`
- `specs/<feature>/traceability.md`
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

## Repository Facts and Selected Workflow

- Existing private Python standard-library calendar helper; `calendar_days.py` exports `days_inclusive(start, end)`.
- README defines inclusive endpoints; invalid dates and reversed ranges raise ValueError.
- Existing tests: `test_calendar_days.py`; run `python3 -m unittest -v`.
- No dependencies, network, API feature, authentication, database, UI, or migration work is in scope.
- This user-selected low-risk bugfix uses `investigate-codebase` → `diagnose` → `lite-spec` → human approval → `implement-task` → `lite-gate`. Lite replaces the full workflow above for this feature; no traceability, ADR, or full review loops are required.
- Diagnosis may add failing regression tests and temporary local probes before approval, but may not repair production code.
- Lite tasks start with `Approval: Draft` and `Status: Planned`; only the human/caller approval fixture may approve them. Stop before implementation in this run.
- Local VCS has no remote. Host CI/issue/PR templates are skipped. Advisory directories are declined by the user.
- Local commits for actual test-before-fix evidence are authorized in this disposable repository only. No push, merge, or publish is authorized.

## Open Questions

None for the requested bugfix: README and user scope define the intended behavior.
