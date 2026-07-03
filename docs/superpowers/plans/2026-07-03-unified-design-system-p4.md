# Unified Design System P4' (Quality-Loop Verification Gates) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the verification-gate layer: design-system-checklist for reviewers, WCAG 2.2 AA accessibility update, the deterministic `check-design-system.(sh|ps1)` script (warn-phase) with its own fixture test pair, and the contract/matrix/quality-gate wiring.

**Architecture:** P4' of `docs/superpowers/specs/2026-07-03-unified-design-system-design.md`. Two spec deviations, both forced by the repo's R-10 hook protection and both consistent with the spec's warn→error policy: (1) new gate test cases go into a NEW test pair `tests/design-system-compliance.tests.(sh|ps1)` instead of the protected `tests/gates.tests.sh`; (2) `design-system` joins risk-gate-matrix.md as a **conditional control** (like cross-model-verification) rather than a machine-enforced tier minimum — the matrix's own invariant requires tier-minimum changes to be mirrored in the protected `check-contract` scripts, which stays a human task at error-promotion time (two releases after introduction).

**Tech Stack:** POSIX sh (bash 3.2) + Windows PowerShell 5.1 scripts and tests, Markdown references, JSON template.

**Branch:** feature/unified-design-system

## Global Constraints

- PROTECTED (do not touch): `tests/gates.tests.sh`, `tests/eval.tests.sh`, `tests/constant-parity.tests.sh`, `tests/guard-parity.tests.sh`, `scripts/check-contract.*`, `scripts/check-evidence-bundle.*`, hook files. If an edit seems to require one of these, STOP and report.
- Warn-phase policy (spec OQ-2): `check-design-system` findings never fail the gate by default; `SDD_DESIGN_SYSTEM_ENFORCE=error` is the promotion switch. Absence of `design-system/` skips with a note, exit 0.
- Script conventions (match `check-placeholders` / `check-risk`): usage header comment; positional args in .sh / named params in .ps1; success `"check-design-system passed."` exit 0; failure list lines prefixed `" - "`; fail-closed exit 1 only on bad invocation or enforce-mode findings.
- .ps1 files: PS5.1-safe (no Test-Json, `ConvertFrom-Json` only) and strictly ASCII (no literal em-dash/arrow — none are needed).
- .sh: bash 3.2/POSIX; no jq/python; `mktemp` + `trap ... EXIT` cleanup in tests.
- Vocabulary verbatim from P0'-P3': `design-system-contract/v1`, `## Design System Compliance`, `ds_profile: none`, `design-system/design-tokens.json`, `design-system/ui-patterns.md`, raw-value examples `#hex / rgb() / hsl()`.
- The contract check id is `design-system` (`required:false` — warn-phase), sitting alongside the existing `ui-verification` optional check in verification-contract.template.json.
- Run sh via Bash tool, ps1 via `powershell -NoProfile -ExecutionPolicy Bypass -File <path>`; if a subagent environment denies PowerShell, note it — the controller verifies.
- Git commits end with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`; author `aharada` with dummy email only.

---

### Task 1: design-system-checklist + rubric severity + evaluator conditional load

**Files:**
- Create: `plugins/sdd-quality-loop/references/design-system-checklist.md`
- Modify: `plugins/sdd-quality-loop/references/evaluation-rubric.md` (Major severity row; Domain Checklists list)
- Modify: `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md` (on-demand checklist sentence in Process step 8)
- Test: `tests/design-system-contract.tests.sh`, `tests/design-system-contract.tests.ps1` (append DS-014)

**Interfaces:**
- Consumes: P0'-P3' vocabulary; the `check-design-system` script name (created in Task 3 — the checklist's Verification section forward-references it; final state is consistent).
- Produces: `design-system-checklist.md` filename that Task 4's matrix footnote and evaluator flow reference.

- [ ] **Step 1: Append failing DS-014 assertions**

In `tests/design-system-contract.tests.sh`, insert directly before the final three lines (`printf 'PASS: ...'` block):

```sh
# DS-014 design-system checklist and evaluator wiring
DSC="$ROOT/plugins/sdd-quality-loop/references/design-system-checklist.md"
assert_contains "$DSC" '^# Design System Review Checklist$' "DS-014 checklist exists"
assert_contains "$DSC" '^## UI Patterns \(ui-patterns\.md\)$' "DS-014 ui-patterns section"
RUB="$ROOT/plugins/sdd-quality-loop/references/evaluation-rubric.md"
assert_contains "$RUB" 'design-system non-conformance' "DS-014 rubric Major classification"
QGS="$ROOT/plugins/sdd-quality-loop/skills/quality-gate/SKILL.md"
assert_contains "$QGS" 'design-system-checklist\.md' "DS-014 quality-gate conditional load"
```

In `tests/design-system-contract.tests.ps1`, insert directly before the final line (`Write-Host "ok: design-system contract tests passed"`):

```powershell
# DS-014 design-system checklist and evaluator wiring
$dsc = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-quality-loop/references/design-system-checklist.md")
if ($dsc -notmatch [regex]::Escape('# Design System Review Checklist')) { throw "not ok: DS-014 checklist missing" }
$rub = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-quality-loop/references/evaluation-rubric.md")
if ($rub -notmatch 'design-system non-conformance') { throw "not ok: DS-014 rubric classification missing" }
$qgs = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-quality-loop/skills/quality-gate/SKILL.md")
if ($qgs -notmatch 'design-system-checklist\.md') { throw "not ok: DS-014 quality-gate load missing" }
Write-Host "ok: DS-014 design-system checklist wiring"
```

- [ ] **Step 2: Run the sh test to verify DS-014 fails**

Run: `sh tests/design-system-contract.tests.sh`
Expected: 56 PASS, 4 FAIL (DS-014), exit 1.

- [ ] **Step 3: Create the checklist**

Create `plugins/sdd-quality-loop/references/design-system-checklist.md` with exactly:

```markdown
# Design System Review Checklist

