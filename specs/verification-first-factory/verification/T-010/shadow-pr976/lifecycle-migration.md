# T-010　ライフサイクル・テンプレート・所有権の移行記録

比較元は `d24368af68ecbe157705810a51043fa212844830`、検証した製品差分は `769b3ff533376e6631ced729b7612e33e5ab475b`。2026-11-26 に macOS で実行した。対象は次の7入口。実行時に通常データを使ったケースと、全入口を実行できたかを区別して記録する。

| 旧入口・保証 | 現行の対応先と確認結果 |
|---|---|
| `task-lifecycle-enum-parity.tests.sh` の5状態の一致 | 永続状態検査2本とREQ行正規化2本の列挙を維持し、Lite 2本の参照先を MCP 契約 `$defs.status.enum` と Core CLI に移した。Core は全5状態のうち Implementation Complete と Done だけを通し、Unknown と done も拒否した。契約コピーに6番目の状態を加えると元スイートは終了1。 |
| `task-state-grammar-parity.tests.sh` の承認文法・綴り・抽出 | 永続状態の sh と ps1 に旧16入力を同一条件で与え、終了値を両方検査した。critical の署名抽出4例も維持した。Core では `v2-pure-lib.mjs` の `isApprovedValue` に対応する11入力を実ゲートに渡し、終了値・記録された値・判定を照合した。例えば自由記述の単一注記は Core が受理し、厳密な署名を要求する永続状態検査は両方で拒否する。 |
| 同入口の Done 報告書同一性・文字大小・パス | 実際の有効な証跡束を用意し、報告書変更後は宣言済みハッシュも更新する。正規 PASS は両 CLI が受理し、大小違い3通り・異なる大小の task ID・FAIL は各 CLI が拒否した。角括弧のある宣言済み実パスと別の PASS 兄弟ファイルを同時に置き、別の報告書で Done を満たせないことを確認した。従来の PowerShell 実装報告書探索の両対照も維持。Core の実行ルートにも空白と角括弧を含めた。旧シェル境界ケースのマーカー試験は今回の安全な再実行対象外。 |
| `template-validator-parity.tests.sh` の報告書、既定 verdict、CI 雛形 | 実装報告書の正規レンダー、validator、品質報告書の Feature / Task ID / Verdict / Run ID / 重大度3項目、run-record の identity を維持した。現行配布 `sdd-gate-report.md` と有効な execution.json を MCP の stdio `sdd_gate_audit` に渡し、既定 FAIL と別タスクの PASS は準備未完、対象の明示 PASS は準備完了となった。`sdd-adopt/templates` の GitHub / GitLab の実コマンドは未設定の診断を出して各終了1。 |
| `template-validator-parity.tests.ps1` の報告書と重大度 | PowerShell側でも元の報告書・validator・run-record の検査を維持した。Bash と共通のゲート・MCP 実行で重大度と報告書の対照を確認した。 |
| `workflow-state-ci-integration.tests.sh` のCI順序・全体状態・対象仕様状態 | 必須ジョブ `v2-guardrails` の構文木で、構造検査より先に全OSで PowerShell、Windows以外で Bash の全体検査を直接実行することを確認した。存在しない Feature の registry を両 CLI とも `registry-dangling` で拒否する。独立した Git fixture で初期 baseline は Core が `CLEAN`・終了0、AC-001 変更後は同 CLI が `UNDECLARED_DRIFT`・終了1、当該 ID を記録。 |
| `ownership-digest.tests.sh` / `.ps1` の digest、意味比較、登録 | 完全入力の digest、Feature 間の意味比較、resolver version、リリース履歴、design inventory の既存13検査を両入口で実行。TEST-041 は実 runner の一覧、catalog の経路に加え、必須ジョブの matrix・実行 shell・コマンド・OS 条件を照合する。旧 CI と同じ Ubuntu/macOS 上で両 suite を実行する構成。ps1 resolver が直接呼ぶ `resolve-component-paths.ps1` 80行の canonicalizer には `d27ce8682` の PowerShell dispatcher を復元し、既存の Python 実装に渡す。 |

## 所有者が個別に承認した退役

1. Bash の `generate-evidence-bundle.sh` から重大度件数コピーを探す pin 1件。比較元に当該生成器がなく、現行 Core が検査するデータは対象チケット。旧報告書の数値行 Critical=0、Major=1、Minor=2 の検査を残した。
2. PowerShell の `generate-evidence-bundle.ps1` に対する同じ pin 1件。同様に旧報告書の3行を独立に確認する。両入口とも同じ実 CLI に対し、同一対象・同一 open チケットの severity だけを変えた。critical/major は終了1・該当票と重大度を blocking に記録、minor は終了0・blocking 空。
3. 廃止済み Full `quality-gate/SKILL.md` がタスクごとに repository-global の検査を task-state より先に要求していた順序1件。現行 `sdd-gate/SKILL.md` 23–36行が指定する feature/task の CLI と上表の CI 全体検査を各々検証した。一時コピーで PowerShell の全体検査を構造検査の後に移すと、CI順序の検査は終了1。

## 実行記録

比較元では全7入口が終了1。enum・grammar は Lite checker 不在、template 両入口は重大度生成器不在、Bash では Lite 配布報告書も不在、workflow は旧スキル不在。所有権 Bash は登録 TEST-041 が失敗し、PowerShell resolver は canonicalizer の dispatcher を起動できなかった。

| 製品差分の実行 | 結果 |
|---|---|
| Bash enum / workflow CI integration | 7/7、workflow の両 CLI と Core 対照成功 |
| PowerShell template / ownership | 18/18、13/13 |
| Bash ownership | 13/13 |
| Bash grammar の通常データケース | 24/24。既存のシェル境界再現ブロックを再実行していない |
| Bash template の通常データケース | 21/21。既存の宣言境界再現ブロックを再実行していない |
| 実 CI 登録を外した TEST-041（Bash / PowerShell） | 各終了1、各 TEST-041 だけが失敗 |
| CI 全体検査の順序を逆転 / 契約に第6状態を追加 | 各終了1、順序エラー / 列挙の不一致を検出 |
| 全体状態を検査する sh / ps1 の実コマンド（リポジトリ全体） | 各終了0、末尾は両方とも `workflow-state: ok` |
| catalog 状況表の再生成、変更した Bash 5本・Python 2本の構文、git diff --check | 一致・成功 |

通常ケース限定の2入口は上表の件数をスイート全件の合格には数えない。一時ハーネスでは元ファイルから grammar の `# Exercise awk`〜`# Root and discovered` の直前、template の `# gate seq 856`〜`# The byte screen is only` の直前を除き、元のパスを `$0` にして残りを Bash で実行した。現行経路は `python3 tests/lib/core-lifecycle-checks.py` に `lifecycle`、`approvals`、`templates`、`workflow` を個別指定しても再実行できる。各回で一時 Git プロジェクトに baseline を記録し、`run-sdd-gate.mjs` の終了値と生成した execution.json を両方照合する。Done 報告書の両 CLI は `python3 tests/lib/task-done-parity.py plugins/sdd-quality-loop/scripts/check-task-state.sh plugins/sdd-quality-loop/scripts/check-task-state.ps1`。所有権の否定対照は各入口に `T003_ONLY=TEST-041` と `T003_MUTATE_ASSERTION=TEST-041` を指定した。

GitHub-hosted の Ubuntu / Windows / macOS はこの作業ツリーでは未実行。リモートでの成績、T-010 全体の判定および速度比較はこの記録の対象外。
