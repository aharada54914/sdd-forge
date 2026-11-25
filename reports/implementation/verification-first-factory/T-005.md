# Implementation Report: T-005

- Task ID: T-005
- Model: gpt-6.2-astra
- Effort: high

Report Schema: implementation-report/v2
Run ID: 01a21382-9a07-7220-9daa-2fdbca554b31
Task Attempt Count: 3
Input manifest: `specs/verification-first-factory/verification/T-005/01a21382-9a07-7220-9daa-2fdbca554b31/task-input-manifest.json`, SHA-256 `01af186c082a692fa8872d93b280925327382412176d9091560b24a97e22840f`

## 今回の再検証

2026-11-26、T-005 専任の Codex ワーカーが、リビジョン `725eb86c5ec64d7c3465db5bee24123e9fbe2712` の入力を専用ディレクトリに複製し、40 ファイルの SHA-256 を照合してから実行した。上記の Run ID は今回の再検証を識別する。旧実装報告の Run ID は `a7fc37b5-0595-468c-b9ca-547038838162`、実装試行回数は 2。旧実行時に固定した入力マニフェストは確認できなかった。第3回は報告と証拠の再検証を行った。旧報告の検証内容を末尾に収録した。

TLC 2.19 で Reservation の正常系、OneAccepted 違反、5 ステップの観測終点への到達を確認した。Check 時点の accepted を改変するとゲートは終了 1 で拒否した。Node の対象ケースは 2 回で各 4 件、Python は 6 件すべて成功し、スキップは 0 件。Node の検証にはツール未導入とタイムアウトの模擬入力を含む。

## Outputs

対象の実装・共有依存・テスト・旧証跡を今回再照合したハッシュと、新たに作成した入力マニフェスト・実行ログを示す。

| Path | SHA-256 |
|---|---|
| `plugins/sdd-quality-loop/rules/agent-lint-ast.mjs` | `8675b5764205df8602f7af1e97ebd16cf5988ab47ed68a5b0a61f846a32c0a06` |
| `plugins/sdd-quality-loop/scripts/v2/discover-state-machines.mjs` | `a352c3a50e80b45ab5aec9681efbd8e6608bd3d9a731eed1e573020fe4326949` |
| `plugins/sdd-quality-loop/scripts/v2/formal-trace.mjs` | `cc8a91ae73d9525ac9e00ef76893645a0188a62b2831de9ba914f588d6a94a76` |
| `plugins/sdd-quality-loop/scripts/v2/render-decision-view.mjs` | `4a49246e4115b3a4c097150a0318931b8f747100c51454b154fb97da21cdf1fd` |
| `plugins/sdd-quality-loop/scripts/v2/run-formal-gate.mjs` | `5f828395a7bfd5504df2a5dc438c134eb007578d4522bebc06a43b620500dabb` |
| `plugins/sdd-quality-loop/scripts/v2/v2-readonly-core.mjs` | `c2007ac8d4e781ca9868e01e38f595d2905f9fc1116cbb9abcaf2759c5277b2a` |
| `plugins/sdd-quality-loop/scripts/validate-review-context-set.sh` | `f79e5a35a9e6106f3493a57cfda5cb9c3f3d456f9cb925ea5a80971bdc1be0e8` |
| `specs/verification-first-factory/verification/T-005/01a21382-9a07-7220-9daa-2fdbca554b31/revalidation.log` | `c8176d7b6cae49e07b05ab41a7e3e08161430c7bca2b0d0f545acafd26f28110` |
| `specs/verification-first-factory/verification/T-005/01a21382-9a07-7220-9daa-2fdbca554b31/task-input-manifest.json` | `01af186c082a692fa8872d93b280925327382412176d9091560b24a97e22840f` |
| `specs/verification-first-factory/verification/T-005/a7fc37b5-0595-468c-b9ca-547038838162/implementation-race.log` | `b2dff9cd5db9fc08ef8a729d0e3971064d5e8ba5be191ee14d96f5d05238d36b` |
| `specs/verification-first-factory/verification/T-005/a7fc37b5-0595-468c-b9ca-547038838162/reservation-baseline.log` | `df369bdafa944c1a6682707ad83fcb05a1ea8ac228d065fe3fa8f53d64264752` |
| `specs/verification-first-factory/verification/T-005/a7fc37b5-0595-468c-b9ca-547038838162/reservation-negative.log` | `3d9ff015cfceaab3f0ab3a622322452b02f5a6f680986e63a26157d725615dad` |
| `specs/verification-first-factory/verification/T-005/a7fc37b5-0595-468c-b9ca-547038838162/reservation-observed.ndjson` | `a2fb732e0a0f8997eae79fd91d481b1012dcf58aa1926f323f23968b83624ca0` |
| `specs/verification-first-factory/verification/T-005/a7fc37b5-0595-468c-b9ca-547038838162/reservation-replay.log` | `c649cc17530e4c9b4cf4dc949777a51a81964c9f845c03ba7d84706f004bc59d` |
| `tests/fixtures/project-skills/formal-review-reservation/Reservation.cfg` | `b8866730366a914aa657b855f10dabb08bd67c68788c625676bb525f27b828f6` |
| `tests/fixtures/project-skills/formal-review-reservation/Reservation.negative.cfg` | `9507a6aa5361bff0d7557401e58733f37b7fb85bbf47d3b6088f094be0c4f07b` |
| `tests/fixtures/project-skills/formal-review-reservation/Reservation.tla` | `604e4c8218082b712fdc678ba1d7bfe4403a26c0ff18305bc19d6243acb56d97` |
| `tests/fixtures/project-skills/formal-review-reservation/mapping.json` | `6e3c9608f133386ba748e277c39a52ce456e6c7c1abc2449dd8e4acf204a132f` |
| `tests/project-skill-formal.tests.py` | `f6428a407327850db0da84b55cae4bdf3845924b05be1f0f5f3d253c813bd2e4` |
| `tests/v2-formal-gate.test.mjs` | `f4850eef1f4e29e9453628ed286dd01836a467339520a261678ceb39b8c7d197` |
| `tests/verify-review-reservation.py` | `3a7207a1c2098f96654bd79b9b743746f06674f547ccb2230fb5edba1d4b2cc0` |

