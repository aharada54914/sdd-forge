# Unified Design System P0' (Contracts & Templates) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the design-system contract layer: a JSON-schema contract for design-tokens.json, three project-level templates (design-tokens / design-system / ui-patterns with D6 defaults), and the producer/consumer contract section in PLUGIN-CONTRACTS.md.

**Architecture:** P0' of `docs/superpowers/specs/2026-07-03-unified-design-system-design.md`. Pure artifacts — no skill changes, no scripts. The contract schema follows the existing `contracts/review-contract.v1.schema.json` conventions (draft 2020-12, `$id` under sdd-forge.dev, strict meta envelope); templates follow the interviewer templates' naming (`<name>.template.<ext>`) and placeholder (`<angle-bracket>`) conventions. A new paired test (`tests/design-system-contract.tests.sh` / `.ps1`) asserts the artifacts' invariants.

**Tech Stack:** JSON Schema draft 2020-12, Markdown templates, POSIX sh (bash 3.2 compatible) + Windows PowerShell 5.1 tests.

**Branch:** feature/unified-design-system

## Global Constraints

- P0' changes NO skill files — the skill visibility contract (21 skills, 5 public) must be untouched; do not edit any SKILL.md.
- New test `.ps1` must run on Windows PowerShell 5.1: no `Test-Json`, no PS7-only syntax. JSON parsing via `ConvertFrom-Json` only.
- New test `.sh` must be bash-3.2/POSIX-sh compatible: no jq, no python, grep/sed only.
- Template naming: `<name>.template.<ext>` in `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/`.
- Schema conventions copied from `contracts/review-contract.v1.schema.json`: `"$schema": "https://json-schema.org/draft/2020-12/schema"`, `"$id": "https://sdd-forge.dev/contracts/design-system.contract.v1.schema.json"`, strict (`additionalProperties: false`) meta envelope.
- The design-tokens template must be a valid JSON instance of the contract (defaults, not `{{placeholders}}` — JSON must parse).
- Absence contract (from spec): when `design-system/` does not exist in a target app, consumers skip with a recorded reason; nothing in P0' may imply blocking behavior.
- Run sh tests with the Bash tool (`sh tests/<name>.tests.sh`), PowerShell with `powershell -NoProfile -ExecutionPolicy Bypass -File <path>`. KNOWN: many existing tests fail on this machine for pre-existing environment reasons; only the tests named in each task gate that task.
- Git commits end with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`; author is `aharada` with dummy email only.
- Spec deviation (documented): the spec's P0' acceptance line "constant-parity.tests.sh が新契約定数を検知" does not apply — that test checks hardcoded constants in check-contract.py/.ps1 only and has no contract-file registry. Testability is provided by the new paired test `tests/design-system-contract.tests.(sh|ps1)` instead.

---

### Task 1: Contract schema + design-tokens template + paired tests

**Files:**
- Create: `contracts/design-system.contract.v1.schema.json`
- Create: `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/design-tokens.template.json`
- Test (create): `tests/design-system-contract.tests.sh`
- Test (create): `tests/design-system-contract.tests.ps1`

**Interfaces:**
- Consumes: nothing.
- Produces: the contract id string `design-system-contract/v1`; the meta envelope shape `{schema, version, generated_by, profile}` with `generated_by ∈ {design-sync-loop, ui-ux-pro-max, manual, figma-dtcg-import}` and `profile ∈ {custom}`; mandatory token groups `color`, `typography`, `spacing`. Tasks 2-3 append assertions to the two test files created here (test IDs DS-001..DS-002 used here; DS-003..DS-005 reserved).

- [ ] **Step 1: Write the failing sh test**

Create `tests/design-system-contract.tests.sh` with exactly:

```sh
#!/bin/sh
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCHEMA="$ROOT/contracts/design-system.contract.v1.schema.json"
TOKENS="$ROOT/plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/design-tokens.template.json"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }

assert_contains() {
  file=$1
  pattern=$2
  label=$3
  if [ -f "$file" ] && grep -Eq "$pattern" "$file"; then pass "$label"; else fail "$label"; fi
}

