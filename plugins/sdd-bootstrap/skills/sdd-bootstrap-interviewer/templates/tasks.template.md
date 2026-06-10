# Tasks: {{feature_name}}

## Lifecycle

`Draft -> Approved -> In Progress -> Implementation Complete -> Done`

A task may enter `Blocked` from any active state. Humans approve tasks.
`implement-task` may set `In Progress`, `Blocked`, or `Implementation Complete`.
Only `quality-gate` may set `Done`.

## T-001 {{task_001_title}}

Source Issue: {{source_issue}}

Approval: Draft

Status: Planned

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
- [ ] traceability.md updated

### Out of Scope
{{out_of_scope}}

### Blockers
None
