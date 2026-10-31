# snapshot mode candidate: 3回目の限定修正

この記録はevidence.mdの「mode-raceの恒久suite化が未完了」を更新する非凍結addendum。旧patch・旧実測JSON・旧suiteコピーは上書きしていない。現候補はcandidate-v3.patch。builder候補2本自体は前回の最終版から変更していない。

## 差分

- Bashの追加execute-maskテストとcopy-mode raceだけをUnix限定化。既存 tests/task-plan-binding-durability.tests.sh:29-33 の uname / MINGW・MSYS・CYGWIN 判定を使用。Windows系では新規2ケース群が非該当である旨をSKIP出力し、既存suite部分は引き続き実行する。
- Bash/PowerShellの既存suite向け提案に、SDD_TEST_SNAPSHOT_COPY_BARRIER_DIRの恒久回帰を追加。copy完了後・source再確認前で同期し、source execだけを0755から0644へ変更する。TASK_INPUT_HASH、final snapshot不在、一時tree cleanupをassertする。同期点未到達・子process timeoutは失敗とし、子processを片付ける。
- PowerShellの新規ケースは既存どおり -not $IsWindows 条件内。Windows非該当は明示SKIP。新framework・dependency・正規source変更なし。

## workflow/caller確認

現行 .github/workflows/test.yml:68-84 のposix-unwired-shardedはubuntu-latest。tests/suite-inventory.posix:33 がこのBash suiteを登録し、tests/run-ci-unwired.sh:120-144 が未配線suiteを選択してbash起動する。

.github/workflows全体でtask-context-isolationとrun-all.sh/ps1への直接参照を探索した結果、run-all.shへのコメント（test.yml:21）以外の直接呼出しは確認できなかった。したがって現行Windows Git Bash CIがこのsuiteを実行しているという証拠はない。tests/run-all.sh経由の手動実行や将来のcallerに備え、Unix専用assertをguardした。CIにWindows matrixが存在するだけでこのsuiteのWindows実行済みとは扱わない。

## 実測

前回と同じDarwin arm64、uid 501、PowerShell 7.6.2 / .NET 10.0.8。以下はownerでrtk proxy、login=false。candidate suiteのROOTとbuilder参照の2箇所だけを実験用に固定し、正規validator/selectorは変更していない。この実験routing差分はpatchに含まれない。

| コマンド末尾 | 結果 |
|---|---|
| bash reports/verification/rt002-snapshot-mode-repair-20261006/suite-candidate-v3.sh | exit 0。追加mode-raceと既存回帰を通過 |
| pwsh -NoLogo -NoProfile -File reports/verification/rt002-snapshot-mode-repair-20261006/suite-candidate-v3.ps1 | exit 0。同上 |
| git apply --check reports/verification/rt002-snapshot-mode-repair-20261006/candidate-v3.patch | exit 0。適用なし |

観測stdout:

```text
ok: task context isolation manifests, snapshots, fallback, and selector are deterministic
ok: PowerShell task context isolation manifests, snapshots, fallback, and selector are deterministic
```

実行結果メタデータはsuite-results-v3.jsonにも保存。旧Red/Green JSONはそのまま残した。今回の追加修正で3回上限に達したため、残り修正回数0。

## 未実施・残る境界

Windows native/Git Bashの実行、Linux CI、独立diff review、正式契約addendum、保護適用/readback、installed baseline採用、RT002本体の新manifest/snapshot再検証は未実施。Windows非該当の分岐をmacOSから実行済みPASSに置き換えていない。manifest v1はmodeを束縛せず、公開後のmode-only改変検知は保証しない。

正規ソースは変更せず、reservation・status変更・commit/pushもしていない。今回の候補実験はDraft task実装や正式な品質ゲート判定ではない。

## SHA-256

```text
bf8e953961f5a8697c52e99de21fdb840627fcd9eaee1b92e761a6bcff759d49  candidate-v3.patch
fd1ea6bce8b3cb8b4aad1d58426649fcbab74f32c8be4fe7bb63b276c56ec5d1  suite-proposed-v3.sh
ef3954581c1578914943e43cc3f73fd2bfd9e50ccd0d1f0355c632b25da8a1ae  suite-proposed-v3.ps1
```
