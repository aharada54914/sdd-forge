# Sites進捗表示の確認 — 2026-11-07

## 結論
今回の3並行検証からSitesへの進捗送信は実行していなかった。このクラウド環境にはcollector/publisherのプロセス・設定・startup接続が見つからない。公開画面の機能は分離試験で動作を確認したが、今回の進捗が本番Sitesへ反映されているとは確認できない。

## 調べた対象

Sites「SDD Forge — プロジェクトの現在地」のversion 7。Site一覧・詳細・version provenanceを照合し、source commit `aa00ae51602055e87d0cb60b9e759a1453f3740f` を取得した。Worker source hashをsource-provenance.jsonに保存。sourceと本番設定は変更していない。

公開versionの更新日時は11月5日。これはコードの日時であり、R2内のsnapshot鮮度を意味しない。Sites登録automationは0件だが、別環境のpublisher稼働までは断定できない。

## 更新経路

外部collector → publisher認証付きPUT → Worker/R2 snapshot → ブラウザが5秒ごとにGET。ブラウザ再読込だけではこのworkspaceのファイルが自動収集されるわけではない。現在の起動設定にこの3検証workspaceの収集・送信は存在しない。

## 実施した機能試験

公開版と同一sourceをローカルHTTPサーバーに接続し、R2だけをメモリ上のテスト代替にした。ローカルの固定viewer/publisherはテスト専用で本番認証には使用していない。

- backend 10項目PASS: 匿名拒否、viewer書込拒否、不正publisher拒否、snapshotの保存/読取、古い更新拒否、別Origin拒否、不正schema拒否、別project拒否、health保存/読取、観測履歴生成。
- browser 19項目PASS: 概要/タイムライン/バックログ/ボード/一覧/リリース、検索と設定保存、状態/テーマ絞込、詳細とHTML文字列の安全表示、実際の5秒poll更新、一時停止/再開、履歴と既読保存、概要から絞込、390px表示、stale警告、通信障害時の直近データ保持/復旧、JS例外なし。
- desktop.png/mobile.pngはローカルfixture画面。今回の実データを本番へ反映したスクリーンショットではない。テーマにfull/SQLiteの停止を置いたが、追加した5タスクはUI試験用の合成データ。

試験初回に検索語が全件共通のテーマ名を含むことを見落としたassertionと、メモリR2のetag比較実装に誤りがあった。harnessを訂正してサーバーを再起動し、全項目を再実行して成功した。Sites sourceは変更していない。

## 本番確認の限界

通常アクセスはSitesサインイン境界で401。Sites get_siteが返すservice tokenを仕様どおりBearerで使うと境界は通過したが、Worker独自のviewer/publisherチェックがJSON `authentication-required` / 401を返した。service tokenはvisitor identityを付与しない仕様。publisher secretは設定済みだがtoolは値を返さないため使用できなかった。

shared Chrome操作toolも現在の環境では提供されていない。したがって本番snapshot、healthの最終時刻、実際のviewer表示は未確認。認証の無効化・secretの変更・既存データ上書き・新規デプロイはしていない。

## 再実行

private Site sourceはこの公開レポートへ複製していない。Sites sourceアクセスで同一commitを取得してから `SDD_SITE_WORKER_MODULE=/absolute/path/to/worker/index.js node server.mjs`、別shellで `python3 browser-test.py` を実行する。Node、Python Playwright、/usr/bin/chromiumが必要。試験サーバーは127.0.0.1:8790のみ。

今回の連携/検証不足は [Issue #728](https://github.com/aharada54914/sdd-forge/issues/728) に記録した。画面コードの確定不具合とは分類しない。今後はpublisher実行環境と収集対象を確定し、実ファイル変更→本番表示まで通して確認する必要がある。
