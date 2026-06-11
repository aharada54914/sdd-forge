# SDD Plugins Windows Installer

v0.5.0、クロスプラットフォーム対応 (Windows / macOS / Linux) — PowerShell または bash から、仕様化・実装・品質保証を分離した3つのSDDプラグインをCodex CLI、Claude Code、Copilot CLIへ導入します。

```text
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
- **Claude Code フック強制層**: `hooks/hooks.json` が `PreToolUse` に `kill-switch.sh` と `guard-task-approval.sh` を挿入し、AGENT_STOP と自己承認を強制ブロックする。
- **ワークフローレトロスペクティブ**: `workflow-retrospective` スキルがリワーク指標を計測し、WFI (Workflow Improvement) 提案を人間承認ループで適用する。

## Windowsワンライナー

```powershell
irm https://raw.githubusercontent.com/aharada54914/sdd-plugins-windows-installer/main/install.ps1 | iex
```

既定では3プラグインすべてを登録します。利用可能なCodex CLI / Claude Code CLIだけが設定されます。

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
