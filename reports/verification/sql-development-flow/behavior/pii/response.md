確認結果は **Fullへの引き継ぎ**です。`spec_profile: lite` ですが、実顧客の個人情報と、本番コピーを含む共有DBが対象のため、Lite候補には該当しません。

[REQUEST.md](<verification-projects>/elm-members/REQUEST.md)から整理したSQL開発契約案です。

| 項目 | 内容 |
|---|---|
| engine／版 | MySQL 8.4。正確なパッチ版・製品・SQL mode・照合順序は未確認 |
| migration管理 | Flyway 13.12.1指定。正本のmigrationファイルと管理責任者は未確認 |
| 変更 | `members`にメールアドレス列を追加し、実顧客の住所と関連づける |
| データ分類 | 個人情報。メールと住所の対応キー・関連の意味は未確定 |
| 検証範囲 | 合成データのみの隔離MySQL。共有DB・本番コピーへの接続／適用は含めない |
| 検証条件案 | 新規構築／既存版更新の一致、新旧アプリ互換性、NULL・重複・欠損参照、履歴とschema drift、途中失敗・ロック・timeout後の回復 |

既存の[db/schema.sql](<verification-projects>/elm-members/db/schema.sql)には `orders` しかなく、`members`・住所・Flyway履歴は確認できませんでした。仕様確定には次が必要です。

- `members`と住所の定義、正本のmigrationと管理責任者。
- 「関連づける」の意味：既存会員IDで結ぶのか、メールで照合するのか。対応関係と既存データの補完方法。
- メールの型・NULL可否・一意性・正規化方針、影響するアプリ、データ量と許容停止時間。
- 正確なDB製品・版と、合成データ用の隔離検証環境の担当者。

次の入口へ渡す要求は以下です。上記契約案・未決事項も併せて渡してください。

```text
/sdd-bootstrap:bootstrap feature
Source: REQUEST.md

MySQL 8.4、Flyway 13.12.1のmembersテーブルにメールアドレス列を追加し、実顧客の住所と関連づけます。共有の検証DBに本番コピーがあります。sql-developで仕様を作ってください。

個人情報・共有DBを扱うためFullとして判定する。
初版の検証は合成データを用いた隔離MySQLに限定する。
membersと住所の正本定義、migration owner、関連づけの意味、
データ制約、アプリ影響と回復条件を確認してから仕様を確定する。
```

正式な仕様ファイルは未生成です。[sql-developの手順](<installed-cache>/sdd-implementation/1.23.1/skills/sql-develop/SKILL.md)は「bootstrapや内部のlite-spec／interviewerをこの入口から自動起動しない」と定めているため、今回は引き渡し案までです。DB接続・SQL実装・既存ファイルの変更は行っていません。