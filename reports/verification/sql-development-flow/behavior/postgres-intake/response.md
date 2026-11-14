SQL開発契約案を整理しました。既存の [db/schema.sql](<verification-projects>/spruce-orders/db/schema.sql) は、`id INTEGER PRIMARY KEY`、`amount_cents INTEGER NOT NULL`、非負制約を持っています。

| 項目 | 契約案 |
|---|---|
| 環境・管理主体 | PostgreSQL 18.0、ローカルの破棄可能な専用DB。Flyway 13.12.1のみが`db/migrations`を管理 |
| 変更 | `orders`にnullableな`note`列を追加。NULLまたは最大100文字。既存行のnoteはNULLとし、既存値を保持 |
| 検索 | 整数のidをバインドパラメーターとして渡す。文字列連結は使用しない。出力案は`id`・`amount_cents`・`note`。一致時1行、不在時は空集合。順序指定は不要 |
| 互換性 | 旧アプリの読み書きを保持。noteを指定しない既存の書込みを維持。列追加に伴う結果列数などの影響も確認 |
| データ・影響 | 合成注文100件、PII・共有利用者・クラウドなし。性能改善・性能測定は受入対象外 |
| トラック | **Lite候補**。最終判定は既存bootstrapのContext・risk判定に従う |

受入条件案は次のとおりです。

- 新規構築と既存100件からの更新で、同じスキーマ・制約を得る。既存のidと金額を全件照合する。
- noteのNULL・空文字・100文字・Unicodeを確認し、101文字の保存は拒否する。
- idの一致・不在、主キー重複、金額の0・負数、新旧CLIの読み書きを確認する。
- Flywayの履歴・checksum検証と、実スキーマの差異確認を別々に行う。
- 二重適用、途中失敗、ロック待ち・タイムアウト後のデータ、スキーマ、履歴を確認する。結果不明のまま再実行しない。

未確定なのは、対象schema/search path、照合順序などのDB設定、Pythonドライバーと旧CLIの実装、Flywayの初期履歴構成、実行上限・回復手順・検証コマンドです。今回のファイル一覧にはCLI実装やmigration設定がなく、互換性は未検証です。

次の入口へ渡す要求は以下です。REQUEST.mdの本文を省略せず、上記契約案・受入条件・未確定事項と合わせて渡してください。

> sql-developでordersのnullableなnote列追加とidを値として受け取る検索クエリを仕様化してください。PostgreSQL 18.0、Flyway 13.12.1のみがdb/migrationsを管理します。アプリはPythonの注文管理CLIです。ローカルの破棄可能な専用DBで合成注文100件、PIIなし、共有利用者なし、クラウドなし。idは整数主キー、amount_centsは0以上の整数、noteはNULLまたは最大100文字。idがなければ空集合、既存行と旧アプリの読み書きは保持。性能改善は要求しません。仕様の実装承認はこれからです。

```text
Use the sdd-bootstrap:bootstrap skill.
Mode: feature --lite
Source: REQUEST.md and the SQL contract draft, acceptance criteria,
and unresolved items from the sql-develop handoff above.
```

今回は引渡し案までです。[sql-developのSKILL.md](<installed-cache>/sdd-implementation/1.23.1/skills/sql-develop/SKILL.md)に「bootstrapや内部のlite-spec／interviewerをこの入口から自動起動しない」とあるため、正式仕様の生成は次のbootstrapで行います。ファイル変更・承認更新・SQL実装・DB接続・DB試験は行っていません。検証範囲は合成データの隔離DBに限定し、共有・本番への接続や適用は含めません。