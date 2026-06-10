# SDD Plugins User Guide

## 1. 全体ワークフロー

このプラグイン群は、調査、仕様作成、実装、品質保証を別の責務として扱います。

| Stage | Plugin / Skill | 結果 |
|---|---|---|
| 調査 (任意/refactor必須) | `sdd-bootstrap` / `investigate-codebase` | `investigation.md` と `baseline-behavior.md` |
| 仕様化 | `sdd-bootstrap` / `sdd-bootstrap-interviewer` | 人間が承認できる仕様とDraftタスク |
| 実装 | `sdd-implementation` / `implement-task` | `Implementation Complete` のタスクと実装レポート |
| 品質保証 | `sdd-quality-loop` / `quality-gate` | 独立検証済みの `Done`、またはレビューYAML |
| 指摘修正 | `sdd-quality-loop` / `fix-by-review-ticket` | 指摘限定修正と再品質ゲート待ち状態 |
| レトロスペクティブ | `sdd-quality-loop` / `workflow-retrospective` | WFI提案と承認済み改善の適用 |

`tasks.md` はタスクの承認・実行順・状態の正本です。`traceability.md` は要件、設計、契約、コード、テストの整合性の正本です。

```text
[Stage 0] investigate-codebase (refactorは必須、他は任意)
       ↓
Draft → Approved → In Progress → Implementation Complete → Done
                   └──────────→ Blocked
       ↓ (フィーチャー完了後)
workflow-retrospective → WFI Draft → 人間が Approved → 改善適用 → 効果検証
```

人間だけがタスクを `Approved` にできます。`implement-task` は `Implementation Complete` まで進め、`quality-gate` だけが `Done` を設定できます。

## 2. どのSkillを使うか

### investigate-codebase (Stage 0)

既存コードの読み取り専用調査を行い、仕様作業の前提となる証跡を生成します。`refactor` モードでは必須です。

```txt
Use the investigate-codebase skill.
Mode: refactor
Target: src/reservation
```

出力先:
- `specs/<feature>/investigation.md` — `INV-xxx` IDつき知見 (全モード)
- `specs/<feature>/baseline-behavior.md` — `BL-xxx` IDつき基線動作 (`bugfix` / `refactor` モード)

生成後、`investigation.md` と `baseline-behavior.md` を `sdd-bootstrap-interviewer` の入力として渡します。Claude Code では `context: fork` により調査が独立セッションで実行されます。Codex では新規セッションで同手順を実施し、生成ファイルを作業コンテキストに貼り付けてから `sdd-bootstrap-interviewer` を呼び出します。

### sdd-bootstrap-interviewer

新規プロジェクト、機能追加、不具合修正、リファクタリングの仕様を作るときに使用します。

```txt
Use the sdd-bootstrap-interviewer skill.
Mode: feature
Source: https://github.com/example/product/issues/42
```

GitHub/GitLab Issue URLを読み取れない場合はIssue本文を入力します。外部サービスへ書込みは行いません。

利用モード:

- `project`: プロジェクト憲章と最初の仕様を作る
- `feature`: 既存プロダクトへ新機能を追加する
- `bugfix`: 現象、期待動作、回帰テスト、最小修正範囲を仕様化する
- `refactor`: 観測可能な動作を変えない構造改善を仕様化する。`investigation.md` と `baseline-behavior.md` が必須前提。受入条件は BL 同値として記述される。

生成後、要件・設計・契約・受入条件・タスクを人間が確認し、着手可能なタスクの `Approval` を `Draft` から `Approved` へ変更します。

### implement-task

承認済みタスクを1件だけ実装します。

```txt
Use the implement-task skill for specs/reservation/tasks.md#T-001
```

Skillは `tasks.md`、仕様、契約、`git status`、`git diff` を読み、既存の無関係な変更を保護します。仕様が曖昧、設計変更が必要、既存変更と干渉する場合は `Blocked` にして停止します。

実装、タスク必須テスト、関連回帰テスト、自己レビューが完了すると、次を生成します。

