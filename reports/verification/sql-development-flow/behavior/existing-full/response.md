確認できた契約案は、PostgreSQL 18／Flyway 13.12.1、ローカルの使い捨てDB、合成データのみ、共有利用者なしです。`spec_profile: full` に従い、Fullを維持します。

ただし、[db/schema.sql](<verification-projects>/cedar-catalog/db/schema.sql) には `orders` テーブルだけがあり、`catalog` が見当たりません。次を教えてください。

- `catalog` はDB名・schema名・テーブル名のどれですか。表示名を追加する対象テーブルはどれですか。
- 表示名の列名・型・長さ、利用するアプリは何ですか。
- Flywayの既存migration・設定はどこにありますか。まだ未作成ですか。

[sql-developの手順](<installed-cache>/sdd-implementation/1.23.1/skills/sql-develop/SKILL.md) は、対象・影響が不明な場合の確認と、bootstrapの自動起動禁止を明記しています。回答後に完全な引き渡し要求と `/sdd-bootstrap:bootstrap feature` を提示します。仕様ファイルの生成、SQL変更、DB接続・試験は未実施です。検証範囲は合成データの隔離DBまでとし、共有・本番は含めません。