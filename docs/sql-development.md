# SQLを含むアプリとDB変更を開発する

SQLの要求を整理し、通常のSDD仕様化・承認・実装・独立検証へつなぐ手順です。
Microsoft SQL Server／Azure SQLのT-SQL、PostgreSQL、MySQLを扱います。

## 始め方

`sdd-implementation` を含む通常の開発プラグイン構成を使います。
仕様化には `sdd-bootstrap`、承認後の実装には `sdd-ship` とその依存が必要です。
Liteを使う場合は `sdd-lite` も必要です。通常の[導入手順](../README.md)を参照してください。
DBクライアントや移行ツールを入口が自動で導入することはありません。

Claude Codeでは次のように要求を渡します。

```text
/sdd-implementation:sql-develop
PostgreSQL 18と既存Flywayを使う社内アプリに、注文の配送予定日を追加したい。
今回は合成データだけの隔離開発DBが対象。共有DBは使わない。
旧アプリも読み書きできる形で、必要な仕様と検証項目を整理して。
```

Codex／Copilotでは `Use the sql-develop skill. Source: ...` と明示します。
SQL入口はコード・仕様の静的な確認と要求の整理を行い、DB接続や実装はしません。
DBエンジン、版、対象環境、管理主体、データ分類、変更影響が分からない場合は確認します。
認証情報や実データを回答に含める必要はありません。

入口が返した完全な要求とSQL契約案を、案内された既存bootstrapへ渡してください。
Lite候補の場合の例は `/sdd-bootstrap:bootstrap feature --lite <要求>` です。
既存Full指定や高影響の変更にはLiteを使わず、既存のトラック判定に従います。
標準の要件・設計・タスクを確認し、人間の承認後に
`/sdd-ship:ship specs/<feature>/tasks.md` で実装を始めます。
通常のbootstrapから始めたSQL案件でも、同じSQL参照手順を利用します。

## Microsoft SQLとAzureの違い

| 対象 | SQL手順で確認すること |
|---|---|
| SQL Server（ローカル／Azure VM） | 製品版、edition、互換性レベル、インスタンス設定、運用するOS |
| Azure SQL Database | T-SQLの対応範囲、projectのtarget platform、Entra認証、DBロール、サービスの復元・切替方法 |
| Azure SQL Managed Instance | SQL Serverとの機能差、インスタンス機能、認証・ネットワーク・復旧条件 |
| Azure Database for PostgreSQL | Microsoft SQLではなくPostgreSQLの手順を使い、サービス固有の差分を確認 |

新規T-SQL案件ではMicrosoft.Build.SqlのSQL Database ProjectsとSqlPackageを候補にします。
既存Flyway、Liquibase、ORM等の管理方式を勝手に置き換えたり、同じオブジェクトを二重管理したりしません。
Azure Data Studioは2026-02-28に終了しているため、新規手順にはVS CodeのMSSQL拡張とCLIを案内します。
[Microsoftの案内](https://learn.microsoft.com/en-us/sql/tools/whats-happening-azure-data-studio)を参照してください。

## 何を検証するか

- 新規構築と前版からの更新で、期待するスキーマ・キー・値・制約になること。
- 旧アプリと新アプリが、移行の各段階で読み書きできること。
- migration履歴の改変と、履歴外で起きた実スキーマの変更を別々に検知すること。
- 途中失敗・ロック待ち・タイムアウト・二重実行の結果と、復旧・再開後の状態。
- 性能が要件の場合、同じデータ・分布・負荷での変更前後の計測。

検証先は、その実行のために作った隔離DBに限り、合成データを使います。
SQL Serverの検証だけでAzure SQLやManaged Instanceの実サービスを受入済みにはしません。
同様に、PostgreSQL／MySQLの検証だけでRDS／Auroraの全機能を確認したとは扱いません。
必須の実DB試験を実行できない場合は未完了とし、モックや別エンジンで置き換えません。

`EXPLAIN ANALYZE`やストアド処理には副作用があり得ます。MySQLのDDLやPostgreSQLの
concurrent indexなども、一律にtransactionで戻せるわけではありません。
各エンジンの手順に従い、CLI終了だけでDB側の処理停止やrollbackを断定しないでください。

## クラウドとの分担と初版の境界

SQL側はDB内部の変更、データ、アプリ互換性を担当します。
[Azure](cloud/azure.md)／[AWS](cloud/aws.md)側はDB基盤・ネットワーク・クラウドIDを担当します。
同じPostgreSQLのSQL手順をクラウドごとに複製せず、製品固有の認証・機能・復元条件を追加で確認します。

初版は、共有・本番DBへの接続や適用を行いません。本番を扱う設計・移行、PII、権限／RLS、
テナント分離、破壊的変更はFullで仕様化し、実装は隔離試験と運用引き継ぎまでに限定します。
ガードをDBアクセス制御の代わりにはできません。

運用へ渡すのは、対象DB、成果物とrevision、必要な権限、前提スキーマ・履歴、適用順、
停止条件、復元先・接続切替、許容するデータ損失と復旧時間です。
本番適用には、対象環境と実行主体を定めた別の運用仕様・承認が必要です。
既存gateのDoneやcloud adapterのapply成功を、本番SQL適用の成功と読み替えないでください。

## 詳細

- [スキルと配布される参照手順](../plugins/sdd-implementation/skills/sql-develop/SKILL.md)
- [承認された初版仕様・調査根拠](../specs/sql-development-flow/design.md)
- [通常の開発フロー](workflow-guide.md)
