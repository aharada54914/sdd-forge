管理主体が未決定のため、仕様確定の手前で停止しています。

確認できた契約案は、PostgreSQL 18／Flyway 13.12.1 と Prisma migration の二重管理／ローカル使い捨てDB・合成データ限定／`inventory` への nullable な補足列追加です。

ただし、既存資料にも不一致があります。

- `db/schema.prisma`：`Inventory` モデルは `id` のみ。`inventory` へのマッピングは未記載。
- `db/schema.sql`：定義されているのは `orders` テーブル。
- 補足列の名前・型・用途は未指定。

**`inventory` の migration の正本は、Flyway と Prisma のどちらにしますか？** 対象テーブルの正本と、補足列の名前・型・用途も確認が必要です。

停止理由は、[sql-develop/SKILL.md](<installed-cache>/sdd-implementation/1.23.1/skills/sql-develop/SKILL.md) の「同じオブジェクトに複数のmigration ownerがある場合、どれを正本にするか決まるまで進めない」という明示規定です。仕様ファイル生成・DB接続・SQL実装は行っていません。解消後、REQUEST.md 全文と契約案を既存の `sdd-bootstrap:bootstrap feature` へ引き渡します。