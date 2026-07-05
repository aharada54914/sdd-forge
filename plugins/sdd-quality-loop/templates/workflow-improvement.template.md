# Workflow Improvement

## WFI-ID

{{wfi_id}}

## Status

Status: {{status}}

<!-- Allowed values: Draft | Approved | Applied | Verified | Rejected | Regressed -->
<!-- Only a human may set status to Approved. The AI sets Draft, Applied, Verified,  -->
<!-- Rejected (verification failed), and Regressed (retention check found the fixed  -->
<!-- failure mode recurring after Verified).                                          -->

## Category

Category: {{category}}

<!-- Allowed values: plugin-improvement | app-dev-efficiency | human-process | measurement -->
<!-- This is the SCOPE axis: where the change lands.                                -->
<!-- plugin-improvement: friction leads to a plugin-level improvement issue.        -->
<!--   Root Cause, Proposed Change, Expected Effect must use generic workflow terms. -->
<!--   See plugins/sdd-quality-loop/references/wfi-category-guide.md Section 2.    -->
<!-- app-dev-efficiency: friction leads to a project-specific workflow improvement. -->
<!--   All sections must use project-specific concrete detail (task IDs, features). -->
<!--   See plugins/sdd-quality-loop/references/wfi-category-guide.md Section 3.    -->
<!-- human-process: changes approval policy, escalation rules, or what humans       -->
<!--   review. Application is always a human action.                                -->
<!-- measurement: changes graders, gate thresholds, retrospective logic, or run-    -->
<!--   record definitions. Forces Meta-Change: true (strict audit lane, §5 of the   -->
<!--   category guide).                                                              -->
<!-- Set by workflow-retrospective during WFI drafting.                             -->
<!-- Do not change after Audit-Status: Human-Pending.                               -->

## Mechanism

Mechanism: {{mechanism}}

<!-- Allowed values: instructions | memory | tools | architecture | model-routing -->
<!-- This is the MECHANISM axis: what kind of thing changes (orthogonal to        -->
<!-- Category). instructions = prompts/SKILL guidance/rubric text.                 -->
<!-- memory = AGENTS.md / CLAUDE.md / persistent templates (watch context bloat).  -->
<!-- tools = scripts, hooks, agent definitions, schemas.                           -->
<!-- architecture = gate ordering, reviewer counts, approval placement.            -->
<!-- model-routing = model selection per stage.                                    -->

## Meta-Change

Meta-Change: {{true_or_false}}

<!-- true when the Proposed Change touches graders, gate thresholds, retrospective -->
<!-- or audit logic, or run-record definitions — anything that measures the        -->
<!-- workflow. Meta-Change WFIs get the strict audit lane: auditor-b must confirm  -->
<!-- the change does not weaken measurement (anti-Goodhart check), and gate/test/  -->
<!-- check counts must be non-decreasing.                                           -->

## GitHub-Issue

GitHub-Issue: {{github_issue_url}}

<!-- plugin-improvement: populated by wfi-audit-cycle after gh issue create.       -->
<!-- app-dev-efficiency: set to N/A (no issue is created).                         -->
<!-- If issue creation failed: CREATION-FAILED — <error>.                          -->

## Audit-Status

Audit-Status: {{audit_status}}

<!-- Allowed values: Not-Started | Cycle-1-In-Progress | Cycle-2-In-Progress | Human-Pending -->
<!-- Not-Started: initial state; audit has not yet run.                            -->
<!-- Cycle-1-In-Progress / Cycle-2-In-Progress: audit currently running.           -->
<!-- Human-Pending: both audit cycles complete; awaiting human Status: Approved.   -->
<!-- Only wfi-audit-cycle may update this field.                                    -->
<!-- Backward compatibility: WFIs without this field are treated as Not-Started.   -->

## Problem Evidence

{{metrics_and_ticket_references}}

<!-- Quote specific BL-IDs, RT-IDs, or retrospective table rows that show the friction. -->

## Root Cause Hypothesis

{{root_cause}}

## Proposed Change

| Target File | Change Description |
|---|---|
| {{file_path}} | {{change_description}} |

<!-- Target files must be project-side workflow files only (AGENTS.md, CLAUDE.md,    -->
<!-- specs/ templates, task-splitting guidelines). Plugin files must not be listed.  -->

## Expected Effect

{{expected_effect}}

<!-- State the metric(s) expected to improve and by how much. -->

## Verification Metric

Target-Metric: {{run_record_metric_key}}
Expected-Direction: {{increase_or_decrease}}
Horizon: {{horizon}}
Baseline: {{baseline_count}}
Target: {{target_count}}

<!-- Target-Metric names one key from the run record (reports/runs/RUN-*.json),     -->
<!-- e.g. metrics.first_pass_gate or metrics.review_tickets.critical, or a          -->
<!-- retrospective table column for gate metrics.                                    -->
<!-- Horizon is binding: "within the next N runs" or an absolute date. When the     -->
<!-- horizon passes without the target being met, retrospective sets                 -->
<!-- Status: Rejected and proposes the Rollback-Plan to the human.                   -->
<!-- State Baseline and Target as counts (numerator/denominator), not percentages.   -->

## Verification Plan

{{verification_plan}}

<!-- Describe how the next task cycle will confirm the improvement. -->
<!-- Reference the specific metric rows from the retrospective template. -->

## Rollback-Plan

{{rollback_plan}}

<!-- Name the exact files/sections this WFI changes and how to revert them          -->
<!-- (normally: git revert of the commit whose message contains this WFI-ID).       -->
<!-- Required before Status: Approved. Executed only after human approval when      -->
<!-- verification classifies the WFI as Rejected or Regressed.                      -->


## Result

{{result}}

<!-- Fill after the next task cycle completes. Append a comparison table. -->
<!-- Leave as "Pending" until verification is complete. -->
