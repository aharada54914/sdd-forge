# PR #531 PowerShell deadline recheck evidence — 2026-09-29

Issue #427 / PR #531 の承認済み根本原因修正のローカル検証記録。
凍結仕様、tasks、承認、review/quality-gate判定は変更しない。
承認済みの通常完了2000ms余裕（4秒budget）は維持し、別途、実プロセスの
再確認競合を各runnerで5回検証する。PowerShellの制御した競合は、凍結
TEST-004(c)の「約2秒で自然終了」という元の時刻条件の実測証明ではない。
先行のcompletion addendumの
「No production timeout or runner behavior changes」はその時点の記録であり、
以下の今回の本番条件修正を記述するものではない。

## 根本原因と最小変更

`acceptance-tests.md:60` と同ファイルのruntime表は、既に正常終了した子を
timeoutとせず成功結果を残す(c)を両runtimeで要求している。
Bashの `lib/panelist-common.sh:94` / `:98` は期限後に完了/死亡を再確認する。
本番の全呼出しは `run-panelist-gpt.sh:292` / `:299` と
`run-panelist-gemini.sh:168`。PowerShellは各runnerに1つの共通実行経路があり、
GPT `:261` / Gemini `:172` の実timed wait後、GPT `:265` / Gemini `:176` で
同じProcessの `HasExited` を観測していたが、falsewaitのみでtimeoutにした。

両PS runnerのtimeout条件を `-not $waitCompleted -and -not $observedExited`
へ変更し、成功経路のログには実際のwait結果を記録する（各runnerの2行のみ）。
絶対deadline、600秒default、`Kill($true)`、非ゼロexit拒否、完全JSON検証は維持。

## 永続した実プロセス再現

`tests/cross-model.tests.ps1:262` のテスト専用launcherは標準の
`Set-PSBreakpoint` により、本番の実timed waitがfalseになった後、
`HasExited` の直前だけを停止する。実Python stubをreleaseし、**本番が待つ
同じProcessハンドル**の実 `WaitForExit(10000)` と `ExitCode` を確認してから
本番を再開する。Process、wait結果、完了receiptは置換/合成しない。
`tests/cross-model.tests.ps1:780` 以降で、両runnerについて以下を要求する。

- 実falsewait → 実exit0 → 本番HasExited=true → cleanupなし → exit0と完全な
  期待JSON、各5回。再確認ログ/本番ログのPID一致、順序、両実PID死亡も確認。
- 同じ再確認経路でも実子exit7はexit1・結果ファイルなし、各1回。
- 実子exit0でも不完全JSONはexit1・結果ファイルなし、各1回。

Bashの既存(c2)も `tests/cross-model.tests.sh:727` で3回から5回に増やした。
通常完了2000ms余裕、500ms出力遅延、起動遅延、hang/子孫cleanup、
fail-closed、空phase記録の既存検証は保持する。

## 実行結果（macOS 27.0.0 / PowerShell 7.6.2、stubのみ）

開始HEAD: `a3cd1cda6f5049dc32c63c8c364d7d1412f5b913`。
本番修正前に同じ永続PSテストを実行し、86成功/14失敗、exit1を取得。
14失敗は追加した再確認成功10件と負例4件のみ。正常終了済みでも本番が
`wait_completed=0 observed_exited=1 cleanup_kill=1` を記録してtimeoutにした。

| 実行 | コマンド | 結果 | ローカル全文ログ / SHA256 |
|---|---|---|---|
| RED（未修正本番） | `rtk proxy pwsh -NoProfile -ExecutionPolicy Bypass -File tests/cross-model.tests.ps1` | 86成功/14失敗、exit1 | `/tmp/pr531-ps-root-cause-red.log` / `0b7365409e33ff85754499993cba601626454a341b5b0cc9428045ff53a2cac6` |
| GREEN | 同上 | 100成功/0失敗、exit0 | `/tmp/pr531-ps-root-cause-green.log` / `d243b4de7ed271456c90108ea16556cca963fd76da4ff1ba8d56714485768b86` |
| 救済除去mutation | temp copyの両runnerから条件の `-and -not $observedExited` のみ除き、同じPSテストを実行 | 86成功/14失敗、exit1 | `/tmp/pr531-ps-recheck-removal-mutation.log` / `90d799433ff25a5a07a383dc2ee8a10127066e0e71c1365d4821e2d5a42da7a0` |
| Bash回帰 | `rtk proxy bash tests/cross-model.tests.sh` | 76成功/0失敗、exit0、(c2)各5回 | `/tmp/pr531-bash-recheck-five-green.log` / `186e483bd5b3689d10090dcecda7ff396c06b33b43687eb8bef77c5615d25550` |

GREEN例: GPT実PID50343はfalsewait後にexit0、再確認true、cleanup0。
Geminiも各5回同じ実経路を成功。非ゼロ例GPT PID50939は実exit7、
不完全JSON例GPT PID51140は実exit0だが結果拒否。救済条件だけを除くと
同じ実プロセステストの追加14件が再び失敗する。
PSテストSHA256はRED/GREEN/mutation共通
`fddbaacfc4a9f8d41d1d44f8a07f22c8728a847291dfe0600c8beb7126b8ab18`。
mutationはtemp copyのみで、作業checkoutの本番を戻したり変更していない。
`git diff --check`、Bash構文、独立空phase回帰もexit0。初回修正でGREEN、再修正なし。

## 残存条件

これはmacOS上のローカル実行証拠であり、Windowsの実OS実行、Linux CI、
最新HEADの全必須CI、live vendor、独立review、main統合の証拠ではない。
Windowsでの実deadline/Process/tree-kill/debugger実行は最新CIで確認が必要。
外部vendor呼出し、commit/push、正式gate/status変更は行っていない。
