# snapshot mode 限定candidate検証

範囲: 非保護candidate領域のコード・テスト案と使い捨てfixtureのみ。正規ソースへの適用、Draft実装、契約変更、reservation、installed baseline変更は対象外。
Owner: /Users/jrmag/.codex/worktrees/rt002-bounded-integration/sdd-forge
HEAD: 1e86fb272643e798db4e1ca0c89f0402317a2fc8
既存dirty: tracked 12件、既存RT002 untracked成果物。全て保持。
Risk: high（共有snapshot実行権限とsource変更検出の境界）。
契約: REQ-007、task-input-manifest/v1、immutable snapshot。v1はmodeを束縛しない。candidateで正式契約は変更しない。

## candidate preflight

| 観測する項目 | 対応する提案契約 | failing mismatch case |
|---|---|---|
| 出力mode | 0444 OR (source AND 0111)、特殊bit除去 | 原版で0755入力が0444になる |
| 非実行入力 | sourceにない実行bitを付与しない | shebang付き0644を直接起動できたら失敗 |
| readonly | write/create/delete拒否 | fixtureへの書込が成功したら失敗 |
| source mode変化 | copy中変化はTASK_INPUT_HASH、公開なし | 同期点でmodeだけ変更し公開したら失敗 |

検証計画: 実際のUnix Bash/PowerShellで元コードRed→候補Green。原版builderにはcode変更せず、builder単独fixtureで比較。現在の実装manifest identity・費用証拠には流用しない。native Windows、CI、独立review、正規適用は未実施。

## 実測結果

環境: Darwin 27.0.0 arm64、uid 501（非root）、PowerShell 7.6.2 / .NET 10.0.8。GetUnixFileMode(SafeFileHandle)の実在をreflectionで確認し、候補で実行した。

| 対象 | 結果 | 証拠 |
|---|---|---|
| 元Bash builder | exit 1。22項目中6失敗（実行mask 5件と直接起動）、readonly等16成功 | red-bash.json |
| 元PowerShell builder | exit 1。同じ6失敗/16成功 | red-powershell.json |
| 最終Bash候補 | exit 0、25/25成功 | green-bash-final.json |
| PowerShell候補 | exit 0、25/25成功 | green-powershell.json |
| 既存Bash suite＋追加maskケース | exit 0。既存manifest/snapshot/fallback/selector回帰成功 | suite-candidate.sh |
| 既存PowerShell suite＋追加maskケース | fixture修正後exit 0。同じ既存回帰成功 | suite-candidate.ps1 |
| 4ファイル向けpatch | git apply --check exit 0。適用はしていない | candidate.patch |

両候補のGreenには0755→0555、0750→0554、0700→0544、0777→0555、0644/0600→0444、07755→0555、source不変、直接起動成功、非実行shebang入力のPermissionError、write/create/delete拒否、root0555を含む。copy完了直後・source再確認前の専用同期点でsourceのmodeだけを0755から0644へ変更し、TASK_INPUT_HASH・公開なし・一時tree cleanupを確認した。旧準備snapshotは変更していない。fixtureは証拠保全のためこのcandidate領域に残した。

suiteの観測stdout:

```text
ok: task context isolation manifests, snapshots, fallback, and selector are deterministic
ok: PowerShell task context isolation manifests, snapshots, fallback, and selector are deterministic
```

PowerShell追加fixtureのprintf改行を二重escapeしていたため、最初のsuite起動はdirect executable assertionで失敗した。builder不具合ではなくテストfixture誤りとして1回修正し、再実行で成功。Bash候補はWindowsの元chmod/検査方式を保持する条件を追記し、最終版で限定fixtureとsuiteを再実行した。修正ループは2回、残り1回。Windowsでの動作をこのmacOS結果から推定しない。

## 成果物と再実行

- builder-candidate.sh / builder-candidate.ps1: 正規ソースを変更せずに実行した候補。
- suite-proposed.sh / suite-proposed.ps1: 既存suiteへの追加テストを含む提案ソース。
- suite-candidate.sh / suite-candidate.ps1: 実行用コピー。ROOTをownerへ、builder参照をcandidateへ固定した2箇所だけがsuite-proposedとの差。validatorとselectorはownerの既存実装を使用。このrouting差分はcandidate.patchに含めない。
- candidate.patch: 共有builder対と既存suite対の4ファイル向け未適用差分。
- mode-regression.py: 独立した限定実験harness。allowed_inputsだけのbuilder fixtureであり、完全manifest validator、費用、実装identityの検証ではない。

全コマンドはownerでrtk proxy経由・login=false。再現形:

```text
rtk proxy python3 -B reports/verification/rt002-snapshot-mode-repair-20261006/mode-regression.py plugins/sdd-implementation/scripts/prepare-task-snapshot.sh --output <new-red-result>
rtk proxy python3 -B reports/verification/rt002-snapshot-mode-repair-20261006/mode-regression.py reports/verification/rt002-snapshot-mode-repair-20261006/builder-candidate.sh --race --output <new-green-result>
rtk proxy bash reports/verification/rt002-snapshot-mode-repair-20261006/suite-candidate.sh
rtk proxy pwsh -NoLogo -NoProfile -File reports/verification/rt002-snapshot-mode-repair-20261006/suite-candidate.ps1
```

PowerShell builder比較は上記.shを.ps1に置換し、別の新規result名を指定する。既存証拠を上書きしない。

## 残る正規手順・限界

正規4ソースは作業前の読取内容とbyte一致を再確認した。保護ファイルへの適用、正式契約更新、Draft task実装、reservation、installed更新、commit/pushは未実施。実拒否を別executorで回避していない。

candidateはUnixのsource execute maskを保持するだけで、manifest v1にmode provenanceを追加していない。copy後にmodeが変わり元へ戻る競合や、公開後のmode-only改変を内容SHAが検出すると主張しない。readonlyは同じ所有者によるchmodまで禁止するsandboxではない。

正規適用前に、共有high-risk修正としての契約addendum/対象scopeの承認、保護対象の再確認、独立diff review、native Windows検証、mode-raceケースの恒久suiteへの取り込みを行う。今回raceは限定harnessにあり、4ファイルpatchの恒久suiteにはまだ組み込んでいない。専用test barrierの追加もレビュー対象である。PowerShellのmode APIは今回runtimeで確認済みだが、supported runtime matrix全体は未確認。

以後は正規保護適用/readback→必要gate・exact-final-head CI→明示承認されたbaseline採用→RT002の新manifest/new snapshot/fresh実sessionによる再検証。candidate GreenはRT002受入・Done・新規実装identityの証明ではない。USD10は引き続き以前の暫定計画見積であり、実費・usage・支出承認ではない。