# DS-001 contract schema envelope
assert_contains "$SCHEMA" 'https://json-schema\.org/draft/2020-12/schema' "DS-001 schema draft 2020-12"
assert_contains "$SCHEMA" 'https://sdd-forge\.dev/contracts/design-system\.contract\.v1\.schema\.json' "DS-001 schema \$id"
assert_contains "$SCHEMA" '"design-system-contract/v1"' "DS-001 schema const id"
assert_contains "$SCHEMA" '"generated_by"' "DS-001 generated_by in contract"
assert_contains "$SCHEMA" '"additionalProperties": false' "DS-001 strict meta envelope"

# DS-002 tokens template is a conforming instance
assert_contains "$TOKENS" '"schema": "design-system-contract/v1"' "DS-002 template meta.schema"
assert_contains "$TOKENS" '"version": "[0-9]+\.[0-9]+\.[0-9]+"' "DS-002 template meta.version semver"
assert_contains "$TOKENS" '"generated_by": "manual"' "DS-002 template meta.generated_by"
assert_contains "$TOKENS" '"profile": "custom"' "DS-002 template meta.profile"
for group in color typography spacing; do
  assert_contains "$TOKENS" "\"$group\"" "DS-002 token group $group"
done
assert_contains "$TOKENS" '"\$type"' "DS-002 DTCG \$type present"
assert_contains "$TOKENS" '"\$value"' "DS-002 DTCG \$value present"

printf 'PASS: %s\n' "$PASS"
printf 'FAIL: %s\n' "$FAIL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Write the failing ps1 test**

Create `tests/design-system-contract.tests.ps1` with exactly:

```powershell
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$schemaPath = Join-Path $repositoryRoot "contracts/design-system.contract.v1.schema.json"
$tokensPath = Join-Path $repositoryRoot "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/design-tokens.template.json"

# DS-001 both JSON files must parse (PS5.1-safe: ConvertFrom-Json, no Test-Json)
$schema = Get-Content -Raw -Encoding Utf8 $schemaPath | ConvertFrom-Json
$tokens = Get-Content -Raw -Encoding Utf8 $tokensPath | ConvertFrom-Json

if ($schema.'$id' -ne 'https://sdd-forge.dev/contracts/design-system.contract.v1.schema.json') {
    throw "not ok: DS-001 schema `$id mismatch"
}
if ($schema.properties.meta.properties.schema.const -ne 'design-system-contract/v1') {
    throw "not ok: DS-001 schema const mismatch"
}
Write-Host "ok: DS-001 contract schema envelope"

# DS-002 tokens template conforms to the meta contract (domain assertions replicate the schema)
if ($tokens.meta.schema -ne 'design-system-contract/v1') { throw "not ok: DS-002 meta.schema" }
if ($tokens.meta.version -notmatch '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$') { throw "not ok: DS-002 meta.version semver" }
if (@('design-sync-loop','ui-ux-pro-max','manual','figma-dtcg-import') -notcontains $tokens.meta.generated_by) { throw "not ok: DS-002 meta.generated_by enum" }
if ($tokens.meta.profile -ne 'custom') { throw "not ok: DS-002 meta.profile" }
foreach ($group in @('color','typography','spacing')) {
    if ($null -eq $tokens.$group) { throw "not ok: DS-002 token group $group missing" }
}
if ($tokens.color.primary.'$value' -notmatch '^#[0-9a-fA-F]{6}$') { throw "not ok: DS-002 color.primary DTCG value" }
Write-Host "ok: DS-002 tokens template conforms"

Write-Host "ok: design-system contract tests passed"
```

- [ ] **Step 3: Run both tests to verify they fail**

Run: `sh tests/design-system-contract.tests.sh`
Expected: multiple `FAIL:` lines, final `FAIL: 14`, exit 1 (files missing).

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/design-system-contract.tests.ps1`
Expected: throws (schema file not found), non-zero exit.

- [ ] **Step 4: Create the contract schema**

