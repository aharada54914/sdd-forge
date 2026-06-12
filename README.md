# SDD Plugins Windows Installer

v0.6.2、クロスプラットフォーム対応 (Windows / macOS / Linux) — PowerShell または bash から、仕様化・実装・品質保証を分離した3つのSDDプラグインをCodex CLI、Claude Code、Copilot CLIへ導入します。

```text
[brownfield] sdd-adopt           既存プロジェクトへ SDD 構造を途中導入する
                                 (AGENTS.md/CLAUDE.md/docs/adr/等をスキャフォールド、ADR 移行)
       ↓
[Stage 0] investigate-codebase  既存コードを読み取り専用で調査し、INV/BL証跡を生成する
                                 (refactorモードでは必須、他モードは任意)
       ↓
sdd-bootstrap       仕様・設計・承認済みタスクを作る
                    モード: project / feature / bugfix / refactor
       ↓
sdd-implementation  承認済みタスクを実装可能な差分へ変換する
       ↓
sdd-quality-loop    実装後の品質と仕様整合性を独立して保証する
                    + workflow-retrospective でワークフロー自体を改善する
```

詳しい運用方法と実際の開発例は [USERGUIDE.md](USERGUIDE.md) を参照してください。

## v0.6.2 変更点

Codexエージェントロールファイルの検証・ガード・診断を追加。

## v0.6.1 変更点

ハーネス監査に基づく信頼性修正リリース。機能追加はありません。

- **強制レイヤの穴を修正**: Claude Code 用フックの承認ガードに `apply_patch` マッチャーを追加 (Codex 用設定との不一致でバイパス可能だった)。Copilot 用フックが `pwsh` のみの環境でフェイルオープンしていた問題を修正 (`pwsh` 優先 + `powershell.exe` フォールバック)。
- **ガード4ランタイム (js/py/sh/ps1) の挙動統一**: `tasks.md` パス判定を全ランタイムで大文字小文字非区別に統一。Python ガードのキルスイッチ判定を stdin 読み込みより前に移動し、TTY ハングを防止。キルスイッチ単体スクリプトが `CLAUDE_PROJECT_DIR` とカレントディレクトリの両方を確認するよう統一。旧世代の `guard-task-approval.{sh,ps1}` (キルスイッチ/apply_patch 非対応) を削除。
- **インストーラ修正**: `install.sh` がインストール先に `.codex/.codex/` 等の入れ子ディレクトリを作成するバグを修正。失敗時ロールバックを堅牢化 (Windows のファイルロックでも復元を試行)。エラー伝播を明示化。
- **テスト/CI強化**: Linux (ubuntu-latest) を CI マトリクスに追加。`.gitattributes` で EOL を固定。Python ガード・キルスイッチ・MultiEdit ペイロード・インストーラ再実行冪等性・Copilot 登録の直接テストを追加。CI 失敗時のログアーティファクト保存を追加。

## v0.6.0 新機能

- **brownfield導入サポート (`sdd-adopt`)**: プロジェクト開始後に SDD を採用する「brownfield導入」シナリオ向けスキル。`AGENTS.md` / `CLAUDE.md` / `docs/adr/` / `docs/review-tickets/` / `reports/` をスキャフォールドし、`specs/<feature>/adr/` などの旧配置 ADR を `docs/adr/` へ移行する。ホスト (GitHub / GitLab) に合わせたテンプレートを選択。
- **構造プリフライトチェック (`check-sdd-structure`)**: `plugins/sdd-bootstrap/scripts/check-sdd-structure.sh` / `.ps1` が必須ファイル・ディレクトリの有無を検査し `missing:` / `advisory:` / `drift:` / `host:` 行で報告。不足時は exit 1。`sdd-bootstrap-interviewer` が feature / bugfix / refactor モード開始時に自動実行し、不足があれば `sdd-adopt` の実行を促して停止する。
- **implement-task / quality-gate の明示的前提条件**: `AGENTS.md` が存在しない場合、両スキルがガイダンス付きで停止し `sdd-adopt` の実行を促す。

## v0.5.0 新機能

