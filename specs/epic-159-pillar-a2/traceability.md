# Traceability: epic-159-pillar-a2

Every Layer Spec cell contains one or more canonical layer-spec anchors, or a
reasoned cross-layer N/A.

| Requirement | Investigation | Layer Spec | Design | API/Schema | Code Target | Test ID | Test Target | Evidence | Status |
|---|---|---|---|---|---|---|---|---|---|
| REQ-001 | investigation.md INV-001..INV-008, INV-029..INV-032 | security-spec.md#trust-boundaries (B1/B4); infra-spec.md#runtime-budget | design.md#api--contract-plan (HITL leg + WFI-audit reference check); design.md#constraint-compliance (CI-resilience rows) | No new contract; drives a fixture copy of `hitl-loop.template.sh` and pins the documented one-directional WFI-audit invariant (`Audit-Attempt >= 3 -> Human-Blocked`; absent field = 0) as a labeled reference check with SHA-256-invariant read-only real-document smoke | tests/hitl-wfi-terminal.tests.sh; tests/hitl-wfi-terminal.tests.ps1; tests/run-all.sh; tests/run-all.ps1; .github/workflows/test.yml | TEST-001, TEST-002, TEST-003, TEST-004, TEST-005, TEST-006, TEST-018 | tests/hitl-wfi-terminal.tests.sh; tests/hitl-wfi-terminal.tests.ps1 | reports/quality-gate/ for T-001; specs/epic-159-pillar-a2/verification/T-001/ | Planned |
| REQ-002 | investigation.md INV-009..INV-012, INV-037 | security-spec.md#trust-boundaries (B1/B2); infra-spec.md#cicd-sequence | design.md#api--contract-plan (seed layout + lock contract + brownfield leg); design.md#constraint-compliance | Canonical brownfield seed instantiating the ADR-0010 `brownfield` profile; existing `check-placeholders` CLI contract and loop-driver `LOOP_FIXTURE_SEED` contract driven unchanged | tests/fixtures/loops/brownfield-seed/ (src/base.py, src/legacy_util.py, src/service.py, specs/brownfield-seed-demo/tasks.md, CHANGED_FILES.txt); tests/check-placeholders-brownfield.tests.sh; tests/check-placeholders-brownfield.tests.ps1; tests/loop-consistency.tests.sh; tests/loop-consistency.tests.ps1 | TEST-007, TEST-008, TEST-009, TEST-010, TEST-018 | tests/check-placeholders-brownfield.tests.sh; tests/check-placeholders-brownfield.tests.ps1; tests/loop-consistency.tests.sh; tests/loop-consistency.tests.ps1 | reports/quality-gate/ for T-002; specs/epic-159-pillar-a2/verification/T-002/ | Planned |
| REQ-003 | investigation.md INV-013, INV-014, INV-016, INV-018..INV-020 | security-spec.md#stride-analysis (weakened-port threat); infra-spec.md#cicd-sequence (no new CI step) | design.md#api--contract-plan (precheck-port contract + guard-ps1-ascii extension); design.md#test-strategy item 3 | Full-parity `.ps1` port of the existing `domain-review-precheck.sh` contract (feature-less `-Attempt`/`-Round`/`-EditSummary`/`-Reset`); no caller change — self-healing dispatch at tests/lib/loop-driver.ps1:211 | plugins/sdd-domain/scripts/domain-review-precheck.ps1; tests/guard-ps1-ascii.tests.sh | TEST-011, TEST-012, TEST-013 | tests/guard-ps1-ascii.tests.sh; tests/loop-consistency.tests.ps1 (domain leg SKIP-to-green, unmodified) | reports/quality-gate/ for T-003; specs/epic-159-pillar-a2/verification/T-003/ | Planned |
| REQ-004 | investigation.md INV-013, INV-015, INV-016, INV-021 | security-spec.md#stride-analysis (weakened-port threat); infra-spec.md#observability (decreasing-SKIP observable) | design.md#api--contract-plan (precheck-port contract); design.md#test-strategy item 3 | Full-parity `.ps1` port of the existing `spec-review-precheck.sh` contract (`-Feature`/`-Attempt`/`-Round`/`-EditSummary`/`-Reset`); no caller change — self-healing dispatch at tests/lib/loop-driver.ps1:206 | plugins/sdd-review-loop/scripts/spec-review-precheck.ps1; tests/guard-ps1-ascii.tests.sh | TEST-014, TEST-015, TEST-016 | tests/guard-ps1-ascii.tests.sh; tests/loop-driver.tests.ps1 + tests/loop-consistency.tests.ps1 (spec/impl/task legs SKIP-to-green, unmodified) | reports/quality-gate/ for T-004; specs/epic-159-pillar-a2/verification/T-004/ | Planned |
| REQ-005 | investigation.md INV-021, INV-025..INV-028 | infra-spec.md#deployment-topology; infra-spec.md#cicd-sequence | design.md#deployment--ci-plan; design.md#constraint-compliance | Twin-pair (`.sh`/`.ps1`) convention; no protocol change; explicit recorded degradation diagnostics; self-healing SKIP-to-green as the cross-host recovery observable | tests/hitl-wfi-terminal.* and tests/check-placeholders-brownfield.* twins; the two new plugins/**/*.ps1 files completing existing pairs; tests/run-all.sh; tests/run-all.ps1; .github/workflows/test.yml | TEST-006, TEST-010, TEST-013, TEST-016, TEST-017 | tests/crlf-parity.tests.sh; tests/constant-parity.tests.sh; tests/guard-ps1-ascii.tests.sh; the suites' recorded SKIP paths | reports/quality-gate/ for T-001..T-004 (each task's own twins) | Planned |
| REQ-006 | N/A — epic #159 doc-following and versioning Done conditions; no investigation surface | N/A — cross-layer only: documentation and versioning duties spanning every deliverable; the affected-document list lives in requirements.md REQ-006 | design.md#constraint-compliance | No API change; `CHANGELOG.md` `## Unreleased` entries citing #145/#146/#147/#174; version bumps only via `scripts/bump-version.sh` | CHANGELOG.md; README.md / USERGUIDE.md / docs/workflow-guide.md / docs/skill-reference.md / docs/agent-capability-matrix.md / PLUGIN-CONTRACTS.md / docs/troubleshooting.md / docs/contributor/* (whichever apply) | TEST-019 | tests/validate-repository.sh; CHANGELOG.md `## Unreleased` section | reports/quality-gate/ for T-001..T-004 (each task's own issue number) | Planned |

