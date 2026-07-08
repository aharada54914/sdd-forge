# Implementation Report: {{task_id}}

- Task ID: {{task_id}}

Report Schema: implementation-report/v2

**Snapshot Notice**: The numbers, statuses, and paths recorded below reflect
the state at this report's own authoring run only. A later same-feature
event -- another task's edit to the same surface, or a gate-phase artifact
normalization such as a path move -- may supersede them. The quality
verification gate's own report is the authority for the gate-time state;
this report is not edited after the fact to reconcile it.

## Target

{{target}}

## Summary

{{summary}}

## Files Changed

{{files_changed}}

## Tests Added Or Updated

{{tests_changed}}

## Outputs

One table row per produced file. Paths MUST be canonical repository-relative
paths: forward slashes only, with no absolute/drive prefix, backslash, empty
segment, `.` segment, or `..` segment. The independent evaluator launch
boundary authorizes changed/test/contract inputs ONLY from rows in exactly
this two-column, backtick-quoted form — keep the shape byte-precise.

| Path | SHA-256 |
|---|---|
| `{{output_path}}` | `{{output_sha256}}` |

## Test Evidence

- **Test Command**: {{test_command}}
- **Test Result**: {{PASS_or_FAIL_or_BLOCKED_or_NOT_RUN}}
- **Test Evidence Path**: {{test_evidence_path}}

`Test Evidence Path` follows the same canonical repository-relative path rules
as output paths.

## Iteration And Escalation

- **Task Attempt Count**: {{task_attempt_count}}
- **Escalation Prior Tier**: {{escalation_prior_tier}}
- **Escalation Next Tier**: {{escalation_next_tier}}
- **Escalation Failure Class**: {{escalation_failure_class}}
- **Escalation Attempt Number**: {{escalation_attempt_number}}
- **Escalation Reason**: {{escalation_reason}}

## Isolation Evidence

- **Run ID**: {{run_id}}
- **Session ID**: {{session_id}}
- **Agent Instance ID**: {{agent_instance_id}}
- **Isolation Mode**: {{isolation_mode}}
- **Fallback Reason**: {{fallback_reason_or_none}}
- **Handoff Reload Evidence Hash**: {{handoff_reload_evidence_hash_or_none}}

Fresh-agent reports MUST use `None` for both fallback fields. The only allowed
fallback is `same-session-file-reload`, whose exact reason is
`host-does-not-support-implementation-subagents` and whose evidence is a
lowercase 64-hex SHA-256.

## Regression Tests Run

{{regression_results}}

## Specification Differences

{{specification_differences}}

## Unresolved Items

{{unresolved_items}}

## Quality Gate Focus

{{quality_gate_focus}}

## Working Notes

Record conclusions from delegated investigations here. One entry per
delegation unit: purpose, result, and file paths examined.

{{working_notes}}

## Session Handoff

Populate this section before ending a session mid-task.

- **Current Status**: {{handoff_status}}
- **Next Action**: {{handoff_next_action}}
- **Unresolved Items**: {{handoff_unresolved}}

`Current Status` is one of `In Progress`, `Implementation Complete`, or
`Blocked`. Only the independent quality gate may set a task to `Done`.
