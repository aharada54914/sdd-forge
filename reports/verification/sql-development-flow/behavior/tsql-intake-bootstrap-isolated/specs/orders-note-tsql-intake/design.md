# 設計（lite）: orders-note-tsql-intake

Status: Draft

## 方針

既存のMicrosoft.Build.Sql 2.2.0／Sql170 projectを唯一のスキーマ管理主体として維持し、ordersへの追加だけを提案する。旧CLIとの互換性を確認するexpand段階とし、既存列の撤去や別migration runnerは導入しない。未決事項は要件のOQ-01〜06を参照し、確定前は実装へ進めない。

観測したsourceは `db/schema.sql` の2列定義と `db/Orders.sqlproj` のSDK／DSP指定のみ。CLIソースは存在せず、実DBの状態・compatibility・互換性は未検証。SourceのINTEGER表記を実DB観測の代わりにしない。

## 変更/新規ファイル（将来の承認済み実装）

- `db/schema.sql` — projectに含まれるorders定義へnullable noteを追加。id・amount_cents・既存制約を保持。
- `db/Orders.sqlproj` — ownerを維持。build対象の重複・漏れ、targetとcompatibilityの設定を確認。不要なSDK更新は含めない。
- CLIソース／クエリ配置先 — OQ-03でパスと契約を確定。現時点で架空のソースパスを作らない。
- 検証コマンド／fixture配置先 — OQ-04で確定。合成データと共通実行器を使用し、今回専用の新しい実行証跡を保存する。

## データ/IF — SQL開発契約

| 項目 | 決定内容・Draft案 |
|---|---|
| engine／version | SQL Server 2025、compatibility 170。正確なbuild・edition・collation等はOQ-01。Sql170指定を実DB設定の確認と同一視しない。 |
| 製品・環境 | ローカルの破棄可能な専用隔離開発DB。合成注文100件、PIIなし、共有利用者なし、Azure接続なし。 |
| 管理主体 | Microsoft.Build.Sql 2.2.0、`db/Orders.sqlproj`。対象ordersの正本はproject内の`db/schema.sql`。ORM等との二重管理はしない。 |
| 変更前と変更 | `orders(id INTEGER PRIMARY KEY, amount_cents INTEGER NOT NULL CHECK (amount_cents >= 0))`へnullable noteを追加。既存行NULL、backfillなし、旧列削除なし。 |
| データ | idは整数主キー、金額は非負整数。noteはNULLまたは100文字以内。型・文字数定義はOQ-02。空文字はNULLと別値。 |
| クエリ | 型付き整数idをbind。戻り列はid・amount_cents・note案、既存数値型を保持しnote型はOQ-02。0または1行、順序不要。SQL文字列への値連結禁止。検索配置・CLI入力不正時の契約はOQ-03。 |
| アプリ互換性 | expand後も旧CLIのread/insert/updateを確認。note省略insertはNULL、旧更新はnoteを保持。新CLIでNULL・空文字・Unicodeを往復。旧CLIが位置依存insert等を使う場合は互換性問題として解決し、推測で合格にしない。 |
| 影響とトラック | 限定的な追加、再作成可能な隔離DB、合成100件、共有利用者なしでLite候補。Context物理不在の互換フォールバックと`--lite`でLite。risk checker実測はlite-eligible。対象変更時は再判定。 |
| 隔離検証先 | 実装承認後に作成主体・資源ID・DB名を記録。所有・接続先を確認できなければ停止。外部DB資格情報を渡さない。配置用とアプリ用権限を分離。具体設定はOQ-06。 |
| 実行上限 | statement／command／lock timeoutと適用排他はOQ-05。並行publishを無制御で走らせない。クライアントtimeoutだけでDB rollback完了と判断しない。 |
| 回復 | 処理・transaction・lock・schema・artifact／適用状態を調べ、結果不明なら再実行停止。atomic性を観測し、所有確認済み破棄可能DBを再作成して合成データ再投入する案。合成更新は失われ得るため必要な証跡を先に保存。共有DBを削除しない。 |
| 性能 | 改善要求がないため受入対象外。性能計測・改善達成の主張なし。 |
| 実行・比較コマンド | OQ-04で確定。project build、SqlPackage変更report／script、初期配置／更新、DACPACのrevision・digestと実schema比較を別確認。SQLCMD変数、pre/post script、callback、table再作成・型変換・削除をレビュー。`BlockOnPossibleDataLoss`を無効化しない。 |
| 未決事項 | OQ-01〜06。DACPAC登録状態・比較範囲とdrift検出方法もコマンド確定時に記録する。 |

## テスト方針

以下は将来の受入計画であり、今回の実行結果ではない。

- 同じ前版・合成fixtureを用い、新規構築と前版更新の最終schema・制約を比較。100件すべてのid・金額保持とnote=NULLを確認する。
- NULL／空文字／100文字は受理、101文字は切り詰めず拒否。OQ-02で確定したUnicode・補助文字・結合文字・末尾空白の境界を試す。金額0は受理、負数と重複主キーは拒否。
- 実driverのtyped bindingで一致idは正しい1行、欠損idは空集合。SQL文字列への入力連結がないことをレビューする。
- 実旧CLIのread/insert/updateと実新CLIのnote読み書きを確認。保存済みnoteが旧CLI更新でも保持されること。CLIやfixtureがなければBlockedとし、モックや別engineで置き換えない。
- DACPAC成果物整合と実schema driftを独立に検査。意図的なdriftを隔離DBで検出し、破壊的計画が止まることと停止後状態を確認。
- 二重適用は追加変更・データ喪失を起こさない。途中失敗・並行適用・ロック待ち・timeout後の処理／transaction／lock／schemaを観測し、確定した再実行／回復手順を試す。
- アプリに不要なDDL権限がなく、対象外へ接続しないことを確認。秘密・接続文字列を証跡に残さない。
- gateの共通実行器でproject checksを実行。revision／dirty状態、DB・tool実測版、fixture識別、commandと終了状態、期待値・観測値・副作用・未実施項目を既存品質レポートからexecution.jsonへ参照する。必須試験が未実施・失敗・BlockedならPASS／Doneにしない。

## Open Questionsと承認境界

要件のOQ-01〜06を未決のまま保持する。今回の成果物はDraftのみで、SQL実装・DB接続・試験やタスク承認を行わない。共有・本番・Azureへの適用はこの契約に含めない。

## Fullへの移行

共有DB、PII、破壊的変更、大規模backfill、権限／RLSやテナント分離が必要になった場合、Liteを停止してbootstrapのFull仕様フローへ戻す。変更したスコープの要件・設計・レビューと人間承認を経てから実装する。