- **macOS/Linuxインストーラ追加**: `install.sh` により `curl | bash` ワンライナーで macOS 13+ および Linux へ導入可能。フラグは PowerShell 版と対称 (`--target`, `--plugins`, `--install-root` 等)。
- **Claude CodeフックのNode.js exec form化**: `hooks/claude-hooks.json` が `sh` 経由のシェル形式ではなく `node` コマンドの exec form を使用。Git Bash 不要の Windowsネイティブ対応を実現。
- **CIをWindows+macOSマトリクスに拡張**: `.github/workflows/test.yml` が `windows-latest` と `macos-latest` の両方でテスト実行。`hooks.tests.ps1` を CI に追加。
- **PS 5.1のTLS 1.2強制**: PowerShell 5.1 環境で `[Net.ServicePointManager]::SecurityProtocol` を TLS 1.2 に設定し、ダウンロード失敗を防止。
- **check-task-state.shのmktemp化**: 競合状態を排除するため一時ファイルに `mktemp` を使用。

## v0.4.0 新機能

- **Copilot CLI対応**: SKILL.md スキル、`*.agent.md` エージェント (`sdd-investigator` / `sdd-evaluator`)、`hooks/copilot-hooks.json` (preToolUse、stdout `permissionDecision` フォーマット)。`-Target Copilot` でインストール。
- **Codex hooks/agents対応**: `hooks/hooks.json` に `command_windows` フィールドを追加し Windows Codex 環境をサポート。`apply_patch` ペイロードを処理する。`.codex/agents/` TOML エージェントをインストーラーが `~/.codex/agents/` へコピー。
- **統一ガード `sdd-hook-guard`**: kill-switch とタスク承認チェックを1スクリプトに統合し、Claude Code / Codex / Copilot の3ランタイムで共通動作。
- **check-contract / check-task-state 強化**: `waiver_reason` 必須化、証拠パストラバーサル防止、重複タスクID検出、実装レポート必須 (`Implementation Complete`)、`Blocked`/`Done` 検証強化。
- **CIテンプレートのフェイルクローズ化**: `TODO_REPLACE_WITH_PROJECT_COMMANDS` マーカーにより未設定のまま CI が通過しない。

## v0.3.0 新機能 (参考)

- **調査フェーズ (investigate-codebase)**: `sdd-investigator` エージェントが読み取り専用でコードを解析し、`INV-xxx` 知見と `BL-xxx` 基線動作を生成する。
- **refactorモード**: `sdd-bootstrap-interviewer` に追加。`baseline-behavior.md` が必須前提となり、受入条件を BL 同値として表現する。
- **決定論的検証ゲート**: Default-FAIL 契約 (`verification-contract.json`)、`check-contract` / `check-placeholders` / `check-task-state` スクリプト (.sh / .ps1) により、エージェント自己申告に依存しない機械検証を実施する。
- **独立 Evaluator**: `sdd-evaluator` サブエージェント (Claude Code) または新規セッション (Codex) が実装文脈を持たない状態で批判レビューを行う。
- **Claude Code フック強制層**: `PreToolUse` フックがキルスイッチ (AGENT_STOP) と自己承認の強制ブロックを行う (現在は `hooks/claude-hooks.json` + `kill-switch.js` / `sdd-hook-guard.js` の Node.js exec form に移行済み)。
- **ワークフローレトロスペクティブ**: `workflow-retrospective` スキルがリワーク指標を計測し、WFI (Workflow Improvement) 提案を人間承認ループで適用する。

## Windowsワンライナー

```powershell
irm https://raw.githubusercontent.com/aharada54914/sdd-plugins-windows-installer/main/install.ps1 | iex
```

既定では3プラグインすべてを登録します。利用可能なCodex CLI / Claude Code CLIだけが設定されます。

> **注意:** `irm … | iex` 形式はすべてデフォルト設定でインストールされます。`-Target`、`-Plugins` などのパラメーターを指定するには、以下のスクリプトブロック形式を使用してください。

## macOS / Linux ワンライナー

```bash
curl -fsSL https://raw.githubusercontent.com/aharada54914/sdd-plugins-windows-installer/main/install.sh | bash
```

既定では3プラグインすべてを登録します。利用可能なCodex CLI / Claude Code CLIだけが設定されます。

オプション指定の例:

