# Unified Design System P1' (Bootstrap Generation Integration) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the P0' design-system contract into the bootstrap generation phase: ds_profile selection in the interviewer, design-sync-loop v2 (design-system/ ensure step with ui-ux-pro-max seeding and D6 fallback, token-driven mockups), a brownfield design inventory in investigate-codebase, and the Design System Compliance section in the design templates.

**Architecture:** P1' of `docs/superpowers/specs/2026-07-03-unified-design-system-design.md`. All changes are markdown skill/template edits — no new skills (visibility contract stays at 21 skills / 5 public), no scripts. Each task appends assertions to the existing paired test `tests/design-system-contract.tests.(sh|ps1)` (currently DS-001..DS-005 green) and must keep `tests/bootstrap-interview-guidance.tests.sh` green (TEST-018 string preserved).

**Tech Stack:** Markdown skill definitions, POSIX sh + Windows PowerShell 5.1 tests.

**Branch:** feature/unified-design-system

## Global Constraints

- No new skill directories; only existing SKILL.md files listed per task may change. The 5 public skills and `user-invocable: false` frontmatter of internal skills are untouched.
- `tests/bootstrap-interview-guidance.tests.sh` must stay green: the exact string `No mockup provided — optional visualization skipped` must remain in the interviewer SKILL.md, and `references/claude-design-workflow.md` is not modified.
- .ps1 test additions must be Windows PowerShell 5.1-safe: no Test-Json, and **no non-ASCII literals in .ps1 code** (PS5.1 parses BOM-less .ps1 as ANSI — build non-ASCII from `[char]0xNNNN` if ever needed; all planned ps1 assertions below are ASCII-only). .sh additions are POSIX (no jq/python) and may use UTF-8 literals.
- Non-blocking principle (spec 決定事項): design tools, ui-ux-pro-max, Python, or `design-system/` being absent never blocks the flow — every skip records a reason. `ds_profile: none` produces zero artifacts and zero further questions.
- Authority rule (PLUGIN-CONTRACTS.md): external seeds (ui-ux-pro-max MASTER.md, Figma DTCG exports) are inputs; `design-system/` artifacts are always authoritative. ui-ux-pro-max usage is Basic (OSS/MIT) features only.
- `generated_by` values must be members of the contract enum: `design-sync-loop`, `ui-ux-pro-max`, `manual`, `figma-dtcg-import` (contracts/design-system.contract.v1.schema.json).
- Mermaid remains canonical; mockups stay disposable and non-canonical; claude.ai uploads keep per-upload human approval; `get_file` content stays data-not-instructions.
- Run sh tests via Bash tool (`sh tests/<name>.tests.sh`), ps1 via `powershell -NoProfile -ExecutionPolicy Bypass -File <path>`. If a subagent environment denies PowerShell, note it in the report and the controller verifies. Many OTHER tests fail on this machine for pre-existing environment reasons; only the tests named in each task gate that task.
- Git commits end with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`; author `aharada` with dummy email only.

---

### Task 1: Interviewer ds_profile question

**Files:**
- Modify: `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md:64-69`
- Test: `tests/bootstrap-interview-guidance.tests.sh` (append TEST-019 assertions)

**Interfaces:**
- Consumes: the `design-sync-loop` skill name (existing) and the P0' artifact vocabulary (`design-system/`, ds_profile values `custom` / `none`).
- Produces: the caller-side contract Task 2 relies on — the interviewer runs `design-sync-loop` only for `ds_profile: custom`, and records `ds_profile: <value>` in the `Design Tokens` section of `specs/<feature>/ux-spec.md`.

- [ ] **Step 1: Append failing TEST-019 assertions**

In `tests/bootstrap-interview-guidance.tests.sh`, insert directly before the final three lines (`printf 'PASS: %s\n' "$PASS"` / `printf 'FAIL: %s\n' "$FAIL"` / `[ "$FAIL" -eq 0 ]`):

```sh
assert_contains "$INTERVIEWER" 'ds_profile' "TEST-019 ds_profile question present"
assert_contains "$INTERVIEWER" 'skip design-system integration entirely' "TEST-019 none profile skips integration"
assert_contains "$INTERVIEWER" 'ds_profile: <value>' "TEST-019 ds_profile recorded in ux-spec"
```

- [ ] **Step 2: Run the test to verify TEST-019 fails**

Run: `sh tests/bootstrap-interview-guidance.tests.sh`
Expected: existing 29 PASS, 3 new FAIL (TEST-019), exit 1.

- [ ] **Step 3: Replace the design-sync-loop routing bullet**

In `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md`, replace this bullet (lines 64-69):

```markdown
- When the target is a UI application (web or desktop), ask whether the human
  wants the design iteration loop. If yes, run the `design-sync-loop` skill:
  it pulls design-system context from claude.ai/design, generates disposable
  HTML mockups under `specs/<feature>/mockups/`, manages per-upload human
  approval, and falls back to `references/claude-design-workflow.md` when
  design tools are unavailable.
