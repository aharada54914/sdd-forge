# Frontend Specification: evidence-deep-verify

N/A — no change: フロントエンド UI は存在しない(non-UI feature)。本 feature は
sdd-forge-mcp(monorepo-nested package)への read-only MCP ツール 1 個の追加であり、
ブラウザ UI・ルーティング・クライアント状態を持たない。本書はランタイム・依存・テスト
環境の記録のみを行い、UI 関連節は reasoned N/A とする。

## Technology Stack

| Layer | Technology | Version | Rationale | Constraint |
|---|---|---|---|---|
| Runtime | Node.js | >= 20 | ADR-0003 の実行要件・既存 sdd-forge-mcp と一致 | 単一バンドル実行、追加依存なし |
| 言語 | TypeScript | ^5.9 | 既存 sdd-forge-mcp 基盤 | strict mode |
| MCP SDK | @modelcontextprotocol/sdk | ^1.29 | 既存 sdd-forge-mcp と同一 | stdio transport のみ |
| ハッシュ | node:crypto(標準) | Node 20 内蔵 | SHA-256 再計算(REQ-002/004/005) | 追加依存なし・git/python 不使用 |
| スキーマ検証 | zod | ^4 | ツール入力(feature/taskId) | コマンド/パス系フィールドを定義しない |
| ビルド | esbuild | ^0.28 | 単一バンドル(ADR-0003) | dist コミット + dist-parity CI |
| Test | node:test | Node 20 内蔵 | 外部依存なし(REQ-013) | tsconfig.test.json + run-tests.mjs 方式 |

## Component Tree / State Shape / Routes / API Client / Code Splitting / Performance Budget / Empty-Loading-Error-Success

N/A — no change: ブラウザ UI・ルーティング・クライアント状態を持たない。応答状態
(ok / error エンベロープ、`evidenceDeepVerifyData`)の正準定義は
`contracts/sdd-forge-mcp-tools.v1.schema.json`(REQ-012)。

## Dependencies

| Dependency | Version | Purpose | Alternative | License / Supply-Chain Note |
|---|---|---|---|---|
| @modelcontextprotocol/sdk | ^1.29.0 | MCP サーバー/stdio(既存) | 自前 JSON-RPC(却下) | MIT / 既存 package-lock.json 固定 |
| zod | ^4.4 | 入力スキーマ(既存) | ajv 直接(却下) | MIT |
| node:crypto | 標準 | SHA-256 再計算 | 外部 hash ライブラリ(却下: 標準で十分) | Node 標準 |

新規 npm 依存の追加なし(SHA-256 は node 標準)。

## Testing

TEST-001〜TEST-016(acceptance-tests.md 参照)。UI テストは N/A。

## Open Questions

- なし
