# SDD Plugins User Guide (移転しました)

本ガイドは再構成され、複数のドキュメントに分割されました。以下の表を参考に、新しいドキュメントをご参照ください。

| 旧セクション | 新しい場所 |
|---|---|
| 1. 全体ワークフロー | [docs/workflow-guide.md](docs/workflow-guide.md) |
| 2. どのSkillを使うか | [docs/skill-reference.md](docs/skill-reference.md) |
| 3. Compatibility Matrix | [docs/skill-reference.md](docs/skill-reference.md) |
| 4. 決定論的ゲートの使い方 | [docs/skill-reference.md](docs/skill-reference.md) |
| 5. refactorモードと差分テスト | [docs/workflow-guide.md](docs/workflow-guide.md) |
| 6-7. 開発例 | [docs/workflow-guide.md](docs/workflow-guide.md) (正常系フロー) |
| 8. 中断後の再開 | [docs/workflow-guide.md](docs/workflow-guide.md) (異常系) |
| 9. GitHubとGitLab | [docs/workflow-guide.md](docs/workflow-guide.md) |
| 10. Blockedになる条件 | [docs/workflow-guide.md](docs/workflow-guide.md) (異常系) |
| 11. バージョン移行ガイド | [CHANGELOG.md](CHANGELOG.md) |
| 12. トラブルシューティング | [docs/troubleshooting.md](docs/troubleshooting.md) |

**初めての方は [docs/workflow-guide.md](docs/workflow-guide.md) の正常系フローからお読みください。**

## sdd-forge-mcp（MCP サーバー）

### 概要

`sdd-forge-mcp` は、対象リポジトリの SDD 状態（spec / タスク / レビューチケット / 品質ゲート結果 / evidence）を構造化データとして読み取るための **read-only** MCP サーバーです。書き込み API は一切持たず、stdio 経由で MCP クライアント（Claude Code / Codex）から子プロセスとして起動されます。

### 導入・除外・選択導入

`install.sh` / `install.ps1` は既定で以下を行います。

- `INSTALL_ROOT/mcp/sdd-forge-mcp/`（`dist/index.js` + `package.json`）へ配置
- Claude Code へユーザースコープで登録:
  ```bash
  claude mcp add sdd-forge-mcp --scope user -- node <INSTALL_ROOT>/mcp/sdd-forge-mcp/dist/index.js
  ```
- Codex を使う場合、`~/.codex/config.toml` にマーカー区切りブロック（`# >>> sdd-forge-mcp ... >>>` 〜 `# <<< sdd-forge-mcp <<<`）を追記（`config.toml` が存在しない場合は新規作成せず警告のみでスキップ）

導入オプション:

| オプション | 効果 |
|---|---|
| （既定） | MCP サーバーを配置し、`--target` に応じて Claude / Codex に登録 |
| `--skip-mcp` | すべての MCP サーバーの配置・登録をスキップ |
| `--mcp sdd-forge-mcp` | 配置・登録する MCP を明示的に選択（現状の有効値は `sdd-forge-mcp` のみ） |

**Node.js 要件**: Node >= 20 が PATH 上に必要です。`node` が見つからない、またはメジャーバージョンが 20 未満の場合、MCP サーバーの配置・登録のみが警告付きでスキップされます（plugin 本体のインストールは継続します）。

### 対象リポジトリの指定

MCP サーバーがどのリポジトリを SDD ルートとして扱うかは、以下の優先順位で決まります。

1. 起動引数 `--root <path>`
2. 環境変数 `SDD_FORGE_ROOT`
3. プロセスの `cwd`（既定。Claude/Codex への登録エントリは引数なしで cwd 解決に任せる）

リポジトリ外から呼び出す場合のみ、利用者が `--root` または `SDD_FORGE_ROOT` を設定してください。

### tools（13種）

**core（8種）**

