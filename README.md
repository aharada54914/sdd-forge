# SDD Plugins Windows Installer

Windows PowerShell から、次の2つの Spec-Driven Development プラグインを Codex CLI と Claude Code に導入します。

- `sdd-bootstrap`: 実装前の要件・設計・ADR・API契約・タスク・トレーサビリティを対話形式で作成
- `sdd-quality-loop`: 実装後のテスト・品質ゲート・レビュー指摘修正・トレーサビリティ更新を実行

## Windows ワンライナー

PowerShell で実行してください。

```powershell
irm https://raw.githubusercontent.com/aharada54914/sdd-plugins-windows-installer/main/install.ps1 | iex
```

スクリプトはリポジトリを `%LOCALAPPDATA%\sdd-plugins` に配置し、PATH 上に存在する Codex CLI / Claude Code CLI へマーケットプレイスと2つのプラグインを登録します。

## 個別インストール

Codex CLI のみ:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/aharada54914/sdd-plugins-windows-installer/main/install.ps1))) -Target Codex
```

Claude Code のみ:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/aharada54914/sdd-plugins-windows-installer/main/install.ps1))) -Target Claude
```

ファイル配置のみ:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/aharada54914/sdd-plugins-windows-installer/main/install.ps1))) -Target FilesOnly
```

## 前提条件

- Windows 10/11
- PowerShell 5.1 以上、または PowerShell 7
- 利用するホストの CLI
  - Codex CLI: `codex`
  - Claude Code: `claude`

どちらか一方の CLI しかない場合、既定のワンライナーは存在する CLI のみ設定します。

## セキュリティ

リモートスクリプトの実行前に内容を確認する場合:

```powershell
irm https://raw.githubusercontent.com/aharada54914/sdd-plugins-windows-installer/main/install.ps1
```

確認後、リポジトリを clone してローカルスクリプトを実行できます。

```powershell
git clone https://github.com/aharada54914/sdd-plugins-windows-installer.git
.\sdd-plugins-windows-installer\install.ps1
```

## 検証

Windows 上でリポジトリ構造とインストーラー統合テストを実行:

```powershell
.\tests\validate-repository.ps1
.\tests\install.tests.ps1
```

GitHub Actions の `windows-latest` でも同じ検証を実行します。
