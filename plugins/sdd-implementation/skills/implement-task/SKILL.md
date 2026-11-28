---
name: implement-task
description: Restore SDD task state and implement one approved task within its Scope and Done When, then hand off at Implementation Complete for sdd-gate.
disable-model-invocation: false
user-invocable: false
---

> **Caller**: `ship`（または `implement-tasks`）から呼び出される内部スキル。下流スキルを自動起動せず、`Implementation Complete`（または `Blocked`）で制御を返す。

# Implement Task

承認済みタスク 1 件を仕様通りに実装・テストし、`sdd-gate` による独立検証へ渡す。

## Preconditions

1. ルートに `AGENTS.md` が存在すること（不在時は `/sdd-bootstrap:bootstrap adopt` を案内して停止）。
2. 対象タスクが `Approval: Approved` であること（`Draft` タスクは着手禁止）。

## Required Reading

- `AGENTS.md`、`specs/<feature>/{requirements,design,tasks}.md`
- 存在する場合: `specs/<feature>/codemap.md`（探索前に読む）、`references/implementation-policy.md`、`references/implementation-craft-policy.md`
- `sdd/pitfalls-catalog.json` が存在する場合: `<installed-root>/plugins/sdd-implementation/scripts/inject-pitfalls.mjs --root <repo-root> --files <変更予定ファイル...>` で該当言語・領域の落とし穴（Progressive Disclosure）だけを抽出して確認する
- UI タスクかつ `design-system/` 存在時: `design-system/design-system.md`、`design-system/ui-patterns.md`
- SQL / DB スキーマ変更時: `../sql-develop/references/sql-development-policy.md`（隔離 DB 検証まで。本番・共有 DB へは接続しない）

## Process

1. **状態復元**: `tasks.md` で対象タスク（`Approval: Approved` かつ `Planned` / `In Progress`）と `git status` / `git diff` を確認する。無関係な既存変更は保持し、スコープと競合するなら `Blocked` にして停止する。
2. **着工**: 対象タスクを `Status: In Progress` に更新する。
3. **薄い縦切り実装**: `### Scope` と `### Done When` の範囲のみを実装し、スライスごとにテストを実行して挙動を確認する。
4. **テスト整備**:
   - 対応する `AC-NNN` を検証する単体・結合テストと関連回帰テストを実行する。
   - `Risk: high` のタスクでは TDD（先に失敗するテストを書いて赤を確認 → 実装して緑を確認）を基本とし、テスト出力を実装レポートへ記録する。
5. **UI 視覚確認（該当時のみ）**: UI レイヤー変更かつ `design-system/` またはモックアップがある場合は `visual-verify-loop`（助言的・非ブロッキング）を実行し、結果をレポートへ残す。
6. **スコープ内自己点検**: 変更差分にプレースホルダー（`TODO` / `FIXME`）やスコープ外変更が混入していないか確認する。
7. **実装レポート作成**: `../../templates/implementation-report.template.md` を使い `reports/implementation/<feature>/<task-id>.md` を作成する。
8. **完了ハンドオフ**: 実装・テスト・レポートがすべて揃ったら `Status: Implementation Complete` に更新して呼び出し元へ返す。

## Block And Stop

以下のいずれかに該当する場合は推測で進めず、`Status: Blocked` と `### Blockers` を記録して停止する:
- 要件・設計が曖昧、または業務・認証/認可・破壊的 API 判断が必要
- 実装中に承認済み仕様の変更が必要と判明（無断で仕様本文を書き換えず、ユーザーと合意して `## Spec Amendments` に理由を追記してから進める）
- 必須テストを実行できない、または無関係な変更と競合する

## Boundaries

- `Approval: Approved` は絶対に書き込まない（人間のみ）。
- `Status: Done` は絶対に書き込まない（`sdd-gate` のみ）。
- 承認済み仕様本文をテスト通過のために無断で緩和・削除しない。
- 明示指示がない限り commit / push / PR 作成は行わない。
