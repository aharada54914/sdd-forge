---
name: sdd-bootstrap-interviewer
description: Interview-driven SDD bootstrap for project, feature, or bugfix work. Creates approved implementation-ready specifications and tasks from GitHub/GitLab issues or supplied requirements.
---

# SDD Bootstrap Interviewer

Prepare work for implementation. This skill creates specifications and approved
task contracts; it does not implement application code.

## Invocation

Codex:

```txt
Use the sdd-bootstrap-interviewer skill.
Mode: project | feature | bugfix
Source: <GitHub/GitLab issue URL or requirement text>
```

Claude Code:

```txt
/sdd-bootstrap:sdd-bootstrap-interviewer <project|feature|bugfix> <source>
```

## Intake And Investigation

1. Accept a GitHub/GitLab issue URL or supplied requirement text.
2. Attempt read-only URL retrieval when available; otherwise ask for issue text.
3. Identify repository host as GitHub, GitLab, or local.
4. In `feature` and `bugfix` modes, inspect related code, tests, contracts, and
   established patterns. Parallel agents may be used only for investigation and
   independent pre-implementation review.
5. Record unknown product decisions under `Open Questions`; do not invent them.

## Modes

- `project`: create the project constitution and first feature specification.
- `feature`: specify a new capability in an existing repository.
- `bugfix`: specify the observed behavior, expected behavior, regression test,
  affected area, and smallest safe correction.

Create `AGENTS.md`, `CLAUDE.md`, and project-level architecture only when absent
or when an approved decision requires an update.

## Required Outputs

- `specs/<feature>/requirements.md`
- `specs/<feature>/design.md`
- `specs/<feature>/acceptance-tests.md`
- `specs/<feature>/tasks.md`
- `specs/<feature>/traceability.md`
- relevant ADRs and API/data contracts

For GitHub, create GitHub Actions, Issue, and PR templates. For GitLab, create
GitLab CI, Issue, and MR templates. Use the bundled references and templates.

## Approval Gate

Generate every task with `Approval: Draft` and `Status: Planned`. Present the
specification and pre-implementation review to the human. Only a human may
change approval to `Approved`.

Do not approve tasks while requirements, design, contracts, acceptance criteria,
scope, or important risks remain ambiguous.

## Handoff

Report generated files, open questions, risks, and the next draft task. Remind
the user that implementation starts with `implement-task` only after approval.
