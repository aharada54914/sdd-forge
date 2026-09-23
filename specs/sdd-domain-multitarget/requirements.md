# Requirements: sdd-domain-multitarget (Issue #423 Phase 1)

Spec-Review-Status: Pending

## Overview

This specification defines a bounded first migration slice for applying the
existing SDD workflow to software and system design targets beyond conventional
application code. It assigns current consumers to KEEP, PARAMETERIZE, EXTRACT,
or DEFER and identifies ownership for shared workflow policy, target
Capabilities, Provider Bindings, and host adapters. It does not replace the
Multi-target Foundation in #187 or claim that its planned integrations are
complete.

Baseline: `origin/main` at `51adb50b` (2026-09-23 checkout). Repository facts
below cite the checked-out source and must be re-verified against the consuming
files at spec/design review and implementation planning, since these files may
change independently.

## Problem

The repository already has a multi-axis workflow model, Capability resolution,
Provider Binding separation, and three runtime hosts. Some consumers still
encode a fixed set of application-oriented documents, checks, UI tooling, or
provider-specific APIs directly. A broad rewrite would duplicate the
Foundation and destabilize legacy consumers. This slice must define which
existing consumer owns each responsibility and the minimum compatibility
boundary for future target-specific selection.

Evidence from current source:

- Full-profile interviewer questions cover UX, contracts, workflow, frontend,
  backend/testing, infrastructure, and security; unaffected layers may be
  written as N/A while security assessment remains required
  ([SKILL.md:102-117](../../plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md#L102)).
- Full-profile Phase 1 required outputs include `ux-spec.md`,
  `frontend-spec.md`, `infra-spec.md`, and `security-spec.md`
  ([SKILL.md:159-176](../../plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md#L159)).
- The design template fixes UX, Frontend, Infrastructure, and Security rows
  ([design.template.md:20-30](../../plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/design.template.md#L20)).
- Verification contracts hardcode risk-tier checks and know only `code`,
  `shell`, `docs`, and `spec` stacks; compile checks are waivable only for the
  non-code stacks currently named there
  ([check-contract.py:37-51](../../plugins/sdd-quality-loop/scripts/check-contract.py#L37),
  [check-contract.py:303-320](../../plugins/sdd-quality-loop/scripts/check-contract.py#L303)).
- The UI design loop contains generic UI artifact intent as well as concrete
  DesignSync, claude.ai/design, Figma DTCG import, ui-ux-pro-max, HTML mockup,
  and egress-consent operations
  ([design-sync-loop/SKILL.md:8-30](../../plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md#L8),
  [design-sync-loop/SKILL.md:39-64](../../plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md#L39),
  [design-sync-loop/SKILL.md:74-86](../../plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md#L74)).
- The architecture checklist names OpenAPI or JSON Schema for endpoint
  contracts ([architecture-review-checklist.md:30-35](../../plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/references/architecture-review-checklist.md#L32)).
- `ci-mcp` is already a distinct package whose server exposes read-only GitHub
  Actions tools ([server.ts:4-18](../../mcp/ci-mcp/src/server.ts#L4)); its API
  client issues GET requests ([github-client.ts:102-117](../../mcp/ci-mcp/src/github-client.ts#L102)).
- ADR-0016 already defines `spec_profile`, `artifact_layout`, and
  `capability_enforcement` as separate axes and describes `facet-hybrid` as a
  compatibility form ([ADR-0016:33-54](../../docs/adr/0016-workflow-axes-separation.md#L33)).
- ADR-0018 puts provider details in Provider Bindings while Capabilities remain
  provider-neutral and Project Context stores binding IDs
  ([ADR-0018:46-68](../../docs/adr/0018-provider-binding-separation.md#L46)).
- ADR-0017 reserves artifact and promotion stages; the Foundation implements
  the implementation stage ([ADR-0017:27-44](../../docs/adr/0017-gate-stage-model.md#L27)).

## Goals

- Define a first, bounded change set that reduces hard-coded target assumptions
  while retaining current default behavior for projects without an active,
  valid Project Context.
- Make the decision for each affected consumer explicit as KEEP,
  PARAMETERIZE, EXTRACT, or DEFER.
- Define which policy belongs to SDD Core, which target-specific obligations
  belong to Capabilities, which provider facts/actions belong to Provider
  Adapters/Bindings, and which runtime mechanics belong to Host Adapters.
- Require examples and compatibility checks spanning CLI/library, UI
  application, design-only, IaC/cloud, and low-code targets.
- Preserve fail-closed enforcement, human approval, evidence binding, and the
  existing Foundation contracts.

## Non-goals and Deferred Work

- No new cloud execution engine, cloud write path, deployment/promotion gate,
  resource model, or Azure/AWS-specific Capability in this slice.
- No wholesale conversion to `facet-native`; retain legacy and hybrid forms
  until migration is separately approved and supported by operational evidence.
- No new plugin/package split unless a concrete independent dependency,
  release, or ownership boundary requires it.
- No change to the reviewed sdd-domain DDD plugin specification or its
  implementation.
- No weakening or bypass of quality gates, evidence requirements, policy
  approvals, or host hook guards.
- No automatic removal of unit/TDD checks for design-only work in this
  requirements/design slice. Any verification-contract change requires its
  own approved, versioned migration and consumer analysis. Existing
  `check-contract.py` requirements remain in force: design-only selection may
  validate which target candidate applies, but it cannot waive or auto-remove
  legacy-required checks. If a legacy-required check is unavailable or unrun,
  the gate MUST report `BLOCKED` with an explicit migration-pending reason;
  `not-applicable` for such checks is permitted only after an approved,
  versioned migration.
- No redesign of the Foundation Resolver or Registry. Their existing state
  and consumers must be verified before connecting a new profile.

## Requirements

### REQ-001: Consumer disposition

The implementation plan derived from this specification MUST classify every
affected consumer below using exactly one of KEEP, PARAMETERIZE, EXTRACT, or
DEFER, state the scope of the classification, and name compatibility evidence.

| Consumer | Decision | Scope and rationale |
|---|---|---|
| Bootstrap Phase 1's questions for requirements, contracts, workflow, security, and system boundaries | KEEP | Shared questions remain in the common interview; make target-specific follow-up conditional through resolved Facets rather than replacing the interviewer. |
| Fixed full-profile seven-layer document set | PARAMETERIZE | Always generate and retain all seven legacy layer documents in legacy and facet-hybrid paths, including for non-UI targets. Express target applicability separately in the target Facet manifest/selection; do not delete, omit, or rewrite a legacy document to represent non-applicability. Only a separately approved, versioned facet-native migration may omit non-applicable documents. Retain security impact assessment. |
| Risk-tier verifier contract and check IDs | PARAMETERIZE | Core owns risk and evidence semantics; target Capability supplies required/conditional verification obligations through the protected Registry/resolver contract. Do not make checks user-editable escape hatches. |
| Compile/build/lint checks on non-code targets | PARAMETERIZE | Resolve appropriate verification kinds per target; distinguish not-applicable from not-run/unknown. Existing fixed checks remain in legacy behavior until a versioned migration. |
| DesignSync/claude.ai/design and service-specific mockup upload steps | EXTRACT | Keep generic user-centered design requirements and local visual-reference support in bootstrap. Put concrete external-tool operations behind an optional UI design provider/capability boundary, preserving consent and manual fallback semantics. |
| Endpoint contract checklist | PARAMETERIZE | Keep contract correctness, pre/postconditions, errors, and compatibility as shared principles; choose OpenAPI, JSON Schema, or a target-appropriate contract through the Capability. |
| ci-mcp GitHub Actions package | KEEP | Existing package boundary is adequate; future CI/VCS integrations stay behind provider adapters and must not add GitHub REST assumptions to common policy. |
| Provider resource schemas, state authority, credentials, and commands | DEFER | Belong to Provider Bindings/Provider Adapters and later provider-specific work, not the common Core slice. |
| Artifact and promotion gate stages | DEFER | Reserved by ADR-0017; this scope uses implementation-stage verification only. |
| Host launch syntax, manifest shape, hook invocation, and host capability detection | KEEP | Continue using host-specific packaging/adapters; common workflow meanings and approval rules remain shared. |
| Facet-native output and distribution/package decomposition | DEFER | Requires migration evidence and separate approval; not needed to establish logical ownership boundaries. |

### REQ-002: Capability and ownership boundaries

- SDD Core MUST own requirement/acceptance traceability, approval and lifecycle
  semantics, risk classification, evidence integrity, gate aggregation,
  compatibility rules, and the meaning of pass/fail/not-applicable/not-run.
- A target Capability MUST express target-neutral obligations for the artifact
  shape, questions/facets, and required verification types. It MUST NOT contain
  provider names, provider credentials, provider-specific resource state, or a
  duplicate gate registry.
- A Provider Binding/Adapter MUST own provider identity, resource references,
  credentials references, provider operations, and provider-reported real
  state. Shared Core MUST consume a normalized result envelope without
  claiming ownership of provider state.
- A Host Adapter MUST own runtime-specific manifests, invocation syntax, hooks,
  and capability-detection mechanics. Hosts MUST share the same workflow,
  approval, and evidence semantics.
- A project context MUST refer to provider bindings by ID and MUST NOT embed
  provider details, consistent with ADR-0018.

### REQ-003: Verification selection and evidence

- An active target profile MUST resolve required checks deterministically from
  protected Registry/Capability data, approved project context, target, and
  implementation stage.
- An unavailable required verifier or a `not-run`/`unknown` result for a
  required check MUST NOT count as success; an optional check does not block
  the gate solely because it is not run. `not-applicable` MUST carry a
  machine-checkable reason and be
  allowed only where the resolved target policy permits it and an approved,
  versioned verification-contract migration has made that check non-required.
  In the current legacy contract, required checks remain required regardless
  of target selection; unavailable or unrun legacy-required checks MUST produce
  an explicit `BLOCKED` result with a migration-pending reason, never a gate
  pass. Target candidate selection alone does not establish gate success.
- The scope in this slice MUST NOT declare artifact or promotion stages
  implemented. Provider execution/deployment results MUST remain distinct from
  implementation completion.

### REQ-004: Compatibility and migration

- A project with no Project Context MUST retain existing legacy output,
  validation, and workflow behavior. This compatibility path MUST be checked
  against the actual current consumers immediately before implementation,
  because the repository state is shared and may change.
- An enabled new target path MUST be additive first: preserve the legacy
  seven-layer documents by always generating and retaining them in
  `facet-hybrid`, including for non-UI targets. Express target Facet
  applicability in a separate manifest/selection; do not delete, omit, or
  rewrite those documents. A `facet-native` layout that omits non-applicable
  documents requires a separately approved, explicitly versioned migration
  and reader/writer compatibility evidence. Do not switch the default layout
  or silently change existing checks.
- Any changed schema, status, field, or check vocabulary MUST use an explicitly
  versioned contract and identify all readers/writers before implementation.
- Compatibility evidence MUST include structural/output comparisons and
  behavioral events for legacy projects, not only unit tests of the new path.

### REQ-005: UI provider extraction

The UI workflow MUST preserve the existing optionality, per-feature upload
consent behavior, tool-unavailable manual fallback, and project-local design
artifact authority. Re-read `ds_upload_consent` on every consent-step
resolution. Preserve all three existing regimes: `per-feature` prompts only
when consent for the current feature/session/destination is absent, treats a
decline as transient, records grants/withdrawals and takes the manual
no-upload fallback for not-permitted egress; `standing` skips the prompt and
writes at most one granted audit record per feature-and-destination pair;
`off` always takes the manual fallback, makes no upload attempt, and records
not-permitted while the setting remains off. A service integration MUST be
invoked only when its Capability is resolved and its provider is available;
absence MUST not block specification generation. Shared Core MUST not acquire
claude.ai/design or Figma API dependencies. These behaviors are grounded in
the consent state machine and record contract ([design-sync-loop/SKILL.md:87-148](../../plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md#L87), [design-sync-loop/SKILL.md:244-288](../../plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md#L244)).

### REQ-006: Reviewable target examples

The Phase-1 design and subsequent implementation plan MUST show the resolved
artifact and verification obligations for at least these cases: CLI/library,
UI application, design-only, IaC/cloud, and low-code. The cases are examples
for checking the selection rules, not a promise that all provider integrations
or execution environments are implemented in this slice.

## User Stories

- As an SDD maintainer, I can see which current consumer remains common and
  which varies by target, so that changes extend the Foundation rather than
  duplicate it.
- As a designer or developer, I can use relevant design workflow for a UI
  target without forcing UI artifacts or an external design service on a
  design-only or backend target.
- As an operator, I can distinguish an inapplicable check from an unavailable
  or unrun check, so that missing verification cannot appear successful.
- As a project migrating from legacy behavior, I retain the existing workflow
  until I explicitly adopt an approved target profile.

## Security and Trust Boundaries

- Capability/Registry data and project context that select required checks are
  policy inputs and remain protected by existing approval and ownership rules.
- Provider credentials remain references managed by provider integration;
  they MUST NOT be copied into Core artifacts or evidence reports.
- External design/provider uploads remain egress boundaries with explicit
  consent and destination recorded according to existing policy.
- Read-only MCP interfaces remain read-only; adding cloud write paths is out of
  scope.

## Risks

- Treating this boundary specification as proof that Resolver integrations are
  complete could cause implementations to duplicate or bypass Foundation
  behavior. Each consumer's actual adoption state must be re-verified before
  implementation.
- Moving checks before confirming every consumer could weaken legacy gates;
  versioned additive rollout and compatibility evidence mitigate this.
- Extracting UI operations may accidentally alter consent/fallback behavior;
  ACs explicitly preserve those behaviors.
- A target abstraction that contains provider names or execution stages would
  collapse ownership boundaries; review must inspect schemas and data flow.
