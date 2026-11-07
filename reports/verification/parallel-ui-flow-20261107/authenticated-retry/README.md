# 認証後の3並行再試行

Codex CLI 0.159.2、installed plugins 1.23.1（検査対象source e768ee09）。ユーザーがdevice認証を完了し、分離したログインprofileをverify-codexへ参照させた。model-probe.jsonに実応答OK / turn.completedを記録。認証Issue #724は解消・close済み。

## 到達点

- lite: native HOOK_ACTIVE、仕様3文書生成。ユーザーがテストのため承認不要と明示した後、親がApprovedをテストfixtureとして設定（通常人間承認経路の検証ではない）。shipで対象外の認証文言を誤検出しfull-requiredで停止。文言の意味を保った回避の再試行中。
- full: native HOOK_ACTIVE、仕様7文書＋契約＋ADR生成。installed spec-review-precheckのパス解決不具合でexit1。実装前に停止。
- full+SQLite: native HOOK_ACTIVE、仕様7文書＋契約＋ADR生成。同じパス解決不具合でexit1。実装・SQLite UI検証前に停止。

## 登録Issue

1. [#725](https://github.com/aharada54914/sdd-forge/issues/725): canary拒否の生応答をheredocで証拠保存するとhookが誤拒否。lite/SQLiteのnative実結果と親の最小再現あり。保護を無効化せず保存方法の変更で回復し、3経路ともHOOK_ACTIVE。
2. [#726](https://github.com/aharada54914/sdd-forge/issues/726): installed spec-review-precheckがcheckout配置を前提にrootを計算し、cache内の存在しないlibを参照。full/SQLiteと親側で再現。source版も利用者projectではなく開発repoを指すため単純な差替えは不可。
3. [#727](https://github.com/aharada54914/sdd-forge/issues/727): liteの明示的な除外仕様やワークフロー承認の語を製品リスクとして全文keyword検出。checkerの現契約と生成文書/ship入力の不整合。親側でも明示的な対象外文でexit10を再現。

## 証拠と制約

`*-repro.json`は親側の独立再現。各ディレクトリに仕様・native gate結果・エラー抜粋を保存。raw rolloutや認証情報は含めない。通常経路の停止と、保存方式/仕様文言の回避を区別する。前回の独立診断用アプリ成功は今回のSDD完走証拠ではない。

fullの後段host identity ledgerの対応可否はprecheck停止により未到達で、確定バグには分類しない。認証は復旧したが、変更なしの通常3経路を完走できるとは結論できない。
