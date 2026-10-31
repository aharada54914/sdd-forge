# Traceability: sdd-domain-concept-test

Status: Planned — no implementation or acceptance test has passed. The Investigation column uses a reasoned N/A because this feature has no `investigation.md`; the cited existing-behavior evidence is in `requirements.md#existing-behavior-evidence`. These are planned code targets, not claims that the new files exist.

Dependency order for REQ-004: T-005 switches the independent v2 domain-sync consumer before T-003 verifies the signed bootstrap flow end to end; T-003 blocks on T-001, T-002, and T-005. High-risk T-001/T-003/T-004 require a separate named quality-gate evaluator PASS and tested fail-closed rollback evidence before Done.

| Requirement | Investigation | Design | Layer Spec | Task | Code Target | Test ID | Status |
|---|---|---|---|---|---|---|---|
| REQ-001 | N/A — no investigation.md; requirements.md#existing-behavior-evidence | design.md#architecture; design.md#data-plan | ux-spec.md#scope-and-user-journeys; frontend-spec.md#state-and-testing | T-001, T-002 | contracts/concept-test.v1.schema.json; plugins/sdd-domain/skills/concept-test/SKILL.md | TEST-001, TEST-002, TEST-003, TEST-004 | Planned |
| REQ-002 | N/A — no investigation.md; requirements.md#existing-behavior-evidence | design.md#architecture; design.md#data-plan | ux-spec.md#component-states; security-spec.md#trust-boundaries-and-stride | T-001, T-002 | plugins/sdd-domain/skills/concept-test/SKILL.md | TEST-008, TEST-009, TEST-023, TEST-024 | Planned |
| REQ-003 | N/A — no investigation.md; requirements.md#existing-behavior-evidence | design.md#data-plan; design.md#deterministic-gate; design.md#test-strategy | frontend-spec.md#state-and-testing; security-spec.md#authorization--data--owasp | T-001, T-003 | contracts/concept-test.v1.schema.json; contracts/approval-sidecar.schema.json; plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py; plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md | TEST-002, TEST-003, TEST-004, TEST-005, TEST-006, TEST-007, TEST-014, TEST-015, TEST-016, TEST-017, TEST-018, TEST-019, TEST-020, TEST-021, TEST-022, TEST-028, TEST-029, TEST-030, TEST-031, TEST-032, TEST-033, TEST-034, TEST-035, TEST-036, TEST-037, TEST-051, TEST-052, TEST-053, TEST-054, TEST-055, TEST-056, TEST-057, TEST-058, TEST-059, TEST-060, TEST-061, TEST-062, TEST-063, TEST-064, TEST-065, TEST-066, TEST-067, TEST-068, TEST-069, TEST-070, TEST-071, TEST-072, TEST-073, TEST-074, TEST-075, TEST-076, TEST-077, TEST-078 | Planned |
| REQ-004 | N/A — no investigation.md; requirements.md#existing-behavior-evidence | design.md#architecture; design.md#deterministic-gate | ux-spec.md#scope-and-user-journeys; infra-spec.md#deployment-topology--environments | T-003, T-005 | plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md; plugins/sdd-domain/skills/domain-sync/SKILL.md | TEST-010, TEST-011, TEST-022, TEST-035, TEST-038, TEST-039, TEST-040, TEST-041, TEST-042, TEST-043, TEST-044, TEST-045, TEST-046, TEST-075, TEST-076, TEST-077, TEST-078 | Planned |
| REQ-005 | N/A — no investigation.md; requirements.md#existing-behavior-evidence | design.md#review-context-and-release | infra-spec.md#ci-cd-and-supply; security-spec.md#trust-boundaries-and-stride | T-004 | plugins/sdd-quality-loop/scripts/validate-review-context-set.sh; plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1; review-context callers | TEST-012, TEST-025, TEST-026, TEST-027, TEST-047, TEST-048, TEST-049, TEST-050 | Planned |
| REQ-006 | N/A — no investigation.md; requirements.md#existing-behavior-evidence | design.md#review-context-and-release | infra-spec.md#ci-cd-and-supply | T-006 | plugins/sdd-domain/.claude-plugin/plugin.json; plugins/sdd-domain/.codex-plugin/plugin.json; plugins/sdd-domain/.plugin/plugin.json; release tests | TEST-013 | Planned |

## Layer Coverage

| Layer | Applicable Requirements | Acceptance Criteria | Primary Sections | Gaps / Reasoned N/A |
|---|---|---|---|---|
| UX | REQ-001, REQ-002, REQ-004 | AC-001, AC-008, AC-009, AC-011, AC-017 | ux-spec.md#scope-and-user-journeys; ux-spec.md#component-states | No GUI; shell skill asks for human confirmation. |
| Frontend | REQ-001, REQ-003, REQ-004 | AC-001–007, AC-011, AC-014–017 | frontend-spec.md#technology-stack--components--routes--api--budgets; frontend-spec.md#state-and-testing | No browser/client component. |
| Infrastructure | REQ-004, REQ-005, REQ-006 | AC-010–013, AC-018 | infra-spec.md#deployment-topology--environments; infra-spec.md#ci-cd-and-supply | No deployment or external upload in scope. |
| Security | REQ-002, REQ-003, REQ-005 | AC-002–009, AC-012, AC-014–018 | security-spec.md#trust-boundaries-and-stride; security-spec.md#authorization--data--owasp | Signed approval and input hash checks are mandatory. |

## Final Status

Update requirement status only from saved test evidence and quality-gate reports. Implementation reports are claims, not verification evidence. The accepted task plan and this table are raw-content bound by task-review; later evidence belongs in `specs/sdd-domain-concept-test/verification/` or implementation reports, not in these frozen rows.
