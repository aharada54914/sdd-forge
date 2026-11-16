# Claude・Gemini 認証付き実機検証の再開

実施日: 2026-11-15 JST
対象ブランチ: `work-20261115-182746-session-model-selection`
対象実装: `d45f5b40147836587861d5db5978ab3567860a02`

前回の `session-model-native-verification.md` に対する追記。前回の未認証結果は履歴として維持する。
判定は、認証付き応答、候補取得、対話開始時の選択案内、ネイティブ切替後の応答、役割別配信に分けた。
モデル比較・独立審査・quality-gate の Done 判定ではない。

## 環境と認証

指定ブランチを origin から取得して継続。開始時の作業ツリーは clean。
前回の CLI インストール領域は存在しなかったため、指定の分離 verification-workspace 下に
Claude Code 2.1.325 / Gemini CLI 0.68.0 を公式 npm パッケージから固定導入した。
今回の Node は 24.19.0（前回は 26.13.0）。

最初に環境変数・標準認証ファイルの有無だけ確認した。
`ANTHROPIC_API_KEY` と `GEMINI_API_KEY` は設定済み、標準 OAuth ファイルはなかった。
Claude の `auth status` は exit 0、loggedIn=true、authMethod=api_key、apiProvider=firstParty。
認証情報の値は結果ファイルへ保存していない。CLI 初期画面には認証値を描画する経路があるため、
今後も認証画面の生出力を証拠ファイルへ転記せず、状態だけ抽出すること。

専用 CLAUDE_CONFIG_DIR / GEMINI_CLI_HOME を使用。Gemini の検証用フォルダーと
ローカル extension は通常の確認画面で信頼した。API キー入力画面は完了せず、
専用設定の `security.auth.selectedType=gemini-api-key` を指定して既存環境変数を利用した。
キーのコピーや OAuth 開始はしていない。

## 実測結果

| 項目 | 結果 | 証明の範囲 |
|---|---|---|
| Claude headless | sonnet 指定、exit 0、`SDD_AUTH_OK`、modelUsage は claude-sonnet-5-5 | 認証付き推論成功。plugin-dir 使用、ツール呼出しなし |
| Gemini headless | 初回 exit 55（未信頼フォルダー）。通常の信頼後 exit 0、`SDD_AUTH_OK` | 認証付き推論成功。認証失敗とは区別 |
| Claude plugin validate | exit 0 | manifest 受理 |
| Claude 新規対話 | model-selection を実際にロードし begin を実行。pending のまま、承認・適用確認を要求して SDD 作業と委任を停止 | 選択案内の実応答。17役割を個別の表として提示する形式は満たさなかった |
| Claude ネイティブ切替 | `/model haiku` の確認画面で承認、`/effort low` を実行。続く応答は `SDD_SWITCH_OK`、会話記録の model は claude-haiku-5-5 | モデル切替後の推論と CLI の effort 設定受理。サーバー内部の推論量の証明ではない |
| Gemini 新規対話 | API キー方式で起動、extension の起動フック実行表示あり。開始時の確認案内要求は約2分応答未完了のため中断 | 最初の選択案内は成功扱いにしない。原因は未確定 |
| Gemini ネイティブ切替 | `/model` → Manual → gemini-3.5-flash-lite を選択。続く応答は `SDD_SWITCH_OK`、会話記録の model も同じ | 実 UI 候補を選んだ切替と応答。役割別配信ではない |
| 候補取得 | 両 CLI の bin を PATH に加えて begin を再実行。両社 installed=true、Gemini listed、Claude の努力値 low/medium/high を取得 | 一覧取得は推論権限保証ではない |

最初の対話起動では CLI を絶対パスで実行したが、その bin を PATH に加えていなかった。
そのため Claude の begin は両 CLI を未導入と判定した。これは検証環境の設定漏れであり、
PATH を修正したスクリプト再実行では解消した。修正後の新規対話全体は未再実行。

## 公開一覧と実際のモデル名の不一致

Gemini の `models --output-format json` は前回と同じ
auto / gemini-2.5-pro / gemini-3.5-flash / gemini-3.1-flash-lite を返した。
しかし、指定モデルと応答統計は次のとおり異なった。

| 起動時の指定 | 応答統計のモデル |
|---|---|
| gemini-3.1-flash-lite | gemini-3.5-flash-lite（2回確認） |
| gemini-3.5-flash | gemini-3.8-flash |

対話 `/model` の Manual 一覧には gemini-3.1-pro-preview、gemini-3-flash-preview、
gemini-2.5-pro、gemini-3.5-flash-lite、gemini-3.8-flash、gemma-4-31b-it、gemma-4-26b-a4b-it が表示された。
CLI の公開一覧・起動引数・応答統計・対話候補は同一ではない。
不一致が CLI 内の解決、サービス側の解決、統計表記のいずれによるものかは未確定。
sdd-forge の候補を listed としただけでは指定 ID への実配信の証明にならない。
無断の代替モデル配信を検出できたという判定もまだしていない。

## 検証と残件

- `SDD_TEST_PWSH=/workspace/.tools/sdd-forge-dev/bin/pwsh python3 tests/session-models.tests.py`: 43件成功、skip 0。
- 最初の PowerShell 未指定実行は43件中2件 skip。上記の再実行で解消。
- 製品実装は変更せず、今回の変更は検証記録のみ。
- Gemini の初回選択案内、PATH 修正後の両社の対話全経路、全17役割の表形式提示・確定・前回設定再確認は未完了。
- 役割別の保護されたランチャー経由の実配信、失敗後の再選択は未検証。汎用 CLI 起動を役割配信の代用にはしていない。
- Claude CLI が追加で広告する xhigh/max と Haiku の effort 受理に対する、現行候補の対応範囲は別途確認が必要。

今回のタスクの会話記録・設定・サニタイズ済み集計は
`/workspace/.tools/sdd-forge-dev/verification-workspace/native-session-models/auth-resume/` に保持。
Git にはこの報告と秘密情報を含まない集計だけを保存する。
