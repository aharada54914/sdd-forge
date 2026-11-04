# v1.20.0からの未移植機能の復旧

比較元はv1.20.0の`96afb59fcceab422024d5f2d1abc1b478d7058cf`、
開始時のmainは`e38705080761eb7ba36656a2da31e66ae279aaae`です。
両系統の共通祖先は`fcb8275a42061b8132ea88a36e69b02f4487be71`です。
v1.21.0への版番号変更は旧系統の統合を含まず、v1.22.1ではクラウド部分だけを復旧しました。
CI成功・配布物の署名・タグとの一致は、旧版の全機能の維持を証明しません。

## 復旧順序と完了条件

ユーザーは2026-11-04に次の順序での対応を指示しました。
状態は成果物と検証結果がそろってから更新します。

| 順序 | 対象 | 開始時の差分 | 完了条件 | 状態 |
|---|---|---|---|---|
| 1 | 導入payload | install-payload.txtと両installerの許可リスト処理が欠落 | local/archiveで必要な実行ファイルを配置し、開発資料・cacheを除外。更新・解除と現行cloud runtimeを検証 | 作業中 |
| 1 | MCP配置 | 最小2ファイル配置とsymlink/reparse拒否が欠落 | source/targetの各境界を拒否し、失敗時に既存内容を保持する回帰を確認 | 作業中 |
| 1 | Windows ZIP | zipball/.NET展開と名前・リンク検査が欠落 | Windows PowerShell 5.1/7の実行環境でarchive境界を確認。共通仕様の重複を抑える | 作業中 |
| 2 | managedモデル制御 | エンジン2本、契約10本、既存契約のrole_defaults、16スキルと起動検証等が欠落 | エンジンから呼出元まで統合し、実設定・失敗境界・互換経路を検証。採用と既定有効化を明示する | 未着手 |
| 3 | CI計画 | schema 3本、planner/collector/cache、workflow配線等が欠落 | 現行必須検証を保持し、fullと選択の比較・失敗欠落検知を確認。未証明の分類はfullを維持 | 未着手 |
| 4 | ADR | 0036/0037/0038が欠落 | 原文のProposed状態と出自を保持し、現在の適用範囲・参照を明示 | 未着手 |
| 4 | リリース退行検査 | 前版の機能維持を検査していない | 旧機能・契約・起動入口・導入内容の対応を検証し、未説明の欠落を公開前に検出 | 未着手 |

## 採用記録と未確認事項

旧policyのClaude候補3件は採用記録が空です。CodexのAstra実装役には採用記録があります。
採用0件でも、選択不能を拒否する境界には意味があります。
既存の固定モデル指定は残っており、managed入口の無条件強制はClaudeの既存利用を停止し得ます。
過去の採用記録やfixture成功を、新しいhostでのモデル実行成功とは扱いません。

`capture-claude-canary-result.py`は比較元タグと取得済み履歴では確認できませんでした。
出自のない同名スクリプトは作りません。歴史的なspec/review/verification記録の欠落数を、
そのまま製品機能数として数えません。

調査では隔離したBashのFilesOnly導入で、MCPソース外へのsymlinkを現行処理が受理し、
外側のindex.jsと余分なdistファイルをコピーすることを確認しました。
実ユーザー設定の変更、MCP登録、JavaScript実行、外側への書込みは行っていません。
Windowsでの同一ケース、および非ASCII/PAX archiveの実機検証は復旧段階で実施します。

既存の入力検証、リテラルパス、通信期限、Bash 3.2とPowerShell 5.1/7の互換性修正、
クラウド認可境界、現行の必須CIを復旧先の条件として保持します。

## 導入経路の復旧検証

両installerへ同じpayload許可リストと既存runtimeの必須ファイル検査を戻しました。
MCPはindex.js/package.jsonのみを配置し、ソース階層のリンクを追跡しません。
WindowsではZIPの名前とリンク属性を展開前に検査し、.NETで展開します。

Linux上のBashとPowerShellで、local/archive、旧配置からの更新、欠落・不正入力時の
既存配置保持を含む13テストが成功しました。各実行のWindows専用2件はskipです。
改行を含む親ディレクトリのリンク拒否は、修正前の失敗と修正後の成功を確認しました。
既存Bash installer suiteは63成功、PowerShell core suiteも成功しています。
Windows PowerShell 5.1ではZIP/.NETに関わる3ケースのみを繰り返し、
共通仕様は既存PowerShell 7 suiteで検証します。実際のWindows CI結果は確認後に追記します。
