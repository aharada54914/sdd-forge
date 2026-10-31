# T-001 限定独立検証・残条件照合 — 2026-10-05

非正式の検証追補。正式SDDレビュー、quality-gate判定、Implementation Complete / Done の認定ではない。製品・テスト原本、凍結仕様、予約、判定、タスク状態は変更していない。今回Git操作は行っていない。testerスキルに従い、成功済みの同一validatorテストは再実行せず、SHA照合と不足範囲の限定実行を分離した。

## 隠しファイル修復の独立再確認

直前の独立再監査で以下を実行し、終了0、9 passed / 0 failed / 0 skipped / 0 pending / 0 inconclusive（812 ms）を観測した。今回の追補作成時には再実行していない。完全な生ログファイルは新設せず、実行ツール出力の観測記録をここに保存する。

```text
rtk proxy pwsh -NoProfile -Command 'Import-Module Pester -RequiredVersion 4.10.1; $result = Invoke-Pester -Script tests/sdd-domain/absence-regression.Tests.ps1 -PassThru; if ($result.FailedCount -ne 0) { exit 1 }'
```

環境: macOS / PowerShell 7.6.2 / Pester 4.10.1。今回読み戻したSHAは再監査対象および作者記録 `reports/verification/issue290-absence-regression-repair-20261005.md` と一致した。

| 対象 | SHA-256 |
|---|---|
| `tests/sdd-domain/absence-regression.Tests.ps1` | `4ee9884c16358837c02d56d695a347c5943b80eeafcf18fe99788ac40383e70a` |
| `plugins/sdd-quality-loop/scripts/check-domain-conformance.sh` | `fd3297986a682b619fcfe45fc03e8b2eef12b29dfd86bacfc4c736212139a8c7` |
| `plugins/sdd-quality-loop/scripts/check-domain-conformance.ps1` | `609b457dab5854420f171d398b1b23f0aec8ac018c9d175fdf56e04678472a97` |

両実ゲート後のファイル一覧は `Get-ChildItem -Recurse -File -Force` を使用する。新負例は `.unexpected-artifact` を作り、WindowsではHidden属性も付与し、一覧への包含と既存の厳密配列assertの失敗を確認する。前指摘「隠し追加ファイルを取りこぼす」は解消。追加指摘なし。GUID一時fixtureのみを変更し、finally / AfterAll で当該fixtureを片付ける。

証明範囲は、domain不在時のshell/PowerShell実conformance gateのskip出力、入力2件の不変性、余剰ファイル（hidden含む）の検出。bootstrapやdomain-syncの実ホスト動作、全生成物の同一性、旧sdd-domain AC-010全体、Windows native実行を証明しない。

## 今回追加した限定実行

T-001 Done Whenの「Phase 0 contract suites」のうちschema/byte-identityを明示的にPesterで確認した。`-File`のみの旧記録を全Pester成功と読み替えない。v2 suiteの非回帰closureにはGit実行がある（同suite:2150–2153）ため、今回のGit操作禁止に従い選択範囲に含めていない。単一suite全体の成功ではない。

```text
rtk proxy pwsh -NoProfile -Command 'Import-Module Pester -RequiredVersion 4.10.1; $a = Invoke-Pester -Script tests/sdd-domain/contract-schema.Tests.ps1 -PassThru -Show Summary; $b = Invoke-Pester -Script tests/sdd-domain/contract-v2-schema.Tests.ps1 -TestName "domain-contract.v2.schema.json shape*","domain-contract.v1.schema.json byte-identity drift lock*" -PassThru -Show Summary; Write-Output "SCOPE v1=$($a.PassedCount)/$($a.FailedCount) v2-shape-and-v1-lock=$($b.PassedCount)/$($b.FailedCount)"; if ($a.FailedCount -ne 0 -or $b.FailedCount -ne 0) { exit 1 }'
```

実出力・終了0:

```text
Tests completed in 212ms
Tests Passed: 8, Failed: 0, Skipped: 0, Pending: 0, Inconclusive: 0
Tests completed in 250ms
Tests Passed: 12, Failed: 0, Skipped: 0, Pending: 0, Inconclusive: 0
SCOPE v1=8/0 v2-shape-and-v1-lock=12/0
```