## Layer Coverage

| Layer | Applicable Requirements | Acceptance Criteria | Primary Sections | Gaps / Reasoned N/A |
|---|---|---|---|---|
| UX | N/A — no user-facing UI | N/A — test infrastructure and precheck script ports | ux-spec.md#scope-and-user-journeys | No rendered or interactive surface; UX spec records this as N/A. |
| Frontend | N/A — no browser/frontend bundle | N/A — test infrastructure and precheck script ports | frontend-spec.md#technology-stack | Shell/PowerShell/fixture test infrastructure is not a frontend surface. |
| Infrastructure | REQ-001, REQ-002, REQ-005 | AC-006, AC-010, AC-017, AC-018 | infra-spec.md#cicd-sequence; infra-spec.md#runtime-budget; infra-spec.md#observability | Two new suite registrations on the existing 3-OS matrix, deterministic lane; T-003/T-004 add NO CI step (picked up by existing pwsh steps via self-healing). |
| Security | REQ-001, REQ-002, REQ-003, REQ-004 | AC-003, AC-004, AC-005, AC-008, AC-009, AC-011, AC-014 | security-spec.md#trust-boundaries; security-spec.md#security-tests | Fixture isolation (B1), read-only non-decreasing gate driving and full-parity port requirement (B2), hook-guard payload constraints (B3), gh-non-invocation by construction (B4). |

## Task Mapping

