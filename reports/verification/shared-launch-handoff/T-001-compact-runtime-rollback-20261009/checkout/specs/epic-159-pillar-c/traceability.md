# Traceability: epic-159-pillar-c

Every Layer Spec cell contains one or more canonical layer-spec anchors, or a
reasoned cross-layer N/A.

| Requirement | Investigation | Layer Spec | Design | API/Schema | Code Target | Test ID | Test Target | Evidence | Status |
|---|---|---|---|---|---|---|---|---|---|
| REQ-001 | investigation.md INV-001 | security-spec.md#trust-boundaries | design.md#api--contract-plan (v2 registry schema); design.md#constraint-compliance | `contracts/agent-model-capabilities.v2.json` — schema `agent-model-capabilities/v2`: `supported_efforts`, `default_effort`, `effort_control` per model; `risk_effort_matrix`; `role_defaults`; v1 frozen | contracts/agent-model-capabilities.v2.json; contracts/agent-model-capabilities.json (v1, read-only); tests/agent-capabilities-v2.tests.sh; tests/agent-capabilities-v2.tests.ps1 | TEST-001, TEST-002, TEST-003, TEST-004, TEST-005, TEST-054 | tests/agent-capabilities-v2.tests.sh; tests/agent-capabilities-v2.tests.ps1 | reports/quality-gate/ for T-001; specs/epic-159-pillar-c/verification/T-001/ | Planned |
| REQ-002 | investigation.md INV-002, INV-009 | security-spec.md#trust-boundaries | design.md#api--contract-plan (selector schema auto-detect + new flags + effort-resolution priority); design.md#constraint-compliance; design.md#adr-change-log (ADR-0012 drafting) | `select-agent-model` JSON output gains `effort_source`, `effort_control` (additive); `--effort-policy welded\|matrix`, `--requested-effort`, `--role`, `--host` CLI flags | plugins/sdd-implementation/scripts/select-agent-model.sh; plugins/sdd-implementation/scripts/select-agent-model.ps1; docs/adr/0012-effort-tier-decoupling.md; tests/agent-model-routing.tests.sh (Phase-1-scoped smoke) | TEST-006, TEST-007, TEST-008, TEST-009, TEST-010, TEST-011, TEST-012, TEST-013, TEST-053, TEST-054 | tests/agent-model-routing.tests.sh; tests/agent-model-routing.tests.ps1 | reports/quality-gate/ for T-002; specs/epic-159-pillar-c/verification/T-002/ | Planned |
| REQ-003 | investigation.md INV-003, INV-004, INV-006, INV-011, INV-012 | security-spec.md#trust-boundaries; infra-spec.md#cicd-sequence | design.md#api--contract-plan (render-agent-frontmatter); design.md#protected-file-statement | `render-agent-frontmatter.sh`/`.ps1` (new); Claude `.md` `model:`/`x-sdd-effort:`; Codex `.toml` `# x-sdd-model:`/`# x-sdd-effort:` comments; `--check` drift mode | render-agent-frontmatter.sh; render-agent-frontmatter.ps1; tests/render-agent-frontmatter.tests.sh; tests/render-agent-frontmatter.tests.ps1; tests/validate-repository.ps1 | TEST-014, TEST-015, TEST-016, TEST-017, TEST-018, TEST-019, TEST-020 | tests/render-agent-frontmatter.tests.sh; tests/render-agent-frontmatter.tests.ps1 | reports/quality-gate/ for T-003; specs/epic-159-pillar-c/verification/T-003/ | Planned |
| REQ-004 | investigation.md INV-005 | security-spec.md#trust-boundaries | design.md#api--contract-plan (run-record v2); design.md#data-plan (3-subfield `effort` object) | `sdd-run-record/v2` — sibling `effort` object to `model_ids`, 3 subfields per role slot: `effort_requested`, `effort_applied`, `effort_degraded_reason` | plugins/sdd-quality-loop/scripts/emit-run-record.sh; plugins/sdd-quality-loop/scripts/emit-run-record.ps1; plugins/sdd-implementation/templates/implementation-report.template.md; tests/emit-run-record-feature-scope.tests.sh; tests/emit-run-record-feature-scope.tests.ps1 | TEST-021, TEST-022, TEST-023, TEST-024, TEST-025, TEST-026, TEST-051 | tests/emit-run-record-feature-scope.tests.sh; tests/emit-run-record-feature-scope.tests.ps1 | reports/quality-gate/ for T-004; specs/epic-159-pillar-c/verification/T-004/ | Planned |
| REQ-005 | investigation.md INV-002 (twin gap) | security-spec.md#trust-boundaries; infra-spec.md#cicd-sequence | design.md#test-strategy; design.md#constraint-compliance (protected `test.yml` row) | No new contract; routing test case list + closed `.ps1` twin gap + 3-part protected-`test.yml` registration proof | tests/agent-model-routing.tests.sh; tests/agent-model-routing.tests.ps1 (new); tests/run-all.ps1 | TEST-027, TEST-028, TEST-029, TEST-030, TEST-031, TEST-032, TEST-033, TEST-034 | tests/agent-model-routing.tests.sh; tests/agent-model-routing.tests.ps1 | reports/quality-gate/ for T-005; specs/epic-159-pillar-c/verification/T-005/ | Planned |
| REQ-006 | investigation.md INV-007, INV-008, INV-014 | security-spec.md#trust-boundaries | design.md#api--contract-plan (run-panelist-gpt `--effort`) | `codex --model <m> --effort <e>` CLI invocation (additive); Codex-host evaluator/investigator startup wiring | plugins/sdd-quality-loop/scripts/run-panelist-gpt.sh; plugins/sdd-quality-loop/scripts/run-panelist-gpt.ps1; plugins/sdd-quality-loop/scripts/prepare-panelist-input.sh; plugins/sdd-quality-loop/scripts/prepare-panelist-input.ps1; tests/run-panelist-effort.tests.sh; tests/run-panelist-effort.tests.ps1 | TEST-035, TEST-036, TEST-037, TEST-038, TEST-039, TEST-040, TEST-052 | tests/run-panelist-effort.tests.sh; tests/run-panelist-effort.tests.ps1 | reports/quality-gate/ for T-006; specs/epic-159-pillar-c/verification/T-006/ | Planned |
| REQ-007 | investigation.md INV-009, INV-010, INV-011 | infra-spec.md#cicd-sequence | design.md#deployment--ci-plan; design.md#design-decisions-resolving-open-questions (OQ-003, OQ-004) | `--effort-policy` default changes from `welded` to `matrix`; no new contract | plugins/sdd-implementation/scripts/select-agent-model.sh (default value); USERGUIDE.md; docs/agent-capability-matrix.md | TEST-041, TEST-042, TEST-043, TEST-044, TEST-045, TEST-046 | select-agent-model default; a real Codex-host run-record | reports/quality-gate/ for T-007; specs/epic-159-pillar-c/verification/T-007/ | Planned |
| REQ-008 | investigation.md INV-013 | security-spec.md#trust-boundaries | design.md#constraint-compliance (cross-host degradation row) | No new contract; `effort_applied=null` + `effort_degraded_reason` structural rule, keyed on `effort_control`, not host identity | (cross-cutting audit — no dedicated new file; verified against T-004's and T-006's own deliverables) | TEST-047, TEST-048 | tests/emit-run-record-feature-scope.tests.sh (TEST-024, TEST-051); tests/run-panelist-effort.tests.sh (TEST-039) | reports/quality-gate/ for T-006 (closing audit); specs/epic-159-pillar-c/verification/T-006/ | Planned |
| REQ-009 | not a per-issue goal — requirements.md states it once as the shared "ドキュメント追従・バージョン改訂" Done condition every one of #149-#155's issue bodies repeats verbatim, and `validate-layer-traceability.py` collects every bare `REQ-NNN` token in requirements.md as a required row | N/A — cross-layer only: documentation and versioning duties spanning T-001 through T-007; the affected-document list lives in requirements.md REQ-009 | design.md#constraint-compliance (doc-following row; version-bump row) | No API change; `CHANGELOG.md` gains one NEW `## Unreleased` entry per T-001..T-006 issue (#149/#150/#151/#153/#154/#152); `PLUGIN-CONTRACTS.md`/`docs/agent-capability-matrix.md`/`USERGUIDE.md`/other REQ-009-listed docs updated per task; version bump exclusively via `scripts/bump-version.sh`, executed only by T-007 | CHANGELOG.md; PLUGIN-CONTRACTS.md; docs/agent-capability-matrix.md; USERGUIDE.md; tests/validate-repository.ps1 | TEST-049, TEST-050 | CHANGELOG.md `## Unreleased` entries (6, one per T-001..T-006); tests/validate-repository.ps1 | reports/quality-gate/ for T-001..T-007 | Planned |

