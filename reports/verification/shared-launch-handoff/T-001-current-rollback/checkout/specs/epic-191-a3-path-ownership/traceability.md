# Traceability: epic-191-a3-path-ownership

Every Layer Spec cell contains one or more canonical layer-spec anchors, or a
reasoned cross-layer N/A.

| Requirement | Investigation | Layer Spec | Design | API/Schema | Code Target | Test ID | Test Target | Evidence | Status |
|---|---|---|---|---|---|---|---|---|---|
| REQ-001 | investigation.md INV-001, INV-002, INV-008, OQ-002 | security-spec.md#trust-boundaries | design.md#design-decisions-resolving-open-questions (glob semantics; path/case normalization + raw identity); design.md#data-plan (resolver output shape); design.md#adr-change-log (ADR-0025) | `resolve-component-paths` output: per-path `{raw_path, normalized_path, classification, owning_components, evidence.excluded_match}` + top-level `affected_components`; glob subset (`**`/`*`/zero-segment, unsupported-meta rejected), NFC + `\`→`/` for matching only, byte-wise case sensitivity, A1 schema conformance | plugins/sdd-quality-loop/scripts/resolve-component-paths.py; resolve-component-paths.sh; resolve-component-paths.ps1; tests/component-path-resolver.tests.sh; tests/component-path-resolver.tests.ps1; docs/adr/0025-component-path-ownership-resolver-semantics.md | TEST-001, TEST-002, TEST-003, TEST-004, TEST-005, TEST-006, TEST-007, TEST-008, TEST-009, TEST-010, TEST-011, TEST-056 (added 2026-08-11; see the Acceptance Mapping AC-056 note) | tests/component-path-resolver.tests.sh; tests/component-path-resolver.tests.ps1 | reports/quality-gate/ for T-001; specs/epic-191-a3-path-ownership/verification/T-001/ | Planned |
| REQ-002 | investigation.md INV-001 | security-spec.md#trust-boundaries | design.md#design-decisions-resolving-open-questions (shared_paths precedence; shared_paths entry shape; EXCLUDED_MATCH evidence) | resolver classification EXCLUSIVE / SHARED_BOUNDED / SHARED_CROSS_CUTTING / OVERLAP / UNOWNED via `shared_paths` precedence over per-component `(include − exclude)`; `EXCLUDED_MATCH` evidence tag; both/neither `shared_paths` shape rejected fail-closed | plugins/sdd-quality-loop/scripts/resolve-component-paths.py; tests/component-path-resolver.tests.sh; tests/component-path-resolver.tests.ps1 | TEST-012, TEST-013, TEST-014, TEST-015, TEST-016, TEST-017, TEST-018 | tests/component-path-resolver.tests.sh; tests/component-path-resolver.tests.ps1 | reports/quality-gate/ for T-001; specs/epic-191-a3-path-ownership/verification/T-001/ | Planned |
| REQ-003 | investigation.md INV-008, INV-009, INV-010 | security-spec.md#trust-boundaries; infra-spec.md#cicd-sequence | design.md#api--contract-plan (resolve-component-paths invocation shape); design.md#architecture (git-diff collector 5-axis contract); design.md#security-boundaries (submodule/symlink reference-only) | git-diff collector: `rev-parse --verify <rev>^{commit}` → `merge-base` baseline; `baseline..worktree` ∪ untracked via NUL-framed git porcelain; pinned rename threshold/`diff.renameLimit`/`--no-ext-diff`; submodule/symlink reference-only 4-case; single-writer/TOCTOU fingerprint + retry-once | plugins/sdd-quality-loop/scripts/resolve-component-paths.py (collector stage); resolve-component-paths.sh; resolve-component-paths.ps1; tests/component-path-diff-basis.tests.sh; tests/component-path-diff-basis.tests.ps1 | TEST-019, TEST-020, TEST-021, TEST-022, TEST-023, TEST-024, TEST-025 | tests/component-path-diff-basis.tests.sh; tests/component-path-diff-basis.tests.ps1 | reports/quality-gate/ for T-002; specs/epic-191-a3-path-ownership/verification/T-002/ | Planned |
| REQ-004 | investigation.md INV-001, INV-003, INV-004, INV-005, INV-006, INV-015, INV-016, INV-017, INV-018, INV-019, INV-020 | security-spec.md#trust-boundaries; security-spec.md#stride-analysis | design.md#api--contract-plan (check-component-coverage; guard-invariants.json; generate-guard-invariants.py; risk-gate-matrix.md + check-contract); design.md#data-plan (verdict record); design.md#protected-file-statement; design.md#design-decisions-resolving-open-questions (capability-derived 3-state; protected/required-check-set registrations) | `check-component-coverage.{py,sh,ps1}` — 3-state (`disabled-legacy`/`advisory`/`required`) derived from `workflow.capability_enforcement`/`disabled-legacy`; six Fail conditions (Fail-2/4 mutual-exclusivity, Fail-5 `EXCLUDED_MATCH` Gate reachability, Fail-6 `adapter_paths`); `check-component-coverage-verdict/v1` evidence with `producer.sha256`; `resolve-component-paths --diagnose`; guard-invariants.json +3 `protected_gate_suffixes`; generate-guard-invariants.py `PHASE2_TARGETS` +3; risk-gate-matrix.md + check-contract tier-minimum +1 id + producer-digest pass | plugins/sdd-quality-loop/scripts/check-component-coverage.py; check-component-coverage.sh; check-component-coverage.ps1; plugins/sdd-quality-loop/scripts/resolve-component-paths.py (--diagnose); plugins/sdd-quality-loop/references/risk-gate-matrix.md; plugins/sdd-quality-loop/skills/quality-gate/SKILL.md; tests/check-component-coverage.tests.sh; tests/check-component-coverage.tests.ps1; (human-copy) guard-invariants.json; generate-guard-invariants.py; generated/guard_invariants.py + 3 siblings; check-contract.{sh,ps1,py} | TEST-026, TEST-027, TEST-028, TEST-029, TEST-030, TEST-031, TEST-032, TEST-033, TEST-034, TEST-035, TEST-036, TEST-052, TEST-053, TEST-054, TEST-055 | tests/check-component-coverage.tests.sh; tests/check-component-coverage.tests.ps1 | reports/quality-gate/ for T-004; specs/epic-191-a3-path-ownership/verification/T-004/ | Planned |
| REQ-005 | investigation.md INV-002 | security-spec.md#trust-boundaries | design.md#data-plan (`ownership_digest`; `ownership_input`); design.md#design-decisions-resolving-open-questions (full-input binding, not a consumed subset) | `ownership_digest: sha256:...` over the canonicalized **complete** `ownership_input` (every component's `paths` + every `shared_paths` entry, unconditionally, + matcher semantics version) via Epic A1's canonicalizer; populates ADR-0021 `context_binding`, excluded from semantic-output comparison | plugins/sdd-quality-loop/scripts/resolve-component-paths.py (digest emitter); tests/ownership-digest.tests.sh; tests/ownership-digest.tests.ps1 | TEST-037, TEST-038, TEST-039, TEST-040, TEST-041 | tests/ownership-digest.tests.sh; tests/ownership-digest.tests.ps1 | reports/quality-gate/ for T-003; specs/epic-191-a3-path-ownership/verification/T-003/ | Planned |
| REQ-006 | investigation.md INV-002, INV-021 | security-spec.md#trust-boundaries | design.md#architecture (T-005: no A3 reference doc; A1 template sole source); design.md#design-decisions-resolving-open-questions (single canonical source, no A3 copy; `contracts/**` excluded) | No A3-authored contract or seed-list; a cross-epic fixture reading Epic A1's `contracts/project-context.template.yaml` `shared_paths` section directly and asserting the exact six-entry cross-cutting set (`specs/**`, `reports/**`, `docs/**`, `.github/**`, `tests/fixtures/**`, `CHANGELOG.md`; `contracts/**` absent); FAILS closed while absent | tests/component-path-resolver.tests.sh (cross-epic cases); tests/component-path-resolver.tests.ps1; tests/fixtures/component-path-ownership/ (cross-epic day-one fixture) | TEST-042, TEST-043, TEST-044 | tests/component-path-resolver.tests.sh; tests/component-path-resolver.tests.ps1 | reports/quality-gate/ for T-005; specs/epic-191-a3-path-ownership/verification/T-005/ | Planned |
| REQ-007 | investigation.md INV-009, INV-010 | infra-spec.md#cicd-sequence; security-spec.md#trust-boundaries | design.md#test-strategy; design.md#deployment--ci-plan; design.md#components (fixture tree + five suite pairs) | Monorepo fixture tree under `tests/fixtures/component-path-ownership/` (≥2 overlapping components, nested excluded subtree, bounded `contracts/**` `shared_paths`, 4 submodule/symlink fixtures, NFC-collision fixture, one per glob clause id, cross-epic day-one fixture); five `.sh`/`.ps1` suite pairs registered in `tests/run-all.*` + staged into `.github/workflows/test.yml` (human-copy) | tests/fixtures/component-path-ownership/; tests/component-path-resolver.tests.{sh,ps1}; tests/component-path-diff-basis.tests.{sh,ps1}; tests/check-component-coverage.tests.{sh,ps1}; tests/ownership-digest.tests.{sh,ps1}; tests/component-path-ownership-parity.tests.{sh,ps1}; tests/run-all.{sh,ps1} | TEST-045, TEST-046, TEST-047 | tests/component-path-resolver.tests.{sh,ps1} (AC-045); tests/check-component-coverage.tests.{sh,ps1} (AC-046); tests/component-path-ownership-parity.tests.{sh,ps1} (AC-047) | reports/quality-gate/ for T-001, T-004, T-006; specs/epic-191-a3-path-ownership/verification/{T-001,T-004,T-006}/ | Planned |
| REQ-008 | investigation.md INV-014 | security-spec.md#trust-boundaries | design.md#adr-change-log (ADR-0025 authorship); design.md#constraint-compliance (doc-following; version-bump discipline; single-source count) | No new runtime contract; `docs/adr/0025-component-path-ownership-resolver-semantics.md` records glob semantics/precedence/six Fail conditions; one NEW `CHANGELOG.md` `## Unreleased` entry per T-001..T-006 citing #191; version bumps exclusively via `scripts/bump-version.sh` (no version-mutation path in this feature); the three `PROTECTED_GATE_SUFFIXES` entries derived from a single source | docs/adr/0025-component-path-ownership-resolver-semantics.md; CHANGELOG.md | TEST-048, TEST-049 | docs/adr/0025-component-path-ownership-resolver-semantics.md; CHANGELOG.md `## Unreleased` entries (6, one per T-001..T-006) | reports/quality-gate/ for T-001..T-006; specs/epic-191-a3-path-ownership/verification/{T-001..T-006}/ | Planned |
| REQ-009 | investigation.md INV-008, INV-010 | infra-spec.md#cicd-sequence; security-spec.md#trust-boundaries | design.md#test-strategy (Canonical normalized stdout JSON form); design.md#architecture (parity harness — product-wrapper-direct) | Parity harness feeding identical fixture+argv DIRECTLY to `resolve-component-paths.{sh,ps1}` and `check-component-coverage.{sh,ps1}` (the two product wrapper pairs); diffs canonical normalized stdout JSON / exit code / WARN-error category / argv pass-through (incl. `$LASTEXITCODE`) byte-for-byte; registered in `tests/run-all.*` + staged into `.github/workflows/test.yml` (human-copy) | tests/component-path-ownership-parity.tests.sh; tests/component-path-ownership-parity.tests.ps1; tests/run-all.{sh,ps1} | TEST-050, TEST-051 | tests/component-path-ownership-parity.tests.sh; tests/component-path-ownership-parity.tests.ps1 | reports/quality-gate/ for T-006; specs/epic-191-a3-path-ownership/verification/T-006/ | Planned |

