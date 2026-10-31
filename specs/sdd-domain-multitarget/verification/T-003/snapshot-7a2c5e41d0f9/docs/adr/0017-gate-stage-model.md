# ADR 0017: Gate Stage Model

Status: Accepted

Date: 2026-07-19

## Context

This decision was confirmed through three independent adversarial review
passes (a Claude counter-argument review, a Claude fact-checking review,
and a Codex counter-argument review), each cross-checked against the
sdd-forge repository's actual code. It is one of the eleven "skeleton"
decisions that survived independent adversarial review without being
falsified, per `docs/ai-dlc-foundation-decision-v2.md` §3 (Q2: Task Done
vs. distribution-evidence timing).

Marking a task's implementation `Done` and confirming that its artifact
is actually signed, notarized, published, or serving production traffic
are different concerns with different available evidence at different
points in time. Conflating them either blocks `Done` on facts that are
not yet knowable (store review completion, canary results, production
SLOs) or lets `Done` claim more than implementation-time verification can
support.

## Decision

1. **Gates are classified into three stages**: `implementation`,
   `artifact`, `promotion`. Foundation (this Epic set) implements only
   `stage: implementation`. `artifact` and `promotion` are reserved enum
   values in the Registry schema with implementation explicitly exempted
   for Foundation; the completeness tests in decision-document v2 §13
   apply only to `stage: implementation` gates.

2. **Implementation Gate** (`stage: implementation`):
   - Executed by `sdd-quality-loop` (or `lite-gate` on the lite track);
     result: `Task Status: Done`.
   - Invariant (unchanged from existing behavior, restated precisely):
     **only the gate skill (`quality-gate` or `lite-gate`) can mark a Task
     Done.**
   - Scope is limited to what is verifiable at implementation time:
     Project Context validity, Facet Manifest validity, Capability
     Coverage, component/git-diff consistency
     (`check-component-coverage`, ADR-0021's staleness dependency),
     design-contract conformance, unit/integration/regression tests,
     package/build feasibility, Delivery Pipeline structure,
     signing/notarization *configuration presence and structure* (not
     execution), migration simulation, IaC validate/plan, retry /
     idempotency / compensation / replay tests, public API diff,
     observability contract, mitigation plan, cross-model verification
     (fail-closed; a waiver requires a second named human approver),
     evaluator-identity fields in the gate report, an HMAC-signed evidence
     bundle, and the quality-gate cycle limit.
   - Explicitly **not** required at this stage: actual code signing,
     actual notarization, store review completion, production deployment,
     canary results, production SLOs, a registry-published artifact, or
     confirmed Stable-channel distribution.

3. **Artifact Gate** (`stage: artifact`, reserved — not implemented in
   Foundation):
   - Would be executed by `sdd-delivery` (a new plugin that does not exist
     in the repository today), gated on the related implementation task
     being `Done`, producing `Artifact Status: Verified`.
   - The per-target (Desktop/Cloud/Workflow/CLI-Library) check inventory
     from decision-document v1 is retained only as reference material; its
     vocabulary is formally decided only when `sdd-delivery` is
     implemented, in its own ADR.
   - Where `Artifact Status: Verified` is recorded is not defined in
     Foundation. If it is derivable from actual provider state at
     implementation time, no local record is kept; if not derivable, it is
     treated the same as the protected sidecar in ADR-0019 (agent
     write-denied + HMAC). No freely agent-writable approval-like record
     may be introduced.

4. **Promotion Gate** (`stage: promotion`, reserved — vocabulary
   deferred by designer ruling):
   - Would produce `Delivery Status: Staging | Candidate | Production |
     Stable`.
   - The v1 check inventory (canary analysis, SLO, store publication
     state, workflow version routing, etc.) is **not frozen** in
     Foundation, because freezing vocabulary against zero real data is a
     primary cause of schema-v2 breakage. It is formalized in its own ADR
     once a cloud-service Pack has a real production case (see decision
     document v2 §17, Pack rollout order).

5. **Gate definition schema**:

   ```yaml
   gates:
     - id: check-update-migration
       stage: implementation   # implementation | artifact | promotion (reserved)
       blocking: true
   ```

## Consequences

- Signing, notarization, store publication, registry publication, and
  canary results are never inputs to `quality-gate`; `quality-gate`
  verifies only that the design and pipeline that would produce them are
  correct.
- Foundation's Registry and Gate machinery (ADR-0020's Predicate DSL,
  ADR-0021's staleness binding, ADR-0016's `capability_enforcement`) need
  only reason about `stage: implementation`; `artifact` and `promotion`
  are inert reserved values until `sdd-delivery` exists.
- Deferring the Promotion vocabulary avoids a second schema-breaking
  freeze but means Epic A9 (dogfood) and any early cloud-service Pack
  cannot rely on a `Delivery Status` contract until that later ADR lands.
- The `Done`-only-via-gate-skill invariant is unchanged from current
  behavior; this ADR narrows *when in the lifecycle* a Done decision can
  be made, not *who* can make it.

## References

- Decision document v2 §3 (Q2) and §13 (Q12, gate completeness scope) —
  `docs/ai-dlc-foundation-decision-v2.md`
- Tracking issue #187 / Epic A0 issue #188
- ADR-0016 (Workflow Axes Separation), ADR-0019 (Approval Sidecar
  Protection), ADR-0021 (Context Projection Staleness)
