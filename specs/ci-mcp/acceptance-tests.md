# Acceptance Tests: ci-mcp

| Acceptance Criterion | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001 `list_workflow_runs` が対象 run の一覧(id / name / status / conclusion / branch / event / created/updated / run number / html_url)を契約準拠エンベロープ(`ok: true`)で返し、branch / status / event / 件数上限の絞り込み入力を受理する | REQ-002, REQ-004 | TEST-001 | integration (fake GitHub API) | mcp/ci-mcp/tests/tools/ | Planned |
| AC-002 `get_workflow_run` が単一 run の詳細(メタデータ + workflow 名 + 実行時間 + commit SHA)を契約準拠エンベロープで返す。存在しない run id は `not-found` | REQ-002, REQ-006 | TEST-002 | integration (fake GitHub API) | mcp/ci-mcp/tests/tools/ | Planned |
| AC-003 `list_run_jobs` が run 内ジョブ一覧(job id / name / status / conclusion / 開始/終了時刻 / 失敗ステップ番号)を契約準拠エンベロープで返す | REQ-002 | TEST-003 | integration (fake GitHub API) | mcp/ci-mcp/tests/tools/ | Planned |
| AC-004 `get_job_log` がジョブのプレーンテキストログを返し、上限 256 KiB 以内は `truncated: false`、超過時は末尾優先で truncate し `truncated: true` + `returnedBytes` を付す。いずれもエンベロープは `ok: true` | REQ-002, REQ-008 | TEST-004 | integration (fake GitHub API, 大容量ログ fixture) | mcp/ci-mcp/tests/tools/ | Planned |
| AC-005 `list_run_artifacts` が run の artifacts メタデータ(id / name / サイズ / expired / 有効期限)を返し、バイナリ内容を含まない。expired な artifact は `expired: true` でエラーにしない | REQ-002 | TEST-005 | integration (fake GitHub API) | mcp/ci-mcp/tests/tools/ | Planned |
| AC-006 5 ツールすべての入力スキーマに write を誘発するフィールド(action / method / body / command 系)が存在せず、owner/repo と read 絞り込みのみを受理する。不正入力は `invalid-input` | REQ-003, REQ-007 | TEST-006 | unit + static | mcp/ci-mcp/tests/no-write/ | Planned |
| AC-007 src に write を行う GitHub API 呼び出し(fetch の POST / PATCH / PUT / DELETE メソッド)・fs 書込み API(writeFile/appendFile/mkdir/rm 等)・`child_process`(exec/spawn/execFile)・`eval` が存在しない静的検査が PASS(HTTP メソッドは GET 固定) | REQ-001, REQ-003 | TEST-007 | static (grep) | mcp/ci-mcp/tests/readonly/ | Planned |
| AC-008 トークン環境変数が未設定のとき、全ツールが `auth-missing` エラーエンベロープを返し、プロセスは異常終了しない | REQ-005 | TEST-008 | integration (env 隔離) | mcp/ci-mcp/tests/auth/ | Planned |
| AC-009 canary トークン(例: `CI_MCP_GITHUB_TOKEN=ghp_canarysecret`)を設定して全ツールを呼んでも、応答・stderr ログ・エラー message/details に canary 値・`Authorization` ヘッダ値が現れない | REQ-005 | TEST-009 | integration (no-secret grep) | mcp/ci-mcp/tests/no-secrets/ | Planned |
| AC-010 GitHub API の 401 → `auth-missing`/`upstream-error`、403(+rate-limit ヘッダ)→ `rate-limited`、404 → `not-found`、429 → `rate-limited`、5xx / ネットワーク失敗 → `upstream-error` にマップされ、上流レスポンス本文が応答に転載されない | REQ-006 | TEST-010 | integration (fake GitHub API error-path) | mcp/ci-mcp/tests/error-paths/ | Planned |
| AC-011 `rate-limited` エラー時、`details` に(トークンを含まない)リセット時刻等の非機微メタデータのみが載る | REQ-006 | TEST-011 | integration (fake GitHub API, 429/403 fixture) | mcp/ci-mcp/tests/error-paths/ | Planned |
| AC-012 対象リポジトリが解決できない(owner/repo 未指定かつ既定なし)場合 `invalid-input` を返し、git remote 参照のための exec を行わない | REQ-007 | TEST-012 | unit + static | mcp/ci-mcp/tests/repo-resolve/ | Planned |
| AC-013 全ツール応答が `contracts/ci-mcp-tools.v1.schema.json` に ajv で適合する(ok / error 両分岐、追加した error code enum を含む) | REQ-004 | TEST-013 | unit (schema validation) | mcp/ci-mcp/tests/contract/ | Planned |
| AC-014 dist-parity: CI が src から esbuild 再ビルドしたバンドルとコミット済み `mcp/ci-mcp/dist/index.js` の一致を検証し PASS | REQ-009 | TEST-014 | CI (dist-parity) | .github/workflows/test.yml | Planned |
| AC-015 MCP Inspector CLI スモーク: サーバーが stdio で起動し `tools/list` に 5 ツール(`list_workflow_runs` / `get_workflow_run` / `list_run_jobs` / `get_job_log` / `list_run_artifacts`)が現れる | REQ-001, REQ-002 | TEST-015 | smoke | mcp/ci-mcp/tests/smoke/ | Planned |
| AC-016 install.sh: デフォルトで ci-mcp が配置され Claude / Codex / Cursor / VS Code 登録経路に含まれる。`--mcp sdd-forge-mcp` 指定時は ci-mcp が配置されない。`--skip-mcp` で配置・登録とも行われない。登録メッセージが必要なトークン環境変数名を案内する | REQ-010 | TEST-016 | integration (installer harness, HOME 隔離) | tests/install.tests.sh | Planned |
| AC-017 install.ps1 が install.sh と同一挙動(ci-mcp 既定同梱・選択・各クライアント登録・冪等性・トークン変数案内)を持つ | REQ-010 | TEST-017 | integration (installer harness) | tests/install.tests.ps1 | Planned |
| AC-018 uninstall.sh / uninstall.ps1: 配置済み ci-mcp が削除され、Claude / Codex / Cursor / VS Code から installer 管理の ci-mcp エントリのみ除去、ユーザー定義の他エントリは無傷 | REQ-011 | TEST-018 | integration (installer harness) | tests/uninstall.tests.sh / tests/install.tests.ps1 | Planned |
| AC-019 README / USERGUIDE に ci-mcp の概要・ツール一覧・write 機能なしの境界・トークン取り扱い・read-only PAT の環境変数と設定手順・各クライアント自動/手動登録手順が記載されている | REQ-012 | TEST-019 | doc review (quality gate) | README.md / USERGUIDE.md | Planned |

## UI Integration Checklist

N/A — 本 feature はシェル UI(view / dialog / menu item / context action)を追加
しない。ユーザー接点は MCP ツール(AI クライアント経由)と installer CLI のみ。
