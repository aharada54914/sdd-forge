---
name: model-selection
description: 新規対話セッションのメインとsdd-forgeの役割別モデル・推論設定を選択し、前回設定を確認する。起動時の案内、設定変更、モデル起動失敗後の再選択に使う。
disable-model-invocation: false
---

# セッションのモデル選択

新規の**対話**セッションで、最初のSDD作業・委任より前に実行する。
非対話CLI、CI、既に実行中の管理されたワーカー、resume、compactでは既存動作を維持する。
フックがないホストではbootstrap/shipからこの手順へ入り、同一セッション内では繰り返さない。

## 取得と確認

1. このスキルと同じインストール版の `../../scripts/session-models.py` を解決する。
   ホストは `claude-code`、`codex-cli`、`gemini-cli` のいずれか。ホスト発行のsession IDを
   利用する。不明なら新しいUUIDを一度生成して会話中保持する。他セッションのIDを再利用しない。
2. 対象プロジェクトをcwdにし、Pythonで以下を実行する（パスや値はそれぞれ独立した引数）。
   `session-models.py begin --host <host> --session <id>`。
   `--refresh` は再取得・やり直し時だけ指定する。beginの再実行は通常は同じ状態を返す。
   全社の候補、取得元、確認状態、CLIの有無と前回設定を読み取る。
3. メインと全17役割の設定を表で提示する。前回設定を一括承認するか、変更する行を選べるようにする。
   初回は共通モデルを提案してよいが、ユーザーの同意なくモデルを決めない。
   メインは起動したCLIのモデルだけ。サブは別会社も選べる。
   panelist-gptはCodex、panelist-geminiはGeminiを維持してクロスモデル検証の多様性を保つ。
   全社モデルがすべての役割で実行可能とは限らない。下記の実行経路を確認し、
   設定表に「対応する起動経路／ポリシー検証が必要／アダプター未対応」の列を付ける。
   未対応の組み合わせは確定前に説明し、対応CLIへの変更または役割の無効化を提案する。
4. `unverified` は現在の認証で利用可能と未確認、`listed` はCLI一覧への掲載のみ。
   推論の実行権限や実際のバックエンドモデルを保証しない。CLI未導入の候補は選べない。
   表示された `efforts` と「CLI既定」だけを提示し、未確認の推論値を推測しない。
   利用したい具体的IDがない場合は、そのCLIの `/model` で確認し、`add-candidate` で未確認候補として追加できる。
5. 各変更を `set --session <id> --role <main|role> --host <host> --model <id> --effort <default|value>` で反映する。
   未指定の役割を継承と解釈しない。初回は全役割を明示的に設定する。
   利用しない役割や未導入CLIのpanelistは、ユーザーの同意後に
   `disable --session <id> --role <role>` で明示的に無効にできる。無効役割の割り当て時は停止する。
6. メインは標準の `/model` と、そのホストの推論設定操作で適用するよう案内する。
   このスクリプトは既に動作しているメインのモデルを変更しない。
   ユーザーから設定全体の承認とメインへの適用確認を受けた後だけ
   `confirm --session <id> --main-applied` を実行する。これは設定の確認記録であり、実配信証明ではない。
   保留中に本来のSDD作業を進めない。キャンセルは `cancel --session <id>`。

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
