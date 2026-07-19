# ADR 0021: Context Projection Staleness

Status: Accepted

Date: 2026-07-19

## Context

This decision was confirmed through three independent adversarial review
passes (a Claude counter-argument review, a Claude fact-checking review,
and a Codex counter-argument review), each cross-checked against the
sdd-forge repository's actual code, per
`docs/ai-dlc-foundation-decision-v2.md` §16 (Q15: Project Context updates
vs. in-progress Features). This is one of the areas where v2 widened v1's
staleness binding after review identified an inconsistency with the
Reverse Coverage Gate (decision document v2 §12, Q11).

A Feature's Facet Manifest was bound only to a hash of the Project
Context fields it referenced. That leaves Registry changes (required
facets, gates, minimum enforcement) and path-ownership changes free to
change "underneath" an already-resolved Feature without invalidating it —
an in-progress Feature can pass its Gate with stale, insufficient
artifacts. This also directly contradicted the Reverse Coverage Gate
(ADR reference in decision document v2 §12), which *does* fail a Feature
when ownership changes; the two mechanisms disagreed about whether
ownership drift matters.

## Decision

1. **Widen the Facet Manifest's staleness binding** to every input the
   Resolver actually consumed, not just the Project Context fields it
   referenced:

   ```yaml
   context_binding:
     full_context_revision: sha256:...
     dependency_pointers:
       - /components/desktop-client/artifact_kinds
       - /workflow/capability_enforcement
     projection_sha256: sha256:...
     registry_digest: sha256:...      # new in v2: digest of the Registry fragment used
     ownership_digest: sha256:...     # new in v2: digest of the path-ownership fragment used
   resolver:
     version: 1.1.0
     rule_set_revision: sha256:...
   ```

   The rationale: if the projection binds only the Project Context
   reference, a Registry change (required facets / gates / minimum
   enforcement) or a path-ownership change passes through as "still
   fresh," letting an old Feature complete its Gate with insufficient
   artifacts. Staleness must bind to everything the Resolver actually
   consumed.

2. **Semantic output, defined for comparison purposes.** Because
   `context_binding` (which carries the digests themselves) is part of
   the Facet Manifest, comparing the *whole* Manifest for change makes
   any digest update trivially "change the output" — that would make the
   unchanged-output branch below unreachable. To keep that branch
   reachable, **semantic output** is defined as: the resolved
   required/conditional facets, their N/A reasons, the **resolved gate
   set (each gate's ID, `stage`, and `blocking` value)**, the **effective
   minimum enforcement applying to the Feature** (the Registry-derived
   input to the effective-enforcement computation, decision document v2
   §10, Q9), the capability set, and the **lite eligibility
   determination** — i.e.
   everything in the Facet Manifest *except* the `context_binding` and
   `resolver` blocks, which are binding/provenance metadata, not output.
   Only semantic output is compared when deciding whether a Feature
   becomes stale; a digest-only update is never by itself a
   semantic-output change. **A Registry edit that changes a gate's
   `stage` or `blocking` value while its gate ID stays the same, or that
   tightens the minimum enforcement applying to the Feature, is a
   semantic-output change** — comparing gate IDs alone would silently
   miss both, which would defeat this ADR's purpose of binding staleness
   to every Registry change that affects Gate behavior.

3. **Unified change handling** across Context, Registry, and ownership:
   - If **none** of the three digests (projection / registry / ownership)
     changed, the Feature continues; only a `WARN` is recorded.
   - If **any** digest changed, the Resolver is re-run for the affected
     Feature(s), and its **semantic output** (as defined above) is
     recomputed and compared to the previous semantic output. **Only
     Features whose semantic output actually changes are selectively
     marked stale.** If the semantic output is unchanged, the
     `context_binding`/`resolver` metadata (including the digests) is
     updated and the Feature continues without becoming stale. There is
     no blanket stop-all-Features behavior.
   - A **Policy Weakening** change (as scoped in ADR-0019 §6) blocks every
     affected Feature, requires Project Context re-approval, and forces
     those Features to re-resolve.

4. **Resolves the Q11/Q15 inconsistency**: because ownership changes are
   now detected via `ownership_digest`, only the Features whose Reverse
   Coverage result actually changes are required to re-resolve — the
   Reverse Coverage Gate (`check-component-coverage`, decision document
   v2 §12) and the Facet Manifest staleness binding now agree.

5. **Completed tasks are not retroactively invalidated.** A past `Done` is
   never revoked. However, at Delivery time the current Context is
   re-checked for compatibility:

   ```text
   Task Done + artifact based on an old Context + inconsistent with
   current production policy → Delivery Blocked
   ```

6. **Resolver version rule** (transcribed from decision document v2
   §18.2): `resolver.version`'s semver component governs how a version
   bump interacts with staleness. A **patch** bump requires no
   regeneration if the semantic output is unchanged. A **minor** bump
   requires running the impact assessment (item 3 above); the Feature is
   marked stale only if the projection's semantic output actually
   changes. A **major** bump requires a mandatory re-resolve for every
   Feature that used the affected Resolver version, regardless of
   whether the semantic output would change.

## Consequences

- Resolver re-execution becomes a normal, expected event on ordinary
  Registry or ownership edits, not just on Project Context edits; Epic A5
  (Capability Resolver) is expected to be cheap enough to re-run per
  affected Feature without becoming a bottleneck, though this ADR does
  not fix a measurable performance threshold.
- Only Features whose resolved output actually differs are stale; this
  avoids the blast-radius problem of "one Registry typo invalidates every
  in-flight Feature" while still closing the staleness gap.
- Policy Weakening remains the one category that blocks unconditionally
  and requires re-approval, which keeps ADR-0019's approval-defense
  investment meaningful — a weakening change cannot be laundered through
  the "no output change → just update the digest" path, because a
  weakening change's whole point is intended to affect Gate behavior.
- Delivery-time compatibility re-checking means a `Done` task's artifact
  can still be blocked from shipping long after implementation, which
  must be surfaced clearly to avoid a "Done but can never ship" trap being
  discovered only at the last step.

## References

- Decision document v2 §16 (Q15) and §12 (Q11, Reverse Coverage Gate) —
  `docs/ai-dlc-foundation-decision-v2.md`
- Tracking issue #187 / Epic A0 issue #188
- ADR-0017 (Gate Stage Model, Implementation Gate's
  `check-component-coverage` dependency), ADR-0019 (Approval Sidecar
  Protection, Policy Weakening scope)
