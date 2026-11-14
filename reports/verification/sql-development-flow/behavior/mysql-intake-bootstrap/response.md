Draft仕様は未生成です。構造チェックは通りましたが、必須ハンドシェイクが `CAPABILITY_RUNTIME_UNAVAILABLE / STALE_CHALLENGE_REJECTED` となり停止しました。既存ソースの変更・実装・DB接続・承認変更は行っていません。

適用した [bootstrap/SKILL.md](<installed-cache>/sdd-bootstrap/1.23.1/skills/bootstrap/SKILL.md) は、`HOOK_ACTIVE` 以外では “stop with CAPABILITY_RUNTIME_UNAVAILABLE” と規定しています。このため仕様生成へ進めませんでした。

自動フックは、カナリア試行結果の証跡保存も保護対象への変更と判定して拒否しました。そのため今回のnonceを保存できず、検証では既存証跡との不一致が報告されています。再開には、この証跡保存経路の修正が必要です。