# SDD Forge リファレンス — MCP サーバーとエージェントモデルルーティング

本書は SDD Forge の次の 2 つの領域を扱う詳細リファレンス（正準）です。

- **MCP サーバー 3 種**（`sdd-forge-mcp` / `local-env-mcp` / `ci-mcp`）の導入・登録・ツール仕様・セキュリティ境界・エラーコード・ロールバック手順
- **エージェントモデルルーティング**（`select-agent-model` の `--effort-policy`）の既定挙動

3サーバーの概要は [README.md](README.md) の「MCP サーバー」節で、アーキテクチャ全体における位置づけは [docs/architecture/overview.md](docs/architecture/overview.md) の §6 で説明しています。どちらも導入オプション・トークン設定・登録手順の詳細は本書へリンクしています。本書は全ツールの入出力・エラーコード・フェイルセーフ挙動・ロールバック手順までを収めています。

SDD のワークフロー手順・Skill の選び方・トラブルシューティングは別ドキュメントに分割済みで、対応表は末尾の [旧ユーザーガイドからの移行先](#旧ユーザーガイドからの移行先) にまとめてあります。**SDD の使い方を初めて学ぶ方は [docs/workflow-guide.md](docs/workflow-guide.md) の正常系フローからお読みください。**

外部根拠の調査は既存の bootstrap `investigate` / `feature` から内部スキルを利用します。
[research-sources の説明](docs/skill-reference.md#research-sources内部スキル)と
[取得・引用照合・保存期限・レビュー連携の手順](plugins/sdd-bootstrap/references/research-workflow.md)を参照してください。MCP に書き込み権限を追加する機能ではありません。

Azure Bicep / AWS CDK の操作は、明示導入する `sdd-azure-cloud` / `sdd-aws-cloud` が扱います。
このリポジトリのインストーラーで共有 runtime を配置し、各 `orchestrate` スキルから使います。
ローカル準備、保護された CI の書込み、認証付きの観測は別の権限境界です。
[導入と対応範囲](docs/cloud/README.md)、[入力契約・実行・復旧の詳細](docs/cloud-orchestration.md)を参照してください。
実クラウドの受入 TEST-003/005/009 は BLOCKED のままで、プラグインの導入やローカル検証だけで本番対応とはしません。

## エージェントモデルルーティング — Effort Policy

`select-agent-model` の `--effort-policy` は T-007 (Issue #155,
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

MCP サーバーが提供する情報は SDD ワークフローに対して常に **助言的（advisory）** です。エージェントは各 tool の応答を判断材料として利用しますが、それによって `tasks.md` の Approval / Status 判定や品質ゲートの合否確認といったファイルベースの手続きを自動的に進めたり、その判定を上書きしたりすることはありません。SDD ワークフローの決定権は常にファイルベースの手続き側にあり、MCP はそれを補助する情報源にとどまります。

また、この read-only な助言層としての位置づけを維持するため、write tool（状態を変更・作成・進行させる tool）をこれらの MCP サーバーに追加しない方針を継続しています。以下の `sdd-forge-mcp` / `local-env-mcp` / `ci-mcp` はいずれも読み取り専用の tool のみを登録しており、将来の機能拡張であってもこの方針は変わりません。

3 つのサーバーの概要と、各ツール契約（入出力スキーマ）の正準ソースは以下のとおりです。契約スキーマはいずれもリポジトリ直下の `contracts/` 配下にあります。

| サーバー | ツール数 | 契約の正準ソース |
|---|---|---|
| `sdd-forge-mcp` | 4種（v2 SSOT 読み取り専用）、resources 2種（`--with-mcp` オプトイン） | [`contracts/sdd-mcp.v2.schema.json`](contracts/sdd-mcp.v2.schema.json) |
| `local-env-mcp` | 3種（**v2.1.0 非推奨 / v2.2.0 廃止予定**） | [`contracts/local-env-mcp-tools.v1.schema.json`](contracts/local-env-mcp-tools.v1.schema.json) |
| `ci-mcp` | 5種（隔離環境向け `--mcp ci-mcp` オプトイン専用） | [`contracts/ci-mcp-tools.v1.schema.json`](contracts/ci-mcp-tools.v1.schema.json) |

いずれのサーバーも **Node.js >= 20 LTS** で動作します（v2.0.0 以降、`Node >= 26.13.0` 要件は撤廃済みです）。

### sdd-forge-mcp

#### 概要

`sdd-forge-mcp` v2 は、対象リポジトリの SDD Core 状態（Active Features / トレーサビリティ / Spec Drift / Decision View / 品質ゲート整合性 / ダッシュボードスナップショット）を構造化データとして読み取る **read-only** MCP サーバーです。純粋読み取り専用コア（`plugins/sdd-quality-loop/scripts/v2/v2-readonly-core.mjs`）と `path-guard.ts` を直接接続する Single Source of Truth 構成であり、書き込み API は `dist/index.js` 含め一切保持しません。

#### 導入・除外・選択導入

ADR-0052 に基づき、ローカル CLI プラグイン導入時は **既定で MCP クライアント登録を行いません（0 トークン税・常駐プロセス 0 本）**。ただし `/sdd-ship:status` のローカル CLI 実行に必要な `INSTALL_ROOT/mcp/sdd-forge-mcp/dist/index.js` のみ配置されます。

| オプション | 効果 |
|---|---|
| （既定） | ローカル CLI プラグインのみ導入・登録（MCP クライアント未登録。`plugins/sdd-quality-loop/scripts/v2/*.mjs` を直接使用） |
| `--with-mcp` | 単一の `sdd-forge-mcp` v2（4 ツール + 2 リソース）を `--target` に応じて登録（Claude / Codex / Cursor / VS Code / Antigravity `agy` / Gemini） |
| `--skip-mcp` | すべての MCP クライアント登録を明示スキップ（`--with-mcp` / `--mcp` との併用不可） |
| `--mcp sdd-forge-mcp,ci-mcp` | 登録する MCP を明示指定してオプトイン（`local-env-mcp` は ADR-0052 により非推奨警告を表示） |

`--with-mcp` 指定時の登録先：
- **Claude Code**: `claude mcp add sdd-forge-mcp --scope user -- node <INSTALL_ROOT>/mcp/sdd-forge-mcp/dist/index.js`
- **Codex CLI**: `~/.codex/config.toml`（マーカー区切りブロック追記）
- **Antigravity CLI (`agy`)**: `~/.gemini/config/mcp_config.json` の `mcpServers`（`SDD_ANTIGRAVITY_CONFIG_DIR` で上書き可）
- **Cursor**: `~/.cursor/mcp.json` の `mcpServers`
- **VS Code**: ユーザープロファイルの `mcp.json` の `servers`
- **旧 Gemini CLI**: `~/.gemini/settings.json` の `mcpServers`（`SDD_GEMINI_DIR` で上書き可）

**Node.js 要件**: Node >= 20 LTS が必要です。フックのホスト要件と導入後の有効化確認は [README のインストール案内](README.md#インストール)を参照してください。

#### 対象リポジトリの指定

MCP サーバーがどのリポジトリを SDD ルートとして扱うかは、以下の優先順位で起動時に一度だけ固定されます（`CLAUDE_PROJECT_DIR` / `SDD_PROJECT_ROOT` には上書きされません）：

1. 起動引数 `--root <path>`
2. 環境変数 `SDD_FORGE_ROOT`
3. プロセスの `cwd`

#### tools（4種・すべて `readOnlyHint: true`）

| tool | 用途 |
|---|---|
| `sdd_project_overview` | 全 Active Features のリスク・タスク集計・Spec Drift・次アクション・`sdd-doctor` 健全性を 1 往復で返却 |
| `sdd_feature_state` | 指定 feature の REQ↔AC↔Task トレーサビリティ、Spec Drift、Open Questions (`OQ-NNN`)、次アクション、および任意 Decision View（観点採否表・元箇所行番号付き）を一括返却 |
| `sdd_gate_audit` | 指定 feature / task の決定論 `.execution.json`、独立 G1–G5 レポート `VERDICT`、Spec Drift、`Risk: high` 未確定 `OQ-NNN` を fail-closed 検証 |
| `sdd_dashboard_snapshot` | ホスト／ローカルダッシュボード向け読み取り専用スナップショット（統一 `Result<T>` エンベロープ） |

#### resources（2種）

| URI | 対応する tool |
|---|---|
| `sdd://overview` | `sdd_project_overview({ includeDoctor: true })` |
| `sdd://feature/{feature}` | `sdd_feature_state({ feature, includeDecisionViewMarkdown: true })` |

#### セキュリティ特性

読み取り可能な範囲は `path-guard.ts` の allowlist（`specs/`、`reports/`、`sdd/knowledge/`、`docs/review-tickets/`、`docs/workflow-improvements/`、`AGENTS.md`、`dashboard-labels.json`、`sdd/guardrails.{yaml,json}`、`.sdd/drift-events.jsonl`、`.sdd/factory-metrics.jsonl`）に厳格限定され、denylist（`SDD_SUDO`、evidence 署名鍵、`.env` / `.env.*`）は allowlist 配下の symlink 経由であっても常に拒否されます。ファイルサイズ上限は 2 MiB（`too-large`）で、書き込み系 API は `dist/index.js` を含め一切含まれません。

#### トラブルシュート

**stderr ログの読み方**: MCP プロトコル準拠のため `stdout` は JSON-RPC 専用で、診断ログはすべて `stderr` に出力されます。起動時に解決した root とその出所（`cli`/`env`/`cwd`）、各 tool 呼び出しの要求内容（tool 名・対象パス）、拒否理由、エラーが記録されます。ファイル内容や環境変数の値はログに出力されません。

**エラーコードの意味**（`Result<T>` 応答の `error.code`）

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

登録形式
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

自動登録対象（OS 別パス）
- **macOS**: `~/Library/Application Support/Code/User/mcp.json`
- **Linux**: `~/.config/Code/User/mcp.json`
- **Windows**: `%APPDATA%\Code\User\mcp.json`

登録形式
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

**重要**: 既存の他エントリは保持し、上書きしないでください。登録解除時も同様に該当のエントリのみを削除してください。

#### フェイルセーフ挙動

- クライアント設定ディレクトリが存在しない場合（クライアント未導入）: そのクライアントのみ登録をスキップし、他のクライアントの登録は継続します
- 設定ファイルが壊れた JSON の場合: 上書きしない（データ破壊を防止）。エラー通知を表示し、該当クライアントの登録のみ中断します

**ロールバック手順**

1. `./uninstall.sh --mcp sdd-forge-mcp,local-env-mcp,ci-mcp`（または `--skip-mcp-uninstall` を付けずに通常のフル uninstall。`--mcp` 省略時は 3 件すべてが対象）を実行すると、Claude / Codex / Cursor / VS Code / Gemini への登録解除と配置済みファイルの削除が行われます
   - 登録解除時は、installer が管理するエントリ（`sdd-forge-mcp`・`local-env-mcp`・`ci-mcp`）のみを削除し、他のユーザー定義エントリは無傷です
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

各ツールの入力スキーマは `.strict()` で、action/method/body を受け取るフィールドは一切存在しません（write 誘発フィールドの構造的排除）。契約の正準ソースは [`contracts/ci-mcp-tools.v1.schema.json`](contracts/ci-mcp-tools.v1.schema.json)（リポジトリ直下の `contracts/` 配下）です。

#### セキュリティ境界

- **write 機能なし**: GET 専用・ホストは `https://api.github.com` に固定でどのツール引数からも書き換え不可。write API・write ツールは実装されていません
- **exec なし**: `child_process` を import しているファイルはリポジトリ内に存在せず、`git remote` 等によるリポジトリ推測も行いません（owner/repo は明示引数または `CI_MCP_REPO` からのみ解決）
- **トークンの非漏えい**: トークン値・`Authorization` ヘッダ値は応答・診断ログ・エラー詳細のいずれにも出力されません。トークンは環境変数からのみ読み取り、プロセスを終了させることもありません（未設定時は `auth-missing` を返すのみ）
- **ジョブログ truncation**: `get_job_log` は 256 KiB（262144 バイト）を超えるログを末尾優先で切り詰め、`truncated`/`returnedBytes` で状態を明示します（診断上重要なのは末尾のため）
- **上流エラーの正規化**: GitHub API のレスポンス本文は成功時のみ読み取られ、エラー時は本文を転載せず決定論的に `upstream-error`/`rate-limited`/`not-found`/`auth-missing` へ写像します

#### トークン設定

`ci-mcp` の実行には read-only スコープの GitHub PAT（Personal Access Token）が必要です。以下の優先順位で最初に非空の環境変数値を採用します（OQ-004）

1. `CI_MCP_GITHUB_TOKEN`（推奨・ci-mcp 専用）
2. `GH_READONLY_TOKEN`（read-only 用途で共有する場合）
3. `GITHUB_TOKEN`（汎用フォールバック）

installer はトークン値を一切生成・保存しません。MCP クライアント（Claude Code / Codex / Cursor / VS Code）がプロセスを起動する環境に、上記いずれかの変数を利用者自身が設定してください。トークンは **Actions の読み取りに必要な最小スコープ**（`repo` の read アクセス、または fine-grained PAT の `Actions: Read-only` + `Contents: Read-only`）のみを付与した read-only PAT を強く推奨します。write スコープを持つトークンを渡しても ci-mcp は write API を呼び出しませんが、最小権限の原則としてトークン自体のスコープを絞ってください。

#### 対象リポジトリの指定（`CI_MCP_REPO`）

各ツールは以下の優先順位で対象リポジトリ（owner/repo）を解決します（OQ-001）

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

登録形式
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

自動登録対象（OS 別パス）
- **macOS**: `~/Library/Application Support/Code/User/mcp.json`
- **Linux**: `~/.config/Code/User/mcp.json`
- **Windows**: `%APPDATA%\Code\User\mcp.json`

登録形式
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

**重要**: 既存の他エントリは保持し、上書きしないでください。登録解除時も同様に該当のエントリのみを削除してください。

#### フェイルセーフ挙動

- クライアント設定ディレクトリが存在しない場合（クライアント未導入）: そのクライアントのみ登録をスキップし、他のクライアントの登録は継続します
- 設定ファイルが壊れた JSON の場合: 上書きしない（データ破壊を防止）。エラー通知を表示し、該当クライアントの登録のみ中断します
- Node.js が使えない、または 20.0.0 LTS 未満の場合: MCP 登録を警告付きでスキップします。導入後に Node や PATH が変わった場合も、実際のクライアント環境を復旧してから起動を確認してください

**ロールバック手順**

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

## 旧ユーザーガイドからの移行先

本書はかつて「SDD Plugins User Guide」として SDD の使い方全般を扱っていましたが、その内容は再構成され、複数のドキュメントに分割されました。現在の本書に残っているのは、上記の MCP サーバーとエージェントモデルルーティングのリファレンスのみです。旧セクションをお探しの場合は以下の表を参照してください。

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

文書中心の固有手順は `project-skill.py seal --root . --name <name> --document-only --check <check-id>` で記録できます。実行可能な手順ではないため draft/not-run を保持し、試行・保守から成功判定は生成されません。

## セッション開始時のモデル選択

新規の対話セッションでは、Claude Code・Codex CLIのSessionStartフックが
`model-selection` を案内します。フックが使えない場合はbootstrap／shipの入口から確認します。
モデル候補と前回設定を確認してから、メインと役割別のモデル・対応する推論設定を選びます。
メインには起動したCLIのモデルを選び、標準の `/model` 等で変更を適用して確認してください。
サブエージェントは別会社のモデルも選べますが、各役割に対応する安全な起動経路が必要です。

Antigravity CLI（`agy`）では、インストーラーの `--target Antigravity`（PowerShell は `-Target Antigravity`）または `All` でネイティブプラグイン（`.antigravity-plugin/plugin.json`＋ルート `hooks.json`）として登録され、`agy models` から最新モデル一覧を動的取得できます。旧 Gemini CLI 用の拡張機能は `--target Gemini` で後方互換維持しています。

- 共通の選択UIは各CLIの既存認証を使い、ClaudeのSDK制御プロトコル、CodexのApp Server
  `model/list`、Antigravity CLIの `agy models`、旧Gemini CLIの認証後ACPセッションからモデル一覧を取得します。
  固定のモデル名や環境変数の値で候補を補わず、取得できない場合は理由と更新操作を表示します。
- 一覧の `listed` はCLIから取得した候補、`unverified` は使用者が追加した未確認候補です。
  いずれも推論成功を保証しません。APIキー・OAuth・ChatGPTの認証経路と課金枠を混同せず、
  CLI管理で方式が分からない場合は未確認と表示します。別の認証方式へ自動で切り替えません。
- 推論の強さはモデルごとに取得した選択肢と「CLI既定」から選びます。
  Geminiの現行ACPにはモデル別推論強度がないため、CLI既定だけを提示します。
- 未使用の役割は明示的に無効にできます。その役割を実行する際には停止して再選択を求めます。
  GPT/Geminiのpanelistは、それぞれ元の会社に固定してクロスモデル検証の多様性を維持します。
- Geminiの汎用独立レビューなど、対応アダプターがない組み合わせは停止します。
  設定を保存しただけで実行可能とは扱わず、別のCLI／モデルを選び直してください。
- 起動失敗時に別モデルへ自動で切り替えません。新しいAPIキー管理は追加せず、各CLIの既存ログインを使います。

個人設定は `XDG_CONFIG_HOME/sdd-forge/model-profiles/`（未設定なら
`~/.config/sdd-forge/model-profiles/`）にプロジェクトの実パスのハッシュ別に保存します。
Gitには保存しません。メインはCLI別、役割別設定はそのプロジェクト共通です。
非対話実行・CI・ワーカー・resume・compactでは確認を繰り返しません。
ホストが対話性を通知しない場合も、注入する案内は対話時に限定します。
自動化では必要に応じて `SDD_SESSION_NONINTERACTIVE=1` で案内自体を抑制できます。

手動操作は、インストールしたsdd-implementationの `scripts/session-models.py` で行えます。
引数のパスはプロジェクトをcwdとして指定します。

```text
python3 <scripts>/session-models.py begin --host antigravity-cli --session <session-id>
python3 <scripts>/session-models.py set --session <session-id> --role evaluator --host antigravity-cli --model gemini-4-neon-xhigh
python3 <scripts>/session-models.py disable --session <session-id> --role workflow-auditor-b
python3 <scripts>/session-models.py status --session <session-id>
python3 <scripts>/session-models.py confirm --session <session-id> --main-applied
```

初回は各役割を選択または無効化します。次回は前回設定を一括確認できます。
候補を再取得する場合は `begin --refresh`、未掲載の具体的IDは `add-candidate`
（未確認候補として追加）、中止は `cancel` を使います。設定変更・再取得後は再確認が必要です。
新規セッションと、15分以上古い一覧で選択画面を開き直した際にも更新します。
取得した新しい推論強度でも、役割別の起動経路が未対応なら停止して再選択を求めます。
CLI/API契約は `contracts/session-model-selection.schema.json` と
`plugins/sdd-implementation/skills/model-selection/SKILL.md` を参照してください。
