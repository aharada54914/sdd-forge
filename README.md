# SDD Plugins Windows Installer

Windows PowerShellから、仕様化・実装・品質保証を分離した3つのSDDプラグインをCodex CLIとClaude Codeへ導入します。

```text
sdd-bootstrap       仕様・設計・承認済みタスクを作る
       ↓
sdd-implementation  承認済みタスクを実装可能な差分へ変換する
       ↓
sdd-quality-loop    実装後の品質と仕様整合性を独立して保証する
```

詳しい運用方法と実際の開発例は [USERGUIDE.md](USERGUIDE.md) を参照してください。

## Windowsワンライナー

```powershell
irm https://raw.githubusercontent.com/aharada54914/sdd-plugins-windows-installer/main/install.ps1 | iex
```

既定では3プラグインすべてを登録します。利用可能なCodex CLI / Claude Code CLIだけが設定されます。

## 個別インストール

ホストを選ぶ場合:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/aharada54914/sdd-plugins-windows-installer/main/install.ps1))) -Target Codex
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

- Windows 10/11
- PowerShell 5.1以上、またはPowerShell 7
- Codex CLIまたはClaude Code CLI

## セキュリティ

リモートスクリプトの内容を確認してから実行できます。

```powershell
irm https://raw.githubusercontent.com/aharada54914/sdd-plugins-windows-installer/main/install.ps1
```

## 検証

```powershell
.\tests\validate-repository.ps1
.\tests\install.tests.ps1
```
