# SDD Forge

旧リポジトリ名 `sdd-plugins-windows-installer` から改名。現在の正式なリポジトリ名は `sdd-forge` です。
本リポジトリは private です。リモート取得を使う場合は `GH_TOKEN` / `GITHUB_TOKEN` を設定するか、`gh auth login` で GitHub CLI を認証してください。

v0.14.0、クロスプラットフォーム対応 (Windows / macOS / Linux) — PowerShell または bash から、仕様化・実装・品質保証を分離したSDDプラグインをCodex CLI、Claude Code、Copilot CLIへ導入します。

```text
[brownfield] sdd-adopt           既存プロジェクトへ SDD 構造を途中導入する
                                 (AGENTS.md/CLAUDE.md/docs/adr/等をスキャフォールド、ADR 移行)
       ↓
[Stage 0] investigate-codebase  既存コードを読み取り専用で調査し、INV/BL証跡を生成する
                                 (refactorモードでは必須、他モードは任意)
       ↓
sdd-bootstrap       仕様・設計を作る [Phase 1]
                    モード: project / feature / bugfix / refactor
       ↓
sdd-impl-review     実装方針レビューループ (2体の独立レビュアー × 最大3ラウンド)
                    → Impl-Review-Status: Passed で Phase 2 を解放
       ↓
sdd-bootstrap       承認済みタスク分解を作る [Phase 2]
                    (tasks.md + traceability.md)
       ↓
sdd-task-review     タスク分解レビューループ (2体の独立レビュアー × 最大3ラウンド)
                    → Task-Review-Status: Passed で承認ゲートへ
       ↓
sdd-implementation  承認済みタスクを実装可能な差分へ変換する
       ↓
sdd-quality-loop    実装後の品質と仕様整合性を独立して保証する
                    + workflow-retrospective でワークフロー自体を改善する
```

```text
[lite] sdd-lite      社内・部署内アプリ向けの中量トラック
                     lite-spec(要件/設計/タスク) → 単一承認 → implement-task → lite-gate → Done
                     traceability/ADR/evidence-bundle/cross-model/critical を省略。
                     impl-review-loop / task-review-loop もスキップ。
                     昇格は加算的（Risk追加→階層、本体ゲート→bundle、cross_model→検証）。
```

## 特徴

- **実装方針レビューループ (`impl-review-loop`)**: design.md に対して2体の独立したブラインドレビュアー（A: 構造健全性、B: 実装可能性/リスク）が最大3ラウンドのレビューを実施し、`Impl-Review-Status: Passed` になるまで tasks.md 生成をブロックします。PASS-with-warnings（Minor のみ）も通過扱い。BLOCKED + `--reset` で新attemptを開始。
- **タスク分解レビューループ (`task-review-loop`)**: tasks.md に対して2体の独立したブラインドレビュアー（A: 構造カバレッジ14チェック、B: 品質/リスク8チェック）が最大3ラウンドのレビューを実施します。依存関係サイクル検出・Blockers 正準形式検証を含む。
- **Phase 1/2 分割**: `sdd-bootstrap-interviewer` が Phase 1（仕様・設計・受入テスト）と Phase 2（タスク・トレーサビリティ）に分割され、`impl-review-loop` 通過を Phase 2 の前提条件とします。
- **軽量トラック sdd-lite**: 社内・部署内アプリ向けの中量SDDトラック。要件/設計/タスク生成・単一承認・implement-task・lite-gateの4ステップで構成し、evidence-bundle/ADR必須/cross-model/critical を省略。`impl-review-loop` / `task-review-loop` もスキップ。既存プラグインとの加算的昇格に対応。
- **バッチ実装 (`implement-tasks`)**: 承認済みタスクを依存関係順に連続実行し、全タスクが `Implementation Complete` になった時点で `quality-gate` を自動起動します。`### Blockers` セクションのタスク参照を解析して依存関係を自動解決します。
- **責務の明確な分離**: 仕様化・実装・品質保証を別々のスキルが担当し、実装者が自分の成果物を甘く採点する構造を排除します。
- **人間承認ゲート**: エージェントはタスク承認も WFI 承認も自己承認できず、フック + 決定論的スクリプトの二重防衛により不正な承認を防止します。critical タスクは二者承認（`Approval:` + 別名義の `Second Approval:`）が必須で、sudo でもバイパスできません。
- **独立した批判レビュー**: 実装者とは別の `sdd-evaluator` エージェント (またはセッション) が新しい視点で検証します。
- **sudoモード**: *承認待ち*（タスク承認・`accepted` 差分・定型サインオフ）を期限付きで自動通過させ、ソロワークの効率を向上。判断フォーク（`requires_human_decision`・アーキ/認証/セキュリティ決定・WFI 承認）と AGENT_STOP・決定論的ゲートは常時人間/有効。入り方は [`/sdd-sudo` スキル](plugins/sdd-quality-loop/skills/sdd-sudo/SKILL.md) を参照。
- **リスク適応ゲート**: タスクごとに `Risk:` 階層 (`low / medium / high / critical`) を設定し、階層に比例した決定論的ゲートセットを強制します。新ゲート `check-risk`（階層と `Risk Rationale` を検証）・`check-traceability`（REQ→AC→TEST→証跡チェーンを検証）を追加。`check-contract` は階層最小セットの superset 強制（Pass 4）と TDD Red→Green 証跡（Pass 5）を実施。高/critical はプロベナンス付き evidence bundle を必須とし、critical は HMAC-SHA256 署名 + クリーンツリー強制。非コード (`stack: shell/docs/spec`) リポジトリでは compile 系チェックを理由付きで waive 可能。正準対応表: [`risk-gate-matrix.md`](plugins/sdd-quality-loop/references/risk-gate-matrix.md)。
- **3環境に対応**: Claude Code、Codex CLI、Copilot CLI の環境でスキル・エージェント・フック・スクリプトがリポジトリ内ファイルを通じて相互ハンドオフし、環境を超えて作業を継続できます。

