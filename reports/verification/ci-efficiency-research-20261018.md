# CI 効率化調査・承認用実装案

調査日: 2026-10-18
状態: 提案。CI 実装の承認待ち。
対象: sdd-forge の変更影響に応じた検証選択と実行時間削減。

## 推奨する変更

既存の検証カタログと変更影響判定を拡張し、PR では影響する検証を実行する。
ワークフローと現在の4つの必須ステータス名は常に返す。選択した検証の未実行・
失敗・キャンセルは集約ゲートで失敗とし、計画上不要な検証だけを省略できる。
main、merge_group、リリース検証、手動実行の既定は全体検証とする。
不明な変更・差分取得失敗・共有基盤変更も全体検証へ戻す。

Azure/AWS の実クラウド検証保留は継続する。今回の CI 改善承認は、クラウドへの
書き込み、外部ブランチ保護設定の変更、過去の検証結果の書き換えを含まない。
T009 の手続き上の例外承認は別件として既に記録されている。

## 現状と実測

調査基準は remote main の `fcb8275a42061b8132ea88a36e69b02f4487be71`。
ローカルのクラウド実装へは未統合のため、実装時に既存変更を保持して統合する。

| 対象 | ジョブ数 | run の参考経過時間 | ジョブ実行時間の単純合計 |
|---|---:|---:|---:|
| 最新 main の Test workflow | 42 | 26分13秒 | 約247.3分 |
| PR #592、`.github/dependabot.yml` だけの変更 | 42 | 29分35秒 | 約255.2分 |

経過時間は run の created_at〜updated_at、合計は job の started_at〜completed_at。
課金額・課金倍率・CPU 使用時間ではない。各 run で A9 advisory の1ジョブは skipped。
2回の観測から一般的な p95 や削減率は推定しない。

