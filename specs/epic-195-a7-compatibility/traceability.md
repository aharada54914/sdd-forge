# Traceability: epic-195-a7-compatibility

Every Layer Spec cell contains one or more canonical layer-spec anchors,
or a reasoned cross-layer `N/A`. This feature has no UX surface (design.md
Layer Specifications; ux-spec.md), so no Layer Spec cell below cites
`ux-spec.md` directly — every REQ's own applicable layer content lives in
`infra-spec.md` and/or `security-spec.md`, matching this repository's own
established convention for CLI/script-only, no-GUI features
(`specs/epic-190-a2-capability-registry/traceability.md`'s identical
`security-spec.md#trust-boundaries`-anchored rows for its own UX/Frontend-N/A
feature). This feature likewise has no browser/frontend application of
its own, so `frontend-spec.md` is never load-bearing on its own merits;
its Technology Stack table is nonetheless the closest analog to a
"frontend" layer this CLI/script feature has, and REQ-002/REQ-003 cite
`frontend-spec.md#technology-stack` below on exactly that reasoned-analog
basis, consistent with this document's own Layer Coverage section, below.

| Requirement | Investigation | Layer Spec | Design | API/Schema | Code Target | Test ID | Test Target | Evidence | Status |
|---|---|---|---|---|---|---|---|---|---|
| REQ-001 | investigation.md INV-007, INV-009 | infra-spec.md#cicd-sequence | design.md#data-plan ("REQ-001 canonical target inventory"); design.md#test-strategy item 3 | golden-baseline manifest (T-002); no new schema | tests/compatibility-byte-identical.tests.{sh,ps1}; tests/install.tests.{sh,ps1}; tests/uninstall.tests.{sh,ps1} | TEST-002, TEST-003, TEST-038 | tests/compatibility-byte-identical.tests.sh; tests/compatibility-byte-identical.tests.ps1 | reports/quality-gate/ for T-003; specs/epic-195-a7-compatibility/verification/T-003/ | Planned |
| REQ-002 | investigation.md INV-017, INV-018, INV-024 | security-spec.md#trust-boundaries; frontend-spec.md#technology-stack | design.md#design-decisions-resolving-requirementsmds-open-questions-where-possible ("Structural-comparison seam"); design.md#test-strategy item 4 | `structural-fixture-corpus/v1` (design.md#data-plan) | tests/structural-compatibility.tests.{sh,ps1}; tests/lib/markdown-ast-canonicalizer.{sh,ps1}; tests/structural-compatibility-live-refresh.tests.{sh,ps1} | TEST-005, TEST-006, TEST-007, TEST-030, TEST-031, TEST-042, TEST-043 | tests/structural-compatibility.tests.sh; tests/structural-compatibility.tests.ps1; tests/structural-compatibility-live-refresh.tests.sh | reports/quality-gate/ for T-004, T-012; specs/epic-195-a7-compatibility/verification/{T-004,T-012}/ | Planned |
| REQ-003 | investigation.md INV-001–INV-006, INV-014, INV-021 | security-spec.md#trust-boundaries; frontend-spec.md#technology-stack | design.md#data-plan ("Canonical orchestration-event-trace schema"; "Collector API"; "Per-kind producer call sites"); design.md#api--contract-plan; design.md#test-strategy items 5-7 | `compatibility-event-trace/v1` (design.md#data-plan) | tests/loops/loop-inventory.json; tests/lib/loop-driver.{sh,ps1}; tests/loop-consistency.tests.{sh,ps1}; tests/loop-escalation.tests.{sh,ps1}; plugins/sdd-quality-loop/scripts/emit-run-record.{sh,ps1} | TEST-008, TEST-009, TEST-010, TEST-011, TEST-012, TEST-022, TEST-023, TEST-024, TEST-025, TEST-026, TEST-027, TEST-032, TEST-033, TEST-036, TEST-037, TEST-039 | tests/loop-inventory.tests.sh; tests/loop-consistency.tests.sh; tests/loop-escalation.tests.sh; tests/emit-run-record-feature-scope.tests.sh | reports/quality-gate/ for T-005, T-006, T-007, T-008, T-009; specs/epic-195-a7-compatibility/verification/{T-005,T-006,T-007,T-008,T-009}/ | Planned |
| REQ-004 | investigation.md (Root cause / rationale for an extension-only design) | N/A — cross-layer only: REQ-004 is a formal requirement-decomposition and citation-discipline concern (decision doc §4's exact sentence, decomposed into clauses (a)/(b)/(c) below), not owned by any single UX/frontend/infra/security layer — already satisfied by design.md's own Observable×fixture-state judgment table and this document's own clause mapping, below | design.md#data-plan ("Observable×fixture-state judgment table"); design.md's Compatibility Matrix disposition legend | N/A — no schema of its own | N/A — no code target; satisfied by requirements.md's own AC-001–AC-043 text and this document | TEST-013, TEST-017, TEST-029 | N/A — see Deferred / Non-Task Acceptance Criteria, below | this document (traceability review) | Satisfied at spec-authoring time — see Deferred / Non-Task Acceptance Criteria, below |
| REQ-005 | investigation.md INV-008, INV-011, INV-013, INV-024 | infra-spec.md#data-residency-and-retention | design.md#api--contract-plan ("Fixture-matrix builder contract"); design.md#data-plan ("`PROJECT_CONTEXT_INVALID` variant plan"; Compatibility Matrix; Context-absent CLI submatrix) | fixture-matrix builder's own five-parameter contract (design.md#api--contract-plan) | tests/lib/fixture-matrix-builder.{sh,ps1}; tests/promote-golden-baseline-ci-guard.tests.{sh,ps1} | TEST-014, TEST-015, TEST-028 | tests/lib/fixture-matrix-builder.sh; tests/lib/fixture-matrix-builder.ps1 (consumed, not independently registered, per design.md's own "never registered as its own independent test suite"); tests/run-all.sh; tests/run-all.ps1; .github/workflows/test.yml | reports/quality-gate/ for T-001, T-011; specs/epic-195-a7-compatibility/verification/{T-001,T-011}/ | In Progress — T-001 Done (quality-gate cycle-2 PASS, ledger seq0662, reports/quality-gate/epic-195-a7-compatibility/T-001.md); T-011 Planned |
| REQ-006 | investigation.md INV-022 | infra-spec.md#data-residency-and-retention; security-spec.md#trust-boundaries | design.md#api--contract-plan ("Golden-baseline capture/promote contract"); design.md#design-decisions-resolving-requirementsmds-open-questions-where-possible ("Golden-baseline location"); design.md#security-boundaries (B1) | golden-baseline manifest (per-target + script sha256, pinned commit SHA, fixed env vars — design.md#api--contract-plan) | tests/capture-golden-baseline.{sh,ps1}; tests/promote-golden-baseline.{sh,ps1}; tests/golden-baseline-contract.tests.{sh,ps1}; tests/promote-golden-baseline-ci-guard.tests.{sh,ps1} | TEST-001, TEST-018, TEST-040, TEST-041 | tests/golden-baseline-contract.tests.sh; tests/golden-baseline-contract.tests.ps1; tests/promote-golden-baseline-ci-guard.tests.sh; tests/promote-golden-baseline-ci-guard.tests.ps1 | reports/quality-gate/ for T-002, T-011; specs/epic-195-a7-compatibility/verification/{T-002,T-011}/ | In Progress — T-002 Done (quality-gate cycle-1 PASS, ledger seq0667, reports/quality-gate/epic-195-a7-compatibility/T-002.md); T-011 Planned |
| REQ-007 | investigation.md INV-015, INV-016, INV-023 | infra-spec.md#data-residency-and-retention; security-spec.md#trust-boundaries | design.md#data-plan ("REQ-007 SKIP allowlist manifest"; "`activation_condition` grammar and evaluator"); design.md#design-decisions-resolving-requirementsmds-open-questions-where-possible ("OQ-001 resolved"; "Cross-epic fingerprint citations") | `skip-allowlist-manifest/v1` (design.md#data-plan) | tests/fixtures/skip-allowlist-manifest.json; tests/lib/skip-allowlist-evaluator.{sh,ps1}; tests/skip-allowlist-manifest.tests.{sh,ps1} | TEST-016, TEST-034, TEST-035 | tests/skip-allowlist-manifest.tests.sh; tests/skip-allowlist-manifest.tests.ps1 | reports/quality-gate/ for T-010; specs/epic-195-a7-compatibility/verification/T-010/ | Planned |
| REQ-009 | investigation.md INV-013 | N/A — cross-layer only: REQ-009 is Epic A1's own requirement (`specs/epic-189-a1-project-context/requirements.md:891-921`), cited in this package's requirements.md only as the external upstream contract that defines `PROJECT_CONTEXT_INVALID` (Field Definitions "Context-present-invalid variant"; Edge Cases) — it is not one of this package's own REQ-001–REQ-007 and has no Layer Spec, Design, or Code Target of its own within this feature | requirements.md Field Definitions ("Context-present-invalid variant"); Edge Cases; AC-019–AC-021 cite its consequence only | N/A — external contract, not authored by this package | N/A — no code target within this feature; T-007/T-008 assert against its consequence (a distinct `PROJECT_CONTEXT_INVALID` stop event), never re-implement Epic A1's own validator | N/A | N/A | N/A | N/A — external, Epic A1's own scope (requirements.md Non-goals); tracked here only to satisfy this document's own requirement-ID coverage check |

## Deferred / Non-Task Acceptance Criteria

Per task-reviewer-a's AC-COVERAGE check, every AC-NNN not claimed by a
task's `Requirements:` field in `tasks.md` is recorded here with a stated
rationale (matching `specs/epic-190-a2-capability-registry/traceability.md`'s
own precedent for this exact section).

| Acceptance Criterion | Requirement | Status | Rationale |
|---|---|---|---|
| AC-013 | REQ-004 | Satisfied by this document (REQ-004 clause mapping, below) | acceptance-tests.md's own Test Strategy marks AC-013's test type "traceability review": decision doc §4's exact requirement sentence is restated as three independently checkable clauses in requirements.md's own REQ-004 goal text, and each clause is traced to at least one AC below (REQ-004 Clause Mapping) — no implementation task performs this restatement; it is satisfied by requirements.md's own approved text (Spec-Review-Status: Passed) plus this traceability document's own act of tracing each clause to its ACs. |
| AC-017 | REQ-004 (process) | Satisfied at Phase 1 (Spec-Review-Status: Passed) | acceptance-tests.md marks AC-017's test type "doc-review": every checkable factual claim in `investigation.md`/`requirements.md`/`design.md` already cites file:line evidence (WFI-011, `AGENTS.md:137-145`) — verified as a precondition of `spec-review-loop` reaching PASS, already reached. No Phase 2/3 implementation task re-performs this citation audit; a stale citation discovered later is a spec-content correction, not a task deliverable. |
| AC-029 | REQ-004 | Satisfied at Phase 1 (Impl-Review-Status: Passed) | acceptance-tests.md marks AC-029's test type "static / doc-review": the observable×fixture-state judgment table (design.md#data-plan, three mutually exclusive classes — byte/structural/event — across the full observable×row cross-product) already exists in design.md and was reviewed to `Impl-Review-Status: Passed`. No Phase 2/3 task re-authors or re-verifies this table's own exhaustiveness; a future revision to it is a design-document change, not a task deliverable. |

### REQ-004 Clause Mapping (satisfies AC-013)

Decision doc §4's exact sentence — "Project Context不在時、決定論的成果物
と制御フローはbyte-identicalまたはevent-identicalであり、LLM生成仕様は既
存のschema・構造・必須見出しと互換であること" — is restated in
requirements.md's REQ-004 goal text as three independently checkable
clauses, each traced here to the AC(s)/task(s) that verify it:

| Clause | Text | Traced to |
|---|---|---|
| (a) | Context-absent determinism is byte-identical | REQ-001; AC-002, AC-003, AC-038 (T-003) |
| (b) | Context-present deviation is event-identical against a registered event vocabulary | REQ-003; AC-008–AC-012, AC-022–AC-027, AC-032, AC-033, AC-036, AC-037, AC-039 (T-005, T-006, T-007, T-008, T-009) |
| (c) | Generated specs remain schema/structure/heading-compatible | REQ-002; AC-005, AC-006, AC-007, AC-030, AC-042, AC-043 (T-004); AC-031 (T-012) |

Clause (a)/(b)'s own boundary is fixed exhaustively and exclusively by
the observable×fixture-state judgment table (AC-029, design.md#data-plan)
— no observable is ever eligible for both a byte-identical and an
event-identical assertion simultaneously.

## Layer Coverage

| Layer | Applicable Requirements | Acceptance Criteria | Primary Sections | Gaps / Reasoned N/A |
|---|---|---|---|---|
| UX | N/A — no GUI, view, dialog, menu item, or human interactive shell surface | N/A | ux-spec.md | design.md Layer Specifications: "The only human-observable effects are suite pass/fail output and CI job status, governed by acceptance-tests.md." ux-spec.md records this as N/A; no task in `tasks.md` introduces any interactive surface. |
| Frontend | N/A — no browser/frontend application of this feature's own | N/A | frontend-spec.md#technology-stack | Every future-task deliverable is Bash/PowerShell/JSON test-infrastructure (frontend-spec.md); frontend-spec.md's own Technology Stack table is cited above (REQ-002, REQ-003) as the closest analog to a "frontend" layer this CLI/script feature has. |
| Infrastructure | REQ-001, REQ-005, REQ-006, REQ-007 | AC-003, AC-014, AC-015, AC-018, AC-028, AC-034, AC-035, AC-040, AC-041 | infra-spec.md#cicd-sequence; infra-spec.md#data-residency-and-retention | This task adds no CI job and no new infrastructure topology (design.md Deployment / CI Plan: "No CI change in this task"); every Phase 2/3 suite/fixture/manifest registers into the existing `tests/run-all.{sh,ps1}` and `.github/workflows/test.yml` (T-011), following the four Pillar-A-loop-suite precedent (investigation.md INV-005). |
| Security | REQ-002, REQ-003, REQ-006, REQ-007 | AC-001, AC-004, AC-007, AC-008, AC-009, AC-011, AC-016, AC-018, AC-021, AC-030, AC-031, AC-033, AC-034, AC-035, AC-035c, AC-036, AC-037, AC-040, AC-041 | security-spec.md#trust-boundaries; security-spec.md#stride-analysis; security-spec.md#owasp-mapping | Five named boundaries (B1–B5, security-spec.md#trust-boundaries): B1 golden-baseline capture/update (T-002, T-011); B2 shared-registry/driver/run-record blast radius (T-005, T-009); B3 REQ-007 allowlist manifest integrity (T-010); B4 cross-epic fingerprint-citation integrity (T-008, T-010); B5 structural-comparison seam / record-corpus tamper resistance (T-004 gating suite; T-012's own AC-031 refresh path is B5's one sanctioned corpus-mutation route). No task introduces a secret, credential, or PII value (security-spec.md#secrets-management). |

## Task Mapping

| Task | Requirements | Acceptance Tests | Planned Verification Evidence |
|---|---|---|---|
| T-001 | REQ-005 (AC-014) | TEST-014 | implementation report with acceptance-first evidence, independent quality-gate report, specs/epic-195-a7-compatibility/verification/T-001/ |
| T-002 | REQ-006 (AC-001, AC-018) | TEST-001, TEST-018 | implementation report with TDD red/green evidence, independent quality-gate report, specs/epic-195-a7-compatibility/verification/T-002/green-sh.log, .../T-002/red-sh.log |
| T-003 | REQ-001 (AC-002, AC-003, AC-038) | TEST-002, TEST-003, TEST-038 | implementation report with acceptance-first red/green evidence, independent quality-gate report, specs/epic-195-a7-compatibility/verification/T-003/green-sh.log, .../T-003/red-sh.log |
| T-004 | REQ-002 (AC-005, AC-006, AC-007, AC-030, AC-042, AC-043) | TEST-005, TEST-006, TEST-007, TEST-030, TEST-042, TEST-043 | implementation report with TDD red/green evidence, independent quality-gate report, specs/epic-195-a7-compatibility/verification/T-004/green-sh.log, .../T-004/red-sh.log |
| T-005 | REQ-003 (AC-008, AC-009, AC-039) | TEST-008, TEST-009, TEST-039 | implementation report with TDD red/green evidence, independent quality-gate report, specs/epic-195-a7-compatibility/verification/T-005/green-sh.log, .../T-005/red-sh.log |
| T-006 | REQ-003 (AC-022, AC-023, AC-024, AC-026, AC-032) | TEST-022, TEST-023, TEST-024, TEST-026, TEST-032 | implementation report with acceptance-first red/green evidence, independent quality-gate report, specs/epic-195-a7-compatibility/verification/T-006/green-sh.log, .../T-006/red-sh.log |
| T-007 | REQ-003 (AC-010, AC-019, AC-020, AC-025, AC-027) | TEST-010, TEST-019, TEST-020, TEST-025, TEST-027 | implementation report with acceptance-first red/green evidence, independent quality-gate report, specs/epic-195-a7-compatibility/verification/T-007/green-sh.log, .../T-007/red-sh.log |
| T-008 | REQ-003, REQ-007 (AC-004, AC-021, AC-036, AC-037) | TEST-004, TEST-021, TEST-036, TEST-037 | implementation report with TDD red/green evidence, independent quality-gate report, specs/epic-195-a7-compatibility/verification/T-008/green-sh.log, .../T-008/red-sh.log |
| T-009 | REQ-003 (AC-011, AC-012, AC-033) | TEST-011, TEST-012, TEST-033 | implementation report with TDD red/green evidence, independent quality-gate report, specs/epic-195-a7-compatibility/verification/T-009/green-sh.log, .../T-009/red-sh.log |
| T-010 | REQ-007 (AC-016, AC-034, AC-035) | TEST-016, TEST-034, TEST-035 | implementation report with TDD red/green evidence, independent quality-gate report, specs/epic-195-a7-compatibility/verification/T-010/green-sh.log, .../T-010/red-sh.log |
| T-011 | REQ-005 (AC-015, AC-028), REQ-006 (AC-040, AC-041) | TEST-015, TEST-028, TEST-040, TEST-041 | implementation report with TDD red/green evidence, independent quality-gate report, specs/epic-195-a7-compatibility/verification/T-011/green-sh.log, .../T-011/red-sh.log |
| T-012 | REQ-002 (AC-031) | TEST-031 | implementation report with TDD red/green evidence, independent quality-gate report, specs/epic-195-a7-compatibility/verification/T-012/green-sh.log, .../T-012/red-sh.log |

## Acceptance Mapping

| Acceptance Criterion | Test ID | Task |
|---|---|---|
| AC-001 | TEST-001 | T-002 |
| AC-002 | TEST-002 | T-003 |
| AC-003 | TEST-003 | T-003 |
| AC-004 | TEST-004 | T-008 |
| AC-005 | TEST-005 | T-004 |
| AC-006 | TEST-006 | T-004 |
| AC-007 | TEST-007 | T-004 |
| AC-008 | TEST-008 | T-005 |
| AC-009 | TEST-009 | T-005 |
| AC-010 | TEST-010 | T-007 |
| AC-011 | TEST-011 | T-009 |
| AC-012 | TEST-012 | T-009 |
| AC-013 | TEST-013 | N/A — see Deferred / Non-Task Acceptance Criteria, above |
| AC-014 | TEST-014 | T-001 |
| AC-015 | TEST-015 | T-011 |
| AC-016 | TEST-016 | T-010 |
| AC-017 | TEST-017 | N/A — see Deferred / Non-Task Acceptance Criteria, above |
| AC-018 | TEST-018 | T-002 |
| AC-019 | TEST-019 | T-007 |
| AC-020 | TEST-020 | T-007 |
| AC-021 | TEST-021 | T-008 |
| AC-022 | TEST-022 | T-006 |
| AC-023 | TEST-023 | T-006 |
| AC-024 | TEST-024 | T-006 |
| AC-025 | TEST-025 | T-007 |
| AC-026 | TEST-026 | T-006 (own share), T-007 (own share) — shared, per-suite done-transition assertion |
| AC-027 | TEST-027 | T-007 |
| AC-028 | TEST-028 | T-011 |
| AC-029 | TEST-029 | N/A — see Deferred / Non-Task Acceptance Criteria, above |
| AC-030 | TEST-030 | T-004 |
| AC-031 | TEST-031 | T-012 |
| AC-032 | TEST-032 | T-006 |
| AC-033 | TEST-033 | T-009 |
| AC-034 | TEST-034 | T-010 |
| AC-035 | TEST-035 | T-010 |
| AC-036 | TEST-036 | T-008 |
| AC-037 | TEST-037 | T-008 |
| AC-038 | TEST-038 | T-003 |
| AC-039 | TEST-039 | T-005 |
| AC-040 | TEST-040 | T-011 |
| AC-041 | TEST-041 | T-011 |
| AC-042 | TEST-042 | T-004 |
| AC-043 | TEST-043 | T-004 |

## Deliverables (Per Task)

| Task | Issue | New Files | Edited Files |
|---|---|---|---|
| T-001 | #195 | tests/lib/fixture-matrix-builder.sh; tests/lib/fixture-matrix-builder.ps1 | none |
| T-002 | #195 | tests/capture-golden-baseline.sh; .ps1; tests/promote-golden-baseline.sh; .ps1; tests/golden-baseline-contract.tests.sh; .ps1; specs/epic-195-a7-compatibility/verification/golden-baseline/canonical/; specs/epic-195-a7-compatibility/verification/golden-baseline/.gitignore | tests/run-all.sh; tests/run-all.ps1 |
| T-003 | #195 | tests/compatibility-byte-identical.tests.sh; .ps1 | tests/install.tests.sh; .ps1; tests/uninstall.tests.sh; .ps1; tests/run-all.sh; tests/run-all.ps1 |
| T-004 | #195 | tests/structural-compatibility.tests.sh; .ps1; tests/lib/markdown-ast-canonicalizer.sh; .ps1; tests/fixtures/structural-fixture-corpus/ | tests/run-all.sh; tests/run-all.ps1 (gating suite only) |
| T-005 | #195 | none | tests/loops/loop-inventory.json; tests/lib/loop-driver.sh; .ps1; tests/loop-inventory.tests.sh; .ps1 |
| T-006 | #195 | tests/fixtures/compatibility-event-trace/ | tests/loop-consistency.tests.sh; .ps1 |
| T-007 | #195 | none (extends T-006's fixture tree) | tests/loop-escalation.tests.sh; .ps1 |
| T-008 | #195 | none | tests/loop-consistency.tests.sh; .ps1; tests/loop-escalation.tests.sh; .ps1 |
| T-009 | #195 | none | plugins/sdd-quality-loop/scripts/emit-run-record.sh; .ps1; tests/emit-run-record-feature-scope.tests.sh; .ps1 |
| T-010 | #195 | tests/fixtures/skip-allowlist-manifest.json; tests/lib/skip-allowlist-evaluator.sh; .ps1; tests/skip-allowlist-manifest.tests.sh; .ps1 | tests/loop-consistency.tests.sh; tests/loop-escalation.tests.sh; tests/compatibility-byte-identical.tests.sh; tests/structural-compatibility.tests.sh (SKIP-source re-pointing only); tests/run-all.sh; tests/run-all.ps1 |
| T-011 | #195 | tests/promote-golden-baseline-ci-guard.tests.sh; .ps1; (conditionally) specs/epic-195-a7-compatibility/human-copy/.github/workflows/test.yml; specs/epic-195-a7-compatibility/human-copy/MANIFEST.sha256 | .github/workflows/test.yml; tests/run-all.sh; tests/run-all.ps1 (cumulative confirmation) |
| T-012 | #195 | tests/structural-compatibility-live-refresh.tests.sh; .ps1 | tests/fixtures/structural-fixture-corpus/ (refresh only, via `refresh_procedure`; never registered in tests/run-all.sh/.ps1 or .github/workflows/test.yml) |

## Final Status

Update requirement status only from saved test evidence and
quality-gate reports. Implementation reports are claims, not independent
verification evidence. This document was produced at Phase 2 (task
decomposition), immediately after `design.md` reached
`Impl-Review-Status: Passed`, with every row `Planned`. Statuses advance
only from saved evidence: REQ-005 is `In Progress` — T-001 is `Done`
behind the independent quality-gate cycle-2 PASS
(`reports/quality-gate/epic-195-a7-compatibility/T-001.md`, ledger
seq0662) with acceptance evidence under
`specs/epic-195-a7-compatibility/verification/T-001/` — and REQ-006 is
`In Progress` — T-002 is `Done` behind the independent quality-gate
cycle-1 PASS
(`reports/quality-gate/epic-195-a7-compatibility/T-002.md`, ledger
seq0667) with acceptance evidence under
`specs/epic-195-a7-compatibility/verification/T-002/` and the committed
canonical baseline under
`specs/epic-195-a7-compatibility/verification/golden-baseline/canonical/`.
REQ-005's and REQ-006's shared remaining task T-011 and every other row
stay `Planned`.
