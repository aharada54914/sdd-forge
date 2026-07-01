# Requirements: Bootstrap Interviewer Enhancement

Spec-Review-Status: Passed

## Overview

Expand the full-profile `sdd-bootstrap-interviewer` output from three core
specification documents to an implementation-ready specification set with
dedicated UX, frontend, infrastructure, and security layer documents. Preserve
the existing LITE workflow and existing repository-level structure checks.

Source: `/Users/jrmag/Downloads/bootstrap-interviewer-enhancement.plan.md`

## Target Users

- Developers bootstrapping full-profile project, feature, bugfix, or refactor work.
- Human and AI implementers consuming reviewed SDD artifacts.
- Reviewers validating cross-layer completeness before implementation.

## Problems

- REQ-001: The current `design.md` template has shallow inline frontend,
  backend, data, security, and deployment sections that do not provide
  implementation-ready layer detail.
- REQ-002: The interviewer question bank does not systematically cover UX,
  frontend architecture, infrastructure operations, and security/compliance.
- REQ-003: Full-profile output lacks dedicated layer artifacts and explicit
  cross-layer traceability.
- REQ-004: Visualization guidance does not describe a safe, optional workflow
  for mockups, Mermaid diagrams, and HTML previews.
- REQ-005: The structure checker cannot validate the artifact set for a
  selected full-profile feature.

## Goals

- REQ-006: Phase 1 of the full-profile interviewer MUST generate
  `ux-spec.md`, `frontend-spec.md`, `infra-spec.md`, and `security-spec.md`
  from reusable templates, without overwriting an existing layer file.
- REQ-007: Each layer template MUST contain actionable structure, requirement
  and acceptance-criterion references, guided placeholders, and this complete
  mandatory content set:
  - UX: target views; a component/state/REQ/AC table; Mermaid interaction
    sequence; wireframe attachment placeholder; navigation map; WCAG 2.2 AA
    guidance; empty/loading/error states; responsive breakpoints; design
    tokens.
  - Frontend: technology stack; Mermaid component tree; state-shape plan;
    route/component/auth/parameter table; API client strategy; code-splitting
    and size budget; LCP/INP/CLS performance budget; concrete TypeScript
    interface; dependency/version/purpose/alternative table.
  - Infrastructure: Mermaid deployment topology and CI/CD sequence;
    environment/URL/auth/trigger/classification table; IaC stub; scaling;
    numeric availability and p95-latency SLOs with AC references; residency
    and retention; logs/traces/metrics; cost estimate; rollback.
  - Security: Mermaid trust boundaries and authentication flow; at least two
    STRIDE rows per boundary; authorization; entity-level data classification,
    at-rest/in-transit encryption and retention; OWASP mapping; secrets; SBOM
    and supply chain; security tests.
- REQ-008: `design.template.md` MUST become a cross-layer index containing
  summaries, dependencies, ADR history, and links to the four layer specs,
  while retaining test strategy, constraints, open questions, and risks.
- REQ-009: `traceability.template.md` MUST map each requirement to a layer spec
  section and summarize layer coverage. A requirement is layer-applicable when
  it affects behavior or a constraint owned by UX, frontend, infrastructure,
  or security as defined by REQ-007. Its Layer Spec cell MUST contain one or
  more relative anchors in the form `<layer>-spec.md#<section>`. A requirement
  with no layer owner MUST instead contain
  `N/A — cross-layer only: <reason>`. Blank cells and bare `N/A` are invalid.
- REQ-010: The question bank MUST organize the retained Japanese questions so
  that every category below contains at least one Japanese probe, add at least
  three new English layer-specific probes to every category, and include a
  layer coverage checklist. Japanese and English probes do not need to be
  translation pairs:
  1. Product and Scope
  2. Users, Roles, and UX
  3. Data and Contracts
  4. Workflow and Acceptance
  5. Frontend Architecture
  6. Backend, API, and Testing
  7. Infrastructure and Operations
  8. Security and Compliance
- REQ-011: The Claude Design reference MUST describe an optional manual
  visualization workflow, state limitations, use Mermaid as the primary
  diagram format, and provide three copy-ready prompts.
