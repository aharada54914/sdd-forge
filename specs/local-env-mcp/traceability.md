# Traceability: local-env-mcp

## REQ → 根拠 / Layer Spec

各 REQ の正準レイヤー仕様アンカー(Layer Spec 列)。レイヤー仕様が所有しない
横断要件は `N/A — cross-layer only:` で理由を記す。

| REQ-ID | 根拠 | Layer Spec | 説明 |
|-----|---|---|---|
| REQ-001 | Issue #64 スコープ | security-spec.md#trust-boundaries; frontend-spec.md#technology-stack | read-only 環境情報 MCP(ファイル読み書きなし) |
| REQ-002 | Issue #64 スコープ | N/A — cross-layer only: ツール仕様は design.md「API / Contract Plan」と contracts/local-env-mcp-tools.v1.schema.json が正準 | ツールチェーンバージョン・CLI 可用性・OS 情報の提供 |
| REQ-003 | Issue #64 承認済み決定 | security-spec.md#trust-boundaries; security-spec.md#stride-analysis | 実行機能非提供(固定 allowlist プローブのみ、ADR-0004) |
| REQ-004 | sdd-forge-mcp 基盤踏襲 | N/A — cross-layer only: エンベロープ契約は contracts/local-env-mcp-tools.v1.schema.json が正準 | エラーエンベロープ + 契約化 |
| REQ-005 | セキュリティ方針 | security-spec.md#secrets-management; security-spec.md#data-classification-and-protection | 秘密情報・準 PII の非漏えい |
| REQ-006 | ADR-0003(Issue #64 前提) | infra-spec.md#cicd-sequence; security-spec.md#sbom-and-supply-chain | esbuild 単一バンドル + dist-parity CI |
| REQ-007 | Issue #64 スコープ | infra-spec.md#deployment-topology | installer 同梱・選択(デフォルト同梱) |
| REQ-008 | Issue #64 スコープ | infra-spec.md#deployment-topology; security-spec.md#trust-boundaries | Cursor 登録(ADR-0005) |
| REQ-009 | Issue #64 スコープ | infra-spec.md#deployment-topology; security-spec.md#trust-boundaries | VS Code(Copilot MCP)登録(ADR-0005) |
| REQ-010 | ADR-0003 の uninstall 対称性 | infra-spec.md#rollback; security-spec.md#trust-boundaries | 登録解除・配置削除 |
| REQ-011 | Issue #64 スコープ | N/A — cross-layer only: README / USERGUIDE のドキュメント要件でレイヤー仕様の対象外 | README / USERGUIDE 追記 |
| REQ-012 | AGENTS.md 品質規約 | frontend-spec.md#testing | node:test / 既存テストハーネス準拠 |

## REQ → ADR

| REQ-ID | 関連 ADR | 決定内容 |
|-----|---|---|
| REQ-001, REQ-003, REQ-005 | ADR-0004 | 実行機能非提供・コンパイル時固定 allowlist プローブ・秘密情報非漏えい境界 |
| REQ-006, REQ-007 | ADR-0003 | esbuild 単一バンドル dist コミット + dist-parity CI + Node >= 20 |
| REQ-008, REQ-009, REQ-010 | ADR-0005 | Cursor / VS Code への冪等 JSON upsert 登録と管理キー限定の解除 |

## Task → REQ

| Task | REQ-ID | 内容 |
|---|-----|---|
| T-001 | REQ-001, REQ-003, REQ-012 | サーバー基盤・エンベロープ・allowlist・probe-engine |
| T-002 | REQ-001, REQ-002, REQ-003, REQ-004 | 3 ツール・server/index・契約・no-exec |
| T-003 | REQ-001, REQ-005 | stderr 診断ロガー(redaction)+ no-secrets 検査 |
| T-004 | REQ-001, REQ-002, REQ-006, REQ-012 | dist バンドル + dist-parity CI + Inspector スモーク |
| T-005 | REQ-008, REQ-009 | OQ-001 解消(Cursor / VS Code 設定形式確定) |
| T-006 | REQ-007 | installer sh コア: 同梱・選択・Node<20 ゲート |
| T-007 | REQ-008, REQ-009 | installer sh Cursor / VS Code 冪等登録 |
| T-008 | REQ-007, REQ-008, REQ-009 | installer ps1 パリティ |
| T-009 | REQ-010 | uninstall 登録解除・配置削除 |
| T-010 | REQ-011 | ドキュメント + traceability 最終化 |

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
| AC-005 | TEST-005 | T-003 | mcp/local-env-mcp/tests/no-secrets/ |
| AC-006 | TEST-006 | T-001 | mcp/local-env-mcp/tests/readonly/ |
| AC-007 | TEST-007 | T-004 | mcp/local-env-mcp/tests/smoke/ |
| AC-008 | TEST-008 | T-004 | .github/workflows/test.yml |
| AC-009 | TEST-009 | T-006 | tests/install.tests.sh |
| AC-010 | TEST-010 | T-007 | tests/install.tests.sh |
| AC-011 | TEST-011 | T-007 | tests/install.tests.sh |
| AC-012 | TEST-012 | T-009 | tests/uninstall.tests.sh / tests/install.tests.ps1 |
| AC-013 | TEST-013 | T-008 | tests/install.tests.ps1 |
| AC-014 | TEST-014 | T-010 | README.md / USERGUIDE.md(quality gate レビュー) |
| AC-015 | TEST-015 | T-007 | tests/install.tests.sh |

## Verification Status (T-010, 2026-07-05)

Implementation of documentation and traceability finalization for local-env-mcp feature.

| TEST-ID | Implementing Task | Verification Location |
|---|---|---|
| TEST-001 | T-002 | specs/local-env-mcp/verification/T-002-green.txt |
| TEST-002 | T-002 | specs/local-env-mcp/verification/T-002-green.txt |
| TEST-003 | T-002 | specs/local-env-mcp/verification/T-002-green.txt |
| TEST-004 | T-001 | specs/local-env-mcp/verification/T-001-green.txt |
| TEST-005 | T-003 | specs/local-env-mcp/verification/T-003-green.txt |
| TEST-006 | T-001 | specs/local-env-mcp/verification/T-001-green.txt |
| TEST-007 | T-004 | specs/local-env-mcp/verification/T-004-acceptance.txt |
| TEST-008 | T-004 | specs/local-env-mcp/verification/T-004-acceptance.txt |
| TEST-009 | T-006 | specs/local-env-mcp/verification/T-006-green.txt |
| TEST-010 | T-007 | specs/local-env-mcp/verification/T-007-green.txt |
| TEST-011 | T-007 | specs/local-env-mcp/verification/T-007-green.txt |
| TEST-012 | T-009 | specs/local-env-mcp/verification/T-009-green.txt |
| TEST-013 | T-008 | specs/local-env-mcp/verification/T-008-green.txt |
| TEST-014 | T-010 | README.md / USERGUIDE.md (quality gate verification) |
| TEST-015 | T-007 | specs/local-env-mcp/verification/T-007-green.txt |