## Layer Coverage

| Layer | Applicable Requirements | Acceptance Criteria | Primary Sections | Gaps / Reasoned N/A |
|---|---|---|---|---|
| UX | N/A — no user-facing UI | N/A — contract/CLI/script feature work | ux-spec.md#scope-and-user-journeys | No rendered or interactive surface; UX spec records this as N/A. |
| Frontend | N/A — no browser/frontend bundle | N/A — contract/CLI/script feature work | frontend-spec.md#technology-stack | JSON contract + Bash/PowerShell scripts + generated Markdown/TOML content is not a frontend surface. |
| Infrastructure | REQ-003, REQ-005, REQ-007 | AC-016, AC-020, AC-027, AC-041, AC-042, AC-043, AC-044 | infra-spec.md#cicd-sequence; infra-spec.md#runtime-budget; infra-spec.md#deployment-topology | `.github/workflows/test.yml` registration for T-001/T-003/T-005/T-006 is human-copy staged (R-10 protected, round-2 correction) rather than a direct CI-wiring edit; the 3-OS matrix and deterministic lane are otherwise unchanged. |
| Security | REQ-001, REQ-002, REQ-003, REQ-004, REQ-006, REQ-008 | AC-002, AC-009, AC-019, AC-020, AC-023, AC-024, AC-027, AC-035..038, AC-051, AC-052, AC-054 | security-spec.md#trust-boundaries; security-spec.md#stride-analysis | Malformed-registry rejection (B1), protected-file write/read boundary incl. `.github/workflows/test.yml` (B2), CLI-argument-injection resistance (B3), run-record truthfulness + host-independent degradation (B4). |

