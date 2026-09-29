# #427 空 phase ログの検証中断修正 — scoped extra 1

Run ID: issue427-empty-phase-extra1-20260928
Base commit: 000b0bb4e28ba768606dfa5153f709f019a08392
Status: local candidate; independent diff review complete; Windows validation pending

## 承認範囲と残件

2026-09-28 の人間承認「A9復旧計画の3タスクを承認した　追加修正の限定承認する」は、直前に提示された #427 の空 phase ログを通常 FAIL にする修正、focused regression、時間制限処理が戻った後だけの診断、Windows 検証1回に対する限定承認。本候補は **scoped extra 1** として記録する。既存の修正ループは 3/3 消費済みであり、その回数をリセットしない。

これは harness の null 例外による中断だけを修正する。Windows でプロセスが期限を超える原因は未解決で、#427 の解決・安定性・quality-gate PASS・Done は主張しない。既存の該当 review-ticket は探索で見つからず、架空の ticket や task 状態変更は作成していない。

根拠となる失敗は [PR #401 の run 36392456347 / Windows job 108831130096](https://github.com/aharada54914/sdd-forge/actions/runs/36392456347/job/108831130096)。Python fixture は phase file を作成してからバッファを書き出すため、kill が間に入ると空ファイルが残りうる。空ファイルに対する `Get-Content -Raw` は null を返し、元の `Regex.Matches` は例外で suite を中断する。

## 変更

- `tests/cross-model.tests.ps1:704`: 既存の phase 読取を1回だけ `[string]` に正規化し、wait/output の両 regex に同じ値を渡す。空入力は両 receipt を0のままに保ち、既存の boundary 判定が FAIL を記録する。
- `tests/cross-model-empty-phase.tests.ps1`: suite の AST から実際の phase 読取〜boundary 判定〜診断〜process assertion を実行する。空ログと timeout 観測では通常 FAIL が2件、正常終了観測でも欠落 evidence の FAIL が1件となり、両方とも後続検証に到達することを確認する。CLI は起動しない。
- `tests/cross-model.tests.ps1:627`: focused regression を既存 suite に接続する。既存 CI と `tests/run-all.ps1:19` はこの suite を呼び出すため、CI workflow の変更は不要。

唯一の phase reader は `tests/cross-model.tests.ps1:703`。両 fake runner の5反復が同じ読取箇所を通る。`Test-BoundaryTiming` と `Assert-ProcessObservation` の定義および全呼出、両 production PowerShell runner、CI の既存呼出を追跡した。

2秒の process deadline、各 runner 5反復、200ms margin、exit=0・verdict 存在・`wait_completed=1`・`observed_exited=1`・`cleanup_kill=0` の必須条件は変更していない。timed worker と production runner は無変更。phase 計測表示と最大4096文字の既存診断は `Invoke-PanelistRunner` が戻った後にのみ実行される (`tests/cross-model.tests.ps1:677`, `:700`, `:727`)。timeout cleanup 後の既存 runner 診断も無変更 (`run-panelist-gpt.ps1:270`, `run-panelist-gemini.ps1:181`)。新たな in-deadline 診断は追加していない。

## 実行証拠

すべて `rtk proxy`、非 login shell で実行。隔離 checkout を使用し、既存 dirty root を変更していない。実環境は macOS (Darwin 27.0.0 arm64)、PowerShell 7.6.2、Python 3.14.5。実モデル CLI は使用せず、Gemini への依頼も行っていない。既存 suite の vendor 名はローカル synthetic CLI fixture の識別子に限る。

### Red

修正前に focused regression を追加し、次を実行:

```text
rtk proxy pwsh -NoProfile -NonInteractive -File tests/cross-model-empty-phase.tests.ps1
fail: empty phase regression: Exception calling "Matches" with "2" argument(s): "Value cannot be null. (Parameter 'input')"
exit: 1
```

これは意図した null 入力の失敗であり、構文エラーや環境不足による Red ではない。

### Green

最小修正後、同じ focused command:

```text
ok: empty phase log reports ordinary FAIL and continues (completed=False)
ok: empty phase log reports ordinary FAIL and continues (completed=True)
exit: 0
```

関連 suite を1回実行:

```text
rtk proxy pwsh -NoProfile -NonInteractive -File tests/cross-model.tests.ps1
Results: 86 passed, 0 failed
exit: 0
```

境界10ケース全件で exit=0、verdict 存在、boundary_timing=1、`wait_completed=1 observed_exited=1 cleanup_kill=0`。output receipt は deadline の189〜190ms前、process observation は177〜187ms前だった。これは local macOS 結果であり、Windows の期限超過原因を解消した証拠ではない。

`rtk proxy git diff --check`: exit 0。

### 独立した主担当による差分レビュー

実装担当とは別の主担当が実際の phase 読取〜boundary 判定〜診断〜process assertion と AST 回帰を確認した。空 evidence を成功扱いしないこと、両 runner が同じ修正箇所を通ること、期限・反復・終了条件が不変であることを確認し、本限定差分に不具合指摘はなかった。主担当も focused regression 2ケースと全件 suite を独立実行し、86 passed / 0 failed、exit 0、whitespace exit 0 を得た。これはコード差分レビューであり、正式 quality-gate や native Windows の合格ではない。

## SHA-256

| 対象 | SHA-256 |
|---|---|
| base の `tests/cross-model.tests.ps1` | `eab56613dbe3134736885f7c7a64724fa0dcdbb296b7c1013f1ae555d0582725` |
| candidate の `tests/cross-model.tests.ps1` | `234e92245d5d46de8cbf92dd8744d4d21a73d63ecc1fe0fdd537213fefa30702` |
| `tests/cross-model-empty-phase.tests.ps1` | `21b4ceef83753a668a221b2f4a4da0d6250abd2e2d6e9f3fc253506584199c3a` |
| base→candidate の既存 suite diff | `1011c7a15c140515d6e189238c8608357b8bb78d46b1aafc1e587ce6731bf8e6` |

## 未実施 / handoff

- commit、push、PR、Windows 検証は本記録時点では未実施。
- Windows 検証の限定1回は **0/1 消費**。独立差分レビュー済みの候補を固定して CI へ提出する。
- unchanged CI rerun、期限緩和、追加修正ループ、仕様・task 状態・review gate の更新は行っていない。
- 本候補への `apply_patch` の hook refusal は発生していない。
