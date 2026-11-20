---
name: ship
description: Implement approved SDD Core tasks under lightweight soft guardrails, verify with sdd-gate (deterministic tests + spec-drift check + independent 1-pass review), and transition passed tasks to Done.
disable-model-invocation: true
---

# SDD Ship (SDD Core v2)

承認済みタスクを実装から品質検証・`Done` まで一貫して進める、2 コマンドワークフローの第 2 ステップ（ADR-0051）。
ローカルの過剰な物理ロックやカナリア儀式を排し、**ベースライン記録 → 自律実装（ソフトガード保護）→ 統合 `sdd-gate`** のシンプルな 3 段構成で高 DX と仕様保全を両立する。

## Invocation

Claude Code / Gemini CLI:

```txt
/sdd-ship:ship specs/<feature>/tasks.md
/sdd-ship:ship specs/<feature>/tasks.md#T-001
/sdd-ship:ship
```

Codex CLI / Copilot CLI:

```txt
Use the ship skill for specs/<feature>/tasks.md
Use the ship skill (no argument — auto-select single approved active feature)
```

### Flags

| Flag | 効果 |
|---|---|
| `--skip-drift` | 緊急時のみ Spec Drift チェックをスキップ（レポートに明記される） |
| `--retro` | 全タスク `Done` 後に任意の回顧を実行 |
| `--lite` / `--full` *(互換エイリアス)* | v2 ではトラック分岐を廃止。指定されても停止せず単一の `SDD Core` フロー（各タスクの `Risk:` に従う）で実行する |

## Preconditions

1. リポジトリルートに `AGENTS.md` が存在すること（未整備時は `/sdd-bootstrap:bootstrap adopt` を案内して停止）。
2. **MCP Preflight（任意・助言のみ）**: `get_next_sdd_command` が利用可能なら参照してよいが、ファイルベースの対象選定を常に正とする。
3. 進捗ダッシュボードが要求された場合は `/sdd-ship:status` の読み取り専用表示を併用できる（画面表示だけで承認・Done は進まない）。

## Step 1 — Target Selection

- 引数 `specs/<feature>/tasks.md`（または `#T-NNN`）があればそれを対象とする。
- 引数なしの場合、`AGENTS.md` の `## Active Spec Directories`（または `specs/*/tasks.md`）から `Approval: Approved` かつ `Status: Planned` / `In Progress` のタスクを持つフィーチャーを探す:
  - 1 件一致 → `[sdd-ship AUTO-SELECT] specs/<feature>/tasks.md` を表示して続行。
  - 0 件 → 承認済みタスクが無い旨を案内して停止。
  - 複数一致 → 候補一覧を表示し、パス指定での再実行を案内して停止。

## Step 2 — Baseline Snapshot（ソフトガードレール有効化）

最初の実装タスクに着手する**前**に、`specs/<feature>/.spec-baseline.json` の存在を確認する。
まだ存在しない場合は、承認済み仕様のスナップショットを自動記録する（外部署名鍵は不要）:

```bash
node "<installed-root>/plugins/sdd-quality-loop/scripts/v2/record-spec-baseline.mjs" \
  --feature "<feature>" --root "<repo-root>"
```

これにより、実装中に承認済み仕様本文（REQ / AC / Design）が意図せず書き換えられた場合、
- **Layer 1**: `sdd-soft-guard.mjs` が編集時に `confirm` / `warn` / `strict` で検知・抑止し、
- **Layer 2**: `sdd-gate` と CI の `check-spec-drift.mjs` が無断改変・AC 削除を確実に捕捉する。

## Step 3 — Autonomous Implementation Loop

対象となる承認済みタスク（`Approval: Approved` かつ `Status: Planned` または `In Progress`）を実装する:
- 単一タスク（`#T-NNN` 指定）→ `/sdd-implementation:implement-task specs/<feature>/tasks.md#T-NNN`
- 複数タスク → `/sdd-implementation:implement-tasks specs/<feature>/tasks.md`（`### Blockers` の依存順に実行）

実装ルール:
- 通常のソース編集・テスト実行・`Bash` 探索はソフトガードによって一切妨げられない。
- 実装中に仕様の誤り・変更必要性に気づいた場合は、勝手に仕様本文を書き換えてテストを通そうとせず、ユーザーへ相談して合意のうえ `## Spec Amendments` に理由を追記してから修正する。
- 中断後の再実行時は、既に `Implementation Complete` / `Done` のタスクをスキップして再開する。

## Step 4 — Unified Quality Gate（`sdd-gate`）

対象タスクが `Status: Implementation Complete` に到達したら、各タスクについて `/sdd-quality-loop:sdd-gate` を実行する:

1. `run-sdd-gate.mjs` により以下を 1 回で決定論的に検証:
   - タスク状態（`Approval: Approved` / `Implementation Complete`）
   - **Spec Drift 検査**（`CLEAN` / `AMENDED` は通過、`UNDECLARED_DRIFT` は FAIL）
   - 変更コードのプレースホルダー検査
   - プロジェクトの lint / typecheck / build / test 実行（`reports/quality-gate/<feature>-<task-id>.execution.json` 出力）
2. 独立コンテキストによる 1 パスレビュー（`AC-*` 充足確認、`AMENDED` 時の理由妥当性確認、回帰リスク確認、`Risk: high` 時のセキュリティ/移行確認）。
3. **PASS**: `reports/quality-gate/<feature>-<task-id>.md` に `VERDICT: PASS` を記録し、`tasks.md` の対象タスクを `Status: Done` へ更新。
4. **FAIL**: 失敗理由（テスト失敗 / プレースホルダー / `UNDECLARED_DRIFT` / 独立レビュー指摘）を明示して停止し、`Status: Implementation Complete` のまま修正を促す。

## Handoff

完了時に以下を報告する:
- 各タスクの最終状態（`Done` / `FAIL` / `Blocked`）
- `Spec Drift` ステータス（`CLEAN` / `AMENDED` — `AMENDED` の場合は PR 説明文へ転記できる変更要約を添付）
- 生成された品質レポートと実行証跡パス（`reports/quality-gate/`）
