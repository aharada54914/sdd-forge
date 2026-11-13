# 実装・統合検証記録

この記録は disposable なローカル単一ユーザーアプリの実測結果を扱う。公開、認証、リモート push、Issue 登録は行っていない。承認は親が保存した TEST FIXTURE (`reports/integration/parent-task-approval-fixture.json`) であり、人間の本人確認や実署名を生成したものではない。

## 最終状態

**T001〜T005 はすべて Done。** 各タスクの実独立評価を採用し、最後に全5 contract・全5 evidence bundle・traceability・repository-wide workflow を再確認してすべて exit0。`reports/verification/task-board/final/` に正確なコマンド・時刻・出力を保存した。作業用サーバーの残存は0。起動・テスト手順は [README.md](README.md)。

T004 は実 native `01a1d33a-9843-7e21-8f3f-5bee34445e34`（99入力）、T005 は `01a1d33e-45d8-7ff0-9400-2aed634fa843`（97入力）が PASS0。allocation と turn の gpt-6-astra/high、実装者と異なるID、配送・予約・全入力hashを確認した。最終判定は [T005品質報告](reports/quality-gate/T-005-v10-final.md)。実受入対応は [全AC結果表](reports/implementation/task-board/T-005/acceptance-results.md)。

T005 の実装ワーカーと親品質検証の両方で、43件のPython試験・11群の実Chromium試験が成功。最終全体チェックに未解決Critical/Majorはなく、ユーザー承認を追加生成していない。ソースリポジトリ変更・push・Issue登録は行っていない。

## 実アプリと表示

Python 標準ライブラリの HTTP サーバー・JSON 永続化と、HTML/CSS/JavaScript の日本語単画面。外部ランタイムパッケージや CDN はない。開発検証では Playwright と `/usr/bin/chromium`、ruff、mypy、ESLint、TypeScript を使用した。

画像は親が実 ImageGen で生成した一方向成果を使用した。`specs/task-board/mockups/imagegen-reference.png` の SHA-256 は `60049c2b9d49f059afbe50ec43cc0d0802bae75b15b5dde090c4acdaf00127d8`。実ファイルを表示・照合し、白／navy／teal、余白、丸角を承認済みトークンに適用した。Claude Design 接続・実行とは主張しない。仕様外の sidebar、count、filter は追加していない。

最初の実画面: [desktop](reports/visual-evidence/task-board/T-004/first-render/visual/board-1440.png)、[mobile390](reports/visual-evidence/task-board/T-004/first-mobile/visual/board-390.png)、[mobile320](reports/visual-evidence/task-board/T-004/first-mobile/visual/board-320.png)。T004 最終実装検証は `reports/visual-evidence/task-board/T-004/final/results.json` に保存。

## 確認済みの実測

T004 実装時の全11ブラウザ群と43件の Python 回帰試験が成功した。追加・空白拒否・checkbox 双方向／reload・削除 confirm/cancel・Tab/Enter/Space と focus・GET loading/error/recovery・保存失敗・応答喪失・10秒 timeout・保存待ち重複防止・HTML風文字列の文字表示・実プロセス再起動と JSON 保持を含む。500個の astral 文字を実ブラウザから入力して保存し、501個は拒否した。UTF-16 の maxlength で切り詰めていない。

T004 実測の100件表示時は入力0.30ms、checkbox更新14.20ms、初期 HTML/CSS/JS 合計14,521 bytes（token CSS 含む）。これは当該ローカル実行の測定で、一般的性能保証ではない。通常系 page/console error は0、故障注入の期待された HTTP500/接続エラーは原記録に保持した。

実 PID に属する listen socket は127.0.0.1のみ、同一 port の loopback GET200、実非loopback IPv4 二つへの proxy不使用 TCP接続はともに拒否（connect_ex111）だった。生の socket表・PID・port は実行ごとの evidence に保存。ストレージ破損／書込失敗時の元ファイル保持は Python 試験で確認した。

1440/390/320px の実 Chromium 描画、長文折返し、44px control を確認した。200% は実 Chromium の CSS zoom2 による描画・横溢れ検証であり、headless の Ctrl+plus は効果がなかったため、browser toolbar zoom が動いたとは主張しない。コントラスト計算は text16.33、teal4.88、danger6.57対白。画面目視と計算記録は `reports/verification/task-board/T-004-visual-inspection.json`。

## 実際の失敗と修正

