# Changelog

## v0.6.2

### 変更内容

Codexエージェントロールファイルの検証・ガード・診断を追加。

## v0.6.1

### 変更内容

ハーネス監査に基づく信頼性修正リリース。機能追加はありません。

**強制レイヤの穴を修正**: Claude Code 用フックの承認ガードに `apply_patch` マッチャーを追加 (Codex 用設定との不一致でバイパス可能だった)。Copilot 用フックが `pwsh` のみの環境でフェイルオープンしていた問題を修正 (`pwsh` 優先 + `powershell.exe` フォールバック)。

**ガード4ランタイム (js/py/sh/ps1) の挙動統一**: `tasks.md` パス判定を全ランタイムで大文字小文字非区別に統一。Python ガードのキルスイッチ判定を stdin 読み込みより前に移動し、TTY ハングを防止。キルスイッチ単体スクリプトが `CLAUDE_PROJECT_DIR` とカレントディレクトリの両方を確認するよう統一。旧世代の `guard-task-approval.{sh,ps1}` (キルスイッチ/apply_patch 非対応) を削除。

**インストーラ修正**: `install.sh` がインストール先に `.codex/.codex/` 等の入れ子ディレクトリを作成するバグを修正。失敗時ロールバックを堅牢化 (Windows のファイルロックでも復元を試行)。エラー伝播を明示化。

**テスト/CI強化**: Linux (ubuntu-latest) を CI マトリクスに追加。`.gitattributes` で EOL を固定。Python ガード・キルスイッチ・MultiEdit ペイロード・インストーラ再実行冪等性・Copilot 登録の直接テストを追加。CI 失敗時のログアーティファクト保存を追加。

## v0.6.0

### 新機能

**brownfield導入サポート (`sdd-adopt`)**: プロジェクト開始後に SDD を採用する「brownfield導入」シナリオ向けスキル。`AGENTS.md` / `CLAUDE.md` / `docs/adr/` / `docs/review-tickets/` / `reports/` をスキャフォールドし、`specs/<feature>/adr/` などの旧配置 ADR を `docs/adr/` へ移行する。ホスト (GitHub / GitLab) に合わせたテンプレートを選択。

**構造プリフライトチェック (`check-sdd-structure`)**: `plugins/sdd-bootstrap/scripts/check-sdd-structure.sh` / `.ps1` が必須ファイル・ディレクトリの有無を検査し `missing:` / `advisory:` / `drift:` / `host:` 行で報告。不足時は exit 1。`sdd-bootstrap-interviewer` が feature / bugfix / refactor モード開始時に自動実行し、不足があれば `sdd-adopt` の実行を促して停止する。

**implement-task / quality-gate の明示的前提条件**: `AGENTS.md` が存在しない場合、両スキルがガイダンス付きで停止し `sdd-adopt` の実行を促す。

### v0.5.0 からの移行

| v0.5.0 | v0.6.0 |
|---|---|
| brownfield導入の公式サポートなし | **`sdd-adopt` スキル追加**: `AGENTS.md`/`CLAUDE.md`/`docs/adr/`/`docs/review-tickets/`/`reports/` をスキャフォールド。ホスト (GitHub/GitLab) に合わせたテンプレートを選択。旧配置 ADR (`specs/<feature>/adr/`) を `docs/adr/` へ移行 |
| 構造チェックなし | **`check-sdd-structure.sh` / `.ps1` 追加**: 必須構造の有無を `missing:`/`advisory:`/`drift:`/`host:` 行で報告。不足時は exit 1 |
| interviewer がそのままインタビューを開始 | **プリフライト必須化**: feature / bugfix / refactor モードで `check-sdd-structure` を自動実行。不足があれば `sdd-adopt` を促して停止 |
| implement-task / quality-gate は AGENTS.md 不在でも継続 | **明示的前提条件**: `AGENTS.md` 不在時にガイダンス付きで停止し `sdd-adopt` を促す |
| ADR 配置が曖昧 | **ADR 正規配置を `docs/adr/` に統一** |

## v0.5.0

### 新機能

**macOS/Linuxインストーラ追加**: `install.sh` により `curl | bash` ワンライナーで macOS 13+ および Linux へ導入可能。フラグは PowerShell 版と対称 (`--target`, `--plugins`, `--install-root` 等)。

**Claude CodeフックのNode.js exec form化**: `hooks/claude-hooks.json` が `sh` 経由のシェル形式ではなく `node` コマンドの exec form を使用。Git Bash 不要の Windowsネイティブ対応を実現。

**CIをWindows+macOSマトリクスに拡張**: `.github/workflows/test.yml` が `windows-latest` と `macos-latest` の両方でテスト実行。`hooks.tests.ps1` を CI に追加。

**PS 5.1のTLS 1.2強制**: PowerShell 5.1 環境で `[Net.ServicePointManager]::SecurityProtocol` を TLS 1.2 に設定し、ダウンロード失敗を防止。

**check-task-state.shのmktemp化**: 競合状態を排除するため一時ファイルに `mktemp` を使用。

### v0.4.0 からの移行

