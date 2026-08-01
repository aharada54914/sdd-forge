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

## エージェントモデルルーティング — Effort Policy

`select-agent-model` の `--effort-policy` は、T-007 (Issue #155,
epic-159-pillar-c Phase 2) 以降、既定値が `matrix` になった
(`risk_effort_matrix` に基づくリスク連動 effort 選択 + escalation bump +
`supported_efforts` へのクランプ)。Phase 1 (T-001..T-006) の既定であった
`welded`(effort を tier に溶接した従来挙動)は、`--effort-policy welded`
を明示すれば引き続き無期限にフルサポートされる(非推奨化なし、OQ-004)。
詳細は [docs/agent-capability-matrix.md](docs/agent-capability-matrix.md)
の「Effort Policy: `welded` vs. `matrix`」節と
[docs/adr/0012-effort-tier-decoupling.md](docs/adr/0012-effort-tier-decoupling.md)
を参照。

## MCP サーバー

### sdd-forge-mcp

#### 概要

`sdd-forge-mcp` は、対象リポジトリの SDD 状態（spec / タスク / レビューチケット / 品質ゲート結果 / evidence）を構造化データとして読み取るための **read-only** MCP サーバーです。書き込み API は一切持たず、stdio 経由で MCP クライアント（Claude Code / Codex）から子プロセスとして起動されます。

#### 導入・除外・選択導入

`install.sh` / `install.ps1` は既定で以下を行います。

- `INSTALL_ROOT/mcp/sdd-forge-mcp/`（`dist/index.js` + `package.json`）へ配置
- Claude Code へユーザースコープで登録:
  ```bash
  claude mcp add sdd-forge-mcp --scope user -- node <INSTALL_ROOT>/mcp/sdd-forge-mcp/dist/index.js
  ```
- Codex を使う場合、`~/.codex/config.toml` にマーカー区切りブロック（`# >>> sdd-forge-mcp ... >>>` 〜 `# <<< sdd-forge-mcp <<<`）を追記（`config.toml` が存在しない場合は新規作成せず警告のみでスキップ）
- Cursor を使う場合、`~/.cursor/mcp.json` の `mcpServers` キーに自動登録
- VS Code を使う場合、ユーザープロファイルの `mcp.json` の `servers` キーに自動登録

導入オプション:

| オプション | 効果 |
|---|---|
| （既定） | MCP サーバーを配置し、`--target` に応じて Claude / Codex / Cursor / VS Code に登録 |
| `--skip-mcp` | すべての MCP サーバーの配置・登録をスキップ |
| `--mcp sdd-forge-mcp,local-env-mcp` | 配置・登録する MCP を明示的に選択（有効値: `sdd-forge-mcp`, `local-env-mcp`） |

**Node.js 要件**: Node >= 20 が PATH 上に必要です。`node` が見つからない、またはメジャーバージョンが 20 未満の場合、MCP サーバーの配置・登録のみが警告付きでスキップされます（plugin 本体のインストールは継続します）。

### 対象リポジトリの指定

MCP サーバーがどのリポジトリを SDD ルートとして扱うかは、以下の優先順位で決まります。

1. 起動引数 `--root <path>`
2. 環境変数 `SDD_FORGE_ROOT`
3. プロセスの `cwd`（既定。Claude/Codex への登録エントリは引数なしで cwd 解決に任せる）

リポジトリ外から呼び出す場合のみ、利用者が `--root` または `SDD_FORGE_ROOT` を設定してください。

#### tools（13種）

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

**evidence（6種）**

