# Unified Design System P3' (Implementation Enforcement) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enforce the design-system contract at implementation time: UI implementation rules in implementation-policy.md, conditional required reading in implement-task, and design-system conformance as a comparison criterion in visual-verify-loop.

**Architecture:** P3' of `docs/superpowers/specs/2026-07-03-unified-design-system-design.md`. Markdown-only edits to the sdd-implementation plugin (none of its files are hook-protected). DS-012/DS-013 assertions extend the paired `tests/design-system-contract.tests.(sh|ps1)` (currently 49 sh assertions green).

**Tech Stack:** Markdown skill/reference files, POSIX sh + Windows PowerShell 5.1 tests.

**Branch:** feature/unified-design-system

## Global Constraints

- Conditional loading (spec acceptance): every new rule applies only to UI tasks in projects carrying `design-system/`; non-UI tasks gain zero context overhead. Absence of `design-system/` is skipped-with-a-note, never blocking.
- Vocabulary must match P0'-P2' artifacts verbatim: `design-system/design-tokens.json`, `design-system/design-system.md`, `design-system/ui-patterns.md`, `Design System Compliance`, raw-value examples `#hex / rgb() / hsl()`.
- visual-verify-loop stays advisory and non-blocking (never decides task state); the deterministic gate ownership belongs to `check-design-system` (built in P4' — the forward reference is intentional and lands before release).
- Frontmatter of both skills (`disable-model-invocation: true`, `user-invocable: false`) untouched; no new skills.
- No non-ASCII literals in .ps1 additions; .sh/.md may use UTF-8 literals. Run sh via Bash tool, ps1 via `powershell -NoProfile -ExecutionPolicy Bypass -File <path>`; if a subagent environment denies PowerShell, note it — the controller verifies.
- Git commits end with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`; author `aharada` with dummy email only.

---

### Task 1: UI implementation rules + conditional required reading

**Files:**
- Modify: `plugins/sdd-implementation/skills/implement-task/references/implementation-policy.md` (22 lines; insert a section between the top bullet list and `## Context Management`)
- Modify: `plugins/sdd-implementation/skills/implement-task/SKILL.md:37-42` (Required Reading)
- Test: `tests/design-system-contract.tests.sh`, `tests/design-system-contract.tests.ps1` (append DS-012)

**Interfaces:**
- Consumes: P0'/P1' artifact names and the `Design System Compliance` section vocabulary.
- Produces: the `## UI Implementation Rules` section heading that P4''s checklist and docs may cite.

- [ ] **Step 1: Append failing DS-012 assertions**

In `tests/design-system-contract.tests.sh`, insert directly before the final three lines (`printf 'PASS: ...'` block):

```sh
# DS-012 implementation policy UI rules and conditional required reading
IPOL="$ROOT/plugins/sdd-implementation/skills/implement-task/references/implementation-policy.md"
assert_contains "$IPOL" '^## UI Implementation Rules$' "DS-012 UI rules section"
assert_contains "$IPOL" 'design-tokens\.json tokens only' "DS-012 tokens-only rule"
assert_contains "$IPOL" 'design-system/ui-patterns\.md' "DS-012 ui-patterns reference"
ITSK="$ROOT/plugins/sdd-implementation/skills/implement-task/SKILL.md"
assert_contains "$ITSK" 'design-system/design-system\.md' "DS-012 conditional required reading"
```

In `tests/design-system-contract.tests.ps1`, insert directly before the final line (`Write-Host "ok: design-system contract tests passed"`):

```powershell
# DS-012 implementation policy UI rules and conditional required reading
$ipol = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-implementation/skills/implement-task/references/implementation-policy.md")
if ($ipol -notmatch [regex]::Escape('## UI Implementation Rules')) { throw "not ok: DS-012 UI rules section missing" }
if ($ipol -notmatch 'design-tokens\.json tokens only') { throw "not ok: DS-012 tokens-only rule missing" }
$itsk = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-implementation/skills/implement-task/SKILL.md")
if ($itsk -notmatch 'design-system/design-system\.md') { throw "not ok: DS-012 required reading missing" }
Write-Host "ok: DS-012 implementation policy UI rules"
```

- [ ] **Step 2: Run the sh test to verify DS-012 fails**

Run: `sh tests/design-system-contract.tests.sh`
Expected: 49 PASS, 4 FAIL (DS-012), exit 1.

- [ ] **Step 3: Add the UI Implementation Rules section**

In `plugins/sdd-implementation/skills/implement-task/references/implementation-policy.md`, insert between the top bullet list (ends with the line about `Implementation Complete`) and `## Context Management`:

```markdown
## UI Implementation Rules

Apply these rules when the task touches UI-layer files and the project
carries a `design-system/` contract (`ds_profile: custom`). When
`design-system/` does not exist, skip them and note the absence in the
implementation report — the absence never blocks the task.

- Style values reference design-tokens.json tokens only. Raw color codes
  (#hex / rgb() / hsl()) and magic spacing values in UI code are defects.
- Reuse existing components first. Create a new component only when the
  feature's design.md `Design System Compliance` section records the reason.
- Accessibility essentials (WCAG 2.2 AA per design-system/design-system.md):
  no icon-only buttons in dialogs, never use placeholder text as a label
  substitute, clickable elements carry text.
- Follow design-system/ui-patterns.md for action placement, dialog usage,
  icons, flow order, and empty/loading/error states.
- When the target language has no lint configuration enforcing these rules,
  raise the gap as a follow-up task in the implementation report — do not
  add lint infrastructure inside an unrelated task's scope.
```

- [ ] **Step 4: Extend Required Reading in implement-task**

In `plugins/sdd-implementation/skills/implement-task/SKILL.md`, replace:

```markdown
Read `AGENTS.md`, the target feature requirements, design, tasks, acceptance tests,
traceability, relevant ADRs and contracts, `references/implementation-policy.md`,
`references/implementation-craft-policy.md`, and
`references/agent-delegation-policy.md`.
```

with:

```markdown
Read `AGENTS.md`, the target feature requirements, design, tasks, acceptance tests,
traceability, relevant ADRs and contracts, `references/implementation-policy.md`,
`references/implementation-craft-policy.md`, and
`references/agent-delegation-policy.md`. For UI tasks in a project that
carries a `design-system/` directory, also read
`design-system/design-system.md` and `design-system/ui-patterns.md`; for
other tasks do not load them.
```

- [ ] **Step 5: Run both tests to verify they pass**

Run: `sh tests/design-system-contract.tests.sh` — Expected: `FAIL: 0` (53 PASS), exit 0.
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/design-system-contract.tests.ps1` — Expected: ok lines through `ok: DS-012 implementation policy UI rules`, exit 0.

- [ ] **Step 6: Commit**

```bash
git add plugins/sdd-implementation/skills/implement-task/references/implementation-policy.md plugins/sdd-implementation/skills/implement-task/SKILL.md tests/design-system-contract.tests.sh tests/design-system-contract.tests.ps1
git commit -m "feat(implementation): add UI implementation rules and conditional design-system reading

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: visual-verify-loop v2 — design-system as a comparison criterion

**Files:**
- Modify: `plugins/sdd-implementation/skills/visual-verify-loop/SKILL.md` (description line 3; Loop step 3 at lines 43-45; Boundaries)
- Test: `tests/design-system-contract.tests.sh`, `tests/design-system-contract.tests.ps1` (append DS-013)

**Interfaces:**
- Consumes: P0' artifact names; Task 1's advisory/ownership vocabulary.
- Produces: the advisory-vs-deterministic ownership statement (`check-design-system` owns warn/error) that P4' relies on.

- [ ] **Step 1: Append failing DS-013 assertions**

In `tests/design-system-contract.tests.sh`, insert directly before the final three lines:

```sh
# DS-013 visual-verify-loop design-system comparison
VVL="$ROOT/plugins/sdd-implementation/skills/visual-verify-loop/SKILL.md"
assert_contains "$VVL" 'design-system/design-tokens\.json' "DS-013 token conformance in loop"
assert_contains "$VVL" 'design-system/ui-patterns\.md' "DS-013 ui-patterns in loop"
assert_contains "$VVL" 'check-design-system' "DS-013 deterministic gate ownership"
```

In `tests/design-system-contract.tests.ps1`, insert directly before the final line:

```powershell
# DS-013 visual-verify-loop design-system comparison
$vvl = Get-Content -Raw -Encoding Utf8 (Join-Path $repositoryRoot "plugins/sdd-implementation/skills/visual-verify-loop/SKILL.md")
foreach ($needle in @('design-system/design-tokens.json', 'design-system/ui-patterns.md', 'check-design-system')) {
    if ($vvl -notmatch [regex]::Escape($needle)) { throw "not ok: DS-013 missing $needle" }
}
Write-Host "ok: DS-013 visual-verify-loop design-system comparison"
```

- [ ] **Step 2: Run the sh test to verify DS-013 fails**

Run: `sh tests/design-system-contract.tests.sh`
Expected: 53 PASS, 3 FAIL (DS-013), exit 1.

- [ ] **Step 3: Update the description**

In `plugins/sdd-implementation/skills/visual-verify-loop/SKILL.md`, replace line 3 (the `description:` line) with:

```yaml
description: Implementation-phase visual verification loop for UI tasks. Launches the app (Claude Preview MCP for web, wpf-visual-verify for WPF desktop), compares the rendered UI against approved mockups, ux-spec states, and — when the project carries one — the design-system contract (tokens and ui-patterns), iterates fixes up to five times, and saves final screenshots as evidence under reports/visual-evidence/. Non-blocking; verdicts stay with quality-gate and human review.
```

- [ ] **Step 4: Extend Loop step 3 and Boundaries**

Replace Loop step 3:

```markdown
3. Compare against the approved mockups in `specs/<feature>/mockups/` and
   the states defined in the feature's layer specs (default, empty,
   loading, error; responsive breakpoints).
```

with:

```markdown
3. Compare against the approved mockups in `specs/<feature>/mockups/`, the
   states defined in the feature's layer specs (default, empty, loading,
   error; responsive breakpoints), and — when the project carries a
   `design-system/` contract — token conformance against
   `design-system/design-tokens.json` (no raw style values in the rendered
   output's sources) and the conventions in `design-system/ui-patterns.md`
   (actions, dialogs, icons, flow, states).
```

Append one bullet at the end of `## Boundaries`:

```markdown
- Design-system conformance findings here are advisory; the deterministic
  `check-design-system` gate (sdd-quality-loop) owns warn/error enforcement.
```

- [ ] **Step 5: Run both tests to verify they pass**

Run: `sh tests/design-system-contract.tests.sh` — Expected: `FAIL: 0` (56 PASS), exit 0.
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/design-system-contract.tests.ps1` — Expected: ok lines through `ok: DS-013 visual-verify-loop design-system comparison`, exit 0.

- [ ] **Step 6: Commit**

```bash
git add plugins/sdd-implementation/skills/visual-verify-loop/SKILL.md tests/design-system-contract.tests.sh tests/design-system-contract.tests.ps1
git commit -m "feat(implementation): compare against design-system tokens and ui-patterns in visual-verify-loop

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```
