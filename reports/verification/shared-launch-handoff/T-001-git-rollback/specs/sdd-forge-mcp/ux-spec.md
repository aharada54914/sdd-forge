# UX Specification: sdd-forge-mcp

N/A — no change: 本 feature は GUI・画面・人間向け対話 UI を持たない
read-only MCP サーバーであり、消費者は AI クライアント（Claude Code / Codex /
Cursor / VS Code）のみ。人間が直接触れる接点は installer の CLI 出力と
stderr ログに限られる。応答フォーマットの正は design.md「API / Contract Plan」
および `contracts/sdd-forge-mcp-tools.v1.schema.json` が持つ。

## Scope and User Journeys

- Primary user: AI クライアント（プログラム）。人間のジャーニーなし。
- Entry point: MCP クライアント設定（installer が登録、AC-007）。
- Success outcome: tool 呼び出しが構造化 JSON を返す（AC-005, AC-013）。
- Excluded journey: 人間向け画面・ダッシュボードは提供しない（Non-goals）。

## Target Views

N/A — ビューなし。

## Component States

N/A — UI コンポーネントなし。等価概念として tool 応答の状態は
`ok` / `error(code)` エンベロープで表現される（design.md 参照。エラー文言は
人間可読・原因特定可能であること — AC-002 の cannot-parse 詳細）。

## Interaction Sequence

N/A — 対話 UI なし。プロトコルシーケンスは design.md Architecture 参照。

## Wireframe Attachments

| View | Local Attachment | Source | Reviewed At | Notes |
|---|---|---|---|---|
| — | none | — | — | No mockup provided — optional visualization skipped |

## Navigation Map

N/A — ナビゲーションなし。

## Accessibility

N/A — 画面なしのため WCAG 対象外。CLI/ログ出力は既存 installer の出力規約
（プレーンテキスト、色依存なし）に従う。

## Responsive Behavior

N/A — 画面なし。

## Design Tokens

N/A — 画面なし。

## Open Questions

- なし。
