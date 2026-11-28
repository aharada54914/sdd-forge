# タスク分解（SDD Core）: ssot-unification-v22

- **Feature**: `ssot-unification-v22`
- **ADR**: `docs/adr/0056-ssot-unification-pitfalls-and-test-lifecycle.md`
- **Design**: `specs/ssot-unification-v22/design.md`

## T-001 Phase 1 — 統一同期 CLI `scripts/sync-ssot.mjs` と契約 JSON・文書表の SSOT 化
Approval: Approved
Status: Implementation Complete
Risk: high

### Scope
- `scripts/sync-ssot.mjs`
- `contracts/agent-model-capabilities.v2.json`
- `contracts/agent-model-capabilities.v2.md`
- `contracts/model-policy.v1.json`
- `docs/agent-capability-matrix.md`
- `plugins/sdd-implementation/skills/implement-task/references/agent-delegation-policy.md`
- `plugins/sdd-quality-loop/references/cross-model-verification-policy.md`
- `tests/ssot-unification-v22.test.mjs`

### Done When
- AC-001, AC-002

## T-002 Phase 2 — 8 プラグイン `plugin.manifest.json`・両 `marketplace.json`・全階層エージェントプロンプト SSOT 化
Approval: Approved
Status: Implementation Complete
Risk: high

### Scope
- `plugins/*/plugin.manifest.json`
- `plugins/*/.claude-plugin/plugin.json`
- `plugins/*/.codex-plugin/plugin.json`
- `plugins/*/.plugin/plugin.json`
- `plugins/*/.antigravity-plugin/plugin.json`
- `plugins/*/gemini-extension.json`
- `plugins/*/gemini/gemini-extension.json`
- `.claude-plugin/marketplace.json`
- `.agents/plugins/marketplace.json`
- `.gitattributes`
- `contracts/agents/`
- `.codex/agents/`
- `plugins/*/agents/`
- `plugins/*/copilot-agents/`
- `uninstall.sh`
- `uninstall.ps1`
- `tests/ssot-unification-v22.test.mjs`

### Done When
- AC-003, AC-004, AC-005

## T-003 Phase 3 — `contracts/release-manifest.json`・統一バージョニング・Node 26.13+・CI 強化・規約＆ピットフォール正本化
Approval: Approved
Status: Implementation Complete
Risk: high

### Scope
- `contracts/release-manifest.json`
- `contracts/pitfalls-catalog.json`
- `docs/coding-conventions.md`
- `AGENTS.md`
- `mcp/AGENTS.md`
- `plugins/AGENTS.md`
- `tests/AGENTS.md`
- `docs/contributor/coding-standards/`
- `install.sh`
- `install.ps1`
- `install-payload.txt`
- `scripts/bump-version.sh`
- `mcp/sdd-forge-mcp/package.json`
- `mcp/ci-mcp/package.json`
- `mcp/local-env-mcp/package.json`
- `.github/workflows/test.yml`
- `.github/workflows/release.yml`
- `.github/workflows/sdd-guardrails.yml`
- `CODEOWNERS`
- `tests/ssot-unification-v22.test.mjs`

### Done When
- AC-006, AC-007, AC-008, AC-009

## T-004 Phase 4 — 動的影響範囲チェック（TIA）・安全テスト改廃・ピットフォール自動抽出・ドキュメント自動生成
Approval: Approved
Status: Implementation Complete
Risk: high

### Scope
- `scripts/check-ecosystem-impact.mjs`
- `scripts/harvest-pitfalls.mjs`
- `sdd/approved-test-retirements.json`
- `tests/verification-catalog-status.mjs`
- `docs/operations/verification-catalog-status.md`
- `PLUGIN-CONTRACTS.md`
- `docs/skill-reference.md`
- `tests/ssot-unification-v22.test.mjs`

### Done When
- AC-010, AC-011

## T-005 Phase 5 — 利用者プロジェクト横展開（戦略的 DDD 3 ティア・ピットフォール動的注入・Fitness Function・Compound ステップ）
Approval: Approved
Status: Implementation Complete
Risk: high

### Scope
- `plugins/sdd-bootstrap/scripts/init-project-governance.mjs`
- `plugins/sdd-implementation/scripts/inject-pitfalls.mjs`
- `plugins/sdd-quality-loop/scripts/v2/check-architecture-fitness.mjs`
- `plugins/sdd-review-loop/scripts/compound-pitfalls.mjs`
- `plugins/sdd-bootstrap/skills/bootstrap/SKILL.md`
- `plugins/sdd-implementation/skills/implement-task/SKILL.md`
- `plugins/sdd-quality-loop/skills/sdd-gate/SKILL.md`
- `plugins/sdd-review-loop/skills/spec-check/SKILL.md`
- `plugins/sdd-ship/skills/ship/SKILL.md`
- `tests/ssot-unification-v22.test.mjs`

### Done When
- AC-012

## Spec Amendments

- （初期版のため変更なし）
