# Traceability: epic-190-a2-capability-registry

Every Layer Spec cell contains one or more canonical layer-spec anchors, or
a reasoned cross-layer N/A.

| Requirement | Investigation | Layer Spec | Design | API/Schema | Code Target | Test ID | Test Target | Evidence | Status |
|---|---|---|---|---|---|---|---|---|---|
| REQ-001 | investigation.md INV-002, INV-007, INV-010, OQ-001, OQ-002, OQ-003 | ux-spec.md#n-a (N/A — no UI surface); frontend-spec.md#technology-stack (N/A — no browser/client UI); security-spec.md#trust-boundaries | design.md#components (Registry schema/instance/catalog); design.md#api--contract-plan (`contracts/capability-registry.schema.json` §REQ-001; the shared `#/definitions/predicate`); design.md#design-decisions-resolving-open-questions (`contracts/` over `sdd/`; flat top-level `gates[]`; `delivery_strategy.kind` open+required; `upgrade_reasons` open+catalog-checked) | `contracts/capability-registry.schema.json` (draft-07, `additionalProperties: false`); `contracts/capability-registry.json` (`"schema": "capability-registry/v1"`); `contracts/lite-upgrade-reason-catalog.json` (`"schema": "lite-upgrade-reason-catalog/v1"`) | plugins/sdd-quality-loop (no plugin code — see T-001 Planned Files); tests/capability-registry-schema.tests.sh; tests/capability-registry-schema.tests.ps1 | TEST-001, TEST-002, TEST-003, TEST-004, TEST-005, TEST-006, TEST-037, TEST-038 | tests/capability-registry-schema.tests.sh; tests/capability-registry-schema.tests.ps1 | reports/quality-gate/ for T-001; specs/epic-190-a2-capability-registry/verification/T-001/ | Planned |
| REQ-002 | investigation.md INV-004a, INV-014 | ux-spec.md#n-a (N/A); frontend-spec.md#technology-stack (N/A); security-spec.md#trust-boundaries (Security Boundary B2, no-dynamic-evaluation) | design.md#api--contract-plan (Predicate DSL evaluator contract; Evidence JSON Schema); design.md#global-constraints (closed 8-operator grammar, determinism) | `evaluate-predicate.py --predicate <path|-> --component-properties <path|->` → `{"result": bool, "evidence": [...]}`; `PREDICATE_SCHEMA_ERROR` on malformed/out-of-grammar input | plugins/sdd-quality-loop/scripts/evaluate-predicate.py; evaluate-predicate.sh; evaluate-predicate.ps1; tests/evaluate-predicate.tests.sh; tests/evaluate-predicate.tests.ps1 | TEST-007, TEST-008, TEST-009, TEST-010, TEST-011, TEST-012, TEST-013, TEST-040 | tests/evaluate-predicate.tests.sh; tests/evaluate-predicate.tests.ps1 | reports/quality-gate/ for T-002; specs/epic-190-a2-capability-registry/verification/T-002/ | Planned |
| REQ-003 | investigation.md INV-002, INV-008, OQ-004 | ux-spec.md#n-a (N/A); frontend-spec.md#technology-stack (N/A); security-spec.md#trust-boundaries (Security Boundary B1, provider-neutrality) | design.md#api--contract-plan (Registry validator contract; nine-check diagnostic-ID table; Gate implementation identity schema); design.md#design-decisions-resolving-open-questions (`implementation_ref`/Gate-implementation-identity mechanism, OQ-004 closed) | `validate-capability-registry.py --registry <path>` → exit 0 or `registry: <check-id>: <detail>` diagnostics (nine checks a-i) | plugins/sdd-quality-loop/scripts/validate-capability-registry.py; validate-capability-registry.sh; validate-capability-registry.ps1; plugins/sdd-quality-loop/references/provider-terms.json; tests/validate-capability-registry.tests.sh; tests/validate-capability-registry.tests.ps1 | TEST-014, TEST-015, TEST-016, TEST-017, TEST-018, TEST-019, TEST-020, TEST-021, TEST-022, TEST-039 | tests/validate-capability-registry.tests.sh; tests/validate-capability-registry.tests.ps1 | reports/quality-gate/ for T-004; specs/epic-190-a2-capability-registry/verification/T-004/ | Planned |
| REQ-004 | investigation.md INV-006 | ux-spec.md#n-a (N/A); frontend-spec.md#technology-stack (N/A); security-spec.md#trust-boundaries (fragment-selection input validation) | design.md#api--contract-plan (`registry_digest` generator contract: fragment selection, dedupe, stable sort, canonicalizer delegation); design.md#cross-layer-dependencies (Epic A1 canonicalizer hard dependency, blocked) | `generate-registry-digest.py (--capability-ids <ids> \| --gate-ids <ids> \| --whole)` → stdout sha256 hex digest | plugins/sdd-quality-loop/scripts/generate-registry-digest.py; generate-registry-digest.sh; generate-registry-digest.ps1; generate-registry-digest.js; tests/generate-registry-digest.tests.sh; tests/generate-registry-digest.tests.ps1 | TEST-023, TEST-024, TEST-032 | tests/generate-registry-digest.tests.sh; tests/generate-registry-digest.tests.ps1 | reports/quality-gate/ for T-005; specs/epic-190-a2-capability-registry/verification/T-005/ | Planned (T-005 hard-blocked on Epic A1's canonicalizer contract, requirements.md Dependencies) |
| REQ-005 | investigation.md INV-009, INV-015, INV-016 | ux-spec.md#n-a (N/A); frontend-spec.md#technology-stack (N/A); infra-spec.md#deployment-topology (CI drift checks; 3-environment standalone-install discovery); security-spec.md#trust-boundaries (Security Boundary B3 protected-file integrity, B4 discovery fail-closed) | design.md#architecture (Registry discovery contract, script-relative → git-root → fail-closed); design.md#api--contract-plan (Projection generator contract; Registry discovery contract, per-artifact version-check table); design.md#protected-file-statement (seven-path registration); design.md#adr-change-log (ADR-0025, already Accepted) | `generate-gate-capabilities.py [--check]` → writes/verifies `gate-capabilities.json` (`_generated` header + `gates` + `capability_gate_map`); discovery: script-relative packaged copy → git-root fallback → fail-closed, per-artifact version check | plugins/sdd-quality-loop/scripts/generate-gate-capabilities.py; generate-gate-capabilities.sh; generate-gate-capabilities.ps1; plugins/sdd-quality-loop/scripts/generated/gate-capabilities.json; plugins/sdd-quality-loop/scripts/registry_discovery.py; plugins/sdd-quality-loop/scripts/vendor-capability-registry.{py,sh,ps1}; plugins/sdd-quality-loop/contracts/capability-registry.json/.schema.json (vendored); tests/generate-gate-capabilities.tests.sh; tests/generate-gate-capabilities.tests.ps1; tests/registry-discovery.tests.sh; tests/registry-discovery.tests.ps1 | TEST-025, TEST-026, TEST-027, TEST-029 | tests/generate-gate-capabilities.tests.sh; tests/generate-gate-capabilities.tests.ps1; tests/registry-discovery.tests.sh; tests/registry-discovery.tests.ps1 | reports/quality-gate/ for T-003, T-006; specs/epic-190-a2-capability-registry/verification/{T-003,T-006}/ | Planned (AC-029's Status resolves through a human `cp` action, acceptance-tests.md) |
| REQ-006 | investigation.md INV-014 | ux-spec.md#n-a (N/A); frontend-spec.md#technology-stack (N/A); infra-spec.md#cicd-sequence (eight new suite pairs registered in `tests/run-all.*` + staged into `.github/workflows/test.yml`) | design.md#test-strategy (eight `tests/*.tests.sh`/`.tests.ps1` pairs, one per numbered item); design.md#deployment--ci-plan | Eight `tests/*.tests.sh`/`.tests.ps1` pairs + `tests/fixtures/capability-registry/`; golden-fixture parity across all four scripts (+ `.js` for the digest generator); 3-runtime invocation parity | tests/capability-registry-schema.tests.{sh,ps1}; tests/evaluate-predicate.tests.{sh,ps1}; tests/registry-discovery.tests.{sh,ps1}; tests/validate-capability-registry.tests.{sh,ps1}; tests/generate-registry-digest.tests.{sh,ps1}; tests/generate-gate-capabilities.tests.{sh,ps1}; tests/capability-registry-parity.tests.{sh,ps1}; tests/run-all.{sh,ps1} | TEST-030, TEST-031, TEST-033 | tests/capability-registry-parity.tests.{sh,ps1} (AC-031/AC-033); tests/run-all.{sh,ps1} (AC-030) | reports/quality-gate/ for T-001..T-007; specs/epic-190-a2-capability-registry/verification/{T-001..T-007}/ | Planned |

