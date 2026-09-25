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

**A9 classification oracle (draft policy, 2026-09-26).** The approved nine IDs
and ownership in the 2026-09-08 OQ-001 amendment remain unchanged. The labels
below are proposed A9 values, not schema enums. Product-level evidence names
developer tooling / CLI / plugin package, GitHub Release / multi-runtime
installation, Windows/macOS/Linux, and Claude/Codex/Copilot
(`docs/ai-dlc-foundation-decision-v2.md:483-492`); README documents the
component boundaries and behaviors (`README.md:108-175`).

| Approved ID | artifact_kinds | runtime_classes | distribution_channels | data_classification | paths |
|---|---|---|---|---|---|
| `sdd-bootstrap` | `[plugin_package]` | `[host_cli_plugin]` | `[github_release, multi_runtime_plugin_install]` | `[repository_content]` | OQ-002 plugin rule |
| `sdd-review-loop` | `[plugin_package]` | `[host_cli_plugin]` | `[github_release, multi_runtime_plugin_install]` | `[repository_content, workflow_evidence]` | OQ-002 plugin rule |
| `sdd-implementation` | `[plugin_package]` | `[host_cli_plugin]` | `[github_release, multi_runtime_plugin_install]` | `[repository_content, workflow_evidence]` | OQ-002 plugin rule |
| `sdd-quality-loop` | `[plugin_package]` | `[host_cli_plugin]` | `[github_release, multi_runtime_plugin_install]` | `[repository_content, workflow_evidence, credential_material]` | OQ-002 plugin rule |
| `sdd-ship` | `[plugin_package]` | `[host_cli_plugin]` | `[github_release, multi_runtime_plugin_install]` | `[repository_content, workflow_evidence]` | OQ-002 plugin rule |
| `sdd-lite` | `[plugin_package]` | `[host_cli_plugin]` | `[github_release, multi_runtime_plugin_install]` | `[repository_content, workflow_evidence]` | OQ-002 plugin rule |
| `sdd-domain` | `[plugin_package]` | `[host_cli_plugin]` | `[github_release, multi_runtime_plugin_install]` | `[repository_content, workflow_evidence]` | `plugins/sdd-domain/**` only |
| `mcp` | `[mcp_server]` | `[local_mcp_server]` | `[github_release, multi_runtime_plugin_install]` | `[repository_content, host_metadata, ci_metadata, credential_material]` | `mcp/**` |
| `installer` | `[installer_script]` | `[shell_installer]` | `[github_release]` | `[repository_content, host_configuration]` | OQ-002 installer paths |

Data labels identify kinds of material read, written, or processed: `repository_content`
is source/spec/task files; `workflow_evidence` is review, implementation, and
quality-gate records; `host_metadata` is OS/toolchain facts; `ci_metadata` is
CI runs, jobs, logs, and artifact metadata; `credential_material` is a
credential consumed by a component (not a claim it emits one); and
`host_configuration` is client/plugin/MCP registration configuration. This
classification does **not** assert absence of PII or credentials in repository
content, logs, or any data. The labels are proposed A9 policy grounded in
`README.md:108-175` and plugin package surfaces, not pre-existing schema enums.
The `sdd-quality-loop` credential label is specifically grounded in its
evidence-bundle signer reading a configured signing key and producing an
HMAC-SHA256 signature (`plugins/sdd-quality-loop/scripts/generate-evidence-bundle.sh:418-425`);
the `mcp` credential label is grounded in `ci-mcp`'s required read-only GitHub
token (`README.md:140-150`).

For all nine rows omit `platform_targets`: the product decision is not a
per-component support matrix and the schema requires both OS and architecture
(`docs/ai-dlc-foundation-decision-v2.md:483-489`;
`contracts/project-context.schema.json:31-40`). Omit `characteristics`
rather than infer booleans: the exact schema keys are `pii`, `ui`,
`auto_update`, `local_persistence`, `long_running`, `replayable`, and
`human_in_the_loop` (`contracts/project-context.schema.json:41-53`); omission
does not mean false, especially for `pii`. Omit `provider_binding_ids` because
ADR-0018 separates binding records from Context and no approved A9 binding IDs
are supplied (`docs/adr/0018-provider-binding-separation.md:49-78`). For
`paths`, use only exact OQ-002 rules; do not broaden ownership. These optional
field omissions are not claims of “none” or “no sensitive data.”

### REQ-003 — Complete path ownership

The Context shall encode the human-approved OQ-002 include/exclude/shared map and
shall pass overlap, unowned-path, reverse-coverage, and ownership-digest checks
supplied by A3. Shared classifications shall use the schema's component-list or
cross-cutting form (`contracts/project-context.schema.json:67-76`;
`docs/ai-dlc-foundation-decision-v2.md:529-530`).