## ドキュメントマップ

| ドキュメント | 対象読者・目的 |
|---|---|
| [README](README.md) (本ファイル) | インストール手順と概要 |
| [docs/workflow-guide.md](docs/workflow-guide.md) | 開発業務フロー：正常系・異常系・仕様変更・レビュー運用 |
| [docs/skill-reference.md](docs/skill-reference.md) | 14スキル・エージェント・フック・スクリプトの詳細 |
| [docs/troubleshooting.md](docs/troubleshooting.md) | 問題解決と対応策 |
| [docs/THREAT-MODEL.md](docs/THREAT-MODEL.md) | 脅威モデル：信頼境界・攻撃面・リスク低減策 |
| [docs/agent-capability-matrix.md](docs/agent-capability-matrix.md) | エージェント能力マトリクス：各エージェントが実行できる操作の一覧 |
| [CHANGELOG.md](CHANGELOG.md) | 変更履歴と版移行ガイド |
| [specs/sdd-lite/design.md](specs/sdd-lite/design.md) | sdd-lite 設計 |
| [plugins/sdd-lite/references/lite-flow-policy.md](plugins/sdd-lite/references/lite-flow-policy.md) | sdd-lite 規約・昇格 |

**初めての方は [docs/workflow-guide.md](docs/workflow-guide.md) の正常系フローからお読みください。**

## 週次セルフ改善 (自動運用)

[.github/workflows/self-improvement.yml](.github/workflows/self-improvement.yml) が毎週月曜 09:00 JST に [.github/self-improvement-prompt.md](.github/self-improvement-prompt.md) の指示でリポジトリを監査し、Issue 起票と小さな改善 PR の作成まで自動で行います。人間の作業はレビューとマージのみです。

初回セットアップ (1回だけ):

1. 手元で `claude setup-token` を実行し、トークンをリポジトリの Secrets に `CLAUDE_CODE_OAUTH_TOKEN` として登録 (Claude Pro/Max のサブスクリプション枠を消費。API 従量課金なし)
2. Settings → Actions → General → Workflow permissions で "Allow GitHub Actions to create and approve pull requests" を有効化

## クイックスタート

### 事前準備

private repo へのアクセス権を持つトークンを設定するか、GitHub CLI を認証します。

```bash
# 非対話環境
export GH_TOKEN="<token>"

# 対話環境
gh auth login
```

### Windows

```powershell
$installer = Join-Path $env:TEMP "sdd-forge-install.ps1"
gh api repos/aharada54914/sdd-forge/contents/install.ps1 -H "Accept: application/vnd.github.raw+json" |
  Set-Content -Encoding Utf8 $installer
& $installer
```

既定では3プラグインすべてを登録します。利用可能なCodex CLI / Claude Code CLIだけが設定されます。

### macOS / Linux

```bash
installer="$(mktemp)"
gh api repos/aharada54914/sdd-forge/contents/install.sh \
  -H "Accept: application/vnd.github.raw+json" > "$installer"
bash "$installer"
rm -f "$installer"
```

既定では3プラグインすべてを登録します。利用可能なCodex CLI / Claude Code CLIだけが設定されます。

### パラメーター指定の例

**PowerShell (Windows / macOS / Linux):**

```powershell
# 上記手順で $installer を取得後:
# Codex CLIのみ
& $installer -Target Codex

# 特定プラグインのみ
& $installer -Plugins sdd-bootstrap,sdd-implementation

# ファイル配置のみ (CLIへの登録はしない)
& $installer -Target FilesOnly
```

**bash (macOS / Linux):**

```bash
# 上記手順で $installer を取得後:
# Codex CLIのみ
bash "$installer" --target Codex

# 特定プラグインのみ
bash "$installer" --plugins sdd-bootstrap,sdd-implementation

# ファイル配置のみ
bash "$installer" --target FilesOnly
```

### スクリプト内容の確認

実行前にスクリプトの内容を確認できます：

```bash
less "$installer"
# 内容を確認してから手動実行
bash "$installer"
```

セキュリティ重視の場合、以下で PowerShell スクリプトの内容を確認できます：

```powershell
Get-Content $installer
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
- リモート install を使う場合は **GitHub CLI (`gh`)** の認証済みセッションが必要です。installer は `gh auth token` を使って private repo の archive を GitHub API から取得します。

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

## リリースの完全性 (署名 + SBOM)

GitHub Release を publish すると [.github/workflows/release.yml](.github/workflows/release.yml) が以下を生成・添付します (すべての Action は commit SHA で pin 済み — H-04)。

- `sdd-forge-<tag>.tar.gz` — 再現可能なソース tarball (`git archive`)
- `sdd-forge-sbom.cdx.json` — CycloneDX SBOM (CI サプライチェーン = pin 済み Actions を列挙)
- `SHA256SUMS` — 上記成果物の SHA-256 チェックサム
- sigstore ベースの **build-provenance attestation** (keyless 署名、OIDC)

検証手順:

```bash
# チェックサム
sha256sum -c SHA256SUMS

# 署名/来歴 (GitHub CLI)
gh attestation verify sdd-forge-<tag>.tar.gz --repo aharada54914/sdd-forge
gh attestation verify sdd-forge-sbom.cdx.json --repo aharada54914/sdd-forge
```

SBOM はローカルでも生成できます: `python3 .github/scripts/generate-sbom.py --version <tag>`。

## 変更履歴

詳しい変更履歴と版移行ガイドは [CHANGELOG.md](CHANGELOG.md) をご参照ください。