Create `contracts/design-system.contract.v1.schema.json` with exactly:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://sdd-forge.dev/contracts/design-system.contract.v1.schema.json",
  "title": "Design system contract v1",
  "description": "Meta contract for a target application's design-system/design-tokens.json. The meta envelope is strict; token groups follow the W3C DTCG format ($type/$value) and additional groups are allowed. Deep DTCG validation is the job of check-design-system, not this schema.",
  "type": "object",
  "required": ["meta", "color", "typography", "spacing"],
  "properties": {
    "meta": {
      "type": "object",
      "additionalProperties": false,
      "required": ["schema", "version", "generated_by", "profile"],
      "properties": {
        "schema": { "const": "design-system-contract/v1" },
        "version": { "type": "string", "pattern": "^(0|[1-9]\\d*)\\.(0|[1-9]\\d*)\\.(0|[1-9]\\d*)$" },
        "generated_by": { "enum": ["design-sync-loop", "ui-ux-pro-max", "manual", "figma-dtcg-import"] },
        "profile": { "enum": ["custom"] }
      }
    },
    "color": { "type": "object" },
    "typography": { "type": "object" },
    "spacing": { "type": "object" }
  }
}
```

- [ ] **Step 5: Create the tokens template**

Create `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/design-tokens.template.json` with exactly:

```json
{
  "meta": {
    "schema": "design-system-contract/v1",
    "version": "0.1.0",
    "generated_by": "manual",
    "profile": "custom"
  },
  "color": {
    "$description": "Semantic color tokens. All styles reference these; raw color values are prohibited outside this file and build/ outputs.",
    "primary": { "$type": "color", "$value": "#0f62fe" },
    "text": { "$type": "color", "$value": "#161616" },
    "background": { "$type": "color", "$value": "#ffffff" },
    "border": { "$type": "color", "$value": "#8d8d8d" },
    "danger": { "$type": "color", "$value": "#da1e28" },
    "success": { "$type": "color", "$value": "#198038" }
  },
  "typography": {
    "$description": "Font family and type scale tokens.",
    "font-family-base": { "$type": "fontFamily", "$value": ["Noto Sans JP", "sans-serif"] },
    "font-size-base": { "$type": "dimension", "$value": "16px" },
    "font-size-small": { "$type": "dimension", "$value": "13px" },
    "font-size-heading": { "$type": "dimension", "$value": "24px" },
    "line-height-base": { "$type": "number", "$value": 1.5 }
  },
  "spacing": {
    "$description": "Spacing scale on a 4px base grid. Magic spacing values outside this scale are prohibited.",
    "xs": { "$type": "dimension", "$value": "4px" },
    "sm": { "$type": "dimension", "$value": "8px" },
    "md": { "$type": "dimension", "$value": "16px" },
    "lg": { "$type": "dimension", "$value": "24px" },
    "xl": { "$type": "dimension", "$value": "40px" }
  },
  "radius": {
    "$description": "Corner radius tokens.",
    "sm": { "$type": "dimension", "$value": "4px" },
    "md": { "$type": "dimension", "$value": "8px" }
  }
}
```

- [ ] **Step 6: Run both tests to verify they pass**

Run: `sh tests/design-system-contract.tests.sh`
Expected: `FAIL: 0`, exit 0.

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/design-system-contract.tests.ps1`
Expected: `ok: design-system contract tests passed`, exit 0.

- [ ] **Step 7: Commit**

```bash
git add contracts/design-system.contract.v1.schema.json plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/design-tokens.template.json tests/design-system-contract.tests.sh tests/design-system-contract.tests.ps1
git commit -m "feat(contracts): add design-system contract schema and design-tokens template

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: design-system.md and ui-patterns.md templates

**Files:**
- Create: `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/design-system.template.md`
- Create: `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/ui-patterns.template.md`
- Modify: `tests/design-system-contract.tests.sh` (append DS-003/DS-004 assertions)
- Modify: `tests/design-system-contract.tests.ps1` (append DS-003/DS-004 assertions)

**Interfaces:**
- Consumes: test files and pass/fail helpers from Task 1.
- Produces: required section headings that P4' `check-design-system` and PLUGIN-CONTRACTS.md (Task 3) will reference verbatim — design-system.md: `## Layer 1 — Tokens (machine-extracted)`, `## Layer 2 — Do / Don't (component conventions)`, `## Layer 3 — Review checklist (human-curated)`, `## Change Process`; ui-patterns.md: `## Actions`, `## Dialogs`, `## Icons`, `## Flow`, `## States`, `## Cognitive Load`.

