# Requirements: epic-159-pillar-c

Spec-Review-Status: Pending
Source Issues: https://github.com/aharada54914/sdd-forge/issues/149,
https://github.com/aharada54914/sdd-forge/issues/150,
https://github.com/aharada54914/sdd-forge/issues/151,
https://github.com/aharada54914/sdd-forge/issues/152,
https://github.com/aharada54914/sdd-forge/issues/153,
https://github.com/aharada54914/sdd-forge/issues/154,
https://github.com/aharada54914/sdd-forge/issues/155
Epic: https://github.com/aharada54914/sdd-forge/issues/159 (Pillar C — effort
routing v2; Phase 1 = #149-154, Phase 2 = #155 single release)
Investigation: specs/epic-159-pillar-c/investigation.md (INV-001..INV-014,
OQ-001..OQ-004)

## Overview

The current agent-model-capabilities registry welds effort 1:1 to canonical
tier (`haiku`→`low`, `sonnet`→`medium`, `opus`→`high`; INV-001:
`contracts/agent-model-capabilities.json:2-40`), so "sonnet at high effort"
cannot be expressed and no per-invocation effort control exists for either
host (INV-003, INV-004). This feature introduces a v2 registry that
separates effort from tier, threads that separation through the selector,
agent definitions, the Codex invocation path, and the run-record schema —
all while Phase 1 (T-001..T-006) preserves today's `welded` behavior
byte-for-byte — and defers the actual default-policy flip to a dedicated,
single-release task (T-007/#155) gated on Phase 1 plus an already-landed
round-2 bug fix (A3; INV-010).

Seven issues, seven tasks, landed in the dependency-respecting issue order
the epic itself specifies (INV-010; investigation.md Task Breakdown
Proposal): T-001=#149 (v2 registry + parity tests), T-002=#150 (selector v2
flags), T-003=#151 (agent-definition generation + CI drift check),
T-004=#153 (run-record v2 effort tracking), T-005=#154 (routing test
expansion), T-006=#152 (Codex host effort real-application), T-007=#155
(Phase 2 default flip, separate release). T-004 and T-005 depend only on
T-001/T-002; T-006 additionally depends on T-003 (the rendered `.toml`
reference values T-006 cross-checks); T-007 depends on all of T-001..T-006
plus A3. This ordering matches both the issues' own stated dependencies (C1,
C2, C3 notation in each issue body) and investigation.md's task numbering
(T-1..T-7).

## Target Users

- Registry maintainers who need `contracts/agent-model-capabilities.v2.json`
  to express independent tier/effort combinations without breaking any v1
  consumer (INV-001, INV-002 — the selector is currently a test-only
  consumer with no production wiring).
- `select-agent-model` callers (currently tests only, per INV-002; future
  production callers per T-006) who need `--effort-policy`,
  `--requested-effort`, `--role`, and `--host` to compose predictably with
  the existing risk/escalation/cost-tiebreak logic already implemented in
  `plugins/sdd-implementation/scripts/select-agent-model.sh:90-273`.
- Maintainers of Claude `.md` agent definitions and Codex `.toml` role files
  who currently hand-edit hardcoded `model:` lines (INV-003:
  `plugins/sdd-quality-loop/agents/evaluator.md:6`) and need a
  registry-generated, drift-checked single source of truth instead.
- WFI effect-measurement stakeholders who need `effort_requested` /
  `effort_applied` / `effort_degraded_reason` in run records (INV-005:
  today's `sdd-run-record/v1` schema at
  `plugins/sdd-quality-loop/scripts/emit-run-record.sh:134-154` has no
  effort fields at all) to have any effort-vs-outcome signal to measure.
- Codex-host operators, whose CLI is the only host that can currently accept
  an `--effort` flag (INV-004, INV-007) — today
  `plugins/sdd-quality-loop/scripts/run-panelist-gpt.sh:146` passes only
  `--model`, never `--effort`.
- Claude Code hosts and their users, who have no per-invocation effort
  mechanism at all (INV-013) and must see this recorded as an explicit,
  reviewable degradation rather than a silently-ignored request.
- Release engineers responsible for sequencing T-007/#155 as a separate,
  gated release after Phase 1 stabilizes (INV-010, Release Strategy).

## Problems

- The v1 registry's 1:1 tier→effort welding (INV-001) makes "sonnet + high"
  or "opus + medium" inexpressible, blocking any risk-driven effort
  assignment that does not also force a model-tier escalation.
- `select-agent-model.sh`/`.ps1` has no effort-policy concept beyond a
  tiebreak field (`efforts = {"": 0, "low": 0, "medium": 1, "high": 2,
  "xhigh": 3}` used only inside the eligibility filter and sort key,
  `select-agent-model.sh:110,232-247`); it cannot select an effort
  independently of the winning model's own welded value.
- Claude `.md` agent definitions hardcode `model:` (INV-003) and Codex
  `.toml` role files carry no model/effort reference at all (verified:
  `.codex/agents/sdd-evaluator.toml` contains only `name`, `description`,
  `sandbox_mode`, and `developer_instructions` — no model or effort field of
  any kind), so neither host has a single generated source of truth, and two
  of the four Claude-side edit targets
  (`plugins/sdd-review-loop/agents/impl-reviewer-a.md`,
  `impl-reviewer-b.md`, `task-reviewer-a.md`, `task-reviewer-b.md`) are R-10
  protected gate files an agent cannot write directly (INV-006:
  `plugins/sdd-quality-loop/scripts/sdd-hook-guard.py:886-927`, confirmed at
  lines 906-910 of that file).
- `sdd-run-record/v1` (INV-005) has no `effort_*` field, so no run record
  can express what effort was requested, whether it was actually applied,
  or why it degraded on a host that cannot apply it.
- `tests/agent-model-routing.tests.sh` has no `.ps1` twin today — verified:
  `tests/run-all.sh:25` registers only the `.sh` suite; neither
  `tests/run-all.ps1` nor `.github/workflows/test.yml` registers any
  `agent-model-routing` suite, and no
  `tests/agent-model-routing.tests.ps1` file exists in `tests/`. The
  repository-wide `.sh`/`.ps1` twin convention (every issue's own "共通検証基準"
  block) is currently unmet for this suite.
- `run-panelist-gpt.sh` (INV-007, INV-014) never passes `--effort` to the
  `codex` CLI (verified invocation site: `run-panelist-gpt.sh:146`,
  `"$_codex_cmd" --model "$model" --no-project-doc ...`), and
  `prepare-panelist-input.sh` has no effort-threading parameter; the
  Codex-host evaluator/investigator startup paths documented at
  `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md:96-99` likewise
  never supply a selector-derived effort value to the `codex` CLI.
