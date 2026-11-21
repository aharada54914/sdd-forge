---
name: spec-check
description: Risk-scaled single-pass pre-implementation review for SDD Core specs. Auto-skips on Risk: low, runs single-reviewer pass on Risk: standard, and runs 2-perspective parallel pass (Spec/AC Reviewer A + Design/Security Reviewer B) on Risk: high.
disable-model-invocation: false
user-invocable: false
---

> **Caller**: `bootstrap` から呼び出される内部スキル。仕様ファイル自身は編集しない。

# Spec Check

着工前に仕様・設計・タスクの欠陥を検出するリスク連動 1 パスレビュー。

## Execution Mode

`sdd/guardrails.yaml` の `review.pre_impl_check` と `tasks.md` 内の最高 `Risk:` 階層で決定する:

| 条件 | `Review Mode` | 動作 |
|---|---|---|
| `off` / `--skip-check`、または `auto` かつ全タスク `Risk: low` | `skipped` | 自動スキップ |
| `Risk: standard`（既定） | **`single`** | 独立コンテキスト 1 体・1 パスで全 4 観点を点検 |
| **`Risk: high`** | **`dual-parallel`** | 独立コンテキスト 2 体並列・1 パス（Reviewer A + Reviewer B）を実行し 1 枚のレポートへ統合 |

> 並列サブエージェント未対応ホストで `dual-parallel` となった場合は、Reviewer A と Reviewer B を別コンテキストで順次 1 回ずつ実行し、第 2 視点を省略しない。

## Inputs

- `specs/<feature>/{requirements,design,tasks}.md`
- 存在する場合: `specs/<feature>/{investigation,baseline-behavior}.md`、関連ソースコード

## Review Perspectives

### `single`（`Risk: standard`）
1. **REQ ↔ AC**: 全 `REQ-NNN` に検証可能な `AC-NNN` が紐付いているか、曖昧表現や未決の重要 `Open Questions` が残っていないか。
2. **設計整合**: 変更ファイル・IF・依存関係が実コードと矛盾していないか。
3. **タスク分解**: `### Scope` / `### Done When` がテスト可能な粒度か、`### Blockers` に循環・欠落がないか、`Risk:` が妥当か。
4. **基本リスク**: 既存機能破壊やデータ不整合リスクの見落としがないか。

### `dual-parallel`（`Risk: high`）
- **Reviewer A（仕様・AC・エッジケース網羅）**: `REQ-NNN` ↔ `AC-NNN` の完全性、異常系・境界条件・権限不足の網羅、`tasks.md` の `Scope` / `Done When` / `Blockers` 整合性、未決事項確認。
- **Reviewer B（設計・セキュリティ・移行批判）**: 実コードとのアーキテクチャ整合、破壊的契約変更、認証/認可/入力検証/秘密情報管理、データ移行とロールバック手順の現実性、TDD / 回帰テスト戦略の十分性。

統合ルール:
- Reviewer A / B のいずれかに 1 件でも Blocker があれば総合判定は `NEEDS_FIX`。
- 重複指摘は統合し、見解が割れた論点は `Open Decisions for Human` に並記して人間判断へ委ねる。
- **報告直前の実在確認**: 統合レポート（`reports/spec-check/<feature>.md`）の書き込み後、親はファイルの実在と非空を直接確認してから `bootstrap` へ完了を返す。

## Verdict & Output

| Verdict | 条件 | 次の動作 |
|---|---|---|
| `PASS` | Blocker なし | 人間承認ゲートへ進む |
| `PASS_WITH_NOTES` | Blocker なし・軽微な Note のみ | Note を記録して人間承認ゲートへ進む |
| `NEEDS_FIX` | Blocker が 1 件以上 | Blocker と修正案を提示して停止（修正後に再実行） |

出力先: `reports/spec-check/<feature>.md`

```markdown
# Spec Check Report: <feature>

- **Verdict**: PASS | PASS_WITH_NOTES | NEEDS_FIX
- **Review Mode**: single | dual-parallel
- **Checked At**: <ISO-8601>
- **Highest Risk Tier**: low | standard | high

## Blockers (Must Fix Before Approval)
- None（または `[Reviewer A]` / `[Reviewer B]` 付きの欠陥と修正案）

## Notes (Advisory)
- None

## Open Decisions for Human
- None
```

## Boundaries

- `tasks.md` の `Approval:` や仕様ファイル本文を編集しない。
- 多重ラウンド番号や `--reset` 手続きは使わない。修正後は単純に再実行する。
