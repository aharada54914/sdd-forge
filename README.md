# SDD Plugins Windows Installer

v0.3.0 — Windows PowerShellから、仕様化・実装・品質保証を分離した3つのSDDプラグインをCodex CLIとClaude Codeへ導入します。

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

## v0.3.0 新機能

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