- Claude Code has categorically no per-invocation effort mechanism
  (INV-013): any effort value recorded for a Claude Code run today can only
  ever be documentation, never an applied setting, and nothing currently
  distinguishes "effort intentionally not applicable on this host" from
  "effort silently dropped."
- Issue #155's Phase 2 flip has an explicit prerequisite (A3, the round-2
  evaluation-route bug fix) but no automated CI gate enforces the ordering
  (OQ-003 in investigation.md): a same-PR or premature merge of the default
  flip ahead of that fix landing is possible today.

## Goals

- REQ-001 (T-001, issue #149; INV-001): Create
  `contracts/agent-model-capabilities.v2.json` (schema
  `agent-model-capabilities/v2`). Each model entry carries
  `supported_efforts` (a non-empty array, superseding v1's single-element
  `efforts` list), `default_effort` (a member of `supported_efforts`), and
  `effort_control` (a per-host map — `claude-code` and `codex-cli` keys,
  each one of `flag` / `frontmatter` / `none`). A top-level
  `risk_effort_matrix` maps `low`→`low`, `medium`→`medium`, `high`→`high`,
  `critical`→`high`, and carries `escalation_bump: true` (on a
  same-classified-failure-twice escalation event, per
  `select-agent-model.sh:155-184`'s existing `escalation_tier` logic, the
  matrix-selected effort is raised one step, still clamped to the winning
  model's `supported_efforts` and still gated by `--xhigh-reason` if the
  bump would land on `xhigh` — REQ-002). `xhigh` never appears as a direct
  `risk_effort_matrix` output value — only as an explicit-override or
  escalation-bump result, preserving the existing `--xhigh-reason` gate
  (`select-agent-model.sh:237`). A top-level `role_defaults` maps
  `spec-reviewer`, `impl-reviewer`, `task-reviewer`, `sdd-evaluator`, and
  `sdd-investigator` each to a minimum tier and a default effort. The v1
  file (`contracts/agent-model-capabilities.json`) is frozen — byte-identical
  before and after this feature. `tests/agent-capabilities-v2.tests.sh`/`.ps1`
  (new twin pair) locks a two-directional parity invariant: every v1 model
  name exists in v2 with the identical `canonical_tier`, and every v1
  model's single-element `efforts` value is a member of that model's v2
  `supported_efforts`. `PLUGIN-CONTRACTS.md` gains a new documented section
  for the v2 schema (verified: no `agent-model-capabilities` schema section
  exists there today — a repository-wide grep for the string returns no
  match). Refreshing model entries to their current generation is
  explicitly deferred (issue #149 body: "モデルエントリの現行世代への刷新は
  D3 で実施") — v2 may start with the same model names/generations as v1.
- REQ-002 (T-002, issue #150; INV-002, INV-009): `select-agent-model.sh`/`.ps1`
  (`plugins/sdd-implementation/scripts/select-agent-model.sh:1-273`;
  `select-agent-model.ps1`, 216 lines, verified present as an existing
  twin) auto-detects the registry schema (`agent-model-capabilities/v1` vs.
  `/v2`) from the `--registry` file's `schema` field. Against a v1
  registry, behavior — including the legacy positional `--candidate
  name:tier:cost` syntax (`select-agent-model.sh:220-230`) — is unchanged,
  byte-for-byte. Four new flags: `--effort-policy welded|matrix` (default
  `welded` for the duration of Phase 1 — REQ-007 changes only the default,
  in a separate release); `--requested-effort <e>` (explicit override,
  still clamped to the winning model's `supported_efforts` and still
  requiring `--xhigh-reason` for `xhigh`, per the existing gate at
  `select-agent-model.sh:237`); `--role <role>` (seeds `--minimum-tier` and
  a default effort from v2 `role_defaults`); `--host claude-code|codex-cli`
  (default `claude-code`; resolves the winning model's `effort_control` for
  that host and surfaces it in JSON output). `welded` mode reproduces
  today's v1-equivalent effort selection exactly — this is the byte-identical
  golden baseline REQ-005/T-005 locks. `matrix` mode selects an effort from
  `risk_effort_matrix[risk]`, applies the escalation bump when an escalation
  event fires, and clamps the result to the winning model's
  `supported_efforts`. JSON output gains two new keys, additively:
  `effort_source` (`risk-matrix` / `requested` / `model-default` /
  `welded`) and `effort_control`; every existing key
  (`model`, `canonical_tier`, `effort`,
  `estimated_cost_per_attempt_usd`, `available_candidates`, `xhigh_reason`,
  `escalation`) is unchanged in name, type, and semantics. A v2
  `--candidates-file` entry may omit its `effort` field (the selector fills
  it from policy); a v1 `--candidates-file` still requires `effort` present,
  matching today's `select-agent-model.sh:204-218` validation.
- REQ-003 (T-003, issue #151; INV-003, INV-004, INV-006, INV-011, INV-012;
  OQ-002): A new `render-agent-frontmatter.sh`/`.ps1` script. Claude path:
  rewrites the `model:` frontmatter line (only that line) in each
  role-mapped `.md` agent file from v2 `role_defaults`, and inserts/refreshes
  an `x-sdd-effort: <e>` frontmatter comment line recording the effort value
  — inert as an applied setting on Claude Code today (REQ-008), record-only
  until the host gains native effort control. Codex path: writes
  `# x-sdd-model: <m>` / `# x-sdd-effort: <e>` reference comment lines into
  each role-mapped `.codex/agents/*.toml` file. These comments are
  documentation-only markers, not a Codex-CLI-parsed configuration surface
  (OQ-002 resolution): verified directly against
  `.codex/agents/sdd-evaluator.toml`, which today carries no model- or
  effort-related field of any kind (only `name`, `description`,
  `sandbox_mode`, `developer_instructions`) — the actual runtime application
  happens exclusively via CLI `--model`/`--effort` flags a caller script
  supplies (REQ-006), and the rendered comments exist so that caller script
  can cross-check its own selector-derived values against the registry's
  last-rendered reference (AC-038). A `--check` mode (read-only, no write,
  no sudo) detects drift between rendered targets and current
  `role_defaults`; it is wired into CI and into the repository-wide
  validation surface (`tests/validate-repository.ps1`,
  `tests/workflow-documentation.tests.sh`'s skill-reference count sync).
  `role_defaults` is seeded from the CURRENT hardcoded values (e.g.
  `evaluator.md:6`'s `model: opus`) so the first real render against
  production files is a zero-diff no-op — no behavior changes on landing.
  Agents whose Claude definition sets `model: inherit` or that are absent
  from the role→agent-file map (e.g., the Claude-side panelist agents) are
  excluded from render targets. **Protected-reviewer procedure**: the four
  R-10 protected Claude review-loop agent files
  (`plugins/sdd-review-loop/agents/impl-reviewer-a.md`, `impl-reviewer-b.md`,
  `task-reviewer-a.md`, `task-reviewer-b.md` — confirmed present in
  `_PROTECTED_GATE_SUFFIXES`, `sdd-hook-guard.py:906-910`) are never written
  directly by the render script or by any agent. `render-agent-frontmatter`
  instead renders the corrected file content to
  `specs/epic-159-pillar-c/human-copy/<basename>` plus a SHA-256 manifest
  entry (the epic-136 human-copy pattern, INV-011), and a human maintainer
  runs the `cp` themselves. The read-only `--check` mode is unaffected by
  this restriction — it may compare rendered content against these four
  files' on-disk content and run unattended in CI, because comparison is
  not a write.
- REQ-004 (T-004, issue #153; INV-005): `emit-run-record.sh`/`.ps1`
  (`plugins/sdd-quality-loop/scripts/emit-run-record.sh:134-154`) gains
  `--effort-main` / `--effort-reviewers` / `--effort-applied-main` /
  `--effort-applied-reviewers` flags. The record schema becomes
  `sdd-run-record/v2`, adding exactly three new fields per role slot
  (main/reviewers) — `effort_requested`, `effort_applied`,
  `effort_degraded_reason` — additively; every v1 field
  (`model_ids`, `track`, `plugin_version`, `active_wfis`, `metrics.*`) is
  unchanged. `effort_requested` is always recorded whenever an
  `--effort-*` flag is supplied. `effort_applied` carries a value only when
  the winning model's `effort_control` for the invoking host resolves to
  `flag` AND the effort was actually applied (Codex host, REQ-006); in
  every other case (`frontmatter` or `none` control, or Claude Code's
  categorical absence of an effort mechanism — REQ-008) `effort_applied` is
  `null` and `effort_degraded_reason` records the specific reason (e.g.
  `"host-no-effort-control"`). `effort_degraded_reason` is populated if and
  only if `effort_applied` is `null` and an `--effort-*` flag was supplied
  (no vacuous reason field when effort tracking was not requested at all).
  v1 records remain valid under the same validator — no migration, schema
  distinguished by the `schema` field alone.
  `implementation-report.template.md` gains `- Model:` / `- Effort:` lines,
  validated present-and-format-only by
  `validate-implementation-report.sh` (no value-correctness check, matching
  that validator's existing scope). The quality-gate process
  (`plugins/sdd-quality-loop/skills/quality-gate/SKILL.md`) gains the same
  two-line requirement for its own gate reports as a documented Process
  instruction — verified there is no separate quality-gate report template
  file to edit (`reports/quality-gate/*.md` files are freely-authored
  Markdown per SKILL.md's Process instructions, not rendered from a
  template; the only template SKILL.md references is
  `templates/verification-contract.template.json`, SKILL.md:34).
  `tests/emit-run-record-feature-scope.tests.sh`/`.ps1` is extended to cover
  the new fields.
- REQ-005 (T-005, issue #154; INV-002's twin gap): Author
  `tests/agent-model-routing.tests.ps1` as a NEW file (closing the twin gap
  the Problems section documents) alongside extending
  `tests/agent-model-routing.tests.sh`. Cases, on both twins: (a) v2
  registry auto-detection; (b) `--effort-policy welded` (the default)
  produces output byte-identical to the pre-feature selector's output
  against an unchanged fixture — a golden baseline — with a mutation-based
  negative self-check proving the assertion is live (mutate the golden
  fixture and confirm the comparison goes red); (c) `--effort-policy
  matrix --risk high --required-tier standard` selects `sonnet` at `high`
  effort; (d) a matrix-selected effort outside the winning model's
  `supported_efforts` clamps to the nearest supported value; (e) `xhigh`
  remains gated by `--xhigh-reason` under matrix mode, including on an
  escalation bump that would otherwise land on `xhigh`; (f) the existing
  `terminal-tier-recurrence` output (`select-agent-model.sh:163-183`) is
  byte-unchanged; (g) `--role sdd-evaluator` enforces the `strong` tier
  floor from `role_defaults`; (h) v1↔v2 projection invariants (may share
  fixtures with REQ-001's parity suite, per issue #154's own "C1 のテストと
  統合可" note, but is asserted as this suite's own case regardless).
- REQ-006 (T-006, issue #152; INV-007, INV-008, INV-014): `run-panelist-gpt.sh`
  gains an `--effort <e>` parameter, forwarded to the `codex` CLI invocation
  alongside the existing `--model` flag (today's sole invocation site:
  `run-panelist-gpt.sh:146`). `prepare-panelist-input.sh`/`.ps1` threads a
  selected effort value from `select-agent-model --host codex-cli` output
  through to the panelist runner. The Codex-host evaluator and investigator
  startup paths documented at
  `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md:96-99` are wired —
  in skill instructions and any startup script this task adds — to supply
  the selector's model+effort output as CLI flags to the `codex` command
  used to launch the shipped `sdd-evaluator`/`sdd-investigator` `.toml`
  agents. A cross-check compares REQ-003's rendered `.toml` reference
  comments against the live selector output at invocation time (detecting
  drift between "last rendered" and "currently selected," not merely
  applying one or the other silently). Claude Code invocation paths degrade
  explicitly per REQ-008 (frontmatter-recorded only,
  `effort_applied=null` + `effort_degraded_reason` in the resulting run
  record). Verification is command-composition-level (the assembled `codex`
  argv is asserted to contain the expected `--model`/`--effort` pair) — no
  live LLM invocation is required or performed by any test in this task.
- REQ-007 (T-007, issue #155; INV-009, INV-010, INV-011; OQ-003): Flip
  `select-agent-model`'s `--effort-policy` default from `welded` to
  `matrix`. Perform the first production `role_defaults` frontmatter render
  against real files, expecting a zero diff (REQ-003 seeded `role_defaults`
  from current values specifically so this render is a no-op); if a
  non-zero diff appears, its cause is investigated and recorded rather than
  silently applied. Update `USERGUIDE.md`, `docs/agent-capability-matrix.md`,
  and `CHANGELOG.md` to describe the now-default matrix policy. A smoke
  check confirms `effort_applied` appears (non-null) in a real Codex-host
  run record after the flip. **Prerequisite gate**: T-007 may not merge
  until (a) T-001 through T-006 (REQ-001..006) are all merged to `main`,
  and (b) A3 — the round-2 evaluation-route bug fix INV-010 names as a
  blocker — is present in `main`. A3 is identified as commit
  `2d8c6a561e0f5d2bc29ded4195c057d4cc918f2f` ("fix: unblock impl review
  rounds after the first (#143)"), which `git merge-base --is-ancestor
  2d8c6a5 HEAD` confirms is ALREADY an ancestor of this spec's HEAD
  (`f6b1365`) at spec-authoring time — recorded in Assumptions below,
  re-verified at T-007 implementation time (the gate is a documented
  procedure, not yet an automated CI check — OQ-003 in investigation.md
  remains open at the automation level; see Open Questions). **T-007 lands
  as a separate PR and a separate release from T-001..T-006** — the Main
  Workflows section states this explicitly so no implementation session
  bundles it into the Phase 1 PR(s).
- REQ-008 (cross-host requirement, all seven issues' shared "共通検証基準"
  block; INV-013): Claude Code has categorically no per-invocation effort
  control (INV-013). Every surface in REQ-001..007 that touches effort must
  record this as an explicit, reviewable degradation on Claude Code —
  `effort_applied=null` plus a populated `effort_degraded_reason` (REQ-004)
  — never a silent no-op and never a test/feature failure purely because
  Claude Code lacks the capability. Codex hosts (`effort_control: flag`)
  apply effort for real via CLI flags (REQ-006). No task in this feature is
  Done without demonstrating both hosts' behavior: real application on
  Codex, explicit recorded degradation on Claude Code.
- REQ-009 (doc-following and version-bump, all seven issues' shared
  boilerplate): each of T-001..T-006's PR(s) updates, in the SAME PR, every
  applicable document among `README.md`, `USERGUIDE.md`,
  `docs/workflow-guide.md`, `docs/skill-reference.md`,
  `docs/agent-capability-matrix.md`, `PLUGIN-CONTRACTS.md`,
  `docs/troubleshooting.md`, `docs/contributor/*`; adds a `CHANGELOG.md`
  `## Unreleased` entry citing its own issue number (#149/#150/#151/#153/
  #154/#152, one per task); and keeps `tests/validate-repository.ps1` and
  the skill-reference count sync (`tests/workflow-documentation.tests.sh`)
  green. Any release version bump goes exclusively through
  `scripts/bump-version.sh` (the same rule
  `specs/epic-159-pillar-a/requirements.md:164-173` (REQ-006) and
  `specs/epic-159-pillar-b/requirements.md:101-110` (REQ-003) already
  state). T-007/#155's default-flip release (REQ-007) is its OWN,
  separately-sequenced release event — not folded into T-001..T-006's
  version bump.

## Non-goals

- Refreshing registry model entries to their current generation (e.g.
  updating `gpt-5.2-codex`/`gpt-5.1-codex-max` naming or adding newer
  models): issue #149's own body defers this to a task labeled "D3,"
  outside this epic's task list; v2 may start with v1's exact model set.
- Rewriting or replacing the `codex` CLI's own argument handling, or
  teaching it to parse TOML comments: REQ-003's rendered comments are a
  reference surface for THIS repository's own caller scripts (REQ-006), not
  a Codex-CLI-consumed configuration format (OQ-002 resolution).
- The broader "risk-adaptive release gating" work
  (`specs/risk-adaptive-layer/`): unrelated scope, not touched here.
- Making `--effort-policy matrix` the default anywhere in T-001..T-006:
  Phase 1 is behavior-preserving by construction; only T-007/#155, a
  separate release, changes the default (REQ-002, REQ-007).
- Building an automated CI gate that mechanically blocks T-007/#155 from
  merging before A3 and T-001..T-006 land: OQ-003 records this as an open,
  non-blocking automation gap; REQ-007 satisfies the prerequisite as a
  documented procedure plus a verified-at-spec-time fact (2d8c6a5 already
  in `main`), not as a new CI mechanism.
- Editing any protected gate file directly (`_PROTECTED_GATE_SUFFIXES`,
  `sdd-hook-guard.py:886-927`): REQ-003's four protected reviewer targets go
  through the scratchpad + human-copy procedure exclusively.
- Modifying `tests/gates.tests.sh`, `tests/eval.tests.sh`,
  `tests/guard-parity.tests.sh`, or `tests/constant-parity.tests.sh`.
- tasks.md and traceability.md (Phase 2 artifacts, authored after spec
  approval).

## User Stories

As a registry maintainer, I can express "sonnet at high effort" or "opus at
medium effort" in `contracts/agent-model-capabilities.v2.json` without
touching the frozen v1 file or breaking any v1 consumer. As a
`select-agent-model` caller, I can request `--effort-policy matrix
--risk high` and get a risk-driven effort that still respects tier,
clamping, and the `xhigh` justification gate — or I can omit the flag
entirely during Phase 1 and get today's exact `welded` output. As a
maintainer of Claude and Codex agent definitions, I run
`render-agent-frontmatter.sh --check` and know immediately whether any
agent file has drifted from the registry, without ever needing sudo or a
protected-file bypass — and for the four protected reviewer files, I copy a
pre-rendered, SHA-256-manifested correction myself. As a WFI
effect-measurement stakeholder, I can query a run record and see exactly
what effort was requested, whether it was actually applied, and why it
degraded when it was not. As a Codex-host operator, my evaluator and
investigator invocations actually receive the selector's chosen effort on
the CLI. As a Claude Code user, I see an honest, explicit
`effort_degraded_reason` instead of a silently-ignored request. As a release
engineer, I know T-007/#155's matrix-default flip cannot land before its
prerequisites — A3 and all of T-001..T-006 — are in `main`, and that it
ships as its own release.

## Acceptance Criteria

- AC-001: `contracts/agent-model-capabilities.v2.json` exists with `schema:
  "agent-model-capabilities/v2"`; every model entry carries a non-empty
  `supported_efforts` array, a `default_effort` that is a member of
  `supported_efforts`, and an `effort_control` map with `claude-code` and
  `codex-cli` keys each one of `flag`/`frontmatter`/`none`. (REQ-001)
- AC-002: `risk_effort_matrix` maps exactly `low`→`low`, `medium`→`medium`,
  `high`→`high`, `critical`→`high`, carries `escalation_bump: true`, and
  never yields `xhigh` as a direct (non-escalated, non-override) output.
  (REQ-001)
- AC-003: `role_defaults` carries an entry for each of `spec-reviewer`,
  `impl-reviewer`, `task-reviewer`, `sdd-evaluator`, `sdd-investigator`,
  each with a minimum tier and a default effort. (REQ-001)
- AC-004: `contracts/agent-model-capabilities.json` (v1) is byte-identical
  before and after this feature (SHA-256 comparison); the two-directional
  parity suite (`tests/agent-capabilities-v2.tests.sh`/`.ps1`) asserts every
  v1 model name exists in v2 with the same `canonical_tier` and every v1
  model's `efforts` value is a member of its v2 `supported_efforts`, with a
  negative self-check (a mutated v2 fixture that removes a v1 effort from
  `supported_efforts`) proving the assertion is live. (REQ-001)
- AC-005: `PLUGIN-CONTRACTS.md` documents the `agent-model-capabilities/v2`
  schema in a new section. (REQ-001)
- AC-006: `select-agent-model.sh`/`.ps1`, given a v1 `--registry` file
  (including the legacy positional `--candidate name:tier:cost` form),
  produces output byte-identical to its pre-feature behavior against a
  fixed fixture set. (REQ-002)
- AC-007: Given a v2 registry and no `--effort-policy` flag (or explicit
  `--effort-policy welded`), output is byte-identical to the pre-feature
  selector's output against the same fixture set — the Phase 1 golden
  baseline; a mutation-based negative self-check (an intentionally altered
  golden fixture) proves the comparison is live, not vacuous. (REQ-002)
- AC-008: `--effort-policy matrix --risk high --required-tier standard`
  against the v2 registry selects `sonnet` at `high` effort. (REQ-002)
- AC-009: A matrix-selected effort outside the winning model's
  `supported_efforts` clamps to the nearest supported value; `xhigh` remains
  reachable only via `--xhigh-reason`, including via an escalation-bumped
  matrix selection. (REQ-002)
- AC-010: `--requested-effort <e>` overrides the policy-selected effort,
  still clamped to `supported_efforts` and still requiring `--xhigh-reason`
  for `xhigh`. (REQ-002)
- AC-011: `--role <role>` seeds `--minimum-tier` and a default effort from
  v2 `role_defaults` for that role. (REQ-002)
- AC-012: `--host claude-code|codex-cli` (default `claude-code`) resolves
  the winning model's `effort_control` for that host into the JSON output's
  new `effort_control` key; the new `effort_source` key
  (`risk-matrix`/`requested`/`model-default`/`welded`) is present and
  correctly attributed per case; every pre-existing JSON key is unchanged in
  name and type. (REQ-002)
- AC-013: A v2 `--candidates-file` entry may omit `effort` (the selector
  fills it); a v1 `--candidates-file` still requires `effort` present and
  rejects its absence exactly as today. (REQ-002)
- AC-014: `render-agent-frontmatter.sh`/`.ps1` rewrites only the `model:`
  frontmatter line and inserts/refreshes an `x-sdd-effort: <e>` line in each
  role-mapped, unprotected Claude `.md` agent file, sourced from v2
  `role_defaults`. (REQ-003)
- AC-015: The same script writes `# x-sdd-model: <m>` / `# x-sdd-effort:
  <e>` reference comment lines into each role-mapped `.codex/agents/*.toml`
  file. (REQ-003)
- AC-016: `--check` mode performs no write, detects drift between rendered
  targets and current `role_defaults`, exits non-zero on drift, and is
  wired into CI and into `tests/validate-repository.ps1`. (REQ-003)
- AC-017: The first render against current production files (seeded
  `role_defaults`) produces a zero diff on every unprotected target.
  (REQ-003)
- AC-018: Agents with `model: inherit` or absent from the role→file map
  (Claude-side panelist agents) are not touched by any render. (REQ-003)
- AC-019: The four protected reviewer `.md` files are never written
  directly by `render-agent-frontmatter`; corrected content is staged under
  `specs/epic-159-pillar-c/human-copy/` with a SHA-256 manifest entry per
  file, for a human to `cp` into place. (REQ-003)
- AC-020: `--check` mode may run unattended in CI against the four protected
  files (read comparison only) without triggering the R-10 guard, verified
  by a CI run that includes the protected paths in its `--check` scope and
  exits based on drift status alone. (REQ-003)
- AC-021: `emit-run-record.sh`/`.ps1` emits `schema: "sdd-run-record/v2"`
  when any `--effort-*` flag is supplied, adding `effort_requested`,
  `effort_applied`, `effort_degraded_reason` per role slot (main/reviewers)
  additively; every v1 field is unchanged in name, type, and value
  semantics. (REQ-004)
- AC-022: `effort_requested` is recorded whenever its corresponding
  `--effort-*` flag is supplied, regardless of host or application outcome.
  (REQ-004)
- AC-023: `effort_applied` carries a value if and only if the winning
  model's `effort_control` for the invoking host is `flag` and the effort
  was actually applied; otherwise it is `null`. (REQ-004)
- AC-024: `effort_degraded_reason` is populated if and only if
  `effort_applied` is `null` and an `--effort-*` flag was supplied for that
  slot. (REQ-004)
- AC-025: A pre-feature `sdd-run-record/v1` record validates successfully
  under the post-feature validator, unchanged. (REQ-004)
- AC-026: `implementation-report.template.md` gains `- Model:` / `- Effort:`
  lines, checked present-and-format-only by
  `validate-implementation-report.sh`; the quality-gate SKILL.md Process
  section documents the same two-line requirement for gate reports.
  (REQ-004)
- AC-027: `tests/agent-model-routing.tests.ps1` exists as a new file,
  closing the twin gap; both `tests/agent-model-routing.tests.sh` and the
  new `.ps1` are registered in `tests/run-all.sh`/`.ps1` and
  `.github/workflows/test.yml`. (REQ-005)
- AC-028: Both twins assert the AC-007 welded-golden byte-identical output
  and its negative self-check. (REQ-005)
- AC-029: Both twins assert `--effort-policy matrix --risk high
  --required-tier standard` selects `sonnet` at `high` effort. (REQ-005)
- AC-030: Both twins assert the AC-009 clamp behavior. (REQ-005)
- AC-031: Both twins assert `xhigh` remains `--xhigh-reason`-gated under
  matrix mode, including on an escalation bump. (REQ-005)
- AC-032: Both twins assert the existing `terminal-tier-recurrence` output
  (`select-agent-model.sh:163-183`) is byte-unchanged. (REQ-005)
- AC-033: Both twins assert `--role sdd-evaluator` enforces the `strong`
  tier floor. (REQ-005)
- AC-034: Both twins assert the v1↔v2 projection invariants (may reuse
  REQ-001's parity fixtures). (REQ-005)
- AC-035: `run-panelist-gpt.sh`/`.ps1` accepts `--effort <e>` and forwards
  it to the `codex` CLI invocation alongside `--model`. (REQ-006)
- AC-036: `prepare-panelist-input.sh`/`.ps1` threads a selector-derived
  effort value through to `run-panelist-gpt`'s `--effort` argument. (REQ-006)
- AC-037: The Codex-host evaluator/investigator startup path supplies
  `select-agent-model --host codex-cli` output (model + effort) as CLI
  flags to the launching `codex` command. (REQ-006)
- AC-038: A cross-check compares REQ-003's rendered `.toml` reference
  comments against the live selector output at invocation time and reports
  a distinguishable result when they diverge (drift is detectable, not
  silently overridden either direction). (REQ-006)
- AC-039: On Claude Code, the same invocation paths record
  `effort_applied=null` + a populated `effort_degraded_reason` in the
  resulting run record, never a silent drop. (REQ-006, REQ-008)
- AC-040: All REQ-006 assertions are provable via assembled `codex` argv
  inspection; no test in this task invokes a real LLM. (REQ-006)
- AC-041: `select-agent-model`'s `--effort-policy` default is `matrix`
  after T-007 lands (no flag needed to get matrix behavior). (REQ-007)
- AC-042: The first production `role_defaults` frontmatter render after the
  flip is asserted zero-diff; a non-zero diff is documented with its cause
  in the T-007 implementation report rather than silently accepted.
  (REQ-007)
- AC-043: `USERGUIDE.md`, `docs/agent-capability-matrix.md`, and
  `CHANGELOG.md` describe the matrix-default policy. (REQ-007)
- AC-044: A smoke check against a real Codex-host run shows a non-null
  `effort_applied` in the resulting run record. (REQ-007)
- AC-045: T-007's implementation report records that (a) T-001..T-006 are
  merged to `main` and (b) commit `2d8c6a561e0f5d2bc29ded4195c057d4cc918f2f`
  (A3) is an ancestor of the release commit, re-verifying the fact already
  confirmed at spec-authoring time. (REQ-007)
- AC-046: T-007/#155 is submitted as its own PR, separate from any
  T-001..T-006 PR, and is not bundled into the same version-bump release as
  Phase 1. (REQ-007, REQ-009)
- AC-047: Every effort-consuming surface added by REQ-001..007 has a
  demonstrated Claude Code degradation case (AC-024, AC-039) — none is
  Done with only a Codex-host demonstration. (REQ-008)
- AC-048: No suite or feature in this epic fails, errors, or is marked
  incomplete solely because Claude Code lacks a native effort mechanism —
  every such case resolves to a recorded, non-null
  `effort_degraded_reason` and a passing (not failing) test outcome.
  (REQ-008)
- AC-049: Each of T-001..T-006's PR(s) updates all applicable documents from
  the REQ-009 list in the same PR and adds/extends a `CHANGELOG.md`
  `## Unreleased` entry citing its own issue number; `validate-repository`
  and the skill-reference count sync stay green after each task. (REQ-009)
- AC-050: No version bump occurs anywhere in this feature's history outside
  `scripts/bump-version.sh`; T-007/#155's release is sequenced as its own,
  separate `scripts/bump-version.sh` invocation, distinct from any
  T-001..T-006 release. (REQ-009)

## Field Definitions

- `welded` (REQ-002; issue #150 body) — the Phase 1 default `--effort-policy`
  value: effort selection reproduces today's v1 tier-welded behavior
  byte-for-byte, regardless of whether the invoked registry is v1 or v2.
- `matrix` (REQ-002, REQ-007; issue #150/#155 bodies) — the Phase 2
  `--effort-policy` value: effort is selected from
  `risk_effort_matrix[risk]`, escalation-bumped one step when an escalation
  event fires, then clamped to the winning model's `supported_efforts`.
  Never the Phase 1 default; becomes the default only after T-007/#155.
- `effort_control` (REQ-001, REQ-002, REQ-004, REQ-006, REQ-008) — a
  per-host classification on each v2 model entry: `flag` (the host accepts
  a CLI effort argument the caller can apply — Codex today), `frontmatter`
  (the host can only record effort as documentation — Claude Code today),
  or `none` (the model/host pairing has no effort concept at all).
- `role_defaults` (REQ-001, REQ-003) — the v2 registry's per-role minimum
  tier + default effort table, consumed both by `--role` (REQ-002) and by
  `render-agent-frontmatter` (REQ-003) as the single source of truth for
  what each generated agent-definition file should contain.
- `human-copy procedure` (REQ-003; epic-136 precedent, INV-011) — the
  established workaround for R-10 protected files: an agent renders
  corrected content to a scratchpad location under
  `specs/epic-159-pillar-c/human-copy/` with a SHA-256 manifest, and only a
  human maintainer copies it into the protected path. `--check` (read-only)
  is exempt from this restriction because it performs no write.
- `Phase 1` / `Phase 2` (all REQs) — Phase 1 is T-001..T-006, behavior
  additive/unchanged (`welded` remains default); Phase 2 is T-007/#155
  alone, the single task that changes the default and therefore ships as
  its own release (REQ-007, REQ-009).

## Roles and Permissions

- Agent: authors all new files in T-001..T-006 directly — the v2 registry,
  the new/extended selector flags, `render-agent-frontmatter.sh`/`.ps1`, the
  run-record schema edits, the two new/extended test suites, the
  panelist/prepare-input effort threading — plus edits to
  `tests/run-all.sh`/`.ps1`, `.github/workflows/test.yml`,
  `tests/validate-repository.ps1`, `PLUGIN-CONTRACTS.md`, and the REQ-009
  documentation surfaces, none of which are protected-gate files. The agent
  does NOT write the four protected reviewer `.md` files directly — it
  stages corrected content under `specs/epic-159-pillar-c/human-copy/` only
  (REQ-003).
- Human maintainer: approves specs and tasks; runs the `cp` step for the
  four protected reviewer files whenever `render-agent-frontmatter`
  produces a non-empty diff for them; verifies and executes T-007/#155's
  prerequisite gate and its separate release.
- CI: runs all new/extended suites on the 3-OS matrix; runs
  `render-agent-frontmatter --check` and `tests/validate-repository.ps1`
  read-only against the current repository state, including the four
  protected reviewer files (AC-020).

## Main Workflows

1. T-001 (#149): author `contracts/agent-model-capabilities.v2.json`;
   author `tests/agent-capabilities-v2.tests.sh`/`.ps1`; extend
   `PLUGIN-CONTRACTS.md`; wire into `run-all`/`test.yml`; CREATE the
   `CHANGELOG.md` `## Unreleased` entry for #149.
2. T-002 (#150): add schema auto-detection and the four new flags to
   `select-agent-model.sh`/`.ps1`; extend
   `tests/agent-model-routing.tests.sh` with a Phase-1-scoped smoke of the
   new flags (full coverage lands with T-005); extend the REQ-009 doc
   surfaces this leg touches; APPEND to the shared `#150` `CHANGELOG.md`
   entry (own entry, distinct issue number from T-001's).
3. T-003 (#151): author `render-agent-frontmatter.sh`/`.ps1`; seed
   `role_defaults` from current values; wire `--check` into CI and
   `tests/validate-repository.ps1`; stage the four protected reviewer files'
   corrected content under `specs/epic-159-pillar-c/human-copy/` with a
   SHA-256 manifest for human `cp`; extend REQ-009 doc surfaces; own
   `CHANGELOG.md` entry for #151.
4. T-004 (#153): add the four `--effort-*` flags and `sdd-run-record/v2`
   fields to `emit-run-record.sh`/`.ps1`; add the two report-template lines;
   document the quality-gate Process instruction; extend
   `tests/emit-run-record-feature-scope.tests.sh`/`.ps1`; own `CHANGELOG.md`
   entry for #153.
5. T-005 (#154): author `tests/agent-model-routing.tests.ps1`; extend
   `tests/agent-model-routing.tests.sh` with the full REQ-002/REQ-005 case
   list (welded golden, matrix cases, clamp, xhigh gate, terminal-tier
   invariance, role floor, v1↔v2 projection); own `CHANGELOG.md` entry for
   #154.
6. T-006 (#152): add `--effort` to `run-panelist-gpt.sh`/`.ps1`; thread it
   through `prepare-panelist-input.sh`/`.ps1`; wire the Codex-host
   evaluator/investigator startup path; add the render/selector
   cross-check; own `CHANGELOG.md` entry for #152.
7. T-007 (#155), **separate PR, separate release, after T-001..T-006 are
   merged AND A3 is confirmed in `main`**: flip the `--effort-policy`
   default to `matrix`; perform and verify the first production
   `role_defaults` render; update `USERGUIDE.md` /
   `docs/agent-capability-matrix.md` / `CHANGELOG.md`; run the
   Codex-host smoke check; execute its own `scripts/bump-version.sh`
   release.

## Edge Cases

- Bash-3.2 / macOS-CI resilience: any new `.sh` suite (T-001's
  `agent-capabilities-v2`, T-004/T-005's extensions) never expands a
  possibly-empty bash array under `set -u`; keeps arrays structurally
  non-empty or guards every expansion, matching the CI-resilience bar
  established at `tests/lib/loop-driver.sh:326-330` and reaffirmed in both
  `specs/epic-159-pillar-a2/requirements.md` (AC-018) and
  `specs/epic-159-pillar-b/requirements.md` (AC-006).
- macOS `$TMPDIR` symlink normalization: every new mktemp fixture root this
  feature creates (registry parity fixtures, selector golden fixtures,
  render-agent-frontmatter scratchpad staging, run-record test fixtures) is
  normalized with `pwd -P` immediately after creation, mirroring
  `tests/lib/loop-driver.sh:124`.
- Windows `jq.exe` CRLF emission: any new jq consumption in this feature's
  suites (the JSON-emitting selector and run-record scripts are natural
  candidates for jq-based assertions) pipes through `tr -d '\r'`
  unconditionally, with no OS branching.
- Real-validator capability probing: no suite in this feature drives
  `validate-review-context-set.sh` or any other real validator gate
  directly; if a future edit ever does, it must go through
  `loop_validator_capability_probe`/`loop_validator_skip`
  (`tests/lib/loop-driver.sh:460-520`) rather than assuming availability.
- Protected-file boundary: `render-agent-frontmatter`'s write path must
  never target any of the four protected reviewer `.md` files or any other
  entry in `_PROTECTED_GATE_SUFFIXES` (`sdd-hook-guard.py:886-927`) — a
  self-check in the new script's own test suite asserts its write-target
  resolution function returns the scratchpad path, never the protected
  path, for those four basenames specifically. `--check` mode's read
  comparison against those same four files is explicitly permitted (it is
  not a write) and is the one place this feature intentionally inspects
  protected-file content.
- `effort_degraded_reason` vacuity: the field must never be populated when
  `effort_applied` carries a real value, and must never be left empty when
  `effort_applied` is `null` and an `--effort-*` flag was supplied — both
  directions are asserted (AC-024).
- Escalation-bump interaction with `xhigh`: a matrix-mode selection that
  escalates into `xhigh` still requires `--xhigh-reason`; omitting it must
  fail the same way an explicit `--requested-effort xhigh` without a reason
  fails today (`select-agent-model.sh:237`), not silently clamp down to
  `high` without diagnostic.
- v1 registry callers must observe zero behavioral change from this
  feature at every layer (selector, and by extension any current
  test-only consumer of `select-agent-model.sh` — INV-002) for the
  duration of Phase 1.

## Security Boundaries

| Trust Boundary | Auth/Authz Requirement | PII / Data Classification | Regulatory Constraints |
|---|---|---|---|
| B1: registry/selector inputs to routing decisions | `--registry`/`--candidates-file` schema and field validation unchanged in strictness from v1 (`select-agent-model.sh:192-230`); v2 parsing rejects malformed `supported_efforts`/`effort_control`/`risk_effort_matrix` the same way v1 rejects malformed `efforts` | internal source only | none identified |
| B2: render output to R-10 protected gate files | protected basenames never receive a direct write from `render-agent-frontmatter`; scratchpad + SHA-256 manifest + human `cp` for the four protected reviewer files; `--check` is read-only against them | internal source only | none identified |
| B3: Codex CLI invocation argument construction | `--model`/`--effort` values passed to `codex` are sourced only from the registry/selector, never from unsanitized task or spec text, preventing CLI-argument injection via task content | internal source only | none identified |
| B4: run-record effort fields vs. real invocation outcome | `effort_applied` is set to a real value only on confirmed application (Codex `flag` control); every other path is `null` + a named `effort_degraded_reason` — no path can report a false "applied" | internal source only | none identified |

Details: [Security specification](security-spec.md#trust-boundaries).

## Assumptions

- `select-agent-model.sh`'s existing escalation logic
  (`select-agent-model.sh:155-184`, `escalation_tier`) remains stable; the
  matrix mode's `escalation_bump` (REQ-001) composes with it rather than
  replacing it.
- `_PROTECTED_GATE_SUFFIXES` (`sdd-hook-guard.py:886-927`) remains as
  observed at investigation/spec time; neither
  `render-agent-frontmatter.sh`/`.ps1` nor any file it targets (other than
  the four already-protected reviewer `.md` files) is added to that list
  during this feature's lifetime.
- A3 (commit `2d8c6a561e0f5d2bc29ded4195c057d4cc918f2f`, "fix: unblock impl
  review rounds after the first (#143)") is confirmed, via
  `git merge-base --is-ancestor 2d8c6a5 HEAD`, to already be an ancestor of
  this spec's HEAD (`f6b1365`) at spec-authoring time. This satisfies
  REQ-007's A3 prerequisite as of NOW; T-007's own implementation report
  re-verifies this fact against the actual release commit, in case an
  intervening history rewrite or revert on `main` were to remove it (low
  probability, but the re-verification cost is negligible — a single `git
  merge-base` check).
- `.codex/agents/sdd-evaluator.toml` and `.codex/agents/sdd-investigator.toml`
  remain free of any model/effort-related TOML key at design time; if a
  future, unrelated Codex CLI upgrade begins consuming such a key, REQ-003's
  "documentation-only comment" design (OQ-002) would need re-verification,
  but no such change is in scope or expected here.
- `tests/run-all.sh`, `tests/run-all.ps1`, `.github/workflows/test.yml`,
  `tests/validate-repository.ps1`, and `tests/workflow-documentation.tests.sh`
  remain outside the protected-gate table for the duration of this feature.

## Open Questions

- OQ-001 (issue #149 investigation OQ-001) — RESOLVED: v1 and v2 coexist for
  the duration of Phase 1; v1 is frozen, not deleted; v2 becomes the sole
  consulted registry only after T-007/#155's flip (design.md Design
  Decisions).
- OQ-002 (issue #151 investigation OQ-002) — RESOLVED: Codex `.toml`
  `# x-sdd-model:`/`# x-sdd-effort:` comments are documentation-only,
  consumed by this repository's own caller scripts (REQ-006), never parsed
  by the `codex` CLI itself (Goals REQ-003 above; verified against
  `.codex/agents/sdd-evaluator.toml`'s current field set).
- OQ-003 (issue #155 investigation OQ-003) — PARTIALLY RESOLVED: the
  release-ordering gate is a documented procedure (REQ-007's prerequisite
  gate, verified via `git merge-base` and PR/release sequencing) rather than
  an automated CI mechanism; building an automated gate remains explicitly
  out of scope (Non-goals) and open for a future issue if a real ordering
  violation occurs in practice.
- OQ-004 (issue #150/#155 investigation OQ-004) — RESOLVED: the
  `--effort-policy` default lives in `select-agent-model.sh`/`.ps1`'s own
  flag-default logic (a hardcoded default, not an external config file),
  changed by exactly one code edit in T-007; no deprecation period is
  defined for `welded` (it remains a fully-supported, explicit flag value
  indefinitely, matching how `--effort-policy welded` continues to work
  after the default flips — see design.md Design Decisions for the
  no-warning-emission decision).

## Risks

- Critical: a `render-agent-frontmatter` bug that targets a protected
  reviewer file for direct write (rather than the scratchpad) would either
  be silently blocked by the R-10 guard (safe but confusing) or, if a
  future guard regression ever removed that protection, could corrupt an
  enforcement-chain file. Mitigation: AC-019's write-target self-check
  (Edge Cases) asserts the resolution function itself, not merely the
  guard's behavior, so the test fails even if the guard were hypothetically
  absent.
- High: the welded-mode golden baseline (AC-007) is the single mechanism
  proving Phase 1 changes nothing for existing behavior; a golden fixture
  that silently goes stale (e.g., because someone edits it to make a
  failing test pass instead of fixing the regression) would mask a real
  regression. Mitigation: AC-007's mutation-based negative self-check is
  mandatory, not optional, mirroring `specs/epic-159-pillar-a2/design.md`'s
  and `specs/epic-159-pillar-b/design.md`'s established red/green pairing
  convention.
- High: T-007/#155 landing before A3 or before all of T-001..T-006 are
  merged would measure effort effects on top of a known-broken round-2
  evaluation path, corrupting the very WFI signal this epic exists to
  produce. Mitigation: REQ-007's prerequisite gate is a hard Done-condition
  precondition (AC-045, AC-046), reviewed at both spec-review and
  quality-gate time, not left as an informal convention.
- Medium: shared registration surfaces (`tests/run-all.sh`/`.ps1`,
  `.github/workflows/test.yml`, `CHANGELOG.md`'s `## Unreleased` section)
  are touched by six of the seven tasks. Mitigation: design.md's Global
  Constraints section (serialized, per-task commits, matching
  epic-159-pillar-a2/b's established precedent).
- Medium: the Codex `.toml` comment format (REQ-003) and the selector's
  live output (REQ-006) could drift apart if a caller script is updated
  without re-running `render-agent-frontmatter --check`. Mitigation:
  AC-038's cross-check makes drift a distinguishable, detectable condition
  rather than a silent divergence.
- Low: `tests/agent-model-routing.tests.ps1`'s status as a wholly new file
  (rather than an edit) means its own registration (AC-027) is itself a new
  surface that could be skipped. Mitigation: the suite self-registers via a
  grep-based self-check against `tests/run-all.ps1`/`test.yml`, mirroring
  `tests/second-approval-mask.tests.sh:285-289`'s established pattern
  (design.md Test Strategy).
