# Design: Bootstrap Interviewer Enhancement

Impl-Review-Status: Passed
Feature Type: cli

## Technical Summary

Add four layer templates and one optional visualization reference to the
interviewer, replace the monolithic design-template plan sections with a
cross-layer index, extend traceability and the bilingual question bank, and
provide explicit selected-feature validation in both structure-check runtimes.
Existing repository-only preflight and LITE behavior remain unchanged.

## Architecture

The interviewer remains the orchestration source of truth. Core documents
summarize cross-layer decisions; layer documents hold implementation detail.
The checker has two modes:

1. Repository mode: current required directories/files only.
2. Selected-feature mode: repository checks plus the nine full-profile spec
   artifacts for one validated feature slug.

Feature mode is explicit so legacy and LITE specs remain valid.

## Components

| Component | Responsibility | Technology | New/Existing |
|---|---|---|---|
| Interviewer skill | Orchestrate layer interviews and artifact generation | Markdown skill | Existing |
| Layer templates | Capture UX/frontend/infra/security implementation detail | Markdown/Mermaid | New |
| Question bank | Supply bilingual, layer-specific probes | Markdown | Existing |
| Claude Design guide | Document optional manual visual workflow | Markdown | New |
| Core templates | Index layers and extend traceability | Markdown | Existing |
| Structure checker | Validate repository or selected feature | POSIX shell/PowerShell | Existing |
| Script tests | Prove parity, compatibility, and content contracts | PowerShell/Bash | Existing |
| Review-loop prechecks | Hash-bind layer inputs and enforce traceability coverage | POSIX shell/Python/Markdown | Existing |
| Release metadata | Publish the additive sdd-bootstrap capability | JSON/Markdown | Existing |

## Architecture Decision Records

No new repository-wide ADR is required. The change is additive within an
existing plugin and does not alter review-gate ownership or the two-command
workflow.

## Layer Artifact Model

| Layer | Template | Phase 1 Output | Primary Contents |
|---|---|---|---|
| UX | `templates/ux-spec.template.md` | `ux-spec.md` | flows, states, accessibility, responsive design |
| Frontend | `templates/frontend-spec.template.md` | `frontend-spec.md` | components, state, routes, API client, typed contracts |
| Infrastructure | `templates/infra-spec.template.md` | `infra-spec.md` | topology, CI/CD, IaC, SLOs, operations |
| Security | `templates/security-spec.template.md` | `security-spec.md` | boundaries, STRIDE, auth, classification, OWASP |

Layer artifacts reference existing REQ-NNN and AC-NNN identifiers; no new ID
namespace is introduced.

## Cross-Layer Dependencies

| From | To | Contract |
|---|---|---|
| requirements.md | all layer specs | REQ-NNN scope and constraints |
| ux-spec.md | frontend-spec.md | component states, routes, accessibility |
| frontend-spec.md | contracts/ | typed request/response and entity shapes |
| security-spec.md | frontend/infra specs | auth, secrets, classification controls |
| infra-spec.md | acceptance-tests.md | SLO and operational acceptance targets |
| all layer specs | traceability.md | section anchor per applicable requirement |

## Structure Checker Interface

POSIX:

```text
check-sdd-structure.sh [project-root] [feature]
```

PowerShell:

```text
check-sdd-structure.ps1 [-Root <project-root>] [-Feature <slug>]
```

When `feature`/`-Feature` is omitted, behavior is byte-for-byte compatible where
practical and semantically compatible in all diagnostics and exits. When
present, the checker validates the feature slug and requires:

- `requirements.md`
- `design.md`
- `ux-spec.md`
- `frontend-spec.md`
- `infra-spec.md`
- `security-spec.md`
- `acceptance-tests.md`
- `tasks.md`
- `traceability.md`

The interviewer may validate Phase 1 with a phase-appropriate helper or after
Phase 2 with the complete set; the final selected-feature check requires all
nine artifacts. Tests cover missing files individually and complete fixtures.

## Existing Artifact Policy

Generation is create-only for layer files. Existing files are read and retained.
For bugfix/refactor modes, affected layers are updated through the normal
reviewed edit flow; unaffected layers state `N/A — no change` with rationale.
Security impact is always assessed.

## Claude Design Integration

The reference is optional and manual. It documents how a maintainer may use a
PNG mockup or other visual input to refine `ux-spec.md`, generate component
scaffolding suggestions, or prepare an HTML preview. Mermaid remains the
canonical text diagram format. The guide explicitly disclaims direct Figma API
access, bidirectional sync, and automatic image analysis.

## Review-Loop Compatibility

The existing sequence remains:

`Phase 1 → spec review → implementation-policy review → Phase 2 → task review`

Review input manifests and deterministic prechecks must accept the canonical
layer artifacts as follows:

- Specification review remains scoped to `requirements.md` and
  `acceptance-tests.md`.
