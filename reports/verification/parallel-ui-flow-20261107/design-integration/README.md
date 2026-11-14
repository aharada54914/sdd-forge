# 外部デザイン連携の再評価 — 2026-11-07

## 判定

**full / full+SQLiteの外部デザイン連携と、それによるUI改善は未達。** 前回は実行側が `ds_profile: none` を選択したため、当該連携を検証対象から外していた。これはユーザーが求めるUI改善ループの試験として不十分だった。

追跡: [Issue #729](https://github.com/aharada54914/sdd-forge/issues/729)。通常fullは別途 #726 によって仕様レビュー入口でも停止する。

## 確認した事実

- 前回full/SQLiteともux-specにnone、mockup skippedを記録。デザイン取得/送信/外部レビューは実行していない。
- プラグインにdesign-sync-loopとvisual-verify-loopの手順はある。customが対象で、DesignSyncやClaude Previewの実ツール提供を前提にする。
- Work側のtool検索とPlugin Management検索に加え、認証済みverify-codexの独立probeを実施。native catalog 431件からDesignSync、Claude Design、Claude Previewの一致なし。外部呼出し0。
- resolverの実測はnone→skip、custom+provider unavailable→manual（pull/upload双方）。resolverには外部API操作はなく、この判定を通信成功と呼ばない。
- ローカルpolicy 12テストと構造/契約121チェックは成功。mockの判定/文書契約の検査であり実デザイン往復の成功ではない。
- visual-verify-loopのweb経路はClaude Preview指定。ツールがない場合はskipするため、Playwrightで画面を開けたことだけではその連携を実行した証拠にならない。

## 合格条件

fullとfull+SQLiteそれぞれで、実デザインproviderへの接続→project/tokens/components取得→mockupの送信とレビュー結果取得→REQ/ACに沿った改善反映→before/after画面とコード差分→UI操作/SQLite再起動永続化の再検証まで実測する。manual/skipや単なるローカルUI改善を外部連携成功と扱わない。

SQLiteは保存方式で、デザイン連携可否はUI/custom設定と利用できるprovider/previewツールによる。提供されていないサービスへの架空の呼出しや、別providerの成功をClaude Design成功とする代替はしない。

## 残る依存

この環境で使えるDesignSync/Claude Previewの接続経路が必要。該当pluginは現在の検索では見つからず、手動認証すら試せるprovider endpointが提供されていない。別providerを使う場合は対応アダプタ・入力/出力契約・差分の検証が必要であり、現行のFigmaファイルimport支援を双方向同期と呼ばない。

今回外部アップロード、remote project作成、既存デザイン変更、full/SQLiteの成果物改変は行っていない。code修正ではなく実連携の不足を記録した。