On-demand checklist for the critical reviewer and `quality-gate`. Load it only
when the change touches user-facing UI in a project that carries a
`design-system/` contract; skip it with a note otherwise. Findings map onto
the shared severities in `evaluation-rubric.md`: design-system non-conformance
is `Major` by default, cosmetic-only drift is `Minor`.

## Tokens

- Style values in the diff reference design-tokens.json tokens; no raw color
  codes (#hex / rgb() / hsl()) or magic spacing values outside design-system/
  and generated build/ outputs.
- New tokens were added to design-tokens.json (with a meta.version bump)
  rather than hardcoded locally.

## Components

- Existing components are reused; every new component has its reason recorded
  in design.md's `## Design System Compliance` section.
- Component states follow the layer specs (default, empty, loading, error).

## Responsive and Dark Mode

- Changed views reflow at the breakpoints the feature's specs define.
- Dark-mode rendering is checked only when design-tokens.json defines dark
  variants; otherwise record `N/A — no dark tokens`.

## UI Patterns (ui-patterns.md)

- Exactly one primary action per screen; destructive actions physically
  separated and confirmed.
- Modals only confirm irreversible or destructive operations; notifications
  and progress stay non-modal; dialog buttons carry text labels.
- Icons are paired with text except universally understood ones; the same
  icon means the same concept everywhere.
- Wizard/flow controls keep fixed positions; layout follows the read → input
  → confirm order; post-submit feedback and error recovery paths exist.
- Empty, loading, and error states are defined for every changed view, with
  errors shown near their source and naming the next action.

## Verification

- `scripts/check-design-system.(sh|ps1)` output is captured as evidence.
  Warn-phase: its findings are recorded, non-blocking until error promotion
  (`SDD_DESIGN_SYSTEM_ENFORCE=error`).
```

- [ ] **Step 4: Update the rubric**

In `plugins/sdd-quality-loop/references/evaluation-rubric.md`, replace the Major severity row:

```markdown
| Major | Untested acceptance criterion, unhandled error path, spec drift, scope creep | Yes |
```

with:

```markdown
| Major | Untested acceptance criterion, unhandled error path, spec drift, scope creep, design-system non-conformance | Yes |
```

And in the `## Domain Checklists` list, after the `accessibility-checklist.md` bullet, add:

```markdown
- `design-system-checklist.md` — user-facing UI in projects carrying a
  `design-system/` contract (tokens, components, ui-patterns).
```

- [ ] **Step 5: Update the quality-gate on-demand list**

In `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md` (Process step 8), replace:

```markdown
   When the change touches the relevant surface, the evaluator also applies the
   on-demand domain checklists — `security-checklist.md` (user input, auth,
   secrets, external systems, AI/LLM), `performance-checklist.md` (data access,
   hot paths, rendering), and `accessibility-checklist.md` (user-facing UI).
   Load a checklist only when its domain is in scope, to keep review context lean.
```

with:

```markdown
   When the change touches the relevant surface, the evaluator also applies the
   on-demand domain checklists — `security-checklist.md` (user input, auth,
   secrets, external systems, AI/LLM), `performance-checklist.md` (data access,
   hot paths, rendering), `accessibility-checklist.md` (user-facing UI), and
   `design-system-checklist.md` (user-facing UI in projects carrying a
   `design-system/` contract).
   Load a checklist only when its domain is in scope, to keep review context lean.
```

(If the file's line wrapping differs slightly from the old block above, match on the sentence content — the replacement must preserve everything else in the step.)

- [ ] **Step 6: Run both tests to verify they pass**

Run: `sh tests/design-system-contract.tests.sh` — Expected: `FAIL: 0` (60 PASS), exit 0.
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/design-system-contract.tests.ps1` — Expected: ok through `ok: DS-014 design-system checklist wiring`, exit 0.

- [ ] **Step 7: Commit**

```bash
git add plugins/sdd-quality-loop/references/design-system-checklist.md plugins/sdd-quality-loop/references/evaluation-rubric.md plugins/sdd-quality-loop/skills/quality-gate/SKILL.md tests/design-system-contract.tests.sh tests/design-system-contract.tests.ps1
git commit -m "feat(quality-loop): add design-system review checklist and Major classification

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: WCAG 2.2 AA accessibility update

**Files:**
- Modify: `plugins/sdd-quality-loop/references/accessibility-checklist.md` (line 4 target; Operable section; Understandable section)
- Modify: `plugins/sdd-quality-loop/references/evaluation-rubric.md` (Domain Checklists accessibility line)
- Test: `tests/design-system-contract.tests.sh`, `tests/design-system-contract.tests.ps1` (append DS-015)

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: WCAG 2.2 AA as the stated target everywhere quality-loop references accessibility (design-system.template.md from P0' already says 2.2).

- [ ] **Step 1: Append failing DS-015 assertions**

In `tests/design-system-contract.tests.sh`, insert directly before the final three lines:

```sh
# DS-015 WCAG 2.2 AA update
ACC="$ROOT/plugins/sdd-quality-loop/references/accessibility-checklist.md"
assert_contains "$ACC" 'WCAG 2\.2 AA' "DS-015 target updated"
assert_contains "$ACC" '2\.5\.8 Target' "DS-015 target size SC"
assert_contains "$ACC" '3\.3\.8 Accessible' "DS-015 accessible authentication SC"
```

In `tests/design-system-contract.tests.ps1`, insert directly before the final line:

```powershell
# DS-015 WCAG 2.2 AA update
$acc = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-quality-loop/references/accessibility-checklist.md")
if ($acc -notmatch 'WCAG 2\.2 AA') { throw "not ok: DS-015 target not updated" }
if ($acc -match 'WCAG 2\.1 AA') { throw "not ok: DS-015 stale 2.1 reference remains" }
Write-Host "ok: DS-015 WCAG 2.2 AA"
```

- [ ] **Step 2: Run the sh test to verify DS-015 fails**

Run: `sh tests/design-system-contract.tests.sh`
Expected: 60 PASS, 3 FAIL (DS-015), exit 1.

- [ ] **Step 3: Update the accessibility checklist**

In `plugins/sdd-quality-loop/references/accessibility-checklist.md`:

(a) Replace in the intro (line 4):

```markdown
when the change touches user-facing UI. Target: WCAG 2.1 AA. A change that makes
```

with:

```markdown
when the change touches user-facing UI. Target: WCAG 2.2 AA. A change that makes
```

(b) In `## Operable`, replace:

```markdown
- Targets are adequately sized; motion respects `prefers-reduced-motion`.
```

with:

```markdown
- Targets are at least 24×24 CSS px or have equivalent spacing (2.5.8 Target
  Size minimum); motion respects `prefers-reduced-motion`.
- Focus is not fully obscured by sticky headers, banners, or overlays when an
  element receives keyboard focus (2.4.11 Focus Not Obscured).
- Any dragging interaction offers a single-pointer alternative (2.5.7
  Dragging Movements).
```

(c) In `## Understandable`, after the last existing bullet (`Navigation and naming are consistent across the changed surface.`), add:

```markdown
- Help mechanisms appear in a consistent location across pages (3.2.6
  Consistent Help).
- Information already entered in the same flow is auto-populated or
  selectable rather than demanded again (3.3.7 Redundant Entry).
- Authentication requires no cognitive function test (memorization,
  transcription, or puzzles); paste and password managers are allowed
  (3.3.8 Accessible Authentication minimum).
```

- [ ] **Step 4: Update the rubric accessibility line**

In `plugins/sdd-quality-loop/references/evaluation-rubric.md`, replace:

```markdown
- `accessibility-checklist.md` — user-facing UI (WCAG 2.1 AA).
```

with:

```markdown
- `accessibility-checklist.md` — user-facing UI (WCAG 2.2 AA).
```

- [ ] **Step 5: Run both tests to verify they pass, plus a stale-reference sweep**

Run: `sh tests/design-system-contract.tests.sh` — Expected: `FAIL: 0` (63 PASS), exit 0.
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/design-system-contract.tests.ps1` — Expected: ok through `ok: DS-015 WCAG 2.2 AA`, exit 0.
Run: `grep -rn 'WCAG 2\.1' plugins/sdd-quality-loop/` — Expected: no output (no stale 2.1 references remain in this plugin).

- [ ] **Step 6: Commit**

```bash
git add plugins/sdd-quality-loop/references/accessibility-checklist.md plugins/sdd-quality-loop/references/evaluation-rubric.md tests/design-system-contract.tests.sh tests/design-system-contract.tests.ps1
git commit -m "feat(quality-loop): update accessibility checklist to WCAG 2.2 AA

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: check-design-system script pair + fixture test pair

**Files:**
- Create: `plugins/sdd-quality-loop/scripts/check-design-system.sh`
- Create: `plugins/sdd-quality-loop/scripts/check-design-system.ps1`
- Create: `tests/design-system-compliance.tests.sh`
- Create: `tests/design-system-compliance.tests.ps1`

**Interfaces:**
- Consumes: the P0' contract shape (`design-system-contract/v1` meta envelope; groups color/typography/spacing) and the `## Design System Compliance` / `ds_profile: none` vocabulary.
- Produces: the script interface Task 4 wires into quality-gate — sh: `check-design-system.sh <project-root> [<design-md>] [<changed-file>...]`; ps1: `check-design-system.ps1 -ProjectRoot <path> [-DesignMd <path>] [-ChangedFiles <paths...>]`. Exit 0 on pass/skip/warn; exit 1 on bad invocation or on findings when `SDD_DESIGN_SYSTEM_ENFORCE=error`.

- [ ] **Step 1: Create the failing sh test**

Create `tests/design-system-compliance.tests.sh` with exactly:

```sh
#!/bin/sh
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CHECK_SH="$ROOT/plugins/sdd-quality-loop/scripts/check-design-system.sh"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }

FIX="$(mktemp -d)"
trap 'rm -rf "$FIX"' EXIT

make_fixture() {
  # $1 = fixture dir. Creates a conforming project.
  mkdir -p "$1/design-system" "$1/src" "$1/specs/demo"
  cat > "$1/design-system/design-tokens.json" <<'EOF'
{
  "meta": {
    "schema": "design-system-contract/v1",
    "version": "0.1.0",
    "generated_by": "manual",
    "profile": "custom"
  },
  "color": { "primary": { "$type": "color", "$value": "#0f62fe" } },
  "typography": { "font-size-base": { "$type": "dimension", "$value": "16px" } },
  "spacing": { "md": { "$type": "dimension", "$value": "16px" } }
}
EOF
  printf '.button { color: var(--color-primary); }\n' > "$1/src/app.css"
  printf '# Design: demo\n\n## Design System Compliance\n\n- Design-System-Version: 0.1.0\n' > "$1/specs/demo/design.md"
}

# CDS-001 skip when no design-system/
mkdir -p "$FIX/empty"
out="$(sh "$CHECK_SH" "$FIX/empty" 2>&1)"; rc=$?
case "$out" in *"skipped: no design-system/"*) [ "$rc" -eq 0 ] && pass "CDS-001 skip without design-system" || fail "CDS-001 skip exit code" ;; *) fail "CDS-001 skip without design-system" ;; esac

# CDS-002 conforming project passes
make_fixture "$FIX/ok"
out="$(sh "$CHECK_SH" "$FIX/ok" "$FIX/ok/specs/demo/design.md" "$FIX/ok/src/app.css" 2>&1)"; rc=$?
case "$out" in *"check-design-system passed."*) [ "$rc" -eq 0 ] && pass "CDS-002 conforming project" || fail "CDS-002 exit code" ;; *) fail "CDS-002 conforming project ($out)" ;; esac

# CDS-003 raw value in changed file -> WARN, exit 0
make_fixture "$FIX/warn"
printf '.bad { color: #ff0000; }\n' > "$FIX/warn/src/bad.css"
out="$(sh "$CHECK_SH" "$FIX/warn" "$FIX/warn/specs/demo/design.md" "$FIX/warn/src/bad.css" 2>&1)"; rc=$?
case "$out" in *"check-design-system WARN"*"raw style value"*) [ "$rc" -eq 0 ] && pass "CDS-003 warn on raw value" || fail "CDS-003 warn exit code" ;; *) fail "CDS-003 warn on raw value ($out)" ;; esac

# CDS-004 enforce mode -> exit 1
out="$(SDD_DESIGN_SYSTEM_ENFORCE=error sh "$CHECK_SH" "$FIX/warn" "$FIX/warn/specs/demo/design.md" "$FIX/warn/src/bad.css" 2>&1)"; rc=$?
case "$out" in *"check-design-system FAILED"*) [ "$rc" -eq 1 ] && pass "CDS-004 enforce mode fails" || fail "CDS-004 enforce exit code" ;; *) fail "CDS-004 enforce mode fails ($out)" ;; esac

# CDS-005 invalid meta envelope -> finding
make_fixture "$FIX/badmeta"
printf '{ "meta": { "schema": "wrong/v1" }, "color": {}, "typography": {}, "spacing": {} }\n' > "$FIX/badmeta/design-system/design-tokens.json"
out="$(sh "$CHECK_SH" "$FIX/badmeta" 2>&1)"; rc=$?
case "$out" in *"meta.schema is not design-system-contract/v1"*) pass "CDS-005 invalid meta detected" ;; *) fail "CDS-005 invalid meta detected ($out)" ;; esac

# CDS-006 design.md missing compliance section -> finding
make_fixture "$FIX/nosec"
printf '# Design: demo\n' > "$FIX/nosec/specs/demo/design.md"
out="$(sh "$CHECK_SH" "$FIX/nosec" "$FIX/nosec/specs/demo/design.md" 2>&1)"; rc=$?
case "$out" in *"missing"*"Design System Compliance"*) pass "CDS-006 missing section detected" ;; *) fail "CDS-006 missing section detected ($out)" ;; esac

# CDS-007 excluded paths are not scanned
make_fixture "$FIX/excl"
printf 'color: #ff0000\n' > "$FIX/excl/design-system/design-system.md"
out="$(sh "$CHECK_SH" "$FIX/excl" "$FIX/excl/specs/demo/design.md" "design-system/design-system.md" 2>&1)"; rc=$?
case "$out" in *"check-design-system passed."*) pass "CDS-007 exclusions honored" ;; *) fail "CDS-007 exclusions honored ($out)" ;; esac

printf 'PASS: %s\n' "$PASS"
printf 'FAIL: %s\n' "$FAIL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Create the failing ps1 test**

Create `tests/design-system-compliance.tests.ps1` with exactly:

```powershell
$ErrorActionPreference = "Stop"

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$checkPs1 = Join-Path $repositoryRoot "plugins/sdd-quality-loop/scripts/check-design-system.ps1"

$fix = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-ds-compliance-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $fix | Out-Null

function New-Fixture([string]$dir) {
    New-Item -ItemType Directory -Path (Join-Path $dir "design-system") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $dir "src") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $dir "specs/demo") -Force | Out-Null
    $tokens = '{ "meta": { "schema": "design-system-contract/v1", "version": "0.1.0", "generated_by": "manual", "profile": "custom" }, "color": { "primary": { "$type": "color", "$value": "#0f62fe" } }, "typography": {}, "spacing": {} }'
    Set-Content -Encoding Ascii -Path (Join-Path $dir "design-system/design-tokens.json") -Value $tokens
    Set-Content -Encoding Ascii -Path (Join-Path $dir "src/app.css") -Value '.button { color: var(--color-primary); }'
    Set-Content -Encoding Ascii -Path (Join-Path $dir "specs/demo/design.md") -Value "# Design: demo`n`n## Design System Compliance`n`n- Design-System-Version: 0.1.0"
}

try {
    # CDS-001 skip when no design-system/
    $empty = Join-Path $fix "empty"; New-Item -ItemType Directory -Path $empty | Out-Null
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $checkPs1 -ProjectRoot $empty 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0 -or $out -notmatch 'skipped: no design-system/') { throw "not ok: CDS-001 skip ($out)" }
    Write-Host "ok: CDS-001 skip without design-system"

    # CDS-002 conforming project passes
    $ok = Join-Path $fix "ok"; New-Fixture $ok
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $checkPs1 -ProjectRoot $ok -DesignMd (Join-Path $ok "specs/demo/design.md") -ChangedFiles @((Join-Path $ok "src/app.css")) 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0 -or $out -notmatch 'check-design-system passed\.') { throw "not ok: CDS-002 conforming ($out)" }
    Write-Host "ok: CDS-002 conforming project"

    # CDS-003 raw value -> WARN exit 0
    $warn = Join-Path $fix "warn"; New-Fixture $warn
    Set-Content -Encoding Ascii -Path (Join-Path $warn "src/bad.css") -Value '.bad { color: #ff0000; }'
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $checkPs1 -ProjectRoot $warn -DesignMd (Join-Path $warn "specs/demo/design.md") -ChangedFiles @((Join-Path $warn "src/bad.css")) 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0 -or $out -notmatch 'check-design-system WARN' -or $out -notmatch 'raw style value') { throw "not ok: CDS-003 warn ($out)" }
    Write-Host "ok: CDS-003 warn on raw value"

    # CDS-004 enforce mode -> exit 1
    $env:SDD_DESIGN_SYSTEM_ENFORCE = 'error'
    try {
        $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $checkPs1 -ProjectRoot $warn -DesignMd (Join-Path $warn "specs/demo/design.md") -ChangedFiles @((Join-Path $warn "src/bad.css")) 2>&1 | Out-String
        if ($LASTEXITCODE -ne 1 -or $out -notmatch 'check-design-system FAILED') { throw "not ok: CDS-004 enforce ($out)" }
    } finally { Remove-Item Env:SDD_DESIGN_SYSTEM_ENFORCE -ErrorAction SilentlyContinue }
    Write-Host "ok: CDS-004 enforce mode fails"

    Write-Host "ok: design-system compliance tests passed"
} finally {
    Remove-Item -LiteralPath $fix -Recurse -Force -ErrorAction SilentlyContinue
}
```

- [ ] **Step 3: Run both tests to verify they fail (script absent)**

Run: `sh tests/design-system-compliance.tests.sh` — Expected: multiple FAIL lines, exit 1.
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/design-system-compliance.tests.ps1` — Expected: throws at CDS-001 (script not found), non-zero exit.

