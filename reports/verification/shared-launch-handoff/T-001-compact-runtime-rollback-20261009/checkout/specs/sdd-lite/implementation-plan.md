# sdd-lite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 社内・部署内アプリ向けの「中量」開発トラックを、独立した軽量プラグイン `sdd-lite` として追加する（要件/設計/タスク + 単一承認 + 軽量ゲートの4ステップ、既存資産を最大限再利用）。

**Architecture:** A案（再利用最大化）。新規は `sdd-lite` プラグイン1つ（スキル2・forkスクリプト1・テンプレ4・policy1）。`implement-task`・`check-placeholders`・`sdd-hook-guard`・`kill-switch` は無改変流用。`check-task-state` のみ lite 用に fork し `Done` を evidence-bundle 非依存にする。配布はコンパニオン同梱（3プラグイン同時 install）。

**Tech Stack:** POSIX sh + awk、PowerShell (.ps1)、Markdown(SKILL.md/テンプレ)、JSON(plugin.json/marketplace)。3 CLI（Claude Code / Codex / Copilot）対応。

**設計の根拠:** [specs/sdd-lite/design.md](design.md)（実コード検証済み・確定）。

---

## File Structure

新規（`plugins/sdd-lite/`）:
- `.claude-plugin/plugin.json` / `.codex-plugin/plugin.json` / `.plugin/plugin.json` — 3 CLI 用メタ
- `skills/lite-spec/SKILL.md` — 軽量仕様生成
- `skills/lite-gate/SKILL.md` — 軽量ゲートのオーケストレータ
- `scripts/check-task-state-lite.sh` / `.ps1` — fork（Done を evidence-bundle 非依存に）
- `templates/requirements-lite.md` / `design-lite.md` / `tasks-lite.md` / `quality-report-lite.md`
- `references/lite-flow-policy.md` — lite 規約・昇格手順

変更（既存）:
- `.claude-plugin/marketplace.json` / `.agents/plugins/marketplace.json` — sdd-lite 登録
- `install.sh` / `install.ps1` — 導入対象に sdd-lite 追加
- `tests/gates.tests.sh` / `tests/scripts.tests.ps1` — lite ゲートのテスト追加
- `README.md` / `docs/workflow-guide.md` / `docs/skill-reference.md` — lite トラック記載
- `CHANGELOG.md` — 変更履歴

無改変流用（編集しない）: `implement-task`, `check-placeholders`, `sdd-hook-guard`, `kill-switch`, `sdd-adopt`。

---

## Task 1: プラグイン雛形（ディレクトリ + 3つの plugin.json）

**Files:**
- Create: `plugins/sdd-lite/.claude-plugin/plugin.json`
- Create: `plugins/sdd-lite/.codex-plugin/plugin.json`
- Create: `plugins/sdd-lite/.plugin/plugin.json`

- [ ] **Step 1: ディレクトリ作成**

Run:
```bash
mkdir -p plugins/sdd-lite/.claude-plugin plugins/sdd-lite/.codex-plugin plugins/sdd-lite/.plugin \
         plugins/sdd-lite/skills/lite-spec plugins/sdd-lite/skills/lite-gate \
         plugins/sdd-lite/scripts plugins/sdd-lite/templates plugins/sdd-lite/references
```

- [ ] **Step 2: Claude Code 用 plugin.json**

`plugins/sdd-lite/.claude-plugin/plugin.json`:
```json
{
  "name": "sdd-lite",
  "description": "Lightweight medium-weight SDD track for internal/departmental apps: spec, single approval, implement, lite gate.",
  "version": "0.11.0",
  "author": {
    "name": "Harada"
  }
}
```

- [ ] **Step 3: Codex CLI 用 plugin.json**

`plugins/sdd-lite/.codex-plugin/plugin.json`:
```json
{
  "name": "sdd-lite",
  "version": "0.11.0",
  "description": "Lightweight medium-weight SDD track for internal/departmental apps: spec, single approval, implement, lite gate.",
  "skills": "./skills/",
  "author": {
    "name": "Harada"
  },
  "interface": {
    "displayName": "SDD Lite",
    "shortDescription": "Lightweight SDD track for internal apps",
    "longDescription": "A medium-weight spec-driven flow for internal/departmental apps: generate requirements/design/tasks, a single human approval, implement, then a lightweight deterministic gate. Reuses the SDD anti-self-approval guard; graduates additively to full SDD.",
    "developerName": "Harada",
    "category": "Developer Tools",
    "capabilities": [
      "Lightweight specification (requirements/design/tasks)",
      "Single human approval gate",
      "Lightweight deterministic quality gate",
      "Additive graduation to full SDD"
    ],
    "defaultPrompt": "Use the lite-spec skill to prepare a lightweight specification."
  }
}
```

- [ ] **Step 4: Copilot CLI 用 plugin.json**

