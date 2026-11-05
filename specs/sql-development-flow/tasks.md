# タスク（lite）: SQL開発フロー

提案・未承認。以下は仕様承認後の実装タスクであり、今回実施済みの調査・文書作成を実装完了には数えない。承認対象は [要件](requirements.md) と [設計](design.md) に示した初版の範囲。共有・本番DBの実行は含まない。

## T-001 SQL入力整理と既存仕様化への入口
Approval: Draft
Status: Planned

### Scope

- REQ-001／002／004／010。`sql-develop` の入口、SQL開発契約のテンプレート、Lite／Fullへの引き渡しを追加する。
- 対象・管理主体・変更影響が不明な場合と、承認前の実装・接続の扱いを定める。

### Done When

- PostgreSQL／T-SQL／MySQLの要求から、既存形式の3文書またはFull仕様化への引き渡しを作れる。
- 未指定engine、管理主体衝突、既存Full、本番DROP、PII、未知対象のケースで必要な停止・確認・昇格を実際のスキル利用経路から確認する。
- 承認欄の書換え、DB接続、SQL実装を入口が行っていない証拠がある。

### Blockers

- 本提案へのユーザー承認待ち。

## T-002 SQL実装・安全な検証の共通手順
Approval: Draft
Status: Planned

### Scope

- REQ-005〜009／012。既存ownerの維持、変更分割、隔離、履歴とdrift、正しさ、性能、回復の参照手順を追加する。
- `implement-task` と既存gateの導線へ接続し、独自の状態モデルやmigration runnerを作らない。

### Done When

- 承認済みSQLタスクが既存 `ship` 経由で実装・独立検証へ進む。
- 未実行試験、履歴改変、実スキーマだけの変更、未信頼macro、秘密出力を成功扱いしない。
- 既存の停止要求、managed model、Context、承認とFull指定の契約を維持する。

### Blockers

- 本提案へのユーザー承認、T-001。

## T-003 3エンジンの参照案件を実DBで検証
Approval: Draft
Status: Planned

### Scope

- REQ-003／006〜009。PostgreSQL 18、SQL Server 2025、MySQL 8.4の参照案件と隔離CIを用意する。
- 実装時にパッチ版、CLI、コンテナdigest、利用条件を確認し固定する。

### Done When

- 3系統で新規構築、前版更新、期待結果、アプリ互換性と失敗後の状態を確認できる。
- PostgreSQLのconcurrent index、T-SQLのデプロイ計画と損失防止、MySQLの暗黙commitをそれぞれ観測する。
- 中断・再開、二重実行、ロック／時間上限、限定した検証資源の破棄を確認する。
- 性能評価対象は条件を固定して前後比較する。必要な実DBを起動できない場合はBlockedとし、モックで代替合格にしない。

### Blockers

- 本提案へのユーザー承認、T-002。実DBの実行環境・利用条件は実装時に確認。

## T-004 Azure・AWS・ソフト開発との導線と配布
Approval: Draft
Status: Planned

### Scope

- REQ-001／011。既存アプリタスクとの依存、運用引き継ぎテンプレート、利用文書、スキル集合の検証を整える。
- 3ホストで既存implementationプラグイン内のスキル・参照資料を配布できることを確認する。

### Done When

- Azure SQLとRDS PostgreSQLの例で、基盤／DB内部／アプリの担当と権限が区別される。
- 同じPostgreSQL手順をローカル・Azure・AWSの設計から参照できるが、未検証のクラウド動作を成功と表示しない。
- 通常ソフト開発とクラウドadapterの既存導線を壊さず、新規pluginや既定導入対象を増やしていない。
- READMEのドキュメントマップからSQL手順へ到達でき、導入先から実行時参照資料を読める。

### Blockers

- 本提案へのユーザー承認、T-001／T-002。

## T-005 独立レビューと初版の受入
Approval: Draft
Status: Planned

### Scope

- REQ-012。3参照案件、未承認／高影響の負例、既存フローとの回帰を独立して確認する。
- 実行証跡と品質レポートに、実施・未実施・対象外を分けて記録する。

### Done When

- 実装を担当していないコンテキストが、設計の完了条件と実際の副作用を確認する。
- 必須試験、配布確認、関連CIが成功し、未解決の重大な指摘がない。
- 共通試験のOS別重複を抑え、PowerShell 5.1／7は差がある境界のみ個別検証する。
- 共有・本番DBへ接続していないこと、および実クラウド受入を完了扱いしていないことを確認する。

### Blockers

- 本提案へのユーザー承認、T-001〜T-004。
