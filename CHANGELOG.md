# Changelog

## v0.9.0

監査の残課題（C-04 / H-02 / H-04 / C-06 / H-06 / H-05）に対応したセキュリティ強化リリース。

### 新機能・強化

**署名付き sudo capability token (C-04)**: `SDD_SUDO` を偽造耐性のある署名トークン化。`issuer` / `nonce` (≥32 hex) / `repo`（プロジェクトルートの正規絶対パス）束縛 + HMAC-SHA256 署名 (`sig`) を追加。署名鍵はリポジトリ作業ツリーの**外**（`SDD_SUDO_KEY` / `SDD_SUDO_KEY_FILE` / `<HOME>/.sdd/sudo-key`）に置く。`sudo_active()` は py/js/ps1 共通で、非シンボリックリンク・必須フィールド・nonce 形式・`issued<=now<expires`・TTL≤24h・repo 一致・鍵で再計算した HMAC 一致をすべて満たす場合のみ有効化し、いずれか欠落で**フェイルクローズ**（承認ゲート維持＝バイパスは決して起きない）。偽造・コミット済み・他リポジトリからのコピー・リプレイを拒否。残存リスク（鍵を読めるエージェントは署名可）は `sudo-mode-policy.md` に明記。`/sdd-sudo` スキルが鍵生成（0600）と署名を行う。

**evidence の runner 生成・git SHA 束縛 (H-02)**: `generate-evidence-bundle.{sh,ps1}` を新設。証拠の SHA-256・`git_commit`(HEAD)・`git_generated_dirty` を自動算出してバンドルを生成（エージェントによる手書きを排除）。`check-evidence-bundle` は `git_commit` を必須化し、リポジトリ履歴に存在し HEAD の祖先（または HEAD）であることを検証（git 不在・検証不能はフェイルクローズ）。digest 束縛（成果物 SHA-256 一致）と併せ、捏造・古い・他コミット由来の証拠を拒否。

**Actions の SHA pin・release 署名・SBOM (H-04 / C-06)**: `test.yml` / `self-improvement.yml` の全 Action を commit SHA に pin（`# vX.Y.Z` コメント付き）。`.github/dependabot.yml` で pin を定期更新。`release.yml` を新設し、Release publish 時に再現可能ソース tarball・CycloneDX SBOM・`SHA256SUMS`・sigstore ベースの build-provenance attestation（keyless）を生成・添付。SBOM は `.github/scripts/generate-sbom.py`（stdlib のみ）が workflow の pin 済み Action から自動生成。

**installer の排他 lock (H-06)**: 同一インストール先への並行 install による stage→backup→swap 競合を防止。`install.sh` は atomic な `mkdir` lock ディレクトリ（macOS でも動くよう flock 非依存）、`install.ps1` はインストール先のハッシュで識別する名前付き Mutex。タイムアウト（`SDD_INSTALL_LOCK_TIMEOUT`、既定 120s）と stale 回収（`SDD_INSTALL_LOCK_STALE` / 死んだ pid）を備え、全 exit 経路で解放。タイムアウト時は install 先に触れずフェイルクローズ。

**outcome ベースの eval suite (H-05)**: `tests/eval.tests.sh` を新設。実際のゲート群（check-contract / check-placeholders / check-evidence-bundle / check-task-state / sdd-hook-guard）を good/completion-faking の 8 シナリオに対して実行し、Done 可否という**結末**を検証。CI (`test.yml`) に組み込み。

### 修正

- 承認ガードの穴を解消: Write content モードが `## T-NNN` セクション単位でしか比較せず、ヘッダ無しの `Approval: Approved` や新規 tasks.md がすり抜けていた問題を、ファイル全体の承認数の純増でも deny するよう py/js/ps1 で統一（per-task swap 検知は維持）。あわせて sudo テストの `issued-epoch` 欠落と、PowerShell の親ディレクトリ走査がルートで終端できず例外になる不具合を修正。

### v0.8.0 からの移行