```

with:

```markdown
- When the target is a UI application (web or desktop), ask for the design
  system profile (`ds_profile`): `custom` (project-level `design-system/`
  contract plus the design iteration loop) or `none` (no design-system
  integration). Record the choice as `ds_profile: <value>` in the
  `Design Tokens` section of `ux-spec.md`. On `custom`, run the
  `design-sync-loop` skill: it ensures `design-system/` exists (seeding it
  when absent), pulls design-system context from claude.ai/design, generates
  token-driven disposable HTML mockups under `specs/<feature>/mockups/`,
  manages per-upload human approval, and falls back to
  `references/claude-design-workflow.md` when design tools are unavailable.
  On `none`, skip design-system integration entirely — no artifacts and no
  further design-system questions.
```

(The following `- Otherwise ask whether the human has a local mockup...` bullet with the TEST-018 string stays unchanged.)

- [ ] **Step 4: Run the test to verify it passes**

Run: `sh tests/bootstrap-interview-guidance.tests.sh`
Expected: `FAIL: 0` (32 PASS), exit 0.

- [ ] **Step 5: Commit**

```bash
git add plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md tests/bootstrap-interview-guidance.tests.sh
git commit -m "feat(bootstrap): add ds_profile selection to interviewer UI-application step

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: design-sync-loop v2 — ensure design-system/ (seed flow) and token-driven mockups

**Files:**
- Modify: `plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md` (description, new section, Loop step 2, Boundaries)
- Test: `tests/design-system-contract.tests.sh` (append DS-006), `tests/design-system-contract.tests.ps1` (append DS-006)

**Interfaces:**
- Consumes: `ds_profile: custom` caller contract from Task 1; P0' templates (`design-tokens.template.json`, `design-system.template.md`, `ui-patterns.template.md` under `../sdd-bootstrap-interviewer/templates/`); contract enum values for `generated_by`.
- Produces: the ensure-step contract P3'/P4' rely on — `design-system/` exists (or the run recorded why not) before mockups; mockups derive styles from `design-system/design-tokens.json` and `design-system/ui-patterns.md`.

- [ ] **Step 1: Append failing DS-006 assertions to the sh test**

In `tests/design-system-contract.tests.sh`, insert directly before the final three lines:

```sh
# DS-006 design-sync-loop v2 ensures design-system/ and token-driven mockups
DSL="$ROOT/plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md"
assert_contains "$DSL" '^## Ensure design-system/$' "DS-006 ensure section"
assert_contains "$DSL" 'ui-ux-pro-max' "DS-006 seed generator detection"
assert_contains "$DSL" 'design-system --persist' "DS-006 seed generation command"
assert_contains "$DSL" 'ui-ux-pro-max unavailable — D6 template interview used' "DS-006 D6 fallback note"
assert_contains "$DSL" 'figma-dtcg-import' "DS-006 figma DTCG import path"
assert_contains "$DSL" 'design-system/design-tokens\.json' "DS-006 mockups reference tokens"
assert_contains "$DSL" 'MASTER\.md' "DS-006 seed is input, artifacts authoritative"
```

- [ ] **Step 2: Append failing DS-006 assertions to the ps1 test**

In `tests/design-system-contract.tests.ps1`, insert directly before the final line (`Write-Host "ok: design-system contract tests passed"`):

```powershell
# DS-006 design-sync-loop v2 (ASCII-only assertions; the em-dash fallback note is asserted by the sh twin)
$dsl = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md")
foreach ($needle in @('## Ensure design-system/', 'ui-ux-pro-max', 'design-system --persist', 'figma-dtcg-import', 'design-system/design-tokens.json', 'MASTER.md')) {
    if ($dsl -notmatch [regex]::Escape($needle)) { throw "not ok: DS-006 missing $needle" }
}
Write-Host "ok: DS-006 design-sync-loop v2"
```

- [ ] **Step 3: Run the sh test to verify DS-006 fails**

