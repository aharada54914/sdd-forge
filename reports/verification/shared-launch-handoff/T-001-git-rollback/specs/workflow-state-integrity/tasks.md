# Tasks: workflow-state-integrity

Task-Review-Status: Passed

## Lifecycle

`Draft -> Approved -> In Progress -> Implementation Complete -> Done`

A task may enter `Blocked` from any active state. Humans approve tasks.
`implement-task` may set `In Progress`, `Blocked`, or `Implementation Complete`.
Only `quality-gate` may set `Done`.

## T-001 Repair downstream review-contract transition validation

Source Issue: Persisted review contracts created before a status transition are
rejected after the canonical header changes from Pending to Passed, and
repository-root absolute reviewer manifests are interpreted inconsistently.

Approval: Approved (sudo 2026-06-27T08:01:04Z)

Status: Done

Risk: high

Risk Rationale: This bugfix changes predecessor review-gate validation and an
incorrect normalization could bypass or deadlock mandatory review transitions.

Required Workflow: tdd

Requirements: REQ-003, REQ-008, REQ-010, REQ-012

Planned Files: `plugins/sdd-review-loop/scripts/impl-review-precheck.sh`,
`plugins/sdd-review-loop/scripts/impl-review-precheck.ps1`,
`plugins/sdd-review-loop/scripts/task-review-precheck.sh`,
`plugins/sdd-review-loop/scripts/task-review-precheck.ps1`,
`tests/spec-review-loop.tests.sh`,
`tests/downstream-review-precheck.tests.sh`,
`tests/downstream-review-precheck.tests.ps1`,
`tests/downstream-review-precheck-parity.tests.sh`,
`specs/workflow-state-integrity/traceability.json`

Data Migration: None

Breaking API: No

Rollback: Revert the status-neutral hash/path-normalization change and its
fixtures as one commit; rerun the predecessor transition reproduction before
restoring the prior scripts.

### Goal

Permit a valid reviewed Pending artifact to transition to Passed without making
its predecessor contract stale, while rejecting unrelated normalization,
repository escape, traversal, and forged manifests.

### Must Read

- `specs/workflow-state-integrity/requirements.md`
- `specs/workflow-state-integrity/design.md`
- `specs/workflow-state-integrity/acceptance-tests.md`
- `specs/workflow-state-integrity/traceability.md`
- `reports/implementation/bootstrap-review-gate.md`

### Scope

Capture the actual Spec-Passed → Impl-precheck failure, diagnose the canonical
hash/path mismatch, implement narrowly status-neutral hashing and repository
path canonicalization in both runtimes, and extend shared predecessor fixtures.

### Done When

- [ ] `bash tests/spec-review-loop.tests.sh` records the original transition failure before the fix and exits 0 after it
- [ ] Shell and PowerShell downstream-precheck suites exit 0 with equivalent normalized outcomes
- [ ] Traversal, escaping absolute paths, stale hashes, and extra artifact normalization remain rejected
- [ ] The failing test is present in a test-only commit that precedes the corresponding implementation commit; Red→Green logs remain under `specs/workflow-state-integrity/verification/T-001.*.log`
- [ ] A named independent reviewer distinct from the implementing agent records a verdict in `reports/implementation/workflow-state-integrity/T-001.md`
- [ ] Evidence records `spec_revision`, the execution environment, exact changed-file hashes, and proof that the mandatory requirement-traceability check passed
- [ ] Rollback procedure is documented and exercised against the isolated reproduction fixture

### Out of Scope

Global repository-state policy, legacy registry creation, version changes, and
rewriting existing historical review records.

### Blockers

None

## T-002 Add the workflow registry contract and bounded migration records

Source Issue: Existing spec directories have incompatible historical review
generations and no authoritative profile declaration.

Approval: Approved (sudo 2026-06-27T08:01:04Z)

Status: Done

Risk: high

Risk Rationale: Overbroad or incomplete migration metadata could hide current
violations or fail every repository validation run.

Required Workflow: tdd

Requirements: REQ-001, REQ-005, REQ-006, REQ-007, REQ-009; AC-001, AC-002, AC-006, AC-011

Planned Files: `contracts/workflow-state-registry.schema.json`,
`specs/workflow-state-registry.json`,
`specs/uninstall-workflow/retrospective.md`,
`tests/fixtures/workflow-state/`,
`tests/workflow-state-registry.tests.sh`,
`tests/workflow-state-registry.tests.ps1`,
`tests/workflow-state-registry-parity.tests.sh`

