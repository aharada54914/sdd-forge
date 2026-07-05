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

### Review gate precheck fallback

While the upstream precheck defect tracked in issue #61
(https://github.com/aharada54914/sdd-forge/issues/61) remains open, a review
gate (specification review, implementation-policy review, task-decomposition
review, or quality verification gate) whose launch precheck cannot be
satisfied may fall back to a manually executed precheck, subject to all of
the following:

1. Run the precheck steps manually and record the results in a
   `manual-precheck-note.md` inside the affected round directory.
2. Obtain explicit human approval of the deviation and record it in the note.
3. Reserve reviewer identities in the identity ledger exactly as the
   automated path would.
4. Reference issue #61 in the note.

This fallback applies only while the upstream precheck defect (issue #61) is
open; once the fix lands, the automated precheck path is again mandatory.
(WFI-002)

## Sources Of Truth

- `tasks.md`: task approval, execution order, and work status
- `traceability.md`: requirements, design, contracts, code, tests, and final status
- `docs/review-tickets/*.yml`: unresolved quality findings

## Active Spec Directories

Update this list whenever a new spec directory is bootstrapped:
- `specs/sdd-forge-refactor/`
- `specs/claude-workflow-compatibility/`
- `specs/sdd-forge-mcp/`
- `specs/workflow-state-integrity/`
- `specs/bootstrap-interviewer-enhancement/`
- `specs/agent-cost-context-isolation/`

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
