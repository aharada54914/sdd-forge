# UX Specification: local-env-mcp

N/A — no change: 本 feature は GUI・画面・人間向け対話 UI を持たない read-only
MCP サーバーと installer 拡張であり、消費者は AI クライアント(Claude Code /
Codex / Cursor / VS Code Copilot)のみ。人間の接点は installer CLI の
テキスト出力(登録成功 / スキップ通知 / エラー通知。REQ-008 / REQ-009 /
AC-010 / AC-011 / AC-015 で検証)に限られ、ビュー・ナビゲーション・
コンポーネント状態・アクセシビリティ要件を持つ UI は存在しない。

- 対象ビュー / ナビゲーション / コンポーネント状態 / レスポンシブ / デザイン
  トークン: N/A — no change(UI なし)
- installer CLI メッセージ要件(登録スキップ・壊れ JSON エラーの平易な文言)は
  infra-spec.md「Observability」および acceptance-tests.md AC-010 / AC-011 /
  AC-015 が正準。

## Wireframe Attachments

None — manual visual refinement skipped
(No mockup provided — optional visualization skipped)

## Open Questions

- なし
