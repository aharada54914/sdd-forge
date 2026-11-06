# SQL開発フローの実装記録

対象はユーザーが承認した [T-001〜T-005](../../../specs/sql-development-flow/tasks.md)。
実装、3エンジンの実DB試験、実モデルによる利用評価、独立レビューを完了した。
実装コミット `a032fea1` の全56ジョブと必須集約が成功し、T-001〜T-005を完了した。

## 実装した内容

| 対象 | 実装 |
|---|---|
| T-001 | 既存implementationプラグインに公開入口 `sql-develop` を追加。DB未接続で対象・管理主体・影響を整理し、完全な要求を既存bootstrapへ渡す |
| T-002 | 共通SQL手順を仕様化・実装・独立gateから参照。既存承認・状態・managed routing・Contextを維持し、新規runner／parser／DB接続APIは追加しない |
| T-003 | PostgreSQL 18.6、SQL Server 2025、MySQL 8.4.13のLinux隔離CIと実DB試験が成功。CLIとimage digestをfixtureに固定 |
| T-004 | 3ホストmanifestと実installerによる配布・個別cache参照を検証。READMEから利用文書へ接続し、Azure SQL／RDSの担当分担と運用引き継ぎを追加 |
| T-005 | 実装担当外のレビューで未解決指摘なし。分離Codex環境での実利用評価が成功。全56ジョブと必須集約が成功 |

実DB試験は生成した合成データだけを使い、ローカルDocker socketから作成した
資源ID・所有labelを検証して片付ける。共有／本番のDSNは受け取らない。
テスト用秘密は毎回生成し、コマンドの引数と保存証跡へ値を出さない。
SQL Serverの一時publish profileは所有者のみ読める権限で作成する。

## 検証上の判断と修正

- 個別plugin cacheでは別pluginへの相対パスが成立しないため、ホストのスキル索引、
  または同ホストで有効なplugin登録から参照先を解決する。未知の別versionを探索して代用しない。
- MySQLの途中失敗は実Flywayの失敗履歴まで確認する。元DBの履歴を消さず、
  変更前backupを別の所有DBへ復元し、修正した未適用migrationでroll-forwardする。
- CIの最初の2回はjob環境変数の無効なcontextで起動前に失敗した。
  `runner.temp` を利用可能な `github.workspace` 基準へ修正し、actionlintで赤→緑を確認した。
  これらの実行はDB試験成功には数えない。
- 実DBの初回PostgreSQL試験は履歴改変の検知ケースで失敗した。さらにartifactの相対親パスが
  アップロードで拒否された。正規絶対パスと診断出力に修正して再実行した。
  Flyway 13.12.1のJSON validateは検証失敗でもexit 0となるため、構造化された失敗内容と対象を確認する。
  当初の失敗を成功に数えず、後続の実行で3DBの成功を確認した。
- Codexのbootstrap試験では、真正のhook拒否応答をshell経由で記録する操作も保護に拒否された。
  通常ファイル用のpatch操作で応答を保持した再試行では `HOOK_ACTIVE` と仕様生成を観測した。
  guardの弱化や確認結果の代作は行わない。初回・再試行は評価記録で区別する。
- MySQLのDDL前後では、DDLまでの行だけが暗黙commitされ、その後のDMLはrollbackされた。
  実状態に合わせたfixtureで失敗履歴・再実行拒否・別DBへの復元と再適用を確認した。
- SQL Serverの隔離ネットワークへホストのSqlPackageを接続するため、所有コンテナのnetwork namespaceだけを使う。
  管理権限はnamespaceへの移動に限り、クライアント起動前に元のUID/GIDへ戻す。
  sqlcmdのtimeoutはexit 0の場合もあるため、診断・開始マーカー・rollback・セッション終了・実測時間を合わせて確認する。
- Windowsの既定文字コードに依存した既存テストは、UTF-8の文書を明示的にUTF-8で読むよう修正した。
  Lite仕様化の14行追加は既存の正確なsuccessor登録に反映し、過去の候補・MANIFEST・承認状態は変えていない。
- 残るContext callerの見出し番号も6から7へ更新し、本文・契約ハッシュ・隣接条件の保持を確認した。
  Windowsの一時cloneで証拠パスが長さ制限に達したため、証拠の内容を保ったまま梱包名を短縮した。
  A2の現在のCI候補にはSQL 4ジョブと最新の集約を同期した。過去の固定候補は変更せず、同期を公開承認とは扱わない。

