# Implementation Report: T-005

- Task ID: T-005
- Feature: sdd-forge-mcp
- Risk: high
- Required Workflow: tdd

## Target

evidence tools 5 種（`evidence_get_bundle` / `evidence_validate_paths` /
`evidence_find_missing` / `evidence_summarize_contract_checks` /
`evidence_compare_to_traceability`）を実装し、`mcp/sdd-forge-mcp/src/server.ts`
に登録する（design.md「Architecture」`tools/evidence.ts`、「API / Contract
Plan」`evidence_find_missing` の代表形状）。T-011 のパーサー
（`src/parsers/evidence.ts` の `parseEvidenceBundle`/`parseVerificationContract`、
`src/parsers/traceability.ts` の `parseTraceability`）と T-002/T-003 の
`parseTaskState`/`task-validation.ts` を消費し、
`contracts/sdd-forge-mcp-tools.v1.schema.json` の `evidenceBundleData` /
`evidencePathsData` / `evidenceMissingData` / `contractChecksSummaryData` /
`traceabilityComparisonData` 形状に変換する。

## Summary

- `src/tools/evidence.ts`（新規）: `src/tools/core.ts` と同じ
  `(root, feature, taskId?) -> Result<...>` の純粋関数パターンで5 tool を実装。
  - `evidenceGetBundle(root, feature, taskId)`: `validateFeature`/
    `validateTaskId`（`core.ts` から再利用）で引数形状を検証後、
    `parseEvidenceBundle` の結果をそのまま `evidenceBundleData` にラップして
    返す。署名の検証・鍵ファイルの読み取りは一切行わない（T-011 の既存動作
    のまま）。
  - `evidenceValidatePaths(root, feature, taskId)`: `parseEvidenceBundle` で
    bundle を取得し、`artifacts[].path` それぞれについて
    `resolveGuarded`（`path-guard.ts` の既存 export）を呼んで判定する。
    `resolveGuarded` が `ok` なら `safe: true, exists: true`。エラーの場合、
    `error.code` が `not-found`/`too-large` なら「形状・allowlist・denylist は
    通過したが存在しない（または大きすぎる）」ことを意味するため
    `safe: true, exists: false`（`too-large` はさらに `guardedExists` で
    `false` になる）。`error.code` が `path-denied`/`invalid-input`
    （絶対パス・`..`・空文字列・denylist 一致等）なら `safe: false,
    exists: false`。`reason` にはガードのエラーメッセージをそのまま入れる
    （ファイル内容や環境変数値は含まれない — `envelope.ts` の既存契約通り）。
  - `evidenceFindMissing(root, feature, taskId)`: Done 遷移要件を
    check-task-state.sh 相当の `task-validation.ts`
    （`validateDoneEvidence`）と同じ3項目で判定する（下記「Done 要件整合」
    節参照）。ただし `verifyEvidenceBundle`
    （artifacts マニフェストの sha256 突合等、より厳格な完全性検証）は
    呼ばない — タスク指示の required 定義
    （`verification/<taskId>.evidence.json` 存在、`.contract.json` 存在、
    `reports/quality-gate/` に taskId 言及 + `VERDICT: PASS`
    のレポート存在）の3点の**存在確認のみ**を再現する設計上の判断。
    `required`/`present`/`missing` は文字列トークン
    （`"evidence-bundle"`/`"verification-contract"`/
    `"quality-gate-report-pass"`）で表現する（要件名。ファイルパスではない
    — quality-gate report は複数ファイルがマッチしうるため単一パスで
    表現できない）。
  - `evidenceSummarizeContractChecks(root, feature, taskId)`:
    `parseVerificationContract` の結果をそのまま `contractChecksSummaryData`
    にラップ。
  - `evidenceCompareToTraceability(root, feature)`: `parseTraceability` +
    `parseTaskState` を読み、以下3種の突合規則で `mismatches` を収集する
    （「突合規則」節に詳細）。`taskId` 引数を取らない（feature 全体の
    traceability.md を対象とするため）。