Run: `sh tests/design-system-contract.tests.sh`
Expected: DS-001..DS-005 PASS, DS-006 FAIL (7 failures), exit 1.

- [ ] **Step 4: Update the skill — description**

In `plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md`, replace line 3 (the `description:` line) with:

```yaml
description: Specification-phase design iteration loop for UI applications (ds_profile custom). Ensures the project-level design-system/ contract exists (seeding via ui-ux-pro-max, Figma DTCG import, or the D6 template interview), pulls design-system context from a claude.ai/design project via the DesignSync tool, generates token-driven disposable HTML mockups per view and state, and pushes them for browser review with per-upload human approval. Falls back to the manual Claude Design workflow when design tools are unavailable.
```

- [ ] **Step 5: Update the skill — intro and new Ensure section**

Replace lines 10-17 (the intro paragraphs):

```markdown
Specification-phase design iteration for UI applications (web or desktop).
Invoked by `sdd-bootstrap-interviewer` (full profile) or `lite-spec` (lite
profile) when the target is a UI application and the human opts in. Mermaid
remains the canonical diagram format; every artifact this loop produces is a
disposable, non-canonical visual reference.

The layer file this loop records into is `specs/<feature>/ux-spec.md` for the
full profile and `specs/<feature>/design.md` for the lite profile ("the layer
file" below).
```

with:

```markdown
Specification-phase design iteration for UI applications (web or desktop).
Invoked by `sdd-bootstrap-interviewer` (full profile) or `lite-spec` (lite
profile) when the human selected `ds_profile: custom`. Mermaid remains the
canonical diagram format; every artifact this loop produces is a disposable,
non-canonical visual reference — except the project-level `design-system/`
contract, which is authoritative for UI decisions (see PLUGIN-CONTRACTS.md,
"sdd-bootstrap design-system artifacts → consumers").

The layer file this loop records into is `specs/<feature>/ux-spec.md` for the
full profile and `specs/<feature>/design.md` for the lite profile ("the layer
file" below).
```

Then insert a new section between `## Capability Detection` (after its item 2) and `## Loop`:

```markdown
## Ensure design-system/

Before the mockup loop, guarantee the project-level `design-system/` contract
exists at the target repository root. Skip this section entirely when it
already exists and `design-tokens.json` carries a valid meta envelope
(`schema: design-system-contract/v1`).

1. **Seed via ui-ux-pro-max (preferred when available).** Detect the
   ui-ux-pro-max skill (`.claude/skills/ui-ux-pro-max/` or a global install)
   and a working `python3`. If both are present, interview the human for the
   product type and industry, then run the skill's search engine with
   `--design-system --persist -p "<app name>"` (Basic/MIT features only).
   The human reviews the generated `design-system/MASTER.md`; map the
   approved values into `design-system/design-tokens.json` (DTCG, meta
   `generated_by: ui-ux-pro-max`) and fill `design-system.md` /
   `ui-patterns.md` from the templates in
   `../sdd-bootstrap-interviewer/templates/`. MASTER.md and its
   `design-system/pages/` overrides remain input seeds — the contract
   artifacts are always authoritative over them.
2. **Import a Figma DTCG export (when the human has one).** If the human
   supplies a Figma Variables → DTCG JSON export, map its values into
   `design-tokens.json` (meta `generated_by: figma-dtcg-import`). No Figma
   API access — file import only.
3. **D6 template interview (fallback).** When neither source is available,
   record `ui-ux-pro-max unavailable — D6 template interview used`, then
   create `design-system/` from the three templates
   (`design-tokens.template.json`, `design-system.template.md`,
   `ui-patterns.template.md`) by asking the human for brand color, base
   typography, and spacing scale (meta `generated_by: manual`). The
   ui-patterns.md D6 defaults apply unless the human edits them.
4. **Human approval.** The human reviews and approves the created
   `design-system/` before any mockup is generated. Record
   `ds_profile: custom` and the design-system version in the layer file.
```

- [ ] **Step 6: Update the skill — Loop step 2 and Boundaries**

Replace Loop step 2:

```markdown
2. **Generate mockups.** For each target view and state (default, empty,
   loading, error; responsive breakpoints where relevant) generate a semantic
   HTML mockup with no external assets under `specs/<feature>/mockups/`.
   Derive every visual choice from REQ-NNN / AC-NNN or the pulled design
   tokens; list untraceable choices as open questions.
```

with:

