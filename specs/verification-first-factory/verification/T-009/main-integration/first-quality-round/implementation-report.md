# Implementation Report: T-009

- Task ID: T-009
- Model: gpt-6.2-astra
- Effort: high

Report Schema: implementation-report/v2
Run ID: 66bd8341-cd3d-442f-bd23-6ced5865d26b
Task Attempt Count: 5
Input manifest: `specs/verification-first-factory/verification/T-009/main-integration/final/task-input-manifest.json`, SHA-256 `0bba9182677319c3a4af7480b029facb110a0f4e49def14771b33390da8a63b7`

## 検証対象

T-009 の読み取り専用 MCP、診断項目とテレメトリー既定値を、`origin/main` の `3497bb179` と作業ブランチを統合した `e9f3e3e00cb85d4c039d88582d7ba541925c3d00`、ツリー `f0ce28a9d64ac95a1fd681b5b7fac647edc7e9ef` で最初に確認した。その後、ゲートと MCP のタスク識別処理をそろえた最終コード `cd27d0a4a90bd4cede2197072aeac5b8625dc258`、ツリー `e22f136f5d34bf2c23fb87e866dbb23806a49db2` を別の隔離 checkout で再検証した。`dist/index.js` のマージ競合は統合後のソースとロックファイルから正規ビルドで解決した。

リリース前の ADR-0052（`417f1a2e9`、59–67行、82行）と実装 `bcdff4be7`、`c19ccd814`、タグ v2.1.0（`96f5273d5`）と v2.1.3（`484cbe7ae`）を照合した。v2.1 の公開契約は4ツールと2リソース。以前の95件は、廃止済みRPCを呼んでいた内部reader試験70件、現行公開機能・旧名の非公開確認16件、試験のファイル探索3件、旧ホストとの比較4件、互換CLI2件に対応する。これらの修正は統合元に含まれている。対応する全95件の現行検証結果を Test Evidence Path に掲載した。

2026-11-25 05:58:40 UTC に v2.1.3 が公開され、その後 16:10:31 UTC に PR #974 が `8052dbfc87b6` として main に統合された。リリース時点の MCP CI は型検査、配布物の鮮度と選択された security/readonly 試験を実行している。旧95件の追跡番号は #871（F001）から #965（F095）に対応する。[v2.1.3 リリース](https://github.com/aharada54914/sdd-forge/releases/tag/v2.1.3)、[リリース SHA の MCP ジョブ](https://github.com/aharada54914/sdd-forge/actions/runs/45556762389/job/139010573830)、[PR #974](https://github.com/aharada54914/sdd-forge/pull/974)、[F001](https://github.com/aharada54914/sdd-forge/issues/871)、[F095](https://github.com/aharada54914/sdd-forge/issues/965)