| tool | 用途 |
|---|---|
| `evidence_get_bundle` | `specs/<feature>/verification/<taskId>.evidence.json` をそのまま読み取り（署名フィールドも含め検証はしない） |
| `evidence_validate_paths` | evidence bundle 内の各アーティファクトパスが path-guard の allowlist 内にあるか・実在するかを報告 |
| `evidence_find_missing` | Done 遷移に必要な要件（evidence bundle・verification contract・PASS の品質ゲートレポート）の有無を報告（check-task-state.sh の Done evidence チェック相当） |
| `evidence_summarize_contract_checks` | `<taskId>.contract.json` の各チェックの required/passes/waiverReason/requirementIds を要約 |
| `evidence_compare_to_traceability` | `traceability.md` の REQ→Task・AC→TEST→Task 表と `tasks.md` のタスクID、各タスクの verification contract の requirementIds と traceability.md の宣言 REQ-ID を突き合わせ |
| `evidence_deep_verify` | evidence bundle を再検証：各成果物の sha256 をディスク上から再計算して記録値と突合、正準 artifacts ダイジェスト・spec_revision・git_commit 40-hex 形状・contract/report クロスバインドの不変条件を検証し、決定論的な pass/fail verdict と failures リストを返す。署名鍵は読まず、署名検証も行わない（verified:false、host 責務）、git 祖先検証も行わない（host-deferred）。 |

#### resources（5種）

| URI | 対応する tool |
|---|---|
| `sdd://active-specs` | `list_active_specs` と同一データ |
| `sdd://spec/{feature}` | `get_spec_status` と同一データ |
| `sdd://tasks/{feature}` | `get_task_state` と同一データ |
| `sdd://review-tickets` | `list_review_tickets` と同一データ |
| `sdd://quality-reports` | `get_quality_gate_summary` と同一データ |

#### セキュリティ特性

読み取り可能な範囲は allowlist（`specs/`、`reports/`、`docs/review-tickets/`、`docs/workflow-improvements/` の各ディレクトリ配下、および単一ファイル `AGENTS.md`）に限定され、denylist（sudo フラグファイル、evidence 署名鍵、`.env`）は allowlist 配下の symlink 経由であっても常に拒否されます。ファイルサイズ上限は 2 MiB で、これを超えるファイルは読み取り不可（`too-large`）です。書き込み系 API は一切実装されていません（`tasks.md` の承認状態変更やファイル作成はできません）。

#### トラブルシュート

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

### local-env-mcp

#### 概要

`local-env-mcp` は、ローカル開発環境の情報を読み取るための **read-only** MCP サーバーです。実行機能を一切持たず、以下の 3 つのツールで環境情報を構造化 JSON で提供します。

#### ツール（3種）

| ツール | 用途 |
|---|---|
| `get_os_info` | OS 情報（プラットフォーム・アーキテクチャ・OS タイプ・バージョン・CPU 論理コア数・総メモリ・Node.js ランタイムバージョン） |
| `get_toolchain_versions` | ツールチェーンバージョン一括取得（コンパイル時に固定された 14 種の CLI：node/npm/pnpm/yarn/bun/deno/git/gh/python3/go/rustc/cargo/java/docker） |
| `list_available_clis` | 上記 14 種の CLI の可用性確認 |

#### セキュリティ特性

- **実行機能なし**: 入力スキーマにコマンド・引数・パスを受け取るフィールドがなく、プローブ対象は外部入力から到達不可のコンパイル時固定リストのみです
- **秘密情報の非漏えい**: 応答とログに環境変数の値・ユーザー名・ホスト名・ホームディレクトリパスは含まれません
- **自動登録**: installer が Cursor と VS Code に自動登録します（詳細は下記）

#### 自動登録（Cursor / VS Code）

installer は以下のクライアントに自動的に `local-env-mcp` を登録します。

##### Cursor

自動登録対象: `~/.cursor/mcp.json`

登録形式:
```json
{
  "mcpServers": {
    "local-env-mcp": {
      "command": "node",
      "args": ["<install-root>/mcp/local-env-mcp/dist/index.js"]
    }
  }
}
```

##### VS Code（ユーザープロファイル）

