# 要件定義（SDD Core）: node26-ts7-mcpv2-optimization

- **Feature**: `node26-ts7-mcpv2-optimization`
- **Risk**: `high`（CI ワークフロー、インストーラー、MCP サーバー、セキュリティ権限境界、旧ラッパー撤去を含むため）
- **ADR**: `docs/adr/0055-node26-ts7-mcpv2-unified-runtime.md`
- **Source Specification**: Google ドキュメント「sdd-forge Node.js 26.13+・TypeScript 7.0・MCP SDK v2 統合最適化仕様書」（v2.1.5 / 2026年11月改訂）

## 目的

`sdd-forge` の「ゼロ外部ランタイム依存・純粋読み取り SSOT」という強みを維持・拡大しながら、Node.js 26.13+（Active LTS）・Go ネイティブ版 TypeScript 7.0（`^7.0.2`）・MCP TypeScript SDK v2（MCP 2.0）へ単一基盤化し、初回起動高速化（2 段階ハイブリッド Compile Cache）、ビルドレス `.ts` 集約、高速プリミティブ＆SQLite 増分キャッシュ、および `--permission` / `--config-file` による宣言的権限境界を全層に定着させる。

## 要件一覧

- **REQ-001 (Node.js 26.13+ 単一基準・TS 7.0 型検査・3 区分計測基盤 — Phase 0)**:
  `.github/workflows/{test,release,sdd-guardrails}.yml` および全 `mcp/*/package.json` の Node 基準を `26.13.0` / `>=26.13.0` へ統一する。ルート `tsconfig.json`（`erasableSyntaxOnly: true`, `noEmit: true`, `strict: true`）で Go ネイティブ版 TypeScript 7.0 による全 `.ts` 一括型検査を CI 必須化する。`node:diagnostics_channel` 3 区分プロファイラ（起動・走査・外部コマンド）とベンチマークランナー（`scripts/bench-runtime.ts`、`--bench` 対応）を整備し、カバレッジ計測ジョブのみ `NODE_DISABLE_COMPILE_CACHE=1` で分離する。
- **REQ-002 (2 段階ハイブリッド事前生成 Compile Cache & `sdd-doctor` 診断 — Phase 1)**:
  Stage 1（`release.yml` での基準 Node 26.13.0 ポータブルキャッシュ生成＋`install-payload.txt` 同梱）、Stage 2（`install.sh` / `install.ps1` のアトミックスワップ前ステージング `--warmup` 生成）、実行時（全フックでの `NODE_COMPILE_CACHE`＋`NODE_COMPILE_CACHE_PORTABLE=1`＋`NODE_COMPILE_CACHE_READONLY=1`）を実装する。`sdd-doctor.mjs` に `--rebuild-cache` と、Node 26.13+・Compile Cache 命中・Git 大規模リポジトリ推奨設定（`core.fsmonitor`, `core.untrackedCache`, `feature.manyFiles`）の診断を追加する。
- **REQ-003 (純粋読み取りコアの `.ts` 化と MCP 完全型共有 — Phase 2)**:
  2,358 行の純粋 SSOT コア `v2-readonly-core` を erasable TypeScript（`plugins/sdd-quality-loop/scripts/v2/v2-readonly-core.ts`）へ移行し、`node:fs`・`process.env`・書込 API ゼロの不変条件を維持したまま、ルート TS 7.0 型検査と `mcp/sdd-forge-mcp` からの直接型共有を実現する。
- **REQ-004 (高速プリミティブ・SQLite 増分スキャン・Git 呼び出し統合 — Phase 2)**:
  `v2-pure-lib.mjs` で `crypto.hash()` と `RegExp.escape()` を採用する。`run-sdd-gate.mjs` で並列度制限付き `fs.promises.glob` 非同期スキャン、`.sdd/scan-cache.sqlite`（`node:sqlite`、読取専用時自動フォールバック）による未変更ファイル再スキャンスキップ、`AbortSignal.timeout()`、`git status --porcelain=v2 -z` および `git cat-file --batch` への統合、さらに `validate-concept-test.ts` の Node 直接実行（`pwsh`/`sh` 起動廃止）を実装する。`task-lock.mjs` に `[Symbol.dispose]`（`using` 対応）および `Temporal` 優先 TTL/日時計算、`factory-metrics.mjs` に `node:sqlite` ベース p95 集計を追加する。
