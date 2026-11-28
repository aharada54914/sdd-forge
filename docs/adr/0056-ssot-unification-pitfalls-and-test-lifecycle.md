# ADR-0056: SSOT 統合・AI ピットフォール自動更新・動的テスト改廃アーキテクチャ

- **Status**: Accepted
- **Date**: 2026-11-28
- **Spec**: `specs/ssot-unification-v22/`
- **Source Specification**: sdd-forge リポジトリ SSOT 統合・再発防止・動的テスト改廃 仕様書（v2.2）

## Context

`sdd-forge`（`v2.1.5`）のリポジトリ全体監査の結果、以下の 7 ドメインに同根の二重・多重保守とガバナンス欠損が存在することが判明した：

1. **契約 JSON 複製 & 文書表**: ルート `contracts/*.json` と `plugins/*/contracts/*.json`、`docs/agent-capability-matrix.md`、`contracts/agent-model-capabilities.v2.md`、各参照文書のモデル表が手動並走している。
2. **マルチ CLI マニフェスト & マーケットプレイス**: 8 プラグイン × 4〜5 CLI マニフェスト（`plugin.json` / `gemini-extension.json`）と 2 種の `marketplace.json` が並列管理され、`skills` 記法（配列／文字列／相対パス）や Gemini 拡張名（`sdd-forge-model-selection` vs `sdd-implementation`）に不整合が生じている。
3. **全階層エージェントプロンプト定義**: `.codex/agents/*.toml`、`plugins/*/agents/*.md`、`plugins/*/copilot-agents/*.agent.md` が手動三重保守されており、Codex `.toml` への Claude 固有ツール名（`Read, Grep, or Glob`）混入や `render-agent-frontmatter.{sh,ps1}` 内の R-10 ゴーストパスが発生している。
4. **配布パス・統一バージョニング・Node 要件**: `install.{sh,ps1}` の `REQUIRED_PATHS` ハードコード、`mcp/ci-mcp`・`mcp/local-env-mcp` の `0.1.0` 取り残し、`minNodeVersion` の散在（本 ADR で `26.13.0` に統一）。
5. **パリティ検証 & CI ゲート**: `tests/capability-registry-parity.tests.sh` の CI 未接続、`tests/check-evidence-bundle-parity.tests.py` の `pwsh` 不在時サイレントスキップ、および必須チェックへの `ssot-sync-check` / `test-lifecycle-check` 欠如。
6. **言語別コーディング規約・AI ピットフォール・肥大化した `AGENTS.md`**: ルート `AGENTS.md` が 346 行に肥大化し、`CLAUDE.md` 混在の機械検査と、WFI/RT からのピットフォール自動抽出・2回発生時の機械ルール昇格パイプラインが存在しない。
7. **機能改廃に伴う動的テスト影響分析（TIA）と安全テスト改廃、および利用者プロジェクトへの横展開（Dogfooding → Productize）**: テスト改廃の強制ゲートと、戦略的 DDD 3 ティア（Lite / Standard / Full）を標準初期化する利用者向けワークフローが未統合である。

## Decision

1. **単一正本（SSOT）＋ 統一同期 CLI（`scripts/sync-ssot.mjs`）**:
   - 7 ドメインすべてに唯一の正本を定め、`node scripts/sync-ssot.mjs [--target all|contracts|manifests|agents|release|conventions|docs|diagnostics] [--check] [--json]` で決定論的に生成・検証する（`0`: 同期済み、`1`: ドリフト＋修復コマンド出力、`2`: 正本スキーマ／マーカー破損）。
   - 生成物には `.gitattributes` の `linguist-generated=true` を付与し、`CODEOWNERS` で正本・同期スクリプト・承認ファイルを保護する。
2. **プラグインマニフェスト & 全階層エージェントプロンプトの SSOT 化**:
   - 各プラグイン直下に `plugin.manifest.json` を配置し、自動走査で全 CLI マニフェストと両 `marketplace.json` を生成する（未登録ディレクトリは Fail-Closed で exit 2）。
   - `contracts/agents/<role>.agent.yaml` を全階層エージェント定義の正本とし、6 ブロック構造（`Role & Non-Goals` / `Boundary & Security` / `Inputs` / `Process` / `Verification Criteria` / `Output & Failure Contract`）と `{{READ_TOOLS}}` 等のツール抽象化プレースホルダから Claude `.md` / Codex `.toml` / Copilot `.agent.md` を一括生成する。`render-agent-frontmatter.{sh,ps1}` は廃止する。