## Layer Coverage

| Layer | Applicable Requirements | Acceptance Criteria | Primary Sections | Gaps / Reasoned N/A |
|---|---|---|---|---|
| UX | N/A — no user-facing UI | N/A — CLI/script + Implementation Gate + reference-documentation feature work | ux-spec.md | No rendered or interactive surface; the resolver, the Gate, the ADR, and the fixtures have no GUI entry point (design.md Layer Specifications; investigation.md INV-013). ux-spec.md records this as N/A. |
| Frontend | N/A — no browser/frontend bundle | N/A — CLI/script feature work | frontend-spec.md#technology-stack | Python master + Bash/PowerShell wrappers + fixture tree + Markdown ADR is not a frontend surface; frontend-spec.md records N/A. |
| Infrastructure | REQ-004, REQ-007, REQ-009 | AC-036, AC-041, AC-047, AC-051 | infra-spec.md#cicd-sequence | The five new `.sh`/`.ps1` suite pairs register in `tests/run-all.*` (direct edit) and stage their `.github/workflows/test.yml` CI steps via human-copy (R-10 protected, INV-010); no new CI job/matrix dimension — the suites run in the existing deterministic 3-OS lane. `check-component-coverage`'s content-protection registration (guard-invariants toolchain, six files) is likewise human-copy staged. |
| Security | REQ-001, REQ-002, REQ-003, REQ-004 | AC-005, AC-006, AC-010, AC-013, AC-018, AC-021, AC-024, AC-035, AC-036, AC-054, AC-055 | security-spec.md#trust-boundaries; security-spec.md#stride-analysis | Protected-file write/read boundary (guard-invariants.json + generate-guard-invariants.py + generated siblings + `.github/workflows/test.yml` + check-contract.{sh,ps1,py} — all human-copy staged, never written directly); new-script content-protection registration + reachability required-check-set registration (two independent boundaries, INV-017) + producer-digest tamper-evidence pass (INV-018/INV-019, two-tier scope per ADR-0019); submodule/symlink reference-only boundary (REQ-003); byte-wise case-sensitivity + NFC-collision fail-closed + unsupported-metacharacter fail-closed (REQ-001); Fail-6 credential exclusion (never reads `credentials`). |

