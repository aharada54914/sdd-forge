# Plugin Contracts

This document defines the inter-plugin interfaces for sdd-forge. These contracts
govern how plugins communicate and hand off control at version boundaries.

## implement-tasks → quality-gate (v0.12.0+)

**Source**: `plugins/sdd-implementation/skills/implement-tasks/SKILL.md`
**Target**: `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md`

### Handoff Preconditions

Before invoking quality-gate, implement-tasks must verify:

1. **All approved tasks implemented**: Every task with `Approval: Approved` in
   `specs/<feature>/tasks.md` has reached `Implementation Complete` status.
2. **No blocked tasks**: No task with `Approval: Approved` is in `Blocked` status.
3. **Dependency order satisfied**: All `### Blockers` references between tasks
   have been resolved in dependency order.

### Signal Format

implement-tasks signals handoff by announcing completion in the session and
invoking quality-gate as the next skill. There is no machine-written file for
this handoff — the session continuity is the signal.

### Precondition Assertion (quality-gate preflight)

quality-gate should verify on entry:
- At least one task exists in `Implementation Complete` state
- Every task with `Approval: Approved` is in `Implementation Complete` state (not `Draft` or `Blocked`)
- All `### Blockers` references between tasks have been resolved in dependency order

If preconditions are not met, quality-gate should pause and report the gap
rather than proceeding with an incomplete implementation set.

---

## sdd-ship → internal plugins (v0.15.0+)

**Source**: `plugins/sdd-ship/skills/ship/SKILL.md`
**Targets**: sdd-implementation (implement-tasks), sdd-quality-loop (quality-gate, lite-gate via sdd-lite), sdd-bootstrap (sdd-adopt preflight)

### Orchestration Contract

sdd-ship is a thin orchestrator. It does not re-implement logic from its dependencies:

1. **Implementation**: delegates entirely to `/sdd-implementation:implement-tasks` (full track) or `/sdd-implementation:implement-task` in document order (lite track).
2. **Quality gate (full)**: delegates to `/sdd-quality-loop:quality-gate` per task. BLOCKED verdict halts the batch immediately.
3. **Quality gate (lite)**: delegates to `/sdd-lite:lite-gate` per task. FAIL verdict halts the batch.
4. **Cross-model verify**: delegates to `/sdd-quality-loop:cross-model-verify` only when `--verify` flag is present AND the task has `Cross-Model: enabled`.
5. **Retrospective**: delegates to `/sdd-quality-loop:workflow-retrospective` when `--retro` is passed or all tasks reach Done for the first time in the session.

### Security Invariants

- sdd-ship must never invoke `sdd-sudo` or create/modify `SDD_SUDO`.
- sdd-ship must never set `Approval: Approved` on any task.
- sdd-ship must never modify files under `plugins/sdd-quality-loop/hooks/` or any `sdd-hook-guard.*` script.
- sdd-ship must never push to remote or create pull requests without explicit user instruction.

### Track Detection (priority order)

1. `--full` flag → FULL (verifies acceptance-tests.md + traceability.md exist)
2. `--lite` flag → LITE
3. `spec_profile: lite` in AGENTS.md → LITE
4. Default → FULL

---

## sdd-bootstrap design-system artifacts → consumers (v1.8.0+)

**Producer**: `plugins/sdd-bootstrap` (design-sync-loop, routed from sdd-bootstrap-interviewer / lite-spec)
**Consumers**: `plugins/sdd-implementation` (implement-task, visual-verify-loop), `plugins/sdd-quality-loop` (quality-gate, check-design-system)

### Artifact Contract

The target application owns a project-level `design-system/` directory at its
repository root (one per project, distinct from per-feature `specs/<feature>/`):

- `design-system/design-tokens.json` — machine-readable tokens. MUST validate
  against `contracts/design-system.contract.v1.schema.json` (strict meta
  envelope: `schema` const `design-system-contract/v1`, semver `version`,
  `generated_by`, `profile`). Token groups follow the W3C DTCG format
  (`$type`/`$value`); groups beyond color/typography/spacing are allowed.
- `design-system/design-system.md` — rules and reasons. Required sections:
  `## Layer 1 — Tokens (machine-extracted)`, `## Layer 2 — Do / Don't
  (component conventions)`, `## Layer 3 — Review checklist (human-curated)`,
  `## Change Process`.
- `design-system/ui-patterns.md` — universal interaction conventions. Required
  sections: `## Actions`, `## Dialogs`, `## Icons`, `## Flow`, `## States`,
  `## Cognitive Load`.
- `design-system/build/` — optional generated token outputs; never
  authoritative.

Templates for all three artifacts live in
`plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/`.

### Handoff Rules

- The producer creates the directory from the templates only when
  `ds_profile: custom` is selected; `ds_profile: none` produces nothing.
  External seeds (ui-ux-pro-max MASTER.md, Figma DTCG exports) are inputs that
  map into these artifacts; the artifacts are always authoritative.
- Consumers read the artifacts and never create or rewrite them. Conformance
  findings flow through review checklists and the advisory visual-verify-loop;
  the deterministic `check-design-system` gate reports warn-level findings
  until its error promotion (two releases after introduction).
- Absence contract: when `design-system/` does not exist, every consumer skips
  with a recorded reason — absence never blocks a workflow.

