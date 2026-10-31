# Traceability: epic-159-pillar-b

Every Layer Spec cell contains one or more canonical layer-spec anchors, or a
reasoned cross-layer N/A.

| Requirement | Investigation | Layer Spec | Design | API/Schema | Code Target | Test ID | Test Target | Evidence | Status |
|---|---|---|---|---|---|---|---|---|---|
| REQ-001 | investigation.md INV-001, INV-003, INV-004, INV-005, INV-009, INV-012, INV-013, INV-017 | security-spec.md#trust-boundaries; infra-spec.md#runtime-budget | design.md#api--contract-plan (bump-version.sh loop-gate prerequisite + fixture-copy test technique); design.md#constraint-compliance (CI-resilience rows) | No new contract; `scripts/bump-version.sh` gains a fail-closed loop-gate prerequisite that invokes `tests/loop-consistency.tests.sh` and `tests/loop-inventory.tests.sh` via `$ROOT`-relative paths, before any mutation step | scripts/bump-version.sh; tests/bump-version-gate.tests.sh; tests/bump-version-gate.tests.ps1; tests/run-all.sh; tests/run-all.ps1; .github/workflows/test.yml | TEST-001, TEST-002, TEST-003, TEST-004, TEST-005, TEST-006 | tests/bump-version-gate.tests.sh; tests/bump-version-gate.tests.ps1 | reports/quality-gate/ for T-001; specs/epic-159-pillar-b/verification/T-001/ | Planned |
| REQ-002 | investigation.md INV-006, INV-007, INV-011, INV-012 | security-spec.md#trust-boundaries; infra-spec.md#cicd-sequence | design.md#api--contract-plan (release.yml loop-gate job + needs: dependency); design.md#constraint-compliance | No new contract; `.github/workflows/release.yml` gains a new `loop-gate` job (runs the two real suites on `ubuntu-latest`) and the existing build job (`release:`) gains a `needs: loop-gate` dependency | .github/workflows/release.yml; tests/release-loop-gate.tests.sh; tests/release-loop-gate.tests.ps1; tests/run-all.sh; tests/run-all.ps1; .github/workflows/test.yml | TEST-007, TEST-008, TEST-009, TEST-010 | tests/release-loop-gate.tests.sh; tests/release-loop-gate.tests.ps1 | reports/quality-gate/ for T-002; specs/epic-159-pillar-b/verification/T-002/ | Planned |
| REQ-003 | investigation.md INV-009, INV-014 | N/A — cross-layer only: documentation and versioning duties spanning both tasks; the affected-document list lives in requirements.md REQ-003 | design.md#constraint-compliance (doc-following row) | No API change; `CHANGELOG.md` `## Unreleased` entry citing #148 (created by T-001, appended by T-002); new `docs/contributor/release-runbook.md` (bump-version section by T-001, release.yml section by T-002); `README.md`/`docs/troubleshooting.md` verified for release-procedure references | CHANGELOG.md; docs/contributor/release-runbook.md; README.md; docs/troubleshooting.md | TEST-011, TEST-012 | CHANGELOG.md `## Unreleased` section; docs/contributor/release-runbook.md; tests/validate-repository.sh | reports/quality-gate/ for T-001, T-002 | Planned |
| REQ-004 | investigation.md INV-008 | infra-spec.md#observability | design.md#design-decisions-resolving-open-questions (OQ-003 resolution); design.md#constraint-compliance | No API change; `scripts/` contains no `bump-version.ps1` twin by design decision (OQ-003); the recorded degradation is documented in `docs/contributor/release-runbook.md` | docs/contributor/release-runbook.md (degradation note); scripts/ (verified absence of bump-version.ps1) | TEST-013, TEST-014 | docs/contributor/release-runbook.md | reports/quality-gate/ for T-001; specs/epic-159-pillar-b/verification/T-001/ | Planned |
| REQ-006 | not a goal of this feature — requirements.md twice cites epic-159-pillar-a's REQ-006 versioning rule in prose (requirements.md REQ-003 body and Assumptions), and validate-layer-traceability.py collects every bare REQ-NNN token in requirements.md as a required row | N/A — cross-layer only: prose citation of the sibling feature's rule, carried here solely to satisfy the tokenizer; no task, test, or deliverable of this feature implements it | N/A | N/A | N/A | N/A | N/A | N/A | N/A |

