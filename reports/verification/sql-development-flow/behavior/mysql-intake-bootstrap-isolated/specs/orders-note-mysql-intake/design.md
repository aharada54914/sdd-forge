# 設計（lite）: orders-note-mysql-intake

Approval: Draft

## 方針

既存ソース`db/schema.sql`を確認した。現行は`orders(id INTEGER PRIMARY KEY, amount_cents INTEGER NOT NULL CHECK (amount_cents >= 0))`。CLIやdriver、Flyway設定、migrationファイルは今回のソース調査では確認できなかった。今回schema.sqlは変更しない。
追加列のみのexpandを計画し、既存データのbackfillやcontract（撤去）は行わない。旧アプリの実SQLとの互換性を確認してから方式を確定する。SQL実装やDBへの接続は人間のタスク承認後とする。

Lite判定: bootstrapの構造チェックOK、今回nonceのhandshakeはHOOK_ACTIVE。sdd/project-context.yamlは物理的に存在せずCOMPATIBILITY_FALLBACK、明示--liteとAGENTS.mdのlite指定を採用。入力のrisk checkerはlite-eligible。専用の再作成可能DB・合成100件・共有利用者なし・限定的追加というSQL条件も満たす。レビュー3ループ、ADR、traceability、専用evidence-bundleは作成しない。

## 変更/新規ファイル（将来の承認対象）

- `db/migrations/` — Flywayの版付きmigration。具体的ファイル名と前版取り込みはQ-04待ち。
- `db/schema.sql` — 現行ソースとの関係と更新の要否をQ-04で決定。migrationと別の適用経路にしない。
- Python CLIの検索実装・接続設定 — パスはQ-03で既存構造から確定。
- プロジェクト検証コマンド・合成fixture — パスと実行器への登録方法はQ-07待ち。

## SQL開発契約 / データ・IF

| 項目 | 決定内容 |
|---|---|
| engine/version | MySQL 8.4.0。MariaDB等への読み替え不可。storage engine、SQL mode、charset/collation、timezoneはQ-01/02 |
| 製品・環境 | ローカル専用の破棄可能DB。共有利用者・PII・クラウドなし |
| 管理主体 | Flyway 13.12.1とdb/migrationsのみ。既存取り込みと版管理はQ-04。適用済みファイル変更なし |
| 変更前と変更 | 上記現行ordersにnullable・最大100文字のnoteを追加。具体的型/default/DDL方式は設定確定後に決める。既存行noteはNULL、backfillなし |
| データ | 注文100件、合成のみ。idは整数PK、amount_centsは非負整数NOT NULL。既存の型・キー・値を維持。日時列・参照キー追加なし。保持期間は検証資源の寿命内 |
| クエリ | 整数idをdriverの値bindingで渡す。固定の表・列を使用。結果はid/amount_cents/note、一致1行・不一致0行、順序不要。placeholderやCLI表示形式はQ-03 |
| アプリ互換性 | 旧アプリ読取・登録・更新を保持。note省略登録可、旧列更新でnote保持。新検索は追加後に有効化。旧アプリのSQL確認が前提 |
| 影響とトラック | 追加列のみ、100件、性能改善なし。Lite。共有/本番や破壊的変更へ拡大時は再判定 |
| 隔離検証先 | Q-05で作成/破棄責任・正確な資源IDの記録を確定。偶然の環境変数の接続先や本番コピーを使用しない。外部DB資格情報・到達性を渡さず、migrationとアプリ権限を分離 |
| 実行上限 | Q-06でstatement/lock/client時間・資源上限を確定。Flyway排他と履歴を利用。client終了をDB側停止と見なさない |
| 回復 | Q-06でroll-forwardまたは専用DB再作成・前版復元の手順/損失を確定。MySQL DDLの暗黙commitとmigration全体の非atomic性を前提に残存状態を確認。repair/clean/baseline/downで自動的に失敗を消さない。状態不明なら再試行停止 |
| 性能 | 改善要求なしのため比較・高速化主張・性能閾値は対象外。lock/timeout上限の検証は別途必要 |
| 実行・比較コマンド | Q-07未確定。Flywayによる履歴/checksum検証と、対象ordersの列・型・NULL/default・PK/CHECK等の実schema比較を分離。具体的コマンドや合格ログを捏造しない |
| 未決事項 | requirements.md Q-01〜07。未解決のまま実装・接続しない |

## テスト方針

requirements.mdの受入表を全件実施する。空DB構築と前版100件からの更新でschemaと期待する全キー・値・制約を比較する。件数のみで判定しない。旧CLIの実コードがなければ互換性は未検証とする。
NULL・空文字・100/101文字・UnicodeをDBとPython経由で往復確認し、厳密拒否と既存値不変を確かめる。金額0/負値、重複PK、検索一致/不一致、parameter bindingを検証する。
失敗注入は隔離DBのみ。複数文DDLの途中失敗、二重/並行適用、lock待ち、timeout/切断後を対象に実行中処理・transaction・lock・schema・履歴を記録する。backfill再開試験はbackfillなしのため対象外。

承認後の実行はプロジェクトチェックとして既存gateの共通実行器に登録する。証跡は毎回新しい`.run-temp/<run-id>/`に保存し、他の呼び出しから流用しない。revision/dirty状態、DB/tool実測版、fixture識別、command/終了状態、期待値・観測結果・副作用・未実施項目とexecution.jsonを既存の実装/品質報告から参照する。秘密や接続文字列は残さない。必須検証未実施ならPASS/Doneとしない。今回はこれらの検証を実施していない。

## Open Questions

requirements.md Q-01〜07を正本とする。設定や検証コマンドを暫定値で確定済みと扱わない。最初のDraftタスクで解決し、仕様を人間が確認するまで後続実装を止める。

## Full SDDへの移行

共有DB・本番・PII・破壊的移行等が追加された場合はLiteを停止し、sdd-bootstrap-interviewerによるFull仕様・レビュー・承認へ移る。現Draftを実装許可に読み替えない。
