# 要件定義書（SDD Core）: ssot-unification-v22

- **Feature**: `ssot-unification-v22`
- **ADR**: `docs/adr/0056-ssot-unification-pitfalls-and-test-lifecycle.md`
- **Target Runtime**: Node.js `>=26.13.0` (ESM, zero external runtime dependencies)
- **Source Specification**: sdd-forge リポジトリ SSOT 統合・再発防止・動的テスト改廃 仕様書（v2.2）

## Requirements

- **REQ-001（契約 JSON・能力レジストリ・モデルポリシー・文書表の SSOT 化）**:
  `contracts/agent-model-capabilities.v2.json`、`contracts/model-policy.v1.json`、`contracts/capability-registry.json` を唯一の正本とし、`scripts/sync-ssot.mjs --target contracts` でプラグイン配下コピーの SHA-256 一致同期と `docs/agent-capability-matrix.md`・`contracts/agent-model-capabilities.v2.md`・参照文書のマーカー区間表を決定論的に生成・検証できること。
- **REQ-002（マルチ CLI マニフェスト & 2 種 `marketplace.json` の自動走査生成）**:
  各プラグイン直下の `plugin.manifest.json` を正本とし、`scripts/sync-ssot.mjs --target manifests` で全 CLI マニフェスト（Claude / Codex / Copilot / Antigravity / Gemini）および `.claude-plugin/marketplace.json`・`.agents/plugins/marketplace.json` を自動走査で生成し、`gemini` 拡張名不整合（`sdd-forge-model-selection` → `sdd-implementation`）と `skills` 記法揺れを解消し、未登録ディレクトリを exit 2（Fail-Closed）で検知すること。
- **REQ-003（全階層エージェントプロンプトの SSOT 化と 6 ブロック標準化）**:
  `contracts/agents/<role>.agent.yaml` を唯一の正本とし、6 ブロック構造・ツール抽象化プレースホルダ（`{{READ_TOOLS}}` 等）・Fail-Loud 契約・DDD/SSOT/テスト改廃観点を標準化した上で `scripts/sync-ssot.mjs --target agents` により Claude `.md` / Codex `.toml` / Copilot `.agent.md` を一括生成し、`render-agent-frontmatter.{sh,ps1}` を廃止すること。
- **REQ-004（統一バージョニング・Node 26.13+ 要件・配布必須パス SSOT 化）**:
  `contracts/release-manifest.json` を単一バージョン（全プラグイン・全 3 MCP パッケージ連動）および `minNodeVersion: "26.13.0"`・必須配布パス（`install-payload.txt` 連動）の正本とし、`install.sh` / `install.ps1` / `scripts/bump-version.sh` / CI ワークフローと整合検証できること。
- **REQ-005（CI ゲート強化・パリティテスト正規接続・サイレントスキップ廃止）**:
  `.github/workflows/test.yml` に `paths` フィルタなしの必須ジョブ `ssot-sync-check` および `test-lifecycle-check` を追加し、`tests/capability-registry-parity.tests.sh` を CI へ接続し、`tests/check-evidence-bundle-parity.tests.py` の `pwsh` 不在時サイレントスキップを廃止すること。
- **REQ-006（言語別規約・AI ピットフォール正本化・全階層 `AGENTS.md` 一本化）**:
  `contracts/pitfalls-catalog.json` から言語別規約（`docs/contributor/coding-standards/*.md`）のピットフォール表を自動生成し、`docs/coding-conventions.md`（R-01〜R-05）を整備し、ルート `AGENTS.md` を 100 行以内の軽量目次へ圧縮し、サブディレクトリ `AGENTS.md`（`mcp/`, `plugins/`, `tests/`）へ分割した上でアクティブ領域の `CLAUDE.md` 混在および symlink を `--check` で機械禁止すること。
- **REQ-007（Compound Engineering 自動抽出・2 回発生昇格・ドキュメント自動生成）**:
  `scripts/harvest-pitfalls.mjs` により `RT-*.yml` / `WFI-*.md` / `fix:` コミットから未登録ピットフォール候補を抽出し、2 回以上発生した項目を機械ルール昇格対象（`enforced-by-lint` 候補）としてレポートできること。また `scripts/sync-ssot.mjs --target docs` で `PLUGIN-CONTRACTS.md` / `docs/skill-reference.md` 等の自動生成マーカー区間を同期できること。
- **REQ-008（動的影響範囲チェック TIA と承認付き安全テスト改廃）**:
  `scripts/check-ecosystem-impact.mjs` で `git diff --name-status` に基づく追加・変更・廃止時の連動漏れを検査し、`tests/verification-catalog-status.mjs --check` と `CODEOWNERS` 保護下の `sdd/approved-test-retirements.json` によりゴーストテスト放置と未承認テスト削除の双方を CI でブロックできること。
