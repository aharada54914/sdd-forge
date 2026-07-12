# Traceability: epic-136-phase1-guards

Every Layer Spec cell contains one or more canonical layer-spec anchors, or a
reasoned cross-layer N/A.

| Requirement | Investigation | Layer Spec | Design | API/Schema | Code Target | Test ID | Test Target | Evidence | Status |
|---|---|---|---|---|---|---|---|---|---|
| REQ-001 | N/A — enforcement-chain hardening; observed behavior is in requirements.md | security-spec.md#trust-boundaries; security-spec.md#powershell-parity-note | design.md#components; design.md#test-strategy | Existing hook decision protocol and protected-suffix table; no format change | plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1 | TEST-001, TEST-002, TEST-003, TEST-015 | tests/guard-r10-port.tests.ps1; tests/guard-ps1-ascii.tests.sh | reports/quality-gate/ for T-001 | Planned |
| REQ-002 | N/A — enforcement-chain hardening; observed behavior is in requirements.md | security-spec.md#stride-analysis; security-spec.md#security-tests | design.md#test-strategy; design.md#security-boundaries | Existing hook decision protocol; no format change | plugins/sdd-quality-loop/scripts/sdd-hook-guard.py; plugins/sdd-quality-loop/scripts/sdd-hook-guard.js | TEST-004, TEST-005 | tests/guard-cwd-bypass.tests.sh | reports/quality-gate/ for T-002 | Planned |
| REQ-003 | N/A — enforcement-chain hardening; observed behavior is in requirements.md | infra-spec.md#ci-cd-sequence; security-spec.md#stride-analysis | design.md#api--contract-plan; design.md#test-strategy | New internal contract: task ID + repo root -> continue/Escalate-Human | plugins/sdd-quality-loop/scripts/check-quality-gate-cycle-limit.sh; plugins/sdd-quality-loop/scripts/check-quality-gate-cycle-limit.ps1; plugins/sdd-ship/skills/ship/SKILL.md | TEST-006 | tests/quality-gate-cycle-limit.tests.sh | reports/quality-gate/ for T-003 | Planned |
| REQ-004 | N/A — enforcement-chain hardening; observed behavior is in requirements.md | security-spec.md#authorization; security-spec.md#stride-analysis | design.md#api--contract-plan; design.md#cross-layer-dependencies | Two additive tasks.md fields (Security-Sensitive, Cross-Model-Waiver); lite-gate rejection | plugins/sdd-ship/skills/ship/SKILL.md | TEST-008, TEST-009, TEST-016 | ship/SKILL.md document conformance; lite-gate conformance | reports/quality-gate/ for T-004 | Planned |
| REQ-005 | N/A — enforcement-chain hardening; observed behavior is in requirements.md | infra-spec.md#deployment-topology; infra-spec.md#ci-cd-sequence | design.md#external-integrations; design.md#deployment--ci-plan | Minimized workflow permissions; deterministic pre-PR guard step | .github/workflows/self-improvement.yml | TEST-010, TEST-011, TEST-014 | tests/self-improvement-guard.tests.sh | reports/quality-gate/ for T-005 | Planned |
| REQ-006 | INV — issue #116 verdict (matcher coverage gap), recorded in requirements.md Problems | security-spec.md#trust-boundaries; security-spec.md#authentication-flow | design.md#architecture; design.md#test-strategy | Existing hook decision protocol; matcher coverage extension only | plugins/sdd-quality-loop/hooks/claude-hooks.json | TEST-012, TEST-013 | tests/claude-bash-matcher.tests.sh | reports/quality-gate/ for T-006 | Planned |

## Layer Coverage

| Layer | Applicable Requirements | Acceptance Criteria | Primary Sections | Gaps / Reasoned N/A |
|---|---|---|---|---|
| UX | N/A — no user-facing UI | N/A — CLI/CI hardening | ux-spec.md#scope-and-user-journeys | No rendered or interactive surface; UX spec records this as N/A. |
| Frontend | N/A — no browser/frontend bundle | N/A — CLI/CI hardening | frontend-spec.md#technology-stack | Shell/PowerShell/JS/YAML scripts are not a frontend surface. |
| Infrastructure | REQ-003, REQ-005 | AC-006, AC-010, AC-011, AC-014 | infra-spec.md#deployment-topology; infra-spec.md#ci-cd-sequence | CI permission change plus a new guard step; no deployment topology change. |
| Security | REQ-001, REQ-002, REQ-004, REQ-006 | AC-001, AC-002, AC-003, AC-004, AC-005, AC-008, AC-009, AC-012, AC-013, AC-015, AC-016 | security-spec.md#trust-boundaries; security-spec.md#security-tests | None. |

## Task Mapping

| Task | Requirements | Acceptance Tests | Planned Verification Evidence |
|---|---|---|---|
| T-001 | REQ-001 | TEST-001, TEST-002, TEST-003, TEST-015 | high-risk (critical) implementation report, cross-model consensus, signed evidence bundle, second approver, independent quality-gate report |
| T-002 | REQ-002 | TEST-004, TEST-005 | high-risk (critical) implementation report, RED evidence, cross-model consensus, signed evidence bundle, second approver, independent quality-gate report |
| T-003 | REQ-003 | TEST-006 | high-risk implementation report and independent quality-gate report |
| T-004 | REQ-004 | TEST-008, TEST-009, TEST-016 | high-risk implementation report and independent quality-gate report |
| T-005 | REQ-005 | TEST-010, TEST-011, TEST-014 | high-risk implementation report and independent quality-gate report |
| T-006 | REQ-006 | TEST-012, TEST-013 | high-risk implementation report, cross-model consensus, independent quality-gate report |

## Acceptance Mapping

| Acceptance Criterion | Test ID | Task |
|---|---|---|
| AC-001 | TEST-001 | T-001 |
| AC-002 | TEST-002 | T-001 |
| AC-003 | TEST-003 | T-001 |
| AC-004 | TEST-004 | T-002 |
| AC-005 | TEST-005 | T-002 |
| AC-006 | TEST-006 | T-003 |
| AC-007 | TEST-006 | T-003 |
| AC-008 | TEST-008 | T-004 |
| AC-009 | TEST-009 | T-004 |
| AC-010 | TEST-010 | T-005 |
| AC-011 | TEST-011 | T-005 |
| AC-012 | TEST-012 | T-006 |
| AC-013 | TEST-013 | T-006 |
| AC-014 | TEST-014 | T-005 |
| AC-015 | TEST-015 | T-001 |
| AC-016 | TEST-016 | T-004 |

## Final Status

Update requirement status only from saved test evidence and quality-gate reports.
Implementation reports are claims, not independent verification evidence.
