---
name: spec-check
description: Risk-scaled single-pass pre-implementation review for SDD Core specs. Auto-skips on Risk: low, runs a single-reviewer integrated pass on Risk: standard, and runs a 2-perspective parallel pass (Spec/AC Reviewer A + Design/Security Reviewer B) on Risk: high without legacy multi-round state machines.
disable-model-invocation: false
user-invocable: false
---

# Spec Check（リスク連動・1 パス統合レビュー）

SDD Core（ADR-0051）の着工前レビュー。旧 `spec-review-loop` / `impl-review-loop` / `task-review-loop`（3 段階 × 2 体 × 最大 3 ラウンド・`attempt`/`--reset` 状態機械）を廃止し、**リスク階層に応じた 1 パスレビュー** へ一本化する。

## Risk-Scaled Execution Mode

`sdd/guardrails.yaml` の `review.pre_impl_check` と `tasks.md` 内の最高 `Risk:` 階層により実行形態を決定する:

| 条件（最高 `Risk:`） | `Review Mode` | 実行内容 |
|---|---|---|
| `pre_impl_check: off` または `--skip-check`、あるいは `auto` かつ全タスク `Risk: low` | `skipped` | 自動スキップして人間の承認ゲートへ進む |
| `Risk: standard`（既定） | **`single`** | 独立コンテキスト **1 体・1 パス** で下記 4 観点を一括点検 |
| **`Risk: high`** | **`dual-parallel`** | 独立コンテキスト **2 体並列・1 パス**（Reviewer A + Reviewer B）を実行し、1 枚のレポートへ統合（ラウンド番号・`--reset`・ハッシュ束縛は使わない） |

> **並列サブエージェント未対応ホストでの動作**: `Risk: high` 時に並列起動できない環境では、Reviewer A と Reviewer B を別プロンプト・別コンテキストで順次 1 回ずつ実行し、第 2 視点を黙って省略しない。

## Inputs

- `specs/<feature>/requirements.md`
- `specs/<feature>/design.md`
- `specs/<feature>/tasks.md`
- （存在する場合）`specs/<feature>/investigation.md` / `baseline-behavior.md` / 関連コード

## Review Perspectives

### `single` モード（`Risk: standard` — 1 体で 4 観点を一括点検）

1. **要件と受入条件の検証可能性（REQ ↔ AC）**: 全 `REQ-NNN` に観測・テスト可能な `AC-NNN` が紐付いているか、曖昧な表現や未解決の重要 `Open Questions` が残っていないか。
2. **設計整合性（Design ↔ Codebase）**: 変更対象ファイル・IF・依存関係が実コードと矛盾していないか。
3. **タスク分解と依存関係（Tasks）**: `### Scope` / `### Done When` がテスト可能な粒度か、`### Blockers` に循環や欠落がないか、`Risk:` 判定が妥当か。
4. **基本リスク確認**: 想定外の既存機能破壊やデータ不整合リスクが見落とされていないか。

### `dual-parallel` モード（`Risk: high` — 2 視点並列 × 1 パス）

高リスク案件（認証/認可・決済・PII・DB マイグレーション・破壊的契約変更など）では、以下の 2 視点を独立して並列実行し、盲点を相互補完する:

- **Reviewer A（仕様・AC・エッジケース網羅担当）**:
  - `REQ-NNN` ↔ `AC-NNN` の完全性・検証可能性・境界条件（異常系・権限不足・空/重複・タイムアウト等）の抜け漏れ
  - `tasks.md` の `Scope` / `Done When` / `Blockers` の整合性と検証可能性
  - スコープ外と要件の矛盾、未決 `Open Questions` の残存確認
- **Reviewer B（設計・セキュリティ・移行批判担当）**:
  - 実コードベースとのアーキテクチャ・IF 整合性、既存契約への破壊的影響
  - セキュリティ（認証・認可・秘密情報・入力検証）、データ整合性、マイグレーションとロールバック手順の現実性
  - テスト戦略（TDD Red→Green / 回帰範囲）の十分性

統合ルール:
- Reviewer A / B のどちらかに 1 件でも `Blocker` があれば総合判定は `NEEDS_FIX`。
- 両者の指摘が重複した場合は統合し、見解が割れた場合は `Open Decisions for Human` に並記して人間判断へ委ねる。

## Verdict Rules

| Verdict | 条件 | アクション |
|---|---|---|
| **`PASS`** | 致命的欠陥（Blocker）なし | そのまま人間の承認ゲートへ進む |
| **`PASS_WITH_NOTES`** | Blocker なし、軽微な改善提案（Note）のみ | Note を記録したうえで人間の承認ゲートへ進む（着工を止めない） |
| **`NEEDS_FIX`** | 手戻りが確実な Blocker が 1 件以上ある | Blocker と修正案を人間へ提示し、仕様を修正してから再度 `spec-check` を実行する |

## Output

レビュー結果を 1 枚の `reports/spec-check/<feature>.md` に保存する:

```markdown
# Spec Check Report: <feature>

- **Verdict**: PASS | PASS_WITH_NOTES | NEEDS_FIX
- **Review Mode**: single | dual-parallel
- **Checked At**: <ISO-8601>
- **Highest Risk Tier**: low | standard | high

## Blockers (Must Fix Before Approval)
- None (または `[Reviewer A]` / `[Reviewer B]` 付きの具体的な欠陥と修正案)

## Notes (Advisory)
- ...

## Open Decisions for Human (if any)
- None
```

## Boundaries

- `tasks.md` の `Approval:` を変更しない。
- 多重ラウンド状態機械（`attempt-N/round-M`、`--reset`、ハッシュ束縛）や外部署名生成は導入しない。修正後は単純に `spec-check` を再実行する。
- 仕様ファイルを勝手に書き換えず、修正が必要な場合のみ人間（または `bootstrap`）へ差し戻す。
