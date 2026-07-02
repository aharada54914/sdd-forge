---
name: investigate-codebase
description: Read-only investigation of an existing codebase or problem domain. Produces investigation.md with INV-xxx findings and baseline-behavior.md with BL-xxx observable behaviors before any specification work.
disable-model-invocation: true
user-invocable: false
context: fork
agent: sdd-investigator
---

# Investigate Codebase

Analyze the current state of a codebase or problem domain before specification
work begins. Never modify code or configuration.

## Invocation

Codex:

```txt
Use the investigate-codebase skill.
Mode: feature | bugfix | refactor | greenfield
Target: <path or topic>
```

Claude Code:

```txt
/sdd-bootstrap:investigate-codebase <mode> <target>
```

## Modes

- `feature`: Inspect existing screens, APIs, business rules, data flows,
  dependencies, test coverage, and established patterns relevant to a new
  capability.
- `bugfix`: Identify the affected area, trace execution paths, extract business
  rules, and record observable behaviors that must be preserved.
- `refactor`: Map all code touched by the change, extract established patterns,
  measure test coverage, and record every observable behavior as a BL-xxx
  baseline before restructuring begins.
- `greenfield`: Survey similar implementations, evaluate candidate libraries,
  and document technical constraints. No existing codebase required.

## Hard Rules

- Read-only. Do not write, edit, or delete any file or configuration.
- No speculation. Every finding must cite `file:line` evidence.
- Unknown items go to Open Questions; do not invent answers.

## Outputs

Always produce:

- `specs/<feature>/investigation.md` — populated from
  `templates/investigation.template.md`. Each finding carries an `INV-NNN` ID
  and an evidence reference (`file:line`).

For `bugfix` and `refactor` modes also produce:

- `specs/<feature>/baseline-behavior.md` — populated from
  `templates/baseline-behavior.template.md`. Each observable behavior carries a
  `BL-NNN` ID.

## Platform Notes

Claude Code executes this skill in a forked context so the main conversation
is not polluted by large read operations.

In Codex or any environment where forking is unavailable, run the same
investigation procedure inline in a fresh session, then paste the resulting
`investigation.md` and `baseline-behavior.md` into the working context before
continuing.

## Handoff

Pass `specs/<feature>/investigation.md` and (when present)
`specs/<feature>/baseline-behavior.md` to `sdd-bootstrap-interviewer` as
context. INV-xxx and BL-xxx IDs must be carried forward into requirements,
design, tasks, and traceability.

## References

- `references/investigation-policy.md` — investigation order and evidence rules
- `references/spec-id-rules.md` — ID naming, sequencing, and deprecation
