---
name: sdd-bootstrap-interviewer
description: Interview-driven SDD bootstrap for project, feature, bugfix, or refactor work. Creates approved implementation-ready specifications and tasks from GitHub/GitLab issues or supplied requirements.
disable-model-invocation: true
---

# SDD Bootstrap Interviewer

Prepare work for implementation. This skill creates specifications and approved
task contracts; it does not implement application code.

## Invocation

Codex:

```txt
Use the sdd-bootstrap-interviewer skill.
Mode: project | feature | bugfix | refactor
Source: <GitHub/GitLab issue URL or requirement text>
```

Claude Code:

```txt
/sdd-bootstrap:sdd-bootstrap-interviewer <project|feature|bugfix|refactor> <source>
```

## Intake And Investigation

1. Accept a GitHub/GitLab issue URL or supplied requirement text.
2. Attempt read-only URL retrieval when available; otherwise ask for issue text.
3. Identify repository host as GitHub, GitLab, or local.
4. In `feature`, `bugfix`, and `refactor` modes, inspect related code, tests,
   contracts, and established patterns. Parallel agents may be used only for
   investigation and independent pre-implementation review.
5. If `specs/<feature>/investigation.md` exists, read it and carry all INV-xxx
   and BL-xxx IDs forward into requirements and traceability.
6. For large or unfamiliar codebases in `feature`, `bugfix`, or `refactor`
   modes, run `investigate-codebase` first and pass its outputs as context here.
7. Record unknown product decisions under `Open Questions`; do not invent them.
8. If a task adds or changes a user-facing entry point (view, dialog, menu item,
   context action), explicitly ask: "Where in the shell is this reachable? What
   safety preconditions must hold before the action is available?" Require at
   least one AC in the UI Integration Checklist of `acceptance-tests.md`
   asserting shell-level reachability before completing the interview.

## Preflight

In `feature`, `bugfix`, and `refactor` modes, run
`scripts/check-sdd-structure.sh` (or `.ps1`) against the project root before
producing any specification artifacts. If the script reports any `missing:`
lines, run `sdd-adopt` (or perform its full process) to resolve every missing
item before continuing. Do not create specifications in a repository that lacks
the required SDD structure. Project-level constitution files (`AGENTS.md`,
`CLAUDE.md`) and CI/issue/PR templates are created by `sdd-adopt`; defer to it.

## Modes

- `project`: create the project constitution and first feature specification.
- `feature`: specify a new capability in an existing repository.
- `bugfix`: specify the observed behavior, expected behavior, regression test,
  affected area, and smallest safe correction.
- `refactor`: specify a structural improvement that does not change observable
  behavior. Requires `specs/<feature>/investigation.md` and
  `specs/<feature>/baseline-behavior.md`; run `investigate-codebase` first if
  they are absent. Acceptance criteria are expressed as BL-xxx behavior
  equivalence.

## Required Outputs

Phase 1 outputs (generated before review gates):

- `specs/<feature>/requirements.md`
- `specs/<feature>/acceptance-tests.md`
- `specs/<feature>/design.md`
- `docs/adr/NNNN-<slug>.md` for each new ADR (4-digit repository-wide sequence;
  `specs/<feature>/adr/` must not be created)
- relevant API/data contracts

Phase 2 outputs (generated after impl-review-loop passes):

- `specs/<feature>/tasks.md`
- `specs/<feature>/traceability.md`

CI/issue/PR templates are created by `sdd-adopt` based on detected host; do not
recreate them here.

## Specification Review Gate

Run after Phase 1 artifacts (requirements.md, acceptance-tests.md) are generated.

1. If `spec_profile: lite` in AGENTS.md → SKIP; log "spec-review skipped: lite profile".
2. Invoke `/spec-review-loop --feature <feature>`.
3. verdict == PASS or PASS-with-warnings → continue.
4. verdict == NEEDS_WORK → present proposed changes; await human edit of
   requirements.md or acceptance-tests.md; re-invoke.
