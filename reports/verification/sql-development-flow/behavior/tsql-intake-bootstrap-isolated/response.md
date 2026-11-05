LiteのDraft仕様を作成しました。

- [requirements.md](specs/orders-note-tsql-intake/requirements.md)
- [design.md](specs/orders-note-tsql-intake/design.md)
- [tasks.md](specs/orders-note-tsql-intake/tasks.md)

3タスクすべて `Approval: Draft`／`Status: Planned` です。SQL型・Unicodeの文字数定義、DB詳細設定、CLI検証方法、実行コマンド、timeout／排他設定は未決事項として明記しました。

構造・フック確認とLite適格性判定は通過しました。既存SQLは変更せず、DB接続・実装・試験は行っていません。今回専用の証跡は `.run-temp/bootstrap-orders-note-tsql-intake-nJJ2trWi/` に保存しました。

まずT-001で未決事項を確定し、人間の承認後に以下へ進みます。

```text
/sdd-ship:ship --lite specs/orders-note-tsql-intake/tasks.md
```