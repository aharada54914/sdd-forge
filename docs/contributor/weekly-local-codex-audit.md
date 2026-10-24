# ローカルCodex週次セルフ改善監査

2026-09-05、所有者の選択により ChatGPT ログインを使うローカル Codex の定期実行へ移行した。APIキーは追加していない。

## 現在の状態と実行前の確認（2026-10-05）

[Issue #545](https://github.com/aharada54914/sdd-forge/issues/545) の再確認では、GitHub API が返す [週次 Actions](https://github.com/aharada54914/sdd-forge/actions/workflows/self-improvement.yml) の状態は `active`、`updated_at` は `2026-09-23T08:01:45Z` だった。[2026-09-28](https://github.com/aharada54914/sdd-forge/actions/runs/36371625415) と [2026-10-05](https://github.com/aharada54914/sdd-forge/actions/runs/37259263467) に `schedule` 起動と実行成功を確認した。`updated_at` だけで再有効化の時刻や理由は確定できない。

したがって、[ワークフロー](https://github.com/aharada54914/sdd-forge/blob/e845fbc8942b7ee496b9f9928e5ada61443048d9/.github/workflows/self-improvement.yml) と [Actions 用指示](https://github.com/aharada54914/sdd-forge/blob/e845fbc8942b7ee496b9f9928e5ada61443048d9/.github/self-improvement-prompt.md) は現在稼働している経路であり、復旧参考用のみではない。下記の2026-09-05／09-11の無効化・ローカル登録確認は当時の記録で、現在の状態を保証しない。

ローカル側は、本調査で定期設定の `ACTIVE`・毎週月曜09:00 JSTを読み取り、所有者保管の2026-10-05監査報告と定期実行履歴を照合して、同日09:01 JSTの監査実行を確認した。オンラインCIと差分確認は完了したが、選定したローカル同等性テストは保護フックの実行前拒否により未実施で、監査全体は一部完了である。両経路が同日に実行された併用状態であり、厳密な同時実行やローカル検証の完走を意味しない。今後どちらを正本にするかは所有者の判断が必要。

状態はリポジトリの文書や clone/fork には固定されないため、監査の実行・再有効化・移行前に次を再確認する。

```sh
gh api repos/aharada54914/sdd-forge/actions/workflows/self-improvement.yml --jq '{state, updated_at}'
gh run list --repo aharada54914/sdd-forge --workflow=self-improvement.yml --limit 10 --json event,status,conclusion,createdAt,url
```

併せて所有者が Codex アプリの定期設定と直近の実行履歴を照合する。設定が有効であることと完走は区別し、両経路が有効なら重複 Issue/PR を避ける運用を決めてから実行する。この訂正ではスケジュールや有効状態を変更していない。

## Actions の手動設定確認（2026-10-24、#620）

手動 `workflow_dispatch` の `capture_configuration: true` は、採用済み
self-improvement 用の明示的な Opus/medium 設定を一度だけ確認し、直後に既存の
managed Action preparation へ渡す。リポジトリ変数の更新は不要で、request 変数が
空なら `.github/self-improvement-request.template.json` を使う。CLI は
`2.1.303 (Claude Code)` に固定し、nonce 応答・セッション・成功イベント・実ツール
呼出しの不在と設定の不変性を確認する。観測した `claude-opus-5-5` は公開採用証拠
に固定された表示ラベルであり、バックエンドの認証済みIDとは主張しない。
quota 通知は既知の外形・セッション・UUID と primary status を検証し、`allowed` /
`allowed_warning` のみ認める。付随する使用率・リセット時刻・overage 情報は成功の
証拠に使わず、nonce・成功終端・実ツール呼出し・エラー・reroute の検証を維持する。

この確認は通常の設定・フックと MCP 権限を保持し、60秒・1回、再試行なしで行う。
実際のイベントでツール呼出しがなかったことを確認するもので、呼出し不能や隔離を
証明するものではない。advertised tools と実呼出しは区別して記録する。失敗時の
stdout/stderr と receipt は `.sdd-self-improvement/<scope>/` 内に非公開モードで
残し、認証情報や設定全文をログへ出さない。成功時だけ既存形式の observation と
実行専用 request を作り、300秒の鮮度制限を変えずに消費する。監査本体が後で変更
する設定も既存の allocation 検査対象であり、確認成功だけで監査完走とはしない。

runner 破棄後の確認用に、成功・失敗とも許可項目だけの JSON 要約を workflow ログへ
残す。設定したモデル・effort・CLI 版、検証できた表示ラベルと実ツール数、固定の
失敗コード、終了コード・時刻、stream/receipt の SHA256 を記録する。生データ、
設定、session ID、nonce、ツール名、パス、任意の例外文は出力しない。生の証拠は
runner 内だけに残り破棄後には再生できず、要約は backend 認証を主張しない。

既定値は false。定期実行には依然として有効な request/新鮮な observation の供給が
必要であり、この手動経路の追加は定期運用の復旧を意味しない。実際の hosted audit
と5項目の検査・completion/finalizer の結果を確認するまで #620 の復旧を宣言しない。

## ローカル運用の移行時設定（2026-09-05）

- 名称: sdd-forge 週次セルフ改善監査
- スケジュール: 毎週月曜09:00（Asia/Tokyo）
- 自動化ID: sdd-forge
- 実行対象: 所有者のローカル sdd-forge チェックアウト
- この移行を行ったCodex会話を継続する定期実行。前回の範囲・対象SHA・未完了項目を会話に残す。
- 指示文のレビュー用コピー: [.github/self-improvement-local-prompt.md](https://github.com/aharada54914/sdd-forge/blob/e845fbc8942b7ee496b9f9928e5ada61443048d9/.github/self-improvement-local-prompt.md)。実際に再生される指示はCodexアプリの定期タスク設定に保存される。このファイルを編集するだけでは定期タスクは更新されないため、変更時はアプリ側も同じ内容に更新する。
- 実行時にはPCを起動し、Codexアプリを稼働させ、プロジェクトとChatGPTログインを利用可能にしておく。
- 結果はこの会話で報告する。GitHubへの自動投稿・commit・push・PR作成・マージは行わない。修正は既に人間承認されたタスクのみ、既存の実装・品質ゲートに従う。新しい指摘は具体的な改善案としてレビューに回す。

移行時は `.github/workflows/self-improvement.yml` の `disabled_manually` を確認し、二重実行を避けるため無効を維持する方針だった。この過去の方針から現在も無効とは判断せず、上記の「現在の状態と実行前の確認」に従う。

## 停止原因と改善

[2026-08-17の失敗実行](https://github.com/aharada54914/sdd-forge/actions/runs/31984000729) は `error_max_turns`、`num_turns: 76`、`Reached maximum number of turns (75)` を記録した。約22分で上限に達しており、45分のジョブタイムアウトが直接原因ではない。[2026-08-31の実行](https://github.com/aharada54914/sdd-forge/actions/runs/33354540734) は52ターンで成功しているため、常時失敗ではなく、監査量に依存する停止だった。

旧指示はWFI全件の読取り、広範な検査・テスト、IssueとPR作成を一回で要求していた。また、開始しただけで失敗Issueを閉じるため、その後の失敗を復旧として誤報告し得た。新指示は次を採用する。

1. 直近差分＋交代制の1領域に絞る。指摘は最大3件、証拠を必須にする。
2. 調査20分・報告5分を目安に、15分から新規調査を止める。これは指示上の予算であり、アプリの強制タイムアウト設定ではない。
3. 各段階の中間記録と次回再開点を保存する。認証・ネットワーク不足は未確認として範囲を限定し、無制限に再試行しない。
4. PASS・FAIL・未実施を分け、実際の失敗経路を検証するまで復旧を宣言しない。
5. 最小の関連テストを実行し、承認済みタスクだけを修正する。ガードと凍結証跡は保持する。

## 確認結果と限界

移行時に `codex login status` の `Logged in using ChatGPT` を確認。`bash tests/self-improvement-guard.tests.sh` は10 passed / 0 failed。定期タスクはACTIVEで登録し、旧GitHubワークフローの無効化もAPIで再確認した。

この移行時の確認はログイン・登録・既存ガードのスモークテストであり、無人実行の完走を証明するものではない。アプリ停止・利用上限・ネットワーク障害まで無停止を保証するものではない。

### 統合前の再確認（2026-09-11）

- 保存された指示文とレビュー用コピーは前後空白を除いて完全一致し、定期タスクの設定は `ACTIVE` だった。設定が有効であることと、実行が成功することは区別する。
- GitHub APIで旧ワークフローの `disabled_manually` を再確認した。定期設定、認証情報、GitHubワークフローの有効状態は今回変更していない。
- `bash tests/self-improvement-guard.tests.sh` は10 passed / 0 failed（終了コード0）。旧ワークフローの保護機構のテストであり、定期実行エンジンのテストではない。
- 移行先会話 `01a06f1c-0ce6-7012-81b3-c9073a4d6a8e` の実行 `01a07c6f-cdab-7e61-92bd-9872ebb692d1` は、2026-09-07に利用上限のエラーで停止していた。これは未完了の監査であり、監査対象に問題がなかったことを示さない。会話履歴だけでは起動元を確定できないため、スケジューラによる無人起動成功の証明にも用いない。
- 利用可能な状態での次回実行では、定刻起動、所要時間、結果報告、中間記録、未調査範囲を確認する。上限によって止まった回の監査を成功扱いしたり、無条件に同じ実行を繰り返したりしない。

この再確認により下記の2026-09-05時点の記録を上書きせず補足する。公式の[定期タスク資料](https://learn.chatgpt.com/docs/automations?surface=app)でも、ローカルファイルを扱う場合はPCとデスクトップアプリの稼働が必要とされている（2026-09-11確認）。

## 調査した公式資料（2026-09-05確認）

### 手動試行の記録（2026-09-05）

新しい指示を移行元の会話で手動試行し、設定照合、ローカル差分確認、GitHub読取り、関連テスト、結果報告まで完了した。スケジューラから起動した試験ではない。

- 対象SHA: `3749a252af31c504387c4cb8855342261c41dbbd`。直近7日・最大20コミットの取得結果は4件。追加領域は b（README・設定・導入手順の整合）。全領域の監査は未実施。
- PASS: 保存された定期指示とレビュー用ファイルの完全一致（前後空白を除く）、ACTIVE、月曜09:00、対象会話IDを確認。`codex login status` はChatGPTログインを確認した。PATH alias作成の警告は出たが終了コードは0。
- PASS: GitHub APIによるIssue一覧20件（API仕様上PRを含む）、PR一覧15件、失敗実行20件の読取り。取得上限外は未確認。旧監査ワークフローは `disabled_manually`。
- PASS: `bash tests/self-improvement-guard.tests.sh` は10 passed / 0 failed、終了コード0。これは旧ワークフローの保護機構の回帰検証であり、新しい定期実行エンジンのテストではない。`git diff --check` も終了コード0。
- 既存CI失敗: [実行33889193748](https://github.com/aharada54914/sdd-forge/actions/runs/33889193748) の取得した20ジョブ中、Ubuntuの3 MCPジョブで `Audit production dependencies` が失敗。[PR #386](https://github.com/aharada54914/sdd-forge/pull/386) が同じ監査失敗への修正を提案している。失敗ステップの存在は高確信、原因の同一性はPR本文との照合までで、今回ログ全文や依存監査の再実行は未実施。新規案件に重複計上せず、PRの検証結果を次回確認する。
- 前回からの変化: 設定確認のみから、オンライン証拠の取得と既存案件の照合まで検証範囲を拡大。実装変更・外部投稿なし。
- 次回再開点: 上記SHAとCI実行を基準に差分を取得し、PR #386の状態と初回の無人実行結果を確認する。スケジューラ起動、利用上限到達、通信断、途中停止後の再開は未検証。

### 参考資料

- [Scheduled tasks](https://learn.chatgpt.com/docs/automations?surface=app): ローカル実行の稼働条件、会話を引き継ぐ定期タスク、通常会話での事前検証と初回運用の見直し。
- [Prompting](https://learn.chatgpt.com/docs/prompting): 目的・文脈・成果物・制約の明確化、現在情報の出典、再現と最小の関連検証。

領域交代、件数と時間の上限、次回再開点は、上記の指針と今回の停止ログをもとにこのリポジトリ向けに設計した運用であり、OpenAIが規定した固定値ではない。