5. verdict == BLOCKED → halt; instruct human to run
   `/spec-review-loop --reset --feature <feature>`.

## Implementation Policy Review Gate

Run after design.md is generated and spec-review-loop has passed.

1. Check AGENTS.md spec_profile. If lite → SKIP.
2. Invoke `/sdd-review-loop:impl-review-loop --feature <feature>`.
3. verdict == PASS or PASS-with-warnings → continue (Impl-Review-Status: Passed
   is now set in design.md).
4. verdict == NEEDS_WORK → present design-round-N-proposed-changes.md; await
   human edit of design.md; re-invoke.
5. verdict == BLOCKED → halt; instruct human to run
   `/sdd-review-loop:impl-review-loop --reset --feature <feature>`.

## Required Outputs Phase 2

Before generating tasks.md and traceability.md:

- Read design.md header for `Impl-Review-Status`.
- If Impl-Review-Status != "Passed" → STOP: "impl-review-loop must PASS before
  Phase 2. Run `/sdd-review-loop:impl-review-loop --feature <feature>`"
- Generate tasks.md and traceability.md.

## Risk Classification

For every generated task, propose a `Risk:` tier
(`low | medium | high | critical`) following
`plugins/sdd-quality-loop/references/risk-classification-policy.md`, with a
one-line `Risk Rationale:`. The agent proposes; the human confirms the tier at
approval. Derive `Required Workflow:` from the tier per
`plugins/sdd-quality-loop/references/risk-gate-matrix.md`:
`low → test-after`, `medium → acceptance-first`, `high`/`critical → tdd`.

For `high`/`critical` tasks, add the risk-derived `Done When` items the matrix
mandates (Red→Green evidence captured; independent review verdict recorded;
provenance with `spec_revision`; and for `critical`, an HMAC-signed evidence
bundle plus a second, distinct named approver). Leaving `Risk:` absent selects
legacy mode (no tier enforcement) and is reserved for pre-existing contracts —
do not use it to dodge a tier. `check-risk` rejects a `high`/`critical` task
that does not declare `Required Workflow: tdd`.

## Task Decomposition Review Gate

Run after Risk Classification completes and tasks.md has been generated.

1. Check AGENTS.md spec_profile. If lite → SKIP.
2. Invoke `/sdd-review-loop:task-review-loop --feature <feature>`.
3. verdict == PASS or PASS-with-warnings → continue to ## Approval Gate.
4. verdict == NEEDS_WORK → present tasks-round-N-proposed-changes.md; await
   human edit of tasks.md; re-invoke.
5. verdict == BLOCKED → halt; instruct human to run
   `/sdd-review-loop:task-review-loop --reset --feature <feature>`.

## Approval Gate

Generate every task with `Approval: Draft` and `Status: Planned`. Present the
specification and pre-implementation review to the human. Only a human may
change approval to `Approved`.

Do not approve tasks while requirements, design, contracts, acceptance criteria,
scope, or important risks remain ambiguous.

### Sudo Mode

If a valid `SDD_SUDO` flag file exists at the project root (see
`plugins/sdd-quality-loop/references/sudo-mode-policy.md`), the routine task
**approval** checkpoint auto-passes. Record
`Approval: Approved (sudo <ISO8601 UTC>)` in tasks.md and continue.

Sudo does not license approving ambiguous specifications: if requirements,
design, contracts, acceptance criteria, scope, or important architecture/
security risks remain unresolved, keep them as Open Questions and do not
auto-approve those tasks. Such decisions remain human-owned even under sudo. All
deterministic gates apply; every check runs as normal.

## Handoff

Report generated files, open questions, risks, and the next draft task. Remind
the user that implementation starts with `implement-task` only after approval.

After creating a new spec directory, append its path (`specs/<feature>/`) to
the **Active Spec Directories** list in `AGENTS.md`. If the list does not exist
yet, add it as a new section under `## Sources Of Truth`.
