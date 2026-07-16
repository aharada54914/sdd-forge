# Tasks: epic-159-pillar-c

Task-Review-Status: Pending

Source: Issues #149-#155 (epic #159, Pillar C — effort routing v2; Phase 1
= #149-154, Phase 2 = #155 single release) /
requirements.md (Spec-Review-Status: Passed) /
design.md (Impl-Review-Status: Passed)

## Lifecycle

`Draft -> Approved -> In Progress -> Implementation Complete -> Done`

A task may enter `Blocked` from any active state. Humans approve tasks.
`implement-task` may set `In Progress`, `Blocked`, or `Implementation Complete`.
Only `quality-gate` may set `Done`.

## Protected Files

Five files this feature's tasks touch are R-10 enforcement-chain protected
(`_PROTECTED_GATE_SUFFIXES` at
`plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4`, loaded
by `sdd-hook-guard.py:891`'s `_load_guard_invariants()`, verified against
current HEAD): the four Claude review-loop reviewer agent files
(`plugins/sdd-review-loop/agents/impl-reviewer-a.md`, `impl-reviewer-b.md`,
`task-reviewer-a.md`, `task-reviewer-b.md`) and `.github/workflows/test.yml`.
**No task below writes any of these five files directly.** T-003 renders
corrected content for the four reviewer files to
`specs/epic-159-pillar-c/human-copy/<basename>` + `MANIFEST.sha256`; T-001,
T-003, T-005, and T-006 each stage their own full corrected copy of
`.github/workflows/test.yml` to
`specs/epic-159-pillar-c/human-copy/.github/workflows/test.yml` +
`MANIFEST.sha256` (the same manifest, one entry per staged file). A human
maintainer runs the `cp` for each staged file and verifies its SHA-256
against the manifest before that task can be marked Done (design.md
Protected-File Statement; security-spec.md B2). `render-agent-frontmatter
--check`'s read-only comparison against the four reviewer files, and every
task's own read of the live `.github/workflows/test.yml` for its
three-part AC-027-style verification, are explicitly permitted — reading
is not writing and does not trigger the R-10 guard.

Every OTHER file this feature's tasks touch (`contracts/agent-model-capabilities.v2.json`,
`select-agent-model.sh`/`.ps1`, `render-agent-frontmatter.sh`/`.ps1`,
`emit-run-record.sh`/`.ps1`, `run-panelist-gpt.sh`/`.ps1`,
`prepare-panelist-input.sh`/`.ps1`, `tests/run-all.sh`/`.ps1`,
`tests/validate-repository.ps1`, `.codex/agents/sdd-evaluator.toml`,
`sdd-investigator.toml`, `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md`,
`PLUGIN-CONTRACTS.md`, `docs/agent-capability-matrix.md`, `USERGUIDE.md`,
`CHANGELOG.md`, `implementation-report.template.md`) is verified absent
from `PROTECTED_GATE_SUFFIXES`/`PROTECTED_GATE_PLUGIN_JSON_SUFFIXES` and is
agent-editable directly (design.md Protected-File Statement).

