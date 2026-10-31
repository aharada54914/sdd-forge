# A7 impl attempt 5 provenance re-review preparation

Owner: `/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge`
HEAD: `25813ee4baf8ae8fff344a6c979da61fbd23d2c7`

既存承認内の高リスクimpl-stage証跡再束縛。実装変更なし。spec A22 PASS成立後、原本workflow-stateのimpl manifest staleを既存Post-Implementation Provenance Re-Review経路で扱う。impl-review-loop SKILL全文、両role全文、review-context-boundary全文を確認。Passedヘッダを維持し、A22専用nonTTY契約は転用しない。

実在attemptは1〜4、最新はattempt4 round3 PASS。attempt5の出力は不存在。親がこの担当を唯一のowner台帳writerとし、並行する予約担当なし。既存dirty変更（AGENTS、review scripts/roles/skill、spec、test、reports等）を保持。事前に旧impl記録とdesign/requirements/ledgerの73ファイルhashをメモリ内に採取。今回の予定書込みは新precheckとこの非凍結記録のみ。

必須検証: 原本 `impl-review-precheck.sh epic-195-a7-compatibility 5 1 --provenance-rereview`、成功時の `--verify-inputs`、旧記録・ヘッダ・台帳のhash不変。予約・正式起動前に親へ報告する。

## 実行結果

通常provenance precheck exit0。実出力:

```text
workflow-state: epic-195-a7-compatibility: stage-provenance: impl reviewer manifest input hash is stale
NOTE: impl-review-precheck: canonical workflow-state validation failed; proceeding under --provenance-rereview (impl-stage evidence re-binding in progress).
impl-review-precheck: complete. Output written to reports/impl-review/epic-195-a7-compatibility/attempt-5/round-1/
```

続けて `rtk proxy bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh epic-195-a7-compatibility 5 1 --verify-inputs` はexit0、`impl-review-precheck: inputs verified for reviewer invocation.`。上のadvisoryは既存skillと原本scriptの明示経路であり、手動迂回ではない。

precheck SHA: `ca6e38c657c17627da4ac5e9043fb0c94c40d8062dc6b91a45d2a91685e60bfc`。input SHA: `610543f9607c393dcb441c37ad3bfd7058806e7dda706600fc5cbe9793a53be6`。legacy_design=false、design_req_drift=false、adr_inputs=[]。全4layer hashを保持。旧73ファイルのSHAが全て事前値と一致。Passedヘッダと台帳不変。

## 配送前の正規経路と実host契約

impl skill STEP2/4は別々のfresh独立agent、Sonnet role、read-only、file-manifest、fallback noneを要求する。Aは現行spec8点（requirements/acceptance/design/4layers/investigation）＋calibration＋当round precheckの10点、Bは同10点＋Aのcounts/check IDsのみのsanitized summary。adr_inputsは空なのでADRを追加しない。各起動直前にverify-inputs、現行台帳に結合したone-role invocation、通常validator --reserve成功の順。receiptのallowed-inputs-v1 digestも検証する。旧raw reviewer出力を入力にしない。

実hostの `claude --help` は `--agent`/`--agents`、`--model`、`--session-id <uuid>`、`--bg`、`-p`/`--output-format`を提供する。これはCLI機能の読取確認だけで、impl正式配送成功の証拠ではない。impl skillにはA22 spec専用のcaller-UUID nonTTY preflight/postflight例外はないため、そのvalidatorや成功receiptを転用しない。起動するなら独立roleの実host sessionを割当・確認し、通常起動契約と読取専用制約を満たした上で予約と配送する。現時点ではhost session割当・予約・reviewer起動は未実施。

TYPE-H収束規則は旧PASSとbyte同一（許可されたstatus等の差のみ）の範囲に限定し、変更済みartifact全体に自動適用しない。TYPE-Dは不変。完了時は統合契約だけでなく原本workflow-state exit0が必要。今回precheck成功をimpl PASSやA7 Doneとはしない。
