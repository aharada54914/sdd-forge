# Tasks: {{feature_name}}

Task-Review-Status: Pending

## Lifecycle

`Draft -> Approved -> In Progress -> Implementation Complete -> Done`

A task may enter `Blocked` from any active state. Humans approve tasks.
`implement-task` may set `In Progress`, `Blocked`, or `Implementation Complete`.
Only `quality-gate` may set `Done`.

## T-001 {{task_001_title}}

Source Issue: {{source_issue}}

Approval: Draft

Status: Planned

Risk: {{risk}}

Risk Rationale: {{risk_rationale}}

Required Workflow: {{required_workflow}}

Requirements: {{requirement_ids}}

Planned Files: {{planned_files}}

Data Migration: {{data_migration}}

Breaking API: {{breaking_api}}

### Goal
{{goal}}

### Must Read
- specs/{{feature_slug}}/requirements.md
- specs/{{feature_slug}}/design.md
- specs/{{feature_slug}}/acceptance-tests.md
- specs/{{feature_slug}}/traceability.md

### Scope
{{scope}}

### Done When
- [ ] Implementation complete
- [ ] Required tests added or updated
- [ ] Related regression tests pass
- [ ] Implementation report created
- [ ] Quality gate passes
- [ ] traceability.md updated with T-001 → {{requirement_ids}} mapping
- [ ] (high/critical) Red→Green evidence captured
- [ ] (high/critical) Independent review verdict recorded
- [ ] (critical) Second approver recorded and evidence bundle signed

### Out of Scope
{{out_of_scope}}

### Blockers
None
