# Tasks: Claude workflow compatibility

Task-Review-Status: Passed

## Lifecycle

`Draft -> Approved -> In Progress -> Implementation Complete -> Done`

A task may enter `Blocked` from any active state. Humans approve tasks.
`implement-task` may set `In Progress`, `Blocked`, or `Implementation Complete`.
Only `quality-gate` may set `Done`.

## T-001 Add the specification review gate and isolated reviewer definitions

Source Issue: Bootstrap exception approved by repository maintainer on 2026-06-23

Approval: Approved

Status: In Progress

Risk: high

Risk Rationale: This task creates the authoritative predecessor gate that controls
whether later SDD phases may proceed and must prevent cross-role evidence access.

Required Workflow: tdd

Requirements: REQ-007, REQ-008; AC-007

Planned Files: `plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md`,
`plugins/sdd-review-loop/agents/spec-reviewer-a.md`,
`plugins/sdd-review-loop/agents/spec-reviewer-b.md`,
`plugins/sdd-review-loop/templates/spec-review-contract.template.json`,
`plugins/sdd-review-loop/templates/spec-review-report.template.md`,
`plugins/sdd-review-loop/scripts/spec-review-precheck.sh`, review-loop test files

Data Migration: None

Breaking API: No

Rollback: Remove the newly added skill and agent assets; existing impl/task loops
remain unchanged until T-002 enables their strengthened predecessor checks.

### Goal

Provide `/sdd-review-loop:spec-review-loop` with a deterministic three-round
state machine and two new, read-only reviewer definitions that are separate from
all implementation-policy and task reviewers.

### Must Read

- specs/claude-workflow-compatibility/requirements.md
- specs/claude-workflow-compatibility/design.md
- specs/claude-workflow-compatibility/acceptance-tests.md
- specs/claude-workflow-compatibility/traceability.md
- docs/adr/0001-independent-review-gates.md

### Scope

- Add the spec-review skill, contract/report templates, and POSIX precheck that
  adopts T-002's shared portable contract/path validation foundation for its
  canonical input, hash, attempt/round, lock, and destination validation.
- Add `spec-reviewer-a` and `spec-reviewer-b` with unique host-session and
  allowed-input-manifest contract requirements plus cross-role raw-report denial.
- Add Red→Green shell tests for clean PASS, NEEDS_WORK, reset, warning PASS,
  invalid transitions, replay, symlink, and path traversal cases.

### Done When

- [ ] A failing review-loop test covering each AC-007 negative path
  is committed before implementation begins, and the same tests pass after it.
- [ ] `spec-review-loop` writes only validated attempt/round evidence and emits
  `verdict: PASS` with `warningCount` for a round-three Minor-only result.
- [ ] The two new reviewer definitions are unique, read-only, fresh-context
  roles and reject raw report paths outside their allowed inputs.
- [ ] Scoped review-loop tests and related regression tests pass with saved output.
- [ ] An implementation report records Red→Green evidence and a named,
  independent second reviewer verdict.
- [ ] `traceability.md` maps T-001 to REQ-007, REQ-008, and AC-007.

### Out of Scope

- Changing implementation-policy or task-review prechecks.
- Claude plugin-manifest compatibility and installation behavior.

### Blockers

T-002

## T-002 Establish the shared portable review-contract validation foundation

Source Issue: Bootstrap exception approved by repository maintainer on 2026-06-23

Approval: Approved

Status: Implementation Complete

Risk: high

Risk Rationale: This task establishes the shared validation boundary used by
review-gate adopters across supported operating systems.

Required Workflow: tdd

Requirements: REQ-009

Planned Files: shared review-contract validation helpers, shared UTF-8 fixtures,
semantic JSON oracle, shell/PowerShell foundation tests

Data Migration: None

Breaking API: No

Rollback: Remove the shared validation helper and fixture corpus without
altering existing gate scripts; persisted review artifacts remain append-only
evidence.

### Goal

Provide a portable, deterministic validation foundation that later gate-specific
tasks can adopt without duplicating contract or path semantics.

### Must Read

- specs/claude-workflow-compatibility/requirements.md
- specs/claude-workflow-compatibility/design.md
- specs/claude-workflow-compatibility/acceptance-tests.md
- specs/claude-workflow-compatibility/traceability.md
- docs/adr/0001-independent-review-gates.md

### Scope

- Define a canonical review-contract input schema and safe path-validation
  helper with shared UTF-8 fixtures and a semantic JSON oracle.
- Provide functionally equivalent shell and PowerShell foundation entry points
  for macOS, Linux, and Windows.
- Add Red→Green fixture tests for inconsistent contracts, invalid slugs,
  nonpositive counters, and unsafe write destinations.

### Done When

