# 要件（lite）: orders-note-mysql-intake

Approval: Draft

- **Issue/出典**: `REQUEST.md` および今回提示された sql-develop 引き渡し。
- **目的**: Python注文管理CLIで注文の任意メモを保持し、整数idを安全に指定して注文を取得できるようにする。
- **今回の成果物**: 仕様のDraftのみ。SQL・アプリ実装、DB接続、migration適用、承認は未実施。

## ユーザーストーリー / 要求

- REQ-001: MySQL 8.4.0のordersにNULLまたは最大100文字のnoteを追加する。NULLと空文字を区別し、101文字以上は切り捨てず拒否する。Unicodeを保持する。文字の数え方と対応範囲はQ-02で確定する。
- REQ-002: 既存の整数主キーid、一意性、amount_centsの整数・NOT NULL・0以上の制約を保持する。更新対象100件のid・amount_centsを値単位で保持し、追加直後のnoteはすべてNULLとする。
- REQ-003: 整数idをSQLの値としてパラメーター束縛する。出力列はid（整数）、amount_cents（非負整数）、note（NULLまたは文字列）。一致は1行、不一致は空集合。順序指定不要。未入力idと不一致idを混同しない。未入力・非整数時のCLI仕様はQ-03で確定する。
- REQ-004: 旧アプリの読み書きを保持する。note省略で新規登録でき、既存列のみの更新でnoteを失わない。新アプリの検索は追加後スキーマに対して動作する。
- REQ-005: Flyway 13.12.1のみがdb/migrationsを管理する。適用済み版付きmigrationを変更せず、独自runnerやORMとの二重管理をしない。
- REQ-006: 新規構築と前版更新で最終スキーマ・制約を一致させる。履歴・checksumの検証と実スキーマdrift検出を別に行う。
- REQ-007: 検証はローカルの破棄可能な専用DB、合成注文100件、PIIなし、共有利用者なし、クラウドなしに限定する。作成した資源のみ識別して後片付けする。
- REQ-008: 二重適用、途中失敗、ロック待ち、timeout・切断後のDB側処理・transaction・lock・schema・履歴を観測する。状態不明なら再試行せず停止する。

## 受入条件（実装承認後に実測）

| ケース | 期待結果 |
|---|---|
| 空DBの構築／前版からの更新 | 同じ最終schema・型・NULL/default・制約。100件の期待キーと金額を全件比較し保持。更新直後noteは全件NULL |
| note境界 | NULL、空文字、100文字を区別して保存・取得。101文字は拒否、変更前の値を保持。確定したUnicode範囲で往復と100/101文字境界を確認 |
| 金額・キー | 金額0を受理、負値・NULLを拒否。主キー重複を拒否し既存値を保持 |
| 検索 | 存在するidは期待3列の1行、不一致は0行。ドライバーのbindingを確認し、入力をSQL構文として連結しない |
| 新旧互換性 | 移行前後で実際の旧CLI読取・登録・更新を検証。note省略登録はNULL、旧列更新はnoteを保持。移行後に新検索が成功 |
| 履歴とdrift | Flywayの版・checksum異常と、履歴を変更しない対象schema変更をそれぞれ検出 |
| 再適用・並行適用 | 適用済み版を再実行しない。並行時はownerの排他が働き、重複列・データ変更なし |
| 失敗・ロック・timeout | 合意した上限で停止し、残存処理・lock・schema・履歴を確認。既に確定したDDLを未適用と誤認しない。承認済み回復後にschema・100件の値を再確認 |
| 隔離・権限 | 記録した専用資源だけへ接続・適用・破棄。アプリに不要なDDL権限なし。秘密を証跡へ保存しない |

## スコープ外

共有・本番DB、クラウド、PII、性能改善・性能比較、backfill、旧列撤去、note入力UIの拡張、別engineでの代替合格。

## Open Questions

すべて未確定。実装承認の前にdesign.mdの同番号とともに解決する。

- Q-01: storage engine、SQL mode、timezone、DDL方式とそのlock/rebuild条件。
- Q-02: charset/collation、Unicode対応範囲、文字数の定義。101文字を黙って切り捨てないDB・接続設定。
- Q-03: Python DBドライバー・版、binding方式、既存CLI/SQL・transaction境界・出力形式、未入力/非整数idの扱い。旧アプリにSELECT *や列リストなしINSERTがあるか。
- Q-04: Flywayの導入方法、前版の識別、既存schemaの取り込み方、migrationの開始版・命名。自動baselineは行わない。
- Q-05: 専用DBの識別・作成/破棄責任、資源上限、権限分離、container使用時のdigestと利用条件。
- Q-06: statement/lock/clientの時間上限、キャンセルとDB側停止の確認、途中失敗の再現方法、回復手順と損失範囲。
- Q-07: 実行可能な検証・lint/build/testコマンド、schema比較手段、100件fixtureの値・分布・識別子。
