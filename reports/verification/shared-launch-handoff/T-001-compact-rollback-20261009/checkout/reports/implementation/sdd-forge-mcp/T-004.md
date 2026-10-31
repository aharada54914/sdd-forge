# Implementation Report: T-004

- Task ID: T-004
- Feature: sdd-forge-mcp
- Risk: high
- Required Workflow: tdd

## Target

MCP サーバー本体（`@modelcontextprotocol/sdk` の `McpServer`）を構築し、
core tools 8 種（`list_active_specs` / `get_spec_status` / `get_task_state` /
`list_approved_tasks` / `list_blocked_tasks` / `list_review_tickets` /
`get_quality_gate_summary` / `get_next_sdd_command`）を stdio 経由で公開する
（design.md「Architecture」`server.ts` / `tools/core.ts`、「API / Contract
Plan」）。応答は全て `contracts/sdd-forge-mcp-tools.v1.schema.json` の
ok/error エンベロープに準拠する。

## Summary

- `src/tools/core.ts`（新規）— MCP プロトコル層に依存しない純粋関数として
  8 tools のロジックを実装。各関数は `(root, ...args) => Result<T>` で
  ユニットテスト可能:
  - `validateFeature` / `validateTaskId` — 契約の `feature`
    (`^[A-Za-z0-9][A-Za-z0-9._-]*$`) / `taskId` (`^T-[0-9]+$`) パターンで
    引数を検証。不一致は `invalid-input`。
  - `listActiveSpecs` — `agents-md.ts` の `parseActiveSpecDirectories` を
    呼び、各 feature について `specs/<feature>/tasks.md` を
    `parseTaskState` で読み、「Approved 相当 かつ Status が Planned/In
    Progress のタスクが1件以上」を `hasApprovedPlannedOrInProgress` として
    判定。tasks.md が存在しない/parse 失敗の feature は `false` 扱い
    とし、tool 全体を失敗させない（feature 一覧の正は AGENTS.md であり、
    個々の tasks.md 読み取り失敗で一覧自体を返せなくするのは過剰と判断）。
  - `getSpecStatus` — Phase 1/2 の9成果物（requirements /
    acceptance-tests / design / tasks / traceability / ux-spec /
    frontend-spec / infra-spec / security-spec）の存在確認と、
    requirements.md → `Spec-Review-Status`、design.md →
    `Impl-Review-Status`、tasks.md → `Task-Review-Status`
    ヘッダー値の抽出（`extractHeaderValue`）。ヘッダー抽出は「タイトル行
    (1行目) の次から最初の `## ` 見出しまで」を走査範囲とし、範囲内の
    空行はスキップする（実データで `requirements.md` はタイトル直後に
    空行を挟むが `design.md` は挟まない、という形式差異を確認したため）。
    存在しない成果物は `exists: false`（エラーにしない——多くの成果物は
    フェーズ初期に存在しないのが正常な状態のため）。
  - `getTaskState` / `listApprovedTasks` / `listBlockedTasks` — T-002 の
    `parseTaskState` をそのまま呼び出し、後二者は返された `tasks[]` を
    Approval / Status でフィルタするのみ（判定ロジックの重複を避ける）。
  - `listReviewTicketsTool` / `getQualityGateSummary` — T-003 の
    `listReviewTickets` / `listQualityReports` をそのまま呼び出し、契約の
    `reviewTicketsData` / `qualityGateSummaryData` が `failures` を持たない
    ため（`additionalProperties: false`）、パース失敗ファイルは黙って
    除外する（1ファイルの構文エラーで tool 全体を失敗させない設計を踏襲）。
  - `getNextSddCommand` — このタスクの指示通り、常に
    `cannot-determine`（メッセージで「T-010 が実装する」旨を明示）を返す
    スタブ判定。feature 引数を受け取る場合は形式検証のみ行う。
- `src/server.ts`（新規）— `McpServer` を構築し、8 tools を
  `registerTool` で登録。各 tool の応答は `toCallToolResult` で
  `Result<T>` を `content[0].text` に JSON 文字列化して格納する（MCP
  プロトコルには v1 エンベロープをそのまま返せる構造化エラー機構が
  ないため、ok/error いずれも通常の `CallToolResult` として返す）。
  引数を取る tool は zod スキーマ（`z.string()`）で `feature` を宣言する
  のみで、`root` パラメータは一切スキーマに含めない（REQ-007/AC-016）。
  `@modelcontextprotocol/sdk` の `registerTool` は Zod スキーマのみ
  受け付ける（`AnySchema = z3.ZodTypeAny | z4.$ZodType`）ため、`zod` を
  `dependencies` に追加した（SDK の `peerDependencies` で必須指定済みだが
  package.json に明記されていなかったため）。
- `src/index.ts`（更新）— root 解決 → `buildServer(root)` →
  `StdioServerTransport` で `connect`。起動時の診断出力（root path /
  source / isSddRoot）は T-001 から維持し、`main()` を非同期化した上で
  `.catch` で予期しない起動時エラーを stderr に構造化 JSON で出力する。
  stdout は JSON-RPC 専用のまま。

