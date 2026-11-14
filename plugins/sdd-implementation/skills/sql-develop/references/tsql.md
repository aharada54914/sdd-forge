# Microsoft SQL Server / Azure SQL

Microsoft SQLは初版の対象。T-SQLはSQL Server系の方言であり、AzureのすべてのDBがT-SQLではない。
対象製品・正確な版・edition・compatibility level・collationを確認する。

| 製品 | 確認する違い |
|---|---|
| SQL Server（ローカル／VM） | OS、edition、instance設定、機能、backup・restoreの責任 |
| Azure SQL Database | 対応するT-SQL／DB機能、Entra認証、service tier、network、別DBへの復元と切替 |
| Azure SQL Managed Instance | instance機能とSQL Serverからの差異、認証、network、復旧のサービス制約 |

隔離したSQL Serverの試験を、Azure SQL DatabaseやManaged Instanceの実サービス受入と呼ばない。
初版はAzureの共有・本番DBへ接続せず、実環境での確認事項を運用へ渡す。

## 既存方式と変更

- 既存のSQL Database Projects、Flyway、Liquibase、ORM等のownerを維持する。
  同じオブジェクトの正本をDACPACと別のmigration方式へ二重化しない。
- 新規案件ではMicrosoft.Build.SqlのSDK-style projectを候補にする。
  projectのtarget platformを対象製品に合わせ、buildした `.dacpac` を特定する。
  SQL Server向けbuild成功をAzure SQLの機能適合証明にしない。
- SqlPackageの変更report／scriptと、pre/post deployment script、SQLCMD変数、
  table再作成・型変換・オブジェクト削除を確認する。外部callbackやbuildも隔離対象。
  生成計画をレビューしただけでは適用成功にならない。
- `BlockOnPossibleDataLoss` を勝手に無効化しない。検出を通過しても、動的SQLや
  pre/post scriptを含むすべてのデータ損失が防がれるとはしない。
  driftのチェックは登録状態と比較範囲を確認し、設定値だけで検証済みと扱わない。
- Publish用の権限とアプリ用の権限を分ける。接続文字列やaccess tokenをコマンドログ・仕様へ
  保存しない。認証、TLSと証明書検証の条件を別々に確認する。

## 検証

参照構成はSQL Server 2025の隔離した開発用環境、Microsoft.Build.Sql、SqlPackage、sqlcmd。
実装時に実測版、image digest、SDK／CLIの版と利用条件を固定する。

project build、空DBへの初期配置、前版からの更新、期待するschema・値・制約、
新旧アプリの読み書きを確認する。破壊的な差分が止まることと、止まった後のDB状態も確かめる。
owner履歴／artifactの整合と、実schemaのdriftを別に検査する。
lock／command timeout、中断後のtransaction・実行中処理・適用状態を確認し、不明なら再実行しない。

query tuningでは推定計画と実際の実行計画を区別し、同条件で遅延・読み取り量・lock待ちを測る。
入力値はparameter bindingを使い、動的なオブジェクト名・並び順を無制限に連結しない。

## 開発ツールと運用

Azure Data Studioは2026-02-28に終了したため、新規手順はVS CodeのMSSQL／SQL Database Projects拡張と
CLIを基本にする。既存ファイルを扱うために不要なproject形式の変換を強制しない。
Azure SQL Databaseの復元は別DBを作るため、backup取得だけでrollback完了とせず、
復元先・接続切替・許容損失・復旧時間を引き継ぐ。

## 公式資料（2026-11-05確認）

- [SQL Database Projects](https://learn.microsoft.com/en-us/sql/tools/sql-database-projects/sql-database-projects?view=sql-server-ver17)
- [SqlPackage Publish](https://learn.microsoft.com/en-us/sql/tools/sqlpackage/sqlpackage-publish?view=sql-server-ver17)
- [Azure Data Studioの終了](https://learn.microsoft.com/en-us/sql/tools/whats-happening-azure-data-studio?view=sql-server-ver17)
- [Azure SQL Database restore](https://learn.microsoft.com/en-us/azure/azure-sql/database/recovery-using-backups?view=azuresql)