- [ ] **Step 4: Create the sh script**

Create `plugins/sdd-quality-loop/scripts/check-design-system.sh` with exactly:

```sh
#!/bin/sh
# Deterministic gate: design-system conformance (warn-phase).
# Usage: check-design-system.sh <project-root> [<design-md>] [<changed-file>...]
#
# Checks (all skipped with exit 0 when <project-root>/design-system is absent):
#  1. design-system/design-tokens.json carries the contract meta envelope
#     (schema design-system-contract/v1, semver version, generated_by) and the
#     required token groups (color, typography, spacing).
#  2. Each <changed-file> contains no raw style values (#hex colors, rgb(,
#     hsl() calls). Excluded from the scan: design-system/, build/, tests/
#     paths and *.md / *.svg files.
#  3. When <design-md> is given: it contains a "## Design System Compliance"
#     section and does not record ds_profile: none while design-system/ exists.
#
# Warn-phase: findings print as WARN and exit 0. Set
# SDD_DESIGN_SYSTEM_ENFORCE=error to fail (exit 1) on findings instead.
# Bad invocation always exits 1.
root="${1:-}"
if [ -z "$root" ] || [ ! -d "$root" ]; then
  echo "check-design-system: project root not found: $root" >&2
  exit 1
fi
if [ ! -d "$root/design-system" ]; then
  echo "check-design-system skipped: no design-system/ directory."
  exit 0
fi
design_md="${2:-}"
[ $# -ge 1 ] && shift
[ $# -ge 1 ] && shift

_f="$(mktemp)"
trap 'rm -f "$_f"' EXIT

tokens="$root/design-system/design-tokens.json"
if [ ! -f "$tokens" ]; then
  echo "design-tokens.json missing" >> "$_f"
else
  grep -q '"schema": *"design-system-contract/v1"' "$tokens" || echo "design-tokens.json: meta.schema is not design-system-contract/v1" >> "$_f"
  grep -Eq '"version": *"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)"' "$tokens" || echo "design-tokens.json: meta.version is not semver" >> "$_f"
  grep -Eq '"generated_by": *"[^"]+"' "$tokens" || echo "design-tokens.json: meta.generated_by missing" >> "$_f"
  for group in color typography spacing; do
    grep -q "\"$group\"" "$tokens" || echo "design-tokens.json: token group $group missing" >> "$_f"
  done
fi

for f in "$@"; do
  case "$f" in
    design-system/*|*/design-system/*|*.md|*.svg|tests/*|*/tests/*|build/*|*/build/*) continue ;;
  esac
  target="$f"
  [ -f "$target" ] || target="$root/$f"
  [ -f "$target" ] || continue
  grep -nE '#[0-9a-fA-F]{6}([^0-9a-fA-F]|$)|#[0-9a-fA-F]{3}([^0-9a-fA-F]|$)|rgb\(|hsl\(' "$target" | head -20 | while IFS= read -r line; do
    echo "raw style value: $f: $line"
  done >> "$_f"
done

if [ -n "$design_md" ]; then
  if [ -f "$design_md" ]; then
    if ! grep -q '^## Design System Compliance$' "$design_md"; then
      echo "design.md: missing '## Design System Compliance' section" >> "$_f"
    elif grep -q 'ds_profile: none' "$design_md"; then
      echo "design.md: records ds_profile: none while design-system/ exists" >> "$_f"
    fi
  else
    echo "design.md not found: $design_md" >> "$_f"
  fi
fi

count=$(grep -c . "$_f")
if [ "$count" -gt 0 ]; then
  if [ "${SDD_DESIGN_SYSTEM_ENFORCE:-warn}" = "error" ]; then
    echo "check-design-system FAILED ($count finding(s)):"
    sed 's/^/ - /' "$_f"
    exit 1
  fi
  echo "check-design-system WARN ($count finding(s)):"
  sed 's/^/ - /' "$_f"
  echo "Warn-phase: findings do not block; record them in the quality-gate report. Set SDD_DESIGN_SYSTEM_ENFORCE=error to enforce."
  exit 0
fi
echo "check-design-system passed."
exit 0
```

