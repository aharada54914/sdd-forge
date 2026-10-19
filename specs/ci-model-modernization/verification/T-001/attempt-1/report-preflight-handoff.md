# Implementation Report: T-001

- Task ID: T-001
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

ci-model-modernization T-001 only.

Run ID: 01a1517b-38f6-7143-8bec-e35f0e425903
Task Attempt Count: 1
spec_revision: f9befa7f301cb96664c692903d61b8d121c20619
Input manifest: `specs/ci-model-modernization/verification/T-001/attempt-1/task-input-manifest.json`, SHA-256 `a013f58fc143f09a6b59bcabf1366fb3e79f88eb7eba1eeec4c8fe5ceec98dbc`

## Summary

Pre-implementation high-risk preflight. No product changes yet.

## Files Changed

New planner tests only.

## Tests Added Or Updated

tests/verification-ci-plan.tests.py: paired wire-field mutations and planner fixtures.

## Outputs

One table row per produced file. Paths MUST be canonical repository-relative
paths: forward slashes only, with no absolute/drive prefix, backslash, empty
segment, `.` segment, or `..` segment. The independent evaluator launch
boundary authorizes changed/test/contract inputs ONLY from rows in exactly
this two-column, backtick-quoted form — keep the shape byte-precise.

| Path | SHA-256 |
|---|---|
| `specs/ci-model-modernization/verification/T-001/attempt-1/task-input-manifest.json` | `a013f58fc143f09a6b59bcabf1366fb3e79f88eb7eba1eeec4c8fe5ceec98dbc` |

## Test Evidence

- **Test Command**: python3 -B tests/verification-ci-plan.tests.py
- **Test Result**: NOT RUN
- **Test Evidence Path**: specs/ci-model-modernization/verification/T-001/attempt-1/red.txt

`Test Evidence Path` follows the same canonical repository-relative path rules
as output paths.

## Iteration And Escalation

- **Task Attempt Count**: 1
- **Escalation Prior Tier**: None
- **Escalation Next Tier**: None
- **Escalation Failure Class**: None
- **Escalation Attempt Number**: None
- **Escalation Reason**: None

## Isolation Evidence

- **Scratch Root**: /tmp/ci-model-T001-01a1517b
- **Run ID**: 01a1517b-38f6-7143-8bec-e35f0e425903
- **Session ID**: 01a1517b-38f6-7143-8bec-e35f0e425903
- **Agent Instance ID**: 01a1517b-38f6-7143-8bec-e35f0e425903
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

Before product work: existing impact 6 tests passed; catalog 15 tests passed (1 PowerShell PATH skip).

## Specification Differences

None. No frozen artifacts edited.

## Unresolved Items

Implementation and tests pending; independent reviewer and formal quality gate remain root-owned.

## Quality Gate Focus

Trusted code versus caller digests; full inventory; every field counterpart; no claimed hosted execution.

## Working Notes

Record conclusions from delegated investigations here. One entry per
delegation unit: purpose, result, and file paths examined.

Ponytail full and ECC coding/security/TDD/verification guidance read. No delegation permitted. Snapshot paths use inputs/<source-path> because validator rejects overlapping input/output names; source bytes preserved. Initial rejected manifest retained. Ordinary checkout is dirty.

## Session Handoff

Populate this section before ending a session mid-task.

- **Current Status**: In Progress
- **Next Action**: Run and commit actual Red tests, then implement T-001 only.
- **Unresolved Items**: All new planner behavior pending.

`Current Status` is one of `In Progress`, `Implementation Complete`, or
`Blocked`. Only the independent quality gate may set a task to `Done`.

## WFI-001 Preflight (before product edits)

Every wire mismatch is passed to intended callable `validate_plan(candidate, expected=independently_bound_plan)`. Matching controls precede mutations. Until implemented, missing callable Red is NOT executed mismatch rejection. After Green every body must execute, with no-op sensitivity checks. No execution verdict is produced by T-001.

