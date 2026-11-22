---
name: workflow-retrospective
description: Measure SDD Core workflow performance from deterministic logs (sdd-doctor, drift events, sdd-gate runs, review tickets) and propose evidence-backed rules, checks, or WFIs with human approval.
disable-model-invocation: false
user-invocable: false
---

> **Caller**: `/sdd-ship:ship --retro specs/<feature>/tasks.md` から呼び出される内部スキル。アプリコードやタスク承認状態は変更しない。

# Workflow Retrospective

SDD ワークフロー自体の摩擦・再発不具合を**事実ログから集計**し、人間承認のもとでルール・自動検査・知見を育てる。

## 設計原則

1. **事実検知（機械）と改善判断（Agent＋人）を分離する**: まずスクリプト・ログから事実を集め、主観的な感想で改善案を作らない。
2. **2 回再発ルール**: 同一パターンの不具合・ブロッカー・差し戻しが **2 回以上**（複数タスクまたは複数期間）観測された場合のみ改善候補に昇格する。単発の例外ではルールやスキルを増やさない。
3. **「今回候補なし（0 件）」を正常終了とする**: 根拠のある再発パターンが無ければ無理に提案を作らず、「候補なし」で終える。
4. **スキルより「機械検査・規約・知見」を優先する**:
   - **第 1 優先（機械検知）**: 回帰テスト、`run-sdd-gate.mjs` のコマンド、`sdd-doctor.mjs` への検査追加
   - **第 2 優先（規約・知見）**: `AGENTS.md` の判断基準、`sdd/knowledge/` の失敗履歴・作法、`specs/` テンプレート
   - **第 3 優先（スキル化）**: 同一の実行手順が **3 回以上** 反復し、規約やテストだけでは防げない場合のみ `create-project-skill` を検討
5. **採らない判断も残す**: 見送り・却下した提案は理由付きで `sdd/rejected-decisions.md` に記録し、別セッションでの再提案ループを防ぐ。

## Step 1: 機械的な事実収集（Read-Only）

以下を読み取り専用で集計する（存在しないものはスキップし、推測で補完しない）:

1. **ハーネス診断（`sdd-doctor.mjs`）**:
   ```bash
   node "<installed-root>/plugins/sdd-quality-loop/scripts/v2/sdd-doctor.mjs" --root "<repo-root>" --json
   ```
   `NG` / `WARN` / `INFO` の件数と項目をそのまま記録する。
2. **工場計測と原因工程遡及（`factory-metrics.mjs` & `.sdd/drift-events.jsonl`）**:
   単一フィーチャー（`<feature>`）を対象とする回顧では `--feature "<feature>"` を明示して対象フィーチャーのみを集計する。プロジェクト横断で複数フィーチャー全体を集計する場合のみ `--feature` を省略する:
   ```bash
   # 単一フィーチャーの回顧（既定: /sdd-ship:ship --retro specs/<feature>/tasks.md 経由）
   node "<installed-root>/plugins/sdd-quality-loop/scripts/v2/factory-metrics.mjs" \
     --root "<repo-root>" --feature "<feature>" --format markdown

   # プロジェクト横断の回顧（複数フィーチャー全体を集計する場合のみ）
   node "<installed-root>/plugins/sdd-quality-loop/scripts/v2/factory-metrics.mjs" \
     --root "<repo-root>" --format markdown
   ```
   `.sdd/factory-metrics.jsonl` と `.sdd/drift-events.jsonl` から、ゲート合格率・実行時間・人の介在回数・**誤りの原因工程（`requirements` / `design` / `code` / `test` / `harness`）**を集計する。
3. **品質ゲート実行証跡（`reports/quality-gate/`）**:
   `<feature>-<T-NNN>.execution.json` および `<feature>-<T-NNN>.md` から、FAIL/再実行回数・`UNDECLARED_DRIFT` 発生有無・プレースホルダー検知数を集計する。
