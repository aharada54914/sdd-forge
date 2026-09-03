# Requirements: epic-197-a9-dogfood

Spec-Review-Status: Pending
Human-Spec-Approval: Pending
Source: full local Issue #197 body (`issue-197-full-body.md:8-37`), parent
tracking Issue #187 (`issue-187-tracking.md:14-27`), and decision document
§§17 and 19

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
`docs/adr/0019-approval-sidecar-protection.md:32-69`;
`issue-197-full-body.md:14-15`).

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

A9 shall implement the developer-tooling / cli-library Pack as the first Pack
implementation and shall not define desktop, cloud-service, or durable-workflow
Packs. This selection and priority are fixed by Issue #197 and recorded as the
resolution of OQ-005. The human-approved OQ-006 decision shall fix the Pack's
Registry capability IDs, predicates, facets, review checks, implementation gates,
Lite policy, minimum enforcement, and delivery strategy before code is authored
(`issue-197-full-body.md:17`; `docs/ai-dlc-foundation-decision-v2.md:488-492`;
`contracts/capability-registry.json:1-43`).

### REQ-006 — Advisory dogfood evidence

Phase 1 shall run the merged A1–A8 Context/ownership/Resolver/Manifest,
compatibility, and cross-runtime mechanisms against sdd-forge changes. Every
sdd-forge PR in one complete, explicitly bounded release cycle shall pass the
capability-mode Gate in advisory mode. Advisory diagnostics shall be recorded
without blocking delivery solely because a new Pack finding exists; existing
independent gates remain unchanged (`issue-197-full-body.md:27`).

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
available (`issue-197-full-body.md:16`). After promotion, at least one real
feature shall complete the full SDD workflow end-to-end under `facet-hybrid`
with required capability enforcement (`issue-197-full-body.md:28`).

### REQ-009 — Policy-weakening rollback

A required-to-advisory rollback shall follow the human-approved OQ-004 procedure
and ADR-0019: two distinct approvals when at least two real identities are
registered, otherwise a first approval plus an HMAC-bound 24-hour cooldown. Early,
unsigned, self-approved, or identity-duplicated application shall fail
(`docs/adr/0019-approval-sidecar-protection.md:49-94`).
The two policy branches are field-test requirements of this epic, not optional
test variants (`issue-197-full-body.md:22`).

### REQ-010 — Operational-friction capture

During dogfood, reproducible path-ownership, staleness, and approval-flow friction
shall be recorded as new Draft WFI records in `docs/workflow-improvements/`, with
evidence, why-why analysis, controllable root-cause hypothesis, proposed change,
and expected effect. The dogfood cycle shall always persist a friction result; if
no friction occurs, it shall explicitly record `none` rather than fabricate a WFI.
Agents shall not approve WFI records (`issue-197-full-body.md:18,29`;
`docs/workflow-improvements/WFI-045.md:1-31`; `README.md:257-259`).

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

### REQ-013 — A3 cross-cutting bootstrap prerequisite

When the live Context is bootstrapped, growing paths such as `specs/` shall
already be registered as cross-cutting through the A3 ownership contract. A9
shall verify this prerequisite rather than silently broadening ownership after
dogfood begins (`issue-197-full-body.md:23`).

### REQ-014 — Epic dependency and parent provenance

A9 work shall remain blocked until all Epic A1-A8 dependencies are merged and
usable, and its provenance shall identify Issue #197 as the A9 child of tracking
Issue #187. This is the final epic in #187's stated A0-A9 ordering
(`issue-197-full-body.md:31-37`; `issue-187-tracking.md:14-27`).

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
| AC-025 | REQ-013 | Bootstrap/ownership validation proves every approved growing path, including `specs/`, is covered by an A3 cross-cutting rule from Context bootstrap time. |
| AC-026 | REQ-014 | A dependency/provenance check blocks unless all A1-A8 surfaces are usable and records Issue #197 under parent #187. |
| AC-027 | REQ-006 | Release-cycle evidence identifies explicit start/end releases and proves every PR in that complete cycle passed the advisory capability-mode Gate. |
| AC-028 | REQ-008 | After required promotion, saved evidence proves at least one real feature completed the full workflow end-to-end under `facet-hybrid`. |
| AC-029 | REQ-010 | The dogfood cycle records WFI references for observed friction or the literal result `none` when zero, covering path ownership, staleness, and approval flow. |

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

