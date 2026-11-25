# 構想書（Concept Document）：`sdd-forge`「本体品質保証（Self-Verification）」×「利用者開発フロー（Plugin Feature）」両輪進化構想（v2.1 / ADR-0053）

| 項目 | 内容 |
| :--- | :--- |
| **対象リポジトリ** | [aharada54914/sdd-forge](https://github.com/aharada54914/sdd-forge)（基準: `v2.1.3` / 現行最新ADR: `0052`） |
| **関連正本** | `docs/adr/0053-verification-first-and-agentic-factory.md`、`specs/verification-first-factory/{requirements,design,tasks}.md` |
| **着想元（一次資料）** | [Jensen Huang, AI & Why Founders Are Irreplaceable \| Tobi Lütke, Shopify](https://www.youtube.com/watch?v=w0oOxs0WKNk)（David Senra, 2026-11-22） |
| **作成日** | 2026-11-25 |

---

## 1. エグゼクティブ・サマリー：両輪（Self-First × Plugin Feature）＋テストの引き算

Tobi Lütke 氏は[対談動画](https://www.youtube.com/watch?v=w0oOxs0WKNk)で「まず自分たちの開発で使い倒して深い洞察を得てから製品化する（Dogfooding-First）」と説き、Anthropic も [Harness Design (Mar 2026)](https://www.anthropic.com/research/harness-design-long-running-apps) で「新しい保証手段を入れたら不要になった足場を削る（引き算の設計）」の重要性を強調している。

- **軸A：Self-Verification（内向き・本体品質保証＆テスト刷新）**: `sdd-forge` 本体コア状態機械（`task-lock.mjs`・`run-sdd-gate.mjs` / `sdd-ship`・`check-spec-drift.mjs`）の TLA+ 形式検証＋実装 [Trace Validation](https://sefm-conference.github.io/2024/acceptedpapers/)、純粋性・4 CLI パリティ Fitness Function、敵対的セキュリティ回帰、残存スクリプトの ESM 集約、および肥大化した旧テスト群の安全廃止・統合。
- **軸B：User-Facing SDD Workflow（外向き・プラグイン機能）**: 軸A（本体 CI）で「誤検知 < 5%・ローカル 2分／PR 10分以内」を実証した仕組みを、Reframing、チェッカー非依存形式検証ゲート（TLA+ 標準・Lean 4 拡張対応）、AST 厳格 Lint、固定アローリスト Security Gate、Differential Rebuild、F-8 Factory / OTel / MCP v2 観測として利用者プロジェクトへ提供。

---

## 2. `ADR-0051` / `ADR-0052` 軽量原則の不変制約（両軸共通）

1. **ハッシュ局所化**: [record-spec-baseline.mjs](https://github.com/aharada54914/sdd-forge/blob/main/plugins/sdd-quality-loop/scripts/v2/record-spec-baseline.mjs) の SHA-256 対象は `specs/<feature>/` の数ファイル（数KB・$O(N)$）に厳密限定。外部署名鍵や `MANIFEST.sha256` は導入しない。
2. **Layer 1（`sdd-soft-guard.mjs`）不変**: 約200行・ゼロ依存・3責務を維持し、AST Lint や重い検証は Layer 2/3 に配置する。
3. **Git diff ＋ `CODEOWNERS` 境界保護**: 改ざん検知・Write-Scope 強制は `git diff --name-only`（Layer 2）＋ `CODEOWNERS` / CI（Layer 3）で行う。
4. **サイドカー非増殖＆MCP 既定 OFF**: Waiver は `sdd/guardrails.yaml` 内に内蔵、形式検証キャッシュは `git diff`＋CI `actions/cache` に委譲、`sdd-forge-mcp` は既定 OFF・4ツール維持。

---

## 3. 実測に基づく現行テスト（262スイート）の安全廃止・統合戦略

`node tests/verification-catalog-status.mjs`（2026-11-25 実測）の結果、v1 資産である `tests/verification-catalog.json` 登録 **262 スイートのうち 96%（252 件）が現行 CI（6ジョブ：`v2-guardrails`, `sdd-forge-mcp-v2`, `mcp-tests`, `cloud-and-ddd`, `installers`, `required-checks`）で未実行**であることが判明した。

- **実行中（現行 CI 稼働）**: **10 件**（`cloud-native` 4 / `installers` 2 / `test` 2 / `posix-regression` 1 / `sql-contract` 1）
- **CI 外（ファイル残存・未実行）**: **196 件**（`posix-regression` 57 / `test` 42 / `version-gates` 39 / `loops-routing` 23 / `test-windows-heavy` 17 他。既存 TLA+ テスト `tests/project-skill-formal.tests.py` も CI 外）
- **廃止済み（ファイル不在のゴースト登録）**: **56 件**（`version-gates` 39 / `test` 7 / `posix-regression` 4 / `test-windows-heavy` 3 / `cli-hook-enforcement` 2 / `windows-powershell` 1）

### 4カテゴリの削減・統合方針
| カテゴリ | 具体例 | 置換先・対応 |
| :--- | :--- | :--- |
| **1. ゴースト登録（56件）＆v1 廃止残骸** | `version-gates` 39件のゴースト、`resolve-project-context-*`（24本）、`human-copy-*`、`rollback-1.5.0` 等 | カタログ掃除＋機能廃止済みの死蔵テスト撤去（Phase 1 即時着手） |
| **2. `.ps1`/`.sh` ペア＆14系統 `parity`** | `constant-parity`, `crlf-parity`, `workflow-state-parity` 等 | Self-Rebuild（Node.js ESM 集約）＋単一 `v2-*.test.mjs` 統合 |
| **3. 手書き状態遷移・ループ・ロック列挙** | `workflow-state*`, `loop-*`, `release-config-lock` 等 | `TaskLock.tla` / `GateLifecycle.tla` ＋ Trace Validation（および `project-skill-formal.tests.py` の CI 復帰） |
| **4. 散在ドキュメント・表記整合スクリプト** | `doc-diagrams.*`, `check-placeholders*`, `render-agent-frontmatter.*` 等 | Self-Fitness Functions（`tests/self-fitness.test.mjs`）へ集約 |

※`v2-real-flows-e2e.test.mjs`, `v2-sdd-core-flow.test.mjs`, `v2-hooks-and-ci.test.mjs`, `v2-mcp-server.test.mjs`, `tests/gemini-environment-loops.tests.py`, `tests/golden/**` は恒久保持。

---

## 4. 段階的導入ロードマップ（Dogfooding-First：軸A → 軸B）

| フェーズ | 軸A（本体品質保証＆テスト安全廃止） | 軸B（利用者向けプラグイン機能） | 昇格ゲート |
| :--- | :--- | :--- | :--- |
| **Phase 1** | ゴースト 56 件掃除＆CI 外 196 件の仕分け・v1 残骸廃止、Self-Fitness Functions 導入＆カテゴリ4統合、`git diff` Anti-Tampering | `guardrails-lib.mjs` 拡張、`run-agent-lint.mjs`（Shadow）、Reframing、`sync-knowledge.mjs meta-analyze` | 誤検知 < 5%、ローカル 2分以内 |
| **Phase 2** | `TaskLock.tla` / `GateLifecycle.tla`＋Trace Validation 導入（`project-skill-formal.tests.py` の CI 復帰含む）＆カテゴリ3圧縮、敵対的テスト＋2層 SAST | `discover-state-machines.mjs`、`run-formal-gate.mjs`（TLA+ 標準・Lean 4 予約）、`run-security-gate.mjs`、反例 HTML 表示 | TLA+ `baseline`/`negative`＋Trace 通過、PR 10分以内 |
| **Phase 3** | 残存ヘルパー ESM 集約（Self-Rebuild）＆カテゴリ2廃止、OTel メトリクス運用 | `/sdd-ship:ship --mode rebuild`、F-8 Write-Scope、`sdd-forge-mcp` オプショナル拡張、`lean4` オプトインアダプタ | 3-AI E2E・ゴールデン全通過＆単一フラグロールバック確認 |
