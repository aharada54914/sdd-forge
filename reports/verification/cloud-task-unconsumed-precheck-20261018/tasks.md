# Tasks: cloud-orchestration

Task-Review-Status: Pending

## Lifecycle and evidence

Generate Draft/Planned tasks for independent review. The user's 2026-10-18
approval and subsequent explicit repair/documentation/release instruction
apply to this scope; record that existing human authorization in the Approval
field only after task review passes. No cloud operation is authorized by it.
Only quality-gate may set Done. One implementation task runs at a time.
Dependency order controls shared files; T-005 extends the harness and public
CLI pattern released by T-004, T-006 extends both provider collectors, and
T-007 owns final packaging and suite registration.

All tasks produce reports/implementation/cloud-orchestration/T-NNN.md and
specs/cloud-orchestration/verification/T-NNN/ with actual Run ID, Task Attempt
Count, spec_revision, commands, exit codes, input/source/test hashes and
fixture/native/live classification. Frozen specs and historical reports are
never edited to record execution; use these addenda. The existing #423 scoped
repair is candidate work with retained prior logs, not an unimplemented change
or a retroactive quality-gate verdict.

Before every high-risk implementation, record each persisted evidence field,
its sibling contract/traceability counterpart and an executed failing mismatch
test. Commit failing tests before implementation; preserve Red→Green evidence.
Each high-risk task requires a fresh independent named reviewer verdict plus
formal quality evaluation. These obligations apply to its complete scope.

## Rollback for every task

Capture base revision and task-owned before-byte hashes, including existing
candidate changes. Test restoring only task-owned code/config in a disposable
checkout and rerun its baseline checks; retain commands/results. Never truncate
identity ledgers or restore historical approvals/reviews. Cloud resources are
not destroyed by code rollback; uncertain operations reconcile their original
IDs. Cleanup/corrective changes require separate environment authorization.
Disable the cloud entry/workflow on defects without weakening legacy gates.

## Live acceptance boundary

OQ-001 blocks live TEST-003/005/009 until owner-supplied scope, OIDC/IAM,
bootstrap, images, health/backup, budget and retention are available. Record
those cases as BLOCKED and keep affected tasks short of Done. Local tests,
compile/synthesis and host trials proceed. Release notes must distinguish
implemented capability from live validation, and tag publication is not a
claim that all cloud acceptance or production readiness has passed.

## T-001 Current foundation repair integration

Approval: Draft
Status: Planned
Risk: medium
Risk Rationale: Integrates scoped regression or delivery evidence without new runtime authority.
Required Workflow: acceptance-first
Data Migration: None
Breaking API: No

Requirements: REQ-001

### Goal

Integrate the already-authorized #423 maintenance repair into cloud delivery evidence; diagnose its historical stale-line failure before any additional fix. The existing RT-20261018-423 repair and its 53 checks are prior candidate evidence, not a new task PASS.

### Must Read

- requirements.md, design.md, acceptance-tests.md, traceability.md
- ux-spec.md, frontend-spec.md, infra-spec.md, security-spec.md, investigation.md
- ../../AGENTS.md and relevant existing consumers before changes

### Planned Files

- tests/sdd-domain-multitarget-foundation.tests.py
- specs/sdd-domain-multitarget/verification/T-001/current-consumer-inventory.json
- tests/run-all.sh, tests/run-all.ps1, tests/run-all-python.tests.ps1, .github/workflows/test.yml

### Done When

- AC-001 / TEST-001: python3 -B tests/sdd-domain-multitarget-foundation.tests.py passes; removal, relocation, duplicate heading and path escape fail as intended. Retain the exact historical failure log and diagnose the section reference before further changes.
- Publish a feature-local current inventory reference and historical-byte comparison under verification/T-001/; preserve historical T-001/T-002 source and evidence bytes. Run current T-003/T-004 regressions and distinguish existing task status from these results.
- All normal Bash, PowerShell and hosted CI drivers invoke the current foundation/boundary suite; tests/run-all-python.tests.ps1 passes with the additional suite.
- Rollback procedure is documented and tested in a disposable checkout, with before/after hashes and baseline test output in the task verification addendum.