- [ ] **Step 1: Append failing assertions to the sh test**

In `tests/design-system-contract.tests.sh`, insert directly before the final three lines (`printf 'PASS: ...` block):

```sh
# DS-003 design-system.md template required sections
DS="$ROOT/plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/design-system.template.md"
assert_contains "$DS" '^## Layer 1 — Tokens \(machine-extracted\)$' "DS-003 layer 1 section"
assert_contains "$DS" '^## Layer 2 — Do / Don'"'"'t \(component conventions\)$' "DS-003 layer 2 section"
assert_contains "$DS" '^## Layer 3 — Review checklist \(human-curated\)$' "DS-003 layer 3 section"
assert_contains "$DS" '^## Change Process$' "DS-003 change process section"
assert_contains "$DS" 'WCAG 2\.2 AA' "DS-003 WCAG 2.2 AA"

# DS-004 ui-patterns.md template required sections (D6 categories)
UIP="$ROOT/plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/ui-patterns.template.md"
for section in Actions Dialogs Icons Flow States 'Cognitive Load'; do
  assert_contains "$UIP" "^## $section$" "DS-004 ui-patterns section $section"
done
assert_contains "$UIP" 'Exactly one primary action per screen' "DS-004 single primary action rule"
assert_contains "$UIP" 'irreversible or destructive' "DS-004 dialog timing rule"
```

- [ ] **Step 2: Append failing assertions to the ps1 test**

In `tests/design-system-contract.tests.ps1`, insert directly before the final line (`Write-Host "ok: design-system contract tests passed"`):

```powershell
# DS-003 / DS-004 markdown templates
$dsPath = Join-Path $repositoryRoot "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/design-system.template.md"
$uipPath = Join-Path $repositoryRoot "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/ui-patterns.template.md"
$ds = Get-Content -Raw -Encoding Utf8 $dsPath
$uip = Get-Content -Raw -Encoding Utf8 $uipPath
foreach ($section in @('## Layer 1 — Tokens (machine-extracted)', "## Layer 2 — Do / Don't (component conventions)", '## Layer 3 — Review checklist (human-curated)', '## Change Process')) {
    if ($ds -notmatch [regex]::Escape($section)) { throw "not ok: DS-003 missing section $section" }
}
if ($ds -notmatch 'WCAG 2\.2 AA') { throw "not ok: DS-003 WCAG 2.2 AA missing" }
Write-Host "ok: DS-003 design-system template sections"
foreach ($section in @('## Actions', '## Dialogs', '## Icons', '## Flow', '## States', '## Cognitive Load')) {
    if ($uip -notmatch [regex]::Escape($section)) { throw "not ok: DS-004 missing section $section" }
}
Write-Host "ok: DS-004 ui-patterns template sections"
```

- [ ] **Step 3: Run tests to verify the new assertions fail**

Run: `sh tests/design-system-contract.tests.sh`
Expected: DS-001/DS-002 PASS, DS-003/DS-004 FAIL, exit 1.

- [ ] **Step 4: Create the design-system template**

Create `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/design-system.template.md` with exactly:

```markdown
# Design System: <project>

- Version: 0.1.0 (mirrors design-tokens.json meta.version; bump together, semver)
- Profile: custom
- Status: Draft

The single source of truth for UI decisions in this project. design-tokens.json
holds the machine-readable values; this document holds the rules and the
reasons. Written as the fastest reference for an implementer (human or AI) to
find the correct answer — not as a compliance document. Rules state the reason
and the alternative, never a bare prohibition.

## Layer 1 — Tokens (machine-extracted)

- Every style value MUST reference a design-tokens.json token. Raw color codes
  (#hex / rgb() / hsl()) and magic spacing values are prohibited outside
  design-tokens.json and generated build/ outputs.
- Token transformation for this stack (CSS variables, tokens.ts, QSS, headers,
  etc.) is generated under `design-system/build/`; the tool (Terrazzo, Style
  Dictionary, or equivalent) is the project's choice and never authoritative.
- <how tokens are consumed in this project's stack — import path, naming>

## Layer 2 — Do / Don't (component conventions)

- Reuse existing components first. Create a new component only when the
  feature's design.md Design System Compliance section records the reason.
- <component conventions for this project: naming, variants, allowed states>
- <prohibited patterns, each written as "avoid X because Y; do Z instead">

## Layer 3 — Review checklist (human-curated)

- [ ] New or changed UI references tokens only (no raw values in the diff)
- [ ] Existing components reused, or the new-component reason is recorded
- [ ] ui-patterns.md conventions applied (actions, dialogs, icons, flow, states)
- [ ] Accessibility meets WCAG 2.2 AA (touch targets >= 24x24 px, focus not
      obscured, no cognitive-load-heavy authentication)

## Change Process

- Change tokens or rules by a reviewed edit to `design-system/`; never fork
  values locally in feature code. Bump meta.version and record the reason here.
```

