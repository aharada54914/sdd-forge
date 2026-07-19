# ADR 0024: Workflow State Registry vs. Project Context

Status: Accepted

Date: 2026-07-19

## Context

This decision was confirmed through three independent adversarial review
passes (a Claude counter-argument review, a Claude fact-checking review,
and a Codex counter-argument review), each cross-checked against the
sdd-forge repository's actual code, per
`docs/ai-dlc-foundation-decision-v2.md` §19, Epic A0's ADR list: "the
division of responsibility between the workflow-state registry and
`project-context.yaml` (source of truth for feature state vs. source of
truth for project configuration; no dual source of truth)."

The repository already has a **workflow-state registry**: the versioned
registry introduced by ADR-0002
(`0002-repository-workflow-state-integrity.md`), validated by
`check-workflow-state.sh` / `.ps1`, which tracks each specification
directory's Spec/Impl/Task review-gate PASS state and `tasks.md`'s task
status machine — a **feature-scoped** record of *where a given Feature
currently stands in the review/implementation lifecycle*.

This Epic (A0–A9) introduces `project-context.yaml` (ADR-0016 onward): a
**project-scoped** record of configuration — the workflow axes
(`spec_profile` / `artifact_layout` / `capability_enforcement`),
components and their path ownership, Provider Bindings, and their
approvals. Without an explicit boundary, it would be possible for the two
registries to drift into overlapping claims about the same fact (for
example, both trying to record whether a given Feature is currently
Capability-enforced), which is exactly the "dual source of truth" failure
mode the framework's existing single-source-of-truth conventions
(`tasks.md`, `traceability.md`, the Registry vs. Pack split in ADR-0013's
sibling decisions) are designed to avoid.

## Decision

1. **The workflow-state registry (ADR-0002) remains the sole source of
   truth for feature-scoped state**: a specification directory's review
   gate PASS/FAIL history, its `tasks.md` task-status machine, and any
   other per-Feature lifecycle fact. Nothing introduced by this Epic
   duplicates or shadows this registry.

2. **`project-context.yaml` is the sole source of truth for
   project-scoped configuration**: the workflow axes (ADR-0016), the
   Capability enforcement policy input to the effective-enforcement
   computation, component and path-ownership declarations, and Provider
   Bindings. Nothing in the workflow-state registry is extended to carry
   this configuration.

3. **No dual source of truth is created.** Where a computation needs both
   kinds of fact — for example, the Implementation Gate (ADR-0017)
   checking a Feature's review-gate PASS state (workflow-state registry)
   *and* its Capability Coverage against the project's declared
   configuration (`project-context.yaml`) — it reads each fact from its
   own registry and does not copy either fact into the other's file. A
   Feature's Facet Manifest (ADR-0021) binds to `project-context.yaml`
   content via digest; it does not restate or re-derive workflow-state
   registry facts.

## Consequences

- Any future schema change to feature lifecycle state (e.g. a new review
  gate) is scoped to the workflow-state registry and its existing
  ADR-0002 validation surface; it does not require a `project-context.yaml`
  schema change.
- Any future schema change to project configuration (e.g. a new workflow
  axis or a new Provider Binding field) is scoped to
  `project-context.yaml` and Epic A1's schema/approval machinery; it does
  not require a workflow-state registry schema change.
- Code that needs to answer "is this Feature Done" and code that needs to
  answer "what is this project's Capability enforcement policy" consult
  two different, independently-versioned registries; a component that
  needs both must read both explicitly rather than expecting either
  registry to expose the other's facts.
- This boundary is a naming and ownership convention, not a new
  mechanism; Epic A0 does not introduce new tooling here beyond stating
  the rule, and Epic A1's schema work is expected to respect it without
  further ADR-level negotiation.

## References

- Decision document v2 §19 (Epic A0 ADR list) —
  `docs/ai-dlc-foundation-decision-v2.md`
- Tracking issue #187 / Epic A0 issue #188
- ADR-0002 (Repository-wide workflow-state integrity), ADR-0016
  (Workflow Axes Separation), ADR-0021 (Context Projection Staleness)
