---
name: ship
description: Implement approved SDD Core tasks under lightweight soft guardrails, verify with sdd-gate (deterministic checks + Spec Drift + independent 1-pass review), and transition passed tasks to Done.
disable-model-invocation: true
---

# SDD Ship

承認済みタスクを「ベースライン固定 → 自律実装 → 統合 `sdd-gate` → `Done`」まで進めるエントリポイント。

## Invocation

```txt
/sdd-ship:ship specs/<feature>/tasks.md
/sdd-ship:ship specs/<feature>/tasks.md#T-001
/sdd-ship:ship
```

### Flags

- `--skip-drift`: 緊急時のみ Spec Drift チェックをスキップ（レポートに明記）。
- `--retro`: 全タスク `Done` 後に任意の回顧を実行。
- `--lite` / `--full` *(互換エイリアス)*: 停止せず単一の標準フロー（各タスクの `Risk:` に従う）で実行する。

## Preconditions

1. ルートに `AGENTS.md` が存在すること（不在時は `/sdd-bootstrap:bootstrap adopt` を案内して停止）。
2. オプトイン MCP（`sdd_project_overview` / `sdd_feature_state` / `sdd_gate_audit`）が有効な場合は参考参照してよいが、対象選定はファイル状態を正とする。
3. 進捗ダッシュボード表示が必要な場合は、ユーザーへ公開コマンド `/sdd-ship:status`（読み取り専用）の実行を案内する。

## Flow

### Step 1 — 対象選定
- 引数 `specs/<feature>/tasks.md`（または `#T-NNN`）があればそれを対象とする。
- 引数なし時は `AGENTS.md` の `## Active Spec Directories`（または `specs/*/tasks.md`）から `Approval: Approved` かつ `Status: Planned` / `In Progress` のタスクを持つフィーチャーを探す（1 件一致なら自動選択、0 件または複数一致なら一覧を表示して停止）。

### Step 2 — 実行ロック取得 & 仕様ベースライン固定
二重起動・並列書込衝突を防ぐため `task-lock.mjs` で排他ロックを取得し、実装開始前に `specs/<feature>/.spec-baseline.json` が無ければ記録する（完了または異常終了時に `task-lock.mjs release` で解放）:

```bash
node "<installed-root>/plugins/sdd-quality-loop/scripts/v2/task-lock.mjs" \
  acquire --feature "<feature>" --root "<repo-root>"
node "<installed-root>/plugins/sdd-quality-loop/scripts/v2/record-spec-baseline.mjs" \
  --feature "<feature>" --root "<repo-root>"
```

### Step 3 — 実装フェーズ
- 単一タスク（`#T-NNN` 指定）→ `/sdd-implementation:implement-task specs/<feature>/tasks.md#T-NNN`
- 複数タスク → `/sdd-implementation:implement-tasks specs/<feature>/tasks.md`（`check-traceability.mjs --plan-batches` による依存順・非重複 Scope 並列で実行）
- 中断後の再実行時は `Implementation Complete` / `Done` 済みタスクをスキップして再開する。
- 仕様変更（`AMENDED`）によるフォローアップ時は `<installed-root>/plugins/sdd-quality-loop/scripts/v2/check-traceability.mjs --feature <feature> --changed-ids <REQ/AC>` で影響タスク（`### Blockers` の推移的依存を含む）のみを抽出し、未影響の完了タスクを再利用する。
- UI / フロントエンド変更を含むタスクでは、必要に応じて `visual-verify-loop` で実ブラウザ動作確認を行う。
- **自動修正上限**: `sdd/guardrails.yaml` の `limits.max_auto_fix_rounds`（既定 2 回）を超えても収束しない論点は無理に再試行を続けず、`OQ-NNN` として整理して人間判断へエスカレーションする。
- 実装中に仕様変更が必要になった場合は本文を無断修正せず、ユーザーと合意のうえ `## Spec Amendments` に理由を追記してから反映する（`--proto` 試作で前提不整合が判明した場合は Scrap & Build を提案）。

### Step 4 — 品質ゲート（`sdd-gate`）
対象タスクが `Status: Implementation Complete` に到達したら、各タスクに対して `/sdd-quality-loop:sdd-gate` を実行する（`run-sdd-gate.mjs` が Spec Drift・プレースホルダー・SQL/Cloud/Secret 非機能センサー・`Risk: high` 時の未確定 `OQ-NNN` を一括検証し、`.sdd/factory-metrics.jsonl` へ計測を記録する）:
- `PASS`: `reports/quality-gate/<feature>-<task-id>.md` に `VERDICT: PASS` を記録し、`Status: Done` へ遷移。全タスク `Done` かつ確定 `OQ-NNN` / `Spec Amendments` / `Alternatives Rejected` がある場合は `sync-knowledge.mjs extract --feature <feature>` でナレッジ還流案を提示する。
- `FAIL`: 失敗理由と原因工程（`requirements` / `design` / `code` / `test` / `harness`）を `factory-metrics.mjs record-attribution` へ記録し、報告して停止（`Status` は `Implementation Complete` のまま保持）。

### Step 5 — 回顧（`--retro` 指定時のみ）
全対象タスクが `Status: Done` に到達し、`--retro` が指定されている場合は `workflow-retrospective` スキルを呼び出し、事実ログ（`sdd-doctor.mjs`, `.sdd/drift-events.jsonl`, `reports/quality-gate/`）から改善候補を抽出してレポートを出力する。

## Handoff

完了時に以下を報告する:
- 各タスクの最終状態（`Done` / `FAIL` / `Blocked`）
- `Spec Drift` ステータス（`CLEAN` / `AMENDED` — `AMENDED` 時は PR 用要約を添付）
- レポートおよび実行証跡パス（`reports/quality-gate/`）
