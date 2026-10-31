# Acceptance Tests: local-env-mcp

| Acceptance Criterion | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001 `get_os_info` が platform / arch / OS type / release / CPU 論理コア数 / 総メモリ / Node ランタイムバージョンを契約準拠エンベロープ(`ok: true`)で返す | REQ-002, REQ-004 | TEST-001 | unit (snapshot) | mcp/local-env-mcp/tests/tools/ | Planned |
| AC-002 `get_toolchain_versions` が、存在する CLI は `available: true` + 正規化済みバージョン文字列、存在しない CLI は `available: false` を per-entry で返し、全体は `ok: true` | REQ-002, REQ-003 | TEST-002 | integration | mcp/local-env-mcp/tests/tools/ | Planned |
| AC-003 3 ツールすべての入力スキーマにコマンド・引数・パスを受け取るフィールドが存在せず、`names` フィルタは allowlist 名 enum のみ受理、allowlist 外は `invalid-input` | REQ-003 | TEST-003 | unit + static | mcp/local-env-mcp/tests/no-exec/ | Planned |
| AC-004 プローブのタイムアウト(2 秒)超過・出力上限(8 KiB)超過でプロセスが kill され、per-entry 失敗として報告、応答は契約準拠のまま | REQ-003, REQ-004 | TEST-004 | integration (error-path, fake slow/verbose CLI fixture) | mcp/local-env-mcp/tests/error-paths/ | Planned |
| AC-005 canary 環境変数(例: `LOCAL_ENV_MCP_CANARY=secretvalue`)を設定して全ツールを呼んでも、応答・stderr ログに canary 値・ユーザー名・ホスト名・ホームパス・PATH 全文が現れない | REQ-005 | TEST-005 | integration (no-secret grep) | mcp/local-env-mcp/tests/no-secrets/ | Planned |
| AC-006 src に fs 書込み API(writeFile/appendFile/mkdir/rm 等)・`child_process.exec`・`spawn`(shell: true)・`eval` が存在しない(`execFile` のみ許可)静的検査が PASS | REQ-001, REQ-003 | TEST-006 | static (grep) | mcp/local-env-mcp/tests/readonly/ | Planned |
| AC-007 MCP Inspector CLI スモーク: サーバーが stdio で起動し `tools/list` に `get_os_info` / `get_toolchain_versions` / `list_available_clis` の 3 件が現れる | REQ-001, REQ-002 | TEST-007 | smoke | mcp/local-env-mcp/tests/smoke/ | Planned |
| AC-008 dist-parity: CI が src から esbuild 再ビルドしたバンドルとコミット済み `dist/index.js` の一致を検証し PASS | REQ-006 | TEST-008 | CI (dist-parity) | .github/workflows/test.yml | Planned |
| AC-009 install.sh: デフォルトで local-env-mcp が配置され Claude / Codex 登録経路に含まれる。`--mcp sdd-forge-mcp` 指定時は local-env-mcp が配置されない。`--skip-mcp` で配置・登録とも行われない | REQ-007 | TEST-009 | integration (installer harness) | tests/install.tests.sh | Planned |
| AC-010 Cursor 登録: 既存 `~/.cursor/mcp.json`(他エントリあり)に対する登録が他エントリを保持したまま `mcpServers.<name>` を upsert し、再実行しても重複・差分が生じない。設定ディレクトリ不在時はスキップ通知 | REQ-008 | TEST-010 | integration (installer harness, HOME 隔離) | tests/install.tests.sh | Planned |
| AC-011 VS Code 登録: ユーザープロファイル `mcp.json`(他エントリあり)への upsert が他エントリを保持し、再実行で冪等。未導入時はスキップ通知 | REQ-009 | TEST-011 | integration (installer harness, HOME 隔離) | tests/install.tests.sh | Planned |
| AC-012 uninstall.sh / uninstall.ps1: 配置済み local-env-mcp が削除され、Claude / Codex / Cursor / VS Code から installer 管理エントリのみ除去、ユーザー定義の他エントリは無傷 | REQ-010 | TEST-012 | integration (installer harness) | tests/uninstall.tests.sh / tests/install.tests.ps1 | Planned |
| AC-013 install.ps1 が install.sh と同一挙動(local-env-mcp 既定同梱・選択・Cursor / VS Code 登録・冪等性)を持つ | REQ-007, REQ-008, REQ-009 | TEST-013 | integration (installer harness) | tests/install.tests.ps1 | Planned |
| AC-014 README / USERGUIDE に local-env-mcp の概要・ツール一覧・実行機能なしの境界・Cursor / VS Code 自動/手動登録手順が記載されている | REQ-011 | TEST-014 | doc review (quality gate) | README.md / USERGUIDE.md | Planned |
| AC-015 壊れた JSON の `~/.cursor/mcp.json` / VS Code `mcp.json` に対して installer が上書きせずエラー通知し、該当クライアント以外の登録は継続する | REQ-008, REQ-009 | TEST-015 | integration (error-path, installer harness) | tests/install.tests.sh | Planned |

## UI Integration Checklist

N/A — 本 feature はシェル UI(view / dialog / menu item / context action)を追加
しない。ユーザー接点は MCP ツール(AI クライアント経由)と installer CLI のみ。