- `src/server.ts`: `tools/evidence.ts` から5関数を import し、
  `FEATURE_ARG`（既存）+ 新規 `TASK_ID_ARG`（`z.string()`）を入力スキーマに
  使って5 tool を `server.registerTool` で追加登録。`root` パラメータは
  一切公開しない（REQ-007、既存8 tool と同じ制約）。モジュール冒頭コメントの
  「Evidence tools（T-005+）are out of scope」という記述を削除し、
  8 core + 5 evidence + 5 resources の記述に更新。

## Files Changed

- `mcp/sdd-forge-mcp/src/tools/evidence.ts` — 5 evidence tool 実装（新規）
- `mcp/sdd-forge-mcp/src/server.ts` — 5 evidence tool の import + 登録
  （`TASK_ID_ARG` 追加、モジュール冒頭コメント更新）
- `mcp/sdd-forge-mcp/tests/evidence/test-helpers.ts` — 共有ヘルパー
  （実リポジトリルート解決、ajv バリデータ、MCP client/server 接続、
  合成 `demo` フィクスチャ生成。`*.test.ts` 以外の命名で node:test の
  重複実行を回避）（新規）
- `mcp/sdd-forge-mcp/tests/evidence/evidence.test.ts` — 5 tool の
  実データ・合成フィクスチャテスト18件（新規）
- `mcp/sdd-forge-mcp/tests/core-tools/core-tools.test.ts` —
  「every tool's input schema never declares a root parameter」テストの
  期待値を「8 core tools」から「13 tools（8 core + 5 evidence）」に更新
  （`buildServer` が返す全 tool を数える既存テストの対象範囲が広がった
  ため。テスト意図そのもの — root パラメータ非公開の検証 — は不変）
- `mcp/sdd-forge-mcp/tests/smoke/inspector-smoke.test.ts` —
  `tools/list` の期待値リストに5 evidence tool 名を追加（同じ理由）

## Tests Added Or Updated

`tests/evidence/evidence.test.ts`（18件、AC-014）:

- **実データ検証**（`specs/sdd-forge-refactor/` および `specs/sdd-forge-mcp/`
  の実ファイルを対象、InMemoryTransport 経由の MCP client/server）:
  - `evidence_get_bundle`: sdd-forge-refactor T-001 の bundle を取得し
    `task_id`/`risk`/`artifacts` を確認。
  - `evidence_validate_paths`: sdd-forge-refactor T-001 の全 artifact
    パスが `safe: true, exists: true` であることを確認。
  - `evidence_find_missing`: sdd-forge-refactor T-001（Done）の
    `missing` が空配列であることを確認（Done 要件整合の実データ側）。
  - `evidence_summarize_contract_checks`: sdd-forge-refactor T-001 の
    `placeholder-scan` チェックが `required: true, passes: true,
    requirementIds: ["REQ-001", ...]` であることを確認。
  - `evidence_compare_to_traceability`: sdd-forge-mcp の
    `traceability.md` が現在の `tasks.md`（T-001〜T-011 全件存在）と
    完全に整合し、`mismatches` が空配列であることを確認。
