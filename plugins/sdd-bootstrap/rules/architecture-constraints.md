---
paths:
  - "specs/**"
  - "docs/architecture/**"
---

# SDD Architecture Constraints

## Architecture Documentation

Use lightweight C4-style documentation. Create:
- `c4-context.md`
- `c4-container.md`
- `c4-component.md`

Record important decisions as ADRs. Architecture docs must help AI agents answer:
- where code belongs
- which component owns which responsibility
- which external systems exist
- which data stores exist
- which boundaries must not be crossed

## Task Splitting

Good task:
- Fits in one PR/MR with one clear goal
- Has measurable Done When criteria
- Includes tests and limited file scope
- Can be reviewed independently

Bad task:
- Mixes frontend, backend, DB, auth, and E2E in one task
- Has no tests or depends on undocumented assumptions

Recommended order: skeleton/domain model → API/data contract → backend use case → backend endpoint → frontend → integration test → E2E → docs.