- [ ] **Step 5: Create the ps1 script**

Create `plugins/sdd-quality-loop/scripts/check-design-system.ps1` with exactly:

```powershell
# Deterministic gate: design-system conformance (warn-phase).
# Usage: check-design-system.ps1 -ProjectRoot <path> [-DesignMd <path>] [-ChangedFiles <paths...>]
#
# Checks (all skipped with exit 0 when <ProjectRoot>/design-system is absent):
#  1. design-system/design-tokens.json carries the contract meta envelope
#     (schema design-system-contract/v1, semver version, generated_by) and the
#     required token groups (color, typography, spacing).
#  2. Each ChangedFiles entry contains no raw style values (#hex colors,
#     rgb(, hsl( calls). Excluded: design-system/, build/, tests/ paths and
#     *.md / *.svg files.
#  3. When -DesignMd is given: it contains a "## Design System Compliance"
#     section and does not record ds_profile: none while design-system/ exists.
#
# Warn-phase: findings print as WARN and exit 0. Set
# SDD_DESIGN_SYSTEM_ENFORCE=error to fail (exit 1) on findings instead.
param(
    [Parameter(Mandatory)][string]$ProjectRoot,
    [string]$DesignMd = "",
    [string[]]$ChangedFiles = @()
)
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ProjectRoot)) {
    Write-Error "check-design-system: project root not found: $ProjectRoot"
    exit 1
}
$dsDir = Join-Path $ProjectRoot "design-system"
if (-not (Test-Path -LiteralPath $dsDir)) {
    Write-Host "check-design-system skipped: no design-system/ directory."
    exit 0
}

$findings = @()
$tokensPath = Join-Path $dsDir "design-tokens.json"
if (-not (Test-Path -LiteralPath $tokensPath)) {
    $findings += "design-tokens.json missing"
} else {
    try {
        $tokens = Get-Content -Raw -Encoding Utf8 $tokensPath | ConvertFrom-Json
        if ($tokens.meta.schema -ne 'design-system-contract/v1') { $findings += "design-tokens.json: meta.schema is not design-system-contract/v1" }
        if ([string]$tokens.meta.version -notmatch '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$') { $findings += "design-tokens.json: meta.version is not semver" }
        if ([string]::IsNullOrEmpty([string]$tokens.meta.generated_by)) { $findings += "design-tokens.json: meta.generated_by missing" }
        foreach ($group in @('color', 'typography', 'spacing')) {
            if ($null -eq $tokens.PSObject.Properties[$group]) { $findings += "design-tokens.json: token group $group missing" }
        }
    } catch {
        $findings += "design-tokens.json: not valid JSON"
    }
}

foreach ($f in $ChangedFiles) {
    $rel = [string]$f
    if ($rel -match '(^|[\\/])design-system[\\/]' -or $rel -match '\.(md|svg)$' -or $rel -match '(^|[\\/])tests[\\/]' -or $rel -match '(^|[\\/])build[\\/]') { continue }
    $target = $rel
    if (-not (Test-Path -LiteralPath $target)) { $target = Join-Path $ProjectRoot $rel }
    if (-not (Test-Path -LiteralPath $target)) { continue }
    $hits = @(Select-String -LiteralPath $target -Pattern '#[0-9a-fA-F]{6}([^0-9a-fA-F]|$)|#[0-9a-fA-F]{3}([^0-9a-fA-F]|$)|rgb\(|hsl\(' | Select-Object -First 20)
    foreach ($hit in $hits) { $findings += "raw style value: ${rel}: line $($hit.LineNumber)" }
}

if ($DesignMd -ne "") {
    if (Test-Path -LiteralPath $DesignMd) {
        $dm = Get-Content -Raw -Encoding Utf8 $DesignMd
        if ($dm -notmatch '## Design System Compliance') {
            $findings += "design.md: missing '## Design System Compliance' section"
        } elseif ($dm -match 'ds_profile: none') {
            $findings += "design.md: records ds_profile: none while design-system/ exists"
        }
    } else {
        $findings += "design.md not found: $DesignMd"
    }
}

if ($findings.Count -gt 0) {
    if ($env:SDD_DESIGN_SYSTEM_ENFORCE -eq 'error') {
        Write-Host "check-design-system FAILED ($($findings.Count) finding(s)):"
        $findings | ForEach-Object { Write-Host " - $_" }
        exit 1
    }
    Write-Host "check-design-system WARN ($($findings.Count) finding(s)):"
    $findings | ForEach-Object { Write-Host " - $_" }
    Write-Host "Warn-phase: findings do not block; record them in the quality-gate report. Set SDD_DESIGN_SYSTEM_ENFORCE=error to enforce."
    exit 0
}
Write-Host "check-design-system passed."
exit 0
```

