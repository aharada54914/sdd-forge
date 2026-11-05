# 要件（lite）: orders-note-postgres-intake

Status: Draft

- **出典**: REQUEST.md全文、および本セッションのsql-develop引渡し（契約案・受入条件・未確定事項）。今回専用の入力記録: `.run-temp/bootstrap-orders-note-LStr7lOA/source.txt`。
- **目的**: Python注文管理CLIで注文の任意メモと整数id検索を扱い、既存データと旧CLIの読書きを保持する。
- **判定**: Project Contextは物理的に存在しない。bootstrapのhook確認はHOOK_ACTIVE。C1のCOMPATIBILITY_FALLBACKで明示された--liteを採用。完全な要求・引渡しを入力したrisk checkerはlite-eligible。隔離・合成データ・共有利用者なし・限定的な追加変更を根拠とする。

## ユーザーストーリー / 要求
- REQ-001: PostgreSQL 18.0のordersにnullableなnoteを追加する。NULLまたは最大100文字を許可し、既存100件のnoteはNULL、idとamount_centsは全件保持する。
- REQ-002: idは整数主キー、amount_centsはNULL不可の0以上の整数を維持する。noteの空文字を許可し、Unicodeも文字数で扱う。101文字の保存はDBで拒否する。
- REQ-003: 整数idを値としてバインドして検索する。SQL文字列連結は禁止。出力契約案はid（整数）、amount_cents（整数）、note（NULLまたは文字列）。一致時1行、不在時空集合、順序指定不要。CLI表示形式は未確定。
- REQ-004: noteなしの旧書込みと旧読込みを保持する。旧CLIの列数依存・位置依存・transaction境界を実装から確認し、新旧CLIを実行して互換性を確認する。現時点では未検証。
- REQ-005: db/migrationsの唯一の管理主体はFlyway 13.12.1。独自runnerやORMとの二重管理は追加しない。新規構築と前版更新で同じ最終schema・制約を得る。
- REQ-006: 検証はローカルで破棄可能な専用DB、合成注文100件のみ。PII・共有利用者・クラウドなし。接続先と作成主体を確認し、記録した資源だけを後片付けする。
- REQ-007: 履歴・checksumと実schema差異を別々に検証する。二重適用・途中失敗・ロック待ち・timeout後にデータ、schema、履歴、実行中処理を観測する。結果不明のまま再実行しない。

## 受入条件
- 新規構築と既存100件更新の最終schema・制約を比較し、更新前後の全id・金額を照合する。行数だけでは合格にしない。
- noteのNULL、空文字、100文字、Unicode（100文字を含む）は保存・読出し一致、101文字は拒否。既存行のnoteはNULL。
- id一致・不在、重複主キー拒否、金額0許可・負数拒否・NULL拒否、新旧CLIの読書きを確認する。
- Flyway履歴改変と、履歴を変えないschema driftを別々に検知する。
- 再適用で二重変更しない。故障注入・並行適用・ロック待ち・timeout後の期待状態は実行前に確定し、観測結果と照合する。
- 必須試験が未実施・失敗・BlockedならPASS/Doneにしない。

## スコープ外
- SQL・CLI実装、DB接続・試験、実装承認、共有・本番接続や適用は今回行わない。
- 性能改善・性能測定、index追加、backfill、旧列撤去、クラウド運用。

## Open Questions
- 対象schema/search path、encoding・collation・timezone・extensions等の設定。
- Pythonドライバー、バインド記法、旧CLIの実体・起動コマンド・出力形式と互換性。
- Flyway初期履歴、空DBと既存DBの導入方式、migration命名・版、schema.sqlの今後の役割。
- 隔離DBの作成・接続・破棄責任者、資源ID、ロール、実行環境・利用条件。
- statement/lock/資源上限、transaction設定、キャンセル後の確認・回復手順と損失範囲。
- 検証コマンド、fixture生成、実schema比較範囲・方法、故障注入と期待状態。
これらを設計・タスクへ反映してから承認を検討する。既定値を推測して実装・接続しない。
