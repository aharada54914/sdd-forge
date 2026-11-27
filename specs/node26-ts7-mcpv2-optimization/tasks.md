# タスク（SDD Core）: node26-ts7-mcpv2-optimization

## T-001 Phase 0: Node 26.13+ CI 統一・TS 7.0 基盤・プロファイラ & ベンチマーク整備
Approval: Approved (owner direct instruction 2026-11-28)
Status: Done
Risk: standard

### Scope
- `.github/workflows/test.yml`
- `.github/workflows/release.yml`
- `.github/workflows/sdd-guardrails.yml`
- `tsconfig.json`
- `mcp/sdd-forge-mcp/package.json`
- `mcp/ci-mcp/package.json`
- `mcp/local-env-mcp/package.json`
- `plugins/sdd-quality-loop/scripts/v2/runtime-profile.mjs`
- `scripts/bench-runtime.ts`
- `tests/node26-ts7-optimization.test.mjs`

### Done When
- AC-001, AC-002, AC-003 が自動テストおよび TS 7.0 `tsc --noEmit` で合格する

### Blockers
- None

## T-002 Phase 1: 2 段階ハイブリッド事前生成 Compile Cache & sdd-doctor 強化
Approval: Approved (owner direct instruction 2026-11-28)
Status: Done
Risk: standard

### Scope
- `plugins/sdd-quality-loop/scripts/v2/compile-cache.mjs`
- `plugins/sdd-quality-loop/scripts/v2/sdd-soft-guard.mjs`
- `plugins/sdd-quality-loop/scripts/v2/run-sdd-gate.mjs`
- `plugins/sdd-quality-loop/scripts/v2/sdd-doctor.mjs`
- `plugins/sdd-quality-loop/hooks/claude-hooks.json`
- `plugins/sdd-quality-loop/hooks/codex-hooks.json`
- `install.sh`
- `install.ps1`
- `install-payload.txt`
- `.github/workflows/release.yml`
- `tests/lib/install-payload-check.py`
- `tests/node26-ts7-optimization.test.mjs`

### Done When
- AC-004, AC-005, AC-006 が自動テストおよび `tests/install.tests.sh` で合格する

### Blockers
- T-001

## T-003 Phase 2: 高速プリミティブ・SQLite キャッシュ・ビルドレス TS 集約 & Parity 検証
Approval: Approved (owner direct instruction 2026-11-28)
Status: Done
Risk: standard

### Scope
- `plugins/sdd-quality-loop/scripts/v2/v2-pure-lib.mjs`
- `plugins/sdd-quality-loop/scripts/v2/scan-cache.mjs`
- `plugins/sdd-quality-loop/scripts/v2/run-sdd-gate.mjs`
- `plugins/sdd-quality-loop/scripts/v2/task-lock.mjs`
- `plugins/sdd-quality-loop/scripts/v2/factory-metrics.mjs`
- `.github/scripts/generate-sbom.ts`
- `plugins/sdd-quality-loop/scripts/validate-path.ts`
- `plugins/sdd-quality-loop/scripts/check-contract.ts`
- `plugins/sdd-domain/scripts/validate-concept-test.ts`
- `scripts/render-agent-frontmatter.ts`
- `mcp/shared/diagnostics-core.ts`
- `mcp/ci-mcp/src/diagnostics.ts`
- `tests/node26-ts7-optimization.test.mjs`

### Done When
- AC-007, AC-008, AC-009, AC-010, AC-011, AC-012 が Parity テストおよび既存全回帰テストで合格する

### Blockers
- T-002

## T-004 Phase 3: MCP SDK v2 移行 & 役割別権限プロファイル固定
Approval: Approved (owner direct instruction 2026-11-28)
Status: Done
Risk: high

### Scope
- `mcp/sdd-forge-mcp/package.json`
- `mcp/sdd-forge-mcp/src/server.ts`
- `mcp/sdd-forge-mcp/src/index.ts`
- `mcp/sdd-forge-mcp/src/resources.ts`
- `mcp/sdd-forge-mcp/dist/index.js`
- `mcp/ci-mcp/package.json`
- `mcp/ci-mcp/src/server.ts`
- `mcp/ci-mcp/src/index.ts`
- `mcp/ci-mcp/dist/index.js`
- `plugins/sdd-quality-loop/config/readonly.node.json`
- `plugins/sdd-quality-loop/config/hook.node.json`
- `tests/node26-ts7-optimization.test.mjs`

### Done When
- AC-013, AC-014, AC-015, AC-016 が MCP v2 スイートおよび `--permission` 遮断テストで合格する

### Blockers
- T-003

## Spec Amendments

- （初期版のため変更なし）