Data Migration: Explicitly classify all spec directories present at commit
`0369c8c96de2eb3179868d1949d66644488f65aa`; do not rewrite their headers.

Breaking API: No

Rollback: Revert the schema, registry, fixtures, and retrospective together
before v1.3.0 publication; no historical artifact is mutated.

### Goal

Create a strict versioned registry that covers every spec directory and permits
only the observed, commit-bounded historical exceptions.

### Must Read

- `specs/workflow-state-integrity/requirements.md`
- `specs/workflow-state-integrity/design.md`
- `specs/workflow-state-integrity/acceptance-tests.md`
- `specs/workflow-state-integrity/traceability.md`
- `docs/adr/0002-repository-workflow-state-integrity.md`

### Scope

Define schema version 1, add exact full/lite/legacy entries, create invalid
registry/path fixtures, and add the uninstall retrospective tied to commit
`277a79d`.

### Done When

- [ ] A schema validator accepts the canonical registry and rejects every AC-002/AC-006 invalid fixture
- [ ] Registry keys exactly match the first-level `specs/` directories, including `uninstall-workflow`
- [ ] The retrospective names commit `277a79d`, implementation/tests, and unavailable review provenance
- [ ] The failing `bash tests/workflow-state-registry.tests.sh` test is present in a test-only commit that precedes the corresponding implementation commit, with output captured in `specs/workflow-state-integrity/verification/T-002.red.log`
- [ ] After implementation, passing `bash tests/workflow-state-registry.tests.sh`, `pwsh -NoProfile -File tests/workflow-state-registry.tests.ps1`, and `bash tests/workflow-state-registry-parity.tests.sh` output is captured in `specs/workflow-state-integrity/verification/T-002.green.log`
- [ ] A named independent reviewer distinct from the implementing agent records a verdict in `reports/implementation/workflow-state-integrity/T-002.md`
- [ ] Evidence records `spec_revision`, the execution environment, exact registry/schema hashes, and proof that the mandatory requirement-traceability check passed
- [ ] The Git-revert rollback procedure is exercised in an isolated fixture

### Out of Scope

Fabricating stage contracts, changing historical status headers, or applying
full-review rules to the lite profile.

### Blockers

None

## T-003 Implement portable workflow-state validation

Source Issue: Repository state is not globally checked for review ordering,
Passed provenance, or task lifecycle coupling.

Approval: Approved (sudo 2026-06-27T08:01:04Z)

Status: Done

Risk: high

Risk Rationale: This is the fail-closed integrity boundary; runtime divergence
or missed error paths would permit invalid review/task state.

Required Workflow: tdd

Requirements: REQ-002, REQ-003, REQ-004, REQ-006, REQ-007, REQ-010, REQ-012; AC-003, AC-004, AC-005, AC-007, AC-008, AC-014

Planned Files: `plugins/sdd-quality-loop/scripts/check-workflow-state.sh`,
`plugins/sdd-quality-loop/scripts/check-workflow-state.ps1`,
`tests/workflow-state.tests.sh`,
`tests/workflow-state.tests.ps1`, `tests/workflow-state-parity.tests.sh`

Data Migration: Consume the T-002 registry without modifying registered specs.

Breaking API: No

Rollback: Revert both adapters and their tests together; validate the prior
repository with existing stage-specific gates before any release rollback.

### Goal

Enforce the same full/lite/legacy state model, stable diagnostics, and
fail-closed behavior in Bash and PowerShell.

### Must Read

- `specs/workflow-state-integrity/requirements.md`
- `specs/workflow-state-integrity/design.md`
- `specs/workflow-state-integrity/acceptance-tests.md`
- `specs/workflow-state-integrity/traceability.md`
- `contracts/workflow-state-registry.schema.json`

### Scope

Implement paired adapters over the shared registry and existing review-contract
rules, plus unit/acceptance fixtures and LF/CRLF parity coverage for all valid
and invalid state transitions.

### Done When

- [ ] Bash and PowerShell workflow-state suites exit 0 across AC-003/004/005/007/014 fixtures
- [ ] `bash tests/workflow-state-parity.tests.sh` reports matching rule IDs and exits for LF and CRLF
- [ ] Malformed, unreadable, traversal, symlink-escape, stale, and forged inputs fail without partial PASS
- [ ] The failing test is present in a test-only commit that precedes the corresponding implementation commit; Red→Green logs remain under `specs/workflow-state-integrity/verification/T-003.*.log`
- [ ] A named independent reviewer distinct from the implementing agent records a verdict in `reports/implementation/workflow-state-integrity/T-003.md`
- [ ] Evidence records `spec_revision`, the execution environment, exact adapter/test hashes, and proof that the mandatory requirement-traceability check passed
- [ ] Paired-script rollback is documented and exercised against the isolated fixture repository

