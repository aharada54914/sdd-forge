---
name: implement-tasks
description: Batch-implement all approved tasks in dependency order (parallelizing disjoint tasks where supported) and return control to ship once tasks reach Implementation Complete.
disable-model-invocation: false
user-invocable: false
---

> **Caller**: `ship` から呼び出される内部スキル。各タスクを `Implementation Complete` まで進め、`sdd-gate` 自体は自動起動せず `ship` へ制御を返す。

# Implement Tasks (Batch)

承認済みタスク群を `### Blockers` の依存順に処理し、独立したタスクを効率よく完了させるバッチオーケストレータ。

## Preconditions

- ルートに `AGENTS.md` が存在すること（不在時は `/sdd-bootstrap:sdd-adopt` を案内して停止）。
- `specs/<feature>/tasks.md` に `Approval: Approved` かつ `Status: Planned` / `In Progress` のタスクが 1 件以上存在すること。

## Task Selection

各パスの開始時に `tasks.md` と `check-traceability.mjs --feature <feature> --plan-batches` の結果（依存順 Wave と Scope 衝突検知）を読み、実行可能集合を抽出する（`task-lock.mjs acquire` で feature ロックを確保し二重起動を防止する）:

1. **対象条件**: `Approval: Approved` かつ `Status: Planned` または `In Progress`。
2. **依存解決**: `### Blockers` に `T-\d+` 参照がある場合、参照先タスクがすべて `Implementation Complete` または `Done` になるまで除外する（`None` または空なら依存なし）。
3. **独立集合（並列実行可能）**: 依存のない対象タスクのうち、`### Scope` の変更ファイルが互いに重複しない最大集合を選ぶ（同一ファイルに触れるタスクは記載順で先頭のみ採用し、残りは次パスへ回す）。
4. 実行可能なタスクが 0 件になったらループを終了し、残タスクの状態（未承認 / 依存待ち / Blocked / 全完了）をまとめて `ship` へ返す。

## Execution Loop

1. 独立集合が 1 件、またはサブエージェント未対応環境では、`implement-task` の手順で順次実行する。
2. 独立集合が 2 件以上かつサブエージェント対応環境では、各タスクに新鮮なワーカーを割り当てて並列実行する（上限: Claude Code 最大 4 並列、他環境はホスト上限内）。
3. **共有状態の書き込み責務**: `specs/<feature>/tasks.md` の `Status:` 更新はオーケストレータが一元管理し、並列ワーカー間で同時書き込みを起こさない。
4. **報告直前の実在確認（空報告防止）**: 各ワーカーは完了報告直前に変更ファイルの実在とテスト実実行結果を確認する。オーケストレータも受領時に `git status` / 変更ファイル実在を確認してから `Status: Implementation Complete` へ更新する。
5. **Fail-fast**: いずれかのタスクが `Blocked` を返したら、新しいパスの起動を停止し、ブロッカー内容を `ship` へ報告する。
6. 全ワーカーの完了を待ったあと、再度 Task Selection を評価し、依存が解けた次パスがあれば続行する。

## Boundaries

- `Approval: Approved` は絶対に書き込まない（人間のみ）。
- `Status: Done` への遷移および `sdd-gate` の起動は行わない（呼び出し元 `ship` の責務）。
- 承認済み仕様本文を無断で書き換えない（仕様変更が必要なら `Blocked` にして人間へ確認する）。
- 明示指示がない限り commit / push / PR 作成は行わない。
