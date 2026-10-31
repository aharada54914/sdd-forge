# Traceability: sdd-forge-mcp

## REQ → 根拠（Issue #60 / 決定事項）

| REQ-ID | 根拠 | 説明 |
|--------|------|------|
| REQ-001 | Issue #60 目的 | 完全 read-only の MCP サーバー（書込み一切なし） |
| REQ-002 | Issue #60 スコープ | Core tools 8 種 |
| REQ-003 | Issue #60 スコープ + 決定事項1 | Evidence tools 5 種（Evidence MCP 統合） |
| REQ-004 | Issue #60 スコープ | Resources 5 種（sdd:// URI） |
| REQ-005 | Issue #60 受入基準 | check-task-state.sh とのシェル等価（ゴールデンテスト） |
| REQ-006 | Issue #60 受入基準 | allowlist / denylist / path traversal 拒否 |
| REQ-007 | インタビュー決定（2026-07-04） | 起動時ルート固定（--root > SDD_FORGE_ROOT > cwd） |
| REQ-008 | インタビュー決定（2026-07-04）+ ADR-0003 | dist バンドルコミット配布、Node >= 20 |
| REQ-009 | Issue #60 スコープ + 決定事項2 + インタビュー決定 | installer 統合（デフォルト同梱・--skip-mcp・--mcp・登録自動） |
| REQ-010 | Issue #60 受入基準 | 3 OS CI、windows-latest でのパーサー・パス処理テスト |
| REQ-011 | Issue #60 スコープ | get_next_sdd_command の決定論マッピング |

## REQ → ADR

| REQ-ID | 関連 ADR | 決定内容 |
|--------|---------|---------|
| REQ-001, REQ-003, REQ-006 | ADR-0002 | read-only サーバーを repo 内 mcp/ に置き Evidence 機能を統合 |
| REQ-008, REQ-009 | ADR-0003 | dist バンドルコミット配布 + installer による登録自動化 |

## REQ → Task

| REQ-ID | Task-ID |
|--------|---------|
| REQ-001 | T-001, T-004 |
| REQ-002 | T-003, T-004 |
| REQ-003 | T-011, T-005 |
| REQ-004 | T-009 |
| REQ-005 | T-002 |
| REQ-006 | T-001 |
| REQ-007 | T-001 |
| REQ-008 | T-001, T-007 |
| REQ-009 | T-006, T-008 |
| REQ-010 | T-007 |
| REQ-011 | T-010 |

## AC → REQ（受け入れ基準 → 要件）

| AC-ID | REQ-ID | 検証内容 |
|-------|--------|---------|
| AC-001 | REQ-005 | 既存 6 spec でのシェル等価（ゴールデン） |
| AC-002 | REQ-005 | cannot-parse（推測禁止） |
| AC-003 | REQ-006 | path traversal 拒否 |
| AC-004 | REQ-006 | allowlist 外・denylist 読取不可 |
| AC-005 | REQ-001, REQ-002 | MCP Inspector smoke（macOS） |
| AC-006 | REQ-010 | windows-latest テスト通過 |
| AC-007 | REQ-009 | デフォルト install 配置+登録 / --skip-mcp |
| AC-008 | REQ-009 | --mcp <list> 選択導入 |
| AC-009 | REQ-009 | uninstall 除去+登録解除 |
| AC-010 | REQ-008 | dist-parity（再ビルド一致） |
| AC-011 | REQ-001 | 書込みコードパス不存在 + 実行時不変 |
| AC-012 | REQ-011 | next-command の整合 + cannot-determine |
| AC-013 | REQ-004 | resources 5 種の内容 |
| AC-014 | REQ-003 | evidence tools の解釈・突合 |
| AC-015 | REQ-002 | 8 core tools の契約スキーマ準拠 |
| AC-016 | REQ-007 | root 不変性 |
| AC-017 | REQ-005, REQ-006 | 名前付きエラーパス（not-found / not-sdd-root / too-large） |

## AC → TEST → Task

| AC-ID | TEST-ID | Task-ID | Test Target |
|-------|---------|---------|-------------|
| AC-001 | TEST-001 | T-002 | mcp/sdd-forge-mcp/tests/golden/ |
| AC-002 | TEST-002 | T-002 | mcp/sdd-forge-mcp/tests/parser/ |
| AC-003 | TEST-003 | T-001 | mcp/sdd-forge-mcp/tests/path-security/ |
| AC-004 | TEST-004 | T-001 | mcp/sdd-forge-mcp/tests/path-security/ |
| AC-005 | TEST-005 | T-010 | mcp/sdd-forge-mcp/tests/smoke/ |
| AC-006 | TEST-006 | T-007 | .github/workflows/test.yml |
| AC-007 | TEST-007 | T-006 | tests/install.tests.sh / .ps1 |
| AC-008 | TEST-008 | T-006 | tests/install.tests.sh / .ps1 |
| AC-009 | TEST-009 | T-006 | tests/uninstall.tests.sh / .ps1 |
| AC-010 | TEST-010 | T-007 | .github/workflows/test.yml |
| AC-011 | TEST-011 | T-001（静的）, T-004（実行時） | mcp/sdd-forge-mcp/tests/readonly/ |
| AC-012 | TEST-012 | T-010 | mcp/sdd-forge-mcp/tests/next-command/ |
| AC-013 | TEST-013 | T-009 | mcp/sdd-forge-mcp/tests/resources/ |
| AC-014 | TEST-014 | T-005 | mcp/sdd-forge-mcp/tests/evidence/ |
| AC-015 | TEST-015 | T-004 | mcp/sdd-forge-mcp/tests/core-tools/ |
| AC-016 | TEST-016 | T-001 | mcp/sdd-forge-mcp/tests/root-immutable/ |
| AC-017 | TEST-017 | T-001（too-large / not-sdd-root）, T-004（not-found） | mcp/sdd-forge-mcp/tests/error-paths/ |

## Open Questions のトレース

| OQ | Owner | 解決タスク |
|----|-------|-----------|
| OQ-001（design.md: Codex 登録手段） | ai-implementer | T-006（実装レポートに記録） |
| OQ-R1（requirements.md: --mcp リスト名規約） | human | tasks.md 承認時に確認（non-blocking） |
