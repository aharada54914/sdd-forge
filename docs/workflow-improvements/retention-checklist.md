# WFI Retention Checklist

Verified になった WFI ごとに「再発検知条件」を1行で登録する台帳。
workflow-retrospective が毎回全行を走査し、条件に合致する証跡をこの期間の
レポート（reports/、docs/review-tickets/）から探す。再発を検知したら:

1. 該当 WFI の `Status:` を `Regressed` に変更し、証跡を `## Result` に追記する
2. この台帳から該当行を削除する
3. 再発を新しい friction pattern として扱い、follow-up WFI の候補にする

登録ルール:

- 1 WFI = 1 行。条件は機械的に判定できる形で書く（「〜が発生したら再発」）。
- 条件には検知対象のアーティファクト種別（review-ticket type、gate 報告の
  BLOCKED 理由、retrospective のメトリクス行など）を必ず含める。
- WFI が `Verified` になった retrospective の中でここに追記する。

| Source WFI | Verified 日 | 再発検知条件 |
|---|---|---|
| WFI-001 | 2026-07-06 | 高リスクタスクの quality-gate で persisted-evidence / traceability 不整合起因の修正チケットまたは 2 サイクル目以降の evidence 修正が発生したら再発 |
| WFI-002 | 2026-07-06 | manual-precheck-note.md(逸脱記録)なしで手動 precheck / 手動レビューゲート実行が行われた証跡が reports/ に現れたら再発 |
| WFI-003 | 2026-07-06 | retrospective Metrics 表に Run ID / Task Attempt Count 欠落起因の N/A セルが発生したら再発 |
| WFI-005 | 2026-07-12 | 実装レポート/ゲートレポートが deterministic consumer(evaluator 起動境界・check-evidence-bundle)に受理されるために書式後付け修正(retrofit)を要した証跡、または placeholder-scan の waiver 試行が contract に現れたら再発 |
| WFI-006 | 2026-07-12 | 1 feature の quality-gate レポートに stale-narrative-vs-current-state クラスの Minor 所見が 2 件以上記録される、または凍結済み実装レポートの stale 値をレビュアーが書き換えた/書き換え要求した証跡が現れたら再発 |
| WFI-007 | 2026-07-12 | 実装レポートが canonical パス(reports/implementation/<feature>/<task-id>.md)以外で first-commit され gate 段階で move/rename された、または evaluator 起動境界がレポートパス起因の PATH 失敗を返したら再発 |
| WFI-008 | 2026-07-19 | 新規完了フィーチャーの evidence bundle(specs/<feature>/verification/T-*.evidence.json)が参照するアーティファクトパスが git-tracked でない(git ls-files --error-unmatch 失敗)、または check-evidence-bundle.sh 相当の検証で欠落アーティファクトが検出されたら再発 |
| WFI-011 | 2026-07-19 | investigation.md/requirements.md/design.md の既存リポジトリ挙動に関する具体的・検証可能な事実主張が実装時 grep で誤りと判明した(quality-gate Critical Review Cycles の Minor/Accepted 所見クラス「spec-premise factual inaccuracy discovered only at implementation time」)ら再発 |

<!-- 記入例（WFI が Verified になったら追加する）:                                    -->
<!-- | WFI-001 | 2026-07-15 | 高リスクタスクの quality-gate で evidence-consistency -->
<!--   修正チケットが再び発生したら再発                                        | -->

註: WFI-004 の行は 2026-07-12 の retention check で再発検知（RT-20260712-003 =
Second Approval 行による frozen-artifact drift 偽陽性）により削除し、WFI-004 を
Status: Regressed とした。同欠陥の恒久修正は specs/second-approval-mask/（Done、
2026-07-12）で出荷済みであり、再発監視は同 feature の
tests/second-approval-mask.tests.sh（tests/run-all.sh 登録済み、39 checks）が
決定論的に担う。