`plugins/sdd-lite/.plugin/plugin.json`:
```json
{
  "name": "sdd-lite",
  "description": "Lightweight medium-weight SDD track for internal/departmental apps: spec, single approval, implement, lite gate.",
  "version": "0.11.0",
  "author": {
    "name": "Harada"
  },
  "skills": "skills/"
}
```

- [ ] **Step 5: JSON 妥当性確認**

Run:
```bash
for f in plugins/sdd-lite/.claude-plugin/plugin.json plugins/sdd-lite/.codex-plugin/plugin.json plugins/sdd-lite/.plugin/plugin.json; do python3 -c "import json,sys; json.load(open('$f')); print('OK', '$f')"; done
```
Expected: 3行すべて `OK ...`

- [ ] **Step 6: Commit**

```bash
git add plugins/sdd-lite/.claude-plugin plugins/sdd-lite/.codex-plugin plugins/sdd-lite/.plugin
git commit -m "feat(sdd-lite): scaffold plugin manifests for 3 CLIs"
```

---

## Task 2: check-task-state-lite.sh（fork）+ テスト

**Files:**
- Create: `plugins/sdd-lite/scripts/check-task-state-lite.sh`
- Test: `tests/gates.tests.sh`（既存に lite ケース追記）
- Reference: `plugins/sdd-quality-loop/scripts/check-task-state.sh`（fork 元）

> **fork 差分（design §4.3）**: 元 `check-task-state.sh` から (a) `Done` の evidence.json/contract.json 必須＋check-evidence-bundle 呼出、(b) critical 二者承認、(c) `approver_id`/`risk`/`second` 関連を除去。`Done` 要件を「Approval: Approved + 実装レポートがタスクIDに言及 + quality-gate レポートがタスクIDに言及かつ `VERDICT: PASS`」に置換。共有規則（Approval/Status 妥当値、In Progress/Impl Complete/Done は Approval 必須、Impl Complete は実装レポート必須、Blocked は Blockers 内容必須、重複ID、CRLF 正規化）は踏襲。

- [ ] **Step 1: 失敗するテストを追加**

まず `tests/gates.tests.sh` を読み、既存のヘルパ（一時 fixture 作成・exit code 判定・PASS/FAIL カウント）の流儀に合わせること。次のケース群を、既存パターンに従って追記する（擬似コードでなく既存の assert ヘルパを使って実装）:

```sh
# --- sdd-lite: check-task-state-lite.sh ---
LITE="plugins/sdd-lite/scripts/check-task-state-lite.sh"

# Case L1: Done が evidence.json 無しでも、impl報告 + VERDICT:PASS報告 があれば PASS
#   fixture: tmp/specs/f/tasks.md に
#     "## T-001\nApproval: Approved\nStatus: Done\n"
#   tmp/reports/implementation/T-001.md に "T-001" を含む内容
#   tmp/reports/quality-gate/T-001.md に "Task ID: T-001" と "VERDICT: PASS"
#   実行: sh "$LITE" tmp/specs/f/tasks.md tmp/reports/quality-gate tmp/reports/implementation tmp
#   期待: 終了コード 0

# Case L2: Approval 無しの Done は FAIL
#   "## T-001\nApproval: Draft\nStatus: Done\n" → 終了コード 1

# Case L3: Done だが quality-gate レポートに VERDICT:PASS が無い → FAIL
#   quality-gate レポートを "VERDICT: FAIL" にする → 終了コード 1

# Case L4: Done だが impl レポートがタスクIDに言及しない → FAIL（impl ディレクトリ空）→ 終了コード 1

# Case L5: 重複タスクID → FAIL
#   "## T-001 ...\n## T-001 ..." → 終了コード 1

# Case L6: CRLF の tasks.md でも L1 と同じく PASS（行末 \r 付き）
```

- [ ] **Step 2: テストが落ちることを確認**

Run: `bash tests/gates.tests.sh`
Expected: 追加した lite ケースが FAIL（`check-task-state-lite.sh` 未作成のため）。

- [ ] **Step 3: fork スクリプトを実装**

