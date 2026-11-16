> 2026-11-15更新: ユーザーが、このWorkセッションでは利用者向けSDD承認フローに代えて
> 開発用スキル・独立レビュー・テストで実装を進めることを明示承認した。
> 以下は承認前の診断記録として保存する。通常利用のガード・署名情報は変更しない。

# セッション開始時のモデル選択：実装再開の引き継ぎ

記録日時: 2026-11-15T09:29:29Z

対象リビジョン: `08e56b843203ad5dc86b25ec4481d0d7497591b8`

作業ブランチ: `work-20261115-182746-session-model-selection`

状態: 実装未着手。以下は診断・再開用の記録であり、正規の仕様、レビューPASS証拠、タスク承認ではない。

## 承認された機能と境界

2026-11-15のインタビューと提案計画を受け、ユーザーから「Implement the proposed plan.」という実装指示を受領した。

- Claude Code、Gemini CLI、Codex CLIの通常の新規セッションでモデル候補を取得する。起動フックで対話できない場合、最初の応答で選択し、確定後に作業を開始する。
- メインは起動したCLI内のモデルから選ぶ。他社CLIへのメインセッション移動は対象外。
- sdd-forgeのサブエージェント全役割についてモデルを役割別に選ぶ。他社のモデルも候補とする。sdd-forge外の任意のエージェント制御は対象外。
- 対応するモデルでは推論の強さも選ぶ。非対応値を渡したり、別設定へ黙って置換したりしない。
- 設定は端末内でプロジェクト別に保存し、Git共有しない。新規セッションでは候補を更新し、前回設定を一括確認するか役割単位で変更する。
- 公式情報や設定由来の未確認候補も表示できるが、取得元と確認状態を示す。モデル名が存在することと、現在の認証で利用可能なことを混同しない。
- インストール・ログイン済みの各社CLIを実行に使う。新しいAPIキー管理・直接API経路は追加しない。
- 起動失敗時は対象の役割を止め、理由を表示して再選択する。他モデルへの自動フォールバックはしない。
- 既存の入力・結果・権限・レビュー独立性・モデルポリシーを維持する。設定未導入の既存経路と非対話実行は従来動作を維持し、入力待ちを増やさない。

## 開発環境と通常利用の区別

この作業はChatGPT Workの共有ワークスペース上で行っている。`/workspace/AGENTS.md` は、sdd-forge開発で専用CLIの起動を前提にせず、ローカル開発スキルを使うことを指定している。一方、リポジトリの通常貢献者向け `AGENTS.md` はSDDの仕様・設計・タスク・検証ゲートを要求している。

プラグイン利用者向けのbootstrapにはネイティブCLIのフック確認とProject Context承認検証がある。このWorkセッションのシェル／ファイル編集ツールが、インストール済みCLIのフック経由で動いているとは確認されていない。開発環境でのチェック失敗を、各CLI上での通常利用の不具合やフック無効化の証明として扱わない。

今回の依頼はプラグイン自体を変更する開発であり、sdd-forgeの通常利用を検証する際は指定の分離された `verify-codex` 環境を使う。認証情報やフック信頼を開発都合で書き換えない。

## フック確認の例外承認

2026-11-15の本セッションで、ユーザーは「フック確認を例外扱いにして実装を続けてよい。その後に停車した原因究明をしてください。」と明示した。メッセージの正確な送信時刻はホストから取得していないため推測しない。

直前の確認では実際のcanary書き込みが成功し、検証は `CAPABILITY_RUNTIME_UNAVAILABLE / WRITE_EXECUTED` となった。canaryは削除済み。この例外は当該開発セッションのフック確認に限定し、Project Context承認、レビュー独立性、レビュー結果、タスク承認や通常利用者のフック設定を解除しない。

`work/日時-…` 形式は既存の `work` ブランチとのGit参照名衝突で作成できなかったため、代わりに上記 `work-日時-…` ブランチを作成した。既存ブランチは削除・改名していない。

## 追加で判明した停止条件

フック確認の例外承認後、bootstrapのTrack Detectionに必要なProject Context承認を検証した。

実行場所: `/workspace/sdd-forge`

```sh
python3 plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py \
  --content sdd/project-context.yaml \
  --sidecar sdd/project-context.approval.json \
  --approver-registry sdd/approver-registry.yaml
```

実際の終了コード: `11`

```text
validate-approval-sidecar: NO_CONTEXT_KEY: no SDD_CONTEXT_KEY resolvable (env SDD_CONTEXT_KEY / env SDD_CONTEXT_KEY_FILE / <HOME>/.sdd/context-key all absent or empty); cannot verify HMAC -- a missing key is a hard failure, never a skip
```

