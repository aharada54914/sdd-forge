Draft仕様を作成しました。

- [requirements.md](specs/orders-note-mysql-intake/requirements.md)
- [design.md](specs/orders-note-mysql-intake/design.md)
- [tasks.md](specs/orders-note-mysql-intake/tasks.md)

全3タスクは`Draft / Planned`です。DB接続・SQL実装・承認変更は行っていません。既存schemaも保持しています。

DB設定、ドライバー、Flyway取り込み方法、時間上限・回復手順・検証コマンドは未確定事項として明記しました。最初のT-001で解決し、人間による仕様確認・タスク承認後にshipへ進みます。

今回専用の証跡は`.run-temp/bootstrap-orders-note-cwetfyl_/`に保存しました。