# Implementation Report: T-011

- Task ID: T-011
- Feature: sdd-forge-mcp
- Risk: high
- Required Workflow: tdd

## Target

evidence 系構造化データ抽出パーサー2種
（`specs/<feature>/verification/T-*.evidence.json` / `T-*.contract.json` /
`specs/<feature>/traceability.md`）を実装し、
`contracts/sdd-forge-mcp-tools.v1.schema.json` の `evidenceBundleData` /
`contractChecksSummaryData` エントリ形状に変換する（design.md「Data Plan」
`evidence.ts` / `traceability.ts`）。既存の `evidence-bundle.ts`
（check-evidence-bundle.sh 相当の検証ロジック）とは責務を分離し、型の
一部のみ共有する。

## Summary

- `src/parsers/evidence.ts`（新規）:
  - `parseEvidenceBundle(root, feature, taskId)` —
    `specs/<feature>/verification/<taskId>.evidence.json` を `guardedRead`
    経由で読み、JSON パース + 基本構造検証（`task_id` が要求された
    taskId と一致、必須フィールド `task_id`/`feature`/`risk`/
    `required_workflow` の存在）を行い、パース済みオブジェクトを
    **そのままエコー**して返す（`signature` を含む全フィールド）。
    署名（`sig`/`signature`）の検証は一切行わず、署名鍵ファイルも
    読まない（path-guard がそもそも鍵ファイルを denylist している）。
    失敗はすべて `cannot-parse`（JSON 構文エラー、非オブジェクト、
    task_id 不一致、必須フィールド欠落）で、いずれもファイル名を
    `details.file` に含める。path-guard 自体の読み取り失敗
    （`not-found` 等）はそのまま伝播する。
  - `parseVerificationContract(root, feature, taskId)` —
    `<taskId>.contract.json` を読み、`task_id` 一致検証の上、
    `checks[]` 配列を `contractChecksSummaryData.checks` の camelCase
    形状（`id`, `required`, `passes`, `waiverReason?`,
    `requirementIds?`）に変換する。`checks` が配列でない、各要素が
    非オブジェクト、`id`/`required`/`passes` のいずれかが期待型でない
    場合は `cannot-parse`。
  - `evidence-bundle.ts` との共有: 検証ロジック本体
    （`verifyEvidenceBundle` 関数）は一切変更せず、生 JSON 形状を表す
    型宣言（`EvidenceBundle`, `VerificationContract`, `ContractCheck`,
    `EvidenceArtifact`, `EvidenceBuildEnv`, `EvidenceReviewVerdict`,
    `EvidenceSignature`）のみ `export` に変えて `evidence.ts` から
    re-import する形にリファクタした（重複定義を避けるための型共有）。
    `ContractCheck`/`VerificationContract` には T-011 が読む
    `required`/`waiver_reason`/`requirement_ids`/`feature`/
    `required_workflow` フィールドを追加したが、すべてオプショナルの
    ため `verifyEvidenceBundle` の既存参照箇所（`passes`/`id`/
    `evidence`/`task_id`/`risk`/`checks`）には影響しない
    （型追加後も既存78テストは無変更で全通過）。
- `src/parsers/traceability.ts`（新規）:
  - Markdown 表（`| ... |` 形式）を節見出しテキストに依存せず、
    ヘッダー行のカラム名で判定する汎用抽出器を実装
    （`findTables` → ヘッダー+区切り行+データ行を収集 →
    `columnIndex`/`hasColumn` でカラム名から表の種別を判定）。
  - `REQ -> Task` 表: `REQ-ID` 列と `Task-ID` 列を持ち `AC-ID` 列を
    持たない表から `{ reqId, taskIds[] }[]` を抽出。
  - `AC -> REQ` 表: `AC-ID` 列と `REQ-ID` 列を持ち `TEST-ID` 列を
    持たない表から `{ acId, reqIds[] }[]` を抽出。
  - `AC -> TEST -> Task` 表: `AC-ID`/`TEST-ID`/`Task-ID` 列を持つ表から
    `{ acId, testId, taskIds[], target? }[]` を抽出（`target` は
    `Test Target` 列があれば拾う）。
  - セル値がカンマ区切りの複数 ID（例: `T-001, T-002`、
    `REQ-007, REQ-009`）の場合は `splitIdList` でトリムして配列化。
  - 表そのものが存在しない形状は単に空配列（エラーではない —
    sdd-forge-refactor には `AC -> TEST -> Task` 表が存在しない）。
    一方、ヘッダーにカラムがあるのにデータ行でセルが欠落/空/ID形状
    不一致（`^REQ-\d+$` 等）の場合は `cannot-parse` + 1始まりの行番号。

