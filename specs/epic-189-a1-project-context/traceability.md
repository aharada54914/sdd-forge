# Traceability: epic-189-a1-project-context

Every Requirement cell traces to a design.md section, a contract/schema
target, one or more planned Task IDs, and one or more Test IDs. No separate
`ux-spec.md`/`frontend-spec.md`/`infra-spec.md`/`security-spec.md` files
were created for this package (not requested by the parent task); design.md
folds Security Boundaries, CI wiring, and constraint compliance directly
into itself.

| Requirement | Investigation | Design | Contract / Schema | Planned Code Target | Test ID | Test Target | Evidence | Status |
|---|---|---|---|---|---|---|---|---|
| REQ-001 | investigation.md INV-001, INV-002 | design.md#api--contract-plan (project-context schema); design.md#data-plan | `contracts/project-context.schema.json` — `sdd-project-context/v1` | contracts/project-context.schema.json; tests/project-context-schema.tests.sh/.ps1 | TEST-001, TEST-002 | tests/project-context-schema.tests.sh/.ps1 | reports/quality-gate/ for T-001; specs/epic-189-a1-project-context/verification/T-001/ | Planned |
| REQ-002 | investigation.md INV-001 | design.md#api--contract-plan (provider-bindings schema) | `contracts/provider-bindings.schema.json` — `sdd-provider-bindings/v1` | contracts/provider-bindings.schema.json; tests/project-context-schema.tests.sh/.ps1 | TEST-003, TEST-004 | tests/project-context-schema.tests.sh/.ps1 | reports/quality-gate/ for T-001; specs/epic-189-a1-project-context/verification/T-001/ | Planned |
| REQ-003 | investigation.md INV-005, INV-014 | design.md#technical-summary; design.md#api--contract-plan (canonicalization procedure) | canonical hash/JCS procedure (no JSON Schema; a byte-format contract stated in design.md) | plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.py/.sh/.ps1/.js; tests/canonicalize-sdd-yaml.tests.sh/.ps1 | TEST-005, TEST-006, TEST-007, TEST-008, TEST-009 | tests/canonicalize-sdd-yaml.tests.sh/.ps1 | reports/quality-gate/ for T-002; specs/epic-189-a1-project-context/verification/T-002/ | Planned |
| REQ-004 | investigation.md INV-003, INV-004 | design.md#api--contract-plan (approval sidecar schema; HMAC preimage and signing) | `contracts/approval-sidecar.schema.json` — `sdd-project-context-approval/v1` / `sdd-provider-bindings-approval/v1` | contracts/approval-sidecar.schema.json; plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py/.sh/.ps1; tests/generate-approval-sidecar.tests.sh/.ps1 | TEST-010, TEST-011, TEST-012, TEST-013 | tests/generate-approval-sidecar.tests.sh/.ps1 | reports/quality-gate/ for T-003; specs/epic-189-a1-project-context/verification/T-003/ | Planned |
| REQ-005 | investigation.md INV-003 | design.md#test-strategy (four-way negative proof) | validator contract stated in design.md API/Contract Plan (consumes REQ-004's schema) | plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py/.sh/.ps1; tests/validate-approval-sidecar.tests.sh/.ps1 | TEST-014, TEST-015, TEST-019, TEST-020 | tests/validate-approval-sidecar.tests.sh/.ps1 | reports/quality-gate/ for T-005; specs/epic-189-a1-project-context/verification/T-005/ | Planned |
| REQ-006 | investigation.md (Open Questions OQ-001) | design.md#api--contract-plan (weakening-category table) | `contracts/approver-registry.schema.json` — `sdd-approver-registry/v1` | contracts/approver-registry.schema.json; plugins/sdd-quality-loop/scripts/detect-policy-weakening.py/.sh/.ps1; tests/detect-policy-weakening.tests.sh/.ps1 | TEST-016, TEST-017, TEST-018 | tests/detect-policy-weakening.tests.sh/.ps1 | reports/quality-gate/ for T-004; specs/epic-189-a1-project-context/verification/T-004/ | Planned |
| REQ-007 | investigation.md INV-006 | design.md#protected-file-statement | `guard-invariants.json` `epic_a1_targets` key (new); `generate-guard-invariants.py` `EPIC_A1_TARGETS` constant (new) | plugins/sdd-quality-loop/references/guard-invariants.json; plugins/sdd-quality-loop/scripts/generate-guard-invariants.py; plugins/sdd-quality-loop/scripts/generated/guard_invariants.{py,js,ps1,sh}; tests/guard-invariants-epic-a1.tests.sh/.ps1 | TEST-021, TEST-022 | tests/guard-invariants-epic-a1.tests.sh/.ps1 | reports/quality-gate/ for T-006; specs/epic-189-a1-project-context/verification/T-006/ (incl. human-apply record) | Planned |
| REQ-008 | investigation.md INV-006 | design.md#constraint-compliance (no hook-guard decision-logic edit row) | none — relies on existing `_is_protected_gate_file` | tests/hook-guard-epic-a1-boundary.tests.sh/.ps1 | TEST-023 | tests/hook-guard-epic-a1-boundary.tests.sh/.ps1 | reports/quality-gate/ for T-007; specs/epic-189-a1-project-context/verification/T-007/ | Planned |
| REQ-009 | investigation.md INV-001, INV-002 | design.md#architecture (Track Detection flow) | `PLUGIN-CONTRACTS.md` Track Detection section (revised) | PLUGIN-CONTRACTS.md; plugins/sdd-bootstrap/skills/bootstrap/SKILL.md; plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md; plugins/sdd-ship/skills/ship/SKILL.md; plugins/sdd-lite/skills/lite-spec/SKILL.md; plugins/sdd-lite/skills/lite-gate/SKILL.md; tests/plugin-contracts-track-selection.tests.sh/.ps1; tests/ship-track-selection-migration.tests.sh/.ps1 | TEST-024, TEST-025, TEST-026 | tests/plugin-contracts-track-selection.tests.sh/.ps1; tests/ship-track-selection-migration.tests.sh/.ps1 | reports/quality-gate/ for T-009, T-010; specs/epic-189-a1-project-context/verification/T-009/, T-010/ (incl. human-apply record) | Planned |
| REQ-010 | investigation.md (decision doc §7 v2 citation) | design.md#architecture (handshake flow) | `HOOK_ACTIVE` / `CAPABILITY_RUNTIME_UNAVAILABLE` result contract stated in design.md | plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py/.sh/.ps1; tests/check-hook-activation-handshake.tests.sh/.ps1 | TEST-027 | tests/check-hook-activation-handshake.tests.sh/.ps1 | reports/quality-gate/ for T-008; specs/epic-189-a1-project-context/verification/T-008/ | Planned |
| REQ-011 | investigation.md INV-007, INV-012 | design.md#test-strategy; design.md#deployment--ci-plan | none — cross-cutting test/CI closing requirement | tests/run-all.sh/.ps1 (all new suites registered); specs/epic-189-a1-project-context/human-copy/.github/workflows/test.yml (final consolidated) | TEST-028, TEST-029 | tests/run-all.sh/.ps1 (full run) | reports/quality-gate/ for T-011; specs/epic-189-a1-project-context/verification/T-011/ | Planned |