- [ ] **Step 6: Run both tests to verify they pass**

Run: `sh tests/design-system-compliance.tests.sh` — Expected: `PASS: 7` / `FAIL: 0`, exit 0.
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/design-system-compliance.tests.ps1` — Expected: ok lines CDS-001..CDS-004 and the final ok, exit 0.

- [ ] **Step 7: Commit**

```bash
git add plugins/sdd-quality-loop/scripts/check-design-system.sh plugins/sdd-quality-loop/scripts/check-design-system.ps1 tests/design-system-compliance.tests.sh tests/design-system-compliance.tests.ps1
git commit -m "feat(quality-loop): add check-design-system deterministic gate (warn-phase) with fixture tests

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: contract check id + risk-gate-matrix conditional control + quality-gate wiring

**Files:**
- Modify: `plugins/sdd-quality-loop/templates/verification-contract.template.json` (add `design-system` check entry)
- Modify: `plugins/sdd-quality-loop/references/risk-gate-matrix.md` (conditional-control row + footnote)
- Modify: `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md` (scripted-gates list in Process step 6)
- Test: `tests/design-system-contract.tests.sh`, `tests/design-system-contract.tests.ps1` (append DS-016)

**Interfaces:**
- Consumes: the Task 3 script interface and warn-phase env switch.
- Produces: contract check id `design-system` (required:false, waivable) and the matrix's documented error-promotion path.

