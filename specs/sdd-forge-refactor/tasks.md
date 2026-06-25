# Tasks: sdd-forge-refactor

Task-Review-Status: Passed

## Lifecycle

`Draft -> Approved -> In Progress -> Implementation Complete -> Done`

タスクは人間が承認する。`implement-task` が `In Progress`・`Blocked`・
`Implementation Complete` を設定できる。`quality-gate` のみ `Done` を設定できる。

> ⚠️ **T-002 Phase 1 と Phase 5 は human/sudo セッションが必須。**
> ガードファイル（sdd-hook-guard.js/py）は PROTECTED_GATE_SUFFIXES で自己保護されており、
> 通常エージェントセッションでは編集不可。

---

## T-001 investigation.md + baseline-behavior.md 作成（完了済み）

Approval: Approved
Status: Done
Risk: low
Risk Rationale: 調査ドキュメントの作成のみ。コードへの影響なし。
Required Workflow: acceptance-first
Requirements: REQ-001

### Goal
リファクタリング前の観察可能な振る舞いをファイルとして確立する。

### Scope
`specs/sdd-forge-refactor/investigation.md` と `baseline-behavior.md` の作成。

### Done When
- [x] investigation.md が INV-001〜INV-008 を含む
- [x] baseline-behavior.md が BL-001〜BL-016 を含む
- [x] 実装レポート作成
- [x] quality gate pass

### Blockers
None

---

## T-002 sdd-review-loop プラグイン作成 + ガード更新 + caller 更新 + 旧プラグイン削除

Approval: Approved
Status: Done
Risk: high
Risk Rationale: hook guard の PROTECTED_GATE_SUFFIXES 更新（自己保護のため human/sudo 必須）。callerの更新漏れで sdd-bootstrap が runtime エラーになる。旧プラグイン削除は後戻り不可。
Required Workflow: tdd
Requirements: REQ-001, REQ-002, REQ-004, REQ-007, REQ-008, REQ-009

### Goal
`sdd-impl-review` と `sdd-task-review` を `sdd-review-loop` プラグインに統合移動する。

### Must Read
- specs/sdd-forge-refactor/design.md §ADR-001, §ADR-002, §ADR-003, §Hook Guard 更新計画

### Scope（Phase 順序厳守）

**Phase 1 [human/sudo — エージェント不可]**:
1. `sdd-hook-guard.js` PROTECTED_GATE_SUFFIXES に新 6 パスを追加（旧パスは保持）
2. `sdd-hook-guard.py` に同 6 パスを追加 + Python Check 2e 関数を追加
   - 必須: bare relative path 解決 (`os.listdir('reports/impl-review/' + feature)`)
   - `_resolve_project_root()` は使わない（ADR-004）

**Phase 2 [エージェント — Phase 1 完了後]**:
3. `plugins/sdd-review-loop/` を作成:
   - `skills/impl-review-loop/SKILL.md`（sdd-impl-review から移植 + パス参照更新）
   - `skills/task-review-loop/SKILL.md`（sdd-task-review から移植 + パス参照更新）
   - `agents/impl-reviewer-a.md`, `agents/impl-reviewer-b.md`（移植）
   - `agents/task-reviewer-a.md`, `agents/task-reviewer-b.md`（移植）
   - `scripts/impl-review-precheck.sh`（sdd-impl-review/scripts/ から移植）
   - `scripts/task-review-precheck.sh`（sdd-task-review/scripts/ から移植）
   - `templates/impl-review-contract.template.json`（sdd-impl-review/templates/ から移植）
   - `templates/impl-review-report.template.md`（sdd-impl-review/templates/ から移植）
   - `templates/task-review-contract.template.json`（sdd-task-review/templates/ から移植）
   - `templates/task-review-report.template.md`（sdd-task-review/templates/ から移植）
   - `references/phase-review-checklist.md`（impl + task チェックリスト統合）
   - Claude/Codex/Copilot の plugin manifest を作成し、両 marketplace に internal dependency として登録する（ADR-006。ADR-005 を廃止）
   - **SKILL.md パス参照更新**: `plugins/sdd-impl-review/` → `plugins/sdd-review-loop/`、
     `plugins/sdd-task-review/` → `plugins/sdd-review-loop/`（各 SKILL.md 内の全参照）

**Phase 3 [エージェント]**:
4. `plugins/sdd-bootstrap/skills/sdd-bootstrap/SKILL.md` を更新:
   - L88: `/sdd-impl-review:impl-review-loop` → `/sdd-review-loop:impl-review-loop`
   - L99: `/sdd-task-review:task-review-loop` → `/sdd-review-loop:task-review-loop`
