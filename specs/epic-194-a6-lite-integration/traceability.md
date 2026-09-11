# Traceability: epic-194-a6-lite-integration

Every Layer Spec cell contains one or more canonical layer-spec anchors, or a
reasoned cross-layer N/A. This feature ships no UI and no new infrastructure
(design.md Layer Specifications) — `ux-spec.md` and `frontend-spec.md` are
therefore N/A for every requirement row below; `security-spec.md` and
`infra-spec.md` carry substantive, requirement-specific content and are
cited by section anchor per row.

| Requirement | Investigation | Layer Spec | Design | API/Schema | Code Target | Test ID | Test Target | Evidence | Status |
|---|---|---|---|---|---|---|---|---|---|
| REQ-001 | investigation.md INV-007, INV-013, INV-017, INV-018, INV-021 | N/A — cross-layer only: `contracts/**` authorship happened in Epic A2's own Phase 2 (2026-07-23); the v1.1 revision this REQ designs, and its own layer-spec surface, remain outside this feature's build scope (Non-goals; Deferred Requirements, below; investigation.md INV-013 as superseded 2026-08-25) | design.md#data-plan (`lite_policy` v1.1 fragment; `lite-check-catalog.json`); design.md#design-decisions-resolving-open-questions (eleven-category-to-token mapping; `lite-check-catalog.json` seed) | `lite_policy.required_lite_checks` schema fragment; `contracts/lite-check-catalog.json` shape; `lite-upgrade-reason-catalog.json` `catalog_version` 2 growth; validator check (j) | **Deferred — the v1.1 revision is applied by a follow-up A2-owned revision task (A2's own Phase 2 authored the base file 2026-07-23), not by this feature's own build scope** (requirements.md Non-goals; Roles and Permissions; see "Deferred Requirements", below) | TEST-001, TEST-002, TEST-003, TEST-004, TEST-005, TEST-006, TEST-029 | N/A — this feature's own test suite does not execute these fixtures (Deferred Requirements, below) | N/A — no `reports/quality-gate/` entry from this feature's own tasks | Deferred |
| REQ-002 | investigation.md INV-008, INV-009, INV-014 | security-spec.md#trust-boundaries | design.md#api--contract-plan ("REQ-002 — `check-risk-upgrade` extended CLI"); design.md#data-plan (Capability-derived trigger fragment) | `check-risk-upgrade.sh <source-path> [--capability-reasons <fragment-path>]` / PowerShell equivalent; fragment JSON shape `{"capabilities":[{"id","eligible","upgrade_reasons"}]}` | `specs/epic-194-a6-lite-integration/human-copy/plugins/sdd-lite/scripts/check-risk-upgrade.{sh,ps1}` (staged); `.../references/risk-upgrade-policy.md` (staged); real `plugins/sdd-lite/scripts/check-risk-upgrade.{sh,ps1}` + `.../references/risk-upgrade-policy.md` (human-applied via T-001's runner) | TEST-007, TEST-008, TEST-009, TEST-010, TEST-027, TEST-028 | tests/check-risk-upgrade-byte-identical.{sh,ps1}; tests/check-risk-upgrade-capability-merge.{sh,ps1}; tests/check-risk-upgrade-fragment-fail-closed.{sh,ps1}; tests/check-risk-upgrade-ineligible-no-reasons.{sh,ps1} | reports/quality-gate/ for T-002; specs/epic-194-a6-lite-integration/verification/T-002.green.log; specs/epic-194-a6-lite-integration/verification/T-002.red.log | Planned |
| REQ-003 | investigation.md INV-005, INV-006, INV-016 | security-spec.md#trust-boundaries; infra-spec.md#cicd-sequence | design.md#api--contract-plan ("REQ-003/REQ-004 — `lite-gate` Process extension"); design.md#architecture | `capability-summary.yaml` read-only consumption contract (fields: `required_lite_checks`, `full_upgrade_required`); validation against `contracts/capability-summary.schema.json` (A4-owned, not reimplemented) | `plugins/sdd-lite/skills/lite-gate/SKILL.md` (direct edit, T-004) | TEST-011, TEST-012, TEST-013, TEST-030 | tests/lite-gate-summary-absent.{sh,ps1}; tests/lite-gate-summary-invalid.{sh,ps1}; tests/lite-gate-summary-absent-active-enforcement.{sh,ps1} | reports/quality-gate/ for T-004; specs/epic-194-a6-lite-integration/verification/T-004.green.log; specs/epic-194-a6-lite-integration/verification/T-004.red.log | Planned |
| REQ-004 | investigation.md INV-008, INV-010, INV-021 | security-spec.md#trust-boundaries; security-spec.md#stride-analysis; infra-spec.md#cicd-sequence | design.md#api--contract-plan ("Lite-check command-discovery contract"; "REQ-003/REQ-004 — `lite-gate` Process extension") | `lite-gate` Process Step 2a (`full_upgrade_required` backstop) + Step 2b (Registry-sourced check execution); command-discovery contract (`package.json` scripts / `scripts/<id>.{sh,ps1}` pair, grammar `^[a-z0-9][a-z0-9-]*$`) | `plugins/sdd-lite/skills/lite-gate/SKILL.md` (direct edit, T-004; re-verified unprotected at implementation-start time) | TEST-014, TEST-015, TEST-016, TEST-017, TEST-018, TEST-026 | tests/lite-gate-summary-consumption.{sh,ps1}; tests/lite-gate-full-upgrade-backstop.{sh,ps1} | reports/quality-gate/ for T-004; specs/epic-194-a6-lite-integration/verification/T-004.green.log; specs/epic-194-a6-lite-integration/verification/T-004.red.log | Planned |
| REQ-005 | investigation.md INV-002, INV-004, INV-006, INV-010 | security-spec.md#trust-boundaries | design.md#api--contract-plan ("REQ-005 — `lite-spec` Risk-Upgrade Gate extension"); design.md#design-decisions-resolving-open-questions ("OQ-002 resolution") | `lite-spec` Risk-Upgrade Gate: `evaluate-predicate` per Capability × declared component; assembled trigger fragment passed as `check-risk-upgrade`'s second argument | `specs/epic-194-a6-lite-integration/human-copy/plugins/sdd-lite/skills/lite-spec/SKILL.md` (staged); real `plugins/sdd-lite/skills/lite-spec/SKILL.md` (human-applied via T-001's runner) | TEST-019, TEST-020, TEST-021, TEST-031 | tests/lite-spec-capability-block.{sh,ps1} | reports/quality-gate/ for T-003; specs/epic-194-a6-lite-integration/verification/T-003.green.log; specs/epic-194-a6-lite-integration/verification/T-003.red.log | Planned |
| REQ-006 | investigation.md (design-phase target itself, no dedicated INV) | infra-spec.md#cicd-sequence | design.md#test-strategy (seventeen numbered fixture items, mapped to requirements.md's own lettered (a)-(l) inventory) | N/A — this REQ fixes a fixture inventory, not an interface | shared — each of T-001..T-004's own `tests/*.tests.{sh,ps1}` suite pair (see Task Mapping, below); T-001's own `apply-protected-files.ps1` and `tests/human-copy-runner-contract.tests.{sh,ps1}` cover item 17 | TEST-022 | acceptance-tests.md "Spec-Authoring-Time Manual Review Record" (AC-022, design-content review — confirms every Test Strategy item names at least one AC/Global concern and every listed testable AC has a covering item); concrete fixtures listed per task in Task Mapping | design.md#test-strategy confirmed present at spec-authoring time (AC-022); concrete fixture pairs Planned across T-001..T-004 |