`plugins/sdd-lite/scripts/check-task-state-lite.sh`:
```sh
#!/bin/sh
# Deterministic gate (lite): validate the tasks.md state machine for the sdd-lite flow.
# Usage: check-task-state-lite.sh <path-to-tasks.md> [reports-dir] [impl-reports-dir] [repo-root]
# Reports dirs default to reports/quality-gate and reports/implementation.
# Lite differences vs check-task-state.sh:
#  - Done does NOT require verification/<id>.evidence.json or .contract.json.
#  - Done requires: Approval: Approved + an implementation report mentioning the
#    task id + a quality-gate report mentioning the task id with VERDICT: PASS.
#  - No critical two-person-approval enforcement (lite has no critical tier).
# Shared rules (same as the full gate):
#  - Approval is Draft or Approved; Status is a known lifecycle value.
#  - In Progress / Implementation Complete / Done require Approval: Approved.
#  - Implementation Complete (and Done) require an implementation report mentioning the task id.
#  - Blocked requires non-empty ### Blockers content.
#  - Duplicate task ids → fail.
tasks="$1"
reports="${2:-reports/quality-gate}"
impl_reports="${3:-reports/implementation}"
repo_root="${4:-.}"

if [ -z "$tasks" ] || [ ! -f "$tasks" ]; then
  echo "check-task-state-lite: tasks file not found: $tasks" >&2
  exit 1
fi

_tmpout="$(mktemp)"
trap 'rm -f "$_tmpout"' EXIT

TASKS="$tasks" REPORTS="$reports" IMPL_REPORTS="$impl_reports" REPO_ROOT="$repo_root" awk '
BEGIN { task=""; failures=0; count=0; in_blockers=0; blockers_content="" }
# Strip trailing CR so CRLF tasks.md parses identically to LF (cross-platform parity).
{ sub(/\r$/, "") }
function fail(msg) { print " - " msg; failures++ }
/^## T-[0-9]+/ {
  if (task != "") finish()
  newid = $2
  if (seen[newid]) fail("duplicate task id " newid)
  seen[newid] = 1
  task = newid; approval=""; status=""; count++
  in_blockers=0; blockers_content=""
}
/^Approval:/ { if (task != "") { approval=$0; sub(/^Approval:[ \t]*/, "", approval); in_blockers=0 } }
/^Status:/   { if (task != "") { status=$0;   sub(/^Status:[ \t]*/, "", status);   in_blockers=0 } }
/^### Blockers/ { if (task != "") { in_blockers=1 } }
/^## [^#]/ { if ($0 !~ /^## T-[0-9]+/) { in_blockers=0 } }
{
  if (in_blockers && $0 !~ /^### Blockers/) {
    line=$0
    gsub(/^[ \t]*[-*][ \t]*/, "", line)
    gsub(/^[ \t]+/, "", line)
    if (line != "" && tolower(line) != "none") blockers_content = blockers_content line
  }
}
function finish(   is_valid_approval, is_approved, cmd, impl_report, f, ok, vc, qa_found) {
  if (approval == "") fail(task " has no Approval line")
  else {
    is_valid_approval = (approval == "Draft" || approval == "Approved" || \
      approval ~ /^Approved \([^ )]+ [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\)$/)
    if (!is_valid_approval) fail(task " has invalid Approval: " approval)
  }
  is_approved = (approval == "Approved" || approval ~ /^Approved \([^ )]+ [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\)$/)
  if (status == "") fail(task " has no Status line")
  else if (status != "Planned" && status != "In Progress" && status != "Blocked" && status != "Implementation Complete" && status != "Done")
    fail(task " has invalid Status: " status)
  if ((status == "In Progress" || status == "Implementation Complete" || status == "Done") && !is_approved)
    fail(task " is \x27" status "\x27 without Approval: Approved")
  # Implementation report required for Implementation Complete AND Done (word-boundary match)
  if (status == "Implementation Complete" || status == "Done") {
    cmd = "grep -rlw \x27" task "\x27 \"" ENVIRON["IMPL_REPORTS"] "\" 2>/dev/null | head -1"
    cmd | getline impl_report; close(cmd)
    if (impl_report == "") fail(task " is \x27" status "\x27 but no implementation report in " ENVIRON["IMPL_REPORTS"] " mentions it")
  }
  # Lite Done: require a quality-gate report mentioning the task with VERDICT: PASS
  if (status == "Done") {
    qa_found = ""
    cmd = "grep -rlw \x27" task "\x27 \"" ENVIRON["REPORTS"] "\" 2>/dev/null"
    while ((cmd | getline f) > 0) {
      vc = "grep -Eq \x27^VERDICT:[ \t]*PASS[ \t]*$\x27 \"" f "\" && echo yes || echo no"
      vc | getline ok; close(vc)
      if (ok == "yes") { qa_found = f; break }
    }
    close(cmd)
    if (qa_found == "") fail(task " is Done but no quality-gate report in " ENVIRON["REPORTS"] " mentions it with VERDICT: PASS")
  }
  if (status == "Blocked") {
    if (blockers_content == "") fail(task " is Blocked but ### Blockers section has no content (not None or empty)")
  }
}
END {
  if (task != "") finish()
  if (count == 0) { print "check-task-state-lite: no tasks found"; exit 1 }
  if (failures > 0) { exit 1 }
  print "Task state (lite) check passed for " count " task(s)."
}
' "$tasks" > "$_tmpout" 2>&1
rc=$?
if [ $rc -ne 0 ]; then
  echo "Task state (lite) check FAILED:"
fi
cat "$_tmpout"
exit $rc
```

Run: `chmod +x plugins/sdd-lite/scripts/check-task-state-lite.sh`

- [ ] **Step 4: テストが通ることを確認**

Run: `bash tests/gates.tests.sh`
Expected: 追加した lite ケース L1–L6 すべて PASS、既存ケースも緑のまま。

- [ ] **Step 5: Commit**