| Persisted field | Counterpart | Failing mismatch test |
|---|---|---|
| `schema` | design.md concrete CI wire contract; independently bound expected plan `schema` | `WireTests.test_every_persisted_field_matches_independent_counterpart` (schema mutation) |
| `mode` | design.md concrete CI wire contract; independently bound expected plan `mode` | `WireTests.test_every_persisted_field_matches_independent_counterpart` (mode mutation) |
| `reason` | design.md concrete CI wire contract; independently bound expected plan `reason` | `WireTests.test_every_persisted_field_matches_independent_counterpart` (reason mutation) |
| `event` | design.md concrete CI wire contract; independently bound expected plan `event` | `WireTests.test_every_persisted_field_matches_independent_counterpart` (event mutation) |
| `run_id` | design.md concrete CI wire contract; independently bound expected plan `run_id` | `WireTests.test_every_persisted_field_matches_independent_counterpart` (run_id mutation) |
| `planning_attempt` | design.md concrete CI wire contract; independently bound expected plan `planning_attempt` | `WireTests.test_every_persisted_field_matches_independent_counterpart` (planning_attempt mutation) |
| `api_head_sha` | design.md concrete CI wire contract; independently bound expected plan `api_head_sha` | `WireTests.test_every_persisted_field_matches_independent_counterpart` (api_head_sha mutation) |
| `tested_revision` | design.md concrete CI wire contract; independently bound expected plan `tested_revision` | `WireTests.test_every_persisted_field_matches_independent_counterpart` (tested_revision mutation) |
| `base_revision` | design.md concrete CI wire contract; independently bound expected plan `base_revision` | `WireTests.test_every_persisted_field_matches_independent_counterpart` (base_revision mutation) |
| `pr_head_revision` | design.md concrete CI wire contract; independently bound expected plan `pr_head_revision` | `WireTests.test_every_persisted_field_matches_independent_counterpart` (pr_head_revision mutation) |
| `merge_base_revision` | design.md concrete CI wire contract; independently bound expected plan `merge_base_revision` | `WireTests.test_every_persisted_field_matches_independent_counterpart` (merge_base_revision mutation) |
| `catalog_sha256` | design.md concrete CI wire contract; independently bound expected plan `catalog_sha256` | `WireTests.test_every_persisted_field_matches_independent_counterpart` (catalog_sha256 mutation) |
| `workflow_sha256` | design.md concrete CI wire contract; independently bound expected plan `workflow_sha256` | `WireTests.test_every_persisted_field_matches_independent_counterpart` (workflow_sha256 mutation) |
| `trusted_planner_sha256` | design.md concrete CI wire contract; independently bound expected plan `trusted_planner_sha256` | `WireTests.test_every_persisted_field_matches_independent_counterpart` (trusted_planner_sha256 mutation) |
| `plan_sha256` | design.md concrete CI wire contract; independently bound expected plan `plan_sha256` | `WireTests.test_every_persisted_field_matches_independent_counterpart` (plan_sha256 mutation) |
| `changed_path_count` | design.md concrete CI wire contract; independently bound expected plan `changed_path_count` | `WireTests.test_every_persisted_field_matches_independent_counterpart` (changed_path_count mutation) |
| `groups` | design.md concrete CI wire contract; independently bound expected plan `groups` | `WireTests.test_every_persisted_field_matches_independent_counterpart` (groups mutation) |
| `obligations` | design.md concrete CI wire contract; independently bound expected plan `obligations` | `WireTests.test_every_persisted_field_matches_independent_counterpart` (obligations mutation) |
| `omissions` | design.md concrete CI wire contract; independently bound expected plan `omissions` | `WireTests.test_every_persisted_field_matches_independent_counterpart` (omissions mutation) |
| `activation_evidence` | design.md concrete CI wire contract; independently bound expected plan `activation_evidence` | `WireTests.test_every_persisted_field_matches_independent_counterpart` (activation_evidence mutation) |
| `obligations[].id` | expanded workflow and catalog obligation `id` | `WireTests.test_every_obligation_field_mismatch_and_guard_sensitivity` (id mutation) |
| `obligations[].job` | expanded workflow and catalog obligation `job` | `WireTests.test_every_obligation_field_mismatch_and_guard_sensitivity` (job mutation) |
| `obligations[].matrix` | expanded workflow and catalog obligation `matrix` | `WireTests.test_every_obligation_field_mismatch_and_guard_sensitivity` (matrix mutation) |
| `obligations[].runner` | expanded workflow and catalog obligation `runner` | `WireTests.test_every_obligation_field_mismatch_and_guard_sensitivity` (runner mutation) |
| `obligations[].step` | expanded workflow and catalog obligation `step` | `WireTests.test_every_obligation_field_mismatch_and_guard_sensitivity` (step mutation) |
| `obligations[].command_sha256` | expanded workflow and catalog obligation `command_sha256` | `WireTests.test_every_obligation_field_mismatch_and_guard_sensitivity` (command_sha256 mutation) |
| `obligations[].suites` | expanded workflow and catalog obligation `suites` | `WireTests.test_every_obligation_field_mismatch_and_guard_sensitivity` (suites mutation) |
| `obligations[].receipt_required` | expanded workflow and catalog obligation `receipt_required` | `WireTests.test_every_obligation_field_mismatch_and_guard_sensitivity` (receipt_required mutation) |
| `omissions[].id/reason` | complete inventory partition / explicit unrelated reason | WireTests.test_omission_and_activation_field_pairs |
| `activation_evidence[].category/path/sha256/rule_sha256/baseline_revision` | trusted category definition, contained proof bytes and baseline commit | WireTests.test_omission_and_activation_field_pairs |
| GitHub output keys/values | plan groups, fixed run_<group> names | WireTests.test_fixed_condition_outputs_and_collision_rejection |

