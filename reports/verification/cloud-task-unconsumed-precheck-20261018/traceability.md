# Traceability: cloud-orchestration

This is a planned map, not executed evidence. investigation.md records source
locations for the #423 audit; no INV identifiers were invented. Later outcomes
belong in task reports and verification addenda. Shared AC claims below have
explicit contract/admission/provider/observation/packaging scopes in tasks.md.

| Requirement | Investigation | Design | Layer Spec | Task | Code Target | Test ID | Evidence | Status |
|---|---|---|---|---|---|---|---|---|
| REQ-001 | investigation.md#existing-behavior-and-boundaries | design.md#data-plan | ux-spec.md#scope-and-user-journeys |  |  | TEST-001 (AC-001) |  | Planned |
| REQ-002 | investigation.md#existing-behavior-and-boundaries | design.md#normative-detailed-design-routing-and-dependencies | ux-spec.md#scope-and-user-journeys |  |  | TEST-002 (AC-002) |  | Planned |
| REQ-003 | investigation.md#existing-behavior-and-boundaries | design.md#normative-detailed-design-authorization-and-execution | infra-spec.md#cicd-sequence |  |  | TEST-003 (AC-003) |  | Planned |
| REQ-004 | investigation.md#existing-behavior-and-boundaries | design.md#api--contract-plan | security-spec.md#trust-boundaries |  |  | TEST-004 (AC-004) |  | Planned |
| REQ-005 | investigation.md#existing-behavior-and-boundaries | design.md#normative-detailed-design-authorization-and-execution | security-spec.md#trust-boundaries |  |  | TEST-005 (AC-005) |  | Planned |
| REQ-006 | investigation.md#existing-behavior-and-boundaries | design.md#normative-detailed-design-lifecycle-and-failure | infra-spec.md#cicd-sequence |  |  | TEST-006 (AC-006) |  | Planned |
| REQ-007 | investigation.md#existing-behavior-and-boundaries | design.md#normative-detailed-design-routing-and-dependencies | security-spec.md#trust-boundaries |  |  | TEST-007 (AC-007) |  | Planned |
| REQ-008 | investigation.md#existing-behavior-and-boundaries | design.md#data-plan | infra-spec.md#cicd-sequence |  |  | TEST-008 (AC-008) |  | Planned |
| REQ-009 | investigation.md#existing-behavior-and-boundaries | design.md#normative-detailed-design-observation-and-verification | infra-spec.md#cicd-sequence |  |  | TEST-009 (AC-009) |  | Planned |
| REQ-010 | investigation.md#existing-behavior-and-boundaries | design.md#data-plan | security-spec.md#trust-boundaries |  |  | TEST-010 (AC-010) |  | Planned |
| REQ-011 | investigation.md#existing-behavior-and-boundaries | design.md#public-invocation-contract | ux-spec.md#scope-and-user-journeys |  |  | TEST-011 (AC-011) |  | Planned |
| REQ-012 | investigation.md#existing-behavior-and-boundaries | design.md#unit-and-integration-boundaries | infra-spec.md#cicd-sequence |  |  | TEST-012 (AC-012) |  | Planned |
| REQ-013 | investigation.md#existing-behavior-and-boundaries | design.md#documentation-and-release-delivery | ux-spec.md#scope-and-user-journeys |  |  | TEST-013 (AC-013) |  | Planned |
| REQ-014 | investigation.md#existing-behavior-and-boundaries | design.md#documentation-and-release-delivery | infra-spec.md#cicd-sequence |  |  | TEST-014 (AC-014) |  | Planned |

## Layer coverage

| Layer | Tasks | Coverage and limit |
|---|---|---|
| UX | T-004, T-005, T-007, T-008 | CLI states, reachability, documented recovery; no graphical interface |
| Frontend | T-002, T-007 | frontend-spec.md#testing records CLI-only applicability; no browser state |
| Infrastructure | T-003, T-004, T-005, T-006, T-008 | Protected CI, exact artifacts, examples, readback; live scope prerequisites remain explicit |
| Security | T-002, T-003, T-004, T-005, T-006 | Strict paths/digests, real authorization, ownership, observations and secret exclusion |