```bash
git add plugins/sdd-lite/scripts/check-task-state-lite.sh tests/gates.tests.sh
git commit -m "feat(sdd-lite): add check-task-state-lite (evidence-bundle-free Done) + tests"
```

---

## Task 3: check-task-state-lite.ps1（fork）+ ps1 テスト

**Files:**
- Create: `plugins/sdd-lite/scripts/check-task-state-lite.ps1`
- Test: `tests/scripts.tests.ps1`（既存に lite ケース追記）
- Reference: `plugins/sdd-quality-loop/scripts/check-task-state.ps1`（fork 元）

> PowerShell 版は `check-task-state.ps1` を fork 元とし、Task 2 と**同一の lite 差分**を適用する（Done の evidence.json/contract.json 必須・check-evidence-bundle 呼出・critical 二者承認を除去し、Done 要件を impl報告 + quality-gate報告 `VERDICT: PASS` に置換）。挙動・引数・出力メッセージは `.sh` と一致させること。

- [ ] **Step 1: 失敗する ps1 テストを追加**

`tests/scripts.tests.ps1` を読み、既存ヘルパに合わせて Task 2 の L1–L6 と同等のケースを追記（pwsh で一時 fixture を作り、`pwsh -File ... check-task-state-lite.ps1 <tasks> <qg-dir> <impl-dir> <root>` の終了コードを判定）。

- [ ] **Step 2: 落ちることを確認**

Run: `pwsh ./tests/scripts.tests.ps1`
Expected: 追加 lite ケースが FAIL（`.ps1` 未作成）。

- [ ] **Step 3: .ps1 を実装**

`plugins/sdd-quality-loop/scripts/check-task-state.ps1` を読み、上記 lite 差分を適用して `plugins/sdd-lite/scripts/check-task-state-lite.ps1` を作成する。Done 判定は次の論理に置換する（疑似コードでなく ps1 構文で実装）:
- `Status -eq 'Done'` のとき:
  - `Approval` が `Approved`（または `Approved (<id> <ISO>)`）であること
  - `reports/implementation` 配下のいずれかのファイルがタスクID（語境界）に言及すること
  - `reports/quality-gate` 配下のいずれかのファイルがタスクIDに言及し、かつ行頭 `^VERDICT:\s*PASS\s*$`（複数行・大小は元実装に合わせる）を含むこと
- evidence.json / contract.json / 署名 / 二者承認の検査は**入れない**。
- CRLF 正規化・Approval/Status 妥当値・In Progress/Impl Complete/Done の Approval 必須・Blocked の Blockers 必須・重複ID検出は `.sh` と同一に保つ。

- [ ] **Step 4: 通ることを確認**

Run: `pwsh ./tests/scripts.tests.ps1`
Expected: lite ケース PASS、既存も緑。

- [ ] **Step 5: クロスプラットフォーム一致を確認**

Run（同一 fixture で sh/ps1 の終了コードが一致することを目視）:
```bash
bash tests/gates.tests.sh >/dev/null 2>&1 && echo "sh OK"; pwsh ./tests/scripts.tests.ps1 >/dev/null 2>&1 && echo "ps1 OK"
```
Expected: `sh OK` と `ps1 OK`。

- [ ] **Step 6: Commit**

```bash
git add plugins/sdd-lite/scripts/check-task-state-lite.ps1 tests/scripts.tests.ps1
git commit -m "feat(sdd-lite): add check-task-state-lite.ps1 mirroring sh + ps1 tests"
```

---

## Task 4: テンプレート4種

**Files:**
- Create: `plugins/sdd-lite/templates/requirements-lite.md`
- Create: `plugins/sdd-lite/templates/design-lite.md`
- Create: `plugins/sdd-lite/templates/tasks-lite.md`
- Create: `plugins/sdd-lite/templates/quality-report-lite.md`

- [ ] **Step 1: requirements-lite.md**

```markdown
# 要件（lite）: <feature>

- **Issue/出典**: <URL or テキスト>
- **目的**: <なぜ作るか 1–3文>

## ユーザーストーリー / 要求
- REQ-001: <主体>として<目的>のために<機能>がほしい
- REQ-002: ...

## スコープ外
- <やらないこと>

## Open Questions
- <未決事項。勝手に埋めない>
```

- [ ] **Step 2: design-lite.md**

```markdown
# 設計（lite）: <feature>

## 方針
<2–4文。既存パターンへの追従点>

## 変更/新規ファイル
- `path/to/file` — 責務

## データ/IF（必要時のみ）
- <入出力・スキーマの要点>

## テスト方針
- <何をどう検証するか>
```

- [ ] **Step 3: tasks-lite.md**

> 注: `Approval` と `Status` の行名・値は既存 `check-task-state-lite` と完全一致させること（ガード/ゲートがこの形式に依存）。`Risk` 行は lite では不要。

```markdown
# タスク（lite）: <feature>

## T-001 <タスク名>
Approval: Draft
Status: Planned

### Scope
- <この差分で触る範囲>

### Done When
- <完了条件（観測可能に）>

### Blockers
- None
```