- run 42137234565ではSQL Server試験自体が成功しても、実行後の作業ツリーがdirtyとなり必須集約が拒否した。
  SqlPackageの作業場所を一時ビルド領域に揃え、前後のGit状態を証拠に含めて試験内でも一致を検査する。
  元の生成ファイル名は旧証拠に記録されていないが、修正後のrun 42145719843では前後ともGit状態が空で、
  試験内の検査とreceiptのclean_before／clean_afterが成功した。独立レビューでも入力・実行場所・削除を照合した。
  旧run 42137234565のmacOS復旧ジョブはキャンセルされており、この旧runを全CI成功とは扱わない。

## 受入証拠

- [実DB CI](https://github.com/aharada54914/sdd-forge/actions/runs/42145719843)：PostgreSQL、MySQL、SQL Server、配布契約の4ジョブ成功。
  [保存した実測結果とハッシュ](ci/runtime/manifest.json)は、PR合成コミットと各入力のSHA-256を保持する。
  DB試験の60／68／48レコードには準備・繰返し確認も含むため、独立した176件の利用シナリオとは数えない。
  全DBで所有資源の削除成功・削除エラーなしを確認した。同runの全56ジョブと[必須集約](ci/required-checks.json)も成功した。対象head・合成コミット・ジョブ一覧は[受入記録](ci/acceptance.json)に保存した。
- [実モデルの入口・負例評価](behavior/README.md)：未指定・高影響・承認不足・未知対象・未信頼macroを確認。
  3エンジンの要求から公開bootstrap経由でDraft仕様を作り、入口でSQL実装・DB接続・承認の代作をしないことを確認した。
- [正常系の実利用評価](behavior/positive/README.md)：固定した合成PostgreSQL案件で初期失敗を確認後、公開shipが比較条件を1か所修正。
  自然なImplementation Completeを観測し、別CLIスレッドのLite gateが新しい実DBで確認してDoneへ進めた。
  最終fixtureはclient 10秒、statement 5秒、lock 1秒。固定テスト等の不変性と4実行のDB削除を照合した。
  初期fixtureの45秒の制約不一致は限定証拠として残し、合格根拠には修正版を使う。
- 実装していないレビュー担当が、上記の生の測定結果・入力ハッシュ・副作用・共通手順参照を独立照合した。
  MySQL再実行拒否の指摘を修正し、最終レビュー範囲に未解決の指摘はない。
- [公開状態の回帰検証](ci/publication-preservation.json)：既存候補とMANIFESTのバイト一致を確認。
  Bash／PowerShellのship-trackとphase2、既存133件mutation matrixが成功。既存runner-pathの1件はskipとして保持する。
  [文字コード回帰](ci/encoding-regression.json)はcp1252の失敗を再現後、5対象テストすべてが成功した記録。
- [Context caller](ci/context-anchor-preservation.json)は旧契約ハッシュを保持して位置だけを更新。
  [証拠パス](ci/evidence-path-compaction.json)は移動76ファイルの内容不変とmanifest142件の一致を確認。
  [現在のCI候補](ci/candidate-workflow-preservation.json)はliveと完全一致、過去の固定成果物は不変。
  候補生成のBash／PowerShell試験はそれぞれ32件成功し、ジョブ削除等の否定検査も維持した。
- [CI証拠の登録回帰](ci/receipt-regression.json)：既存テストの期待数18にSQL 4系統を追加し、
  合計22の登録と各SQLジョブ／単一suite／空matrixの対応を検証した。
  元の失敗を再現後、証拠収集・照合に関する92件すべてが成功。producerや厳密な照合条件は変更していない。

## 対象外・制限

Azure SQL Database／Managed Instance、RDS／Auroraの実サービス受入、本番適用、
本番性能・復旧保証は含めない。性能改善を目的とする参照案件ではないため、
クエリ高速化の実証とは扱わない。WindowsネイティブDBの動作確認でもない。

Claude／Codex／Copilotは3ホストの配布形式を検証する。実モデルの対話評価はCodexで行い、
Claudeの既定プロファイルは未認証だったためClaude実モデル評価は未実施。
単発の受入ケースであり、モデル間比較や統計的な成功率を示すものではない。

## 完了判定

[品質レポート](quality.md)に基づきT-001〜T-005をDoneとした。
この判定は承認済み初版の実装・隔離受入を対象とし、実クラウド・共有／本番への適用やリリース承認を含まない。
