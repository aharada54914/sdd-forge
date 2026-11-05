SQL開発契約案を整理しました。既存の `db/schema.sql` は `orders(id INTEGER PRIMARY KEY, amount_cents INTEGER NOT NULL CHECK (amount_cents >= 0))`、`db/Orders.sqlproj` は Microsoft.Build.Sql 2.2.0／Sql170 を指定しています。

再作成可能な専用隔離DB、合成データ100件、PII・共有利用者なし、限定的な追加なので **Lite候補**です。正式な判定と仕様生成はbootstrapで行います。

次の入口に、以下の要求と契約案を渡してください。

```text
/sdd-bootstrap:bootstrap feature --lite
```

**引き渡す要求全文（REQUEST.md）**

> sql-developでordersのnullableなnote列追加とidを値として受け取る検索クエリを仕様化してください。SQL Server 2025の開発用隔離DB、compatibility level 170、Microsoft.Build.SqlのSQL Database Projectsのみがdb/Orders.sqlprojを管理します。アプリは.NET注文管理CLIです。ローカルの破棄可能な専用DBで合成注文100件、PIIなし、共有利用者なし、Azureへの接続なし。idは整数主キー、amount_centsは0以上の整数、noteはNULLまたは最大100文字。idがなければ空集合、既存行と旧アプリの読み書きは保持。性能改善は要求しません。仕様の実装承認はこれからです。

**併せて渡すSQL開発契約案**

| 項目 | 契約案 |
|---|---|
| 対象・管理主体 | ローカルSQL Server 2025、compatibility level 170。Microsoft.Build.Sqlの `db/Orders.sqlproj` を唯一のスキーマ管理主体として維持する。 |
| スキーマ変更 | `orders` にNULL許容の `note` を追加。NULLまたは最大100文字とし、既存行はNULL。`id`・`amount_cents` と既存制約を保持する。backfill・既存列削除は不要。 |
| 検索 | 整数の `id` を型付きパラメーターとしてバインドする。入力値をSQL文字列に連結しない。出力案は `id`・`amount_cents`・`note`。一致時は1行、不一致時は空集合。最大1行なので並び順指定は不要。 |
| 互換性 | 既存100件のキー・金額を保持する。旧CLIの読み取り・追加・更新と、新CLIのnote読み書きを検証する。旧CLIによる更新で既存noteが失われないことも確認する。 |
| 境界値 | NULL、空文字、100文字、101文字、Unicode、金額0・負数、存在しないid、主キー重複を検証。101文字は黙って切り詰めず拒否する案とする。 |
| 配置・整合性 | 新規構築と前版からの更新で同じ最終スキーマ・制約になること。DACPACの成果物整合と実スキーマのdriftを別に確認する。SqlPackageの変更計画・pre/post scriptを確認し、データ損失防止設定を維持する。 |
| 失敗・回復 | 二重適用、途中失敗、ロック待ち、timeoutを検証する。中断時はDB側の処理・transaction・lock・スキーマを確認してから再実行を判断する。回復案は、所有確認済みの破棄可能DBの再作成と合成データ再投入。 |
| 隔離・記録 | 実装承認後、作成主体・資源ID・DB名を記録した専用DBだけで検証する。アプリ権限と配置権限を分離し、秘密を証跡に保存しない。片付けは記録した資源に限定する。 |
| 性能 | 改善要求がないため性能評価は受入対象外。性能改善を達成したとは報告しない。 |
| 実装前に確定 | SQL Serverの正確なbuild・edition・collation、noteの型と「100文字」のUnicode上の数え方、CLIソースと旧版の検証方法、実行コマンド、statement／lock timeoutと適用排他。現リポジトリにはCLIソースがないため、互換性は未検証。 |

今回はファイル変更・DB接続・SQL実装・試験を行っていません。スキルの[SKILL.md](<installed-cache>/sdd-implementation/1.23.1/skills/sql-develop/SKILL.md)が「bootstrapや内部のlite-spec／interviewerをこの入口から自動起動しない」と定めているため、ここで引き渡します。正式な仕様は次のbootstrapで生成し、人間による承認後にshipへ進みます。共有・本番DBやAzureへの接続・適用は対象外です。