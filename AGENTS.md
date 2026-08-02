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

### Post-review artifact freeze

Once a review gate passes, its hash-bound artifacts (the design document
after the design review gate; the task plan body and traceability document
after the task decomposition review gate) are content-frozen except for the
normalized status/approval fields. Sanctioned later updates — open-question
resolutions, verification-status finalization — are recorded in non-frozen
addenda (implementation reports, `specs/<feature>/verification/`, user
documentation) instead of the frozen artifact, and task authors must scope
Done When items accordingly. When an already-approved task's Done When names
a frozen artifact, the Done When wording is amended to name the equivalent
addendum record — a spec change requiring explicit human authorization,
recorded in the task plan and re-bound by a post-implementation provenance
re-review (human decision of 2026-07-05 for the blocked feature: wording
amendment, not deemed satisfaction). (WFI-004)

### Post-implementation provenance re-review

When task-stage review evidence must be re-bound after the implementation
phase (evidence-schema drift, incomplete reviewer input manifests), the task
decomposition review gate runs a new attempt in which both reviewers receive
the complete input set including all four layer specification files, emit
the persisted-state validator's canonical task output schema (reviewer A:
top-level `feature`/`attempt`/`round`, `stage: "task-review"`,
`role: "reviewer-a"`, `manifest` array of path+sha256 pairs,
`checks[].status`, and a `findings` array with one severity-bearing entry
per FAIL; reviewer B: top-level `feature`/`attempt`/`round`,
`manifest.allowed_inputs`, `checks[].result`, and the same `findings`
array), and evaluate task state by lifecycle validity — an approved approval
field bearing a valid human or workflow-bypass-mode audit mark and statuses
{Planned, In Progress, Blocked, Implementation Complete, Done} are valid —
instead of the pre-implementation initial-state rule. The mismatch between
the review gate plugin's shipped role definitions and the validator's
canonical schema is tracked in
https://github.com/aharada54914/sdd-forge/issues/86; this rule does not
authorize plugin-internal changes. (WFI-004)

## Active Spec Directories

Update this list whenever a new spec directory is bootstrapped:
- `specs/sdd-forge-refactor/`
- `specs/claude-workflow-compatibility/`
- `specs/sdd-forge-mcp/`
- `specs/workflow-state-integrity/`
- `specs/bootstrap-interviewer-enhancement/`
- `specs/agent-cost-context-isolation/`
- `specs/sdd-domain/`
- `specs/local-env-mcp/`
- `specs/ci-mcp/`
- `specs/epic-136-phase2-gates/`
- `specs/epic-136-phase1-rce/`
- `specs/epic-136-phase1-guards/`
- `specs/epic-159-pillar-a/`
- `specs/epic-159-pillar-a2/`
- `specs/epic-159-pillar-b/`
- `specs/epic-159-pillar-c/`
- `specs/epic-159-pillar-d/`
- `specs/epic-192-a4-facet-manifest/`

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

### Evidence report identity fields

- Implementation reports (`reports/implementation/`) must carry a `Run ID:`
  line and a `Task Attempt Count:` line.
- Quality verification gate reports (`reports/quality-gate/`) must carry a
  `Task: T-NNN` line and a `Run ID:` line whose value equals the evaluator
  run id reserved in the identity ledger for that gate run.

These fields are additive: existing consumers (check-task-state,
evidence-bundle generation) ignore them and are unaffected. They exist so
that retrospective analysis and run-record emission can associate evidence
with tasks deterministically. (WFI-003)

### Spec factual-claim evidence citations

When `investigation.md`, `requirements.md`, or `design.md` asserts a
specific, checkable factual claim about existing repository behavior (e.g.,
"N scripts enforce X", "script Y has no existing test driver", "script Z
contains a numeric limit"), the assertion must cite the specific
grep/file:line evidence it rests on in the document itself. Spec-review and
task-review treat an uncited factual claim of this kind as a structural gap
— it is not accepted on the strength of prose alone. (WFI-011)

### High-risk task preflight

Before changing the implementation for a high-risk task (`Risk: high` or
`Risk: critical`), the implementer must record a preflight checklist in the
implementation report listing, for each evidence field the task will persist
(contract fields, verdict fields, traceability claims):

1. the persisted evidence field,
2. its sibling-contract or traceability counterpart, and
3. a failing mismatch test that fails while the field and its counterpart
   disagree.

Implementation work may start only after every persisted field has all three
entries. This front-loads the cross-artifact consistency checks that were
previously discovered during review (claude-workflow-compatibility T-002 and
T-006). (WFI-001)
