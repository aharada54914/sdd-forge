# SDD スキルリファレンス

6つのプラグイン（sdd-bootstrap、sdd-ship、sdd-review-loop、sdd-implementation、sdd-quality-loop、sdd-lite）に含まれる19のスキルの詳細リファレンスです。業務フローの全体像については [workflow-guide.md](workflow-guide.md) を参照してください。

> **2コマンドワークフロー**: ユーザーが直接呼び出すのは `/sdd-bootstrap:bootstrap` と `/sdd-ship:ship` の2つのみです。他のスキルはこれらのオーケストレーターが内部で呼び出します。

## 1. スキル一覧 (早見表)

| スキル名 | 所属プラグイン | 役割 | 前段スキル | 後段スキル |
|---|---|---|---|---|
| **bootstrap** | **sdd-bootstrap** | **[公開] 仕様化フェーズのエントリーポイント（`/sdd-bootstrap:bootstrap`）。investigate/adopt/feature/bugfix/refactor/project モードをルーティング** | **—** | **ship** |
| **ship** | **sdd-ship** | **[公開] 実装・品質保証フェーズのオーケストレーター（`/sdd-ship:ship`）。implement-tasks → quality-gate (or lite-gate) → workflow-retrospective を順次実行** | **bootstrap** | **—** |
| sdd-adopt | sdd-bootstrap | 既存プロジェクトにSDD構造を導入 | — | investigate-codebase, sdd-bootstrap-interviewer |
| investigate-codebase | sdd-bootstrap | コードベース・問題領域の読み取り調査 | sdd-adopt | sdd-bootstrap-interviewer |
| sdd-bootstrap-interviewer | sdd-bootstrap | インタビュー駆動の仕様生成 [Phase 1] と タスク生成 [Phase 2] | investigate-codebase (任意) | spec-review-loop → impl-review-loop (Phase 1後), task-review-loop (Phase 2後) |
| **spec-review-loop** | **sdd-review-loop** | **requirements.md と acceptance-tests.md を `spec-reviewer-a/b` が独立レビューし、implementation-policy review の前提 PASS を作る** | **sdd-bootstrap-interviewer [Phase 1]** | **impl-review-loop (Spec-Review-Status: Passed後)** |
| **impl-review-loop** | **sdd-review-loop** | **design.md の実装方針を2体のブラインドレビュアー × 最大3ラウンドでレビュー** | **sdd-bootstrap-interviewer [Phase 1]** | **sdd-bootstrap-interviewer [Phase 2] (Impl-Review-Status: Passed後)** |
| **task-review-loop** | **sdd-review-loop** | **tasks.md のタスク分解を2体のブラインドレビュアー × 最大3ラウンドでレビュー** | **sdd-bootstrap-interviewer [Phase 2]** | **implement-task, implement-tasks (承認ゲート後)** |
| diagnose | sdd-implementation | ハードなバグ・リグレッション・フレーキーテスト・性能退行の診断規律（再現→計装→根本原因→最小修正）。`reports/diagnosis/<id>.md` を出力し、軽量トラック（lite-spec）への入口を兼ねる | — | lite-spec（診断結果を入力に要件/設計/タスクを生成） |
| implement-task | sdd-implementation | 承認済みタスク1つを実装 | sdd-bootstrap-interviewer | quality-gate |
| **implement-tasks** | **sdd-implementation** | **承認済みタスクを依存関係順に一括実装し、全完了時に自動で quality-gate へ移行** | **sdd-bootstrap-interviewer** | **quality-gate (自動)** |
| quality-gate | sdd-quality-loop | 実装完了タスクの独立検証・Done判定 | implement-task, implement-tasks | fix-by-review-ticket (条件付き), workflow-retrospective |
| fix-by-review-ticket | sdd-quality-loop | レビューチケットの修正を実装 | quality-gate | quality-gate |
| workflow-retrospective | sdd-quality-loop | SDD ワークフロー自体の改善提案 | quality-gate | — |
| sdd-sudo | sdd-quality-loop | 人間承認ゲートを期限付きで自動通過 | — | implement-task, implement-tasks, quality-gate (オプション) |
| cross-model-verify | sdd-quality-loop | 複数ベンダーの独立 LLM パネリストを盲目並列実行し verdict JSON を収集 | quality-gate (critical タスク) | check-cross-model ゲート |
| wfi-audit-cycle | sdd-quality-loop | WFI-NNN.md Draft を2サイクルの独立監査（品質→影響/リスク）で審査し Human-Pending に移行するオーケストレーター | workflow-retrospective | — (人間承認待ち) |
| lite-spec | sdd-lite | 社内・部署内アプリ向けの軽量仕様生成（要件/設計/タスクの3ファイル、traceability/ADR/evidence-bundle 不要） | — | implement-task, implement-tasks |
| lite-gate | sdd-lite | sdd-lite フローの軽量決定論的品質ゲート（検証コマンドを自分で再実行し lite 品質レポートを生成 → Done） | implement-task, implement-tasks | — |

