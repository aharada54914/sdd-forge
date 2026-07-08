# Quality Gate Report

Task ID: {{task_id}}
Feature: {{feature}}
VERDICT: {{verdict}}

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