- [ ] **Step 4: quality-report-lite.md**

> 注: `Task ID:` と `VERDICT:` の行は `check-task-state-lite` の Done 判定が依存するため、行頭・綴りを厳守（`VERDICT: PASS` / `VERDICT: FAIL`）。

```markdown
# 品質レポート（lite）

Task ID: <T-001>
VERDICT: PASS

## 実行したチェック
- placeholder-scan: PASS — <根拠/出力要約>
- lint: PASS — <コマンドと結果>
- typecheck: PASS — <コマンドと結果>
- build: PASS — <コマンドと結果>
- tests: PASS — <コマンドと結果>
- task-state-lite: PASS — <出力要約>

## 備考
- <あれば>
```

- [ ] **Step 5: Commit**

```bash
git add plugins/sdd-lite/templates
git commit -m "feat(sdd-lite): add lite spec/report templates"
```

---

## Task 5: lite-spec スキル

**Files:**
- Create: `plugins/sdd-lite/skills/lite-spec/SKILL.md`

- [ ] **Step 1: SKILL.md を作成**

```markdown
---
name: lite-spec
description: Lightweight SDD specification for internal/departmental apps. Creates requirements, design, and tasks (single-approval, no traceability/ADR/evidence-bundle). Use for low-stakes internal app work; graduate to sdd-bootstrap-interviewer for higher rigor.
disable-model-invocation: true
---

# Lite Spec

社内・部署内アプリ向けの軽量仕様を作る。要件・設計・タスクの3ファイルのみを生成し、traceability/ADR/受入テストの重い記述は任意とする。アプリのコードは実装しない。

## Invocation

Codex:

\`\`\`txt
Use the lite-spec skill.
Source: <issue URL or 要件テキスト>
\`\`\`

Claude Code:

\`\`\`txt
/sdd-lite:lite-spec <source>
\`\`\`

## Preconditions

リポジトリ root に `AGENTS.md` が存在し、`scripts/check-sdd-structure.sh`（または `.ps1`）が `missing:` を出さないこと。未整備なら `/sdd-bootstrap:sdd-adopt` を案内して停止する。lite でも SDD 構造（AGENTS.md + 必須ディレクトリ）は前提（implement-task の前提条件）。

## Process

1. Issue URL か要件テキストを受け取る（読み取り専用取得を試み、不可なら本文を尋ねる）。
2. 関連コード・既存パターンを軽く調査（大規模調査は委譲可）。
3. 次の3ファイルを `specs/<feature>/` に生成（テンプレは本プラグインの `templates/`）:
   - `requirements.md`（`templates/requirements-lite.md`）
   - `design.md`（`templates/design-lite.md`）
   - `tasks.md`（`templates/tasks-lite.md`）
4. 各タスクは `Approval: Draft` / `Status: Planned` で生成する。`Risk:` 行は付けない（lite は階層強制を使わない）。
5. 不明な製品判断は `Open Questions` に残す。勝手に埋めない。

## Approval Gate

人間のみが `tasks.md` の `Approval:` を `Approved` にできる。AI は承認できない（既存 hook-guard が `tasks.md` の `Approval: Approved` 増加をブロックする）。要件/設計/スコープ/重要リスクが曖昧なまま承認を促さない。

## Boundaries

- traceability.md・ADR・evidence-bundle・受入テストの厳密記述は生成しない（必要なら sdd-bootstrap-interviewer に切替）。
- アプリのコードを実装しない（実装は `implement-task`）。
- 承認・Done 化を行わない。

## Handoff

生成ファイル・Open Questions・最初の Draft タスクを報告し、「承認後に `/sdd-implementation:implement-task` で実装開始」と案内する。昇格が必要になったら design.md §6 の手順で full SDD に移行できることも伝える。
```

- [ ] **Step 2: フロントマター妥当性確認**

Run:
```bash
head -5 plugins/sdd-lite/skills/lite-spec/SKILL.md
```
Expected: `---` / `name: lite-spec` / `description: ...` / `disable-model-invocation: true` / `---`

- [ ] **Step 3: Commit**

```bash
git add plugins/sdd-lite/skills/lite-spec/SKILL.md
git commit -m "feat(sdd-lite): add lite-spec skill"
```

---

## Task 6: lite-gate スキル

**Files:**
- Create: `plugins/sdd-lite/skills/lite-gate/SKILL.md`

- [ ] **Step 1: SKILL.md を作成**