## Test Evidence

- **Test Command**: `node --test '--test-name-pattern=ADR-0054 T-005|scan finds|skips unchanged|changed inputs|retry exhaustion' tests/v2-formal-gate.test.mjs`, `python3 tests/project-skill-formal.tests.py -v`, `node plugins/sdd-quality-loop/scripts/v2/run-formal-gate.mjs`（全引数はログに記録）
- **Test Result**: PASS
- **Test Evidence Path**: specs/verification-first-factory/verification/T-005/01a21382-9a07-7220-9daa-2fdbca554b31/revalidation.log

## Iteration And Escalation

- **Task Attempt Count**: 3
- **Escalation Prior Tier**: None
- **Escalation Next Tier**: None
- **Escalation Failure Class**: None
- **Escalation Attempt Number**: None
- **Escalation Reason**: None

## Isolation Evidence

今回の報告再検証の実行環境を記録する。

- **Scratch Root**: /private/tmp/vff-t005-report-8wzh8d0f
- **Run ID**: 01a21382-9a07-7220-9daa-2fdbca554b31
- **Session ID**: 01a21382-99eb-7a90-b06a-9d536c20e4d9
- **Agent Instance ID**: 01a21382-99eb-7a90-b06a-9d536c20e4d9
- **Isolation Mode**: fresh-agent
- **Fallback Reason**: None
- **Handoff Reload Evidence Hash**: None

## Unresolved Items

独立品質ゲートの判定待ち。今回の実行範囲は macOS のローカルファイルシステム。Windows と NFS 上の動作、クラッシュ復旧は未検証。

## Session Handoff

- **Current Status**: Implementation Complete
- **Next Action**: 独立評価者が固定した入力で T-005 の品質ゲートを実施する。
- **Unresolved Items**: 独立品質判定および上記環境制約。

## 旧実装報告（a7fc37b5-0595-468c-b9ca-547038838162）

## WFI-001 preflight

Recorded before changing implementation. Scope: AC-003–AC-006.

