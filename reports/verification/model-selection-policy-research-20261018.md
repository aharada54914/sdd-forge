# 最新モデルを継続利用するための調査・承認案

Date: 2026-10-18 UTC
Status: Approved — user authorized implementation on 2026-10-18; product implementation has not started

## 推奨する方針

**役割別の設定を一元化し、実行開始時に利用可能な最新の適合モデルへ解決する。解決結果は実行単位で固定し、既存の週次チェックでカタログを保守する。** 変数だけ、固定モデル名の定期置換だけ、という方式にはしない。

ここで「最新」は、対象ホスト・プロバイダー・契約で利用でき、役割の能力条件と互換性検証を満たす現行モデルを意味する。世界で最後に発表されたモデルを全役割に強制する意味ではない。未提供・未検証の新モデルを発見した場合はその状態を明示し、旧モデルを黙って「最新」と表示しない。プロバイダーの提供時期や廃止を本製品が保証することはできない。

## 調査結果と既存実装

| 確認内容 | 根拠 | 設計への影響 |
|---|---|---|
| Codex はモデル一覧、対応 reasoning effort、推奨既定値、任意の upgrade 情報を返す。内容はアカウントとクライアントに依存する | [OpenAI App Server: Models](https://learn.chatgpt.com/docs/app-server#models) | 実行時 discovery を利用し、ページ送りも処理する。モデル名の文字列順や一覧の順を新しさと解釈しない |
| Codex の推奨は一般的な複雑コーディングに GPT-6.1 Sol、特に難しい作業に Astra、反復的な小タスクに Luna。提供状況と認証方式で利用可能性が異なる | [OpenAI Models](https://learn.chatgpt.com/docs/models) | 役割・リスクを維持して世代を更新する。単純に全役割を最大モデルへ変更しない |
| Claude Code のモデルエイリアスは設定・環境変数で解決先を変更でき、管理者設定も影響する | [Claude Code model configuration](https://code.claude.com/docs/en/model-config) | エイリアス名だけで実モデルを判断しない。実効設定を確認する |
| Claude 4.6 以降の日付なし API モデル ID は固定スナップショットであり、常に最新へ向く名前ではない | [Claude model IDs and versioning](https://platform.claude.com/docs/en/about-claude/models/model-ids-and-versions) | CLI のエイリアスと API のモデル ID を区別する。固定 ID でも完全に同じ出力を保証するわけではない |
| Copilot CLI は custom agent の model を CLI オプション・COPILOT_MODEL より優先する | [GitHub Copilot programmatic reference: Model precedence](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-programmatic-reference#model-precedence) | 環境変数を追加するだけでは不足。生成される agent 定義と起動経路を整合させる |
| モデル変更には代表例・境界例による継続評価が必要 | [OpenAI evaluation best practices](https://developers.openai.com/api/docs/guides/evaluation-best-practices) | 新モデルの採用前に既存の振る舞い評価を再利用し、評価器自身の変更も記録する |
| 現在の selector は能力・effort・コスト等で選ぶが、現行世代の優先情報を持たない | `plugins/sdd-implementation/scripts/select-agent-model.sh:427-443` | 現行モデルの候補集合を決めてから既存のリスク条件を適用する。旧モデルが安価・辞書順で選ばれ続ける問題を避ける |
| Codex evaluator の生成済み参照コメントは旧 ID のまま | `.codex/agents/sdd-evaluator.toml:1`; `render-agent-frontmatter.sh:211` | 参照コメントと実際の起動モデルを分けて検証する。コメント変更だけで実装完了としない |
| 実装方針レビューの launcher には Sonnet 限定検査がある | `plugins/sdd-review-loop/scripts/launch-impl-review.py:342-348` | 新しい役割ポリシーへ明示的に移行し、既存の承認・独立性検査を維持する |
| 週次のモデル鮮度 workflow は既にある。外部テキストから候補を抽出して issue 通知する保守的検出であり、モデル解決器ではない | `.github/workflows/model-freshness-check.yml:13-25`; `.github/scripts/check-model-freshness.sh:116-174` | 重複する定期ジョブを新設せず、既存の検出と手動更新経路を改善する |

ローカル実測: 2026-10-18 22:16:39 UTC、認証済み Codex app-server の `model/list` を全ページ取得。`gpt-6.1-sol` が `isDefault: true`。`gpt-6-astra`、`gpt-6-sol`、`gpt-6-luna` 等も返された。推論ターンは開始していない。この観測は一覧取得の成功であり、全モデルの品質評価や将来のアクセス保証ではない。証跡は同日付の `model-selection-host-observation-20261018.json`。

## 方式の比較

| 方式 | 利点 | 制約 | 採否 |
|---|---|---|---|
| モデル ID を各ファイルへ固定し定期置換 | 実装が単純 | 更新漏れ・権限差・提供終了に弱い | 再現用の明示指定として残す |
| 全経路で latest / auto / inherit | 設定が少ない | 共通規格ではなく、実モデル・能力・評価の比較条件を固定できない場合がある | ホストが実モデルを検証可能な場合に限定 |
| 環境変数のみ | 利用者が上書きしやすい | agent 定義が優先される場合や検証のない値に弱い | 正規の resolver 入力として使う |
| 役割別ポリシー＋実行時 discovery＋カタログ保守 | 更新漏れを減らし、能力条件・監査・再現性を両立 | 小さなホスト別 adapter とカタログ管理が必要 | **推奨** |

## 承認対象の具体的な仕様

1. **設定の正本を一本化。** 実装・調査・仕様レビュー・設計レビュー・タスクレビュー・品質評価を役割で指定する。既存 registry/selector を拡張し、別系統の選択器を増やさない。既存の v1/v2 入力・過去の証跡を壊さず、必要な追加契約はバージョン管理する。
2. **通常は `latest-compatible`。** 役割ごとの能力下限、利用を許可された provider、リスク、予算を満たす現行モデルを選ぶ。同じ系列の後継関係と公式推奨を、出典・確認日付きのカタログで表す。名前の数値や API の作成日時だけで異なる系列の優劣を決めない。費用最小化のために旧世代を暗黙選択しないため、従来より費用が増える場合がある。
3. **明示指定も維持。** `pinned` モードと役割別の固定 ID を設ける。設定候補は `SDD_MODEL_POLICY=latest-compatible|pinned`、`SDD_MODEL_IMPLEMENTER`、`SDD_MODEL_EVALUATOR` 等。最終の名前・schema は設計で確定する。利用者の明示指定を尊重しつつ、ホスト・組織の許可、能力下限、入力検証は常に適用する。未知値は無視しない。
4. **起動直前に解決。** Codex は `model/list` を使う。Claude Code / Copilot は公式に提供された設定・一覧・起動応答を利用し、存在しない共通 API を仮定しない。機械可読の情報が足りないホストでは、検証済み設定か明示 ID を要求して制限を表示する。ChatGPT 画面上の親モデル等、本製品が制御しない実行は対象外と明記する。
5. **未検証モデルを自動採用しない。** 起動時に未知の後継を見つけたら更新候補として報告する。登録情報・互換性・役割別評価の確認後に採用する。一度採用された後継は次回実行から自動解決でき、各 agent ファイルの手修正を不要にする。新規モデルを検証する時間があるため、発表と同時の無条件切替は約束しない。
6. **実行単位で固定。** 選択ポリシー、要求 ID/alias、解決 ID、実際に報告された ID、effort、ホスト/CLI、カタログ hash・確認時刻、選択理由を記録する。ホストが実 ID を返さない場合は未確認と記録し、監査で実 ID を要求するゲートは開始しない。実行途中・再開時にモデルを黙って変更せず、新しい試行として記録する。
7. **フォールバックを明示。** 候補不在・取得不能・廃止・能力不明・予算超過は理由付きで停止する。過去の検証済みモデルを使う場合は明示設定による固定実行とし、「最新利用成功」には数えない。新しい名前を知っているだけで利用可能と判定しない。
8. **定期保守を再利用。** 現行の毎週月曜 03:00 UTC と手動起動を維持し、各ホストの公式情報・廃止情報・登録情報の差を検出する。通知の重複抑制と外部取得障害の表示を改善する。既存 issue 通知の範囲で運用し、自動マージ・無条件 registry 書換えは行わない。開発中に実 issue 通知を試す必要はなく、fixture で検証する。
9. **評価を二種類に分ける。** 通常の品質ゲートは現行の適合評価モデルで実施する。モデル更新の比較評価はデータ・指示・評価器・設定を固定し、旧モデルと新モデルの差を測る。評価器が変わった結果を同じ基準の点数として混ぜない。独立したレビューコンテキスト、cross-model 条件、承認・証跡検証は維持する。
10. **最新モデルと effort は別管理。** 最新モデルを選んだからといって最大 effort や並列エージェントを自動有効化しない。ホストが返す対応値と既存リスク条件の共通部分を使う。新しい effort の追加は能力・費用・委任方針を検証してから行う。
11. **全経路と文書を更新。** Bash / PowerShell selector、renderer、起動 launcher、インストール後の agent、契約、README、利用者/貢献者向け文書、能力表、変更履歴、CI の検出を対象にする。古い証跡・凍結済み仕様は書換えず、現行文書から歴史的記録を区別する。

## 初回移行と受け入れ条件

初回はこの環境で一覧確認できた GPT-6.1 Sol / GPT-6 Astra / GPT-6 Luna を役割別採用の候補とし、公式情報と実測で能力対応を確認する。Claude / Copilot は当該ホストで確認できたモデルだけを採用し、確認不能なホストを検証済みと扱わない。

- モデル追加・後継公開・旧モデル廃止・アカウント不許可・一覧のページ送り・取得失敗・古いキャッシュ・未知モデル・不正入力の選択結果が検証可能である。
- 役割別上書き、pinned、予算超過、非対応 effort、alias 解決、生成 agent の優先順位、起動要求と応答の不一致をテストする。
- 正規 launcher / インストール後経路で選択が反映され、旧モデル名のコメントだけを直した状態では合格しない。
- 選択証跡と独立レビューの実 ID が結び付き、モデル変更時に履歴が混ざらない。
- Bash / PowerShell の条件・大小文字・エラー処理を一致させ、既存ゲートの能力下限・独立性・検証を維持する。
- 比較評価用の固定設定で再実行できる。確率的な出力の完全一致を再現性の条件にしない。
- 既存の鮮度チェックを活用し、毎回の通常 CI で有料モデル評価や公開通知を走らせない。モデル関連変更では selector/adapter/証跡のテストを CI で選択する。

## 承認範囲と進行

本書の方式・既定動作・明示固定・停止条件・既存週次保守・移行/文書/検証を承認対象とする。承認後、リポジトリの通常の仕様・設計・タスクレビューを経て実装する。既に承認された CI 効率化は継続し、この追加機能の承認待ちで止めない。実クラウド検証用サンドボックスは引き続き未用意として扱う。

## 実装承認

ユーザーが本案への質問に「この案で実装を承認」と回答。上記の範囲・制約を実装に適用する。通常の仕様・タスク・品質レビューは維持する。

## 承認後の呼び出し元調査（同日）

既存 Google パネリストにも固定値 `gemini-2.0-flash` が残る（`plugins/sdd-quality-loop/scripts/run-panelist-gemini.sh:52`、対応 PowerShell `:34`）。既存の全起動経路を更新する承認範囲で取り扱い、新しい外部送信先を追加するものではない。[Gemini CLI の選択](https://geminicli.com/docs/cli/model/)には Auto と明示指定があるが、[Gemini API の latest](https://ai.google.dev/gemini-api/docs/models) は preview/experimental を指す場合もある。採用済みの方針どおり、未検証の alias 一括置換は避け、外部送信の同意と実 ID の確認条件を維持する。

Copilot の公式 SDK は実行時モデル一覧を提供する（[公式 SDK](https://github.com/github/copilot-sdk)）。利用時は既存依存または既存 CLI の対応を確認し、この機能だけのために不要な SDK を導入しない。API 用一覧と CLI の契約・組織設定を混同しない。

この作業シェルでは Codex CLI 0.159.2 を確認できた。Claude/Copilot/Gemini の実 CLI 実行はまだ確認できていないため、これらの起動互換性を実機検証済みとは記録しない。

同日、実際の selector に利用可能一覧で確認した ID を渡す read-only 比較も実施した。`gpt-6.1-sol` は未登録候補として exit 1、`gpt-6-astra` は exit 0。価格欄は検査用の合成値であり、実価格の測定ではない。推論は実行していない（`model-selection-selector-baseline-20261018.json`）。

Codex CLI 0.159.2 の生成 schema も確認した。`Thread.model` は設定済み/永続化されたモデルであり、ターン単位の実行テレメトリではないと明記されている。`model/rerouted` 通知は変更元・変更先と thread/turn を返す。設定値を実行モデルの証明へ読み替えず、通知を収集し、実 ID が得られなければ未確認と記録する。実 ID 証明を必須とするゲートの停止条件は維持する（`model-selection-host-schema-20261018.json`、[公式イベント仕様](https://learn.chatgpt.com/docs/app-server)）。
