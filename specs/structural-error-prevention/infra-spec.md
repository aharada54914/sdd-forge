# Infrastructure Specification: Structural Error Prevention

Draft; no execution results asserted.

## Deployment Topology

REQ-002/003/006: reuse `tests/verification-catalog.json`, `tests/verification.py`, existing local wrappers and existing CI jobs. Register the existing focused Python classifier suite directly in compatible profiles already used for mirror verification; no new CI service, runner framework or dependency. Preserve actual #619 helper delegation through `tests/cross-model.tests.ps1`.

## Runtime and Failure Handling

Execute selected catalog suites and inspect receipts/output. Keep required-runtime failure and explicitly optional skip semantics; do not mark a required runtime optional for this feature. Retain Bash/PowerShell mirror freshness and applicable generator/parity checks. Existing Linux/macOS/Windows routes establish only their actual coverage; Windows PowerShell 5.1 evidence requires an actual Desktop producer. Tests use temporary roots and fake external command fixtures where already supported, with no live provider invocation.

## Deployment and Rollback

No deployment or migration. Changes enter through normal reviewed repository changes after task approval. If registration exposes a failure, fix or report it; do not suppress the suite to manufacture success. Any rollback uses existing review/approval processes and preserves evidence. TEST-002/004/006/007 cover execution and compatibility; future retention remains separate.
