# Implementation Report: T-010

- Task ID: T-010
- Feature: sdd-forge-mcp
- Risk: high
- Required Workflow: tdd

## Target

`get_next_sdd_command` の状態 → 次コマンド決定論マッピングを実装し
（design.md「Architecture」`next-command.ts`、「API / Contract Plan」、
REQ-011）、`src/tools/core.ts` の暫定実装（常に `cannot-determine`）を
置換する。加えて MCP Inspector CLI による smoke テスト（AC-005）を追加する。

## Summary

- `src/next-command.ts`（新規）— `getNextSddCommand(root, feature?)`:
  - `feature` 指定時、AGENTS.md の Required Workflow 8ステップの順に
    `specs/<feature>/` のアーティファクトを走査する
    `nextCommandForFeature`:
    1. `requirements.md` が読めない（`not-found`）→
       `phase1-not-started` / `/sdd-bootstrap:bootstrap feature <feature>`
    2. `Spec-Review-Status` が `Passed` でない → `spec-review` /
       `/sdd-review-loop:spec-review-loop --feature <feature>`
    3. `Spec-Review-Status: Passed` なのに `design.md` が読めない →
       `cannot-determine`（未知の組み合わせとして推測しない）
    4. `Impl-Review-Status` が `Passed` でない → `impl-review` /
       `/sdd-review-loop:impl-review-loop --feature <feature>`
    5. `tasks.md` が読めない（`not-found`）→ `phase2-not-started` /
       `/sdd-bootstrap:bootstrap feature`（Phase 2）
    6. `Task-Review-Status` が `Passed` でない → `task-review` /
       `/sdd-review-loop:task-review-loop --feature <feature>`
    7. `parseTaskState`（T-002 の状態機械パーサー、シェル等価）で
       `verdict: fail` → `cannot-determine`（failures を message に含める）
    8. `phaseFromTasks` で `verdict: pass` のタスク一覧を判定
       （Blockers 章参照）
  - `phaseFromTasks`（tasks.md 判定の中核）:
    - `Status: Blocked` のタスクが1件でもあれば、他に
      Approved+Planned/In Progress のタスクがあっても
      **最優先で** `phase: "blocked"` / `nextCommand: "human: resolve
      blockers"` を返す（下記「設計判断」参照）。
    - Approved-shaped タスクがゼロ（全 Draft）→ `approval-gate` /
      `"human: approve tasks in tasks.md"`
    - Approved タスクに Planned または In Progress が1件でもあれば →
      `implementation` / `/sdd-ship:ship specs/<feature>/tasks.md`
    - 全 Approved タスクが `Implementation Complete` → `quality-gate` /
      `/sdd-quality-loop:quality-gate specs/<feature>/tasks.md`
    - 全 Approved タスクが `Done` → `done` / `"feature complete"`
    - どれにも該当しない組み合わせ（例: 一部が Implementation
      Complete・一部が Done で Planned/In Progress/Blocked が無い）→
      `cannot-determine`
  - `feature` 未指定時、`autoSelectFeature` が `sdd-ship:run` の
    ゼロ引数 auto-selection 規則（`plugins/sdd-ship/skills/run/SKILL.md`
    「Step 1 — Target Selection」）を再現: AGENTS.md の Active Spec
    Directories を走査し、tasks.md に Approved+Planned/In-Progress の
    タスクを持つ feature を集計。ちょうど1件ならその feature で
    `nextCommandForFeature` を実行。0件 → `cannot-determine`
    （`rule: auto-select-none-active`）。複数件 →
    `cannot-determine`（`rule: auto-select-multiple-active`、
    候補一覧を `details.candidates` に含める）。
  - **`guardedRead` の失敗理由を区別**: 「アーティファクトが単に
    存在しない」（`not-found`）場合のみ `phase1-not-started` 等の
    フェーズと解釈し、それ以外のエラーコード（`path-denied` /
    `invalid-input` / `too-large` 等 — 例えば feature に `../escape` の
    ような path traversal を仕込んだ場合）はそのまま呼び出し元へ
    伝播する。実装当初はこの区別をせず、`guardedRead` の失敗を
    一律「存在しない」として扱っていたため、不正な feature 名でも
    誤って `phase1-not-started`（`ok: true`）を返してしまうバグが
    テストで発覚し修正した（下記 Working Notes 参照）。
