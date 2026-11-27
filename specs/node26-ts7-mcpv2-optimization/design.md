# 設計（SDD Core）: node26-ts7-mcpv2-optimization

- **ADR**: `docs/adr/0055-node26-ts7-mcpv2-unified-runtime.md`

## 方針とアーキテクチャ概要

本設計は、`sdd-forge` の既存強み（ゼロ外部ランタイム依存・純粋読み取り SSOT コア）を維持しつつ、4 フェーズでランタイム・型検査・キャッシュ・MCP プロトコル・実行権限境界を一体最適化する。

### 1. 単一ランタイム & TS 7.0 基盤（Phase 0）

- **CI 統一**: `.github/workflows/{test,release,sdd-guardrails}.yml` の `actions/setup-node` を `node-version: "26.13.0"` に統一する。
- **パッケージ統一**: `mcp/{sdd-forge-mcp,ci-mcp,local-env-mcp}/package.json` の `engines.node` を `">=26.13.0"` に更新する。
- **TS 7.0 共通設定**: ルート `tsconfig.json` で `erasableSyntaxOnly: true`, `noEmit: true`, `strict: true`, `allowImportingTsExtensions: true`, `module: "NodeNext"` を定義し、全ビルドレス `.ts` ファイルを Go ネイティブ `tsc` (v7.0.2) で一括型検査する。
- **3 区分プロファイラ & ベンチマーク**:
  - `plugins/sdd-quality-loop/scripts/v2/runtime-profile.mjs`: `node:diagnostics_channel` の 3 チャネル（`sdd-forge:startup`, `sdd-forge:scan`, `sdd-forge:exec`）に軽量タイマーを接続。通常時は `channel.hasSubscribers === false` でオーバーヘッドゼロ。
  - `scripts/bench-runtime.ts`: 冷起動（`NODE_DISABLE_COMPILE_CACHE=1`）vs 温起動（Portable Read-only Cache）、`crypto.hash()` vs `createHash()`、`fs.promises.glob` スキャンを計測。

### 2. 2 段階ハイブリッド事前生成 Compile Cache（Phase 1）

```
[Stage 1: release.yml (Node 26.13.0)]
   compile-cache.mjs --warmup --> .sdd-compile-cache/ (NODE_COMPILE_CACHE_PORTABLE=1)
              |
              v
[Stage 2: install.sh / install.ps1 staging (user's local node)]
   compile-cache.mjs --warmup --> $STAGING/.sdd-compile-cache/
   atomic swap $STAGING -> $INSTALL_ROOT
              |
              v
[Runtime: PreToolUse hook / CLI / MCP]
   NODE_COMPILE_CACHE=<root>/.sdd-compile-cache
   NODE_COMPILE_CACHE_PORTABLE=1
   NODE_COMPILE_CACHE_READONLY=1
   (Coverage job only: NODE_DISABLE_COMPILE_CACHE=1)
```

- `--warmup` 対応エントリ: `sdd-soft-guard.mjs`, `run-sdd-gate.mjs`, `sdd-doctor.mjs`, `mcp/sdd-forge-mcp/src/index.ts`。
- `sdd-doctor.mjs`:
  - `--rebuild-cache [--cache-dir <path>]` で現行 Node 向けキャッシュを再生成。
  - 診断項目に `runtime-node-version`（26.13+ 推奨）、`compile-cache`（`.sdd-compile-cache` 有無・エントリ数）、`git-performance-config`（`core.fsmonitor`, `core.untrackedCache`, `feature.manyFiles`）を追加（既存テストとの互換のため INFO 区分で通知）。

### 3. コア高速化 & ビルドレス `.ts` 集約（Phase 2）

| 対象 | 変更内容 |
|---|---|
| `v2-pure-lib.mjs` | `sha256Text` を `crypto.hash('sha256', ..., 'hex')` へ置換。`escapeRegExp` を `RegExp.escape` 優先実装へ刷新 |
| `task-lock.mjs` | `[Symbol.dispose]()` 付き `acquireTaskLockHandle` 追加（`using` 対応）。TTL/日時演算に `Temporal` 優先ヘルパー導入 |
| `factory-metrics.mjs` | `node:sqlite` (`DatabaseSync`) による SQL ベース p95・集計エンジン `summarizeMetricsWithSqlite` を追加（JSONL 互換維持） |
| `run-sdd-gate.mjs` | `plugins/sdd-quality-loop/scripts/v2/scan-cache.mjs`（`node:sqlite` `.sdd/scan-cache.sqlite`、権限・読取専用環境は自動フォールバック）による未変更ファイル増分スキャンキャッシュ、`fs.promises.glob` 非同期収集、`AbortSignal.timeout()`、`git status --porcelain=v2 -z` ヘルパー統合 |
| `.github/scripts/generate-sbom.ts` | `generate-sbom.py` のゼロ依存 TS 移植。`release.yml` から `node .github/scripts/generate-sbom.ts` で実行 |
| `plugins/sdd-quality-loop/scripts/validate-path.ts` | `validate_path.py` のゼロ依存 TS 移植 |
| `plugins/sdd-quality-loop/scripts/check-contract.ts` | `check-contract.py` のゼロ依存 TS 移植 |
| `plugins/sdd-domain/scripts/validate-concept-test.ts` | Concept Test v2 検証器のゼロ依存 TS 実装（Windows `pwsh` 不要経路） |
| `scripts/render-agent-frontmatter.ts` | `render-agent-frontmatter.sh` のゼロ依存 TS 移植 |
| `mcp/shared/diagnostics-core.ts` & `mcp/ci-mcp` | `RegExp.escape` 採用および `ci-mcp/src/diagnostics.ts` からの直接参照化 |

