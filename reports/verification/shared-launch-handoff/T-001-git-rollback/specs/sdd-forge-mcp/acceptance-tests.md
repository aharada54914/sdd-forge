# Acceptance Tests: sdd-forge-mcp

| Acceptance Criterion | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001 既存 6 spec で `get_task_state` が `check-task-state.sh` 判定と完全一致（PASS/FAIL・失敗理由の対応関係含む） | REQ-005 | TEST-001 | integration (golden) | mcp/sdd-forge-mcp/tests/golden/ | Planned |
| AC-002 不正な tasks.md（重複 T-ID、不正 Status、Approval 欠落）に `cannot-parse` を返し推測しない | REQ-005 | TEST-002 | unit | mcp/sdd-forge-mcp/tests/parser/ | Planned |
| AC-003 `..`・絶対パス・allowlist 外へ解決される symlink を含む feature/path 引数が拒否される | REQ-006 | TEST-003 | unit | mcp/sdd-forge-mcp/tests/path-security/ | Planned |
| AC-004 allowlist 外（`plugins/` `.git/` 等）読取不可、denylist（SDD_SUDO・署名鍵・.env）が応答に含まれない | REQ-006 | TEST-004 | unit + integration | mcp/sdd-forge-mcp/tests/path-security/ | Planned |
| AC-005 MCP Inspector smoke（tools/list, resources/list, 代表 tool 呼び出し）が macOS で通過 | REQ-001, REQ-002 | TEST-005 | e2e (scripted smoke) | mcp/sdd-forge-mcp/tests/smoke/ | Planned |
| AC-006 windows-latest でパーサー・パス処理テストが通過（ドライブレター・バックスラッシュ含む） | REQ-010 | TEST-006 | CI integration | .github/workflows/test.yml | Planned |
| AC-007 デフォルト install で MCP 配置+Claude/Codex 登録、`--skip-mcp` で両方スキップ | REQ-009 | TEST-007 | integration | tests/install.tests.sh / .ps1 | Planned |
| AC-008 `--mcp <list>` で指定された MCP のみ導入される（不正名はエラー） | REQ-009 | TEST-008 | integration | tests/install.tests.sh / .ps1 | Planned |
| AC-009 uninstall で MCP 配置ファイル除去+登録解除（未導入時は best-effort 成功） | REQ-009 | TEST-009 | integration | tests/uninstall.tests.sh / .ps1 | Planned |
| AC-010 CI で src/ からの再ビルド結果とコミット済み dist/ が一致 | REQ-008 | TEST-010 | CI check | .github/workflows/test.yml | Planned |
| AC-011 書込み API（fs.write*/appendFile/mkdir/rm 等）が本体コードに存在しない（静的検証）+ 実行前後でリポジトリの mtime/内容が不変 | REQ-001 | TEST-011 | static + integration | mcp/sdd-forge-mcp/tests/readonly/ | Planned |
| AC-012 `get_next_sdd_command` が AGENTS.md フェーズ定義・sdd-ship 選択規則と整合（fixture 網羅: Phase1〜quality-gate、判定不能→`cannot-determine`） | REQ-011 | TEST-012 | unit (fixture) | mcp/sdd-forge-mcp/tests/next-command/ | Planned |
| AC-013 Resources 5 種（sdd://active-specs 等）が対応ファイル内容を正しく返す | REQ-004 | TEST-013 | integration | mcp/sdd-forge-mcp/tests/resources/ | Planned |
| AC-014 evidence tools が evidence.json / contract.json / traceability.md を正しく解釈し不足・不一致を構造化して返す | REQ-003 | TEST-014 | integration (fixture) | mcp/sdd-forge-mcp/tests/evidence/ | Planned |
| AC-015 8 core tools すべてが fixture リポジトリに対し契約スキーマ（contracts/sdd-forge-mcp-tools.v1.schema.json）準拠の応答を返し、tool ごとの主要フィールド（kind・feature・件数等）が期待値と一致する | REQ-002 | TEST-015 | integration | mcp/sdd-forge-mcp/tests/core-tools/ | Planned |
| AC-016 root 不変性: 全 tool の入力スキーマに root 相当の引数が存在せず（契約の静的検証）、起動後に SDD_FORGE_ROOT / cwd を変更しても応答の対象 root が起動時の値のまま変わらない | REQ-007 | TEST-016 | unit + static | mcp/sdd-forge-mcp/tests/root-immutable/ | Planned |
| AC-017 3 つの名前付きエラーパスが構造化エラーで返る: tasks.md 欠落 feature→`not-found`、SDD 構造なし root→`not-sdd-root`、サイズ上限（2 MiB）超過ファイル→`too-large`。いずれも推測値を返さない | REQ-005, REQ-006 | TEST-017 | unit | mcp/sdd-forge-mcp/tests/error-paths/ | Planned |

## Notes

- TEST-001 のゴールデンテストは、specs/ 配下の実 spec 6 件それぞれについて
  `bash plugins/sdd-quality-loop/scripts/check-task-state.sh <tasks.md>` の
  exit code・失敗メッセージ集合と、`get_task_state` の
  `verdict` / `failures[]` を突合する。CI（POSIX）で常設し、シェル側の変更による
  ドリフトを検出する。Windows ではシェル実行の代わりに記録済みゴールデン
  フィクスチャと比較する。
- TEST-005 は `@modelcontextprotocol/inspector` の CLI モード
  （`--method tools/list` 等）をスクリプト化し、手動 GUI 確認を補助とする。
- 本 feature は UI エントリポイントを追加しないため、UI Integration Checklist は
  適用外（non-UI feature）。
