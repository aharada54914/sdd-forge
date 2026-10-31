# Traceability: epic-159-pillar-d

Every Layer Spec cell contains one or more canonical layer-spec anchors, or a
reasoned cross-layer N/A.

| Requirement | Investigation | Layer Spec | Design | API/Schema | Code Target | Test ID | Test Target | Evidence | Status |
|---|---|---|---|---|---|---|---|---|---|
| REQ-001 | investigation.md INV-001, INV-002, INV-012, OQ-005 | N/A — cross-layer only: contributor-process documentation (two Markdown files) with no UX/frontend/infra/security runtime surface of its own; host-neutrality is recorded under REQ-004 (AC-015) and the marker-literal sharing under REQ-002's dedup contract | design.md#api--contract-plan (workflow-detail.md capability-refresh step insertion point + agent-capability-matrix.md trailing columns + assert_literal prefix-compatibility proof); design.md#design-decisions-resolving-open-questions (lifecycle-prose placement, OQ-005) | No new contract; the WFI lifecycle section gains the capability-refresh step (canonical source list verbatim, four check items, D2 connection/manual fallback with the `[model-freshness-divergence]` marker literal stated verbatim); the Provider Tier Mapping table gains trailing 最終確認日/参照ソース columns on all six rows | docs/contributor/workflow-detail.md; docs/agent-capability-matrix.md | TEST-001, TEST-002, TEST-003, TEST-004 | docs/contributor/workflow-detail.md §5; docs/agent-capability-matrix.md Provider Tier Mapping; tests/agent-model-routing.tests.sh (re-run, unedited) | reports/quality-gate/ for T-001; specs/epic-159-pillar-d/verification/T-001/ | Planned |
| REQ-002 | investigation.md INV-003, INV-004, INV-006, INV-008, INV-009, INV-012, INV-013, OQ-001, OQ-004 | security-spec.md#trust-boundaries; security-spec.md#stride-analysis; infra-spec.md#cicd-sequence; infra-spec.md#weekly-schedule; infra-spec.md#external-dependency-fail-soft-handling | design.md#api--contract-plan (model-freshness-check.yml planned shape; check-model-freshness.sh three-function structure; suite test technique steps 1-9); design.md#protected-file-statement (the one protected touch); design.md#constraint-compliance (fail-soft vs. no-bypass rows, CI-resilience rows, issue-body allowlist row) | New workflow contract: weekly `cron` + `workflow_dispatch`, `ubuntu-latest`, `contents: read`/`issues: write` only; script contract: fixture-injectable fetch, pure allowlist-validated (`[A-Za-z0-9.\-]`) divergence over v2 `models[].name`, dedup filing under the stable title markers (`[model-freshness-divergence]` / `[model-freshness-fetch-unavailable]`), fail-soft exit 0 on any fetch failure, no `contracts/` write path, no-bypass on genuine drift | .github/workflows/model-freshness-check.yml; .github/scripts/check-model-freshness.sh; tests/model-freshness-check.tests.sh; tests/model-freshness-check.tests.ps1; tests/run-all.sh; tests/run-all.ps1; specs/epic-159-pillar-d/human-copy/.github/workflows/test.yml (+ MANIFEST.sha256, human-applied pre-merge) | TEST-005, TEST-006, TEST-007, TEST-008, TEST-009, TEST-010, TEST-011, TEST-020, TEST-021 | tests/model-freshness-check.tests.sh; tests/model-freshness-check.tests.ps1; one-time recorded workflow_dispatch run (TEST-008); staged human-copy candidate + MANIFEST.sha256 (TEST-011) | reports/quality-gate/ for T-003; specs/epic-159-pillar-d/verification/T-003/ | Planned |
| REQ-003 | investigation.md INV-005, INV-006, INV-008, INV-013, OQ-001, OQ-004 | security-spec.md#data-classification-and-protection | design.md#data-plan (data-only edit within C1's schema; v1 frozen); design.md#api--contract-plan (v2 data update + adjacent confirmation record placement decision) | No schema change (schema owned by Pillar C's C1/#149); v2 `models[]` data updated to current-generation Anthropic/OpenAI entries with per-model `supported_efforts` and both hosts' `effort_control` paths; confirmation date + reference URLs recorded adjacent; v1 registry byte-for-byte frozen | contracts/agent-model-capabilities.v2.json; adjacent confirmation-date/source record (task-time placement) | TEST-012, TEST-013, TEST-014 | contracts/agent-model-capabilities.v2.json; contracts/agent-model-capabilities.json (hash comparison); tests/agent-capabilities-v2.tests.sh/.ps1 + tests/agent-model-routing.tests.sh (re-run, unedited) | reports/quality-gate/ for T-002; specs/epic-159-pillar-d/verification/T-002/ | Planned |
| REQ-004 | investigation.md INV-007 | infra-spec.md#runtime-dependencies | design.md#constraint-compliance (cross-host row); design.md#api--contract-plan (.ps1 twin native reimplementation, no bash shell-out); design.md#design-decisions-resolving-open-questions (bash-only non-twin decision, self-improvement-pr-guard.sh precedent) | No API change; D1 docs are host-neutral prose (no branch); check-model-freshness.sh is a recorded bash-only non-twin (GitHub-Actions-only runtime); its locking suite IS a full twin pair on the 3-OS matrix; D3 populates BOTH hosts' `effort_control` paths per entry | docs/contributor/workflow-detail.md (host-neutral prose); .github/scripts/ (verified absence of check-model-freshness.ps1); tests/model-freshness-check.tests.sh + .ps1 (twin pair); contracts/agent-model-capabilities.v2.json (both host paths) | TEST-015, TEST-016, TEST-017 | docs/contributor/workflow-detail.md §5; .github/scripts/; tests/run-all.sh/.ps1 registrations; T-002 implementation report (review-time AC-017) | reports/quality-gate/ for T-001, T-002, T-003 | Planned |
| REQ-005 | investigation.md INV-006, INV-011 | N/A — cross-layer only: documentation and versioning duties spanning all three tasks; the affected-document list lives in requirements.md REQ-005 | design.md#constraint-compliance (doc-following + version-bump rows); design.md#global-constraints (three independent CHANGELOG entries, no create-then-append) | No API change; `CHANGELOG.md` `## Unreleased` gains three independent entries (#156 by T-001, #158 by T-002, #157 by T-003); applicable doc surfaces verified per task with edits only where a genuine reference exists; no version-literal edit outside scripts/bump-version.sh | CHANGELOG.md; README.md; USERGUIDE.md; docs/workflow-guide.md; docs/skill-reference.md; docs/agent-capability-matrix.md; PLUGIN-CONTRACTS.md; docs/troubleshooting.md; docs/contributor/* | TEST-018, TEST-019 | CHANGELOG.md `## Unreleased` section; tests/validate-repository.sh; skill-reference count sync | reports/quality-gate/ for T-001, T-002, T-003 | Planned |
| REQ-006 | not a goal of this feature — requirements.md cites epic-159-pillar-a's REQ-006 versioning rule in prose (requirements.md REQ-005 body: "specs/epic-159-pillar-a/requirements.md:164-173 REQ-006's existing rule"), and validate-layer-traceability.py collects every bare REQ-NNN token in requirements.md as a required row | N/A — cross-layer only: prose citation of the sibling feature's rule, carried here solely to satisfy the tokenizer; no task, test, or deliverable of this feature implements it | N/A | N/A | N/A | N/A | N/A | N/A | N/A |

