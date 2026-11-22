---
name: bootstrap
description: Generate implementation-ready SDD Core specifications (requirements with ACs, design, and risk-tiered tasks) and run a risk-scaled pre-implementation spec check. First step of the two-command workflow before /sdd-ship:ship.
disable-model-invocation: true
---

# SDD Bootstrap

要件から実装可能な仕様・設計・タスク契約を生成し、着工前レビューまで完了させるエントリポイント。

## Invocation

```txt
/sdd-bootstrap:bootstrap <mode> <source>
/sdd-bootstrap:bootstrap <mode> --feature <slug> [--risk low|standard|high] [--proto|--harden] [--skip-check] <source>
/sdd-bootstrap:bootstrap adopt [project-root]
/sdd-bootstrap:bootstrap investigate <mode> <source>
```

| Mode | 委譲先 | 用途 |
|---|---|---|
| `feature` | `sdd-core-spec` → `spec-check` | 新機能の仕様・設計・タスク生成 |
| `bugfix` | `sdd-core-spec` → `spec-check` | 不具合修正（原因不明時は先に `/sdd-implementation:diagnose` 推奨） |
| `refactor` | `sdd-core-spec` → `spec-check` | リファクタリング（事前に `investigate refactor` でベースライン取得推奨） |
| `project` | `sdd-adopt` → `sdd-core-spec` → `spec-check` | 新規プロジェクト立ち上げ |
| `adopt` | `sdd-adopt` | 既存リポジトリへの SDD 構造導入のみ |
| `investigate` | `investigate-codebase` | 読み取り専用のコードベース調査のみ |

### Flags

- `--feature <slug>`: 出力先 `specs/<slug>/` を明示指定。
- `--risk low|standard|high`: リスク階層を明示指定（省略時は `sdd/guardrails.yaml` の既定値と変更内容から判定）。
- `--proto`: 試作探索モード（`Risk: low` 相当・`OQ-NNN` 仮決定での高速試作を許容し、実物確認後に `--harden` へ進む）。
- `--harden`: 本番品質昇格モード（既存仕様の確定判断を引き継ぎ、非機能・SQL 移行・Cloud 監視観点を `design.md` へ追記して `Risk: standard|high` で再構成）。
- `--skip-check`: 着工前レビュー（`spec-check`）を省略。
- `--lite` / `--full` *(互換エイリアス)*: それぞれ `--risk low` / `--risk high` として解釈する。

## Preconditions

1. ルートに `AGENTS.md` が無い場合、`feature` / `bugfix` / `refactor` / `project` では先に `/sdd-bootstrap:sdd-adopt` を実行または案内する。
2. `sdd/guardrails.yaml`（または `sdd/guardrails.json`）があれば読み込む。不在時は既定値（`spec_guard.mode: confirm`, `review.pre_impl_check: auto`, `risk_defaults.default_tier: standard`）を使用する。
3. オプトイン MCP（`sdd_project_overview` / `sdd_feature_state`）が有効な場合は参考情報として参照してよいが、ルーティング判断は常にファイル状態を正とする。
4. `<source>` に GitHub Issue URL が渡された場合は `gh issue view`（利用可能時）で要件本文を取得してよい。

## Flow

- `adopt` / `investigate`: 該当スキルへ委譲して終了。
- オプトイン専門ルート: 外部資料調査は `research-sources`、UI デザインシステムは `design-system/` 存在時のみ `design-sync-loop` を委譲する。DDD モデル構築（`/sdd-domain:domain-model`）および既存クラウド運用（`/sdd-azure-cloud:orchestrate` / `/sdd-aws-cloud:orchestrate`）は公開コマンド（`disable-model-invocation: true`）のため自動委譲せず、該当する場合のみユーザーへ実行を案内する。

`feature` / `bugfix` / `refactor` / `project` は次の 3 ステップで進める:

1. **仕様生成（`sdd-core-spec`）**:
   `/sdd-bootstrap:sdd-core-spec` を実行し、`specs/<feature>/{requirements,design,tasks}.md` を生成する。
2. **着工前レビュー（`spec-check`）**:
   `review.pre_impl_check` と最高 `Risk:` 階層に従って `/sdd-review-loop:spec-check` を実行する:
   - `off` / `--skip-check`、または `auto` かつ全タスク `Risk: low` → スキップして Step 3 へ。
   - `Risk: standard` → `single` モード（独立 1 体・1 パス）。
   - `Risk: high` → `dual-parallel` モード（Reviewer A [仕様・AC] ＋ Reviewer B [設計・セキュリティ] の 2 視点並列 1 パス）。
   - `PASS` / `PASS_WITH_NOTES` → Step 3 へ。`NEEDS_FIX` → Blocker を提示し仕様修正後に再実行。
3. **人間承認ゲート（Decision View 提示）**:
   `<installed-root>/plugins/sdd-quality-loop/scripts/v2/check-traceability.mjs --plan-batches` で REQ↔AC↔Task・Code/Test・並列 Scope 衝突を確認し、`<installed-root>/plugins/sdd-quality-loop/scripts/v2/render-decision-view.mjs` で **Decision View（全体像＋元ファイル行番号付き `OQ-NNN` 事実/理由/人の問い＋採らなかった設計＋共通8観点×プロダクト観点の採否表）** を生成して人間へ提示して停止する。`Approval: Approved` は絶対に書き込まない。

## Handoff

完了時に以下を報告する:
- 生成ファイル一覧（`specs/<feature>/{requirements,design,tasks}.md`）
- `spec-check` 結果（実行時）と残る `Open Questions`
- 次の人間操作: `specs/<feature>/tasks.md` の対象タスクを `Approval: Approved` へ変更
- 次のコマンド: `/sdd-ship:ship specs/<feature>/tasks.md`
