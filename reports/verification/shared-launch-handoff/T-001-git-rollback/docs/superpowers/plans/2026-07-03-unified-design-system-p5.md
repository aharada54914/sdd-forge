# Unified Design System P5' (Tests, Docs, Closeout) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close out the unified design-system integration: fix the deferred sh/ps1 output-parity nit, document the feature across workflow-guide / skill-reference / README / CHANGELOG, and run the final verification sweep (including the ship-no-change contract confirmation).

**Architecture:** P5' of `docs/superpowers/specs/2026-07-03-unified-design-system-design.md`. Note: the spec's P5'-1 (design-system-compliance test pair) was already delivered in P4' Task 3; this plan's test work is the deferred parity fix plus doc-presence assertions (DS-017).

**Tech Stack:** Markdown docs, PowerShell/sh script touch-up, paired tests.

**Branch:** feature/unified-design-system

## Global Constraints

- PROTECTED files stay untouched (tests/gates.tests.sh, eval, constant-parity, guard-parity, check-contract*, hooks, reviewer agent files, ship SKILL.md — ship is verified unchanged, not edited).
- docs/workflow-guide.md edits must not reorder or insert `spec-review-loop` / `impl-review-loop` / `task-review-loop` mentions inside sections 3.1-3.4 (tests/workflow-documentation.tests.sh asserts their relative order) — the new subsection mentions only design-sync-loop / visual-verify-loop / check-design-system.
- No non-ASCII literals in .ps1 additions; Japanese/UTF-8 fine in .md and .sh.
- CHANGELOG entry goes under `## Unreleased`, AFTER the existing `### デザイン駆動高速イテレーションレーン` section and BEFORE `## v1.7.0 (2026-07-02)`.
- Run sh via Bash tool, ps1 via `powershell -NoProfile -ExecutionPolicy Bypass -File <path>`; if a subagent environment denies PowerShell, note it — the controller verifies.
- Git commits end with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`; author `aharada` with dummy email only.

---

### Task 1: sh/ps1 raw-value finding parity fix

**Files:**
- Modify: `plugins/sdd-quality-loop/scripts/check-design-system.ps1` (one line: include matched line text)
- Modify: `tests/design-system-compliance.tests.sh` (strengthen CDS-003 to assert the offending content appears)
- Modify: `tests/design-system-compliance.tests.ps1` (same)

**Interfaces:**
- Consumes: P4' Task 3 script pair.
- Produces: identical finding format in both scripts: `raw style value: <file>: <lineno>:<line text>`.

- [ ] **Step 1: Strengthen the CDS-003 assertions (failing for ps1)**

In `tests/design-system-compliance.tests.sh`, in the CDS-003 block, replace:

```sh
case "$out" in *"check-design-system WARN"*"raw style value"*) [ "$rc" -eq 0 ] && pass "CDS-003 warn on raw value" || fail "CDS-003 warn exit code" ;; *) fail "CDS-003 warn on raw value ($out)" ;; esac
```

with:

```sh
case "$out" in *"check-design-system WARN"*"raw style value"*"#ff0000"*) [ "$rc" -eq 0 ] && pass "CDS-003 warn on raw value" || fail "CDS-003 warn exit code" ;; *) fail "CDS-003 warn on raw value ($out)" ;; esac
```

In `tests/design-system-compliance.tests.ps1`, in the CDS-003 block, replace:

```powershell
    if ($LASTEXITCODE -ne 0 -or $out -notmatch 'check-design-system WARN' -or $out -notmatch 'raw style value') { throw "not ok: CDS-003 warn ($out)" }
```

with:

```powershell
    if ($LASTEXITCODE -ne 0 -or $out -notmatch 'check-design-system WARN' -or $out -notmatch 'raw style value' -or $out -notmatch 'ff0000') { throw "not ok: CDS-003 warn ($out)" }
```

- [ ] **Step 2: Run both tests to observe the asymmetry**

Run: `sh tests/design-system-compliance.tests.sh` — Expected: still `PASS: 7 / FAIL: 0` (the sh script already prints the matched line text).
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/design-system-compliance.tests.ps1` — Expected: throws `not ok: CDS-003 warn` (ps1 script prints only the line number today). If PowerShell is denied in your environment, note it and continue — the logic gap is established by reading the script.