```bash
# Codex CLIのみ
curl -fsSL https://raw.githubusercontent.com/aharada54914/sdd-plugins-windows-installer/main/install.sh | bash -s -- --target Codex

# 特定プラグインのみ
curl -fsSL https://raw.githubusercontent.com/aharada54914/sdd-plugins-windows-installer/main/install.sh | bash -s -- --plugins sdd-bootstrap,sdd-implementation

# ファイル配置のみ (CLIへの登録はしない)
curl -fsSL https://raw.githubusercontent.com/aharada54914/sdd-plugins-windows-installer/main/install.sh | bash -s -- --target FilesOnly
```

実行前にスクリプトの内容を確認する場合:

```bash
curl -fsSL https://raw.githubusercontent.com/aharada54914/sdd-plugins-windows-installer/main/install.sh | less
# 内容を確認してから手動実行
bash install.sh
```

## 個別インストール

ホストを選ぶ場合:

```powershell
# Codex CLIのみ
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/aharada54914/sdd-plugins-windows-installer/main/install.ps1))) -Target Codex

# Copilot CLIのみ
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/aharada54914/sdd-plugins-windows-installer/main/install.ps1))) -Target Copilot
```

プラグインを選ぶ場合:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/aharada54914/sdd-plugins-windows-installer/main/install.ps1))) -Plugins sdd-bootstrap,sdd-implementation
```

ファイル配置のみ:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/aharada54914/sdd-plugins-windows-installer/main/install.ps1))) -Target FilesOnly
```

## 前提条件

**Windows:**
- Windows 10/11
- PowerShell 5.1以上、またはPowerShell 7

**macOS / Linux:**
- macOS 13 以上、または主要 Linux ディストリビューション
- bash、curl、tar (通常プリインストール済み)

**共通:**
- Codex CLI、Claude Code CLI、またはCopilot CLI は任意です。PATHにあるものだけが自動登録されます。
- Claude Codeのフック強制層は公式推奨のNode.js exec formを使用するため、**Node.js**が必要です (Git Bash は不要)。

## インストール先

インストーラーが配置するファイルのデフォルトパスは以下のとおりです。

| 環境 | インストール先 |
|---|---|
| Windows | `%LOCALAPPDATA%\sdd-plugins` |
| macOS / Linux | `${XDG_DATA_HOME:-~/.local/share}/sdd-plugins` |

Codex エージェント TOML は上記のインストール先とは別に、個人ディレクトリへもコピーされます。

| ファイル | コピー先 |
|---|---|
| `.codex/agents/sdd-investigator.toml` | `~/.codex/agents/` |
| `.codex/agents/sdd-evaluator.toml` | `~/.codex/agents/` |

`--install-root` (`install.sh`) または `-InstallRoot` (`install.ps1`) でデフォルトのインストール先を変更できます。Codex エージェントのコピーをスキップするには `--skip-agent-install` / `-SkipAgentInstall` を使用してください。

環境変数 `SDD_CODEX_HOME` を設定すると、Codex エージェントの個人ディレクトリ (`~/.codex/agents/`) をオーバーライドできます。

## トラブルシューティング

### Codex起動時の「Ignoring malformed agent role definition」警告

Codex起動時に次のような警告が表示される場合があります：

```
⚠ Ignoring malformed agent role definition: ~/.codex/agents/auditor.toml must define `developer_instructions`
```

本リポジトリが配布するのは `sdd-investigator.toml` と `sdd-evaluator.toml` のみで、どちらも有効です。警告に表示されたファイル（例：`auditor.toml`、`constraint-guardian.toml` など）は、他のツールやAIセッションが作成したもので、`~/.codex/agents/` ディレクトリに不正に配置されています。

**対応方法：**
1. 警告に表示されたファイルを削除する：`rm ~/.codex/agents/auditor.toml` など
2. または、そのファイルに `developer_instructions` キーを追加する
3. インストーラーはインストール時にこの問題を検出して警告し、SDDフックガードはエージェントによる不正なロールファイル作成をブロックします

## セキュリティ

リモートスクリプトの内容を確認してから実行できます。

```powershell
irm https://raw.githubusercontent.com/aharada54914/sdd-plugins-windows-installer/main/install.ps1
```

## 検証

```powershell
# PowerShell (Windows / macOS / Linux)
.\tests\validate-repository.ps1
.\tests\scripts.tests.ps1
.\tests\hooks.tests.ps1
.\tests\install.tests.ps1
```

```bash
# bash (macOS / Linux)
bash tests/install.tests.sh
```