```markdown
---
name: lite-gate
description: Lightweight deterministic quality gate for the sdd-lite flow. Runs placeholder-scan, the project's lint/typecheck/build/test commands, and check-task-state-lite, then writes a lite quality report and moves the task to Done. Use after implement-task in the lite flow.
disable-model-invocation: true
---

# Lite Gate

sdd-lite の軽量品質ゲート。実装者の自己申告でなく、ゲート自身が検証コマンドを再実行して結果を記録する（自己採点防止の核を低コストで維持）。evidence-bundle / contract.json / cross-model / 署名は扱わない。

## Invocation

Codex:

\`\`\`txt
Use the lite-gate skill for specs/<feature>/tasks.md#T-001
\`\`\`

Claude Code:

\`\`\`txt
/sdd-lite:lite-gate specs/<feature>/tasks.md#T-001
\`\`\`

## Preconditions

- 対象タスクが `Status: Implementation Complete` かつ `Approval: Approved`。
- `reports/implementation/<task-id>.md` が存在する。
- 望ましくは別コンテキスト/別セッション（または委譲）で実行し、実装者の主張を独立に再検証する。

## Process

1. 変更範囲に対し `plugins/sdd-quality-loop/scripts/check-placeholders.sh`（または `.ps1`）を実行。
2. プロジェクトの lint / typecheck / build / test コマンドを**自分で実行**し、出力を捕捉する（コマンドはプロジェクトの AGENTS.md / 設定から判定）。コマンドが無い種別は「N/A」と記録し理由を添える。
3. `plugins/sdd-lite/scripts/check-task-state-lite.sh`（または `.ps1`）を実行し状態機械を検証。
4. `reports/quality-gate/<task-id>.md` を `templates/quality-report-lite.md` から生成する。先頭に `Task ID: <task-id>` と `VERDICT: PASS|FAIL` を必ず置く（`check-task-state-lite` の Done 判定が依存）。各チェックの PASS/FAIL と根拠を列挙。
5. すべて PASS のときのみ `tasks.md` の対象タスクを `Status: Done` にする。1つでも FAIL なら `VERDICT: FAIL` を記録し Done にしない（実装者に差し戻す）。

## Boundaries

- evidence-bundle / contract.json / cross-model-verify / 二者承認 / リスク階層強制は行わない（昇格時は full quality-gate に切替）。
- `Approval` を変更しない（人間のみ）。
- Done は本スキルのみが設定する（implement-task は設定しない）。

## Handoff

VERDICT と各チェック結果、Done 化の有無を報告する。FAIL 時は不足点を明示し implement-task への差し戻しを案内する。
```

- [ ] **Step 2: フロントマター妥当性確認**

Run:
```bash
head -5 plugins/sdd-lite/skills/lite-gate/SKILL.md
```
Expected: 正しい YAML フロントマター。

- [ ] **Step 3: Commit**

```bash
git add plugins/sdd-lite/skills/lite-gate/SKILL.md
git commit -m "feat(sdd-lite): add lite-gate skill"
```

---

## Task 7: lite-flow-policy リファレンス

**Files:**
- Create: `plugins/sdd-lite/references/lite-flow-policy.md`

- [ ] **Step 1: policy を作成**

```markdown
# Lite Flow Policy

sdd-lite は社内・部署内アプリ向けの「中量」トラック。完全版 SDD の部分集合であり、加算的に昇格できる。

## 維持するもの（核）
- 単一の人間承認（AI は `tasks.md` の `Approval: Approved` を増やせない。既存 hook-guard が保護）。
- kill-switch（`AGENT_STOP`）常時有効。
- 独立した軽量ゲート（lite-gate が検証コマンドを自分で再実行）。

## 省くもの
- traceability.md、ADR 必須化、受入テストの厳密記述。
- evidence.json バンドル（SHA256/git_commit/署名/provenance）。
- contract.json（lite 品質レポートで代替）。
- cross-model 検証、critical 階層、二者承認、WFI/retrospective、品質ゲート多重サイクル、リスク階層強制。

## 状態モデル
- `Approval: Draft|Approved`、`Status: Planned|In Progress|Implementation Complete|Blocked|Done`。
- 遷移検証は `check-task-state-lite`（Done は impl報告 + 品質レポート VERDICT:PASS を要求、evidence.json は不要）。

## 昇格（full SDD へ）
| 追加 | 有効化 |
|---|---|
| `Risk:` + `Risk Rationale:` | 階層強制（check-risk / check-contract Pass4） |
| 本体 `check-task-state` を使用 | evidence-bundle 必須・Done の機械的証明 |
| `cross_model: required` | クロスモデル検証 |
| critical タスク | 二者承認 + 署名 + provenance |
| `traceability.md` | REQ→AC→TEST→証跡チェーン |

成果物の場所・命名は full SDD と同一（`specs/<feature>/`, `reports/`）。sdd-lite を外して sdd-bootstrap / quality-loop の本フローへ連続的に移行できる。
```

- [ ] **Step 2: Commit**

```bash
git add plugins/sdd-lite/references/lite-flow-policy.md
git commit -m "docs(sdd-lite): add lite-flow policy and graduation guide"
```

---

## Task 8: マーケットプレイス登録

**Files:**
- Modify: `.claude-plugin/marketplace.json`
- Modify: `.agents/plugins/marketplace.json`

- [ ] **Step 1: Claude マーケットプレイスに追記**

