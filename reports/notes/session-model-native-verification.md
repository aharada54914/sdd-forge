# Claude・Gemini実CLI検証

実施日: 2026-11-15 UTC
対象: セッション開始時のモデル選択。結果は認証付き推論の成功とは区別する。

## 環境と判定基準

指定の分離されたverification-workspaceに公式npm配布のClaude Code 2.1.325と
Gemini CLI 0.68.0を固定して導入し、Node 26.13.0で実行した。
Claudeは専用CLAUDE_CONFIG_DIR、Geminiは専用GEMINI_CLI_HOMEを使用した。
実ユーザーの認証ファイルや既存フック信頼は変更せず、Geminiの新しい検証用
workspace/extensionだけ通常の確認画面から信頼・リンクした。認証情報は読出し・複製していない。

実施前にバージョン、manifest受理、実ホストのSessionStart実行、非対話時の入力待ち、
候補取得、認証付き応答、役割への適用を判定基準として分けた。偽CLIやモデル応答の代用品は
成功証拠に使っていない。モデル間の比較・盲検評価は今回の目的ではなく実施していない。

## 確認結果

| 対象 | 実機で確認した結果 | 限界 |
|---|---|---|
| Claude | 実CLIのplugin validate成功。修正後のSessionStartは1回、正しいclaude-code、終了0でadditionalContextを受理 | 確認ログはheadless起動。対話UIはログイン方法選択まで到達したが、認証付き応答は未実施 |
| Gemini | 実CLIでextensionをリンク・有効化。実対話起動のローカルtelemetryがSessionStartのsuccess=true、exit=0、39ms、interactive=trueを記録 | 認証付き応答と、モデルが案内に従う最初の応答は未実施 |
| 一覧・推論候補 | 実Claude --helpの対応値を読み取り。実Gemini公開一覧からautoと3つの具体的モデルIDを取得 | 一覧掲載は現在のアカウントの推論権限を保証しない |
| 未認証headless | ClaudeはNot logged inで終了1、Geminiは認証方法なしで終了41。確認入力待ちにはならなかった | 認証済みheadlessの実モデル応答は別途必要 |

## 見つかった不具合と修正

1. Claudeはmanifestの追加hooksだけでなく、既定のhooks/hooks.jsonも自動読込する。
   最初の実起動ではClaude用とCodex用が両方動き、2回の案内と誤ったCodexのホスト識別が生じた。
   Codex用を自動読込対象外のhooks/codex-hooks.jsonへ移し、Codex manifestを変更した。
   同じ実CLIの再起動で、Claude用だけが1回実行され、追加コンテキストの受理を確認した。
2. Geminiのhook timeoutの単位はミリ秒であり、10は10秒ではなく10msだった。
   実対話起動でSessionStart失敗を再現。10000msへ直し、実ホストの成功記録を確認した。

これらは今回追加したモデル選択機能の接続不具合であり、先のWork開発における
フック稼働証明／Project Context検証鍵不足とは別の事象である。
既存SDD承認・署名・ガードの判定は変更していない。

Gemini 0.68.0では `gemini models --output-format json` という公開一覧機能も確認したため、
先に--helpで対応を確認してから取得するよう改善した。旧CLIは位置引数をモデルへの
プロンプトと解釈する場合があるため、対応しない版では一覧コマンドを呼ばない。
返却IDを検証し、一覧にない公式aliasは未確認候補のまま残す。

## 再現する操作

- Claude: 専用CLAUDE_CONFIG_DIRを指定し、`claude plugin validate <implementation-plugin>`。
- Claude起動: `claude -p <短い確認依頼> --plugin-dir <implementation-plugin> --debug-file <専用ログ> --output-format json --no-session-persistence --strict-mcp-config --mcp-config '{"mcpServers":{}}'`。
  ログのSessionStart実行数・host・終了値・additionalContext受理と、未認証結果をそれぞれ確認する。
- Gemini: 専用GEMINI_CLI_HOMEで `gemini extensions link <implementation-plugin>/gemini`。
  新しい検証workspaceと自作extensionの確認には通常の画面から応答し、`gemini extensions list`で確認。
- Gemini一覧: `gemini --help`でmodelsの存在を確認後、`gemini models --output-format json`。
- Gemini起動: 実PTYで `gemini --debug --approval-mode plan`。
  ローカルだけのtelemetry出力を指定してSessionStartの成功・終了値・時間を確認し、検証後に終了する。

## 認証により未完了の範囲

開始時の安全な存在確認では、両社の認証用環境変数と標準認証ファイルはなかった。
Claudeの実auth statusはloggedIn=false、Geminiの実headlessは認証方法未設定だった。
ユーザーへOAuthまたは安全な環境設定の選択を依頼したが、この記録時点では応答・利用可能な認証を得ていない。
認証なしでモデル応答、メイン切替後の推論、サブエージェントの実配信を成功扱いにしていない。
OAuthは勝手に開始せず、秘密値をチャットへ貼るよう求めていない。

認証の準備後は、新規対話セッションの最初の応答、実際のモデル／推論設定の変更、
対応する役割の起動と失敗時の再選択を続けて確認する必要がある。

機械可読の結果: `reports/verification/session-model-native-results.json`。
rawログとローカルtelemetryは分離した検証領域に留め、認証情報・端末識別情報を含みうる生データはGitへ入れていない。

## 修正後の検証とレビュー

- `tests/session-models.tests.py`: 43件成功。実インストーラー経由のBash／PowerShell配布確認も含む。
- `tests/lib/install-payload-check.py --runtime bash`: 11件成功、2件はプラットフォーム条件によりskip。
- Python構文検査と差分の空白検査は成功。
- 別コンテキストの読取専用レビュー `/root/design_review` は、フック分離・Geminiのtimeout・公開一覧取得について新たなMajor/Critical指摘なし。

認証の準備に対する回答はまだ得られていないため、認証後の項目を完了とせず、再開可能な状態で記録する。
