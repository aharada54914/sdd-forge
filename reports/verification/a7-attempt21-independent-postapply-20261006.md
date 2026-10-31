# A7 A21 human適用後の独立検証

限定artifact/行動検証であり、正式SDD verdictではない。予約・レビューlaunch・原本追加編集なし。

- Owner: `/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge`
- HEAD: `25813ee4baf8ae8fff344a6c979da61fbd23d2c7`
- Scope/risk: A20失敗履歴の診断的quarantineとA21 admission、4保護対象、高リスクのevidence/identity境界。
- 既存dirty changesはAGENTS、role/precheck、ledger、A7仕様、tests等に広く存在。保持し、本検証は非凍結の本報告と再実行driverのみ追加。
- 根拠: `a7-attempt21-recovery-candidate-20261006/human-command-release.md`、`four-target-package.md`、適用後 `spec-review-loop/SKILL.md`、`docs/development-policy.md`。

## Apply/readback

ユーザー提示backup `/private/var/folders/7z/hjmz6jdj4wb40srf64sl368w0000gn/T/a7-a21-human-backup-cjoebiuw` の4preimageと現在原本の4postimageを独立SHA256再計算。全てrelease packageの期待値に一致。

| 対象（plugins/sdd-review-loop/相対） | current SHA256 |
|---|---|
| scripts/failed-last-attempt.py | 438431a8f75ff83d302413ed69c8d66bf0b44aab80d5d7c1ab72cb55b1e74dc5 |
| scripts/fresh-review-recovery.py | 7c61cfdfb92cf885a974881d3264418ef09f10264db2eb87701237cc15cfb6c1 |
| scripts/validate-nontty-spec-launch.py | fe5274cf4f49c324c6ef05efaf079c2d66ab11b05af3ef08e60ffe63b6b71b64 |
| skills/spec-review-loop/SKILL.md | 2b7763cb3b49c5fad4a82b677b70a9d336f0edbd9ed9731e8cafb76584635e3b |

## 行動回帰

現在原本をsourceとする再実行driverを追加。候補時PASSを転用せず、既存19+34ケースのcandidate source参照だけをメモリ内で原本pathに差し替え実行。fixtureは原本byteをコピーして隔離実行する。owner上の本番precheck実行とは区別する。nested recovery testsも同じ差し替えを適用。

コマンド（owner cwd、login=false）:

```text
rtk proxy python3 -B reports/verification/a7-attempt21-original-path-regression-20261006.py
```

同一driver本体による初回実行exit 0、53 unique cases成功（additional内部で19件を追加再実行）。確認済み: unanswered trailing tool-result拒否、旧truncated positive/negative、通常fenced postflight拒否/raw JSON transport成功、current mismatch、歴史pin改変、complete-round allocation必須、Bash/PowerShell canonical validator・lock・replay拒否、隔離full A21 copied-history admission。合成authorityはfixture専用で、実承認ではない。

ledgerは前後とも `ff87c248649b9a2a52081ba7405ea58fd9712b29d2a5aca0fdb1743460bca3e0`。ownerの予約/判定を書き換えていない。

## 実A21 precheckと未完了事項

現時点、実A21のimmutable fresh contract/approval auditは未作成。提案書とfixtureの合成authorityは代用不可。適用後skillのSeparately authorized recovery節に従い、主担当が実会話承認を転記したaudit、current5hash、failed_turn_sha256、transport_inventories_sha256、全歴史証跡pinを持つ実contractを準備する必要がある。

その後の通常command形:

```text
rtk proxy bash plugins/sdd-review-loop/scripts/spec-review-precheck.sh epic-195-a7-compatibility 21 1 --reset --fresh-review-contract=<実contractの絶対path>
```

owner precheckは未実施。既存destinationの確認後に1回だけ実行し、同じowner roundへ両runtimeを重複実行しない。precheck成功は予約でもformal PASSでもない。主担当へ条件を報告し、予約/正式launchは未実施。native host、正式独立review、quality gate、CI、mergeは未検証。sdd-verification-applyに従い適用・行動回帰・formal admissionを分離した。

## 続行記録 — 2026-10-06T02:47:29Z

上節の未準備/未実施はこの追補で更新。主担当から実契約作成と通常precheckまでの明示指示を受けて続行した。回帰driverの保存後再実行もexit 0、53 unique cases成功。

`a7-attempt21-formal-20261006/approval-audit-attempt21.json` は、主担当が確認したユーザー発言「全部承認する」「追加で何回でもレビュー、限定修正して良い」と今回のhuman適用receiptを委譲転記した。人間署名、sudo、host証明ではない。A21新規round 1と歴史quarantineのみへscope限定。SHA256 `d451e77d1054d263c8138895aa4c14da415f8f759abb696c9c844eba785edd77`。

旧A20契約の全evidenceを現物hash照合し、不一致なし。旧pinを保持して旧authorityのみ新authorityへ置換。A20r1/r2現物inventory、3 invocation、外部blocker、native transcript byte同一copyを新規追加。現仕様5hashを再計算し、新failed_turnとtransport inventoryのcanonical JSON digestをauditへ固定した。既存出力/履歴を書き換えていない。

実契約 `a7-attempt21-formal-20261006/fresh-review-contract-attempt21.json` のSHA256: `4182c9fe9ef314f4d02ef4652301011a0998e7d34a9b85829b4de18df506b32d`。適用後原本 `fresh-review-recovery.py <owner> epic-195-a7-compatibility 21 <contract>` read-only validateはexit 0。合成authority不使用。

次に上記通常Bash precheckを実contract絶対pathで1回実行しexit 0:

```text
spec-review-precheck: complete. Output written to /Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge/reports/spec-review/epic-195-a7-compatibility/attempt-21/round-1/
```

round 1の現物は `precheck-result.json` のみ。contract path/hash、current input hash `a301b63ca7888eeb4475f93bd47c0340ddd3646819006e8e32726bb7100e68e1`、Pendingをreadback確認。ledgerと4原本hashは上記値のまま。ownerでPowerShell二重precheckはしない。

主担当が実契約の独立差分確認を担当するため、この契約作成は自身による独立review済みと主張しない。次はfresh reviewer用のordinary manifest/proposal/preflight/reservation/first-turn手順であり、未実施。すでにattempt 21が存在するため、このadmissionを再実行/replayしない。正式review/quality gate/native host/CI/mergeは引き続き未検証。