根拠:
- [main CI](https://github.com/aharada54914/sdd-forge/actions/runs/39103722974)
- [設定変更 CI](https://github.com/aharada54914/sdd-forge/actions/runs/39122240433)
- [PR #592 の変更](https://github.com/aharada54914/sdd-forge/pull/592/files)
- [取得結果](ci-efficiency-20261018/run-summary.json)、[PR ファイル一覧](ci-efficiency-20261018/config-pr.json)

#591 でカタログ、共通 runner、実測時間に基づく POSIX 分割が導入済み。
`verification-impact.py` は観測専用で、現在の必須 CI を省略しない。
取得した変更前コードの関数を実際に呼び出すと、local-posix の190スイートに対し
README 単独変更だけが5スイートの仮説を返し、Dependabot設定・MCP・クラウド変更は
190スイートを返した。全カタログは357スイート。これは提案関数の確認であり、
選択 CI を実装・検証済みという意味ではない。

- [現行カタログ](https://github.com/aharada54914/sdd-forge/blob/fcb8275a42061b8132ea88a36e69b02f4487be71/tests/verification-catalog.json)
- [現行影響判定](https://github.com/aharada54914/sdd-forge/blob/fcb8275a42061b8132ea88a36e69b02f4487be71/tests/verification-impact.py#L1)
- [現行運用方針](https://github.com/aharada54914/sdd-forge/blob/fcb8275a42061b8132ea88a36e69b02f4487be71/docs/verification.md)
- [実関数の確認結果](ci-efficiency-20261018/upstream-probe.json)

取得できた active ruleset は `test (windows-latest)`、`test (macos-latest)`、
`test (ubuntu-latest)`、`required-checks` を要求している。
従来の branch protection API は権限不足403で未確認。取得できたルールを含め、
外部設定の変更を必要としないよう現在のジョブ名と必須コンテキストを維持する。
[観測記録](ci-efficiency-20261018/ruleset-observation.json)

## 2026年時点の公式情報から採用する方針

| 観点 | 確認した仕様・推奨 | このリポジトリへの適用 |
|---|---|---|
| 必須チェック | workflow 全体を path filter で省略すると Pending のままになり得る。条件付き job の skip と、失敗した依存 job による skip は扱いが異なる。[S1] | workflow は起動し、`required-checks` は `always()` で計画と結果を突合する |
| 変更一覧 | 現行公式文書の path filter 上限は3,000ファイル。PR は three-dot、push は two-dot 比較。[S2] | Git から NUL 区切りの完全な差分を取得する。rename は旧・新双方、削除・追加・型変更を扱う。取得不能時は full |
| merge queue | 必須チェックを返すには `merge_group` が必要。[S1/S3] | 既存トリガーを維持し、初期導入では full |
| キャッシュ | lockfile 等を含むキー、OS・runtime の区分、秘密情報除外、信頼境界の維持が必要。[S4] | npm/pip/Pester・固定ツールの取得コストを削減。ソース、認可、検証 PASS、クラウド状態は再利用しない |
| キャッシュ権限 | 現行仕様に `cache-mode: read/write/write-only/none` がある。低信頼イベントの既定 read を明示 write で緩めない。通常の pull_request キャッシュは merge ref に隔離される。[S4] | サポートを確認した job で必要最小限のモードを使い、既存のイベント境界を維持。共有キャッシュの書き込み元を信頼された実行に限定 |
| 重複実行 | concurrency は同じグループを取り消せる。現在は `queue: max` もあるが、`cancel-in-progress: true` と併用不可。[S5] | PR の新しい commit は同じ PR の旧実行を取消。キーは branch 名から PR 番号へ改善し、別 fork の同名 branch を混同しない。main/merge/release は取消さない |
| 並列化 | 前段 output から matrix を組め、max-parallel で並列数を制限できる。[S6] | 選択後の独立スイートを既存の実測重みで分割。OS 固有の必須検証を維持し、起動コストも測る |
| 依存 Action | 公式は推移依存も固定する `actions.lock` を案内しているが、公開プレビュー。[S7/S8] | 今回は既存の full SHA 固定を維持。lockfile は別評価とし、速度改善の前提にしない |
| 実行権限 | 未信頼 PR を privileged trigger で checkout/実行しない。[S7] | 新しい planner は trusted base のコードで差分を扱い、read-only 権限で動かす。CI 高速化のための `pull_request_target` や新しい秘密情報は導入しない |

「2026年にすべて新規導入された」という主張ではなく、調査日に確認した現行仕様。
旧情報にある300ファイル制限と、今回取得した3,000ファイルの記述を混同しない。
公式文書全文はリポジトリへ転載せず、出典 URL と取得ハッシュを保存する。

## 変更分類の初期案

パスは入口に使い、実際の消費先・契約・fixture・生成物の依存を含めて選択する。
複数カテゴリの変更は必要検証の和集合になる。例外のない巨大な ignore リストは作らない。

| 変更 | 実行する範囲 | 省略可能な範囲 |
|---|---|---|
| README と影響確認済みの一般文書 | 文書・リンク・公開契約・リリース表記の検査、常設ゲート | 文書に依存しない MCP/クラウド等の重い実行 |
| `.github/dependabot.yml` 単独 | YAML/Dependabot設定検査、関連ポリシー、常設ゲート | runtime・全 OS の重い機能回帰。lockfile が同時に変われば該当パッケージ検証を追加 |
| `mcp/<package>/**` | 該当 MCP の既存 OS matrix、プロトコル・スキーマの消費先、配布/インストールの該当検査 | 依存関係のない MCP と機能群 |
| Azure/AWS プラグイン | 該当 adapter と共通契約、routing/execution/verification、インストール、bootstrap への必要な回帰 | 無関係と確認された機能群。共有 cloud ファイル変更は双方を含む |
| 各機能のテスト/fixture | 所有スイートと共有 fixture 消費先、カタログ整合性 | 影響がないと検証された範囲 |
| `contracts/**`、共有 guard/認可/検証、install/uninstall、marketplace・version面、CI/カタログ/selector | full | 初期導入では省略しない |
| 未分類、新しい依存関係、差分不明、空差分、選択規則変更 | full | なし |

`plugins/**/SKILL.md` や `AGENTS.md`、`specs/**/human-copy/**`、契約付きの
証跡文書は実行・検証の入力なので、Markdown/文書フォルダという理由で省略しない。
全 docs/specs/reports をまとめて軽量扱いしない。
カテゴリの対応関係が証明できない時は full とし、証明済みカテゴリから実スキップを有効化する。

## 実装の形と変更範囲

1. **既存基盤の統合**: #591 をクラウド作業へ統合し、#423 のインベントリ・境界・否定ケースと新しい4つの cloud suite を共通カタログに接続する。
2. **判定の単一化**: `tests/verification-catalog.json` と `verification-impact.py` を拡張する。機能グループ・必要スイート・依存関係を宣言し、判定根拠付き計画を出す。既存 runner/receipt を再利用する。
3. **必須コンテキストの維持**: `test` の3 OS matrix と既存のステータス名を保ち、不要な重い step のセットアップ/実行を条件化する。他の任意 lane は job 単位で選択する。単に matrix job 全体を省略して必須の名前が消える構成にはしない。
4. **計画と結果の照合**: 集約 gate は planner 成功、同じ base/head/実際のテスト対象 revision、カタログ/計画、選択スイート・OS の完了を確認する。計画欠落・改変・予期しない skipped/cancelled は失敗。計画上省略した検証は PASS と書かない。
5. **既存カバレッジ証明も更新**: 現行 `verification-workflow.py` は `needs.*.outputs` 条件を未対応として拒否し、fallback shard の無条件実行を要求する。実関数呼び出しでも確認済み。既知の planner 条件と full/affected 両モードを検証できる契約へ改め、任意条件式を無条件に受理する変更はしない。
6. **取得・並列化の改善**: 既存3 MCP の npm cache は維持。繰り返しの依存取得を、OS/runtime/lockfile/ツール digest を含むキーで整理する。最大待ち時間に効く A7/native・A9 等は実測後に独立 lane を調整し、全 assertion と OS 対応を残す。
7. **文書と計測**: `docs/verification.md`、workflow/release/contributor 手順、必要な README を更新する。選択理由、実行・省略リスト、所要時間を安全な summary に残す。生ログと資格情報は公開しない。

主な対象: `.github/workflows/test.yml`、`tests/verification-{catalog.json,impact.py,workflow.py}`、
`tests/verification.py`、`tests/run-ci-unwired.sh`、対応する regression tests、検証・運用文書。
必要な分類データは既存カタログに集約し、NX/Bazel 等の新しい汎用ビルド基盤は導入しない。
branch protection の変更は本案の前提にしない。

## 受け入れ条件と展開

- 変更の追加・削除・rename・大文字小文字・3,000件超・複数カテゴリ・base不明・fork PR・未知パスを検証する。PR の差分とテストした merge revision を別々に正しく固定する。
- planner/カタログ/CI 自身を変更すると full になる。PR が selector を差し替えて必須検証を消せないことを否定テストで確認する。
- 依存する契約/fixture/生成物の変更が消費先のスイートを選ぶ。必要スイートを外す変異が検査を失敗させる。
- 意図した skip は受理し、選択した job の failure/cancelled/unexpected skipped、receipt 欠落、旧 revision の結果、空の成功は gate を失敗させる。
- full モードのスイート・assertion・OS 義務が導入前と同じであることをカタログと実行結果で確認する。#423 とクラウドの回帰も維持する。
- 代表的な文書・MCP・クラウド・共有変更で、選択案と full の結果を比較してから当該カテゴリの実スキップを有効化する。未証明カテゴリは full のままにする。
- 実 GitHub CI で条件分岐、4必須ステータス名、native OS、merge_group/full/manual 経路を確認する。ローカル fixture 成功を実 CI 成功に置き換えない。
- 実行計画を full に戻す単一の運用スイッチと、その検証を用意する。必要時は選択の効率化だけを無効にして既存全体検証へ戻せる。
- リリースタグは引き続き、full CI と必要なローカル全体検証に合格した同一コミットへ付ける。

測定は PR 種別ごとに、最初の有効な失敗までの時間、全体経過時間、job 分合計、
cache hit、待機時間、選択から漏れた失敗、誤検知、再実行回数を分ける。
まず文書/設定 PR の大幅短縮を狙うが、具体的な削減率や10分以内を実績として約束しない。
常設の nightly 全体検証を追加する案は今回は含めない。main/merge/release の全体検証を使う。

## 比較した構成

| 構成 | 評価 |
|---|---|
| workflow の paths/paths-ignore だけ | 小さい変更で済むが、必須 Pending・差分上限・共有依存の表現に課題 |
| 新しい monorepo engine/外部選択サービス | 依存と運用面が増え、既存カタログと重複する |
| 既存カタログ＋既存 impact planner＋常設 gate | 推奨。小さい公開インターフェースで、選択と full の検証を同じ基盤に集約できる |

## 公式出典

- S1: [Troubleshooting required status checks](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/collaborating-on-repositories-with-code-quality-features/troubleshooting-required-status-checks#handling-skipped-but-required-checks)
- S2: [Workflow syntax / Git diff comparisons](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#git-diff-comparisons)
- S3: [Events / merge_group](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#merge_group)
- S4: [Dependency caching reference](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching#controlling-cache-access-with-cache-mode)
- S5: [Control workflow concurrency](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency)
- S6: [Running variations of jobs in a workflow](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/run-job-variations)
- S7: [Secure use reference](https://docs.github.com/en/actions/reference/security/secure-use#using-third-party-actions)
- S8: [Workflow dependency lockfiles — public preview](https://docs.github.com/en/actions/concepts/security/workflow-dependency-lockfiles)
- [取得ハッシュ一覧](ci-efficiency-20261018/sources.json)

承認対象は上記の変更分類・安全側の full fallback・必須コンテキスト維持・キャッシュ/並列化・
検証と文書更新を含む実装範囲。承認後、必要な仕様/タスクのレビューと実装を進める。
この文書の作成時点では CI コード、キャッシュ設定、ブランチ保護設定を変更していない。

## クラウド統合後の追記（2026-10-18）

上記の調査基準コミットはクラウド実装ブランチへ統合済み。現在のカタログは363スイート、
local-posix は196、local-powershell は130の登録を持つ。同じ Python スイートが両プロファイルに
含まれるため、合計326は異なる326スイートを意味しない。初回の調査値357/190は当時の値として保持する。

[クラウド版の初回 CI](https://github.com/aharada54914/sdd-forge/actions/runs/39155983283) では、
Linux のクラウド検証ステップが672秒、macOS が487秒を要した。Linux の native test ジョブは
既存の30分制限で停止した。全検証を維持するため、リリース候補では同ジョブの上限を45分へ
調整した。Windows のチェックアウトには Git の core.longpaths を指定した。
これらは実際のリリース阻害要因への修正であり、本案の変更選択・キャッシュ・concurrency の
実装承認や、CI の短縮実績を意味しない。

実行時間の評価には候補修正中の失敗 run を成功 run と混ぜず、最終合格コミットでの計測を使う。
Windows と POSIX のテスト用環境差も、必要検証の省略理由には使わない。
