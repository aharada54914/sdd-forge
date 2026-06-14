# Bootstrap Quality Gates

## Intake Gate

- Mode is `project`, `feature`, or `bugfix`.
- GitHub/GitLab Issue URL or supplied requirement text is recorded.
- Goals, non-goals, constraints, and open questions are separated.

## Specification Gate

- Requirements and acceptance criteria are testable.
- Design, security, deployment, and data/API contract needs are explicit.
- Major architecture decisions have ADRs.
- Existing code and tests were investigated for feature and bugfix work.
- Each requirement/task carries a risk tier with a rationale; security, auth,
  data-integrity, and money-moving paths are escalated to `high`/`critical`
  per `risk-classification-policy.md`.

## Task Gate

- Each task fits in one PR/MR and has one clear goal.
- Every task contains Source Issue, Approval, Status, Must Read, Scope,
  Done When, Out of Scope, and Blockers.
- Every task is generated with `Approval: Draft` and `Status: Planned`.
- Every task declares `Risk:`, `Risk Rationale:`, and a `Required Workflow:`
  consistent with the matrix (`high`/`critical ⇒ tdd`); `check-risk` passes.
- Acceptance tests and initial traceability exist.

## Handoff Gate

- Open questions and risks are reported.
- Independent pre-implementation review is complete when available.
- No task is marked Approved by the skill.
- The human is told to approve a task before using `implement-task`.