- REQ-012: The structure checker MUST retain its existing project-root
  preflight behavior and add an explicit, backward-compatible feature mode
  that fails when any required full-profile artifact is absent. POSIX feature
  mode MUST use `check-sdd-structure.sh [project-root] [feature]`; PowerShell
  feature mode MUST use
  `check-sdd-structure.ps1 [-Root <project-root>] [-Feature <feature>]`.
  Feature names MUST match `^[a-z0-9][a-z0-9-]*$`; invalid names MUST emit
  `invalid feature: <value>` and exit 1 without accessing a path outside
  `specs/`. Selected-feature validation MUST require exactly these nine files:
  `requirements.md`, `design.md`, `ux-spec.md`, `frontend-spec.md`,
  `infra-spec.md`, `security-spec.md`, `acceptance-tests.md`, `tasks.md`, and
  `traceability.md`.
- REQ-013: LITE MUST skip layer-spec generation and feature-level layer-spec
  validation.
- REQ-014: Bash and PowerShell behavior MUST remain semantically equivalent.
- REQ-015: The sdd-bootstrap release metadata and changelog MUST identify this
  additive capability using the next repository-valid version.
- REQ-016: The existing implementation-policy review MUST hash-bind and review
  `ux-spec.md`, `frontend-spec.md`, `infra-spec.md`, and `security-spec.md`
  together with its current canonical inputs. Its deterministic precheck MUST
  reject a missing, non-canonical, or changed layer input. The existing task
  review MUST consume those same hash-bound layer inputs and MUST verify that
  every applicable requirement has a nonblank Layer Spec reference in
  `traceability.md`. No new review stage is added.
- REQ-017: The workflow MUST preserve the approval boundary after task review:
  tasks remain Draft until a human changes selected tasks to Approved, or
  until an active, signed `sdd-sudo` token authorizes that same transition.
  `implement-task` MUST continue to reject Draft tasks.

## Non-goals

- Direct Figma API integration or bidirectional design synchronization.
- Automated Claude Design invocation or image analysis.
- A new review stage, standalone layer-spec review loop, or new identifier
  prefix. Existing implementation-policy and task reviews are extended.
- Changes to `sdd-ship`, quality-gate semantics, or the LITE artifact model.
- Automated Mermaid rendering.
- Adding a dedicated backend layer file beyond the existing design and
  contract artifacts.

## User Stories

- As a developer, I can bootstrap a full-profile feature and receive all
  implementation-relevant layer specs without a second clarification pass.
- As a reviewer, I can trace every requirement through the cross-layer design
  to an acceptance test.
- As a LITE user, I retain the existing shallow workflow and artifact count.
- As a maintainer, I can validate either repository structure alone or one
  selected full-profile feature without breaking existing callers.

## Acceptance Criteria

- AC-001: The four new layer templates exist and satisfy their required
  sections, guided placeholders, and diagram/contract examples.
- AC-002: The UX template maps component states to both REQ-NNN and AC-NNN and
  includes accessibility, responsive, navigation, and failure-state guidance.
- AC-003: The frontend template includes a Mermaid component tree, routing,
  state/API/bundle/performance plans, dependencies, and a typed interface with
  concrete fields and types.
- AC-004: The infrastructure template includes topology and CI/CD diagrams,
  environment/IaC/scaling/observability/cost/rollback sections, plus explicit
  availability and p95-latency SLO examples tied to acceptance criteria.
- AC-005: The security template models trust boundaries, at least two STRIDE
  rows per boundary, authentication/authorization, data classification, OWASP,
  secrets, supply chain, and security testing.
- AC-006: The question bank has eight category sections, retains at least one
  existing Japanese probe in every category, adds at least three new English
  layer-specific probes per category, and contains a layer coverage checklist.
  Japanese and English probes are not required to be translation pairs. The
  eight headings are Product and Scope; Users, Roles, and UX; Data and
  Contracts; Workflow and Acceptance; Frontend Architecture; Backend, API, and
  Testing; Infrastructure and Operations; and Security and Compliance.
- AC-007: The design template contains four relative layer links, cross-layer
  dependencies, and an ADR change log, with no legacy inline plan placeholder.
- AC-008: The traceability template contains a Layer Spec column and a layer
  coverage table. Every row contains either one or more canonical layer anchors
  or a reasoned `N/A — cross-layer only: <reason>` value; blank and bare `N/A`
  values fail task review.