### 4. MCP TypeScript SDK v2 移行 & 権限プロファイル固定（Phase 3）

- **MCP SDK v2 (`@modelcontextprotocol/server` v2.4.0)**:
  - `mcp/sdd-forge-mcp`: `@modelcontextprotocol/sdk` → `@modelcontextprotocol/server@^2.4.0`（テストは `@modelcontextprotocol/client@^2.4.0`）。`McpServer` / `ResourceTemplate` を `@modelcontextprotocol/server` から、`StdioServerTransport` を `@modelcontextprotocol/server/stdio` からインポート。4 ツール・2 リソースの静的リスト結果に Cacheable list metadata（`ttlMs`, `cacheScope`）を付与。
  - `mcp/ci-mcp`: 同様に `@modelcontextprotocol/server@^2.4.0` へ移行し、`dist/index.js` を再ビルド。
  - `mcp/local-env-mcp`: 非推奨（新規投資対象外）として `package.json` 説明と `README.md` に整理を明記。
- **役割別設定プロファイル（`plugins/sdd-quality-loop/config/`）**:
  - `readonly.node.json`: `sdd-doctor` / `sdd-forge-mcp` 向けの `--permission`, `--allow-fs-read=*`, `--disallow-code-generation-from-strings`, `--disable-proto=throw`, Portable Read-only Compile Cache 設定。
  - `hook.node.json`: `sdd-soft-guard` 向けの `--permission`, `--disallow-code-generation-from-strings`, `--disable-proto=throw` と読取＋`.sdd/drift-events.jsonl` 追記の最小権限プロファイル。

## データ / インターフェース契約

- `contracts/sdd-mcp.v2.schema.json`: 4 ツール・2 リソースの JSON Schema 契約を 100% 維持する（後方互換破壊なし）。
- `install-payload.txt`: `.sdd-compile-cache/`（存在時同梱）および `plugins/sdd-quality-loop/config/`（`plugins/` プレフィックスで自動包含）を含める。
- `tests/lib/install-payload-check.py`: ステージング生成された `.sdd-compile-cache/` を正当なインストール成果物として認識する。

## 採らなかった設計（Alternatives Rejected）

| 候補案 | 不採用理由 | 再検討条件 |
|---|---|---|
| 既存 `.mjs` ファイルをすべて `.ts` にリネームして即時削除 | 既存スキル・外部フック・約 150 件のテストが `.mjs` パスを直接参照しており破壊的影響が大きい | v3.0 メジャーリリースで `.mjs` エントリポイント廃止を事前告知した場合 |
| インストーラーの Node ゲートを即時 `26.13.0` へハードロック | Node 24/25 ローカル環境および既存境界テスト（`v20.0.0`）が即座に停止する | Active LTS 移行猶予期間終了後（次期メジャー版） |
| `node:sqlite` を必須ファイル永続化のみにする | `--permission` 読取専用実行や読取専用 FS でクラッシュする | 実行環境が常に書込可能キャッシュ領域を保証できる場合 |

## 影響範囲・リスク考慮

- `Risk: high` 領域を含む変更（CI ワークフロー、インストーラー、MCP バンドル、セキュリティ境界）。
- ロールバック方針: ブランチ分離＋既存 `.mjs` / Python スクリプトの互換維持により、問題発生時は該当 PR の revert のみで即時復元可能。
- テスト方針: Phase 0〜3 各 AC に対応する自動テスト（TS 7.0 型検査、Compile Cache 命中、Parity テスト、SQLite キャッシュ、MCP SDK v2 契約、Permission Model 遮断テスト、および既存全回帰テスト）を実行して証明する。

## Spec Amendments

- （初期版のため変更なし）