5. `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md` を更新:
   - L105: `/impl-review-loop` → `/sdd-review-loop:impl-review-loop`
   - L111: `/impl-review-loop --reset` → `/sdd-review-loop:impl-review-loop --reset`
   - L118: `/impl-review-loop` → `/sdd-review-loop:impl-review-loop`
   - L119: `/impl-review-loop` → `/sdd-review-loop:impl-review-loop`（同行の2箇所確認）
   - L145: `/task-review-loop` → `/sdd-review-loop:task-review-loop`
   - L150: `/task-review-loop --reset` → `/sdd-review-loop:task-review-loop --reset`

**Phase 3.5 [エージェント — Phase 3 完了後、Phase 4 前の検証ゲート]**:
削除前に以下を確認してから Phase 4 に進む:
- `plugins/sdd-review-loop/` が全ファイル（skills/, agents/, scripts/, templates/, references/）を含む
- `sdd-bootstrap/SKILL.md` L88/L99 が新パスを参照している
- `sdd-bootstrap-interviewer/SKILL.md` L105/111/118/119/145/150 が更新済み
- AC-002（新パスへの書き込みが exit 2 で拒否）が手動確認可能な状態

**Phase 4 [エージェント — Phase 3.5 検証後]**:
6. `plugins/sdd-impl-review/` を完全削除
7. `plugins/sdd-task-review/` を完全削除

**Phase 5 [human/sudo — Phase 4 完了後]**:
8. `sdd-hook-guard.js/py` PROTECTED_GATE_SUFFIXES から旧 6 パスを削除
（注: `$forbiddenPaths` の更新は T-005 が担当 — ここでは行わない）

### Done When
- [x] Phase 1: guard files 更新済み（human/sudo 実施）
- [x] Phase 2: `plugins/sdd-review-loop/` が全ファイルを含んで存在する
- [x] Phase 3: sdd-bootstrap/SKILL.md L88/L99 と sdd-bootstrap-interviewer/SKILL.md L105/111/118/119/145/150 が更新済み
- [x] Phase 3.5: 新プラグイン・caller 更新の事前検証完了
- [x] Phase 4: `plugins/sdd-impl-review/` と `plugins/sdd-task-review/` が存在しない
- [x] Phase 5: guard の旧パスが削除済み（human/sudo 実施）
- [x] AC-001, AC-002, AC-003 が pass する
- [x] AC-009（承認ガード健在）が pass する
- [x] BL-009（guard-parity）、BL-010（scenario）、BL-011（install）が pass する
- [x] BL-012/BL-013（install.sh auto-include + marketplace sdd-ship）が変化しないことを確認
- [x] 実装レポート作成（reports/implementation/sdd-forge-refactor-T-002.md）
- [x] quality gate pass

### Post-completion remediation (ADR-006)

既存完了タスクの監査で、review-loop が runtime 依存であるにもかかわらず配布・登録されない
矛盾を確認した。以下は ADR-006 に基づく是正実装の完了条件である。

- [x] `sdd-review-loop` の3 manifest と両 marketplace entry を追加
- [x] installer dependency closure を bootstrap/lite/ship から `sdd-review-loop` まで展開
- [x] `--source-directory` は Git 追跡ファイルだけを stage
- [x] bootstrap の lite 選択優先順位と lite-spec の handoff を2コマンド workflow と同期

### Blockers
None

---

## T-003 内部 SKILL.md に Caller ヘッダー追加

Approval: Approved
Status: Done
Risk: low
Risk Rationale: 各ファイルへの4行追加のみ。validate-repository.ps1 の期待テキストとの競合がないことを確認する。
Required Workflow: acceptance-first
Requirements: REQ-001

### Goal
sdd-ship が orchestrate する内部スキルに "このスキルは sdd-ship から呼ばれる" という
caller-context ヘッダーを追加し、直接呼び出しを抑止する。

### Must Read
- tests/validate-repository.ps1 L152, L159（期待テキスト確認）

### Scope

以下の3ファイルの frontmatter 直後に追加（削除はしない）:

```markdown
> **Caller**: This skill is invoked by `sdd-ship`. Do not invoke directly.
> Results are returned to the caller; no downstream skill is auto-invoked.
```

対象:
- `plugins/sdd-implementation/skills/implement-task/SKILL.md`
- `plugins/sdd-implementation/skills/implement-tasks/SKILL.md`
- `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md`

### Done When
- [x] 3ファイルに Caller ヘッダーが追加された
- [x] `validate-repository.ps1` L152/L159 の期待テキストが壊れていない
- [x] BL-010（scenario.tests.sh）が pass する
- [x] 実装レポート作成（reports/implementation/sdd-forge-refactor-T-003.md）
- [x] quality gate pass

