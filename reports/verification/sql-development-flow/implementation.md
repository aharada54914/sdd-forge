# SQL開発フローの実装記録

対象はユーザーが承認した [T-001〜T-005](../../../specs/sql-development-flow/tasks.md)。
実装と受入検証を進めている。未実施の確認を完了扱いにしない。

## 実装した内容

| 対象 | 実装 |
|---|---|
| T-001 | 既存implementationプラグインに公開入口 `sql-develop` を追加。DB未接続で対象・管理主体・影響を整理し、完全な要求を既存bootstrapへ渡す |
| T-002 | 共通SQL手順を仕様化・実装・独立gateから参照。既存承認・状態・managed routing・Contextを維持し、新規runner／parser／DB接続APIは追加しない |
| T-003 | PostgreSQL 18、SQL Server 2025、MySQL 8.4を各1回実行するLinux隔離CIと実DB試験を追加。受入検証中。CLIとimage digestをfixtureに固定 |
| T-004 | 3ホストmanifestと実installerによる配布・個別cache参照を検証。READMEから利用文書へ接続し、Azure SQL／RDSの担当分担と運用引き継ぎを追加 |
| T-005 | 実装担当外のレビューと、分離したCodex環境での実利用評価を実施中 |

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
  アップロードで拒否されたため、正規絶対パスと診断出力へ修正して再確認する。
  この時点で3DBの受入は未完了であり、成功とは扱わない。
- Codexのbootstrap試験では、真正のhook拒否応答をshell経由で記録する操作も保護に拒否された。
  通常ファイル用のpatch操作で応答を保持した再試行では `HOOK_ACTIVE` と仕様生成を観測した。
  guardの弱化や確認結果の代作は行わない。初回・再試行は評価記録で区別する。

## 対象外・制限

Azure SQL Database／Managed Instance、RDS／Auroraの実サービス受入、本番適用、
本番性能・復旧保証は含めない。性能改善を目的とする参照案件ではないため、
クエリ高速化の実証とは扱わない。WindowsネイティブDBの動作確認でもない。

Claude／Codex／Copilotは3ホストの配布形式を検証する。実モデルの対話評価はCodexで行い、
Claudeの既定プロファイルは未認証だったためClaude実モデル評価は未実施。
単発の受入ケースであり、モデル間比較や統計的な成功率を示すものではない。
