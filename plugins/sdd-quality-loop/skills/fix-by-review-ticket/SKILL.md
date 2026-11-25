---
name: fix-by-review-ticket
description: Apply a scoped fix for one repository review ticket under docs/review-tickets/, verify with scoped tests, and return the task to Implementation Complete for sdd-gate re-verification.
disable-model-invocation: true
---

# Fix By Review Ticket

`docs/review-tickets/` 配下のレビューチケット 1 件に対して最小限の修正を適用し、`sdd-gate` の再検証へ戻す。

## Process

1. チケットと関連する仕様（`specs/<feature>/*.md`）・実装・テストを読む。
2. `requires_human_decision: true`、対象不明確、またはチケット範囲を超える変更が必要な場合は停止して人間へ判断を仰ぐ。
3. チケット記載の最小修正のみを適用する。原因が自明でない不具合は `plugins/sdd-quality-loop/references/debugging-recovery-policy.md` に従って切り分け、テストの弱体化やハードコードで回避しない。
4. 必要なテストを追加・更新し、スコープ内のチェックを実行する。
5. 修正とテストが通った場合のみチケットを `resolved` とし、対象タスクを `Status: Implementation Complete` に戻す。
6. **2 回再発ルール**: 同一パターンの不具合・指摘が 2 回以上発生している場合は個別修正だけで終えず、共通ルール（`AGENTS.md` / `sdd/knowledge/`）・回帰テスト・`sdd-doctor` 検査への昇格を人間へ提案する。
7. `Done` にする前に、チケットの `target` の feature とタスクを明示して `/sdd-ship:ship specs/<feature>/tasks.md#<task>` を実行し、そのタスクだけ `sdd-gate` を再実行する（ship は `Implementation Complete` のタスクを実装せずゲートへ進む）。チケットの target に feature または task がない場合は推測せず停止し、人間に対象を確認する。

## Boundaries

- 無関係なリファクタ、仕様本文の無断改変、破壊的変更は行わない。
- `Approval:` や `Status: Done` は変更しない（`Done` は `sdd-gate` のみ）。
- 明示指示がない限り commit / push / PR 作成は行わない。
