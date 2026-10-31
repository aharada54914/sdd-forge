# Investigation: epic-159-pillar-c (issues #149-#155 — effort routing v2)

Source: issues #149-#155 (epic #159, Pillar C). Investigated: 2026-07-16,
worktree of main (f6b1365 lineage), read-only survey with file:line
evidence (sdd-investigator). Paths cited relative to the repository root.

# SDD Investigation: epic-159 Pillar C (issues #149-#155)

## INV-001: Current agent-model-capabilities Registry (v1) Structure
**File**: `contracts/agent-model-capabilities.json:2-40`

Current v1 schema uses 1:1 "welded" binding of effort to canonical_tier:
- `haiku` (lightweight) → efforts: `["low"]`
- `sonnet` (standard) → efforts: `["medium"]`
- `opus` (strong) → efforts: `["high", "xhigh"]`
- Codex models similarly welded (gpt-5.1-codex-mini→low, gpt-5.1-codex→medium, gpt-5.2-codex→high/xhigh)

This prevents expressions like "sonnet + high effort" without model substitution.

## INV-002: select-agent-model Script Current Consumers
**File**: `plugins/sdd-implementation/scripts/select-agent-model.sh:1-273`

Script is currently **test-only** consumer:
- `tests/agent-model-routing.tests.sh` (structural tests)
- `tests/loop-escalation.tests.sh` (T-011 escalation verification)
- `tests/task-context-isolation.tests.sh`

**No production consumers** in skills or CI workflows yet. The script is available but not wired to actual agent invocation paths in implement-task, quality-gate, or panelist runners.

## INV-003: Claude Agent Model Hardcoding (static v1 bindings)
**File**: `plugins/sdd-quality-loop/agents/evaluator.md:6`

Claude agents hardcode `model:` keys:
- `model: opus` (evaluator)
- Similar hardcoding in investigator.md, reviewer agents

These bypass the routing selector entirely. No per-invocation effort override capability exists for Claude Code.

## INV-004: Codex Agent TOML Role Files (model-unbound)
**Files**: `.codex/agents/sdd-investigator.toml`, `.codex/agents/sdd-evaluator.toml`

Codex roles do NOT hardcode model:
- Runtime receives `--model` and `--effort` via CLI invocation
- Caller (currently run-panelist-gpt.sh, future: quality-gate flow) must supply these flags
- No current `--effort` flag passed; only `--model` used in run-panelist-gpt.sh

## INV-005: run-record v1 Schema (sdd-run-record/v1)
**File**: `plugins/sdd-quality-loop/scripts/emit-run-record.sh:134-154`

Current recording includes:
- `model_ids: {main, reviewers}` — but NO `effort_*` fields
- `track`, `plugin_version`, `active_wfis`, metrics (tasks, gate_reports, review_tickets)

v1 schema cannot measure effort effect: no `effort_requested` or `effort_applied` recording.

## INV-006: Protected Gate Files (R-10 constraint)
**File**: `plugins/sdd-quality-loop/scripts/sdd-hook-guard.py:886-927`

Protected files that CANNOT be agent-edited (even with sudo):
- Hook guard scripts (sdd-hook-guard.{sh,ps1,js,py})
- Gate scripts: check-contract, check-evidence-bundle
- Review loop agents: **plugins/sdd-review-loop/agents/impl-reviewer-a.md, impl-reviewer-b.md, task-reviewer-a.md, task-reviewer-b.md**
- Skill definitions: impl-review-loop/SKILL.md, task-review-loop/SKILL.md

