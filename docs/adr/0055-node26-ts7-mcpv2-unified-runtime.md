# ADR-0055: Node.js 26.13+・TypeScript 7.0・MCP SDK v2 統合ランタイム最適化

- **Status**: Accepted
- **Date**: 2026-11-28
- **Related**: ADR-0051 (Lightweight Guardrails & SDD Core), ADR-0052 (MCP v2 Consolidation), ADR-0054 (Verification-First Factory)

## Context

`sdd-forge` v2.1.5 の棚卸しにより、以下の構造的課題が明らかになった。

1. **PreToolUse フックの冷起動集中**: `plugins/sdd-quality-loop/hooks/claude-hooks.json` および `codex-hooks.json` はツール呼び出しごとに新規 `node` プロセスで `sdd-soft-guard.mjs`（677 行）を起動する。
2. **CI と配布ゲートの Node バージョン乖離**: `self-improvement.yml` は `node-version: "26.13.0"` を採用済みである一方、`test.yml`・`release.yml`・`sdd-guardrails.yml` および `mcp/*/package.json` の `engines.node` は EOL 済みの Node 20 に留まっている。
3. **TypeScript 7.0 は部分導入、MCP SDK は v1.x 残存**: `mcp/*/package.json` には Go ネイティブ版 TypeScript 7.0 (`^7.0.2`) と `zod` (`^4.6.5`) が入っているが、リポジトリ横断の型検査基盤と MCP SDK v2 (`@modelcontextprotocol/server` v2.4.0) への移行が未完了であり、`mcp/shared/sync-diagnostics.py` による手動コピー同期も残存している。
4. **Python / PowerShell / Shell の重複維持コスト**: SBOM 生成（`generate-sbom.py`）、契約・パス検証（`check-contract.py`, `validate_path.py`）、フロントマター生成（`render-agent-frontmatter.{sh,ps1}`）、Concept Test 検証（`validate-concept-test.{sh,ps1,py}`）が非 Node ランタイムに分散しており、Windows での `pwsh` 起動や Python 依存を生んでいる。

## Decision

1. **単一必須ランタイムを Node.js 26.13+ (Active LTS) へ統一**（Rust・Docker・外部 DB・TLC 実行基盤は導入しない）。
   - GitHub Actions (`test.yml`, `release.yml`, `sdd-guardrails.yml`) と全 MCP `package.json` (`engines.node`) を `26.13.0` / `>=26.13.0` へ統一する。
   - 既存端末の段階的移行のため、インストーラーの下限チェックは互換性を保ちつつ `sdd-doctor` で Node 26.13+ 未満を診断し、すべての新 API（`Temporal`・`RegExp.escape`・`crypto.hash`・`node:sqlite` 等）は Node 24/25 ローカル環境でも安全にフォールバック動作させる。
2. **2 段階ハイブリッド事前生成 Compile Cache の導入**:
   - 段階 1: `release.yml` で基準 Node 26.13.0 により `NODE_COMPILE_CACHE_PORTABLE=1` キャッシュを `.sdd-compile-cache/` に生成・同梱（`install-payload.txt` に追加）。
   - 段階 2: `install.sh` / `install.ps1` のステージング工程でユーザー自身の `node` により主要エントリ（`sdd-soft-guard`, `run-sdd-gate`, `sdd-doctor`, `sdd-forge-mcp/dist/index.js`）を `--warmup` 実行してポータブルキャッシュを生成してからアトミックスワップ。
   - 実行時: `NODE_COMPILE_CACHE` + `NODE_COMPILE_CACHE_PORTABLE=1` + `NODE_COMPILE_CACHE_READONLY=1` でディスク書込ゼロの高速起動を実現し、Node 更新時は `sdd-doctor --rebuild-cache` で再生成する。V8 カバレッジ計測時のみ `NODE_DISABLE_COMPILE_CACHE=1` を明示する。
3. **TypeScript 7.0 (`erasableSyntaxOnly: true`, `noEmit: true`) の全リポジトリ展開とビルドレス `.ts` 集約**:
   - リポジトリルートに共通 `tsconfig.json` を配置し、移行したビルドレス `.ts` スクリプト群（`generate-sbom.ts`, `validate-path.ts`, `check-contract.ts`, `validate-concept-test.ts`, `render-agent-frontmatter.ts`, `bench-runtime.ts`）を TS 7.0 で型検査する。
   - 既存 `.mjs` エントリポイントは後方互換を維持しながら、内部プリミティブを `crypto.hash()`, `RegExp.escape()`, `fs.promises.glob`, `node:sqlite` (`DatabaseSync`), `[Symbol.dispose]` (`using`), `Temporal` 優先, `node:diagnostics_channel` 3 区分プロファイラへ刷新する。
4. **MCP TypeScript SDK v2 (`@modelcontextprotocol/server` v2.4.0) 移行と役割別権限プロファイル固定**:
   - `mcp/sdd-forge-mcp` と `mcp/ci-mcp` を `@modelcontextprotocol/server` v2.4.0（テストクライアントは `@modelcontextprotocol/client` v2.4.0）へ移行し、静的ツール一覧のキャッシュ最適化および `mcp/shared/diagnostics-core.ts` の直接参照を実現する。非推奨 `mcp/local-env-mcp` は新規投資対象外として明示整理する。
   - 役割別設定プロファイル（`plugins/sdd-quality-loop/config/readonly.node.json`, `hook.node.json`）で `--permission`, `--disallow-code-generation-from-strings`, `--disable-proto=throw` を宣言し、読取専用コンポーネントの書込・子プロセス起動遮断を自動テストで固定する。

## Alternatives Rejected

| 候補案 | 不採用理由 | 再検討条件 |
|---|---|---|
| Rust 製バイナリへの全面書き換え | 3 OS クロスコンパイル・バイナリ配布署名・メンテナンス言語増加により既存の「ゼロ依存・ソース読解可能」な強みを損なう | Node.js 起動レイテンシが事前キャッシュ後も 100ms を継続超過し UX 障害となる場合 |
| Release 同梱 Compile Cache のみ（導入時 warmup なし） | Node.js の Compile Cache はバージョン固有のため、ユーザーのマイナーバージョン差で初回キャッシュミスが発生する | Node.js 本体がマイナーバージョン跨ぎの完全互換キャッシュ仕様を提供した場合 |
| Python 3.14 / PowerShell 7.6 への最新版強制 | 利用者端末に追加のランタイム導入・維持負担を強いる | Node.js で代替不可能な OS 固有 API が必要になった場合 |

## Consequences

- **Positive**: 初回 `PreToolUse` からの起動高速化、TS 7.0 による高速一括型検査、CI の EOL Node 20 脱却、MCP SDK v2 への最新化、Python/PowerShell 依存の大幅削減、`--permission` による最小権限境界の機械検証。
- **Trade-offs**: 移行期間中は既存テストとの互換性のため旧 Python/Shell スクリプトを残しつつ Parity テストで挙動一致を保証する（完全撤去は次期マイナーでの廃止通知後に実施可能）。
