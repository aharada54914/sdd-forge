# Traceability: epic-196-a8-integration

Every Layer Spec cell contains one or more canonical layer-spec anchors, or
a reasoned cross-layer N/A. This feature has no `ux-spec.md`/
`frontend-spec.md`/`infra-spec.md`/`security-spec.md` (design.md#layer-
specifications: "Not applicable. This package is explicitly Phase 1,
four-file only... matching Epic A7's own established precedent, INV-018");
every row below therefore carries the `N/A — cross-layer only: <reason>`
form `plugins/sdd-review-loop/scripts/validate-layer-traceability.py`'s
`EXCLUSION` pattern requires, never a bare `N/A` and never a fabricated
layer-spec anchor into a file that does not exist.

| Requirement | Investigation | Layer Spec | Design | API/Schema | Code Target | Test ID | Test Target | Evidence | Status |
|---|---|---|---|---|---|---|---|---|---|
| REQ-001 | investigation.md INV-001, INV-002, INV-003, INV-013, INV-015, INV-021; requirements.md OQ-001 | N/A — cross-layer only: this package is explicitly Phase 1, four-file only (design.md#layer-specifications); no ux-spec.md/frontend-spec.md/infra-spec.md/security-spec.md exists for this feature, matching Epic A7's established precedent (investigation.md INV-018) | design.md#data-plan (`cross-runtime-handoff-trace/v1`, Fixture Contract table); design.md#skip-allowlist-activation-gate; design.md#test-strategy item 1 | `cross-runtime-handoff-trace/v1` (`schema`, `steps[]`, `canary_case`) | tests/fixtures/cross-runtime-handoff/; tests/cross-runtime-handoff.tests.sh; tests/cross-runtime-handoff.tests.ps1; plugins/sdd-review-loop/references/a8-skip-allowlist.json (AC-006 entry) | TEST-001, TEST-002, TEST-003, TEST-004, TEST-005, TEST-006 | tests/cross-runtime-handoff.tests.sh; tests/cross-runtime-handoff.tests.ps1 | reports/quality-gate/ for T-001; specs/epic-196-a8-integration/verification/T-001/ | Planned |
| REQ-002 | investigation.md INV-001, INV-003, INV-010, INV-014, INV-016 | N/A — cross-layer only: this package is explicitly Phase 1, four-file only (design.md#layer-specifications); no ux-spec.md/frontend-spec.md/infra-spec.md/security-spec.md exists for this feature, matching Epic A7's established precedent (investigation.md INV-018) | design.md#data-plan (`install-uninstall-matrix-result/v1`, Target × Phase × Surface Registration Table, Required MCP-Surface Preconditions); design.md#test-strategy items 2–3 | `install-uninstall-matrix-result/v1` | tests/install-uninstall-matrix.tests.sh; tests/install-uninstall-matrix.tests.ps1; tests/fixtures/install-uninstall-matrix/ | TEST-007, TEST-008, TEST-009, TEST-010, TEST-011 | tests/install-uninstall-matrix.tests.sh; tests/install-uninstall-matrix.tests.ps1 | reports/quality-gate/ for T-003; specs/epic-196-a8-integration/verification/T-003/ | Planned |
| REQ-003 | investigation.md INV-001, INV-002, INV-004, INV-005, INV-006, INV-007, INV-011, INV-012, INV-013, INV-021 | N/A — cross-layer only: this package is explicitly Phase 1, four-file only (design.md#layer-specifications); no ux-spec.md/frontend-spec.md/infra-spec.md/security-spec.md exists for this feature, matching Epic A7's established precedent (investigation.md INV-018) | design.md#live-host-semantic-matrix; design.md#direct-invocation-de-spoofing; design.md#skip-allowlist-activation-gate; design.md#data-plan (`live-host-verification-record/v1`, Signing Contract, Nonce Issuance Ledger, Expected-Digest Manifest); design.md#security-boundaries (B1); docs/adr/0028-live-host-proof-ed25519-signing.md | `live-host-verification-record/v1`; `validate-live-host-proof.{sh,ps1} [--records-dir] [--nonce-ledger] [--expected-digest-manifest] [--trusted-signers] [--skip-allowlist]` → `discharged`\|`pending`\|named error code | tests/cli-hook-enforcement.ps1 (extended); plugins/sdd-quality-loop/scripts/validate-live-host-proof.py; .sh; .ps1; tests/validate-live-host-proof.tests.sh; .ps1; tests/hook-activation-live-proof/ (5 semantic-cell records, nonce-ledger.json); plugins/sdd-review-loop/references/a8-trusted-signers.json; a8-expected-hook-config-digests.json | TEST-012, TEST-013, TEST-014, TEST-015, TEST-016, TEST-017, TEST-028 | tests/cli-hook-enforcement.ps1; tests/validate-live-host-proof.tests.sh; tests/validate-live-host-proof.tests.ps1 | reports/quality-gate/ for T-004, T-005; specs/epic-196-a8-integration/verification/{T-004,T-005}/ | Planned (AC-013–016 stay manual-required/SKIP until a scripted session contract is confirmed or Epic A1 merges, per requirements.md Assumptions) |
| REQ-004 | investigation.md INV-022 | N/A — cross-layer only: this package is explicitly Phase 1, four-file only (design.md#layer-specifications); no ux-spec.md/frontend-spec.md/infra-spec.md/security-spec.md exists for this feature, matching Epic A7's established precedent (investigation.md INV-018) | design.md#data-plan (`path-lineending-fixture-result/v1`, REQ-004 Pairwise Covering Combination Matrix, Unicode-Normalization Contract); design.md#pathline-ending-regression-matrix; design.md#test-strategy item 6 | `path-lineending-fixture-result/v1` | tests/path-lineending-regression.tests.sh; tests/path-lineending-regression.tests.ps1; tests/fixtures/path-lineending-regression/ | TEST-018, TEST-019, TEST-020, TEST-021 | tests/path-lineending-regression.tests.sh; tests/path-lineending-regression.tests.ps1 | reports/quality-gate/ for T-006; specs/epic-196-a8-integration/verification/T-006/ | Planned |
| REQ-005 | investigation.md INV-016, INV-017, INV-019 | N/A — cross-layer only: this package is explicitly Phase 1, four-file only (design.md#layer-specifications); no ux-spec.md/frontend-spec.md/infra-spec.md/security-spec.md exists for this feature, matching Epic A7's established precedent (investigation.md INV-018) | design.md#data-plan (`installed-plugin-drift-report/v1`, Region Extraction Rule, Platform Install-Root Defaults, Coverage Scope table); design.md#security-boundaries (B2) | `installed-plugin-drift-report/v1`; `check-installed-plugin-drift [--install-root <path>] [--mode preflight\|verify]` | plugins/sdd-quality-loop/scripts/check-installed-plugin-drift.py; .sh; .ps1; tests/check-installed-plugin-drift.tests.sh; .ps1; tests/fixtures/installed-plugin-drift/ | TEST-022, TEST-023, TEST-024 | tests/check-installed-plugin-drift.tests.sh; tests/check-installed-plugin-drift.tests.ps1; tests/install-uninstall-matrix.tests.sh (TEST-024 wiring proof) | reports/quality-gate/ for T-002, T-003; specs/epic-196-a8-integration/verification/{T-002,T-003}/ | Planned |
| REQ-006 | investigation.md INV-021; requirements.md OQ-001 | N/A — cross-layer only: this package is explicitly Phase 1, four-file only (design.md#layer-specifications); no ux-spec.md/frontend-spec.md/infra-spec.md/security-spec.md exists for this feature, matching Epic A7's established precedent (investigation.md INV-018) | design.md#automated--manual-classification-table; design.md#technical-summary ("REQ-006 is not a sixth surface but a classification discipline applied to the other five") | `live-host-verification-record/v1` (shared with REQ-003; AC-026 schema); `a8-skip-allowlist.json`; `a8-expected-hook-config-digests.json`; `a8-trusted-signers.json` | plugins/sdd-quality-loop/scripts/validate-live-host-proof.py (AC-026/027 share); plugins/sdd-quality-loop/scripts/check-a8-classification-table.py; .sh; .ps1 (AC-025) | TEST-025, TEST-026, TEST-027 | tests/validate-live-host-proof.tests.sh; tests/validate-live-host-proof.tests.ps1; tests/check-a8-process-integrity.tests.sh; tests/check-a8-process-integrity.tests.ps1 | reports/quality-gate/ for T-005, T-007; specs/epic-196-a8-integration/verification/{T-005,T-007}/ | Planned |
| REQ-007 | investigation.md INV-001, INV-020; AGENTS.md WFI-011 (`AGENTS.md:137-145`) | N/A — cross-layer only: this package is explicitly Phase 1, four-file only (design.md#layer-specifications); no ux-spec.md/frontend-spec.md/infra-spec.md/security-spec.md exists for this feature, matching Epic A7's established precedent (investigation.md INV-018) | design.md#technical-summary ("REQ-007 is likewise not a verification surface but a process-integrity discipline") | N/A — no schema of its own; process-integrity checks only | plugins/sdd-quality-loop/scripts/check-a8-scope-boundary.py; .sh; .ps1; check-a8-citation-compliance.py; .sh; .ps1 | TEST-029, TEST-030 | tests/check-a8-process-integrity.tests.sh; tests/check-a8-process-integrity.tests.ps1 | reports/quality-gate/ for T-007; specs/epic-196-a8-integration/verification/T-007/ | Planned |

## Deferred / Non-Task Acceptance Criteria

None. Every `AC-001`–`AC-030` requirements.md/acceptance-tests.md name is
claimed by exactly one task's `Requirements:` field in tasks.md (Acceptance
Mapping, below), matching task-reviewer-a's AC-COVERAGE check.
acceptance-tests.md's own text ("Every `Planned` status above is a Phase 1
... placeholder: no test code exists yet") applies uniformly across all 30
rows with no explicit deferred/non-task exception carved out for any of
them — unlike `specs/epic-190-a2-capability-registry/acceptance-tests.md`,
which explicitly flagged three of its own ACs `Deferred to Phase 2`/
spec-authoring-time-satisfied in its own text. No AC in this package is
treated as satisfied without a task producing real Phase 2/3 test code for
it, including the three REQ-006/REQ-007 process-integrity checks
(AC-025, AC-029, AC-030), which T-007 implements as real static-check
scripts rather than leaving as an inspection-only claim against the
already-frozen Phase 1 documents.

## Layer Coverage

| Layer | Applicable Requirements | Acceptance Criteria | Primary Sections | Gaps / Reasoned N/A |
|---|---|---|---|---|
| UX | N/A — no user-facing UI | N/A — internal test-infrastructure specification work | ux-spec.md (does not exist for this feature) | requirements.md's own Security Boundaries section states this explicitly: "This is internal test-infrastructure specification work with no user-facing entry point; the UI Integration Checklist is not applicable." design.md#design-system-compliance restates the same for the design layer. No ux-spec.md exists (design.md#layer-specifications); this row records N/A rather than a fabricated anchor. |
| Frontend | N/A — no browser/frontend bundle | N/A — sh/PowerShell/Python test drivers and JSON contract files only | frontend-spec.md (does not exist for this feature) | Every new component in design.md#components is sh/PowerShell/Python plus JSON — not a frontend surface. No frontend-spec.md exists; this row records N/A rather than a fabricated anchor. |
| Infrastructure | REQ-001, REQ-002, REQ-003, REQ-004, REQ-005, REQ-006, REQ-007 | AC-001–AC-030 (all) | design.md#deployment--ci-plan; design.md#global-constraints | Seven new `.sh`/`.ps1`(/`.py`) suite pairs register directly in `tests/run-all.*` (not protected, INV-014) and stage their `.github/workflows/test.yml` CI steps via human-copy (R-10 protected, confirmed present in `guard-invariants.json`'s `protected_gate_suffixes`/`phase2_human_copy_targets`). No new CI job or matrix dimension — every check registers into the existing 3-OS matrix (Global Constraints, design.md). No infra-spec.md exists for this feature (design.md#layer-specifications); this row cites design.md's own infrastructure-relevant sections instead of a fabricated anchor. |
| Security | REQ-002, REQ-003, REQ-005, REQ-006 | AC-009, AC-012, AC-013, AC-014, AC-015, AC-016, AC-017, AC-022, AC-023, AC-024, AC-026, AC-027, AC-028 | design.md#security-boundaries; requirements.md's own Security Boundaries table (B1, B2) | Security Boundary B1 (live-host session authenticity, REQ-003) is enforced by the fortified `live-host-verification-record/v1` schema (nonce, raw hashes, session/event IDs, installed-config digest, two-party Ed25519 attestation per ADR-0028) plus the AC-027 classification-mismatch/replay guard and the AC-028 aggregate `validate-live-host-proof` Done/release gate (T-005). Security Boundary B2 (installed-cache drift, REQ-005) is enforced by `check-installed-plugin-drift`'s own read-only API contract — no write flag exists in its own interface (T-002). No task in this feature registers a new `guard-invariants.json`/`PROTECTED_GATE_SUFFIXES` entry (Protected-File Statement, design.md; Protected Files, tasks.md). No security-spec.md exists for this feature (design.md#layer-specifications); this row cites requirements.md's/design.md's own Security Boundaries sections instead of a fabricated anchor. |

## Task Mapping

| Task | Requirements | Acceptance Tests | Planned Verification Evidence |
|---|---|---|---|
| T-001 | REQ-001 (AC-001–AC-006) | TEST-001, TEST-002, TEST-003, TEST-004, TEST-005, TEST-006 | implementation report with acceptance-first red/green evidence, independent quality-gate report, specs/epic-196-a8-integration/verification/T-001/green-sh.log, .../T-001/red-sh.log |
| T-002 | REQ-005 (AC-022, AC-023) | TEST-022, TEST-023 | implementation report with TDD red/green evidence, independent quality-gate report, specs/epic-196-a8-integration/verification/T-002/green-sh.log, .../T-002/red-sh.log |
| T-003 | REQ-002 (AC-007–AC-011), REQ-005 (share — AC-024) | TEST-007, TEST-008, TEST-009, TEST-010, TEST-011, TEST-024 | implementation report with acceptance-first red/green evidence, independent quality-gate report, specs/epic-196-a8-integration/verification/T-003/green-sh.log, .../T-003/red-sh.log |
| T-004 | REQ-003 (AC-012, AC-017) | TEST-012, TEST-017 | implementation report with TDD red/green evidence, independent quality-gate report, specs/epic-196-a8-integration/verification/T-004/green-sh.log, .../T-004/red-sh.log |
| T-005 | REQ-003 (AC-013, AC-014, AC-015, AC-016, AC-028), REQ-006 (AC-026, AC-027) | TEST-013, TEST-014, TEST-015, TEST-016, TEST-026, TEST-027, TEST-028 | implementation report with TDD red/green evidence, independent quality-gate report, specs/epic-196-a8-integration/verification/T-005/green-sh.log, .../T-005/red-sh.log, human apply-step record (Trusted-Signer Registry + two-party signatures on the 5 draft SKIP records) |
| T-006 | REQ-004 (AC-018–AC-021) | TEST-018, TEST-019, TEST-020, TEST-021 | implementation report with acceptance-first red/green evidence, independent quality-gate report, specs/epic-196-a8-integration/verification/T-006/green-sh.log, .../T-006/red-sh.log |
| T-007 | REQ-006 (AC-025), REQ-007 (AC-029, AC-030) | TEST-025, TEST-029, TEST-030 | implementation report with acceptance-first red/green evidence, independent quality-gate report, specs/epic-196-a8-integration/verification/T-007/green-sh.log, .../T-007/red-sh.log |

## Acceptance Mapping

| Acceptance Criterion | Test ID | Task |
|---|---|---|
| AC-001 | TEST-001 | T-001 |
| AC-002 | TEST-002 | T-001 |
| AC-003 | TEST-003 | T-001 |
| AC-004 | TEST-004 | T-001 |
| AC-005 | TEST-005 | T-001 |
| AC-006 | TEST-006 | T-001 |
| AC-007 | TEST-007 | T-003 |
| AC-008 | TEST-008 | T-003 |
| AC-009 | TEST-009 | T-003 |
| AC-010 | TEST-010 | T-003 |
| AC-011 | TEST-011 | T-003 |
| AC-012 | TEST-012 | T-004 |
| AC-013 | TEST-013 | T-005 |
| AC-014 | TEST-014 | T-005 |
| AC-015 | TEST-015 | T-005 |
| AC-016 | TEST-016 | T-005 |
| AC-017 | TEST-017 | T-004 |
| AC-018 | TEST-018 | T-006 |
| AC-019 | TEST-019 | T-006 |
| AC-020 | TEST-020 | T-006 |
| AC-021 | TEST-021 | T-006 |
| AC-022 | TEST-022 | T-002 |
| AC-023 | TEST-023 | T-002 |
| AC-024 | TEST-024 | T-003 (the `check-installed-plugin-drift --mode verify` wiring proof; script itself is T-002) |
| AC-025 | TEST-025 | T-007 |
| AC-026 | TEST-026 | T-005 |
| AC-027 | TEST-027 | T-005 |
| AC-028 | TEST-028 | T-005 |
| AC-029 | TEST-029 | T-007 |
| AC-030 | TEST-030 | T-007 |

All 30 acceptance criteria (AC-001–AC-030) are accounted for; none is
unassigned.

## Deliverables (Per Task)

| Task | Issue | New Files | Edited Files |
|---|---|---|---|
| T-001 | #196 | tests/fixtures/cross-runtime-handoff/handoff-01-claude-to-codex.yaml; handoff-02-codex-to-copilot.md; tests/cross-runtime-handoff.tests.sh; tests/cross-runtime-handoff.tests.ps1; plugins/sdd-review-loop/references/a8-skip-allowlist.json (created, AC-006 entry) | tests/run-all.sh; tests/run-all.ps1; specs/epic-196-a8-integration/human-copy/.github/workflows/test.yml (staged); specs/epic-196-a8-integration/human-copy/MANIFEST.sha256 |
| T-002 | #196 | plugins/sdd-quality-loop/scripts/check-installed-plugin-drift.py; .sh; .ps1; tests/check-installed-plugin-drift.tests.sh; .ps1; tests/fixtures/installed-plugin-drift/ | tests/run-all.sh; tests/run-all.ps1; specs/epic-196-a8-integration/human-copy/.github/workflows/test.yml (staged, appended); specs/epic-196-a8-integration/human-copy/MANIFEST.sha256 |
| T-003 | #196 | tests/install-uninstall-matrix.tests.sh; .ps1; tests/fixtures/install-uninstall-matrix/ | tests/run-all.sh; tests/run-all.ps1; specs/epic-196-a8-integration/human-copy/.github/workflows/test.yml (staged, appended); specs/epic-196-a8-integration/human-copy/MANIFEST.sha256 |
| T-004 | #196 | (none — extends an existing file only) | tests/cli-hook-enforcement.ps1 |
| T-005 | #196 | plugins/sdd-review-loop/references/a8-trusted-signers.json; a8-expected-hook-config-digests.json; tests/hook-activation-live-proof/nonce-ledger.json; claude-active.json; codex-enabled-active.json; codex-disabled-expected-unavailable.json; copilot-primary-active.json; copilot-subagent-expected-unavailable.json; plugins/sdd-quality-loop/scripts/validate-live-host-proof.py; .sh; .ps1; tests/validate-live-host-proof.tests.sh; .ps1; tests/fixtures/live-host-proof/ | plugins/sdd-review-loop/references/a8-skip-allowlist.json (appends AC-015/AC-016 entries); tests/run-all.sh; tests/run-all.ps1; specs/epic-196-a8-integration/human-copy/.github/workflows/test.yml (staged, appended); specs/epic-196-a8-integration/human-copy/MANIFEST.sha256 |
| T-006 | #196 | tests/path-lineending-regression.tests.sh; .ps1; tests/fixtures/path-lineending-regression/ | tests/run-all.sh; tests/run-all.ps1; specs/epic-196-a8-integration/human-copy/.github/workflows/test.yml (staged, appended); specs/epic-196-a8-integration/human-copy/MANIFEST.sha256 |
| T-007 | #196 | plugins/sdd-quality-loop/scripts/check-a8-classification-table.py; .sh; .ps1; check-a8-scope-boundary.py; .sh; .ps1; check-a8-citation-compliance.py; .sh; .ps1; tests/check-a8-process-integrity.tests.sh; .ps1 | tests/run-all.sh; tests/run-all.ps1; specs/epic-196-a8-integration/human-copy/.github/workflows/test.yml (staged, appended — final cumulative candidate); specs/epic-196-a8-integration/human-copy/MANIFEST.sha256 |

## Final Status

Update requirement status only from saved test evidence and quality-gate
reports. Implementation reports are claims, not independent verification
evidence. REQ-003's own Status additionally stays gated on the AC-013–016
manual-required/SKIP disposition (Assumptions, requirements.md): a
`Done` status for T-004/T-005 records `validate-live-host-proof` reporting
`pending` (the correct pre-Epic-A1-merge state), never `discharged`, until
a follow-up task un-skips AC-006/AC-015/AC-016 after Epic A1 merges (Main
Workflows step 7, requirements.md).