自動登録対象（OS 別パス）:
- **macOS**: `~/Library/Application Support/Code/User/mcp.json`
- **Linux**: `~/.config/Code/User/mcp.json`
- **Windows**: `%APPDATA%\Code\User\mcp.json`

登録形式:
```json
{
  "servers": {
    "local-env-mcp": {
      "type": "stdio",
      "command": "node",
      "args": ["<install-root>/mcp/local-env-mcp/dist/index.js"]
    }
  }
}
```

#### 手動登録手順

自動登録がスキップされた場合や、後から登録したい場合は、上記の JSON スニペットを対応するクライアントの設定ファイルに手動で追加してください。

**重要**: 既存の他エントリは保持・上書きしないでください。登録解除時も同様に該当のエントリのみを削除してください。

#### フェイルセーフ挙動

- クライアント設定ディレクトリが存在しない場合（クライアント未導入）: その クライアントのみ登録をスキップし、他のクライアントの登録は継続します
- 設定ファイルが壊れた JSON の場合: 上書きしない（データ破壊を防止）。エラー通知を表示し、該当クライアントの登録のみ中断します

**ロールバック手順**:

1. `./uninstall.sh --mcp sdd-forge-mcp,local-env-mcp`（または `--skip-mcp-uninstall` を付けずに通常のフル uninstall）を実行すると、Claude / Codex / Cursor / VS Code への登録解除と配置済みファイルの削除が行われます
   - 登録解除時は、installer が管理するエントリ（`sdd-forge-mcp`・`local-env-mcp`）のみを削除し、他のユーザー定義エントリは無傷です
2. リポジトリ側で MCP サーバー自体の変更を戻したい場合は、該当コミットを revert してください（`dist/` も同一コミットに含まれるため、revert だけで成果物も戻ります）
3. 次回 install 時に `--skip-mcp` を付けることで、MCP サーバーなしでの再導入も可能です

### ci-mcp

#### 概要

`ci-mcp` は、GitHub Actions の CI 状態（ワークフロー実行・ジョブ・ジョブログ・成果物メタデータ）を読み取るための **read-only** MCP サーバーです。write API・write ツールは一切持たず、GitHub REST API へは `https://api.github.com` に固定されたホストへの **GET リクエストのみ**を発行します。`child_process` は一切importせず、`git`/`gh` などのサブプロセス実行は行いません。

#### ツール（5種）

| ツール | 入力 | 出力 |
|---|---|---|
| `list_workflow_runs` | `owner`?, `repo`?（両方揃えて指定、省略時は `CI_MCP_REPO`）, `branch`?, `status`?（`queued`\|`in_progress`\|`completed`\|`waiting`\|`requested`\|`pending`）, `event`?, `perPage`?（1-100） | `{ kind: "workflow-runs", runs: WorkflowRun[] }` |
| `get_workflow_run` | `owner`?, `repo`?, `runId`（必須・正の整数） | `{ kind: "workflow-run", run: WorkflowRun }`（存在しない run は `not-found`） |
| `list_run_jobs` | `owner`?, `repo`?, `runId`（必須） | `{ kind: "run-jobs", jobs: Job[] }`（`failedStep` は最初に失敗したステップ番号、なければ `null`） |
| `list_run_artifacts` | `owner`?, `repo`?, `runId`（必須） | `{ kind: "run-artifacts", artifacts: Artifact[] }`（メタデータのみ、バイナリ本体は返さない。`expired: true` は正常データ） |
| `get_job_log` | `owner`?, `repo`?, `jobId`（必須） | `{ kind: "job-log", jobId, log, truncated, returnedBytes }`（256 KiB＝262144 バイトを超えるログは末尾優先で truncate。UTF-8 文字境界を跨がない安全な切り出し） |

各ツールの入力スキーマは `.strict()` で、action/method/body を受け取るフィールドは一切存在しません（write 誘発フィールドの構造的排除）。契約の正準ソースは `mcp/ci-mcp/contracts/ci-mcp-tools.v1.schema.json` です。