## Files Changed

- `mcp/sdd-forge-mcp/src/parsers/evidence.ts` — evidence bundle /
  verification contract 抽出パーサー（新規）
- `mcp/sdd-forge-mcp/src/parsers/traceability.ts` — traceability.md
  表抽出パーサー（新規）
- `mcp/sdd-forge-mcp/src/parsers/evidence-bundle.ts` — 内部型
  （`ContractCheck`/`VerificationContract`/`EvidenceArtifact`/
  `EvidenceBuildEnv`/`EvidenceReviewVerdict`/`EvidenceSignature`/
  `EvidenceBundle`）を `export` に変更し、T-011 が読むフィールド
  （`required`/`waiver_reason`/`requirement_ids`/`feature`/
  `required_workflow`）をオプショナルとして追加。検証ロジック本体
  （`verifyEvidenceBundle` 関数の実装）は無変更。

## Tests Added Or Updated

- `mcp/sdd-forge-mcp/tests/parsers-evidence/test-helpers.ts` —
  実リポジトリルートを解決する共有ヘルパー（既存の
  `tests/parsers-state/test-helpers.ts` と同型、`*.test.ts` 以外の
  命名でテストランナーの重複実行を回避）。
- `mcp/sdd-forge-mcp/tests/parsers-evidence/evidence.test.ts`（13件）—
  実データ検証（`specs/sdd-forge-refactor/verification/` の
  T-001〜T-005 の evidence.json/contract.json 全件が例外なくパース
  され、T-001 の内容・contract の `placeholder-scan` チェックの
  `requirementIds` に `REQ-001` を含むことを確認）、合成正常系
  （signature 値のエコーのみ・検証しないことの確認、checks[] の
  camelCase 変換）、cannot-parse 系（task_id 不一致、JSON 構文
  エラー、必須フィールド欠落、`checks` が配列でない）、path-guard
  失敗の伝播（`not-found`）。
- `mcp/sdd-forge-mcp/tests/parsers-evidence/traceability.test.ts`
  （7件）— 実データ検証（`specs/sdd-forge-refactor/traceability.md`
  の REQ->Task・AC->REQ 抽出、AC->TEST->Task 表が存在しないことの
  確認／`specs/sdd-forge-mcp/traceability.md` の3表すべての抽出、
  REQ-003 の taskIds が `["T-011", "T-005"]` に、AC-014 の
  reqIds/testId/taskIds/target が期待通りであることの厳密検証）、
  合成正常系（カンマ区切り Task-ID の分割、表が1つも無い場合は
  空配列でエラーにならないこと）、cannot-parse 系（データ行の
  カラム欠落、必須セルが空、行番号の一致確認）、path-guard 失敗の
  伝播（`not-found`）。

## Regression Tests Run

- `npx tsc --noEmit`（src/、strict）: エラーゼロ
- `npx tsc -p tsconfig.test.json`（テストビルド）: エラーゼロ
- `npm test`（`node --test dist-test/tests/**/*.test.js`）:
  **98 tests / 98 pass / 0 fail**（既存 T-001〜T-010 の78テスト +
  T-011 の新規20テスト: evidence.test.ts 13、traceability.test.ts 7）。
- Red/Green evidence:
  `specs/sdd-forge-mcp/verification/T-011-red.txt`（実装前、
  `tsc -p tsconfig.test.json` が新規モジュール不在によりコンパイル
  エラーで失敗することを記録）、
  `specs/sdd-forge-mcp/verification/T-011-green.txt`（実装後、
  `tsc --noEmit` エラーゼロ + `npm test` 98/98 pass のフル出力）。

## Specification Differences

- なし。タスク指示の2パーサー・想定エラー種別（cannot-parse オンリー
  — evidence 系は署名検証をしないため cannot-determine は不要）を
  そのまま実装した。

## Unresolved Items