## Task Mapping

| Task | Requirements | Acceptance Tests | Planned Verification Evidence |
|---|---|---|---|
| T-001 | REQ-001, REQ-002, REQ-007 (share — AC-045), REQ-008 (share — authors ADR-0025) | TEST-001..TEST-018, TEST-045; TEST-048 (ADR + CHANGELOG share), TEST-049 (no-version-bump share) scoped to this task's own diff and issue #191 | implementation report with TDD red/green evidence, independent quality-gate report, specs/epic-191-a3-path-ownership/verification/T-001/green-sh.log, .../T-001/red-sh.log, docs/adr/0025-component-path-ownership-resolver-semantics.md |
| T-002 | REQ-003, REQ-007 (share), REQ-008 (share) | TEST-019..TEST-025; TEST-048/TEST-049 shares scoped to this task's own diff and issue #191 | implementation report with TDD red/green evidence, independent quality-gate report, specs/epic-191-a3-path-ownership/verification/T-002/green-sh.log, .../T-002/red-sh.log |
| T-003 | REQ-005, REQ-007 (share), REQ-008 (share) | TEST-037..TEST-041; TEST-048/TEST-049 shares scoped to this task's own diff and issue #191 | implementation report with acceptance-first evidence, independent quality-gate report, specs/epic-191-a3-path-ownership/verification/T-003/green-sh.log, .../T-003/red-sh.log |
| T-004 | REQ-004, REQ-007 (share — AC-046), REQ-008 (share) | TEST-026..TEST-036, TEST-046, TEST-052, TEST-053, TEST-054, TEST-055; TEST-048/TEST-049 shares scoped to this task's own diff and issue #191 | implementation report with TDD red/green evidence, independent quality-gate report, specs/epic-191-a3-path-ownership/verification/T-004/green-sh.log, .../T-004/red-sh.log, specs/epic-191-a3-path-ownership/human-copy/MANIFEST.sha256 (9 staged protected entries + test.yml) |
| T-005 | REQ-006, REQ-007 (share), REQ-008 (share) | TEST-042, TEST-043, TEST-044; TEST-048/TEST-049 shares scoped to this task's own diff and issue #191 | implementation report with acceptance-first evidence, independent quality-gate report, specs/epic-191-a3-path-ownership/verification/T-005/green-sh.log, .../T-005/red-sh.log |
| T-006 | REQ-009, REQ-007 (share — AC-047), REQ-008 (share) | TEST-047, TEST-050, TEST-051; TEST-048/TEST-049 shares scoped to this task's own diff and issue #191 | implementation report with TDD red/green evidence, independent quality-gate report, specs/epic-191-a3-path-ownership/verification/T-006/green-sh.log, .../T-006/red-sh.log |

