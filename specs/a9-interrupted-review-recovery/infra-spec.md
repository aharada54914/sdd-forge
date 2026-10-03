# Infrastructure Specification: a9-interrupted-review-recovery

## Deployment Topology

Existing local orchestrator -> Bash/PowerShell precheck -> repository evidence and existing single-writer lock. REQ-001/004; AC-001/004. No new service, region, network, database, IaC or deployment unit. Runtime/tool prerequisites remain those of existing scripts; missing tools fail closed (TEST-105).

## CI/CD Sequence

Preparation -> independent spec review -> independent implementation-policy review -> Phase2 Draft tasks -> independent task review -> human approval -> bounded implementation -> independent quality gate. Neither preparation nor recovery provenance grants PASS. Run Bash and PowerShell matrix/regressions in matching environments (REQ-005 / AC-005 / TEST-100-107). No commit, push, reservation or live recovery during preparation.

## Environments / Infrastructure as Code

Local checkout and existing CI runners only. No cloud or URL, no IaC/state backend changes. Preserve hook/sandbox/trust/approval settings.

## Scaling Strategy / Service Level Objectives

Single writer per feature, existing `.spec-review.lock` (`plugins/sdd-review-loop/scripts/spec-review-precheck.sh:407-411`). TEST-091 asserts at most one writer. Availability, latency, throughput and autoscaling targets: N/A local validation without service change; correctness is hash preservation and deterministic rejection.

## Data Residency and Retention

REQ-004 / AC-004: all previous rounds, source inputs, status and ledger retained byte-for-byte, no deletions or migrations. Success creates only next target precheck and blank report. Revalidate under lock (TEST-092-094). Validation rejection creates no target. Partial publication fails nonzero, leaves any partial target quarantined as failure evidence with no consumable success, automatic reuse/reset/PASS, and requires separate authorized remediation (TEST-095); never automatic historical cleanup.

## Observability / Cost Estimate

Use existing CLI failure exit plus bounded reason and source/target identifiers; no secrets, no new telemetry service or alert channel. Precheck recovery path/hash is audit linkage, not verdict. Owner: workflow maintainer. No new dependency/egress/cloud cost.

## Rollback

Before implementation there is nothing deployed to roll back. After eventual repair implementation, revert the recovery option through reviewed human changes while retaining evidence; ordinary reset remains unchanged. Do not undo historical reservation or status. TEST-003/096/100 are invariants.

## Open Questions

AUTH-001: execution authorization supplied by human/orchestrator before actual recovery. Runtime availability is measured during implementation; absent PowerShell is unverified, not passed.