### REQ-004 — Repository characteristics

The component inventory shall preserve meaningful differences between plugin,
MCP, installer, CI, and release surfaces. In particular, credential-bearing CI
MCP and release publication shall not inherit a blanket "no credentials/no
write" characteristic from the read-only local services (`README.md:108-150`;
`.github/workflows/release.yml:26-50`).

Because the approved OQ-001 decomposition keeps all MCP services in one `mcp`
component and OQ-002 places release automation under a cross-cutting rule,
component-level booleans alone cannot express these two distinctions. Per the
owner ruling of 2026-09-04 (recorded under OQ-001), the Context schema's
component records shall accept an additive, optional list of scoped
characteristic-override entries.

**Valid override characteristic namespace.** The seven base schema keys are
`pii`, `ui`, `auto_update`, `local_persistence`, `long_running`, `replayable`,
and `human_in_the_loop`; they remain unchanged by this extension
(`contracts/project-context.schema.json:41-53`). The only
additional machine names introduced for use inside `characteristic_overrides`
entries are `credential_bearing` (human label: "credential-bearing") and
`release_write` (human label: "release-write"). Any name other than these two
is unknown and shall be rejected by validation; no further override-only names
are introduced by this epic.

**Additive schema boundary.** The optional `characteristic_overrides` list is
permitted only on two record types: (1) component records, and (2) approved
shared-path (cross-cutting) rules. No other schema record types, and no
additional top-level or nested fields beyond `characteristic_overrides`, are
introduced by this extension. Each entry in the list must contain exactly four
fields: `scope` (a sub-service path prefix inside the owning component, or the
name of an approved cross-cutting rule), `characteristic` (one of the two
override-only machine names above), `value` (a boolean), and `rationale` (a
non-empty one-line string). Entries with any missing or extra field, any
unrecognised `characteristic` name, a `scope` not covered by the owning
component's include set or the referenced cross-cutting rule, or a `value`
equal to the record's baseline for that override characteristic (a no-op
override) shall be rejected. **Override-only baseline rule (proposed A9
policy, 2026-09-26):** for resolving these two override-only characteristics,
an absent value on the owning record is baseline `false`; a `false` override
is therefore a no-op and rejects. This applies only to override resolution;
it is not a security assertion or classification of any other path, component,
or schema characteristic.

The OQ-002 cross-cutting rule for `.github/**` is the release-automation
override owner; its canonical `scope` value is exactly `.github/**`. The
release-write classification is exercised against the tracked release workflow
`.github/workflows/release.yml`. This uses the already-approved OQ-002 pattern;
it creates no third ownership rule or new paths.

The live Context shall carry exactly two such overrides in Phase 1: `mcp/ci-mcp`
with `characteristic: credential_bearing` and `value: true` on the `mcp`
component record, and the `.github/**` cross-cutting rule with
`characteristic: release_write` and `value: true`. Characteristic tests
(AC-007) shall read overrides when distinguishing the CI-MCP credential and
release-write cases. The extension is additive: a Context with no overrides
remains valid, and existing consumers that ignore the field keep their
behavior.

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

A required-to-advisory rollback shall follow the human-approved OQ-004
procedure: two distinct approvals when at least two real identities are
registered, otherwise first approval plus a 24-hour cooldown represented by
the signed `effective_at` boundary; re-evaluate current registry membership
at application. The persisted rollback record
uses OQ-004's Ed25519 live-host-proof machinery (JCS, domain-separated
signatures, trusted-signer registry); the approval sidecar separately remains
under ADR-0019's external-key HMAC protection. Neither substitutes for the
other (`docs/adr/0019-approval-sidecar-protection.md:49-94`;
`docs/adr/0028-live-host-proof-ed25519-signing.md:56-98`). Early, unsigned,
self-approved, or identity-duplicated application shall fail.
The two policy branches are field-test requirements of this epic, not optional
test variants (`issue-197-full-body.md:22`).

