# Tasks: cloud-orchestration

Task-Review-Status: Passed

## Lifecycle and evidence

Generate Draft/Planned tasks for independent review. The user's 2026-10-18
approval and subsequent explicit repair/documentation/release instruction
apply to this scope; record that existing human authorization in the Approval
field only after task review passes. No cloud operation is authorized by it.
Only quality-gate may set Done. One implementation task runs at a time.
Dependency order controls shared files; T-005 extends the local CLI pattern released by T-004; T-012 then T-013
extend the governed execution harness. T-006 extends both provider collectors;
T-009 owns protected profile dispatch, T-010 consumes its verified dependency
receipts, T-007 owns packaging/install lifecycle, and T-011 owns routing and suite/host integration.

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

Approval: Approved (user-recorded 2026-10-18T04:41:34Z)
Status: Done
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

Approval: Approved (user-recorded 2026-10-18T04:41:34Z)
Status: Done
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

Approval: Approved (user-recorded 2026-10-18T04:41:34Z)
Status: Implementation Complete
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

## T-004 Azure routing and local Bicep preparation

Approval: Approved (user-recorded 2026-10-18T04:41:34Z)
Status: Done
Risk: high
Risk Rationale: Changes externally visible contracts, trust or verification boundaries.
Required Workflow: tdd
Data Migration: None
Breaking API: No

Requirements: REQ-002, REQ-003, REQ-007

### Goal

Deliver Azure route/plan/validate CLI operations, the pinned upstream dependency closure and a minimal private VM Bicep example. Own unprivileged owner detection, exact compile inputs and local policy checks. Credentialed prepare/apply and recovery belong to T-012.

### Must Read

- requirements.md, design.md, acceptance-tests.md, traceability.md
- ux-spec.md, frontend-spec.md, infra-spec.md, security-spec.md, investigation.md
- ../../AGENTS.md and relevant existing consumers before changes

### Planned Files