- AC-009: The interviewer declares all seven full-profile Phase 1 outputs
  (`requirements.md`, `acceptance-tests.md`, `design.md`, `ux-spec.md`,
  `frontend-spec.md`, `infra-spec.md`, and `security-spec.md`),
  prompts optionally for visual inputs, records layer-local unknowns, preserves
  review-gate ordering, and explicitly excludes LITE.
- AC-010: The Claude Design guide is under 200 lines, names Mermaid as primary,
  states unsupported integration limits, and contains three usable prompts.
- AC-011: Bash and PowerShell project-root checks keep their current output and
  exit semantics when feature validation is not requested.
- AC-012: Bash and PowerShell feature validation emit one stable `missing:`
  diagnostic per absent file in the exact nine-file inventory from REQ-012 and
  exit 1; complete nine-file fixtures exit 0.
- AC-013: Existing script and repository validation tests pass, with new
  parity coverage for feature validation and LITE exclusion.
- AC-014: All sdd-bootstrap host manifests and marketplace entries use the same
  new version and `CHANGELOG.md` documents the enhancement.
- AC-015: Implementation-policy and task review prechecks accept the complete
  canonical four-layer input set, record each layer path and SHA-256 in their
  allowed-input manifests, and reject a missing, path-substituted, or
  post-manifest-modified layer file. Task review additionally rejects blank,
  bare `N/A`, malformed layer anchors, and reasonless cross-layer exclusions.
- AC-016: After task review passes, generated tasks remain Draft;
  `implement-task` rejects them until the existing human or active signed
  `sdd-sudo` approval transition sets selected tasks to Approved.

## Roles and Permissions

This feature changes static skill instructions, templates, references, scripts,
tests, and release metadata. It adds no runtime user roles or authorization
surface.

## Main Workflows

1. Run the existing repository-level preflight.
2. Interview all applicable full-profile layers.
3. Populate core and layer templates without overwriting existing artifacts.
4. Optionally incorporate visual inputs using the documented manual workflow.
5. Run spec review, then implementation-policy review over the core design and
   all four hash-bound layer specs.
6. Generate Draft tasks, run task review over the same layer set and
   traceability, then require the existing human or signed-sudo approval
   transition before implementation.
7. Validate the selected feature artifact set explicitly.
8. Skip steps 2–4 layer generation and feature-layer validation for LITE.

## Edge Cases

- Existing layer files are preserved.
- Bugfix/refactor work marks unaffected layers `N/A — no change`, not `TBD`;
  security impact is always assessed.
- Greenfield infrastructure does not assume an existing provider or topology.
- No mockup input leaves the optional visualization step cleanly skipped.
- Existing pre-v1.4 spec directories are not made invalid by repository-only
  preflight.
- Invalid or traversal-like feature slugs fail closed.

## Security Boundaries

| Trust Boundary | Auth/Authz Requirement | PII / Data Classification | Regulatory Constraints |
|---|---|---|---|
| CLI input to feature path | Validate a canonical feature slug; no authorization change | Repository metadata only | Prevent traversal and writes outside `specs/` |
| Optional visual artifact input | Manual, local attachment only | May contain product-sensitive UI data | Do not promise upload privacy or external API integration |

## Validated Baseline And Decisions

- Mermaid source is the canonical diagram artifact. Rendering support is
  optional and is not an acceptance condition, so host renderer behavior is
  outside this feature's correctness boundary.
- Repository investigation confirmed that implementation-policy and task
  review behavior is implemented in local skills, precheck scripts, reviewer
  prompts, and contract validators. These existing stages will be extended in
  place; status ownership and stage order remain unchanged.
- Current repository manifests, marketplace entries, validation expectations,
  and `CHANGELOG.md` identify `1.3.0` as the current release baseline.
  Repository convention keeps plugin/catalog versions synchronized, so this
  additive release is `1.4.0`.

## Open Questions

None. The source plan's checker mismatch is resolved by the explicit POSIX and
PowerShell interfaces in REQ-012. The review-surface decision is resolved by
extending the existing implementation-policy and task review stages.

## Risks

- Review-loop manifests may reject or fail to bind layer artifacts; AC-015
  requires canonical-path and tamper-rejection coverage.
- Making feature checks implicit would invalidate legacy specs; feature mode
  therefore remains explicit.
- Larger interviews may become burdensome; layer questions permit `N/A` with a
  reason and do not affect LITE.
- Host/version catalogs may drift; repository validation must check all
  sdd-bootstrap metadata together.
