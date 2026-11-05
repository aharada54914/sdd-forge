# タスク: order-filter

## T-001 注文金額の包含下限を修正する
Approval: Approved
Status: Implementation Complete

### Scope
- db/queries/orders.sqlの金額下限比較だけを要件どおり修正する。
- 既存checks/acceptance.pyとnpm testで境界・空集合・Unicode・並び順・データ/schema不変を実DBで確認する。
- 実装/品質の既存報告とタスク状態を更新する。提供済みチェック・期待値・fixture・schema・runtime設定は変更しない。

### Done When
- minimum=100の同額行2/3を含む3行、minimum=0/-1で4行、501で0行を指定順序と値で返す。
- 不正整数拒否、読取り専用ロール、対象版・隔離、全キー値とschema不変の既存checkが実PostgreSQL18.6で成功する。
- 独立したlite-gateが実測を再確認し、品質レポートとexecution.jsonを残す。

### Blockers
- None
