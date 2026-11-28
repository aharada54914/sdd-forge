# ADR-0055: Node.js 26.13+・TypeScript 7.0・MCP SDK v2 統合ランタイム最適化

- **Status**: Accepted
- **Date**: 2026-11-28
- **Related**: ADR-0051 (Lightweight Guardrails & SDD Core), ADR-0052 (MCP v2 Consolidation)
- **ADR Number Verification (WFI-013)**: 2026-11-28 時点で `origin/main` の最大番号は `0053-keyless-concept-decisions.md`、オープン中 PR #976（`feat/adr-0054-verification-first`）が `0054` を予約済みであるため、競合しない `0055` を採番する（実装・マージ直前に `docs/adr/` とオープン PR を再確認すること）。

## Context

`sdd-forge` v2.1.5（`origin/main`）の実装・CI・ミドルウェアを棚卸しした結果、以下の 4 つの構造的ボトルネックとバージョン不整合が確認された。

1. **毎ツール呼び出しで冷起動する PreToolUse フック**: `plugins/sdd-quality-loop/hooks/claude-hooks.json`（および `codex-hooks.json` / `copilot-hooks.json` / `gemini/hooks/hooks.json`）はツール呼び出し（`matcher: "*"`）ごとに新規 `node` プロセスで `plugins/sdd-quality-loop/scripts/v2/sdd-soft-guard.mjs` を起動するため、起動レイテンシが開発体験に直結している。
2. **純粋読み取りコアの型境界と CI Node バージョンねじれ**: `plugins/sdd-quality-loop/scripts/v2/v2-readonly-core.mjs`（2,358 行）は `node:fs`・`process.env`・書込 API ゼロの純粋 SSOT コアとして分離済みだが、`.mjs` のため MCP 側 TypeScript との型共有が限定的である。一方、CI（`.github/workflows/test.yml`・`release.yml`・`sdd-guardrails.yml`）と全 `mcp/*/package.json` はすでに EOL 済み（2026-04-30）の Node 20 に留まっている。
3. **TypeScript 7.0 は部分導入、MCP SDK は v1.x 残存**: `mcp/*/package.json` はすでに Go ネイティブ版 `typescript: ^7.0.2` と `zod: ^4.6.5` を採用しているが、リポジトリ共通の TS 7.0 型検査基盤が未整備であり、MCP SDK は `@modelcontextprotocol/sdk@^1.32.2`（v1.x）のまま残っている。また `mcp/shared/sync-diagnostics.py` による複製同期が残存し、非推奨の `local-env-mcp` も未整理である。
4. **Python / PowerShell / Shell ラッパーの重複と起動オーバーヘッド**: `run-sdd-gate.mjs` が Concept Test 実行で Windows 時 `pwsh` / POSIX 時 `sh`（`validate-concept-test.{ps1,sh}`）を呼び出し、さらに個別 `git cat-file blob` を繰り返している。`release.yml` の `generate-sbom.py`、`check-contract.{py,sh,ps1}`、`validate_path.py`、`render-agent-frontmatter.{sh,ps1}`、および `plugins/sdd-quality-loop/scripts/lib/py-dispatch.{sh,ps1}` により非 Node ランタイム依存が分散している。

## Decision

1. **単一必須ランタイムを Node.js 26.13+（Active LTS・EOL 2029-04-30）へ統一し、Rust・外部 DB・Docker・TLC 実行基盤は導入しない。**
   - `.github/workflows/{test,release,sdd-guardrails}.yml` の `actions/setup-node` を `26.13.0` に統一し、`mcp/*/package.json` の `engines.node` を `>=26.13.0` へ引き上げる。
   - ローカル Node 24/25 環境からの段階移行を壊さないため、すべての新 API（`Temporal`・`RegExp.escape`・`crypto.hash`・`node:sqlite`）はフォールバック互換を保ち、`sdd-doctor` が Node 26.13+ 未満を診断通知する。
2. **2 段階ハイブリッド事前生成 Compile Cache を標準化する。**
   - **Stage 1（Release 同梱）**: `release.yml` で基準 Node 26.13.0 により `NODE_COMPILE_CACHE_PORTABLE=1` キャッシュを `.sdd-compile-cache/` に生成し、`install-payload.txt` に含めて配布する。
   - **Stage 2（導入時ステージング生成）**: `install.sh` / `install.ps1` のアトミックスワップ直前のステージング領域で、ユーザー端末の `node` バイナリを用いて主要エントリ（`sdd-soft-guard`・`v2-readonly-core`・`run-sdd-gate`・`render-decision-view`・`sdd-doctor`・`sdd-forge-mcp/dist/index.js`・`ci-mcp/dist/index.js`）を `--warmup` 実行してポータブルキャッシュを生成する（`SDD_SKIP_COMPILE_CACHE=1` で明示スキップ可）。
   - **実行時**: `NODE_COMPILE_CACHE`＋`NODE_COMPILE_CACHE_PORTABLE=1`＋`NODE_COMPILE_CACHE_READONLY=1` でディスク書込ゼロの高速起動を行う。Node 昇格時は `sdd-doctor --rebuild-cache` で再生成する。V8 カバレッジ計測ジョブのみ公式制約に従い `NODE_DISABLE_COMPILE_CACHE=1` を明示指定する。
