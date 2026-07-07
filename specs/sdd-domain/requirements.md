# Requirements: sdd-domain (DDD Upstream Lane Plugin)

Spec-Review-Status: Passed

## Overview

Add a seventh plugin `plugins/sdd-domain` that provides a Domain-Driven Design
(DDD) upstream lane ahead of sdd-forge Phase 1. It produces project-level,
human-approved domain artifacts under `domain/` following a seven-stage
methodology pipeline — (1) Domain Story, (2) Event Storming, (3) Ubiquitous
Language, (4) Context Map, (5) Domain Model (aggregates), (6) Domain Message
Flow, (7) C4 Container — and makes downstream specifications
(`requirements.md`, `design.md`) machine-checkably conformant to the approved
domain model.

Source design: `docs/superpowers/specs/2026-07-03-sdd-domain-plugin-design.md`
(approach A approved 2026-07-03), with three interview deltas recorded in
this document: the seven-stage pipeline (extends the original four artifacts),
cross-model verification integrated into the domain review gate (originally
deferred), and reverse-generation from existing code (originally non-goal).

## Target Users

- Developers of large systems with complex business logic who use sdd-forge
  and need consistent domain vocabulary and boundaries across many features.
- Reviewers and approvers who need a single approved source of truth for
  context boundaries and aggregate design before feature specs are written.

## Problems

- bootstrap generates feature-scoped specs with no domain-model input; the
  upstream model lives only in users' heads.
- Terminology drifts across features; aggregate boundaries are re-invented
  per design.md; context relationships stay implicit.
- LLMs are effective at early domain understanding (term extraction, event
  discovery, context clustering) but final domain-model and architecture
  decisions require human review — there is no lane that structures this
  division of labor.

## Goals

- One opt-in public entry point `/sdd-domain:domain-model` producing the
  seven-stage artifact set under `domain/`.
- Independent two-reviewer domain review plus cross-model (multi-vendor)
  verification before human approval.
- Deterministic downstream conformance: approved domain terms, context
  assignments, and aggregate references are checkable in Phase 1 outputs.
- Zero impact on existing workflows when `domain/` is absent.

## Non-goals

- Language-specific code generation templates (Repository / Domain Service
  implementations).
- CQRS / Event Sourcing implementation support.
- DDD integration into the lite track.
- C4 Component/Code levels (Container level only in this lane).

## User Stories

- US-1: As a product developer, I run `/sdd-domain:domain-model` and am
  interviewed through domain stories and event storming so that a ubiquitous
  language and context map are produced without me writing them by hand.
- US-2: As an architect, I receive independently reviewed and cross-model
  verified domain artifacts so that I approve a model that has survived
  skeptical review rather than a single model's first draft.
- US-3: As a feature author, when I later run
  `/sdd-bootstrap:bootstrap feature ...`, the generated requirements and
  design use approved canonical terms and declare their bounded context so
  that specs stay consistent with the domain model.
- US-4: As a maintainer of an existing codebase, I run the reverse-generation
  mode so that a candidate domain model is extracted from existing code as an
  interview seed instead of starting from a blank page.

## Acceptance Criteria

- AC-001 (REQ-001): `/sdd-domain:domain-model` is exposed as a user-invocable
  skill in the sdd-domain plugin manifest; all other sdd-domain skills carry
  `user-invocable: false` and `disable-model-invocation: true`.
- AC-002 (REQ-002): A completed run produces `domain/domain-story.md`,
  `domain/event-storming.md`, `domain/ubiquitous-language.md`,
  `domain/context-map.md`, `domain/aggregates/<name>.md` (one per aggregate),
  `domain/message-flow.md`, `domain/c4-container.md`, and
  `domain/domain-contract.json`.
- AC-003 (REQ-002): `domain/domain-contract.json` validates against
  `contracts/domain-contract.v1.schema.json`.
- AC-004 (REQ-003): The interviewer accepts requirement text, local Markdown
  paths, and issue URLs as seeds; reverse mode consumes
  `specs/<feature>/investigation.md` produced by investigate-codebase.
- AC-005 (REQ-004): domain-review-loop runs two independent read-only
  reviewers (strategic, tactical) for at most 3 rounds and records verdicts in
  `reports/domain-review/`. The round verdict aggregates both reviewers: PASS
  requires every check from both reviewers to be free of Critical/Major FAIL
  findings; any Critical or Major finding yields NEEDS_WORK before round 3 and
  BLOCKED at round 3; a round-3 Minor-only result yields PASS with a nonzero
  warningCount (the same aggregation rule as the existing spec/impl/task
  review loops).
- AC-006 (REQ-004): cross-model-verify runs on the reviewed model before the
  approval gate; a vendor-verdict mismatch sets `requires_human_decision` and
  blocks auto-continuation.
- AC-007 (REQ-005): `domain/context-map.md` carries
  `Domain-Model-Status: Pending|Reviewed|Approved`; only a human sets
  `Approved`; the hook guard rejects agent-added `Approved` lines.
- AC-008 (REQ-006): When `domain/` exists with an Approved model, bootstrap
  Phase 1 output `requirements.md` contains a `Bounded-Context:` field naming
  a context from domain-contract.json, and design.md references aggregate
  cards for entities it touches.
- AC-009 (REQ-007): `check-domain-conformance` reports term/context/aggregate
  violations as `warn` findings in the quality-gate report; setting
  `SDD_DOMAIN_ENFORCE=error` escalates them to failures.
