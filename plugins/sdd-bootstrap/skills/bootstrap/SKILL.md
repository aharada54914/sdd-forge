---
name: bootstrap
description: Generate implementation-ready SDD specifications and approved task contracts from requirements. The first of the two-command workflow — run before /sdd-ship:ship.
disable-model-invocation: true
---

# SDD Bootstrap

Generate implementation-ready specifications and task contracts for a feature,
bug fix, refactor, or new project. This skill orchestrates investigation,
Phase 1 specification, implementation-policy review, Phase 2 task decomposition,
and task-decomposition review.

## Invocation

Claude Code:

```txt
/sdd-bootstrap:bootstrap <mode> <source>
/sdd-bootstrap:bootstrap adopt [project-root]
/sdd-bootstrap:bootstrap investigate <mode> <source>
/sdd-bootstrap:bootstrap <mode> --lite <source>
/sdd-bootstrap:bootstrap <mode> --feature <slug> <source>
/sdd-bootstrap:bootstrap <mode> --reset --feature <slug>
```

Codex:

```txt
Use the bootstrap skill.
Mode: project | feature | bugfix | refactor | adopt | investigate
Source: <GitHub/GitLab issue URL or requirement text>
```

### Modes

| Mode | Delegates to | Description |
|---|---|---|
| `feature` | sdd-bootstrap-interviewer | New capability in an existing repository |
| `bugfix` | sdd-bootstrap-interviewer | Bug fix specification |
| `refactor` | sdd-bootstrap-interviewer | Structural improvement (investigation recommended first) |
| `project` | sdd-bootstrap-interviewer | Greenfield project — runs sdd-adopt automatically |
| `adopt` | sdd-adopt | Scaffold SDD structure in an existing repository (no spec) |
| `investigate` | investigate-codebase | Read-only codebase analysis only |

### Flags

| Flag | Effect |
|---|---|
| `--lite` | Use lite-spec track (skip review loops, no traceability/ADR) |
| `--feature <slug>` | Override the inferred feature slug |
| `--reset` | Pass to impl-review-loop or task-review-loop after a BLOCKED verdict |

## Preconditions

For `feature`, `bugfix`, `refactor`, and `project` modes:

1. Run `scripts/check-sdd-structure.sh` (or `.ps1`) at the repository root.
2. If `missing:` items are reported (AGENTS.md absent, required directories
   missing): automatically invoke `/sdd-bootstrap:sdd-adopt` to create the
   structure, then continue.
3. For `refactor` mode: require `specs/<feature>/investigation.md` and
   `specs/<feature>/baseline-behavior.md`. If absent, recommend running
   `/sdd-bootstrap:bootstrap investigate refactor <source>` first and stop.

## Routing

### `adopt` mode

Delegate entirely to `/sdd-bootstrap:sdd-adopt [project-root]`.
Stop after sdd-adopt completes. Remind the user to run
`/sdd-bootstrap:bootstrap feature <source>` next.

### `investigate` mode

Delegate entirely to `/sdd-bootstrap:investigate-codebase <mode> <source>`.
Stop after investigation completes. Outputs: `specs/<feature>/investigation.md`
and `specs/<feature>/baseline-behavior.md`.

### Track selection

Choose the track once, before invoking the interviewer:

1. `--lite` selects the lite track.
2. Otherwise, `AGENTS.md` with `spec_profile: lite` selects the lite track.
3. Otherwise, use the full track.

### `feature` / `bugfix` / `refactor` / `project` modes (full track)

1. **Phase 1** — invoke `/sdd-bootstrap:sdd-bootstrap-interviewer <mode> <source>`.
   Outputs: `requirements.md`, `acceptance-tests.md`, `design.md`,
   `ux-spec.md`, `frontend-spec.md`, `infra-spec.md`, and `security-spec.md`,
   plus ADRs and contracts. `design.md` starts with
   `Impl-Review-Status: Pending`.

2. **Spec-review gate** — invoke `/sdd-review-loop:spec-review-loop --feature <slug>`.
   - PASS / PASS-with-warnings: continue to the implementation-policy review.
   - NEEDS_WORK: present proposed edits to the human, wait for the Phase 1
     artifacts to be updated, then re-invoke.
   - BLOCKED: stop. Instruct the human to revise and run
     `/sdd-bootstrap:bootstrap <mode> --reset --feature <slug>`.

3. **Impl-review gate** — invoke `/sdd-review-loop:impl-review-loop --feature <slug>`.
   - PASS / PASS-with-warnings: continue to Phase 2.
   - NEEDS_WORK: present proposed edits to the human, wait for `design.md`
     update, then re-invoke.
   - BLOCKED: stop. Instruct the human to revise and run
     `/sdd-bootstrap:bootstrap <mode> --reset --feature <slug>`.

4. **Phase 2** — invoke `/sdd-bootstrap:sdd-bootstrap-interviewer <mode> <source>`
   in Phase 2 mode (after `Impl-Review-Status: Passed`).
   Outputs: `tasks.md` (Approval: Draft), `traceability.md`.

5. **Task-review gate** — invoke `/sdd-review-loop:task-review-loop --feature <slug>`.
   - PASS / PASS-with-warnings: continue to Approval Gate.
   - NEEDS_WORK: present proposed edits, wait for `tasks.md` update, re-invoke.
   - BLOCKED: stop. Instruct: `/sdd-bootstrap:bootstrap <mode> --reset --feature <slug>`.

6. **Approval Gate** — present all generated artifacts to the human.
   Remind them that implementation starts only after they set
   `Approval: Approved` on each task in `tasks.md`.
   Next step: `/sdd-ship:ship specs/<slug>/tasks.md`

### Lite track (`--lite` or `spec_profile: lite`)

Substitute `lite-spec` for `sdd-bootstrap-interviewer` and skip all three review loops.
Outputs: `requirements.md`, `design.md`, `tasks.md` (no `traceability.md`,
no ADR). LITE produces zero layer outputs: no `ux-spec.md`,
`frontend-spec.md`, `infra-spec.md`, or `security-spec.md`. Approval gate is
the same.

Next step after approval: `/sdd-ship:ship --lite specs/<slug>/tasks.md`

## Handoff

After sdd-bootstrap completes, report:

- Generated artifacts with file paths
- Open Questions that remain unresolved
- Human action required: set `Approval: Approved` on tasks in `tasks.md`
- Next command: `/sdd-ship:ship specs/<feature-slug>/tasks.md`
  (or `/sdd-ship:ship --lite specs/<feature-slug>/tasks.md` for lite track)
