# v1.20.0からの未移植機能の復旧

比較元はv1.20.0の`96afb59fcceab422024d5f2d1abc1b478d7058cf`、
開始時のmainは`e38705080761eb7ba36656a2da31e66ae279aaae`です。
両系統の共通祖先は`fcb8275a42061b8132ea88a36e69b02f4487be71`です。
v1.21.0への版番号変更は旧系統の統合を含まず、v1.22.1ではクラウド部分だけを復旧しました。
CI成功・配布物の署名・タグとの一致は、旧版の全機能の維持を証明しません。

## 復旧順序と完了条件

ユーザーは2026-11-04に次の順序での対応を指示しました。
以下は2026-11-04の復旧準備時点の記録です。統合・CIの最新状態は各PRのChecks、
公開物と署名の検証結果は[Releases](https://github.com/aharada54914/sdd-forge/releases)を参照してください。

| 順序 | 対象 | 開始時の差分 | 完了条件 | 状態 |
|---|---|---|---|---|
| 1 | 導入payload | install-payload.txtと両installerの許可リスト処理が欠落 | local/archiveで必要な実行ファイルを配置し、開発資料・cacheを除外。更新・解除と現行cloud runtimeを検証 | 完了（PR #709、CI全51ジョブ成功） |
| 1 | MCP配置 | 最小2ファイル配置とsymlink/reparse拒否が欠落 | source/targetの各境界を拒否し、失敗時に既存内容を保持する回帰を確認 | 完了（PR #709、CI全51ジョブ成功） |
| 1 | Windows ZIP | zipball/.NET展開と名前・リンク検査が欠落 | Windows PowerShell 5.1/7の実行環境でarchive境界を確認。共通仕様の重複を抑える | 完了（PR #709、Windows 5.1/7を含むCI成功） |
| 2 | managedモデル制御 | エンジン2本、契約10本、既存契約のrole_defaults、16スキルと起動検証等が欠落 | エンジンから呼出元まで統合し、実設定・失敗境界・互換経路を検証。採用と既定有効化を明示する | PR #710でCI検証中。Windows 5.1向け修正を反映し、CI確認待ち |
| 3 | CI計画 | schema 3本、planner/collector/cache、workflow配線等が欠落 | 現行必須検証を保持し、fullと選択の比較・失敗欠落検知を確認。未証明の分類はfullを維持 | PR #711・#712でツールと配線を検証。分類はinactive |
| 4 | ADR | 0036/0037/0038が欠落 | 原文のProposed状態と出自を保持し、現在の適用範囲・参照を明示 | ローカル検証済み。統合待ち |
| 4 | リリース退行検査 | 前版の機能維持を検査していない | 旧機能・契約・起動入口・導入内容の対応を検証し、未説明の欠落を公開前に検出 | ローカル検証済み。統合と実リリースでの検証待ち |

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
WindowsのZIP名・リンク属性、非ASCII名の配置を含む復旧検証は、下記のCIで完了しました。

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
共通仕様は既存PowerShell 7 suiteで検証します。

[PR #709](https://github.com/aharada54914/sdd-forge/pull/709)は統合済みです。
[CI run 41812062954](https://github.com/aharada54914/sdd-forge/actions/runs/41812062954)は、
Windows PowerShell 5.1/7を含む全51ジョブが成功しました。
[統合後のmainのCI](https://github.com/aharada54914/sdd-forge/actions/runs/41815972053)も成功しています。
この完了記録は導入経路の復旧に対するもので、後続のモデル制御・CI選択・リリースまで
完了したことを意味しません。

## 後続段階の準備状況

モデル制御は[PR #710](https://github.com/aharada54914/sdd-forge/pull/710)で検証中です。
公開されたpolicyとroleを最終的な選択の根拠にする修正を含めています。
Windows PowerShell 5.1の標準入力エンコーディングと追加検証の修正を反映しました。
CIでの確認は残っており、モデル制御全体の統合完了・全CI成功とは記録しません。

CI計画のschema、planner、collector、cacheとテストは[PR #711](https://github.com/aharada54914/sdd-forge/pull/711)、
現行CIへの配線は[PR #712](https://github.com/aharada54914/sdd-forge/pull/712)で検証します。
fullとの実比較と故障注入による検出確認は[CI評価手順](ci-selection-recovery.md)に従います。
fixtureでの成功を運用時の時間短縮や実CIでの受入完了とは扱いません。

ADR 0036・0037・0038は、原文のProposed状態と比較元コミットへの参照を保って復旧しました。
ローカルのリリース検査は、必要な実装・契約・ADR・呼出入口・配布許可リストの欠落を
拒否します。リリースworkflowは、受入対象のコミットに検証・成果物・由来情報を結び付け、
公開前のタグ移動を拒否する構成です。これらはローカルで検証した段階であり、
統合、全CIの確認、実際のリリースによる確認は今後実施します。

## 独立照合と再発防止

比較元タグと統合準備コミット`43f91e03`の公開入口・契約を独立して照合し、
報告された項目の未回収は見つかりませんでした。これはソースの照合結果であり、
実モデルの採用、クラウドへのデプロイ、CIの性能改善を証明するものではありません。

managed節の復旧でbootstrapの見出しが2つ増えました。Capability Interview Phaseから
Full-Profile Layer Interviewまでの本文は従来と同一であることを確認し、固定ハッシュを
保ったまま位置の期待値を更新しました。本文・隣接関係・未承認の位置変更を拒否する
検査は保持しています。

リリース前のソース検証は、履歴に結び付いた既存証拠も検査します。そのため
リリース対象SHAのcheckoutでは全履歴を取得します。同一SHAについて浅い履歴では
検証が失敗し、履歴取得後には成功することを独立して確認しました。