- **sudo モードは鍵が必要に**: `/sdd-sudo` を再実行して鍵（`<HOME>/.sdd/sudo-key`）を生成し直してください。署名の無い・古い `SDD_SUDO` は無効（フェイルクローズ）として扱われます。CI 等で鍵を共有する場合は `SDD_SUDO_KEY` を設定。
- **evidence bundle は runner 生成必須**: `git_commit` フィールドが必須になりました。`generate-evidence-bundle.{sh,ps1}` で生成してください（手書きの sha256 / git_commit は不可）。
- **GitHub Actions は SHA pin**: タグ更新で自動追従しなくなります。更新は Dependabot（または手動で SHA + コメント更新）で行ってください。
- 破壊的なファイル配置変更はなし。プラグイン再インストール（ワンライナー再実行）で移行完了。

## v0.8.0

### 変更内容

- private repo 前提の remote install に対応。`install.sh` / `install.ps1` は `gh auth token` を使って GitHub API の archive を取得。
- `SourceDirectory` の既存テストを維持しつつ、認証済み remote path の mock テストを追加。
- README / troubleshooting を private 前提に更新。
- フックガードを fail-closed に変更し、agent role の更新・削除・shell 書き込みを拒否。
- `Done` 判定に SHA-256 付き evidence bundle を必須化。

### v0.7.0 からの移行

- `Done` タスクには `specs/<feature>/verification/<task-id>.evidence.json` が必要です。
- evidence bundle は quality report、verification contract、passing evidence の SHA-256 を記録します。
- malformed hook payload、guard runtime 不在、Copilot guard 不在は拒否されます。

## v0.7.0

### 新機能

**sudoモード**: 人間による明示的な `/sdd-sudo` 呼び出しで、人間承認ゲート（tasks.md の `Approval: Approved`、アーキテクチャ review 承認、quality-gate 判定）を期限付きで自動通過。AGENT_STOP kill switch と決定論的スクリプト（contract 検証、placeholder 検出、task-state 検証）は常に有効。audit trail には `(sudo <ISO8601>)` 記号で記録。使用は `/sdd-sudo [duration]`、`/sdd-sudo status`、`/sdd-sudo off`。詳細は `plugins/sdd-quality-loop/skills/sdd-sudo/SKILL.md` と `sudo-mode-policy.md` を参照。

**リポジトリ改名**: `sdd-plugins-windows-installer` から `sdd-forge` へ改名（自動リダイレクト）。

**週次セルフ改善ワークフロー**: `.github/workflows/self-improvement.yml` を新設。毎週月曜 09:00 JST に `anthropics/claude-code-action@v1` がリポジトリを監査し、Issue 起票と小さな改善 PR の作成までを自動実行する（人間はレビューとマージのみ）。実行指示は `.github/self-improvement-prompt.md` に置き、プロンプト自体も改善対象。認証は `claude setup-token` で発行した `CLAUDE_CODE_OAUTH_TOKEN` シークレット（Pro/Max サブスクリプション枠を消費、API 従量課金なし）。workflow-retrospective (WFI) ループとの競合は調停プロトコル（不可侵領域・台帳照合・WFI provenance・単一飛行・優先順位）で防止 — docs/workflow-guide.md「週次セルフ改善ルーチンとの境界と優先順位」参照。

### v0.6.2 からの移行

| v0.6.2 | v0.7.0 |
|---|---|
| sudoモードなし | **sudoモード追加**: 人間 `/sdd-sudo` 呼び出しで approval gate 自動通過。AGENT_STOP と決定論的ゲートは常に有効 |
| リポジトリ名 `sdd-plugins-windows-installer` | **改名**: `sdd-forge` へ移行（GitHub 自動リダイレクト対応） |
| 改善は人手起点のみ | **週次セルフ改善ワークフロー追加**: GitHub Actions が毎週監査 → Issue → 改善 PR を自動作成（要 `CLAUDE_CODE_OAUTH_TOKEN` シークレット） |

**破壊的変更**: なし。プラグインの再インストール（ワンライナー再実行)のみで移行完了。

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
