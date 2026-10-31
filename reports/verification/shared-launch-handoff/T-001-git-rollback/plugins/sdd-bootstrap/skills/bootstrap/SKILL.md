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

## MCP Preflight (Advisory)

Attempt `get_next_sdd_command` with no arguments; if it is unavailable or
the call fails, continue with the file-based flow below.

`get_next_sdd_command` is read-only: it only reads repository state and
returns a suggestion, never writing or mutating anything. Its answer is
advisory — it does not decide the mode, track, or step that follows.
`## Routing` below remains the sole decision procedure, and nothing this
step reads changes what `## Routing` concludes.

This step is unconditional: apply it the same way for every mode
(`feature` / `bugfix` / `refactor` / `project` / `adopt` / `investigate`)
and every track (full / lite) — do not skip or gate it by mode or track.
Do not surface the unavailability or the failure to the user as a run
failure.

If the probe's suggestion and the conclusion `## Routing` reaches disagree,
state in the output both that a disagreement occurred and which source was
acted on. Always act on the `## Routing` conclusion in that case, never the
probe's.

## Routing

### `adopt` mode

Delegate entirely to `/sdd-bootstrap:sdd-adopt [project-root]`.
Stop after sdd-adopt completes. Remind the user to run
`/sdd-bootstrap:bootstrap feature <source>` next.

### `investigate` mode

Delegate entirely to `/sdd-bootstrap:investigate-codebase <mode> <source>`.
Stop after investigation completes. Outputs: `specs/<feature>/investigation.md`,
`specs/<feature>/codemap.md`, and `specs/<feature>/baseline-behavior.md`.

### Track selection

Choose the track once, before invoking the interviewer. This is a
Capability-Mode-relevant entry point, so run the hook-activation handshake
first:

<!-- sdd:handshake-wiring v1 -->

1. `check-hook-activation-handshake --emit-challenge` — returns a fresh
   nonce and the canary target `sdd/.hook-canary-sentinel`.
2. Make your **own** real tool-call attempt against that canary target,
   using the per-runtime template the challenge carries, and record the raw
   result verbatim.
3. `check-hook-activation-handshake --verify-response --nonce <nonce>
   --recorded-result <path> --runtime <claude-code|codex-cli|copilot-cli>`.
4. `HOOK_ACTIVE` — continue to track selection. Any other outcome — stop with
   `CAPABILITY_RUNTIME_UNAVAILABLE`; never fall back to legacy behaviour
   silently.

<!-- /sdd:handshake-wiring -->

Then resolve the track, checking physical presence FIRST and approval
validity SECOND. A `sdd/project-context.yaml` that exists but fails
`validate-approval-sidecar` is **not** the same as one that is absent —
treating the two alike is the fail-open ADR-0023 closes.

<!-- sdd:track-selection-contract v1 -->

| Case | Project Context | Flag | Resolution |
|---|---|---|---|
| C1 | physically absent | `--full`, `--lite`, or none | `COMPATIBILITY_FALLBACK` |
| C2 | physically present, REQ-005 validation fails | `--full`, `--lite`, or none | `PROJECT_CONTEXT_INVALID` |
| C3 | physically present and valid, `spec_profile: lite` | `--full` | `PROMOTE_FULL` |
| C4 | physically present and valid, `spec_profile: lite` | `--lite` | `NO_OP_LITE` |
| C5 | physically present and valid, `spec_profile: full` | `--lite` | `ERROR_STOP` |
| C6 | physically present and valid, `spec_profile: full` | `--full` | `NO_OP_FULL` |

<!-- /sdd:track-selection-contract -->

- `COMPATIBILITY_FALLBACK` (C1 only) — `--lite` selects the lite track;
  otherwise `AGENTS.md` with `spec_profile: lite` selects the lite track;
  otherwise the full track.
- `PROJECT_CONTEXT_INVALID` (C2) — stop and report that name. Do not invoke
  the interviewer or `lite-spec`, and do not fall through to C1's fallback.
- `PROMOTE_FULL` — run the full track. `NO_OP_LITE` / `NO_OP_FULL` — run the
  profile's own track. `ERROR_STOP` — stop with an explicit message; `--lite`
  never downgrades a `full` profile.

`PLUGIN-CONTRACTS.md`'s Track Detection section is the normative source for
this table.

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

### Lite track (resolved track: `lite`)

Substitute `lite-spec` for `sdd-bootstrap-interviewer` and skip all three review loops.
Outputs: `requirements.md`, `design.md`, `tasks.md` (no `traceability.md`,
no ADR). LITE produces zero layer outputs: no `ux-spec.md`,
`frontend-spec.md`, `infra-spec.md`, or `security-spec.md`. Approval gate is
the same.

Next step after approval: `/sdd-ship:ship --lite specs/<slug>/tasks.md`

## Context Compaction

Bootstrap sessions are long. Every phase output is persisted on disk
(`specs/<feature>/*.md` and the review reports), so a compacted or fresh
context can resume from any gate boundary by re-reading those files.

Compact (or accept auto-compaction) only at phase boundaries:

- after `investigate-codebase` completes — findings persist in
  `investigation.md`, `codemap.md`, and `baseline-behavior.md`
- after a review gate returns PASS (spec-review, impl-review, task-review)
- at the Approval Gate, before handing off to `/sdd-ship:ship`

Do not compact in the middle of an interviewer phase or an active review
round: interview answers and reviewer context not yet written to disk are
lost. If context pressure forces it, have the interviewer write its current
outputs to `specs/<feature>/` first, then compact.

## Handoff

After sdd-bootstrap completes, report:

- Generated artifacts with file paths
- Open Questions that remain unresolved
- Human action required: set `Approval: Approved` on tasks in `tasks.md`
- Next command: `/sdd-ship:ship specs/<feature-slug>/tasks.md`
  (or `/sdd-ship:ship --lite specs/<feature-slug>/tasks.md` for lite track)
