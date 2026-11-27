# 要件（SDD Core）: node26-ts7-mcpv2-optimization

- **出典**: `sdd-forge Node.js 26.13+・TS 7.0・MCP SDK v2 統合最適化仕様書.md` / `docs/adr/0055-node26-ts7-mcpv2-unified-runtime.md`
- **目的**: `sdd-forge` のランタイム基盤を Node.js 26.13+・TypeScript 7.0・MCP TypeScript SDK v2 へ統合最適化し、PreToolUse フックの初回起動高速化・ゼロ依存ビルドレス `.ts` 化・最小権限境界の機械固定を実現する。

## 要件（Requirements）

- **REQ-001**: CI ワークフロー（`test.yml`, `release.yml`, `sdd-guardrails.yml`）および MCP パッケージの Node 基準を `26.13.0` / `>=26.13.0` へ統一し、リポジトリ共通の TypeScript 7.0（`erasableSyntaxOnly: true`, `noEmit: true`）型検査基盤と `node:diagnostics_channel` 3 区分プロファイラ・ベンチマークランナーを整備すること。
- **REQ-002**: Release 同梱キャッシュ＋導入時ステージング `--warmup`＋実行時 Read-only Portable Cache の 2 段階ハイブリッド事前生成 Compile Cache を実装し、`sdd-doctor` にキャッシュ・Node 26.13+・大規模リポジトリ向け Git 推奨設定の診断および `--rebuild-cache` を追加すること。
- **REQ-003**: コアライブラリ（`v2-pure-lib.mjs`）・品質ゲート（`run-sdd-gate.mjs`）・ロック（`task-lock.mjs`）・メトリクス（`factory-metrics.mjs`）に `crypto.hash()`, `RegExp.escape()`, `fs.promises.glob`, `node:sqlite` 増分スキャンキャッシュ, `AbortSignal.timeout()`, `using` (`[Symbol.dispose]`), `Temporal` 優先演算を適用すること。
- **REQ-004**: `generate-sbom.py`, `validate_path.py`, `check-contract.py`, `validate-concept-test.{sh,ps1,py}`, `render-agent-frontmatter.{sh,ps1}` をゼロ依存・ビルドレスの erasable `.ts` へ移植し、旧実装との Parity テストを通過させること。また `mcp/shared/diagnostics-core.ts` を直接参照し `sync-diagnostics.py` 依存を削減すること。
- **REQ-005**: `mcp/sdd-forge-mcp` および `mcp/ci-mcp` を MCP TypeScript SDK v2（`@modelcontextprotocol/server` v2.4.0）へ移行し、4 ツール／5 ツールおよびリソースの契約・キャッシュメタデータ互換を維持したままビルド・テストを通過させ、非推奨 `local-env-mcp` を整理すること。
- **REQ-006**: 役割別 Node 設定プロファイル（`readonly.node.json`, `hook.node.json`）で `--permission`, `--disallow-code-generation-from-strings`, `--disable-proto=throw` を宣言し、読取専用コンポーネントの書込・子プロセス起動・コード評価・プロトタイプ汚染遮断を自動テストで検証すること。

## 受入条件（Acceptance Criteria）

