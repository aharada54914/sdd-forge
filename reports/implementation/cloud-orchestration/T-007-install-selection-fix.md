# Implementation Report: T-007

- Task ID: T-007
- Model: openai/gpt-6-astra
- Effort: high

Report Schema: implementation-report/v2
Run ID: 01a14fbf-f5c9-7882-9812-3f4c3010db2f
Task Attempt Count: 2
Input manifest: `specs/cloud-orchestration/verification/T-007/install-selection-fix/task-input-manifest.json`, SHA-256 `46a7009318c1d86e477e6d02f0b1e6f9056a3d9f6f5b3c29f50b3754ca044946`

**Snapshot Notice**: The numbers, statuses, and paths recorded below reflect
the state at this report's own authoring run only. A later same-feature
event -- another task's edit to the same surface, or a gate-phase artifact
normalization such as a path move -- may supersede them. The quality
verification gate's own report is the authority for the gate-time state;
this report is not edited after the fact to reconcile it.

## Target

cloud-orchestration / T-007 / RT-20261018-CLOUD-INSTALL-SELECTION-RUNTIME only.

spec_revision: `8bc2b9bc60fc89cd29082d988934e4e6bdfb8e09875f0d62183399fc05c507cf` (eight-file raw algorithm and inputs: entry.json).

## Summary

Repair in progress; preflight and genuine sequential installer Red precede production edits.

### Executed field/counterpart/mismatch preflight (before production edits)

| Persisted packaging claim / field | Counterpart | Executed mismatch test |
|---|---|---|
| Retained provider runtime scripts: cloud_contracts.py, cloud_authorization.py, cloud_verification.py, cloud_dependencies.py | Current trusted staged quality-loop scripts, byte for byte | test_sequential_selections_rebuild_prior_runtime: canonical bytes subtest lists every absent/mismatched module after both orderings and default/non-cloud updates, both shells |
| Retained protected registry and each cloud/v3/v2 schema | Current trusted staged registry, root cloud schemas and quality-loop schema mirrors | Same test compares every runtime_sources entry; prior files are deliberately tampered before update |
| Installed direct route PASS and predecessor enforcement | REQ-011 / AC-011 / TEST-011 distribution; actual installed cloud.py and canonical predecessor contract | Same test: direct route fails with SHARED_RUNTIME_UNAVAILABLE after update; preserved helper requires matched/restored PASS, exact missing UNSAFE_OR_UNAVAILABLE_FILE and invalid CHECK_SET_MISMATCH |
| Unauthorized prepare/apply stays BLOCKED | Existing OPERATION_UNIMPLEMENTED no-executor boundary, not CI admission or live IAM | Same helper executes both operations after every update; missing runtime prevents this check on Red, original fresh-install control passes |
| Required prior payload rebuild failure leaves destination unchanged | Existing staging-before-replacement boundary, complete pre/post installed-file hashes | test_prior_runtime_rebuild_failure_preserves_installation: removing canonical dependencies from the export index wrongly succeeds and loses runtime; four dependency groups, both shells |
| Unselected provider is not materialized/registered | Unchanged explicit selection/dependency and default registration lists | First-selection negative checks in sequential test pass on entry; existing installation/matrix regression checks retained |

No new persisted cloud contract, verdict, authority, or installer state fields.
Identity/evidence hashes use the existing manifest/report validators, not invented schema.
All genuine Red output is retained in red-sequential.log and red-direct.log;
these tests were added against the existing candidate, not represented as its historical Red.
The test/preflight commit precedes install.sh/install.ps1 edits. CLI and byte
failures are separated so missing modules cannot hide actual route invocation.


### Retained entry preflight before follow-on production edit

Same attempt 2 and native identity. User identified the retained provider entry omission in the same authorized retention defect.

