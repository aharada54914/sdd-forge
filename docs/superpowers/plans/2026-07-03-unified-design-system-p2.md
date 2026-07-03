# Unified Design System P2' (Review-Loop Integration) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add design-system conformance to the impl-review gate: a new DESIGN-SYSTEM-CONFORMANCE check in impl-reviewer-a, an unsanctioned-UI-library rule in impl-reviewer-b's DESIGN-WITHIN-SCOPE check, and the matching phase-review-checklist entries and counts.

**Architecture:** P2' of `docs/superpowers/specs/2026-07-03-unified-design-system-design.md`. Markdown-only edits to the sdd-review-loop plugin's agent prompts and checklist reference. `tests/review-prompt-calibration.tests.sh` asserts check counts (impl 19→20) and must be updated in lockstep; DS-010/DS-011 assertions extend the paired `tests/design-system-contract.tests.(sh|ps1)`.

**Tech Stack:** Markdown agent prompts, POSIX sh + Windows PowerShell 5.1 tests.

**Branch:** feature/unified-design-system

## Global Constraints

- No SKILL.md files change in P2'; only sdd-review-loop agent/reference files and test files listed per task. Skill visibility contract untouched.
- The new check is skip-not-block: when the project has no `design-system/` directory or design.md records `N/A — ds_profile: none`, the check is skipped (PASS with a skip note) — absence never blocks (PLUGIN-CONTRACTS.md absence contract).
- Vocabulary must match P0'/P1' artifacts verbatim: `## Design System Compliance` (design.template.md), `N/A — ds_profile: none`, `design-system/design-system.md`, `design-system/ui-patterns.md`, design-tokens.json `meta.version`.
- `tests/review-prompt-calibration.tests.sh` count assertions: line 60 (`impl-review-loop`: 19 checks`) must become 20 in the same task that updates the checklist counts; the reviewer-b count line (10 checks) stays unchanged — the UI-library rule extends an existing check, it does not add one.
- No non-ASCII literals in .ps1 additions (PS5.1 ANSI parsing); .sh may use UTF-8 literals.
- Run sh tests via Bash tool, ps1 via `powershell -NoProfile -ExecutionPolicy Bypass -File <path>`; if a subagent environment denies PowerShell, note it — the controller verifies.
- Git commits end with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`; author `aharada` with dummy email only.

---

### Task 1: DESIGN-SYSTEM-CONFORMANCE check (impl-reviewer-a + checklist + counts)

**Files:**
- Modify: `plugins/sdd-review-loop/agents/impl-reviewer-a.md` (new check after ADR-PRESENT ~line 204-217; ordered checks array ~line 259-262)
- Modify: `plugins/sdd-review-loop/references/phase-review-checklist.md` (line 6 count; lines 269-271 counts; line 293 heading count; new #### block after ADR-PRESENT block ~line 476)
- Modify: `tests/review-prompt-calibration.tests.sh:60` (count 19→20)
- Modify: `tests/design-system-contract.tests.sh`, `tests/design-system-contract.tests.ps1` (append DS-010)

**Interfaces:**
- Consumes: P1' vocabulary (`## Design System Compliance`, `N/A — ds_profile: none`).
- Produces: check ID `DESIGN-SYSTEM-CONFORMANCE` (Reviewer impl-reviewer-a, TYPE-D, Major, skip condition as above) that P4''s rubric/docs may cite.

- [ ] **Step 1: Append failing DS-010 assertions**

In `tests/design-system-contract.tests.sh`, insert directly before the final three lines (`printf 'PASS: ...'` block):

```sh
# DS-010 impl-reviewer-a design-system conformance check
IRA="$ROOT/plugins/sdd-review-loop/agents/impl-reviewer-a.md"
assert_contains "$IRA" '^## DESIGN-SYSTEM-CONFORMANCE \(Major, TYPE-D\)$' "DS-010 reviewer-a check defined"
assert_contains "$IRA" 'ADR-PRESENT, DESIGN-SYSTEM-CONFORMANCE\.' "DS-010 ordered checks updated"
PRC="$ROOT/plugins/sdd-review-loop/references/phase-review-checklist.md"
assert_contains "$PRC" '^#### DESIGN-SYSTEM-CONFORMANCE$' "DS-010 checklist block"
assert_contains "$PRC" 'impl-review-loop`: 20 checks' "DS-010 impl count updated"
```

In `tests/design-system-contract.tests.ps1`, insert directly before the final line (`Write-Host "ok: design-system contract tests passed"`):

```powershell
# DS-010 impl-reviewer-a design-system conformance check
$ira = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-review-loop/agents/impl-reviewer-a.md")
if ($ira -notmatch [regex]::Escape('## DESIGN-SYSTEM-CONFORMANCE (Major, TYPE-D)')) { throw "not ok: DS-010 reviewer-a check missing" }
if ($ira -notmatch [regex]::Escape('ADR-PRESENT, DESIGN-SYSTEM-CONFORMANCE.')) { throw "not ok: DS-010 ordered checks not updated" }
$prc = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-review-loop/references/phase-review-checklist.md")
if ($prc -notmatch [regex]::Escape('#### DESIGN-SYSTEM-CONFORMANCE')) { throw "not ok: DS-010 checklist block missing" }
Write-Host "ok: DS-010 reviewer-a conformance check"
```

- [ ] **Step 2: Update the calibration test count (also failing until the checklist changes)**

In `tests/review-prompt-calibration.tests.sh` line 60, replace:

```bash
grep -Fq 'impl-review-loop`: 19 checks' "$CHECKLIST" || fail "impl checklist count must be 19"
```

with:

```bash
grep -Fq 'impl-review-loop`: 20 checks' "$CHECKLIST" || fail "impl checklist count must be 20"
```

- [ ] **Step 3: Run both tests to verify they fail**

Run: `sh tests/design-system-contract.tests.sh` — Expected: DS-010 4 failures, exit 1.
Run: `sh tests/review-prompt-calibration.tests.sh` — Expected: FAIL on "impl checklist count must be 20", exit non-zero.

- [ ] **Step 4: Add the check to impl-reviewer-a.md**

In `plugins/sdd-review-loop/agents/impl-reviewer-a.md`, the ADR-PRESENT check section is followed by `# Severity Reference`. Insert directly before `# Severity Reference`:

```markdown
## DESIGN-SYSTEM-CONFORMANCE (Major, TYPE-D)

Applies only when the target project has a `design-system/` directory. When
the project has no `design-system/` directory, or design.md's
`## Design System Compliance` section records exactly
`N/A — ds_profile: none`, record the check as skipped in the notes and emit
PASS.

Otherwise the `## Design System Compliance` section of design.md must:
1. Name the design-system version it was written against
   (design-tokens.json `meta.version`).
2. List the token groups the feature uses.
3. Record a reason for every new component — reuse of existing components is
   the default, and an unexplained new component is a finding.
4. Not contradict `design-system/design-system.md` or
   `design-system/ui-patterns.md` (for example, sanctioning raw style values
   or icon-only dialog buttons).

A missing section while `design-system/` exists, a missing version reference,
or an unexplained new component is a Major finding.
```

Then update the ordered checks declaration. Replace:

```markdown
The `checks` array must contain one entry per check ID in this order:
ARCH-COVERAGE, NO-CIRCULAR-DEPS, DATA-COVERAGE, API-COVERAGE, SECURITY-COVERAGE,
FRONTEND-BACKEND-CONSISTENCY, TEST-STRATEGY-COVERAGE, NO-UNDEFINED-COMPONENT,
ADR-PRESENT.
```

with:

```markdown
The `checks` array must contain one entry per check ID in this order:
ARCH-COVERAGE, NO-CIRCULAR-DEPS, DATA-COVERAGE, API-COVERAGE, SECURITY-COVERAGE,
FRONTEND-BACKEND-CONSISTENCY, TEST-STRATEGY-COVERAGE, NO-UNDEFINED-COMPONENT,
ADR-PRESENT, DESIGN-SYSTEM-CONFORMANCE.
```

- [ ] **Step 5: Update the checklist counts and add the block**

In `plugins/sdd-review-loop/references/phase-review-checklist.md`:

(a) Line 6, replace:

```markdown
- **Part 1** — `impl-review-loop`: 19 checks across impl-reviewer-a and impl-reviewer-b
```

with:

```markdown
- **Part 1** — `impl-review-loop`: 20 checks across impl-reviewer-a and impl-reviewer-b
```

(b) Lines 269-271, replace:

```markdown
Complete reference for all 19 checks in the impl-review-loop. Checks are split
across two reviewers: impl-reviewer-a (structural soundness, 9 checks) and
impl-reviewer-b (implementability/risk, 10 checks).
```

with:

```markdown
Complete reference for all 20 checks in the impl-review-loop. Checks are split
across two reviewers: impl-reviewer-a (structural soundness, 10 checks) and
impl-reviewer-b (implementability/risk, 10 checks).
```

(c) Line 293, replace:

```markdown
### Reviewer-A Checks (Structural Soundness — 9 checks)
```

with:

```markdown
### Reviewer-A Checks (Structural Soundness — 10 checks)
```

(d) The ADR-PRESENT block (#### ADR-PRESENT, ~line 460) ends with its Fail
condition paragraph followed by `---` and then `### Reviewer-B Checks
(Implementability/Risk — 10 checks)`. Insert between that `---` and the
`### Reviewer-B Checks` heading:

```markdown
#### DESIGN-SYSTEM-CONFORMANCE

| Field | Value |
|---|---|
| Reviewer | impl-reviewer-a |
| Type | TYPE-D |
| Severity | Major |
| Default | FAIL |
| Skip condition | Project has no `design-system/` directory, or design.md records `N/A — ds_profile: none` |

**Description:** When the project carries a `design-system/` contract, design.md's
`## Design System Compliance` section must reference the design-system version
(design-tokens.json `meta.version`), list the token groups used, and record a
reason for every new component, without contradicting
`design-system/design-system.md` or `design-system/ui-patterns.md`.

**Pass condition:** Section present with a version reference and token list;
every new component carries a reason; no contradiction with the design-system
artifacts.

**Fail condition:** Section missing while `design-system/` exists; version or
token usage unrecorded; a new component without a reason; or a statement that
contradicts the design-system artifacts.

---

```

- [ ] **Step 6: Run the gating tests to verify green**

Run: `sh tests/design-system-contract.tests.sh` — Expected: `FAIL: 0` (47 PASS), exit 0.
Run: `sh tests/review-prompt-calibration.tests.sh` — Expected: pass, exit 0.
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/design-system-contract.tests.ps1` — Expected: ok lines through `ok: DS-010 reviewer-a conformance check`, exit 0.

- [ ] **Step 7: Commit**

```bash
git add plugins/sdd-review-loop/agents/impl-reviewer-a.md plugins/sdd-review-loop/references/phase-review-checklist.md tests/review-prompt-calibration.tests.sh tests/design-system-contract.tests.sh tests/design-system-contract.tests.ps1
git commit -m "feat(review-loop): add DESIGN-SYSTEM-CONFORMANCE check to impl-reviewer-a

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Unsanctioned-UI-library rule in DESIGN-WITHIN-SCOPE (impl-reviewer-b + checklist)

**Files:**
- Modify: `plugins/sdd-review-loop/agents/impl-reviewer-b.md:191-202` (DESIGN-WITHIN-SCOPE check)
- Modify: `plugins/sdd-review-loop/references/phase-review-checklist.md:643-659` (#### DESIGN-WITHIN-SCOPE block)
- Modify: `tests/design-system-contract.tests.sh`, `tests/design-system-contract.tests.ps1` (append DS-011)

**Interfaces:**
- Consumes: `## Design System Compliance` vocabulary; check counts unchanged (extends an existing check).
- Produces: the reviewer-b scope rule P4''s evaluation-rubric change may cite.

- [ ] **Step 1: Append failing DS-011 assertions**

In `tests/design-system-contract.tests.sh`, insert directly before the final three lines:

```sh
# DS-011 impl-reviewer-b unsanctioned UI library rule
IRB="$ROOT/plugins/sdd-review-loop/agents/impl-reviewer-b.md"
assert_contains "$IRB" 'UI component library or styling framework' "DS-011 reviewer-b UI library rule"
assert_contains "$PRC" 'unsanctioned UI component library' "DS-011 checklist UI library rule"
```

In `tests/design-system-contract.tests.ps1`, insert directly before the final line:

```powershell
# DS-011 impl-reviewer-b unsanctioned UI library rule
$irb = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-review-loop/agents/impl-reviewer-b.md")
if ($irb -notmatch 'UI component library or styling framework') { throw "not ok: DS-011 reviewer-b rule missing" }
Write-Host "ok: DS-011 reviewer-b UI library rule"
```

- [ ] **Step 2: Run the sh test to verify DS-011 fails**

Run: `sh tests/design-system-contract.tests.sh` — Expected: DS-011 2 failures, exit 1.

- [ ] **Step 3: Extend the reviewer-b check**

In `plugins/sdd-review-loop/agents/impl-reviewer-b.md`, inside `## DESIGN-WITHIN-SCOPE (Major, TYPE-H)`, replace:

```markdown
Conversely, the design must cover every feature described in requirements.md
`## Goals` and `## User Stories`. An under-scoped design that omits a required
capability is also a Major finding.

For each finding, cite the specific design element that is out-of-scope or the
requirement that is unaddressed.
```

with:

```markdown
Conversely, the design must cover every feature described in requirements.md
`## Goals` and `## User Stories`. An under-scoped design that omits a required
capability is also a Major finding.

When the project carries a `design-system/` contract, introducing a UI
component library or styling framework that neither requirements.md nor
design.md's `## Design System Compliance` section sanctions is scope creep —
a Major finding.

For each finding, cite the specific design element that is out-of-scope or the
requirement that is unaddressed.
```

- [ ] **Step 4: Extend the checklist block**

In `plugins/sdd-review-loop/references/phase-review-checklist.md`, in the `#### DESIGN-WITHIN-SCOPE` block, replace:

```markdown
**Description:** Design must not introduce unRequested components (scope creep)
and must not omit required capabilities (under-scope).

**Pass condition:** Design covers all Goals and User Stories; no extra capabilities
introduced without requirement backing.

**Fail condition:** Any design element with no requirement backing; any requirement
capability absent from design.
```

with:

```markdown
**Description:** Design must not introduce unRequested components (scope creep)
and must not omit required capabilities (under-scope). With a `design-system/`
contract present, an unsanctioned UI component library or styling framework is
scope creep.

**Pass condition:** Design covers all Goals and User Stories; no extra capabilities
introduced without requirement backing.

**Fail condition:** Any design element with no requirement backing; any requirement
capability absent from design; an unsanctioned UI component library or styling
framework introduced while `design-system/` exists.
```

- [ ] **Step 5: Run the gating tests to verify green**

Run: `sh tests/design-system-contract.tests.sh` — Expected: `FAIL: 0` (49 PASS), exit 0.
Run: `sh tests/review-prompt-calibration.tests.sh` — Expected: pass, exit 0 (counts unchanged by this task).
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/design-system-contract.tests.ps1` — Expected: ok lines through `ok: DS-011 reviewer-b UI library rule`, exit 0.

- [ ] **Step 6: Commit**

```bash
git add plugins/sdd-review-loop/agents/impl-reviewer-b.md plugins/sdd-review-loop/references/phase-review-checklist.md tests/design-system-contract.tests.sh tests/design-system-contract.tests.ps1
git commit -m "feat(review-loop): flag unsanctioned UI libraries as scope creep in DESIGN-WITHIN-SCOPE

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```