**重要（スキルの可視性契約）:** すべてのスキルは `disable-model-invocation: true` を指定しています。つまり、モデルが勝手にスキルを起動することはありません。さらに、内部オーケストレーション用スキルは `user-invocable: false` も指定しており、スラッシュコマンドメニューには表示されず、ユーザーが直接呼び出すこともできません。ユーザーに見えるコマンドは次の5つだけです: `/sdd-bootstrap:bootstrap`（エントリ1）、`/sdd-ship:ship`（エントリ2）、`/sdd-quality-loop:sdd-sudo`（人間専用トグル）、`/sdd-quality-loop:fix-by-review-ticket`（BLOCKED 後の人間による再開点）、`/sdd-implementation:diagnose`（バグ診断の独立エントリ）。この契約は `tests/validate-repository.ps1` が強制します。

## 2. 各スキル詳細

### sdd-bootstrap（公開エントリーポイント）

**目的**

仕様化フェーズのトップレベルルーターです。`feature` / `bugfix` / `refactor` / `project` / `adopt` / `investigate` の各モードをサブスキルにルーティングし、Phase 1 → spec-review-loop → impl-review-loop → Phase 2 → task-review-loop → 承認ゲートの三段階独立レビューを管理します。

**呼び出し例**

```txt
# Claude Code
/sdd-bootstrap:bootstrap feature https://github.com/example/repo/issues/42
/sdd-bootstrap:bootstrap bugfix  https://github.com/example/repo/issues/88
/sdd-bootstrap:bootstrap refactor https://github.com/example/repo/issues/55
/sdd-bootstrap:bootstrap project "新規プロジェクト要件"
/sdd-bootstrap:bootstrap adopt
/sdd-bootstrap:bootstrap investigate refactor src/payments
/sdd-bootstrap:bootstrap feature --lite <source>
/sdd-bootstrap:bootstrap feature --feature my-slug <source>
/sdd-bootstrap:bootstrap feature --reset --feature my-slug

# Codex
Use the bootstrap skill.
Mode: feature
Source: https://github.com/example/repo/issues/42
```

**詳細は** `plugins/sdd-bootstrap/skills/bootstrap/SKILL.md` **を参照。**

---

### sdd-ship（公開エントリーポイント）

**目的**

実装・品質保証フェーズのオーケストレーターです。承認済みタスクを implement-tasks → quality-gate (または lite-gate) → workflow-retrospective の順に処理し、全タスクを Done に導きます。

**呼び出し例**