## Layer Coverage

| Layer | Applicable Requirements | Acceptance Criteria | Primary Sections | Gaps / Reasoned N/A |
|---|---|---|---|---|
| UX | N/A — no user-facing UI | N/A | design.md (Feature Type header states no UI) | No rendered or interactive surface anywhere in this epic. |
| Frontend | N/A — no browser/frontend bundle | N/A | design.md (Feature Type header) | JSON Schema + Python/Bash/PowerShell/JS scripts + Markdown skill-instruction edits only. |
| Infrastructure | REQ-007, REQ-011 | AC-021, AC-022, AC-028, AC-029 | design.md#deployment--ci-plan | `.github/workflows/test.yml` registration for every test-adding task is human-copy staged (R-10 protected), never a direct CI-wiring edit. |
| Security | REQ-003, REQ-004, REQ-005, REQ-006, REQ-007, REQ-008, REQ-009, REQ-010 | AC-005..AC-023, AC-025..AC-027 | design.md#security-boundaries | This package folds security analysis directly into design.md (no separate security-spec.md was requested); every trust boundary is enumerated there. |

## Task Mapping

| Task | Requirements | Acceptance Tests | Planned Verification Evidence |
|---|---|---|---|
| T-001 | REQ-001, REQ-002 | TEST-001, TEST-002, TEST-003, TEST-004 | implementation report with acceptance-first evidence, independent quality-gate report |
| T-002 | REQ-003 | TEST-005, TEST-006, TEST-007, TEST-008, TEST-009 | implementation report with TDD red/green evidence, independent quality-gate report |
| T-003 | REQ-004 | TEST-010, TEST-011, TEST-012, TEST-013 | implementation report with TDD red/green evidence, independent quality-gate report |
| T-004 | REQ-006 | TEST-016, TEST-017, TEST-018 | implementation report with TDD red/green evidence, independent quality-gate report |
| T-005 | REQ-005 | TEST-014, TEST-015, TEST-019, TEST-020 | implementation report with TDD red/green evidence, independent quality-gate report |
| T-006 | REQ-007 | TEST-021, TEST-022 | implementation report with TDD red/green evidence + human-apply record, independent quality-gate report |
| T-007 | REQ-008 | TEST-023 | implementation report with TDD red/green evidence, independent quality-gate report |
| T-008 | REQ-010 | TEST-027 | implementation report with TDD red/green evidence, independent quality-gate report |
| T-009 | REQ-009 (part 1) | TEST-024; partial TEST-025/TEST-026 | implementation report with acceptance-first evidence, independent quality-gate report |
| T-010 | REQ-009 (part 2), REQ-010 (wiring) | TEST-025, TEST-026 | implementation report with TDD red/green evidence + human-apply record, independent quality-gate report |
| T-011 | REQ-011 | TEST-028, TEST-029 | implementation report with acceptance-first evidence, independent quality-gate report |

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
| AC-008 | TEST-008 | T-002 |
| AC-009 | TEST-009 | T-002 |
| AC-010 | TEST-010 | T-003 |
| AC-011 | TEST-011 | T-003 |
| AC-012 | TEST-012 | T-003 |
| AC-013 | TEST-013 | T-003 |
| AC-014 | TEST-014 | T-005 |
| AC-015 | TEST-015 | T-005 |
| AC-016 | TEST-016 | T-004 |
| AC-017 | TEST-017 | T-004 |
| AC-018 | TEST-018 | T-004 |
| AC-019 | TEST-019 | T-005 (owns the end-to-end proof; T-003 supplies the enforcement it exercises) |
| AC-020 | TEST-020 | T-005 (owns the end-to-end proof; T-003/T-004 supply the mechanisms it exercises) |
| AC-021 | TEST-021 | T-006 |
| AC-022 | TEST-022 | T-006 |
| AC-023 | TEST-023 | T-007 |
| AC-024 | TEST-024 | T-009 |
| AC-025 | TEST-025 | T-010 (T-009 supplies the partial unprotected-consumer proof) |
| AC-026 | TEST-026 | T-010 (T-009 supplies the partial unprotected-consumer proof) |
| AC-027 | TEST-027 | T-008 |
| AC-028 | TEST-028 | T-011 |
| AC-029 | TEST-029 | T-011 |

