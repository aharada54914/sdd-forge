# Traceability: epic-159-pillar-a

Every Layer Spec cell contains one or more canonical layer-spec anchors, or a
reasoned cross-layer N/A.

| Requirement | Investigation | Layer Spec | Design | API/Schema | Code Target | Test ID | Test Target | Evidence | Status |
|---|---|---|---|---|---|---|---|---|---|
| REQ-001 | investigation.md INV-001..INV-004, INV-010, INV-019 | infra-spec.md#cicd-sequence; security-spec.md#trust-boundaries | design.md#api--contract-plan; design.md#components | New `loop-inventory/v1` registry schema; closed `fixture_profiles` vocabulary greenfield/brownfield (ADR-0010) | tests/loops/loop-inventory.json; tests/loop-inventory.tests.sh; tests/loop-inventory.tests.ps1; tests/run-all.sh; tests/run-all.ps1; .github/workflows/test.yml; docs/adr/0010-loop-inventory-and-fixture-vocabulary.md | TEST-001, TEST-002, TEST-003, TEST-004, TEST-017 | tests/loop-inventory.tests.sh; tests/loop-inventory.tests.ps1 | reports/quality-gate/ for T-001; specs/epic-159-pillar-a/verification/T-001/ | Planned |
| REQ-002 | investigation.md INV-005..INV-010 | security-spec.md#trust-boundaries; infra-spec.md#runtime-dependencies | design.md#api--contract-plan; design.md#test-strategy | New sourced loop-driver contract: `loop_fixture_init`, `drive_review_round`, `assert_artifacts_schema`, `assert_terminal`, `assert_runtime_budget`; env `SDD_LOOP_REPO_ROOT`, `LOOP_INVENTORY_PATH` | tests/lib/loop-driver.sh; tests/lib/loop-driver.ps1; tests/loop-driver.tests.sh; tests/loop-driver.tests.ps1 | TEST-005, TEST-006, TEST-007, TEST-017 | tests/loop-driver.tests.sh; tests/loop-driver.tests.ps1 | reports/quality-gate/ for T-002; specs/epic-159-pillar-a/verification/T-002/ | Planned |
| REQ-003 | investigation.md INV-011..INV-013, INV-022 | security-spec.md#security-tests; infra-spec.md#cicd-sequence | design.md#test-strategy; design.md#architecture | No new contract; drives the REAL prechecks and `validate-review-context-set.sh --reserve` read-only; RED differential via `SDD_LOOP_REPO_ROOT` at `2d8c6a5^` | tests/loop-consistency.tests.sh; tests/loop-consistency.tests.ps1 | TEST-008, TEST-009, TEST-010, TEST-017 | tests/loop-consistency.tests.sh; tests/loop-consistency.tests.ps1 | reports/quality-gate/ for T-003; specs/epic-159-pillar-a/verification/T-003/ (green.log + red-differential.log) | Planned |
| REQ-004 | investigation.md INV-014..INV-017 | security-spec.md#authorization; infra-spec.md#runtime-dependencies | design.md#a4-parity-extension-placement-decision; design.md#test-strategy | No new contract; drives existing script contracts read-only (cycle-limit continue/Escalate-Human; `select-agent-model.sh` next_tier; `contracts/terminal-tier-blocked-state.schema.json`; `check-terminal-tier-resume.sh` deny/permit) | tests/loop-escalation.tests.sh; tests/loop-escalation.tests.ps1 | TEST-011, TEST-012, TEST-013, TEST-017, TEST-018 | tests/loop-escalation.tests.sh; tests/loop-escalation.tests.ps1 | reports/quality-gate/ for T-004; specs/epic-159-pillar-a/verification/T-004/ | Planned |
| REQ-005 | investigation.md INV-020, INV-021 | infra-spec.md#deployment-topology; infra-spec.md#cicd-sequence | design.md#deployment--ci-plan; design.md#constraint-compliance | Twin-pair (`.sh`/`.ps1`) convention; no protocol change; explicit recorded degradation diagnostics | all new twins under tests/ and tests/lib/; tests/run-all.sh; tests/run-all.ps1; .github/workflows/test.yml | TEST-004, TEST-008, TEST-013, TEST-014, TEST-015 | tests/crlf-parity.tests.sh; tests/constant-parity.tests.sh; the four new suites' recorded SKIP paths | reports/quality-gate/ for T-001..T-004 (each task's own twins) | Planned |
| REQ-006 | N/A — epic #159 doc-following and versioning Done conditions; no investigation surface | N/A — cross-layer only: documentation and versioning duties spanning every deliverable; the affected-document list lives in requirements.md REQ-006 | design.md#constraint-compliance | No API change; `CHANGELOG.md` `## Unreleased` entries citing #141/#142/#143/#144; version bumps only via `scripts/bump-version.sh` | CHANGELOG.md; README.md / USERGUIDE.md / docs/workflow-guide.md / docs/skill-reference.md / docs/agent-capability-matrix.md / PLUGIN-CONTRACTS.md / docs/troubleshooting.md / docs/contributor/* (whichever apply) | TEST-016 | tests/validate-repository.sh; CHANGELOG.md `## Unreleased` section | reports/quality-gate/ for T-001..T-004 (each task's own issue number) | Planned |