## Deferred / Non-Task Acceptance Criteria

Per task-reviewer-a's AC-COVERAGE check, every AC-NNN not claimed by a
task's `Requirements:` field above is recorded here with a stated
rationale, matching acceptance-tests.md's own documented exceptions:

| Acceptance Criterion | Requirement (per acceptance-tests.md) | Status | Rationale |
|---|---|---|---|
| AC-034 | Non-goals (spec-commit-bound scope boundary) | Satisfied at spec-authoring commit — no implementation task | acceptance-tests.md's Spec-Authoring-Time Manual Review Record: a one-time, spec-commit-bound manual review confirming `git status`/`git diff` for the spec-authoring commit was confined to `specs/epic-190-a2-capability-registry/`. It is evaluated exactly once, against that commit's own SHA (already recorded in the spec-review-loop's round record, not repeated here), and is not re-evaluated at any later commit — every task below is expected to touch `plugins/`, `contracts/`, `tests/`, and `.github/` by design. No TEST-034 row exists in acceptance-tests.md; this is by design, not an omission. |
| AC-035 | User Stories, Dependencies (Phase 1 open-question audit) | Satisfied during Phase 1 (spec-review) — no implementation task | acceptance-tests.md states this check is "doable now, without traceability.md" — it was satisfied when `Spec-Review-Status: Passed` was reached: OQ-001 and OQ-004 are cross-referenced from their relevant REQ/AC entries in requirements.md (REQ-003(h)/AC-022 for OQ-001; REQ-003(c)/AC-016-017 for OQ-004). No Phase 2 task re-performs this audit. |
| AC-036 | User Stories, Dependencies (Phase 2 traceability audit) | Satisfied by this document | acceptance-tests.md marks TEST-036 `Deferred to Phase 2` because its target (this file) did not exist during Phase 1. Now that it exists: OQ-001 (owner Epic A6, not blocking; resolution path is a new `lite-upgrade-reason-catalog.json` `catalog_version`, tracked against REQ-003(h)/AC-022/TEST-022 above) and OQ-004 (closed by orchestrator ruling P8, 2026-07-22; resolution recorded against REQ-003(c)/AC-016-017/TEST-016-017 above, the Gate implementation identity schema) are each traced to the REQ/design/task/test rows above that resolved or exercise them. OQ-002 and OQ-003 are resolved by orchestrator ruling 2026-07-22 (design.md Design Decisions) and are traced against REQ-001/AC-006 (OQ-002, "conditions" is not a third field) and REQ-001/AC-004 (OQ-003, `delivery_strategy.kind` open+required) respectively. No OQ was resolved without a recorded trace. |

## Layer Coverage

| Layer | Applicable Requirements | Acceptance Criteria | Primary Sections | Gaps / Reasoned N/A |
|---|---|---|---|---|
| UX | N/A — no user-facing UI | N/A — CLI/script + machine-readable-contract feature work | ux-spec.md | No rendered or interactive surface; the Registry, its four scripts, and the discovery contract have no GUI entry point (design.md Technical Summary; design.md Layer Specifications). ux-spec.md records this as N/A. |
| Frontend | N/A — no browser/frontend bundle | N/A — CLI/script feature work | frontend-spec.md#technology-stack | Python master + Bash/PowerShell(/JS) wrappers + JSON contract files is not a frontend surface; frontend-spec.md records N/A. |
| Infrastructure | REQ-005, REQ-006 | AC-025, AC-026, AC-027, AC-030, AC-031, AC-033 | infra-spec.md#deployment-topology; infra-spec.md#cicd-sequence | The eight new `.sh`/`.ps1`(/`.js`) suite pairs register in `tests/run-all.*` (direct edit) and stage their `.github/workflows/test.yml` CI steps via human-copy (R-10 protected, INV-009); no new CI job/matrix dimension — the suites run in the existing deterministic lane, extended with the `generate-gate-capabilities.py --check` and vendored-copy drift-check steps (mirroring `generate-guard-invariants.py --check`). `generate-gate-capabilities`'s protected-file registration (guard-invariants toolchain, six staged files / seven newly-registered paths) is likewise human-copy staged, sole-edited by T-006. |
| Security | REQ-002, REQ-003, REQ-005 | AC-007, AC-008, AC-009, AC-011, AC-012, AC-014, AC-016, AC-019, AC-020, AC-021, AC-022, AC-027, AC-029 | security-spec.md#trust-boundaries | Security Boundary B1 (provider-neutrality, REQ-003(g)) — first automated implementation of ADR-0018's boundary in this repository; B2 (no dynamic evaluation, REQ-002) — the closed 8-operator grammar structurally excludes every forbidden operator; B3 (protected-file integrity, REQ-005) — every write to a guard-invariants-protected path goes through human-copy with a SHA-256 manifest, no script this feature's tasks author writes to a protected path directly; B4 (discovery fail-closed, REQ-005) — the Registry discovery contract never silently falls back to a stale or absent artifact, and the vendored-copy drift check additionally gates release. No task introduces network calls, live Provider API calls, secrets, or credentials anywhere in the Registry or its fixtures (Global Constraints, tasks.md). |

## Task Mapping

| Task | Requirements | Acceptance Tests | Planned Verification Evidence |
|---|---|---|---|
| T-001 | REQ-001, REQ-006 (share) | TEST-001..TEST-006, TEST-037, TEST-038 | implementation report with acceptance-first red/green evidence, independent quality-gate report, specs/epic-190-a2-capability-registry/verification/T-001/green-sh.log, .../T-001/red-sh.log |
| T-002 | REQ-002, REQ-006 (share) | TEST-007..TEST-013, TEST-040 | implementation report with TDD red/green evidence, independent quality-gate report, specs/epic-190-a2-capability-registry/verification/T-002/green-sh.log, .../T-002/red-sh.log |
| T-003 | REQ-005 (share — discovery contract only), REQ-006 (share) | TEST-027 | implementation report with TDD red/green evidence, independent quality-gate report, specs/epic-190-a2-capability-registry/verification/T-003/green-sh.log, .../T-003/red-sh.log |
| T-004 | REQ-003, REQ-005 (share — AC-028), REQ-006 (share) | TEST-014..TEST-022, TEST-039, TEST-028 | implementation report with TDD red/green evidence, independent quality-gate report, specs/epic-190-a2-capability-registry/verification/T-004/green-sh.log, .../T-004/red-sh.log |
| T-005 | REQ-004, REQ-006 (share) | TEST-023, TEST-024, TEST-032 | implementation report with acceptance-first red/green evidence, independent quality-gate report, specs/epic-190-a2-capability-registry/verification/T-005/green-sh.log, .../T-005/red-sh.log (blocked on Epic A1's canonicalizer contract until finalized) |
| T-006 | REQ-005 (share — projection generator + protected-file registration), REQ-006 (AC-030 share) | TEST-025, TEST-026, TEST-029, TEST-030 | implementation report with TDD red/green evidence, independent quality-gate report, specs/epic-190-a2-capability-registry/verification/T-006/green-sh.log, .../T-006/red-sh.log, specs/epic-190-a2-capability-registry/human-copy/MANIFEST.sha256 (six staged files / seven newly-registered paths + test.yml) |
| T-007 | REQ-006 (AC-031, AC-033 share) | TEST-031, TEST-033 | implementation report with acceptance-first red/green evidence, independent quality-gate report, specs/epic-190-a2-capability-registry/verification/T-007/green-sh.log, .../T-007/red-sh.log |

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
| AC-011 | TEST-011 | T-002 |
| AC-012 | TEST-012 | T-002 |
| AC-013 | TEST-013 | T-002 |
| AC-014 | TEST-014 | T-004 |
| AC-015 | TEST-015 | T-004 |
| AC-016 | TEST-016 | T-004 |
| AC-017 | TEST-017 | T-004 |
| AC-018 | TEST-018 | T-004 |
| AC-019 | TEST-019 | T-004 |
| AC-020 | TEST-020 | T-004 |
| AC-021 | TEST-021 | T-004 |
| AC-022 | TEST-022 | T-004 |
| AC-023 | TEST-023 | T-005 |
| AC-024 | TEST-024 | T-005 |
| AC-025 | TEST-025 | T-006 |
| AC-026 | TEST-026 | T-006 |
| AC-027 | TEST-027 | T-003 |
| AC-028 | TEST-028 | T-004 (structural placement, this suite's own setup fixture) |
| AC-029 | TEST-029 | T-006 (Status resolves through a human `cp` action) |
| AC-030 | TEST-030 | T-006 (finalized), T-001..T-005, T-007 (each contributes its own suite's registration; T-006 verifies the cumulative state, T-007 re-confirms after its own append) — share |
| AC-031 | TEST-031 | T-007 |
| AC-032 | TEST-032 | T-005 |
| AC-033 | TEST-033 | T-007 |
| AC-034 | (none — TEST-034 does not exist) | N/A — see Deferred / Non-Task Acceptance Criteria, above |
| AC-035 | TEST-035 | N/A — satisfied in Phase 1; see Deferred / Non-Task Acceptance Criteria, above |
| AC-036 | TEST-036 | N/A — satisfied by this document; see Deferred / Non-Task Acceptance Criteria, above |
| AC-037 | TEST-037 | T-001 |
| AC-038 | TEST-038 | T-001 |
| AC-039 | TEST-039 | T-004 |
| AC-040 | TEST-040 | T-002 |

## Deliverables (Per Task)

| Task | Issue | New Files | Edited Files |
|---|---|---|---|
| T-001 | #190 | contracts/capability-registry.schema.json; contracts/capability-registry.json; contracts/lite-upgrade-reason-catalog.json; tests/capability-registry-schema.tests.sh; tests/capability-registry-schema.tests.ps1; tests/fixtures/capability-registry/ (base fixture tree) | tests/run-all.sh; tests/run-all.ps1; specs/epic-190-a2-capability-registry/human-copy/.github/workflows/test.yml (staged); specs/epic-190-a2-capability-registry/human-copy/MANIFEST.sha256 |
| T-002 | #190 | plugins/sdd-quality-loop/scripts/evaluate-predicate.py; evaluate-predicate.sh; evaluate-predicate.ps1; tests/evaluate-predicate.tests.sh; tests/evaluate-predicate.tests.ps1 | tests/fixtures/capability-registry/ (predicate fixtures); tests/run-all.sh; tests/run-all.ps1; specs/epic-190-a2-capability-registry/human-copy/.github/workflows/test.yml (staged, appended); specs/epic-190-a2-capability-registry/human-copy/MANIFEST.sha256 |
| T-003 | #190 | plugins/sdd-quality-loop/scripts/registry_discovery.py; vendor-capability-registry.py; vendor-capability-registry.sh; vendor-capability-registry.ps1; plugins/sdd-quality-loop/contracts/capability-registry.json; capability-registry.schema.json; lite-upgrade-reason-catalog.json (vendored copies); tests/registry-discovery.tests.sh; tests/registry-discovery.tests.ps1 | tests/fixtures/capability-registry/ (discovery fixtures); tests/run-all.sh; tests/run-all.ps1; specs/epic-190-a2-capability-registry/human-copy/.github/workflows/test.yml (staged, appended); specs/epic-190-a2-capability-registry/human-copy/MANIFEST.sha256 |
| T-004 | #190 | plugins/sdd-quality-loop/scripts/validate-capability-registry.py; validate-capability-registry.sh; validate-capability-registry.ps1; plugins/sdd-quality-loop/references/provider-terms.json; tests/validate-capability-registry.tests.sh; tests/validate-capability-registry.tests.ps1 | tests/fixtures/capability-registry/ (registry-mutation fixtures); tests/run-all.sh; tests/run-all.ps1; specs/epic-190-a2-capability-registry/human-copy/.github/workflows/test.yml (staged, appended); specs/epic-190-a2-capability-registry/human-copy/MANIFEST.sha256 |
| T-005 | #190 | plugins/sdd-quality-loop/scripts/generate-registry-digest.py; generate-registry-digest.sh; generate-registry-digest.ps1; generate-registry-digest.js; tests/generate-registry-digest.tests.sh; tests/generate-registry-digest.tests.ps1 | tests/fixtures/capability-registry/ (digest/JCS-NFC fixtures); tests/run-all.sh; tests/run-all.ps1; specs/epic-190-a2-capability-registry/human-copy/.github/workflows/test.yml (staged, appended); specs/epic-190-a2-capability-registry/human-copy/MANIFEST.sha256 |
| T-006 | #190 | plugins/sdd-quality-loop/scripts/generate-gate-capabilities.py; generate-gate-capabilities.sh; generate-gate-capabilities.ps1; plugins/sdd-quality-loop/scripts/generated/gate-capabilities.json; tests/generate-gate-capabilities.tests.sh; tests/generate-gate-capabilities.tests.ps1; specs/epic-190-a2-capability-registry/human-copy/plugins/sdd-quality-loop/references/guard-invariants.json (staged); .../scripts/generate-guard-invariants.py (staged); .../scripts/generated/guard_invariants.py (staged); .../scripts/generated/guard-invariants.generated.{js,ps1,sh} (staged) | tests/fixtures/capability-registry/ (projection fixtures); tests/run-all.sh; tests/run-all.ps1; specs/epic-190-a2-capability-registry/human-copy/.github/workflows/test.yml (staged, appended); specs/epic-190-a2-capability-registry/human-copy/MANIFEST.sha256 (seven newly-registered paths + test.yml) |
| T-007 | #190 | tests/capability-registry-parity.tests.sh; tests/capability-registry-parity.tests.ps1 | tests/fixtures/capability-registry/ (installed-plugin-context fixtures); tests/run-all.sh; tests/run-all.ps1; specs/epic-190-a2-capability-registry/human-copy/.github/workflows/test.yml (staged, appended — final cumulative candidate); specs/epic-190-a2-capability-registry/human-copy/MANIFEST.sha256 |

## Final Status

Update requirement status only from saved test evidence and quality-gate
reports. Implementation reports are claims, not independent verification
evidence.
