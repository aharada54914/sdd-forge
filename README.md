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

## 特徴

- **責務の明確な分離**: 仕様化・実装・品質保証を別々のスキルが担当し、実装者が自分の成果物を甘く採点する構造を排除します。
- **人間承認ゲート**: エージェントは自己承認できず、フック + 決定論的スクリプトの二重防衛により不正な承認を防止します。
- **独立した批判レビュー**: 実装者とは別の `sdd-evaluator` エージェント (またはセッション) が新しい視点で検証します。
- **3環境に対応**: Claude Code、Codex CLI、Copilot CLI の環境でスキル・エージェント・フック・スクリプトがリポジトリ内ファイルを通じて相互ハンドオフし、環境を超えて作業を継続できます。

## ドキュメントマップ

| ドキュメント | 対象読者・目的 |
|---|---|
| [README](README.md) (本ファイル) | インストール手順と概要 |
| [docs/workflow-guide.md](docs/workflow-guide.md) | 開発業務フロー：正常系・異常系・仕様変更・レビュー運用 |
| [docs/skill-reference.md](docs/skill-reference.md) | 7スキル・エージェント・フック・スクリプトの詳細 |
| [docs/troubleshooting.md](docs/troubleshooting.md) | 問題解決と対応策 |
| [CHANGELOG.md](CHANGELOG.md) | 変更履歴と版移行ガイド |

**初めての方は [docs/workflow-guide.md](docs/workflow-guide.md) の正常系フローからお読みください。**

## クイックスタート

### Windowsワンライナー

```powershell
irm https://raw.githubusercontent.com/aharada54914/sdd-plugins-windows-installer/main/install.ps1 | iex
```

既定では3プラグインすべてを登録します。利用可能なCodex CLI / Claude Code CLIだけが設定されます。

### macOS / Linux ワンライナー

```bash
curl -fsSL https://raw.githubusercontent.com/aharada54914/sdd-plugins-windows-installer/main/install.sh | bash
```

既定では3プラグインすべてを登録します。利用可能なCodex CLI / Claude Code CLIだけが設定されます。

### パラメーター指定の例

`irm … | iex` 形式はすべてデフォルト設定でインストールされます。`-Target`、`-Plugins` などのパラメーターを指定するには、**スクリプトブロック形式**を使用してください。

**PowerShell (Windows / macOS / Linux):**

```powershell
# Codex CLIのみ
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/aharada54914/sdd-plugins-windows-installer/main/install.ps1))) -Target Codex

# 特定プラグインのみ
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/aharada54914/sdd-plugins-windows-installer/main/install.ps1))) -Plugins sdd-bootstrap,sdd-implementation

# ファイル配置のみ (CLIへの登録はしない)
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/aharada54914/sdd-plugins-windows-installer/main/install.ps1))) -Target FilesOnly
```

**bash (macOS / Linux):**

```bash
# Codex CLIのみ
curl -fsSL https://raw.githubusercontent.com/aharada54914/sdd-plugins-windows-installer/main/install.sh | bash -s -- --target Codex

# 特定プラグインのみ
curl -fsSL https://raw.githubusercontent.com/aharada54914/sdd-plugins-windows-installer/main/install.sh | bash -s -- --plugins sdd-bootstrap,sdd-implementation

# ファイル配置のみ
curl -fsSL https://raw.githubusercontent.com/aharada54914/sdd-plugins-windows-installer/main/install.sh | bash -s -- --target FilesOnly
```

### スクリプト内容の確認

実行前にスクリプトの内容を確認できます：

```bash
curl -fsSL https://raw.githubusercontent.com/aharada54914/sdd-plugins-windows-installer/main/install.sh | less
# 内容を確認してから手動実行
bash install.sh
```

セキュリティ重視の場合、以下で PowerShell スクリプトの内容を確認できます：

```powershell
irm https://raw.githubusercontent.com/aharada54914/sdd-plugins-windows-installer/main/install.ps1
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

## 変更履歴

詳しい変更履歴と版移行ガイドは [CHANGELOG.md](CHANGELOG.md) をご参照ください。
