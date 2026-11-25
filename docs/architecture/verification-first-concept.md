# 構想書（Concept Document）：`sdd-forge`「本体品質保証（Self-Verification）」×「利用者開発フロー（Plugin Feature）」両輪進化構想（v2.2 / ADR-0054）

| 項目 | 内容 |
| :--- | :--- |
| **対象リポジトリ** | [aharada54914/sdd-forge](https://github.com/aharada54914/sdd-forge)（基準: `v2.1.3`） |
| **関連正本** | `docs/adr/0054-verification-first-and-agentic-factory.md`（WFI-013: PR #974 の `0053` と重複回避のため `0054` 仮採番・マージ前再確認必須）、`specs/verification-first-factory/{requirements,design,tasks}.md` |
| **着想元（一次資料）** | [Jensen Huang, AI & Why Founders Are Irreplaceable \| Tobi Lütke, Shopify](https://www.youtube.com/watch?v=w0oOxs0WKNk)（David Senra, 2026-11-22） |
| **作成日** | 2026-11-25 |

---

## 1. エグゼクティブ・サマリー：両輪（Self-First × Plugin Feature）＋テストの引き算

Tobi Lütke 氏は[対談動画](https://www.youtube.com/watch?v=w0oOxs0WKNk)で「まず自分たちの開発で使い倒して深い洞察を得てから製品化する（Dogfooding-First）」と説き、Anthropic も [Harness Design (Mar 2026)](https://www.anthropic.com/research/harness-design-long-running-apps) で「新しい保証手段を入れたら不要になった足場を削る（引き算の設計）」の重要性を強調している。

- **軸A：Self-Verification（内向き・本体品質保証＆テスト刷新）**: `sdd-forge` 本体コア状態機械（`task-lock.mjs`・`run-sdd-gate.mjs` / `sdd-ship`・`check-spec-drift.mjs`）の TLA+ 形式検証＋実装 [Trace Validation](https://sefm-conference.github.io/2024/acceptedpapers/)、純粋性・4 CLI パリティ Fitness Function、敵対的セキュリティ回帰、残存スクリプトの ESM 集約、および肥大化した旧テスト群の安全廃止・統合。
- **軸B：User-Facing SDD Workflow（外向き・プラグイン機能）**: 軸A（本体 CI）で「誤検知 < 5%・新規ゲート純増オーバーヘッド（ローカル `<= +15s` / PR CI `<= +120s`）」を実証した仕組みを、Reframing、チェッカー非依存形式検証ゲート（TLA+ 標準・Lean 4 拡張対応）、AST 厳格 Lint、固定アローリスト Security Gate、Differential Rebuild、F-8 Factory / OTel / MCP v2 観測として利用者プロジェクトへ提供。

---

## 2. `ADR-0051` / `ADR-0052` 軽量原則と実測根拠（WFI-011 準拠）

1. **ハッシュ局所化**: [record-spec-baseline.mjs](https://github.com/aharada54914/sdd-forge/blob/main/plugins/sdd-quality-loop/scripts/v2/record-spec-baseline.mjs) の SHA-256 対象は `specs/<feature>/` の数ファイル（数KB・$O(N)$）に厳密限定。外部署名鍵や `MANIFEST.sha256` は導入しない。
2. **Layer 1（`sdd-soft-guard.mjs`）不変＆非肥大化ラチェット**: 現行実測は **663 行**（`wc -l plugins/sdd-quality-loop/scripts/v2/sdd-soft-guard.mjs`）。ファイル自体は変更せず、Fitness Function は現行 663 行を基準に上限 `<= 700` 行・外部依存ゼロ・`< 200ms` の非肥大化ラチェットとする。
3. **既存スクリプトの終了コード非破壊**: `task-lock.mjs:345`（`exit 1`）、`sdd-soft-guard.mjs`（`exit 2`）、`validate-concept-test.py`（`2`/`3`）、`finalize-domain-review.*`（`exit 3`）の終了コードは変更しない。
4. **時間バジェットと CI コスト見積もり**: `docs/verification.md:164-166` の「ローカル 2分・PR 10分」は targets（現行保証ではない）であり、既存 CI ジョブ上限は 30〜90 分（`docs/verification.md:46-53`）。新規追加の目安は Gitleaks（5〜15秒/PR）、Semgrep diff-only（20〜60秒/PR）、TLC 有界検査（変更時のみ `<= 120s`）、CodeQL（夜間 5〜15分、公開リポジトリ追加課金なし）。
5. **可逆／不可逆ロールバックの区分**: 新規ゲート実行は `sdd/guardrails.yaml` の各 `enabled: false` で即時無効化できるが、削除した旧テストの復元は該当 PR の `git revert` で行う。

---

## 3. 実測に基づく現行テスト（直下 386 ファイル / カタログ 262 件）の安全廃止・統合戦略

`find tests -maxdepth 1 -type f | wc -l` = **386 ファイル**、`find tests -maxdepth 1 -name 'resolve-project-context*' | wc -l` = **24 ファイル**、および `node tests/verification-catalog-status.mjs`（2026-11-25 実測）の結果、登録 **262 スイートのうち 96%（252 件）が現行 CI 6ジョブで未実行**（稼働 10 件 / CI 外 196 件 / ゴースト 56 件）であることが確認された。

| カテゴリ | 具体例（実測根拠付き） | 置換先・安全条件 |
| :--- | :--- | :--- |
| **1. ゴースト登録（56件）＆v1 廃止残骸** | `version-gates` ゴースト 39件、`resolve-project-context-*`（24ファイル）、`human-copy-*`、`rollback-1.5.0` 等 | カタログ掃除＋機能廃止済みの死蔵テスト撤去（Phase 1） |
| **2. `.ps1`/`.sh` ペア＆14系統 `parity`** | `constant-parity`, `crlf-parity`, `workflow-state-parity` 等 | **対応する本番 `.ps1`/`.sh` の ESM 集約＋Windows ネイティブ CI 検証完了まで廃止禁止**（Phase 3） |
| **3. 手書き状態遷移の重複列挙テスト** | `workflow-state*`, `loop-*`, `release-config-lock` の組合せ列挙部分 | TLA+＋Trace Validation へ圧縮（実装境界テスト自体は残す） |
| **4. 散在ドキュメント・表記整合スクリプト** | `doc-diagrams.*`, `check-placeholders*`, `render-agent-frontmatter.*` 等 | Self-Fitness Functions（`tests/self-fitness.test.mjs`）へ集約 |

※廃止承認は実装エージェントが書けない **`CODEOWNERS` 保護ファイル `sdd/approved-test-retirements.json`**（パス＋Git blob SHA）で管理し、負例ミュータント 100% 検知パリティを確認する。E2E・3-AI・`tests/golden/**` は恒久保持。
