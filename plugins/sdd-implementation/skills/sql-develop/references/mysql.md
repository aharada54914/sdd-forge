# MySQL

実engine／正確な版、storage engine、SQL mode、charset／collation、timezoneを確認する。
MySQL、MariaDB、Aurora MySQLを同一製品として扱わない。初版は合成データの隔離DBで検証する。

## 既存方式と変更

- 既存Flyway／Liquibase／ORM等のownerを継続する。新規の参照構成はMySQL 8.4、
  Flywayの版付きmigration、mysql clientの期待結果検査。導入先の版を自動変更しない。
- 多くのDDLは暗黙commitを伴う。全migrationをtransactionで囲むだけで元へ戻ると仮定しない。
  一つのatomic DDLと、複数文からなるmigration全体のatomicityは別。
- `ALTER TABLE`の方式とlock・table rebuildの条件を、対象版と操作ごとに確認する。
  online／instantという語や既存optionを、無停止・無負荷の保証にしない。
- アプリの最小権限とmigration権限を分離する。表・列名やORDER BYは許可した候補から選び、
  値はparameter bindingを使う。SQL modeの差による切捨てや暗黙変換も受入対象にする。

## 検証

空DBへの新規構築と前版からの更新を試し、同じschema、キー、値、制約と新旧アプリの読み書きを確認する。
NULL・重複・欠損参照、Unicode、decimalや日時の境界は対象要求に合わせて検証する。
ownerの履歴／checksumと実schemaのdriftを別に比較する。

途中でDDLが失敗するケースを作り、既にcommitされた変更、未適用の変更、migration履歴を観測する。
残存状態からのroll-forwardまたは復元を承認済み手順で行い、`repair`やdownを自動実行して隠さない。
二重適用、lock待ち、timeout、backfill中断後の再開も確認する。
client終了後もDB側処理・transaction・lockが残っていないか確認し、不明なら再試行しない。

実行計画と実測の区別、同条件での性能比較、証跡の秘密除去は共通手順に従う。
隔離MySQLの成功をRDS／Aurora、特定regionやreplication構成の受入へ流用しない。

## 公式資料（2026-11-05確認）

- [MySQL 8.4: Statements That Cause an Implicit Commit](https://dev.mysql.com/doc/refman/8.4/en/implicit-commit.html)
- [Flyway Validate](https://documentation.red-gate.com/flyway/reference/commands/validate)
- [Flyway Drift analysis](https://documentation.red-gate.com/flyway/flyway-concepts/drift-analysis)
- [RDS IAM DB authentication](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.IAMDBAuth.html)
