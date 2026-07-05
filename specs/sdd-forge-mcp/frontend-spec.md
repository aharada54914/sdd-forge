# Frontend Specification: sdd-forge-mcp

N/A — no change: フロントエンド UI は存在しない（non-UI feature）。
本書はランタイム・依存・テスト環境の記録のみを行い、UI 関連節は
reasoned N/A とする。

## Technology Stack

| Layer | Technology | Version | Rationale | Constraint |
|---|---|---|---|---|
| Runtime | Node.js | >= 20 (LTS) | MCP SDK 要件充足・fs/path の安定 API・利用者環境の下限 | engines.node で宣言（REQ-008） |
| Language | TypeScript | 5.x | 型安全なパーサー実装 | `tsc --noEmit` を CI 必須 |
| Protocol | @modelcontextprotocol/sdk | 最新安定 | MCP 公式 SDK（stdio transport） | package-lock.json で固定 |
| YAML | js-yaml | 4.x | review ticket (RT-*.yml) パース | 同上 |
| Build | esbuild | 最新安定（dev） | 単一ファイルバンドル（dist コミット方式） | dist-parity CI（AC-010） |
| Test | node:test | Node 同梱 | 追加依存ゼロでユニット/統合テスト | 3 OS で実行（AC-006） |
| UI | N/A | — | UI なし | — |

## Component Tree

N/A — UI コンポーネントなし。モジュール構成は design.md「Architecture」が正。

## State Shape

N/A — クライアント状態なし。サーバーは無状態（起動時に root を固定するのみ、
REQ-007）。

## Routes and Components

N/A — ルーティングなし。tool / resource の一覧は design.md「API / Contract
Plan」および contracts スキーマが正。

## API Client Strategy

N/A — 本 feature は API の提供側。クライアント実装（Claude Code / Codex）は
スコープ外。応答契約は `contracts/sdd-forge-mcp-tools.v1.schema.json`。

## Code Splitting and Size Budget

N/A — Web バンドルなし。等価物として dist/index.js のサイズ上限を 1.5 MB
（バンドル後）とし、超過時は依存見直しを行う（レビュー時チェック）。

## Performance Budget

N/A — Web Vitals 対象外。ローカル応答性目標は infra-spec.md「Service Level
Objectives」（p95 <= 500 ms）が正。

## Empty, Loading, Error, and Success Behavior

N/A — UI 状態なし。エラー表現は design.md のエラーエンベロープ
（`cannot-parse` / `not-found` / `path-denied` 等）が正（AC-002）。

## Dependencies

| Dependency | Version | Purpose | Alternative | License / Supply-Chain Note |
|---|---|---|---|---|
| @modelcontextprotocol/sdk | 固定（lock） | MCP プロトコル実装 | 自前実装（却下: 保守コスト） | MIT。バンドル同梱 |
| js-yaml | 4.x 固定 | RT-*.yml パース | yaml（同等。js-yaml は依存ゼロで軽量） | MIT。バンドル同梱 |
| typescript / esbuild | dev のみ | 型検査 / バンドル | tsc 単体ビルド（却下: 依存同梱不可） | 配布物に含まれない |

## Testing

design.md「Test Strategy」が正。TEST-001〜TEST-014 を node:test で実装し、
フィクスチャは決定論（実 spec のスナップショット + 合成異常系）とする。

## Open Questions

- なし。
