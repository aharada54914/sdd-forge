# Major1 限定追加修正記録

Owner `/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge`; HEAD `25813ee4baf8ae8fff344a6c979da61fbd23d2c7`。
2026-10-06の追加限定修正承認に基づく候補修正1回。従前3/3履歴を保持し、今回承認を別記する。High-risk recovery evidence boundary。dirty treeにはAGENTS、review scripts/skill、A7 specs、ledger、その他testsの既存変更と多数の報告原本がある。これらを変更しない。

対象は候補failed-last-attemptのmalformed診断分岐のみ。検証予定：新negativeをRED確認後、既存52件＋新negative、共有native_delivery/postflight差分不変確認、patch再生成・原本hash読戻し。persisted verdict/approval/identity fieldsは追加せず、完了条件は最終meaningful user/assistant event=assistant end_turn。counterpartは提案step3、mismatch negativeはend_turn後の未回答tool_result。

## 結果

coder/sdd-verification-applyとcheckout AGENTSを再読。原本やformal gateを変更せず候補＋disposable fixturesに限定した。

RED: `rtk proxy env PYTHONDONTWRITEBYTECODE=1 python3 reports/verification/a7-attempt21-recovery-candidate-20261006/recovery.tests.py` exit1。追加negativeが `AssertionError: unanswered tool-result after end_turn unexpectedly accepted` となりMajor1を再現。fixtureのtranscript pinだけを再計算、owner証拠は変更しない。

最小修正：`failed-last-attempt.candidate.py:210-213` の最後のassistant選択を、最後のmeaningful user/assistant event選択へ置換。最終eventがassistantかつend_turnを要求。共有 `native_delivery` は診断と通常postflightの両方に使われるが、そこには変更を加えない。普通postflight・preflight・旧truncated分岐も今回不変。

GREEN: 上記command exit0、19件PASS。`rtk proxy env PYTHONDONTWRITEBYTECODE=1 python3 reports/verification/a7-attempt21-recovery-candidate-20261006/additional.tests.py` exit0、34件PASS（同内部は新19件もcaptured stdoutで実行）。既存52件＋新1件の合計53種類。full A21のvalidate、sh/ps1 canonical contract・lock再検証、通常JSON postflight、旧truncated検証も通過。新negativeの拒否文は `native failed turn did not end`。

最終hash:

- failed candidate `438431a8f75ff83d302413ed69c8d66bf0b44aab80d5d7c1ab72cb55b1e74dc5`
- fresh candidate（不変）`7c61cfdfb92cf885a974881d3264418ef09f10264db2eb87701237cc15cfb6c1`
- nontty candidate（不変）`fe5274cf4f49c324c6ef05efaf079c2d66ab11b05af3ef08e60ffe63b6b71b64`
- 再生成patch `bc99b48a357ac3209a20242ce06facc6bb09fa2bf620ca43f99a85480e78834c`

原本3hashはstatus記録と一致：failed `e08110df5b23723ed31de141894bd47e8cdc12ee062ad49cb9496d2064117b5f`、fresh `88a2775809e587008d2aefdd9b05f1aaef1fde6b0a3e604b6249d4c2a3e1e037`、nontty `fcebcf252957ec4a0ff47879f5b0096d770fc9a59f30c2130c75c006d9c57abd`。

今回限定修正1回終了。独立再レビュー・正式レビュー・原本適用・予約・native launch・CIは本修正では実施していない。旧independent-candidate-review.mdのNEEDS_WORKを上書きしない。52件時点のhashは履歴であり本修正後の証明ではない。
