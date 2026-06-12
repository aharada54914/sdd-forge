# トラブルシューティング

## インストール関連

### Codex起動時の「Ignoring malformed agent role definition」警告

Codex起動時に次のような警告が表示される場合があります：

```
⚠ Ignoring malformed agent role definition: ~/.codex/agents/auditor.toml must define `developer_instructions`
```

本リポジトリが配布するのは `sdd-investigator.toml` と `sdd-evaluator.toml` のみで、どちらも有効です。警告に表示されたファイル（例：`auditor.toml`、`constraint-guardian.toml` など）は、他のツールやAIセッションが作成したもので、`~/.codex/agents/` ディレクトリに不正に配置されています。

**対応方法：**
1. 警告に表示されたファイルを削除する：`rm ~/.codex/agents/auditor.toml` など
2. または、そのファイルに `developer_instructions` キーを追加する
3. インストーラーはインストール時にこの問題を検出して警告し、SDDフックガードはエージェントによる不正なロールファイル作成をブロックします

### CLI登録失敗時の挙動

インストーラーが Codex CLI、Claude Code CLI、Copilot CLI へのプラグイン登録に失敗した場合：

- **初回配置時に失敗**: インストーラーはファイル配置を削除してロールバックします
- **更新時に失敗**: インストーラーは以前の配置へ復元します

### PowerShell 5.1 の TLS 設定

PowerShell 5.1 でスクリプト実行時にダウンロード失敗が発生する場合があります。v0.5.0 以降のインストーラーは自動で `[Net.ServicePointManager]::SecurityProtocol` を TLS 1.2 に設定するため、通常は対応不要です。

ただし、環境によっては手動設定が必要な場合があります：

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
```

### スクリプトブロック形式の必要性

`irm | iex` 形式ではパラメーター（`-Target`, `-Plugins`, `-InstallRoot` など）を指定できません。パラメーター指定が必要な場合は、スクリプトブロック形式を使用してください：

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/aharada54914/sdd-forge/main/install.ps1))) -Target Codex
```

## ワークフロー実行時

### 実装が開始されない

**症状：** `implement-task` を実行しても `In Progress` にならない、またはスキルが停止する。

**原因：**
- タスクの `Approval` が `Approved` でない（`Draft` のままになっている）
- タスクの `Status` が `Planned` でない
- `Blockers` フィールドにエントリがある場合、タスクが `Blocked` 状態

**対応：**
1. `tasks.md` を確認し、対象タスクの `Approval` が `Approved` になっているか確認
2. 人間だけがタスクを `Approved` に変更できます。エージェントは自動承認できません
3. タスク状態が `Blocked` の場合、`Blockers` セクションの内容を確認し、解決されているかどうか確認してください

### quality-gate が開始されない

**症状：** `quality-gate` スキルが停止する、またはタスクが Done にならない。

**原因：**
- タスクが `Implementation Complete` 状態でない
- タスクの `Approval` が `Approved` でない

**対応：**
1. `tasks.md` でタスクの `Status` が `Implementation Complete` になっているか確認
2. `implement-task` が `Implementation Complete` に設定してから `quality-gate` を実行してください

### Done にならない

**症状：** `quality-gate` が完了しても、タスクの `Status` が `Done` にならない。

**原因：**
- 品質レポート (`reports/quality-gate/*.md`) の内容に問題がある
- `docs/review-tickets/*.yml` にレビューチケットが作成されており、未解決の Critical/Major 指摘がある
- `check-contract` による検証が失敗している
- 受け入れテストが不足している
- UI変更時の検証に失敗している

**対応：**
1. 生成された品質レポート (`reports/quality-gate/` 内のファイル) を確認
2. レビューチケット (`docs/review-tickets/*.yml`) に `critical` または `major` 指摘がないか確認
3. `check-contract` の実行結果を確認：
   ```bash
   sh plugins/sdd-quality-loop/scripts/check-contract.sh specs/<feature>/verification/<task-id>.contract.json
   ```
4. テスト結果ログを確認し、未対応のテストがあれば `fix-by-review-ticket` で修正してから再度 `quality-gate` を実行

### UI検証ができない

**症状：** quality-gate が UI 変更の検証で停止する。

**原因：**
- ブラウザまたは Playwright が利用不可
- 検証環境が未設定

**対応：**
- UI変更が検証必須の場合、ブラウザまたは Playwright が使える環境を整備してから `quality-gate` を再実行してください。必須検証が完了しない限りタスクは `Done` になりません

### implement-task / quality-gate が AGENTS.md 不在で停止する

**症状：** スキルが起動直後に停止し、「`AGENTS.md` が見つからない」旨のメッセージが表示される。

**原因：**
- リポジトリルートに `AGENTS.md` ファイルが存在しない
- SDD 必須構造が整備されていない

**対応：**
1. `sdd-adopt` スキルを実行：
   ```txt
   Use the sdd-adopt skill.
   ```