4. **レビュー・チケット・診断履歴**:
   - `reports/spec-check/<feature>.md`（`NEEDS_FIX` や頻出 Blocker）
   - `docs/review-tickets/`（種別・重大度・解決状況）
   - `reports/diagnosis/*.md`（繰り返し発生する不具合カテゴリ）
   - 過去の `reports/retrospective/*.md`・`docs/workflow-improvements/WFI-*.md`・`sdd/rejected-decisions.md`
5. **ドメイン適合ドリフト（`domain/` が存在する場合のみ）**:
   `reports/quality-gate/` に記録済みの `check-domain-conformance` 指摘から用語逸脱・境界違反件数を集計する（`domain/` 不在時はセクションごと省略）。

## Step 2: 既存改善（Applied WFI）の効果検証

新規提案の前に、`docs/workflow-improvements/WFI-*.md` のうち `Status: Applied` のものを実測値で評価する:
- 目標達成 → `Status: Verified`、再発条件を `docs/workflow-improvements/retention-checklist.md` に記録。
- 改善傾向・期間内 → `Needs-Followup`。
- 期限切れ未達または悪化 → `Status: Rejected` とし、`Rollback-Plan` を人間へ提示（人間承認なしにロールバック実行しない）。

## Step 3: 改善候補の抽出とレポート出力

出力先: `reports/retrospective/<YYYYMMDD-HHMMSS>.md`

```markdown
# Retrospective Report: <feature>

- **Generated**: <ISO-8601>
- **Data Completeness**: Complete | Partial
- **Doctor Status**: CLEAN | WARN | NG (NG=<n>, WARN=<n>)

## Deterministic Summary
| Metric | Count / Value |
|---|---|
| Tasks Reviewed | <n> |
| sdd-gate Runs (PASS / FAIL) | <pass> / <fail> |
| Guard Events (deny / confirm / warn) | <d> / <c> / <w> |
| Review Tickets (critical / major / minor) | <c> / <m> / <min> |

## Recurring Friction Patterns (2+ occurrences)
- 該当なし（今回改善候補なし）
<!-- 該当ありの場合: パターン名・根拠（Task ID / Ticket ID / Event ログ）・発生回数・昇格先（機械検査 / 規約・知見 / スキル）を記載 -->

## Proposed Improvements (Human Approval Required)
| ID | 昇格先 | 対象ファイル | 根拠 | 期待効果 |
|---|---|---|---|---|
| WFI-NNN | 機械検査 / 規約・知見 / スキル | `AGENTS.md` 等 | `T-001, T-003` | <測定可能な効果> |

## Rejected / Deferred Decisions
- 今回見送った案は `sdd/rejected-decisions.md`（日付・案・不採用理由・再検討条件）へ追記提案する。
```

## Step 4: 反映（人間承認後のみ）

- 提案（`docs/workflow-improvements/WFI-NNN.md`、または `AGENTS.md` / `sdd/knowledge/` / `sdd/knowledge/review-perspectives.yaml` / `sdd/rejected-decisions.md` への追記）は **人間の承認後** のみ適用する。
- 人間レビューで発見された再発観点は `sdd/knowledge/review-perspectives.yaml` へ追加提案し、次回以降 AI・機械検証が先回りして検出できる範囲を広げる。
- 新規の `WFI-NNN.md`（`Status: Draft`）を起票した場合、人間レビュー前に 2 サイクル品質監査を通すときは `wfi-audit-cycle` スキルを呼び出せる。
- 適用対象はプロジェクト側ファイル（`AGENTS.md`, `sdd/`, `specs/` テンプレート, テスト）に限定し、インストール済みプラグイン本体（`plugins/`）は直接書き換えない。
- 適用コミットには `WFI-NNN` を明記し、`git revert` で確実に戻せる状態を保つ。

## Boundaries

- アプリケーションコード・`Approval:`・`Status:`・レビューチケットを変更しない。
- `sdd/rejected-decisions.md` に既に「不採用」と記録された案は、再検討条件が満たされない限り再提案しない。
- 明示指示がない限り commit / push / PR 作成は行わない。
