# Implementation Report: T-009

- Task ID: T-009
- Feature: sdd-forge-mcp
- Risk: high
- Required Workflow: tdd

## Target

MCP resources 5 種（`sdd://active-specs`、`sdd://spec/{feature}`、
`sdd://tasks/{feature}`、`sdd://review-tickets`、`sdd://quality-reports`）を
`McpServer` に登録する（design.md「Architecture」`resources.ts`、「API /
Contract Plan」）。各 resource は対応する core tool（T-004 実装済み、
`src/tools/core.ts`）と同一のロジックを再利用し、同一のエンベロープ JSON を
`application/json` で返す薄いビューとする。

## Summary

- `src/resources.ts`（新規）— `registerResources(server, root)` を実装:
  - `sdd://active-specs`（固定 URI）→ `listActiveSpecs(root)`
  - `sdd://spec/{feature}`（`ResourceTemplate`、`list: undefined`）→
    `getSpecStatus(root, feature)`
  - `sdd://tasks/{feature}`（`ResourceTemplate`、`list: undefined`）→
    `getTaskState(root, feature)`
  - `sdd://review-tickets`（固定 URI）→ `listReviewTicketsTool(root)`
  - `sdd://quality-reports`（固定 URI）→ `getQualityGateSummary(root)`
  - いずれも `tools/core.ts` の既存関数をそのまま呼び出すのみで、
    ロジックの再実装は一切行っていない。`feature` パラメータの形式検証
    （`^[A-Za-z0-9][A-Za-z0-9._-]*$`）は呼び出し先の tool 関数
    （`getSpecStatus`/`getTaskState` 内部の `validateFeature`）に委譲して
    おり、resources 層で重複したバリデーションは持たない——不正な
    feature は tool 呼び出しと同じ `invalid-input` エンベロープになる。
  - `ResourceTemplate` の `list` コールバックは、この2テンプレートに
    「動的に列挙可能な既知の feature 一覧」という概念がないため
    （feature の集合は `sdd://active-specs`/AGENTS.md 側にすでにある）
    `undefined` を明示的に渡した（SDK の型定義上 `list` キー自体は
    必須だが値は `undefined` を許容する）。
  - レスポンスは `{ contents: [{ uri, mimeType: "application/json", text:
    JSON.stringify(result) }] }` の単一エントリ。tool 側の
    `toCallToolResult`（`content[0].text` に envelope JSON を格納）と
    対になる形。
- `src/server.ts`（更新）— `buildServer` の末尾で
  `registerResources(server, root)` を呼ぶよう追加。8 tools の登録内容・
  順序は変更していない。

## Files Changed

- `mcp/sdd-forge-mcp/src/resources.ts` — resources 5 種の登録（新規）
- `mcp/sdd-forge-mcp/src/server.ts` — `registerResources(server, root)` 呼び出しを追加
- `mcp/sdd-forge-mcp/tests/resources/test-helpers.ts`（新規、`*.test.ts`
  以外の命名）— T-004 の `tests/core-tools/test-helpers.ts` が持つ
  `makeCoreToolsFixture`/`getEnvelopeValidator`/`parseEnvelope` を再輸出し、
  resource 読み取り専用の `parseResourceEnvelope`（`ReadResourceResult` の
  `contents[0].text` を JSON パース）を追加。フィクスチャ実装自体は
  一切複製していない。
- `mcp/sdd-forge-mcp/tests/resources/resources.test.ts` — AC-013 検証（新規、7件）

## Tests Added Or Updated

- `resources/list + resources/templates/list together expose all 5 sdd://
  resources` — SDK `Client.listResources()`（固定 URI 3件: active-specs /
  review-tickets / quality-reports）と `Client.listResourceTemplates()`
  （テンプレート2件: spec/{feature} / tasks/{feature}）を突合し、
  合計5件になることを assert。
- `sdd://active-specs matches list_active_specs exactly` /
  `sdd://spec/{feature} matches get_spec_status exactly` /
  `sdd://tasks/{feature} matches get_task_state exactly` /
  `sdd://review-tickets matches list_review_tickets exactly` /
  `sdd://quality-reports matches get_quality_gate_summary exactly` —
  同一フィクスチャ上で tool 呼び出しと resource 読み取りの両方を実行し、
  ajv でスキーマ検証した上で `assert.deepEqual` により envelope が
  完全一致することを検証（tool と resource の実装が同一関数を経由して
  いることの直接的な証跡）。`sdd://active-specs` の resource では
  `contents[0].mimeType === "application/json"` も確認。
