# Tasks: Bootstrap Interviewer Enhancement

Task-Review-Status: Passed

## Lifecycle

`Draft -> Approved -> In Progress -> Implementation Complete -> Done`

## T-001 Create the four layer artifacts

Approval: Approved (sudo 2026-06-29T14:25:04Z)

Status: Done

Risk: medium

Risk Rationale: This adds generated full-profile document structures without
changing executable path handling or authorization.

Required Workflow: acceptance-first

Requirements: REQ-001, REQ-003, REQ-006, REQ-007, AC-001, AC-002, AC-003,
AC-004, AC-005

Planned Files: four layer templates and
`tests/bootstrap-layer-templates.tests.sh`.

Data Migration: None.

Breaking API: No.

Rollback: Remove the four additive templates; existing core and LITE artifacts
remain unchanged.

### Goal

Provide implementation-ready UX, frontend, infrastructure, and security layer
documents with canonical diagrams, contracts, budgets, and controls.

### Must Read

- `specs/bootstrap-interviewer-enhancement/requirements.md`
- `specs/bootstrap-interviewer-enhancement/design.md`
- `specs/bootstrap-interviewer-enhancement/acceptance-tests.md`
- all four approved layer documents

### Scope

Implement the four reusable layer templates and their static acceptance fixture.

### Done When

- [ ] TEST-001 through TEST-005 fail in `tests/bootstrap-layer-templates.tests.sh` before template creation
- [ ] `tests/bootstrap-layer-templates.tests.sh` exits 0 and reports AC-001 through AC-005
- [ ] Removing each mandatory section in the `malformed-layer-template` fixture makes the test exit 1 with the missing heading
- [ ] Every template contains canonical REQ/AC placeholders and its required Mermaid diagram
- [ ] Frontend budgets, infrastructure SLOs, and security STRIDE rows satisfy the exact static assertions
- [ ] Acceptance-first logs are stored under `specs/bootstrap-interviewer-enhancement/verification/T-001/`

### Out of Scope

Core indexes, interview instructions, executable checkers, review gates, and
release metadata.

### Blockers

None

## T-002 Create the cross-layer indexes

Approval: Approved (sudo 2026-06-29T14:25:04Z)

Status: Done

Risk: medium

Risk Rationale: This changes reviewed document schemas and traceability
requirements without changing runtime code.

Required Workflow: acceptance-first

Requirements: REQ-008, REQ-009, AC-007, AC-008

Planned Files: `design.template.md`, `traceability.template.md`, and
`tests/bootstrap-cross-layer-index.tests.sh`.

Data Migration: None; existing documents remain valid.

Breaking API: No.

Rollback: Revert both core templates together to restore the former inline
design layout.

### Goal

Make design.md a cross-layer index and require canonical layer ownership in
traceability rows.

### Must Read

- `specs/bootstrap-interviewer-enhancement/requirements.md`
- `specs/bootstrap-interviewer-enhancement/design.md`
- `specs/bootstrap-interviewer-enhancement/acceptance-tests.md`
- `specs/bootstrap-interviewer-enhancement/traceability.md`

### Scope

Update the design and traceability templates plus their static acceptance fixture.

### Done When

- [ ] TEST-007 and TEST-008 fail in `tests/bootstrap-cross-layer-index.tests.sh` before template changes
- [ ] `tests/bootstrap-cross-layer-index.tests.sh` exits 0 and reports AC-007 and AC-008
- [ ] Every traceability example is a canonical layer anchor or `N/A — cross-layer only: <reason>`
- [ ] Acceptance-first logs are stored under `specs/bootstrap-interviewer-enhancement/verification/T-002/`

### Out of Scope

Layer template content, interviewer prompts, executable validation, and release
metadata.

### Blockers

T-001

## T-003 Expand full-profile interview guidance

Approval: Approved (sudo 2026-06-29T14:25:04Z)

Status: Done

Risk: medium

Risk Rationale: This changes full-profile generation instructions and optional
visualization guidance while preserving LITE and existing-file boundaries.

Required Workflow: acceptance-first

Requirements: REQ-002, REQ-004, REQ-006, REQ-010, REQ-011, REQ-013, AC-006,
AC-009, AC-010

Planned Files: interviewer/run skills, question bank, Claude Design reference,
and `tests/bootstrap-interview-guidance.tests.sh`.

Data Migration: None.

Breaking API: No.

Rollback: Revert guidance and question-bank changes; generated user files are
never overwritten.

### Goal

Generate the seven Phase 1 outputs through a bilingual layer-aware interview
with a bounded optional visualization workflow.

### Must Read

- `specs/bootstrap-interviewer-enhancement/requirements.md`
- `specs/bootstrap-interviewer-enhancement/design.md`
- `specs/bootstrap-interviewer-enhancement/acceptance-tests.md`

### Scope

Update the question bank, optional Claude Design guide, and full-profile
interviewer/run instructions.

### Done When