- **REQ-009（軸 B: 利用者プロジェクトへの戦略的 DDD 3 ティア＆SSOT 横展開）**:
  `sdd-bootstrap`・`sdd-implementation`・`sdd-quality-loop`・`sdd-review-loop` / `sdd-ship` において、戦略的 DDD 3 ティア自動判定（`Lite` / `Standard` / `Full`）、`sdd/glossary.json`・`sdd/context-map.json`・Bounded Context 別 `AGENTS.md`・`sdd/pitfalls-catalog.json`・`sdd/verification-catalog.json` の自動初期化、ピットフォール動的注入、依存方向 Fitness Function（`domain-isolated` / `context-via-api`）、および Compound ステップを E2E で提供すること。

## Acceptance Criteria

- **AC-001** (REQ-001): `contracts/agent-model-capabilities.v2.json` / `model-policy.v1.json` / `capability-registry.json` 更新後に `node scripts/sync-ssot.mjs --target contracts` を実行すると、プラグイン内複製 JSON および `docs/agent-capability-matrix.md` 等のマーカー区間表が決定論的に同期され、2 回連続実行で差分ゼロとなる。
- **AC-002** (REQ-001, REQ-005): `node scripts/sync-ssot.mjs --check` がドリフトを exit 1 で検知し、違反ファイル・編集すべき正本パス・修復コマンドを標準エラー（および `--json` で構造化 JSON）に出力する。正本 JSON 破損やマーカー破損時は exit 2 で終了する。
- **AC-003** (REQ-002): 全 8 プラグインの `plugin.manifest.json` から全 CLI マニフェストおよび `.claude-plugin/marketplace.json`・`.agents/plugins/marketplace.json` がバイト再現でき、`.gitattributes` に `linguist-generated=true` が設定される。`plugin.manifest.json` を持たない新規ディレクトリは exit 2 で Fail-Closed する。
- **AC-004** (REQ-002): `plugins/sdd-implementation/gemini/gemini-extension.json` の `name` 不整合（`sdd-forge-model-selection` → `sdd-implementation`）および `skills` 記法揺れがジェネレータのスキーマ変換により解消される。
- **AC-005** (REQ-003): `contracts/agents/*.agent.yaml` から全 CLI エージェント定義（Claude `.md` / Codex `.toml` / Copilot `.agent.md`）が 6 ブロック標準化かつバイト再現でき、Codex `.toml` への Claude 固有ツール名混入、`# x-sdd-model:` / `# x-sdd-effort:` 欠落、R-10 ゴーストパス、および `render-agent-frontmatter.{sh,ps1}` がすべて解消・廃止される。
- **AC-006** (REQ-004): `contracts/release-manifest.json`（`version: "2.1.5"`, `minNodeVersion: "26.13.0"`, 必須配布パス正本）から `install.sh` / `install.ps1` 両方の必須パスおよび最小 Node.js 要件が連動し、`scripts/bump-version.sh` が `sync-ssot.mjs --target release` を利用する。
- **AC-007** (REQ-005): `.github/workflows/test.yml` に `paths` フィルタなしの必須ジョブ `ssot-sync-check`・`test-lifecycle-check` が追加され、`tests/capability-registry-parity.tests.sh` が CI へ接続され、`tests/check-evidence-bundle-parity.tests.py` に `pwsh` サイレントスキップが残らない。
- **AC-008** (REQ-004): `mcp/*/package.json`（`sdd-forge-mcp`, `ci-mcp`, `local-env-mcp`）すべてが `2.1.5` かつ `engines.node: ">=26.13.0"` に統一され、未登録またはバージョン不一致の新規 `mcp/<new>/package.json` を `sync-ssot.mjs --check` が自動検知して exit 1 でブロックする。
- **AC-009** (REQ-006): ルート `AGENTS.md` が 100 行以内を維持し、アクティブ領域に `CLAUDE.md` や symlink が混在していないことを `sync-ssot.mjs --check` が検証し、`contracts/pitfalls-catalog.json` から `docs/contributor/coding-standards/*.md` のピットフォール表が自動生成され、`docs/coding-conventions.md`（R-01〜R-05）および `CODEOWNERS` が整備される。
- **AC-010** (REQ-008): `scripts/check-ecosystem-impact.mjs` と `tests/verification-catalog-status.mjs --check` が機能廃止 PR でのゴーストテスト放置または `sdd/approved-test-retirements.json` 未承認のテスト削除を exit 1 でブロックし、承認済みかつ負例パリティ確認済み削除のみ許可する。
- **AC-011** (REQ-007): `scripts/harvest-pitfalls.mjs` が `docs/review-tickets/RT-*.yml`・`docs/workflow-improvements/WFI-*.md`・`fix:` コミットからピットフォール候補を抽出し、2 回以上発生項目に機械ルール昇格（`enforced-by-lint`）フラグを付与する。また `sync-ssot.mjs --target docs` が `PLUGIN-CONTRACTS.md` / `docs/skill-reference.md` のマーカー区間を同期する。
- **AC-012** (REQ-009): 利用者プロジェクト向けの初期化・実装・検証・振り返りツール群（`init-project-governance.mjs`、ピットフォール動的注入、依存方向 Fitness Function `domain-isolated` / `context-via-api`、ユビキタス言語検査、TIA＋テスト改廃、Compound ステップ）が新規プロジェクト E2E テストで動作実証される。

## Spec Amendments

- （初期版のため変更なし）