```text
reports/implementation/T-001.md
```

その後、タスクは `Implementation Complete` になります。これは品質保証待ちであり、完了ではありません。

### quality-gate

`Implementation Complete` のタスクを独立して検証します。

```txt
Use the quality-gate skill for specs/reservation/tasks.md#T-001
```

1. タスク開始時に `templates/verification-contract.template.json` から Default-FAIL 契約 (`specs/<feature>/verification/<task-id>.contract.json`) を作成する。すべての検査項目は `passes: false` で始まる。
2. CI相当チェック、`check-placeholders`、`check-task-state` を実行し、実際の出力をエビデンスファイルに保存して契約を更新する。
3. Done 判定の前に `check-contract` を実行し、未充足チェックがあれば Done を拒否する。
4. `sdd-evaluator` サブエージェント (Claude Code)、Codex `.codex/agents/` エージェント、または Copilot `*.agent.md` エージェントで独立批判レビューを行う。最大3サイクル。
5. `refactor` / `bugfix` タスクで `baseline-behavior.md` が存在する場合、`differential-test-policy.md` に従い各 BL エントリを `fix-required` / `accepted` / `environmental` に分類する。

UI変更時は利用可能なブラウザまたはPlaywrightで画面、DOM、consoleも確認します。

未解決のCritical/Major指摘がなく、`check-contract` が通過し、すべての必須検証とトレーサビリティ更新が完了した場合だけ `Done` になります。

### workflow-retrospective

フィーチャー完了後にワークフロー自体のパフォーマンスを計測し、改善を提案します。

```txt
Use the workflow-retrospective skill for specs/reservation
```

リワークサイクル数、Blocked 回数、レビューチケット数などを `reports/` から集計し、`reports/retrospective/<timestamp>.md` を生成します。繰り返しパターンが検出された場合は `docs/workflow-improvements/WFI-NNN.md` を `Draft` で作成します。WFI は人間が `Approved` にして初めて適用されます。

### fix-by-review-ticket

品質ゲートが作成したリポジトリ内YAML指摘を限定修正します。

```txt
Use the fix-by-review-ticket skill for docs/review-tickets/RT-0001.yml
```

チケット外の改善は行いません。`requires_human_decision: true` の場合は停止します。修正後は `Implementation Complete` に戻り、再度 `quality-gate` を実行します。

## 3. Compatibility Matrix

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

**hooksは補助線 (defense in depth)。決定論的スクリプト (`check-contract` / `check-task-state`) が最終防衛線です。**

**Codex / Copilot での運用:** `sdd-investigator` と `sdd-evaluator` はそれぞれ Codex の `.codex/agents/` TOML エージェントおよび Copilot の `copilot-agents/*.agent.md` として利用できます。インストーラーが `~/.codex/agents/` へ自動コピーするため、`codex` CLI のインタラクティブセッションからそのまま起動できます。hooks が無効な環境では、`scripts/check-task-state` と `scripts/check-contract` を手動実行して同じ不変条件を確認してください。

**併用時のハンドオフ:** ワークフロー状態はすべてリポジトリ内ファイル (`tasks.md` / `specs/` / `reports/` / 検証契約 JSON / `docs/review-tickets/`) に保存されます。Claude Code で生成した成果物を Codex / Copilot セッションでそのまま引き継ぐことができ、逆方向も同様です。

## 4. 決定論的ゲートの使い方

### 検証契約のライフサイクル

1. `quality-gate` 開始時に `templates/verification-contract.template.json` を `specs/<feature>/verification/<task-id>.contract.json` へコピーする。
2. 各検査項目は `passes: false`、`evidence: ""` で始まる (Default-FAIL)。
3. コマンドを実際に実行し、出力をファイルに保存してから `passes: true` と `evidence` パスを記入する。エビデンスファイルが存在しない場合、`check-contract` はその検査を失敗とみなす。
4. Done 判定の直前に `check-contract` を実行する。