3. **Go ネイティブ版 TypeScript 7.0（`^7.0.2`）を全リポジトリの型検査基盤へ横展開し、コアとスクリプトをビルドレス erasable `.ts` へ集約する。**
   - ルート `tsconfig.json`（`erasableSyntaxOnly: true`, `noEmit: true`, `strict: true`, `allowImportingTsExtensions: true`, `verbatimModuleSyntax: true`, `module: "NodeNext"`）を追加し、CI で `tsc --noEmit -p tsconfig.json` を必須化する。
   - 2,358 行の純粋 SSOT コアを `plugins/sdd-quality-loop/scripts/v2/v2-readonly-core.ts` へ移行して `mcp/sdd-forge-mcp` と完全型共有する（既存 `.mjs` インポート互換は 1 行の純粋再エクスポートシム `v2-readonly-core.mjs` で保持）。
   - `generate-sbom.ts`・`validate-path.ts`・`check-contract.ts`・`validate-concept-test.ts`・`render-agent-frontmatter.ts` をゼロ依存 erasable `.ts` として実装し、通常運用・リリース CI から Python / `pwsh` 呼び出しを除去する。
   - `v2-pure-lib.mjs` に `crypto.hash()`・`RegExp.escape()`、`run-sdd-gate.mjs` に `fs.promises.glob` 並列スキャン・`node:sqlite` 増分キャッシュ（`.sdd/scan-cache.sqlite`、読取専用時フォールバック）・`AbortSignal.timeout()`・`git status --porcelain=v2 -z` & `git cat-file --batch` 統合・`validate-concept-test.ts` 直接実行、`task-lock.mjs` に `[Symbol.dispose]`（`using` 対応）& `Temporal` 優先ヘルパー、`factory-metrics.mjs` に `node:sqlite` p95 集計エンジンを導入する。
4. **MCP TypeScript SDK v2 へ移行し、役割別 `--config-file` 権限プロファイル適用と旧ラッパー撤去を完了する。**
   - `mcp/sdd-forge-mcp`・`mcp/ci-mcp` を `@modelcontextprotocol/server@^2.4.0` / `@modelcontextprotocol/client@^2.4.0` へ移行し、4 ツール・2 リソースへ MCP 2.0 Cacheable list results（`cacheHints: { ttlMs, cacheScope }`）を付与する。非推奨の `mcp/local-env-mcp` は新規投資対象外として明記する。
   - `mcp/shared/sync-diagnostics.py` および複製された `diagnostics-core.ts` を撤去し、`mcp/ci-mcp`・`mcp/local-env-mcp` から `mcp/shared/diagnostics-core.ts` を直接参照する。
   - 役割別 Node 設定プロファイル `plugins/sdd-quality-loop/config/{readonly,hook}.node.json` を作成し、Node `node.config.json` 仕様に厳密準拠した `nodeOptions`（`permission`, `allow-fs-read`, `allow-fs-write`, `disable-proto`）と CLI フラグ（`--disallow-code-generation-from-strings`, `--env-file-if-exists=.sdd/env`）を組み合わせてフック・`sdd-doctor`・MCP へ適用する。
   - 旧ラッパー（`generate-sbom.py`, `validate_path.py`, `check-contract.{py,sh,ps1}`, `validate-concept-test.{sh,ps1}`, `render-agent-frontmatter.{sh,ps1}`, `sync-diagnostics.py`, `plugins/sdd-quality-loop/scripts/lib/py-dispatch.{sh,ps1}`）を撤去し、関連テストを更新する（歴史的監査ログ `docs/contributor/coding-standards/audit/` 等は保持）。

## Consequences

- **Positive**:
  - 毎ツール実行の PreToolUse フック・CLI・MCP が導入直後から Read-only Portable Compile Cache で高速起動する。
  - `v2-readonly-core.ts` と 5 本のビルドレス `.ts` ツールが Go ネイティブ TS 7.0 で一括型検査され、MCP との完全型共有が成立する。
  - リリース生成・ゲート検証・フック実行から Python / `pwsh` 依存と重複コピー同期が消滅し、権限境界が `--permission` と `--config-file` で宣言的に強制される。
- **Trade-offs / Risks**:
  - Node 24 環境では `--config-file` が `--experimental-config-file` 扱い、`Temporal` が未実装であるため、ランタイムは安全なフォールバックを持ちつつ、Node 26.13.0 の 3 OS GitHub Actions CI で本運用フラグを直接検証する。
  - V8 フラグ `--disallow-code-generation-from-strings` および `--env-file-if-exists` は Node.js `node.config.json` の `nodeOptions` 内で未サポート（終了コード 9 で拒否）であることが実機検証で判明したため、`node.config.json` にはサポート済み `nodeOptions` のみを記述し、上記 2 フラグは CLI 引数として明示併用する。
