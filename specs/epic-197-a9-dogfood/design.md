# Design: epic-197-a9-dogfood

Impl-Review-Status: Pending
Human-Design-Approval: Pending

## Technical Summary

A9 is a two-phase configuration-and-evidence change. Phase 1 publishes a live,
approved sdd-forge Project Context using the legacy seven-layer artifact layout
and advisory enforcement, adds the first developer-tooling / cli-library Pack,
and dogfoods the merged Foundation pipeline. Phase 2 promotes both workflow axes
atomically after human-approved evidence thresholds. This design deliberately
leaves component, ownership, promotion, rollback-operation, and Pack-content
decisions open (OQ-001–OQ-005).

## Architecture

```text
repository paths + git change
          |
          v
sdd/project-context.yaml -----> component ownership / ownership_digest
          |                                  |
          +--------> Capability Resolver <---+--- Capability Registry + first Pack
                         |
                         +--> Facet Manifest / Summary / Projection / evidence
                                      |
                       advisory observe (Phase 1)
                                      |
                    promotion decision + human approval
                                      |
                       required enforce (Phase 2)
                                      |
             policy-weakening rollback (conditional approval)
```

The output names follow the A4/A5 decision contract
(`docs/ai-dlc-foundation-decision-v2.md:532-539`). The live resolver must be
re-verified after A5 merges; this draft does not bind another branch's filenames.

## Components

| Design component | Responsibility | Planned owner |
|---|---|---|
| Context candidate | Human-approved component characteristics and ownership map | T-002 |
| First Pack | Registry entries selected by OQ-005 | T-003 |
| Dogfood evidence harness | Representative advisory scenarios and evidence capture | T-004 |
| Promotion/rollback harness | Threshold, atomic transition, and approval-branch tests | T-005 |
| WFI capture | Draft records for reproducible operational friction | T-006 |

These are implementation-work components, not the unresolved Project Context
component inventory itself.

## Protected-File Statement

The live Context approval sidecar and policy verification machinery use the
protected human-copy boundary (`docs/adr/0019-approval-sidecar-protection.md:49-82`).
Before implementation, T-001 must re-scan `guard-invariants.json` and record the
exact protected paths. Tasks shall stage protected candidates only in the
feature's `human-copy/` tree with the repository's required manifest; no task may
edit a protected live target directly. This draft creates no such candidate.

## Layer Specifications

- UX: `ux-spec.md` — CLI/operator journeys only; no graphical UI.
- Frontend: `frontend-spec.md` — N/A browser frontend; script/contract surfaces.
- Infrastructure: `infra-spec.md` — CI, release, environments, rollback.
- Security: `security-spec.md` — sidecar, approval identities, token/release boundaries.

## Design System Compliance

N/A. sdd-forge is developer tooling and this epic adds no graphical interface.

## Cross-Layer Dependencies

| From | To | Contract |
|---|---|---|
| Context | Ownership resolver | component IDs and path rules |
| Context + Registry | Capability Resolver | workflow mode, characteristics, Pack triggers |
| Resolver | Promotion decision | bound Manifest/Summary/Projection/evidence |
| Promotion/rollback | Security | approval sidecar, identities, effective time, HMAC |
| Dogfood | WFI lane | reproducible friction evidence only |

## ADR Change Log

No new ADR is proposed in this draft. ADR-0019 governs approval and rollback.
If OQ-001, OQ-003, OQ-004, or OQ-005 creates a durable architecture decision not
already covered, the human ruling must decide whether a new ADR is required and
re-verify the next free number immediately before drafting.

## Data Plan

### `sdd/project-context.yaml`

Uses `contracts/project-context.schema.json`. Phase tuples:

| Phase | spec_profile | artifact_layout | capability_enforcement |
|---|---|---|---|
| 1 | full | legacy-seven-layer | advisory |
| 2 | full | facet-hybrid | required |

The component and shared-path bodies are placeholders until OQ-001/OQ-002 are
resolved. The generic starter is an input, not the live result
(`contracts/project-context.template.yaml:1-30`).

### `dogfood-run/v1` evidence concept

The exact storage contract must align with the merged A5 output rather than
inventing a competing evidence schema. At minimum the saved run must make
reviewable: run ID/time, Context revision/hash, Registry and ownership digests,
resolver version/rule-set revision, changed paths, affected components, phase,
findings/dispositions, output artifact paths, platform/host, and outcome.

### `promotion-decision/v1` evidence concept

Stores the OQ-003 criteria revision, evidence-set references, per-criterion
pass/fail, human decision identity/time, old tuple, proposed tuple, and result.
It must not claim promotion if any evidence is stale or any threshold fails.

