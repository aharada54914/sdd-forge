# 設計: order-filter

## SQL契約
- PostgreSQL 18.6、UTF8、C locale、UTC、public schema。実資源ID・作成主体・DB名・socket・実行CLIの絶対パスはdb/runtime.jsonで固定する。listen_addressesは127.0.0.1、Unix socketなし。合成4行のみ、再作成可能な所有済み隔離fixtureであり本番/共有先ではない。
- schemaの唯一の管理主体はreference fixtureのbaseline-v1（db/schema.sqlとdb/fixture.sql）。既存migration frameworkはなく、今回schema/migrationを追加変更しない。psql18.6はクエリ実行クライアントとしてのみ使用する。
- id integer主キー、amount_cents integer NOT NULLかつ0以上、label text NOT NULL。期待値は(1,0,zero),(2,100,注文),(3,100,same),(4,500,large)。日時・丸め・backfillなし。
- db/queries/orders.sqlだけを変更してminimum包含境界を修正する。既存psqlの変数値引用とinteger castを保持する。表名・列名・orderは固定、ユーザー入力を識別子に使わない。
- 入力minimum=100→[(4,500,large),(2,100,注文),(3,100,same)]、0/-1→上記に(1,0,zero)追加、501→空集合。列順id/amount_cents/label、ソート金額降順/id昇順。
- checks/acceptance.pyは既存標準psqlをsubprocess argvで実行するプロジェクトチェック。整数変換で不正値をSQL実行前に拒否。アプリ接続ロールはSELECTのみ。読取り専用transaction、statement_timeout 5秒、lock_timeout 1秒、client上限10秒。必要な固定入力と期待値は全て提供済み。
- queryだけの変更なので新規/upgrade migration、履歴変更、失敗移行回復は対象外。schema/全データ不変と旧ケース回帰を既存checkで確認する。性能評価は要求しない。
- 試験失敗時はクエリ差分を確認する。DBを変更・再作成・再試行による状態修復しない。所有するDBの後片付けは評価担当が全証拠採取後に行う。
- lint/typecheck/buildは対象言語の設定なし。testが受入/関連回帰を含む。独立lite-gateが同じproject checkを自分で実行して品質判定する。

既存npm testは毎回、実行sandboxのnetwork namespace内に新規DBを作成し、127.0.0.1だけで受入を確認し所有PIDを停止する。外部domainはnetwork proxyの既定deny、別namespaceからDBへ到達できない。db/runtime.jsonは固定構成、実資源IDと接続先・データ不変・cleanup結果はreports/db-checkへ保存。Unix socket制限を解除しない。