### Out of Scope

CI wiring, marketplace versions, changing review verdict semantics, or writing
task lifecycle state.

### Blockers

T-001, T-002

## T-004 Integrate workflow-state validation into repository validation and CI

Source Issue: Repository validation and CI can report packaging success without
checking the complete persisted-state invariant.

Approval: Approved (sudo 2026-06-27T08:01:04Z)

Status: Done

Risk: high

Risk Rationale: Incorrect integration ordering could report release success
before an integrity failure on one or more supported hosts.

Required Workflow: tdd

Requirements: REQ-008, REQ-010; AC-009

Planned Files: `tests/validate-repository.ps1`, `.github/workflows/test.yml`,
`tests/workflow-state-repository-integration.tests.ps1`,
`tests/workflow-state-ci-integration.tests.sh`

Data Migration: None

Breaking API: No

Rollback: Revert repository/CI call sites and their integration assertions
together, leaving the standalone validator intact.

### Goal

Make repository validation and every supported CI job call the canonical
validator before packaging/release success.

### Must Read

- `specs/workflow-state-integrity/requirements.md`
- `specs/workflow-state-integrity/design.md`
- `specs/workflow-state-integrity/acceptance-tests.md`
- `specs/workflow-state-integrity/traceability.md`
- `.github/workflows/test.yml`

### Scope

Wire global validation into repository validation and the OS-matrix CI jobs,
then add isolated invalid-state integration assertions.

### Done When

- [ ] Invalid persisted state makes repository validation exit nonzero before packaging success
- [ ] Unix and Windows CI entry commands invoke the matching workflow-state adapter before release validation
- [ ] Repository-validation and CI integration fixtures exit 0 on supported runtimes
- [ ] The failing test is present in a test-only commit that precedes the corresponding implementation commit; Red→Green logs remain under `specs/workflow-state-integrity/verification/T-004.*.log`
- [ ] A named independent reviewer distinct from the implementing agent records a verdict in `reports/implementation/workflow-state-integrity/T-004.md`
- [ ] Evidence records `spec_revision`, the execution environment, exact integration-file hashes, and proof that the mandatory requirement-traceability check passed
- [ ] Repository/CI rollback is documented and exercised against an isolated invalid-state repository

### Out of Scope

Changing quality/review gates, install/uninstall behavior, or publishing the
release.

### Blockers

T-003

## T-005 Integrate workflow-state validation into quality and review gates

Source Issue: Full quality-gate and downstream review prechecks do not recheck
the canonical persisted-state invariant.

Approval: Approved (sudo 2026-06-27T08:01:04Z)

Status: Done

Risk: high

Risk Rationale: Incorrect gate wiring could allow a bypass or replace existing
predecessor and task-evidence checks.

Required Workflow: tdd

Requirements: REQ-008, REQ-010; AC-010, AC-012

Planned Files: `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md`,
`plugins/sdd-quality-loop/scripts/check-task-state.sh`,
`plugins/sdd-quality-loop/scripts/check-task-state.ps1`,
`plugins/sdd-review-loop/scripts/impl-review-precheck.sh`,
`plugins/sdd-review-loop/scripts/impl-review-precheck.ps1`,
`plugins/sdd-review-loop/scripts/task-review-precheck.sh`,
`plugins/sdd-review-loop/scripts/task-review-precheck.ps1`,
`tests/gates.tests.sh`, `tests/scripts.tests.ps1`,
`tests/downstream-review-precheck.tests.sh`,
`tests/downstream-review-precheck.tests.ps1`,
`tests/downstream-review-precheck-parity.tests.sh`, `tests/run-all.sh`,
`tests/run-all.ps1`, `AGENTS.md`

Data Migration: None

Breaking API: No

Rollback: Revert quality/review gate call sites and integration assertions,
leaving the standalone validator and explicit predecessor checks intact.

### Goal

Run canonical validation before full quality and downstream review actions
without removing any existing task or predecessor enforcement.

### Must Read

- `specs/workflow-state-integrity/requirements.md`
- `specs/workflow-state-integrity/design.md`
- `specs/workflow-state-integrity/acceptance-tests.md`
- `specs/workflow-state-integrity/traceability.md`
- `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md`

### Scope

Wire global validation into quality-gate and scoped validation into Impl/Task
prechecks, bind Done-state quality-report lookup to the path declared by each
task's evidence bundle, then extend downstream integration and regression
assertions.

