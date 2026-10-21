---
name: investigate-codebase
description: Read-only investigation of an existing codebase or problem domain. Produces investigation.md with INV-xxx findings and baseline-behavior.md with BL-xxx observable behaviors before any specification work.
disable-model-invocation: false
user-invocable: false
context: fork
agent: sdd-investigator
---

# Investigate Codebase

Analyze the current state of a codebase or problem domain before specification
work begins. Never modify code or configuration.

## Managed allocation boundary

Affected policy roles: `investigator`.

Apply in the allocating parent before an unbound forked Skill/Agent, native role,
or fresh context receives work, and before any identity reservation. This
boundary takes precedence over later native/default launch guidance for these
roles. It does not add an availability or authority gate.

Keep an already admitted managed entry with its validated selection/controls and
matching role, host, run/session and workload. Keep a concretely known matching
batch startup and fixed generated Codex configuration under their original
contracts. An already bound worker continues its original procedure: do not
select again, allocate again, or run this refusal inside that same worker.
A bound parent does not bind a new child, role or session: each new allocation
needs its own admitted selection/carrier binding or takes the refusal below.

When this operation has no admitted binding of the selected model and effort to
its actual native carrier, substitute the next affected policy role and actual
host (`claude-code`, `codex-cli`, `copilot-cli`, or `gemini-cli`) and execute:

```bash
python3 -I -B "<installed-root>"/plugins/sdd-implementation/scripts/managed-model-entry.py unsupported-entry \
  --role "<policy-role>" --host "<host>"
```

Exit 2 with `model-policy-error/v1` / `model-unavailable` stops that allocation
before work or reservation. Do not fall through to an old model hint, alias,
unbound native default or another parent session; do not count allocation alone
as selection proof. This refusal does not assert host incapability and never
authorizes same-session reload. Original host-incapable-only implementation
fallback evidence and all review isolation requirements remain unchanged.

The invoking parent applies this boundary before context: fork or native investigator allocation. A worker already entered through the bound managed investigator entry performs this original procedure without another selection or allocation. The later inline/fresh-session platform note is not permission for an unbound launch.

## Invocation

Codex:

```txt
Use the investigate-codebase skill.
Mode: feature | bugfix | refactor | greenfield
Target: <path or topic>
```

Claude Code — internal skill, not directly invocable. Reached by following
this file from its entry command:

```
/sdd-bootstrap:bootstrap
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
- `specs/<feature>/codemap.md` — populated from
  `templates/codemap.template.md`. A token-lean architecture map (entry
  points, module topology, key symbols, external dependencies, test map)
  derived from the INV-NNN findings. Downstream skills read this file first
  and limit fresh repository exploration to areas it does not cover.
  Regenerate it whenever `investigation.md` changes.

For `bugfix` and `refactor` modes also produce:

- `specs/<feature>/baseline-behavior.md` — populated from
  `templates/baseline-behavior.template.md`. Each observable behavior carries a
  `BL-NNN` ID.

When the investigated codebase contains UI code, additionally record a
`Design Inventory` finding group in `investigation.md`: occurrence locations
(`file:line`) and counts of hardcoded color codes (#hex / rgb() / hsl()),
font specifications, and magic spacing values. Each entry carries an INV-NNN
ID like any other finding. This inventory is the brownfield input for
initializing `design-system/design-tokens.json` and `design-system.md`; the
investigation itself stays read-only and creates no design-system files.

## Platform Notes

Claude Code executes this skill in a forked context so the main conversation
is not polluted by large read operations.

In Codex or any environment where forking is unavailable, run the same
investigation procedure inline in a fresh session, then paste the resulting
`investigation.md` and `baseline-behavior.md` into the working context before
continuing.

## Handoff

Pass `specs/<feature>/investigation.md`, `specs/<feature>/codemap.md`, and
(when present) `specs/<feature>/baseline-behavior.md` to
`sdd-bootstrap-interviewer` as context. INV-xxx and BL-xxx IDs must be
carried forward into requirements, design, tasks, and traceability.
Downstream skills treat `codemap.md` as the first-stop map of the repository
so they do not repeat the exploration this skill already performed.

## References

- `references/investigation-policy.md` — investigation order and evidence rules
- `references/spec-id-rules.md` — ID naming, sequencing, and deprecation