## Task Mapping

| Task | Requirements | Acceptance Tests | Planned Verification Evidence |
|---|---|---|---|
| T-001 | REQ-001, REQ-009 (share) | TEST-001, TEST-002, TEST-003, TEST-004, TEST-005; TEST-054 (registry-side share, primary owner T-002); TEST-049/TEST-050 shares scoped to this task's own diff and issue #149 | implementation report with acceptance-first evidence, independent quality-gate report, specs/epic-159-pillar-c/verification/T-001/green-sh.log, specs/epic-159-pillar-c/verification/T-001/red-sh.log |
| T-002 | REQ-002, REQ-009 (share) | TEST-006, TEST-007, TEST-008, TEST-009, TEST-010, TEST-011, TEST-012, TEST-013, TEST-053, TEST-054; TEST-049/TEST-050 shares scoped to this task's own diff and issue #150 | implementation report with acceptance-first evidence, independent quality-gate report, specs/epic-159-pillar-c/verification/T-002/green-sh.log, specs/epic-159-pillar-c/verification/T-002/red-sh.log, docs/adr/0012-effort-tier-decoupling.md |
| T-003 | REQ-003, REQ-009 (share) | TEST-014, TEST-015, TEST-016, TEST-017, TEST-018, TEST-019, TEST-020; TEST-049/TEST-050 shares scoped to this task's own diff and issue #151 | implementation report with TDD red/green evidence, independent quality-gate report, specs/epic-159-pillar-c/verification/T-003/green-sh.log, specs/epic-159-pillar-c/verification/T-003/red-sh.log, specs/epic-159-pillar-c/human-copy/MANIFEST.sha256 (5 staged entries) |
| T-004 | REQ-004, REQ-009 (share) | TEST-021, TEST-022, TEST-023, TEST-024, TEST-025, TEST-026, TEST-051; TEST-049/TEST-050 shares scoped to this task's own diff and issue #153 | implementation report with acceptance-first evidence, independent quality-gate report, specs/epic-159-pillar-c/verification/T-004/green-sh.log, specs/epic-159-pillar-c/verification/T-004/red-sh.log |
| T-005 | REQ-005, REQ-009 (share) | TEST-027, TEST-028, TEST-029, TEST-030, TEST-031, TEST-032, TEST-033, TEST-034; TEST-049/TEST-050 shares scoped to this task's own diff and issue #154 | implementation report with TDD red/green evidence, independent quality-gate report, specs/epic-159-pillar-c/verification/T-005/green-sh.log, specs/epic-159-pillar-c/verification/T-005/red-sh.log, specs/epic-159-pillar-c/human-copy/MANIFEST.sha256 (1 new staged entry) |
| T-006 | REQ-006, REQ-008 (share, closing audit), REQ-009 (share) | TEST-035, TEST-036, TEST-037, TEST-038, TEST-039, TEST-040, TEST-052; TEST-047, TEST-048 (REQ-008 closing audit); TEST-049/TEST-050 shares scoped to this task's own diff and issue #152 | implementation report with acceptance-first evidence AND the REQ-008 closing-audit checklist, independent quality-gate report, specs/epic-159-pillar-c/verification/T-006/green-sh.log, specs/epic-159-pillar-c/verification/T-006/red-sh.log |
| T-007 | REQ-007 | TEST-041, TEST-042, TEST-043, TEST-044, TEST-045, TEST-046 | implementation report with TDD red/green evidence, independent quality-gate report, specs/epic-159-pillar-c/verification/T-007/green-sh.log, specs/epic-159-pillar-c/verification/T-007/red-sh.log, the release commit `git merge-base --is-ancestor` output |

