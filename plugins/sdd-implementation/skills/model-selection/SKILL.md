---
name: model-selection
description: Dynamically fetch the latest available models and reasoning efforts from installed CLIs (Claude Code, Codex CLI, Gemini CLI) and optionally configure per-role overrides. Unconfigured roles inherit the active session model by default.
disable-model-invocation: false
user-invocable: true
---

# セッションのモデル選択（動的取得・任意上書き）

新規セッションの既定では、全サブエージェントが親セッションの現行モデル（`model: inherit`）をそのまま継承するため、**通常作業の開始前に本スキルで停止する必要はない**。
ユーザーが最新モデル一覧を確認したいとき、または役割別に別モデル・推論強度（GPT-6 Astra / Claude Opus 5.5 / Fable / Gemini 4 Neon 等）を明示指定したいときに実行する。

## 1. 最新モデル一覧の動的取得

このスキルと同じインストール版の `../../scripts/session-models.py` を対象プロジェクトルートで実行する:

```bash
python3 "<installed-root>/plugins/sdd-implementation/scripts/session-models.py" \
  begin --host <claude-code|codex-cli|gemini-cli> --session <session-id> --refresh
```

- 取得は `model-discovery.py` が各 CLI の最新ライブカタログから直接行う（固定候補リスト・ハードコード補完は行わない）:
  - **Claude Code**: SDK control `initialize.models`（`displayName` / `supportedEffortLevels` / `defaultEffort`）
  - **Codex CLI**: App Server `model/list`（`displayName` / `supportedReasoningEfforts` / `defaultReasoningEffort`）
  - **Gemini CLI**: ACP `session/new.models.availableModels`（推論強度が公開されていれば同時取得、未公開なら CLI 既定）
- JSON 出力は途中切断せず全体をパースし、プロバイダー・モデル ID・表示名・対応推論強度・`auth_mode` を表形式でユーザーへ提示する。
- `status=unavailable` の CLI は理由と再取得案内を表示し、他 CLI や固定名で勝手に代替しない。
- 一覧外の最新モデル ID をユーザーが標準 `/model` で確認済みの場合のみ `add-candidate` で登録できる。

## 2. 役割別設定（既定はすべて `inherit`）

対象となる v2 稼働役割:
`implementer`, `investigator`, `spec-reviewer-a`, `spec-reviewer-b`, `evaluator`, `domain-reviewer-a`, `domain-reviewer-b`, `workflow-auditor-a`, `workflow-auditor-b`, `diagnosis`, `self-improvement`

- **メインモデル設定**: `set --session <id> --role main --host <host> --model <返却ID> --effort <default|返却値>`
- **役割別上書き（任意）**: 変更したい役割だけ `set --session <id> --role <role> ...` で指定する。未指定の役割は `inherit`（メインモデル継承）として扱われ、全役割を手動入力しなくても確定できる。
- **無効化（任意）**: `disable --session <id> --role <role>`
- **確定**: ユーザーがメインの `/model` 切替と設定内容を確認した後に `confirm --session <id> --main-applied` を実行する（キャンセルは `cancel --session <id>`）。

## 3. 動的取得モデルの適用（Dynamic Passthrough）

- `selection --session <id> --role <role>` は確定済みの役割設定（`inherit` 時は `main` へ解決済み）を返す。
- ライブ取得済みモデル（`verification: listed`）であれば、静的 `contracts/model-policy.v1.json` に未記載の最新フロンティアモデル（例: `claude-opus-5-5`, `fable`, `gemini-4-neon`, `[1m]` 付き ID、新規 effort 値）でもそのままパススルー適用でき、古いモデルへ無断ダウングレードしない。
- 明示的な競合・認証エラー・CLI 実行失敗時は黙って代替せず、理由を示して `begin --refresh` による再選択を案内する。

## 保存と秘密情報

- 個人設定は `XDG_CONFIG_HOME`（既定 `~/.config`）配下の `sdd-forge/model-profiles/<project-hash>/` にのみ保存し、Git リポジトリ内へ書き込まない。
- 認証情報・API キー・生のアカウント情報は保存・転記しない。
