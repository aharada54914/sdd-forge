LiteのDraft仕様を作成しました。

- [requirements.md](specs/orders-note-postgres-intake/requirements.md)
- [design.md](specs/orders-note-postgres-intake/design.md)
- [tasks.md](specs/orders-note-postgres-intake/tasks.md)

4タスクすべて`Approval: Draft`／`Status: Planned`です。最初のT-001でschema/search path、CLI・ドライバー、Flyway初期履歴、実行上限・回復手順・検証コマンドを確定します。

構造チェック・hook確認・Lite適格性チェックは通過しました。既存スキーマは保持し、実装・DB接続・DB試験・承認更新は行っていません。一時証跡は今回専用の`.run-temp/bootstrap-orders-note-LStr7lOA/`に保存しました。

未決事項の解消と人間による承認後の入口：
`/sdd-ship:ship --lite specs/orders-note-postgres-intake/tasks.md`