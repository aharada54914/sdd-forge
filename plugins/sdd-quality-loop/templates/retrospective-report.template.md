# Retrospective Report

## Header

| Field | Value |
|---|---|
| Feature | {{feature}} |
| Period | {{period_start}} – {{period_end}} |
| Generated | {{generated_timestamp}} |

## Metrics

| Task | QG Cycles | Blocked Count | Tickets (C/M/Min) | Auto-fixed | Outcome |
|---|---|---|---|---|---|
| {{task_id}} | {{qg_cycles}} | {{blocked_count}} | {{critical}}/{{major}}/{{minor}} | {{auto_fixed}} | {{outcome}} |
| **Total** | | | | | |

_C = Critical, M = Major, Min = Minor_

## Friction Patterns

Patterns observed across two or more tasks in this period.

<!-- One sub-section per pattern. Remove this comment when filling. -->

### {{pattern_id}}: {{pattern_title}}

- **Evidence:** {{affected_tasks_and_ticket_ids}}
- **Frequency:** {{occurrence_count}} occurrences
- **Phase:** {{workflow_phase}}

## Proposed Improvements

| WFI-ID | Status | Problem | Target File(s) |
|---|---|---|---|
| {{wfi_id}} | Draft | {{problem_summary}} | {{target_files}} |

## Comparison With Previous Retrospective

| Metric | Previous | This Period | Trend |
|---|---|---|---|
| Avg QG Cycles per Task | {{prev_avg_qg}} | {{curr_avg_qg}} | {{trend}} |
| Total Blocked Count | {{prev_blocked}} | {{curr_blocked}} | {{trend}} |
| Total Review Tickets | {{prev_tickets}} | {{curr_tickets}} | {{trend}} |
| Auto-fix Rate | {{prev_autofix_pct}} | {{curr_autofix_pct}} | {{trend}} |

_If no previous retrospective exists, mark all "Previous" cells as N/A._