| v0.4.0 | v0.5.0 |
|---|---|
| Windowsのみインストーラー (`install.ps1`) | **クロスプラットフォーム対応**: `install.sh` により macOS 13+ / Linux へ `curl \| bash` で導入可能 |
| Claude Codeフックが `sh` 経由のシェル形式 (Git Bash必須) | **Node.js exec form化**: `hooks/claude-hooks.json` が `node` コマンドの exec form を使用。Git Bash 不要 |
| CI は windows-latest のみ | **マトリクスCI**: `windows-latest` と `macos-latest` の両方で実行。`hooks.tests.ps1` を CI に追加 |
| PS 5.1でダウンロード失敗する場合あり | **TLS 1.2強制**: `[Net.ServicePointManager]::SecurityProtocol` を TLS 1.2 に設定 |
| `check-task-state.sh` が固定パス一時ファイル | **mktemp化**: 競合状態を排除 |

## v0.4.0

### 新機能

**Copilot CLI対応**: SKILL.md スキル、`*.agent.md` エージェント (`sdd-investigator` / `sdd-evaluator`)、`hooks/copilot-hooks.json` (preToolUse、stdout `permissionDecision` フォーマット)。`-Target Copilot` でインストール。

**Codex hooks/agents対応**: `hooks/hooks.json` に `command_windows` フィールドを追加し Windows Codex 環境をサポート。`apply_patch` ペイロードを処理する。`.codex/agents/` TOML エージェントをインストーラーが `~/.codex/agents/` へコピー。

**統一ガード `sdd-hook-guard`**: kill-switch とタスク承認チェックを1スクリプトに統合し、Claude Code / Codex / Copilot の3ランタイムで共通動作。

**check-contract / check-task-state 強化**: `waiver_reason` 必須化、証拠パストラバーサル防止、重複タスクID検出、実装レポート必須 (`Implementation Complete`)、`Blocked`/`Done` 検証強化。

**CIテンプレートのフェイルクローズ化**: `TODO_REPLACE_WITH_PROJECT_COMMANDS` マーカーにより未設定のまま CI が通過しない。

### v0.3.0 からの移行

| v0.3.0 | v0.4.0 |
|---|---|
| Claude Code のみ対応 | **Copilot CLI対応**: SKILL.md スキル、`*.agent.md` エージェント、`hooks/copilot-hooks.json` (preToolUse、既知の不具合: サブエージェント内) |
| Codex hookなし / エージェントなし | **Codex hooks/agents対応**: `command_windows` フィールド追加、`apply_patch` ペイロード処理、`.codex/agents/` TOML エージェント、インストーラーが `~/.codex/agents/` へコピー |
| 個別の kill-switch / guard スクリプト | **統一ガード `sdd-hook-guard`**: 3ランタイム共通、kill-switch + タスク承認チェックを統合 |
| check-contract / check-task-state 基本版 | **強化版スクリプト**: `waiver_reason` 必須化、証拠パストラバーサル防止、重複タスクID検出、実装レポート必須 (`Implementation Complete`)、`Blocked`/`Done` 検証強化、ベースライン必須セット保護 |
| CIテンプレートがコマンドなしで通過 | **フェイルクローズ化**: `TODO_REPLACE_WITH_PROJECT_COMMANDS` マーカーで未設定のまま通過しない |

## v0.3.0

### 新機能 (参考)

**調査フェーズ (investigate-codebase)**: `sdd-investigator` エージェントが読み取り専用でコードを解析し、`INV-xxx` 知見と `BL-xxx` 基線動作を生成する。

**refactorモード**: `sdd-bootstrap-interviewer` に追加。`baseline-behavior.md` が必須前提となり、受入条件を BL 同値として表現する。

**決定論的検証ゲート**: Default-FAIL 契約 (`verification-contract.json`)、`check-contract` / `check-placeholders` / `check-task-state` スクリプト (.sh / .ps1) により、エージェント自己申告に依存しない機械検証を実施する。

**独立 Evaluator**: `sdd-evaluator` サブエージェント (Claude Code) または新規セッション (Codex) が実装文脈を持たない状態で批判レビューを行う。

**Claude Code フック強制層**: `PreToolUse` フックがキルスイッチ (AGENT_STOP) と自己承認の強制ブロックを行う (現在は `hooks/claude-hooks.json` + `kill-switch.js` / `sdd-hook-guard.js` の Node.js exec form に移行済み)。

**ワークフローレトロスペクティブ**: `workflow-retrospective` スキルがリワーク指標を計測し、WFI (Workflow Improvement) 提案を人間承認ループで適用する。

### v0.2.0 からの移行

| v0.2.0 | v0.3.0 |
|---|---|
| bootstrap は3モード (project/feature/bugfix) | 4モード (+ `refactor`) |
| 調査フェーズなし | `investigate-codebase` (Stage 0) が追加 |
| `quality-gate` はエージェント自己申告を許容 | Default-FAIL 検証契約 + 決定論的スクリプトゲート |
| 独立レビューは任意 | `sdd-evaluator` サブエージェント (または新規セッション) が必須 |
| フックなし | `hooks/hooks.json` が承認ガード / AGENT_STOP を強制 |
| レトロスペクティブなし | `workflow-retrospective` + WFI ループが追加 |
