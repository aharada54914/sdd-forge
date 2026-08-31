# Requirements: epic-197-a9-dogfood

Spec-Review-Status: Pending
Human-Spec-Approval: Pending
Source: Issue #197 supplied requirements; decision document §§17 and 19

## Overview

Epic A9 dogfoods AI-DLC Foundation by describing sdd-forge itself in a live
Project Context, exercising the first developer-tooling / cli-library Capability
Pack, and promoting enforcement in a controlled second phase. This package is a
first draft only. It creates no live Context, Pack, approval sidecar, or WFI.

## Target Users

- sdd-forge maintainers defining repository architecture and policy.
- contributors changing plugins, MCP services, installers, CI, or release paths.
- SDD agents and deterministic tooling resolving affected components and facets.

## Problems

- The generic Context starter intentionally has no components and is not a live
  sdd-forge instance (`contracts/project-context.template.yaml:1-17`).
- The Registry lacks the first Pack named by the decision (`contracts/capability-registry.json:1-43`;
  `docs/ai-dlc-foundation-decision-v2.md:488-492`).
- Component and ownership choices affect enforcement but are not safely derivable
  without human architectural judgment.
- Promotion and rollback require evidence and governance stronger than a direct
  workflow-field edit (`docs/adr/0019-approval-sidecar-protection.md:49-94`).

## Goals

### REQ-001 — Phase-1 live Project Context

After human approval and dependency preflight, A9 shall create sdd-forge's live
`sdd/project-context.yaml`, schema-valid as `sdd-project-context/v1`, with
`spec_profile: full`, `artifact_layout: legacy-seven-layer`, and
`capability_enforcement: advisory`. The implementation shall use the protected
approval publication workflow and shall not make an unsigned or agent-approved
sidecar (`contracts/project-context.schema.json:1-20`;
`docs/adr/0019-approval-sidecar-protection.md:32-69`).

### REQ-002 — Human-approved component inventory

The Context shall contain the human-approved OQ-001 decomposition. Each component
shall have a stable ID and the applicable artifact kinds, runtime classes,
platform targets, characteristics, distribution channels, data classification,
provider bindings, and path rules; omitted optional fields shall be justified,
not silently guessed (`contracts/project-context.schema.json:21-65`).

### REQ-003 — Complete path ownership

The Context shall encode the human-approved OQ-002 include/exclude/shared map and
shall pass overlap, unowned-path, reverse-coverage, and ownership-digest checks
supplied by A3. Shared classifications shall use the schema's component-list or
cross-cutting form (`contracts/project-context.schema.json:67-76`;
`docs/ai-dlc-foundation-decision-v2.md:529-530`).

### REQ-004 — Repository characteristics

The component inventory shall preserve meaningful differences between plugin,
MCP, installer, CI, and release surfaces. In particular, credential-bearing CI
MCP and release publication shall not inherit a blanket “no credentials/no
write” characteristic from the read-only local services (`README.md:108-150`;
`.github/workflows/release.yml:26-50`).

### REQ-005 — First developer-tooling / cli-library Pack

A9 shall add the first Pack selected by Q16 without defining desktop,
cloud-service, or durable-workflow Packs. The human-approved OQ-005 decision shall
fix its Registry capability IDs, predicates, facets, review checks, implementation
gates, Lite policy, minimum enforcement, and delivery strategy before code is
authored (`docs/ai-dlc-foundation-decision-v2.md:488-492`;
`contracts/capability-registry.json:1-43`).

### REQ-006 — Advisory dogfood evidence

Phase 1 shall run the merged A1–A8 Context/ownership/Resolver/Manifest,
compatibility, and cross-runtime mechanisms against representative sdd-forge
changes. Advisory diagnostics shall be recorded without blocking delivery solely
because a new Pack finding exists; existing independent gates remain unchanged.

### REQ-007 — Promotion readiness decision

Promotion shall occur only after the human approves OQ-003's measurable criteria
and saved evidence demonstrates them. The promotion decision shall identify the
Context revision, Registry digest, ownership digest, resolver version, affected
components, advisory findings/dispositions, and compatibility/cross-runtime
results used as its basis (`docs/ai-dlc-foundation-decision-v2.md:501-510,547-555`).

### REQ-008 — Atomic Phase-2 promotion

Phase 2 shall change the live Context from `legacy-seven-layer`/`advisory` to
`facet-hybrid`/`required` through the protected approval workflow. Verification
shall reject a mixed transition where only one axis changed, or where required
enforcement is activated before the selected Pack and resolver evidence are
available.

### REQ-009 — Policy-weakening rollback