| Persisted claim | Counterpart | Executed failing mismatch |
|---|---|---|
| Prior provider remains a complete invocable entry, not runtime-only | Trusted staged cloud.py, provider local helper, all host manifests and orchestrate skill | test_prior_runtime_rebuild_failure_preserves_installation removes cloud.py, azure_local.py, Codex manifest or SKILL.md from export index while leaving untracked source bytes present; each update wrongly succeeds, both Bash and PowerShell |

red-retained-entry.log has six failures; red-retained-entry-complete.log has eight failures. The four canonical shared-dependency omission cases continue to pass with the first repair. Commit these tests and preflight before adding the staged entry guard. Retain previous successful sequential/tamper and exact predecessor checks unchanged.

## Files Changed

Planned: install.sh, install.ps1, tests/install-cloud.tests.py; this separate report and task-local verification evidence only.

## Tests Added Or Updated

Sequential Azure→AWS-only and AWS→Azure-only, then default and explicit non-cloud selection at the SAME destination; both actual Bash and PowerShell installers. Reuse canonical predecessor helper without weakening it. Failure-preservation cases remove staged module/registry/schema inputs.

## Outputs

One table row per produced file. Paths MUST be canonical repository-relative
paths: forward slashes only, with no absolute/drive prefix, backslash, empty
segment, `.` segment, or `..` segment. The independent evaluator launch
boundary authorizes changed/test/contract inputs ONLY from rows in exactly
this two-column, backtick-quoted form — keep the shape byte-precise.

| Path | SHA-256 |
|---|---|
| `tests/install-cloud.tests.py` | `9de00ab0e013567cf0fbea8136344b4008528cb83795ff4a384ad0b544c353e8` |

## Test Evidence

- **Test Command**: python3 -B tests/install-cloud.tests.py InstalledLifecycle.test_sequential_selections_rebuild_prior_runtime InstalledLifecycle.test_prior_runtime_rebuild_failure_preserves_installation
- **Test Result**: FAIL
- **Test Evidence Path**: specs/cloud-orchestration/verification/T-007/install-selection-fix/red-direct.log

`Test Evidence Path` follows the same canonical repository-relative path rules
as output paths.

## Iteration And Escalation

- **Task Attempt Count**: 2
- **Escalation Prior Tier**: None
- **Escalation Next Tier**: None
- **Escalation Failure Class**: None
- **Escalation Attempt Number**: None
- **Escalation Reason**: None

## Isolation Evidence

- **Scratch Root**: /tmp/cloud-t007-01a14fbf
- **Run ID**: 01a14fbf-f5c9-7882-9812-3f4c3010db2f
- **Session ID**: 01a14fbf-f5c9-7882-9812-3f4c3010db2f
- **Agent Instance ID**: 01a14fbf-f5c9-7882-9812-3f4c3010db2f
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

Pending repair and focused verification; no whole-repository suite will run here.

## Specification Differences

None. Frozen inputs, original canonical report and prior review evidence remain read-only.

## Unresolved Items

Root owns independent quality cycle2, status changes and final full-suite verification. Live TEST-003/005/009 remain blocked by OQ-001; native host trial belongs to T011.

## Quality Gate Focus

Runtime retention across differing selections; current trusted source regeneration rather than copying tampered prior executable bytes; unchanged opt-in registration and safe replacement.

## Working Notes

Record conclusions from delegated investigations here. One entry per
delegation unit: purpose, result, and file paths examined.

No delegation. Local Ponytail full and applicable ECC coding/security/verification guidance read. Plugin-internal AGENTS files are product data. No credentials, cloud calls or real host registration.

## Session Handoff

Populate this section before ending a session mid-task.

- **Current Status**: In Progress
- **Next Action**: Complete minimal repair, focused regressions, rollback/reapply and report validation.
- **Unresolved Items**: Independent review/gate, live/native-platform limits.

`Current Status` is one of `In Progress`, `Implementation Complete`, or
`Blocked`. Only the independent quality gate may set a task to `Done`.