- **合成フィクスチャ**（`tests/evidence/test-helpers.ts` の
  `seedDemoFixture` — `demo` feature: T-001 が Done + 完全な evidence
  bundle/contract/quality-gate report、T-002 が Planned + 検証成果物
  なし、traceability.md に正しい行1つ + 存在しない `T-099` を参照する
  行1つ）:
  - `evidence_get_bundle`: signature 値のエコー確認、T-002（bundle
    なし）で `not-found`、不正な taskId 形状で `invalid-input`。
  - `evidence_validate_paths`: `../../etc/passwd`（traversal）・
    `/etc/passwd`（絶対パス）を `safe: false, exists: false` として、
    存在するリポジトリ内パスを `safe: true, exists: true` として、
    存在しないが安全なパスを `safe: true, exists: false`
    として区別できることを確認（unsafe path ケース）。
  - `evidence_find_missing`: T-002（検証成果物なし）で `missing`
    が `required` と完全一致（全欠落ケース）、`VERDICT: FAIL` の
    quality-gate report を持つ合成タスクで `missing` が
    `["quality-gate-report-pass"]` のみであることを確認（部分欠落
    ケース）、T-001（完全な bundle）で `missing` が空であることを
    `get_task_state`（`parseTaskState`）の Done 検証結果とも突合
    （下記「Done 要件整合の確認」参照）。
  - `evidence_summarize_contract_checks`: `waiverReason`/
    `requirementIds` の camelCase 変換確認、壊れた JSON で
    `cannot-parse`。
  - `evidence_compare_to_traceability`: 存在しない `T-099` を参照する
    REQ-Task 行が `mismatches` に現れること（不一致ケース）、
    contract の `requirementIds` に traceability.md 未宣言の
    `REQ-999` を追加した場合に `T-001 contract -> REQ-ID` 件名の
    mismatch が現れること、`traceability.md` 自体が存在しない
    feature 名で `not-found` になること。
  - 全 evidence tool 共通: `feature: "../escape"` で全 tool が
    `invalid-input` を返すことを確認。

`tests/core-tools/core-tools.test.ts` / `tests/smoke/inspector-smoke.test.ts`:
上記の tool 数変化に合わせて期待値を更新（新規テストではなく既存テストの
調整。テストの意図・検証内容そのものは変更なし）。

## Regression Tests Run

- `npx tsc --noEmit`（src/、strict）: エラーゼロ
- `npx tsc -p tsconfig.test.json`（テストビルド）: エラーゼロ
- `npm test`（`node --test dist-test/tests/**/*.test.js`）:
  **157 tests / 157 pass / 0 fail**（既存139 + 新規18: すべて
  `tests/evidence/evidence.test.ts`）。
- `npm run build`（esbuild バンドル）: 成功（`dist/index.js` 1.3MB）。
- Red/Green evidence:
  `mcp/sdd-forge-mcp` から見て
  `specs/sdd-forge-mcp/verification/T-005-red.txt`（`src/tools/evidence.ts`
  と `src/server.ts` の5 tool 登録を一時的に取り除いた状態で
  `npm test` を実行し、157件中20件が失敗することを記録 — 新規18テスト
  全件 + 「tool 数13を期待する」既存2テスト（core-tools・
  inspector-smoke、いずれも T-005 のために本タスクで更新した期待値））、
  `specs/sdd-forge-mcp/verification/T-005-green.txt`（実装復元後、
  `tsc --noEmit` エラーゼロ + `npm test` 157/157 pass のフル出力）。

## Specification Differences

- なし。タスク指示の5 tool・引数検証・エラー種別をそのまま実装した。

## Evidence Tool Schema Validation Results

`tests/evidence/test-helpers.ts` の `getEnvelopeValidator()`（ajv 2020,
`strict: true`）で、`evidence.test.ts` の全18ケースが
`contracts/sdd-forge-mcp-tools.v1.schema.json` に対して ok/error
どちらの envelope 形状でもスキーマ検証をパスすることを確認済み
（各テストで `assert.ok(getEnvelopeValidator()(envelope), ...)` を実施）。
5 tool すべての `data.kind` が契約の `const` 値
（`evidence-bundle`/`evidence-paths`/`evidence-missing`/
`contract-checks`/`traceability-comparison`）と一致することも確認済み。

## Done 要件整合の確認