```markdown
2. **Generate mockups.** For each target view and state (default, empty,
   loading, error; responsive breakpoints where relevant) generate a semantic
   HTML mockup with no external assets under `specs/<feature>/mockups/`.
   Derive every visual choice from REQ-NNN / AC-NNN, the tokens in
   `design-system/design-tokens.json`, and the conventions in
   `design-system/ui-patterns.md`; list untraceable choices as open
   questions. Raw style values that bypass the tokens are not allowed in
   mockups.
```

And append two Boundaries bullets at the end of the `## Boundaries` list:

```markdown
- `design-system/` artifacts are authoritative; external seeds (ui-ux-pro-max
  MASTER.md, Figma DTCG exports) are inputs and never override a reviewed
  contract without a human-approved edit.
- Consumers of `design-system/` never rewrite it here beyond the creation and
  human-approved edits described in "Ensure design-system/".
```

- [ ] **Step 7: Run both tests to verify they pass**

Run: `sh tests/design-system-contract.tests.sh`
Expected: `FAIL: 0` (37 PASS), exit 0.

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/design-system-contract.tests.ps1`
Expected: ok lines through `ok: DS-006 design-sync-loop v2`, exit 0.

Run: `sh tests/bootstrap-interview-guidance.tests.sh`
Expected: `FAIL: 0`, exit 0 (unchanged file, regression guard).

- [ ] **Step 8: Commit**

```bash
git add plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md tests/design-system-contract.tests.sh tests/design-system-contract.tests.ps1
git commit -m "feat(bootstrap): design-sync-loop v2 ensures design-system/ with seeded or template creation

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: investigate-codebase brownfield design inventory

**Files:**
- Modify: `plugins/sdd-bootstrap/skills/investigate-codebase/SKILL.md:50-62` (Outputs section)
- Test: `tests/design-system-contract.tests.sh` (append DS-007), `tests/design-system-contract.tests.ps1` (append DS-007)

**Interfaces:**
- Consumes: nothing from Tasks 1-2.
- Produces: the `Design Inventory` finding group name in `investigation.md` that design-sync-loop's D6 interview and P4' documentation may cite as brownfield input.

- [ ] **Step 1: Append failing DS-007 assertions**

In `tests/design-system-contract.tests.sh`, insert directly before the final three lines:

```sh
# DS-007 investigate-codebase brownfield design inventory
INV="$ROOT/plugins/sdd-bootstrap/skills/investigate-codebase/SKILL.md"
assert_contains "$INV" 'Design Inventory' "DS-007 design inventory group"
assert_contains "$INV" '#hex / rgb\(\) / hsl\(\)' "DS-007 hardcoded color patterns"
```

In `tests/design-system-contract.tests.ps1`, insert directly before the final line:

```powershell
# DS-007 investigate-codebase design inventory
$inv = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-bootstrap/skills/investigate-codebase/SKILL.md")
if ($inv -notmatch 'Design Inventory') { throw "not ok: DS-007 Design Inventory missing" }
Write-Host "ok: DS-007 investigate-codebase design inventory"
```

- [ ] **Step 2: Run the sh test to verify DS-007 fails**

Run: `sh tests/design-system-contract.tests.sh`
Expected: DS-007 FAIL (2 failures), exit 1.

- [ ] **Step 3: Add the inventory bullet to Outputs**

In `plugins/sdd-bootstrap/skills/investigate-codebase/SKILL.md`, the Outputs section currently ends with:

```markdown
For `bugfix` and `refactor` modes also produce:

- `specs/<feature>/baseline-behavior.md` — populated from
  `templates/baseline-behavior.template.md`. Each observable behavior carries a
  `BL-NNN` ID.
```

Append directly after that block (still inside `## Outputs`, before `## Platform Notes`):

```markdown
When the investigated codebase contains UI code, additionally record a
`Design Inventory` finding group in `investigation.md`: occurrence locations
(`file:line`) and counts of hardcoded color codes (#hex / rgb() / hsl()),
font specifications, and magic spacing values. Each entry carries an INV-NNN
ID like any other finding. This inventory is the brownfield input for
initializing `design-system/design-tokens.json` and `design-system.md`; the
investigation itself stays read-only and creates no design-system files.
```

- [ ] **Step 4: Run both tests to verify they pass**

