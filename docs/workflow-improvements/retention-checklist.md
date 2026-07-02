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

<!-- 記入例（WFI が Verified になったら追加する）:                                    -->
<!-- | WFI-001 | 2026-07-15 | 高リスクタスクの quality-gate で evidence-consistency -->
<!--   修正チケットが再び発生したら再発                                        | -->

現在、Verified 状態の WFI はありません（WFI-001 は Human-Pending）。