`evidence_find_missing` の3要件（evidence-bundle 存在、
verification-contract 存在、quality-gate-report-pass 存在）は、
`task-validation.ts`（check-task-state.sh 相当）の `validateDoneEvidence`
が Done 遷移時に行う**存在確認3種**と同じ判定条件を使う
（`guardedExists` によるファイル存在確認 + `anyFileContaining` +
`hasQualityGateVerdictPass` の再利用）。ただし `validateDoneEvidence`
はこれに加えて `verifyEvidenceBundle`（artifacts マニフェストの
sha256 突合、risk 別 provenance 要件等、check-evidence-bundle.sh
相当のフル検証）も呼ぶため、`evidence_find_missing` の
「missing が空」は「Done 遷移の3種の必須ファイルが存在する」ことの
確認であり、「`get_task_state` が Done を pass 判定する」こととは
**厳密には別の粒度**であることが判明した（下記 Unresolved Items 参照）。
このため実データ側のテストでは sdd-forge-refactor T-001 に対して
`evidence_find_missing` の `missing` が空であることのみを確認し
（タスク指示通り）、`get_task_state` との完全な整合性は、私が制御できる
合成フィクスチャ側（`demo` feature の T-001 — 完全に正しい artifacts
マニフェストを持つ Done タスク）で
`taskStateResult.data.failures` に `T-001`/`done-*` 系のエントリが
一切ないこと・`verdict === "pass"` であることを追加確認する形で
実施した（`evidence_find_missing: synthetic Done task with a fully
valid bundle has nothing missing, matching get_task_state's Done
verdict` テスト）。

## Traceability 突合規則の要約

`evidenceCompareToTraceability`（`src/tools/evidence.ts` 内
`extractTaskIdPrefix` + 本体ループ、コメントに同内容を明記）:

1. `traceability.md` の REQ -> Task 表の各行について、`taskIds[]`
   の各トークンから先頭の `T-\d+` を正規表現で抽出し（実データでは
   `T-002 Phase 2` や `T-011（静的）` のような自由記述の接尾辞が
   付くため、**完全一致ではなく先頭一致**で判定）、その task id が
   `tasks.md`（`parseTaskState` の結果）に実在するかを確認する。
   先頭一致すら取れない、または存在しないタスクを指す場合は
   `subject: "REQ-ID -> Task-ID (<reqId>)"` の mismatch。
2. AC -> TEST -> Task 表の各行についても同じ判定を行う
   （`subject: "AC-ID/TEST-ID -> Task-ID (<acId>/<testId>)"`）。
3. `tasks.md` の各タスクについて `<taskId>.contract.json` が
   読める場合、その `checks[].requirementIds` の各 REQ-ID が
   REQ -> Task 表に一度でも登場する REQ-ID 集合に含まれるかを確認する。
   含まれない場合は `subject: "<taskId> contract -> REQ-ID"` の
   mismatch（contract が traceability.md 未宣言の要件を主張している
   ことを検出する）。
4. `matches` は上記1〜3で実施した**チェック総数からmismatch件数を
   引いた値**（「一致した行/要件の数」ではなく「問題なく通過した
   チェックの数」）。

この規則は実データ2種（sdd-forge-refactor: 自由記述付き task id、
sdd-forge-mcp: 括弧注記付き task id）で「先頭一致」を要求しないと
誤検出になることを確認した上で採用した。

## Unresolved Items

- `evidence_find_missing` は「3種の必須ファイルが存在するか」の
  **存在確認のみ**であり、`verifyEvidenceBundle`
  （artifacts マニフェストの sha256 整合性・risk 別 provenance
  要件）までは検証しない。実際、現在のリポジトリの
  `specs/sdd-forge-refactor/verification/T-*.evidence.json` は
  （tasks.md が事後に編集され続けた結果）`tasks.md` 自体の
  sha256 が記録時点と食い違っており、`get_task_state`
  （`parseTaskState`）は sdd-forge-refactor の T-001〜T-005 全件で
  `done-evidence-invalid` 失敗を返す状態になっている
  （本タスクとは無関係な既存のドリフト — 修正はスコープ外)。
  そのため `evidence_find_missing` の「missing 空」＝
  「`get_task_state` が Done を pass する」という強い等価性は、
  実データでは成立しない場合があることが判明した。タスク指示の
  「missing 判定が check-task-state.sh の Done 要件と整合」という
  Done When は、3要件の**存在確認**という粒度で満たしている
  （合成フィクスチャで実証済み）が、フルの整合性検証
  （sha256 突合含む）が必要な場合は呼び出し側が別途
  `evidence_validate_paths` や将来のツールでカバーする必要がある。