## Acceptance Mapping

| Acceptance Criterion | Test ID | Task |
|---|---|---|
| AC-001 | TEST-001 | T-001 |
| AC-002 | TEST-002 | T-001 |
| AC-003 | TEST-003 | T-001 |
| AC-004 | TEST-004 | T-001 |
| AC-005 | TEST-005 | T-001 |
| AC-006 | TEST-006 | T-001 |
| AC-007 | TEST-007 | T-001 |
| AC-008 | TEST-008 | T-001 |
| AC-009 | TEST-009 | T-001 |
| AC-010 | TEST-010 | T-001 |
| AC-011 | TEST-011 | T-001 |
| AC-012 | TEST-012 | T-001 |
| AC-013 | TEST-013 | T-001 |
| AC-014 | TEST-014 | T-001 |
| AC-015 | TEST-015 | T-001 |
| AC-016 | TEST-016 | T-001 |
| AC-017 | TEST-017 | T-001 |
| AC-018 | TEST-018 | T-001 |
| AC-019 | TEST-019 | T-002 |
| AC-020 | TEST-020 | T-002 |
| AC-021 | TEST-021 | T-002 |
| AC-022 | TEST-022 | T-002 |
| AC-023 | TEST-023 | T-002 |
| AC-024 | TEST-024 | T-002 |
| AC-025 | TEST-025 | T-002 |
| AC-026 | TEST-026 | T-004 |
| AC-027 | TEST-027 | T-004 |
| AC-028 | TEST-028 | T-004 |
| AC-029 | TEST-029 | T-004 |
| AC-030 | TEST-030 | T-004 |
| AC-031 | TEST-031 | T-004 |
| AC-032 | TEST-032 | T-004 |
| AC-033 | TEST-033 | T-004 |
| AC-034 | TEST-034 | T-004 |
| AC-035 | TEST-035 | T-004 |
| AC-036 | TEST-036 | T-004 |
| AC-037 | TEST-037 | T-003 |
| AC-038 | TEST-038 | T-003 |
| AC-039 | TEST-039 | T-003 |
| AC-040 | TEST-040 | T-003 |
| AC-041 | TEST-041 | T-003 |
| AC-042 | TEST-042 | T-005 |
| AC-043 | TEST-043 | T-005 |
| AC-044 | TEST-044 | T-005 |
| AC-045 | TEST-045 | T-001 |
| AC-046 | TEST-046 | T-004 |
| AC-047 | TEST-047 | T-006 |
| AC-048 | TEST-048 | T-001 (ADR authorship + share), T-002 (share), T-003 (share), T-004 (share), T-005 (share), T-006 (share) — each task's own CHANGELOG `## Unreleased` entry citing #191; ADR-0025 authored by T-001 |
| AC-049 | TEST-049 | T-001 (share), T-002 (share), T-003 (share), T-004 (share), T-005 (share), T-006 (share) — each task's own no-version-bump grep self-check |
| AC-050 | TEST-050 | T-006 |
| AC-051 | TEST-051 | T-006 |
| AC-052 | TEST-052 | T-004 |
| AC-053 | TEST-053 | T-004 |
| AC-054 | TEST-054 | T-004 |
| AC-055 | TEST-055 | T-004 |
| AC-056 | TEST-056 | T-001 |