#### セキュリティ境界

- **write 機能なし**: GET 専用・ホストは `https://api.github.com` に固定でどのツール引数からも書き換え不可。write API・write ツールは実装されていません
- **exec なし**: `child_process` を import しているファイルはリポジトリ内に存在せず、`git remote` 等によるリポジトリ推測も行いません（owner/repo は明示引数または `CI_MCP_REPO` からのみ解決）
- **トークンの非漏えい**: トークン値・`Authorization` ヘッダ値は応答・診断ログ・エラー詳細のいずれにも出力されません。トークンは環境変数からのみ読み取り、プロセスを終了させることもありません（未設定時は `auth-missing` を返すのみ）
- **ジョブログ truncation**: `get_job_log` は 256 KiB（262144 バイト）を超えるログを末尾優先で切り詰め、`truncated`/`returnedBytes` で状態を明示します（診断上重要なのは末尾のため）
- **上流エラーの正規化**: GitHub API のレスポンス本文は成功時のみ読み取られ、エラー時は本文を転載せず決定論的に `upstream-error`/`rate-limited`/`not-found`/`auth-missing` へ写像します

#### トークン設定

`ci-mcp` の実行には read-only スコープの GitHub PAT（Personal Access Token）が必要です。以下の優先順位で最初に非空の環境変数値を採用します（OQ-004）:

1. `CI_MCP_GITHUB_TOKEN`（推奨・ci-mcp 専用）
2. `GH_READONLY_TOKEN`（read-only 用途で共有する場合）
3. `GITHUB_TOKEN`（汎用フォールバック）

installer はトークン値を一切生成・保存しません。MCP クライアント（Claude Code / Codex / Cursor / VS Code）がプロセスを起動する環境に、上記いずれかの変数を利用者自身が設定してください。トークンは **Actions の読み取りに必要な最小スコープ**（`repo` の read アクセス、または fine-grained PAT の `Actions: Read-only` + `Contents: Read-only`）のみを付与した read-only PAT を強く推奨します。write スコープを持つトークンを渡しても ci-mcp は write API を呼び出しませんが、最小権限の原則としてトークン自体のスコープを絞ってください。

#### 対象リポジトリの指定（`CI_MCP_REPO`）

各ツールは以下の優先順位で対象リポジトリ（owner/repo）を解決します（OQ-001）:

1. ツール引数 `owner` と `repo` を**両方**明示指定した場合はそれを使用（片方のみの指定は `invalid-input`。`CI_MCP_REPO` へのフォールバックはしません）
2. 明示引数が両方とも未指定の場合、環境変数 `CI_MCP_REPO` を `owner/repo` 形式で解釈
3. どちらも解決できない場合は `invalid-input`

`CI_MCP_REPO` の例: `CI_MCP_REPO=your-org/your-repo`。`owner`/`repo` それぞれ GitHub の命名規則に沿った文字種のみ許容され、`.`/`..` や不正な文字列は `invalid-input` になります。git-remote からの自動推測は行いません（exec 回避方針）。

#### 自動登録（Claude Code / Codex / Cursor / VS Code）

installer は以下のクライアントに自動的に `ci-mcp` を登録します。登録方式は `sdd-forge-mcp`/`local-env-mcp` と同一の仕組みを使い、管理エントリ名は `ci-mcp` です。

##### Claude Code

```bash
claude mcp add ci-mcp --scope user -- node <install-root>/mcp/ci-mcp/dist/index.js
```

##### Codex

`~/.codex/config.toml` にマーカー区切りブロック（`# >>> ci-mcp (managed by sdd-forge installer; do not edit by hand) >>>` 〜 `# <<< ci-mcp <<<`）を追記します（`config.toml` が存在しない場合は新規作成せず警告のみでスキップ）。

##### Cursor

自動登録対象: `~/.cursor/mcp.json`