2. `sdd-adopt` がリポジトリ構造をスキャフォールドし、`AGENTS.md` などの必須ファイル・ディレクトリを作成します
3. その後、`implement-task` / `quality-gate` を再度実行してください

### ADR が `specs/<feature>/adr/` にある

**症状：** ADR（Architecture Decision Record）が `specs/<feature>/adr/` に存在している。

**原因：**
- v0.6.0 より前のバージョンで作成された ADR がまだ旧配置にある

**対応：**
1. `sdd-adopt` を実行すると、`specs/<feature>/adr/` 内の ADR を自動で `docs/adr/NNNN-<slug>.md` に移行します
2. ADR の正規配置は `docs/adr/` です

## フック・ガード関連

### フックが発火しない

**症状：** AGENT_STOP ファイルを作成してもエージェントが停止しない、または承認ガードが動作しない。

**原因：**
- Codex では `plugin_hooks` フラグが無効に設定されている
- Copilot のサブエージェント内では hook が発火しない場合がある（既知の制限）
- Claude Code の環境で Node.js が利用不可

**代替手段：**
1. hook が無効な場合、手動で `check-task-state` と `check-contract` を実行して同じ不変条件を確認してください：
   ```bash
   sh plugins/sdd-quality-loop/scripts/check-task-state.sh specs/<feature>/tasks.md
   sh plugins/sdd-quality-loop/scripts/check-contract.sh specs/<feature>/verification/<task-id>.contract.json
   ```
2. AGENT_STOP の代わりに、セッションを手動で終了してください

### AGENT_STOP が効かない

**症状：** AGENT_STOP ファイルを作成しても、エージェントが停止しない。

**原因：**
- フックが発火していない環境（上記参照）では、AGENT_STOP ファイルはシグナルとして機能しません

**対応：**
- セッションを手動で終了してください

### エージェントが Approval: Approved を書き込もうとしてブロックされる

**症状：** エージェントが `tasks.md` へ `Approval: Approved` を追加しようとして、hook guard によってブロックされる。

**原因：**
- これは正常な動作です。エージェントは自己承認できません
- または、sudoモード (`SDD_SUDO`) が有効に設定されているはずなのに自動通過していない

**説明：**
- 仕様上、タスク承認は人間だけが行えます（sudoモード未使用時）
- hook guard が `Approval: Approved` の自動書き込みをブロックします
- sudoモード使用時でも、`SDD_SUDO` ファイルが存在し有効期限内であることを確認してください

**対応：**
1. 人間が手動で `tasks.md` を編集し、`Approval` フィールドを `Draft` から `Approved` に変更 (通常)
2. または `/sdd-sudo 8h` で sudoモード有効化後、自動通過で記録（sudoモード利用時）

## Sudoモード関連

### sudoが効かない

**症状：** `/sdd-sudo 8h` で有効化したはずなのに、Approval ガードでブロックされ、approval gates が自動通過しない。

**原因：**
- `SDD_SUDO` ファイルが存在しない
- ファイルが存在しても、`expires-epoch` 行が期限切れ（現在 Unix time > expires-epoch）
- `CLAUDE_PROJECT_DIR` 環境変数とカレントディレクトリが一致していない可能性

**対応：**
1. `SDD_SUDO` ファイルがプロジェクトルートに存在するか確認：
   ```bash
   ls -la SDD_SUDO
   ```
2. ファイルの内容を確認し、`expires-epoch` が現在時刻より大きいか確認：
   ```bash
   cat SDD_SUDO
   date +%s      # 現在の Unix time
   ```
3. 期限が切れていれば `/sdd-sudo 8h` で再有効化
4. `CLAUDE_PROJECT_DIR` がセットされている場合、そのパスがカレントディレクトリと一致しているか確認

### 無効化し忘れが心配

**症状：** sudoモードを有効化した後、その後の作業で無効化し忘れないか不安。

**安心設定：**

1. **自動失効**: sudoモードは `expires-epoch` の時刻で自動失効します
   - デフォルト 8 時間で自動失効
   - その後は Approval ガードが再度有効になります
   - ファイル削除は自動で行われません（手動削除可能）

2. **即座に無効化**:
   ```txt
   /sdd-sudo off         # コマンドで即座に無効化
   ```

3. **手動削除**:
   ```bash
   rm SDD_SUDO           # Bash
   ```
   ```powershell
   Remove-Item SDD_SUDO  # PowerShell
   ```

**推奨**: デフォルトの 8 時間で十分。期限切れ後は自動的に無効化されます。

## 関連リンク

- [README.md](../README.md) — インストールと概要
- [docs/workflow-guide.md](workflow-guide.md) — 開発業務フローと正常系・異常系・レビュー運用
- [docs/skill-reference.md](skill-reference.md) — スキル・エージェント・フック・スクリプト詳細