### Blockers

None

## T-002 Strict cloud artifact contracts

Approval: Draft
Status: Planned
Risk: high
Risk Rationale: Changes externally visible contracts, trust or verification boundaries.
Required Workflow: tdd
Data Migration: None
Breaking API: No

Requirements: REQ-004, REQ-010

### Goal

Implement only strict cloud artifact parsing, canonical contained evidence paths, input/transitive dependency locks, digests and result envelopes. These establish integrity, never cloud authority. Enumerate every schema mirror, validator and emitter affected before edits.

### Must Read

- requirements.md, design.md, acceptance-tests.md, traceability.md
- ux-spec.md, frontend-spec.md, infra-spec.md, security-spec.md, investigation.md
- ../../AGENTS.md and relevant existing consumers before changes

### Planned Files

- contracts/cloud-*.schema.json
- plugins/sdd-quality-loop/scripts/cloud_contracts.py
- tests/cloud-orchestration-contracts.tests.py

### Done When

- AC-004 / TEST-004 (contract layer): mutating every bound scope, input, compiled artifact, asset, policy, verification or dependency digest is rejected. Reject unlocked transitive dependencies and tool-schema changes.
- AC-010 / TEST-010 (artifact layer): duplicate keys, unknown fields/versions, NaN, invalid UTC/digests, path traversal, symlink components, overwrite and secret-canary publication are rejected by python3 -B tests/cloud-orchestration-contracts.tests.py.
- Result and input-error envelope schemas enforce documented fields, states and exit mapping; invalid identity does not produce an invented run receipt.
- Red→Green evidence includes failing tests committed before implementation, the field/counterpart/mismatch preflight, spec_revision and a named independent reviewer verdict with no blocking findings in the task report.
- Rollback procedure is documented and tested in a disposable checkout, with before/after hashes and baseline test output in the task verification addendum.

### Blockers

None

## T-003 Protected CI admission

Approval: Draft
Status: Planned
Risk: high
Risk Rationale: Changes externally visible contracts, trust or verification boundaries.
Required Workflow: tdd
Data Migration: None
Breaking API: No

Requirements: REQ-005, REQ-006

### Goal

Implement authenticated GitHub/provider admission and immutable prepare/apply receipts at a reusable write boundary. Governed CI templates obtain separate protected environment OIDC identities; fixed trusted code and policy are external to deployment inputs. Own replay/scope admission, not provider resource execution.

### Must Read

- requirements.md, design.md, acceptance-tests.md, traceability.md
- ux-spec.md, frontend-spec.md, infra-spec.md, security-spec.md, investigation.md
- ../../AGENTS.md and relevant existing consumers before changes

### Planned Files

