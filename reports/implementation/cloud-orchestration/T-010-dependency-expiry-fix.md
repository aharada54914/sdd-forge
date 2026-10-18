# Implementation Report: T-010

- Task ID: T-010
- Model: openai/gpt-6-astra
- Effort: high

Report Schema: implementation-report/v2

**Snapshot Notice**: The numbers, statuses, and paths recorded below reflect
the state at this report's own authoring run only. A later same-feature
event -- another task's edit to the same surface, or a gate-phase artifact
normalization such as a path move -- may supersede them. The quality
verification gate's own report is the authority for the gate-time state;
this report is not edited after the fact to reconcile it.

## Target

cloud-orchestration / T-010 / RT-20261018-CLOUD-DEPENDENCY-EXPIRY / REQ-006 / AC-006 / TEST-006

Run ID: 01a14f7b-2c6f-7fd2-a9d1-dfb5c7efdc0c
Task Attempt Count: 3
spec_revision: 9b8a12e8d875cf283e0c4370426ecf3c6e4338feff27a69ff888a2888066c440
Input manifest: `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/task-input-manifest.json`, SHA-256 `942285cb354d2cdea8048d181ae8f006eebff17b5b62a69f73048a62872c9b58`

## Summary

Callback-time dependency expiry repair. Pre-implementation Red recorded; implementation pending.

## Files Changed

tests/cloud-orchestration-verification.tests.py and task-local evidence/report. Production is unchanged at preflight.

## Tests Added Or Updated

DependencyCallbackExpiryCases: synthetic admitted deadline; real provider final guards, wire counters, minimum expiry and empty-set controls.

## Outputs

One table row per produced file. Paths MUST be canonical repository-relative
paths: forward slashes only, with no absolute/drive prefix, backslash, empty
segment, `.` segment, or `..` segment. The independent evaluator launch
boundary authorizes changed/test/contract inputs ONLY from rows in exactly
this two-column, backtick-quoted form — keep the shape byte-precise.

| Path | SHA-256 |
|---|---|
| `specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/red.log` | `5fce78786b86853d0d5082773e9b5bbf90c1f46591c4496112a1a4300013db03` |

## Test Evidence

- **Test Command**: python3 -B specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/run-scoped.py tests/cloud-orchestration-verification.tests.py DependencyCallbackExpiryCases
- **Test Result**: FAIL
- **Test Evidence Path**: specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/red.log

`Test Evidence Path` follows the same canonical repository-relative path rules
as output paths.

## Iteration And Escalation

- **Task Attempt Count**: 3
- **Escalation Prior Tier**: None
- **Escalation Next Tier**: None
- **Escalation Failure Class**: None
- **Escalation Attempt Number**: None
- **Escalation Reason**: None

## Isolation Evidence

- **Scratch Root**: /tmp/cloud-T010-01a14f7b-2c6f-7fd2-a9d1-dfb5c7efdc0c
- **Run ID**: 01a14f7b-2c6f-7fd2-a9d1-dfb5c7efdc0c
- **Session ID**: 01a14f7b-2c6f-7fd2-a9d1-dfb5c7efdc0c
- **Agent Instance ID**: 01a14f7b-2c6f-7fd2-a9d1-dfb5c7efdc0c
- **Isolation Mode**: fresh-agent
- **Fallback Reason**: None
- **Handoff Reload Evidence Hash**: None

Scratch Root, when declared, uses plain text or exactly one balanced
single-backtick Markdown span for the same path; malformed spans, controls
and duplicate declarations are invalid. A quality reservation additionally
requires a canonical absolute path with forward slashes and no empty/dot/parent
segments. Do not edit a frozen report to change its recorded root.

Fresh-agent reports MUST use `None` for both fallback fields. The only allowed
fallback is `same-session-file-reload`, whose exact reason is
`host-does-not-support-implementation-subagents` and whose evidence is a
lowercase 64-hex SHA-256.

## Regression Tests Run

Before regressions running; no whole repository suite.

## Specification Differences

None. Frozen specifications and canonical report remain read-only.

## Unresolved Items

Implementation, Green, scoped regressions/static checks and rollback pending; independent quality gate root-owned.

## Quality Gate Focus

Inspect minimum expiry handoff, real callback-time freshness and preserved replay/revocation invariants.

## Working Notes

Record conclusions from delegated investigations here. One entry per
delegation unit: purpose, result, and file paths examined.

No subagents. Ponytail full; ECC coding standards/security/verification; fix-by-review-ticket/debugging policy applied. No cloud actions.

## WFI-001 Pre-Implementation Mismatch Preflight

Recorded before production edits. `red.log`: 3 tests, 24 behavioral subtest failures,
zero errors. Ten fresh controls successfully submit; twenty stale/exact-deadline
cases wrongly submit once; four receipt-minimum cases retain consumer TTL rather
than predecessor expiry. These are executed real final guards and native fixture
submission counters, not inferred coverage. Earlier red-setup/red-second/red-third
logs contain fixture mistakes and are NOT the qualifying Red.

| Persisted field / acceptance claim | Counterpart | Executed mismatched-input Red |
|---|---|---|
| authorization.expires_at | minimum admitted predecessor deadline, OIDC exp, provider lease, iat + policy TTL, apply preview.expires_at | DependencyCallbackExpiryCases.test_receipt_expiry_minimum_and_empty_predecessors: both providers/stages emit 06:01:50Z instead of synthetic predecessor 06:00:10Z. Policy/OIDC/provider/preview and real empty-set controls pass. |
| provider result/state; native submissions zero when stale (AC-006) | Azure prepare what-if / apply PUT final receipt expiry guard after validation and journal work | test_azure_callback_freshness_validation_and_journal: fresh through last shared dependency admission, elapsed 10/11 only inside callback; one write observed instead of zero, real expiry guard executes. |
| provider result/state; native submissions zero when stale (AC-006) | AWS publish / CreateChangeSet / ExecuteChangeSet receipt lease guard after authentication, readback and execute history | test_aws_callback_freshness_readback_history_and_authentication: same injected deadline, elapsed 10/11 in callback while consumer/preview valid; target write observed once instead of zero. Prior legitimate prepare writes are not miscounted as target execute writes. |
| authorization receipt and submission journal retention (existing invariant) | exclusive publication/replay markers retained on failed final send | All callback cases assert actual journal existence. Existing admission/execution replay/revocation suites retained; no journal schema or identity field changes. |

The deadline stub is explicitly synthetic admitted-predecessor data, not provenance.
Real acquisition/cross-provider tests remain separate and unchanged. No final
provider guard is replaced: the assertion observer records then invokes the actual
assertion. No cloud/network calls are authorized.

Diagnosis: WriteBoundary discards first admit_predecessors return; expires_at lacks
its freshness bound. The later check is before provider callback work. Both provider
callbacks already consume the published expires_at in their final guards. The minimal
fix is to cap the existing receipt expiry before immutable publication, retaining
both authenticated acquisitions and all last consumer checks. No new wire schema.


## Session Handoff

Populate this section before ending a session mid-task.

- **Current Status**: In Progress
- **Next Action**: Commit genuine failing tests before shared production repair.
- **Unresolved Items**: Green, regressions, rollback and independent review pending.

`Current Status` is one of `In Progress`, `Implementation Complete`, or
`Blocked`. Only the independent quality gate may set a task to `Done`.