- plugins/sdd-azure-cloud/scripts/* local routing/validation only
- plugins/sdd-azure-cloud/examples/* and references/*
- tests/cloud-orchestration-routing.tests.py

### Done When

- AC-002 / TEST-002 (Azure local), AC-003 / TEST-003 (Azure compile), AC-007 / TEST-007 (Azure local policy): one Bicep owner, mixed/unsupported owner and import denial, real pinned Bicep compilation with private network/identity/monitoring and mandatory-backup validation.
- python3 -B tests/cloud-orchestration-routing.tests.py passes Azure local cases. Runtime dependency closure binds consumed/transitive upstream files and actual tool versions; no cloud credentials are needed.
- Red→Green evidence includes failing tests committed before implementation, the field/counterpart/mismatch preflight, spec_revision and a named independent reviewer verdict with no blocking findings in the task report.
- Rollback procedure is documented and tested in a disposable checkout, with before/after hashes and baseline test output in the task verification addendum.

### Blockers

T-002

## T-005 AWS routing and local CDK preparation

Approval: Approved (user-recorded 2026-10-18T04:41:34Z)
Status: Done
Risk: high
Risk Rationale: Changes externally visible contracts, trust or verification boundaries.
Required Workflow: tdd
Data Migration: None
Breaking API: No

Requirements: REQ-002, REQ-003, REQ-007

### Goal

Deliver AWS route/plan/validate CLI operations, pinned upstream references and a minimal private EC2 CDK example. Reuse the public local CLI pattern and routing suite from T-004. Freeze complete assembly/assets locally; actual publication, Change Set execution and recovery belong to T-013.

### Must Read

- requirements.md, design.md, acceptance-tests.md, traceability.md
- ux-spec.md, frontend-spec.md, infra-spec.md, security-spec.md, investigation.md
- ../../AGENTS.md and relevant existing consumers before changes

### Planned Files

- plugins/sdd-aws-cloud/scripts/* local routing/validation only
- plugins/sdd-aws-cloud/examples/* and references/*
- tests/cloud-orchestration-routing.tests.py

### Done When

- AC-002 / TEST-002 (AWS local), AC-003 / TEST-003 (AWS synthesis), AC-007 / TEST-007 (AWS local policy): one CDK owner, mixed/unsupported owner and import denial, real pinned CDK synthesis with private network/identity/monitoring and mandatory-backup validation.
- python3 -B tests/cloud-orchestration-routing.tests.py passes both local provider paths. Record assembly/asset/package integrity and real synth output separately from fixtures; no publish or implicit CDK bootstrap occurs.
- Red→Green evidence includes failing tests committed before implementation, the field/counterpart/mismatch preflight, spec_revision and a named independent reviewer verdict with no blocking findings in the task report.
- Rollback procedure is documented and tested in a disposable checkout, with before/after hashes and baseline test output in the task verification addendum.

### Blockers

T-004

## T-012 Azure governed execution and recovery

Approval: Approved (user-recorded 2026-10-18T04:41:34Z)
Status: Implementation Complete
Risk: high
Risk Rationale: Changes externally visible contracts, trust or verification boundaries.
Required Workflow: tdd
Data Migration: None
Breaking API: No

Requirements: REQ-003, REQ-004, REQ-006, REQ-007, REQ-009

### Goal

Extend the Azure adapter with governed prepare/apply and read-only reconcile. Consume exact local artifacts from T-004 and admission from T-003. Enforce incremental deployment and semantic what-if comparison at the write site. Resource health collectors remain T-006.

### Must Read

- requirements.md, design.md, acceptance-tests.md, traceability.md
- ux-spec.md, frontend-spec.md, infra-spec.md, security-spec.md, investigation.md
- ../../AGENTS.md and relevant existing consumers before changes

### Planned Files

- plugins/sdd-azure-cloud/scripts/* execution/reconciliation only
- tests/cloud-orchestration-execution.tests.py

### Done When

- AC-003 / TEST-003 (Azure executor), AC-004 / TEST-004 (Azure), AC-007 / TEST-007 (Azure preview): only selected executor runs; changed template/scope/what-if semantics or destructive referenced-resource mutations block before apply.
- AC-006 / TEST-006 (Azure) and AC-009 / TEST-009 (Azure no-op): timeout retains original deployment ID and reconcile never submits a second apply; empty preview yields genuine NO_CHANGE evidence, zero apply submissions and no fabricated deployment ID.
- python3 -B tests/cloud-orchestration-execution.tests.py passes Azure admission/execution/recovery cases, including direct CLI denial and bounded polling.
- Red→Green evidence includes failing tests committed before implementation, the field/counterpart/mismatch preflight, spec_revision and a named independent reviewer verdict with no blocking findings in the task report.
- Rollback procedure is documented and tested in a disposable checkout, with before/after hashes and baseline test output in the task verification addendum.

### Blockers

T-003, T-004

## T-013 AWS governed Change Set execution

Approval: Approved (user-recorded 2026-10-18T04:41:34Z)
Status: Implementation Complete
Risk: high
Risk Rationale: Changes externally visible contracts, trust or verification boundaries.
Required Workflow: tdd
Data Migration: None
Breaking API: No

Requirements: REQ-003, REQ-004, REQ-005, REQ-006, REQ-007, REQ-009

### Goal

Extend AWS with authorized exact-asset publication, Change Set preparation/execution and read-only recovery. Consume local assembly from T-005, the admission boundary from T-003 and the execution harness released by T-012. Resource health collectors remain T-006; apply never resynthesizes or invokes CDK deploy/hotswap.

### Must Read

- requirements.md, design.md, acceptance-tests.md, traceability.md
- ux-spec.md, frontend-spec.md, infra-spec.md, security-spec.md, investigation.md
- ../../AGENTS.md and relevant existing consumers before changes

### Planned Files

- plugins/sdd-aws-cloud/scripts/* execution/reconciliation only
- tests/cloud-orchestration-execution.tests.py

### Done When

- AC-003 / TEST-003 (AWS executor), AC-004 / TEST-004 (AWS), AC-005 / TEST-005 (AWS prepare), AC-007 / TEST-007 (AWS preview): only selected executor runs; changed asset/template/ARN blocks; asset publication requires prepare admission; destructive referenced-resource mutations block.
- AC-006 / TEST-006 (AWS) and AC-009 / TEST-009 (AWS no-op): exact Change Set execution uses the original token, timeout reconciles without resubmission, and genuine empty preview yields NO_CHANGE with zero apply and no fabricated deployment ID.
- python3 -B tests/cloud-orchestration-execution.tests.py passes both providers with fixed command arguments and bounded polling.
- Red→Green evidence includes failing tests committed before implementation, the field/counterpart/mismatch preflight, spec_revision and a named independent reviewer verdict with no blocking findings in the task report.
- Rollback procedure is documented and tested in a disposable checkout, with before/after hashes and baseline test output in the task verification addendum.

### Blockers

T-005, T-012

## T-006 Provider observations and verification reducer

Approval: Approved (user-recorded 2026-10-18T04:41:34Z)
Status: Implementation Complete
Risk: high
Risk Rationale: Changes externally visible contracts, trust or verification boundaries.
Required Workflow: tdd
Data Migration: None
Breaking API: No

Requirements: REQ-009, REQ-010

### Goal

Implement read-only collectors in both provider adapters and a strict reducer consuming authenticated cloud-observation/v1 records. Check actual resource, network, identity, monitoring signal, workload and mandatory backup state. This task does not change registry dispatch or dependency orchestration.

### Must Read

- requirements.md, design.md, acceptance-tests.md, traceability.md
- ux-spec.md, frontend-spec.md, infra-spec.md, security-spec.md, investigation.md
- ../../AGENTS.md and relevant existing consumers before changes

### Planned Files

- plugins/sdd-quality-loop/scripts/cloud_verification.py
- plugins/sdd-azure-cloud/scripts/*, plugins/sdd-aws-cloud/scripts/*
- tests/cloud-orchestration-verification.tests.py

### Done When

- AC-009 / TEST-009 and AC-010 / TEST-010 (observation layer): actual network, identity, received monitoring signal, workload health and required backup checks bind native IDs/principal/time/digests; failure, missing permission, stale data, tamper or incomplete evidence prevent VERIFIED/EVIDENCE_COMPLETE. Fixture transports explicitly remain synthetic.
- python3 -B tests/cloud-orchestration-verification.tests.py passes observation/reduction cases with both provider transports; missing scope/OIDC prerequisites leave live TEST-003/005/009 BLOCKED in the addendum, not PASS.
- Red→Green evidence includes failing tests committed before implementation, the field/counterpart/mismatch preflight, spec_revision and a named independent reviewer verdict with no blocking findings in the task report.
- Rollback procedure is documented and tested in a disposable checkout, with before/after hashes and baseline test output in the task verification addendum.

### Blockers

T-012, T-013

## T-009 Protected cloud profile dispatch

Approval: Approved (user-recorded 2026-10-18T04:41:34Z)
Status: Done
Risk: high
Risk Rationale: Changes externally visible contracts, trust or verification boundaries.
Required Workflow: tdd
Data Migration: None
Breaking API: No

Requirements: REQ-008

### Goal

Add explicit versioned cloud verification dispatch to existing protected registry/evaluator consumers using T-006 observation/reducer contracts. Survey every schema mirror, parser, emitter and protected projection; retain the old version untouched and reject unknown cloud fields/versions. No provider execution or dependency scheduling belongs here.

### Must Read

- requirements.md, design.md, acceptance-tests.md, traceability.md
- ux-spec.md, frontend-spec.md, infra-spec.md, security-spec.md, investigation.md
- ../../AGENTS.md and relevant existing consumers before changes

### Planned Files

- contracts/*verification*, plugins/sdd-quality-loop/contracts/*verification*
- plugins/sdd-quality-loop/scripts/check-contract*, evaluate-selected-plan.py
- plugins/sdd-quality-loop/references/*registry*, *guard* and generated projections
- tests/cloud-orchestration-verification.tests.py

### Done When

- AC-008 / TEST-008: deterministic protected cloud profile selection rejects unsupported version/missing IaC checks; original legacy regression cases retain all required checks without synthetic TDD/unit observations.
- python3 -B tests/cloud-orchestration-verification.tests.py profile cases and existing contract/selected-plan/guard suites pass; a frozen map of all affected consumers and old/new version behavior is recorded in the task addendum.
- Red→Green evidence includes failing tests committed before implementation, the field/counterpart/mismatch preflight, spec_revision and a named independent reviewer verdict with no blocking findings in the task report.
- Rollback procedure is documented and tested in a disposable checkout, with before/after hashes and baseline test output in the task verification addendum.

### Blockers

T-006

## T-010 Deployment dependency receipts

Approval: Approved (user-recorded 2026-10-18T04:41:34Z)
Status: Done
Risk: high
Risk Rationale: Changes externally visible contracts, trust or verification boundaries.
Required Workflow: tdd
Data Migration: None
Breaking API: No

Requirements: REQ-006

### Goal

Implement the dependency receipt validator and ordering helper for per-unit orchestration. Consume the selected profile/verified receipts from T-009 and provider lifecycle outputs. Preserve successful independent units on partial failure; do not introduce atomic rollback or a generic resource language. Integrate predecessor receipt admission into the common cloud_authorization.py write boundary so direct provider entry points cannot bypass dependency checks.

### Must Read

- requirements.md, design.md, acceptance-tests.md, traceability.md
- ux-spec.md, frontend-spec.md, infra-spec.md, security-spec.md, investigation.md
- ../../AGENTS.md and relevant existing consumers before changes

### Planned Files

- plugins/sdd-quality-loop/scripts/cloud_dependencies.py
- tests/cloud-orchestration-verification.tests.py
- plugins/sdd-quality-loop/scripts/cloud_authorization.py dependency admission only

### Done When

- AC-006 / TEST-006 (dependency layer): execute A succeeds, independent B fails, C depends on B; C has zero prepare/apply submissions, A receipt is unchanged, aggregate is not verified. Cycles and unverified predecessor receipts block.
- python3 -B tests/cloud-orchestration-verification.tests.py dependency cases reject cycles, changed/missing receipts and wrong run/unit/profile; dispatch depends on verified predecessors, and existing successful evidence is never overwritten.
- Red→Green evidence includes failing tests committed before implementation, the field/counterpart/mismatch preflight, spec_revision and a named independent reviewer verdict with no blocking findings in the task report.
- Rollback procedure is documented and tested in a disposable checkout, with before/after hashes and baseline test output in the task verification addendum.

### Blockers

T-009

## T-007 Cloud plugin packaging and install lifecycle

Approval: Approved (user-recorded 2026-10-18T04:41:34Z)
Status: Done
Risk: high
Risk Rationale: Changes externally visible contracts, trust or verification boundaries.
Required Workflow: tdd
Data Migration: None
Breaking API: No

Requirements: REQ-011

### Goal

Package the two provider skills and their explicit shared-validation install dependency. Own plugin manifests, marketplace entries and cross-platform install/uninstall lifecycle. Bootstrap routing, suite registration and native host invocation belong to T-011. The installed shared runtime must include cloud_contracts.py, cloud_authorization.py, cloud_verification.py and cloud_dependencies.py. T-010 produces the last module and its call-site integration for mandatory predecessor receipt admission; packaging before that output exists cannot provide the complete installed CLI.

### Must Read

- requirements.md, design.md, acceptance-tests.md, traceability.md
- ux-spec.md, frontend-spec.md, infra-spec.md, security-spec.md, investigation.md
- ../../AGENTS.md and relevant existing consumers before changes

### Planned Files

- plugins/sdd-azure-cloud/skills/orchestrate/SKILL.md and plugin manifests
- plugins/sdd-aws-cloud/skills/orchestrate/SKILL.md and plugin manifests
- install.sh, install.ps1, uninstall.sh, uninstall.ps1, marketplace manifests
- tests/validate-repository.ps1 and installation/visibility suites

### Done When

- AC-011 / TEST-011 (distribution): install each plugin into a temporary destination, directly invoke its installed CLI with the shared module present, and assert unauthorized prepare/apply is blocked. Uninstall preserves dependencies still needed by another installed plugin.
- Existing installer/visibility suites pass with both explicit-entry plugins registered. Versioned provider manifests, installed references and shared dependency locations resolve.
- The temporary installed-package test imports all four shared runtime modules and exercises predecessor-receipt denial through the installed CLI; omitting T-010 cloud_dependencies.py fails that test.
- Red→Green evidence includes failing tests committed before implementation, the field/counterpart/mismatch preflight, spec_revision and a named independent reviewer verdict with no blocking findings in the task report.
- Rollback procedure is documented and tested in a disposable checkout, with before/after hashes and baseline test output in the task verification addendum.

### Blockers

T-010

## T-011 Bootstrap routing and host integration

Approval: Approved (user-recorded 2026-10-18T04:41:34Z)
Status: Planned
Risk: high
Risk Rationale: Changes externally visible contracts, trust or verification boundaries.
Required Workflow: tdd
Data Migration: None
Breaking API: No

Requirements: REQ-011, REQ-012

### Goal

Connect bootstrap to the installed cloud entries released by T-007 using the canonical request contract. Register the four cloud regression suites and execute isolated host routing/denial trials. Own final integration tests and driver wiring, not install lifecycle.

### Must Read

- requirements.md, design.md, acceptance-tests.md, traceability.md
- ux-spec.md, frontend-spec.md, infra-spec.md, security-spec.md, investigation.md
- ../../AGENTS.md and relevant existing consumers before changes

### Planned Files

- plugins/sdd-bootstrap/skills/*, plugins/sdd-bootstrap/scripts/*routing*
- tests/run-all.sh, tests/run-all.ps1, .github/workflows/test.yml
- tests/cloud-orchestration-routing.tests.py and host verification addenda

### Done When

- AC-011 / TEST-011 (routing): bootstrap and direct installed entries reach the same supported route; safeguards hold for direct prepare/apply. Existing non-cloud bootstrap and all seven Phase 1 documents remain compatible.
- AC-012 / TEST-012: all four cloud suites execute through normal drivers; a real verify-codex host routing/denial trial records native invocation identity and outputs. Unavailable host authentication is explicitly BLOCKED, never replaced by fixture PASS.
- Existing bootstrap and guard regression suites pass. Record native Windows junction coverage as pending until the actual hosted Windows CI executes it.
- Red→Green evidence includes failing tests committed before implementation, the field/counterpart/mismatch preflight, spec_revision and a named independent reviewer verdict with no blocking findings in the task report.
- Rollback procedure is documented and tested in a disposable checkout, with before/after hashes and baseline test output in the task verification addendum.

### Blockers

T-001, T-007

## T-008 Operator documentation and tagged release

Approval: Approved (user-recorded 2026-10-18T04:41:34Z)
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

T-011