- T001 の実品質指摘に従って境界テストを補完した。古い raw PASS／配送失敗は採用せず保持した。
- T002 独立評価 cycle1 は RED コミットの検証可能な結び付けが不足して Major1。元の native 実行・保存 RED log・Git blob/tree/ancestry を照合して補足し、別の新規 evaluator が cycle2 PASS。中断された cycle2 配送は verdict 未生成のまま未採用であり、追加の製品指摘に数えていない。
- T004の最初の独立評価配送は実装報告の `Task ID:` がテンプレートの `- Task ID:` と異なり、reservation前に拒否された。原本と失敗を保存し、見出しだけ修正した新しい入力で新規評価者を割り当てた。製品指摘ではない。
- T005の最初のChromium起動は長いTMPDIRがUNIX socket長制限に当たり、シナリオ開始前に失敗した。既存コードを変えず通常の短い `/tmp` で再実行し、全ケース成功。
- T004 の最初の画面計測は非表示 dialog control を高さ0として数えた。表示中の control だけを測るよう試験を修正した。
- Playwright check/uncheck の即時状態検査が「HTTP成功後にだけ snapshot 更新する」UI方針と合わず、実 click と非同期状態 assertion に修正した。期待条件は保持した。
- 親の集約 typecheck がT001で strict 対象にしていなかった既存テストまで誤って拡大し、注釈不足66件を検出した。失敗を保存し、従来の採用対象（全production Pythonとtyped HTTP/token tests）および今回のbrowser harnessに戻して再実行した。T001の元contractやテストを変更せず、JS strict検査も維持した。
- JS strict typecheck が DOM global `status` との名前衝突を検出し、変数を `statusMessage` に修正した。検証用一時 npm tools の消失は保存済み lock による npm ci で復元した。初回失敗ログを消していない。

高リスク T001/T002/T004 は、実行して失敗したテストの RED commit を実装前に保存した。T002 は `398a701` → `bbab284`、T004 は `c861f6e` → `c336d0b`。各報告の完全な commit ID・実コマンド・時刻・SHA が正本となる。合成 test author は人間承認者ではない。

最終traceability更新では、親が標準外の `Verified` 値を使って `task traceability hash is stale` を発生させた。初めはシステムブロッカーと誤認したが、既存validatorが許す `Done` に修正すると正常に通った。8セルのStatus以外の仕様本文・レビューhash・runtimeは変更していない。失敗と差分・対照実験は `reports/integration/final-traceability-blocker/` に保持し、`RESOLVED-author-status-error.md` で誤分類を訂正した。新しい製品不具合として扱わない。

## ワークフローとランタイムの限界

後続 review/quality 実行は immutable `reports/integration/runtime-snapshot-v10/` の sibling plugins を使用。v9との差は親修復 #743 の二つの canonical validator のみで、279資産と過去の calibration pin を維持した。古い snapshot、reservation、配送失敗、未採用 identity は上書きしない。v10 source inventory 照合記録は `reports/integration/runtime-v10-source-verified.json`。

独立評価は product native idle allocation→preflight/reservation→first turn を使用し、実 allocation と turn の `gpt-6-astra/high`、実装者と異なる identity、read-only/no-network、全 input SHA を検証した。候補 PASS だけでは Done にせず、contract・bundle・repository-wide workflow の結果を別に要求した。read-only evaluator は書込や socket を使う試験を再実行せず、caller の実行証拠を検査したことを明記している。

check-component-coverage は実行結果が disabled-legacy N/A。実行した事実を記録し、active な component coverage を実施したとは主張しない。存在しない capability 設定や concept-test を作っていない。generated __pycache__ は immutable source contract の証拠に含めない。

過去の仕様・実装設計・タスクレビューと lifecycle 記録は canonical reports に保持した。task-scoped immutable traceability と累積 actual-only traceability を併用し、後続タスクの成功を先取りしていない。

## 読み取り専用の振り返り

[retrospective](reports/retrospective/task-board-final.md) と正規 [run record](reports/runs/RUN-20261113T045704Z-task-board.json) を保存した。正規emitterは入力宣言用delivery報告も数えるため、raw gate_reports=20／first_pass=0は製品レビュー失敗回数ではない。skillのtask/run重複排除で13文書、そのうち5はpending input declaration、実質的な品質レビュー報告は8（T001=3、T002=2、T003/T004/T005各1）。raw JSONを書換えず、集計上の限界を明記した。外部Issue・WFI承認・workflow規則の変更は行っていない。

通常仕様の最終独立レビューはspec round2、impl round2、task round3でPASS。途中のNEEDS_WORK/BLOCKED、legacy_design=trueからの修正、失敗配送はcanonical履歴に残っている。テスト失敗・環境ミス・配送失敗・製品指摘を区別し、完了していない実行を成功として数えていない。
