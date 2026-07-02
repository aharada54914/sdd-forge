# トラブルシューティング

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
- `check-evidence-bundle` によるtask ID、PASS判定、SHA-256検証が失敗している
- 受け入れテストが不足している
- UI変更時の検証に失敗している

**対応：**
1. 生成された品質レポート (`reports/quality-gate/` 内のファイル) を確認
2. レビューチケット (`docs/review-tickets/*.yml`) に `critical` または `major` 指摘がないか確認
3. `check-contract` の実行結果を確認：
   ```bash
   sh plugins/sdd-quality-loop/scripts/check-contract.sh specs/<feature>/verification/<task-id>.contract.json
   ```
4. `check-evidence-bundle` の実行結果を確認：
   ```bash
   sh plugins/sdd-quality-loop/scripts/check-evidence-bundle.sh specs/<feature>/verification/<task-id>.evidence.json
   ```
5. テスト結果ログを確認し、未対応のテストがあれば `fix-by-review-ticket` で修正してから再度 `quality-gate` を実行

### リスク適応ゲート (check-risk / check-traceability / check-contract 階層) が失敗する

**症状：** リスク適応層の新ゲートでタスクが止まる。

- **`check-risk` FAIL** — タスクに `Risk:` (`low/medium/high/critical`) が無い/無効、`Risk Rationale:` が空、または `high`/`critical` で `Required Workflow: tdd` が未宣言。tasks.md にこれらを追記して再実行。
- **`check-contract`「risk medium requires check 'acceptance-tests' …」** — contract の `required:true` セットが階層最小セットを満たしていない。[`risk-gate-matrix.md`](../plugins/sdd-quality-loop/references/risk-gate-matrix.md) に従い不足チェックを追加するか、コンパイルツールチェーンの無い shell/Markdown/JSON リポジトリなら contract に `"stack": "shell"`（または `docs`/`spec`）を設定して `lint`/`typecheck`/`build` を理由付きで waive する。テスト/トレーサビリティ系チェックは stack では免除されない。
- **`check-contract`「… needs non-empty red_evidence / green_evidence」** — `required_workflow: tdd` のテストチェックに Red→Green 証跡が無い。失敗→成功のログを保存し `red_evidence`/`green_evidence` に実在パスを指定する。
- **`check-traceability` FAIL** — `traceability.json` の link に `req`/`acs`/`tests` が欠落、または `require-evidence` モードで証跡ファイルが未列挙/不在。チェーンを補完し証跡パスを実在ファイルに向ける。
- **`check-evidence-bundle`（critical）が署名/dirty で FAIL** — critical バンドルは外部署名鍵 (`SDD_EVIDENCE_KEY` / `~/.sdd/evidence-key`) とクリーンツリーが必須。鍵を設定し、未コミット変更を解消してから生成する。

### check-placeholders が正当なコードを誤検出する（brownfield）

**症状：** 既存プロジェクトでタスクが変更したファイルに含まれる `raise NotImplementedError`（正当な抽象メソッド）や、タスクと無関係な既存の `# TODO` を `check-placeholders` が FAIL 判定する。

**原因：**
- `check-placeholders` は変更された本番ファイルのみを走査し、`TODO`/`FIXME`/スタブや `raise NotImplementedError` / `panic("TODO")` 等を保守的に検出します。抽象メソッドや既存マーカーも区別なく検出されます（無関係な未変更ファイルは走査対象外）。

**対応：**
- これはゲートの欠陥ではなく仕様です。正当なケースを通すには、検証契約の `placeholder-scan` チェックを `"required": false` ＋ 非空の `waiver_reason` に設定し（Default-FAIL ルール準拠）、**かつ** quality-gate レポートに人間の accept を記録してください。`check-contract` はレポートを読まず、`passes: false` の必須チェックを失敗扱いにするため、契約側の `required: false`＋`waiver_reason` が実際にゲートを解除します。
- `check-placeholders` 自体は渡されたパス（ファイル/ディレクトリ）を再帰的に走査し、Git 差分での絞り込みはしません。**変更ファイルのみを渡すのは呼び出し側（quality-gate）の責任**です（ディレクトリ全体を渡すと既存マーカーも検出されます）。
- スキャン自体を緩めてプロンプトを回避しないでください。
- 無関係な既存マーカーは、その変更をタスク範囲外として切り出す（別タスク化）ことも検討してください。

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