| Evidence field | Counterpart | Failing mismatch case |
| --- | --- | --- |
| graph.reachable / scan.signals | initial state and Mermaid edges / source boolean conditions | disconnected state, lone boolean |
| checker.baseline.ok / status / exitCode | actual checker, timeout and CI policy | missing JAR locally and on CI, timed-out runner |
| checker.negative.ok / expectedViolatedInvariant | specific checker violation and mutation cfg | configuration error that merely mentions invariant, missing negative |
| trace.ok / stepsChecked | consecutive mapped actions and model invariants | forbidden action order or missing observed state |
| evidence / escalation | actual captured counterexample and Provisional OQ in decision view | failed baseline reaching retry limit |

## 実装と受入検証

- AC-003。仕様中の Mermaid は形式検証候補として検出する。ソースの `--scan [files...]` は ast-grep で同一スコープの関連する複合ブール分岐を抽出する。`--validate graph.json` は `initial`, `states`, `transitions: [{from, to}]` の有向グラフを探索する。到達不能状態で終了 1、不正入力で 2。回帰テストは単独条件を除外し、到達不能な状態名を照合した。
- AC-004。ベースラインの探索完了と正常終了、変異設定が指定した不変条件名と終了 12 をそれぞれ検査する。Red では変異名を含む構文エラーも合格していた。Green では拒否する。Git の変更判定にはモデル、設定、マッピング、実装ソース、トレースを含める。タイムアウトは FAIL、実行不能はローカル 10 / CI 1。Lean 4 は予約値。Java は引数配列で直接起動する。タイムアウトと未導入分岐は注入した終了状態で検査した。
- AC-005。ステップ番号・宣言アクション・状態を検査し、初期状態、実モデルの Next、観測アクション、観測フィールドを同時に満たす実行列をチェッカーで探索する。終点に到達した証拠は `TraceIncomplete` の反例である。観測 5 ステップを受理し、Check 時点で Publish 済みとする観測を拒否した。予約の NDJSON は構成した入力で、実シェルの競合は別途 Python で実行した。
- AC-006。失敗時のチェッカーログ・利用可能なネイティブ反例・リプレイ入力を保存する。修正上限に達した場合は Provisional OQ を原子的に記録し、HTML 判断ビューにモデル名、失敗フェーズ、原因と証跡ディレクトリを出す。回帰テストでベースラインのタイムアウトと不正な観測の両方を検査した。

## 再現と結果

Java 21.0.13.1、[TLA+ Tools v1.7.4](https://github.com/tlaplus/tlaplus/releases/tag/v1.7.4) の `tla2tools.jar` (SHA-256 `936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88`)、TLC 2.19 (5a47802)。リポジトリのルートで `TLA2TOOLS_JAR` を取得した JAR の絶対パスに設定して実行する。

```sh
node plugins/sdd-quality-loop/scripts/v2/run-formal-gate.mjs --adapter tlc --mode strict --tla tests/fixtures/project-skills/formal-review-reservation/Reservation.tla --trace specs/verification-first-factory/verification/T-005/a7fc37b5-0595-468c-b9ca-547038838162/reservation-observed.ndjson --risk high
python3 tests/project-skill-formal.tests.py
```

| Reservation | 終了 | 異なる状態 | 深さ |
| --- | ---: | ---: | ---: |
| ベースライン | 0 | 15 | 8 |
| ロック無効・OneAccepted 違反 | 12 | 25 | 7 |
| 観測終点に到達・TraceIncomplete 違反 | 12 | 5 | 5 |
| Check 時点の観測を改変・終点未到達 | 0 (ゲート FAIL) | 2 | 2 |

仮定は同じ初期ハッシュを持つ申請者 2 人、各 1 試行、ローカルの原子的 mkdir/rename、同ロックを守る全ライター。競合再生を含む Python 6 件すべて成功。クラッシュ復旧、NFS と Windows の実ランナーはこの計測の範囲外。TLC のモデル探索、実装競合、判断ビューを個別に再現できる。

[実行ログ・変異の状態列・入力トレース](../../../specs/verification-first-factory/verification/T-005/a7fc37b5-0595-468c-b9ca-547038838162)。TLC / Apalache を導入して実行した共通テストは 10/10、スキップ 0。T-006 の `formal-suite.log` に失敗を期待した観測も含む。
