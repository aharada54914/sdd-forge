# ADR 0018: Provider Binding Separation

Status: Accepted

Date: 2026-07-19

## Context

This decision was confirmed through three independent adversarial review
passes (a Claude counter-argument review, a Claude fact-checking review,
and a Codex counter-argument review), each cross-checked against the
sdd-forge repository's actual code. It is one of the eleven "skeleton"
decisions that survived independent adversarial review without being
falsified ("robustly confirmed, unchanged"), per
`docs/ai-dlc-foundation-decision-v2.md` §5 (Q4: provider neutrality).

If a Capability Pack or a Project Context encodes a specific cloud or
distribution provider (Azure, AWS, MS Store, etc.) directly inside its
provider-neutral characteristics, replacing that provider later requires
duplicating the Registry entry, the gate definitions, and the schema
itself. The framework needs a way to describe a component's
provider-neutral *nature* separately from *which concrete provider*
currently realizes it.

## Decision

1. **`target_platforms` (component characteristics) is separated from
   provider identity.** Project Context components carry only
   provider-neutral properties:

   ```yaml
   components:
     - id: invoice-workflow
       artifact_kinds: [durable_workflow]
       runtime_classes: [managed_durable_runtime]
       platform_targets:
         - os: linux
           architecture: amd64
       characteristics:
         long_running: true
         replayable: true
         human_in_the_loop: true
       provider_binding_ids: [invoice-workflow-prod]
   ```

2. **Provider Bindings live in a separate file**, `sdd/provider-bindings.yaml`:

   ```yaml
   schema: sdd-provider-bindings/v1
   bindings:
     - id: invoice-workflow-prod
       provider: azure
       product: durable-functions
       purpose: runtime
       state_authority:
         type: azure-runtime
         resource_ref: invoice-workflow-prod
       credentials:
         source: environment
         reference: AZURE_FEDERATED_IDENTITY
   ```

3. **Boundary**:
   - A Capability Pack never carries a provider name.
   - A Project Context carries only Provider Binding **IDs**, never
     provider details.
   - Provider Bindings may name Azure, AWS, Argo, MS Store, or any other
     provider.
   - The existing review rule that detects provider-specific detail
     leaking into a Capability specification is retained.

4. **Deferred vocabulary**: as with the Artifact Gate (ADR-0017 §3), the
   detailed vocabulary for `credentials` and `state_authority` is deferred
   to the ADR written when a real case (a cloud-service Pack with an
   actual production target) exists. Foundation fixes only the binding's
   skeleton — `id` / `provider` / `product` / `purpose` / the binding
   reference — and does not standardize credential-source taxonomies or
   state-authority resolution rules beyond that skeleton.

## Consequences

- A component's Registry entry, its required/conditional Facets, and its
  Gate definitions never need to change when the underlying provider is
  swapped; only the Provider Binding referenced by
  `provider_binding_ids` changes.
- Multiple bindings (e.g. one per environment, or a migration pair of old
  and new provider) can coexist for the same component without touching
  Capability-level artifacts.
- Because `credentials` and `state_authority` are deliberately left
  underspecified in Foundation, Epic A1's schema work must still define
  *enough* of the binding skeleton for `check-component-coverage`
  (ADR-0021 dependency) and Provider Adapter change detection (decision
  document v2 §12) to function, without pretending the full credential and
  state-authority vocabulary is settled.
- Any future `sdd-delivery` (ADR-0017 §3) or `sdd-operability` work that
  needs concrete provider detail reads it from `provider-bindings.yaml`,
  never from a Capability Pack or Registry entry.

## References

- Decision document v2 §5 (Q4) — `docs/ai-dlc-foundation-decision-v2.md`
- Tracking issue #187 / Epic A0 issue #188
- ADR-0017 (Gate Stage Model, Artifact Gate deferred vocabulary),
  ADR-0021 (Context Projection Staleness, Provider Adapter change
  detection)