- [ ] **Step 1: Append failing DS-016 assertions**

In `tests/design-system-contract.tests.sh`, insert directly before the final three lines:

```sh
# DS-016 contract check id, matrix row, quality-gate wiring
VCT="$ROOT/plugins/sdd-quality-loop/templates/verification-contract.template.json"
assert_contains "$VCT" '"id": "design-system"' "DS-016 contract check id"
RGM="$ROOT/plugins/sdd-quality-loop/references/risk-gate-matrix.md"
assert_contains "$RGM" 'design-system conformance' "DS-016 matrix conditional row"
assert_contains "$QGS" 'check-design-system' "DS-016 quality-gate runs the script"
```

In `tests/design-system-contract.tests.ps1`, insert directly before the final line:

```powershell
# DS-016 contract check id, matrix row, quality-gate wiring
$vct = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-quality-loop/templates/verification-contract.template.json")
if ($vct -notmatch '"id": "design-system"') { throw "not ok: DS-016 contract check id missing" }
$rgm = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-quality-loop/references/risk-gate-matrix.md")
if ($rgm -notmatch 'design-system conformance') { throw "not ok: DS-016 matrix row missing" }
if ($qgs -notmatch 'check-design-system') { throw "not ok: DS-016 quality-gate wiring missing" }
Write-Host "ok: DS-016 contract and matrix wiring"
```

