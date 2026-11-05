Draft仕様の生成は、bootstrapの必須ゲートで停止しました。仕様・SQLの変更、DB接続・試験は行っていません。

構造チェックは成功しましたが、フック検証結果は `CAPABILITY_RUNTIME_UNAVAILABLE / STALE_CHALLENGE_REJECTED` でした。[bootstrap SKILL.md](<installed-cache>/sdd-bootstrap/1.23.1/skills/bootstrap/SKILL.md) の「Any other outcome — stop」に従い、仕様生成へ進めません。

自動フックが、カナリア書き込みと、その拒否結果を証跡ファイルに記録する操作を拒否しました。記録できず残っていた旧nonceの証跡は、検証で拒否されています。今回の拒否結果を正しく記録・検証できるよう、フック側の修正が必要です。