```txt
# Claude Code
/sdd-ship:ship                                          # ゼロ引数（Active Spec Dirs から自動選択）
/sdd-ship:ship specs/<feature>/tasks.md                 # バッチ実装（全承認済みタスク）
/sdd-ship:ship specs/<feature>/tasks.md#T-001           # 単一タスク
/sdd-ship:ship --lite specs/<feature>/tasks.md          # lite トラック強制
/sdd-ship:ship --full specs/<feature>/tasks.md          # フル トラック強制
/sdd-ship:ship --verify specs/<feature>/tasks.md        # cross-model-verify を実行
/sdd-ship:ship --retro specs/<feature>/tasks.md         # 完了後に workflow-retrospective を実行

# Codex
Use the ship skill for specs/<feature>/tasks.md
```

**トラック検出（優先順）**

1. `--full` フラグ → FULL（acceptance-tests.md と traceability.md の存在確認）
2. `--lite` フラグ → LITE
3. AGENTS.md に `spec_profile: lite` → LITE
4. デフォルト → FULL

**ゼロ引数起動**: AGENTS.md の `## Active Spec Directories` を読み、承認済みタスクが1件のみなら自動選択。複数ある場合はリスト表示して停止。

**詳細は** `plugins/sdd-ship/skills/ship/SKILL.md` **を参照。**

---

> 内部スキル（sdd-adopt、investigate-codebase、implement-task 等）の詳細仕様は [`docs/contributor/skill-reference-detail.md`](contributor/skill-reference-detail.md) を参照してください。

## 3. サブエージェント

### sdd-investigator

**役割**

`investigate-codebase` スキルの代わりに、コードベース・問題領域を読み取り専用で調査します。ソースコードから事実を抽出し、file:line 出典付きの構造化所見を生成。ファイル書き込み・編集・削除禁止。

**環境別実体**

- **Claude Code**: サブエージェント (`context: fork`)
- **Codex**: `.codex/agents/sdd-investigator.toml`
- **Copilot**: `plugins/sdd-bootstrap/copilot-agents/sdd-investigator.agent.md`

**行動原則**

- すべての所見に最低1つの `file:line` 出典参照が必須
- 出典なしの主張は許さない。出典が見つからなければ Open Questions へ記載
- 調査順: Entry points → routing/screens → business rules → data → external dependencies → tests

---

### sdd-evaluator

**役割**

SDD 品質ゲートの独立的な懐疑的評価者。`Implementation Complete` タスク1つを、承認仕様と照合して新規コンテキストで検証。読み取り専用。PASS または NEEDS_WORK を分類所見とともに返す。

**環境別実体**

- **Claude Code**: サブエージェント (実装者と共有履歴なし)
- **Codex**: `.codex/agents/sdd-evaluator.toml`
- **Copilot**: `plugins/sdd-quality-loop/copilot-agents/sdd-evaluator.agent.md`

**行動原則**

1. 生成者は自分の成果物を甘く採点する。評価者は実装作業と共有コンテキストを持たず、何も編集しない
2. レポートは主張であって証拠ではない。観察証拠のみカウント：評価者が自ら実行したコマンド出力、行番号レベルで読んだコード、検査したスクリーンショット
3. デフォルト評決は `NEEDS_WORK`。`PASS` は証拠で勝ち取る

**評価規則**

1. 実装レポートを主張として扱う。すべての主張をコード・テスト・コマンド出力で自ら検証
2. タスク必須テストを再実行（可能なら）し、実出力を読む
3. 完了詐称を狩る：placeholder ページ・ハードコード sample data・generic fallback・skipped / trivially-true テスト・commented-out チェック
4. 実装と各受け入れ基準・各参照要件・契約・ADR を照合。scope creep は発見
5. refactor / bugfix で baseline-behavior.md BL 項目が存在すれば、それと比較
6. デフォルトで懐疑的。「たぶん動く」は NEEDS_WORK（PASS ではない）

**Severity 分類**

- **Critical**: 動作間違い・欠落・契約破損・セキュリティ欠陥・検証詐称。常に Done をブロック
- **Major**: テストなし受け入れ基準・未処理エラーパス・仕様ドリフト。Done をブロック
- **Minor**: スタイル・命名・非ブロック cleanup。記録するがブロックしない

