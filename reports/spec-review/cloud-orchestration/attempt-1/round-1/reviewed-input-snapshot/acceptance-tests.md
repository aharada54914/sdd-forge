# Acceptance Tests: Azure / AWS cloud orchestration

| Acceptance Criterion | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001: A current section-anchored inventory resolves the seven-file requirement; changing/removing the anchored requirement fails CI; historical evidence bytes remain unchanged. Historical task states are not promoted from test success. | REQ-001 | TEST-001 | integration | Current inventory checker, suite inventory and CI driver | Planned |
| AC-002: Each supported fixture produces exactly one executor and IaC owner; mixed owners, unsupported Terraform/SAM/azd/raw-CFN execution and import produce BLOCKED without provider writes. | REQ-002 | TEST-002 | unit/integration | Router and entry points | Planned |
| AC-003: Azure Bicep VM and AWS CDK EC2 examples synthesize/validate with private networking, scoped identity and monitoring; missing required backup blocks. Each calls only its selected executor. | REQ-003 | TEST-003 | integration/live sandbox | Two provider adapters and examples | Planned |
| AC-004: Mutating any bound scope/input/compiled artifact/asset/policy/verification/dependency digest after approval blocks the write, including changed transitive skill input or tool schema. | REQ-004 | TEST-004 | adversarial integration | Lock and authorization validation at executor call site | Planned |
| AC-005: No approval, fabricated JSON approval, wrong actor/run/environment, revoked or expired approval, and unauthorized prepare asset publication are rejected. Valid protected CI prepare/apply jobs reach only their permitted operations. | REQ-005 | TEST-005 | integration/live sandbox | CI authorization boundary and IAM policy examples | Planned |
| AC-006: Concurrent overlapping scopes cannot apply together; stale/replayed receipts fail; timeout reconciles the original provider ID and never submits another apply automatically. | REQ-006 | TEST-006 | adversarial integration | CI concurrency, operation receipts, reconcile | Planned |
| AC-007: Referenced brownfield resources cannot be deleted/replaced/mutated outside approved attachments; managed resources preserve their owner and identifiers; import blocks. | REQ-007 | TEST-007 | integration | Preview policy and ownership classifier | Planned |
| AC-008: Cloud profile checks are selected deterministically from protected registry/versioned contracts; legacy profile fixtures retain their required checks; unsupported versions and missing IaC checks fail closed without fake TDD/unit observations. | REQ-008 | TEST-008 | contract/regression | Registry, schemas, evaluator and all contract consumers | Planned |
| AC-009: Deployment success with failed network/identity/monitoring/workload or mandatory backup check is not VERIFIED; stale/unknown/missing observations block; all required genuine observations allow verification. | REQ-009 | TEST-009 | integration/live sandbox | Collectors and verification reducer | Planned |
| AC-010: Evidence binds native IDs, principal, timestamps, input digests and actual results; tampered evidence, traversal, symlink escapes and secret-bearing responses cannot produce complete evidence. | REQ-010 | TEST-010 | adversarial integration | Evidence writer and reader | Planned |
| AC-011: Bootstrap and both installed plugin entries reach the supported route; prepare/apply safeguards hold at the call site even when invoked directly. Existing non-cloud bootstrap and seven Phase 1 documents remain compatible. | REQ-011 | TEST-011 | integration/isolated host | Bootstrap routing, plugin packaging, verify-codex profile | Planned |
| AC-012: The regression suite exercises both success and denial paths; isolated host reports cite actual invocation evidence; absent credentials/host auth are explicitly untested, never substituted with fixture PASS. | REQ-012 | TEST-012 | regression/behavior | CI suite and isolated verification report | Planned |

## Entry Point Safety

These are CLI/skill entry points, with no graphical UI. TEST-011 must cover
bootstrap → cloud router and direct plugin invocation. TEST-005 must verify
authorization at the write call site, not just prompt wording. TEST-006 must
prove no second cloud submission on an indeterminate first submission.

## Provider-specific Observations

TEST-004 must change Azure what-if semantic content between preview and apply
and observe reapproval, and must substitute an AWS Change Set ARN or template
and observe denial. TEST-003/009 live trials must query actual deployed resource
IDs, effective network/identity configuration, monitoring signals and an
explicit workload health probe. Offline fixtures validate interpretation only.

## Evidence Rules

Persist results in new verification addenda after review freeze. Do not update
this table to imply execution after it becomes hash-bound. Live evidence needs
the configured scope, authentic CI/provider run identity and timestamp; mocked
provider output must be labeled fixture. Cleanup is a separately authorized
operation, not an implied destructive rollback.