**Zero-identity fail-closed clarification (2026-09-26):** OQ-004's historical
resolution defines count ≥2 and count ==1. If the trusted approver registry
contains zero real registered identities at request or application time,
rollback rejects without issuing a request or applying a record. Neither the
solo approval nor signature verification can be grounded to an authorized
identity in that state. This fail-closed case adds no approval branch and
preserves the signed-record and current-registry requirements.

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
| AC-003 | REQ-002 | A fixture asserts all nine approved IDs, supported classifications, explicitly omitted optional fields, and OQ-002 paths against the OQ-001 decision and the dated A9 classification oracle. |
| AC-004 | REQ-002 | Separate fixtures reject omission of each of the nine required IDs, an extra ID, an unjustified empty classification, and each incorrect classification field (TEST-003c–i). |
| AC-005 | REQ-003 | Ownership validation reports zero unexplained overlaps for the approved map and blocks Phase-1 publication when a tracked path newly matches multiple components without an approved shared rule. |
| AC-006 | REQ-003 | Ownership validation reports zero unexplained unowned tracked paths, verifies every approved shared-path rule, and blocks Phase-1 publication when a tracked path matches neither a component nor a shared rule. |
| AC-007 | REQ-004 | Characteristic tests distinguish plugin/MCP/installer/CI/release boundaries, including the CI-MCP credential and release-write cases. |
| AC-008 | REQ-005 | Registry validation accepts the human-approved first Pack and resolves it for the representative change defined below (full-track plugin code, never docs-only). |
| AC-009 | REQ-005 | Registry validation proves desktop, cloud-service, and new durable-workflow Pack entries were not added by A9. |
| AC-010 | REQ-006 | An advisory run emits Manifest/Summary/Projection/evidence with bound revision and digests for the representative change defined below (full-track plugin code, never docs-only). |
| AC-011 | REQ-006 | An advisory Pack finding is visible and non-blocking while pre-existing blocking gates retain their behavior. |
| AC-012 | REQ-007 | The promotion record contains every evidence field named in REQ-007 and links each criterion to saved evidence. |
| AC-013 | REQ-007 | Promotion is rejected when one human-approved OQ-003 threshold is unmet or evidence is stale. |
| AC-014 | REQ-008 | Schema/resolver tests accept the atomic Phase-2 tuple `full` / `facet-hybrid` / `required`. |
| AC-015 | REQ-008 | Tests reject each partial promotion: layout-only and enforcement-only. |
| AC-016 | REQ-009 | A two-or-more-identity fixture requires two distinct valid approvals for required-to-advisory rollback. |
| AC-017 | REQ-009 | For the solo branch, `effective_at` is the HMAC-authorized first-approval time plus 24 hours: TEST-017a rejects one second before that signed boundary, TEST-017b accepts exactly at it, and TEST-017c accepts one second after it, all with valid signed rollback evidence. |
| AC-018 | REQ-009 | TEST-018a/b revalidate a changed registry; TEST-018c/c2 reject zero identities at request/application; TEST-018d–g separately reject unsigned, unbound, self-approved, and duplicate-identity approval sidecars; TEST-018h/i reject invalid/untrusted Ed25519-signed rollback records. |
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
| AC-030 | REQ-004 | The live Context carries exactly two `characteristic_overrides` entries and no others: (a) on `mcp`, `scope: mcp/ci-mcp`, `characteristic: credential_bearing`, `value: true`; (b) on the OQ-002 `.github/**` cross-cutting rule, `scope: .github/**`, `characteristic: release_write`, `value: true`, exercised against `.github/workflows/release.yml`. Any other count, scope, characteristic, or value rejects. |
| AC-031 | REQ-004 | Override validation rejects unknown names and out-of-scope entries; rejects `value: false` as a no-op for each absent override-only baseline; rejects each missing/extra entry field (TEST-031e–i) and each placement on a record type other than component or cross-cutting rule (TEST-031j–k). |
| AC-032 | REQ-003 | Ownership validation verifies that every component include set matches tracked paths and that the recomputed ownership digest matches the recorded digest; an empty include match or mismatched digest each blocks publication. |
| AC-033 | REQ-008 | Required-enforcement activation rejects when the selected Pack evidence is missing, resolver evidence is missing, or both are missing. |
| AC-034 | REQ-009 | A registry-cardinality change between rollback request and effective time forces branch re-evaluation with the current registry (a solo cooldown in progress becomes two-party when a second identity is registered). |

Reconciliation (2026-09-17): AC-030/031/034 are now included alongside
AC-032/033 from the previous remediation candidate
`4349ae407aa7dffc5baf0b6595084c7c6e0e514b`. The characteristic-override
contract is normative in REQ-004 and remains additive; AC-034 retains the
registry-cardinality edge case in a dedicated row. None of these edits
retroactively changes a review verdict or authorizes implementation of Draft
tasks.

## Field Definitions