- `src/parsers/spec-header.ts`（新規）— `extractHeaderValue` を
  `src/tools/core.ts` から抽出した共有モジュール。`get_spec_status`
  （既存）と `next-command.ts`（今回）の両方が同一ロジックで
  `<Key>: <value>` ヘッダーを読むようにし、判定ロジックの重複実装を
  避けた（ロジック自体は無変更、移動のみ）。
- `src/tools/core.ts`（更新）— `getNextSddCommand` の暫定実装
  （常に `cannot-determine`）を `next-command.ts` の呼び出しに
  置換。`NextCommandData` 型は `next-command.ts` からの re-export に
  変更（design.md のアーキテクチャ通り、next-command.ts を正とする）。
  tool の入出力スキーマ（`server.ts` の `registerTool` 呼び出し）は
  無変更。`extractHeaderValue` のローカル定義を削除し
  `parsers/spec-header.ts` からの import に置換。
- `src/server.ts`（更新）— `get_next_sdd_command` の description を
  「T-010 は cannot-determine を返す暫定実装」という古い文言から、
  実装済みの挙動（Required Workflow ゲートを辿る／feature 省略時は
  auto-select する）を説明する文言に更新。tool 名・入力スキーマは
  無変更。
- `tests/smoke/inspector-smoke.test.ts`（新規、AC-005）— 実際の
  `dist/index.js` を `npx @modelcontextprotocol/inspector --cli`
  経由（本物の stdio JSON-RPC、SDK の InMemoryTransport ではない）で
  起動し、`tools/list`（8 tools 名の一致）、`resources/list` +
  `resources/templates/list`（3 static + 2 template = 5）、
  `tools/call --tool-name list_active_specs`（実リポジトリを
  `--root` で指定し、envelope 形状と `sdd-forge-mcp` を含むことを
  確認）を検証。`before()` フックで `dist/index.js` の存在を確認し、
  無ければ `npm run build` を実行してから進める（スキップしない）。
  ネットワークアクセスは発生しない（ローカル stdio サブプロセスのみ）。
- `package.json` / `package-lock.json`（更新）— `@modelcontextprotocol/
  inspector` を devDependency にバージョン固定（`0.22.0`、キャレット
  無し）で追加。

## Files Changed

- `mcp/sdd-forge-mcp/src/next-command.ts` — 決定論マッピング本体（新規）
- `mcp/sdd-forge-mcp/src/parsers/spec-header.ts` — `extractHeaderValue`
  共有モジュール（新規、core.ts から抽出）
- `mcp/sdd-forge-mcp/src/tools/core.ts` — `getNextSddCommand` を
  next-command.ts 呼び出しに置換、`extractHeaderValue` を
  spec-header.ts からの import に変更
- `mcp/sdd-forge-mcp/src/server.ts` — `get_next_sdd_command` の
  description 更新（実装済みの挙動を反映）
- `mcp/sdd-forge-mcp/tests/next-command/test-helpers.ts`（新規、
  `*.test.ts` 以外の命名）— AGENTS.md / requirements.md / design.md /
  tasks.md フィクスチャビルダーと ajv envelope バリデータ
- `mcp/sdd-forge-mcp/tests/next-command/next-command.test.ts`（新規、
  18件）— フェーズ網羅 + auto-select + 実リポジトリ実行
- `mcp/sdd-forge-mcp/tests/smoke/inspector-smoke.test.ts`（新規、3件）
  — Inspector CLI smoke
- `mcp/sdd-forge-mcp/tests/core-tools/core-tools.test.ts`（更新）—
  暫定実装専用だった2テスト（"schema-valid cannot-determine stub"）を
  実装後の期待値（feature-a は Blocked タスクを含むため `blocked`
  フェーズになる）に更新
- `mcp/sdd-forge-mcp/package.json` / `package-lock.json` —
  `@modelcontextprotocol/inspector@0.22.0`（devDependency）を追加

## Tests Added Or Updated

`tests/next-command/next-command.test.ts`（18件、design.md の
フェーズ網羅指示に対応）:

| # | フェーズ | 検証内容 |
|---|---|---|
| 1 | phase1-not-started | requirements.md 不在 |
| 2 | spec-review | Spec-Review-Status が Passed 以外 |
| 3 | spec-review | Spec-Review-Status ヘッダー自体が無い |
| 4 | impl-review | Impl-Review-Status が Passed 以外 |
| 5 | cannot-determine | Spec-Review-Status: Passed なのに design.md 不在 |
| 6 | phase2-not-started | design.md: Passed なのに tasks.md 不在 |
| 7 | task-review | Task-Review-Status が Passed 以外 |
| 8 | approval-gate | 全タスクが Draft |
| 9 | implementation | Approved+Planned |
| 10 | implementation | Approved+In Progress |
| 11 | quality-gate | 全 Approved が Implementation Complete |
| 12 | done | 全 Approved が Done（evidence bundle 完備） |
| 13 | blocked | Blocked タスクが Planned タスクより優先 |
| 14 | cannot-determine | feature に `../escape`（path-denied がそのまま伝播することを確認） |
| 15 | auto-select 1件 | Active Spec 2件中1件のみ active → 解決される |
| 16 | auto-select 0件 | 全 feature が Done のみ → cannot-determine（none-active） |
| 17 | auto-select 複数件 | 2 feature が active → cannot-determine（multiple-active、候補列挙） |
| 18 | 実リポジトリ | `feature=sdd-forge-mcp` → `implementation`（`/sdd-ship:ship specs/sdd-forge-mcp/tasks.md`）、ajv スキーマ検証込み |

`tests/smoke/inspector-smoke.test.ts`（3件、AC-005）:

- `tools/list` が8 tool 名と完全一致
- `resources/list` + `resources/templates/list` が 3 static + 2
  template = 5 件
- `tools/call --tool-name list_active_specs`（`--root` に実リポジトリを
  指定）が `ok: true` の envelope を返し、`specs` に
  `sdd-forge-mcp` を含む

`tests/core-tools/core-tools.test.ts`（既存2件を更新）:

- `get_next_sdd_command: feature-a has a Blocked task -> blocked takes
  priority` — フィクスチャの feature-a（T-002 が Draft+Blocked）に
  対する呼び出しが `phase: "blocked"` になることを確認
- `get_next_sdd_command: no feature argument auto-selects feature-a` —
  feature 省略時も同じ結果になることを確認

## Regression Tests Run

- `npx tsc --noEmit`: エラーゼロ
- `npm run build`（esbuild バンドル、`dist/index.js` を一旦削除して
  再生成することも確認）: 成功
- `npm test`（`node --test dist-test/tests/**/*.test.js`）:
  **139 tests / 139 pass / 0 fail**（既存118 + next-command 新規18 +
  smoke 新規3。core-tools の2件は既存カウント内での内容更新）
- Red/Green evidence:
  `specs/sdd-forge-mcp/verification/T-010-red.txt`（`src/
  next-command.ts` を一時的に「常に cannot-determine を返す
  プレースホルダー」に差し替えた状態で
  `tests/next-command/*.test.js` + `tests/core-tools/*.test.js` を
  実行し、30件中19件が期待通り失敗することを記録。実装を復元後、
  同じ30件が全通過することを確認）、
  `specs/sdd-forge-mcp/verification/T-010-green.txt`（`tsc --noEmit` /
  `npm run build` / `npm test` 139/139 pass のフル出力、Inspector
  smoke 3件を含む）。

## Specification Differences

- **Blocked の優先順位**: タスク指示の記載順では「Blocked タスクあり」
  は末尾近くに書かれているが、実装では「Approved+Planned/In Progress
  のタスクがあっても、Blocked タスクが1件でもあれば最優先で
  `phase: "blocked"` を返す」という順序にした。根拠は
  `plugins/sdd-ship/skills/run/SKILL.md`（"Do not proceed to other
  tasks while any task is Blocked."）— Blocked タスクが存在する限り
  `sdd-ship:run` 自体が他タスクへ進まない設計であるため、次に取るべき
  行動として最も緊急性が高いのは Blocked 解消であるという判断。
  quality-gate/reviewer に確認いただきたい判断ポイント。
- **design.md 不在時の扱い**: タスク指示に明記の無い「Spec-Review-
  Status: Passed だが design.md が読めない」という組み合わせは、
  存在しないはずの状態として `cannot-determine` にした（推測しない
  という設計原則を優先）。