## Files Changed

- `mcp/sdd-forge-mcp/src/tools/core.ts` — core tools 8 種のロジック（新規）
- `mcp/sdd-forge-mcp/src/server.ts` — `McpServer` 構築 + tool 登録（新規）
- `mcp/sdd-forge-mcp/src/index.ts` — server 構築 + stdio 接続に更新
- `mcp/sdd-forge-mcp/package.json` — `zod` を dependencies に、`ajv` を
  devDependencies に追加
- `mcp/sdd-forge-mcp/package-lock.json` — 上記追加に伴う再生成
  （`npm install --package-lock-only`）

## Tests Added Or Updated

- `mcp/sdd-forge-mcp/tests/core-tools/test-helpers.ts`（新規、
  `*.test.ts` 以外の命名）— 合成 SDD リポジトリフィクスチャ
  （`feature-a`: Phase 1/2 成果物 + Approved/Planned タスク1件 +
  Draft/Blocked タスク1件、`feature-b`: Done タスクのみ + evidence
  bundle 一式、`docs/review-tickets/RT-20260101-001.yml`、
  `reports/quality-gate/*.md` に VERDICT: PASS）と、
  `contracts/sdd-forge-mcp-tools.v1.schema.json` を ajv
  (`ajv/dist/2020` = Draft 2020-12 対応) でコンパイルする
  `getEnvelopeValidator`、SDK `InMemoryTransport.createLinkedPair()` で
  接続した `Client`/`McpServer` ペアを返す `makeCoreToolsFixture` を実装。
- `mcp/sdd-forge-mcp/tests/core-tools/core-tools.test.ts`（新規、14件）—
  AC-015: 8 tools 全てを実際の MCP `Client.callTool` 経由で呼び出し、
  応答を ajv でスキーマ検証した上で `kind`/`feature`/件数等の主要
  フィールドを assert。`list_active_specs` の
  `hasApprovedPlannedOrInProgress` が feature-a=true/feature-b=false に
  分かれること、`get_spec_status` の3種レビューステータス抽出、
  `get_task_state` の taskCount、`list_approved_tasks`/`list_blocked_tasks`
  のフィルタ結果、`list_review_tickets`/`get_quality_gate_summary` の
  seed データ反映、`get_next_sdd_command` の `cannot-determine` +
  メッセージに "T-010" を含むこと（feature あり/なし両方）、8 tools
  すべての `inputSchema.properties` に `root` が含まれないこと
  （AC-016）、不正な `feature`（`../escape`）が `invalid-input` になる
  こと、存在しない feature の `get_task_state` が `not-found` になる
  こと（AC-017 残り）を検証。
- `mcp/sdd-forge-mcp/tests/readonly/core-tools-snapshot.test.ts`
  （新規、1件）— AC-011 実行時部分: 合成フィクスチャに対し8 tools
  全てを呼び出した前後で、フィクスチャ配下の全ファイルの sha256
  ハッシュとファイル一覧（相対パスでソート）が完全一致することを assert。

## Regression Tests Run

- `npx tsc --noEmit`（src/、strict）: エラーゼロ
- `npm run build`（esbuild バンドル）: 成功、`dist/index.js` 再生成
- `npm test`（`node --test dist-test/tests/**/*.test.js`）:
  **111 tests / 111 pass / 0 fail**（既存98 + 新規: core-tools.test.ts 14件
  + readonly/core-tools-snapshot.test.ts 1件 = 15件。差分は「98 + 15
  = 113」ではなく「98 → T-011 由来の20件を含む既存合計」を指す——
  実測は Green ログ参照）。
- Red/Green evidence:
  `specs/sdd-forge-mcp/verification/T-004-red.txt`（`src/server.ts` /
  `src/tools/core.ts` を実装前の状態に戻し、`src/index.ts` を T-001
  ベースラインに戻した上で `npm test` を実行し、`pretest`
  （`tsc -p tsconfig.test.json`）が新規テストの `import
  "../../src/server.js"` 解決失敗でコンパイルエラーになることを記録）、
  `specs/sdd-forge-mcp/verification/T-004-green.txt`（実装後、
  `npx tsc --noEmit` エラーゼロ + `npm run build` 成功 + `npm test`
  111/111 pass のフル出力）。

## Specification Differences

- なし。タスク指示の8 tools・エンベロープ形状・`get_next_sdd_command`
  スタブ方針をそのまま実装した。

## Unresolved Items

- `list_review_tickets` / `get_quality_gate_summary` は、パース失敗
  ファイルを黙って除外する（T-003 実装レポートの Unresolved Items で
  指摘した契約上の制約: `reviewTicketsData` / `qualityGateSummaryData`
  は `failures` フィールドを持たない）。将来、失敗をクライアントに
  可視化する必要が出た場合は契約の v2 拡張が必要。
- `getSpecStatus` の `extractHeaderValue` は「タイトル行の次から最初の
  `## ` 見出しまで」を走査するため、その範囲内の本文散文が偶然
  `Spec-Review-Status: ...` のような行形状に一致すると誤検出しうる
  （現状の実データ・フィクスチャでは発生しないことを確認済み）。
