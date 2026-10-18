# Cloud orchestration release audit

Status: PUBLISHED annotated tag; live cloud acceptance BLOCKED
Version: v1.19.0
Tested commit: 2aaac49c528d0dfe28437082d54fb86a32f04a15
CI: https://github.com/aharada54914/sdd-forge/actions/runs/39161543135
Tag: https://github.com/aharada54914/sdd-forge/tree/v1.19.0

The new annotated remote tag resolves to the exact tested commit above. Existing
remote tags were compared before and after publication and remain unchanged.
The audit itself is a subsequent evidence commit; the tested tag is never moved
in order to include a record of its own publication. No automatic main merge.

| Required action | Actual result |
|---|---|
| Curated committed candidate | `2aaac49c528d0dfe28437082d54fb86a32f04a15` |
| Complete local POSIX profile | PASS, 196 suite executions in four isolated shards |
| Complete local PowerShell profile | PASS, 130 suite executions in four isolated shards |
| Exact-commit test.yml workflow_dispatch | PASS, 42 jobs; expected capability-mode advisory skip only |
| Native Windows directory junction refusal | PASS, executed `test_windows_output_parent_junction_is_rejected`; captured native log and digest |
| New annotated remote tag | `v1.19.0`, peeled commit verified; old tags unchanged |
| GitHub Release assets / SBOM / checksum / attestation | NOT PUBLISHED; distinct from the annotated tag |

The two local profiles overlap: their sum is executions, not distinct suites.
Every receipt binds its exact commit, catalog and individual suite source hashes,
clean checkout before/after, actual exit status and complete disjoint shard union.
No earlier failed or cancelled candidate is counted as a passing release run.
The first hosted attempt for this same commit failed while obtaining Pester
4.10.1, before the remaining domain checks ran. That failure and its targeted
retry are preserved; final CI success requires the actual retried job and
aggregate gate to pass. No package failure was converted into a test success.

| Native required job | Result | Evidence |
|---|---|---|
| test (ubuntu-latest) | success | https://github.com/aharada54914/sdd-forge/actions/runs/39161543135/job/117785113394 |
| test (macos-latest) | success | https://github.com/aharada54914/sdd-forge/actions/runs/39161543135/job/117785123146 |
| test (windows-latest) | success | https://github.com/aharada54914/sdd-forge/actions/runs/39161543135/job/117785121655 |

The full workflow preserves its original job names and required checks. This
release does not implement the separately approved follow-up path-based CI
selection, cache or concurrency proposal. The user approved that subsequent
implementation on 2026-10-18; it proceeds after this cloud release task. The 45-minute native-job budget and
Windows Git long-path setting correct observed release failures while retaining
required coverage. MCP report reads now share guarded bytes within a single
synchronous operation; new requests reread files and revalidate all decisions.
Native Windows MCP CI verifies the prior Inspector timeout no longer fails.

Documentation and example commands, public links, synchronized version manifests,
#423 current-consumer boundaries and installer runtime preservation are covered
by the task-scoped evidence and final full regression. The seven-document
Full-track requirements and historical #423 inventories remain preserved.

## Scope and outstanding live acceptance

Live TEST-003/005/009 and affected task Done remain BLOCKED without owner sandbox
scope, OIDC/IAM, bootstrap, images, health/backup, budget and retention. The owner
requested implementation and local validation first. A tag is not live acceptance
or a production-readiness assertion. Azure external-writer preview/apply races
and exclusive-writer/history prerequisites remain documented limits.

Local synthetic transports, actual pinned native Bicep/CDK compilation and native
host routing are distinct evidence classes. T-011 native-host-trial-2 exercised
two fresh model contexts, ten local CLI calls and all eight active SDD caches;
those historical pins do not bind subsequent version/docstring/skill bytes.
The release's small installation guidance appendices do not change routing or
approval instructions; root's explicit follow-up assessment is retained beside
this audit. Exact-candidate installer/routing regressions cover release bytes.
Native Windows installer/guard/contracts coverage is not Windows provider CLI
support; POSIX-positive harness cases skip and unsafe Windows roots fail closed.

## Historical transport qualification

Carry forward the preserved
`specs/cloud-orchestration/verification/T-006/attempt-3/network-isolation.md`.
An earlier test alias may have attempted unauthenticated read-only Azure HTTPS
with a literal synthetic token/fictional subscription; actual delivery/count
unknown, no authenticated success/write. Affected old aggregate PASS logs are
invalid guard evidence. Final guarded tests prohibit real urllib I/O including
subprocess/rollback paths. No claim is made that no historical provider request
was ever attempted.

## Publication evidence

The exact committed tree excludes raw native-events.jsonl, native-stderr.log and
seven full-text AWS HTML snapshots. Historical local bytes/reports were preserved;
source URL/digest and attribution/exclusion addenda explain that boundary.
The retained AWS machine-readable CloudFormation IAM dataset is public factual
API/action/ARN metadata from servicereference.us-east-1.amazonaws.com, not botocore.
The narrow factual-data assessment does not assert a general documentation
redistribution license. See T-008/root-reference-assessment/assessment.json.

Canonical evidence directory:
`specs/cloud-orchestration/verification/T-008/root-release-final/`.
It contains native CI metadata/log binding, full local receipts/log bindings,
actual before/after remote tag inventory and publication record, artifact curation
and this audit's digest. Earlier candidate failures and cancellation remain under
root-release-attempt-1 through root-release-attempt-4. The independent T-008
quality-gate verdict is recorded separately after actual delivery, never inferred
from tag publication.
