# Architecture Review Checklist

Architecture decisions and `design.md` content require human review and
explicit approval before any task leaves `Draft` status. AI agents must present
this checklist to the human and wait for a confirmed sign-off.

## Checklist

### Technology Choices

- [ ] Technology selection rationale is documented in an ADR.
- [ ] Trade-offs (performance, operability, cost, team familiarity) are stated.
- [ ] Rejected alternatives are listed with reasons.

### C4 Consistency

- [ ] `c4-context.md` identifies all external actors and systems.
- [ ] `c4-container.md` reflects the chosen deployment units.
- [ ] `c4-component.md` maps responsibility boundaries within each container.
- [ ] No responsibility is assigned to two components simultaneously.

### Contract Alignment

- [ ] OpenAPI or JSON Schema contracts match the design for every new or
  changed endpoint.
- [ ] Breaking changes are called out explicitly with a migration plan.

### Non-Functional Requirements

- [ ] Performance, scalability, and latency targets are stated or marked N/A.
- [ ] Observability (logging, metrics, tracing) approach is described.
- [ ] Availability and recovery requirements are addressed.

### Migration and Rollback

- [ ] A migration path from the current state is documented.
- [ ] A rollback procedure or feature-flag strategy is described.

### Security Boundaries

- [ ] Trust boundaries between components are drawn on at least one C4 diagram.
- [ ] Authentication and authorization approach is documented.
- [ ] Sensitive data flows are identified and protected.

### Refactor Mode (additional)

- [ ] Every `BL-xxx` baseline behavior is mapped to an acceptance criterion.
- [ ] The refactor scope does not introduce observable behavior changes beyond
  the approved list of intentional improvements.

## Gate

Present this checklist to the human reviewer. Keep all affected tasks at
`Approval: Draft` until the human explicitly confirms each applicable item.
Do not self-approve architectural decisions on behalf of the human.