- **REQ-005 (5 本のビルドレス `.ts` 集約と通常運用・リリースからの Python / `pwsh` 排除 — Phase 2)**:
  `.github/scripts/generate-sbom.ts`、`plugins/sdd-quality-loop/scripts/validate-path.ts`、`plugins/sdd-quality-loop/scripts/check-contract.ts`、`plugins/sdd-domain/scripts/validate-concept-test.ts`、`scripts/render-agent-frontmatter.ts` をゼロ依存 erasable `.ts` として実装し、機能同等性（Parity）テストを通過させ、`release.yml`・`run-sdd-gate.mjs`・`install-payload.txt` を `.ts` 経路へ切り替える。
- **REQ-006 (MCP TypeScript SDK v2 移行と共有診断の直接参照化 — Phase 3)**:
  `mcp/sdd-forge-mcp` と `mcp/ci-mcp` を `@modelcontextprotocol/server@^2.4.0`・`@modelcontextprotocol/client@^2.4.0` へ移行し、4 ツール・2 リソースに MCP 2.0 Cacheable list results（`cacheHints: { ttlMs, cacheScope }`）を適用して `dist/index.js` を再ビルドする。`mcp/local-env-mcp` は非推奨（新規投資対象外）として整理する。`mcp/shared/sync-diagnostics.py` と複製ファイル（`mcp/{ci-mcp,local-env-mcp}/src/diagnostics-core.ts`）を撤去し、`mcp/shared/diagnostics-core.ts`（`RegExp.escape` 対応）を直接参照する。
- **REQ-007 (役割別 `--config-file` 権限プロファイルの全面適用 — Phase 3)**:
  `plugins/sdd-quality-loop/config/readonly.node.json`（`sdd-doctor` / `sdd-forge-mcp` 向け読取専用）と `hook.node.json`（`sdd-soft-guard` 向け読取＋`.sdd/drift-events.jsonl` 追記のみ）を作成し、Node.js `node.config.json` 実機検証済みスキーマで `--permission`・`--allow-fs-*`・`--disable-proto=throw` を宣言し、CLI 引数で `--disallow-code-generation-from-strings`・`--env-file-if-exists=.sdd/env` を併用してフック・`sdd-doctor`・MCP 登録へ適用する。
- **REQ-008 (旧ラッパーおよび `py-dispatch.{sh,ps1}` の撤去とテスト整合 — Phase 3)**:
  仕様書 Phase 3 に従い、置き換え済みの旧ラッパー（`generate-sbom.py`, `validate_path.py`, `check-contract.{py,sh,ps1}`, `validate-concept-test.{sh,ps1}`, `render-agent-frontmatter.{sh,ps1}`, `sync-diagnostics.py`）および `plugins/sdd-quality-loop/scripts/lib/py-dispatch.{sh,ps1}` を撤去し、関連テストおよび残存ラッパー参照を整合させる（歴史的監査証跡 `docs/contributor/coding-standards/audit/` は改変しない）。

## 受入基準（Acceptance Criteria）