- [ ] **Step 3: Fix the ps1 finding format**

In `plugins/sdd-quality-loop/scripts/check-design-system.ps1`, replace:

```powershell
    foreach ($hit in $hits) { $findings += "raw style value: ${rel}: line $($hit.LineNumber)" }
```

with:

```powershell
    foreach ($hit in $hits) { $findings += "raw style value: ${rel}: $($hit.LineNumber):$($hit.Line)" }
```

- [ ] **Step 4: Run both tests to verify green**

Run: `sh tests/design-system-compliance.tests.sh` — Expected: `PASS: 7 / FAIL: 0`, exit 0.
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/design-system-compliance.tests.ps1` — Expected: ok CDS-001..CDS-004 + final ok, exit 0.

- [ ] **Step 5: Commit**

```bash
git add plugins/sdd-quality-loop/scripts/check-design-system.ps1 tests/design-system-compliance.tests.sh tests/design-system-compliance.tests.ps1
git commit -m "fix(quality-loop): include matched line text in ps1 raw-value findings for sh parity

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Documentation (workflow-guide, skill-reference, README, CHANGELOG)

**Files:**
- Modify: `docs/workflow-guide.md` (new subsection before `### 3.2 不具合修正 (bugfix)`)
- Modify: `docs/skill-reference.md` (new `### check-design-system` entry before `## 6. テンプレート一覧`)
- Modify: `README.md` (new 特徴 bullet after the sdd-lite bullet)
- Modify: `CHANGELOG.md` (new Unreleased section)
- Test: `tests/design-system-contract.tests.sh`, `tests/design-system-contract.tests.ps1` (append DS-017)

**Interfaces:**
- Consumes: all P0'-P4' vocabulary.
- Produces: user-facing documentation; no downstream consumers.

- [ ] **Step 1: Append failing DS-017 assertions**

In `tests/design-system-contract.tests.sh`, insert directly before the final three lines:

```sh
# DS-017 user-facing documentation
assert_contains "$ROOT/README.md" 'design-system/' "DS-017 README feature bullet"
assert_contains "$ROOT/docs/workflow-guide.md" 'design-sync-loop' "DS-017 workflow-guide integration"
assert_contains "$ROOT/docs/skill-reference.md" 'check-design-system' "DS-017 skill-reference script entry"
assert_contains "$ROOT/CHANGELOG.md" '統一デザインシステム統合' "DS-017 changelog entry"
```

In `tests/design-system-contract.tests.ps1`, insert directly before the final line:

```powershell
# DS-017 user-facing documentation (ASCII-checkable subset; the Japanese changelog heading is asserted by the sh twin)
$readme = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "README.md")
if ($readme -notmatch 'design-system/') { throw "not ok: DS-017 README bullet missing" }
$wfg = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "docs/workflow-guide.md")
if ($wfg -notmatch 'design-sync-loop') { throw "not ok: DS-017 workflow-guide missing" }
$sref = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "docs/skill-reference.md")
if ($sref -notmatch 'check-design-system') { throw "not ok: DS-017 skill-reference missing" }
Write-Host "ok: DS-017 documentation"
```

- [ ] **Step 2: Run the sh test to verify DS-017 fails**

Run: `sh tests/design-system-contract.tests.sh`
Expected: 66 PASS, 4 FAIL (DS-017), exit 1.

- [ ] **Step 3: Add the workflow-guide subsection**

In `docs/workflow-guide.md`, insert directly before the `### 3.2 不具合修正 (bugfix)` heading:

```markdown
### 3.1b デザインシステム統合（UI アプリ・任意）

UI アプリでは Step 3a の途中で `ds_profile`（`custom` / `none`）を選択する。
`custom` を選ぶと内部スキル `design-sync-loop` が実行され、プロジェクト直下の
`design-system/`（W3C DTCG 準拠の design-tokens.json / design-system.md /
ui-patterns.md）を保証（ui-ux-pro-max シード生成・Figma DTCG エクスポート取込・
D6 テンプレートインタビューのいずれか）したうえで、トークン駆動の使い捨て
モックアップを生成し、claude.ai/design で確認ループを回す（アップロードは
都度人間承認）。実装段階では `implement-task` が UI タスクで
`visual-verify-loop`（advisory・非ブロッキング）を実行し、品質検証では
`check-design-system.(sh|ps1)` が warn モードで決定論的に照合する
（`SDD_DESIGN_SYSTEM_ENFORCE=error` で昇格）。`ds_profile: none` と非 UI
フィーチャーでは生成物・質問は一切増えない。

```

- [ ] **Step 4: Add the skill-reference script entry**

In `docs/skill-reference.md`, insert directly before the `## 6. テンプレート一覧` heading:

````markdown
### check-design-system

デザインシステム準拠の決定論ゲート（warn フェーズ）。対象プロジェクトに
`design-system/` が存在するときのみ動作し、無ければ note 付きでスキップする
（exit 0）。① design-tokens.json の契約エンベロープ検証
（`design-system-contract/v1`・semver・generated_by・color/typography/spacing）、
② 変更ファイル中の生スタイル値（#hex / rgb() / hsl()）検出（design-system/・
build/・tests/・*.md・*.svg は除外）、③ design.md の
`## Design System Compliance` セクション確認。既定は WARN（exit 0）、
`SDD_DESIGN_SYSTEM_ENFORCE=error` で違反時に exit 1。

```txt
# Git Bash / WSL / macOS / Linux
plugins/sdd-quality-loop/scripts/check-design-system.sh <project-root> [<design-md>] [<changed-file>...]

# PowerShell
plugins/sdd-quality-loop/scripts/check-design-system.ps1 -ProjectRoot <path> [-DesignMd <path>] [-ChangedFiles <paths...>]
```

````

- [ ] **Step 5: Add the README feature bullet**

In `README.md`, in the `## 特徴` list, insert a new bullet directly after the `- **軽量トラック sdd-lite**: ...` bullet:

```markdown
- **統一デザインシステム統合**: UI アプリでは `ds_profile: custom` を選ぶと、プロジェクト直下の `design-system/`（W3C DTCG 準拠 design-tokens.json・design-system.md・ui-patterns.md）を契約として生成・強制します。仕様段階は `design-sync-loop`（ui-ux-pro-max シード生成 / Figma DTCG 取込 / claude.ai/design 確認ループ）、実装段階は `visual-verify-loop`（Claude Preview / wpf-visual-verify による視覚検証）、品質検証は `check-design-system`（warn 開始の決定論ゲート）の3層で支えます。a11y 基準は WCAG 2.2 AA。非 UI プロジェクトへのオーバーヘッドはゼロです。
```

- [ ] **Step 6: Add the CHANGELOG section**

In `CHANGELOG.md`, insert after the `### デザイン駆動高速イテレーションレーン` section's last line (`  ルーティングを追加。公開スキルは5つのまま（可視性契約は不変）。`) and before `## v1.7.0 (2026-07-02)`:

```markdown

### 統一デザインシステム統合（design-system 契約）

- プロジェクトレベルの `design-system/` 契約を新設: W3C DTCG 準拠の
  design-tokens.json（`contracts/design-system.contract.v1.schema.json` で
  メタ検証）、design-system.md（3層構造・WCAG 2.2 AA）、ui-patterns.md
  （言語非依存の普遍的 UX 規約6カテゴリ）。テンプレート3点を同梱し、
  PLUGIN-CONTRACTS.md に producer/consumer 契約を定義。
- interviewer に `ds_profile`（custom / none）選択を追加。custom では
  design-sync-loop v2 が design-system/ を保証（ui-ux-pro-max シード生成・
  Figma DTCG エクスポート取込・D6 テンプレートインタビューの3経路）し、
  トークン駆動モックアップを生成。investigate-codebase に brownfield 用
  Design Inventory を追加。
- レビュー統合: impl-reviewer-a に DESIGN-SYSTEM-CONFORMANCE 検査を追加
  （impl-review-loop は20チェック化）、impl-reviewer-b の DESIGN-WITHIN-SCOPE
  に規約外 UI ライブラリ検出を追加。
- 実装強制: implementation-policy に UI 実装規則（トークン参照のみ・
  再利用優先・a11y 要点・lint 未整備のタスク化）、implement-task の
  条件付き必須読み物、visual-verify-loop の照合基準に design-system を追加。
- 検証ゲート: design-system-checklist.md 新設、accessibility-checklist を
  WCAG 2.2 AA に更新、決定論ゲート `check-design-system.(sh|ps1)` を warn
  モードで導入（`SDD_DESIGN_SYSTEM_ENFORCE=error` で昇格、導入2リリース後に
  error 化予定）。verification-contract に `design-system` チェック、
  risk-gate-matrix に条件付きコントロール行を追加。
- 全変更は条件付きロード / waivable check として実装し、非 UI プロジェクト・
  `ds_profile: none` へのオーバーヘッドはゼロ。
```