No implementation success, quality verdict, or traceability status is persisted. Report/manifest identity fields bind caller allocation and input snapshot; manifest validator and report validator exercise their existing contracts, not new planner product fields.

## Activation proof preflight (before proof implementation)

Root clarified strict proof payload definition is within T-001. No frozen input changes.

| Persisted fields | Counterpart | Failing mismatch test |
|---|---|---|
| proof schema/category/rule_sha256/baseline_revision | exact version and trusted category/rule/baseline | ProofTests.test_proof_fields_and_references_must_match, per-key mutations |
| proof full_plan/full_result/consumer_inventory/mutation_evidence path and sha256 | contained committed reference bytes | ProofTests.test_proof_fields_and_references_must_match, per-reference substitutions |
| full result schema/status/reason/run_id/api_head_sha/tested_revision/plan_sha256/results | baseline full plan identity and complete successful obligations | ProofTests.test_full_result_and_consumer_mutation_records_are_not_success_flags |
| consumer schema/baseline_revision/rule_sha256/consumers input/suites/groups/sources path/sha256 | category selectors and baseline Git source blobs | ProofTests.test_full_result_and_consumer_mutation_records_are_not_success_flags |
| mutation schema/baseline_revision/rule_sha256/cases input/plan/result refs | changed-input prediction and bound failing full result | ProofTests.test_full_result_and_consumer_mutation_records_are_not_success_flags |

Proof artifacts are consumed, not fabricated by the planner. Synthetic test records are local protocol fixtures. Live category activation remains T-011.

## Control-boundary preflight

Root identified the aggregate self-observation hazard. Before implementation, `PlanningTests.test_control_verifier_is_not_its_own_completed_workload` requires one explicit disposition for the exact required-checks verifier, no completed-workload dependency on itself, preserved native wrappers, and rejection of added workload commands. Persisted disposition/id/job/matrix/runner/step/command_sha256/suites/receipt_required fields pair with the expanded current workflow and the exact admitted verifier command; the same test mutates identity, body, extra step and failure handling. This is not a generic control-job exemption or execution verdict.