## Layer Coverage

| Layer | Applicable Requirements | Acceptance Criteria | Primary Sections | Gaps / Reasoned N/A |
|---|---|---|---|---|
| UX | N/A — no user-facing UI | N/A — test infrastructure | ux-spec.md#scope-and-user-journeys | No rendered or interactive surface; UX spec records this as N/A. |
| Frontend | N/A — no browser/frontend bundle | N/A — test infrastructure | frontend-spec.md#technology-stack | Shell/PowerShell/JSON test infrastructure is not a frontend surface. |
| Infrastructure | REQ-001, REQ-005 | AC-004, AC-014, AC-015, AC-017 | infra-spec.md#cicd-sequence; infra-spec.md#runtime-budget | Suite registration on the existing 3-OS matrix, deterministic lane; no deployment topology change. |
| Security | REQ-002, REQ-003, REQ-004 | AC-005, AC-010, AC-011, AC-012 | security-spec.md#trust-boundaries; security-spec.md#security-tests | Fixture isolation (B1), read-only non-decreasing gate driving (B2), hook-guard payload constraints (B3). |

## Task Mapping

| Task | Requirements | Acceptance Tests | Planned Verification Evidence |
|---|---|---|---|
| T-001 | REQ-001, REQ-005, REQ-006 | TEST-001, TEST-002, TEST-003, TEST-004, TEST-017 (loop-inventory leg); TEST-014/TEST-015/TEST-016 shares scoped to this task's files and issue #141 | implementation report with acceptance-first evidence, independent quality-gate report, specs/epic-159-pillar-a/verification/T-001/green.log |
| T-002 | REQ-002, REQ-005, REQ-006 | TEST-005, TEST-006, TEST-007, TEST-017 (loop-driver smoke leg); TEST-014/TEST-015/TEST-016 shares scoped to this task's files and issue #142 | implementation report with acceptance-first evidence, independent quality-gate report, specs/epic-159-pillar-a/verification/T-002/green.log |
| T-003 | REQ-003, REQ-005, REQ-006 | TEST-008, TEST-009, TEST-010, TEST-017 (loop-consistency leg); TEST-014/TEST-015/TEST-016 shares scoped to this task's files and issue #143 | implementation report with acceptance-first evidence and the recorded RED differential, independent quality-gate report, specs/epic-159-pillar-a/verification/T-003/green.log, specs/epic-159-pillar-a/verification/T-003/red-differential.log |
| T-004 | REQ-004, REQ-005, REQ-006 | TEST-011, TEST-012, TEST-013, TEST-018, TEST-017 (loop-escalation leg); TEST-014/TEST-015/TEST-016 shares scoped to this task's files and issue #144 | implementation report with acceptance-first evidence, independent quality-gate report, specs/epic-159-pillar-a/verification/T-004/green.log |

## Acceptance Mapping

| Acceptance Criterion | Test ID | Task |
|---|---|---|
| AC-001 | TEST-001 | T-001 |
| AC-002 | TEST-002 | T-001 |
| AC-003 | TEST-003 | T-001 |
| AC-004 | TEST-004 | T-001 |
| AC-005 | TEST-005 | T-002 |
| AC-006 | TEST-006 | T-002 |
| AC-007 | TEST-007 | T-002 |
| AC-008 | TEST-008 | T-003 |
| AC-009 | TEST-009 | T-003 |
| AC-010 | TEST-010 | T-003 |
| AC-011 | TEST-011 | T-004 |
| AC-012 | TEST-012 | T-004 |
| AC-013 | TEST-013 | T-004 |
| AC-014 | TEST-014 | T-001, T-002, T-003, T-004 (each task's own twins) |
| AC-015 | TEST-015 | T-001, T-002, T-003, T-004 (each task's own suites' recorded SKIPs) |
| AC-016 | TEST-016 | T-001, T-002, T-003, T-004 (each task's own issue number in CHANGELOG) |
| AC-017 | TEST-017 | T-001, T-002, T-003, T-004 (one runtime-budget assertion per suite) |
| AC-018 | TEST-018 | T-004 |

## Final Status

Update requirement status only from saved test evidence and quality-gate reports.
Implementation reports are claims, not independent verification evidence.
