# A21 round1失敗の既存復旧経路候補

2026-10-06。RELEASE_READY=False。正式admission・予約・レビューではない。

Owner `/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge`、HEAD `25813ee4baf8ae8fff344a6c979da61fbd23d2c7`。既存dirty work（保護review scripts/agents/skill、台帳、spec/tests、多数の履歴証跡）を保持。本作業はhigh-risk復旧の非保護候補準備のみ。新しい保護実装を追加しない。変更契約面は将来のhistory admission入力・launcher tool scope、必須検証は現行helperと通常precheck/単一予約/postflightで、後者は未実施。

## 既存経路

`fresh-review-recovery.py:250-266,317-333` の interrupted_transport_inventories がround1-only失敗を扱う。今回A21を新たなtransport inventoryに含め、A20 failed_final_round2を historical_failed_roundsへ移す。`SKILL.md:80-88` に従いtop-level transcriptは最後のmulti-round失敗A20のまま。A21をfailed_final_round1と偽装しない（`failed-last-attempt.py:65` は2/3のみ）。

同generic inventoryの `transport_required` (`fresh-review-recovery.py:267-278`) はlaunch-blocker-note.mdを必須とする。A21には実際の8ファイルがあり、このnoteがない。消去・名称偽装・optional扱いで迂回しない。

## 候補成果物

- `launch-reviewer-a.candidate.py`: 旧A21 driverを変更せず新規作成。path identityをA22へ変更し、custom agent.toolsへStructuredOutputだけ追加。通常permission/hook/read-only/raw-result検証は不変。実行していない。
- `launch-blocker-note.candidate.md`: 実A21拒否の追記用候補。旧roundに未配置。将来配置先はA21 round1/launch-blocker-note.mdであり既存8ファイルは一切変更不要。note SHA256 `67b5a2acc8bc042baec8de8e7fd7a96efed978137989a61b3cf129c70f215a8a`。
- `approval-audit-attempt22.candidate.json`: 実会話の包括承認を限定転記した候補。人間署名ではなく、現時点は候補準備・主担当確認待ちで正式実行をしていない旨を明記。
- `fresh-review-contract-attempt22.candidate.json`: 既存v2 schemaのみ。terminal7、連続partial8..21、historical_failed15/20、transport18/19/21、A21旧8ファイル＋未配置noteの9項目をexact hashで列挙。旧A21 authority/contractは編集しない。過去出力はdiagnostic-only、transition_legality not-established。

## 実検証と停止

現行原本helperをread-onlyでcandidateに実行しexit1:

`ERROR: fresh-review recovery: missing, symlinked or escaping evidence: reports/spec-review/epic-195-a7-compatibility/attempt-21/round-1/launch-blocker-note.md`

これは意図的に未配置のnoteを検出した実拒否。これ以降のcontract全体検証が成功したとは扱わない。旧round不変更の明示指示を守り、note配置・precheck・予約は行わず停止。

次に主担当が候補を確認し、旧8ファイル不変のままこの新規診断noteの追加を認めた場合に限り、配置→hash確認→現行read-only helper→通常precheckの順に進める。保護コードの変更は現時点で不要見込みだが、note以降の拒否を事前に成功扱いしない。full reviewer schemaのStructuredOutput実証も未実施であり、単純schema GREENを正式レビューへ転用しない。

## 続報: 通常 precheck 成功（2026-10-06T03:05:00Z）

上記の未配置による停止状態はこの続報で更新する。主担当が、旧 round 不変更は既存 bytes・判定の上書き禁止であり、未作成 note の正確な追加は許可範囲と明確化した。不存在と既存8ファイルの SHA を再確認後、`attempt-21/round-1/launch-blocker-note.md` を新規追加した。候補 note と同一 SHA `67b5a2acc8bc042baec8de8e7fd7a96efed978137989a61b3cf129c70f215a8a`。CLI0 / 非canonical raw result / postflight1 を記録し、失敗を判定として採用していない。

現行 read-only recovery helper は exit0。その後、通常コマンドを一度実行し exit0:

```text
rtk proxy bash plugins/sdd-review-loop/scripts/spec-review-precheck.sh epic-195-a7-compatibility 22 1 --reset --fresh-review-contract=/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge/reports/verification/a7-attempt22-candidate-20261006/fresh-review-contract-attempt22.candidate.json
spec-review-precheck: complete. Output written to /Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge/reports/spec-review/epic-195-a7-compatibility/attempt-22/round-1/
```

生成済み `attempt-22/round-1/precheck-result.json` は attempt22/round1/reset=true、status Pending、現在5入力 hash と contract SHA `503e689d960e16bddb83ca0ef7b5f90e195da74c1a8bef1d52db7eb31c2b62b4` を保持する。authority SHA `ef1655ffdf2cf833e83a0a36de40aa1e07391871b2297af2cc5f15f2593b3bdf`。これら admission 済み入力は以後変更しない。next-attempt helper / precheck の再実行も行わない。

### 保全・差分の最終確認

- A21 既存8ファイル全てが準備前 inventory hash と一致。追加 note を含む exact9 inventory も全て一致。旧 reviewer 出力の変換・再採用はない。
- 旧 A21 launcher SHA `7bee14812df9304ca5e9e7912025c4d3d665901bb6ff3890acfeb9d0b7b6329e`。旧ファイルは編集していない。
- 新 launcher SHA `c02a81c69d678ed7e80c2df8dbabfe852bb3871c0425d1ff540a91c040a3d6d0`。旧 source に対し round path A21→A22、invocation path a21r1→a22r1、custom agent.tools に StructuredOutput 追加、の3置換だけで byte 全体が一致することを assert した。Python compile も成功。末尾の余分な空行は候補だけから除いた。permission allowlist/disallowlist、CLI 引数、role prompt、schema、raw-result postflight は不変。
- 台帳 tip は sequence1210、A21 run `c933b018-5af0-4c78-b3ba-9a2d14c9d134` のまま。A22 invocation は存在せず、A22 round1 は precheck-result.json のみ。予約・配送・B 起動は未実施。

PRECHECK_OK=True。RELEASE_READY=False（この記録は正式起動許可・レビュー判定ではない）。主担当の契約確認後も、ordinary manifest/proposal/preflight、単一予約、fresh reviewer delivery、raw-result postflight が必要。単純 schema GREEN は tool 可用性の根因修復証拠に限定し、full reviewer schema 成功・正式 PASS を保証しない。保護コード追加編集、履歴上書き、拒否迂回はない。
