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
   `.sdd/factory-metrics.jsonl` と `.sdd/drift-events.jsonl` から、ゲート合格率・実行時間・人の介在回数・**誤りの原因工程（`requirements` / `design` / `code` / `test` / `harness`）**を集計する。合格率は **`Final Independent Reviews`（独立評価 G1〜G5 の最終 VERDICT）** を使い、`Mechanical Gate Runs` は独立評価前の機械チェック結果として区別して報告する（最終判定の記録がない期間は「n/a」とし、機械 PASS で代用しない）。
3. **品質ゲート実行証跡（`reports/quality-gate/`）**:
   `<feature>-<T-NNN>.execution.json` と `<feature>-<T-NNN>.md` はタスクごとに上書きされる**最新試行だけ**の記録である。FAIL/再実行回数と試行ごとのプレースホルダー検知数は、上書きされない `factory-metrics.mjs` の `attemptsByTask`（試行履歴）と `placeholderFindingsTotal` から集計し、最新ファイルは `UNDECLARED_DRIFT` など直近状態の確認に使う。
4. **レビュー・チケット・診断履歴**:
   - `reports/spec-check/<feature>.md`（`NEEDS_FIX` や頻出 Blocker）
   - `docs/review-tickets/`（種別・重大度・解決状況）
   - `reports/diagnosis/*.md`（繰り返し発生する不具合カテゴリ）
   - 過去の `reports/retrospective/*.md`・`docs/workflow-improvements/WFI-*.md`・`sdd/rejected-decisions.md`
5. **ドメイン適合ドリフト**：`domain/` がない場合はレポートの該当節を省略する。ある場合は対象機能・期間の保存済みレポートだけを読む。検査の再実行やドメインモデルからの推定は行わない。
   - 現行の `reports/quality-gate/<feature>-<T-NNN>.md` は対象タスクごとに1回読む。旧レポートは機能が一致し、タスク識別行（`Task ID:` または旧 `Task:`）と空でない `Run ID:` が各1行のものを使う。同じタスク・実行の複製はリポジトリ相対パスの辞書順で先頭の1件を採る。識別が曖昧なレポートは除外する。
   - `check-domain-conformance WARN` と `check-domain-conformance FAILED` の所見行を次の表で分類する。入力エラーなど、どちらにも該当しない行は集計から外す。

   | 指標 | 1件と数える所見 |
   |---|---|
   | Term-Deviation Count | `unrecognized term '...'`、`aggregate reference '...' not found in domain-contract.json aggregates`、`aggregate reference '...' has no domain/aggregates/....md card` |
   | Boundary-Violation Count | `Bounded-Context '...' not found in domain-contract.json`、`Bounded-Context lists two contexts (...) with no declared relation in context map` |

   `check-domain-conformance passed.` は0件と数える。検査結果が欠けていれば `Data Completeness` に記し、対象全件で結果がなければ件数は `N/A` とする。`N/A` は検査未実行を意味し、`0`（実行して指摘ゼロ）とは区別して報告する。v2 の `sdd-gate` はこの検査を自動実行しないため、記録は利用者が検査を実行して品質ゲート報告に出力行を残した場合だけ存在する。合計を同じ機能・集計範囲の前回値と比べ、比較できないときは傾向を `N/A` とする。

## Step 2: 既存改善（Applied WFI）の効果検証

新規提案の前に、`docs/workflow-improvements/WFI-*.md` のうち `Status: Applied` のものを実測値で評価する:
- 目標達成 → `Status: Verified`、再発条件を `docs/workflow-improvements/retention-checklist.md` に記録。
- 改善傾向・期間内 → `Status: Applied` のまま、WFI の `## Result` に `Needs-Followup: <評価日> <実測値> / 次回評価期限 <日付>` を追記する（`Needs-Followup` は Status 値ではない）。
- 期限切れ未達または悪化 → `Status: Rejected` とし、`Rollback-Plan` を人間へ提示（人間承認なしにロールバック実行しない）。

## Step 3: 改善候補の抽出とレポート出力

出力先: `reports/retrospective/<YYYYMMDD-HHMMSS>.md`

`domain/` がある場合は、下記の挿入位置に[レポートテンプレート](../../templates/retrospective-report.template.md#domain-drift-metrics)の3行を Step 1 の計測値で埋める。

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

<!-- domain/ がある場合にテンプレートの Domain Drift Metrics 節を挿入 -->

## Recurring Friction Patterns (2+ occurrences)
- 該当なし（今回改善候補なし）
<!-- 該当ありの場合: パターン名・根拠（Task ID / Ticket ID / Event ログ）・発生回数・昇格先（機械検査 / 規約・知見 / スキル）を記載 -->

## Proposed Improvements (Human Approval Required)
| ID | Category | 昇格先 | 対象ファイル | 根拠 | 測定指標・基準値→目標・評価時期 |
|---|---|---|---|---|---|
| WFI-NNN | plugin-improvement / app-dev-efficiency / human-process / measurement | 機械検査 / 規約・知見 / スキル | `AGENTS.md` 等 | `T-001, T-003` | <指標>: <基準値> → <目標>（<評価時期>） |

## Rejected / Deferred Decisions
- 今回見送った案は `sdd/rejected-decisions.md`（日付・案・不採用理由・再検討条件）へ追記提案する。
```

## Step 4: 反映（人間承認後のみ）

- 提案（`docs/workflow-improvements/WFI-NNN.md`、または `AGENTS.md` / `sdd/knowledge/` / `sdd/knowledge/review-perspectives.yaml` / `sdd/rejected-decisions.md` への追記）は **人間の承認後** のみ適用する。
- 人間レビューで発見された再発観点は `sdd/knowledge/review-perspectives.yaml` へ追加提案し、次回以降 AI・機械検証が先回りして検出できる範囲を広げる。
- 新規の `WFI-NNN.md`（`Status: Draft`）は `plugins/sdd-quality-loop/templates/workflow-improvement.template.md` を複製して起票し、監査員が検査する欄をレポートから引き継ぐ: `Category`（Step 3 の表の値）、`Mechanism`、`Meta-Change`（計測・ゲート・回顧ロジックに触れるなら `true`）、`GitHub-Issue`、`Audit-Status: Not-Started`（`Audit-Attempt: 0` / `Audit-Content-Hash: none`）、`Problem Evidence`（根拠の Task / Ticket ID・イベント）、`Why-Why Analysis`、`Root Cause Hypothesis`、`Proposed Change`、`Expected Effect`、`Verification Metric`（指標・基準値・目標・評価時期）、`Verification Plan`、`Rollback-Plan`。レポートから決まらない値は推測しない: `TBD（人間確認）` と明記し、監査前に人間へ確認を依頼する。
- 起票した Draft を人間レビュー前に 2 サイクル品質監査へ通すときは `wfi-audit-cycle` スキルを呼び出せる。
- 適用対象はプロジェクト側ファイル（`AGENTS.md`, `sdd/`, `specs/` テンプレート, テスト）に限定し、インストール済みプラグイン本体（`plugins/`）は直接書き換えない。
- 適用コミットには `WFI-NNN` を明記し、`git revert` で確実に戻せる状態を保つ。

## Boundaries

- アプリケーションコード・`Approval:`・`Status:`・レビューチケットを変更しない。
- `sdd/rejected-decisions.md` に既に「不採用」と記録された案は、再検討条件が満たされない限り再提案しない。
- 明示指示がない限り commit / push / PR 作成は行わない。
