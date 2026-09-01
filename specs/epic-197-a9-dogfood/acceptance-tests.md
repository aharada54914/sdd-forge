# Acceptance Tests: epic-197-a9-dogfood

All rows are Planned first-draft mappings. No test has been implemented or run.

| AC | REQ | TEST | Type | Assertion / Oracle | Status |
|---|---|---|---|---|---|
| AC-001 | REQ-001 | TEST-001 | automated | schema accepts exact Phase-1 tuple | Planned |
| AC-002 | REQ-001 | TEST-002 | security | missing/invalid binding rejected; human-copy path demonstrated | Planned |
| AC-003 | REQ-002 | TEST-003 | contract | component IDs/fields equal dated OQ-001 ruling | Planned |
| AC-004 | REQ-002 | TEST-004 | negative | omitted component and unjustified empty classification rejected | Planned |
| AC-005 | REQ-003 | TEST-005 | ownership | zero unexplained overlaps | Planned |
| AC-006 | REQ-003 | TEST-006 | ownership | zero unexplained unowned paths; shared rules verified | Planned |
| AC-007 | REQ-004 | TEST-007 | contract | plugin/MCP/installer/CI/release characteristics remain distinct | Planned |
| AC-008 | REQ-005 | TEST-008 | resolver | approved Pack validates and triggers representative component | Planned |
| AC-009 | REQ-005 | TEST-009 | scope | no desktop/cloud-service/new durable-workflow Pack added | Planned |
| AC-010 | REQ-006 | TEST-010 | integration | representative advisory run emits bound outputs/evidence | Planned |
| AC-011 | REQ-006 | TEST-011 | integration | Pack finding non-blocking; existing blockers unchanged | Planned |
| AC-012 | REQ-007 | TEST-012 | evidence | promotion record has every REQ-007 field and link | Planned |
| AC-013 | REQ-007 | TEST-013 | negative | unmet threshold and stale evidence each reject promotion | Planned |
| AC-014 | REQ-008 | TEST-014 | automated | schema/resolver accept exact Phase-2 tuple | Planned |
| AC-015 | REQ-008 | TEST-015 | negative | layout-only and enforcement-only transitions each reject | Planned |
| AC-016 | REQ-009 | TEST-016 | security | multi-identity rollback requires two distinct approvals | Planned |
| AC-017 | REQ-009 | TEST-017 | security | solo rollback rejects before and accepts at/after effective time | Planned |
| AC-018 | REQ-009 | TEST-018 | security | unsigned, self-approved, duplicate, unbound sidecars each reject | Planned |
| AC-019 | REQ-010 | TEST-019 | process | observed friction yields complete Draft WFI, never Approved | Planned |
| AC-020 | REQ-011 | TEST-020 | preflight | one absent/incompatible A1–A8 surface blocks with identity | Planned |
| AC-021 | REQ-011 | TEST-021 | preflight | six named shared-state inventories/hashes recorded | Planned |
| AC-022 | REQ-012 | TEST-022 | parity | applicable shell and PowerShell entry points pass | Planned |
| AC-023 | REQ-012 | TEST-023 | CI | checks run on three OSes in existing topology | Planned |
| AC-024 | REQ-012 | TEST-024 | regression | Phase 1/2 preserve three-host install/release behavior | Planned |
| AC-025 | REQ-013 | TEST-025 | ownership | `specs/` and every approved growing path are cross-cutting from bootstrap | Planned |
| AC-026 | REQ-014 | TEST-026 | provenance | all A1-A8 dependencies usable; #197 recorded under #187 | Planned |
| AC-027 | REQ-006 | TEST-027 | operational | every PR in one bounded full release cycle passed advisory Gate | Planned |
| AC-028 | REQ-008 | TEST-028 | end-to-end | one real post-promotion feature completes under facet-hybrid/required | Planned |
| AC-029 | REQ-010 | TEST-029 | process | friction WFI references recorded, or literal `none` when zero | Planned |

Coverage note: AC-015 expands both partial-transition branches; AC-018 expands
all four invalid-sidecar branches; AC-021's oracle covers Registry, guards,
components, Active Specs, WFI namespace, and protected targets individually.
AC-027 quantifies over every PR in the named cycle; AC-029 covers both observed
friction and zero-friction branches and names path ownership, staleness, and
approval flow individually.