## Layer Coverage

| Layer | Applicable Requirements | Acceptance Criteria | Primary Sections | Gaps / Reasoned N/A |
|---|---|---|---|---|
| UX | N/A — no user-facing UI | N/A — CI/docs/data-wiring work | ux-spec.md#scope-and-user-journeys | No rendered or interactive surface; UX spec records this as N/A. |
| Frontend | N/A — no browser/frontend bundle | N/A — Markdown/Bash/PowerShell/YAML/JSON only | frontend-spec.md#technology-stack | Docs/CI/registry wiring is not a frontend surface. |
| Infrastructure | REQ-002, REQ-004 | AC-005, AC-006, AC-007, AC-008, AC-016, AC-020 | infra-spec.md#cicd-sequence; infra-spec.md#weekly-schedule; infra-spec.md#external-dependency-fail-soft-handling; infra-spec.md#runtime-dependencies | model-freshness-check.yml runs schedule/dispatch-only on `ubuntu-latest` (never the push/PR matrix); the suite twin joins the existing test.yml 3-OS matrix once the human-copied registration is applied as a pre-merge commit on the feature PR branch (AC-011). |
| Security | REQ-002, REQ-003 | AC-005, AC-006, AC-007, AC-009, AC-010, AC-011, AC-013, AC-020, AC-021 | security-spec.md#trust-boundaries; security-spec.md#stride-analysis; security-spec.md#security-tests | External-fetch trust boundary B1 including issue bodies (charset allowlist, AC-021); registry write-boundary B2 (no write path, no unconditional filing — AC-020); protected-file boundary B3 (human-copy, pre-merge application); fixture isolation B4. |

