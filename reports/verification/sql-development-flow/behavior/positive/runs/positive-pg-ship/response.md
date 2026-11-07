T-001 は包含比較 `>=` へ修正しましたが、現在は **Blocked** です。

`npm test` が指定private Unix socketへの接続で `Operation not permitted` となり、受入確認を実行できませんでした。独立lite-gateは未実行で、Doneにはしていません。

証跡は今回専用の `.run-temp/ship-order-filter-20261105/implementer/`、詳細は[実装報告](reports/implementation/order-filter/T-001.md)に保存しました。既存socketへのアクセス回復後に再開が必要です。