## Layer Coverage

| Layer | Applicable Requirements | Acceptance Criteria | Primary Sections | Gaps / Reasoned N/A |
|---|---|---|---|---|
| UX | N/A — no user-facing UI | N/A — CLI/CI release-gate wiring | ux-spec.md#scope-and-user-journeys | No rendered or interactive surface; UX spec records this as N/A. |
| Frontend | N/A — no browser/frontend bundle | N/A — CLI/CI release-gate wiring | frontend-spec.md#technology-stack | Shell/PowerShell/YAML/Markdown release-gate wiring is not a frontend surface. |
| Infrastructure | REQ-001, REQ-002, REQ-004 | AC-006, AC-007, AC-008, AC-009, AC-010, AC-014 | infra-spec.md#cicd-sequence; infra-spec.md#runtime-budget; infra-spec.md#observability | The new `loop-gate` job runs `ubuntu-latest` only (`release.yml` has never had a 3-OS matrix, OQ-002 resolution); the two new suites join the existing `test.yml` 3-OS matrix. |
| Security | REQ-001, REQ-002 | AC-002, AC-003, AC-004, AC-008, AC-009 | security-spec.md#trust-boundaries; security-spec.md#stride-analysis | Weakened-gate/bypass threat mitigation (B2), fixture isolation (B1/B3), release-path integrity (B4). |

## Task Mapping

| Task | Requirements | Acceptance Tests | Planned Verification Evidence |
|---|---|---|---|
| T-001 | REQ-001, REQ-003 (share), REQ-004 | TEST-001, TEST-002, TEST-003, TEST-004, TEST-005, TEST-006; TEST-011/TEST-012 shares scoped to this task's files and issue #148; TEST-013, TEST-014 | implementation report with acceptance-first evidence, independent quality-gate report, specs/epic-159-pillar-b/verification/T-001/green-sh.log, specs/epic-159-pillar-b/verification/T-001/red-sh.log |
| T-002 | REQ-002, REQ-003 (share) | TEST-007, TEST-008, TEST-009, TEST-010; TEST-011/TEST-012 shares scoped to this task's files and issue #148 | implementation report with acceptance-first evidence, independent quality-gate report, specs/epic-159-pillar-b/verification/T-002/green-sh.log, specs/epic-159-pillar-b/verification/T-002/red-sh.log |

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
| AC-011 | TEST-011 | T-001 (CREATE the `## Unreleased` #148 entry), T-002 (APPEND to the same entry) |
| AC-012 | TEST-012 | T-001 (CREATE `docs/contributor/release-runbook.md`, bump-version section), T-002 (APPEND release.yml section) |
| AC-013 | TEST-013 | T-001 |
| AC-014 | TEST-014 | T-001 |

## Deliverables (Per Task)

| Task | Issue | New Files | Edited Files |
|---|---|---|---|
| T-001 | #148 | tests/bump-version-gate.tests.sh; tests/bump-version-gate.tests.ps1; docs/contributor/release-runbook.md (new — bump-version section) | scripts/bump-version.sh; tests/run-all.sh; tests/run-all.ps1; .github/workflows/test.yml; CHANGELOG.md (CREATE #148 entry); README.md (conditional, verify-only expected) |
| T-002 | #148 | tests/release-loop-gate.tests.sh; tests/release-loop-gate.tests.ps1 | .github/workflows/release.yml; tests/run-all.sh; tests/run-all.ps1; .github/workflows/test.yml; CHANGELOG.md (APPEND to the #148 entry T-001 created); docs/contributor/release-runbook.md (APPEND release.yml section); docs/troubleshooting.md (conditional, verify-only expected) |

## Final Status

Update requirement status only from saved test evidence and quality-gate reports.
Implementation reports are claims, not independent verification evidence.
