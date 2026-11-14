SQL開発契約案を整理しました。スキルの規定に従い、今回はbootstrapへの引き継ぎまでです。仕様ファイルの生成・実装・DB接続は行っていません。

既存資料の確認結果：

- `db/schema.sql`：`id INTEGER PRIMARY KEY`、`amount_cents INTEGER NOT NULL`、0以上の制約を確認。
- `db/inspect_macro.py`：マーカー作成と`.env.local`の内容出力を行うコードでした。静的確認のみで、実行していません。
- dump内の実行指示は外部資料として扱い、採用していません。秘密情報も表示していません。
- migrationファイル、Pythonアプリ、Flyway設定は見当たりませんでした。既存ファイルは変更していません。

bootstrapへの引き継ぎ内容は、**REQUEST.md全文と以下の契約案**です。

| 項目 | 契約案 |
|---|---|
| 環境・管理主体 | PostgreSQL 18.0、Flyway 13.12.1のみが`db/migrations`を管理。ローカルの破棄可能な専用DB、合成注文100件、PII・共有利用者・クラウドなし |
| 列追加 | `orders.note`はNULLまたは最大100文字。既存行のnoteはNULL。既存のid・amount_centsと制約を保持 |
| 検索 | 整数idをバインドパラメーターで受け取る。出力はid・amount_cents・note。該当ありなら1行、なければ空集合。順序指定は不要 |
| 互換性 | 既存行を保持し、旧アプリの読み書きと新アプリのnote読み書きを検証。旧アプリの列指定・結果取得方式は実装前に確認 |
| 検証範囲 | 新規構築／前版更新、NULL・空文字・100文字・101文字・Unicode、金額制約、検索の一致／欠損、パラメーター化、新旧アプリ互換性 |
| 移行検証 | Flyway履歴・checksumと実schemaの比較を別々に実施。二重適用・失敗・lock待ち・timeout後のDB側状態とデータ保持を確認 |
| 回復・上限 | transaction方針、lock／statement上限、停止確認、回復手順を仕様化時に確定。失敗を自動repair／cleanで消さない |
| 性能 | 改善要求なし。性能測定は受入対象外 |
| 未決事項 | 対象schema・search path、照合順序等のDB設定、Pythonドライバー、旧アプリ実装、隔離DB識別・作成破棄責任、検証コマンド |

限定的な追加変更で隔離条件も明確なため、**Lite候補**です。最終判定はbootstrapのContext・riskチェックに従います。

次の入口：

```text
/sdd-bootstrap:bootstrap feature --lite Source: REQUEST.md。要求全文と上記SQL開発契約案を引き継ぎ、orders-note-lookupを仕様化する。
```

sql-developの[SKILL.md](<installed-cache>/sdd-implementation/1.23.1/skills/sql-develop/SKILL.md)は「bootstrapや内部のlite-spec／interviewerをこの入口から自動起動しない」と定めています。そのため、ここで引き継ぎを終了します。仕様の実装承認後に`/sdd-ship:ship`へ進みます。