# Design: epic-159-pillar-c

Impl-Review-Status: Pending
Feature Type: contract schema migration + CLI/script feature additions
(effort routing v2) across a registry, a selector, an agent-definition
renderer, a run-record schema, and one host's real invocation path

## Technical Summary

Seven additive-first deliverables land in dependency order (T-001..T-006),
with a single, separately-released behavior flip (T-007/#155) gated on all
six plus an already-landed bug fix (A3). The registry (T-001) is the single
source of truth every other component reads from: the selector (T-002)
consumes it to choose model+effort; the renderer (T-003) consumes it to
generate agent-definition files on both hosts; the run-record (T-004)
records what the selector chose and what was actually applied; the routing
tests (T-005) lock all of the above byte-for-byte during Phase 1; the Codex
invocation path (T-006) is the one place effort is REALLY applied, on the
one host that supports it (`effort_control: flag`); Phase 2 (T-007) changes
exactly one default value once every prerequisite is verified in `main`.

The guiding principle, carried from epic-159-pillar-a2 and epic-159-pillar-b:
no safety property is asserted by reimplementation, and Phase 1 introduces
capability without changing observed behavior. `welded` mode's byte-identical
golden baseline (REQ-002/REQ-005) is this feature's version of that
principle — every new code path is provably inert until T-007 flips the
switch, and T-007 itself is provably gated rather than merely documented as
gated.

## Architecture

```mermaid
flowchart TB
  V1["contracts/agent-model-capabilities.json (v1, FROZEN)"]
  V2["contracts/agent-model-capabilities.v2.json (T-001, new)"]
  PARITY["tests/agent-capabilities-v2.tests.sh/.ps1 (T-001, new)"]
  V1 -.->|two-directional parity lock| PARITY
  V2 --> PARITY

  SEL["select-agent-model.sh/.ps1 (T-002, edited)"]
  V1 -->|legacy schema path, byte-identical| SEL
  V2 -->|welded (Phase 1 default) / matrix (Phase 2)| SEL

  ROUTE["tests/agent-model-routing.tests.sh/.ps1 (T-005: .sh extended, .ps1 NEW)"]
  SEL --> ROUTE

  RENDER["render-agent-frontmatter.sh/.ps1 (T-003, new)"]
  SEL -.->|role_defaults seed, no runtime call| RENDER
  V2 -->|role_defaults| RENDER
  CLAUDEMD["Claude .md agents: model: + x-sdd-effort: (unprotected targets)"]
  CODEXTOML[".codex/agents/*.toml: # x-sdd-model: / # x-sdd-effort: comments"]
  PROTECTED["4x protected reviewer .md (R-10) — scratchpad + human cp ONLY"]
  RENDER --> CLAUDEMD
  RENDER --> CODEXTOML
  RENDER -.->|scratchpad + SHA-256 manifest, never direct write| PROTECTED
  CHECK["render-agent-frontmatter --check (read-only)"]
  RENDER --> CHECK
  CHECK -->|wired into| CI["CI + tests/validate-repository.ps1"]
  CHECK -.->|read-only comparison, no guard trip| PROTECTED

  PANEL["run-panelist-gpt.sh/.ps1 --effort (T-006, edited)"]
  PREP["prepare-panelist-input.sh/.ps1 (T-006, edited)"]
  SEL -->|--host codex-cli output: model + effort| PREP --> PANEL
  PANEL -->|codex --model --effort| CODEXCLI["codex CLI (real, Codex host only)"]
  CODEXTOML -.->|reference cross-check, drift detectable| PANEL
  STARTUP["evaluator/investigator Codex startup path (SKILL.md-documented)"]
  SEL -->|--host codex-cli| STARTUP --> CODEXCLI

  RECORD["emit-run-record.sh/.ps1 (T-004, edited) — sdd-run-record/v2"]
  SEL -->|effort_requested (both hosts)| RECORD
  PANEL -->|effort_applied (Codex host, confirmed)| RECORD
  CLAUDEMD -.->|effort_applied=null + effort_degraded_reason (Claude Code host)| RECORD

  FLIP["T-007/#155: --effort-policy default welded -> matrix"]
  SEL -.->|Phase 2, gated: T-001..T-006 merged + A3 (2d8c6a5) in main| FLIP
  FLIP -.->|separate PR, separate release| RELEASE["scripts/bump-version.sh (own invocation)"]
```

## Components

| Component | Responsibility | Technology | New/Existing | Protected? |
|---|---|---|---|---|
| `contracts/agent-model-capabilities.v2.json` | tier/effort-decoupled registry: `supported_efforts`, `default_effort`, `effort_control`, `risk_effort_matrix`, `role_defaults` | JSON | new | no |
| `contracts/agent-model-capabilities.json` | v1 registry, FROZEN | JSON | existing, unmodified | no |
| `tests/agent-capabilities-v2.tests.sh` / `.ps1` | v1⇔v2 two-directional parity lock + negative canary | Bash / PowerShell | new | no |
| `select-agent-model.sh` / `.ps1` | schema auto-detect; `--effort-policy`/`--requested-effort`/`--role`/`--host`; additive JSON keys | Bash (python3 heredoc) / PowerShell | existing, edited (T-002) | no (verified) |
| `render-agent-frontmatter.sh` / `.ps1` | Claude `.md` frontmatter render; Codex `.toml` comment render; `--check` drift detection; protected-file scratchpad staging | Bash / PowerShell | new | no (writes are gated, script itself is not a protected file) |
| `tests/render-agent-frontmatter.tests.sh` / `.ps1` | render correctness, no-op proof, exclusion lock, protected-file write/read boundary | Bash / PowerShell | new | no |
| `emit-run-record.sh` / `.ps1` | +`--effort-*` flags; `sdd-run-record/v2` fields | Bash / PowerShell | existing, edited (T-004) | no (verified) |
| `implementation-report.template.md` | +`- Model:`/`- Effort:` lines | Markdown | existing, edited (T-004) | no |
| `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md` | +Process instruction: gate reports record Model/Effort | Markdown (skill) | existing, edited (T-004) | no (verified — not in `_PROTECTED_GATE_SUFFIXES`) |
| `tests/agent-model-routing.tests.sh` | extended: welded golden, matrix cases, clamp, xhigh gate, terminal-tier invariance, role floor, v1↔v2 projection | Bash | existing, edited (T-005) | no |
| `tests/agent-model-routing.tests.ps1` | same case list, NEW twin (closes the pre-existing gap) | PowerShell | new (T-005) | no |
| `run-panelist-gpt.sh` / `.ps1` | +`--effort <e>`, forwarded to `codex` CLI | POSIX sh / PowerShell | existing, edited (T-006) | no |
| `tests/run-panelist-effort.tests.sh` / `.ps1` | argv-composition lock (AC-035..040), injection-rejection lock (AC-052) | Bash / PowerShell | new (T-006) | no |
| `prepare-panelist-input.sh` / `.ps1` | threads selector-derived effort to the panelist runner | POSIX sh / PowerShell | existing, edited (T-006) | no |
| `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md` (Codex startup instructions) | evaluator/investigator Codex launch supplies `--host codex-cli` output | Markdown (skill) | existing, edited (T-006) | no |
| `.codex/agents/sdd-evaluator.toml`, `sdd-investigator.toml` | gain `# x-sdd-model:`/`# x-sdd-effort:` reference comments (via render, T-003); consumed by T-006's cross-check | TOML | existing, edited (T-003 render target) | no |
| `plugins/sdd-review-loop/agents/impl-reviewer-a.md`, `impl-reviewer-b.md`, `task-reviewer-a.md`, `task-reviewer-b.md` | R-10 PROTECTED render targets — human-copy only | Markdown (agent frontmatter) | existing, human-applied (T-003) | **YES** |
| `tests/run-all.sh` / `.ps1` | suite registration (T-001, T-003, T-005, T-006 suites) — agent-edited directly | Bash / PowerShell | existing, edited | no (verified) |
| `.github/workflows/test.yml` | suite/step registration (T-001, T-003, T-005, T-006) | YAML | existing, human-applied via staged candidate + `MANIFEST.sha256` | **YES** (`plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4`, round-2 remedy) |
| `tests/validate-repository.ps1` | +`render-agent-frontmatter --check` invocation | PowerShell | existing, edited (T-003) | no (verified) |
| `PLUGIN-CONTRACTS.md`, `docs/agent-capability-matrix.md`, `USERGUIDE.md`, `CHANGELOG.md` | doc-following surfaces (REQ-009) + T-007's default-policy documentation | Markdown | existing, edited | no |

Real surfaces exercised READ-ONLY where a script drives them without
modification: `select-agent-model.sh`/`.ps1`'s existing eligibility/sort
logic (`select-agent-model.sh:232-247`, unchanged by T-002's additions — new
flags compose with it, they do not replace it).

## Protected-File Statement

**Round-2 CRITICAL correction**: verified directly against the CURRENT
`PROTECTED_GATE_SUFFIXES` tuple at
`plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4` (the
module `plugins/sdd-quality-loop/scripts/sdd-hook-guard.py:891`'s
`_load_guard_invariants()` function loads) — this SUPERSEDES this design's
round-1 statement that exactly four files were protected.
`.github/workflows/test.yml` IS now present in `PROTECTED_GATE_SUFFIXES`
(landed between round 1 and round 2 via the concurrently-merged epic-136
Phase 2 work, commit lineage `2b8a52f`, outside this feature's control),
making the total FIVE protected files this feature's tasks touch: the four
review-loop reviewer files —
`plugins/sdd-review-loop/agents/impl-reviewer-a.md`, `impl-reviewer-b.md`,
`task-reviewer-a.md`, `task-reviewer-b.md` (T-003 render targets) — PLUS
`.github/workflows/test.yml` itself (T-001, T-003, T-005, T-006's shared
registration surface). No other file this feature creates or edits appears
in `PROTECTED_GATE_SUFFIXES` or `PROTECTED_GATE_PLUGIN_JSON_SUFFIXES` — not
`contracts/agent-model-capabilities.v2.json`, not
`select-agent-model.sh`/`.ps1`, not `render-agent-frontmatter.sh`/`.ps1`
itself, not `emit-run-record.sh`/`.ps1`, not `run-panelist-gpt.sh`/`.ps1`,
not `prepare-panelist-input.sh`/`.ps1`, not `tests/run-all.sh`/`.ps1`, not
`tests/validate-repository.ps1`, not
`plugins/sdd-quality-loop/skills/quality-gate/SKILL.md` (the protected
sdd-review-loop `SKILL.md` entries are specifically
`impl-review-loop/SKILL.md` and `task-review-loop/SKILL.md` —
`sdd-hook-guard.py:917-919` — a different plugin's `SKILL.md` entirely from
`sdd-quality-loop/skills/quality-gate/SKILL.md`), and not the `.codex/agents/`
TOML files (re-verified: no `.codex/agents/*.toml` entry appears in the
current `PROTECTED_GATE_SUFFIXES` tuple). Per requirements.md's Assumptions
discipline, this is a live-repository snapshot re-verified at round-2
remedy time, not a permanent guarantee — each of T-001, T-003, T-005, and
T-006 re-verifies `PROTECTED_GATE_SUFFIXES`'s then-current contents at its
own implementation-start time.

**Procedure for the five protected targets** (epic-136 human-copy pattern,
requirements.md Field Definitions): `render-agent-frontmatter` writes
corrected content for the four reviewer files to
`specs/epic-159-pillar-c/human-copy/<basename>` plus a
`specs/epic-159-pillar-c/human-copy/MANIFEST.sha256` entry per file, and
never opens the real protected path for write. For
`.github/workflows/test.yml`, each of T-001/T-003/T-005/T-006 stages the
FULL corrected file content (its own step addition applied on top of
whatever the file already contains at that task's start) to
`specs/epic-159-pillar-c/human-copy/.github/workflows/test.yml`, updating
the same `MANIFEST.sha256` with that file's new SHA-256, again never
opening the real path for write. A human maintainer runs
`cp specs/epic-159-pillar-c/human-copy/<staged-path> <real-path>`
for each staged file, then verifies the copied file's SHA-256 matches the
manifest, before that task can be marked Done. `--check` mode is exempt
from this restriction for the four reviewer files: it opens them for READ
only (to compare against expected rendered content), which is not a write
and does not trigger the R-10 guard — this is the one intentional place
this feature reads protected-file content, and it is wired unattended into
CI (AC-020). `.github/workflows/test.yml`'s own registration presence is
likewise verified read-only, post-human-copy, by AC-027's part (c)
self-registration grep — no script in this feature ever attempts to WRITE
`.github/workflows/test.yml`.

## Layer Specifications

| Layer | Summary | Canonical Detail | Owner | Status |
|---|---|---|---|---|
| UX | N/A — no change: no GUI or user-facing surface | [UX specification](ux-spec.md#scope-and-user-journeys) | maintainers | N/A |
| Frontend | N/A — no change: JSON contract, shell/PowerShell scripts, Markdown/TOML generation only | [Frontend specification](frontend-spec.md#technology-stack) | maintainers | N/A |
| Infrastructure | CI drift-check job; 3-OS suite registration via human-copy staging for `.github/workflows/test.yml` (round-2 correction); `.codex-plugin` manifest + `.codex/agents/*.toml` role path unchanged in structure | [Infrastructure specification](infra-spec.md#cicd-sequence) | maintainers | Planned |
| Security | protected-file write boundary (4 reviewer `.md` + `.github/workflows/test.yml`, round 2); CLI-argument injection prevention + rejection lock; run-record truthfulness (`effort_applied` never falsely non-null, host-independent); malformed-registry rejection | [Security specification](security-spec.md#trust-boundaries) | maintainers | Planned |

## Design System Compliance

N/A — ds_profile: none. Not a UI application; no mockup provided; optional
visualization skipped.

## Cross-Layer Dependencies

| From | To | Contract / Decision | REQ | AC | Verification |
|---|---|---|---|---|---|
| requirements.md | design.md | v2 registry schema, v1 frozen, two-directional parity, malformed-field rejection | REQ-001 | AC-001..005, AC-054 | TEST-001..005, TEST-054 |
| requirements.md | design.md | selector schema auto-detect + 4 new flags, welded golden, welded+requested-effort carve-out, malformed-field rejection | REQ-002 | AC-006..013, AC-053, AC-054 | TEST-006..013, TEST-053, TEST-054 |
| requirements.md | design.md | render-agent-frontmatter (Claude/Codex), `--check`, protected-file procedure (4 reviewer `.md` + `.github/workflows/test.yml`, round-2) | REQ-003 | AC-014..020 | TEST-014..020 |
| requirements.md | design.md | run-record v2, 3-subfield effort tracking, template lines, Codex-host non-flag-control degradation | REQ-004 | AC-021..026, AC-051 | TEST-021..026, TEST-051 |
| requirements.md | design.md | routing test expansion, new `.ps1` twin, protected-`test.yml` 3-part registration | REQ-005 | AC-027..034 | TEST-027..034 |
| requirements.md | design.md | Codex host real effort application, cross-check, CLI-argument-injection rejection | REQ-006 | AC-035..040, AC-052 | TEST-035..040, TEST-052 |
| requirements.md | design.md | Phase 2 flip, prerequisite gate, separate release | REQ-007 | AC-041..046 | TEST-041..046 |
| requirements.md | design.md | cross-host degradation coverage | REQ-008 | AC-047..048 | TEST-047..048 |
| requirements.md | design.md | doc-following + version-bump discipline | REQ-009 | AC-049..050 | TEST-049..050 |
| requirements.md | security-spec.md | protected-file write boundary (incl. `.github/workflows/test.yml`, round-2); CLI-argument injection + rejection lock; run-record truthfulness + host-independent degradation; malformed-registry rejection | REQ-001, REQ-003, REQ-004, REQ-005, REQ-006 | AC-019, AC-020, AC-023, AC-024, AC-027, AC-038, AC-051, AC-052, AC-054 | TEST-019, TEST-020, TEST-023, TEST-024, TEST-027, TEST-038, TEST-051, TEST-052, TEST-054 + security tests |
| requirements.md | infra-spec.md | 3-OS × bash/pwsh wiring; `--check` CI job; `.github/workflows/test.yml` human-copy CI-registration procedure (round-2); deterministic lane except T-007's smoke | REQ-003, REQ-005 | AC-016, AC-027, AC-044 | TEST-016, TEST-027, TEST-044 |

## ADR Change Log

**New ADR**: `docs/adr/0012-effort-tier-decoupling.md` (round-2 impl-review
correction: renumbered from `0011` — `docs/adr/0011-phase2-handle-relative-protected-copy.md`
already occupies `0011`, landed by the concurrently-merged epic-136 Phase 2
work; verified via `ls docs/adr/` at remedy time that `0012` is the next
free number). ADR-0003
("Turn-First Agent Routing", `docs/adr/0003-turn-first-agent-routing.md`)
currently states the canonical tier table as welding effort to tier
("strong | Opus | `gpt-5.2-codex` with high or xhigh effort") — a decision
this feature's v2 registry and matrix policy structurally supersede once
T-007 flips the default. The new ADR records: (a) v1/v2 coexistence during
Phase 1 (OQ-001), (b) the `welded`/`matrix` policy split and why Phase 1
must remain behavior-identical, (c) the decision that Codex `.toml`
comments are documentation-only, never CLI-parsed (OQ-002), (d) the
release-ordering decision for T-007 (OQ-003), and (e) that ADR-0003's tier
table's role remains authoritative for TIER selection — only the
tier↔effort weld is superseded, not turn-first tier selection itself. This
crosses ADR weight because it changes a previously-Accepted architectural
decision's stated behavior (the weld), unlike epic-159-pillar-a2/b, which
each explicitly declared "No new ADR" for changes that only extended
existing, unchanged vocabulary. The `greenfield`/`brownfield` fixture
vocabulary (ADR-0010) and the turn-first tier-selection algorithm
(ADR-0003's non-weld portions) are unaffected and not restated.

**Drafting ownership** (round-2 impl-review remedy — previously
unassigned): ADR-0012 is drafted as part of T-002's own implementation
commit (`select-agent-model`'s `--effort-policy` implementation is the
change that actually introduces the tier/effort decoupling this ADR
records), and `docs/adr/0012-effort-tier-decoupling.md` is added to the
repository in that SAME commit — not as a separate task, and not deferred
to T-001 or T-007. The number is NOT assumed fixed at spec-authoring time:
T-002's implementer re-verifies via `ls docs/adr/` at drafting time and, if
a concurrent merge has occupied `0012` in the interim (the same class of
collision that made this round-2 correction necessary), renumbers to the
next free number, updating both the ADR's own filename and every
`docs/adr/00NN-effort-tier-decoupling.md` / `ADR-00NN` reference in this
design document in the same commit.

## Data Plan

Data Entities:

- `contracts/agent-model-capabilities.v2.json` (new, committed): top-level
  `schema`, `models[]` (each: `name`, `canonical_tier`, `supported_efforts[]`,
  `default_effort`, `effort_control.claude-code`, `effort_control.codex-cli`),
  `risk_effort_matrix` (`low`, `medium`, `high`, `critical`,
  `escalation_bump`), `role_defaults` (per role: `minimum_tier`,
  `default_effort`).
- `sdd-run-record/v2` (schema-versioned, per generated record): the run
  record's existing `model_ids` object (`main`, `reviewers` — unchanged)
  gains a SIBLING `effort` object with the identical two-key shape, each
  key holding exactly three subfields (requirements.md REQ-004; explicit
  per past-review guidance on subfield enumeration):
  - `effort.main.effort_requested` (string | null) — the requested effort
    value for the main agent, always recorded when
    `--effort-main` is supplied.
  - `effort.main.effort_applied` (string | null) — non-null only when
    `effort_control` for the invoking host resolved to `flag` and
    application was confirmed (Codex host); otherwise `null`.
  - `effort.main.effort_degraded_reason` (string | null) — populated if
    and only if `effort.main.effort_applied` is `null` and
    `effort.main.effort_requested` is non-null (e.g.
    `"host-no-effort-control"`).
  - `effort.reviewers.effort_requested` (string | null) — same semantics
    as `effort.main.effort_requested`, for the reviewers role slot.
  - `effort.reviewers.effort_applied` (string | null) — same semantics as
    `effort.main.effort_applied`, for the reviewers role slot.
  - `effort.reviewers.effort_degraded_reason` (string | null) — same
    semantics as `effort.main.effort_degraded_reason`, for the reviewers
    role slot.
- `specs/epic-159-pillar-c/human-copy/` (new, mktemp-adjacent but
  COMMITTED as a review artifact, not deleted by any test): the four
  protected-target render outputs plus `MANIFEST.sha256`.

Existing Data Affected: `contracts/agent-model-capabilities.json` (v1) is
read but never written (AC-004's SHA-256 check). Real
`plugins/**/agents/*.md` and `.codex/agents/*.toml` files ARE written in
production by `render-agent-frontmatter` (not a test-fixture concern) —
this is the feature's intended effect, distinct from every prior
epic-159-pillar spec, which touched no production agent-definition files.
The four protected `.md` files are the sole exception, written only via the
human-copy procedure above.

Migration Strategy: none for the registry (v1/v2 coexist, no in-place
migration). Run-record v2 is additive-only; no v1 record is rewritten or
migrated — `emit-run-record` simply emits `v1` shape when no `--effort-*`
flag is supplied and `v2` shape when one is, and the validator accepts
both shapes keyed off the `schema` field.

## API / Contract Plan

### `contracts/agent-model-capabilities.v2.json` schema (T-001)

```json
{
  "schema": "agent-model-capabilities/v2",
  "models": [
    {
      "name": "anthropic/opus",
      "canonical_tier": "strong",
      "supported_efforts": ["high"],
      "default_effort": "high",
      "effort_control": { "claude-code": "frontmatter", "codex-cli": "none" }
    },
    {
      "name": "openai/gpt-5.2-codex",
      "canonical_tier": "strong",
      "supported_efforts": ["high", "xhigh"],
      "default_effort": "high",
      "effort_control": { "claude-code": "none", "codex-cli": "flag" }
    }
  ],
  "risk_effort_matrix": {
    "low": "low",
    "medium": "medium",
    "high": "high",
    "critical": "high",
    "escalation_bump": true
  },
  "role_defaults": {
    "sdd-evaluator": { "minimum_tier": "strong", "default_effort": "high" },
    "sdd-investigator": { "minimum_tier": "lightweight", "default_effort": "low" },
    "spec-reviewer": { "minimum_tier": "standard", "default_effort": "medium" },
    "impl-reviewer": { "minimum_tier": "standard", "default_effort": "medium" },
    "task-reviewer": { "minimum_tier": "standard", "default_effort": "medium" }
  }
}
```

Every v1 model name (`anthropic/haiku`, `anthropic/sonnet`,
`anthropic/opus`, `openai/gpt-5.1-codex-mini`, `openai/gpt-5.1-codex`,
`openai/gpt-5.2-codex`, `openai/gpt-5.1-codex-max` —
`contracts/agent-model-capabilities.json:1-40`) appears in v2 with the
identical `canonical_tier`; each v1 model's single-element `efforts` array
value is a member of that model's v2 `supported_efforts` array (v1's
`anthropic/opus` carries `efforts: ["high"]` only — verified directly from
the file, not the `["high", "xhigh"]` investigation.md's INV-001 prose
summarized; v2's `anthropic/opus.supported_efforts` must therefore contain
at least `"high"`, and MAY add `"xhigh"` as a v2-only expansion without
violating the parity subset rule, since parity is v1-⊆-v2, not equality).
`effort_control` is populated per this feature's investigation: Claude-side
models get `claude-code: "frontmatter"` (INV-013 — no CLI effort mechanism
exists to promote to `"flag"`); Codex-side "strong" models supporting
`xhigh` get `codex-cli: "flag"` (INV-007's target state); every model's
opposite-host key is `"none"` where that host cannot run that vendor's
model at all (e.g. `codex-cli: "none"` for `anthropic/*` entries).

### `select-agent-model.sh`/`.ps1` schema auto-detection + new flags (T-002)

Schema detection reads the `--registry` file's top-level `schema` field
before any other parsing (`select-agent-model.sh:196-197`'s existing
`json.load` call is the insertion point): `"agent-model-capabilities/v1"`
routes into the EXISTING, byte-unmodified code path
(`select-agent-model.sh:192-230`); `"agent-model-capabilities/v2"` routes
into a new v2 parsing branch that additionally reads `supported_efforts`,
`default_effort`, `effort_control`, `risk_effort_matrix`, `role_defaults`.
An unrecognized `schema` value is a `MODEL_SELECTION_ERROR`, matching the
script's existing fail-closed error convention
(`select-agent-model.sh:124-135`'s pattern for other invalid inputs).

`--effort-policy welded` (default through Phase 1): the v2 branch computes
effort using the SAME tiebreak logic the v1 branch already uses inside the
eligibility filter and sort key (`select-agent-model.sh:110,232-247` —
`efforts = {"": 0, "low": 0, "medium": 1, "high": 2, "xhigh": 3}` as a
tiebreak, not a driver of selection), reading each candidate's welded
effort from the WINNING model's `default_effort` rather than a
matrix lookup — reproducing v1's observed behavior exactly against the
same fixture inputs (the golden baseline, AC-007).

`--effort-policy matrix`: after the existing eligibility filter and
tier/cost sort (`select-agent-model.sh:232-247`, unchanged) selects a
winning model, effort is computed as
`risk_effort_matrix[risk]`, clamped to `min(matrix_effort,
max(winning_model.supported_efforts))` by the existing `efforts` ordinal
map, then bumped one step (still clamped) if `escalation_tier` is set
(`select-agent-model.sh:155-184`, unchanged escalation logic) and
`risk_effort_matrix.escalation_bump` is `true`. If the clamped-and-bumped
result is `xhigh`, the existing `--xhigh-reason` gate
(`select-agent-model.sh:237`) applies exactly as it does for an explicit
request — an eligible-candidate filter that requires `xhigh_reason` be
truthy whenever the resolved effort is `xhigh`, computed AFTER the bump,
not before it (so a bump that lands on `xhigh` without a reason drops that
candidate from eligibility rather than silently downgrading it, matching
today's `BLOCKED model-tier-unavailable`-style fail-closed behavior when no
eligible candidate remains).

`--requested-effort <e>`: overrides the policy-computed effort entirely,
subject to the same clamp-to-`supported_efforts` and `xhigh_reason` gate.

`--role <role>`: looks up `role_defaults[role]`, seeding `--minimum-tier`
(if not already set by the caller) and providing a default `--requested-effort`
(if the caller does not separately set one) — composing with, not
overriding, an explicit `--requested-effort`.

`--host claude-code|codex-cli` (default `claude-code`): after the winning
model and final effort are resolved, looks up
`winning_model.effort_control[host]` and includes it in JSON output as
`effort_control`.

JSON output (additive only): existing keys
(`model`, `canonical_tier`, `effort`, `estimated_cost_per_attempt_usd`,
`available_candidates`, `xhigh_reason`, `escalation`) are unchanged in name
and type (`select-agent-model.sh:248-263`); two new keys, `effort_source`
(one of `"welded"`, `"matrix"`, `"requested"`, `"model-default"`) and
`effort_control` (one of `"flag"`, `"frontmatter"`, `"none"`), are added at
the same top level.

`--candidates-file` v2 entries: the existing per-item validation
(`select-agent-model.sh:207-215`) currently requires `effort` present and a
member of the model's (v1) `efforts` list; for a v2 registry, an item MAY
omit `effort`, in which case the selector fills it via the same
welded/matrix/requested/role logic above rather than reading a
caller-supplied value. A v1 `--candidates-file` continues to require
`effort` present, unchanged.

### `render-agent-frontmatter.sh`/`.ps1` (T-003)

A `TARGETS` map (mirroring `tests/guard-ps1-ascii.tests.sh`'s established
`TARGET`→`TARGETS` generalization pattern, epic-159-pillar-a2 design.md
Field Definitions) of `role -> { claude_md_path?, codex_toml_path? }`,
covering: `sdd-evaluator` → `plugins/sdd-quality-loop/agents/evaluator.md`
+ `.codex/agents/sdd-evaluator.toml`; `sdd-investigator` →
`plugins/sdd-bootstrap/agents/investigator.md` +
`.codex/agents/sdd-investigator.toml`; `spec-reviewer`/`impl-reviewer`/
`task-reviewer` → their respective Claude `.md` agent files where
unprotected, PLUS the four protected `impl-reviewer-{a,b}.md`/
`task-reviewer-{a,b}.md` files flagged `protected: true` in the map (routed
to the human-copy path, never a direct write target).

For each unprotected Claude target: read the current `model:` frontmatter
line; if it differs from `role_defaults[role].default_effort`'s paired
tier's canonical model name, rewrite ONLY that line (no other frontmatter
field is touched); insert or refresh a trailing `x-sdd-effort:
<role_defaults[role].default_effort>` comment line immediately after the
frontmatter's closing `---` (a comment, not a YAML frontmatter key, so it
never participates in the agent-loader's frontmatter parsing — consistent
with `x-sdd-model`/`x-sdd-effort` being explicitly documentation-only per
OQ-002's resolution for the Codex side, applied symmetrically here for the
Claude side per REQ-008's "record-only" characterization).

For each Codex `.toml` target: insert or refresh two comment lines,
`# x-sdd-model: <model-name>` and `# x-sdd-effort: <effort>`, at the top of
the file (before the `name = "..."` line), leaving every existing TOML key
(`name`, `description`, `sandbox_mode`, `developer_instructions`)
byte-unchanged — verified the current files carry none of these keys today
(`.codex/agents/sdd-evaluator.toml`), so this is a pure addition, not a
rewrite of any existing line.

For each PROTECTED target: compute the same corrected content as the
unprotected path would produce, write it to
`specs/epic-159-pillar-c/human-copy/<basename>` (never to the real path),
and append a `<basename> <sha256>` line to
`specs/epic-159-pillar-c/human-copy/MANIFEST.sha256`.

`--check`: performs the same read-and-compute step as a real render, but
instead of writing anywhere, diffs the computed content against the
on-disk content at EVERY target's real path — including the four protected
targets' real paths (a read, not a write) — and exits non-zero if any
target's on-disk content differs from the computed content (for protected
targets, "on-disk content" is the real protected file itself; a non-zero
exit there means a human-copy is pending, not that the script attempted an
illegal write).

### `emit-run-record.sh`/`.ps1` `sdd-run-record/v2` (T-004)

New flags: `--effort-main <e>`, `--effort-reviewers <e>`,
`--effort-applied-main <e|none>`, `--effort-applied-reviewers <e|none>`
(the `none` sentinel distinguishes "flag supplied, application confirmed
absent" from "flag not supplied at all" — when `--effort-main` is supplied
without a paired `--effort-applied-main`, the script itself resolves
whether application occurred by reading the same `effort_control`
resolution T-002's selector already computed for that invocation, passed
through as an additional `--effort-control-main <flag|frontmatter|none>`
flag). Insertion point: immediately after the existing `model_ids` object
construction (`emit-run-record.sh:141-144`), adding a sibling `effort`
object with the exact six subfields the Data Plan section enumerates. When
no `--effort-*` flag is supplied at all, the emitted record omits the
`effort` object entirely and `schema` remains `"sdd-run-record/v1"` —
`emit-run-record` is unconditionally backward-compatible by construction,
not by a separate legacy code path.

### `run-panelist-gpt.sh`/`.ps1` `--effort` (T-006)

New `--effort` case in the existing argument-parsing `while`/`case` block
(`run-panelist-gpt.sh:31-42`, alongside `--model`); the resolved value is
appended to the existing `codex` invocation
(`run-panelist-gpt.sh:146`: `"$_codex_cmd" --model "$model" --no-project-doc
...` becomes `"$_codex_cmd" --model "$model" --effort "$effort"
--no-project-doc ...` when `--effort` was supplied; omitted entirely when
it was not, preserving today's exact invocation for any caller that does
not yet pass `--effort`). `prepare-panelist-input.sh`/`.ps1` gains a
`--effort <e>` pass-through flag that is forwarded verbatim as
`run-panelist-gpt --effort <e>` when the caller (T-006's Codex-host
startup wiring) supplies one.

## Test Strategy

1. Golden-baseline red/green pairing (T-002/T-005): AC-006/AC-007's
   byte-identical outputs are the positive proof; their mutation-based
   negative self-checks (mutate the golden fixture, assert the comparison
   goes red) are the required negative proof, mirroring
   epic-159-pillar-a2's and epic-159-pillar-b's established
   red-demonstrable convention.
2. Field-population pairing (T-004/T-006/T-008): `effort_applied`/
   `effort_degraded_reason` are asserted in BOTH directions per case
   (value-present/reason-absent for Codex `flag` control;
   null/reason-present for every other control) — a single-direction
   assertion would not catch a validator that accepts a record with both
   fields simultaneously populated.
3. Protected-file write/read boundary pairing (T-003): AC-019 (never
   written) and AC-020 (may be read unattended) are independently
   falsifiable claims, tested as two separate assertions rather than one
   combined "handled correctly" check.
4. External-observable proof (T-003's no-op render, AC-017): landing the
   render against real production files and observing zero diff is the
   acceptance signal for correct `role_defaults` seeding — mirroring
   epic-159-pillar-a2's SKIP-to-green external-observable pattern, applied
   here as a diff-to-zero external observable instead.
5. Argv-composition proof, not live-LLM proof (T-006): every REQ-006
   assertion inspects the assembled `codex` command line or the JSON
   selector/prepare-input intermediate output; no test in this feature
   invokes a real LLM (matches the #126 deterministic-lane note carried
   from every prior epic-159-pillar spec).
6. Prerequisite-gate proof (T-007): AC-045 is a `git merge-base
   --is-ancestor` check against the actual release commit, not a manual
   attestation — already demonstrated satisfiable at spec time (Assumptions
   below).
7. Self-registration (round-2 split, following `.github/workflows/test.yml`'s
   protected-file status): `tests/agent-capabilities-v2.tests.sh`,
   `tests/render-agent-frontmatter.tests.sh`,
   `tests/agent-model-routing.tests.ps1` (the new twin), and
   `tests/run-panelist-effort.tests.sh` each grep `tests/run-all.sh`/`.ps1`
   (unprotected, checked directly at agent-commit time) for their own
   basename, mirroring `tests/second-approval-mask.tests.sh:285-289`'s
   established pattern. Each suite's `.github/workflows/test.yml`
   registration cannot be self-checked the same way pre-human-copy (the
   agent never writes that file) — its presence is instead verified by the
   three-part staged/live/applied check AC-027 states for T-005's suite,
   which generalizes to every `test.yml`-touching task in this feature
   (T-001, T-003, T-006 included).
8. Full suite: `bash tests/run-all.sh` and `pwsh tests/run-all.ps1` locally;
   the 3-OS CI matrix is authoritative for TEST-001..TEST-040; TEST-041..
   TEST-046 (T-007) run only at T-007 implementation/release time, gated on
   the prerequisite check above.

## Design Decisions (resolving open questions)

- OQ-001 → v1 and v2 registries coexist for the duration of Phase 1; v1 is
  frozen (never edited, never deleted) and remains the schema every
  pre-existing v1 consumer reads; v2 becomes the sole consulted registry
  only when T-007/#155 flips the selector default (requirements.md Goals
  REQ-001, REQ-007; new ADR-0012).
- OQ-002 → Codex `.toml` `# x-sdd-model:`/`# x-sdd-effort:` comments are
  documentation-only, verified against the current, comment-free
  `.codex/agents/sdd-evaluator.toml`; the actual runtime effort application
  happens exclusively via `codex --model`/`--effort` CLI flags a caller
  script supplies (T-006), and the comments exist purely so T-006's
  cross-check (AC-038) can detect drift between "last rendered reference"
  and "currently selected."
- OQ-003 → the release-ordering gate for T-007 is a documented procedure
  (REQ-007's prerequisite: T-001..T-006 merged + A3 in `main`, verified via
  `git merge-base --is-ancestor`) rather than a new automated CI mechanism;
  building such a mechanism is explicitly out of scope (Non-goals) and
  remains an open automation gap noted for a future issue if a real
  ordering violation is ever observed in practice.
- OQ-004 → the `--effort-policy` default is a hardcoded default inside
  `select-agent-model.sh`/`.ps1`'s own flag-parsing logic (not an external
  config file), changed by exactly one code edit in T-007; `welded` remains
  a fully-supported explicit flag value indefinitely after the flip (no
  deprecation timer, no warning emission) — a caller that still wants
  Phase-1-equivalent behavior after T-007 lands can request it explicitly
  forever.
- New decision (not carried from an investigation OQ): whether T-004's
  `--effort-applied-*` flags accept a bare value or require an accompanying
  `--effort-control-*` flag to disambiguate "not supplied" from "supplied,
  confirmed absent." Decided: require `--effort-control-*` (API/Contract
  Plan above) — a bare `none`-vs-absent string sentinel would be more
  fragile across the `.sh` (POSIX empty-string) and `.ps1` (native `$null`)
  twins than an explicit, typed second flag.
- New decision: whether the new ADR (ADR-0012) supersedes ADR-0003 outright
  or amends it in place. Decided: new ADR that narrows ADR-0003's scope
  (tier selection remains ADR-0003's domain; effort selection moves to
  ADR-0012) rather than editing ADR-0003's already-Accepted text, following
  this repository's established append-only ADR convention (no existing
  ADR in `docs/adr/` is observed to have been retroactively rewritten
  rather than superseded by a later-numbered ADR).

## Global Constraints

Files edited by more than one task in this feature, mirroring
epic-159-pillar-a2's and epic-159-pillar-b's established commit-serialization
precedent:

- `tests/run-all.sh` / `tests/run-all.ps1` (UNPROTECTED, direct agent edit)
  — T-001 adds `agent-capabilities-v2.tests`; T-003 adds
  `render-agent-frontmatter.tests`; T-005 adds
  `agent-model-routing.tests.ps1` (new twin registration) and touches the
  existing `agent-model-routing.tests.sh` entry only to confirm it remains
  registered; T-006 adds `run-panelist-effort.tests`. Land each task's
  array entry in its own, serialized commit.
- `.github/workflows/test.yml` (**R-10 PROTECTED, round-2 correction** —
  `guard_invariants.py:4`) — same four tasks' same additions, but NEVER
  direct-written: each of T-001/T-003/T-005/T-006 stages its own full
  corrected copy under
  `specs/epic-159-pillar-c/human-copy/.github/workflows/test.yml` +
  `MANIFEST.sha256` update, in its own serialized commit, for a human to
  `cp` — the same serialization discipline as the unprotected file above,
  PLUS the protected-file write boundary (Protected-File Statement, above).
  A task whose commit stages this file is not Done until the human-copy
  step is confirmed applied.
- `select-agent-model.sh` / `.ps1` — T-002 is the sole editor within this
  feature; flagged because it is a wave-1/turn-first-routing shared file a
  concurrent, unrelated session could also be editing (same shared-worktree
  caution noted in prior session memory), not because of an intra-feature
  collision.
- `CHANGELOG.md`'s `## Unreleased` section — six of the seven tasks
  (T-001..T-006) each add their OWN entry citing their OWN issue number
  (#149/#150/#151/#153/#154/#152) — unlike epic-159-pillar-a2/b's pattern of
  multiple tasks sharing ONE entry, these are six issues, so six entries;
  no task edits another task's entry. T-007/#155 adds a seventh, separate
  entry at release time.
- `tests/validate-repository.ps1` — T-003 is the sole editor (adds the
  `--check` invocation); flagged for the same shared-file caution as
  `select-agent-model.sh` above.
- `.codex/agents/sdd-evaluator.toml`, `sdd-investigator.toml` — T-003
  writes the reference comments (render); T-006 READS them (cross-check,
  AC-038) but does not edit them further. No write collision.

## Security Boundaries

| Trust Boundary | Auth/Authz Mechanism | Data Classification | OWASP Concerns |
|---|---|---|---|
| B1: registry/candidates-file input to routing decisions | v2 schema validation rejects malformed `supported_efforts`/`effort_control`/`risk_effort_matrix` the same way v1 rejects malformed `efforts` (fail-closed `MODEL_SELECTION_ERROR`) | internal source | Injection (avoided by strict schema validation) |
| B2: render output vs. R-10 protected gate files | protected basenames NEVER opened for write by `render-agent-frontmatter`; scratchpad + SHA-256 manifest + human `cp`; `--check` is read-only against them | internal source | Broken Access Control (prevented) |
| B3: registry/selector output vs. `codex` CLI argument construction | `--model`/`--effort` values passed to `codex` originate only from registry/selector output, never from unsanitized task or spec text | internal source | Injection / command-argument tampering (avoided by construction) |
| B4: run-record effort fields vs. real invocation outcome | `effort_applied` is non-null only on CONFIRMED application (Codex `flag` control, T-006's real invocation); every other path is `null` + a named `effort_degraded_reason` — no path can emit a false "applied" | internal source | Repudiation / false-positive telemetry (prevented) |

Detailed controls: [Security specification](security-spec.md#trust-boundaries).

## External Integrations

None new. `run-panelist-gpt.sh`'s existing `codex` CLI invocation
(`run-panelist-gpt.sh:146`) is extended with one additional flag; no new
network call, service, or third-party action is introduced anywhere in this
feature.

## Deployment / CI Plan

No runtime deployment. Three new suite pairs
(`agent-capabilities-v2`, `render-agent-frontmatter`,
`agent-model-routing.tests.ps1` as a new twin registration) join
`tests/run-all.sh`/`.ps1` directly (unprotected); the corresponding
`.github/workflows/test.yml` registration for each is staged via human-copy
(round-2 correction, Protected-File Statement above) rather than joining
the file directly. `render-agent-frontmatter --check` additionally joins
`tests/validate-repository.ps1`'s existing check sequence. Deterministic
lane (#126 note, carried from every prior epic-159-pillar spec): TEST-001..
TEST-040 plus TEST-051..TEST-054 (T-001 through T-006) require no LLM
invocation; TEST-041..
TEST-046 (T-007's Phase 2 smoke check, AC-044) is the one place a real
Codex-host run is exercised, scoped to T-007's own implementation-time
verification, never to the standard CI matrix. Rollback: T-001..T-006 are
each independently revertible (registry, selector flags, renderer, run-record
fields, tests, and effort threading are additive; reverting any one leaves
`welded` mode and v1 consumers fully functional). Reverting any of
T-001/T-003/T-005/T-006's agent-authored commits does NOT automatically
revert its human-applied `.github/workflows/test.yml` change (round-2
addition) — the revert PR's own description must separately note whether
the corresponding `test.yml` step should be hand-reverted by a human
maintainer, since that step never entered git history via an agent commit
in the first place. T-007's revert restores
the `welded` default; because T-007 changes exactly one default value plus
documentation, its rollback is a single-line revert, not a data migration.

## Constraint Compliance

| Requirement Constraint | Design Response |
|---|---|
| v1 registry frozen / byte-identical (REQ-001, AC-004) | `contracts/agent-model-capabilities.json` is never opened for write by any script in this feature; TEST-004 asserts its SHA-256 unchanged before/after the full suite run, not merely "the parity test passed" |
| welded-mode Phase-1 byte-identical golden baseline, no silent behavior change, `--requested-effort` carve-out stays outside golden scope (REQ-002, REQ-005, AC-007, AC-028, AC-053) | the v2 selector branch computes welded effort using the SAME tiebreak ordinal map the v1 branch already uses (`select-agent-model.sh:110`), against the SAME fixture inputs; TEST-007/TEST-028's mutation-based negative self-check proves the byte-identical comparison is live, not vacuously true; the golden fixture set structurally never includes a `--requested-effort` invocation, so AC-053's carve-out case (TEST-053) is provably disjoint from AC-007/AC-028's comparison set, not a silent narrowing of it |
| `xhigh` justification gate preserved under matrix mode and escalation bump (REQ-001, REQ-002, REQ-005, AC-002, AC-009, AC-031) | the existing `--xhigh-reason` eligibility filter (`select-agent-model.sh:237`) is evaluated AFTER matrix selection and escalation bump, not before — a bump that lands on `xhigh` without a reason drops the candidate rather than silently downgrading; TEST-002/TEST-009/TEST-031 each independently exercise this |
| malformed v2 registry fields rejected fail-closed (REQ-001, REQ-002, AC-054) | `supported_efforts`/`effort_control`/`risk_effort_matrix` schema validation mirrors v1's existing malformed-`efforts` rejection (`select-agent-model.sh:207-215`) — one negative fixture per malformed-field category; TEST-054 gives Security Boundaries B1's construction-only claim (design.md Security Boundaries, below) an executable per-category proof |
| no protected file modified — R-10 reviewer `.md` files (REQ-003, AC-019) | the four protected reviewer `.md` files are structurally excluded from `render-agent-frontmatter`'s write-target resolution function (never merely guarded by a runtime check); TEST-019 asserts the resolution function itself returns the scratchpad path for those four basenames |
| protected-file read boundary is permitted and CI-unattended (REQ-003, AC-020) | `--check` mode's comparison logic opens the four protected files for READ only, which does not trigger the R-10 write guard; TEST-020 runs this unattended in CI and asserts correct drift reporting without any guard error |
| protected `.github/workflows/test.yml` via human-copy staging (round-2 CRITICAL remedy; REQ-005, AC-027; Protected-File Statement, above) | `.github/workflows/test.yml` is confirmed R-10 protected at `guard_invariants.py:4` — no task (T-001, T-003, T-005, T-006) ever opens it for write; each stages its full corrected copy under `specs/epic-159-pillar-c/human-copy/.github/workflows/test.yml` + `MANIFEST.sha256` instead; TEST-027 verifies all three parts independently — staged-candidate existence/manifest-consistency, live-file byte-identity (agent never wrote it), and post-human-`cp` self-registration — so no single assertion could pass "by accident" if any one part were violated |
| `.sh`/`.ps1` twin pairs mandatory (all REQs) | `agent-capabilities-v2`, `render-agent-frontmatter`, `run-panelist-effort` ship as twins from creation; `agent-model-routing.tests.ps1` is authored as a NEW file specifically to close the pre-existing twin gap (REQ-005); every edited existing script (`select-agent-model`, `emit-run-record`, `run-panelist-gpt`, `prepare-panelist-input`) already has a twin and both sides of each twin are edited together |
| cross-host (Claude Code / Codex) degradation, never silent, keyed on `effort_control` not host name (REQ-004, REQ-006, REQ-008, AC-039, AC-047, AC-048, AC-051) | every effort-consuming surface has a demonstrated Claude Code case: `effort_control` resolves to `frontmatter` for every Claude-side model, `effort_applied` is structurally `null` with a populated `effort_degraded_reason` on that path (not merely a convention — the run-record's field-population logic makes non-null `effort_applied` impossible when `effort_control != "flag"`); the SAME structural rule additionally covers a Codex-host invocation that selects a non-`flag`-control model (AC-051, TEST-051), proving the rule is host-independent, not Claude-Code-specific; TEST-039/TEST-047/TEST-048/TEST-051 assert this as a PASS outcome, never a FAIL/SKIP |
| run-record truthfulness: `effort_applied` never false-positive (REQ-004, REQ-006, AC-023, AC-038) | `effort_applied` is populated only by T-006's confirmed-application code path (the actual `codex --effort` invocation succeeding), never by the selector's mere INTENT to apply; TEST-023/TEST-038 assert both the positive (Codex, confirmed) and negative (every other) cases |
| CLI-argument-injection resistance is executably verified, not construction-only (REQ-006, Security Boundaries B3, AC-052) | `run-panelist-gpt`/Codex-startup argv assembly rejects any `--model`/`--effort` value outside the registry's enumerated vocabulary (whitespace, leading `-`/`--`, `;`, out-of-enum effort) with a non-zero exit and zero `codex` invocations; TEST-052 exercises each rejected-value shape independently |
| release-ordering gate for T-007 (REQ-007, AC-045, AC-046) | T-007's implementation report contains a `git merge-base --is-ancestor` check against BOTH the A3 commit and each of T-001..T-006's merge commits, re-run against the actual release commit rather than relying on the spec-time verification alone (Assumptions below) |
| doc-following in same PR (REQ-009, AC-049) | each of T-001..T-006 lists its own applicable-doc subset in Main Workflows (requirements.md); `CHANGELOG.md` gets one entry per issue, not a shared entry |
| version bump via `scripts/bump-version.sh` only (REQ-009, AC-050) | this feature introduces no alternate version-mutation path; T-007's release is explicitly its OWN, separate invocation of the same script, sequenced after Phase 1's own (if any) release |
| CI resilience: bash 3.2 `set -u` empty-array safety | none of the three new `.sh` suites declares a possibly-empty array under `set -u`; the `--role`/`--host`/`--effort-policy` case dispatch in `select-agent-model.sh` uses `case`/string comparison, not array indexing |
| CI resilience: macOS `$TMPDIR` symlink normalization | every new mktemp fixture root (registry parity fixtures, selector golden fixtures, render-agent-frontmatter scratchpad staging under `specs/epic-159-pillar-c/human-copy/`, run-record test fixtures) is normalized with `pwd -P` immediately after creation, mirroring `tests/lib/loop-driver.sh:124` |
| CI resilience: Windows `jq.exe` CRLF stripping | every new JSON-output-consuming assertion in `agent-model-routing.tests.sh`/`.ps1` and `emit-run-record-feature-scope.tests.sh`/`.ps1` pipes `jq` output through `tr -d '\r'` unconditionally on the bash side; the `.ps1` twins use native `ConvertFrom-Json`, which is not subject to the same CRLF hazard |
| CI resilience: real-validator capability probe | no suite in this feature drives `validate-review-context-set.sh` or any other real validator gate; this is a non-use declaration, mirroring epic-159-pillar-a2's INV-032 non-use pattern |

## Assumptions

`select-agent-model.sh`'s eligibility filter and sort key
(`select-agent-model.sh:232-247`) and escalation logic
(`:155-184`) remain as observed at design time; T-002's new flags compose
with, and do not alter, this existing logic. `.codex/agents/sdd-evaluator.toml`
and `sdd-investigator.toml` remain free of any model/effort TOML key at
design time (verified directly); if a future, unrelated Codex CLI upgrade
begins consuming such a key at runtime, OQ-002's "documentation-only"
design would need re-verification, but no such change is in scope or
expected here. A3 (`2d8c6a561e0f5d2bc29ded4195c057d4cc918f2f`, "fix:
unblock impl review rounds after the first (#143)") is confirmed via `git
merge-base --is-ancestor 2d8c6a5 HEAD` to already be an ancestor of this
spec's HEAD (`f6b1365`) at design time; T-007's own implementation report
re-verifies this against the actual release commit rather than relying on
this design-time snapshot alone. `_PROTECTED_GATE_SUFFIXES`
(`sdd-hook-guard.py:886-927`) remains as observed; no file this feature
creates is added to it during this feature's lifetime other than the four
already-protected reviewer `.md` files this feature routes around, never
into.

## Open Questions

None blocking. All investigation.md OQ-001..OQ-004 are resolved above with
design decisions; the two additional decisions this design makes (the
`--effort-control-*` disambiguating flag; ADR-0012 as a new, narrowing ADR
rather than an ADR-0003 rewrite) are stated as resolved decisions, not left
open, because both are reversible, low-risk, additive choices a future
issue could revisit without touching this feature's deliverables.

## Risks

Principal risk is the welded-mode golden baseline going stale without
anyone noticing (a golden fixture edited to make a failing test pass,
rather than to fix a real regression) — mitigation is the mandatory
mutation-based negative self-check (Test Strategy item 1), which fails the
suite itself if the baseline comparison were ever made vacuous. Secondary
risk is T-007 landing ahead of its prerequisites despite the documented
gate, since no automated CI mechanism blocks it (OQ-003) — mitigation is
AC-045's `git merge-base` re-verification as a hard, reviewed Done
condition at T-007's own quality-gate time, not merely a spec-time note.
Tertiary risk is a future `render-agent-frontmatter` edit accidentally
widening its write-target resolution to include a protected basename —
mitigation is TEST-019's assertion against the resolution FUNCTION itself
(Constraint Compliance above), which would fail even before any write
attempt reached the R-10 guard. Quaternary risk is the six-way
`CHANGELOG.md` entry fan-out (one per T-001..T-006 issue) creating merge
churn if two tasks land in close succession — mitigation is the Global
Constraints section's per-task serialized-commit convention, unchanged from
epic-159-pillar-a2/b precedent.
