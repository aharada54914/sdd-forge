# Traceability: local-env-mcp

## REQ → 根拠

| REQ-ID | 根拠 | 説明 |
|-----|---|---|
| REQ-001 | Issue #64 スコープ | read-only 環境情報 MCP(ファイル読み書きなし) |
| REQ-002 | Issue #64 スコープ | ツールチェーンバージョン・CLI 可用性・OS 情報の提供 |
| REQ-003 | Issue #64 承認済み決定 | 実行機能非提供(固定 allowlist プローブのみ、ADR-0004) |
| REQ-004 | sdd-forge-mcp 基盤踏襲(Issue #64 前提) | エラーエンベロープ + 契約化 |
| REQ-005 | セキュリティ方針(security-spec.md) | 秘密情報・準 PII の非漏えい |
| REQ-006 | ADR-0003(Issue #64 前提) | esbuild 単一バンドル + dist-parity CI |
| REQ-007 | Issue #64 スコープ | installer 同梱・選択(デフォルト同梱) |
| REQ-008 | Issue #64 スコープ | Cursor 登録(ADR-0005) |
| REQ-009 | Issue #64 スコープ | VS Code(Copilot MCP)登録(ADR-0005) |
| REQ-010 | ADR-0003 の uninstall 対称性 | 登録解除・配置削除 |
| REQ-011 | Issue #64 スコープ(ドキュメント) | README / USERGUIDE 追記 |
| REQ-012 | AGENTS.md 品質規約 | node:test / 既存テストハーネス準拠 |

## REQ → ADR

| REQ-ID | 関連 ADR | 決定内容 |
|-----|---|---|
| REQ-001, REQ-003, REQ-005 | ADR-0004 | 実行機能非提供・コンパイル時固定 allowlist プローブ・秘密情報非漏えい境界 |
| REQ-006 | ADR-0003 | esbuild 単一バンドル dist コミット + dist-parity CI + Node >= 20 |
| REQ-008, REQ-009, REQ-010 | ADR-0005 | Cursor / VS Code への冪等 JSON upsert 登録と管理キー限定の解除 |

## REQ → Task

| REQ-ID | Task | 内容 |
|-----|---|---|
| REQ-001 | T-001, T-002 | サーバー基盤・エンベロープ・ツール実装 |
| REQ-002 | T-002 | 3 ツール実装 |
| REQ-003 | T-001, T-002 | allowlist / probe-engine / 入力スキーマ境界 |
| REQ-004 | T-002 | 契約準拠(ajv 検証) |
| REQ-005 | T-002 | no-secrets 検査 |
| REQ-006 | T-003 | dist バンドル + dist-parity CI |
| REQ-007 | T-004, T-005 | installer 同梱・選択(sh / ps1) |
| REQ-008 | T-004, T-005 | Cursor 登録(sh / ps1) |
| REQ-009 | T-004, T-005 | VS Code 登録(sh / ps1) |
| REQ-010 | T-006 | uninstall 登録解除・配置削除 |
| REQ-011 | T-007 | ドキュメント |
| REQ-012 | T-001〜T-007 | テスト方式準拠(全タスク横断) |

## AC → REQ

| AC-ID | REQ-ID | 検証内容 |
|-----|---|---|
| AC-001 | REQ-002, REQ-004 | get_os_info の契約準拠応答 |
| AC-002 | REQ-002, REQ-003 | get_toolchain_versions の per-entry 挙動 |
| AC-003 | REQ-003 | 入力スキーマにコマンド系フィールド不在・allowlist 外拒否 |
| AC-004 | REQ-003, REQ-004 | timeout / 出力上限 / kill / 契約準拠 |
| AC-005 | REQ-005 | canary による秘密情報・準 PII 非漏えい |
| AC-006 | REQ-001, REQ-003 | 静的 read-only / no-exec 検査 |
| AC-007 | REQ-001, REQ-002 | Inspector スモーク(3 ツール列挙) |
| AC-008 | REQ-006 | dist-parity CI |
| AC-009 | REQ-007 | installer 同梱・選択・skip |
| AC-010 | REQ-008 | Cursor 冪等登録・他エントリ保持 |
| AC-011 | REQ-009 | VS Code 冪等登録・他エントリ保持 |
| AC-012 | REQ-010 | uninstall 管理エントリのみ除去 |
| AC-013 | REQ-007, REQ-008, REQ-009 | ps1 パリティ |
| AC-014 | REQ-011 | ドキュメント 4 項目 |
| AC-015 | REQ-008, REQ-009 | 壊れ JSON フェイルセーフ |

## AC → TEST → Task

| AC-ID | TEST-ID | Task-ID | Test Target |
|-----|---|---|---|
| AC-001 | TEST-001 | T-002 | mcp/local-env-mcp/tests/tools/ |
| AC-002 | TEST-002 | T-002 | mcp/local-env-mcp/tests/tools/ |
| AC-003 | TEST-003 | T-002 | mcp/local-env-mcp/tests/no-exec/ |
| AC-004 | TEST-004 | T-001 | mcp/local-env-mcp/tests/error-paths/ |
| AC-005 | TEST-005 | T-002 | mcp/local-env-mcp/tests/no-secrets/ |
| AC-006 | TEST-006 | T-001 | mcp/local-env-mcp/tests/readonly/ |
| AC-007 | TEST-007 | T-002 | mcp/local-env-mcp/tests/smoke/ |
| AC-008 | TEST-008 | T-003 | .github/workflows/test.yml |
| AC-009 | TEST-009 | T-004 | tests/install.tests.sh |
| AC-010 | TEST-010 | T-004 | tests/install.tests.sh |
| AC-011 | TEST-011 | T-004 | tests/install.tests.sh |
| AC-012 | TEST-012 | T-006 | tests/uninstall.tests.sh / tests/install.tests.ps1 |
| AC-013 | TEST-013 | T-005 | tests/install.tests.ps1 |
| AC-014 | TEST-014 | T-007 | README.md / USERGUIDE.md(quality gate レビュー) |
| AC-015 | TEST-015 | T-004 | tests/install.tests.sh |