```bash
# Git Bash / WSL
sh plugins/sdd-quality-loop/scripts/check-contract.sh specs/reservation/verification/T-001.contract.json
sh plugins/sdd-quality-loop/scripts/check-placeholders.sh src/reservation
sh plugins/sdd-quality-loop/scripts/check-task-state.sh specs/reservation/tasks.md
```

```powershell
# PowerShell
.\plugins\sdd-quality-loop\scripts\check-contract.ps1 specs\reservation\verification\T-001.contract.json
.\plugins\sdd-quality-loop\scripts\check-placeholders.ps1 src\reservation
.\plugins\sdd-quality-loop\scripts\check-task-state.ps1 specs\reservation\tasks.md
```

### AGENT_STOP キルスイッチ

統一ガード `sdd-hook-guard` が Claude Code、Codex (plugin_hooks フラグ有効時)、Copilot の3ランタイムで AGENT_STOP を強制します。プロジェクトルートに `AGENT_STOP` ファイルが存在する間、エージェントのすべてのツール操作がブロックされます。

```powershell
# エージェントを停止する
New-Item AGENT_STOP

# エージェントを再開する
Remove-Item AGENT_STOP
```

hooks が有効でない環境 (Codex で `plugin_hooks` フラグ未設定、Copilot のサブエージェント内など) では、`AGENT_STOP` ファイルはシグナルとして機能しません。その場合はセッションを手動で終了してください。

## 5. refactorモードと差分テスト

`refactor` モードを使用する場合:

1. `investigate-codebase refactor` を先に実行し、`baseline-behavior.md` の `BL-xxx` エントリを確定させる。
2. `sdd-bootstrap-interviewer refactor` を実行する。受入条件は BL 同値 (`BL-001 の動作が保持されること`) として記述される。
3. `quality-gate` は `differential-test-policy.md` に従い各 BL エントリを以下の3値に分類する:

| 分類 | 意味 | アクション |
|---|---|---|
| `fix-required` | 変更後に意図しない動作差分が生じた | レビューチケット作成・Done ブロック |
| `accepted` | タスク記述で明示された意図的な変更 | 人間の Approved が必要・`baseline-behavior.md` を更新 |
| `environmental` | 正規化後に差分なし | 対応不要 |

タイムスタンプ・UUID・ホスト固有パスは比較前に正規化します (`<TIMESTAMP>`, `<RANDOM>`, `<ENV>`)。

## 6. 新機能開発の例

GitHub Issue `#42: 設備予約のキャンセル機能` を実装する例です。

1. (任意) `investigate-codebase feature` を実行し、既存の予約処理・権限・API契約・テストの知見を `investigation.md` に記録する。
2. `sdd-bootstrap-interviewer` を `feature` モードで実行する。`investigation.md` がある場合は入力として渡す。
3. requirements、design、acceptance-tests、tasks、traceabilityを生成する。
4. 人間が仕様を確認し、最初のタスクを `Approved` にする。
5. `implement-task` が承認済みタスクだけを実装する。
6. 実装レポートを確認し、`quality-gate` を実行する。`check-contract` が通過した場合のみ `Done` になる。
7. フィーチャー完了後、`workflow-retrospective` を実行して改善機会を計測する。
8. commit、push、PR作成が必要なら明示的に依頼する。

GitLab Issueでも同じ流れです。bootstrapはGitLab CI、Issue、MR用テンプレートを選択します。

## 7. 不具合修正の例

GitLab Issue `予約枠が重複登録される` を修正する例です。

1. `sdd-bootstrap-interviewer` を `bugfix` モードで実行する。
2. 再現条件、期待動作、影響範囲、必要な回帰テストを仕様化する。
3. 人間が最小修正範囲を承認する。
4. `implement-task` が回帰テストと修正を実装する。
5. `quality-gate` が全体検証と独立批判レビューを行う。
6. 未解決指摘があればレビューYAMLを作成する。
7. 人間判断済み指摘を `fix-by-review-ticket` で修正し、再度 `quality-gate` を実行する。

## 8. 中断後の再開

再開時も同じ `implement-task` を使用します。別のresume用Skillはありません。

