# ADR-0005 Cursor / VS Code への MCP 登録は installer の冪等 JSON upsert で行う

## Status

Proposed(人間承認待ち)

## Context

Issue #64 は sdd-forge-mcp(+ local-env-mcp)を Cursor と VS Code(Copilot
MCP)へ登録する installer 拡張を要求する。既存 installer は Claude Code
(`claude mcp add` CLI)と Codex(config.toml のマーカー区切りブロック)に
対応済み。Cursor / VS Code は CLI の普及状況が安定せず、設定は JSON ファイル
(Cursor: `~/.cursor/mcp.json` の `mcpServers`、VS Code: ユーザープロファイル
`mcp.json` の `servers`)が正準となっている。JSON はコメント不可のため Codex 式
マーカーブロックが使えず、別の冪等化戦略が必要。

## Decision

1. Cursor / VS Code への登録は、設定 JSON への **キー単位の冪等 upsert** で行う
   (`mcpServers.<name>` / `servers.<name>` を installer 管理キーとして所有し、
   他エントリには触れない)。
2. JSON の読取・マージ・書出しは Node.js ワンライナー(`node -e`)で行う。
   MCP 配置は Node >= 20 ゲート(MCP_NODE_OK)通過時のみ実行されるため、
   登録時の Node 利用は追加要件にならない。
3. フェイルセーフ: 設定ファイルが壊れた JSON の場合は**上書きせず**エラー通知
   して該当クライアントの登録のみ中断する。クライアント設定ディレクトリが
   存在しない場合は未導入とみなしスキップ通知する(ディレクトリを新規作成
   しない)。
4. uninstall は installer 管理名(sdd-forge-mcp / local-env-mcp)のキーのみ
   削除し、ユーザー定義エントリを保持する。
5. 正確な設定パス・スキーマは実装タスク冒頭で各公式ドキュメントと突合して確定
   する(specs/local-env-mcp/design.md OQ-001)。

## Consequences

- ユーザーが同名キーを手動編集していた場合、installer 再実行で installer 管理の
  内容に上書きされる(管理キーの所有権は installer にあると文書化する)。
- Cursor / VS Code の設定仕様変更に追従する保守コストが生じる。手動登録手順を
  USERGUIDE に併記し、自動登録失敗時の代替経路を確保する。
- Codex(TOML マーカー)と方式が二本立てになるが、各クライアントの正準形式に
  合わせる方が安全と判断。
