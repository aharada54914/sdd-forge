# Traceability: quality-loop-fixes

Every Layer Spec cell contains one or more canonical layer-spec anchors, or a
reasoned cross-layer N/A.

| Requirement | Investigation | Layer Spec | Design | API/Schema | Code Target | Test ID | Test Target | Evidence | Status |
|---|---|---|---|---|---|---|---|---|---|
| REQ-001 | investigation.md INV-001..005, INV-020..023, INV-026 (bash 3.2/`.ps1` exit conventions this task's own edits follow) | infra-spec.md#cicd-sequence; security-spec.md#trust-boundaries | design.md#api--contract-plan (`check-quality-gate-cycle-limit` new `<task-id> <feature> [reports-dir]` contract + two-predicate counting logic; `ship/SKILL.md` Step 4 human-copy edit; `.github/workflows/test.yml` CI-registration human-copy edit); design.md#protected-file-statement (the two carve-outs sharing one `MANIFEST.sha256`) | New CLI contract: `feature` REQUIRED second positional, grammar `^[a-z0-9][a-z0-9-]*$`, missing/malformed → usage error exit 2; count = reports matching BOTH the word-bounded task id AND an anchored `^Feature:[[:space:]]*<feature>[[:space:]]*$` line (reuses `emit-run-record.sh:125`'s anchor shape) | plugins/sdd-quality-loop/scripts/check-quality-gate-cycle-limit.sh; .ps1 | TEST-001, TEST-002, TEST-003, TEST-004, TEST-005, TEST-006, TEST-007 | tests/quality-gate-cycle-limit.tests.sh; staged `specs/quality-loop-fixes/human-copy/` candidates + `MANIFEST.sha256` | reports/quality-gate/ for T-001; specs/quality-loop-fixes/verification/T-001/ | Planned |
| REQ-002 | investigation.md INV-006..010, INV-026 (`emit-run-record.ps1`'s missing trailing `exit`, closed by this task) | N/A — cross-layer only: an anchored one-line read replacing an unanchored whole-file scan over repository-local gate-report content; introduces no new trust boundary of its own — security-spec.md's own Impact Assessment states directly: "Streams 1 and 2 carry materially lower risk... and are covered here for completeness rather than because either introduces a new boundary of its own" | design.md#api--contract-plan (`emit-run-record.{sh,ps1}` anchored `^VERDICT:[[:space:]]*BLOCKED[[:space:]]*$` replacement) | `gate_reports.blocked` = count of feature-scoped reports matching the anchored `VERDICT:` line only; a report with no `VERDICT:` line is not counted (fail-open, OQ-4) | plugins/sdd-quality-loop/scripts/emit-run-record.sh; .ps1 | TEST-008, TEST-009, TEST-010, TEST-011, TEST-012 | tests/emit-run-record-feature-scope.tests.sh; .ps1 | reports/quality-gate/ for T-002; specs/quality-loop-fixes/verification/T-002/ | Planned |
| REQ-003 | investigation.md INV-011..013, INV-015, INV-026 | security-spec.md#trust-boundaries; security-spec.md#stride-analysis | design.md#api--contract-plan (`prepare-panelist-input.{sh,ps1}` `find`-based recursion + declared-outputs completeness check reusing `validate-review-context-set.sh:63-74`'s parser/containment shape); design.md#security-boundaries (Boundary B1) | Recursion visits regular files at any depth under `--input`; every `## Outputs` table row is resolved and containment-checked against the bundle's own input root BEFORE any read, then hash-verified; any gap → fail-closed exit, gap list on stderr, NO digest line | plugins/sdd-quality-loop/scripts/prepare-panelist-input.sh; .ps1 | TEST-013, TEST-014, TEST-015, TEST-016, TEST-017, TEST-018, TEST-032 | tests/prepare-panelist.tests.sh; .ps1 | reports/quality-gate/ for T-003; specs/quality-loop-fixes/verification/T-003/ | Planned |
| REQ-004 | investigation.md INV-011, INV-014 | N/A — cross-layer only: a `cross-model-verify` skill-prose deterministic readiness step with no independent UX/frontend/infra/security runtime surface of its own; its evidence-completeness relevance is captured under REQ-003's Security Boundary B1 (same script family) | design.md#api--contract-plan (Step 1.5 — Pre-Panel Readiness planned shape, inserted between Step 1 and Step 2) | No API change; a new deterministic, fail-closed prose step: no-op when no enumerable coverage requirement is flagged; proceeds to Step 2 when every enumerated element is mapped; STOPS before any panelist invocation when any element is unmapped | plugins/sdd-quality-loop/skills/cross-model-verify/SKILL.md | TEST-019, TEST-020, TEST-021, TEST-031 | plugins/sdd-quality-loop/skills/cross-model-verify/SKILL.md (reviewed at PR time, no dedicated automated suite — `disable-model-invocation: true`/`user-invocable: false`) | reports/quality-gate/ for T-003; specs/quality-loop-fixes/verification/T-003/ | Planned |
| REQ-005 | investigation.md INV-016..019, INV-024 | security-spec.md#trust-boundaries; security-spec.md#stride-analysis | design.md#api--contract-plan (`validate-review-context-set.sh` `\| tr -d '\r'` site enumeration, commit `c756a5a` pattern reused verbatim); design.md#security-boundaries (Boundary B2) | No API change; every enumerated `jq -r` consumption site gains `\| tr -d '\r'` unconditionally; the ledger's own persisted JSON bytes are never touched; `.ps1` twin unmodified (INV-019) | plugins/sdd-quality-loop/scripts/validate-review-context-set.sh | TEST-022, TEST-023, TEST-024, TEST-025, TEST-026 | tests/review-contract-foundation.tests.sh or a new tests/validate-review-context-crlf.tests.sh (task-time decision) | reports/quality-gate/ for T-004; specs/quality-loop-fixes/verification/T-004/ | Planned |
| REQ-006 | investigation.md INV-026 (bash 3.2 `set -u`/`declare -A` avoidance; `.ps1` explicit-exit convention) | N/A — cross-layer only: a cross-cutting shell/PowerShell CI-resilience convention spanning all 4 tasks' own script edits; no dedicated UX/frontend/infra/security runtime surface of its own | design.md#constraint-compliance (CI-resilience rows: bash 3.2 `set -u` array safety; explicit `.ps1` exit); design.md#global-constraints | No API change; every new/changed `.sh` line avoids `declare -A` and guards empty-array expansion under `set -u`; every `.ps1` file touched keeps or gains an explicit `exit N` | all 4 tasks' `.sh`/`.ps1` targets | TEST-027, TEST-028 | each task's own implementation report + grep-based review-time check | reports/quality-gate/ for T-001, T-002, T-003, T-004 | Planned |
| REQ-007 | investigation.md INV-005, INV-025 (CI-registration state); `CHANGELOG.md`'s `## Unreleased` section confirmed existing at task-authoring time | N/A — cross-layer only: documentation and versioning duties spanning all 4 tasks; the affected-document list lives in requirements.md REQ-007 | design.md#constraint-compliance (doc-following + version-bump rows); design.md#global-constraints (four independent `CHANGELOG.md` entries, no create-then-append serialization) | No API change; `CHANGELOG.md` `## Unreleased` gains FOUR independent entries (#167 T-001, #176 T-002, #166 T-003, #179 T-004); applicable doc surfaces verified per task with edits only where a genuine reference exists; no version-literal edit outside `scripts/bump-version.sh` | CHANGELOG.md; README.md; USERGUIDE.md; docs/workflow-guide.md; docs/skill-reference.md; PLUGIN-CONTRACTS.md; docs/troubleshooting.md; docs/contributor/* | TEST-029, TEST-030 | CHANGELOG.md `## Unreleased` section; tests/validate-repository.sh; skill-reference count sync | reports/quality-gate/ for T-001, T-002, T-003, T-004 | Planned |

## Layer Coverage

| Layer | Applicable Requirements | Acceptance Criteria | Primary Sections | Gaps / Reasoned N/A |
|---|---|---|---|---|
| UX | N/A — no user-facing UI | N/A — CLI/script/skill-prose work | ux-spec.md#scope-and-user-journeys | No rendered or interactive surface; ux-spec.md records this as N/A. |
| Frontend | N/A — no browser/frontend bundle | N/A — Bash/PowerShell/Markdown/YAML only | frontend-spec.md#technology-stack | No frontend surface; frontend-spec.md records this as N/A. |
| Infrastructure | REQ-001 | AC-006, AC-007 | infra-spec.md#cicd-sequence | The suite's CI-registration line is staged via human-copy (T-001) and does not run in the 3-OS matrix until the human maintainer applies it as a pre-merge commit — a designed fail-closed gap, not an unmanaged one (infra-spec.md Deployment / CI Plan precedent). |
| Security | REQ-001, REQ-003, REQ-005 | AC-006, AC-007, AC-014, AC-015, AC-016, AC-017, AC-022, AC-023, AC-024, AC-026, AC-032 | security-spec.md#trust-boundaries; security-spec.md#stride-analysis; security-spec.md#security-tests | REQ-002's own risk framing (security-spec.md Impact Assessment) explicitly disclaims a boundary of its own ("Streams 1 and 2 carry materially lower risk... covered here for completeness"); REQ-002 and REQ-004 therefore do not appear in this row (REQ-004's evidence-completeness relevance is carried under REQ-003's B1). |

## Task Mapping

| Task | Requirements | Acceptance Tests | Planned Verification Evidence |
|---|---|---|---|
| T-001 | REQ-001, REQ-006 (share), REQ-007 (share) | TEST-001, TEST-002, TEST-003, TEST-004, TEST-005, TEST-006, TEST-007; TEST-027/TEST-028/TEST-029/TEST-030 legs scoped to this task's files and issue #167 | implementation report with acceptance-first evidence (RT-20260712-001 red-side context + green runs), independent quality-gate report, specs/quality-loop-fixes/verification/T-001/ |
| T-002 | REQ-002, REQ-006 (share), REQ-007 (share) | TEST-008, TEST-009, TEST-010, TEST-011, TEST-012; TEST-027/TEST-028/TEST-029/TEST-030 legs scoped to this task's files and issue #176 | implementation report with acceptance-first evidence (INV-010 red-side context + green runs), WFI-010 `Status: Approved -> Applied` flip, independent quality-gate report, specs/quality-loop-fixes/verification/T-002/ |
| T-003 | REQ-003, REQ-004, REQ-006 (share), REQ-007 (share) | TEST-013..TEST-021, TEST-031, TEST-032; TEST-027/TEST-028/TEST-029/TEST-030 legs scoped to this task's files and issue #166 | implementation report with TDD Red→Green evidence (pre-fix RED run + post-commit-A GREEN run), WFI-009 `Status: Approved -> Applied` flip, independent quality-gate report + independent review verdict distinct from the implementing agent (high risk), specs/quality-loop-fixes/verification/T-003/ |
| T-004 | REQ-005, REQ-006 (share), REQ-007 (share) | TEST-022..TEST-026; TEST-027/TEST-028/TEST-029/TEST-030 legs scoped to this task's files and issue #179 | implementation report with TDD Red→Green evidence (CRLF-shim RED/GREEN pair + BL-010 non-regression re-run), independent quality-gate report + independent review verdict distinct from the implementing agent (high risk), specs/quality-loop-fixes/verification/T-004/ |

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
| AC-008 | TEST-008 | T-002 |
| AC-009 | TEST-009 | T-002 |
| AC-010 | TEST-010 | T-002 |
| AC-011 | TEST-011 | T-002 |
| AC-012 | TEST-012 | T-002 |
| AC-013 | TEST-013 | T-003 |
| AC-014 | TEST-014 | T-003 |
| AC-015 | TEST-015 | T-003 |
| AC-016 | TEST-016 | T-003 |
| AC-017 | TEST-017 | T-003 |
| AC-018 | TEST-018 | T-003 |
| AC-019 | TEST-019 | T-003 |
| AC-020 | TEST-020 | T-003 |
| AC-021 | TEST-021 | T-003 |
| AC-022 | TEST-022 | T-004 |
| AC-023 | TEST-023 | T-004 |
| AC-024 | TEST-024 | T-004 |
| AC-025 | TEST-025 | T-004 |
| AC-026 | TEST-026 | T-004 |
| AC-027 | TEST-027 | T-001, T-002, T-003, T-004 (each task's own leg) |
| AC-028 | TEST-028 | T-001, T-002, T-003, T-004 (each task's own leg) |
| AC-029 | TEST-029 | T-001, T-002, T-003, T-004 (each task's own leg — four independent CHANGELOG entries, never merged into one) |
| AC-030 | TEST-030 | T-001, T-002, T-003, T-004 (each task's own leg) |
| AC-031 | TEST-031 | T-003 |
| AC-032 | TEST-032 | T-003 |

## Deliverables (Per Task)

| Task | Issue | New Files | Edited Files |
|---|---|---|---|
| T-001 | #167 | specs/quality-loop-fixes/human-copy/plugins/sdd-ship/skills/ship/SKILL.md; specs/quality-loop-fixes/human-copy/.github/workflows/test.yml; specs/quality-loop-fixes/human-copy/MANIFEST.sha256 | plugins/sdd-quality-loop/scripts/check-quality-gate-cycle-limit.sh; .ps1; tests/quality-gate-cycle-limit.tests.sh; CHANGELOG.md (CREATE #167 entry); plugins/sdd-ship/skills/ship/SKILL.md (HUMAN-applied pre-merge from the staged candidate — never agent-written); .github/workflows/test.yml (HUMAN-applied pre-merge — never agent-written); docs/review-tickets/RT-20260712-001.yml (`status:` flip — HUMAN post-merge action, not agent-written); conditional doc surfaces |
| T-002 | #176 | none | plugins/sdd-quality-loop/scripts/emit-run-record.sh; .ps1; tests/emit-run-record-feature-scope.tests.sh; .ps1; docs/workflow-improvements/WFI-010.md (`Status: Approved -> Applied`); CHANGELOG.md (CREATE #176 entry); conditional doc surfaces |
| T-003 | #166 | none (all target files pre-exist) | plugins/sdd-quality-loop/scripts/prepare-panelist-input.sh; .ps1; tests/prepare-panelist.tests.sh; .ps1; plugins/sdd-quality-loop/skills/cross-model-verify/SKILL.md; docs/workflow-improvements/WFI-009.md (`Status: Approved -> Applied`); CHANGELOG.md (CREATE #166 entry); conditional doc surfaces |
| T-004 | #179 | tests/validate-review-context-crlf.tests.sh (or an extension of tests/review-contract-foundation.tests.sh — task-time decision, AC-022 note) | plugins/sdd-quality-loop/scripts/validate-review-context-set.sh; CHANGELOG.md (CREATE #179 entry); conditional doc surfaces |

## Final Status

Update requirement status only from saved test evidence and quality-gate reports.
Implementation reports are claims, not independent verification evidence.