GitHub Actions の [main の MCP ジョブ](https://github.com/aharada54914/sdd-forge/actions/runs/45654087540/job/139345990822) は選択された公開契約検査に成功した。下記のパッケージ全件は統合ツリーでのローカル実測値である。

## Outputs

| Path | SHA-256 |
|---|---|
| `plugins/sdd-quality-loop/scripts/v2/v2-readonly-core.mjs` | `916ba0e56a0b2e57607684aafd2b06c866d11692a1d6782a6ca4d64bab66b648` |
| `plugins/sdd-quality-loop/scripts/v2/factory-metrics.mjs` | `9122b5cce0bac86e246975a4586e636586a9435077c6ca759c7295c0e85add88` |
| `mcp/sdd-forge-mcp/src/tools/v2.ts` | `c7f43b09a1cb39e2f2e9fb241109524a292572baa30512676f721b392a9c3d25` |
| `mcp/sdd-forge-mcp/dist/index.js` | `e085947210ab0041af3003c394aac6234d1beb950a54459aea2b16d05435f0df` |
| `contracts/sdd-mcp.v2.schema.json` | `eb3bd9e3e3f41da34d7396936e8d488a047927811ab6f08e29643090f82d18a8` |
| `tests/v2-mcp-server.test.mjs` | `af68c09b7d19ac6b8c930b48ca02f516317194ebeac1dd849d6705995980256a` |
| `tests/v2-wave3-integration.test.mjs` | `9a2d430e2cc10c915c259a7dfde394765bb5137fae045d7d5813a368a8ad4178` |
| `specs/verification-first-factory/verification/T-009/main-integration/prior-report.md` | `0150c7ac4aa29e14f64a66c85a4e01ac5020c20d8f56cb9114683d7839839ea8` |
| `specs/verification-first-factory/verification/T-009/main-integration/task-input-manifest.json` | `b2e6fa7bf01b24b20b4ee9521d048cc154e762eee648e9edf9cd2651b1adff9c` |
| `specs/verification-first-factory/verification/T-009/main-integration/test-result.log` | `57221f03a56458deb767bbddae73e8148306a78c9fd6702ce110435236b6632f` |
| `reports/quality-gate/verification-first-factory-T-009.execution.json` | `f7db70fcb979cd61cf59a1ce0bf9bddb1a3601b7046c22cbf8083373e2babd32` |
| `specs/verification-first-factory/verification/T-009/main-integration/final/task-input-manifest.json` | `0bba9182677319c3a4af7480b029facb110a0f4e49def14771b33390da8a63b7` |
| `specs/verification-first-factory/verification/T-009/main-integration/final/test-result.log` | `25b9e32c49a5c632ce7d15115c13e948b58e5e70f5e8a49241f31a1d3dd9ea7c` |
| `specs/verification-first-factory/verification/T-009/main-integration/compatibility.json` | `126fa7f2d743b6cf392a108e55abcd324719be4c8d7a54410be1f47c838e5479` |
| `plugins/sdd-quality-loop/scripts/v2/v2-pure-lib.mjs` | `47b527ce95f65d69edfa43fd253041a63623dccb7f23046c12a6c0d529280a02` |
| `plugins/sdd-quality-loop/scripts/v2/run-sdd-gate.mjs` | `2d67724fc842505ad8c3fa3b20e6dfdf5ad4709dd89c0fbc6aef38442d9ac594` |
| `tests/v2-software-factory.test.mjs` | `7d09f822024456c532e666a518f25d9ca0d17bdc3c4598672b54d6225fe48c0f` |

`reports/quality-gate/verification-first-factory-T-009.execution.json` は主担当が別途生成した決定論的ゲートの実行記録（Run ID `920911b0-a741-4bd1-9838-3848d0216596`、仕様入力あり、4コマンド、PASS）。独立評価者に渡す資料に含めた。

## Test Evidence

- **Test Command**: `npm --prefix mcp/sdd-forge-mcp test`
- **Test Result**: PASS
- **Test Evidence Path**: `specs/verification-first-factory/verification/T-009/main-integration/final/test-result.log`

クリーンな依存環境で369件全件成功、失敗0件、スキップ0件。旧95件のうち94件は対応する現行ケース名で成功を確認し、旧 F016 はモジュールの21件すべての登録・成功を確認した。

v2.1.3 の設定ファイルを維持し、doctor、traceability、decision、引数エラー、MCP stdio の5経路を片側各5回、最終コードと比較した。25組すべて終了コード一致、最大増分は113.64ms（基準は15秒以内）。MCP実起動で4つの読み取り専用ツール、静的リソース1件とリソーステンプレート1件を確認し、stdio スイートのインストール試験で登録既定OFFも確認した。互換計測の環境・時刻・サンプルを `specs/verification-first-factory/verification/T-009/main-integration/compatibility.json` に記録した。対象外の旧スクリプトと他環境の網羅性は未検証。

## Regression Tests Run

macOS arm64、Node.js v24.22.1。型検査、ビルド、追跡済み配布物のバイト一致を確認した。Ajv 必須の stdio 試験は25/25件、Wave 3 は10/10件、旧ホスト実スクリプトを使った追加の比較は4/4件成功した。全件実行した各試験のスキップは0件。Wave 形式のタスク解析・証跡の回帰2件も成功した。第4回の途中では Wave 3 の初回は T-008 の lint 依存が不足し、旧ホスト比較の初回は同梱 Python モジュールが不足した。各依存を元のロックファイルまたは Git スナップショットから復元して再実行した。第4回の途中経過は `specs/verification-first-factory/verification/T-009/main-integration/test-result.log` に保存した。最終 SHA の各実行は Test Evidence Path に掲載した。

## Iteration And Escalation

- **Task Attempt Count**: 5
- **Escalation Prior Tier**: None
- **Escalation Next Tier**: None
- **Escalation Failure Class**: None
- **Escalation Attempt Number**: None
- **Escalation Reason**: None

前回（第3回、Run ID `f3df5b97-f348-41e8-a491-8a233042b989`、`725eb86c5`）は319件中224件成功、95件失敗、スキップ0件。原文を `specs/verification-first-factory/verification/T-009/main-integration/prior-report.md` に保存した。第2回（Run ID `verification-first-factory-T-009-repair-20261126`）の原文は `specs/verification-first-factory/verification/T-009/report-revalidation/prior-report.md` にある。第4回（Run ID `f860eee8-2a80-4db1-b4b8-e6a519cc97ae`、`e9f3e3e00`）は初期統合ツリーで全369件成功。第5回は同じ T-009 専任担当が最終コードを別の事前 manifest と checkout で再検証した。

## Isolation Evidence

- **Scratch Root**: `/private/var/folders/7z/hjmz6jdj4wb40srf64sl368w0000gn/T/sdd-final-t009-72hw_r3c`
- **Run ID**: 66bd8341-cd3d-442f-bd23-6ced5865d26b
- **Session ID**: 01a2138c-0726-7f03-860a-38fe123172d2
- **Agent Instance ID**: codex-01a2138c-0726-7f03-860a-38fe123172d2
- **Isolation Mode**: fresh-agent
- **Fallback Reason**: None
- **Handoff Reload Evidence Hash**: None

今回の正式検証は新規入力 manifest を固定し、そのハッシュを検証した後、上記の隔離 checkout で実行した。

## Unresolved Items

今回の対象である AC-013 のパッケージ全件合格を確認した。旧版コードとの所要時間・終了コード比較は記載した5経路に限る。旧実装当時の事前入力と独立性は当時の記録から検証できていない。

## Session Handoff

- **Current Status**: Implementation Complete
- **Next Action**: 独立ゲートが統合ツリーの実行記録と本報告を評価する。
- **Unresolved Items**: 独立ゲートの最終判定は主担当が別途記録する。