**VERDICT 出力フォーマット**

```
VERDICT: PASS | NEEDS_WORK
FINDINGS:
- [Critical|Major|Minor] <file:line or artifact> - <wrong item> - <observed evidence>
CHECKED:
- <verification you actually performed and its observed result>
```

PASS は Critical 0・Major 0・かつ最低1つの実際の実行または行番号レベル検査を CHECKED で示すことで獲得します。

---

## 4. フックと強制レイヤ

### 不変条件

**Kill-Switch (AGENT_STOP)**

プロジェクトルートに `AGENT_STOP` ファイルが存在する限り、すべてのツール呼び出しをブロック。削除で再開。

**承認ガード (Approval Guard)**

`Approval: Approved` を tasks.md に書き込むエディット操作をブロック。人間のみ、エージェント外でファイルを編集して承認可。自己承認防止。

ただし、有効な `SDD_SUDO` フラグファイルが存在する場合、この guard は無効化されます（sudo モード；期限切れまたはファイル不在で再度有効になります）。詳細は `/sdd-sudo` スキル と `sudo-mode-policy.md` を参照。

**WFI 承認ガード (WFI Approval Guard)**

`docs/workflow-improvements/WFI-*.md` に `Status: Approved` を書き込むエディット操作をブロック。WFI 承認はワークフロー統治の変更であり、**sudo でも解除されません**（タスク承認ガードと異なる点）。人間のみがファイルを直接編集して承認可。

### 環境別フック実装

| 環境 | フックファイル | 実装方式 | 注意点 |
|---|---|---|---|
| Claude Code | `hooks/hooks.json` | Node.js で Edit/Write/MultiEdit/apply_patch 登録 | — |
| Codex CLI | `hooks/hooks.json` + `command_windows` | shell / PowerShell。`plugin_hooks` フラグ必須 | apply_patch は `tool_input.command` で処理 |
| Copilot CLI | `hooks/copilot-hooks.json` | stdout で JSON `permissionDecision` 返す | サブエージェント内で発火しない既知不具合 |

**設計思想**

フックは defense in depth（層防御）。最終防衛線は決定論的スクリプト (`check-contract` / `check-task-state`)。フックが無効な環境では、これら決定論的スクリプトを手動実行して同じ不変条件を確認。AGENT_STOP が効かない場合はセッション手動終了。

### Hook Guard Script

**位置**

`plugins/sdd-quality-loop/scripts/sdd-hook-guard.{sh,ps1,py,js}`

**実行方法**

