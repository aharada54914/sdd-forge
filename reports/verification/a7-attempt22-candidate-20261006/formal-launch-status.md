# A22 formal launch status

2026-10-06。Owner `/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge`。

主担当が実承認auditとreadinessを確認し、包括承認内の正式A22実行を指示した。入場済みcontract/audit/precheckは変更・再実行していない。現行spec-review-loop skill全文を再確認し、親はこの担当をownerの唯一の台帳writerに指定した。

予約前にrecovery contractの全evidence hashを再検証した。旧A21既存8ファイル、旧launcherを保持。A22 launcherは旧launcherのround/manifest identity2箇所とcustom toolsへのStructuredOutput追加だけという既証明hashと一致。通常permission、deny、role、schema、raw-result検証を保持。表示文言の旧A21は実identityに影響しない。

## Reviewer A: 完了・adopted

- UUID/run/session: `6891e8e7-cb0c-463c-8635-a28bab50b0ca`。
- 通常5入力manifest、nonTTY PREFLIGHT_OK、caller-proposalを予約前保存。proposalはhost acceptanceではない。
- 通常reserve1回: sequence1211、record `468d06dae7296c47456551ef25ac4f56714a6858a8c098ba21d8c5b2f546df97`。
- fresh Sonnet CLI1回、exit0。通常postflight `DELIVERY_OK`。prompt4065 bytes SHA `a1e84d8def23465073c49225918e835171beba4fe9f278d28b9c361aa4e24c3d`、native SHA `2050660296c720fa932398d16c3a4fee6ddd9ba790655a3bf09a7b74020ed4f5`、wrapper SHA `a6435749558b8181ab7a44f4acbf3060471b5848fcb40783a4935c0034ebeeb7`。
- wrapper.resultはraw JSON、structured_outputと同値、is_error=false。変換・fence除去なし。
- 原本spec-review-precheck.shの `validate_reviewer_output` 関数とpath正規化定義をそのままread-only実行。schema/manifest/identity/チェック順/coherence検証exit0後、rawをreviewer-a.jsonへ保存。
- A verdict PASS、6 PASS/1 DOMAIN-CONFORMANCE SKIP。sanitized summaryはID/result/severityと件数のみ。raw findingはBへ渡さない。

## Reviewer B: 配送開始記録

- 別fresh UUID/run/session: `1c1e3233-25a2-4756-ad9f-1ef6ba363483`。
- 通常6入力manifest（Aと同じ5点＋sanitized summary）、nonTTY PREFLIGHT_OK、caller-proposalを予約前保存。
- 通常reserve1回: sequence1212、record `859f684752e74d70ef9fba5f9f4706a5d3d4ab3e85b216a65da6d163b6bc6453`。
- B driverはA22 driverからrole/output/invocationのB identityと表示文言のみ変更。B role原本を使用。fresh Sonnet CLI1回を配送中。

統合verdict/contractとstatusは未変更。B結果を未確認のままPASSと扱わない。CLI拒否やpostflight拒否では再配送しない。

## 完了追記（上記配送開始時点を更新、旧記録は保持）

- B CLI exit0、通常postflight DELIVERY_OK。prompt SHA `3fb3650826ca0e44e36823dfc6fef101c4e2e5a695865119de68b93a9fb46b3c`、native SHA `1d3a21446cb7b0af185e65eec5cb716bdf07cf6383322edbad7323b7361d0f71`、wrapper SHA `77e640b96418259d94c321751c45cf2dd5b1ca03f7b62cb141dbd0203ec59f9a`。raw JSONとstructured_output一致、is_error=false。原本validate_reviewer_output exit0後のみraw採用。
- A/Bとも6 PASS、0 FAIL、1 DOMAIN-CONFORMANCE SKIP。統合PASS、Critical/Major/Minor各0、warningCount0。Bの非blocking proseを改変・FAIL化していない。
- 実親が `rtk proxy uuidgen` でこの統合作業に採番したorchestrator run_idは `1363d80d-5913-487d-b5ac-107a3aa06138`。親の実host context（CODEX_THREAD_ID）は `01a06d01-11b5-7bd3-83a3-7e29bb3c96cd`。後者をfresh run_idと称していない。
- templateからintegrated-verdict/contract/reportを作成。原本spec-review-precheck.shのvalidate_contract関数と依存定義をそのままread-only実行してexit0 `ORDINARY_FULL_CONTRACT_VALIDATED`。入場済みprecheckを再実行していない。
- integrated-verdict SHA `16c42f89d39a618449abbdc9a9debbca6309a112a511220d903174a0663ee131`、spec-review-contract SHA `052903fb8316a28f29016f8a47589d734ccc18aede2b920fee5b6a67ada6c987`。
- 全入力検証後、requirements.mdのSpec-Review-StatusだけPending→Passed。読戻しraw SHA `f188aef257cb4afd5f0185aeff010d0fae6ee665f9aa2d0fbbb9ee2031c88c46`。PassedをPendingに1箇所だけ戻したbytesのSHAは入場時 `492f54a812be75ca20d0a05ec41dcf225f9b1b17cd512148498e02cf954dd96c` と一致。
- recovery contractの旧history evidence134点、A21 launcher、入場contract/audit/precheckはhash不変。台帳tipはBのsequence1212。再予約・再配送なし。

## 原本workflow-stateと次工程（read-only確認）

実行: `rtk proxy bash plugins/sdd-quality-loop/scripts/check-workflow-state.sh --feature epic-195-a7-compatibility`

exit1、stderr: `workflow-state: epic-195-a7-compatibility: stage-provenance: impl reviewer manifest input hash is stale`

A22 spec gate成功とこの下流拒否は別。原本consumerはmanifestのplugin hashを1433–1435行、その他の入力hashを1453–1455行で検査する。既存impl attempt-4/round-3のmanifestには旧calibration（a73f2b86…）と旧spec入力hashが残り、現行calibrationは537f7765…。design.mdの既存Passed表示だけでは新入力の設計レビューを証明しない。次工程は現行impl-review-loop契約に従うfresh実装方針レビューの準備・入場確認であり、既存contractのhash置換ではない。今回追加の保護変更・予約・実装方針レビュー起動はしていない。保護コード修正が必要との根拠は現時点ではない。

A7全体Done、task/quality gate、CI、merge完了とはしない。
