# Quality Gate Report

Task ID: {{task_id}}
Feature: {{feature}}
Run ID: {{run_id}}
VERDICT: {{verdict}}
Critical: {{critical_count}}
Major: {{major_count}}
Minor: {{minor_count}}

<!-- Identity header contract (WFI-020). Every line above is parsed by a     -->
<!-- deterministic consumer: Task ID by check-evidence-bundle and the         -->
<!-- run-record/cycle-limit counters (canonical task-identity field; the      -->
<!-- legacy separate `Task:` line is retired — do not add one); Feature by    -->
<!-- report selection and the exactly-one rule in check-evidence-bundle;      -->
<!-- Run ID by the retrospective's artifact rules (value = the evaluator run  -->
<!-- id reserved in the identity ledger for this gate run); Critical/Major/   -->
<!-- Minor by generate-evidence-bundle, which records zeros when absent.      -->
<!-- Keep each as a bare line before any prose, and never start a later line  -->
<!-- in the body with `Feature: ` or `Task ID: `.                             -->

## Target
{{target}}

## Implementation Report Reviewed
{{implementation_report}}

## Verification Results
{{verification_results}}

## Evidence Matrix

| Surface | Evidence Type | Evidence Path Or Command | Result | Notes |
|---|---|---|---|---|
| {{surface}} | {{command_output|scripted_gate|line_inspection|manual_artifact}} | {{evidence}} | {{pass_fail_or_na}} | {{notes}} |

Implementation-report statements are claims, not evidence. Leave no in-scope
surface without a command, scripted gate, line inspection, or manual artifact.

## Cannot-Verify Items

| Surface | Missing Evidence | Blocking Ticket Or Resolution |
|---|---|---|
| {{surface}} | {{missing_command_path_or_artifact}} | {{blocking_ticket_or_evidence_to_collect}} |

In-scope cannot-verify items block Done until evidence is collected or a review
ticket is created. Waivers are valid only for optional out-of-scope checks.

## Out-Of-Scope Waivers

| Surface | Why Out Of Scope | Waiver Reference |
|---|---|---|
| {{surface}} | {{reason}} | {{waiver_reference_or_na}} |

## Critical Review Cycles
{{critical_review_cycles}}

## UI Verification
{{ui_verification}}

## Traceability And Drift
{{traceability_and_drift}}

## Review Tickets
{{review_tickets}}

## Decision
{{decision}}
