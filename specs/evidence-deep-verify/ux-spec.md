# UX Specification: evidence-deep-verify

N/A — no change(GUI なし): 本 feature は read-only MCP ツール 1 個の追加であり、
画面・人間向け対話 UI を持たない。消費者は AI クライアント(Claude Code / Codex /
Cursor / VS Code Copilot)のみ。人間の接点は存在しない(installer 変更もなし)。

本節は MCP ツールの I/O(ツールとしての最小 UX)のみを記録する。

## MCP ツール I/O(最小 UX)

- ツール名: `evidence_deep_verify`
- 入力: `{ feature: string, taskId: string }`(既存 evidence 5 ツールと同一。自由文・
  コマンド・パス入力なし)。
- 出力: `evidenceDeepVerifyData` エンベロープ(design.md「API / Contract Plan」が正準)。
  クライアントは `verdict`(pass/fail)、`artifacts[].status`、`invariants`、`signature`、
  `failures[]` を構造化データとして受け取り、人間可読の要約はクライアント側が生成する。
- エラー時は既存エラーエンベロープ(`invalid-input` / `not-found` / `cannot-parse`)を返す。

## 対象ビュー / ナビゲーション / コンポーネント状態 / レスポンシブ / デザイントークン

N/A — no change(UI なし)。応答状態(ok / error エンベロープ)の正準定義は
`contracts/sdd-forge-mcp-tools.v1.schema.json`。

## Wireframe Attachments

None — manual visual refinement skipped
(No mockup provided — optional visualization skipped)

## Open Questions

- なし
