# Retrospective Report

## Header

| Field | Value |
|---|---|
| Feature | {{feature}} |
| Period | {{period_start}} – {{period_end}} |
| Generated | {{generated_timestamp}} |
| Sample Size | {{task_count}} tasks, {{review_contract_count}} review contracts, {{qg_report_count}} QG reports, {{ticket_count}} tickets |
| Data Completeness | {{complete_partial_blocked}} |
| Confidence | {{high_medium_low_with_reason}} |

## Metrics

| Task | Task Attempts | Review Rounds | Quality-Gate Runs | Model Escalations | Blocked Count | Tickets (C/M/Min) | Outcome |
|---|---|---|---|---|---|---|---|
| {{task_id}} | {{task_attempts}} | {{review_rounds}} | {{quality_gate_runs}} | {{model_escalations}} | {{blocked_count}} | {{critical}}/{{major}}/{{minor}} | {{outcome}} |
| **Total** | | | | | | | |

_C = Critical, M = Major, Min = Minor_

Counts use the workflow-retrospective deterministic artifact selection,
task-association, ordering, tie-break, and de-duplication rules. Record excluded
or conflicting artifacts in the Data Completeness explanation.

## Domain Drift Metrics

<!-- Include this section only when domain/ exists; omit entirely otherwise. -->

| Metric | This Period | Previous Period | Trend |
|---|---|---|---|
| Term-Deviation Count | {{term_deviation_count}} | {{prev_term_deviation_count}} | {{trend}} |
| Boundary-Violation Count | {{boundary_violation_count}} | {{prev_boundary_violation_count}} | {{trend}} |
| Combined Domain-Drift Count | {{combined_drift_count}} | {{prev_combined_drift_count}} | {{trend}} |

Counts are sourced only from `check-domain-conformance` findings already
recorded in the retained `reports/quality-gate/*.md` reports for this
feature.

## Friction Patterns

Patterns observed across two or more tasks in this period.

<!-- One sub-section per pattern. Remove this comment when filling. -->

### {{pattern_id}}: {{pattern_title}}

- **Evidence:** {{affected_tasks_and_ticket_ids}}
- **Frequency:** {{occurrence_count}} occurrences
- **Phase:** {{workflow_phase}}
- **Confidence:** {{high_medium_low}}
- **Do Not Overfit:** {{why_this_is_not_a_single_task_exception}}

## Proposed Improvements

| WFI-ID | Status | Problem | Target File(s) |
|---|---|---|---|
| {{wfi_id}} | Draft | {{problem_summary}} | {{target_files}} |

## Improvement Verification Plan

| WFI-ID | Expected Effect Metric | Baseline | Target | Next Checkpoint |
|---|---|---|---|---|
| {{wfi_id}} | {{metric}} | {{baseline}} | {{target}} | {{next_feature_or_date}} |

## Review Gate Metrics

| Feature | Spec Review Rounds | Spec Review Verdict | Task Review Rounds | Task Review Verdict | Impl Review Rounds | Impl Review Verdict | Legacy Design |
|---|---|---|---|---|---|---|---|
| {{feature}} | {{spec_review_rounds}} | {{spec_review_verdict}} | {{task_review_rounds}} | {{task_review_verdict}} | {{impl_review_rounds}} | {{impl_review_verdict}} | {{legacy_design}} |

## Comparison With Previous Retrospective

| Metric | Previous | This Period | Trend |
|---|---|---|---|
| Avg QG Cycles per Task | {{prev_avg_qg}} | {{curr_avg_qg}} | {{trend}} |
| Avg Task Attempts | {{prev_task_attempts}} | {{curr_task_attempts}} | {{trend}} |
| Avg Review Rounds | {{prev_review_rounds}} | {{curr_review_rounds}} | {{trend}} |
| Avg Quality-Gate Runs | {{prev_quality_gate_runs}} | {{curr_quality_gate_runs}} | {{trend}} |
| Total Model Escalations | {{prev_model_escalations}} | {{curr_model_escalations}} | {{trend}} |
| Total Blocked Count | {{prev_blocked}} | {{curr_blocked}} | {{trend}} |
| Total Review Tickets | {{prev_tickets}} | {{curr_tickets}} | {{trend}} |
| Auto-fix Rate | {{prev_autofix_pct}} | {{curr_autofix_pct}} | {{trend}} |
| Avg Spec Review Rounds | {{prev_spec_review_rounds}} | {{curr_spec_review_rounds}} | {{trend}} |
| Spec Review Blocked Rate | {{prev_spec_review_blocked}} | {{curr_spec_review_blocked}} | {{trend}} |
| Avg Task Review Rounds | {{prev_task_review_rounds}} | {{curr_task_review_rounds}} | {{trend}} |
| Task Review Blocked Rate | {{prev_task_review_blocked}} | {{curr_task_review_blocked}} | {{trend}} |
| Avg Impl Review Rounds | {{prev_impl_review_rounds}} | {{curr_impl_review_rounds}} | {{trend}} |
| Impl Review Blocked Rate | {{prev_impl_review_blocked}} | {{curr_impl_review_blocked}} | {{trend}} |
| Impl Legacy Design Rate | {{prev_legacy_design_rate}} | {{curr_legacy_design_rate}} | {{trend}} |
| Repeat Finding Rate | {{prev_repeat_finding_rate}} | {{curr_repeat_finding_rate}} | {{trend}} |
| WFI Verification Rate | {{prev_wfi_verification_rate}} | {{curr_wfi_verification_rate}} | {{trend}} |

_If no previous retrospective exists, mark all "Previous" cells as N/A._