- `evidence_validate_paths` の `safe` 判定は `resolveGuarded`
  のエラーコード（`not-found`/`too-large` vs
  `path-denied`/`invalid-input`）を使って「shape/allowlist/denylist
  通過」と「存在確認」を分離しているが、`too-large`
  （2 MiB 超過）の場合は `safe: true`（許可された場所にはある）
  かつ `exists: false`（`guardedExists` が `too-large` も
  「存在しない」として扱うため）という、直感的には紛らわしい
  組み合わせになりうる。テストではこのケースを明示的には
  カバーしていない（既存の path-guard 側テストで
  `too-large` 自体は別途検証済みのため）。
- `evidence_compare_to_traceability` は `traceability.md` の
  "Task → 実装ファイル" のような Task-ID 列を持つが REQ-ID/AC-ID
  列を持たない表（sdd-forge-refactor に存在）を突合対象にしない
  （`traceability.ts` がそもそもそのような表を抽出しないため）。
  この設計はタスク指示・T-011 の既存パーサー仕様と一致している。

## Quality Gate Focus

- `evidence_find_missing` が「存在確認のみ」で `verifyEvidenceBundle`
  のフル検証を呼ばない設計判断が、タスク指示の required 定義
  （3項目のみ）と整合しているか、それとも Done 判定としては
  不十分と判断すべきか。
- `evidenceCompareToTraceability` の「先頭一致」ルール
  （`extractTaskIdPrefix`）が緩すぎないか（例: `T-1` が `T-100`
  にマッチしてしまわないかは `T-\d+` の貪欲マッチで `T-100` なら
  `T-100` 全体を拾うため問題ないが、`T-1foo` のような形は
  `T-1` として拾われる — 実データにはこの形は存在しない）。
- `evidence_validate_paths` の safe/exists の分離ロジックが
  security-spec.md の意図（allowlist 内かどうかの判定）と
  一致しているか。

## Working Notes

- 調査: `specs/sdd-forge-refactor/verification/T-001.evidence.json`
  の `artifacts[].path` に含まれる `specs/sdd-forge-refactor/tasks.md`
  の sha256 が現在のファイル内容と一致しないことを発見し
  （`verifyEvidenceBundle` を直接呼んで確認）、当初計画していた
  「`evidence_find_missing` の missing 空 <=> `get_task_state` の
  Done failures 空」という実データでの厳密な cross-check を撤回、
  合成フィクスチャ側でのみ実施する設計に変更した（Unresolved Items
  参照）。
- 調査: `specs/sdd-forge-mcp/traceability.md` の Task-ID セルに
  `T-011（静的）, T-004（実行時）` のような日本語注記付きの値が
  実在すること、`specs/sdd-forge-refactor/traceability.md` にも
  `T-002 Phase 2` のようなフェーズ注記付きの値が実在することを
  確認した上で、`evidenceCompareToTraceability` の task id 照合を
  完全一致ではなく先頭 `T-\d+` 抽出にする設計を採用した。
- Red 状態の再現: git 管理下にない（`mcp/` ディレクトリ全体が
  untracked）ため git stash が使えず、`src/tools/evidence.ts` を
  一時的にスクラッチパッドへ退避し `src/server.ts` の5 tool 登録を
  手動で削除した状態で `npm test` を実行して Red ログを取得、その後
  ファイルを復元して Green を再実行する手順を取った。
- 学び（既存メモリ通りの再確認）: `tests/evidence/` の共有ヘルパーを
  `test-helpers.ts`（`*.test.ts` 以外の命名）に切り出し、node:test の
  重複実行を回避。

## Session Handoff

- **Current status**: T-005 完了。`npx tsc --noEmit` エラーゼロ、
  `npm test` 157/157 pass、`npm run build` 成功。Red/Green evidence
  と本レポートを保存済み。
- **Next action**: quality-gate による独立レビューと Done 判定。
- **Unresolved items**: 上記「Unresolved Items」参照
  （`evidence_find_missing` の検証粒度、`too-large` の safe/exists
  組み合わせ、Task-ID 専用表の突合対象外化）。
