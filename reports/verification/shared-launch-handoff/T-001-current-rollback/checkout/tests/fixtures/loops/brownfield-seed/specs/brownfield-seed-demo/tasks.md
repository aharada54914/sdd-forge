# Tasks: brownfield-seed-demo

Task-Review-Status: Passed

## Lifecycle

`Draft -> Approved -> In Progress -> Implementation Complete -> Done`

A task may enter `Blocked` from any active state. Humans approve tasks.
`implement-task` may set `In Progress`, `Blocked`, or `Implementation Complete`.
Only `quality-gate` may set `Done`.

## T-001 Seed demo task

Source Issue: none (canonical brownfield seed fixture; epic-159-pillar-a2 T-002 / Issue #146)

Approval: Approved

Status: Done

Risk: low

Risk Rationale: Inert fixture data, scanned and copied only; never driven
through a review loop.

Required Workflow: acceptance-first

Requirements: REQ-001

Planned Files: src/service.py

Data Migration: none

Breaking API: no

### Goal

Demonstrate a bootstrap-complete tasks.md structure inside the canonical
brownfield seed.

### Must Read

- specs/brownfield-seed-demo/requirements.md

### Scope

Inert seed content only.

### Done When

- [x] Structure matches the bootstrap interviewer's template output.

### Out of Scope

Everything else.

### Blockers

None