- `traceability.ts` の `AC -> REQ` / `AC -> TEST -> Task` 抽出は、
  T-005/T-005 実データで検証したカラム名（`AC-ID`, `REQ-ID`,
  `TEST-ID`, `Task-ID`, `Test Target`）にのみ対応する。将来
  他 feature の traceability.md で異なる列名表記（例:
  `Test-ID` ではなく `TestID`）が使われた場合は追加の別名対応が
  必要になる可能性がある（現状は実データ2種のみで検証）。
- `evidenceBundleData`/`contractChecksSummaryData` を実際に MCP
  ツールとして公開する層（`evidence_get_bundle` /
  `evidence_summarize_contract_checks` 等）は T-005 のスコープであり、
  本タスクではパーサー関数の実装のみ提供した。
  `traceabilityComparisonData`（traceability.md 行と検証成果物の
  突合結果）も T-005 側で `parseTraceability` の出力を消費する想定
  だが、突合ロジック自体は本タスクに含まれない。
- `ContractCheck`/`VerificationContract` に追加したフィールド
  （`required`, `waiver_reason`, `requirement_ids`, `feature`,
  `required_workflow`）は evidence-bundle.ts の既存ロジックからは
  未参照だが、将来 evidence-bundle.ts 側の検証を拡張する際に
  型が既に揃っている状態になる（意図的な副次効果）。

## Quality Gate Focus

- `evidence-bundle.ts` の型 export リファクタが検証ロジック本体
  （`verifyEvidenceBundle`）の挙動に一切影響していないこと
  （既存78テストが無変更で全通過していることで確認済みだが、
  レビューでの再確認を推奨）。
- `parseEvidenceBundle` が署名値を一切検証せずエコーのみに留めている
  こと（`signature` フィールドの値をそのまま透過させる設計が
  タスク指示・security-spec.md の意図と一致しているか）。
- `traceability.ts` の表種別判定（ヘッダーカラム名ベース）が、
  実データ2種以外の将来の traceability.md フォーマット変化に対して
  過度に厳しくないか（列名の別名を許容すべきかどうかの判断）。

## Working Notes

- 調査: `specs/sdd-forge-refactor/verification/` の実ファイル
  （T-001〜T-005 の evidence.json/contract.json）と
  `specs/sdd-forge-refactor/traceability.md` /
  `specs/sdd-forge-mcp/traceability.md` の両方を精読し、
  節見出しテキストが feature ごとに揺れること（例: 「REQ → Task
  (実装対応)」vs「REQ → Task」）、AC->REQ の REQ-ID セルがカンマ
  区切り複数値になりうること（`AC-001 | REQ-001, REQ-004`）、
  REQ->Task の Task-ID セルも複数値になりうること
  （`REQ-008 | T-001, T-007`）を確認した上で、ヘッダーカラム名判定 +
  カンマ分割という設計を選んだ。
- 調査: `contracts/sdd-forge-mcp-tools.v1.schema.json` の
  `evidenceBundleData` は `bundle: { type: "object" }`
  （形状を固定しない素通しオブジェクト）であることを確認し、
  `parseEvidenceBundle` の戻り値もオブジェクトをそのままエコーする
  設計にした（過度な型変換をしない）。
- 設計判断: `evidence-bundle.ts` の型を export する際、検証ロジック
  本体（関数の中身）には一切手を入れず、型宣言のみを変更対象とした。
  タスク指示の「検証ロジック本体は変更せず、テスト78件を壊さない
  こと」を厳密に満たすため、リファクタ後すぐに `npm test` で
  78/78 pass を確認してから T-011 のテストを追加した。
- 学び（既存メモリ通りの再確認）: `tests/parsers-evidence/`
  ディレクトリの共有ヘルパーを `test-helpers.ts`
  （`*.test.ts` 以外の命名）に切り出し、node:test の重複実行を回避。

## Session Handoff

- **Current status**: T-011 完了。`npx tsc --noEmit` エラーゼロ、
  `npm test` 98/98 pass。Red/Green evidence と本レポートを保存済み。
- **Next action**: quality-gate による独立レビューと Done 判定。
- **Unresolved items**: 上記「Unresolved Items」参照
  （traceability.ts の列名別名対応、T-005 側でのツール層実装、
  evidence-bundle.ts 追加フィールドの将来利用）。
