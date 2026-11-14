# PostgreSQL

適用前に実engine／正確な版、extensions、collation、timezone、対象schemaを確認する。
ローカルPostgreSQL、Azure Database for PostgreSQL、RDS、Aurora PostgreSQLは、同じ版番号だけで
機能・権限・復旧方法が同一とは扱わない。初版の実行範囲は合成データの隔離DB。

## 既存方式と変更

- 既存Flyway／Liquibase／ORM等のownerを継続する。新規の参照構成はPostgreSQL 18と
  Flywayの版付きmigration、psqlによる期待結果検査。導入先の自動upgradeは行わない。
- 対象schemaとsearch pathを明確にし、アプリ用ロールへsuperuserや不要なDDL権限を渡さない。
  migrationに必要な権限は隔離した適用用ロールへ限定する。
- 制約追加、型変換、index作成、table rewriteの可能性を変更ごとに確認し、
  許容するlock待ちとstatement時間を定める。CONCURRENTLYを無停止保証と扱わない。
- `CREATE INDEX CONCURRENTLY` はtransaction block内で実行できない。ownerの非transaction設定を
  対象migration単位で明示し、全migrationのtransactionを無効化しない。
  失敗時はinvalid indexが残る場合があるため、存在だけで成功にせずvalidityを確認する。
  cleanup／再構築は実際の残存状態と承認済み回復手順に従う。

## 検証

新規構築と前版更新に同じ期待結果を適用し、制約・NULL・重複・参照整合性とアプリの
パラメーター化された読み書きを確かめる。ownerの履歴とschema差異は別に比較する。
concurrent indexの失敗と回復、lock待ち・timeout・二重適用を隔離DBで観測する。

推定 `EXPLAIN` と実行する `EXPLAIN ANALYZE` を区別する。必要なら機械可読な計画を保存するが、
literalを含む機微情報は記録しない。`BEGIN` / `ROLLBACK`で囲んだことだけを、関数・sequence・
外部処理を含むすべての副作用が戻る保証にしない。

## クラウドへ渡す情報

AzureはEntra／managed identityの対応、DBロール、networkと復元先を確認事項にする。
AWSは実製品・版・IAM DB認証の対応、TLS、replicationと復旧条件を確認する。
RDS Blue/Greenのphysical replicationではgreen側schema変更に制約があり、logical方式でも
DDLが複製されるわけではない。汎用migration方式として自動選択しない。

## 公式資料（2026-11-05確認）

- [PostgreSQL 18 CREATE INDEX](https://www.postgresql.org/docs/18/sql-createindex.html)
- [PostgreSQL 18 Using EXPLAIN](https://www.postgresql.org/docs/18/using-explain.html)
- [Flyway Validate](https://documentation.red-gate.com/flyway/reference/commands/validate)
- [RDS Blue/Green limitations](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/blue-green-deployments-considerations.html)
