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
components and their path ownership, and the Provider Binding
**references** (`provider_binding_ids`) a component points at. Per
ADR-0018, `project-context.yaml` never holds Provider Binding *content*
or its approval: that content lives in the separate, sibling file
`sdd/provider-bindings.yaml` (with its own approval sidecar, ADR-0019),
which is project-scoped configuration in its own right, just not part of
`project-context.yaml` itself. Without an explicit boundary, it would be
possible for the two registries (workflow-state vs. project-scoped
configuration) to drift into overlapping claims about the same fact (for
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

2. **`project-context.yaml` is the sole source of truth for the
   project-scoped configuration it itself holds**: the workflow axes
   (ADR-0016), the Capability enforcement policy input to the
   effective-enforcement computation, component and path-ownership
   declarations, and each component's Provider Binding **IDs**. It is
   never the source of truth for Provider Binding *content* or approval
   — per ADR-0018, `sdd/provider-bindings.yaml` (plus its own approval
   sidecar, ADR-0019) is the separate source of truth for that. Nothing
   in the workflow-state registry is extended to carry any of this
   configuration.

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
- Any future schema change to project configuration is scoped to
  whichever file already owns it: a new workflow axis or component/path
  field is scoped to `project-context.yaml`; a new Provider Binding field
  is scoped to `provider-bindings.yaml` (ADR-0018) instead. Neither
  requires a workflow-state registry schema change, and neither requires
  duplicating the field into the other configuration file.
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
  (Workflow Axes Separation), ADR-0018 (Provider Binding Separation, the
  `project-context.yaml`/`provider-bindings.yaml` boundary this ADR must
  stay consistent with), ADR-0021 (Context Projection Staleness)