登録形式:
```json
{
  "mcpServers": {
    "ci-mcp": {
      "command": "node",
      "args": ["<install-root>/mcp/ci-mcp/dist/index.js"]
    }
  }
}
```

##### VS Code（ユーザープロファイル）

自動登録対象（OS 別パス）:
- **macOS**: `~/Library/Application Support/Code/User/mcp.json`
- **Linux**: `~/.config/Code/User/mcp.json`
- **Windows**: `%APPDATA%\Code\User\mcp.json`

登録形式:
```json
{
  "servers": {
    "ci-mcp": {
      "type": "stdio",
      "command": "node",
      "args": ["<install-root>/mcp/ci-mcp/dist/index.js"]
    }
  }
}
```

いずれのクライアントでも、`ci-mcp` プロセスが起動する環境に [トークン設定](#トークン設定) の環境変数を利用者自身が設定する必要があります（installer はトークンを配布しません）。

#### 手動登録手順

自動登録がスキップされた場合や、後から登録したい場合は、上記の JSON スニペット / コマンドを対応するクライアントの設定ファイルに手動で追加してください。

**重要**: 既存の他エントリは保持・上書きしないでください。登録解除時も同様に該当のエントリのみを削除してください。

#### フェイルセーフ挙動

- クライアント設定ディレクトリが存在しない場合（クライアント未導入）: そのクライアントのみ登録をスキップし、他のクライアントの登録は継続します
- 設定ファイルが壊れた JSON の場合: 上書きしない（データ破壊を防止）。エラー通知を表示し、該当クライアントの登録のみ中断します
- Node.js が PATH 上にない、またはメジャーバージョンが 20 未満の場合: MCP サーバーの配置・登録のみが警告付きでスキップされます（plugin 本体のインストールは継続します）

**ロールバック手順**:

1. `./uninstall.sh --mcp ci-mcp`（または通常のフル uninstall）を実行すると、Claude / Codex / Cursor / VS Code への登録解除と配置済みファイルの削除が行われます
   - 登録解除時は、installer が管理する `ci-mcp` エントリのみを削除し、他のユーザー定義エントリは無傷です
2. リポジトリ側で MCP サーバー自体の変更を戻したい場合は、該当コミットを revert してください（`dist/` も同一コミットに含まれるため、revert だけで成果物も戻ります）
3. 次回 install 時に `--skip-mcp` または `--mcp sdd-forge-mcp,local-env-mcp`（`ci-mcp` を除外）を付けることで、ci-mcp なしでの再導入も可能です

#### エラーコードの意味（`Result<T>` 応答の `error.code`、10 種）

| コード | 意味 |
|---|---|
| `cannot-parse` | 上流レスポンス本文を期待する形式として解析できなかった |
| `cannot-determine` | 判定に必要な情報が不足していて結論を出せない |
| `not-found` | 対象のワークフロー実行・ジョブ・成果物が存在しない（GitHub 404） |
| `path-denied` | （sdd-forge-mcp/local-env-mcp とのエンベロープ互換のため予約。ci-mcp のツールがこのコードを返すことはない） |
| `not-sdd-root` | （同上、ci-mcp では未使用） |
| `too-large` | （同上、ci-mcp では未使用。ジョブログの上限超過は `truncated: true` で表現し、エラーにはしない） |
| `invalid-input` | tool 引数の形式が不正（owner/repo 片方のみ指定・不正な文字種・runId/jobId が正の整数でない等） |
| `upstream-error` | GitHub API が 403（rate limit 以外）/5xx/予期しないステータスを返した、またはネットワーク障害が発生した |
| `rate-limited` | GitHub API のレート制限に到達した（403 + レート制限ヘッダ、または 429） |
| `auth-missing` | `CI_MCP_GITHUB_TOKEN`/`GH_READONLY_TOKEN`/`GITHUB_TOKEN` のいずれも設定されていない、または GitHub API が 401 を返した |
