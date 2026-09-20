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
| WFI-002 | 2026-07-06 | manual-precheck-note.md(逸脱記録)なしで手動 precheck / 手動レビューゲート実行が行われた証跡が reports/ に現れたら再発 |
| WFI-007 | 2026-07-12 | 実装レポートが canonical パス(reports/implementation/<feature>/<task-id>.md)以外で first-commit され gate 段階で move/rename された、または evaluator 起動境界がレポートパス起因の PATH 失敗を返したら再発 |
| WFI-008 | 2026-07-19 | 新規完了フィーチャーの evidence bundle(specs/<feature>/verification/T-*.evidence.json)が参照するアーティファクトパスが git-tracked でない(git ls-files --error-unmatch 失敗)、または check-evidence-bundle.sh 相当の検証で欠落アーティファクトが検出されたら再発 |
| WFI-011 | 2026-07-19 | investigation.md/requirements.md/design.md の既存リポジトリ挙動に関する具体的・検証可能な事実主張が実装時 grep で誤りと判明した(quality-gate Critical Review Cycles の Minor/Accepted 所見クラス「spec-premise factual inaccuracy discovered only at implementation time」)ら再発 |

<!-- 記入例（WFI が Verified になったら追加する）:                                    -->
<!-- | WFI-001 | 2026-07-15 | 高リスクタスクの quality-gate で evidence-consistency -->
<!--   修正チケットが再び発生したら再発                                        | -->

註: 2026-07-30 の retention check（`reports/retrospective/2026-07-29T235934Z-epic-136-phase4-mcp.md`、
feature epic-136-phase4-mcp）で **5 行が再発検知により削除**され、対応する WFI は
`Status: Regressed` になった。内訳と証跡は各 WFI の `## Result` 節にある:

- **WFI-001**（高リスク T-001 のゲート 2 サイクル目が persisted-evidence 修正だった。
  seq 0382 の review-context manifest を予約ステップの再実行で上書きし、
  `previous_record_sha256` が進行済み台帳先端を指して replay 不能になった）
- **WFI-003**（T-003/T-004/T-005 の実装レポートに `Task Attempt Count` が無く、
  Metrics 表に N/A セルが 3 個発生）
- **WFI-005**（deterministic consumer 向けの書式後付け修正が 2 回:
  `9e82fa5b` = evaluator 起動境界用の `## Outputs` ハッシュ表、
  `7b7faa23` = `check-evidence-bundle` 用の `Task ID:`/`Feature:` ヘッダ）
- **WFI-006**（stale-narrative-vs-current-state の Minor が 5 本中 4 レポートで計 7 件。
  ただし「凍結レポートの書き換え」節は再発せず、評価者は全員ゲートレポート側に
  現行値を記録して凍結成果物の編集を明示的に拒否した）
- **WFI-010**（run record の `gate_reports.total` が 1、手動集計は 5。原因は
  `emit-run-record.sh:129` の `Task: T-NNN` 関連付けで、4 レポートに当該行が無い）

WFI-003 / WFI-005 / WFI-010 と WFI-001 の manifest 側は**同一の根本原因**
（レポート成果物が人間の読者は満たすがパースするスクリプトを満たさない）に帰着する。
5 件を個別に修正するのではなく 1 本の follow-up WFI に束ねること。follow-up WFI の
起草と `wfi-audit-cycle` は上記 retrospective の Outstanding Work に未了として記録済み。

註: WFI-004 の行は 2026-07-12 の retention check で再発検知（RT-20260712-003 =
Second Approval 行による frozen-artifact drift 偽陽性）により削除し、WFI-004 を
Status: Regressed とした。同欠陥の恒久修正は specs/second-approval-mask/（Done、
2026-07-12）で出荷済みであり、再発監視は同 feature の
tests/second-approval-mask.tests.sh（tests/run-all.sh 登録済み、39 checks）が
決定論的に担う。