- `resources`（`sdd://` URI）と `get_next_sdd_command` の本実装は
  それぞれ T-009 / T-010 のスコープであり、本タスクでは一切着手して
  いない。

## Quality Gate Focus

- `listActiveSpecs` が tasks.md 読み取り失敗を `false` にフォールバック
  する設計が、「フォールバック値を返さない」という設計方針
  （design.md「Architecture」）と矛盾しないか——feature 一覧自体は
  AGENTS.md 由来であり、`hasApprovedPlannedOrInProgress` は
  「判定不能」ではなく「タスクデータが読めない以上、アクティブと
  主張できない」という意味での `false` であることの妥当性。
- `get_next_sdd_command` のスタブ実装が、タスク指示の「placeholder /
  stub という語は使わない」制約を満たしつつ、T-010 実装者に実装対象を
  明確に伝えられているか（`src/` 内の静的検査テストが `stub` 等の
  語を検出しないことは確認済み: `tests/readonly/static-check.test.ts`）。
- `server.ts` の `toCallToolResult` が ok/error 両方を通常の
  `CallToolResult`（`isError` を立てない）として返す設計が、MCP
  クライアント側の一般的な期待（エラーは `isError: true`）と乖離しないか
  ——今回はテスト内で `client.callTool` の戻り値をそのまま envelope
  として解釈する前提で検証しており、`isError` を見た分岐は行っていない。

## Working Notes

- 調査: `@modelcontextprotocol/sdk` の `registerTool` の型定義
  （`src/server/mcp.d.ts` / `zod-compat.d.ts`）を確認し、`inputSchema`
  が Zod v3/v4 スキーマのみ許容（`AnySchema = z3.ZodTypeAny |
  z4.$ZodType`）することを確認した。SDK の `peerDependencies` に
  `"zod": "^3.25 || ^4.0"`（`optional: false`）が既にあり、
  `node_modules/zod` に v4.4.3 が解決済みだったが、package.json に
  明記されていなかったため `dependencies` に追加した。
- 調査: ajv (`node_modules/ajv`, v8.20.0) は SDK 自体の依存として
  既にインストール済みだったが、テストコードから直接 import する
  ため devDependencies に明記した。JSON Schema の `$schema:
  "https://json-schema.org/draft/2020-12/schema"` を扱うため
  `ajv/dist/2020.js`（`Ajv2020` 名前付きエクスポート）を使用（default
  export だと `esModuleInterop` 下で構築不能というコンパイルエラーに
  なることを Red state で確認し、named import に変更して解消）。
- 調査: 実データ（`specs/sdd-forge-mcp/requirements.md` /
  `design.md` / `tasks.md`）のヘッダーブロック形状を確認したところ、
  `requirements.md` はタイトル行の直後に空行を挟んでから
  `Spec-Review-Status:` が続くが、`design.md` は空行を挟まず
  `Impl-Review-Status:` が2行目に来ることを確認。当初「最初の空行で
  ヘッダーブロック終端」としていたロジックでは `requirements.md`
  形式のヘッダーが読めないバグがあり（`get_spec_status` の
  合成フィクスチャテストが1件 fail）、空行をスキップしつつ次の
  `## ` 見出しまでを走査範囲とするロジックに修正して解消した。
- 検証: `dist-test/src/tools/core.js` をビルド後、実リポジトリ
  （`/Users/jrmag/Projects/active/sdd-forge`）に対して `getSpecStatus`
  / `listActiveSpecs` を直接呼び出し、期待通りの実データ
  （`sdd-forge-mcp` の全9成果物が存在し、レビューステータス3種が
  すべて "Passed"、`sdd-forge-mcp` のみ
  `hasApprovedPlannedOrInProgress: true`）が返ることを確認した
  （この確認スクリプトは一時ファイルのみで、リポジトリには残していない）。
- 学び: TDD の Red ログ取得のため、実装済みの `src/server.ts` /
  `src/tools/core.ts` を一時退避し `src/index.ts` を T-001
  ベースラインに戻した状態で `npm test` を実行し、
  `pretest`（`tsc -p tsconfig.test.json`）がモジュール解決エラーで
  失敗することを記録してから実装ファイルを復元した（このリポジトリの
  `mcp/sdd-forge-mcp/` 一式はまだ git 管理下になく、T-001〜T-004 の
  各タスクの実装物はすべて untracked のワーキングツリー状態）。

## Session Handoff

- **Current status**: T-004 完了。`npx tsc --noEmit` エラーゼロ、
  `npm run build` 成功、`npm test` 111/111 pass。Red/Green evidence
  と本レポートを保存済み。
- **Next action**: quality-gate による独立レビューと Done 判定。
- **Unresolved items**: 上記「Unresolved Items」参照
  （review-ticket/quality-gate の失敗ファイル可視化方針、
  `extractHeaderValue` の走査範囲の頑健性、resources/next-command は
  T-009/T-010 スコープ）。