### Claude Code に `/sdd-bootstrap:bootstrap` などのコマンドが表示されない

**症状：** Claude Code で plugin をインストールした後も、`/sdd-bootstrap:bootstrap`
などの SDD コマンドが候補に表示されない。

**対応：**
1. インストール対象の manifest を先に検証します。plugin ルートを指定してください。
   ```bash
   claude plugin validate plugins/sdd-bootstrap
   ```
2. 登録済み plugin を確認します。
   ```bash
   claude plugin list
   ```
3. 古いまたは失敗した登録があれば、最新版を再インストールします。
   ```bash
   claude plugin install sdd-bootstrap@sdd-plugins --scope user
   ```
4. Claude Code で `/reload-plugins` を実行してから、`/sdd-bootstrap:bootstrap` を
   再度確認します。

`install.sh` と `install.ps1` は selected plugin の manifest を検証してから
marketplace を登録します。`plugin validate` が失敗した場合は、原因を修正して
からインストールを再実行してください。

### Codex で SDD スキルを利用できない

**症状：** Codex で SDD のスキルが見つからない、または Claude Code 用の
`/sdd-bootstrap:bootstrap` をそのまま入力しても起動しない。

**対応：**
1. Codex 用の marketplace と plugin を登録します。
   ```bash
   ./install.sh --target Codex --plugins sdd-bootstrap,sdd-ship
   ```
2. Codex が認識している plugin を確認します。
   ```bash
   codex plugin list
   ```
3. Codex では slash command ではなく、スキル名を指定して依頼します。
   ```txt
   Use the sdd-bootstrap:bootstrap skill.
   Mode: feature
   Source: <issue URL または要件>
   ```

Claude の manifest 修正は Claude Code の validator 互換性に限定しています。
Codex の `.codex-plugin` manifest、marketplace、agent TOML の配布経路は変更せず、
インストーラー試験で `codex plugin add` を継続して検証します。

### 三段階レビューが次の段階へ進まない

**症状：** `impl-review-loop` または `task-review-loop` が predecessor を検証できず停止する。

**対応：** フルトラックでは三つの**独立した**レビューを順に通します。

1. `/sdd-review-loop:spec-review-loop --feature <feature>` を実行し、
   `requirements.md` の `Spec-Review-Status: Passed` と valid PASS contract を確認
2. `/sdd-review-loop:impl-review-loop --feature <feature>` を実行し、
   `design.md` の `Impl-Review-Status: Passed` と valid PASS contract を確認
3. Phase 2 で tasks を生成してから
   `/sdd-review-loop:task-review-loop --feature <feature>` を実行

各 stage は専用の reviewer A/B を fresh context で起動します。前段が
`NEEDS_WORK` または `BLOCKED` の場合、該当する canonical input を人間が修正し、
`--edit-summary` または `--reset` で同じ stage を再実行してください。status header
だけを手作業で書き換えて次段を通すことはできません。

## フック・ガード関連

### フックが発火しない

**症状：** AGENT_STOP ファイルを作成してもエージェントが停止しない、または承認ガードが動作しない。

**原因：**
- Codex では `plugin_hooks` フラグが無効に設定されている
- Copilot のサブエージェント内では hook が発火しない場合がある（既知の制限）
- Claude Code の環境で Node.js が利用不可

**代替手段：**
1. hook が無効な場合、手動で `check-task-state`、`check-contract`、`check-evidence-bundle` を実行して同じ不変条件を確認してください：
   ```bash
   sh plugins/sdd-quality-loop/scripts/check-task-state.sh specs/<feature>/tasks.md
   sh plugins/sdd-quality-loop/scripts/check-contract.sh specs/<feature>/verification/<task-id>.contract.json
   sh plugins/sdd-quality-loop/scripts/check-evidence-bundle.sh specs/<feature>/verification/<task-id>.evidence.json
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

- [README.md](../README.md) — プロジェクト概要・フロー図
- [docs/workflow-guide.md](workflow-guide.md) — 開発業務フローと正常系・異常系・レビュー運用
- [docs/skill-reference.md](skill-reference.md) — スキル・エージェント・フック・スクリプト詳細
