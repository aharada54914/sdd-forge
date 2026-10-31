# Investigation: epic-159-pillar-d (issues #156-#158)

Source: issues #156-#158 (epic #159, Pillar D). Investigated: 2026-07-16,
read-only survey with file:line evidence (sdd-investigator) against a
main-lineage worktree. Note: statements about "C1 not yet existing" were
true at investigation time; pillar-c (#149-#155) is now in its own SDD
pipeline on feature/epic-159-pillar-c and D2/#157, D3/#158 remain gated
on its T-001 (#149) landing in main.

# Investigation: epic-159 Pillar D (Issues #156-#158)

## INV-001: Issue #156 Scope and Dependencies

**Finding:** Issue #156 adds a "capability refresh" process step to contributor workflow documentation, with Size S and stated dependencies: None.

**Details:**
- **Target files:** `/Users/jrmag/Projects/active/sdd-forge-wt-pillar-c/docs/contributor/workflow-detail.md` (lines 1-728, workflow exception flows and process guide), `/Users/jrmag/Projects/active/sdd-forge-wt-pillar-c/docs/agent-capability-matrix.md` (agent roles and capabilities matrix)
- **Changes:** Add "capability refresh" step to workflow document with references to official Anthropic/OpenAI docs as canonical sources; add "final confirmation date + reference sources" column to agent capability matrix
- **Shared Done conditions apply:** CHANGELOG.md entry, documentation followup (README/USERGUIDE/docs/workflow-guide/skill-reference/agent-capability-matrix/PLUGIN-CONTRACTS/troubleshooting/contributor), version bump via `scripts/bump-version.sh`
- **Protected file status:** Neither file is in `_PROTECTED_GATE_SUFFIXES` (/Users/jrmag/Projects/active/sdd-forge-wt-pillar-c/plugins/sdd-quality-loop/scripts/sdd-hook-guard.py:886-927) — normal documentation files
- **Test integration:** run-all.sh tests (line 7-51) do not show specific documentation validation tests, but `validate-repository` tests exist

**Evidence:** #156 issue body describes "contributor プロセスに追加" with Done conditions stating documentation checklist entry requirement.

---

## INV-002: Issue #156 Does Not Depend on Pillar C or Parallel Sessions

**Finding:** Issue #156 has zero external dependencies and is orthogonal to epic-136 Phase 1-4 (completed PR #168 and ongoing Phase 2+) and to Pillar C.

**Details:** The issue explicitly states `サイズ / 依存` = `S / なし` (Size S / dependencies: none). It is purely a documentation and workflow process change with no registry/contract dependencies.

**Evidence:** #156 issue body line stating "サイズ / 依存 = S / なし"

---

## INV-003: Issue #157 Depends on C1 (v2 Registry) and D1 (Process Docs)

**Finding:** Issue #157 requires issue #149 (Pillar C1, v2 registry creation) to complete first, and additionally depends on #156 (D1, process documentation for "capability refresh" that underpins the automation).

**Details:**
- **Declared dependency:** Issue #157 states `サイズ / 依存 = M / C1（v2 レジストリ）, D1（プロセス文書との整合）`
- **Current state:** `/Users/jrmag/Projects/active/sdd-forge-wt-pillar-c/contracts/agent-model-capabilities.v2.json` does not exist (only v1 exists at contracts/agent-model-capabilities.json:1-40, lines 1-40)
- **Impact:** #157 workflow extension cannot reference `contracts/agent-model-capabilities.v2.json` until C1 creates it
- **Target files:** `.github/workflows/self-improvement.yml` (lines 1-229, existing weekly workflow), new script for diff/automation

**Evidence:** #157 issue body "self-improvement.yml 拡張または新規 workflow（週次 cron）" and dependency statement "M / C1（v2 レジストリ）, D1（プロセス文書との整合）"

---

## INV-004: Issue #157 Target File Is Protected by self-improvement-pr-guard

**Finding:** `.github/workflows/self-improvement.yml` is protected by the `self-improvement-pr-guard.sh` enforcement chain, which blocks modifications during weekly self-improvement automation.

**Details:**
- **Protection rule:** `/Users/jrmag/Projects/active/sdd-forge-wt-pillar-c/.github/scripts/self-improvement-pr-guard.sh:34` includes `case` pattern `.github/workflows/*) return 0` — this marks any `.github/workflows/` change as an enforcement-chain violation
- **Consequence:** The weekly `self-improvement.yml` workflow (line 113) cannot self-modify to add freshness checking. Changes must be made via normal PR flow, not via weekly sessions
- **Cross-protection note:** Unlike `sdd-hook-guard.py` (plugins/*/ focus), `self-improvement-pr-guard.sh` (line 34) protects all GitHub workflows as "enforcement surfaces" (line 19-20 comment)

**Evidence:** `/Users/jrmag/Projects/active/sdd-forge-wt-pillar-c/.github/scripts/self-improvement-pr-guard.sh:34`

---

## INV-005: Issue #158 Depends on C1 (v2 Registry Creation)

**Finding:** Issue #158 updates model entries in the v2 registry but the registry structure does not yet exist. C1 (issue #149) must complete first.

**Details:**
- **Declared scope:** #158 states `実装内容` = update v2 registry with current Anthropic/OpenAI model generations (Claude 5 aliases, gpt-5.4/5.5/5.6 systems)
- **Current state:** No `contracts/agent-model-capabilities.v2.json` file exists in the worktree
- **Pillar C baseline:** Issue #149 (C1) creates `contracts/agent-model-capabilities.v2.json` with schema `agent-model-capabilities/v2`, including `supported_efforts` (plural), `default_effort`, `effort_control`, `risk_effort_matrix`, and `role_defaults` — matching current generation model IDs
- **Sequence:** C1 creates v2 structure → D3 (#158) populates current model data (Claude 5, gpt-5.4+) → Optional: D2 (#157) automates freshness checking against D3's curated list

**Evidence:** #158 issue body "v2 レジストリを更新: OpenAI 現行世代（5.4/5.5/5.6 系）, Anthropic 現行世代（Claude 5 系のエイリアス方針含む）" and C1 issue #149 stating "contracts/agent-model-capabilities.v2.json（schema `agent-model-capabilities/v2`）新設"

---

## INV-006: Shared Done Conditions Across All Three Pillar D Issues

**Finding:** All three Pillar D issues (#156, #157, #158) declare identical shared Done conditions for documentation followup and version bumping, appended on 2026-07-10.

**Details:**
- **Documentation followup:** Modifications affecting "仕様・挙動・コマンド・契約スキーマ・エージェント定義" must update (in same PR): README.md, USERGUIDE.md, docs/workflow-guide.md, docs/skill-reference.md, docs/agent-capability-matrix.md, PLUGIN-CONTRACTS.md, docs/troubleshooting.md, docs/contributor/* — and CHANGELOG.md `## Unreleased` section with issue number
- **Version bump workflow:** Manual CHANGELOG heading rename (`## Unreleased` → `## vX.Y.Z (YYYY-MM-DD)`) required before running `scripts/bump-version.sh` (fails if heading absent, lines 38-42)
- **Validation:** `validate-repository` and skill-reference count sync must pass
- **Semver guidance:** patch for fix/test-only, minor for behavior-changing feat

**Evidence:** #156 body (line "## ドキュメント追従・バージョン改訂"), #157 body (identical section), #158 body (identical section)

---

## INV-007: Cross-Host Validation Requirement for All Issues

**Finding:** All three issues declare a "クロスホスト要件" (cross-host requirement) ensuring both Claude Code and Codex hosts can use the feature; degradation must be explicit and recorded.

**Details:**
- **Host matrix:** Claude Code (plugin/frontmatter pathway) + Codex (.codex-plugin manifest + .codex/agents/*.toml + CLI --model/--effort)
- **Degradation:** Non-supported features must fail gracefully with recorded evidence, not silently behave differently
- **Test inclusion:** Done conditions include "両ホストでの検証" (validation on both hosts)
- **Implication for #156:** Workflow docs must address model selection for both hosts
- **Implication for #157:** Automation must reference both host pathways for model configuration
- **Implication for #158:** Registry must cover both host's CLI routing assumptions

**Evidence:** #156/#157/#158 all include identical "クロスホスト要件: Claude Code と Codex の両ホストで本機能が利用可能であること" section.

---

## INV-008: Test Integration Requirements — run-all.sh and Parity Constraints

**Finding:** All issues require passing `bash tests/run-all.sh` and `pwsh tests/run-all.ps1` with three OS environments (ubuntu-latest, macos-latest, windows-latest per `.github/workflows/test.yml`). Parity constraints (crlf-parity, constant-parity) are mandatory for new scripts.

**Details:**
- **Test list:** `/Users/jrmag/Projects/active/sdd-forge-wt-pillar-c/tests/run-all.sh:8-51` enumerates 42 POSIX test files, plus PowerShell guard-parity test (line 60-65 conditionally if pwsh available)
- **Parity enforcement:** Line 14 shows `tests/crlf-parity.tests.sh` is mandatory; constant-parity test not shown but referenced in shared Done conditions as enforcement
- **Script requirements:** Any new/modified .sh or .ps1 must have both forms with CRLF/constant parity
- **Implication for #156:** Documentation-only, no test script changes needed
- **Implication for #157:** New workflow script must be .sh/.ps1 pair; crlf-parity + constant-parity required
- **Implication for #158:** JSON data update, no test scripts; but any v2 registry tests (mentioned in C1 as `tests/agent-capabilities-v2.tests.sh/.ps1`) must pass

**Evidence:** `/Users/jrmag/Projects/active/sdd-forge-wt-pillar-c/tests/run-all.sh:8-51` and `.github/workflows/test.yml` reference to `ubuntu-latest, macos-latest, windows-latest` (CI 3 OS)

---

## INV-009: Issue #157 Automation Must Handle CI-Resilience (External Dependencies)

**Finding:** Issue #157's model freshness check must implement fail-closed safety for external API/documentation access and not break CI when external sources are unavailable.

**Details:**
- **Issue statement:** "取得失敗時は fail ではなく「取得不能」を issue コメント（外部依存で CI を壊さない）" — automation must log "fetch unavailable" to issue comment rather than fail the CI job
- **Implementation location:** `.github/workflows/self-improvement.yml:1-229` shows existing error-handling pattern; lines 204-228 show failure-issue reporting mechanism that #157 can extend
- **Cross-model resilience precedent:** Issue #157 references epic-159's overall plan "シナリオ検証基盤 / effort 自動選択 / モデル鮮度維持" which epic-136 phase-1 (PR #168) demonstrated via `prepare-panelist-input.py` (read-only, sanitization) and vendor-slot subagent resilience (memory: "外部 CLI 不可→vendor-slot subagent 3体")

**Evidence:** #157 issue body "取得失敗時は fail ではなく「取得不能」を issue コメント"

---

## INV-010: No Direct File Collision with Parallel Sessions (epic-136 Phase 2+)

**Finding:** epic-136 Phase 1 is complete (PR #168 merged 2026-07-14). No direct file collision risk with Pillar D is visible, as Pillar D targets documentation/process/CI metadata, not core guard/ship/loop logic.

**Details:**
- **Phase 1 status:** Memory indicates all tasks Done, QG passed, retrospective complete, PR #168 merged
- **Phase 2+ scope:** Memory mentions "Phase 2 は並行セッションの別エージェント担当中" but provides no detail; issues #117-#133 range may involve parallel work
- **Collision surface:** Pillar D files are non-overlapping (docs/contributor/, docs/agent-capability-matrix.md, .github/workflows/self-improvement.yml, contracts/v2 registry) versus Phase 1's guard/ship SKILL.md, hook-guard scripts, and phase-1 tests
- **Assumption:** If Phase 2+ modifies core loop/guard files, those changes would be isolated to feature branches; Pillar D's PR can target main

**Evidence:** Memory: "epic-136-phase1-guards bootstrap... PR #168 マージ済(2026-07-14)" and "phase-2 は並行セッションの別エージェント担当中"

---

## INV-011: Version Numbering Rationale (Semver)

**Finding:** CHANGELOG.md follows semantic versioning (patch for fix/test, minor for behavior-changing feat). Pillar D issues likely trigger minor bumps due to feature-level process/automation additions.

**Details:**
- **Current version:** Scripts/bump-version.sh derives OLD version from `tests/validate-repository.ps1` (line 26)
- **Latest version in CHANGELOG.md:** v1.10.0 (2026-07-09)
- **Issue categories:** #156 is labeled `documentation`+`workflow-improvement`; #157 is `enhancement`+`workflow-improvement`; #158 is `enhancement`
- **Semver implication:** #156 (doc+process) = patch-worthy; #157/#158 (behavior features) = minor-worthy
- **Manual gate:** bump-version.sh line 38-41 enforces CHANGELOG heading must pre-exist (fail-closed if renamed after version bump)

**Evidence:** `/Users/jrmag/Projects/active/sdd-forge-wt-pillar-c/scripts/bump-version.sh:38-41` and CHANGELOG.md version progression

---

## INV-012: No Protected File Issues for #156 and #158, Workflow-Protected for #157

**Finding:** File protection analysis shows #156 and #158 are unprotected (normal docs/data), but #157 modifies a workflow protected by both hooks and self-improvement guard.

**Details:**
- **#156 targets:** docs/contributor/workflow-detail.md, docs/agent-capability-matrix.md — not in `_PROTECTED_GATE_SUFFIXES` (/Users/jrmag/Projects/active/sdd-forge-wt-pillar-c/plugins/sdd-quality-loop/scripts/sdd-hook-guard.py:886-927)
- **#158 targets:** contracts/agent-model-capabilities.v2.json — not protected (data file, not scripts/configs/tests/skills)
- **#157 targets:** .github/workflows/self-improvement.yml — protected by `/Users/jrmag/Projects/active/sdd-forge-wt-pillar-c/.github/scripts/self-improvement-pr-guard.sh:34` pattern `.github/workflows/*`; cannot be self-modified during weekly runs

**Evidence:** 
- Hook guard protected list: `/Users/jrmag/Projects/active/sdd-forge-wt-pillar-c/plugins/sdd-quality-loop/scripts/sdd-hook-guard.py:886-927` (no docs/ or contracts/ entries for v1 registry)
- Self-improvement guard: `/Users/jrmag/Projects/active/sdd-forge-wt-pillar-c/.github/scripts/self-improvement-pr-guard.sh:34`

---

## INV-013: Pillar C (C1 Issue #149) Prerequisite Status

**Finding:** Pillar C C1 (issue #149) is a Pillar D prerequisite for both #157 and #158, but its completion status is unknown in current worktree; the v2 registry file does not yet exist.

**Details:**
- **C1 role:** Creates `contracts/agent-model-capabilities.v2.json` with schema supporting multiple efforts per model, effort control flags, risk-to-effort matrix, and role defaults (issue #149 description)
- **C1 parity test:** Issue #149 mentions `tests/agent-capabilities-v2.tests.sh/.ps1` parity validation (v1→v2 all models present, canonical_tier match, supported_efforts superset)
- **Current state:** Only v1 exists at `/Users/jrmag/Projects/active/sdd-forge-wt-pillar-c/contracts/agent-model-capabilities.json:1-40` with hardcoded 1:1 model-effort mapping (haiku=low, sonnet=medium, opus=high)
- **Blocking D2/D3:** #157 automation needs v2 structure to query; #158 needs v2 structure to populate

**Evidence:** 
- Issue #149 body "feat(contracts): agent-model-capabilities v2"
- Absence of v2 file at `/Users/jrmag/Projects/active/sdd-forge-wt-pillar-c/contracts/agent-model-capabilities.v2.json`
- v1 file exists at `/Users/jrmag/Projects/active/sdd-forge-wt-pillar-c/contracts/agent-model-capabilities.json:1-40` with hardcoded tier-effort bindings

---

## OQ-001: Pillar C (C1-C3) Completion Status and Timeline

**Question:** Is Pillar C (C1 issue #149, and subsequent C2/C3 issues) already complete, in-progress, or blocked? Are there open PRs or branches?

**Implication:** D2 (#157) and D3 (#158) both depend on C1. If C1 is incomplete, Pillar D cannot proceed until C1 ships.

**Recommendation:** Query `gh pr list --repo aharada54914/sdd-forge --search "149" --state open` and check if issue #149 (and follow-on C2/C3) have associated open PRs or branch status.

---

## OQ-002: Epic-136 Phase 2-4 Scope and File Overlap

**Question:** What are the specific issues and files targeted by epic-136 Phase 2, Phase 3, and Phase 4? Do they modify any of docs/contributor/, docs/agent-capability-matrix.md, .github/workflows/self-improvement.yml, or contracts/ ?

**Implication:** Determines risk of merge-time conflicts or parallel-session file collisions with Pillar D.

**Recommendation:** Query `gh issue list --repo aharada54914/sdd-forge --search "epic-136" --state open` to identify Phase 2+ issues, then inspect those issue bodies for file targets.

---

## OQ-003: Pillar D Task Breakdown Granularity

**Question:** Should Pillar D be executed as three separate PRs (#156, #157, #158 independently) or as a single feature branch/PR encompassing all three?

**Implication:** 
- Three separate PRs: allows parallel approval/merging, reduces context per PR, aligns with issue-per-task model
- Single PR: reduces CI runs, ensures consistent version bump, but larger review surface

**Recommendation:** Check existing epic-159-pillar-a/b/c PR structure (memory mentions "PR #175 レビュー待ち" for pillar-a; determine if pillar-b/c used same pattern). Align Pillar D accordingly.

---

## OQ-004: Effort-Routing v2 Relationship to Pillar D

**Question:** Issue #157 references "effort ルーティング v2" and issue #149 (C1) creates effort-control fields in the v2 registry. Are #157's freshness automation and #158's registry updates the *implementation* of effort-routing v2, or are they preparatory?

**Implication:** Determines scope of #157/#158 relative to C1's registry schema design.

**Recommendation:** Review issue #149 (C1) and related ADR/spec docs to understand if effort-routing v2 is complete after C1 or requires D2/D3 as well.

---

## OQ-005: Canonical Sources and Refresh Intervals for #156

**Question:** Issue #156 specifies "正典ソースの明示リスト: Anthropic 公式 docs（models overview）/ Anthropic blog、OpenAI developers docs（Codex）/ OpenAI blog、各 CLI（Claude Code / Codex CLI / Copilot CLI）のリリースノート". Is a specific refresh cycle or automation expected (weekly, monthly, per-release), or is the "capability refresh" step manual?

**Implication:** 
- If manual: #156 workflow docs only; no CI automation needed
- If automatic: #156 may feed into #157's freshness checking

**Recommendation:** Review #156 Done condition "WFI テンプレートのチェックリストに項目が入る" to clarify scope (manual checklist vs. automation).

---

## Task Breakdown and Dependency Graph

### Sequential Order (Critical Path)

1. **C1 (issue #149 - Pillar C):** Create `contracts/agent-model-capabilities.v2.json` with v2 schema, parity tests → blocks D2, D3
2. **D1 (issue #156 - Pillar D):** Add "capability refresh" to contributor docs (independent, no blockers except maybe C1's docs updates)
3. **D2 (issue #157 - Pillar D):** Add freshness checking workflow → depends on C1 (registry structure), D1 (process docs)
4. **D3 (issue #158 - Pillar D):** Populate v2 registry with current models → depends on C1 (schema)

### Parallelism Opportunities

- **D1 + C1:** Can proceed in parallel (independent changes)
- **D2 + D3:** Both depend on C1 but can work in parallel once C1 is done (D2 writes workflow, D3 writes data)

### Risk-Ordered Execution

**High-risk-first variant:**
1. C1 (registry schema) — foundational, unblocks D2/D3
2. D2 (freshness automation) — highest integration complexity (protected file, external API, CI-resilience)
3. D3 (registry population) — highest domain complexity (curating model data, version mappings)
4. D1 (docs) — lowest risk, can be done last to incorporate learnings from D2/D3

---

## Size and Effort Estimation Summary

| Issue | Pillar | Category | Size | Depends On | Risk | File Count | Test Impact |
|-------|--------|----------|------|-----------|------|------------|------------|
| #156  | D1     | docs     | S    | None      | Low  | 2 (docs)   | No new tests, validate-repo applies |
| #157  | D2     | ci(feat) | M    | C1, D1    | High | 3-4 (workflow + script + tests) | New tests required (crlf-parity, constant-parity, workflow logic) |
| #158  | D3     | chore    | S    | C1        | Medium | 1 (v2.json) | New v2 parity tests (from C1), data validation |

---

## Cross-Pillar Ordering Decision

**Recommended sequence for Pillar D:**
1. **Await C1 completion** (issue #149) if not already done
2. **Implement D1 (#156)** in parallel or immediately after C1, since it is independent and low-risk
3. **Implement D3 (#158)** once C1 is done (data curation can proceed in parallel with D2 workflow)
4. **Implement D2 (#157)** last, since it integrates both D1 (process docs) and C1 (registry) and has highest complexity/risk

**Justification:** D1 is independent and de-risks D2 by establishing process (enables D2 automation to reference). D3 is pure data curation (minimal risk once C1 schema exists). D2 is highest-risk integrator.

---

## Final Assessment

Pillar D is a three-issue feature set addressing model-freshness process automation and documentation. All three depend on Pillar C's v2 registry creation. None conflict with epic-136 or existing code; protected-file status requires PR flow for #157. Shared test/doc/versioning requirements apply uniformly. Recommended blockage: Await C1; then sequence D1 → D3 || D2 in parallel.