1. Human resolves OQ-001–OQ-004 and OQ-006 and approves the reviewed spec/tasks;
   OQ-005 is already resolved by Issue #197.
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
- No friction is observed: record the dogfood-cycle friction result as `none`;
  never fabricate a WFI.

## Security Boundaries

- Project Context and provider approval sidecars are protected, HMAC-bound human
  records (`docs/adr/0019-approval-sidecar-protection.md:32-82`).
- Release publication has write/OIDC/attestation permissions and remains outside
  the read-only MCP claim (`.github/workflows/release.yml:26-50`).
- CI-MCP reads a token but must not persist or disclose it (`README.md:132-144`).

## Assumptions

- The full local Issue #197 and #187 bodies were read and reconciled on
  2026-09-01; `investigation.md` records the discharged limitation and changes.
- A1–A8 availability is mutable shared state and must be re-verified at spec
  review and implementation, never assumed from this draft.
- The Issue #197 assumption that `specs/`-type growing paths are cross-cutting at
  bootstrap is verified by REQ-013/AC-025, not accepted without evidence.
- The next WFI number is not reserved here; allocate it at record-creation time.

## Open Questions

### OQ-001 — Component decomposition — Resolved

Which stable components should represent sdd-forge: per-package, capability-group,
or hybrid? Human ruling must include IDs and rationale.

Resolution (2026-09-02, human approval verbatim: 「OQ 推奨案で全て承認する
実装せよ」): **hybrid — eight components**: one per plugin
(`sdd-bootstrap`, `sdd-review-loop`, `sdd-implementation`,
`sdd-quality-loop`, `sdd-ship`, `sdd-lite`), plus `mcp` (the MCP service
group under `mcp/`) and `installer` (`install.sh`/`install.ps1`/
`uninstall.sh`/`uninstall.ps1`/`scripts/bump-version.sh`). Rationale: the
guard, gates, and test suites are already organized per plugin, and the
measured defect class this decision guards against — concurrent epics
overwriting shared plugin files — occurs exactly at the plugin boundary;
per-package is finer than any enforcement surface, and capability-group is
too coarse to detect cross-plugin drift.

### OQ-002 — Path ownership map — Resolved

Which include/exclude patterns belong to each component, and which repository
paths are component-shared versus cross-cutting? Human ruling must address
plugins, MCP services, root installers, contracts, scripts, tests, docs, specs,
reports, marketplaces, CI, release, and root metadata. Issue #197 already fixes
one constraint: `specs/`-type growing paths must be cross-cutting at bootstrap
(`issue-197-full-body.md:23`); the human ruling may not reverse that constraint.

Resolution (2026-09-02, same human approval): **component-owned**:
`plugins/<name>/**` → its plugin component; `mcp/**` → `mcp`;
`install.sh`/`install.ps1`/`uninstall.sh`/`uninstall.ps1`/
`scripts/bump-version.sh` → `installer`. **Cross-cutting (shared)**:
`specs/**` (fixed by issue #197, not reversible), `tests/**` (suites span
plugins — measured: epic-195 T-010 re-pointed suites belonging to five
different tasks), `contracts/**`, `docs/**`, `reports/**`,
`marketplaces/**`, `.github/**` (protected, human-copy staged),
release/root metadata (`CHANGELOG.md`, `AGENTS.md`, `README.md`,
`package.json`). Rationale: this session's principal measured frictions —
amendment propagation across shared files and stale review provenance —
all arose from ownership ambiguity on exactly these shared paths.

### OQ-003 — Phase-2 promotion criteria — Resolved

Issue #197 fixes the minimum duration/sample boundary as every PR over one full
release cycle (`issue-197-full-body.md:27`). Beyond that fixed minimum, what
false-positive threshold, unresolved-finding threshold, platform coverage,
compatibility evidence, and rollback rehearsal are mandatory before
`facet-hybrid`/`required`?

Resolution (2026-09-02, same human approval): beyond the fixed
one-release-cycle minimum, promotion to `facet-hybrid`/`required` requires
all four, measured mechanically: (1) **every guard/gate false positive
observed during the advisory period is triaged into a WFI — zero
untriaged** (grounded in this session's measurement that false positives
were the dominant operational friction); (2) zero unresolved
Critical/Major findings; (3) all three OS CI lanes green (platform
coverage); (4) one successful rollback rehearsal executing the OQ-004
procedure end-to-end. Rationale: converts the Risks-section warning about
premature `required` promotion into a machine-checkable precondition.