(2026-08-11 note, AC-056/TEST-056 — DEFERRAL RATIONALE, this table's
authoritative coverage anchor for the criterion. Amended in the a7r1
task-review round, which ruled this note's earlier wording a descriptive
explanation rather than an explicit deferral rationale; this revision
states the deferral explicitly. tasks.md itself carries no AC-056
reference and, under this feature's review freeze, MUST NOT be edited to
add one: the task plan is hash-bound by task-review provenance, its body
is frozen after review, and this criterion was created by the
human-authorized requirements/acceptance-tests amendment `6e7c84dd` —
closing the a2r3 spec re-review's EDGE-CASE-COVERAGE Major — AFTER that
freeze. The AC-056 -> TEST-056 -> T-001 obligation is therefore DEFERRED
from tasks.md's frozen text to this traceability row, under the same
frozen-artifact supersession convention this feature already uses for the
ADR-0025 -> ADR-0027 renumbering (T-001.md's dated WFI-023 note). The
assignment is mechanically forced by the approved documents, not a new
decision: acceptance-tests.md maps AC-056 1:1 to TEST-056 under REQ-001,
design.md's Cross-Layer Dependencies REQ-001 row names AC-056, and T-001
is the only task carrying REQ-001. The obligation is discharged and
verified through T-001's own resolver suite — TEST-056.1..TEST-056.6 in
tests/component-path-resolver.tests.sh and .tests.ps1
(present-but-malformed `--config`, plain and `--diagnose`, three malformed
classes, disposable fixture trees, per acceptance-tests.md's AC-056 row
and Notes) — and by T-001's independent quality-gate evaluation, which
judged the criterion on the implementation's merits and recorded PASS at
ledger seq0683. Forward rule: if tasks.md is ever legitimately unfrozen
for a body edit, AC-056 must be folded into T-001's Requirements/Done-When
text and this deferral note reduced to a historical record.)

## Deliverables (Per Task)

| Task | Issue | New Files | Edited Files |
|---|---|---|---|
| T-001 | #191 | plugins/sdd-quality-loop/scripts/resolve-component-paths.py; resolve-component-paths.sh; resolve-component-paths.ps1; tests/component-path-resolver.tests.sh; tests/component-path-resolver.tests.ps1; tests/fixtures/component-path-ownership/ (base fixture tree); docs/adr/0025-component-path-ownership-resolver-semantics.md | tests/run-all.sh; tests/run-all.ps1; CHANGELOG.md (CREATE #191 entry); specs/epic-191-a3-path-ownership/human-copy/.github/workflows/test.yml (staged); specs/epic-191-a3-path-ownership/human-copy/MANIFEST.sha256 |
| T-002 | #191 | tests/component-path-diff-basis.tests.sh; tests/component-path-diff-basis.tests.ps1 | plugins/sdd-quality-loop/scripts/resolve-component-paths.py (collector stage); resolve-component-paths.sh; resolve-component-paths.ps1; tests/fixtures/component-path-ownership/ (diff-basis fixtures); tests/run-all.sh; tests/run-all.ps1; CHANGELOG.md (CREATE #191 entry); specs/epic-191-a3-path-ownership/human-copy/.github/workflows/test.yml (staged, appended); specs/epic-191-a3-path-ownership/human-copy/MANIFEST.sha256 |
| T-003 | #191 | tests/ownership-digest.tests.sh; tests/ownership-digest.tests.ps1 | plugins/sdd-quality-loop/scripts/resolve-component-paths.py (digest emitter); tests/run-all.sh; tests/run-all.ps1; CHANGELOG.md (CREATE #191 entry); specs/epic-191-a3-path-ownership/human-copy/.github/workflows/test.yml (staged, appended); specs/epic-191-a3-path-ownership/human-copy/MANIFEST.sha256 |
| T-004 | #191 | plugins/sdd-quality-loop/scripts/check-component-coverage.py; check-component-coverage.sh; check-component-coverage.ps1; tests/check-component-coverage.tests.sh; tests/check-component-coverage.tests.ps1; specs/epic-191-a3-path-ownership/human-copy/plugins/sdd-quality-loop/references/guard-invariants.json (staged); .../scripts/generate-guard-invariants.py (staged); .../scripts/generated/guard_invariants.py (staged); .../scripts/generated/guard-invariants.generated.{js,ps1,sh} (staged); .../scripts/check-contract.{sh,ps1,py} (staged) | plugins/sdd-quality-loop/scripts/resolve-component-paths.py (--diagnose subcommand); plugins/sdd-quality-loop/references/risk-gate-matrix.md; plugins/sdd-quality-loop/skills/quality-gate/SKILL.md (## Process); tests/fixtures/component-path-ownership/ (Fail-1..6 + contracts bounded-shared fixtures); tests/run-all.sh; tests/run-all.ps1; CHANGELOG.md (CREATE #191 entry); specs/epic-191-a3-path-ownership/human-copy/.github/workflows/test.yml (staged, appended); specs/epic-191-a3-path-ownership/human-copy/MANIFEST.sha256 (9 protected entries + test.yml) |
| T-005 | #191 | (none — shares T-001's suite; adds cases + fixtures only) | tests/component-path-resolver.tests.sh; tests/component-path-resolver.tests.ps1; tests/fixtures/component-path-ownership/ (cross-epic day-one + six-entry seed fixtures); CHANGELOG.md (CREATE #191 entry) |
| T-006 | #191 | tests/component-path-ownership-parity.tests.sh; tests/component-path-ownership-parity.tests.ps1 | tests/run-all.sh; tests/run-all.ps1; CHANGELOG.md (CREATE #191 entry); specs/epic-191-a3-path-ownership/human-copy/.github/workflows/test.yml (staged, appended); specs/epic-191-a3-path-ownership/human-copy/MANIFEST.sha256 |

## Final Status

Update requirement status only from saved test evidence and quality-gate reports.
Implementation reports are claims, not independent verification evidence.
