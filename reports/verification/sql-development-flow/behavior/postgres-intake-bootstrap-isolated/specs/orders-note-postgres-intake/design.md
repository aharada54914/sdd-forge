# 設計（lite）: orders-note-postgres-intake

Status: Draft

## 方針
既存db/schema.sqlはid INTEGER PRIMARY KEYとamount_cents INTEGER NOT NULL CHECK (amount_cents >= 0)のみを定義する。既存ソースを保持し、Flyway所有の追加migrationによるexpandを計画する。noteはnullableで最大100文字をDBで保証する型を候補とするが、具体的DDLは承認後に作成する。旧形式撤去や既存値の書換えは含めない。

## 変更/新規ファイル（実装候補・今回未変更）
- db/migrations/ — Flyway版付きmigration。初期履歴と版の確定後にファイル名を決める。
- Python CLIの接続・検索箇所 — 実体未提供。実装対象パスとドライバーを確定する。
- 隔離DB fixture・project checks — 既存のチェック機構と共通実行器へ接続する。パス・コマンド未確定。
- db/schema.sql — 既存source artifact。migrationとの関係・更新要否を決めるまで変更しない。

## SQL開発契約
| 項目 | 決定内容 |
|---|---|
| engine/version | PostgreSQL 18.0。実測版は未確認。encoding、collation、timezone、extensions未確定 |
| 製品・環境 | ローカル・破棄可能な専用DB。共有利用者・クラウドなし |
| 管理主体 | Flyway 13.12.1のみがdb/migrationsを管理。設定・履歴構成は未提供 |
| 変更前と変更内容 | ordersへnullable note追加。既存行はNULL、id・金額を保持。既存キー・非負/NULL不可制約維持 |
| データ | 合成注文100件、PIIなし。note NULL/空文字/100文字/Unicode。101文字拒否。追加の日時・参照・丸め要件なし |
| クエリ | 整数idをドライバーでバインド。識別子はアプリ所有の固定値。出力案id・amount_cents・note、一致1行/不在空集合、順序不要 |
| 互換性 | 追加前後の旧CLI読書きと追加後の新CLI読書きを検証。SELECT *、位置依存、列指定なしINSERT、transaction境界を確認。未検証 |
| 影響とトラック | 100件の限定的な追加、backfillなし。Lite適格。破壊的変更や共有環境へ広がるならFullへ再判定 |
| 隔離検証先 | 作成責任者・DB名/資源ID・作成主体の記録を実行前に確定。外部接続資格情報を渡さず、app最小権限とmigration権限を分離 |
| 実行上限 | statement/lock/資源上限は未確定。並行適用はFlywayの排他・履歴を使用。timeoutだけでDB側停止を断定しない |
| 回復 | transaction/atomic性を対象migration単位で確認。処理・transaction・lock・schema・履歴と全保持データを観測後、承認済み手順で回復。結果不明の再実行禁止。自動repair/clean/baseline/downは禁止。具体手順・損失範囲は未確定 |
| 性能 | 改善要求なし、測定は受入対象外。lock/statement上限の確認は失敗時安全性のため行う |
| 実行・比較 | Flyway履歴/checksum検証と実schema比較を分離。正確なproject checks・比較範囲・コマンドは未確定 |
| 未決事項 | requirements.md Open Questions全項目。T-001完了前に後続実装・接続しない |

## テスト方針
requirements.mdの受入条件を、承認後にPostgreSQL 18.0/Flyway 13.12.1の隔離実環境で検証する。新規・更新、全値照合、境界、新旧CLI、履歴とdrift、故障・並行適用・timeoutを対象とする。モックや他engineで合格に置換しない。既存migrationを書き換えず、独自runnerは作らない。
実行報告に共通実行器のexecution.json、revision/dirty状態、実測版、fixture識別、command/終了状態、期待結果、観測副作用、未実施項目を残す。秘密・接続文字列は保存しない。一時証跡は各呼出しで新規作成する.run-temp配下に置き、今回のものを次回の実行証明に流用しない。

## 状態と移行
今回の調査はファイル読取りと仕様入口チェックのみ。SQL実装・DB接続・DB試験は未実施。未確定事項の解消と人間の承認を経て既存shipフローへ進む。共有DB・PII・破壊的移行などへ範囲変更する場合、Full interviewerへ切り替え、仕様・承認を再確認する。