- `sdd://tasks/{feature} surfaces invalid-input for a malformed feature,
  same as the tool` — `../escape` を feature に使い、tool 側
  （`get_task_state`）と resource 側（`sdd://tasks/..%2Fescape`）が両方とも
  `invalid-input` エンベロープになることを確認（AC-017 相当の resource 版）。

## Regression Tests Run

- `npx tsc --noEmit`: エラーゼロ
- `npm run build`（esbuild バンドル）: 成功、`dist/index.js` 再生成
- `npm test`（`node --test dist-test/tests/**/*.test.js`）:
  **118 tests / 118 pass / 0 fail**（既存111 + 新規 resources.test.ts 7件）
- Red/Green evidence:
  `specs/sdd-forge-mcp/verification/T-009-red.txt`（`src/server.ts` の
  `registerResources(server, root)` 呼び出し行のみを一時的にコメントアウト
  した状態で `npm test` を実行し、`tests/resources/resources.test.ts` の
  7件全てが MCP `-32601 Method not found`（resources/list・
  resources/templates/list・resources/read のいずれも未登録のため）で
  失敗し、既存111件は無傷で通過することを記録。呼び出し行を復元後、
  Green を取得）、
  `specs/sdd-forge-mcp/verification/T-009-green.txt`（`tsc --noEmit` /
  `npm run build` / `npm test` 118/118 pass のフル出力）。

## Specification Differences

- なし。タスク指示の5 resources・URI 形状・「tool と同一エンベロープを
  返す薄いビュー」という設計方針をそのまま実装した。

## Unresolved Items

- 「resources/list に5エントリ（テンプレート含む）」というタスク指示は、
  MCP プロトコル上は静的 resource（`resources/list`）とテンプレート
  （`resources/templates/list`）が別エンドポイントであるため、本実装・
  本テストでは両方を呼び出して合計5件であることを検証する形で解釈した
  （SDK の `McpServer.registerResource` の型定義上も、固定 URI と
  `ResourceTemplate` は明確に別種として扱われており、単一の
  `resources/list` 呼び出しに両方を混在させる標準的な手段は無い）。
- `next-command`（T-010）と evidence tools（T-005）には一切踏み込んで
  いない。

## Quality Gate Focus

- `resources.ts` が `feature` の形式検証を一切行わず tool 関数へ
  そのまま委譲している設計（`getSpecStatus`/`getTaskState` 内部の
  `validateFeature` に完全依存）が、「ロジックの重複実装をしない」という
  タスク指示と整合しているか、逆に resources 層で早期に弾かないことに
  よる副作用がないか（現状、tool 関数側の `validateFeature` は
  ファイルシステムに触れる前に検証しているため副作用はない）。
- `ResourceTemplate` の `list: undefined` が、将来 MCP クライアントが
  `resources/templates/list` の completion 機能（`complete` コールバック）
  を必要とした場合に拡張ポイントとして十分か。

## Working Notes

- 調査: `@modelcontextprotocol/sdk` の `server/mcp.d.ts` を確認し、
  `registerResource` が固定 URI 文字列と `ResourceTemplate` インスタンスの
  2オーバーロードを持つこと、`ResourceTemplate` のコンストラクタが
  `{ list: ListResourcesCallback | undefined }` を必須（値は undefined 可）
  で要求することを確認した。
- 調査: `resources/list` は静的 resource のみを返し、テンプレートは
  `resources/templates/list` という別リクエストで返ることを SDK の
  `Client` 型定義（`listResources` / `listResourceTemplates` の2メソッド）
  から確認し、テストの「5エントリ」検証をこの2メソッドの合計として設計した。
- 検証: `npm test` を、`server.ts` の resources 登録呼び出しをコメントアウト
  した状態（Red）と復元した状態（Green）の両方で実行し、既存111件の
  tool/parser/path-guard/readonly/root-immutable テストが Red 側でも
  全て無傷で通過することを確認した——resources 追加が既存 tool 登録や
  root 解決に副作用を与えていないことの直接的な証跡。

## Session Handoff

- **Current status**: T-009 完了。`npx tsc --noEmit` エラーゼロ、
  `npm run build` 成功、`npm test` 118/118 pass。Red/Green evidence と
  本レポートを保存済み。
- **Next action**: quality-gate による独立レビューと Done 判定。
- **Unresolved items**: 上記「Unresolved Items」参照
  （resources/list vs resources/templates/list の解釈、
  next-command/evidence tools は T-010/T-005 スコープ）。