- Implementation-policy review binds and reviews `requirements.md`,
  `acceptance-tests.md`, `design.md`, and all four layer specs.
- Task review binds those same Phase 1 artifacts plus `tasks.md` and
  `traceability.md`, and rejects any applicable requirement with a blank Layer
  Spec reference. Each Layer Spec cell must contain one or more canonical
  `<layer>-spec.md#<section>` anchors, or exactly
  `N/A — cross-layer only: <reason>` for a requirement with no layer owner.
  Blank cells, bare `N/A`, malformed anchors, and empty reasons are rejected.

Each extended precheck rejects missing inputs, non-canonical paths, and content
whose SHA-256 differs from the allowed-input manifest. No new review stage is
added and no Passed status may be written without the existing validated
verdict.

After task review passes, tasks remain Draft. The existing human approval or
active signed `sdd-sudo` transition selects Approved tasks; `implement-task`
continues to reject Draft tasks.

## API / Contract Plan

No product API changes. The checker command line gains only an optional,
backward-compatible selected-feature argument. Template TypeScript interfaces
are illustrative typed contract stubs and must use named fields and concrete
types rather than TODO-only bodies.

No endpoint, RPC, or event is added, deprecated, or breaking-changed. The
checker CLI is the only changed public contract and its exact POSIX and
PowerShell request/exit behavior is defined in Structure Checker Interface.

## Data Plan

Data Entities: no database entities. Modified document schemas are the review
input manifest entry (`path`, `sha256`), traceability row (`requirement`,
`layerSpec`), and selected-feature inventory.

Existing Data Affected: existing Markdown templates, review evidence manifests,
plugin/catalog version metadata, and shell/PowerShell validation fixtures.

Migration Strategy: no database migration is required. Existing documents stay
valid in repository mode; new full-profile feature documents opt into the
expanded templates and review manifests.

## Review-Gate Bootstrap

This feature's own implementation-policy review runs under the currently
released three-artifact precheck contract. The four layer documents below are
still normative Phase 1 inputs and are reviewed through this cross-layer
design. After implementation, the extended prechecks hash-bind them directly;
regression tests prove that transition before release.

## Test Strategy

- Unit/static scope: validate each template heading, manifest builder, slug
  validator, and traceability value; no external service is mocked.
- Integration scope: run checker and review prechecks against complete,
  missing, path-substituted, and tampered fixture repositories.
- Acceptance scope: map TEST-001 through TEST-019 to AC-001 through AC-016 and
  retain their command output in the repository test run.
- Extend existing structure-check fixtures in `tests/scripts.tests.ps1` for
  project-mode regression, complete feature mode, every missing layer file,
  invalid slugs, and Bash/PowerShell parity where both runtimes are available.
- Add static assertions for all new templates, the question bank, core
  templates, interviewer instructions, Claude Design guide, and release
  metadata.
- Extend implementation-policy and task-review fixtures to prove canonical
  four-layer manifest binding, missing/path-substituted/tampered input
  rejection, Layer Spec traceability enforcement, and preservation of the
  Draft approval boundary.
- Run scoped structure/repository suites first, then the complete repository
  suite.
- Keep the three pre-existing unrelated working-tree changes outside this
  feature's commit.

## Security Boundaries

| Trust Boundary | Auth/Authz Mechanism | Data Classification | OWASP Concerns |
|---|---|---|---|
| Feature selector to filesystem | Strict slug validation and root-relative join | Repository metadata | Path traversal |
| Optional visual input to documentation workflow | Explicit human action; no automatic upload | Potentially confidential mockups | Sensitive-data disclosure |

## Deployment / CI Plan

No runtime deployment. Repository validation and CI consume the updated tests
and synchronized sdd-bootstrap manifest/catalog versions.

## Constraint Compliance

| Requirement Constraint | Design Response |
|---|---|
| Preserve LITE | Layer generation and feature validation are explicitly full-profile only. |
| Preserve legacy specs | Repository preflight does not scan all spec directories for layer files. |
| Safe feature selector | Enforce `^[a-z0-9][a-z0-9-]*$`; invalid values emit exactly `invalid feature: <value>`, exit 1, and perform no access outside `specs/`. |
| Bash/PowerShell parity | One shared fixture corpus and semantically identical diagnostics. |
| No direct design integration | Documentation-only optional guide with limitations. |
| Existing review order | No gate bypass or new state transition. |
| Preserve user changes | Commit only feature-specific files and hunks. |

## Assumptions

None. The paired-script fixture location and synchronized `1.4.0` release
policy are repository-backed design inputs recorded in requirements.md under
Validated Baseline And Decisions.

## Open Questions

None.

## Risks

- Static template checks can become brittle; assert structural contracts rather
  than full prose.
- Optional feature-mode positional arguments can be ambiguous; PowerShell uses
  a named parameter and POSIX accepts the feature only as the second argument.
- Additional review inputs could widen trust boundaries; manifests must remain
  canonical and hash-bound.