## Layer Coverage

| Layer | Applicable Requirements | Acceptance Criteria | Primary Sections | Gaps / Reasoned N/A |
|---|---|---|---|---|
| UX | N/A — no user-facing UI for any requirement | N/A — CLI/skill-process feature work throughout | ux-spec.md | No rendered or interactive surface; every artifact this feature's own tasks touch (a CLI script's extended argument, two skill-process documents) is non-interactive (design.md Layer Specifications; ux-spec.md's own top-of-file N/A statement). |
| Frontend | N/A — no browser/frontend bundle for any requirement | N/A — CLI/skill-process feature work throughout | frontend-spec.md#technology-stack | No new runtime service, no new plugin (design.md Global Constraints: "No new plugin — every script/skill this design touches already lives in `plugins/sdd-lite/` or `plugins/sdd-quality-loop/`"); frontend-spec.md records N/A. |
| Infrastructure | REQ-002, REQ-003, REQ-004, REQ-005, REQ-006 | AC-010, AC-014, AC-025, AC-031 | infra-spec.md#cicd-sequence; infra-spec.md#rollback | T-001..T-004's own five new `.sh`/`.ps1` suite pairs (plus the runner's own suite) register in `tests/run-all.*` (direct edit) and stage their `.github/workflows/test.yml` CI steps via human-copy (R-10 protected), in the serialized order tasks.md's Global Constraints fix; no new CI job/matrix dimension is added — the suites run in the existing deterministic lane (infra-spec.md#deployment-topology). |
| Security | REQ-002, REQ-003, REQ-004, REQ-005 | AC-016, AC-017, AC-018, AC-027, AC-028, AC-030, AC-031 | security-spec.md#trust-boundaries; security-spec.md#stride-analysis; security-spec.md#authorization; security-spec.md#owasp-mapping | Fail-closed boundaries: a supplied-but-invalid `--capability-reasons` fragment (REQ-002, exit `2`, Blocker [B3]); an `eligible:false`-no-reasons entry still produces a non-empty trigger (REQ-002, Blocker [B4]); a Capability Summary absent under active `capability_enforcement` (REQ-003, Blocker [B6]); `full_upgrade_required:true` (REQ-004 Step 2a, Blocker [B2]); an unmapped/grammar-failing/symlink-escaping Registry-sourced check-id (REQ-004, Blocker [B7], NEW-01); the protected-file human-copy boundary itself, applied only by T-001's own hash-verified, post-copy-re-verified runner (REQ-002/REQ-005, AC-031) — never a bare `cp`. No new agent-writable approval-like record is introduced by any task (security-spec.md Data Classification and Protection). |

## Deferred Requirements (Out of This Feature's Own Build Scope)

**REQ-001** (Registry `lite_policy` v1.1 additive extension, `contracts/
lite-check-catalog.json`, `lite-upgrade-reason-catalog.json` vocabulary
growth, and `validate-capability-registry`'s new check (j)) has **no task**
in `tasks.md` and is intentionally deferred, per requirements.md's own
text:

- **Non-goals** (requirements.md): "This feature does not author or edit
  `contracts/capability-registry.schema.json`, `contracts/capability-
  registry.json`, `contracts/capability-summary.schema.json`,
  `contracts/facet-manifest.schema.json`, or any other file under
  `contracts/**`... REQ-001 is a design for a future revision Epic A2's
  own Phase 2 (or a follow-up A2-owned revision task) applies."
- **Roles and Permissions** (requirements.md): "Epic A2's own Phase 2
  implementer (or a follow-up A2-owned revision task): the sole intended
  author of the live `contracts/capability-registry.schema.json`/`.json`
  v1.1 edit and the live `contracts/lite-check-catalog.json`/`lite-
  upgrade-reason-catalog.json` catalog-version bumps this feature's
  REQ-001 designs — this feature defines the target shape, it does not
  apply it."
- This deferral **also covers the validator check (j) addition**
  (`plugins/sdd-quality-loop/scripts/validate-capability-registry.{py,sh,
  ps1}`), since REQ-001 item 5 ("Validator and projection ripple") names
  that same future revision as its own applier — this feature's own
  build scope (`tasks.md`) touches no file under `plugins/sdd-quality-
  loop/scripts/validate-capability-registry.*` or `.../generate-gate-
  capabilities.*` (design.md Test Strategy item 11, also REQ-001-scoped,
  is deferred for the identical reason).

**Acceptance Criteria covered by this deferral**: AC-001, AC-002, AC-003,
AC-004, AC-005, AC-006, AC-029 (all REQ-001) — each is a design-phase
target this Phase 1 package's own `design.md`/`requirements.md` text
already satisfies (confirmed by spec-review/impl-review passing); none is
implemented, tested, or re-verified by any task in `tasks.md`. AC-029
specifically records this feature's own half of a cross-epic contract for
Epic A5's Resolver to enforce (requirements.md: "this fixture documents
the contract this feature's own REQ-001 states for A5's Resolver to
enforce, not a fixture this feature's own test suite executes against A5's
code") — Epic A5's own package, not this one, carries the reciprocal
implementation obligation.

## Already-Satisfied at Spec-Authoring Time (No Task Action Required)

The following Acceptance Criteria are design-content-review or Phase-1-
commit-scope facts, already confirmed present by direct inspection at this
package's own spec-authoring time (acceptance-tests.md "Spec-Authoring-Time
Manual Review Record") — no task in `tasks.md` re-implements or re-tests
them; they are listed here only to close AC-COVERAGE cleanly:

- **AC-020** (REQ-005, design-content review) — `design.md`'s Design
  Decisions "OQ-002 resolution" section states candidate (a) as selected
  and the `ship`-time recheck as retained. T-003's own Done-When cites
  this AC by reference (its implementation matches the already-confirmed
  design, not a new fixture).
- **AC-022** (REQ-006, design-content review) — `design.md`'s Test
  Strategy section's own seventeen-item-to-AC mapping, confirmed complete
  at spec-authoring time.
- **AC-023, AC-024, AC-025** (Global) — this Phase 1 package's own
  registration-commit scope-boundary and `Pending`-status facts, verified
  directly against the live repository at that commit's own time (already
  landed before this Phase 2 task decomposition began) — not implementation-
  phase tests any `tasks.md` task re-runs. AC-025's own `check-sdd-
  structure.sh`/`check-workflow-state.sh` green-check is, however, re-run
  per task in this Phase 2 (tasks.md "Registration-Drift Check, Global,
  AC-025-class") since each task adds its own new registration surface.

## Task Mapping

| Task | Requirements | Acceptance Tests | Planned Verification Evidence |
|---|---|---|---|
| T-001 | REQ-002 (share — application mechanism), REQ-005 (share — application mechanism), REQ-006 (share — item 17) | TEST-031 (share); item-17 fixture | implementation report with TDD red/green evidence, independent quality-gate report (incl. security-review confirmation), specs/epic-194-a6-lite-integration/verification/T-001/green-sh.log, .../T-001/red-sh.log |
| T-002 | REQ-002, REQ-006 (share — items 4/5/13/14) | TEST-007, TEST-008, TEST-009, TEST-010, TEST-027, TEST-028 | implementation report with TDD red/green evidence, independent quality-gate report, specs/epic-194-a6-lite-integration/verification/T-002.green.log, .../T-002.red.log, .../verification/qg/T-002/unit-acceptance-green.log, specs/epic-194-a6-lite-integration/human-copy/MANIFEST.sha256 (3 new entries) |
| T-003 | REQ-005, REQ-006 (share — item 6) | TEST-019, TEST-020, TEST-021, TEST-031 (share) | implementation report with TDD red/green evidence, independent quality-gate report, specs/epic-194-a6-lite-integration/verification/T-003.green.log, .../T-003.red.log, .../verification/qg/T-003/unit-acceptance-green.log, specs/epic-194-a6-lite-integration/human-copy/MANIFEST.sha256 (1 new entry) |
| T-004 | REQ-003, REQ-004, REQ-006 (share — items 7/8/9/12/15) | TEST-011, TEST-012, TEST-013, TEST-014, TEST-015, TEST-016, TEST-017, TEST-018, TEST-026, TEST-030 | implementation report with TDD red/green evidence, independent quality-gate report, specs/epic-194-a6-lite-integration/verification/T-004.green.log, .../T-004.red.log |

## Acceptance Mapping

| Acceptance Criterion | Test ID | Task |
|---|---|---|
| AC-001 | TEST-001 | Deferred (REQ-001, Epic A2 Phase 2) |
| AC-002 | TEST-002 | Deferred (REQ-001, Epic A2 Phase 2) |
| AC-003 | TEST-003 | Deferred (REQ-001, Epic A2 Phase 2) |
| AC-004 | TEST-004 | Deferred (REQ-001, Epic A2 Phase 2) |
| AC-005 | TEST-005 | Deferred (REQ-001, Epic A2 Phase 2) |
| AC-006 | TEST-006 | Deferred (REQ-001, Epic A2 Phase 2) |
| AC-007 | TEST-007 | T-002 |
| AC-008 | TEST-008 | T-002 |
| AC-009 | TEST-009 | T-002 |
| AC-010 | TEST-010 | T-002 (staging), T-001 (application mechanism, AC-031) |
| AC-011 | TEST-011 | T-004 |
| AC-012 | TEST-012 | T-004 |
| AC-013 | TEST-013 | T-004 |
| AC-014 | TEST-014 | T-004 |
| AC-015 | TEST-015 | T-004 |
| AC-016 | TEST-016 | T-004 |
| AC-017 | TEST-017 | T-004 |
| AC-018 | TEST-018 | T-004 |
| AC-019 | TEST-019 | T-003 |
| AC-020 | TEST-020 | T-003 (design-content review — Already-Satisfied, above) |
| AC-021 | TEST-021 | T-003 |
| AC-022 | TEST-022 | Already-Satisfied at spec-authoring time (REQ-006, design-content review); concrete fixtures across T-001..T-004 |
| AC-023 | (none) | Already-Satisfied at Phase 1 spec-package commit time (Global) |
| AC-024 | (none) | Already-Satisfied at Phase 1 spec-package commit time (Global) |
| AC-025 | (none) | Already-Satisfied at Phase 1 spec-package commit time (Global); re-checked per task (Registration-Drift Check) |
| AC-026 | TEST-026 | T-004 |
| AC-027 | TEST-027 | T-002 |
| AC-028 | TEST-028 | T-002 |
| AC-029 | TEST-029 | Deferred (REQ-001, this feature's own half of a cross-epic contract for A5 to enforce) |
| AC-030 | TEST-030 | T-004 |
| AC-031 | TEST-031 | T-001 (runner), T-002 (REQ-002 payload), T-003 (REQ-005 payload) |

## Deliverables (Per Task)

| Task | Issue | New Files | Edited Files |
|---|---|---|---|
| T-001 | #194 | specs/epic-194-a6-lite-integration/human-copy/apply-protected-files.ps1; tests/human-copy-runner-contract.tests.sh; tests/human-copy-runner-contract.tests.ps1; tests/fixtures/epic-194-human-copy/; specs/epic-194-a6-lite-integration/human-copy/MANIFEST.sha256 (created) | tests/run-all.sh; tests/run-all.ps1; CHANGELOG.md (CREATE #194 entry); specs/epic-194-a6-lite-integration/human-copy/.github/workflows/test.yml (staged) |
| T-002 | #194 | tests/check-risk-upgrade-byte-identical.{sh,ps1}; tests/check-risk-upgrade-capability-merge.{sh,ps1}; tests/check-risk-upgrade-fragment-fail-closed.{sh,ps1}; tests/check-risk-upgrade-ineligible-no-reasons.{sh,ps1}; tests/fixtures/epic-194-check-risk-upgrade/; specs/epic-194-a6-lite-integration/human-copy/plugins/sdd-lite/scripts/check-risk-upgrade.{sh,ps1} (staged); specs/epic-194-a6-lite-integration/human-copy/plugins/sdd-lite/references/risk-upgrade-policy.md (staged) | tests/run-all.sh; tests/run-all.ps1; CHANGELOG.md (CREATE #194 entry); specs/epic-194-a6-lite-integration/human-copy/.github/workflows/test.yml (staged, appended); specs/epic-194-a6-lite-integration/human-copy/MANIFEST.sha256 (3 new entries); (post-human-apply) plugins/sdd-lite/scripts/check-risk-upgrade.{sh,ps1}; plugins/sdd-lite/references/risk-upgrade-policy.md |
| T-003 | #194 | tests/lite-spec-capability-block.{sh,ps1}; tests/fixtures/epic-194-lite-spec/; specs/epic-194-a6-lite-integration/human-copy/plugins/sdd-lite/skills/lite-spec/SKILL.md (staged) | tests/run-all.sh; tests/run-all.ps1; CHANGELOG.md (CREATE #194 entry); specs/epic-194-a6-lite-integration/human-copy/.github/workflows/test.yml (staged, appended); specs/epic-194-a6-lite-integration/human-copy/MANIFEST.sha256 (1 new entry); (post-human-apply) plugins/sdd-lite/skills/lite-spec/SKILL.md |
| T-004 | #194 | tests/lite-gate-summary-consumption.{sh,ps1}; tests/lite-gate-summary-absent.{sh,ps1}; tests/lite-gate-summary-invalid.{sh,ps1}; tests/lite-gate-full-upgrade-backstop.{sh,ps1}; tests/lite-gate-summary-absent-active-enforcement.{sh,ps1}; tests/fixtures/epic-194-lite-gate/ | plugins/sdd-lite/skills/lite-gate/SKILL.md (direct edit); tests/run-all.sh; tests/run-all.ps1; CHANGELOG.md (CREATE #194 entry); specs/epic-194-a6-lite-integration/human-copy/.github/workflows/test.yml (staged, appended) |

## Final Status

Update requirement status only from saved test evidence and quality-gate
reports. Implementation reports are claims, not independent verification
evidence. REQ-001's `Deferred` status is a scope statement, not a
verification-pending state — it resolves only when Epic A2's own Phase 2
(or a follow-up A2-owned revision task) applies the live `contracts/**`
edits this feature's own `design.md` specifies; that resolution is
out-of-band for this feature's own Final Status tracking.
