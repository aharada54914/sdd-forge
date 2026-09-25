# Traceability: sdd-domain-multitarget (Issue #423 Phase 1)

## Baseline and Re-verification

The Issue #423 description identifies `08baf03a45c7d47f5bc5e73bf2519e47ea500a5d`
as its 2026-09-13 investigation baseline. This Phase 1 specification was
reviewed on 2026-09-23 against then-current `origin/main`
(`2b328e4050f6a2e3fbb647fc9530fcc55ac7ec70`, as recorded in
requirements.md and design.md). The repository facts are review-time
assertions, not claims that the older Issue baseline remains current. Re-run
the source checks at specification review, task decomposition, and immediately
before implementation planning, and update/review the relevant claims if
behavior has changed.

Between the Issue baseline and the review baseline, the following cited
consumers changed: `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md`
adds a Capability Interview Phase; its `templates/design.template.md` adds
ownership, contract, state/failure, and workflow-position guidance;
`plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/references/architecture-review-checklist.md`
adds responsibility-boundary and contract/failure criteria; and
`plugins/sdd-quality-loop/scripts/check-contract.py` validates optional
per-check execution fields. Other cited baseline files checked in this review
have no diff between the Issue baseline and review baseline: ADR-0016,
ADR-0017, ADR-0018, the design-sync-loop skill, and the ci-mcp server/client.
These statements must be re-verified at each listed checkpoint because main is
shared and continues to change.

## Requirement to Acceptance Coverage

| Requirement | Acceptance criteria | Coverage evidence |
|---|---|---|
| REQ-001 Consumer disposition | AC-001, AC-012 | TEST-001a–001h individually inspect the consumer groups; TEST-012 checks ci-mcp and Core boundary. |
| REQ-002 Capability and ownership boundaries | AC-002, AC-010, AC-011, AC-012 | TEST-002 checks ownership/schema; TEST-010 checks normalized provider evidence; TEST-011 checks host semantics; TEST-012 checks read-only ci-mcp/Core boundary. |
| REQ-003 Verification selection and evidence | AC-003, AC-004, AC-010, AC-013 | TEST-003a–003e are separate target fixtures; TEST-004 checks required/optional/unavailable/not-applicable outcomes; TEST-010 distinguishes simulated/real; TEST-013 limits stages to implementation. |
| REQ-004 Compatibility and migration | AC-005, AC-006, AC-007, AC-011 | TEST-005 covers no-context behavior; TEST-006 covers hybrid output; TEST-007 covers versioned contracts/readers/writers; TEST-011 covers cross-host semantics. |
| REQ-005 UI provider extraction | AC-008, AC-009 | TEST-008a–008g separately cover non-UI selection, local artifacts, unavailable tool, file import, and per-feature/standing/off consent; TEST-009a–009b check no-upload and non-blocking fallback outcomes. |
| REQ-006 Reviewable target examples | AC-003, AC-010 | TEST-003a–003e provide five distinct target fixtures; TEST-010 distinguishes provider simulation from real observation. |

## Acceptance Criteria to Test Rows

| Acceptance criterion | Test rows |
|---|---|
| AC-001 | TEST-001a, TEST-001b, TEST-001c, TEST-001d, TEST-001e, TEST-001f, TEST-001g, TEST-001h, TEST-001i |
| AC-002 | TEST-002 |
| AC-003 | TEST-003a (CLI/library), TEST-003b (UI), TEST-003c (design-only candidate selection and separate gate evaluation), TEST-003d (IaC/cloud), TEST-003e (low-code) |
| AC-004 | TEST-004 |
| AC-005 | TEST-005 |
| AC-006 | TEST-006 |
| AC-007 | TEST-007 |
| AC-008 | TEST-008a, TEST-008b, TEST-008c, TEST-008d, TEST-008e, TEST-008f, TEST-008g |
| AC-009 | TEST-009a (decline/not-permitted/off), TEST-009b (provider unavailable under per-feature/standing/off) |
| AC-010 | TEST-010 |
| AC-011 | TEST-011 |
| AC-012 | TEST-012 |
| AC-013 | TEST-013 |
| AC-014 | TEST-014 (implementation release evidence roll-up; not a substitute for the specific tests above) |

## Requirement to Design and Layer Anchors

| Requirement | Design location | Layer Spec |
|---|---|---|
| REQ-001 | Consumer Disposition; Compatibility Strategy | N/A — cross-layer only: shared workflow policy |
| REQ-002 | Architecture and Ownership; Consumer Disposition; UI Provider Boundary | N/A — cross-layer only: ownership and contract boundaries |
| REQ-003 | Resolution Model; Target Selection Examples; Test and Evidence Strategy | N/A — cross-layer only: resolver and evidence policy |
| REQ-004 | Compatibility Strategy; Constraints and Deferred Decisions | N/A — cross-layer only: migration compatibility |
| REQ-005 | UI Provider Boundary; Compatibility Strategy; Test and Evidence Strategy | N/A — cross-layer only: provider boundary |
| REQ-006 | Target Selection Examples | N/A — cross-layer only: reviewable examples |

## Requirement to Task Anchors

| Task | Requirements | Acceptance criteria | Test rows |
|---|---|---|---|
| T-001 | REQ-001 | AC-001 | TEST-001a, TEST-001b, TEST-001c, TEST-001d, TEST-001e, TEST-001f, TEST-001g, TEST-001h, TEST-001i |
| T-002 | REQ-001, REQ-002 | AC-002, AC-012 | TEST-002, TEST-012 |
| T-003 | REQ-003, REQ-006 | AC-003, AC-004, AC-013 | TEST-003a, TEST-003b, TEST-003c, TEST-003d, TEST-003e, TEST-004, TEST-013 |
| T-004 | REQ-004 | AC-005, AC-006, AC-007 | TEST-005, TEST-006, TEST-007 |
| T-005 | REQ-005 | AC-008, AC-009 | TEST-008a, TEST-008b, TEST-008c, TEST-008d, TEST-008e, TEST-008f, TEST-008g, TEST-009a, TEST-009b |
| T-006 | REQ-002, REQ-004, REQ-005, REQ-006 | AC-010, AC-011, AC-014 | TEST-010, TEST-011, TEST-014 |

Task review status is `Pending`; all task approvals remain `Draft` until the
task-review gate and explicit human approval are complete.