- [ ] TEST-006, TEST-009, TEST-010, TEST-017, and TEST-018 fail in `tests/bootstrap-interview-guidance.tests.sh` before guidance changes
- [ ] `tests/bootstrap-interview-guidance.tests.sh` exits 0 and reports AC-006, AC-009, and AC-010
- [ ] The fixture `bugfix-unaffected-layers` records reasoned N/A values and a security assessment
- [ ] The fixtures `existing-layer-files` and `no-mockup` report preserved hashes and a clean optional-step skip
- [ ] The LITE fixture reports zero layer outputs
- [ ] Acceptance-first logs are stored under `specs/bootstrap-interviewer-enhancement/verification/T-003/`

### Out of Scope

Checker implementation, review-gate integrity, and release metadata.

### Blockers

T-001, T-002

## T-004 Add selected-feature structure validation

Approval: Approved (sudo 2026-06-29T14:25:04Z)

Status: Done

Risk: high

Risk Rationale: Feature selectors cross a filesystem trust boundary and paired
Bash/PowerShell behavior must fail closed without path traversal.

Required Workflow: tdd

Requirements: REQ-005, REQ-012, REQ-014, AC-011, AC-012, AC-013

Planned Files: paired structure-check scripts,
`tests/structure-check-feature-mode.tests.sh`, and
`tests/structure-check-feature-mode.tests.ps1`.

Data Migration: None.

Breaking API: No; feature selection is optional and repository-only invocation
retains its existing interface and output.

Rollback: Revert the optional feature arguments and isolated fixtures;
repository-only behavior remains the baseline.

### Goal

Validate the exact nine-file inventory for one safe feature slug with equivalent
Bash and PowerShell behavior.

### Must Read

- `specs/bootstrap-interviewer-enhancement/requirements.md`
- `specs/bootstrap-interviewer-enhancement/design.md`
- `specs/bootstrap-interviewer-enhancement/acceptance-tests.md`
- `specs/bootstrap-interviewer-enhancement/security-spec.md`

### Scope

Add optional feature selectors, slug validation, exact missing diagnostics, and
paired runtime fixtures.

### Done When

- [ ] TEST-011, TEST-012, TEST-013, and TEST-019 fail before checker changes
- [ ] Complete and each-single-missing inventories produce the specified exit codes and diagnostics
- [ ] Invalid selector fixtures emit `invalid feature: <value>`, exit 1, and record no access outside `specs/`
- [ ] Repository-only and LITE regression fixtures exit 0 in both runtimes
- [ ] Red→Green logs are stored under `specs/bootstrap-interviewer-enhancement/verification/T-004/`
- [ ] Independent reviewer `T-004-independent-reviewer` records PASS in `reports/implementation/bootstrap-interviewer-enhancement/T-004.md`
- [ ] The isolated rollback fixture restores baseline script hashes and repository-only checks exit 0

### Out of Scope

Layer content, review manifests, task approvals, and release versioning.

### Blockers

None

## T-005 Bind layer inputs through implementation review

Approval: Approved (sudo 2026-06-29T14:25:04Z)

Status: Done

Risk: high

Risk Rationale: This changes mandatory implementation-review input integrity;
divergence could bypass or deadlock the SDD workflow.

Required Workflow: tdd

Requirements: REQ-016

Planned Files: implementation-review skill, prompts, contracts, prechecks, and
`tests/impl-layer-review-inputs.tests.sh` plus its PowerShell parity fixture.

Data Migration: None; existing legacy review contracts remain supported.

Breaking API: No.

Rollback: Revert implementation-review layer-manifest extensions and fixtures;
existing core-input review remains active.

### Goal

Hash-bind all four layer artifacts through implementation review.

### Must Read

- `specs/bootstrap-interviewer-enhancement/requirements.md`
- `specs/bootstrap-interviewer-enhancement/design.md`
- `specs/bootstrap-interviewer-enhancement/acceptance-tests.md`
- all four layer documents

### Scope

Extend implementation-review manifests, prechecks, prompts, and contracts
without creating a new review stage.

### Done When

- [ ] Implementation-review missing, substituted, and tampered layer fixtures fail before reviewer invocation
- [ ] Complete canonical layer inputs pass the implementation-review precheck
- [ ] Bash and PowerShell implementation-review fixtures produce equivalent verdicts
- [ ] Red→Green logs are stored under `specs/bootstrap-interviewer-enhancement/verification/T-005/`
- [ ] Independent reviewer `T-005-independent-reviewer` records PASS in `reports/implementation/bootstrap-interviewer-enhancement/T-005.md`
- [ ] The isolated rollback fixture restores legacy contract hashes and the legacy implementation precheck exits 0

### Out of Scope

Task review, approval behavior, quality-gate semantics, and release metadata.

### Blockers

T-001, T-002

## T-006 Bind layer inputs through task review

Approval: Approved (sudo 2026-06-29T14:25:04Z)

Status: Done

Risk: high