- [ ] **Step 5: Create the ui-patterns template**

Create `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/ui-patterns.template.md` with exactly:

```markdown
# UI Patterns: <project>

Universal, stack-independent interaction conventions. They apply to web,
desktop, and embedded UI alike, and are referenced at generation time by the
implementation policy and at verification time by the design-system checklist.
Mermaid diagrams remain canonical for flows; this document constrains layout
and interaction decisions. Defaults below may be edited per project — keep
every rule phrased with its reason.

## Actions

- Keep primary/secondary button order and position consistent on every screen,
  following the platform convention.
- Exactly one primary action per screen.
- Physically separate destructive actions from routine ones; defend them with
  color plus a confirmation step.

## Dialogs

- Use a modal dialog only to confirm an irreversible or destructive operation.
- Notifications and progress never use modals — use toast or inline display.
  Do not stack or chain dialogs.
- Dialog buttons carry text labels; icon-only buttons are prohibited inside
  dialogs.

## Icons

- Icon-only usage is limited to universally understood meanings (search,
  close); otherwise pair the icon with text.
- One icon per element. Use the same icon for the same concept on every screen.

## Flow

- Fix the position of "next/back" in wizards and screen transitions.
- Arrange content top-to-bottom / left-to-right along the user's work order
  (read → input → confirm).
- Always design the post-submit feedback and the recovery path on error.

## States

- Define empty, loading, and error states for every view.
- Show an error message near where it occurred and state the next action.

## Cognitive Load

- One purpose per screen.
- Group choices to roughly 7±2 items and provide sensible defaults.
```

- [ ] **Step 6: Run tests to verify they pass, and confirm the existing template test is unaffected**

Run: `sh tests/design-system-contract.tests.sh`
Expected: `FAIL: 0`, exit 0.

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/design-system-contract.tests.ps1`
Expected: exit 0.

Run: `sh tests/bootstrap-layer-templates.tests.sh`
Expected: `FAIL: 0`, exit 0 (asserts named templates only; additions are safe).

- [ ] **Step 7: Commit**

```bash
git add plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/design-system.template.md plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/ui-patterns.template.md tests/design-system-contract.tests.sh tests/design-system-contract.tests.ps1
git commit -m "feat(bootstrap): add design-system and ui-patterns templates with D6 defaults

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: PLUGIN-CONTRACTS.md producer/consumer section

**Files:**
- Modify: `PLUGIN-CONTRACTS.md` (insert new section after the sdd-ship section, before the `---` that precedes `## Plugin Dependency Declarations`)
- Modify: `tests/design-system-contract.tests.sh` (append DS-005 assertion)
- Modify: `tests/design-system-contract.tests.ps1` (append DS-005 assertion)

**Interfaces:**
- Consumes: the artifact names and required section headings from Tasks 1-2 (quoted verbatim in the new contract section).
- Produces: the contract section heading `## sdd-bootstrap design-system artifacts → consumers (v1.8.0+)` that later phases (P1'-P4') cite as the authority for producer/consumer behavior.

- [ ] **Step 1: Append the failing DS-005 assertion to the sh test**

In `tests/design-system-contract.tests.sh`, insert directly before the final three lines:

```sh
# DS-005 PLUGIN-CONTRACTS section
PC="$ROOT/PLUGIN-CONTRACTS.md"
assert_contains "$PC" '^## sdd-bootstrap design-system artifacts → consumers \(v1\.8\.0\+\)$' "DS-005 contract section heading"
assert_contains "$PC" 'design-system\.contract\.v1\.schema\.json' "DS-005 schema referenced"
assert_contains "$PC" 'absence never blocks' "DS-005 absence contract"
```

