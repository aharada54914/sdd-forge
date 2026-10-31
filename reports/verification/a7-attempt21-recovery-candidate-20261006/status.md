# A21 candidate implementation status

Candidate only. Owner `/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge`; HEAD `25813ee4baf8ae8fff344a6c979da61fbd23d2c7`. Scope is the recovery proposal in the sibling `a7-attempt21-recovery-proposal-20261006.md`. Existing dirty changes are retained. No protected source, skill, frozen spec, ledger, reservation or verdict was written.

Three source candidates and `candidate.patch` implement an explicit malformed-result diagnostic branch, a shared native delivery check preserving ordinary postflight parsing, one additional closed recovery-contract key combination, and scoped failed-turn approval hash binding. No native launch or prior output adoption occurs.

Executed: `rtk proxy python3 reports/verification/a7-attempt21-recovery-candidate-20261006/recovery.tests.py` from the owner checkout. Final exit 0; 18 cases: one retained-record diagnostic acceptance and 17 negative cases. Exact stdout is in `regression.stdout.txt`. All copied owner records are placed in disposable temporary trees; fixture mutations occur only there.

Correction loop: initial reproduction rejected A20r1's existing transport inventory. Correction 1 adds the exact closed successful non-TTY inventory only for the new mode. A subsequent harness failure came from the macOS `/var` alias; correction 2 resolves the temporary root before the canonical-path validator. Final regression succeeded; no further correction used. The proposal records the completed-round inventory delta.

Confirmed by this regression: retained A20r2 diagnostic binds complete native first turn, reservation receipt, precheck/manifest, canonical ledger and prior NEEDS_WORK identity records; normal postflight continues rejecting fenced output. Malformed mode rejects valid JSON, wrong/error wrapper, non-string result, extra human user turn, unfinished/wrong native session, current-input/manifest/ledger mismatch, extra/missing evidence, changed transcript pin, preceding PASS and use of old mode with new evidence.

Not run: full `fresh-review-recovery.validate()` end-to-end contract/authority/inventory admission; complete-round contract validator; old truncated fixture full suite; normal valid-JSON postflight success; duplicate JSON wrapper case; shell/PowerShell precheck and lock parity; installed native host; independent diff review; formal review/quality gate; exact-HEAD CI. Those remain required before application. This is not a full admission PASS or A21 permission. The canonical-ledger validator was exercised directly after candidate inspector on every fixture; it is not replaced by the native helper's lighter header check.

Original source SHA-256 (current readback):

- `failed-last-attempt.py`: `e08110df5b23723ed31de141894bd47e8cdc12ee062ad49cb9496d2064117b5f`
- `fresh-review-recovery.py`: `88a2775809e587008d2aefdd9b05f1aaef1fde6b0a3e604b6249d4c2a3e1e037`
- `validate-nontty-spec-launch.py`: `fcebcf252957ec4a0ff47879f5b0096d770fc9a59f30c2130c75c006d9c57abd`

Candidate SHA-256:

- `failed-last-attempt.candidate.py`: `d58ea713d87099c5f600916bc8bc8ee0534f1e93966b68d980ce698dc618ace8`
- `fresh-review-recovery.candidate.py`: `069eb9304c4ad166ae83a8f61cc55e62d952fcb19245981ddf8dc03df79d8d48`
- `validate-nontty-spec-launch.candidate.py`: `fe5274cf4f49c324c6ef05efaf079c2d66ab11b05af3ef08e60ffe63b6b71b64`
- `candidate.patch`: `f76011ae7bee387a900b80e2e234029e103a17f7144d07df16a482fe252a12a3`

Next safe action: independent bounded candidate diff review followed by missing isolated admission/old-mode/ordinary-success regressions; no original-source application or reviewer reservation follows automatically.
# 最終追加検証（2026-10-06）

修正枠3/3消費済み。候補のみ、原本不変。historical callerのみ当時固定precheckから入力hashを渡す最小修正を追加。直前failedround=current一致は不変。提案書の最終追補参照。

`rtk proxy python3 reports/verification/a7-attempt21-recovery-candidate-20261006/additional.tests.py`: exit0、34 PASS。`recovery.tests.py`: 再実行exit0、18 PASS。full A21は原本の全履歴コピー＋synthetic authorityを使用して候補validateとsh/ps1双方canonical completed-round contracts・lock再検証まで通過。履歴precheck/manifest改変は元pin不一致で拒否。A20r1 exact23既存canonical検証通過。通常rawJSON delivery成功、fenced拒否不変、duplicate wrapper拒否。旧truncated18件通過。completedround allocation必須不変。

full A21の最初の拒否は過去A15 inputと現在A20r2 inputのcategory mismatch。拒否を迂回せず当時hash固定precheck・manifest・ledger比較へ限定修正。最終fresh candidate SHA256 `7c61cfdfb92cf885a974881d3264418ef09f10264db2eb87701237cc15cfb6c1`。更新patch SHA256 `acc253dc8ac375e97035da3e8ffbaac32393f7fc881de7933e5e4d846f8d1c5e`。前段にある旧candidate/patch hashは最終hashとして使わない。

保護原本3ファイルのhashは既存status記録から不変。予約・台帳・approval・判定原本・凍結仕様変更なし。正式適用・native launch・独立レビュー・CI未実施。これらをPASS扱いしない。
# Major1追加限定修正（最新）

2026-10-06追加承認により候補malformed分岐の最終meaningful eventをassistant/end_turnへ限定。新negative RED→GREEN、既存52＋新1＝53種類PASS。今回限定修正1回終了、過去3/3履歴保持。詳細・最終hashはmajor1-repair.md参照。最新patch SHA256 `bc99b48a357ac3209a20242ce06facc6bb09fa2bf620ca43f99a85480e78834c`。原本・ledger・approval・予約・判定変更なし。独立再レビューは主担当へ引継ぎ、正式PASSではない。
