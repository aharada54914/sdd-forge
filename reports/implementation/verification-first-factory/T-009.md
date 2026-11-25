# T-009 MCP v2 の診断契約

Run ID: verification-first-factory-T-009-repair-20261126
Task Attempt Count: 2

## 修正と検証

- 修正前の配布バンドルに対する stdio の `tools/call` では `sdd_project_overview` の `doctor.v2_2_gates` が欠落し、追加テストが `Cannot read properties of undefined (reading 'agent_lint')` で失敗した。
- `contracts/sdd-mcp.v2.schema.json` に任意の診断フィールドと4ゲートそれぞれの型を定義した。`mcp/sdd-forge-mcp/src/tools/v2.ts` が読み取り専用コアの正規化済み値を返す。配布バンドルを再生成した。
- `npm --prefix mcp/sdd-forge-mcp run typecheck` と `run build` は成功。`SDD_REQUIRE_AJV=1 node --test tests/v2-mcp-server.test.mjs` は14件成功、スキップ0件。実 stdio の4ツール、明示設定した strict lint の伝播、Ajv による応答契約、オプトイン導入を検証した。`tests/v2-wave3-integration.test.mjs` で OTel の本文収集が既定で無効であることと CLI 診断出力を検証した。

## AC-013 の既存不合格

`npm --prefix mcp/sdd-forge-mcp test` を変更後の作業ツリー（HEAD `fc166bd1a8b8303531c0445ff78965897ea59c61`）と独立 worktree の merge-base `484cbe7aef828488ee49fa5d92569917e74c5891` で実行した。両方とも319件中224件成功、95件失敗、スキップ0件。実行時間と worktree の絶対パスを除いて失敗テスト名95件が一致した。

既存失敗には ADR-0052 で廃止した `evidence_*` RPC を呼ぶテストと、コンパイル後のテストから `contracts/cross-critique.v1.schema.json` の解決に失敗するケースが含まれる。今回追加した v2 契約は独立して合格したが、AC-013 のパッケージ全件成功条件は未達である。