`.claude-plugin/marketplace.json` の `plugins` 配列の末尾（`sdd-quality-loop` エントリの後）に追加:
```json
    ,{
      "name": "sdd-lite",
      "source": "./plugins/sdd-lite",
      "description": "Lightweight medium-weight SDD track for internal/departmental apps.",
      "version": "0.11.0",
      "author": {
        "name": "Harada"
      }
    }
```
（直前エントリの閉じ `}` の後にカンマを置き、整形を既存に合わせること。最終的に配列要素は4つ。）

- [ ] **Step 2: agents マーケットプレイスに追記**

`.agents/plugins/marketplace.json` の `plugins` 配列末尾に追加:
```json
    ,{
      "name": "sdd-lite",
      "source": {
        "source": "local",
        "path": "./plugins/sdd-lite"
      },
      "policy": {
        "installation": "AVAILABLE",
        "authentication": "ON_INSTALL"
      },
      "category": "Developer Tools"
    }
```

- [ ] **Step 3: JSON 妥当性確認**

Run:
```bash
python3 -c "import json; d=json.load(open('.claude-plugin/marketplace.json')); assert [p['name'] for p in d['plugins']].count('sdd-lite')==1; print('claude OK', len(d['plugins']))"
python3 -c "import json; d=json.load(open('.agents/plugins/marketplace.json')); assert [p['name'] for p in d['plugins']].count('sdd-lite')==1; print('agents OK', len(d['plugins']))"
```
Expected: `claude OK 4` と `agents OK 4`。

- [ ] **Step 4: Commit**

```bash
git add .claude-plugin/marketplace.json .agents/plugins/marketplace.json
git commit -m "feat(sdd-lite): register sdd-lite in both marketplaces"
```

---

## Task 9: インストールスクリプト更新

**Files:**
- Modify: `install.sh`（13, 18, 32行付近 + 279-284 のリスト）
- Modify: `install.ps1`（8-9 + 188-193 のリスト）

- [ ] **Step 1: install.sh のプラグイン集合に追加**

- 13行 `PLUGINS="sdd-bootstrap,sdd-implementation,sdd-quality-loop"` → 末尾に `,sdd-lite` を追加。
- 18行 `VALID_PLUGINS="sdd-bootstrap sdd-implementation sdd-quality-loop"` → 末尾に ` sdd-lite` を追加。
- 32行 usage の `Names from: ...` 文言に `,sdd-lite` を追加。
- 279-284 の plugin.json リスト（codex/copilot 検証用）に次の2行を追加:
  ```
      "plugins/sdd-lite/.codex-plugin/plugin.json"
      "plugins/sdd-lite/.plugin/plugin.json"
  ```
  （配列要素の区切りを既存に合わせる）

- [ ] **Step 2: install.ps1 のプラグイン集合に追加**

- 8行 `[ValidateSet("sdd-bootstrap", "sdd-implementation", "sdd-quality-loop")]` に `, "sdd-lite"` を追加。
- 9行 既定値 `@("sdd-bootstrap", "sdd-implementation", "sdd-quality-loop")` に `, "sdd-lite"` を追加。
- 188-193 の plugin.json リストに次の2行を追加:
  ```
          "plugins/sdd-lite/.codex-plugin/plugin.json",
          "plugins/sdd-lite/.plugin/plugin.json",
  ```

- [ ] **Step 3: 構文確認**

Run:
```bash
sh -n install.sh && echo "install.sh syntax OK"
pwsh -NoProfile -Command "[void][System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path ./install.ps1), [ref]\$null, [ref]\$null); Write-Output 'install.ps1 syntax OK'"
```
Expected: 両方 `... syntax OK`。

- [ ] **Step 4: インストールテスト**

Run:
```bash
bash tests/install.tests.sh 2>&1 | tail -20
```
Expected: 既存テストが緑（sdd-lite を含む4プラグインが検証対象になる）。失敗時は install.tests.sh が4プラグイン前提に更新が要るか確認し、必要なら同テストに sdd-lite 期待を追記。

- [ ] **Step 5: Commit**

```bash
git add install.sh install.ps1 tests/install.tests.sh
git commit -m "feat(sdd-lite): install sdd-lite by default (companion bundle)"
```

---

## Task 10: ドキュメント更新

**Files:**
- Modify: `README.md`（フロー図・ドキュメントマップ）
- Modify: `docs/workflow-guide.md`（lite トラック節を追加）
- Modify: `docs/skill-reference.md`（lite-spec / lite-gate / check-task-state-lite を追記）
- Modify: `CHANGELOG.md`

- [ ] **Step 1: README にlite トラックを追記**

README 冒頭のフロー図ブロックの下に、軽量トラックの短い節を追加する（既存 `[Stage 0]...` ブロックの様式に合わせる）:
```text
[lite] sdd-lite      社内・部署内アプリ向けの中量トラック
                     lite-spec(要件/設計/タスク) → 単一承認 → implement-task → lite-gate → Done
                     traceability/ADR/evidence-bundle/cross-model/critical を省略。
                     昇格は加算的（Risk追加→階層、本体ゲート→bundle、cross_model→検証）。
```
さらに「特徴」リストに1項目（軽量トラック sdd-lite）を追加し、ドキュメントマップ表に `specs/sdd-lite/design.md`（設計）と `plugins/sdd-lite/references/lite-flow-policy.md`（規約・昇格）を追記。

