# タスク分解（SDD Core）: node26-ts7-mcpv2-optimization

- **Feature**: `node26-ts7-mcpv2-optimization`
- **ADR**: `docs/adr/0055-node26-ts7-mcpv2-unified-runtime.md`
- **Design**: `specs/node26-ts7-mcpv2-optimization/design.md`

## T-001 Phase 0 — Node.js 26.13+ CI 統一・TS 7.0 共通設定・3 区分プロファイラ＆ベンチマーク
Approval: Approved
Status: Implementation Complete
Risk: high

### Scope
- `.github/workflows/test.yml`
- `.github/workflows/release.yml`
- `.github/workflows/sdd-guardrails.yml`
- `mcp/sdd-forge-mcp/package.json`
- `mcp/ci-mcp/package.json`
- `mcp/local-env-mcp/package.json`
- `tsconfig.json`
- `plugins/sdd-quality-loop/scripts/v2/runtime-profile.mjs`
- `scripts/bench-runtime.ts`
- `tests/node26-ts7-optimization.test.mjs`

### Done When
- AC-001, AC-002, AC-003, AC-004

## T-002 Phase 1 — 2 段階ハイブリッド Compile Cache・インストーラー統合・`sdd-doctor` 拡張
Approval: Approved
Status: Implementation Complete
Risk: high

### Scope
- `plugins/sdd-quality-loop/scripts/v2/compile-cache.mjs`
- `plugins/sdd-quality-loop/scripts/v2/sdd-soft-guard.mjs`
- `plugins/sdd-quality-loop/scripts/v2/run-sdd-gate.mjs`
- `plugins/sdd-quality-loop/scripts/v2/render-decision-view.mjs`
- `plugins/sdd-quality-loop/scripts/v2/sdd-doctor.mjs`
- `install.sh`
- `install.ps1`
- `install-payload.txt`
- `tests/lib/install-payload-check.py`
- `tests/node26-ts7-optimization.test.mjs`

### Done When
- AC-005, AC-006, AC-007

## T-003 Phase 2A — `v2-readonly-core.ts` 移行と MCP 型共有・高速プリミティブ刷新
Approval: Approved
Status: Implementation Complete
Risk: high

### Scope
- `plugins/sdd-quality-loop/scripts/v2/v2-readonly-core.ts`
- `plugins/sdd-quality-loop/scripts/v2/v2-readonly-core.mjs`
- `plugins/sdd-quality-loop/scripts/v2/v2-pure-lib.mjs`
- `plugins/sdd-quality-loop/scripts/v2/task-lock.mjs`
- `plugins/sdd-quality-loop/scripts/v2/factory-metrics.mjs`
- `plugins/sdd-quality-loop/scripts/v2/scan-cache.mjs`
- `plugins/sdd-quality-loop/scripts/v2/run-sdd-gate.mjs`
- `tests/node26-ts7-optimization.test.mjs`

### Done When
- AC-008, AC-009, AC-010, AC-011, AC-012

## T-004 Phase 2B — 5 本のゼロ依存ビルドレス `.ts` 移植と通常経路切替
Approval: Approved
Status: Implementation Complete
Risk: standard

### Scope
- `.github/scripts/generate-sbom.ts`
- `plugins/sdd-quality-loop/scripts/validate-path.ts`
- `plugins/sdd-quality-loop/scripts/check-contract.ts`
- `plugins/sdd-domain/scripts/validate-concept-test.ts`
- `scripts/render-agent-frontmatter.ts`
- `tests/node26-ts7-optimization.test.mjs`

### Done When
- AC-011, AC-013

## T-005 Phase 3A — MCP SDK v2 移行・`cacheHints`・`diagnostics-core.ts` 直接参照化
Approval: Approved
Status: Implementation Complete
Risk: high

### Scope
- `mcp/shared/diagnostics-core.ts`
- `mcp/sdd-forge-mcp/`
- `mcp/ci-mcp/`
- `mcp/local-env-mcp/`
- `README.md`
- `tests/mcp-diagnostics-sharing.tests.py`
- `tests/node26-ts7-optimization.test.mjs`

### Done When
- AC-014, AC-015

## T-006 Phase 3B — 役割別 `--config-file` 権限プロファイル適用・旧ラッパー撤去・総合検証
Approval: Approved
Status: Implementation Complete
Risk: high

### Scope
- `plugins/sdd-quality-loop/config/readonly.node.json`
- `plugins/sdd-quality-loop/config/hook.node.json`
- `plugins/sdd-quality-loop/hooks/claude-hooks.json`
- `plugins/sdd-quality-loop/hooks/codex-hooks.json`
- `plugins/sdd-quality-loop/hooks/copilot-hooks.json`
- `plugins/sdd-quality-loop/gemini/hooks/hooks.json`
- `plugins/sdd-domain/scripts/finalize-domain-review.sh`
- `plugins/sdd-domain/scripts/finalize-domain-review.ps1`
- `tests/node26-ts7-optimization.test.mjs`
- `tests/mcp-diagnostics-sharing.tests.py`
- `tests/v2-real-flows-e2e.test.mjs`
- `tests/domain-review-finalize.tests.py`
- `tests/concept-test.tests.py`
- `tests/codex-versioned-cache.tests.py`

### Done When
- AC-016, AC-017

## Spec Amendments

- （初期版のため変更なし）
