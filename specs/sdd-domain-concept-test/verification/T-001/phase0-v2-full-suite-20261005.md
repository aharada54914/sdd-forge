# Phase 0 v2 全suite実行 — 2026-10-05

非正式の検証記録。T-001のPhase 0回帰確認に限る。SDDレビュー、quality-gate判定、タスク状態変更ではない。

## 実行範囲・安全性

`tests/sdd-domain/contract-v2-schema.Tests.ps1` の全Pesterケースを選択除外なしで実行した。事前に起動・ファイル操作・外部プロセス・Git利用箇所を読み、GUID付きtemp fixtureと一時runner以外への書込みがないことを確認。validator twinsは入力読取りのみ。suiteのGit操作は `git diff --name-only main...HEAD` （2153行）の読取りであり、init/commit/push/branch変更はない。suite内のv1 fresh-process検査も実行対象。元ファイルは編集していない。

testerスキルに従い、旧限定12件だけでは未確認だった実validatorの構造・参照・parse・anchor・case-key負例、78fixture parity、全suite非回帰closureを今回実行した。

## 固定入力

下記SHA-256を実行直前・直後に測定し、全件一致した。コピーへ置き換えず、ownerの現物を実行した。

| ファイル | SHA-256 |
|---|---|
| `tests/sdd-domain/contract-v2-schema.Tests.ps1` | `7b52aad3f22796bf604cb25e1082319db94a6013ceb268231188d492d5422fab` |
| `tests/sdd-domain/contract-schema.Tests.ps1` | `5c1f3e5530a36fee1a55813ec711e910a1804510f44eb043198513ed45c4d912` |
| `plugins/sdd-domain/scripts/validate-domain-contract.sh` | `4613aacd33ed9c30956f218374a300503e25ddfa936e478759ca2a1253e152e4` |
| `plugins/sdd-domain/scripts/validate-domain-contract.ps1` | `2de062d711ccf860a6216a4a288cf37cb62d93bf980ce998609c22c7d15ecdbc` |
| `contracts/domain-contract.v1.schema.json` | `0ab46b74c1e2561431b42b76106698339e79cd64ce0513b02aec5527b8b73841` |
| `contracts/domain-contract.v2.schema.json` | `ad69c28f323e5c2f83e07b78c4f14461b4f7152193a9021c0a12c3e0285aba16` |

読取り比較に用いられるGit refsも前後一致:

- HEAD: `badbb7aa5d16114be542c33018967c58770d1a41`
- main: `493ff5a84da4ab993dcdceb8cf5d07927ae45db1`

## 実行結果

macOS / PowerShell 7.6.2 / Pester 4.10.1、ownerルートで以下を実行。外側シェルは `login=false`。

```text
rtk proxy pwsh -NoProfile -Command 'Import-Module Pester -RequiredVersion 4.10.1; $r = Invoke-Pester -Script tests/sdd-domain/contract-v2-schema.Tests.ps1 -PassThru -Show Failed,Summary; $r.TestResult | Where-Object { $_.Result -ne "Passed" } | Format-List Describe,Context,Name,Result,FailureMessage; if ($r.FailedCount -ne 0) { exit 1 }'
```

終了コード0。捕捉された全出力:

```text
Tests completed in 143.33s
Tests Passed: 319, Failed: 0, Skipped: 0, Pending: 0, Inconclusive: 0
```

失敗・skipはなく、今回根因調査を必要とする不具合は観測されなかった。これは成功時に個別ケースを表示しない実行設定であり、319件の詳細生出力を保存したという意味ではない。

## 証明の境界・残条件

`independent-absence-and-readiness-20261005.md` の「v2全suite未実行」は本記録で解消。ただし旧Phase 0の当該suite全体の成功であり、`tests/sdd-domain/` 全12ファイルの一括実行ではない。非回帰closureのGit assertionはコミット済み `main...HEAD` を見るため、dirty変更全体の無変更証明でもない。

319成功はnative Windows、Phase 1 bootstrapのTEST-022/051–078下流0回、現行task-plan正式再束縛、独立実装レビュー、最終feature traceability、quality-gate、CI・統合の証明ではない。これらを新たに完了とはしていない。保護拒否の迂回、正式予約、判定、承認・状態変更、既存Git状態変更は行っていない。
