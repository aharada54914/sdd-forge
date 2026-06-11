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

- `specs/<feature>/requirements.md`
- `specs/<feature>/design.md`
- `specs/<feature>/acceptance-tests.md`
- `specs/<feature>/tasks.md`
- `specs/<feature>/traceability.md`
- `docs/adr/NNNN-<slug>.md` for each new ADR (4-digit repository-wide sequence;
  `specs/<feature>/adr/` must not be created)
- relevant API/data contracts

CI/issue/PR templates are created by `sdd-adopt` based on detected host; do not
recreate them here.

## Approval Gate

Generate every task with `Approval: Draft` and `Status: Planned`. Present the
specification and pre-implementation review to the human. Only a human may
change approval to `Approved`.

Do not approve tasks while requirements, design, contracts, acceptance criteria,
scope, or important risks remain ambiguous.

## Handoff

Report generated files, open questions, risks, and the next draft task. Remind
the user that implementation starts with `implement-task` only after approval.