## Acceptance Mapping

| Acceptance Criterion | Test ID | Task |
|---|---|---|
| AC-001 | TEST-001 | T-001 |
| AC-002 | TEST-002 | T-001 |
| AC-003 | TEST-003 | T-001 |
| AC-004 | TEST-004 | T-001 |
| AC-005 | TEST-005 | T-001 |
| AC-006 | TEST-006 | T-002 |
| AC-007 | TEST-007 | T-002 |
| AC-008 | TEST-008 | T-002 |
| AC-009 | TEST-009 | T-002 |
| AC-010 | TEST-010 | T-002 |
| AC-011 | TEST-011 | T-002 |
| AC-012 | TEST-012 | T-002 |
| AC-013 | TEST-013 | T-002 |
| AC-014 | TEST-014 | T-003 |
| AC-015 | TEST-015 | T-003 |
| AC-016 | TEST-016 | T-003 |
| AC-017 | TEST-017 | T-003 |
| AC-018 | TEST-018 | T-003 |
| AC-019 | TEST-019 | T-003 |
| AC-020 | TEST-020 | T-003 |
| AC-021 | TEST-021 | T-004 |
| AC-022 | TEST-022 | T-004 |
| AC-023 | TEST-023 | T-004 |
| AC-024 | TEST-024 | T-004 |
| AC-025 | TEST-025 | T-004 |
| AC-026 | TEST-026 | T-004 |
| AC-027 | TEST-027 | T-005 |
| AC-028 | TEST-028 | T-005 |
| AC-029 | TEST-029 | T-005 |
| AC-030 | TEST-030 | T-005 |
| AC-031 | TEST-031 | T-005 |
| AC-032 | TEST-032 | T-005 |
| AC-033 | TEST-033 | T-005 |
| AC-034 | TEST-034 | T-005 |
| AC-035 | TEST-035 | T-006 |
| AC-036 | TEST-036 | T-006 |
| AC-037 | TEST-037 | T-006 |
| AC-038 | TEST-038 | T-006 |
| AC-039 | TEST-039 | T-006 |
| AC-040 | TEST-040 | T-006 |
| AC-041 | TEST-041 | T-007 |
| AC-042 | TEST-042 | T-007 |
| AC-043 | TEST-043 | T-007 |
| AC-044 | TEST-044 | T-007 |
| AC-045 | TEST-045 | T-007 |
| AC-046 | TEST-046 | T-007 |
| AC-047 | TEST-047 | T-006 (REQ-008 closing audit) |
| AC-048 | TEST-048 | T-006 (REQ-008 closing audit) |
| AC-049 | TEST-049 | T-001 (share), T-002 (share), T-003 (share), T-004 (share), T-005 (share), T-006 (share) — each task's own CHANGELOG entry + REQ-009 doc surfaces |
| AC-050 | TEST-050 | T-001 (share), T-002 (share), T-003 (share), T-004 (share), T-005 (share), T-006 (share) — each task's own no-version-bump self-check; T-007 owns the actual separate release execution |
| AC-051 | TEST-051 | T-004 |
| AC-052 | TEST-052 | T-006 |
| AC-053 | TEST-053 | T-002 |
| AC-054 | TEST-054 | T-002 (the rejection behavior is implemented and owned by `select-agent-model.sh`/`.ps1`; T-001's parity suite may share fixtures but does not own the AC) |

## Deliverables (Per Task)

| Task | Issue | New Files | Edited Files |
|---|---|---|---|
| T-001 | #149 | contracts/agent-model-capabilities.v2.json; tests/agent-capabilities-v2.tests.sh; tests/agent-capabilities-v2.tests.ps1 | tests/run-all.sh; tests/run-all.ps1; PLUGIN-CONTRACTS.md; CHANGELOG.md (CREATE #149 entry); specs/epic-159-pillar-c/human-copy/.github/workflows/test.yml (staged); specs/epic-159-pillar-c/human-copy/MANIFEST.sha256 |
| T-002 | #150 | docs/adr/0012-effort-tier-decoupling.md | plugins/sdd-implementation/scripts/select-agent-model.sh; plugins/sdd-implementation/scripts/select-agent-model.ps1; tests/agent-model-routing.tests.sh; CHANGELOG.md (CREATE #150 entry) |
| T-003 | #151 | render-agent-frontmatter.sh; render-agent-frontmatter.ps1; tests/render-agent-frontmatter.tests.sh; tests/render-agent-frontmatter.tests.ps1 | plugins/sdd-quality-loop/agents/evaluator.md and other unprotected role-mapped Claude `.md` agents; .codex/agents/sdd-evaluator.toml; .codex/agents/sdd-investigator.toml; tests/run-all.sh; tests/run-all.ps1; tests/validate-repository.ps1; CHANGELOG.md (CREATE #151 entry); specs/epic-159-pillar-c/human-copy/plugins/sdd-review-loop/agents/{impl,task}-reviewer-{a,b}.md (staged); specs/epic-159-pillar-c/human-copy/.github/workflows/test.yml (staged); specs/epic-159-pillar-c/human-copy/MANIFEST.sha256 |
| T-004 | #153 | (none — all edits to existing files) | plugins/sdd-quality-loop/scripts/emit-run-record.sh; plugins/sdd-quality-loop/scripts/emit-run-record.ps1; plugins/sdd-implementation/templates/implementation-report.template.md; plugins/sdd-implementation/scripts/validate-implementation-report.sh; plugins/sdd-quality-loop/skills/quality-gate/SKILL.md; tests/emit-run-record-feature-scope.tests.sh; tests/emit-run-record-feature-scope.tests.ps1; CHANGELOG.md (CREATE #153 entry) |
| T-005 | #154 | tests/agent-model-routing.tests.ps1 | tests/agent-model-routing.tests.sh; tests/run-all.ps1; CHANGELOG.md (CREATE #154 entry); specs/epic-159-pillar-c/human-copy/.github/workflows/test.yml (staged, appended); specs/epic-159-pillar-c/human-copy/MANIFEST.sha256 |
| T-006 | #152 | tests/run-panelist-effort.tests.sh; tests/run-panelist-effort.tests.ps1 | plugins/sdd-quality-loop/scripts/run-panelist-gpt.sh; plugins/sdd-quality-loop/scripts/run-panelist-gpt.ps1; plugins/sdd-quality-loop/scripts/prepare-panelist-input.sh; plugins/sdd-quality-loop/scripts/prepare-panelist-input.ps1; plugins/sdd-quality-loop/skills/quality-gate/SKILL.md; tests/run-all.sh; tests/run-all.ps1; CHANGELOG.md (CREATE #152 entry); specs/epic-159-pillar-c/human-copy/.github/workflows/test.yml (staged, appended); specs/epic-159-pillar-c/human-copy/MANIFEST.sha256 |
| T-007 | #155 | (none) | plugins/sdd-implementation/scripts/select-agent-model.sh; plugins/sdd-implementation/scripts/select-agent-model.ps1; USERGUIDE.md; docs/agent-capability-matrix.md; CHANGELOG.md (this task's own, separately-released entry); production Claude `.md`/Codex `.toml` agent-definition files (first matrix render) |

## Final Status

Update requirement status only from saved test evidence and quality-gate reports.
Implementation reports are claims, not independent verification evidence.
