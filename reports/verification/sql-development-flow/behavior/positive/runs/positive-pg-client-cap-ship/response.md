T-001 は **Done** です。

- SQL の金額下限比較を `>` → `>=` に修正。
- 実装側と別コンテキストの独立 lite-gate で、既存 `npm test` が成功。
- PostgreSQL 18.6で境界値・データ/schema不変・所有DBの停止を確認。
- 提供済みチェック・fixture・runtime設定は変更していません。

[品質レポート](reports/quality-gate/T-001.md) · [実行証跡](reports/quality-gate/T-001.execution.json)