3. **固定統一バージョニング & Node.js 26.13+ 要件**:
   - `contracts/release-manifest.json` を唯一のバージョン（`2.1.5`）・最小 Node.js 要件（`26.13.0`）・必須配布パス（`install-payload.txt` 連携）の正本とし、全プラグイン・両マーケットプレイス・全 3 MCP パッケージ（`sdd-forge-mcp` / `ci-mcp` / `local-env-mcp`）・CI ワークフロー・インストーラーを連動同期する。
4. **全階層 `AGENTS.md` 一本化 & Compound Engineering ピットフォール循環**:
   - Claude Code `v2.1.277+` のネイティブ `AGENTS.md` 読み込みを前提に、ルート `AGENTS.md` を 100 行以内の軽量目次へ圧縮し、サブディレクトリ `AGENTS.md`（`mcp/`, `plugins/`, `tests/`）へ詳細ルールを委譲する。リポジトリ内のアクティブ領域における `CLAUDE.md` 混在およびシンボリックリンク配置を `--check` で機械禁止する（過去の歴史的検証スナップショット配下 `reports/verification/` は明示的除外）。
   - `contracts/pitfalls-catalog.json` から言語別規約（`docs/contributor/coding-standards/*.md`）のピットフォール表を自動生成し、`scripts/harvest-pitfalls.mjs` で `WFI-*.md` / `RT-*.yml` / `fix:` コミットから候補抽出・2 回発生項目の `enforced-by-lint` 昇格候補を検出する。
5. **動的影響範囲チェック（TIA）と承認付き安全テスト改廃**:
   - `scripts/check-ecosystem-impact.mjs` で PR の `git diff --name-status` から追加・変更・廃止のエコシステム連動漏れを検査する。
   - `tests/verification-catalog-status.mjs --check` で `file-missing` / `not-in-ci` 増加をブロックし、既存テスト削除は `CODEOWNERS` 保護下の `sdd/approved-test-retirements.json`（`git_blob_sha`・理由・負例パリティ検証フラグ必須）でのみ許可する。
6. **軸 B（Productize）: 利用者プロジェクトへの戦略的 DDD 3 ティア＆SSOT 横展開**:
   - `sdd-bootstrap` に `init-project-governance.mjs`（DDD ティア自動判定 `Lite` / `Standard` / `Full`、`sdd/glossary.json`、`sdd/context-map.json`、`sdd/pitfalls-catalog.json`、`sdd/verification-catalog.json`、軽量 `AGENTS.md`＋Bounded Context 別 `AGENTS.md`、`.gitattributes` 生成）を追加する。
   - `sdd-implementation`（タスク着手時ピットフォール動的注入）・`sdd-quality-loop`（依存方向 Fitness Function `domain-isolated` / `context-via-api`＋ユビキタス言語検査＋TIA）・`sdd-review-loop` / `sdd-ship`（Compound ステップ）へ統合する。

## Alternatives Rejected

| Alternative | Reason Rejected |
|---|---|
| 既存の個別スクリプト群（`bump-version.sh`, `render-agent-frontmatter.{sh,ps1}`, `sync-diagnostics.py`）にパッチを継ぎ足す | 固定配列ハードコードと多言語三重保守が残り、新規 MCP／プラグイン追加時の同期漏れが再発する。 |
| `CLAUDE.md` をルートに置き `AGENTS.md` と symlink / 二重管理する | Claude Code `v2.1.277+` は `CLAUDE.md` 存在時に `AGENTS.md` を無視し、Windows 環境では symlink が破損するため Context Clash の温床となる。 |
| すべてのテスト削除を無条件ブロックまたは無条件許可する | 無条件許可はエージェントによるテスト改ざんを招き、無条件ブロックは正当な機能廃止時のゴーストテスト蓄積を招く。`sdd/approved-test-retirements.json` による承認＋負例パリティ確認で両立する。 |
| 全プロジェクトに戦術的 DDD（Aggregate/Repository スキャフォールディング）を一律強制する | 小規模 CLI では過剰抽象化となり LLM が CRUD へ退行しやすいため、戦略的 DDD 中心の 3 ティア（Lite / Standard / Full）を採用する。 |

## Consequences

- 正本 1 箇所の変更と `node scripts/sync-ssot.mjs` 実行のみで全 7 ドメインがバイト再現可能となり、CI の `ssot-sync-check` および `test-lifecycle-check` がドリフト・未承認テスト削除・`CLAUDE.md` 混在を自動ブロックする。
- 利用者プロジェクトでも `sdd-bootstrap` 初期化初日から同じ SSOT・DDD ティア・ピットフォール循環・動的テスト改廃ループが動作する。