- [ ] **Step 2: Append the failing DS-005 assertion to the ps1 test**

In `tests/design-system-contract.tests.ps1`, insert directly before the final line:

```powershell
# DS-005 PLUGIN-CONTRACTS section
$pc = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "PLUGIN-CONTRACTS.md")
if ($pc -notmatch [regex]::Escape('## sdd-bootstrap design-system artifacts → consumers (v1.8.0+)')) { throw "not ok: DS-005 contract section missing" }
if ($pc -notmatch 'absence never blocks') { throw "not ok: DS-005 absence contract missing" }
Write-Host "ok: DS-005 PLUGIN-CONTRACTS section"
```

- [ ] **Step 3: Run the sh test to verify DS-005 fails**

Run: `sh tests/design-system-contract.tests.sh`
Expected: DS-001..DS-004 PASS, DS-005 FAIL, exit 1.

- [ ] **Step 4: Insert the contract section**

In `PLUGIN-CONTRACTS.md`, the sdd-ship section ends with the Track Detection list:

```markdown
1. `--full` flag → FULL (verifies acceptance-tests.md + traceability.md exist)
2. `--lite` flag → LITE
3. `spec_profile: lite` in AGENTS.md → LITE
4. Default → FULL

---

## Plugin Dependency Declarations
```

Insert between `4. Default → FULL` and the `---` before `## Plugin Dependency Declarations`:

```markdown

---

## sdd-bootstrap design-system artifacts → consumers (v1.8.0+)

**Producer**: `plugins/sdd-bootstrap` (design-sync-loop, routed from sdd-bootstrap-interviewer / lite-spec)
**Consumers**: `plugins/sdd-implementation` (implement-task, visual-verify-loop), `plugins/sdd-quality-loop` (quality-gate, check-design-system)

### Artifact Contract

The target application owns a project-level `design-system/` directory at its
repository root (one per project, distinct from per-feature `specs/<feature>/`):

- `design-system/design-tokens.json` — machine-readable tokens. MUST validate
  against `contracts/design-system.contract.v1.schema.json` (strict meta
  envelope: `schema` const `design-system-contract/v1`, semver `version`,
  `generated_by`, `profile`). Token groups follow the W3C DTCG format
  (`$type`/`$value`); groups beyond color/typography/spacing are allowed.
- `design-system/design-system.md` — rules and reasons. Required sections:
  `## Layer 1 — Tokens (machine-extracted)`, `## Layer 2 — Do / Don't
  (component conventions)`, `## Layer 3 — Review checklist (human-curated)`,
  `## Change Process`.
- `design-system/ui-patterns.md` — universal interaction conventions. Required
  sections: `## Actions`, `## Dialogs`, `## Icons`, `## Flow`, `## States`,
  `## Cognitive Load`.
- `design-system/build/` — optional generated token outputs; never
  authoritative.

Templates for all three artifacts live in
`plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/`.

### Handoff Rules

- The producer creates the directory from the templates only when
  `ds_profile: custom` is selected; `ds_profile: none` produces nothing.
  External seeds (ui-ux-pro-max MASTER.md, Figma DTCG exports) are inputs that
  map into these artifacts; the artifacts are always authoritative.
- Consumers read the artifacts and never create or rewrite them. Conformance
  findings flow through review checklists and the advisory visual-verify-loop;
  the deterministic `check-design-system` gate reports warn-level findings
  until its error promotion (two releases after introduction).
- Absence contract: when `design-system/` does not exist, every consumer skips
  with a recorded reason — absence never blocks a workflow.
```

- [ ] **Step 5: Run both tests to verify they pass**

Run: `sh tests/design-system-contract.tests.sh`
Expected: `FAIL: 0`, exit 0.

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/design-system-contract.tests.ps1`
Expected: exit 0.

- [ ] **Step 6: Commit**

```bash
git add PLUGIN-CONTRACTS.md tests/design-system-contract.tests.sh tests/design-system-contract.tests.ps1
git commit -m "docs(contracts): define design-system producer/consumer contract in PLUGIN-CONTRACTS

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```