- [ ] Failing shell and PowerShell fixture tests for the shared denial cases are
  committed before implementation begins, and their passing counterparts are
  saved after it.
- [ ] Shell and PowerShell implementations produce equivalent semantic JSON for
  the shared UTF-8 fixture corpus.
- [ ] Scoped review-loop tests and related regression tests pass with saved output.
- [ ] An implementation report records Red→Green evidence and a named,
  independent second reviewer verdict.
- [ ] `traceability.md` maps T-002 to REQ-009.

### Out of Scope

- Gate-specific predecessor enforcement, new review roles, and host manifests.

### Blockers

None

## T-003 Repair Claude plugin discovery and installation validation

Source Issue: Bootstrap exception approved by repository maintainer on 2026-06-23

Approval: Approved

Status: Planned

Risk: medium

Risk Rationale: This task changes marketplace installation preconditions and
Claude-facing plugin metadata but does not change application data or APIs.

Required Workflow: acceptance-first

Requirements: REQ-001, REQ-003, REQ-004, REQ-006; AC-001, AC-003, AC-004, AC-006

Planned Files: affected Claude manifests, WFI audit skill metadata, installer
scripts, installer tests, `docs/troubleshooting.md`

Data Migration: None

Breaking API: No

Rollback: Withdraw the affected marketplace plugin/version and retain the
Claude-valid manifest. Restore only the installer behavior to a version that
does not register an invalid manifest, then rerun validation before any retry.

### Goal

Make affected SDD plugins load in Claude Code, keep their intended manual
commands, and reject an invalid selected Claude manifest before registration.

### Must Read

- specs/claude-workflow-compatibility/requirements.md
- specs/claude-workflow-compatibility/design.md
- specs/claude-workflow-compatibility/acceptance-tests.md
- specs/claude-workflow-compatibility/traceability.md

### Scope

- Remove unsupported Claude-only manifest fields while preserving Codex and
  Copilot manifest behavior and manual public command metadata.
- Correct malformed WFI frontmatter and validate all shipped skill metadata.
- Add installer validation ordering and integration tests for invalid manifests.

### Done When

- [ ] Acceptance-first tests demonstrate that every selected invalid Claude
  manifest fails before marketplace registration on each applicable installer.
- [ ] `claude plugin validate` accepts each shipped Claude manifest with no
  unsupported explicit agent/rules declaration.
- [ ] The WFI audit skill frontmatter and every shipped skill metadata document
  parse with `name` and `description` retained.
- [ ] Recovery documentation describes validation, `plugin list`, update or
  reinstall, and `/reload-plugins` after a failed Claude installation.
- [ ] Installer and registration regression tests pass with saved output.
- [ ] An implementation report records test evidence and an independent reviewer verdict.
- [ ] `traceability.md` maps T-003 to REQ-001, REQ-003, REQ-004, REQ-006 and
  AC-001, AC-003, AC-004, AC-006.

### Out of Scope

- CI OS-matrix integration, isolated release smoke, and release/catalog version
  propagation.

### Blockers

None

## T-004 Add real Claude validation to CI and release verification

Source Issue: Bootstrap exception approved by repository maintainer on 2026-06-23

Approval: Approved

Status: Planned

Risk: medium

Risk Rationale: This task changes CI release checks and release-catalog
consistency assertions, without changing runtime review semantics.

Required Workflow: acceptance-first

Requirements: REQ-002, REQ-005, REQ-010; AC-002, AC-005, AC-010

Planned Files: `.github/workflows/test.yml`, release smoke/test scripts,
repository validation tests, host manifests and root marketplace catalogs

Data Migration: None

Breaking API: No

Rollback: Revert the CI/release validation job and restore the prior synchronized
host/catalog version set as one change; rerun repository validation before a
release is retried.

### Goal

Ensure the real Claude CLI validates every shipped Claude plugin across the OS
matrix, isolated release smoke verifies runtime discovery, and release artifacts
have one newer, consistent version.

### Must Read

- specs/claude-workflow-compatibility/requirements.md
- specs/claude-workflow-compatibility/design.md
- specs/claude-workflow-compatibility/acceptance-tests.md
- specs/claude-workflow-compatibility/traceability.md

### Scope

- Add an OS-matrix real-CLI manifest-validation job and invalid-manifest fixture.
- Implement the complete isolated release-smoke contract: isolated HOME/config/
  cache paths, reload, command and agent discovery, credential-aware skip, and
  machine-readable result output.
- Update affected host manifests and both root marketplace catalogs together and
  test their version consistency.

### Done When

- [ ] Acceptance-first CI fixture tests prove an invalid manifest fails on each
  existing OS matrix entry.
- [ ] Release smoke uses isolated roots, reloads plugins, verifies the required
  commands and reviewer agents, and emits CLI version, plugin version, install
  root, discovery outcome, and an explicit credential skip reason when needed.
