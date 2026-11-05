# タスク（lite）: orders-note-postgres-intake

Draft生成のみ。未確定事項を解消し仕様を更新するまで実装承認を求めない。全タスク未承認、未実施。

## T-001 実装・隔離検証の前提を確定する
Approval: Draft
Status: Planned

### Scope
- requirements.mdのOpen Questions全項目を確認し、設計・後続タスクの対象パス、コマンド、期待結果を具体化する。
- 旧CLIの実体・読書き契約、Flyway初期履歴とschema.sqlの関係、schema/search path、DB設定、ドライバーを確認する。
- 隔離資源・責任者・権限、実行上限、transaction/故障注入/回復・後片付けを定義する。
### Done When
- 推測した既定値を使わず全未決事項が解消され、実行先の確認方法・実行/比較コマンド・失敗後の期待状態が設計に記録される。
- 新旧CLIの対象revision・起動方法と互換性の判定方法が特定される。仕様変更を人間が確認できる。
### Blockers
- CLI実装・Flyway設定が未提供。設定・責任者・回復判断が未確定。

## T-002 Flywayによるnullable note追加を実装する
Approval: Draft
Status: Planned

### Scope
- Depends on: T-001。承認後、Flyway所有の版付きmigrationと必要なfixture・検証を実装する。
- 既存データと制約を保持し、NULLまたは最大100文字のnoteを追加する。
### Done When
- 新規構築と既存合成100件更新で同じschema・制約を得て、全id・金額が保持され既存noteがNULLになる。
- NULL/空文字/100文字/Unicodeを保存・読出し、101文字・重複主キー・負金額・NULL金額を拒否し、金額0を許可する。
- 適用済みmigrationを書き換えず二重管理しない。
### Blockers
- T-001未完了、人間の実装承認なし。

## T-003 整数id検索とCLI互換性を実装・確認する
Approval: Draft
Status: Planned

### Scope
- Depends on: T-001, T-002。確定したPythonドライバーでid値をバインドし、指定出力契約を実装する。
- 新旧CLIの読書き・transactionと列数依存を確認する。
### Done When
- id一致でid/amount_cents/noteの1行、不在で空集合となり、SQL文字列連結を使わないことをコードと実行で確認する。
- 旧CLIの移行前後の読書き、新CLIの移行後読書き、noteなし書込みを確認し、既存契約を保持する。
### Blockers
- 前提タスク未完了、人間の実装承認なし。

## T-004 隔離DBで失敗・履歴・driftの回帰検証を行う
Approval: Draft
Status: Planned

### Scope
- Depends on: T-001, T-002, T-003。承認済みの専用DBと合成100件で全受入条件をproject checksとして実行する。
- Flyway履歴/checksumと実schema比較を分離し、二重/並行適用、途中失敗、lock待ち・timeout後を検証する。
### Done When
- 履歴改変と履歴を変えないschema driftを別々に検知する。
- 故障・timeout後の処理/transaction/lock、全保持データ、schema、履歴が事前定義した期待値に一致し、承認済み回復を検証する。結果不明の再実行はない。
- 実測版・fixture・revision/dirty・command/終了状態・副作用・未実施を共通実行器execution.jsonと既存報告へ記録し、秘密を含めない。
- 必須未実施や失敗を合格にせず、独立したlite品質ゲートへ引き渡す。後片付けは記録した所有資源のみ。
### Blockers
- 前提タスク未完了、人間の実装承認なし。必要な実環境・CLIが使えなければBlockedとする。
