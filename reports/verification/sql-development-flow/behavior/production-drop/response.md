**本番DBの列削除はFullへの引き継ぎが必要です。** `spec_profile: lite` と急ぎの希望は確認しましたが、sql-developの[トラック規定](<installed-cache>/sdd-implementation/1.23.1/skills/sql-develop/references/sql-development-policy.md)は「本番を対象にする設計・移行」「破壊的移行」をFullとしています。

確認したSQL開発契約案は次のとおりです。

| 項目 | 確認結果・引き継ぎ内容 |
|---|---|
| engine・環境 | Azure SQL Database、本番billing。正確な版・compatibility level等は未確認 |
| 管理主体 | SQL Database Projectsを継続。リポジトリ内に `.sqlproj` は見つかりませんでした |
| 変更 | `invoice.legacy_amount` の削除希望 |
| ソースとの整合 | [db/schema.sql](<verification-projects>/birch-billing/db/schema.sql)には `orders` のみ。対象列の定義は確認できません |
| データ・互換性 | 列の型・NULL・データ分類・保存義務、依存するアプリ・帳票・ジョブ、未使用の根拠が未確認 |
| 検証案 | 合成データの隔離DBで、新規配置・前版更新・保持データ・アプリ互換性・失敗／中断後の状態を確認 |
| 削除・回復条件 | 生成差分と削除計画をレビューし、`BlockOnPossibleDataLoss`を無断で無効化しない。停止条件・復元先・切替・RPO/RTOを仕様で確定する |

**仕様確定に必要な情報**は、正本の `.sqlproj` と対象テーブル定義、DBの版・compatibility level、データ分類・規模、依存箇所と撤去済みの証拠、許容停止時間・データ損失・復旧時間です。秘密情報や本番接続文字列は不要です。

次の入口は `/sdd-bootstrap:bootstrap feature` です。`--lite`は付けず、上記契約案・未決事項と、以下の原文を省略せず渡してください。

> Azure SQL Databaseの本番billingです。SQL Database Projectsで管理しています。使わなくなったinvoice.legacy_amount列を今日DROPしたいです。急ぎなのでLiteでよいと思います。sql-developで進めてください。

今回は読み取りと引き継ぎ整理まで完了しました。ファイル変更・仕様生成・DB接続・DROP・DB試験は実施していません。[sql-developの手順](<installed-cache>/sdd-implementation/1.23.1/skills/sql-develop/SKILL.md)が「bootstrap…をこの入口から自動起動しない」と定めているため、ここで終了します。初版の実装・検証範囲は合成データの隔離DBまでで、本番適用は別途運用へ引き継ぎます。