---

## sdd-domain domain model → consumers (v1.8.0+)

**Producer**: `plugins/sdd-domain` (domain-interviewer, domain-reverse, domain-review-loop, routed from the public `domain-model` entry skill)
**Consumers**: `plugins/sdd-bootstrap` (sdd-bootstrap-interviewer, via domain-sync), `plugins/sdd-review-loop` (spec-reviewer-a/b, impl-reviewer-a/b), `plugins/sdd-quality-loop` (quality-gate, check-domain-conformance, workflow-retrospective)

### What sdd-domain reads

- `domain/` artifacts it owns and regenerates itself: `domain-story.md`,
  `event-storming.md`, `ubiquitous-language.md`, `context-map.md`,
  `aggregates/*.md`, `message-flow.md`, `c4-container.md`,
  `domain-contract.json`.
- `investigate-codebase`'s `specs/<feature>/investigation.md` output, read
  only by `domain-reverse` to build a candidate seed — never written to.
- `tasks.md`-mediated consent is not used for cross-model verification;
  `domain-review-loop` invokes `prepare-panelist-input.sh` /
  `check-cross-model.sh` directly under human (`SDD_SUDO`-style)
  authorization instead.

### What sdd-domain writes

The target project owns a project-level `domain/` directory at its
repository root (one per project, not per feature, distinct from
per-feature `specs/<feature>/`):

- `domain/domain-contract.json` — machine-readable contract. MUST validate
  against `contracts/domain-contract.v1.schema.json` (`schema` const
  `domain-contract/v1`). Regenerated from the approved Markdown artifacts
  after every stage change.
- `domain/domain-story.md`, `domain/event-storming.md`,
  `domain/ubiquitous-language.md`, `domain/context-map.md`,
  `domain/aggregates/*.md`, `domain/message-flow.md`,
  `domain/c4-container.md` — the seven-stage Markdown artifact set, each
  checkpointed to disk before the next stage begins (resumable on
  interruption).
- A `Domain-Model-Status` field (Pending / Approved) inside `domain/`,
  gated on `domain/context-map.md`: only a human may set it to Approved;
  `sdd-hook-guard` rejects an agent-authored write of the approved value
  (a valid `SDD_SUDO` token permits it, matching the `tasks.md`
  approval-guard pattern).

### Handoff Rules

- The producer creates `domain/` only via an explicit, opt-in
  `/sdd-domain:domain-model` run; it is never created implicitly by
  bootstrap or any other plugin.
- Consumers read `domain/domain-contract.json` and the Markdown artifacts
  and never create or rewrite them. `domain-sync` is the sole injection
  point into `sdd-bootstrap-interviewer`'s Phase 1 output (a
  `Bounded-Context:` field in generated `requirements.md`, aggregate-card
  references in `design.md`) — the flow is strictly unidirectional
  (domain model → downstream specs); feedback in the other direction
  returns only via WFI/diagnose triggering a new `domain-model update` run,
  never a direct write back into `domain/`.
- `spec-reviewer-a/b` and `impl-reviewer-a/b` add a DOMAIN-CONFORMANCE
  observation to their fixed check list; `check-domain-conformance`
  (`plugins/sdd-quality-loop/scripts/check-domain-conformance.{sh,ps1}`) is
  a warn-phase-only deterministic gate (`SDD_DOMAIN_ENFORCE=error`
  escalates to failure; default flips to error two releases after
  introduction, by human edit, mirroring `check-design-system`).
  `workflow-retrospective` aggregates its warn findings into domain-drift
  metrics (term-deviation count, boundary-violation count) when they have
  been recorded in quality-gate reports.
- Absence contract: when `domain/` does not exist, every hook, sync step,
  and gate skips with exactly one recorded skip line — absence never
  blocks a workflow, and existing workflows produce byte-identical
  artifacts (AC-010).
- Cross-plugin file ownership: sdd-domain never reads another plugin's
  files by relative filesystem path at runtime. Where a technical-default
  basis cites an existing file (e.g. `c4-container.template.md`),
  sdd-domain ships its own adapted copy under its own skill's
  `templates/` rather than reading across the plugin boundary.

---

## Plugin Dependency Declarations

| Plugin | Depends On | Notes |
|--------|------------|-------|
| sdd-ship | sdd-bootstrap, sdd-implementation, sdd-quality-loop, sdd-lite | orchestrates all implementation and verification phases |
| sdd-implementation | sdd-quality-loop | quality-gate invocation |
| sdd-lite | sdd-quality-loop | check-task-state-lite mirrors check-task-state logic |
| sdd-bootstrap | (none) | standalone; optionally consumes `domain/` via domain-sync when present |
| sdd-quality-loop | (none) | standalone; optionally reads `domain/domain-contract.json` via check-domain-conformance when present |
| sdd-domain | (none) | standalone; produces `domain/` consumed optionally by sdd-bootstrap, sdd-review-loop, sdd-quality-loop |

---

## Cross-Plugin Script References

If a future refactoring merges `check-task-state-lite` into `check-task-state`
(via `--lite` flag), sdd-lite would gain a runtime dependency on the
sdd-quality-loop scripts directory. This dependency must be declared in
`plugins/sdd-lite/.plugin/plugin.json` before the merge proceeds.