- **AC-001** (REQ-001): `test.yml`, `release.yml`, `sdd-guardrails.yml` のすべての `node-version` が `26.13.0` であり、MCP パッケージ `engines.node` が `>=26.13.0` であること。
- **AC-002** (REQ-001): ルート `tsconfig.json` が `erasableSyntaxOnly: true` と `noEmit: true` を持ち、TS 7.0 `tsc --noEmit -p tsconfig.json` がエラー 0 で完了すること。
- **AC-003** (REQ-001): `runtime-profile.mjs` が `sdd-forge:startup` / `sdd-forge:scan` / `sdd-forge:exec` の 3 区分 `diagnostics_channel` を計測でき、`scripts/bench-runtime.ts` が冷起動・温起動・ハッシュ・スキャンのベンチマーク JSON を出力すること。
- **AC-004** (REQ-002): `sdd-soft-guard.mjs`, `run-sdd-gate.mjs`, `sdd-doctor.mjs`, `sdd-forge-mcp/dist/index.js` が `--warmup` で副作用ゼロのまま終了 0 し、`compile-cache.mjs` が `NODE_COMPILE_CACHE_PORTABLE=1` で `.sdd-compile-cache/` にキャッシュを生成できること。
- **AC-005** (REQ-002): `install.sh` / `install.ps1` のステージング工程で `.sdd-compile-cache/` が事前生成され、`install-payload.txt` および `release.yml` が `.sdd-compile-cache/` を扱い、フック設定が Read-only Portable Cache 環境変数を含むこと。
- **AC-006** (REQ-002): `sdd-doctor.mjs` が Node 26.13+ 基準・Compile Cache 状態・Git 推奨設定（`core.fsmonitor`, `core.untrackedCache`, `feature.manyFiles`）を診断し、`--rebuild-cache` でキャッシュを再生成できること。
- **AC-007** (REQ-003): `v2-pure-lib.mjs` が `crypto.hash('sha256', ...)` と `RegExp.escape()` を利用し、既存の全 SHA-256・glob テストが 100% 合格すること。
- **AC-008** (REQ-003): `run-sdd-gate.mjs` が `.sdd/scan-cache.sqlite`（`node:sqlite`）で未変更ファイルの増分スキャンをスキップし、`fs.promises.glob` および `AbortSignal.timeout()` / `git` 統合ヘルパーを提供すること。
- **AC-009** (REQ-003): `task-lock.mjs` が `[Symbol.dispose]` を持つ `acquireTaskLockHandle` と `Temporal` 優先の TTL 計算を提供し、`factory-metrics.mjs` が `node:sqlite` による p95・集計機能を備え JSONL 互換を維持すること。
- **AC-010** (REQ-004): `.github/scripts/generate-sbom.ts` が CycloneDX 1.5 JSON を出力し、`generate-sbom.py` と同一リポジトリ入力に対して同一コンポーネント一覧を出力すること（`release.yml` から Node で実行）。
- **AC-011** (REQ-004): `validate-path.ts`, `check-contract.ts`, `validate-concept-test.ts`, `render-agent-frontmatter.ts` が erasable `.ts` として直接 `node` で実行でき、旧 Python/Shell 実装と Parity テストに合格すること。
- **AC-012** (REQ-004): `mcp/ci-mcp/src/diagnostics.ts` が `mcp/shared/diagnostics-core.ts` を直接参照し、コピー同期なしでビルド・テストが通ること。
- **AC-013** (REQ-005): `mcp/sdd-forge-mcp` および `mcp/ci-mcp` が `@modelcontextprotocol/server` v2.4.0 に移行済みであり、`npm run typecheck`, `npm run build`, 全 MCP スイートが合格すること。
- **AC-014** (REQ-005): `sdd-forge-mcp` の 4 ツール・2 リソースが既存 JSON Schema (`contracts/sdd-mcp.v2.schema.json`) に完全準拠し、静的ツール一覧のキャッシュ設定メタデータを保持すること。
- **AC-015** (REQ-006): `plugins/sdd-quality-loop/config/readonly.node.json` と `hook.node.json` が `--permission`, `--disallow-code-generation-from-strings`, `--disable-proto=throw` を宣言していること。
- **AC-016** (REQ-006): `--permission --allow-fs-read=... --disallow-code-generation-from-strings --disable-proto=throw` 下で `sdd-doctor.mjs` / `sdd-forge-mcp` が正常読取でき、許可外書込・子プロセス起動・文字列からのコード生成・`__proto__` 操作が確実に遮断されること。

## スコープ外

- Rust ツールチェーン・Docker・外部データベース・TLA+ TLC 実行基盤の導入
- 非推奨 `mcp/local-env-mcp` への新規機能投資（整理・注記のみ）
- 既存 Python/Shell テストが直接参照している旧スクリプトの破壊的削除（Parity 確保のうえ移行経路を確立する）

## Open Questions（未確定事項・AI 仮決定）

| ID | 分類 | 設計した事実・AI 仮決定 | なぜそうしたか | 人が判断する問い | 状態 | 影響タスク |
|---|---|---|---|---|---|---|
| OQ-001 | 技術選定 | 既存端末互換のため `install.sh` / `install.ps1` の下限は Node 20 を維持しつつ CI・`engines.node`・`sdd-doctor` で Node 26.13+ を標準基準とする | 既存の Node 24/25 ローカル環境および `install.tests.sh` 境界テストを破壊せずに段階移行するため | インストーラーのハード拒否下限も即時 26.13.0 に引き上げるか、次期メジャーまで警告運用にするか | Confirmed | T-001 |

## Spec Amendments

- （初期版のため変更なし）