A required-to-advisory rollback shall follow the human-approved OQ-004 procedure
and ADR-0019: two distinct approvals when at least two real identities are
registered, otherwise a first approval plus an HMAC-bound 24-hour cooldown. Early,
unsigned, self-approved, or identity-duplicated application shall fail
(`docs/adr/0019-approval-sidecar-protection.md:49-94`).

### REQ-010 — Operational-friction capture

During dogfood, reproducible workflow friction shall be recorded as new Draft WFI
records in `docs/workflow-improvements/`, with evidence, why-why analysis,
controllable root-cause hypothesis, proposed change, and expected effect. Agents
shall not approve those records (`docs/workflow-improvements/WFI-045.md:1-31`;
`README.md:257-259`).

### REQ-011 — Dependency and shared-state preflight

Before any implementation task changes live artifacts, it shall re-verify at its
current HEAD that A1–A8's required contracts and implementation surfaces are
merged and usable, and shall re-scan the shared Registry, guard inventory,
component directories, Active Spec list, WFI number, and protected human-copy
targets. Missing or incompatible dependencies shall block rather than be inferred
from another branch (`docs/ai-dlc-foundation-decision-v2.md:522-555`; INV-018).

### REQ-012 — Deterministic, cross-platform validation

The Context, Pack, advisory run, promotion, and rollback paths shall have saved
deterministic test evidence on the applicable Bash/PowerShell and Windows,
macOS, Linux surfaces, reusing existing CI topology and preserving current
install/release behavior (`README.md:148-175,261`; `.github/workflows/test.yml:21-1145`).

## Non-goals

- Creating any live `sdd/` file during specification bootstrap.
- Implementing later desktop, cloud-service, or durable-workflow Packs.
- Replacing the Registry, ownership resolver, Facet Manifest, or approval model.
- Adding a UI, cloud deployment, or new CI workflow.
- Approving this spec, any task, approval sidecar, or WFI.

## User Stories

- As a maintainer, I want repository changes mapped to meaningful components so
  capability guidance and ownership findings are explainable.
- As a contributor, I want advisory dogfood before required enforcement so false
  positives can be corrected with evidence.
- As a solo maintainer, I want emergency policy rollback possible without a fake
  second identity, while retaining the mandated cooldown.

## Acceptance Criteria

| ID | Requirement | Criterion |
|---|---|---|
| AC-001 | REQ-001 | A schema test accepts exactly the Phase-1 workflow tuple `full` / `legacy-seven-layer` / `advisory`. |
| AC-002 | REQ-001 | Publication tests reject missing/invalid approval binding and demonstrate the human-copy boundary. |
| AC-003 | REQ-002 | A fixture asserts every approved component ID and its required classification fields against the OQ-001 decision record. |
| AC-004 | REQ-002 | A fixture rejects one deliberately omitted required component and one unjustified empty classification. |
| AC-005 | REQ-003 | Ownership validation reports zero unexplained overlaps for the approved map. |
| AC-006 | REQ-003 | Ownership validation reports zero unexplained unowned tracked paths and verifies every approved shared-path rule. |
| AC-007 | REQ-004 | Characteristic tests distinguish plugin/MCP/installer/CI/release boundaries, including the CI-MCP credential and release-write cases. |
| AC-008 | REQ-005 | Registry validation accepts the human-approved first Pack and resolves it for a representative sdd-forge component. |
| AC-009 | REQ-005 | Registry validation proves desktop, cloud-service, and new durable-workflow Pack entries were not added by A9. |
| AC-010 | REQ-006 | An advisory run emits Manifest/Summary/Projection/evidence with bound revision and digests for a representative plugin change. |
| AC-011 | REQ-006 | An advisory Pack finding is visible and non-blocking while pre-existing blocking gates retain their behavior. |
| AC-012 | REQ-007 | The promotion record contains every evidence field named in REQ-007 and links each criterion to saved evidence. |
| AC-013 | REQ-007 | Promotion is rejected when one human-approved OQ-003 threshold is unmet or evidence is stale. |
| AC-014 | REQ-008 | Schema/resolver tests accept the atomic Phase-2 tuple `full` / `facet-hybrid` / `required`. |
| AC-015 | REQ-008 | Tests reject each partial promotion: layout-only and enforcement-only. |
| AC-016 | REQ-009 | A two-or-more-identity fixture requires two distinct valid approvals for required-to-advisory rollback. |
| AC-017 | REQ-009 | A single-identity fixture rejects rollback before 24 hours and accepts it at/after the signed effective time. |
| AC-018 | REQ-009 | Rollback fixtures reject unsigned, self-approved, duplicated-identity, and non-bound sidecars. |
| AC-019 | REQ-010 | A dogfood friction fixture produces a Draft WFI with all required analysis sections and no Approved status. |
| AC-020 | REQ-011 | Dependency preflight blocks when any A1–A8 required surface is absent/incompatible and records the failing dependency. |
| AC-021 | REQ-011 | Shared-state preflight records fresh hashes/inventories for Registry, guards, components, Active Specs, WFI namespace, and protected targets. |
| AC-022 | REQ-012 | Context/Pack/advisory/promotion tests pass through the applicable `.sh` and `.ps1` entry points. |
| AC-023 | REQ-012 | Existing CI executes the new checks on Windows, macOS, and Linux without adding a workflow or matrix dimension. |
| AC-024 | REQ-012 | An install/release regression set proves Phase 1 and Phase 2 preserve current Claude/Codex/Copilot packaging behavior. |