| Task | Requirements | Acceptance Tests | Planned Verification Evidence |
|---|---|---|---|
| T-001 | REQ-001, REQ-005, REQ-006 | TEST-001, TEST-002, TEST-003, TEST-004, TEST-005, TEST-006; TEST-017/TEST-018/TEST-019 shares scoped to this task's files and issue #145 | implementation report with acceptance-first evidence, independent quality-gate report, specs/epic-159-pillar-a2/verification/T-001/green-sh.log, specs/epic-159-pillar-a2/verification/T-001/red-sh.log |
| T-002 | REQ-002, REQ-005, REQ-006 | TEST-007, TEST-008, TEST-009, TEST-010; TEST-017/TEST-018/TEST-019 shares scoped to this task's files and issue #146 | implementation report with acceptance-first evidence, independent quality-gate report, specs/epic-159-pillar-a2/verification/T-002/green-sh.log, specs/epic-159-pillar-a2/verification/T-002/red-sh.log |
| T-003 | REQ-003, REQ-005, REQ-006 | TEST-011, TEST-012, TEST-013; TEST-017/TEST-019 shares scoped to this task's pair and issue #147 | implementation report with the before/after SKIP counts (pre-landing named SKIP = recorded red side), independent quality-gate report, specs/epic-159-pillar-a2/verification/T-003/green-sh.log, specs/epic-159-pillar-a2/verification/T-003/red-sh.log |
| T-004 | REQ-004, REQ-005, REQ-006 | TEST-014, TEST-015, TEST-016; TEST-017/TEST-019 shares scoped to this task's pair and issue #174 | implementation report with the before/after SKIP counts across both wave-1 suites, independent quality-gate report, specs/epic-159-pillar-a2/verification/T-004/green-sh.log, specs/epic-159-pillar-a2/verification/T-004/red-sh.log |

## Acceptance Mapping

| Acceptance Criterion | Test ID | Task |
|---|---|---|
| AC-001 | TEST-001 | T-001 |
| AC-002 | TEST-002 | T-001 |
| AC-003 | TEST-003 | T-001 |
| AC-004 | TEST-004 | T-001 |
| AC-005 | TEST-005 | T-001 |
| AC-006 | TEST-006 | T-001 |
| AC-007 | TEST-007 | T-002 |
| AC-008 | TEST-008 | T-002 |
| AC-009 | TEST-009 | T-002 |
| AC-010 | TEST-010 | T-002 |
| AC-011 | TEST-011 | T-003 |
| AC-012 | TEST-012 | T-003 |
| AC-013 | TEST-013 | T-003 |
| AC-014 | TEST-014 | T-004 |
| AC-015 | TEST-015 | T-004 |
| AC-016 | TEST-016 | T-004 |
| AC-017 | TEST-017 | T-001, T-002 (new twins), T-003, T-004 (completing existing pairs) |
| AC-018 | TEST-018 | T-001, T-002 (the two tasks adding `.sh` suites; T-003/T-004 add no bash suite — their `.ps1` hygiene is AC-012/AC-015) |
| AC-019 | TEST-019 | T-001, T-002, T-003, T-004 (each task's own issue number in CHANGELOG) |

## Deliverables (Per Task)

| Task | Issue | New Files | Edited Files |
|---|---|---|---|
| T-001 | #145 | tests/hitl-wfi-terminal.tests.sh; tests/hitl-wfi-terminal.tests.ps1 | tests/run-all.sh; tests/run-all.ps1; .github/workflows/test.yml; CHANGELOG.md (+ affected docs per REQ-006) |
| T-002 | #146 | tests/fixtures/loops/brownfield-seed/ (src/base.py, src/legacy_util.py, src/service.py, specs/brownfield-seed-demo/tasks.md, CHANGED_FILES.txt); tests/check-placeholders-brownfield.tests.sh; tests/check-placeholders-brownfield.tests.ps1 | tests/loop-consistency.tests.sh; tests/loop-consistency.tests.ps1; tests/run-all.sh; tests/run-all.ps1; .github/workflows/test.yml; CHANGELOG.md (+ affected docs); tests/lib/loop-driver.sh/.ps1 listed per INV-037 with a no-edit expectation |
| T-003 | #147 | plugins/sdd-domain/scripts/domain-review-precheck.ps1 | tests/guard-ps1-ascii.tests.sh (TARGET → TARGETS generalization + entry); CHANGELOG.md (+ affected docs) |
| T-004 | #174 | plugins/sdd-review-loop/scripts/spec-review-precheck.ps1 | tests/guard-ps1-ascii.tests.sh (one-line TARGETS entry after T-003); CHANGELOG.md (+ affected docs) |

## Final Status

Update requirement status only from saved test evidence and quality-gate reports.
Implementation reports are claims, not independent verification evidence.
