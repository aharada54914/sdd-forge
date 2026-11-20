---
name: spec-check
description: Single-pass, single-reviewer integrated pre-implementation review for SDD Core specs (requirements, ACs, design, and tasks). Replaces the legacy three-loop review ceremony while catching ambiguity and design flaws before coding.
disable-model-invocation: false
user-invocable: false
---

# Spec Check（統合軽量レビュー・1パス）

SDD Core（ADR-0051）の着工前レビュー。旧 `spec-review-loop` / `impl-review-loop` / `task-review-loop`（3 段階 × 2 体 × 最大 3 ラウンド）を、**独立コンテキストによる 1 体・1 パスの統合チェック** へ一本化し、開発スピードを維持しつつ設計抜け漏れ・曖昧な受入条件を着工前に防ぐ。

## When to Run

- `sdd/guardrails.yaml` の `review.pre_impl_check`:
  - `auto`（既定）: タスクに `Risk: standard` または `Risk: high` が含まれる場合に実行。全タスクが `Risk: low` の場合は自動スキップ。
  - `always`: リスクに関わらず実行。
  - `off`（または `--skip-check`）: スキップ。

## Inputs

- `specs/<feature>/requirements.md`
- `specs/<feature>/design.md`
- `specs/<feature>/tasks.md`
- （存在する場合）`specs/<feature>/investigation.md` / `baseline-behavior.md` / 関連コード

## Review Checklist（4 観点・1 パス）

仕様作成者とは独立したレビュー観点で、以下 4 項目を一度に点検する:

1. **要件と受入条件の検証可能性（REQ ↔ AC）**:
   - すべての `REQ-NNN` に検証可能な `AC-NNN` が紐付いているか？
   - 「適切に処理する」「高速に動く」のような曖昧な表現が残っていないか？
   - 重要な未決事項が `Open Questions` に埋もれたまま着工しようとしていないか？
2. **設計整合性（Design ↔ Codebase）**:
   - 変更対象ファイル・既存インターフェース・依存関係が実コードと矛盾していないか？
   - 既存パターンを不必要に壊したり、影響範囲を見落としたりしていないか？
3. **タスク分解と依存関係（Tasks）**:
   - 各タスクの `### Scope` と `### Done When` が明確で、テスト可能な粒度になっているか？
   - `### Blockers` に循環依存や欠落がないか？
   - `Risk:` 階層（`low` / `standard` / `high`）が変更内容と合致しているか？
4. **高リスク追加点検（`Risk: high` タスクがある場合のみ）**:
   - 認証/認可・データ整合性・マイグレーション・ロールバック手順・エラー時挙動が `design.md` に明記されているか？

## Verdict Rules

| Verdict | 条件 | アクション |
|---|---|---|
| **`PASS`** | 致命的欠陥（Blocker）なし | そのまま人間の承認ゲートへ進む |
| **`PASS_WITH_NOTES`** | Blocker なし、軽微な改善提案（Note）のみ | Note を記録したうえで人間の承認ゲートへ進む（着工を止めない） |
| **`NEEDS_FIX`** | 実装すると手戻りが確実な Blocker が 1 件以上ある | Blocker と修正案を人間へ提示し、仕様を修正してから再実行する |

## Output

簡潔なレビュー結果を `reports/spec-check/<feature>.md` に保存する:

```markdown
# Spec Check Report: <feature>

- **Verdict**: PASS | PASS_WITH_NOTES | NEEDS_FIX
- **Checked At**: <ISO-8601>
- **Highest Risk Tier**: low | standard | high

## Blockers (Must Fix Before Approval)
- None (または具体的な欠陥と修正案)

## Notes (Advisory)
- ...
```

## Boundaries

- `tasks.md` の `Approval:` を変更しない。
- 複数ラウンドの自動ループや 2 体ブラインド実行、暗号署名・provenance 生成は行わない。
- 仕様ファイルを勝手に書き換えず、修正が必要な場合のみ人間（または `bootstrap`）へ差し戻す。