```txt
Use the implement-task skill for specs/reservation/tasks.md
```

Skillは `In Progress` タスクを優先し、`git status` と `git diff` から現在位置を復元します。対象外の変更は保護し、タスクと干渉するときだけ `Blocked` にします。

## 9. GitHubとGitLab

| Repository host | Bootstrap成果物 |
|---|---|
| GitHub | GitHub Actions、Issueテンプレート、PRテンプレート |
| GitLab | GitLab CI、Issueテンプレート、MRテンプレート |
| local | 共通仕様、契約、タスク、トレーサビリティ |

Issue URLの読取りはread-onlyです。Issue作成、コメント、commit、push、PR/MR作成は明示依頼時だけ行います。

## 10. Blockedになる条件

- タスクが `Approved` ではない
- 要件、設計、契約、受入条件が曖昧
- 認証・認可、breaking API、主要アーキテクチャの判断が必要
- 対象外の未コミット変更と干渉する
- 必須テストを実行できない
- 指摘に人間判断が必要

仕様不足の場合は `sdd-bootstrap-interviewer` へ戻り、仕様更新と再承認を行います。

## 11. バージョン移行ガイド

### v0.2.0 → v0.3.0

| v0.2.0 | v0.3.0 |
|---|---|
| bootstrap は3モード (project/feature/bugfix) | 4モード (+ `refactor`) |
| 調査フェーズなし | `investigate-codebase` (Stage 0) が追加 |
| `quality-gate` はエージェント自己申告を許容 | Default-FAIL 検証契約 + 決定論的スクリプトゲート |
| 独立レビューは任意 | `sdd-evaluator` サブエージェント (または新規セッション) が必須 |
| フックなし | `hooks/hooks.json` が承認ガード / AGENT_STOP を強制 |
| レトロスペクティブなし | `workflow-retrospective` + WFI ループが追加 |

### v0.3.0 → v0.4.0

| v0.3.0 | v0.4.0 |
|---|---|
| Claude Code のみ対応 | **Copilot CLI対応**: SKILL.md スキル、`*.agent.md` エージェント、`hooks/copilot-hooks.json` (preToolUse、既知の不具合: サブエージェント内) |
| Codex hookなし / エージェントなし | **Codex hooks/agents対応**: `command_windows` フィールド追加、`apply_patch` ペイロード処理、`.codex/agents/` TOML エージェント、インストーラーが `~/.codex/agents/` へコピー |
| 個別の kill-switch / guard スクリプト | **統一ガード `sdd-hook-guard`**: 3ランタイム共通、kill-switch + タスク承認チェックを統合 |
| check-contract / check-task-state 基本版 | **強化版スクリプト**: `waiver_reason` 必須化、証拠パストラバーサル防止、重複タスクID検出、実装レポート必須 (`Implementation Complete`)、`Blocked`/`Done` 検証強化、ベースライン必須セット保護 |
| CIテンプレートがコマンドなしで通過 | **フェイルクローズ化**: `TODO_REPLACE_WITH_PROJECT_COMMANDS` マーカーで未設定のまま通過しない |
| version 0.3.0 | version 0.4.0 |

通常は3プラグインすべてを導入してください。個別導入する場合:

```powershell
.\install.ps1 -Plugins sdd-bootstrap,sdd-implementation
```

Copilot CLIのみに登録する場合:

```powershell
.\install.ps1 -Target Copilot
```

Codexエージェントの個人ディレクトリへのコピーをスキップする場合:

```powershell
.\install.ps1 -Target Codex -SkipAgentInstall
```

## 12. トラブルシューティング

- 実装が開始されない: タスクの `Approval` と `Status`、Blockersを確認する。
- quality-gateが開始されない: タスクが `Implementation Complete` か確認する。
- Doneにならない: 品質レポートと `docs/review-tickets/*.yml` を確認する。
- UI検証ができない: 必須検証なら環境を整えてquality-gateを再実行する。
- CLI登録に失敗する: インストーラーは初回配置を削除、更新時は以前の配置へ復元する。