### Blockers
None

---

## T-004 ドキュメント再構成

Approval: Approved
Status: Done
Risk: low
Risk Rationale: ドキュメント移動・更新のみ。CI への影響なし。リンク切れのリスクは redirect note で軽減。
Required Workflow: acceptance-first
Requirements: REQ-005

### Goal
`docs/skill-reference.md` と `docs/workflow-guide.md` を2コマンド化後のユーザーモデルに
合わせて再構成する。

### Must Read
- specs/sdd-forge-refactor/design.md §ドキュメント再構成計画

### Scope

**`docs/skill-reference.md`** の更新（行レベルチェックリスト）:
- L3: `7つのプラグイン（...sdd-impl-review...sdd-task-review...）` → `6つのプラグイン（...sdd-review-loop...）`
- L16-17: skill テーブルの「所属プラグイン」列 → `sdd-review-loop`
- L786-788: `/sdd-impl-review:impl-review-loop` → `/sdd-review-loop:impl-review-loop`
- L851-853: `/sdd-task-review:task-review-loop` → `/sdd-review-loop:task-review-loop`
- ユーザー向け Part1 / コントリビューター向け Part2 への分割: `docs/contributor/skill-reference-detail.md` を作成

**`docs/workflow-guide.md`** の更新:
- フルトラック詳細を `docs/contributor/workflow-detail.md` に移動
- Mermaid 図はスキル名がベア名のため変更不要

**`plugins/sdd-quality-loop/references/wfi-category-guide.md`**:
- forbidden terms リストに `sdd-review-loop` を追記（既存エントリは変更しない）

**`README.md` / `USERGUIDE.md`**:
- skill-reference.md / workflow-guide.md へのリンクが分割後も有効かを確認・更新

### Done When
- [x] skill-reference.md が L3/L16-17/L786-788/L851-853 で新プラグイン名を使用している
- [x] docs/contributor/ ディレクトリが存在し skill-reference-detail.md を含む
- [x] workflow-guide.md のユーザー向けコンパクト版が 450 行以内（297行）
- [x] wfi-category-guide.md の forbidden terms に sdd-review-loop が含まれる
- [x] README と USERGUIDE のリンクが有効
- [x] 実装レポート作成（reports/implementation/sdd-forge-refactor-T-004.md）
- [x] quality gate pass

### Blockers
None

---

## T-005 CHANGELOG + guard-parity Scenarios 19/20/21 + validate-repository.ps1 修正

Approval: Approved
Status: Done
Risk: low
Risk Rationale: テスト追加と既存 CI 不整合の修正のみ。
Required Workflow: acceptance-first
Requirements: REQ-003, REQ-006

### Goal
テストスイートを強化し、v0.15.x のリファクタリングを CHANGELOG に記録する。

### Must Read
- specs/sdd-forge-refactor/design.md §Python Check 2e 追加仕様
- tests/guard-parity.tests.sh（既存パターン確認）
- tests/validate-repository.ps1（$expectedSkills / $forbiddenPaths 確認）

### Scope

**`tests/guard-parity.tests.sh`** に Scenarios 19/20/21 を追加:
- Scenario 19: verdict なしで `Impl-Review-Status: Passed` を書く → JS exit 2, Python exit 2
- Scenario 20: 有効 PASS verdict あり → JS exit 0, Python exit 0
  ⚠️ guard 実行直前に `cd "$WORK"` が必要（CWD 相対 path 解決のため）
- Scenario 21: FAIL verdict では拒否 → JS exit 2, Python exit 2

**`tests/validate-repository.ps1`** の修正（pre-existing bug 修正）:
- `$expectedSkills` に `"sdd-bootstrap"` と `"sdd-ship"` を追加（15 → 17 件）
- `$forbiddenPaths` に `"plugins/sdd-impl-review"` と `"plugins/sdd-task-review"` を追加

**`CHANGELOG.md`** に v0.15.x エントリを追加。

### Done When
- [x] guard-parity.tests.sh が 21 シナリオすべてで pass する（AC-006）
- [x] validate-repository.ps1 が 17 件のスキルを検出して pass する（AC-007）
- [x] $forbiddenPaths に旧プラグインパスが含まれる
- [x] CHANGELOG に v0.15.x エントリがある
- [x] BL-009（guard-parity）、BL-010（scenario）、BL-011（install）が pass する
- [x] 実装レポート作成（reports/implementation/sdd-forge-refactor-T-005.md）
- [x] quality gate pass

### Blockers
None