## Field Definitions

| Field | Meaning |
|---|---|
| Phase 1 | Approved live Context using `full`/`legacy-seven-layer`/`advisory`. |
| Phase 2 | Approved live Context using `full`/`facet-hybrid`/`required`. |
| Pack | Human-approved Registry capability set for developer-tooling / cli-library. |
| Promotion record | Saved, reviewable decision evidence for moving Phase 1 to Phase 2. |
| Rollback | Policy-weakening `required` to `advisory` transition. |

## Roles and Permissions

| Role | May do | Must not do |
|---|---|---|
| Agent implementer | Draft Context/Registry/human-copy candidates and tests after task approval | Approve protected records, tasks, or WFIs |
| Human maintainer | Resolve OQs, approve spec/tasks, apply protected copies | Bypass deterministic checks |
| Independent evaluator | Verify task evidence | Implement or self-approve the task being evaluated |

## Main Workflows

1. Human resolves OQ-001–OQ-005 and approves the reviewed spec/tasks.
2. Preflight A1–A8 and mutable shared state.
3. Publish and approve Phase-1 Context; add and validate the first Pack.
4. Run advisory dogfood and capture saved evidence and Draft WFIs.
5. Human evaluates OQ-003 criteria and authorizes promotion.
6. Publish atomic Phase-2 Context and verify required enforcement.
7. If rollback is necessary, follow OQ-004 and ADR-0019.

## Edge Cases

- A tracked path matches no component and no shared rule: block Phase 1.
- A path matches multiple components without an approved shared rule: block.
- Resolver evidence binds an older Context/Registry/ownership digest: stale, not
  promotion evidence.
- Approver registry changes between rollback request and effective time: re-run
  approval validation with the current registry.
- No friction is observed: record the dogfood run and “no WFI created”; never
  fabricate a WFI.

## Security Boundaries

- Project Context and provider approval sidecars are protected, HMAC-bound human
  records (`docs/adr/0019-approval-sidecar-protection.md:32-82`).
- Release publication has write/OIDC/attestation permissions and remains outside
  the read-only MCP claim (`.github/workflows/release.yml:26-50`).
- CI-MCP reads a token but must not persist or disclose it (`README.md:132-144`).

## Assumptions

- Issue #197's full body must be re-read before spec review because network access
  failed during this bootstrap; any conflict supersedes the supplied summary.
- A1–A8 availability is mutable shared state and must be re-verified at spec
  review and implementation, never assumed from this draft.
- The next WFI number is not reserved here; allocate it at record-creation time.

## Open Questions

### OQ-001 — Component decomposition

Which stable components should represent sdd-forge: per-package, capability-group,
or hybrid? Human ruling must include IDs and rationale.

### OQ-002 — Path ownership map

Which include/exclude patterns belong to each component, and which repository
paths are component-shared versus cross-cutting? Human ruling must address
plugins, MCP services, root installers, contracts, scripts, tests, docs, specs,
reports, marketplaces, CI, release, and root metadata.

### OQ-003 — Phase-2 promotion criteria

What measurable advisory duration/sample size, false-positive threshold,
unresolved-finding threshold, platform coverage, compatibility evidence, and
rollback rehearsal are mandatory before `facet-hybrid`/`required`?

### OQ-004 — Conditional rollback procedure

What exact operator steps and persisted evidence select the two-party branch or
single-maintainer cooldown branch, handle approver-registry changes, and authorize
the human-copy application of required-to-advisory rollback?

### OQ-005 — First Pack contents

Is developer-tooling / cli-library encoded as one capability, two capabilities,
or a composed Pack, and which predicates, facets, review checks, gates, Lite
policy, minimum enforcement, and delivery strategy are normative?

## Risks

- Over-broad ownership may make coverage green by hiding meaningful boundaries.
- Required enforcement may create release deadlocks if promoted on insufficient
  samples.
- Pack semantics may duplicate rather than compose existing Registry entries.
- Rollback governance may be unusable if it does not explicitly model registry
  cardinality and time-bound approval.