| tool | 用途 |
|---|---|
| `list_active_specs` | AGENTS.md の Active Spec Directories 配下の feature を一覧し、Approved かつ Planned/In Progress のタスクを持つかを付記 |
| `get_spec_status` | `specs/<feature>/` の Phase 1/2 成果物の有無と各ファイルのレビューステータスヘッダーを報告 |
| `get_task_state` | `specs/<feature>/tasks.md` の状態機械を解析（check-task-state.sh 相当の pass/fail 判定と失敗タスク一覧） |
| `list_approved_tasks` | `tasks.md` 内の Approved 形状の Approval を持つタスクを一覧 |
| `list_blocked_tasks` | `tasks.md` 内の Status が Blocked のタスクを一覧 |
| `list_review_tickets` | `docs/review-tickets/RT-*.yml` を解析して一覧 |
| `get_quality_gate_summary` | `reports/quality-gate/*.md` のうち VERDICT 行を持つレポートを件数付きで一覧 |
| `get_next_sdd_command` | AGENTS.md の Required Workflow ゲートをたどり、feature（省略時は sdd-ship:run と同様に自動選択）の次の SDD コマンドを判定 |

**evidence（5種）**

| tool | 用途 |
|---|---|
| `evidence_get_bundle` | `specs/<feature>/verification/<taskId>.evidence.json` をそのまま読み取り（署名フィールドも含め検証はしない） |
| `evidence_validate_paths` | evidence bundle 内の各アーティファクトパスが path-guard の allowlist 内にあるか・実在するかを報告 |
| `evidence_find_missing` | Done 遷移に必要な要件（evidence bundle・verification contract・PASS の品質ゲートレポート）の有無を報告（check-task-state.sh の Done evidence チェック相当） |
| `evidence_summarize_contract_checks` | `<taskId>.contract.json` の各チェックの required/passes/waiverReason/requirementIds を要約 |
| `evidence_compare_to_traceability` | `traceability.md` の REQ→Task・AC→TEST→Task 表と `tasks.md` のタスクID、各タスクの verification contract の requirementIds と traceability.md の宣言 REQ-ID を突き合わせ |

### resources（5種）

| URI | 対応する tool |
|---|---|
| `sdd://active-specs` | `list_active_specs` と同一データ |
| `sdd://spec/{feature}` | `get_spec_status` と同一データ |
| `sdd://tasks/{feature}` | `get_task_state` と同一データ |
| `sdd://review-tickets` | `list_review_tickets` と同一データ |
| `sdd://quality-reports` | `get_quality_gate_summary` と同一データ |

### セキュリティ特性

読み取り可能な範囲は allowlist（`specs/`、`reports/`、`docs/review-tickets/`、`docs/workflow-improvements/` の各ディレクトリ配下、および単一ファイル `AGENTS.md`）に限定され、denylist（sudo フラグファイル、evidence 署名鍵、`.env`）は allowlist 配下の symlink 経由であっても常に拒否されます。ファイルサイズ上限は 2 MiB で、これを超えるファイルは読み取り不可（`too-large`）です。書き込み系 API は一切実装されていません（`tasks.md` の承認状態変更やファイル作成はできません）。

### トラブルシュート

**stderr ログの読み方**: MCP プロトコル準拠のため `stdout` は JSON-RPC 専用で、診断ログはすべて `stderr` に出力されます。起動時に解決した root とその出所（`cli`/`env`/`cwd`）、各 tool 呼び出しの要求内容（tool 名・対象パス）、拒否理由、エラーが記録されます。ファイル内容や環境変数の値はログに出力されません。

**エラーコードの意味**（`Result<T>` 応答の `error.code`）:

| コード | 意味 |
|---|---|
| `cannot-parse` | 対象ファイルの内容を期待する形式として解析できなかった |
| `not-found` | 対象パスが存在しない、通常ファイルでない、または読み取れない |
| `path-denied` | allowlist 外、または denylist に一致するパスへのアクセス要求 |
| `not-sdd-root` | 解決された root に `AGENTS.md` または `specs/` が存在せず、SDD プロジェクトルートと認識できない |
| `too-large` | 対象ファイルが 2 MiB の上限を超えている |
| `cannot-determine` | 判定に必要な情報が不足していて結論を出せない |
| `invalid-input` | tool 引数の形式が不正（空文字列、パストラバーサル等） |

**ロールバック手順**:

1. `./uninstall.sh --mcp sdd-forge-mcp`（または `--skip-mcp-uninstall` を付けずに通常のフル uninstall）を実行すると、Claude/Codex への登録解除と `INSTALL_ROOT/mcp/sdd-forge-mcp/` の配置除去が行われます
2. リポジトリ側で MCP サーバー自体の変更を戻したい場合は、該当コミットを revert してください（`dist/` も同一コミットに含まれるため、revert だけで成果物も戻ります）
3. 次回 install 時に `--skip-mcp` を付けることで、MCP サーバーなしでの再導入も可能です