| 対象 | 今回SHA-256 |
|---|---|
| `tests/sdd-domain/contract-schema.Tests.ps1` | `5c1f3e5530a36fee1a55813ec711e910a1804510f44eb043198513ed45c4d912` |
| `tests/sdd-domain/contract-v2-schema.Tests.ps1` | `7b52aad3f22796bf604cb25e1082319db94a6013ceb268231188d492d5422fab` |
| `contracts/domain-contract.v1.schema.json` | `0ab46b74c1e2561431b42b76106698339e79cd64ce0513b02aec5527b8b73841` |
| `contracts/domain-contract.v2.schema.json` | `ad69c28f323e5c2f83e07b78c4f14461b4f7152193a9021c0a12c3e0285aba16` |

## T-001 Done Whenと現在証跡

現在 `tasks.md` raw SHA-256は `8e8c8dafa256652f3ac9adb77b4adf1a54a00bbb59d549bef95970adf6470e02`。T-001はApproved / In Progressであり、本追補はその状態を変えない。

| 条件 | 今回照合結果 / 残条件 |
|---|---|
| 署名付き正例、実validatorの署名負例、4分類のmd/json/input不一致 | 既存Bash113件・PowerShell112件の現行保存ログと `evidence-map.md`、`traceability-readiness-20261004.md` が対応する。今回再実行ではない。既存出力表示の存在だけを全TEST受入としない。 |
| 既存承認型・Phase 0契約回帰 | 現行署名driverの既存成功証跡に加え、今回v1 8件 / v2 shape・v1 lock 12件を実行。v2 suite全体とnative Windowsは本記録で未実行。 |
| Red→Green・実装独立レビュー・spec_revision/environment | 既存実装報告にRED履歴・GREEN・仕様SHAとmacOS環境あり。ただし独立した正式実装品質判定を新たに得ていない。狭いabsence再監査はその代替ではない。 |
| validator rollback | 既存6成功記録あり。rollback driver SHAは既存報告と一致。Git archiveを含むため今回再実行していない。bootstrap rollbackはT-003担当で未証明。 |
| validator側REQ/AC/TEST mapping | 既存T-001追補にあり。TEST-022、TEST-051–078のbootstrap/下流0回はT-003 pending。未来タスクの証拠を補ったfeature-root traceabilityを捏造しない。 |
| 正式task-plan再束縛 | 最新準備記録 `reports/verification/issue290-current-task-provenance-prep-20261004.md` は現行と同じraw task SHAで、task-plan stale / attempt-7 precheck ready / 未予約を記録する。今回はworkflow checkや正式precheckを再実行しておらず、現在の予約状態を網羅監査したものではない。古いPassedヘッダを現行束縛の代わりに使わない。 |
| 全Approved task IC後のQG | 現行Done WhenはT-001 IC前提ではなく後段条件と明記。T-002–T-006の実装・bootstrap証拠・完全feature mappingを経た独立QGが未完了。 |

SHA照合で変更なしを確認したvalidator側対象（既存 `reports/implementation/sdd-domain-concept-test/T-001.md` Outputsと一致）:

- approval-sidecar schema: `f205da8f1103fc2ac876e7fbff4dc6f89db4146325e65aadc15d139ffa4265e3`
- concept-test schema: `e9345fb3e07a57ec695a11531cac4b61989ad5b619993b3745b5f206cf090674`
- renderer: `5961db64004d32a4c58eef5945dd5b113510164a7dd312f4a347dcc071c459d4`
- validator: `5f1fe69df13bc90baac757aefa56e2e36c82a175b6db1000cee71592e22cbc74`
- Bash driver: `72511d69f5407e5f186beb3b32ebb8c5a0fa47b94807f319341f04429dad43e6`
- PowerShell driver: `a8ed8ee80504e1ff75fbe38c1f33e8a3e614b0c38906f38a88a2d6e19fa7eb09`
- rollback driver: `86994d944e75c1a2e0bea5833bc672d6de6064d3ac45e8a08afec49543b2e8da`
- current Bash log: `f5905ddfe3a54c23045c5c96f06a6faf182724086bc1e3ae512c202519e83f08`
- current PowerShell log: `b2786c3e8a156cf2ccb1e6e6cd221f45b764717c3b5a6964047a811090dd0c5e`

旧実装報告のplaceholder指摘は `reports/verification/issue290-minitems-audit-20261002.md:16` に解消記録があり、現行validatorの該当注釈も修復済み。未解決条件として再掲しない。今回placeholder checker自体は再実行していない。

次工程は、担当が現在の正規経路でtask-plan再束縛と実装独立レビュー準備を確認すること。過去の拒否は迂回せず、今回禁止された正式予約・判定は実行しない。v2全suiteの未実行部分を確認する場合はGitを含むclosureとその他の実fixture検査を分け、今回の8+12成功を全suite成功と表現しない。