**No generalized `check-*` or `precheck` pattern in suffixes** — only specific named files. The constraint affects agents that need frontmatter updates (issue #151).

## INV-007: Codex Panelist Invocation (Effort Pre-staging)
**File**: `plugins/sdd-quality-loop/scripts/run-panelist-gpt.sh:62-82`

Current state:
- Passes `--model <model>` to codex CLI (line 81: `codex --model "$model"`)
- **No `--effort` flag currently used** — this is the C4 implementation gap
- prepare-panelist-input.sh does not thread effort values
- Effort will be v2-added as new parameter to --effort flow

## INV-008: Codex Agent Invocation Paths (sdd-evaluator/investigator)
**File**: `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md:96-99`

Current documented invocation:
- Claude Code: `sdd-evaluator` subagent (model pre-pinned in .md)
- Codex: shipped `sdd-evaluator` TOML agent from `.codex/agents/` (runtime model supply)

Future (C4): evaluator startup must receive select-agent-model output (model + effort) via CLI flags to `codex` command.

## INV-009: Welded vs. Matrix Mode Definitions
**File**: `gh issue view 150` / `gh issue view 155` (from GitHub API)

- **Welded mode** (default, Phase 1): effort linked to model tier (current v1 behavior)
  - `--effort-policy welded` → ignores risk_effort_matrix, uses canonical tier binding
  - Backward-compatible (byteidentical with current output)
  
- **Matrix mode** (Phase 2): effort selected from risk-driven matrix
  - `--effort-policy matrix` → selects effort from `risk_effort_matrix[risk]` then clamps to model's `supported_efforts`
  - Enables risk-adaptive effort (high-risk high-effort without model escalation)
  - Default flip occurs in issue #155 after phases 1-6 stabilize

## INV-010: Dependencies and Release Strategy (#155 separation)
**File**: `gh issue view 155` (from GitHub API)

Issue #155 (matrix default flip) is marked **single release** with explicit blockers:
- Depends on: #149 (v2 registry), #150 (selector v2), #151 (agent generation), #152 (Codex apply), #153 (run-record v2), #154 (tests), **PLUS** A3 (bug fix for round-2 route)
- Cannot land until all prerequisites merge to main AND A3 bug fix is in place
- Front-loads v2 complexity under wraps (v1 behavior unaffected) before flipping default

## INV-011: Parallel Epic-136 Collision Surface
**File**: `specs/epic-136-phase1-guards/requirements.md` / `tasks.md`

Current guardpoint interaction:
- Epic-136 Phase 1 (R-10 gates) protects impl-reviewer-{a,b}.md, task-reviewer-{a,b}.md
- Epic-159 Pillar C issue #151 must regenerate frontmatter in those same protected files
- Workaround: render to scratchpad, human `cp` deployment (per epic-136 human-copy pattern)
- **No blocker** — R-10 gates exist and human-copy method is proven (epic-136 Phase 1 Done already)

## INV-012: Agent Definition Targets for Registry Generation (#151)
**Files**: 
- Claude side: `plugins/sdd-quality-loop/agents/evaluator.md` (model: opus hardcoded)
- Codex side: `.codex/agents/sdd-investigator.toml`, `.codex/agents/sdd-evaluator.toml`
- Protected reviewers: `plugins/sdd-review-loop/agents/{impl,task}-reviewer-{a,b}.md`

Issue #151 (`render-agent-frontmatter.sh`) will:
- Rewrite `model:` line in Claude .md files from registry
- Add `# x-sdd-model:` / `# x-sdd-effort:` comment lines to Codex .toml files
- Store current values as seeds so initial render is no-op (drift == 0)
- Enforce via CI `--check` (read-only, non-sudo) to detect hand-edits

## INV-013: Effortless Claude Code (Host Degradation)
**File**: `gh issue view 152` (cross-host requirements)

Claude Code currently:
- Has **NO per-invocation effort mechanism** (no --effort CLI flag equivalent)
- Workaround: record effort in frontmatter (`x-sdd-effort:` line) for documentation only
- Effort selection is "planned but inactive" — host awaits native effort support
- Will degrade gracefully: effort_applied=null, effort_degraded_reason="host-no-effort-control"

## INV-014: Panelist Effort Threading Path (C4 gap)
**File**: `plugins/sdd-quality-loop/scripts/run-panelist-gpt.sh`

Missing pieces for C4 (Codex effort apply):
- `--effort <e>` parameter not yet in run-panelist-gpt.sh signature
- prepare-panelist-input.sh does not thread effort from selector output
- codex CLI invocation (line 81) will need `--effort` appended
- Test coverage needed: verify effort flag propagation to codex command

## OQ-001: Schema Projection Risk (v1 → v2)
Issue #149 creates v2 registry but states "v1 is frozen". No doc of:
- Whether v1/v2 coexist or if v2 becomes canonical after Phase 2 flip
- Deprecation timeline for v1 (will old code path be removed?)
- Recommendation: Clarify v2 adoption timeline in PLUGIN-CONTRACTS.md

## OQ-002: Codex Agent File Update Mechanism
Issue #151 describes `# x-sdd-model:` comment generation for .toml files but:
- Does Codex parse these comments at runtime, or are they documentation-only?
- If documentation-only, how does C4 (Codex apply) read the rendered values?
- Recommendation: Verify render output format matches Codex CLI expectation

## OQ-003: Single-Release Assumptions for #155
Issue #155 states "single release" with A3 blocker, but:
- No explicit CI gate preventing #155 merge without A3 in main
- Will require manual hold or branch protection rule setup
- Recommendation: Document or automate the release ordering check

## OQ-004: Effort-Policy Default Transitioning
Issues #150 and #155 use `--effort-policy` flag but:
- Where is DEFAULT stored (hardcoded in selector, or config file)?
- Will there be a deprecation period where welded is still available?
- How will run-record emit warning if effort-policy is not explicitly declared?
- Recommendation: Add implementation detail to #155

---

## Task Breakdown Proposal

**Phase 1 (foundation, no behavior change)**

**T-1** (#149): Agent-model-capabilities v2 registry
- Create `contracts/agent-model-capabilities.v2.json` with `supported_efforts`, `default_effort`, `effort_control`, `risk_effort_matrix`, `role_defaults`
- Add parity tests (v1↔v2 subset check)
- 1-2 days, Sonnet

**T-2** (#150): select-agent-model v2 support
- Auto-detect schema (v1 or v2)
- Add `--effort-policy welded` (default, backward-compat)
- Add `--requested-effort`, `--role`, `--host` flags
- Welded output byte-identical with current (golden baseline)
- 2-3 days, Sonnet

**T-3** (#151): Agent frontmatter generation + drift check
- New `render-agent-frontmatter.sh/.ps1` script
- Update Claude .md `model:` lines from role_defaults
- Add Codex .toml `# x-sdd-model/effort:` comment references
- Protected-file scratchpad workaround for reviewers
- Integrate `--check` into CI + validate-repository
- 2 days, Sonnet

**T-4** (#153): run-record v2 with effort tracking
- Schema: `sdd-run-record/v2` (adds `effort_requested`, `effort_applied`, `effort_degraded_reason`)
- Update emit-run-record.sh/.ps1 with `--effort-*` flags
- Backward-compat: v1 records still valid
- 1 day, Sonnet

**T-5** (#154): Routing test expansion
- Extend agent-model-routing.tests.sh with welded golden + matrix mode cases
- Add v1↔v2 projection tests
- Test role-defaults application, clamp-to-supported, xhigh gate
- 2 days, Sonnet

**T-6** (#152): Codex host effort implementation
- Add `--effort` parameter to run-panelist-gpt.sh/.ps1
- Update prepare-panelist-input.sh to thread effort from selector
- Wire evaluator/investigator startup to receive select-agent-model output
- Test codex CLI command composition
- 2-3 days, Sonnet

---

**Phase 2 (behavior flip, single release)**

**T-7** (#155): Matrix default flip + documentation
- Change selector default from `--effort-policy welded` to `--effort-policy matrix`
- First-time role_defaults frontmatter render (should be no-op if T-3 seeded correctly)
- Update USERGUIDE.md, docs/agent-capability-matrix.md, CHANGELOG.md
- Smoke test: effort_applied appears in run-record for Codex hosts
- **Prerequisite**: A3 (round-2 bug fix) must be in main
- 1 day, Opus (design decision review) + Sonnet (implementation)

---

## Release Strategy for #155

**Single-Release Constraint** (#155 explicit instruction):

1. **Phase 1 complete**: All T-1 through T-6 merged, CI 3-OS green, backward-compat verified
2. **A3 merged**: Bug fix for round-2 evaluation route (no effort measurement on broken path)
3. **Release creation**: Bump version via `scripts/bump-version.sh`, create release notes (WFI effect measurability starts here)
4. **Phase 2 flip**: #155 in separate minor release after Phase 1 stabilizes in production

**Rationale**: Isolating Phase 2 flip as a single release prevents:
- Matrix mode bugs from being mixed with v2 infrastructure bugs
- WFI measurement noise (Phase 1 = setup only, Phase 2 = active measurement)
- Rollback complexity (each phase independently reversible)

---

## Summary of Evidence References

| Finding | File | Lines |
|---------|------|-------|
| INV-001 v1 registry | `contracts/agent-model-capabilities.json` | 2–40 |
| INV-002 select-agent-model | `plugins/sdd-implementation/scripts/select-agent-model.sh` | 1–273 |
| INV-003 Claude hardcoding | `plugins/sdd-quality-loop/agents/evaluator.md` | 6 |
| INV-004 Codex TOML agents | `.codex/agents/sdd-evaluator.toml` | 1–57 |
| INV-005 run-record v1 | `plugins/sdd-quality-loop/scripts/emit-run-record.sh` | 134–154 |
| INV-006 Protected files | `plugins/sdd-quality-loop/scripts/sdd-hook-guard.py` | 886–927 |
| INV-007 Panelist runner | `plugins/sdd-quality-loop/scripts/run-panelist-gpt.sh` | 62–82 |
| INV-008 quality-gate invocation | `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md` | 96–99 |
| INV-009 Welded/Matrix modes | GitHub issue #150, #155 body text | N/A |
| INV-010 #155 dependencies | GitHub issue #155 body text | N/A |
| INV-011 Epic-136 guards | `specs/epic-136-phase1-guards/requirements.md` | N/A |
| INV-012 Agent targets | Multiple .md/.toml files (3 files) | N/A |
| INV-013 Claude degradation | `gh issue 152` (cross-host requirements) | N/A |
| INV-014 Panelist effort gap | `plugins/sdd-quality-loop/scripts/run-panelist-gpt.sh` | signature, line 81 |