- plugins/sdd-quality-loop/scripts/cloud_authorization.py
- templates/cloud/github-*.yml
- templates/cloud/iam/*
- tests/cloud-orchestration-execution.tests.py

### Done When

- AC-005 / TEST-005: fake local receipts/flags, absent/revoked/expired approval, wrong actor/run/environment/scope, denied history and run_attempt > 1 yield zero write submissions; fixtures are labeled and do not claim live IAM.
- AC-006 / TEST-006 (admission layer): canonical account/subscription-region workflow concurrency uses cancel-in-progress false; repeated receipt and changed manifest are rejected. Native protected environment/OIDC policies and exclusive-writer prerequisites are documented and tested with deterministic API transports.
- python3 -B tests/cloud-orchestration-execution.tests.py runs the admission cases; missing authenticated metadata or provider principal fails closed at each prepare/apply call site.
- Red→Green evidence includes failing tests committed before implementation, the field/counterpart/mismatch preflight, spec_revision and a named independent reviewer verdict with no blocking findings in the task report.
- Rollback procedure is documented and tested in a disposable checkout, with before/after hashes and baseline test output in the task verification addendum.

### Blockers

T-002

## T-004 Azure Bicep execution path

Approval: Draft
Status: Planned
Risk: high
Risk Rationale: Changes externally visible contracts, trust or verification boundaries.
Required Workflow: tdd
Data Migration: None
Breaking API: No

Requirements: REQ-002, REQ-003, REQ-007

### Goal

Deliver the Azure provider CLI, upstream routing lock and one private VM Bicep example. Route/plan/validate are unprivileged; prepare/apply use T-003 admission. Preserve existing IaC ownership; exact artifact incremental deployment and semantic what-if comparison are the only initial Azure execution path.

### Must Read

- requirements.md, design.md, acceptance-tests.md, traceability.md
- ux-spec.md, frontend-spec.md, infra-spec.md, security-spec.md, investigation.md
- ../../AGENTS.md and relevant existing consumers before changes

### Planned Files

- plugins/sdd-azure-cloud/scripts/*
- plugins/sdd-azure-cloud/examples/*
- plugins/sdd-azure-cloud/references/*
- tests/cloud-orchestration-routing.tests.py
- tests/cloud-orchestration-execution.tests.py

### Done When

- AC-002 / TEST-002 (Azure), AC-003 / TEST-003 (Azure), AC-007 / TEST-007 (Azure): select one Bicep owner, reject mixed/unsupported owners/import, synthesize the private network/identity/monitoring example with a pinned real Bicep compiler; missing required backup and destructive referenced-resource changes block.
- AC-004 / TEST-004 (Azure), AC-006 / TEST-006 (Azure): changed what-if semantics block before apply; timeout preserves original deployment ID and reconcile never submits a second apply. Real empty preview yields NO_CHANGE and zero apply submissions without an invented deployment ID (AC-009 / TEST-009 Azure no-op).
- python3 -B tests/cloud-orchestration-routing.tests.py and python3 -B tests/cloud-orchestration-execution.tests.py pass Azure cases, including direct CLI argument/output safety and bounded polling. Retain real compile output separately from transport fixtures.
- Red→Green evidence includes failing tests committed before implementation, the field/counterpart/mismatch preflight, spec_revision and a named independent reviewer verdict with no blocking findings in the task report.
- Rollback procedure is documented and tested in a disposable checkout, with before/after hashes and baseline test output in the task verification addendum.

### Blockers

T-002, T-003

## T-005 AWS CDK execution path

Approval: Draft
Status: Planned
Risk: high
Risk Rationale: Changes externally visible contracts, trust or verification boundaries.
Required Workflow: tdd
Data Migration: None
Breaking API: No

Requirements: REQ-002, REQ-003, REQ-007

### Goal

Deliver AWS provider CLI, upstream routing lock and one private EC2 CDK example. Consume the shared public CLI decisions and test harness released by T-004; freeze assembly/assets, publish assets only in authorized prepare and execute the exact CloudFormation Change Set. No synthesis/deploy/hotswap at apply, implicit bootstrap or ownership migration.

### Must Read

- requirements.md, design.md, acceptance-tests.md, traceability.md
- ux-spec.md, frontend-spec.md, infra-spec.md, security-spec.md, investigation.md
- ../../AGENTS.md and relevant existing consumers before changes

### Planned Files

- plugins/sdd-aws-cloud/scripts/*
- plugins/sdd-aws-cloud/examples/*
- plugins/sdd-aws-cloud/references/*
- tests/cloud-orchestration-routing.tests.py
- tests/cloud-orchestration-execution.tests.py

### Done When

- AC-002 / TEST-002 (AWS), AC-003 / TEST-003 (AWS), AC-007 / TEST-007 (AWS): one CDK owner, mixed/unsupported owner/import denial, real pinned CDK synthesis of private network/identity/monitoring, missing backup denial, referenced-resource destructive change denial.
- AC-004 / TEST-004 (AWS), AC-006 / TEST-006 (AWS): changed asset/template/ARN blocks; prepare asset publication requires prepare admission; exact Change Set execution uses original token; timeout reconciles and never resubmits. Real empty preview yields NO_CHANGE with zero apply and no invented deployment ID (AC-009 / TEST-009 AWS no-op).
- python3 -B tests/cloud-orchestration-routing.tests.py and python3 -B tests/cloud-orchestration-execution.tests.py pass both providers; retain real CDK synthesis and package integrity evidence separately from fixtures.
- Red→Green evidence includes failing tests committed before implementation, the field/counterpart/mismatch preflight, spec_revision and a named independent reviewer verdict with no blocking findings in the task report.
- Rollback procedure is documented and tested in a disposable checkout, with before/after hashes and baseline test output in the task verification addendum.

### Blockers

T-002, T-003, T-004

## T-006 Cloud observation and verification dispatch

Approval: Draft
Status: Planned
Risk: high
Risk Rationale: Changes externally visible contracts, trust or verification boundaries.
Required Workflow: tdd
Data Migration: None
Breaking API: No

Requirements: REQ-006, REQ-008, REQ-009, REQ-010

### Goal

Implement read-only provider collectors and a strict reducer plus explicit versioned cloud profile dispatch in the existing protected registry/evaluator consumers. Keep legacy code/shell/docs/spec gates unchanged. Multi-unit dependencies consume verified receipts, not task statuses. Review all schema mirrors and protected-file projections before editing them.

### Must Read

- requirements.md, design.md, acceptance-tests.md, traceability.md
- ux-spec.md, frontend-spec.md, infra-spec.md, security-spec.md, investigation.md
- ../../AGENTS.md and relevant existing consumers before changes

### Planned Files

- plugins/sdd-quality-loop/scripts/cloud_verification.py
- plugins/sdd-quality-loop/scripts/check-contract*, evaluate-selected-plan.py
- contracts/*verification*, plugins/sdd-quality-loop/contracts/*verification*
- plugins/sdd-quality-loop/references/*registry*, *guard* and generated projections
- plugins/sdd-azure-cloud/scripts/*, plugins/sdd-aws-cloud/scripts/*
- tests/cloud-orchestration-verification.tests.py

### Done When

- AC-008 / TEST-008: deterministic protected cloud profile selection rejects unsupported version/missing IaC checks; original legacy regression cases retain all required checks without synthetic TDD/unit observations.
- AC-009 / TEST-009 and AC-010 / TEST-010 (observation layer): actual network, identity, received monitoring signal, workload health and required backup checks bind native IDs/principal/time/digests; failure, missing permission, stale data, tamper or incomplete evidence prevent VERIFIED/EVIDENCE_COMPLETE. Fixture transports explicitly remain synthetic.
- AC-006 / TEST-006 (dependency layer): execute A succeeds, independent B fails, C depends on B; C has zero prepare/apply submissions, A receipt is unchanged, aggregate is not verified. Cycles and unverified predecessor receipts block.
- python3 -B tests/cloud-orchestration-verification.tests.py and affected existing contract/selected-plan/guard regressions pass. Record sandbox TEST-003/005/009 as blocked if OQ-001 inputs are absent; code completion is not live acceptance or task Done.
- Red→Green evidence includes failing tests committed before implementation, the field/counterpart/mismatch preflight, spec_revision and a named independent reviewer verdict with no blocking findings in the task report.
- Rollback procedure is documented and tested in a disposable checkout, with before/after hashes and baseline test output in the task verification addendum.

### Blockers

T-004, T-005

## T-007 Installed cloud skill integration

Approval: Draft
Status: Planned
Risk: high
Risk Rationale: Changes externally visible contracts, trust or verification boundaries.
Required Workflow: tdd
Data Migration: None
Breaking API: No

Requirements: REQ-011, REQ-012

### Goal

Package both provider skills and wire bootstrap to the same strict CLI. Reuse sdd-quality-loop shared validation through explicit install dependency, without making Core a provider executor. Register the four cloud suites in normal drivers and extend existing installer/visibility/protection contracts for the two explicit-entry plugins.

### Must Read

- requirements.md, design.md, acceptance-tests.md, traceability.md
- ux-spec.md, frontend-spec.md, infra-spec.md, security-spec.md, investigation.md
- ../../AGENTS.md and relevant existing consumers before changes

### Planned Files

- plugins/sdd-azure-cloud/skills/orchestrate/SKILL.md and plugin manifests
- plugins/sdd-aws-cloud/skills/orchestrate/SKILL.md and plugin manifests
- plugins/sdd-bootstrap/skills/*, plugins/sdd-bootstrap/scripts/*routing*
- install.sh, install.ps1, uninstall.sh, uninstall.ps1, marketplace manifests
- tests/validate-repository.ps1, tests/run-all.sh, tests/run-all.ps1, .github/workflows/test.yml
- tests/cloud-orchestration-routing.tests.py and installation/visibility suites

### Done When

- AC-011 / TEST-011: install each plugin in an isolated temporary destination; bootstrap and direct installed entries resolve the same request contract and reject unauthorized prepare/apply; uninstall preserves shared dependencies still needed by other plugins.
- AC-012 / TEST-012: all four deterministic suites run through normal drivers; execute an actual verify-codex host routing/denial trial with native invocation evidence. Unavailable auth is explicitly BLOCKED, never fixture PASS.
- Existing non-cloud bootstrap, mandatory seven Phase 1 outputs, installer/visibility and guard regression suites pass. Name native Windows junction coverage as pending until actual hosted Windows CI exercises it.
- Red→Green evidence includes failing tests committed before implementation, the field/counterpart/mismatch preflight, spec_revision and a named independent reviewer verdict with no blocking findings in the task report.
- Rollback procedure is documented and tested in a disposable checkout, with before/after hashes and baseline test output in the task verification addendum.

### Blockers

T-001, T-006

## T-008 Operator documentation and tagged release

Approval: Draft
Status: Planned
Risk: medium
Risk Rationale: Integrates scoped regression or delivery evidence without new runtime authority.
Required Workflow: acceptance-first
Data Migration: None
Breaking API: No

Requirements: REQ-013, REQ-014

### Goal

Complete the approved documentation matrix and publish the exact tested release commit/tag using existing release tooling. Deliver actual limitations and sandbox readiness, not unimplemented capability claims. No automatic merge, production write, tag replacement or asset-publication claim.

### Must Read

- requirements.md, design.md, acceptance-tests.md, traceability.md
- ux-spec.md, frontend-spec.md, infra-spec.md, security-spec.md, investigation.md
- ../../AGENTS.md and relevant existing consumers before changes

### Planned Files

- README.md, CHANGELOG.md, docs/cloud-orchestration.md, docs/workflow-guide.md
- docs/skill-reference.md, docs/contributor/skill-reference-detail.md, docs/architecture/overview.md, docs/adr/README.md, docs/contributor/release-runbook.md
- provider skill/reference/example documentation
- release version manifests, marketplace versions and validators via scripts/bump-version.sh
- reports/verification/cloud-orchestration-release.md

### Done When

- AC-013 / TEST-013: every design documentation-matrix surface describes the implemented CLI, installation, separate prepare/apply approvals, unsupported owners, recovery and observed limits; local links resolve and documented example commands validate.
- AC-014 / TEST-014: select an unused semantic version from remote tags, update CHANGELOG and run scripts/bump-version.sh; required release suites, repository validation and exact-commit test.yml CI pass. Record actual CI URL and native OS results.
- Publish a new annotated remote tag resolving to that exact commit; compare existing remote tags unchanged. Report tag, commit, CI, release asset status and live sandbox limitations in reports/verification/cloud-orchestration-release.md. If required CI fails, fix and retest before tagging.
- Rollback procedure is documented and tested in a disposable checkout, with before/after hashes and baseline test output in the task verification addendum.

### Blockers

T-007

