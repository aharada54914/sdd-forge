# Evaluation Rubric

Shared scoring standard for independent critical review. On Claude Code the
`sdd-evaluator` subagent applies it automatically. On Codex CLI, use the
`sdd-evaluator` TOML agent (`.codex/agents/sdd-evaluator.toml`) in an
interactive session; the installer also copies it to `~/.codex/agents/`.
Do not create new agent role files under `~/.codex/agents/`; a role file
without `developer_instructions` is ignored by Codex at startup.
On Copilot CLI, use the `sdd-evaluator.agent.md` agent from
`plugins/sdd-quality-loop/copilot-agents/`. Where none of these agent
mechanisms are available, start a fresh session (or a clearly separated
review pass with none of the implementation conversation), give it this
rubric, and have it produce the same verdict format.

## Principles

1. Generators grade their own work generously. The evaluator must not share
   context with the implementation work and must not edit anything.
2. Reports are claims. Only observed evidence counts: command output the
   evaluator ran, code it read at line level, screenshots it inspected.
3. The default verdict is `NEEDS_WORK`. `PASS` must be earned with evidence.

## Severity Definitions

| Severity | Meaning | Blocks Done |
| --- | --- | --- |
| Critical | Wrong/missing behavior, broken contract, security defect, faked verification | Yes |
| Major | Untested acceptance criterion, unhandled error path, spec drift, scope creep, design-system non-conformance | Yes |
| Minor | Style, naming, non-blocking cleanup | No |

## Domain Checklists

When the change touches a specialized surface, apply the matching on-demand
checklist in addition to this rubric, and map its findings onto the severities
above. Load a checklist only when its domain is in scope:

- `security-checklist.md` — user input, authentication/authorization, secrets,
  external systems, AI/LLM features.
- `performance-checklist.md` — data access, hot paths, loops over user-sized
  input, rendering.
- `accessibility-checklist.md` — user-facing UI (WCAG 2.2 AA).
- `design-system-checklist.md` — user-facing UI in projects carrying a
  `design-system/` contract (tokens, components, ui-patterns).

## Calibration Examples

- Tests pass, but the handler returns hardcoded data shaped like the fixture:
  `Critical`. This is completion-faking, the highest-priority target.
- Acceptance criterion AC-3 has no test; the code path looks correct on
  reading: `Major`, verdict `NEEDS_WORK`.
- A skipped test (`skip`, `todo`, `xit`) covering in-scope behavior: `Major`.
- Console warning on an unchanged page, unrelated to the task: `Minor`.
- "All 47 tests pass" claimed in the report, evaluator reruns and observes
  47 passing: record under `CHECKED`; this alone is still not a `PASS` —
  acceptance criteria must each be traced.

## Verdict Format

```
VERDICT: PASS | NEEDS_WORK
FINDINGS:
- [Critical|Major|Minor] <file:line or artifact> — <problem> — <observed evidence>
CHECKED:
- <verification actually performed and its result>
```

`PASS` requires zero Critical, zero Major, and at least one real execution or
line-level inspection in `CHECKED`. quality-gate maps `Rejected`/`Accepted`/
`Deferred` classifications onto these findings and never weakens a severity
without recording why in its report.