Risk Rationale: This changes mandatory task-review inputs and traceability
validation; divergence could admit incomplete task plans.

Required Workflow: tdd

Requirements: REQ-016, AC-015

Planned Files: task-review skill, prompts, contracts, prechecks,
workflow-state validation, and `tests/task-layer-review-inputs.tests.sh` plus
its PowerShell parity fixture.

Data Migration: None; existing legacy task-review contracts remain supported.

Breaking API: No.

Rollback: Revert task-review layer and traceability extensions; existing core
task review remains active.

### Goal

Hash-bind layer inputs through task review and reject invalid Layer Spec
traceability values.

### Must Read

- `specs/bootstrap-interviewer-enhancement/requirements.md`
- `specs/bootstrap-interviewer-enhancement/design.md`
- `specs/bootstrap-interviewer-enhancement/acceptance-tests.md`
- all four layer documents and `traceability.md`

### Scope

Extend task-review manifests, prechecks, prompts, contracts, and workflow-state
validation for canonical layer inputs and traceability.

### Done When

- [ ] TEST-015 fails before task-review policy changes
- [ ] Missing, substituted, tampered, blank, bare N/A, malformed anchor, and reasonless exclusion fixtures fail before reviewer invocation
- [ ] Complete canonical inputs pass the task-review precheck
- [ ] Bash and PowerShell task-review fixtures produce equivalent verdicts
- [ ] Red→Green logs are stored under `specs/bootstrap-interviewer-enhancement/verification/T-006/`
- [ ] Independent reviewer `T-006-independent-reviewer` records PASS in `reports/implementation/bootstrap-interviewer-enhancement/T-006.md`
- [ ] The isolated rollback fixture restores legacy contract hashes and the legacy task precheck exits 0

### Out of Scope

Approval behavior, quality-gate semantics, and release metadata.

### Blockers

T-001, T-002, T-005

## T-007 Preserve the approval boundary

Approval: Approved (sudo 2026-06-29T14:25:04Z)

Status: Done

Risk: high

Risk Rationale: This verifies the authorization boundary between task review
and implementation eligibility.

Required Workflow: tdd

Requirements: REQ-017, AC-016

Planned Files: approval/workflow-state validation and
`tests/approval-boundary.tests.sh`.

Data Migration: None.

Breaking API: No.

Rollback: Revert only the additive approval fixtures; existing Draft rejection
and signed-sudo behavior remain the baseline.

### Goal

Preserve human or signed-sudo ownership of Draft-to-Approved transitions.

### Must Read

- `specs/bootstrap-interviewer-enhancement/requirements.md`
- `specs/bootstrap-interviewer-enhancement/acceptance-tests.md`
- `specs/bootstrap-interviewer-enhancement/security-spec.md`

### Scope

Add regression coverage for Draft rejection and the existing authorized human
or signed-sudo approval paths.

### Done When

- [ ] TEST-016 fails before approval-boundary fixture changes
- [ ] Draft-task fixtures remain ineligible for `implement-task`
- [ ] Human-approved and active signed-sudo fixtures become eligible while expired or invalid tokens remain ineligible
- [ ] Red→Green logs are stored under `specs/bootstrap-interviewer-enhancement/verification/T-007/`
- [ ] Independent reviewer `T-007-independent-reviewer` records PASS in `reports/implementation/bootstrap-interviewer-enhancement/T-007.md`
- [ ] Removing the additive fixtures leaves the baseline Draft-rejection command exiting 0

### Out of Scope

New approval mechanisms, review-input binding, and quality-gate semantics.

### Blockers

T-006

## T-008 Publish synchronized 1.4.0 release metadata

Approval: Approved (sudo 2026-06-29T14:25:04Z)

Status: Done

Risk: low

Risk Rationale: This is repository metadata and changelog synchronization after
the functional tasks complete.

Required Workflow: test-after

Requirements: REQ-015, AC-014

Planned Files: all six plugin manifests, Claude/Agents/Codex marketplace
catalogs, `CHANGELOG.md`, and repository validation expectations.

Data Migration: None.

Breaking API: No.

Rollback: Revert the synchronized version and changelog entry together.

### Goal

Publish the additive workflow capability consistently as version 1.4.0.

### Must Read

- `specs/bootstrap-interviewer-enhancement/requirements.md`
- `specs/bootstrap-interviewer-enhancement/design.md`
- `specs/bootstrap-interviewer-enhancement/acceptance-tests.md`

### Scope

Synchronize repository release metadata and changelog content after functional
behavior is verified.

### Done When

- [ ] Every plugin and marketplace version assertion resolves to `1.4.0`
- [ ] `CHANGELOG.md` identifies layer artifacts, selected-feature validation, and review-input binding
- [ ] Repository validation and manifest/catalog consistency commands exit 0
- [ ] Test-after logs are stored under `specs/bootstrap-interviewer-enhancement/verification/T-008/`

### Out of Scope

Functional template, checker, or review-policy behavior.

### Blockers

T-003, T-004, T-007