- [ ] **Step 2: docs/workflow-guide.md に lite 節を追加**

新節「## 軽量トラック（sdd-lite）」を追加し、(a) 4ステップフロー、(b) full SDD との差分表（省くもの/維持するもの）、(c) 昇格手順（lite-flow-policy を参照）を記載。本文の事実は design.md §4・§6 と一致させること。

- [ ] **Step 3: docs/skill-reference.md に追記**

スキル一覧に `lite-spec`・`lite-gate` を、スクリプト一覧に `check-task-state-lite.sh/.ps1`（Done を evidence-bundle 非依存にする lite 状態ゲート）を、既存表の様式で追加。

- [ ] **Step 4: CHANGELOG.md に追記**

最新版見出し（`0.11.0` を新設）に「Added: sdd-lite プラグイン（軽量・中量トラック）」「Changed: install/marketplace が4プラグイン構成に」を追記。日付は 2026-06-15。

- [ ] **Step 5: 参照整合性チェック**

Run:
```bash
grep -rn "sdd-lite" README.md docs/workflow-guide.md docs/skill-reference.md CHANGELOG.md | head
```
Expected: 4ファイルすべてに sdd-lite への言及がある。

- [ ] **Step 6: Commit**

```bash
git add README.md docs/workflow-guide.md docs/skill-reference.md CHANGELOG.md
git commit -m "docs(sdd-lite): document the lite track across README, workflow guide, skill reference, changelog"
```

---

## Task 11: E2E スモーク + 最終検証

**Files:**
- Test: `tests/gates.tests.sh`（lite E2E スモークを追記）
- 参照: 既存テスト群

- [ ] **Step 1: lite E2E スモークを追加**

`tests/gates.tests.sh` に、最小フィクスチャで「Draft→Approved→Implementation Complete→（impl報告 + VERDICT:PASS報告）→ check-task-state-lite が Done を許可」を通すケースと、「VERDICT:FAIL なら Done を拒否」する負ケースを追記（既存ヘルパ流儀に従う）。

- [ ] **Step 2: 全 sh テスト実行**

Run:
```bash
bash tests/gates.tests.sh && bash tests/guards.tests.sh && bash tests/install.tests.sh && bash tests/crlf-parity.tests.sh
```
Expected: すべて緑。特に guards.tests.sh で lite の tasks.md に対しても承認ガードが効くこと（必要なら guards.tests.sh に lite パスのケースを追加）。

- [ ] **Step 3: 全 ps1 テスト実行**

Run:
```bash
pwsh ./tests/validate-repository.ps1 && pwsh ./tests/scripts.tests.ps1 && pwsh ./tests/scenario.tests.ps1
```
Expected: すべて緑。

- [ ] **Step 4: 最終 Commit**

```bash
git add tests/gates.tests.sh tests/guards.tests.sh
git commit -m "test(sdd-lite): add lite E2E smoke and guard-coverage cases"
```

- [ ] **Step 5: ブランチ確認**

Run:
```bash
git log --oneline main..HEAD
```
Expected: Task 1–11 のコミットが並ぶ。PR は人間の指示があってから作成する。

---

## Self-Review（計画作成者によるチェック結果）

- **Spec coverage**: design §2 の D1–D6、§4（フロー/fork/レイアウト/再利用/marketplace/install）、§5（ガード）、§8（クロスプラットフォーム）、§9（テスト）を Task 1–11 が網羅。§6 昇格は Task 7（policy）+ Task 10（docs）で文書化。
- **Placeholder scan**: コード生成タスク（2,3,5,6）は完全な内容を提示。テンプレ/docs は様式と必須行（`Approval:`/`Status:`/`Task ID:`/`VERDICT:`）を厳密指定。残る `<...>` はテンプレート内のユーザー記入欄であり計画の穴ではない。
- **Type/契約整合**: `check-task-state-lite` が依存する行（`Approval: Approved` / `Status: Done` / `Task ID:` / `^VERDICT: PASS$`）を、テンプレ（Task 4）・スキル（Task 5,6）・スクリプト（Task 2,3）・テスト（Task 2,3,11）で一貫させた。引数順 `<tasks> <qg-dir> <impl-dir> <root>` を sh/ps1/テストで統一。

## 注意（実装委譲時）
- 各タスクは Haiku/Sonnet サブエージェントに委譲可能な粒度。fork スクリプト（Task 2/3）は correctness 重要のため、メインがレビューすること。
- 既存ファイル無改変の原則を厳守（流用対象に手を入れない）。
- バージョンは `0.11.0` で統一（plugin.json×3・marketplace×2・CHANGELOG）。