- **`nextCommandForFeature` の異常系伝播**: タスク指示には明記が
  無かったが、`guardedRead` の失敗理由が `not-found` 以外（
  `path-denied`/`invalid-input`/`too-large` 等）の場合は、
  「アーティファクトが無い」という肯定的なフェーズ判定をせず、
  そのままエラーとして呼び出し元に伝播するようにした。当初実装は
  この区別が無く、`../escape` のような不正な feature 名でも
  `phase1-not-started`（`ok: true`）という誤った回答を返すバグが
  TDD の過程で発覚したため修正した。

## Unresolved Items

- 一部 Approved タスクが Implementation Complete、一部が Done という
  組み合わせ（Planned/In Progress/Blocked が皆無）は `cannot-determine`
  としているが、この状態が実運用でどの程度発生しうるか（例えば
  quality-gate がタスクを1つずつ Done にしていく過程で一時的に
  この状態になりうる）は未検証。必要であれば「一部 Done・残りは
  Implementation Complete → quality-gate を継続」という追加フェーズを
  design レビューで検討されたい。
- Inspector smoke テストは `npx @modelcontextprotocol/inspector` の
  初回実行時に npm のパッケージ解決（ローカル node_modules 参照）が
  発生するため、初回のみ数秒〜十数秒かかる（2回目以降はキャッシュされ
  高速）。CI 環境での実行時間は未計測。
- evidence tools（T-005）には一切踏み込んでいない。

## Quality Gate Focus

- `phaseFromTasks` の判定順序（Blocked 最優先 → approval-gate →
  implementation → quality-gate → done → cannot-determine）が
  design.md の意図と一致しているか、特に Blocked の優先順位付けの
  妥当性。
- `guardedRead` のエラーコード区別（`not-found` のみを「フェーズ」と
  解釈し、それ以外は伝播）が、他の呼び出し元（`get_spec_status` 等）
  との一貫性を保っているか。
- Inspector smoke テストが `dist/index.js` 不在時に自動 build する
  設計（スキップしない）が CI のタイムアウト設定と両立するか。

## Working Notes

- 調査: `plugins/sdd-ship/skills/run/SKILL.md` の「Step 1 — Target
  Selection」を読み、feature 未指定時の auto-selection 規則
  （ちょうど1件なら自動選択、0件/複数件は停止してメッセージ表示）を
  確認。`next-command.ts` の `autoSelectFeature` はこの規則をそのまま
  再現し、停止時のメッセージ相当を `cannot-determine` の `message`/
  `details.rule` にマッピングした。
- 調査: `AGENTS.md`（リポジトリルート）の「Required Workflow」8
  ステップの文言を確認し、各フェーズの `rationale` にステップ番号を
  明記した（例: "AGENTS.md Required Workflow step 2"）。
- 調査: `src/parsers/task-validation.ts` / `src/parsers/
  evidence-bundle.ts` を読み、`Implementation Complete`/`Done` タスクの
  状態機械バリデーションが単なる Status 文字列一致では済まず、
  実装レポート・evidence bundle・quality-gate レポートの実体を要求
  することを確認。next-command のフィクスチャ（quality-gate/done
  フェーズのテスト）にこれらの補助ファイルを追加する形で対応した。
- 検証: TDD の過程で `../escape` を feature に渡すテストが最初
  失敗し、`guardedRead` の失敗コードを一律「not-found 相当」として
  扱っていたバグを発見（Specification Differences 参照）。修正後、
  同テストは `path-denied` がそのまま伝播することを確認して green
  にした。
- 検証: Inspector CLI (`@modelcontextprotocol/inspector@0.22.0`) を
  手動で試し、`--cli node dist/index.js --root <path> --method
  <method> [--tool-name <name>]` という呼び出し形状と、サーバー起動
  引数（`--root`）がサブコマンドとしてそのまま `node dist/index.js`
  に渡ることを確認した上でテストを実装した。

## Session Handoff

- **Current status**: T-010 完了。`npx tsc --noEmit` エラーゼロ、
  `npm run build` 成功、`npm test` 139/139 pass（Inspector smoke 3件
  含む）。Red/Green evidence と本レポートを保存済み。
- **Next action**: quality-gate による独立レビューと Done 判定。
- **Unresolved items**: 上記「Unresolved Items」参照（Implementation
  Complete/Done 混在状態の扱い、Inspector smoke の CI 実行時間未計測）。
