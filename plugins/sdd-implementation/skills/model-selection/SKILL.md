---
name: model-selection
description: 新規対話セッションのメインとsdd-forgeの役割別モデル・推論設定を選択し、前回設定を確認する。起動時の案内、設定変更、モデル起動失敗後の再選択に使う。
disable-model-invocation: false
user-invocable: false
---

# セッションのモデル選択

新規の**対話**セッションで、最初のSDD作業・委任より前に実行する。
非対話CLI、CI、既に実行中の管理されたワーカー、resume、compactでは既存動作を維持する。
フックがないホストではbootstrap/shipからこの手順へ入り、同一セッション内では繰り返さない。

## 取得と確認

1. このスキルと同じインストール版の `../../scripts/session-models.py` を解決する。
   対象プロジェクトをcwdにし、`begin --host <claude-code|codex-cli|gemini-cli> --session <id>` を実行する。
   JSONをhead等で途中切断しない。大きい場合も全体をパースし、各社のID・表示名・推論強度・取得状態を抽出する。
   ホスト発行のsession IDを使い、不明ならUUIDを一度生成して保持する。
   新規セッションで再取得し、選択画面を開き直す際は15分以上古い一覧を更新する。
   明示的な更新・認証変更・実行失敗後は `begin --refresh`。更新は選択を保留へ戻し、再確認を必要とする。
2. **共通のモデル選択UI**として、取得した情報だけから次の順で選択肢を提示する。
   - プロバイダー: Claude Code / Codex / Gemini CLI。メインは現在のCLIだけ、役割別は他社も選べる。
   - 使用モデル: 選択したプロバイダーの `catalog.models` の `display_name`（なければ `model`）。
     設定には返却された `model` をそのまま使う。DefaultもCLIが返したときだけ表示する。
   - 推論強度: そのモデルの `efforts` と「CLI既定」。Low / Medium / Highなどの共通固定リストは作らない。
     `default_effort` がある場合はCLI既定の値も表示する。nullは「既定値は未取得」であり「既定なし」ではない。
     空配列なら「CLI既定（取得経路に選択肢なし）」と表示する。
   - 更新: `begin --refresh` で再取得する。前回設定は現在の一覧と照合して表示し、勝手に代替しない。
   一覧はモデルと推論強度が分かる表にする。使用者が選ぶまで設定しない。
3. 取得は `model-discovery.py` の共通インターフェースとCLI別アダプターが担当する。
   CodexはApp Server `model/list`、ClaudeはSDKの制御プロトコルの初期化応答、Geminiは認証後のACPセッション一覧。
   既存CLIが認証方式と接続先を解決する。APIキーを再入力させず、認証情報を読出し・コピーしない。
   `auth_mode` がapi-keyならAPIキー経路、subscriptionならChatGPT認証経路（有料プランの保証ではない）、oauthならOAuth認証経路、
   cli-managedなら「既存CLIの認証を使用（課金方式は未確認）」と説明する。利用枠や無料利用を推測しない。
   `status=unavailable` は取得失敗として理由と再取得を提示する。固定名・環境変数のモデル名・古い公開一覧で補わない。
   `listed` はこのCLIから取得した一覧であり、推論成功や実際の配信モデルの証明ではない。
   Geminiの現行ACPにはモデル別推論強度がなく、権限モードを推論強度に流用しない。
4. メインと全17役割を1行ずつ表にし、選択したモデルを他の行へコピーするか、個別に変更するかを尋ねる。
   コピーも使用者の同意後だけ実行する。panelist-gptはCodex、panelist-geminiはGeminiを維持する。
   表には推論強度と「対応する起動経路／ポリシー検証が必要／アダプター未対応」も示す。
   対応しない組み合わせは確定前に説明し、別CLIへの変更または役割の無効化を選んでもらう。
5. 使用者が選んだ行を
   `set --session <id> --role <main|role> --host <host> --model <返却ID> --effort <default|返却値>` で記録する。
   未指定の役割を継承と解釈しない。利用しない役割は使用者の同意後に
   `disable --session <id> --role <role>` で無効化する。未導入CLIの利用を必須にしない。
   一覧外のIDを使用者が標準 `/model` で確認した場合のみ、既存の `add-candidate` で未確認候補として追加できる。
   これは取得失敗を隠す代替一覧ではなく、推論強度や実配信証明も付与しない。
6. メインは現在のCLIの標準 `/model` と対応する推論設定操作で、選んだ値を適用してもらう。
   このスクリプト自体は実行中のメインを変更しない。設定全体の承認とメインへの適用確認を受けた後だけ
   `confirm --session <id> --main-applied` を実行する。保留中はSDD作業・委任を開始しない。
   キャンセルは `cancel --session <id>`。非対話実行にこの選択UIを追加しない。

## 役割への適用

新しい役割の割り当て前に `selection --session <id> --role <role>` を読み取る。
保存された前回設定だけでは実行を認可しない。選択済みのワーカー内で再選択しない。

- **Codexの独立レビュー／評価**: 既存 `launch-codex-review.py` の
  `--model-session <id>` を渡す（独自の保存先を使った場合は `--model-config-home <path>` も指定）。
  ランチャー自体が確定済み設定と役割・CLIを照合する。明示引数との競合は停止する。
  元のprecheck、入力manifest、隔離、権限プローブ、idle identity予約、結果検証をすべて維持する。
- **既存の管理された起動**: 既存のpolicy requestに対し
  `request --session <id> --role <role> --input <request.json>` を実行し、stdoutの更新済み要求を
  プロジェクト内の新しい要求ファイルとして保存して、元のmanaged-entry/launcherへ渡す。
  入力要求のhostは選択CLI、roleは選択役割に一致させる。起動の新しい観測・バインド・権限検証は
  従来どおり実行する。候補一覧をmodel-observationへ変換しない。
- **クロスモデルpanelist**: 既存のrun-panelist-gpt/run-panelist-geminiへ `--model-session <id>` を渡す。
  独自の保存先なら `--model-config-home <path>` も渡す。Bash・PowerShellとも
  アダプターが確定済みモデルとGPTの明示推論設定を元の `--model`／`--effort` へ渡す。元の入力サニタイズ・同意・結果検証を維持する。
  管理された起動では上記requestを使い、legacyへ切り替えない。
- **対応経路がない場合**: 対象役割を停止し、利用できない経路を具体的に示して再選択を求める。
  現在、Geminiの汎用独立レビュー用アダプターはない。Claudeも全役割がmanaged-entryに対応するわけではない。
  汎用の `claude -p` / `codex exec` / `gemini -p` を追加して既存の保護を迂回しない。

明示的な既存モデル・推論設定との競合、認証エラー、取得失敗、制限、ポリシー不適格では
停止して理由を表示する。自動代替や既定モデルへの黙った変更は禁止。
再選択時は `begin --refresh` から確認し直す。過去の実行の選択を遡って変更しない。

## 保存と秘密情報

設定はXDG_CONFIG_HOME（未設定なら `~/.config`）下のsdd-forge/model-profilesに
プロジェクトの実パスのハッシュ別に保存する。別CLIのメインは別欄、役割の前回設定はプロジェクト共通。
認証情報や生のアカウント情報は保存しない。設定をGitや共有プロジェクトへコピーしない。
CLIのログインを代行したり、新しいAPIキーを要求したりしない。