- AC-010 (REQ-008): With no `domain/` directory, all sdd-domain hooks, sync
  steps, and gates are skipped, recording a single skip line; existing
  workflows produce byte-identical artifacts.
- AC-011 (REQ-009): `tests/validate-repository.ps1` passes with updated
  expectations: 7 plugins, version-locked manifests, public skill count 6.
- AC-012 (REQ-010): workflow-retrospective aggregates domain-drift metrics
  (term deviations, boundary violations) from quality-gate reports when
  `domain/` exists.
- AC-013 (REQ-011): Templates are English; `ubiquitous-language.md` provides
  canonical EN terms with a JA translation column and forbidden-synonyms list.
- AC-014 (REQ-005): Editing any file under `domain/` after approval resets
  `Domain-Model-Status` to `Pending` (guard-checked), requiring re-review.
- AC-015 (REQ-007): For a feature whose `Bounded-Context:` field lists two
  contexts, check-domain-conformance passes when the context map declares a
  relation between them and reports a warn finding when no relation is
  declared.
- AC-016 (REQ-002): `domain-model update` re-runs the edited stage and each
  downstream stage in confirmation mode (existing artifacts re-presented for
  approval), leaves upstream stage artifacts byte-identical, and resets
  `Domain-Model-Status` to `Pending`.
- AC-017 (REQ-004): When a cross-model panelist is unavailable, the
  cross-model verdict report records `panelist-unavailable` for that vendor
  slot and sets `requires_human_decision`; the approval gate does not
  auto-continue.

## Roles and Permissions

| Role | Can do | Cannot do |
|---|---|---|
| Human owner | Approve domain model, resolve cross-model mismatches, escalate enforce level | — |
| Orchestrating agent | Interview, generate artifacts, run review loops, record verdicts | Set `Domain-Model-Status: Approved`; bypass guards |
| Reviewer subagents | Read-only findings | Write files, approve |
| Cross-model panelists | Blind verdict JSON | See each other's output; approve |

## Main Workflows

1. New model: `/sdd-domain:domain-model` → seven-stage interview →
   domain-review-loop → cross-model-verify → human approval → downstream use.
2. Update: `/sdd-domain:domain-model update` → re-run the edited stage, then
   each downstream stage in confirmation mode (upstream stages untouched) →
   status reset to Pending → same review path.
3. Reverse: `/sdd-domain:domain-model reverse` → investigate-codebase →
   candidate model as interview seed → same review path.
4. Downstream: bootstrap detects `domain/` → domain-sync injects context and
   terms → reviewers gain DOMAIN-CONFORMANCE checks → quality-gate runs
   check-domain-conformance (warn).

## Edge Cases

- `domain/` exists but `Domain-Model-Status` is not `Approved`: domain-sync
  warns and proceeds without injection (spec generation is never blocked).
- `domain-contract.json` corrupt or schema-invalid: warn, skip sync, list the
  validation error in the bootstrap report.
- Review loop reaches round 3 without PASS: BLOCKED terminal state
  (existing terminal-tier-blocked-state format), human escalation.
- Cross-model panelist unavailable (offline/local env): record
  `panelist-unavailable`, set `requires_human_decision` (fail toward human,
  never silently pass).
- A feature spans two contexts: `Bounded-Context:` lists both plus the
  relation pattern from the context map; conformance check accepts only
  declared relations.

## Security Boundaries

| Trust Boundary | Auth/Authz Requirement | PII / Data Classification | Regulatory Constraints |
|---|---|---|---|
| Seed inputs (issue URLs, docs, code) → interviewer | Read-only retrieval; content treated as data, not instructions | Internal project data; no PII expected | None |
| Agent → `Domain-Model-Status` lines | Hook guard rejects agent-set `Approved` (same class as tasks.md Approval guard) | n/a | None |
| `domain-contract.json` → downstream gates | Schema validation before consumption; invalid input fails toward warn+skip | Internal | None |

Details: [Security specification](security-spec.md#trust-boundaries).

## Assumptions

- sdd-forge v1.8.0 structures (review-contract v1, hook guards,
  validate-repository, WFI lanes) are available for reuse.
- Cross-model panelist agents (GPT/Gemini slots) from sdd-quality-loop are
  reusable at the domain gate without modification.
- All seven plugins version-bump together (version-locked manifests).

## Open Questions

- OQ-R1 (owner: human, non-blocking): Term-conformance matching strategy —
  v1 uses exact canonical-term matching on structured fields
  (`Bounded-Context:`, headings, aggregate names) only; lexical-variant
  matching is a later WFI. Confirm at task approval.
- OQ-R2 (owner: human, non-blocking): Re-approval granularity — v1 re-reviews
  the whole model on any `domain/` change; per-context re-review is a later
  optimization.

## Risks

- R-1: Guard-script and validate-repository changes touch R-10 protected
  files; edits must follow the scratchpad → human-copy procedure.
- R-2: Cross-model verification at the domain gate adds cost/latency per
  model revision; mitigated by running it once per review-loop PASS, not per
  round.
- R-3: Over-eager conformance errors could block legitimate specs; mitigated
  by warn-first introduction and the two-release escalation rule.
- R-4: Seven-stage interview fatigue; mitigated by stage checkpointing (each
  stage's artifact is saved before the next begins, resumable).