- [ ] **Step 7: Run the gating tests to verify green**

Run: `sh tests/design-system-contract.tests.sh` — Expected: `FAIL: 0` (70 PASS), exit 0.
Run: `sh tests/workflow-documentation.tests.sh` — Expected: exit 0 (review-loop ordering unaffected).
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/design-system-contract.tests.ps1` — Expected: ok through `ok: DS-017 documentation`, exit 0.

- [ ] **Step 8: Commit**

```bash
git add docs/workflow-guide.md docs/skill-reference.md README.md CHANGELOG.md tests/design-system-contract.tests.sh tests/design-system-contract.tests.ps1
git commit -m "docs: document unified design-system integration across guide, reference, README, changelog

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Closeout verification sweep

**Files:**
- No file changes expected. If a failure reveals a defect, STOP and report — do not fix inside this task.

**Interfaces:**
- Consumes: everything from P0'-P5'.
- Produces: the phase-closeout evidence recorded in the task report.

- [ ] **Step 1: Confirm ship needs no changes**

Read `PLUGIN-CONTRACTS.md`'s `## sdd-ship → internal plugins (v0.15.0+)` Orchestration Contract (5 delegations) and `plugins/sdd-ship/skills/ship/SKILL.md`'s track detection. Confirm and record in the report: design-system integration enters via bootstrap (interviewer/design-sync-loop), implementation (implement-task/visual-verify-loop), and quality-loop (quality-gate/check-design-system) — all behind existing delegation boundaries, so sdd-ship requires no change. Do not edit ship files.

- [ ] **Step 2: Run the full relevant test set**

Run each; all must pass:

```
sh tests/design-system-contract.tests.sh          → PASS: 70 / FAIL: 0
sh tests/design-system-compliance.tests.sh        → PASS: 7 / FAIL: 0
sh tests/bootstrap-interview-guidance.tests.sh    → FAIL: 0
sh tests/bootstrap-layer-templates.tests.sh       → FAIL: 0
sh tests/review-prompt-calibration.tests.sh       → exit 0
sh tests/workflow-documentation.tests.sh          → exit 0
sh tests/crlf-parity.tests.sh                     → exit 0
powershell -NoProfile -ExecutionPolicy Bypass -File tests/design-system-contract.tests.ps1   → exit 0
powershell -NoProfile -ExecutionPolicy Bypass -File tests/design-system-compliance.tests.ps1 → exit 0
powershell -NoProfile -ExecutionPolicy Bypass -File tests/claude-manifest-validation.tests.ps1 → exit 0
```

(If PowerShell is denied in your environment, run the sh set and note the ps1 gap for the controller.) Any unexpected failure: classify against the branch base `66717ff` in a temp worktree (same test, same command) — pre-existing failures are recorded, regressions STOP the task.

- [ ] **Step 3: Verify the skill visibility contract one last time**

Run an inline replica of the validator's skill checks (enumerate plugins/**/SKILL.md, extract `name:`; expect exactly 21 names matching tests/validate-repository.ps1's `$expectedSkills`; every skill has `disable-model-invocation: true`; all except bootstrap, ship, sdd-sudo, fix-by-review-ticket, diagnose have `user-invocable: false`). Record the result.

- [ ] **Step 4: Write the closeout report**

Record all outputs in the task report (no commit — this task changes no files).
