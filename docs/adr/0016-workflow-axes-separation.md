# ADR 0016: Workflow Axes Separation

Status: Accepted

Date: 2026-07-19

## Context

This decision was confirmed through three independent adversarial review
passes (a Claude counter-argument review, a Claude fact-checking review,
and a Codex counter-argument review), each cross-checked against the
sdd-forge repository's actual code. It is one of the eleven "skeleton"
decisions that survived independent adversarial review without being
falsified, per `docs/ai-dlc-foundation-decision-v2.md` §2 (Q1: mode
decision-variable conflict).

Prior designs risked using incidental file existence (for example, the
presence of a Capability Registry entry or a Facet Manifest) as an
implicit mode-selection variable. That conflates three logically distinct
concerns — how strict the review/evidence workflow must be, how
specification artifacts are laid out on disk, and how strictly
capability-specific gates are enforced — into a single axis, which makes
partial adoption (e.g. lite review discipline with facet-native layout)
inexpressible and makes mode detection depend on accidents of what
happens to exist on disk.

## Decision

1. **Three independent axes, each single-valued** (array notation is
   discontinued):

   ```yaml
   workflow:
     spec_profile: full          # full | lite
     artifact_layout: facet-hybrid
       # lite-three-file | legacy-seven-layer | facet-hybrid | facet-native
     capability_enforcement: required   # advisory | required
   ```

   - `spec_profile` governs review, evidence, and approval strictness.
   - `artifact_layout` governs which structure specification artifacts are
     placed in.
   - `capability_enforcement` governs whether capability-specific gates are
     advisory or required.

2. **Layout definitions**:
   - `facet-hybrid`: retains every legacy-seven-layer artifact while the
     Facet Manifest and Facet files co-exist alongside them. This is the
     migration form that preserves compatibility with existing tooling and
     the existing review flow.
   - `facet-native`: Facets are canonical; the duplicate legacy-seven-layer
     artifacts are not generated. This is the future form, reached only
     after `facet-hybrid` has an operational track record.

3. **Source of truth**: when `project-context.yaml` exists, its
   `workflow.*` fields are the sole source of truth for these three axes.
   File-existence checks are used only for the compatibility fallback when
   `project-context.yaml` is absent:

   - Absent, with `AGENTS.md` carrying a `spec_profile: lite` marker →
     `spec_profile: lite` / `artifact_layout: lite-three-file` / (internal
     state: capability mechanism inactive).
   - Absent, otherwise → `spec_profile: full` /
     `artifact_layout: legacy-seven-layer` / (internal state: capability
     mechanism inactive).

4. **`disabled-legacy` redefinition**: this is not an enum value of
   `capability_enforcement`. It is a **derived internal state** meaning
   "the entire capability evaluation pipeline is inactive." In this state
   the Resolver, the Registry, the Gate stage machinery, and the effective
   enforcement `max()` computation do not run at all — they are outside
   that computation's domain, not evaluated with a low input. A Registry
   entry carrying `minimum_enforcement: required` therefore has no effect
   on a project that has no Project Context.

## Consequences

- Mode selection no longer depends on incidental file presence; it becomes
  a single explicit, auditable declaration in `project-context.yaml`.
- Consumers branch on three independent values instead of one composite
  "mode," which is a larger but more precise combinatorial surface;
  ADR-0022's Lite Capability Upgrade matrix defines the valid combinations
  explicitly rather than leaving them implicit.
- Any component that consults `capability_enforcement` (the effective
  enforcement computation, Registry-driven gates) must first check whether
  the capability pipeline is in the `disabled-legacy` derived state before
  reading Registry minimums.
- Plugins that previously used file-existence heuristics to infer mode
  must migrate to reading `project-context.yaml.workflow` explicitly; the
  compatibility fallback exists specifically for the period before a
  project adopts a Project Context.

## References

- Decision document v2 §2 (Q1) — `docs/ai-dlc-foundation-decision-v2.md`
- Tracking issue #187 / Epic A0 issue #188
- ADR-0017 (Gate Stage Model), ADR-0022 (Lite Capability Upgrade),
  ADR-0023 (Track Selection Contract Migration)