(Note: `$qgs` was defined by the DS-014 block earlier in the same file and still holds the pre-Task-4 content when this block first runs — the test re-reads files top-to-bottom on every invocation, so after Task 4's SKILL.md edit the DS-014 read picks up the new content. No change needed.)

- [ ] **Step 2: Run the sh test to verify DS-016 fails**

Run: `sh tests/design-system-contract.tests.sh`
Expected: 63 PASS, 3 FAIL (DS-016), exit 1.

- [ ] **Step 3: Add the contract check entry**

In `plugins/sdd-quality-loop/templates/verification-contract.template.json`, replace:

```json
    { "id": "ui-verification", "required": false, "passes": false, "evidence": "", "waiver_reason": "", "requirement_ids": [], "red_evidence": "", "green_evidence": "" }
```

with:

```json
    { "id": "ui-verification", "required": false, "passes": false, "evidence": "", "waiver_reason": "", "requirement_ids": [], "red_evidence": "", "green_evidence": "" },
    { "id": "design-system", "required": false, "passes": false, "evidence": "", "waiver_reason": "", "requirement_ids": [], "red_evidence": "", "green_evidence": "" }
```

- [ ] **Step 4: Add the matrix conditional-control row and footnote**

In `plugins/sdd-quality-loop/references/risk-gate-matrix.md`, replace the matrix row:

```markdown
| cross-model-verification   |  —  |   —    |  ◐³  |    ✓³    |
```

with:

```markdown
| cross-model-verification   |  —  |   —    |  ◐³  |    ✓³    |
| design-system conformance  |  —  |   ◐⁴   |  ◐⁴  |    ◐⁴    |
```

And after the `³` footnote block (ends with `...(see \`references/cross-model-verification-policy.md\`).`), add:

```markdown
⁴ Warn-phase **conditional control**, NOT part of the machine-form `RISK_TIERS`
  set. When the project carries a `design-system/` directory and the task
  touches UI-layer files, `check-design-system.(sh|ps1)` runs and its findings
  are recorded in the report and in the contract's `design-system` check
  (`required:false`, with evidence or a `waiver_reason`). Error promotion —
  two releases after introduction — moves it into the tier minimums, which is
  a human edit of the R-10-protected `check-contract` scripts and their parity
  tests, per this file's invariant note.
```

- [ ] **Step 5: Wire the script into quality-gate's scripted gates**

In `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md` (Process step 6 list), replace:

```markdown
   - `check-placeholders` on the changed production files only.
```

with:

```markdown
   - `check-placeholders` on the changed production files only.
   - `check-design-system` on the changed files when the project carries a
     `design-system/` directory and the task touches UI-layer files: validates
     the design-tokens.json contract envelope, scans changed files for raw
     style values, and confirms design.md's `## Design System Compliance`
     section. Warn-phase: findings are recorded in the report and in the
     contract's `design-system` check but do not block until the error
     promotion (`SDD_DESIGN_SYSTEM_ENFORCE=error`); when `design-system/` is
     absent the script skips with a note.
```

- [ ] **Step 6: Run the gating tests to verify green**

Run: `sh tests/design-system-contract.tests.sh` — Expected: `FAIL: 0` (66 PASS), exit 0.
Run: `sh tests/design-system-compliance.tests.sh` — Expected: `PASS: 7` / `FAIL: 0`, exit 0 (regression guard).
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/design-system-contract.tests.ps1` — Expected: ok through `ok: DS-016 contract and matrix wiring`, exit 0.

- [ ] **Step 7: Commit**

```bash
git add plugins/sdd-quality-loop/templates/verification-contract.template.json plugins/sdd-quality-loop/references/risk-gate-matrix.md plugins/sdd-quality-loop/skills/quality-gate/SKILL.md tests/design-system-contract.tests.sh tests/design-system-contract.tests.ps1
git commit -m "feat(quality-loop): wire design-system conditional control into contract, matrix, and gate

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```