### Rollback request/evidence

Do not invent a second approval format. Use the A1/ADR-0019 approval sidecar and
weakening evidence. The procedure selected by OQ-004 supplies approver-registry
cardinality, distinct identities or cooldown `effective_at`, HMAC verification,
and application result (`docs/adr/0019-approval-sidecar-protection.md:32-94`).

## API / Contract Plan

| Contract | Change | Compatibility rule |
|---|---|---|
| Project Context schema | no schema change expected | Live YAML validates existing v1. |
| Capability Registry | extend existing instance per OQ-005 | Existing durable-workflow entry remains semantically unchanged. |
| A3 ownership tools | consume, do not fork | Results must bind current ownership digest. |
| A4/A5 outputs | consume merged contract | Block if absent/incompatible. |
| Approval sidecar | consume A1 contract | Protected, HMAC-bound, no agent approval. |

## Test Strategy

1. Schema and exact-tuple fixtures for Phase 1 and Phase 2.
2. Component oracle derived from the dated OQ-001 ruling.
3. Ownership positive, omitted-path, overlap, and shared-path fixtures.
4. Pack trigger/non-trigger fixtures and later-Pack absence check.
5. Advisory non-blocking versus unchanged existing-gate behavior.
6. Promotion evidence completeness, staleness, and each partial-transition case.
7. Rollback branch fixtures for multi-identity and solo/cooldown modes plus four
   invalid sidecar classes.
8. `.sh`/`.ps1`, three-OS, install/release regression evidence in existing CI.

Tests that scan vocabulary must assemble banned markers at runtime so their own
source cannot become the detection suite's false positive (AGENTS.md WFI-012).
Any `.sh` to `.ps1` parity port receives separate operator-level and
cmdlet/language-feature case-sensitivity sweeps with mis-cased negatives.

## Design Decisions

- Use one live Context and one existing Registry; no A9-specific shadow stores.
- Treat Phase 1 and Phase 2 as separately approved Context revisions.
- Make Phase-2 axes atomic at the A9 contract level.
- Reuse the accepted approval-sidecar mechanism for rollback.
- Persist dogfood friction only when reproducible; do not manufacture WFI volume.

## Global Constraints

- Implement one approved task at a time; only quality-gate may set Done.
- No task begins until T-001's dependency/shared-state preflight passes.
- Protected targets use human-copy staging.
- No new CI workflow or matrix dimension.
- No external service or LLM call in deterministic tests.
- Re-verify line citations and shared inventories at review/implementation time.

## Security Boundaries

| Boundary | Threat | Control | Tests |
|---|---|---|---|
| Agent → protected approval | self-approval/tampering | protected copy + HMAC | TEST-002, TEST-016–018 |
| Context → Resolver evidence | stale/mismatched policy | bound revisions/digests | TEST-010, TEST-012–013 |
| CI-MCP → GitHub | token disclosure/write expansion | preserve read-only GET contract | TEST-007, TEST-024 |
| Release workflow | unauthorized publication | preserve existing gate/OIDC/attestation policy | TEST-007, TEST-024 |

## External Integrations

No new integration. Existing GitHub CI/release and CLI installers are regression
surfaces. Deterministic tests use fixtures; real release publication is not a
quality-gate side effect.

## Deployment / CI Plan

Register checks inside the existing cross-OS test topology only
(`.github/workflows/test.yml:21-1145`). Any protected workflow edit is staged for
human application. Phase 1 deploys the approved Context/Pack in advisory mode;
Phase 2 deploys the separately approved atomic promotion.

## Constraint Compliance

This design creates specs only, carries unresolved decisions as OQs, preserves
other epics' frozen artifacts, and leaves every task Draft/Planned.

## Assumptions

- The issue body will be reachable and reconciled before review.
- A5's merged filenames/contracts may differ from its current remote feature ref.
- Current component directories, guard list, Registry, and WFI namespace are
  mutable shared state and require fresh scans.

## Open Questions

OQ-001 through OQ-005 are defined normatively in `requirements.md` and remain
unresolved. No implementation task may turn a candidate into a binding choice
without a dated human ruling.

## Risks

| Risk | Mitigation |
|---|---|
| Ownership rules hide changes | omitted/overlap/reverse-coverage fixtures and human map review |
| Pack overreaches | OQ-005 and explicit later-Pack absence test |
| Premature enforcement | measurable OQ-003 gates plus stale-evidence rejection |
| Rollback unusable or weak | both cardinality branches and invalid-sidecar fixtures |
| Shared state drifts | T-001 fresh inventories/hashes at implementation HEAD |

