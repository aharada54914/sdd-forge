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
- [ ] Reviewed traceability.md mapping T-001 → {{requirement_ids}} verified; execution evidence recorded in implementation reports without editing review-frozen specifications
- [ ] (high/critical) Failing Red tests committed before implementation; Red commit ID and actual Red→Green execution evidence recorded
- [ ] (high/critical) Independent review verdict and the actual named reviewer/context ID recorded; reviewer differs from the implementer
- [ ] (critical) Second approver recorded and evidence bundle signed

If a Done When item depends on a case staying unchanged and a design clause can change that case from outside the task, name the design clause in the task plan so the contradiction is visible at review time.

### Out of Scope
{{out_of_scope}}

### Blockers
None
