# Requirements: Azure / AWS cloud orchestration

Spec-Review-Status: Pending

## Overview

Provide thin Azure and AWS orchestration integrations that route to upstream
skills, govern cloud writes, collect observations, and verify outcomes. The
user approved this initial scope in the current session on 2026-10-18 after
the #423 audit. That approval authorizes development; it is not cloud apply
authorization or evidence that the repository review gates passed.

## Target Users

Platform engineers preparing IaC changes; authenticated environment owners
approving writes; operators diagnosing partial or uncertain operations.

## Problems

The existing selected-plan entry point evaluates implementation evidence
(`plugins/sdd-quality-loop/skills/quality-gate/SKILL.md:72`). Legacy stack
identifiers are code, shell, docs, and spec
(`plugins/sdd-quality-loop/scripts/check-contract.py:48`). This feature must
define cloud verification explicitly without pretending that evidence
selection executes cloud operations. The #423 audit also found a stale
consumer reference: the inventory points to lines 159–176, whereas the
mandatory seven-file statement is now at line 201
(`specs/sdd-domain-multitarget/verification/T-001/consumer-inventory.json:27`,
`plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md:201`).

## Goals

| ID | Requirement |
|---|---|
| REQ-001 | Preserve #423 historical evidence, publish a current consumer inventory with durable section anchors, and exercise current inventory and contract-boundary checks in the normal CI suite. Report historical task state separately from present test results. |
| REQ-002 | Select exactly one primary execution path and one IaC owner per deployment unit. Recognize existing Terraform, SAM, raw CloudFormation and azd ownership; conflicting ownership or unsupported execution must block rather than migrate or execute silently. |
| REQ-003 | Deliver Azure compute/Bicep and AWS CDK/CloudFormation initial paths, with provider-specific thin skills and one minimal VM/EC2 example each. Reuse upstream skills by pinned references, without copying their implementation or adding a universal cloud resource language. |
| REQ-004 | Bind each run to scope, immutable input artifacts, dependencies, policy and verification profile. A changed input, target, owner, dependency or preview invalidates authorization before any write. |
| REQ-005 | Enforce distinct prepare and apply authorizations at the actual cloud-write boundary using authenticated CI/environment policy. Locally asserted approval flags or model-generated receipts never authorize cloud writes. |
| REQ-006 | Serialize operations on overlapping deployment scopes, reject replay, and recover uncertain operations by querying their original operation identity. A timeout must not trigger a blind second apply. |
| REQ-007 | Preserve brownfield ownership: referenced resources receive only explicitly planned additive attachments; managed resources change through their existing IaC owner; import is blocked in this release. |
| REQ-008 | Provide versioned cloud verification profiles with real IaC validation, policy, preview and post-deploy checks. Preserve existing code/shell/docs/spec verification semantics; never synthesize successful unit/TDD evidence for IaC. |
| REQ-009 | Distinguish execution success, observed resource state, verified health, and complete evidence. Missing permissions, missing checks, stale observations, partial failure or unknown state must prevent VERIFIED/EVIDENCE_COMPLETE. |
| REQ-010 | Record reproducible, secret-free audit evidence, including native provider/CI operation identities, timings, actual exit status, authenticated principal, hashes, and verification results. Evidence rewriting must not repair an otherwise failed run. |
| REQ-011 | Make both paths reachable from bootstrap and plugin entry points, with clear dry-run/prepare/apply/reconcile/verify behavior. Preserve existing non-cloud flows and the mandatory Phase 1 documents. |
| REQ-012 | Validate positive and adversarial behavior using deterministic tests and isolated host evaluation; label fixture evidence and live sandbox evidence separately. Production writes are outside development approval. |

## Non-goals

No cross-cloud atomic transaction, generic deployment engine, automatic
destructive rollback, automatic import, Terraform/SAM/azd execution adapter,
multi-account landing zone, Kubernetes platform, production provisioning, or
unattended upstream upgrades. Supporting upstream skills may assist planning;
they cannot become a second executor for a deployment unit.

## User Stories

- As an engineer, I can discover the existing IaC owner and prepare one reviewable plan (REQ-002–004).
- As an environment owner, I approve the exact operation and target that CI will execute (REQ-005).
- As an operator, I can reconcile a timed-out operation and see which health checks actually passed (REQ-006, REQ-009–010).
- As a maintainer, I can add cloud profiles without weakening existing workflow gates (REQ-001, REQ-008, REQ-011–012).

## Acceptance Criteria

AC-001 through AC-012 in `acceptance-tests.md` correspond one-to-one to the
requirements above. All mandatory checks must pass; unsupported capability,
unavailable live credentials and missing approval are BLOCKED, never a pass.

## Roles and Permissions

The local author can inspect, route, edit IaC and validate locally. A protected
prepare job may publish assets and create a preview only within its approved
scope. A separate protected apply job may execute only the approved immutable
artifact. A read-only observer collects resource and health results. An
authenticated environment approver authorizes writes and cannot be replaced
by an agent assertion. Provider IAM and CI policy enforce these distinctions.

## Main Workflows

Route → plan → local validation → prepare authorization → preview preparation
→ apply authorization → execution → observation → verification → evidence.
Azure preview is refreshed under the scope lock before apply; relevant changes
return to preview/approval. AWS executes the exact prepared Change Set. Cross-
cloud requests are dependency graphs of independently authorized units; a
failed predecessor blocks dependents and preserves successful-unit receipts.

## Edge Cases

Ambiguous owner; stale preview; changed CDK assets; dependency/tool-schema
drift; expired approval; cross-account substitution; concurrent overlapping
scope; lost CI response; partial deployment; unavailable read permission;
missing mandatory backup; provider success with unhealthy workload; replayed
receipt; secret-bearing provider error; path traversal or symlinked evidence.
Each must yield an actionable blocked/failed/unknown result and no unauthorized
follow-on write. A no-op preview is reported explicitly without fake apply.

## Security Boundaries

| Trust Boundary | Auth/Authz Requirement | PII / Data Classification | Regulatory Constraints |
|---|---|---|---|
| Agent/repository → CI | Protected workflow and environment approval; immutable run/input binding | Internal plans and resource identifiers | Target-specific constraints supplied before live use |
| CI → cloud | Short-lived OIDC principal limited by account, environment and operation | Infrastructure metadata; secrets by reference only | Region and account allowlists |
| Cloud → evidence | Native identity, freshness, schema and hash verification; redaction | Internal observations; no credentials | Configured evidence residency and retention |

## Assumptions

GitHub Actions is the initial CI authorization boundary. Bicep and CDK are the
two supported initial owners. Actual subscriptions/accounts, regions, workload
health probes, backup policy and budget are supplied as run inputs before live
deployment; missing values block live operation, not local implementation.

## Open Questions

The environment owner must supply real target scopes, CI federation and health
expectations before a live sandbox trial. No cloud credentials are requested
in repository files. These are deployment prerequisites, not permission to
silently substitute an arbitrary target.

## Risks

Upstream skill drift is controlled by dependency locks and compatibility tests.
Cloud drift is controlled by serialized previews and readback, subject to the
documented Azure preview/apply race. Privilege drift is controlled by external
CI/IAM policy and negative authorization tests. Misleading fixture results are
controlled by distinct evidence classifications and explicit live-test limits.
