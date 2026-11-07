# 3並行 UI / SDD フロー検証 — 2026-11-07

Sites表示の追加確認: [機能試験と本番同期の制約](sites-audit/README.md)。

**更新:** ユーザーのdevice認証後に3セッションを再実行。認証は解消し、プラグイン停止バグ3件を登録。最新結果は [authenticated-retry](authenticated-retry/README.md) を参照。以下は最初の未認証試行の記録。

対象コミット: `e768ee09`。Codex CLI: `0.159.2`。

## 結論

lite / full / full+SQLite を3つの分離作業ディレクトリと並行エージェントで実行。各エージェントが専用 `verify-codex` CLIを起動したが、**3/3が認証401によりモデル処理前に停止**。SDD通常フローの完走は未確認であり、成功とは判定しない。

追跡Issue: https://github.com/aharada54914/sdd-forge/issues/724

| 経路 | 通常CLI | 追加診断 | 独立UIアプリ |
| --- | --- | --- | --- |
| lite | token refresh失敗 | 構造・lite適格性・Draftタスク状態チェック成功 | localStorage: 6項目成功、ブラウザ例外なし |
| full | token refresh失敗 | Workのcanary writeは実行され、handshakeはexit 63 / CAPABILITY_RUNTIME_UNAVAILABLE | Python+JSON: 8項目成功 |
| full+SQLite | token refresh失敗 | native hook証拠を偽装せず、fullゲート通過は未実施 | Python+SQLite: 8項目成功、ブラウザ例外なし |

## 実施した範囲

通常CLIが使えないため、独立した診断用のタスク管理アプリを3つ作成した。これらはプラグインによるSDD全工程の成果物ではない。liteは仕様fixtureのタスクをDraftのまま保持。人間承認やhook証拠を生成・偽装して完走扱いにはしていない。

SQLiteでは追加・完了・削除、DB行の確認、サーバープロセス再起動後の永続化、390px表示、HTMLとSQL入力のリテラル保持、空タイトル400を確認した。

fullのcanary write成功はホストhookが拒否した証拠を作れないことを示す。fail-closedの停止は契約どおりであり、プラグインのバグとして登録しない。認証障害も根本原因未確定の検証環境Issueとして登録した。

## 成果物と再現

- `cli-failures.json`: 3セッションのエラーイベントのみを抽出した証拠。
- `lite/`: 個別README、構造/適格性/タスク状態結果、UI HTML、結果、スクリーンショット。
- `full/`: 個別README、handshake結果、診断アプリ、ブラウザテスト、結果、スクリーンショット。
- `sqlite/`: 個別README、診断アプリ、再起動を含むブラウザテスト、結果、PC/モバイルスクリーンショット。

元の作業場所は `/workspace/.tools/sdd-forge-dev/verification-workspace/{lite-task-board,full-task-board,sqlite-task-board}`。個別READMEのコマンドは当該作業場所を指す。このレポートにも再現用ソースを保存した。DB、キャッシュ、生の認証ログはコミット対象外。試験は診断アプリ限定で、本番運用や全プラグインの安全性を保証しない。

## 残る確認

独立CLIの認証経路を復旧し、モデルリクエスト成功を確認した後、native hookが有効なホストで3経路を再実行する。人間承認を要する箇所では具体的な仕様/タスクを提示して承認手続きを行う。その前に「システム原因で止まらない」と結論付けることはできない。