- [ ] The nine affected host manifest entries and both marketplace entries use a
  version greater than 1.1.0 and repository assertions verify it.
- [ ] CI/release regression tests pass with saved output.
- [ ] An implementation report records test evidence and an independent reviewer verdict.
- [ ] `traceability.md` maps T-004 to REQ-002, REQ-005, REQ-010, AC-002,
  AC-005, and AC-010.

### Out of Scope

- Installer logic and end-user workflow documentation.

### Blockers

T-003

## T-005 Synchronize workflow documentation and diagrams

Source Issue: Bootstrap exception approved by repository maintainer on 2026-06-23

Approval: Approved

Status: Planned

Risk: low

Risk Rationale: This task updates developer documentation and diagrams only.

Required Workflow: test-after

Requirements: REQ-011; AC-011

Planned Files: `README.md`, `AGENTS.md`, `docs/workflow-guide.md`,
`docs/contributor/workflow-detail.md`, `docs/skill-reference.md`,
`docs/contributor/skill-reference-detail.md`, bootstrap interviewer skill,
documentation consistency tests

Data Migration: None

Breaking API: No

Rollback: Revert the documentation and diagram edits as one change and rerun
documentation-consistency tests; no runtime state or marketplace registration
is changed by this task.

### Goal

Document the new three-stage independent review workflow and command sequence
consistently in all user and contributor references.

### Must Read

- specs/claude-workflow-compatibility/requirements.md
- specs/claude-workflow-compatibility/design.md
- specs/claude-workflow-compatibility/acceptance-tests.md
- specs/claude-workflow-compatibility/traceability.md

### Scope

- Update user and contributor workflows with the spec → implementation-policy →
  task review diagram and command sequence.
- Update skill references and bootstrap instructions to invoke the new gate.
- Add deterministic documentation checks for recovery steps and all required
  workflow references.

### Done When

- [ ] Workflow diagrams and command sequences show `spec-review-loop` before
  implementation-policy review and name all three independent review stages.
- [ ] Documentation consistency and related regression tests pass with saved output.
- [ ] An implementation report records test evidence and an independent reviewer verdict.
- [ ] `traceability.md` maps T-005 to REQ-011 and AC-011.

### Out of Scope

- Changing plugin behavior or release validation code.

### Blockers

T-001

## T-006 Adopt deterministic predecessor checks in implementation-policy and task gates

Source Issue: Bootstrap exception approved by repository maintainer on 2026-06-23

Approval: Approved

Status: Planned

Risk: high

Risk Rationale: This task changes the enforcement that permits or blocks two
downstream review-state transitions and their evidence writes.

Required Workflow: tdd

Requirements: REQ-008, REQ-009; AC-008, AC-009

Planned Files: implementation-policy and task review prechecks, matching
PowerShell entry points, shared contract fixtures, review-loop tests

Data Migration: None

Breaking API: No

Rollback: Restore the two prior gate prechecks and their matching PowerShell
entry points as one change; preserve append-only evidence already written by
valid prior runs.

### Goal

Adopt the shared validation foundation in the two downstream gates and prove
they fail closed before writing report evidence when predecessor or path
contracts are invalid.

### Must Read

- specs/claude-workflow-compatibility/requirements.md
- specs/claude-workflow-compatibility/design.md
- specs/claude-workflow-compatibility/acceptance-tests.md
- specs/claude-workflow-compatibility/traceability.md
- docs/adr/0001-independent-review-gates.md

### Scope

- Integrate shared predecessor PASS, contract, attempt/round, input-manifest,
  and safe-destination validation into implementation-policy and task gates.
- Add their portable entry points and cross-gate fixture coverage, including
  heading-style blocker graph edges and cycle detection.
- Verify role/session separation across all six agent definitions using the
  canonical structural fixture.

### Done When

- [ ] Failing fixture tests for each AC-008 and AC-009 denial path are committed
  before implementation begins and their passing counterparts are saved after it.
- [ ] Both downstream gates reject a missing, inconsistent, or non-PASS
  predecessor contract before creating report evidence.
- [ ] Shell and PowerShell gate outputs match the shared UTF-8 semantic oracle.
- [ ] Dependency graph fixtures emit declared edges and detect cycles.
- [ ] Scoped review-loop tests and related regression tests pass with saved output.
- [ ] An implementation report records Red→Green evidence and a named,
  independent second reviewer verdict.
- [ ] `traceability.md` maps T-006 to REQ-008, REQ-009, AC-008, and AC-009.

### Out of Scope

- The spec-review loop implementation and the shared validation foundation.
- Claude plugin manifest compatibility, installer behavior, and documentation.

### Blockers

T-001, T-002