安全な存在確認で判明した状態:

| 項目 | 状態 |
|---|---|
| `SDD_CONTEXT_KEY` | 未設定 |
| `SDD_CONTEXT_KEY_FILE` | 未設定 |
| `/home/agent/.sdd/context-key` | ファイルなし |
| 開発用プロファイル直下の `.sdd/context-key` | ファイルなし |
| 検証用プロファイル直下の `.sdd/context-key` | ファイルなし |

秘密値を出力していない。キー候補の値を探し回ったり、新しいキーを生成したり、既存sidecarを再署名したりしていない。キー未注入は、sidecarの署名が不正だという判定ではない。検証できない状態である。

`plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md` のTrack Detection C2は、Project Contextが物理的に存在して承認検証に失敗した場合、`PROJECT_CONTEXT_INVALID` として「Generate no artifact」と指定する。そのため、`specs/session-model-selection/`、レジストリ登録、レビューPASS、Draft/Approvedタスクはまだ作成していない。キー不足を理由に既存Contextを削除してC1へ落とすこともしない。

## 実装前に分かった接続箇所と注意点

- `plugins/sdd-implementation/scripts/model-policy.py` に、観測・選択・セッションへのバインド・起動制御の既存実装がある。現在の `_discover` はCodex以外を明示的にunsupportedとして扱う。未確認の候補を既存の検証済み観測へ変換してはならない。
- 既存 `select-agent-model` と `managed-model-entry.py` を優先して再利用する。選択UIだけを追加して、実際の起動引数へ適用されたことにしない。
- `contracts/model-policy.v1.json` には17役割がある。`panelist-gpt` と `panelist-gemini` はベンダー別の既存収集処理を持つ。役割別選択を加える際、クロスモデル検証のベンダー多様性や結果契約を壊さない設計が必要。全役割で全モデルが適格だと仮定しない。
- 現在のmanaged Claude起動は一部役割に限定され、汎用のGemini役割起動経路は確認できていない。会社をまたぐ実行は既存の安全な役割起動境界まで接続する必要がある。
- この環境で存在確認できたCLIは `/opt/codex/bin/codex`。Claude・Geminiの実CLI検証は未実施。既存のhook設定は主に `PreToolUse` であり、起動時対話やメインの変更が可能だという証拠はまだない。
- インストーラーの現在の対象は `All|Codex|Claude|Copilot|FilesOnly` で、Geminiの導入経路も確認・設計対象になる。

これらは作業時点の調査結果である。仕様レビューと実装直前に現在のソース、役割一覧、インストーラー、各CLIの公式機能を再確認する。

## 再開に必要な選択と手順

追加のContext承認検証については、次のいずれかが必要になる。フック確認だけの例外承認から推測して進めない。

1. **正規の検証を復旧する**: 既存sidecarに対応するキーを管理者が安全に環境へ注入し、同じ検証を再実行する。チャットやGitへキーを貼らない。任意の新しいキーでは既存署名を検証できない。
2. **開発セッション限定の追加例外を明示承認する**: このWork開発で当該Context承認検証をどう扱うかをユーザーが決め、対象・期間・残る検証を記録する。通常利用のガードや既存承認情報を変更する許可にはしない。

再開後の順序:

1. フック例外の記録を保持し、Context検証の復旧または明示された例外の範囲を確認する。
2. bootstrap Phase 1で7層仕様・受け入れ条件・必要な契約／ADRを作成し、featureを登録する。公式CLIの一覧・起動・切替・推論設定の能力を調査し、未対応を明示する。
3. specレビュー、設計レビューを既存のprecheckと独立コンテキストで実行する。Workのagent起動だけで「実行前のhost identity予約」を満たすとは仮定しない。必要なら既存のnative Codex reviewer launcherを試し、実際の起動証拠を保存する。
4. Phase 2でDraftタスクとtraceabilityを作成し、タスクレビューを行う。人間のタスク承認または明示的に適用できる既存承認根拠を記録し、承認済みタスクだけ実装する。
5. 一覧取得、確認状態、前回設定、役割別モデル／推論設定、適用確認、失敗時停止、非対話経路、秘密情報非保存のテストを実施する。既存モデルポリシーと配布パッケージの回帰を確認する。
6. 実CLIで確認できた範囲とfixtureだけで確認した範囲を分けて報告する。quality-gateだけがDoneを決定する。

現時点で機能の受け入れテストは作成・実行していない。SDD構造チェックは親セッションで `check-sdd-structure: OK` を確認済み。追加のContext検証失敗は上記の実測であり、レビューの自動承認拒否ではない。