- POSIX shell: `sh plugins/sdd-quality-loop/scripts/sdd-hook-guard.sh --emit exit|copilot`
- PowerShell: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/sdd-hook-guard.ps1 -Emit exit|copilot`
- Python3: `PAYLOAD=... python3 scripts/sdd-hook-guard.py`
- Node.js: Claude Code `hooks.json` で呼び出し

**Emit modes**

- `exit`: デフォルト。エラー時は警告メッセージ付きでフェイルオープン
- `copilot`: JSON `{"permissionDecision":"allow"|"deny"}` を stdout に出力（Copilot CLI 用）

---

## 5. 決定論的スクリプト

### check-sdd-structure

**目的**

SDD プロジェクトディレクトリ構造を決定論的に検証。Preflight チェック。

**使用法**

```bash
# Git Bash / WSL / macOS / Linux
sh plugins/sdd-bootstrap/scripts/check-sdd-structure.sh [project-root]
```

```powershell
# PowerShell
.\plugins\sdd-bootstrap\scripts\check-sdd-structure.ps1 [project-root]
```

**検査内容**

**必須項目 (missing → exit code 1):**
- `AGENTS.md` (file)
- `specs/` (directory)
- `reports/implementation/` (directory)
- `reports/quality-gate/` (directory)
- `docs/adr/` (directory)
- `docs/review-tickets/` (directory)

**任意項目 (missing → warning のみ、exit 0):**
- `CLAUDE.md` (file)
- `contracts/` (directory)
- `docs/architecture/` (directory)

**ドリフト検査 (advisory、exit code に影響しない):**
- `specs/*/adr` に合致するディレクトリを検出。出力: `"drift: <path> (ADRs belong in docs/adr/)"`

**ホスト検出:**
- `.gitlab-ci.yml` または `.gitlab/` 存在 → `"host: gitlab"`
- `.github/` 存在 → `"host: github"`
- いずれもなし → `"host: local"`

**Exit codes**

- 0: 必須項目すべて存在 (OK)
- 1: missing 項目あり (FAIL)

---

### check-contract

**目的**

Default-FAIL 検証契約 (JSON) を決定論的に検証。quality-gate の必須ゲート。

**使用法**

```bash
# Git Bash / WSL / macOS / Linux
sh plugins/sdd-quality-loop/scripts/check-contract.sh <path-to-contract.json> [repo-root]
```

```powershell
# PowerShell
.\plugins\sdd-quality-loop\scripts\check-contract.ps1 <path-to-contract.json> [-RepoRoot <repo-root>]
```

**検査内容**

1. **Duplicate check IDs**: 同一契約内での重複 check id → FAIL

2. **チェック別ルール:**
   - `required: true` かつ `passes: false` → FAIL
   - `required: false` かつ `passes: false` → `waiver_reason` が非空でなければ FAIL
   - `passes: true` のチェックは非空の `evidence` (証拠ファイルパス) が必須
   - `evidence` は相対パスのみ（絶対パス・`../` トラバーサルは拒否）
   - `evidence` が指すファイルはリポジトリルート内に実在すること

3. **必須セット保護:**
   Baseline IDs (`lint`, `unit-tests`, `build`, `placeholder-scan`, `task-state-check`) は template に存在必須。存在するが `required: false` なら `waiver_reason` が非空でなければ FAIL

4. **リスク階層 superset 強制 (Pass 4):**
   contract に `risk` フィールドが存在する場合、`risk-gate-matrix.md` の階層最小セットを全て `required: true` で含むこと（contract は最小セットの superset であること）。`risk` フィールドが無い場合はレガシーモード（Pass 4 スキップ）。

5. **TDD Red→Green 証跡 (Pass 5):**
   `required_workflow: tdd` の場合、各テスト系チェックが非空・パスセーフな `red_evidence` と `green_evidence` ファイルパスを持つこと。

6. **`stack` 記述子:**
   contract に `"stack": "shell"` / `"docs"` / `"spec"` が設定されている場合、`lint` / `typecheck` / `build` の3チェックは `required: false` + 非空 `waiver_reason` で waive 可能。absent / `""` / `"code"` はデフォルト（waive 不可）。テスト/トレーサビリティ系チェックは全 stack で必須のまま。

**Exit codes**

- 0: すべてのチェック成功
- 1: 必須チェック失敗 or ルール違反

---

### check-task-state

**目的**

tasks.md 状態機械をディスク上で決定論的に検証。タスク遷移の整合性ゲート。

**使用法**

```bash
# Git Bash / WSL / macOS / Linux
sh plugins/sdd-quality-loop/scripts/check-task-state.sh <path-to-tasks.md> [reports-dir] [impl-reports-dir] [repo-root]
```

```powershell
# PowerShell
.\plugins\sdd-quality-loop\scripts\check-task-state.ps1 <path-to-tasks.md> [-ReportsDir <reports-dir>] [-ImplReportsDir <impl-reports-dir>] [-RepoRoot <repo-root>]
```

**検査内容**

1. **Approval field**: `Draft` または `Approved` のみ許可

2. **Status field**: `Planned`, `In Progress`, `Blocked`, `Implementation Complete`, `Done` のいずれかのみ

3. **In Progress / Implementation Complete / Done は Approval: Approved 必須:**
   Status が該当するなら Approval は `Approved` であること

4. **Done 必須証跡:**
   - tasks.md ディレクトリ下に `verification/<task-id>.evidence.json` が存在
   - evidence bundle が `check-evidence-bundle` を通過
   - quality report に完全一致する `Task ID` と `VERDICT: PASS` が存在
   - verification contract が `check-contract` を通過し、全 passing evidence の SHA-256 が一致

5. **Implementation Complete 必須証跡:**
   - `reports/implementation/` に task id を言及する implementation レポート存在

6. **Blocked 必須フィールド:**
   - Non-empty `### Blockers` セクション（None / 空白 / bare list marker のみは不可）

7. **Duplicate task IDs**: `## T-001` の重複 → FAIL

**Exit codes**

- 0: すべてのタスク状態有効
- 1: ルール違反

---

### check-task-state-lite

**目的**

sdd-lite フロー用に `check-task-state` を fork した軽量状態ゲート。`Done` 遷移を evidence-bundle 非依存にし、「実装レポートがタスク ID に言及 + 品質レポートが `VERDICT: PASS` でタスク ID に言及」の2条件で許可する。共有ルール（Approval/Status 妥当値・In Progress/Impl Complete/Done の Approval 必須・Blocked の Blockers 必須・重複 ID 検出・CRLF 正規化）は `check-task-state` と同一。

**使用法**

```bash
# Git Bash / WSL / macOS / Linux
sh plugins/sdd-lite/scripts/check-task-state-lite.sh <path-to-tasks.md> [reports-dir] [impl-reports-dir] [repo-root]
```

```powershell
# PowerShell
.\plugins\sdd-lite\scripts\check-task-state-lite.ps1 <path-to-tasks.md> [<reports-dir>] [<impl-reports-dir>] [<repo-root>]
```

**lite 差分（check-task-state との違い）**

- 除去: `Done` の `verification/<id>.evidence.json` 必須・`.contract.json` 必須・check-evidence-bundle 呼出
- 除去: critical 二者承認ロジック
- 変更: `Done` 要件を「`Approval: Approved` + 実装レポートがタスク ID に言及 + lite 品質レポートが `VERDICT: PASS` でタスク ID に言及」に置換

**Exit codes**

- 0: すべてのタスク状態有効
- 1: ルール違反

---

### check-risk

**目的**

タスクの `Risk:` 階層 (`low / medium / high / critical`) と `Risk Rationale:` フィールドの存在・値を決定論的に検証。`high`/`critical` タスクが `Required Workflow: tdd` を宣言していない場合にフェイルクローズ。

**使用法**

```bash
sh plugins/sdd-quality-loop/scripts/check-risk.sh <path-to-tasks.md> [task-id]
```

```powershell
.\plugins\sdd-quality-loop\scripts\check-risk.ps1 <path-to-tasks.md> [-TaskId <task-id>]
```

**Exit codes**

- 0: Risk フィールドが有効
- 1: 無効な階層値、`Risk Rationale:` 欠落、または `high`/`critical` で `Required Workflow: tdd` 未宣言

---

### check-traceability

**目的**

`traceability.json` の REQ→AC→TEST→証跡チェーンを決定論的に検証。第3引数 `require-evidence`（呼び出し側の quality-gate が `high`/`critical` 時に付与）を渡すと、各 link に証跡 (`evidence`) が列挙され実ファイルが存在することも検査。

**使用法**

```bash
sh plugins/sdd-quality-loop/scripts/check-traceability.sh <traceability.json> [repo-root] [require-evidence]
```

```powershell
.\plugins\sdd-quality-loop\scripts\check-traceability.ps1 -TracePath <traceability.json> [-RepoRoot <repo-root>] [-RequireEvidence]
```

**検査内容**

1. 各 link に非空の `req`、≥1件の `acs`（受け入れ条件）、≥1件の `tests` があること
2. `evidence` が列挙されている場合、各パスがリポジトリ内・実在・非空であること（`..` などの path traversal は拒否）
3. `require-evidence` モードでは、全 link が ≥1件の証跡ファイルを列挙していること（未列挙はフェイルクローズ）

**Exit codes**

- 0: トレーサビリティチェーン有効
- 1: チェーン断絶（`req`/`acs`/`tests` 欠落）、または `require-evidence` モードでの証跡欠落・不正パス

---

### check-evidence-bundle

**目的**

`Done` 判定に使う quality report、verification contract、passing evidence の存在と SHA-256 を検証。`high`/`critical` タスクでは `risk`・`required_workflow`・`spec_revision`・`build_env`・`builder`・`review_verdict` のプロベナンスフィールドを必須検証。`critical` タスクでは HMAC-SHA256 署名も検証（鍵は `SDD_EVIDENCE_KEY` / `SDD_EVIDENCE_KEY_FILE` / `~/.sdd/evidence-key` から解決）。

```bash
sh plugins/sdd-quality-loop/scripts/check-evidence-bundle.sh <path-to-evidence.json> [repo-root]
```

```powershell
.\plugins\sdd-quality-loop\scripts\check-evidence-bundle.ps1 <path-to-evidence.json> [-RepoRoot <repo-root>]
```

---

### check-placeholders

**目的**

Placeholder・stub・generic-fallback 実装を検出。エージェントが完了を詐称する際に使用するパターンを狩る。

**使用法**

```bash
# Git Bash / WSL / macOS / Linux
sh plugins/sdd-quality-loop/scripts/check-placeholders.sh <file-or-dir> [<file-or-dir> ...]
```

```powershell
# PowerShell
.\plugins\sdd-quality-loop\scripts\check-placeholders.ps1 <file-or-dir> [<file-or-dir> ...]
```

**検索パターン**

```
TODO|FIXME|HACK\b|NotImplemented|not[ _-]implemented|PLACEHOLDER|lorem ipsum|coming soon|do not ship|temporary stub|dummy (data|value|response)|TODO_REPLACE_WITH_PROJECT_COMMANDS
```

**除外ディレクトリ**

- `.git`, `node_modules`, `bin`, `obj`, `dist`

**Exit codes**

- 0: placeholder / stub / fallback 検出なし
- 1: 1つ以上検出（各マッチ行を報告）

---

## 6. テンプレート一覧

### sdd-bootstrap

| テンプレートパス | 生成物説明 |
|---|---|
| `plugins/sdd-bootstrap/skills/investigate-codebase/templates/investigation.template.md` | INV-xxx 所見付き調査レポート |
| `plugins/sdd-bootstrap/skills/investigate-codebase/templates/baseline-behavior.template.md` | BL-xxx 項目付き baseline 記録 |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/AGENTS.template.md` | プロジェクト agent・role 定義 |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/CLAUDE.template.md` | Claude インタラクションガイドライン |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/requirements.template.md` | 機能要件書 |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/design.template.md` | アーキテクチャ・設計決定 |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/acceptance-tests.template.md` | 受け入れ基準・テスト |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/tasks.template.md` | タスク分割 (T-xxx) |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/traceability.template.md` | トレーサビリティ行列 |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/adr.template.md` | Architecture Decision Record |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/ai-task.template.md` | AI 特化タスク template |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/c4-context.template.md` | C4 Context diagram |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/c4-container.template.md` | C4 Container diagram |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/c4-component.template.md` | C4 Component diagram |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/openapi.template.yaml` | OpenAPI 仕様 |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/json-schema.template.json` | JSON Schema 定義 |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/ci-github.template.yml` | GitHub Actions CI workflow |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/ci-gitlab.template.yml` | GitLab CI pipeline |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/pull-request.template.md` | GitHub PR template |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/merge-request.template.md` | GitLab MR template |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/gitlab-issue.template.md` | GitLab Issue template |

### sdd-implementation

| テンプレートパス | 生成物説明 |
|---|---|
| `plugins/sdd-implementation/templates/implementation-report.template.md` | 実装進捗レポート（タスク サイクルごと） |
| `plugins/sdd-implementation/templates/diagnosis-report.template.md` | diagnose の診断レポート（再現手順・根本原因・回帰テスト） |

### sdd-quality-loop

| テンプレートパス | 生成物説明 |
|---|---|
| `plugins/sdd-quality-loop/templates/verification-contract.template.json` | Default-FAIL 契約 (lint / unit-tests / build 等チェック) |
| `plugins/sdd-quality-loop/templates/quality-report.template.md` | Quality gate 評価レポート |
| `plugins/sdd-quality-loop/templates/review-ticket.template.yml` | Review ticket YAML format |
| `plugins/sdd-quality-loop/templates/retrospective-report.template.md` | Workflow retrospective レポート |
| `plugins/sdd-quality-loop/templates/workflow-improvement.template.md` | Workflow improvement (WFI) 提案 |

---

## 7. Compatibility Matrix

各機能がどの実行環境で動作するかを示します。

| 機能 | Claude Code | Codex CLI | Copilot CLI |
|---|---|---|---|
| スキル本文 / テンプレート / references | ○ | ○ | ○ (SKILL.md互換) |
| scripts (.sh / .ps1) | ○ | ○ | ○ |
| `sdd-investigator` エージェント | ○ (`context: fork`) | ○¹ (`.codex/agents/`) | ○ (`*.agent.md`) |
| `sdd-evaluator` エージェント | ○ (サブエージェント) | ○¹ (`.codex/agents/`) | ○ (`*.agent.md`) |
| `hooks/hooks.json` (承認ガード / AGENT_STOP) | ○ | ○² (`plugin_hooks` フラグ必要) | ○³ (plugin `preToolUse`) |
| `disable-model-invocation` | ○ | — | ○ |
| `context: fork` | ○ | — | — |

¹ `.codex/agents/` の TOML エージェントは Codex app / CLI のインタラクティブセッションで動作します。インストーラーはこれらを `~/.codex/agents/` へもコピーします。

² Codex は `hooks/hooks.json` の `command` / `command_windows` を `plugin_hooks` フィーチャーフラグが有効な場合に読み込みます。`apply_patch` ペイロードは `sdd-hook-guard` が処理します。

³ Copilot は `hooks/copilot-hooks.json` を使用します。stdout で `permissionDecision` を返すフォーマットを採用し、フェイルセーフ拒否を実装しています。既知の不具合: サブエージェント内では発火しない場合があります。

**フックは補助線 (defense in depth)。決定論的スクリプト (`check-contract` / `check-task-state`) が最終防衛線です。**

**Codex / Copilot での運用:** `sdd-investigator` と `sdd-evaluator` はそれぞれ Codex の `.codex/agents/` TOML エージェント（`~/.codex/agents/` へインストーラーが自動コピー）および Copilot の `copilot-agents/*.agent.md` として利用できます。フックが無効な環境では、`scripts/check-task-state` と `scripts/check-contract` を手動実行して同じ不変条件を確認してください。

**併用時のハンドオフ:** ワークフロー状態はすべてリポジトリ内ファイル (`tasks.md` / `specs/` / `reports/` / 検証契約 JSON / `docs/review-tickets/`) に保存されます。Claude Code で生成した成果物を Codex / Copilot セッションでそのまま引き継ぐことができ、逆方向も同様です。

---

## 関連ドキュメント

- [../README.md](../README.md) — プロジェクト概要・フロー図
- [workflow-guide.md](workflow-guide.md) — SDD ワークフロー全体フロー・実行例
- [troubleshooting.md](troubleshooting.md) — よくあるエラー・解決方法
