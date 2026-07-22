# Traceability: epic-136-phase3

Every Layer Spec cell contains one or more canonical layer-spec anchors, or a
reasoned cross-layer N/A.

| Requirement | Investigation | Layer Spec | Design | API/Schema | Code Target | Test ID | Test Target | Evidence | Status |
|---|---|---|---|---|---|---|---|---|---|
| REQ-001 | investigation.md INV-001..006, INV-028 (bash 3.2 `set -u` safety this task's own new file follows) | security-spec.md#trust-boundaries (Boundary B1) | design.md#api--contract-plan (`tests/guard-dispatch-fallback.tests.sh` PATH-restricted subshell technique, thin forwarding-shim design decision) | `sdd-hook-guard.sh`'s 5 PATH-availability combinations + 1 precedence combination, each re-run under `--emit exit`/`--emit copilot`; dispatcher-selected decision must equal a direct `.py`/`.ps1` invocation for the identical payload | tests/guard-dispatch-fallback.tests.sh | TEST-001, TEST-002, TEST-003, TEST-004, TEST-005, TEST-006, TEST-007 | tests/guard-dispatch-fallback.tests.sh (drives live `sdd-hook-guard.sh`/`.py`/`.ps1`, read-only) | reports/quality-gate/ for T-001; specs/epic-136-phase3/verification/T-001/ | Planned |
| REQ-002 | investigation.md INV-007..011, INV-031 (`tool_name` shape enumeration, issue #124's own "exec_command / apply_patch 等" wording) | security-spec.md#trust-boundaries (Boundary B1, STRIDE payload-quoting row) | design.md#api--contract-plan (`tests/guard-negative-corpus.tests.sh` 4-runtime x 3-`tool_name`-shape matrix + post-loop parity aggregation) | 3 defect-class corpora (`cd&&rm` reused, triple-quote net-new, task-id-collision net-new) x 4 runtimes x 3 `tool_name` shapes = 36 leaf assertions; a separate cross-runtime decision-parity pass over the same payload set | tests/guard-negative-corpus.tests.sh | TEST-008, TEST-009, TEST-010, TEST-011 | tests/guard-negative-corpus.tests.sh (drives live `sdd-hook-guard.py`/`.js`/`.ps1`/`.sh`, read-only) | reports/quality-gate/ for T-002; specs/epic-136-phase3/verification/T-002/ | Planned |
| REQ-003 | investigation.md INV-012..018 (the 10-class mapping table, INV-017; inbound/outbound distinction, INV-018) | security-spec.md#trust-boundaries (Boundary B2, STRIDE inbound-prompt-injection row) | design.md#api--contract-plan (`tests/workflow-scenarios/` target-shape section, now implemented per T-004's unblock re-check) | `scenario-schema.json`'s `fixture_profile` enum `["greenfield","brownfield"]` (verbatim reuse of `loop-inventory.json:25`); 10 scenario-id fixtures (8 referencing existing coverage, 2 net-new: `refactor-baseline-missing`, `inbound-prompt-injection`); scenario 5 targets the named `sdd-bootstrap-interviewer` entry point's INBOUND direction | tests/workflow-scenarios/scenario-schema.json; tests/workflow-scenarios/*.json; tests/workflow-scenarios/workflow-scenarios.tests.sh | TEST-012, TEST-013, TEST-014, TEST-015 | tests/workflow-scenarios/workflow-scenarios.tests.sh; tests/scenario.tests.sh (cross-reference comment) | reports/quality-gate/ for T-004; specs/epic-136-phase3/verification/T-004/ | Planned |
| REQ-004 | investigation.md INV-019..023 (single `test` job structure, `required-checks` `needs:` membership, zero LLM-invoking steps today) | infra-spec.md#cicd-sequence; security-spec.md#trust-boundaries (Boundary B3, STRIDE two-candidates-collision row) | design.md#api--contract-plan (`.github/workflows/test.yml` step-prefix lane marking, job-count-preserving design decision OQ-5) | every `test`-job step gains a `[deterministic]` name prefix; one documented, currently-empty eval-lane comment placeholder; job count/names and `required-checks: needs: [test, cli-hook-enforcement]` stay byte-unchanged | .github/workflows/test.yml (staged candidate only, `specs/epic-136-phase3/human-copy/`) | TEST-016, TEST-017, TEST-018 | staged `specs/epic-136-phase3/human-copy/.github/workflows/test.yml` + `MANIFEST.sha256`; text-marker self-check reusing `tests/workflow-state-ci-integration.tests.sh`'s technique | reports/quality-gate/ for T-003; specs/epic-136-phase3/verification/T-003/ | Planned |
| REQ-005 | investigation.md INV-006, INV-025 (CI-registration gap for pre-existing guard suites; this feature's own new-suite registration discipline) | infra-spec.md#cicd-sequence | design.md#api--contract-plan; design.md#global-constraints (`tests/run-all.sh`/`.ps1` registration rows; ONE shared `test.yml` batch scope, explicitly excluding Stream C) | every new suite from T-001/T-002 (and T-004 once unblocked) present in `tests/run-all.sh`; a CI step for T-001's and T-002's suites staged in the ONE shared `test.yml` batch (T-003); T-004's own CI-step registration explicitly deferred to a later feature's batch (requirements.md Non-goals) | tests/run-all.sh; .github/workflows/test.yml (staged, T-001/T-002 legs only) | TEST-019, TEST-020 | grep-based self-check (`tests/run-all.sh` presence); staged `test.yml` candidate content (T-003) | reports/quality-gate/ for T-001, T-002, T-003, T-004 | Planned |
| REQ-006 | investigation.md INV-028, INV-030 (bash 3.2 `set -u`/`declare -A` avoidance; epic #136's Done-condition doc-surface list) | N/A — cross-layer only: a cross-cutting shell CI-resilience + CHANGELOG + doc-following convention spanning all 4 tasks' own file edits; no dedicated UX/frontend/infra/security runtime surface of its own beyond what REQ-001..005 already cover | design.md#constraint-compliance (CI-resilience rows: bash 3.2 `set -u` array safety; no new native `.ps1` file this feature, ASCII/BOM/exit-N sub-check reviewed N/A); design.md#global-constraints (four independent `CHANGELOG.md` entries) | every new/changed `.sh` line across T-001/T-002/T-004 avoids `declare -A` and guards empty-array expansion under `set -u`; `CHANGELOG.md` `## Unreleased` gains 4 independent entries (#123 T-001, #124 T-002, #126 T-003, #125 T-004); applicable doc surfaces verified per task, expected answer "none" for all 4; no version-literal edit outside `scripts/bump-version.sh` | all 4 tasks' `.sh` targets; CHANGELOG.md; README.md; USERGUIDE.md; docs/workflow-guide.md; docs/skill-reference.md; docs/agent-capability-matrix.md; PLUGIN-CONTRACTS.md; docs/troubleshooting.md; docs/contributor/* | TEST-021, TEST-022, TEST-023 | each task's own implementation report + grep-based review-time check | reports/quality-gate/ for T-001, T-002, T-003, T-004 | Planned |

## Layer Coverage

| Layer | Applicable Requirements | Acceptance Criteria | Primary Sections | Gaps / Reasoned N/A |
|---|---|---|---|---|
| UX | N/A — no user-facing UI | N/A — CLI/script/CI/scenario-schema work | ux-spec.md#scope-and-user-journeys | No rendered or interactive surface; ux-spec.md records this as N/A. |
| Frontend | N/A — no browser/frontend bundle | N/A — Bash/PowerShell/YAML/JSON-schema only | frontend-spec.md#technology-stack | No frontend surface; frontend-spec.md records this as N/A. |
| Infrastructure | REQ-004, REQ-005 | AC-016, AC-017, AC-018, AC-019, AC-020 | infra-spec.md#cicd-sequence | The ONE shared `test.yml` batch (T-003, carrying T-001's/T-002's CI steps) is staged via human-copy and does not run in the 3-OS matrix until a human maintainer applies it as a pre-merge commit — a designed fail-closed gap (infra-spec.md Deployment / CI Plan precedent). T-004's own CI-step registration is a SEPARATE, deliberately deferred gap (requirements.md Non-goals: Stream C may never author a second batch of this feature's own) — `tests/workflow-scenarios/workflow-scenarios.tests.sh` runs via `tests/run-all.sh` only until a later feature's batch lands it in CI. |
| Security | REQ-001, REQ-002, REQ-003, REQ-004 | AC-001, AC-008, AC-014, AC-016 | security-spec.md#trust-boundaries; security-spec.md#stride-analysis | REQ-005/REQ-006 do not appear in this row — both are cross-cutting registration/CI-resilience/documentation conventions with no trust boundary of their own beyond what REQ-001..004 already establish (mirrors `quality-loop-fixes` traceability.md's identical convention for its own cross-cutting REQ-006/REQ-007 rows). |

## Task Mapping

| Task | Requirements | Acceptance Tests | Planned Verification Evidence |
|---|---|---|---|
| T-001 | REQ-001, REQ-005 (share — AC-019 leg), REQ-006 (share — AC-021/AC-022/AC-023 legs) | TEST-001, TEST-002, TEST-003, TEST-004, TEST-005, TEST-006, TEST-007; TEST-019/TEST-021/TEST-022/TEST-023 legs scoped to this task's files and issue #123 | implementation report with acceptance-first evidence (previously-unobservable-behavior framing, design.md Test Strategy item 1), independent quality-gate report, specs/epic-136-phase3/verification/T-001/ |
| T-002 | REQ-002, REQ-005 (share — AC-019 leg), REQ-006 (share — AC-021/AC-022/AC-023 legs) | TEST-008, TEST-009, TEST-010, TEST-011; TEST-019/TEST-021/TEST-022/TEST-023 legs scoped to this task's files and issue #124 | implementation report with acceptance-first evidence (36-leaf-assertion enumeration, WFI-014 discipline), independent quality-gate report, specs/epic-136-phase3/verification/T-002/ |
| T-003 | REQ-004, REQ-005 (share — AC-019/AC-020, staging T-001's/T-002's CI steps), REQ-006 (share — AC-022/AC-023 legs) | TEST-016, TEST-017, TEST-018, TEST-020; TEST-022/TEST-023 legs scoped to this task's files and issue #126 | implementation report with TDD Red->Green evidence (TEST-017's dropped-step self-check RED/GREEN pair), independent quality-gate report + independent review verdict distinct from the implementing agent (high risk), specs/epic-136-phase3/verification/T-003/ |
| T-004 | REQ-003, REQ-005 (share — AC-019 leg only, AC-020 explicitly deferred), REQ-006 (share — AC-021/AC-022/AC-023 legs) | TEST-012, TEST-013, TEST-014, TEST-015; TEST-019/TEST-021/TEST-022/TEST-023 legs scoped to this task's files and issue #125 | implementation report with TDD Red->Green evidence for the prompt-injection sub-scope (mutated-stub RED, real-target GREEN, AC-014), independent quality-gate report + independent review verdict distinct from the implementing agent (high risk), specs/epic-136-phase3/verification/T-004/ |

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
| AC-012 | TEST-012 | T-004 |
| AC-013 | TEST-013 | T-004 |
| AC-014 | TEST-014 | T-004 |
| AC-015 | TEST-015 | T-004 |
| AC-016 | TEST-016 | T-003 |
| AC-017 | TEST-017 | T-003 |
| AC-018 | TEST-018 | T-003 |
| AC-019 | TEST-019 | T-001, T-002, T-004 (each task's own leg) |
| AC-020 | TEST-020 | T-003 (stages T-001's and T-002's CI steps; T-004's own leg explicitly deferred, requirements.md Non-goals) |
| AC-021 | TEST-021 | T-001, T-002, T-004 (each task's own leg) |
| AC-022 | TEST-022 | T-001, T-002, T-003, T-004 (each task's own leg — four independent CHANGELOG entries, never merged into one) |
| AC-023 | TEST-023 | T-001, T-002, T-003, T-004 (each task's own leg) |

## Deliverables (Per Task)

| Task | Issue | New Files | Edited Files |
|---|---|---|---|
| T-001 | #123 | tests/guard-dispatch-fallback.tests.sh | tests/run-all.sh; CHANGELOG.md (CREATE #123 entry); conditional doc surfaces |
| T-002 | #124 | tests/guard-negative-corpus.tests.sh | tests/run-all.sh; CHANGELOG.md (CREATE #124 entry); conditional doc surfaces |
| T-003 | #126 | specs/epic-136-phase3/human-copy/.github/workflows/test.yml; specs/epic-136-phase3/human-copy/MANIFEST.sha256 | CHANGELOG.md (CREATE #126 entry); .github/workflows/test.yml (HUMAN-applied pre-merge from the staged candidate — never agent-written); conditional doc surfaces |
| T-004 | #125 | tests/workflow-scenarios/scenario-schema.json; tests/workflow-scenarios/greenfield-cli.json; tests/workflow-scenarios/brownfield-web.json; tests/workflow-scenarios/refactor-baseline-missing.json; tests/workflow-scenarios/lite-full-misclassification.json; tests/workflow-scenarios/inbound-prompt-injection.json; tests/workflow-scenarios/mcp-evidence-corruption.json; tests/workflow-scenarios/ci-token-shortage.json; tests/workflow-scenarios/huge-actions-log.json; tests/workflow-scenarios/critical-cross-model-missing.json; tests/workflow-scenarios/unreadable-contract-traceability.json; tests/workflow-scenarios/workflow-scenarios.tests.sh | tests/scenario.tests.sh (cross-reference comment); tests/run-all.sh; CHANGELOG.md (CREATE #125 entry); conditional doc surfaces |

## Final Status

Update requirement status only from saved test evidence and quality-gate reports.
Implementation reports are claims, not independent verification evidence.
