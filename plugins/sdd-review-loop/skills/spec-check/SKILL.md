---
name: spec-check
description: Risk-scaled single-pass pre-implementation review for SDD Core specs with strict perspective parity (P1-P6). Runs 1 independent reviewer on Risk: standard and 2 parallel independent reviewers on Risk: high over the exact same 6 canonical perspectives.
disable-model-invocation: false
user-invocable: false
---

> **Caller**: `bootstrap` から呼び出される内部スキル。仕様ファイル自身や `Approval:` は絶対に編集しない。

# Spec Check

着工前に仕様・設計・タスクの欠陥を検出するリスク連動 1 パスレビュー。
**設計原則（Perspective Parity）**: リスク階層で変わるのは「独立コンテキスト数と探索深度」のみであり、**点検する観点（P1〜P6）は `single` でも `dual-parallel` でも 100% 同一**とする。対象外の面がある場合は暗黙省略せず `N/A（理由）` を明記する。

## Execution Mode

`sdd/guardrails.yaml` の `review.pre_impl_check` と `tasks.md` 内の最高 `Risk:` 階層で決定する:

| 条件 | `Review Mode` | エージェント構成 | 点検観点 |
|---|---|---|---|
| `off` / `--skip-check`、または `auto` かつ全タスク `Risk: low` | `skipped` | 0 体（着工前スキップ、後段 `sdd-gate` で全 G1〜G5 検証） | — |
| `Risk: standard`（既定）または `always` かつ `low` | **`single`** | 独立コンテキスト 1 体（`spec-reviewer-a`）・1 パス | **P1〜P6 全 6 観点** |
| **`Risk: high`** | **`dual-parallel`** | 独立コンテキスト 2 体並列（`spec-reviewer-a` + `spec-reviewer-b`）・1 パス | **同一 P1〜P6 全 6 観点**（A: P1/P3/P6, B: P2/P4/P5） |

> 並列サブエージェント未対応ホストで `dual-parallel` となった場合は、`spec-reviewer-a` と `spec-reviewer-b` を別コンテキストで順次 1 回ずつ実行し、第 2 視点を省略しない。

## Inputs

- `specs/<feature>/{requirements,design,tasks}.md`
- 存在する場合: `specs/<feature>/{investigation,codemap,baseline-behavior}.md`、関連ソースコード、`domain/domain-contract.json`、`design-system/`

## Canonical Review Perspectives（統一 6 観点・P1〜P6）

| ID | 観点 | 検査基準 | `single` 担当 | `dual-parallel` 担当 |
|---|---|---|---|---|
| **P1** | **REQ ↔ AC・異常系/境界条件** | 全 `REQ-NNN` に観測・テスト可能な `AC-NNN` が紐付き、異常系・境界条件・権限不足・空状態・曖昧表現が潰されているか | Reviewer A | Reviewer A |
| **P2** | **設計整合・破壊的変更・採らなかった設計** | `design.md` の変更ファイル・IF/データ契約が実コードと矛盾せず、破壊的契約変更の影響と `採らなかった設計（Alternatives Rejected）` の妥当性が妥当か | Reviewer A | Reviewer B |
| **P3** | **タスク分解・依存・テスト戦略** | `tasks.md` の `### Scope` / `### Done When` がテスト可能な粒度か、`### Blockers` に循環・欠落がないか、`Risk:` 判定と TDD/回帰テスト戦略が妥当か | Reviewer A | Reviewer A |
| **P4** | **セキュリティ・非機能境界** | 認証/認可・入力検証・秘密情報管理・SQL 破壊操作/性能・Cloud 権限/ネットワーク境界に欠陥がないか（無関係時は `N/A（理由）`） | Reviewer A | Reviewer B |
| **P5** | **データ移行・ロールバック・既存破壊リスク** | スキーマ/データ移行・ロールバック手順の現実性と既存機能への回帰リスクが検討されているか（無関係時は `N/A（理由）`） | Reviewer A | Reviewer B |
| **P6** | **未決 `OQ-NNN`・ドメイン/デザイン規約整合** | 重要 `Open Questions`（特に `Risk: high` 時の未確定 `OQ-NNN`）が残存していないか、`domain/`（`Bounded-Context:`・正典用語・概念境界）や `design-system/` との乖離がないか | Reviewer A | Reviewer A |

## Integration Rules

- **レビュー対象の鮮度固定（`Review-Inputs-SHA256`）**:
  - 独立レビューを起動する**前**と評価者の返答を受け取った**後**に、同じコマンドで仕様 3 文書の入力ハッシュを採取して一致を確認する:
    ```bash
    node "<installed-root>/plugins/sdd-quality-loop/scripts/v2/render-decision-view.mjs" \
      --feature "<feature>" --root "<repo-root>" --format review-hash
    ```
  - 前後でハッシュが一致した場合のみ、そのダイジェストをレポートヘッダーの `- **Review-Inputs-SHA256**: <digest>` に記録する（レビュー中に仕様が書き換わって不一致になった場合は再レビューする。旧レポートへ後からハッシュだけを書き足さない）。
- Reviewer A / B のいずれかに 1 件でも Critical / Major（Blocker）があれば総合判定は `NEEDS_FIX`。
- 重複指摘は統合し、見解が割れた論点は `Open Decisions for Human` に両論併記して人間判断へ委ねる。
- **報告直前の実在確認**: 統合レポート（`reports/spec-check/<feature>.md`）の書き込み後、親はファイルの実在と非空を直接確認してから `bootstrap` へ完了を返す。

## Verdict & Output

| Verdict | 条件 | 次の動作 |
|---|---|---|
| `PASS` | Blocker なし（P1〜P6 全点検済み） | 人間承認ゲート（Decision View）へ進む |
| `PASS_WITH_NOTES` | Blocker なし・軽微な Note のみ | Note を記録して人間承認ゲートへ進む |
| `NEEDS_FIX` | Blocker が 1 件以上 | Blocker と修正案を提示して停止（修正後に再実行） |

出力先: `reports/spec-check/<feature>.md`

```markdown
# Spec Check Report: <feature>

- **Verdict**: PASS | PASS_WITH_NOTES | NEEDS_FIX
- **Review-Inputs-SHA256**: <64-hex-sha256>
- **Review Mode**: single | dual-parallel
- **Checked At**: <ISO-8601>
- **Highest Risk Tier**: low | standard | high

## Perspective Coverage (P1–P6)
- P1 (REQ/AC & Edge Cases): PASS | FAIL | N/A (<reason>)
- P2 (Design & Alternatives Rejected): PASS | FAIL | N/A (<reason>)
- P3 (Tasks, Blockers & Test Strategy): PASS | FAIL | N/A (<reason>)
- P4 (Security & Non-Functional): PASS | FAIL | N/A (<reason>)
- P5 (Migration, Rollback & Regression): PASS | FAIL | N/A (<reason>)
- P6 (OQ-NNN & Domain/Design-System): PASS | FAIL | N/A (<reason>)

## Blockers (Must Fix Before Approval)
- None（または `[P#][Reviewer A|B]` 付きの欠陥と修正案）

## Notes (Advisory)
- None

## Open Decisions for Human
- None
```

## Boundaries

- `tasks.md` の `Approval:` や仕様ファイル本文を編集しない。
- 多重ラウンド番号や `--reset` 手続きは使わない。修正後は単純に再実行する。