| Field | Meaning |
|---|---|
| Phase 1 | Approved live Context using `full`/`legacy-seven-layer`/`advisory`. |
| Phase 2 | Approved live Context using `full`/`facet-hybrid`/`required`. |
| Pack | Human-approved Registry capability set for developer-tooling / cli-library. |
| Promotion record | Saved, reviewable decision evidence for moving Phase 1 to Phase 2. |
| Rollback | Policy-weakening `required` to `advisory` transition. |
| Representative change | A plugin-code change touching at least one owned plugin component in the approved nine-component inventory, never a docs-only change. Under OQ-006 it takes the full track and exercises the selected Pack's predicate/facet/gate machinery. |
| Characteristic override | An additive, scoped entry permitted only on component records or approved shared-path (cross-cutting) rules, setting one of the two override-only characteristics (`credential_bearing` or `release_write`) to a boolean value for a named sub-scope, with rationale (REQ-004). Any other characteristic name is unknown and rejected. |

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

Historical resolution (2026-09-02; component count superseded below, human approval verbatim: 「OQ 推奨案で全て承認する
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

Amendment (2026-09-08, human approval verbatim):
「A9 を進めるため、plugins/domain/** を独立した「9番目のコンポーネント」として扱う設計変更を承認」
The binding inventory is now nine components: `sdd-bootstrap`,
`sdd-review-loop`, `sdd-implementation`, `sdd-quality-loop`, `sdd-ship`,
`sdd-lite`, `sdd-domain`, `mcp`, and `installer`. The ninth component owns
`plugins/sdd-domain/**`, independently of the other eight; it is neither
folded into another component nor classified as cross-cutting.
The approval prompt and prior reviewer used `plugins/domain/**` as a spelling
for the domain plugin. At base commit
`135b147926689bd3adc8c834932a9b82b9f5a607`, `git ls-tree --name-only HEAD:plugins`
identifies `sdd-domain`; `git ls-tree -r --name-only HEAD plugins/domain`
returns no tracked paths. The canonical existing path above governs; this
decision does not create a new directory or an alias ownership rule.
Re-verify the tracked plugin inventory at review and implementation HEAD;
unexpected additions or renames require reconciliation, not an automatic
change to this closed nine-component set.
This amendment supersedes only the earlier eight-component count and the
omission of domain, not approval boundaries or the separate characteristic
override proposal. Historical review outputs remain unchanged.
The provisional-choice text in investigation.md's Component Decomposition
discussion and Open Questions is historical; this dated OQ-001 amendment and
OQ-002 govern ownership for the next review.

Characteristic amendment (2026-09-17, owner ruling retained from 2026-09-04):
the nine-component decomposition remains unchanged except for the approved
additive scoped override mechanism. The single `mcp` component may therefore
mark `mcp/ci-mcp` credential-bearing, and the approved release-automation rule
may mark release-write, without splitting components or broadening ownership.
The normative contract is REQ-004; AC-030/AC-031 define positive and negative
oracles. Historical review outputs remain unchanged and this amendment must be
re-bound by the next formal spec-review attempt.

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

OQ-001 propagation (2026-09-08): `plugins/sdd-domain/**` maps exclusively to
`sdd-domain`. All other component/shared rules above are retained.

Growing-path clarification (2026-09-08, human approval verbatim):
「固定名のルートファイルは別の共有ルールとして維持する定義でよい」
This approves the proposed distinction: "growing paths" means the seven
directory patterns `specs/**`, `tests/**`, `contracts/**`, `docs/**`,
`reports/**`, `marketplaces/**`, and `.github/**`. Each is cross-cutting from
bootstrap, including newly added tracked descendants. Fixed root metadata
`CHANGELOG.md`, `AGENTS.md`, `README.md`, and `package.json` retains separate
exact-path cross-cutting rules; it is not part of the growing-path set.
This does not authorize a catch-all root rule or move installer-owned root
scripts into shared ownership. An unlisted new root file still requires
ownership reconciliation under REQ-003. This clarification supersedes earlier
claims that the growing-path definition is unresolved, including historical
investigation/review discussion; original review evidence remains unchanged.

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

**Dated factual clarification and precedence (2026-09-26; no change to human
approval):** the immediately preceding 2026-09-02 resolution preserves its
verbatim approval/history. Its phrase “existing Epic A2 capability-registry
entries” was inaccurate as a current-tree statement: the current Registry
contains only `durable-workflow`, and A2 assigns fragment selection to A5
(`contracts/capability-registry.json:1-67`;
`specs/epic-190-a2-capability-registry/requirements.md:311-318`). A9 shall add
the two approved IDs using A2's existing Registry schema and A5's existing
capability-ID fragment-selection mechanism for Resolver composition; the
schema defines capability and gate records but no Pack record
(`contracts/capability-registry.schema.json:5-19,40-76`;
`specs/epic-190-a2-capability-registry/design.md:121-128,1025-1028`). This
clarifies the implementation basis only: the human-approved IDs, composition,
predicates/facets/gates, Lite policy, enforcement minimum, and delivery remain
unchanged. Historical approval and review records are not rewritten.

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
