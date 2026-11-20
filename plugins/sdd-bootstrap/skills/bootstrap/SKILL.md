---
name: bootstrap
description: Generate implementation-ready SDD Core specifications (requirements with ACs, design, and risk-tiered tasks) and run a single-pass pre-implementation spec check. The first of the two-command workflow — run before /sdd-ship:ship.
disable-model-invocation: true
---

# SDD Bootstrap (SDD Core v2)

要件から実装可能な仕様・設計・タスク契約を生成する、2 コマンドワークフローの第 1 ステップ（ADR-0051）。
従来の「重すぎる Full（3 連レビューループ・7 層ドキュメント・カナリア儀式）」と「軽すぎる Lite（事前レビューゼロ）」を **単一トラック `SDD Core` ＋ リスクレベル伸縮（`low` / `standard` / `high`）** へ統合している。

## Invocation

Claude Code / Gemini CLI:

```txt
/sdd-bootstrap:bootstrap <mode> <source>
/sdd-bootstrap:bootstrap adopt [project-root]
/sdd-bootstrap:bootstrap investigate <mode> <source>
/sdd-bootstrap:bootstrap <mode> --feature <slug> [--risk low|standard|high] [--skip-check] <source>
```

Codex CLI / Copilot CLI:

```txt
Use the bootstrap skill.
Mode: feature | bugfix | refactor | project | adopt | investigate
Source: <GitHub/GitLab issue URL or requirement text>
```

### Modes

| Mode | 委譲先 | 説明 |
|---|---|---|
| `feature` | `sdd-core-spec` → `spec-check` | 新機能の仕様・設計・タスク生成 |
| `bugfix` | `sdd-core-spec` → `spec-check` | 不具合修正（原因不明・複雑な回帰は先に `/sdd-implementation:diagnose` 推奨） |
| `refactor` | `sdd-core-spec` → `spec-check` | リファクタリング（事前に `investigate refactor` でベースライン取得推奨） |
| `project` | `sdd-adopt` → `sdd-core-spec` → `spec-check` | 新規プロジェクト立ち上げ |
| `adopt` | `sdd-adopt` | 既存リポジトリへの SDD 構造導入のみ |
| `investigate` | `investigate-codebase` | 読み取り専用のコードベース調査のみ |

### Flags

| Flag | 効果 |
|---|---|
| `--feature <slug>` | 生成先 `specs/<slug>/` のスラッグを明示指定 |
| `--risk low\|standard\|high` | タスクのリスク階層を明示指定（省略時は `sdd/guardrails.yaml` の既定値＋変更内容から自動判定） |
| `--skip-check` | 着工前の `spec-check`（1 パス統合レビュー）をスキップ |
| `--lite` / `--full` *(互換エイリアス)* | v2 ではトラック分岐を廃止。`--lite` は `--risk low`、`--full` は `--risk high` のヒントとして安全に解釈する（停止エラーにはしない） |

## Preconditions

1. リポジトリルートに `AGENTS.md` が無い場合、`feature`/`bugfix`/`refactor`/`project` では自動的に `/sdd-bootstrap:sdd-adopt` を案内または実行して構造を整える。
2. `sdd/guardrails.yaml`（または `sdd/guardrails.json`）が存在すれば読み込む。存在しなくてもエラーにせず既定値（`spec_guard.mode: confirm`, `review.pre_impl_check: auto`, `risk_defaults.default_tier: standard`）で続行する。
3. **MCP Preflight（任意・助言のみ）**: `get_next_sdd_command` が利用可能なら参照してよいが、失敗しても停止せずファイルベースのルーティングを優先する。

## Routing & Flow（SDD Core 単一トラック）

### `adopt` / `investigate` / オプトイン専門ルート
- `adopt`: `/sdd-bootstrap:sdd-adopt [project-root]` へ委譲して終了。
- `investigate`: `/sdd-bootstrap:investigate-codebase <mode> <source>` へ委譲して終了。
- 外部一次資料調査が必要な場合は内部スキル `research-sources`、既存クラウド運用ユニットの明示操作は `sdd-azure-cloud:orchestrate` / `sdd-aws-cloud:orchestrate`、UI デザインシステム統合は `design-system/` 存在時のみ `design-sync-loop`、DDD モデルがある場合は `domain/` 存在時のみ `sdd-domain` を併用する（いずれも不在時のオーバーヘッドはゼロ）。

### `feature` / `bugfix` / `refactor` / `project`（標準フロー）

1. **Step 1 — 仕様・設計・タスク生成（`sdd-core-spec`）**:
   - `/sdd-bootstrap:sdd-core-spec` を実行し、`specs/<feature>/` に以下 3 ファイルを生成する:
     - `requirements.md`（目的・`REQ-NNN`・**検証可能な `AC-NNN`**・スコープ外・未決事項・`## Spec Amendments`）
     - `design.md`（方針・変更ファイル・IF/データ契約・影響範囲・テスト方針・`## Spec Amendments`）
     - `tasks.md`（`Approval: Draft`, `Status: Planned`, `Risk: low|standard|high`, `Scope`, `Done When`, `Blockers`, `## Spec Amendments`）
   - `Risk: high` のタスクを含む場合のみ、必要に応じて ADR（`docs/adr/`）や詳細な `acceptance-tests.md` を追加する。

2. **Step 2 — 統合軽量レビュー（`spec-check`・1体1パス）**:
   - `sdd/guardrails.yaml` の `review.pre_impl_check` に従って判定:
     - `off` または `--skip-check`、あるいは `auto` かつ全タスクが `Risk: low` → スキップして Step 3 へ。
     - それ以外 → `/sdd-review-loop:spec-check` を 1 回だけ実行し、`reports/spec-check/<feature>.md` を出力。
   - `PASS` / `PASS_WITH_NOTES` → そのまま Step 3 へ進む。
   - `NEEDS_FIX` → 指摘された Blocker と修正案を人間へ提示し、仕様を修正してから再度確認する。

3. **Step 3 — 人間による承認ゲート**:
   - 生成した仕様ファイル、各タスクの `Risk:`、未解決の `Open Questions`、`spec-check` 結果を人間へ提示する。
   - エージェントは `Approval: Approved` を書き込まない（`sdd-soft-guard.mjs` が自己承認を抑止）。
   - 人間が `specs/<feature>/tasks.md` の対象タスクを `Approval: Approved` に変更したら準備完了。

## Handoff

完了時に以下を簡潔に報告する:
- 生成された仕様ファイル一覧（`specs/<feature>/{requirements,design,tasks}.md`）
- `spec-check` 結果（実行した場合）と残る `Open Questions`
- 人間のアクション: `specs/<feature>/tasks.md` で対象タスクを `Approval: Approved` に変更
- 次のコマンド: `/sdd-ship:ship specs/<feature>/tasks.md`