## Task Mapping

| Task | Requirements | Acceptance Tests | Planned Verification Evidence |
|---|---|---|---|
| T-001 | REQ-001, REQ-004 (share), REQ-005 (share) | TEST-001, TEST-002, TEST-003, TEST-004, TEST-015; TEST-018/TEST-019 legs scoped to this task's files and issue #156 | implementation report with test-after evidence (document-conformance checks + TEST-003 suite re-run log), independent quality-gate report, specs/epic-159-pillar-d/verification/T-001/ |
| T-002 | REQ-003, REQ-004 (share), REQ-005 (share) | TEST-012, TEST-013, TEST-014, TEST-017; TEST-018/TEST-019 legs scoped to this task's files and issue #158 | implementation report with acceptance-first evidence (pre-edit registry state + hash pair + post-edit suite re-runs), independent quality-gate report, specs/epic-159-pillar-d/verification/T-002/ |
| T-003 | REQ-002, REQ-004 (share), REQ-005 (share) | TEST-005, TEST-006, TEST-007, TEST-008, TEST-009, TEST-010, TEST-011, TEST-016, TEST-020, TEST-021; TEST-018/TEST-019 legs scoped to this task's files and issue #157 | implementation report with TDD Red→Green evidence (pre-landing red run + post-commit-A green run, TEST-009's live-file half green only after the human-copy pre-merge commit), TEST-008's recorded one-time dispatch, independent quality-gate report, specs/epic-159-pillar-d/verification/T-003/ |

## Acceptance Mapping

| Acceptance Criterion | Test ID | Task |
|---|---|---|
| AC-001 | TEST-001 | T-001 |
| AC-002 | TEST-002 | T-001 |
| AC-003 | TEST-003 | T-001 |
| AC-004 | TEST-004 | T-001 |
| AC-005 | TEST-005 | T-003 |
| AC-006 | TEST-006 | T-003 |
| AC-007 | TEST-007 | T-003 |
| AC-008 | TEST-008 | T-003 (one-time recorded manual dispatch, not CI-repeated) |
| AC-009 | TEST-009 | T-003 (live-file self-check green only after the human-copy pre-merge commit, AC-011) |
| AC-010 | TEST-010 | T-003 |
| AC-011 | TEST-011 | T-003 (staging by agent; application is a HUMAN pre-merge commit on the feature PR branch) |
| AC-012 | TEST-012 | T-002 |
| AC-013 | TEST-013 | T-002 |
| AC-014 | TEST-014 | T-002 |
| AC-015 | TEST-015 | T-001 |
| AC-016 | TEST-016 | T-003 |
| AC-017 | TEST-017 | T-002 |
| AC-018 | TEST-018 | T-001 (#156 entry), T-002 (#158 entry), T-003 (#157 entry) — three independent entries, no shared block |
| AC-019 | TEST-019 | T-001, T-002, T-003 (each task's own verification leg) |
| AC-020 | TEST-020 | T-003 |
| AC-021 | TEST-021 | T-003 |

## Deliverables (Per Task)

| Task | Issue | New Files | Edited Files |
|---|---|---|---|
| T-001 | #156 | none | docs/contributor/workflow-detail.md; docs/agent-capability-matrix.md; CHANGELOG.md (CREATE #156 entry); conditional doc surfaces (verify-only expected) |
| T-002 | #158 | adjacent confirmation-date/source record (task-time placement, e.g. sibling .md note or PLUGIN-CONTRACTS.md addendum) | contracts/agent-model-capabilities.v2.json (data only, once C1 lands); CHANGELOG.md (CREATE #158 entry); conditional doc surfaces (verify-only expected) |
| T-003 | #157 | .github/workflows/model-freshness-check.yml; .github/scripts/check-model-freshness.sh; tests/model-freshness-check.tests.sh; tests/model-freshness-check.tests.ps1; specs/epic-159-pillar-d/human-copy/.github/workflows/test.yml; specs/epic-159-pillar-d/human-copy/MANIFEST.sha256 | tests/run-all.sh; tests/run-all.ps1; CHANGELOG.md (CREATE #157 entry); .github/workflows/test.yml (HUMAN-applied pre-merge commit from the staged candidate — never agent-written); conditional doc surfaces (verify-only expected) |

## Final Status

Update requirement status only from saved test evidence and quality-gate reports.
Implementation reports are claims, not independent verification evidence.
