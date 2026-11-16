# 共通モデル一覧取得とCLIアダプター

実施日: 2026-11-15 JST
対象: `work-20261115-182746-session-model-selection`

使用者の指定に従い、共通の会話内選択UIとCLI別の一覧取得を分離した。
標準 `/model` への案内だけで済ませる案は採用せず、プロバイダー・モデル・推論強度を
sdd-forge の共通UIで選ぶ。メインの実設定は引き続き各CLIの標準操作で適用確認する。

## 変更

- `model-discovery.py` に共通の正規化・失敗処理・制御通信と3つのアダプターを配置。
  選択状態の保存と既存の起動ポリシーは `session-models.py` 以下に残した。
- Claude: 公式Agent SDKの `supportedModels()` と同じ制御プロトコルの初期化応答を使用。
  `models[].value`、`displayName`、`supportsEffort`、`supportedEffortLevels` を取得する。
  `[1m]` のようなCLIが返すモデルIDも保存できる。
- Codex: App Serverの `account/read` と `model/list`。`includeHidden=false`、全ページ取得、
  表示名・モデル別推論強度・既定の推論強度を正規化する。
  UI一覧は起動証拠ではないため、強い起動検証用の `model-policy.py` は変更していない。
- Gemini: ACPの `initialize` / `session/new`。既存認証を解決した後の
  `models.availableModels` を取得する。認証前の `gemini models` の一覧は使用しない。
- 固定のモデル候補、環境変数からの候補追加、Claudeのhelpから全モデル共通の努力値を推測する処理を削除。
  推論強度は返却された文字列を検証して保存し、low/high等を固定のモデル能力として補わない。
- 新規セッション、明示更新、15分以上経過後の選択画面再表示で再取得する。
  同じセッションの仮選択は保持し、確認状態をpendingに戻す。廃止されたモデル・努力値は確定時に停止。
  キャンセル済みセッションは明示更新するまで再開しない。常駐更新はしない。
- 共有スキルUIで全体をパースして候補を表にし、選択・役割へのコピーは使用者の同意後に行う。
  取得できないモデルや努力値は固定例で補わない。既定の努力値が未取得なら「なし」と断定しない。
- Bash/PowerShellインストーラーの必須配布ファイルと検証カタログを更新。
  v1保存形式は維持し、表示名・既定努力値・認証経路の項目は任意の追加フィールドとした。

## 認証と境界

認証の読出し・キーの入力・ログイン代行・直接のモデルAPI呼出しは追加していない。
CLI自身が既存のOAuth/APIキー/外部プロバイダー設定を解決する。
Geminiでは `authenticate` を呼ばず、取得に失敗してもAPIキー経路へ切り替えない。
認証方式は生のアカウント情報から必要な区分だけを残す。
ClaudeのOAuthを有料サブスクリプションと断定せず `oauth` と分類する。
CodexのChatGPT認証経路も、有料プランや推論成功を保証するものではない。

制御通信は時間・出力サイズ・ページ数に上限を持ち、同じカーソルの繰り返し、重複モデル、
不正ID、重複JSONキーを拒否する。子CLIからのファイル・ツール・権限要求を承認しない。
子プロセスを終了・回収し、生のstderr、認証情報、例外メッセージを一覧やエラーへ出さない。

## 実機と回帰検証

固定版 Claude Code 2.1.325 / Gemini CLI 0.68.0、既存Codex、Node 24.19.0で実施。
認証値を表示せず、専用設定を使った分離verification-workspaceで検証した。

| CLI | 取得件数 | 実測した推論強度 | 認証経路 |
|---|---:|---|---|
| Claude | 5 | low / medium / high / xhigh / max | APIキー |
| Codex | 8 | モデルにより low / medium / high / xhigh / max / ultra | ChatGPT |
| Gemini | 6 | ACPにモデル別の選択肢なし。CLI既定のみ | CLI管理。課金方式は分類しない |

Geminiでは認証前の一覧にあった旧名ではなく、gemini-3.8-flash、gemini-3.5-flash-lite等を
認証後のCLIから取得できた。この表の名前・件数は実測記録であり実装の固定候補ではない。

Claude Codeの実対話からスキルを呼び、3社19件とモデル別推論強度を表示した。
続けて使用者操作に相当する入力で sonnet / medium を仮選択し、保存状態がpending、
残り17役割が未設定、委任なしであることを確認した。
最初の実行でモデルがJSON出力をheadで切ったため、全体パースの指示とコンパクト出力を追加した。新しい対話セッションでJSON全体をパースし、
3社すべての候補と推論強度を表示することを再確認した。
会話原文・認証情報はGitへ保存せず、集計だけを保存する。

- モデル選択・配布経路: 42件成功、skip 0（指定PowerShellを使用）。
- 新アダプター: 11件成功。ページング、途中のアカウント変更拒否、動的努力値、認証失敗、未導入、機密エラー抑止、
  実パイプの権限要求拒否、タイムアウト、子プロセス回収を含む。
- Codexレビュー起動回帰: 20件成功、1件skip。
- 検証カタログ: 14件成功、1件skip。
- Bash配布ペイロード: 9件成功、4件skip（Node要件・プラットフォーム条件）。
- Python構文検査、Bash構文検査、差分の空白検査成功。

## 限界

取得結果はCLIが現在の認証・設定で返す候補であり、全モデルの推論成功やバックエンドIDの証明ではない。
Claude/GeminiのOAuth実アカウントでの取得はこの環境では未検証。
Geminiの現行ACP ModelInfoにはモデル別推論強度がなく、権限モードを流用しない。
既存の役割別起動アダプター・モデルポリシーが対応しないIDや努力値は従来どおり停止する。
この変更で全役割の新しい起動経路や、起動ポリシーの値域拡大を行ったわけではない。

設計・実装根拠は [ADR 0050](../../docs/adr/0050-session-model-preferences.md)、
集計は [model-discovery-adapters-results.json](../verification/model-discovery-adapters-results.json)。
実機の私有証拠は `verification-workspace/native-session-models/auth-resume/` に保持する。

## PR #780 のインストール配置回帰

バージョン付きプラグインキャッシュでも、レビュー起動とpanelistの往復が同じリリースの
session-models/session-panelistを解決するよう修正した。別バージョンへのフォールバックは行わない。
追加回帰を含むモデル設定43件、Codexレビュー起動22件（1件skip）が成功。
モデル設定の回帰はBashとPowerShellの両方でバージョン付き配置を実行した。