- **AC-001 (REQ-001)**: `.github/workflows/{test,release,sdd-guardrails}.yml` のすべての `node-version` が `"26.13.0"` であり、`mcp/{sdd-forge-mcp,ci-mcp,local-env-mcp}/package.json` の `engines.node` が `">=26.13.0"` である。
- **AC-002 (REQ-001)**: ルート `tsconfig.json` が `erasableSyntaxOnly: true`, `noEmit: true`, `strict: true` を持ち、TS 7.0（`tsc --noEmit -p tsconfig.json`）がエラー 0 件で通過し、`test.yml` に組み込まれている。
- **AC-003 (REQ-001)**: `runtime-profile.mjs` が `sdd-forge:startup` / `sdd-forge:scan` / `sdd-forge:exec` の 3 チャネルで計測イベントを発行し、購読者不在時はオーバーヘッドなく動作する。
- **AC-004 (REQ-001)**: `scripts/bench-runtime.ts` が冷起動・温起動・SHA-256・`fs.promises.glob` を計測し JSON レポートを出力でき、`test.yml` にベンチマークおよび `NODE_DISABLE_COMPILE_CACHE=1` 付きカバレッジ計測ジョブが存在する。
- **AC-005 (REQ-002)**: `compile-cache.mjs --warmup` が主要エントリのポータブルキャッシュを生成し、`release.yml`（Stage 1）と `install.sh` / `install.ps1`（Stage 2）に組み込まれ、`install-payload.txt` に `.sdd-compile-cache/` が記載されている。
- **AC-006 (REQ-002)**: 全 4 ホストのフックマニフェストが `NODE_COMPILE_CACHE`・`NODE_COMPILE_CACHE_PORTABLE=1`・`NODE_COMPILE_CACHE_READONLY=1` を設定し、`sdd-soft-guard.mjs` の初回起動からポータブルキャッシュを参照できる。
- **AC-007 (REQ-002)**: `sdd-doctor.mjs --rebuild-cache` がキャッシュを再生成でき、通常診断で `runtime-node-version`・`compile-cache`・`git-performance-config` を報告し、かつ本リポジトリで `summary.ng === 0` を維持する。
- **AC-008 (REQ-003)**: `plugins/sdd-quality-loop/scripts/v2/v2-readonly-core.ts` が純粋読み取り不変条件（`node:fs`・`process.env`・書込 API ゼロ）を満たしつつ TS 7.0 型検査を通過し、`mcp/sdd-forge-mcp/src/` から直接インポート・型共有されている。
- **AC-009 (REQ-004)**: `v2-pure-lib.mjs` の `sha256Text` が `crypto.hash('sha256', ...)` を、`escapeRegExp` が `RegExp.escape` を使用し、既存ハッシュ・正規表現テストと完全一致する。
- **AC-010 (REQ-004)**: `scan-cache.mjs` が `node:sqlite` により未変更ファイルの増分スキャンスキップを行い、読取専用環境でも安全にフォールバックし、`run-sdd-gate.mjs` が `fs.promises.glob` 並列スキャン・`AbortSignal.timeout()`・`git status --porcelain=v2 -z`・`git cat-file --batch` を使用する。
- **AC-011 (REQ-004)**: `run-sdd-gate.mjs` が Concept Test 検証を `node` で `validate-concept-test.ts` 直接実行し、`pwsh` / `sh` を起動しない。
- **AC-012 (REQ-004)**: `task-lock.mjs` の `acquireTaskLockHandle` が `[Symbol.dispose]()` で決定論的にロック解放し、`Temporal` 優先ヘルパーを持ち、`factory-metrics.mjs` の `summarizeMetricsWithSqlite` が `node:sqlite` で p95・サマリを算出する。
- **AC-013 (REQ-005)**: 5 本の `.ts` スクリプト（`generate-sbom.ts`, `validate-path.ts`, `check-contract.ts`, `validate-concept-test.ts`, `render-agent-frontmatter.ts`）がすべて外部依存ゼロで動作し、期待仕様と厳密一致する（`release.yml` は `node .github/scripts/generate-sbom.ts` を実行する）。
- **AC-014 (REQ-006)**: `mcp/sdd-forge-mcp` と `mcp/ci-mcp` が `@modelcontextprotocol/server@^2.4.0` でビルド・起動・テスト通過し、`sdd-forge-mcp` が 4 ツール・2 リソースに `cacheHints`（`ttlMs`, `cacheScope`）を付与する。`mcp/local-env-mcp` は非推奨と明記される。
- **AC-015 (REQ-006)**: `mcp/shared/sync-diagnostics.py` および複製された `mcp/{ci-mcp,local-env-mcp}/src/diagnostics-core.ts` が撤去され、両パッケージが `mcp/shared/diagnostics-core.ts`（`RegExp.escape` 対応）を直接参照する。
- **AC-016 (REQ-007)**: `plugins/sdd-quality-loop/config/{readonly,hook}.node.json` が Node.js の config-file 検証に実際に合格し（終了コード 0）、`readonly.node.json` では書き込み・子プロセス起動が `ERR_ACCESS_DENIED` で遮断され、`hook.node.json` では `.sdd/drift-events.jsonl` 以外の書き込み・子プロセス起動が遮断され、`claude-hooks.json` / `codex-hooks.json` / `sdd-guardrails.yml` 等へ配線されている。
- **AC-017 (REQ-008)**: 旧ラッパー（`generate-sbom.py`, `validate_path.py`, `check-contract.{py,sh,ps1}`, `validate-concept-test.{sh,ps1}`, `render-agent-frontmatter.{sh,ps1}`, `sync-diagnostics.py`, `py-dispatch.{sh,ps1}`）が撤去され、全 CI テストスイート（`v2-guardrails`, `sdd-forge-mcp`, `ci-mcp`, `local-env-mcp`, `cloud-and-ddd`, `installers`, `node26-ts7-optimization`）が通過する。

## Spec Amendments

- （初期版のため変更なし）
