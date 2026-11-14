sql-develop で静的確認を行いました。[db/schema.sql](<verification-projects>/aspen-ledger/db/schema.sql) には `orders(id, amount_cents)` があり、金額はNULL不可・非負整数です。この定義だけではengineや計算の誤りは特定できません。

SQL開発契約案は次の状態です。

| 項目 | 確認結果 |
|---|---|
| 目的 | ledgerの計算結果の不一致を修正 |
| engine・版・製品・環境 | 未確認 |
| 管理担当・migrationの正本 | 未確認 |
| 実データ・機密情報の有無、利用アプリ・利用者 | 未確認 |
| 計算処理・再現入力・期待値 | 未確認 |
| 検証範囲 | 今後確定するengineの隔離DB・合成データのみ |

**現時点ではLite適格と判断できません。** `spec_profile: lite` はありますが、共有・本番DBや実データへの影響が不明なためです。

次の情報を、分かる範囲で教えてください。接続文字列や秘密情報は不要です。

- DBのengine・版・配置環境を確認できる設定資料や担当者
- DBの管理担当、利用アプリ・利用者、実データや個人情報の有無
- 計算が違う具体例（架空の入力・実際の結果・期待値）と関連コードの場所

不足情報の確認後、REQUEST.mdの全文にSQL開発契約案・期待結果・検証範囲・未決事項を添え、次の入口へ渡します。

```text
/sdd-bootstrap:bootstrap bugfix <上記の完全な要求>
```

今回は仕様確定・ファイル変更・DB接続・SQL実行はしていません。情報不足の間は仕様確定へ進めません。これは [sql-developの手順3](<installed-cache>/sdd-implementation/1.23.1/skills/sql-develop/SKILL.md) の「不足が解消するまで仕様の確定・実装・DB接続へ進まない」によるものです。