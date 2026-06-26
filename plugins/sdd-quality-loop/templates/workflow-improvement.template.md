# Workflow Improvement

## WFI-ID

{{wfi_id}}

## Status

Status: {{status}}

<!-- Allowed values: Draft | Approved | Applied | Verified | Rejected -->
<!-- Only a human may set status to Approved. The AI sets Draft, Applied, and Verified. -->

## Category

Category: {{category}}

<!-- Allowed values: plugin-improvement | app-dev-efficiency -->
<!-- plugin-improvement: friction leads to a plugin-level improvement issue.        -->
<!--   Root Cause, Proposed Change, Expected Effect must use generic workflow terms. -->
<!--   See plugins/sdd-quality-loop/references/wfi-category-guide.md Section 2.    -->
<!-- app-dev-efficiency: friction leads to a project-specific workflow improvement. -->
<!--   All sections must use project-specific concrete detail (task IDs, features). -->
<!--   See plugins/sdd-quality-loop/references/wfi-category-guide.md Section 3.    -->
<!-- Set by workflow-retrospective during WFI drafting.                             -->
<!-- Do not change after Audit-Status: Human-Pending.                               -->

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

{{metric_name_baseline_target_checkpoint}}

<!-- Name one primary metric, the current baseline, target, and checkpoint. -->
<!-- Retrospective compares this after the next task cycle.                 -->

## Verification Plan

{{verification_plan}}

<!-- Describe how the next task cycle will confirm the improvement. -->
<!-- Reference the specific metric rows from the retrospective template. -->

## Result

{{result}}

<!-- Fill after the next task cycle completes. Append a comparison table. -->
<!-- Leave as "Pending" until verification is complete. -->