### Done When

- [ ] Quality-gate invokes global workflow-state validation before task-state checks
- [ ] Impl/Task prechecks invoke scoped validation and retain every explicit predecessor check
- [ ] Done-state validation uses the evidence bundle's feature-scoped `quality_report` path and cannot select a same-ID report from another feature
- [ ] `bash tests/run-all.sh` and `pwsh -NoProfile -File tests/run-all.ps1` exit 0
- [ ] The failing test is present in a test-only commit that precedes the corresponding implementation commit; Red→Green logs remain under `specs/workflow-state-integrity/verification/T-005.*.log`
- [ ] A named independent reviewer distinct from the implementing agent records a verdict in `reports/implementation/workflow-state-integrity/T-005.md`
- [ ] Evidence records `spec_revision`, the execution environment, exact gate/integration hashes, and proof that the mandatory requirement-traceability check passed
- [ ] Gate-call rollback is documented and exercised against an isolated invalid-state repository

### Out of Scope

Repository/CI wiring, removing existing gate checks, changing sudo policy, or
publishing the release.

### Blockers

T-003

## T-006 Revise synchronized release metadata to v1.3.0

Source Issue: The integrity feature changes shipped plugin behavior while all
release surfaces still identify v1.2.0.

Approval: Approved (sudo 2026-06-27T08:01:04Z)

Status: Done

Risk: medium

Risk Rationale: Version skew can break validation and update discovery, but the
change is reversible metadata with no runtime state migration.

Required Workflow: acceptance-first

Requirements: REQ-011; AC-013

Planned Files: `plugins/sdd-bootstrap/.claude-plugin/plugin.json`,
`plugins/sdd-bootstrap/.codex-plugin/plugin.json`,
`plugins/sdd-bootstrap/.plugin/plugin.json`,
`plugins/sdd-implementation/.claude-plugin/plugin.json`,
`plugins/sdd-implementation/.codex-plugin/plugin.json`,
`plugins/sdd-implementation/.plugin/plugin.json`,
`plugins/sdd-lite/.claude-plugin/plugin.json`,
`plugins/sdd-lite/.codex-plugin/plugin.json`,
`plugins/sdd-lite/.plugin/plugin.json`,
`plugins/sdd-quality-loop/.claude-plugin/plugin.json`,
`plugins/sdd-quality-loop/.codex-plugin/plugin.json`,
`plugins/sdd-quality-loop/.plugin/plugin.json`,
`plugins/sdd-review-loop/.claude-plugin/plugin.json`,
`plugins/sdd-review-loop/.codex-plugin/plugin.json`,
`plugins/sdd-review-loop/.plugin/plugin.json`,
`plugins/sdd-ship/.claude-plugin/plugin.json`,
`plugins/sdd-ship/.codex-plugin/plugin.json`,
`plugins/sdd-ship/.plugin/plugin.json`,
`.claude-plugin/marketplace.json`, `.agents/plugins/marketplace.json`,
`tests/validate-repository.ps1`, `CHANGELOG.md`

Data Migration: None

Breaking API: No

Rollback: Revert all synchronized `1.3.0` metadata and changelog changes as one
unit, restore the preceding version identity, and rerun repository plus
install/release validation to confirm the restored surfaces remain consistent.

### Goal

Publish one internally consistent v1.3.0 identity and document the integrity
gate, migration metadata, and compatibility-preserving precheck repair.

### Must Read

- `specs/workflow-state-integrity/requirements.md`
- `specs/workflow-state-integrity/design.md`
- `specs/workflow-state-integrity/acceptance-tests.md`
- `specs/workflow-state-integrity/traceability.md`

### Scope

Update every synchronized version constant and changelog entry, then run
repository/install/release validation without changing public commands.

### Done When

- [ ] A version-consistency assertion fails before the bump and passes with every release surface at `1.3.0`
- [ ] `CHANGELOG.md` lists workflow-state enforcement, bounded legacy migration, and the predecessor transition repair
- [ ] `pwsh -NoProfile -File tests/validate-repository.ps1` exits 0
- [ ] Install/release validation reports no version skew and no removed public command
- [ ] The implementation report records the atomic rollback procedure and evidence that the restored preceding version passes version-consistency validation
- [ ] `reports/implementation/workflow-state-integrity/T-006.md` records acceptance-first evidence and changed-file hashes

### Out of Scope

Publishing GitHub releases, changing public command names, or modifying
installer/uninstaller behavior.

### Blockers

T-004, T-005