Run: `sh tests/design-system-contract.tests.sh`
Expected: `FAIL: 0` (39 PASS), exit 0.

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/design-system-contract.tests.ps1`
Expected: ok lines through `ok: DS-007 investigate-codebase design inventory`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add plugins/sdd-bootstrap/skills/investigate-codebase/SKILL.md tests/design-system-contract.tests.sh tests/design-system-contract.tests.ps1
git commit -m "feat(bootstrap): record brownfield design inventory in investigate-codebase outputs

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Design System Compliance section (full) + lite one-line declaration

**Files:**
- Modify: `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/design.template.md:29-32`
- Modify: `plugins/sdd-lite/templates/design-lite.md:3-4`
- Test: `tests/design-system-contract.tests.sh` (append DS-008/DS-009), `tests/design-system-contract.tests.ps1` (append DS-008/DS-009)

**Interfaces:**
- Consumes: ds_profile vocabulary from Task 1.
- Produces: the `## Design System Compliance` heading in design.template.md that P2' reviewers and P4' check-design-system will match verbatim; the lite declaration line in design-lite.md.

- [ ] **Step 1: Append failing DS-008/DS-009 assertions**

In `tests/design-system-contract.tests.sh`, insert directly before the final three lines:

```sh
# DS-008 design.template.md compliance section / DS-009 lite declaration
DT="$ROOT/plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/design.template.md"
assert_contains "$DT" '^## Design System Compliance$' "DS-008 compliance section"
assert_contains "$DT" 'ds_profile: none' "DS-008 none profile N/A rule"
assert_contains "$DT" 'design_system_version' "DS-008 version placeholder"
DL="$ROOT/plugins/sdd-lite/templates/design-lite.md"
assert_contains "$DL" 'design-system/' "DS-009 lite token declaration"
```

In `tests/design-system-contract.tests.ps1`, insert directly before the final line:

```powershell
# DS-008 / DS-009 design templates
$dt = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/design.template.md")
if ($dt -notmatch [regex]::Escape('## Design System Compliance')) { throw "not ok: DS-008 compliance section missing" }
if ($dt -notmatch 'ds_profile: none') { throw "not ok: DS-008 none rule missing" }
$dl = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-lite/templates/design-lite.md")
if ($dl -notmatch 'design-system/') { throw "not ok: DS-009 lite declaration missing" }
Write-Host "ok: DS-008/DS-009 design templates"
```

- [ ] **Step 2: Run the sh test to verify DS-008/DS-009 fail**

Run: `sh tests/design-system-contract.tests.sh`
Expected: 4 new FAIL, exit 1.

- [ ] **Step 3: Insert the compliance section into design.template.md**

In `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/design.template.md`, after the Layer Specifications block ending:

```markdown
Use `N/A — no change: <reason>` for an unaffected layer. Security impact must
still be assessed.
```

and before `## Cross-Layer Dependencies`, insert:

```markdown
## Design System Compliance

Applies when the project has a `design-system/` directory (`ds_profile:
custom`); otherwise record exactly `N/A — ds_profile: none`.

- Design-System-Version: {{design_system_version}} (design-tokens.json meta.version)
- Tokens Used: {{tokens_used}}
- New Components: {{new_components_with_reasons}} (reuse existing components
  first; record the reason for every new component)
```

- [ ] **Step 4: Add the lite declaration line**

In `plugins/sdd-lite/templates/design-lite.md`, replace:

```markdown
## 方針
<2–4文。既存パターンへの追従点>
```

with:

```markdown
## 方針
<2–4文。既存パターンへの追従点>
- デザイン: `design-system/` がある場合はそのトークン・既存コンポーネントを使用（生値・独自スタイルは避ける）。無い場合はこの行を削除。
```

- [ ] **Step 5: Run all gating tests to verify green**

Run: `sh tests/design-system-contract.tests.sh`
Expected: `FAIL: 0` (43 PASS), exit 0.

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/design-system-contract.tests.ps1`
Expected: all ok lines through `ok: DS-008/DS-009 design templates`, exit 0.

Run: `sh tests/bootstrap-layer-templates.tests.sh`
Expected: `FAIL: 0`, exit 0 (template additions are safe; it asserts named sections only).

Run: `sh tests/bootstrap-interview-guidance.tests.sh`
Expected: `FAIL: 0`, exit 0.

- [ ] **Step 6: Commit**

```bash
git add plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/design.template.md plugins/sdd-lite/templates/design-lite.md tests/design-system-contract.tests.sh tests/design-system-contract.tests.ps1
git commit -m "feat(bootstrap): add Design System Compliance section and lite token declaration

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```