**Re-verification discipline** (requirements.md Assumptions; carried into
every task's Done-When below): `PROTECTED_GATE_SUFFIXES` is a
live-repository snapshot re-verified at round-2 spec-review-remedy time,
not a permanent guarantee — every task whose Planned Files include
`.github/workflows/test.yml` (T-001, T-003, T-005, T-006) re-runs
`grep -F ".github/workflows/test.yml"
plugins/sdd-quality-loop/scripts/generated/guard_invariants.py` at its own
implementation-start time before assuming the human-copy procedure is
still required.

## Global Constraints

- **Two-commit landing plan per task** (commit A = implementation, commit
  B = docs), the same task-review round-1 TASK-SIZE precedent
  epic-159-pillar-b established: commit A is the script/contract/test edit
  + `tests/run-all.sh`/`.ps1` registration (where applicable) + staging the
  `.github/workflows/test.yml` candidate under `human-copy/` (where
  applicable); commit B is the `CHANGELOG.md` entry + the REQ-009 doc
  surfaces that task's own Main Workflows entry names. Commit A must land
  before commit B within the same task. Unlike epic-159-pillar-b (one
  shared issue, two tasks), each of T-001..T-006 here has its OWN issue
  number (#149/#150/#151/#153/#154/#152), so each task's `CHANGELOG.md`
  entry is its OWN new `## Unreleased` block, never an append to another
  task's entry.
- **Version bumps only via `scripts/bump-version.sh`**; never hand-edit
  versions. T-001..T-006 introduce no version-mutation path at all; T-007
  is the ONLY task that executes a real `scripts/bump-version.sh`
  invocation, as its own, separate release (requirements.md REQ-009;
  design.md Constraint Compliance).
- **`tests/run-all.sh` / `tests/run-all.ps1`** (unprotected, direct edit):
  T-001, T-003, T-005, and T-006 each append only their OWN new suite's
  registration lines, in the serialized order the Depends On / Blockers
  fields below establish (T-001 -> T-003 -> T-005 -> T-006 for this shared
  array specifically, layered on top of each task's own functional
  Blockers).
- **`.github/workflows/test.yml`** (R-10 PROTECTED — see Protected Files,
  above): the same four tasks (T-001, T-003, T-005, T-006) each stage their
  own registration addition via human-copy, in the SAME serialized order,
  so no two tasks' staged candidates race each other under
  `specs/epic-159-pillar-c/human-copy/`.
- **`select-agent-model.sh` / `.ps1`**: T-002 is the sole editor within
  this feature.
- **`tests/validate-repository.ps1`**: T-003 is the sole editor (adds the
  `render-agent-frontmatter --check` invocation).
- **`.codex/agents/sdd-evaluator.toml`, `sdd-investigator.toml`**: T-003
  writes the `# x-sdd-model:`/`# x-sdd-effort:` reference comments; T-006
  reads them (cross-check, AC-038) but never edits them further.
- **`docs/adr/0012-effort-tier-decoupling.md`** (new): drafted and added to
  the repository as PART OF T-002's implementation commit A (design.md ADR
  Change Log, Drafting ownership paragraph — round-2 impl-review remedy).
  T-002's implementer re-verifies via `ls docs/adr/` at drafting time that
  `0012` is still free (a concurrent, unrelated merge could have occupied
  it since spec/design time) and renumbers — updating both the ADR's own
  filename and every `docs/adr/00NN-effort-tier-decoupling.md` / `ADR-00NN`
  reference in `design.md` in the same commit — if it is not.
- **CI-resilience** (requirements.md Edge Cases; design.md Constraint
  Compliance CI-resilience rows) applies to every new `.sh` suite this
  feature adds (T-001, T-003, T-005's new `.ps1` twin, T-006): no
  possibly-empty bash array expanded under `set -u`; every directly-created
  mktemp root normalized with `pwd -P` immediately after creation; any jq
  output consumption piped through `tr -d '\r'` unconditionally; no suite
  drives a real validator gate directly (non-use declaration, all tasks).
- Fixture writes happen inside script/test files only; no task places a
  protected basename together with a write verb on a Bash command line
  (security-spec.md B3-equivalent convention, carried from
  epic-159-pillar-a2/b's Global Constraints).
- Preserve unrelated changes; implement one task at a time.
- **T-007 is a SEPARATE PR and a SEPARATE RELEASE from T-001..T-006** — it
  is not bundled into this wave's PR(s) under any circumstance
  (requirements.md REQ-007, REQ-009; Main Workflows item 7).

---

## T-001 Create the v2 registry and its parity lock

Source Issue: https://github.com/aharada54914/sdd-forge/issues/149

Approval: Draft

Status: Planned

Risk: medium

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly (release/contract-adjacent change, not defaulted). medium is
justified on three grounds: (1) the change is a NEW, additive JSON
contract file plus a new, additive parity-lock suite — the frozen v1 file
(`contracts/agent-model-capabilities.json`) is never opened for write
(AC-004; TEST-004's SHA-256 check is the external, mechanical proof, not
self-certification); (2) no existing script, contract consumer, or CI step
is edited by this task beyond additive registration lines
(`tests/run-all.sh`/`.ps1`, `.github/workflows/test.yml` staging); (3) the
task does not touch authentication, payments, data migration, or an
irreversible operation — it does not reach `high` because nothing it adds
is yet CONSUMED by production code (T-002 is the first consumer). It is
not `low` because it introduces a new schema other tasks structurally
depend on (design.md Technical Summary: "the single source of truth every
other component reads from").

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-001, REQ-009 (share)

Depends On: none (design.md Technical Summary: the registry is the root of
the dependency graph; issue #149's own body: "依存: なし（Pillar C の起点）").

Planned Files:
- `contracts/agent-model-capabilities.v2.json` (new, agent-editable —
  design.md API/Contract Plan schema)
- `tests/agent-capabilities-v2.tests.sh` (new, agent-editable)
- `tests/agent-capabilities-v2.tests.ps1` (new, agent-editable)
- `tests/run-all.sh` (existing, agent-editable — this suite's registration)
- `tests/run-all.ps1` (existing, agent-editable — this suite's registration)
- `specs/epic-159-pillar-c/human-copy/.github/workflows/test.yml` (new
  staged candidate, agent-editable — this suite's CI steps; R-10 protected
  real path, human-copy only)
- `specs/epic-159-pillar-c/human-copy/MANIFEST.sha256` (new, agent-editable
  — SHA-256 entry for the staged `test.yml` candidate)
- `PLUGIN-CONTRACTS.md` (existing, agent-editable — new v2 schema section,
  AC-005)
- `CHANGELOG.md` (existing, agent-editable — CREATE the `## Unreleased`
  entry citing #149)

Data Migration: none — v1 and v2 coexist; no in-place migration
(design.md Data Plan, Migration Strategy).

Breaking API: no; v2 is a wholly new, additive file. v1's schema, field
names, and semantics are unchanged (byte-identical, AC-004).

Rollback: revert this task's two commits (B then A, or both together);
nothing protected is written directly by either commit (staged `test.yml`
candidates are a human-applied change, not part of the agent's own commit
history the way an unprotected file's edit is — reverting the agent's
commits does not automatically revert any already-human-applied
`test.yml` change; the revert PR states explicitly whether a human should
also hand-revert that step). Reverting restores today's v1-only registry
state.

### Goal

Author `contracts/agent-model-capabilities.v2.json` (schema
`agent-model-capabilities/v2`) with `supported_efforts`, `default_effort`,
`effort_control` per model; a top-level `risk_effort_matrix`
(low/medium/high/critical -> low/medium/high/high, `escalation_bump: true`,
never a direct `xhigh` output); and `role_defaults` for the five listed
roles. Leave `contracts/agent-model-capabilities.json` (v1) byte-identical.
Author `tests/agent-capabilities-v2.tests.sh`/`.ps1` locking the
two-directional v1<->v2 parity invariant with a mutation-based negative
self-check, and the malformed-field-category rejection cases AC-054 needs
from the registry-content side (T-002 implements and owns the actual
rejection behavior; this task's suite may share fixtures). Extend
`PLUGIN-CONTRACTS.md` with the new schema's documentation.

### Must Read

- `specs/epic-159-pillar-c/requirements.md`
- `specs/epic-159-pillar-c/design.md`
- `specs/epic-159-pillar-c/acceptance-tests.md`
- `specs/epic-159-pillar-c/investigation.md`
- `specs/epic-159-pillar-c/security-spec.md`
- `specs/epic-159-pillar-c/infra-spec.md`
- `contracts/agent-model-capabilities.json` (the v1 file this task's parity
  suite locks read-only; INV-001)
- `plugins/sdd-implementation/scripts/select-agent-model.sh:1-273` (the v1
  consumer whose behavior must remain unaffected; not edited by this task)
- `PLUGIN-CONTRACTS.md` (the doc surface this task extends)
- `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:1-20`
  (the current `PROTECTED_GATE_SUFFIXES` tuple — confirms
  `.github/workflows/test.yml`'s protected status before staging)

### Scope

Commit A (implementation — registry + parity suite + CI wiring):

- Write the acceptance checks first (TEST-001..005, TEST-054's
  registry-side share): schema/field presence (AC-001); `risk_effort_matrix`
  exact mapping + no direct `xhigh` (AC-002); `role_defaults` presence for
  all five roles (AC-003); the two-directional parity lock + SHA-256
  unchanged + mutation-based negative self-check (AC-004); doc-section
  presence (AC-005).
- CI resilience: any directly-created mktemp fixture root is `pwd -P`
  normalized immediately after creation; no possibly-empty array under
  `set -u`; no jq consumption, or `tr -d '\r'` if any is added; no
  real-validator invocation.
- Register the new suite (`.sh` and `.ps1`) in `tests/run-all.sh`/`.ps1`
  directly; stage the `.github/workflows/test.yml` candidate with this
  suite's new steps under `specs/epic-159-pillar-c/human-copy/` +
  `MANIFEST.sha256` (never a direct write to the real path — Protected
  Files, above).

Commit B (documentation):

- CREATE the `CHANGELOG.md` `## Unreleased` entry citing #149.
- Extend `PLUGIN-CONTRACTS.md` with the v2 schema documentation (AC-005).
- Re-run `tests/validate-repository.ps1` locally where feasible and record
  the result (full `--check` verification requires T-003's renderer, which
  has not landed yet at T-001 time — record this scope limit, not a
  failure).

### Done When

- [ ] TEST-001 proves the v2 file's schema field and per-model
  `supported_efforts`/`default_effort`/`effort_control` shape (AC-001).
- [ ] TEST-002 proves the exact `risk_effort_matrix` mapping,
  `escalation_bump: true`, and no direct `xhigh` output (AC-002).
- [ ] TEST-003 proves `role_defaults` covers all five roles (AC-003).
- [ ] TEST-004 proves v1's SHA-256 is unchanged before/after, the
  two-directional parity invariant holds, and the mutation-based negative
  self-check turns red on an intentionally broken fixture (AC-004).
- [ ] TEST-005 proves `PLUGIN-CONTRACTS.md` documents the v2 schema
  (AC-005).
- [ ] `tests/agent-capabilities-v2.tests.sh`/`.ps1` self-register in
  `tests/run-all.sh`/`.ps1` (grep self-check).
- [ ] Staged `.github/workflows/test.yml` candidate exists under
  `specs/epic-159-pillar-c/human-copy/` with a correct `MANIFEST.sha256`
  entry; the LIVE `.github/workflows/test.yml`'s SHA-256 is unchanged
  before/after this task's own commits (part of AC-027's pattern, verified
  per-task starting here).
- [ ] `CHANGELOG.md` gains a NEW `## Unreleased` entry citing #149
  (AC-049 share).
- [ ] A grep-based self-check over this task's full diff confirms no
  version string was mutated anywhere outside a `scripts/bump-version.sh`
  invocation (AC-050 share).
- [ ] Acceptance-first evidence recorded in the implementation report: RED
  (the parity suite run against a version of the fixture where a v1 effort
  is deliberately removed from v2's `supported_efforts`, proving the
  suite is not vacuously green) and GREEN (the same suite passing against
  the real, correct v2 file). An independent quality-gate verdict records
  PASS.

### Out of Scope

- Any change to `select-agent-model.sh`/`.ps1` (T-002).
- Refreshing model entries to their current generation (explicit
  Non-goal, deferred to a future "D3" task outside this epic).
- The malformed-field REJECTION runtime behavior itself (AC-054's actual
  enforcement lives in `select-agent-model.sh`, T-002) — this task may
  supply fixtures but does not implement or claim ownership of the
  rejection code path.

### Blockers

None

---

## T-002 Add selector v2 support, effort-resolution priority, and ADR-0012

Source Issue: https://github.com/aharada54914/sdd-forge/issues/150

Approval: Draft

Status: Planned

Risk: medium

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. medium is justified on three grounds: (1) the change is
STRICTLY ADDITIVE against the v1 code path
(`select-agent-model.sh:192-230`, byte-unmodified) and gated behind a
schema-detection branch — v1 callers observe zero behavioral change
(AC-006's byte-identical golden, with TEST-006's mutation-based negative
self-check as the external, mechanical proof); (2) the new `welded` default
similarly reproduces today's v1-equivalent output byte-for-byte (AC-007,
TEST-007); (3) the malformed-registry rejection this task implements
(AC-054) NARROWS acceptance (fail-closed), it does not widen what
previously succeeded (security-spec.md B1). It does not reach `high`
because no existing validation or eligibility logic is loosened or
removed — only new, opt-in flags are added (contrast
`specs/workflow-state-integrity/tasks.md:23-26`'s `high`-classified
precedent, which changed predecessor validation logic).

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-002, REQ-009 (share)

Depends On: T-001 (functional — the v2 schema this task auto-detects and
parses; issue #150's own body: "依存: C1"). No shared-registration-file
serialization concern: this task extends the ALREADY-registered
`tests/agent-model-routing.tests.sh` in place (no new `run-all`/`test.yml`
entry — the full twin-registration work is T-005's).

Planned Files:
- `plugins/sdd-implementation/scripts/select-agent-model.sh` (existing,
  agent-editable — schema auto-detect, `--effort-policy`,
  `--requested-effort`, `--role`, `--host`, additive JSON keys, malformed-field
  rejection; design.md API/Contract Plan)
- `plugins/sdd-implementation/scripts/select-agent-model.ps1` (existing,
  agent-editable — twin)
- `tests/agent-model-routing.tests.sh` (existing, agent-editable —
  Phase-1-scoped smoke of the new flags; full case list lands with T-005)
- `docs/adr/0012-effort-tier-decoupling.md` (new, agent-editable — drafted
  as part of THIS task's commit A; design.md ADR Change Log, Drafting
  ownership)
- `CHANGELOG.md` (existing, agent-editable — CREATE the `## Unreleased`
  entry citing #150)

Data Migration: none.

Breaking API: no; every pre-existing `select-agent-model` JSON key
(`model`, `canonical_tier`, `effort`, `estimated_cost_per_attempt_usd`,
`available_candidates`, `xhigh_reason`, `escalation`) is unchanged in name
and type — the two new keys (`effort_source`, `effort_control`) are
additive only (design.md API/Contract Plan).

Rollback: revert this task's two commits; nothing protected is touched
(this task stages no `test.yml` candidate — Global Constraints). Reverting
also reverts `docs/adr/0012-effort-tier-decoupling.md`'s addition; a
revert PR must state whether the ADR should remain (documenting a decision
already acted upon elsewhere) or be removed together with the code it
records.

### Goal

Add schema auto-detection (v1 byte-identical; v2 new branch) plus
`--effort-policy welded|matrix`, `--requested-effort`, `--role`, `--host`
to `select-agent-model.sh`/`.ps1`, implementing the full effort-resolution
priority order requirements.md's REQ-002 states (`--requested-effort` >
`welded`-default > `risk_effort_matrix` > `role_defaults` fallback >
model's own `default_effort`), the malformed-v2-field rejection (AC-054),
and the `welded` + `--requested-effort` carve-out (AC-053) that stays
outside AC-007's golden-comparison scope. Draft and add
`docs/adr/0012-effort-tier-decoupling.md` in this same commit, re-verifying
via `ls docs/adr/` that `0012` is still free at drafting time.

### Must Read

- `specs/epic-159-pillar-c/requirements.md`
- `specs/epic-159-pillar-c/design.md`
- `specs/epic-159-pillar-c/acceptance-tests.md`
- `specs/epic-159-pillar-c/investigation.md`
- `specs/epic-159-pillar-c/security-spec.md`
- `plugins/sdd-implementation/scripts/select-agent-model.sh:1-273` (the
  script this task edits; existing eligibility/sort/escalation logic at
  lines 110, 155-184, 232-247, 237 must remain unmodified in behavior)
- `plugins/sdd-implementation/scripts/select-agent-model.ps1` (the twin)
- `contracts/agent-model-capabilities.v2.json` (T-001's registry, read by
  the new v2 branch)
- `docs/adr/0003-turn-first-agent-routing.md` (the ADR this task's new ADR
  narrows, not rewrites — design.md ADR Change Log)
- `docs/adr/` directory listing (`ls docs/adr/`, re-verified at drafting
  time before naming the new ADR file)

### Scope

Commit A (implementation — selector + ADR):

- Write the acceptance checks first (TEST-006..013, TEST-053, TEST-054):
  v1 byte-identical golden + negative canary; v2 welded byte-identical
  golden + negative canary; matrix mode risk-based selection + escalation
  bump + clamp; `--requested-effort` override (both policies, AC-010/
  AC-053); `--role` tier-seed-always / effort-seed-conditional (AC-011);
  `--host` + `effort_source` 5-way attribution (AC-012); v2
  `--candidates-file` optional `effort` (AC-013); malformed-field rejection
  per category (AC-054).
- CI resilience: no possibly-empty array under `set -u` in the new
  `case`/flag-dispatch logic; no jq consumption change beyond existing
  patterns.
- Implement the effort-resolution priority order exactly as design.md's
  API/Contract Plan specifies, composing with (not replacing) the existing
  eligibility filter, sort key, and escalation logic.
- `ls docs/adr/`; if `0012-*.md` is unoccupied, draft
  `docs/adr/0012-effort-tier-decoupling.md`; if occupied by a concurrent
  merge, renumber to the next free slot and update every
  `docs/adr/00NN-effort-tier-decoupling.md` / `ADR-00NN` reference in
  `design.md` in this same commit.

Commit B (documentation):

- CREATE the `CHANGELOG.md` `## Unreleased` entry citing #150.
- Re-run `tests/validate-repository.ps1` and confirm the ADR is
  discoverable and correctly cross-referenced.

### Done When

- [ ] TEST-006 proves v1-registry output (incl. legacy positional
  `--candidate`) is byte-identical to the pre-feature baseline (AC-006).
- [ ] TEST-007 proves v2-registry `welded` output is byte-identical to the
  pre-feature baseline, with a mutation-based negative self-check (AC-007).
- [ ] TEST-008 proves `matrix --risk high --required-tier standard`
  selects `sonnet` at `high` (AC-008).
- [ ] TEST-009 proves the clamp and escalation-bumped `xhigh` gate
  (AC-009).
- [ ] TEST-010 proves `--requested-effort` overrides under `matrix`,
  clamped and `xhigh`-gated (AC-010).
- [ ] TEST-011 proves `--role` always seeds `--minimum-tier`, and seeds a
  fallback effort ONLY under `matrix` with a `risk_effort_matrix` gap
  (AC-011).
- [ ] TEST-012 proves `--host`-resolved `effort_control` and the 5-way
  `effort_source` attribution (AC-012).
- [ ] TEST-013 proves the v1/v2 `--candidates-file` `effort`-field
  divergence (AC-013).
- [ ] TEST-053 proves `--requested-effort` under `welded` (or no policy
  flag) applies the requested value (`effort_source: "requested"`) and is
  provably outside AC-007's golden-comparison set (AC-053).
- [ ] TEST-054 proves each malformed-v2-field category
  (`supported_efforts`, `effort_control`, `risk_effort_matrix`) is
  rejected fail-closed with a `MODEL_SELECTION_ERROR`-class diagnostic
  (AC-054).
- [ ] `docs/adr/0012-effort-tier-decoupling.md` exists, is correctly
  numbered (re-verified via `ls docs/adr/` at drafting time, not merely
  assumed from the spec), and is cross-referenced correctly everywhere
  `design.md` names it.
- [ ] `CHANGELOG.md` gains a NEW `## Unreleased` entry citing #150
  (AC-049 share).
- [ ] A grep-based self-check confirms no version string was mutated
  outside `scripts/bump-version.sh` (AC-050 share).
- [ ] Acceptance-first evidence recorded: RED (each new flag's
  pre-landing absence — `select-agent-model.sh` rejects `--effort-policy`/
  `--requested-effort`/`--role`/`--host` today as unknown arguments) and
  GREEN (the full TEST-006..013/053/054 suite passing post-landing). An
  independent quality-gate verdict records PASS.

### Out of Scope

- `render-agent-frontmatter.sh`/`.ps1` (T-003).
- The full routing-test case list beyond this task's Phase-1-scoped smoke
  (T-005 owns `tests/agent-model-routing.tests.ps1`'s authoring and the
  `.sh` twin's full case-list extension).
- Making `--effort-policy matrix` the default anywhere (T-007 only,
  separate release).

### Blockers

T-001

---

## T-003 Author render-agent-frontmatter, --check, and the protected-file human-copy procedure

Source Issue: https://github.com/aharada54914/sdd-forge/issues/151

Approval: Draft

Status: Planned

Risk: high

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly — this task touches a sensitive surface (writes to REAL,
production Claude `.md` and Codex `.toml` agent-definition files that
downstream review/evaluation gates execute as system prompts, PLUS the
protected-file boundary itself for five R-10 files). high is justified,
not merely asserted: (1) a defect in the write-target resolution function
could corrupt an enforcement-chain reviewer file — TEST-019 asserts the
resolution FUNCTION itself excludes all five protected basenames,
independent of and in addition to the R-10 hook-guard's own runtime
enforcement (design.md Constraint Compliance; security-spec.md STRIDE B2);
(2) `--check`'s read-vs-write boundary (TEST-020) is a second,
independently falsifiable claim, not folded into the write-boundary proof;
(3) this is the one task in the feature whose blast radius, if wrong,
reaches every future Claude/Codex agent invocation across the whole
repository, not merely this feature's own test suites. Required Workflow
is therefore `tdd` per `risk-gate-matrix.md` (high/critical require
red->green evidence, not `acceptance-first` — `plugins/sdd-quality-loop/references/risk-gate-matrix.md:26`).

Required Workflow: tdd

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-003, REQ-009 (share)

Depends On: T-001 (functional — reads `role_defaults` directly from the v2
registry per design.md's Architecture diagram, no runtime dependency on
T-002's selector; issue #151's own body: "依存: C1"). Also touches the
shared `tests/run-all.sh`/`.ps1` array and `test.yml` staging — serialized
after T-001 per Global Constraints (T-002 does not touch these files, so
no additional serialization against T-002 is needed).

Planned Files:
- `render-agent-frontmatter.sh` (new, agent-editable — design.md
  API/Contract Plan)
- `render-agent-frontmatter.ps1` (new, agent-editable — twin)
- `tests/render-agent-frontmatter.tests.sh` (new, agent-editable)
- `tests/render-agent-frontmatter.tests.ps1` (new, agent-editable)
- `plugins/sdd-quality-loop/agents/evaluator.md` (existing, agent-editable
  — unprotected render target)
- `plugins/sdd-bootstrap/agents/investigator.md` (existing, agent-editable
  — unprotected render target)
- other unprotected role-mapped Claude `.md` agent files per the
  `TARGETS` map (design.md API/Contract Plan)
- `.codex/agents/sdd-evaluator.toml`, `.codex/agents/sdd-investigator.toml`
  (existing, agent-editable — reference-comment render targets)
- `specs/epic-159-pillar-c/human-copy/plugins/sdd-review-loop/agents/impl-reviewer-a.md`,
  `impl-reviewer-b.md`, `task-reviewer-a.md`, `task-reviewer-b.md` (new
  staged candidates, agent-editable — R-10 protected real paths, human-copy
  only)
- `specs/epic-159-pillar-c/human-copy/.github/workflows/test.yml` (staged
  candidate, agent-editable — this suite's CI steps + `--check` step; R-10
  protected real path)
- `specs/epic-159-pillar-c/human-copy/MANIFEST.sha256` (existing after
  T-001, agent-editable — five new entries: four reviewer files + this
  task's `test.yml` candidate)
- `tests/run-all.sh` (existing, agent-editable — this suite's registration)
- `tests/run-all.ps1` (existing, agent-editable — this suite's registration)
- `tests/validate-repository.ps1` (existing, agent-editable — `--check`
  invocation)
- `CHANGELOG.md` (existing, agent-editable — CREATE the `## Unreleased`
  entry citing #151)

Data Migration: none.

Breaking API: no; `render-agent-frontmatter` is a wholly new script. No
existing script's contract changes. The Claude `.md`/Codex `.toml` files it
writes gain a `model:`/`x-sdd-effort:` line or reference comments only —
no existing frontmatter key or TOML key is removed (design.md API/Contract
Plan).

Rollback: revert this task's two commits; the render script and its suite
are additive and independently revertible. The four protected reviewer
files and `.github/workflows/test.yml` are NEVER part of the agent's own
commit history (human-applied only) — a revert PR must separately state
whether any already-human-applied protected-file change should also be
hand-reverted, and by whom (design.md Deployment/CI Plan).

### Goal

Author `render-agent-frontmatter.sh`/`.ps1`: rewrite only the `model:`
line plus insert/refresh `x-sdd-effort:` in unprotected Claude `.md`
targets; insert/refresh `# x-sdd-model:`/`# x-sdd-effort:` comments in
Codex `.toml` targets; stage corrected content for the four protected
reviewer `.md` files AND `.github/workflows/test.yml` under
`specs/epic-159-pillar-c/human-copy/` with a `MANIFEST.sha256`, never
writing any of the five directly; implement `--check` as a strictly
read-only drift detector (including read-only comparison against the five
protected files) wired into CI and `tests/validate-repository.ps1`. Seed
`role_defaults` from CURRENT hardcoded values so the first render against
real files is zero-diff.

### Must Read

- `specs/epic-159-pillar-c/requirements.md`
- `specs/epic-159-pillar-c/design.md`
- `specs/epic-159-pillar-c/acceptance-tests.md`
- `specs/epic-159-pillar-c/security-spec.md`
- `specs/epic-159-pillar-c/infra-spec.md`
- `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:1-20`
  (current `PROTECTED_GATE_SUFFIXES`, re-verified before writing anything)
- `plugins/sdd-quality-loop/agents/evaluator.md:6` (a representative
  unprotected render target — hardcoded `model: opus` today, INV-003)
- `.codex/agents/sdd-evaluator.toml` (a representative Codex render target
  — no model/effort key today, verified)
- `plugins/sdd-review-loop/agents/impl-reviewer-a.md`,
  `impl-reviewer-b.md`, `task-reviewer-a.md`, `task-reviewer-b.md` (the
  four PROTECTED render targets — read-only reference for the human-copy
  content this task computes; never written directly)
- `specs/epic-136-phase2-gates/human-copy/` (the established human-copy
  procedure precedent this task's staging follows)
- `tests/guard-ps1-ascii.tests.sh` (the `TARGET`->`TARGETS` generalization
  pattern this task's `TARGETS` map follows, design.md API/Contract Plan)

### Scope

Commit A (implementation — renderer + suite + CI wiring):

- Write the acceptance checks first (TEST-014..020): unprotected Claude
  `.md` render correctness; Codex `.toml` comment render; `--check`
  no-write + drift detection wired into CI/`validate-repository.ps1`;
  zero-diff first-render proof against real seeded files; `model: inherit`/
  role-map-absent exclusion; the protected-file write-boundary POSITIVE
  proof (TEST-019, asserting the resolution function itself); the
  protected-file READ-boundary proof (TEST-020, `--check` unattended in
  CI).
- CI resilience: mktemp scratch roots (including
  `specs/epic-159-pillar-c/human-copy/`'s staging area) normalized with
  `pwd -P`; no possibly-empty array under `set -u`; no jq consumption
  (non-use declaration) or `tr -d '\r'` if added.
- Implement the `TARGETS` map, the unprotected write path, the Codex
  comment-insertion path, the protected-target staging path (never a real
  write), and `--check`'s read-only comparison across all targets
  including the five protected ones.
- Wire `--check` into a new CI step and into `tests/validate-repository.ps1`.
- Register the suite (`.sh`/`.ps1`) in `tests/run-all.sh`/`.ps1`; stage the
  `.github/workflows/test.yml` candidate (this suite's steps + the
  `--check` step) under `human-copy/` + manifest, alongside the four
  reviewer files' staged candidates.

Commit B (documentation):

- CREATE the `CHANGELOG.md` `## Unreleased` entry citing #151.
- Extend the REQ-009 doc surfaces this task's Main Workflows entry names.
- Verify `tests/validate-repository.ps1` exits 0 (post-human-copy, or
  recorded as pending human action if the copy has not yet occurred —
  T-003's own commit cannot force the human step).

### Done When

- [ ] TEST-014 proves unprotected Claude `.md` targets get only `model:`
  rewritten + `x-sdd-effort:` inserted/refreshed (AC-014).
- [ ] TEST-015 proves Codex `.toml` targets get the two reference comment
  lines (AC-015).
- [ ] TEST-016 proves `--check` performs no write, detects injected drift,
  and is wired into CI + `validate-repository.ps1` (AC-016).
- [ ] TEST-017 proves the first render against real, current production
  files is zero-diff (AC-017).
- [ ] TEST-018 proves `model: inherit`/role-map-absent agents are
  untouched (AC-018).
- [ ] TEST-019 proves the write-target resolution FUNCTION itself excludes
  all five protected basenames — never merely relying on the R-10 guard
  (AC-019).
- [ ] TEST-020 proves `--check` runs unattended in CI against the five
  protected files (read-only) with correct drift reporting and zero guard
  trips (AC-020).
- [ ] Five staged candidates exist under `specs/epic-159-pillar-c/human-copy/`
  (four reviewer `.md` files + `.github/workflows/test.yml`) with correct
  `MANIFEST.sha256` entries; the five LIVE protected files are byte-identical
  before/after this task's commits.
- [ ] `CHANGELOG.md` gains a NEW `## Unreleased` entry citing #151
  (AC-049 share).
- [ ] A grep-based self-check confirms no version string was mutated
  outside `scripts/bump-version.sh` (AC-050 share).
- [ ] TDD evidence recorded: RED (the resolution-function self-check
  against a deliberately widened, protected-basename-including target map,
  proving it fails correctly) and GREEN (the same check against the real,
  correctly scoped map) for AC-019; RED/GREEN likewise for the `--check`
  read/write-boundary pair (AC-020). An independent quality-gate verdict
  records PASS, including confirmation that the human-copy steps for all
  five staged files have been applied and verified before Done.

### Out of Scope

- `select-agent-model.sh`/`.ps1` (T-002).
- `emit-run-record.sh`/`.ps1` (T-004).
- The Codex-host real invocation path that CONSUMES the rendered
  reference comments (T-006's cross-check, AC-038).
- Refreshing `.codex/agents/*.toml` beyond the two reference comment
  lines.

### Blockers

T-001

---

## T-004 Add run-record v2 effort tracking

Source Issue: https://github.com/aharada54914/sdd-forge/issues/153

Approval: Draft

Status: Planned

Risk: medium

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. medium is justified on three grounds: (1) the schema change is
strictly additive (`sdd-run-record/v1` records remain valid, unmigrated —
AC-025's backward-compatibility proof is external and mechanical, not
self-certified); (2) the field-population rule
(`effort_applied`/`effort_degraded_reason`) is structural, not merely
conventional — a value can only reach `effort_applied` via the
confirmed-application code path (design.md Constraint Compliance:
run-record truthfulness row), and this task's own tests assert BOTH
directions (TEST-023, TEST-024, TEST-051); (3) no existing `emit-run-record`
field, consumer, or validator behavior is removed or loosened. It does not
reach `high` because this task produces telemetry/evidence records, not an
access-control or payment surface, and every new field is additive.

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-004, REQ-009 (share)

Depends On: T-001, T-002 (functional — `--effort-control-*` values this
task's flags accept originate from T-002's `effort_control` resolution;
issue #153's own body: "依存: C1, C2"). No shared-registration-file
touch: this task only extends the already-registered
`tests/emit-run-record-feature-scope.tests.sh`/`.ps1`, no new `run-all`/
`test.yml` entry.

Planned Files:
- `plugins/sdd-quality-loop/scripts/emit-run-record.sh` (existing,
  agent-editable — `--effort-*` flags, `sdd-run-record/v2` fields;
  design.md API/Contract Plan)
- `plugins/sdd-quality-loop/scripts/emit-run-record.ps1` (existing,
  agent-editable — twin)
- `plugins/sdd-implementation/templates/implementation-report.template.md`
  (existing, agent-editable — `- Model:`/`- Effort:` lines)
- `plugins/sdd-implementation/scripts/validate-implementation-report.sh`
  (existing, agent-editable — present-and-format-only check for the two
  new lines; verify twin `.ps1` if one exists)
- `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md` (existing,
  agent-editable — Process instruction: gate reports record Model/Effort)
- `tests/emit-run-record-feature-scope.tests.sh` (existing, agent-editable
  — extended)
- `tests/emit-run-record-feature-scope.tests.ps1` (existing, agent-editable
  — extended)
- `CHANGELOG.md` (existing, agent-editable — CREATE the `## Unreleased`
  entry citing #153)

Data Migration: none — additive-only schema, `emit-run-record` emits `v1`
shape when no `--effort-*` flag is supplied and `v2` shape when one is
(design.md Data Plan, Migration Strategy).

Breaking API: no; every v1 field (`model_ids`, `track`, `plugin_version`,
`active_wfis`, `metrics.*`) is unchanged. The new `effort` object is a
sibling addition, present only when requested.

Rollback: revert this task's two commits; nothing protected is touched.
No v1 record is ever rewritten by this task or affected by its revert
(design.md Data Plan).

### Goal

Add `--effort-main`/`--effort-reviewers`/`--effort-applied-main`/
`--effort-applied-reviewers`/`--effort-control-main`/`--effort-control-reviewers`
flags to `emit-run-record.sh`/`.ps1`, emitting `sdd-run-record/v2` with the
six new subfields (three per role slot: `effort_requested`,
`effort_applied`, `effort_degraded_reason`) exactly per design.md's Data
Plan, keyed on the resolved `effort_control` value — including the
host-independent Codex non-`flag`-control degradation case (AC-051), not
merely the Claude Code case. Add the two report-template lines and the
quality-gate Process instruction.

### Must Read

- `specs/epic-159-pillar-c/requirements.md`
- `specs/epic-159-pillar-c/design.md`
- `specs/epic-159-pillar-c/acceptance-tests.md`
- `specs/epic-159-pillar-c/security-spec.md`
- `plugins/sdd-quality-loop/scripts/emit-run-record.sh:134-154` (the
  script this task edits; the `model_ids` construction this task's
  `effort` object sits beside)
- `plugins/sdd-implementation/templates/implementation-report.template.md`
  (the template this task extends)
- `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md` (the Process
  section this task documents; no separate quality-gate report template
  file exists — verified)
- `tests/emit-run-record-feature-scope.tests.sh`/`.ps1` (the suite this
  task extends)

### Scope

Commit A (implementation — script + template + skill doc + suite):

- Write the acceptance checks first (TEST-021..026, TEST-051): schema
  bump + additive fields (AC-021); `effort_requested` always-recorded
  (AC-022); `effort_applied` iff `flag` control + confirmed (AC-023);
  `effort_degraded_reason` both-directions (AC-024); v1
  backward-compatibility (AC-025); report-template/validator/SKILL.md
  documentation (AC-026); the Codex-host non-`flag`-control degradation
  case, proving the rule is keyed on `effort_control` not host name
  (AC-051).
- Insert the `effort` object at the design.md-specified point; implement
  the `--effort-control-*` disambiguating-flag design decision.
- Extend `implementation-report.template.md` and document the
  quality-gate Process instruction.

Commit B (documentation):

- CREATE the `CHANGELOG.md` `## Unreleased` entry citing #153.
- Extend the REQ-009 doc surfaces this task's Main Workflows entry names.

### Done When

- [ ] TEST-021 proves `schema: "sdd-run-record/v2"` when any `--effort-*`
  flag is supplied, with all v1 fields unchanged (AC-021).
- [ ] TEST-022 proves `effort_requested` recorded whenever its flag is
  supplied, any host/outcome (AC-022).
- [ ] TEST-023 proves `effort_applied` non-null only under `flag` control
  + confirmed application (AC-023).
- [ ] TEST-024 proves `effort_degraded_reason`'s both-direction
  field-population rule (AC-024).
- [ ] TEST-025 proves a pre-feature v1 record validates under the
  post-feature validator (AC-025).
- [ ] TEST-026 proves the report-template lines, validator scope, and
  SKILL.md Process instruction (AC-026).
- [ ] TEST-051 proves the Codex-host, non-`flag`-control degradation case
  is identical in shape to the Claude Code case (AC-051).
- [ ] `CHANGELOG.md` gains a NEW `## Unreleased` entry citing #153
  (AC-049 share).
- [ ] A grep-based self-check confirms no version string was mutated
  outside `scripts/bump-version.sh` (AC-050 share).
- [ ] Acceptance-first evidence recorded: RED (today's `emit-run-record`
  rejects the new flags as unknown arguments) and GREEN (the full
  TEST-021..026/051 suite passing). An independent quality-gate verdict
  records PASS.

### Out of Scope

- `run-panelist-gpt.sh`/`.ps1`'s real `--effort` application (T-006).
- The REQ-008 closing cross-host-degradation audit across the whole
  feature (owned by T-006, the last Phase-1 task — AC-047/048).

### Blockers

T-001, T-002

---

## T-005 Extend routing tests, author the .ps1 twin, and close the test.yml registration gap

Source Issue: https://github.com/aharada54914/sdd-forge/issues/154

Approval: Draft

Status: Planned

Risk: high

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. high is justified, not merely asserted: (1) this task authors
the GOLDEN-BASELINE proof (AC-028, mirroring AC-007) that Phase 1 changes
NOTHING about today's selector output — a silently-stale or vacuously-true
golden comparison here would mask a real regression across the entire
routing surface, not merely this task's own scope (design.md Risks,
Principal risk); (2) TEST-028's mutation-based negative self-check is the
ONLY mechanism proving that claim is live, not merely asserted; (3) this
task also closes a genuine, pre-existing cross-host parity gap (no `.ps1`
twin existed for `tests/agent-model-routing.tests.sh` before this task —
Problems, requirements.md) and interacts with the newly-protected
`.github/workflows/test.yml` registration surface (Critical remedy,
round 2) — a double-consequence surface (behavior-preservation proof +
protected-file registration) that together exceed `medium`. Required
Workflow is therefore `tdd` per `risk-gate-matrix.md:26`.

Required Workflow: tdd

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-005, REQ-009 (share)

Depends On: T-002 (functional — the `--effort-policy`/`--requested-effort`/
`--role`/`--host` flags this task's full case list exercises; issue #154's
own body: "依存: C2"). Additionally serialized after T-003 for the SHARED
`tests/run-all.sh`/`.ps1` array and `.github/workflows/test.yml` staging
candidate (Global Constraints) — T-003 is not a functional dependency of
T-005, this ordering exists solely to avoid a staging-file collision under
`specs/epic-159-pillar-c/human-copy/`.

Planned Files:
- `tests/agent-model-routing.tests.sh` (existing, agent-editable — full
  REQ-002/REQ-005 case list)
- `tests/agent-model-routing.tests.ps1` (NEW, agent-editable — closes the
  pre-existing twin gap; same case list)
- `tests/run-all.sh` (existing, agent-editable — confirms/re-verifies the
  existing `.sh` registration line; unchanged)
- `tests/run-all.ps1` (existing, agent-editable — this NEW twin's
  registration line)
- `specs/epic-159-pillar-c/human-copy/.github/workflows/test.yml` (staged
  candidate, agent-editable — this twin's pwsh-lane step; R-10 protected
  real path)
- `specs/epic-159-pillar-c/human-copy/MANIFEST.sha256` (existing, agent-editable
  — new entry for this task's staged `test.yml` candidate)
- `CHANGELOG.md` (existing, agent-editable — CREATE the `## Unreleased`
  entry citing #154)

Data Migration: none.

Breaking API: no; test-only changes, no production contract touched.

Rollback: revert this task's two commits. The `.ps1` twin's removal
reopens the twin gap this task closes; nothing protected is touched by the
agent directly — a revert PR must state whether the corresponding
`test.yml` step should also be hand-reverted by a human.

### Goal

Extend `tests/agent-model-routing.tests.sh` and author
`tests/agent-model-routing.tests.ps1` (new) with the full case list: v2
auto-detection; the AC-028 welded-golden byte-identical assertion + its
mutation-based negative self-check; matrix mode selection; clamp; `xhigh`
gate under matrix + escalation; `terminal-tier-recurrence` invariance;
`--role` tier floor; v1<->v2 projection. Verify the three-part AC-027
protected-`test.yml` registration proof for this task's own staged
candidate.

### Must Read

- `specs/epic-159-pillar-c/requirements.md`
- `specs/epic-159-pillar-c/design.md`
- `specs/epic-159-pillar-c/acceptance-tests.md`
- `specs/epic-159-pillar-c/security-spec.md`
- `tests/agent-model-routing.tests.sh` (the existing suite this task
  extends; verify no `.ps1` twin exists today before authoring one)
- `plugins/sdd-implementation/scripts/select-agent-model.sh:163-183`
  (`terminal-tier-recurrence` output, asserted byte-unchanged)
- `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:1-20`
  (re-verify `.github/workflows/test.yml`'s protected status before
  staging)
- `tests/second-approval-mask.tests.sh:285-289` (the self-registration
  grep pattern this task's twins follow)

### Scope

Commit A (implementation — suite extension + new twin + CI wiring):

- Write the acceptance checks first (TEST-027..034): twin existence +
  three-part protected-`test.yml` registration proof; welded-golden +
  negative canary; matrix risk-based selection; clamp; `xhigh` gate under
  escalation; `terminal-tier-recurrence` invariance; `--role` floor;
  v1<->v2 projection.
- CI resilience: no possibly-empty array under `set -u`; any jq
  consumption piped through `tr -d '\r'` on the bash side (the `.ps1`
  twin uses native `ConvertFrom-Json`, not subject to the CRLF hazard).
- Author `tests/agent-model-routing.tests.ps1` porting the full case list
  1:1 from the extended `.sh`.
- Register the new `.ps1` twin in `tests/run-all.ps1` directly; confirm
  the existing `.sh` registration in `tests/run-all.sh` remains correct
  (no edit expected there beyond the array's pre-existing entry).
- Stage the `.github/workflows/test.yml` candidate (this twin's new
  pwsh-lane step) under `human-copy/` + manifest, AFTER re-reading T-003's
  already-staged candidate (if not yet human-applied) to avoid clobbering
  it — append this step to the same staged file rather than starting from
  the unmodified real file.

Commit B (documentation):

- CREATE the `CHANGELOG.md` `## Unreleased` entry citing #154.

### Done When

- [ ] TEST-027 proves the three-part `test.yml` registration check:
  staged-candidate existence + manifest consistency; live-file
  byte-identity before/after this task; post-human-copy self-registration
  grep (AC-027).
- [ ] TEST-028 proves the welded-golden byte-identical assertion +
  mutation-based negative self-check on both twins (AC-028).
- [ ] TEST-029 proves the matrix `sonnet`+`high` selection on both twins
  (AC-029).
- [ ] TEST-030 proves the clamp case on both twins (AC-030).
- [ ] TEST-031 proves the `xhigh` gate under matrix + escalation on both
  twins (AC-031).
- [ ] TEST-032 proves `terminal-tier-recurrence` invariance on both twins
  (AC-032).
- [ ] TEST-033 proves the `--role sdd-evaluator` tier floor on both twins
  (AC-033).
- [ ] TEST-034 proves the v1<->v2 projection invariants on both twins
  (AC-034).
- [ ] `CHANGELOG.md` gains a NEW `## Unreleased` entry citing #154
  (AC-049 share).
- [ ] A grep-based self-check confirms no version string was mutated
  outside `scripts/bump-version.sh` (AC-050 share).
- [ ] TDD evidence recorded: RED (the pre-landing absence of
  `tests/agent-model-routing.tests.ps1` — the twin gap itself, `ls tests/`
  showing no such file; and, for the extended `.sh` cases, running them
  against a deliberately mutated golden fixture to confirm red) and GREEN
  (both twins passing post-landing, and the golden comparison passing
  against the real, unmutated fixture). An independent quality-gate
  verdict records PASS, including confirmation the human-copy step for
  this task's staged `test.yml` addition has been applied.

### Out of Scope

- `select-agent-model.sh`/`.ps1`'s own implementation (T-002).
- Any change to `render-agent-frontmatter` (T-003) or run-record (T-004).

### Blockers

T-002, T-003

---

## T-006 Apply effort on the Codex host and reject argv injection

Source Issue: https://github.com/aharada54914/sdd-forge/issues/152

Approval: Draft

Status: Planned

Risk: medium

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. medium is justified on three grounds: (1) the `--effort`
addition to `run-panelist-gpt.sh`/`.ps1` is purely additive — the existing
invocation (`run-panelist-gpt.sh:146`) is preserved byte-for-byte for any
caller that does not yet pass `--effort` (design.md API/Contract Plan);
(2) every REQ-006 assertion is argv/JSON-composition-level, never a live
LLM invocation (AC-040) — the blast radius of a defect is a malformed CLI
invocation caught by this task's own tests, not an uncontrolled runtime
effect; (3) the injection-rejection work (AC-052) NARROWS acceptance
(fail-closed on out-of-vocabulary values), it does not widen any existing
trust boundary (security-spec.md B3). It does not reach `high` because
this task's own tests never exercise a real `codex` process, and no
existing script's contract is broken.

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-006, REQ-008 (share, closing audit), REQ-009 (share)

Depends On: T-001, T-002, T-003 (functional — the `--host codex-cli`
selector output this task threads, and the T-003-rendered `.toml`
reference comments this task's cross-check reads; issue #152's own body:
"依存: C1, C2, C3").

Planned Files:
- `plugins/sdd-quality-loop/scripts/run-panelist-gpt.sh` (existing,
  agent-editable — `--effort <e>`, forwarded to `codex`; design.md
  API/Contract Plan)
- `plugins/sdd-quality-loop/scripts/run-panelist-gpt.ps1` (existing,
  agent-editable — twin)
- `plugins/sdd-quality-loop/scripts/prepare-panelist-input.sh` (existing,
  agent-editable — `--effort` pass-through)
- `plugins/sdd-quality-loop/scripts/prepare-panelist-input.ps1` (existing,
  agent-editable — twin)
- `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md` (existing,
  agent-editable — Codex-host evaluator/investigator startup wiring)
- `tests/run-panelist-effort.tests.sh` (new, agent-editable)
- `tests/run-panelist-effort.tests.ps1` (new, agent-editable)
- `tests/run-all.sh` (existing, agent-editable — this suite's registration)
- `tests/run-all.ps1` (existing, agent-editable — this suite's registration)
- `specs/epic-159-pillar-c/human-copy/.github/workflows/test.yml` (staged
  candidate, agent-editable — this suite's CI steps; R-10 protected real
  path)
- `specs/epic-159-pillar-c/human-copy/MANIFEST.sha256` (existing,
  agent-editable — new entry for this task's staged `test.yml` candidate)
- `CHANGELOG.md` (existing, agent-editable — CREATE the `## Unreleased`
  entry citing #152)

Data Migration: none.

Breaking API: no; `--effort` is optional and additive on both scripts;
omitted entirely preserves today's exact invocation (design.md
API/Contract Plan).

Rollback: revert this task's two commits; nothing protected is touched by
the agent directly — a revert PR must state whether the staged `test.yml`
step should also be hand-reverted.

### Goal

Add `--effort <e>` to `run-panelist-gpt.sh`/`.ps1`, forwarded to the
`codex` CLI invocation; thread a selector-derived effort value through
`prepare-panelist-input.sh`/`.ps1`; wire the Codex-host evaluator/
investigator startup path to supply `select-agent-model --host codex-cli`
output as CLI flags; cross-check T-003's rendered `.toml` reference
comments against live selector output; reject out-of-vocabulary
`--model`/`--effort` values (AC-052). Close the feature with the REQ-008
cross-host-degradation AUDIT (AC-047/048) across every effort-consuming
surface T-001..T-006 added.

### Must Read

- `specs/epic-159-pillar-c/requirements.md`
- `specs/epic-159-pillar-c/design.md`
- `specs/epic-159-pillar-c/acceptance-tests.md`
- `specs/epic-159-pillar-c/security-spec.md`
- `plugins/sdd-quality-loop/scripts/run-panelist-gpt.sh:31-42,146` (the
  argument-parsing block and the sole `codex` invocation site this task
  edits)
- `plugins/sdd-quality-loop/scripts/prepare-panelist-input.sh` (the script
  this task threads `--effort` through)
- `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md:96-99` (the
  Codex-host evaluator/investigator invocation instructions this task
  wires)
- `.codex/agents/sdd-evaluator.toml`, `sdd-investigator.toml` (T-003's
  rendered reference comments, read by this task's cross-check, never
  edited further by this task)

### Scope

Commit A (implementation — panelist/prepare-input/skill wiring + suite):

- Write the acceptance checks first (TEST-035..040, TEST-052): `--effort`
  in the assembled `codex` argv; `prepare-panelist-input` threading;
  Codex-host startup wiring; the render/selector cross-check reporting
  divergence; Claude Code degradation recorded (host-independent, shares
  the AC-024/AC-051 rule); construction proof (no live LLM call); and
  out-of-vocabulary argv rejection per malformed-shape category.
- CI resilience: no possibly-empty array under `set -u`; no jq consumption
  beyond `tr -d '\r'`-guarded uses.
- Implement `--effort` on both scripts, the threading, the startup-path
  wiring, the cross-check, and the enumerated-vocabulary rejection.
- Register the suite (`.sh`/`.ps1`) in `tests/run-all.sh`/`.ps1`; stage
  the `.github/workflows/test.yml` candidate under `human-copy/` +
  manifest, appended to whichever prior task's staged candidate is still
  pending human application.
- Perform the closing REQ-008 audit: confirm every effort-consuming
  surface T-001..T-006 added (T-004's run-record, T-006's own panelist
  path) has a demonstrated Claude Code (or non-`flag`-control) degradation
  case, and that no suite anywhere in this feature reports FAIL/SKIP
  solely due to that host's absent effort mechanism.

Commit B (documentation):

- CREATE the `CHANGELOG.md` `## Unreleased` entry citing #152.
- Extend the REQ-009 doc surfaces this task's Main Workflows entry names.

### Done When

- [ ] TEST-035 proves `--effort` in the assembled `codex` argv (AC-035).
- [ ] TEST-036 proves `prepare-panelist-input` threading (AC-036).
- [ ] TEST-037 proves the Codex-host startup path supplies model+effort
  (AC-037).
- [ ] TEST-038 proves the render/selector cross-check reports divergence
  (AC-038).
- [ ] TEST-039 proves the Claude Code degradation case (AC-039).
- [ ] TEST-040 proves no test in this task invokes a real LLM (AC-040).
- [ ] TEST-052 proves out-of-vocabulary argv rejection per malformed-shape
  category (AC-052).
- [ ] The REQ-008 closing audit (AC-047, AC-048) confirms every
  effort-consuming surface has a demonstrated degradation case and no
  suite fails/SKIPs solely due to Claude Code's absent effort mechanism —
  recorded explicitly in the implementation report with a per-surface
  checklist (T-004's AC-024/AC-051, T-006's own AC-039).
- [ ] `CHANGELOG.md` gains a NEW `## Unreleased` entry citing #152
  (AC-049 share).
- [ ] A grep-based self-check confirms no version string was mutated
  outside `scripts/bump-version.sh` (AC-050 share).
- [ ] Acceptance-first evidence recorded: RED (today's
  `run-panelist-gpt.sh` has no `--effort` case — an unknown-argument
  rejection) and GREEN (the full TEST-035..040/052 suite passing). An
  independent quality-gate verdict records PASS.

### Out of Scope

- The `--effort-policy` default flip (T-007, separate release).
- Any change to `emit-run-record.sh`/`.ps1` itself (T-004; this task only
  CONSUMES its `--effort-control-*` contract).

### Blockers

T-001, T-002, T-003, T-005

---

## T-007 Flip the effort-policy default to matrix (Phase 2, separate release)

Source Issue: https://github.com/aharada54914/sdd-forge/issues/155

Approval: Draft

Status: Planned

Risk: high

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly — this task changes a release-path DEFAULT that governs every
future Codex-host invocation's effort selection, and is explicitly a
release-gating change (REQ-007's prerequisite gate). high is justified:
(1) landing before A3 or before all of T-001..T-006 merge would measure
effort effects on top of a known-broken round-2 evaluation path,
corrupting the WFI signal this epic exists to produce (design.md Risks,
Secondary risk) — this is exactly the class of "silent defect causes
material harm" the policy's `high` tier describes; (2) AC-045's
`git merge-base --is-ancestor` check is a hard, external, re-run
verification at RELEASE time, not a spec-time attestation relied upon
alone; (3) this is the ONLY task in the feature that executes a real
`scripts/bump-version.sh` release. Required Workflow is therefore `tdd`
per `risk-gate-matrix.md:26`.

Required Workflow: tdd

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-007

Depends On: T-001, T-002, T-003, T-004, T-005, T-006 (ALL, explicit
prerequisite gate — requirements.md REQ-007) PLUS A3 (commit
`2d8c6a561e0f5d2bc29ded4195c057d4cc918f2f`, "fix: unblock impl review
rounds after the first (#143)") present in `main` — already confirmed an
ancestor of HEAD at spec/design time via `git merge-base --is-ancestor`;
re-verified against the actual release commit at this task's own
implementation time (AC-045). A3 is an external commit-ancestry fact, not
a task within this feature's own T-001..T-006 set, and is tracked in
Done-When rather than the task-ID Blockers list.

Planned Files:
- `plugins/sdd-implementation/scripts/select-agent-model.sh` (existing,
  agent-editable — flip the `--effort-policy` default)
- `plugins/sdd-implementation/scripts/select-agent-model.ps1` (existing,
  agent-editable — twin)
- `USERGUIDE.md` (existing, agent-editable — matrix-default policy
  description)
- `docs/agent-capability-matrix.md` (existing, agent-editable — matrix-default
  policy description)
- `CHANGELOG.md` (existing, agent-editable — this task's own,
  separately-released entry)
- production Claude `.md` / Codex `.toml` agent-definition files (existing
  — the first production `role_defaults` render post-flip; expected
  zero-diff per T-003's seeding)

Data Migration: none.

Breaking API: no in-repository contract change (the default value change
is a behavior change, not a schema/contract change); any external caller
relying on `welded`'s implicit default must now pass `--effort-policy
welded` explicitly to retain Phase-1-equivalent behavior (OQ-004
resolution: `welded` remains fully supported indefinitely, no deprecation
timer).

Rollback: a single-line revert of the default value plus a follow-up
documentation revert; no data migration exists to unwind (run-record v2 is
additive-only, no v1 record is rewritten by this task or affected by its
revert — design.md Data Plan).

### Goal

Flip `select-agent-model`'s `--effort-policy` default from `welded` to
`matrix`. Perform and verify the first production `role_defaults` render
(expected zero-diff). Update `USERGUIDE.md`/`docs/agent-capability-matrix.md`/
`CHANGELOG.md`. Run the AC-044 Codex-host smoke check. Execute this task's
own, separate `scripts/bump-version.sh` release — as its OWN PR, never
bundled with T-001..T-006.

### Must Read

- `specs/epic-159-pillar-c/requirements.md`
- `specs/epic-159-pillar-c/design.md`
- `specs/epic-159-pillar-c/acceptance-tests.md`
- `docs/adr/0012-effort-tier-decoupling.md` (T-002's ADR, the design
  record this task's flip enacts)
- `scripts/bump-version.sh` (the release script this task's own,
  separate invocation uses — fail-closed CHANGELOG-rename discipline,
  v1.9.0 non-sync precedent)

### Scope

This task lands as its own PR, entirely separate from T-001..T-006's PR(s)
(Global Constraints; requirements.md REQ-007/REQ-009). It is not split
into a two-commit A/B plan the way T-001..T-006 are — its own sequence is:
(1) verify the prerequisite gate; (2) flip the default; (3) render and
verify zero-diff; (4) update docs; (5) run the AC-044 smoke check; (6)
execute the separate release via `scripts/bump-version.sh`.

### Done When

- [ ] TEST-041 proves the `--effort-policy` default resolves to `matrix`
  post-flip (AC-041).
- [ ] TEST-042 proves the first production `role_defaults` render is
  zero-diff, or a documented cause is recorded if not (AC-042).
- [ ] TEST-043 proves `USERGUIDE.md`/`docs/agent-capability-matrix.md`/
  `CHANGELOG.md` describe the matrix-default policy (AC-043).
- [ ] TEST-044 proves a real Codex-host run's run-record shows non-null
  `effort_applied` (AC-044).
- [ ] TEST-045 proves, via `git merge-base --is-ancestor` re-run against
  the actual release commit, that T-001..T-006's merge commits AND A3 are
  ancestors (AC-045).
- [ ] TEST-046 proves this task's PR is distinct from any T-001..T-006 PR
  and its `scripts/bump-version.sh` invocation is separate from Phase 1's
  (AC-046).
- [ ] TDD evidence recorded: RED (the pre-flip default resolving to
  `welded`, confirmed against the merged T-001..T-006 state) and GREEN
  (the post-flip default resolving to `matrix`, plus the AC-044 real
  smoke-check evidence). An independent quality-gate verdict records
  PASS. The release itself follows `scripts/bump-version.sh`'s existing
  fail-closed CHANGELOG-heading-rename discipline.

### Out of Scope

- Any T-001..T-006 deliverable (all already Done and merged as this
  task's prerequisite).
- Building an automated CI gate that mechanically blocks this task from
  merging early (explicit Non-goal; the gate is this task's own documented
  procedure, AC-045/046).

### Blockers

T-001, T-002, T-003, T-004, T-005, T-006 (plus the external A3
commit-ancestry fact — see Depends On)
