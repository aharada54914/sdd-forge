# 要件（lite）: orders-note-tsql-intake

Status: Draft

- **Issue/出典**: `REQUEST.md` と今回の prior sql-develop handoff。今回の入力記録: `.run-temp/bootstrap-orders-note-tsql-intake-nJJ2trWi/source.txt`。
- **目的**: .NET注文管理CLIの注文に任意のnoteを保存し、整数idを値として安全に渡して検索できるようにする。
- **段階**: 仕様Draftのみ。実装・DB接続・試験は未承認、未実施。

## ユーザーストーリー / 要求

- REQ-001: ローカルの破棄可能な専用SQL Server 2025開発DB、compatibility level 170を対象とする。Microsoft.Build.SqlのSQL Database Projects `db/Orders.sqlproj` のみをスキーマ管理主体とする。
- REQ-002: `orders` にnullableな `note` を追加する。NULLまたは最大100文字。既存行のnoteはNULLとし、既存100件のid・amount_centsと主キー・非負制約を保持する。backfillは不要。
- REQ-003: 検索は整数idを型付きパラメーターとしてバインドし、値をSQL文字列へ連結しない。Draftの出力契約は `id`、`amount_cents`、`note`。一致時は1行、存在しないidでは空集合。最大1行なので順序指定は不要。
- REQ-004: 旧CLIの読み取り・追加・更新が継続すること。旧CLIでnoteを省略した追加はNULL、旧CLIの金額更新で保存済みnoteが失われないこと。新CLIはnoteを読み書きでき、NULLと空文字を区別する。旧CLIの実物がない間は互換性を合格扱いにしない。
- REQ-005: Draft案として101文字以上は保存前またはDB境界で明確に拒否し、黙って切り詰めない。NULL、空文字、100文字、101文字、Unicode、金額0・負数、存在しないid、主キー重複を検証する。「文字」の定義はOpen Questionsで確定する。
- REQ-006: 空DBからの新規構築と前版からの更新で同じ最終スキーマ・制約となること。更新では行数だけでなく既存100件すべてのキーと金額の一致を確認する。DACPACの成果物整合と実スキーマdriftを別々に確認する。
- REQ-007: 二重適用、途中失敗、ロック待ち、timeoutを隔離DBで検証する。中断後はDB側の処理・transaction・lock・schemaを観測し、状態不明のまま再実行しない。復旧は所有確認した専用DBの再作成・合成データ再投入を案とする。
- REQ-008: 合成注文100件のみを使い、PII・共有利用者・Azure接続を含めない。作成主体・資源ID・DB名を記録して接続先の所有と隔離を確認する。アプリ権限と配置権限を分離し、秘密を証跡へ保存しない。片付けは記録した資源に限る。

## スコープ外

- 今回のSQL・CLI実装、DB接続、配置、試験、資源作成・破棄。
- 性能改善・性能評価。性能改善を達成したとは報告しない。
- 共有・本番DB、Azure、旧列削除、破壊的移行、大規模backfill、別migration ownerの導入。

## Open Questions

実装承認を求める前に以下を決定して設計・タスクに反映する。未決のままDB接続や実装を始めない。

- OQ-01: SQL Serverの正確なbuild、edition、OS／image digest、collation、利用条件。
- OQ-02: noteのSQL型とUnicode上の100文字の定義（UTF-16 code unit、code point、grapheme等）。補助文字・結合文字・末尾空白を含む境界の期待結果、アプリ／DBの拒否方法。`nvarchar(100)`だけで要求を満たすとは仮定しない。
- OQ-03: CLIソースと旧版バイナリ／revision、既存SQL・transaction境界、旧CLIの検証方法。CLIのnote入力・NULL指定・表示・エラー契約、検索の配置先（CLI側SQLかproject管理routineか）、戻り列契約の確定。
- OQ-04: .NET SDK、SqlPackage、sqlcmd、driverの版と、build・配置・比較・互換性・失敗試験の具体的コマンド、project checksへの登録方法。現在CLIソースと実行基盤がない。
- OQ-05: statement／command／lock timeout、適用排他、キャンセルと失敗時の観測方法、atomic性と再実行条件。
- OQ-06: 専用資源の作成・所有確認・破棄担当、DB名／資源IDの記録形式、認証・TLS・証明書検証、アプリ／配置権限の具体設定。