### OQ-004 — Conditional rollback procedure — Resolved

Issue #197 fixes that the transition is policy weakening and that a solo
maintainer may execute it with first approval plus a 24-hour cooldown
(`issue-197-full-body.md:22`). What exact operator steps and persisted evidence
select the two-party or fixed solo-maintainer branch, handle approver-registry
changes, and authorize the human-copy application of required-to-advisory rollback?

Resolution (2026-09-02, same human approval): the branch is selected
**mechanically by approver-registry cardinality** at execution time:
registry count ≥ 2 → two-party approval; count == 1 → solo-maintainer
branch (first approval + 24-hour cooldown). A registry-membership change
is itself a recorded registry update and re-evaluates the branch. The
persisted evidence is a **signed rollback record reusing the Ed25519
live-host-proof machinery epic-196 T-005 already implemented and
verified** (JCS canonicalization + domain-separated signatures +
trusted-signer registry), applied via the established human-copy staging
route. Rationale: reuses tested machinery instead of inventing a bespoke
approval path, and answers the Risks-section requirement to model registry
cardinality and time-bound approval explicitly.

### OQ-005 — First Pack selection and priority — Resolved

Resolution (2026-09-01): implement the developer-tooling / cli-library Pack as
the first Pack implementation. Issue #197 states this explicitly at
`issue-197-full-body.md:17`. No human decision remains on selection or order.

### OQ-006 — First Pack internal contract — Resolved

Is the selected developer-tooling / cli-library Pack encoded as one capability,
two capabilities, or a composed Pack, and which predicates, facets, review checks,
gates, Lite policy, minimum enforcement, and delivery strategy are normative?
Issue #197 does not answer these internal-contract questions; a dated human ruling
is required.

Resolution (2026-09-02, human approval verbatim: 「OQ 推奨案で全て承認する
実装せよ」): a **composed Pack of two capabilities** —
`developer-tooling` and `cli-library` as separate capabilities, the Pack
defined as their composition. Predicates and facets **reference and
compose the existing Epic A2 capability-registry entries**
(`specs/epic-190-a2-capability-registry`) rather than defining duplicates.
Minimum enforcement: `advisory`. Lite policy: the lite track is admissible
for docs-only changes; everything else takes the full track. Delivery:
via the established human-copy staging route. Rationale: composition by
reference structurally avoids the Risks-section duplicate-registry-entry
failure, and keeping the two capabilities separate preserves
decomposability when later Packs arrive.

## Risks

- Over-broad ownership may make coverage green by hiding meaningful boundaries.
- Required enforcement may create release deadlocks if promoted on insufficient
  samples.
- Pack semantics may duplicate rather than compose existing Registry entries.
- Rollback governance may be unusable if it does not explicitly model registry
  cardinality and time-bound approval.

## Transferred Backlog — approval-attestation primitive (from WFI-047)

Owner ruling, recorded verbatim (2026-09-03):
「47についてはA9 dogfoodに追記してクローズで良い」

WFI-047 (Approved 2026-09-02, closed by transfer into this epic) proposed a
durable, statement-scoped human approval attestation: a small signed record
(statement text, date, scope) using the same out-of-repo key machinery the
sudo token already uses, verifiable by review prechecks, replacing the
prose-based Amendment Re-Review Context evidence and eventually the impl
stage's `legacy_design` relaxation. Its own Implementation Disposition
already named this epic as the natural first advisory-mode candidate.

Standing in this epic: a **future work item carried by the dogfood lane, not
part of this epic's REQ/AC set**. It shall be treated as a candidate advisory
finding during Phase 1 dogfood (the friction it addresses — unverifiable
prose approval claims — is precisely the class REQ-010 captures), and its
implementation, if promoted, is its own SDD feature cycle whose spec inherits
WFI-047's recorded human approval as authorization. The open design contract
WFI-047's Result enumerates (record path, schema/version, signing payload
canonicalization, algorithm/encoding, scope-matching grammar, key rotation,
issuance command, `legacy_design` migration) remains human-authored input to
that future cycle.
