# Frontend Specification: ci-mcp

N/A — no change: フロントエンド UI は存在しない(non-UI feature)。本書は
ランタイム・依存・テスト環境の記録のみを行い、UI 関連節は reasoned N/A とする。

## Technology Stack

| Layer | Technology | Version | Rationale | Constraint |
|---|---|---|---|---|
| Runtime | Node.js | >= 20 | ADR-0003 の実行要件と一致(REQ-009)。undici 内蔵 `fetch` を使用 | 単一バンドル実行、npm install 不要 |
| 言語 | TypeScript | ^5.9 | sdd-forge-mcp / local-env-mcp と同一基盤 | strict mode |
| MCP SDK | @modelcontextprotocol/sdk | ^1.29 | 既存 2 MCP と同一 | stdio transport のみ |
| スキーマ検証 | zod | ^4 | ツール入力の enum / 形式制約(REQ-003, REQ-007) | 入力に write 誘発フィールド(action/method/body)を定義しない |
| HTTP | Node 内蔵 `fetch`(undici) | Node 20 内蔵 | 追加依存なしで GET 専用アクセス | GET 固定・write メソッド不使用の静的検査 |
| ビルド | esbuild | ^0.28 | 単一バンドル(ADR-0003) | dist コミット + dist-parity CI |
| Test | node:test | Node 20 内蔵 | 外部依存なし(REQ-013) | tsconfig.test.json + run-tests.mjs 方式・fake HTTP でスタブ |

## Component Tree / State Shape / Routes / API Client / Code Splitting / Performance Budget / Empty-Loading-Error-Success

N/A — no change: ブラウザ UI・ルーティング・クライアント状態を持たない。
応答状態(ok / error エンベロープ)の正準定義は
`contracts/ci-mcp-tools.v1.schema.json`(REQ-004)。GitHub API クライアントは
サーバー内部の `github-client`(GET 専用 fetch ラッパ)であり、フロントエンドの
API クライアントではない。

## Dependencies

| Dependency | Version | Purpose | Alternative | License / Supply-Chain Note |
|---|---|---|---|---|
| @modelcontextprotocol/sdk | ^1.29.0 | MCP サーバー/stdio | 自前 JSON-RPC(却下: 保守コスト) | MIT / package-lock.json 固定 |
| zod | ^4.4 | 入力スキーマ | ajv 直接(却下: SDK 統合性) | MIT |
| esbuild (dev) | ^0.28 | バンドル | tsc のみ(却下: 単一ファイル配布不可) | MIT |

HTTP クライアントは Node 内蔵 `fetch`(undici)を使用し、`@octokit/*` や
`axios` 等の追加ランタイム依存を導入しない(バンドルサイズ・供給網面)。
js-yaml は不要(YAML を扱わない)。

## Testing

TEST-001〜TEST-015(acceptance-tests.md 参照)。GitHub API はローカルの
フェイク HTTP サーバー(またはインジェクトした fetch)でスタブし、実ネット
ワークに接続しない。UI テストは N/A。

## Open Questions

- なし