## Deliverables (Per Task)

| Task | New Files | Edited Files |
|---|---|---|
| T-001 | contracts/project-context.schema.json; contracts/provider-bindings.schema.json; tests/project-context-schema.tests.sh; tests/project-context-schema.tests.ps1 | tests/run-all.sh; tests/run-all.ps1; CHANGELOG.md (CREATE #189 entry); specs/epic-189-a1-project-context/human-copy/.github/workflows/test.yml (staged); specs/epic-189-a1-project-context/human-copy/MANIFEST.sha256 |
| T-002 | plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.py/.sh/.ps1/.js; tests/canonicalize-sdd-yaml.tests.sh; tests/canonicalize-sdd-yaml.tests.ps1 | tests/run-all.sh; tests/run-all.ps1; CHANGELOG.md (APPEND); human-copy/.github/workflows/test.yml (staged, appended) |
| T-003 | contracts/approval-sidecar.schema.json; plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py/.sh/.ps1; tests/generate-approval-sidecar.tests.sh; tests/generate-approval-sidecar.tests.ps1 | tests/run-all.sh; tests/run-all.ps1; CHANGELOG.md (APPEND); human-copy/.github/workflows/test.yml (staged, appended) |
| T-004 | contracts/approver-registry.schema.json; plugins/sdd-quality-loop/scripts/detect-policy-weakening.py/.sh/.ps1; tests/detect-policy-weakening.tests.sh; tests/detect-policy-weakening.tests.ps1 | tests/run-all.sh; tests/run-all.ps1; CHANGELOG.md (APPEND); human-copy/.github/workflows/test.yml (staged, appended) |
| T-005 | plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py/.sh/.ps1; tests/validate-approval-sidecar.tests.sh; tests/validate-approval-sidecar.tests.ps1 | tests/run-all.sh; tests/run-all.ps1; CHANGELOG.md (APPEND); human-copy/.github/workflows/test.yml (staged, appended) |
| T-006 | tests/guard-invariants-epic-a1.tests.sh; tests/guard-invariants-epic-a1.tests.ps1; human-copy/plugins/sdd-quality-loop/references/guard-invariants.json (staged); human-copy/plugins/sdd-quality-loop/scripts/generate-guard-invariants.py (staged); human-copy/plugins/sdd-quality-loop/scripts/generated/guard_invariants.py/.js/.ps1/.sh (staged) | tests/run-all.sh; tests/run-all.ps1; CHANGELOG.md (APPEND); human-copy/MANIFEST.sha256 (6 new entries) |
| T-007 | tests/hook-guard-epic-a1-boundary.tests.sh; tests/hook-guard-epic-a1-boundary.tests.ps1 | tests/run-all.sh; tests/run-all.ps1; CHANGELOG.md (APPEND); human-copy/.github/workflows/test.yml (staged, appended) |
| T-008 | plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py/.sh/.ps1; tests/check-hook-activation-handshake.tests.sh; tests/check-hook-activation-handshake.tests.ps1 | tests/run-all.sh; tests/run-all.ps1; CHANGELOG.md (APPEND); human-copy/.github/workflows/test.yml (staged, appended) |
| T-009 | tests/plugin-contracts-track-selection.tests.sh; tests/plugin-contracts-track-selection.tests.ps1 | PLUGIN-CONTRACTS.md; plugins/sdd-bootstrap/skills/bootstrap/SKILL.md; plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md; tests/run-all.sh; tests/run-all.ps1; CHANGELOG.md (APPEND); human-copy/.github/workflows/test.yml (staged, appended) |
| T-010 | tests/ship-track-selection-migration.tests.sh; tests/ship-track-selection-migration.tests.ps1; human-copy/plugins/sdd-ship/skills/ship/SKILL.md (staged); human-copy/plugins/sdd-lite/skills/lite-spec/SKILL.md (staged) | plugins/sdd-lite/skills/lite-gate/SKILL.md (if applicable); tests/run-all.sh; tests/run-all.ps1; CHANGELOG.md (APPEND); human-copy/MANIFEST.sha256 (2 new entries); human-copy/.github/workflows/test.yml (staged, appended) |
| T-011 | (none — audit/reconciliation only) | tests/run-all.sh; tests/run-all.ps1 (audit only); CHANGELOG.md (APPEND, closing entry); human-copy/.github/workflows/test.yml (final consolidated candidate, if drift found); human-copy/MANIFEST.sha256 (reconciled) |

## Final Status

Update requirement status only from saved test evidence and quality-gate
reports. Implementation reports are claims, not independent verification
evidence. No task in this plan may be marked Done until a human has set
its Approval field to an approved designation by editing `tasks.md`
directly, and until `spec-review-loop`/`impl-review-loop` have actually run
against this package to `Passed` (see the note at the top of tasks.md).
