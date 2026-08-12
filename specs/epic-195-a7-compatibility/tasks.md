# Tasks: epic-195-a7-compatibility

Task-Review-Status: Passed

Source: Issue #195 (Epic A7 — Compatibility), tracked under epic #187
(AI-DLC Foundation) /
requirements.md (Spec-Review-Status: Passed) /
design.md (Impl-Review-Status: Passed)

## Lifecycle

`Draft -> Approved -> In Progress -> Implementation Complete -> Done`

A task may enter `Blocked` from any active state. Humans approve tasks.
`implement-task` may set `In Progress`, `Blocked`, or `Implementation
Complete`. Only `quality-gate` may set `Done`.

## Scope Note

Every task below is a **Phase 2/3 future-task deliverable** design.md
itself describes as not-yet-built (design.md Components: "existing,
extended (future task)" / "new (future task)" on every row). This
package's own Phase 1 change set (`investigation.md`, `requirements.md`,
`design.md`, `acceptance-tests.md`, the four layer-spec files) is already
complete and unmodified by any task here (design.md Protected-File
Statement). No task below edits `investigation.md`, `requirements.md`,
`design.md`, or `acceptance-tests.md` — those are frozen, hash-bound
Phase 1 artifacts.

## Protected Files

No task in this feature writes to a path this repository's guard
currently treats as R-10-protected. `tests/loops/loop-inventory.json`,
`tests/lib/loop-driver.sh`, and
`plugins/sdd-quality-loop/scripts/emit-run-record.sh` are **unprotected
today but cross-epic shared surfaces** (requirements.md Security
Boundaries B2); every task touching them (T-005, T-006, T-007, T-008,
T-009) is written additive-only, per design.md's own Constraint
Compliance table, and is reviewed with the same rigor as a protected-file
change even though no guard enforces that today.

`.github/workflows/test.yml`'s own protected-file status is explicitly
left open by design.md (Deployment / CI Plan: "explicitly left for Phase
2/3 to confirm against the live protected-file list at that time").
**T-011 is the sole task that edits this file** and must resolve that
question first: if the live protected-file list names it, T-011 stages
its diff under `specs/epic-195-a7-compatibility/human-copy/` with a
`MANIFEST.sha256` entry (ADR-0011 pattern, matching Epic A5's own
precedent investigation.md cites); if it does not, T-011 edits it
directly. No other task in this feature touches `.github/workflows/test.yml`.

## Global Constraints

- **Serialized order for the shared `tests/run-all.sh`/`tests/run-all.ps1`
  array**: every task that introduces a *new* `.tests.sh`/`.tests.ps1`
  suite file (T-002, T-003, T-004, T-009's extension of an existing
  suite excepted) appends only its own suite's registration line, in
  task order T-001 → T-011. T-005, T-006, T-007, T-008, and T-009 extend
  an *already-registered* suite (`tests/loop-consistency.tests.sh`,
  `tests/loop-escalation.tests.sh`, `tests/emit-run-record-feature-scope.tests.sh`)
  and add no new `run-all` line of their own.
- **No task other than T-011 edits `.github/workflows/test.yml`**
  (Protected Files, above; design.md Test Strategy item 9). CI wiring for
  every suite built by T-002–T-010 is registered once, cumulatively, by
  T-011.
- **AC-031's non-gating live-model refresh test is never added to the
  gating `tests/run-all.sh` array or the gating `.github/workflows/test.yml`
  entries** (design.md Deployment / CI Plan) — T-012 registers it, if at
  all, as a separate, explicitly non-gating entry, or leaves it
  run-manually-only.
- **F5–F8** (Compatibility Matrix, design.md) have no fixture-builder call
  and no task in this feature: F5/F6 remain `SKIP-with-activation` (Epic
  A1 **and** Epic A6, T-010's manifest), F7/F8 remain `N/A` with the
  stated no-Foundation-epic rationale (design.md Design Decisions) — no
  task below builds them.
- **No task fabricates current capability-machinery behavior**
  (investigation.md Safety constraints; AC-016): every "Context present"
  assertion and every Context-absent assertion whose own target does not
  exist yet is authored as a named `SKIP` reading from T-010's REQ-007
  allowlist manifest, never a hard failure and never a silent pass, until
  its cited upstream epic merges.
- **Fixtures never touch the real working tree**: every fixture this
  feature's tasks construct (directly in T-001, or by calling
  `build_fixture` in T-002–T-004/T-006–T-008) follows
  `loop_fixture_init`'s own `mktemp -d` + physical-path-normalization +
  outside-repo-root assertion pattern (`tests/lib/loop-driver.sh:106-141`).
- **Fixed environment for every byte-comparison assertion**: `TZ`,
  `LC_ALL` set, no ambient `SDD_*` environment variable read (AC-003,
  API / Contract Plan "Golden-baseline capture/promote contract").
- **`plugins/**`/`scripts/**`/`contracts/**`/`docs/**` stay out of scope**
  except the one named exception design.md's Components table fixes:
  `plugins/sdd-quality-loop/scripts/emit-run-record.sh`
  (`.sh`/`.ps1`), edited by T-009 only. No task edits any other file under
  `plugins/**`, `scripts/**`, `contracts/**`, or `docs/**`.
- Preserve unrelated changes; implement one task at a time.

---

## T-001 Author the fixture-matrix builder

Source Issue: https://github.com/aharada54914/sdd-forge/issues/195

Approval: Approved (sudo 2026-08-08T16:33:11Z)

Status: Done

Risk: medium

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. `medium` is justified: this task authors a shared, sourced
fixture-construction library with observable behavior (which files exist
in the constructed fixture tree, and their content) but no sensitive
surface of its own — it is inert until a consuming suite (T-003, T-004,
T-006, T-007, T-008) actually drives a fixture through the CLI/loop
machinery under test, matching this repository's own precedent for a
foundational-but-inert contract (`specs/epic-190-a2-capability-registry/tasks.md`
T-001's identical reasoning for its own Registry schema). It is not
`high`: this task performs no capability-machinery invocation, no
network I/O, and no write outside `mktemp -d` temporary directories
(`loop_fixture_init`'s own outside-repo-root assertion pattern,
`tests/lib/loop-driver.sh:106-141`, applies here too). Required Workflow
is `acceptance-first` per the policy's medium-tier row.

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-005 (AC-014)

Depends On: none (functional — this is the foundational fixture-
construction primitive every other Phase-2/3 task in this feature either
calls directly or consumes indirectly).

Planned Files:
- `tests/lib/fixture-matrix-builder.sh` (new, agent-editable — the
  `build_fixture <project_context> <agents_marker>
  <capability_enforcement> <valid_or_invalid> <track_flag>` function,
  API / Contract Plan)
- `tests/lib/fixture-matrix-builder.ps1` (new, agent-editable — twin,
  INV-005/INV-007 convention)
- fixture template content this function writes (e.g. a minimal
  `sdd/project-context.yaml` template with exactly one deliberately-
  broken field for the `PROJECT_CONTEXT_INVALID` variant, and an
  `AGENTS.md` `spec_profile: lite` marker template) — colocated with the
  library files, not a separate top-level fixtures tree, since these are
  templates the function itself renders, not committed golden data

Data Migration: none — new, additive library; no prior version.

Breaking API: no; `fixture-matrix-builder.{sh,ps1}` are wholly new files.

Rollback: revert this task's commit(s); nothing protected is written
directly, and no consuming suite exists yet to be broken by a revert
(T-002–T-004/T-006–T-008 all depend on this task, never the reverse).

### Goal

Author `tests/lib/fixture-matrix-builder.{sh,ps1}` implementing the
five-parameter `build_fixture` contract design.md's API / Contract Plan
fixes exactly: `project_context` (`absent`\|`present`), `agents_marker`
(`absent`\|`present`), `capability_enforcement`
(`disabled-legacy`\|`advisory`\|`required`), `valid_or_invalid`
(`valid`\|`PROJECT_CONTEXT_INVALID`, F3/F4 only), `track_flag`
(`none`\|`--full`\|`--lite`). The function returns the constructed
fixture's own root directory path and never touches the real working
tree.

### Must Read

- `specs/epic-195-a7-compatibility/requirements.md`
- `specs/epic-195-a7-compatibility/design.md` (API / Contract Plan
  "Fixture-matrix builder contract"; Data Plan
  "`PROJECT_CONTEXT_INVALID` variant plan"; Compatibility Matrix)
- `specs/epic-195-a7-compatibility/acceptance-tests.md`
- `specs/epic-195-a7-compatibility/traceability.md`
- `tests/lib/loop-driver.sh:106-141` (`loop_fixture_init`'s own
  `mktemp -d` + physical-path-normalization + outside-repo-root
  assertion pattern this builder follows)
- `PLUGIN-CONTRACTS.md:63-66` (the CLI-flag → `AGENTS.md`-marker →
  default track-selection priority order the `track_flag`/`agents_marker`
  parameters exercise, ADR-0023 item 2)

### Scope

- Implement `build_fixture` covering every documented parameter value and
  combination for F1–F4 (the four rows this package's own Phase 2/3
  increment builds; F5–F8 have no builder call, Global Constraints).
- Implement the F3/F4-only `PROJECT_CONTEXT_INVALID` variant: a
  `sdd/project-context.yaml` that parses as valid YAML but fails a named
  validator by exactly one deliberately-broken field (e.g. a corrupted
  `content_hash`) — never a syntactically invalid YAML file (Data Plan).
- Implement the Context-absent CLI submatrix's own `track_flag` parameter
  (`none`\|`--full`\|`--lite`), independent of the other four parameters.
- Verify every constructed fixture's own root directory is a fresh
  `mktemp -d` result, physically normalized, and asserted outside the
  real repository root before any file is written into it.
- Acceptance-first: write the parameter-combination assertions (every
  documented value of each of the five parameters, individually and in
  the F1–F4 combinations design.md names) before/alongside the
  implementation.

### Done When

- [ ] `build_fixture` accepts all five parameters exactly as API /
  Contract Plan fixes them and returns a fresh, isolated fixture root
  for every one of F1–F4's own parameter tuples (AC-014).
- [ ] The Context-absent CLI submatrix's six cells (`none`/`--full`/`--lite`
  × marker present/absent) are each constructible via the `track_flag`
  parameter (AC-014).
- [ ] The F3/F4 `valid_or_invalid` parameter constructs a
  `PROJECT_CONTEXT_INVALID` variant that is syntactically valid YAML with
  exactly one deliberately-broken field, never a parse-error fixture
  (Data Plan).
- [ ] Every constructed fixture is verified, by direct invocation during
  implementation, to live under a fresh `mktemp -d` root outside the real
  working tree — captured as this task's own implementation-report
  evidence rather than a registered `tests/*.tests.sh` suite, matching
  design.md API / Contract Plan's own statement that the builder is
  "sourced by the suites that consume it, never registered as its own
  independent test suite." Full behavioral coverage of every parameter
  combination is additionally exercised, indirectly, by T-003/T-004/
  T-006/T-007/T-008's own suites, which fail if `build_fixture` misbehaves.
- [ ] Implementation report created; quality gate passes; traceability.md
  updated with T-001 → REQ-005 (AC-014).

### Out of Scope

- The golden-baseline capture/promote scripts (T-002), the byte-identical
  and structural-compatibility suites (T-003, T-004), the canonical
  event-trace schema and driver extension (T-005), `TEST-018`/`TEST-019`
  themselves (T-006, T-007), the Epic A5 deferred fixture assertions
  (T-008), the `emit-run-record.sh` extension (T-009), the REQ-007
  allowlist manifest (T-010), and CI registration (T-011).
- F5–F8 fixture construction (Global Constraints — no builder call in
  this feature's own Phase 2/3 increment).

### Blockers

None

---

## T-002 Author the golden-baseline capture/promote scripts and the initial canonical baseline

Source Issue: https://github.com/aharada54914/sdd-forge/issues/195

Approval: Approved (sudo 2026-08-08T16:33:11Z)

Status: Done

Risk: high

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. `high` is justified, not merely asserted: this task is the
concrete implementation of Security Boundary B1
(security-spec.md#trust-boundaries — "the canonical baseline must never
be silently regenerated by an automated or CI-driven process"). A silent
defect here — `--write-candidate` accidentally writing the canonical
path, or `promote-golden-baseline.sh` failing to refuse under a set `CI`
environment variable or a missing `--approved-by` flag — lets an
unreviewed, possibly-regressed legacy-behavior snapshot get silently
canonized as the new compatibility oracle every other suite in this
feature trusts, exactly the "silent defect causes material harm" surface
the policy's `high` tier names. It is not `critical`: no financial-
settlement, physical-safety, or irreversible-destructive surface — a bad
promotion is a `git revert` (infra-spec.md#rollback), not an
unrecoverable loss. Required Workflow is `tdd` (Red→Green) per the
policy's high-tier row.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-006 (AC-001, AC-018)

Depends On: T-001 (Global Constraints — serialized `run-all` append order
only; no functional dependency — the initial canonical capture runs
directly against the fixed pre-capability merge-base commit, INV-022,
never through the fixture-matrix builder).

Planned Files:
- `tests/capture-golden-baseline.sh` (new, agent-editable — default
  invocation: read-only diff-against-canonical; `--write-candidate`:
  additionally writes a gitignored candidate, never the canonical path,
  API / Contract Plan)
- `tests/capture-golden-baseline.ps1` (new, agent-editable — twin)
- `tests/promote-golden-baseline.sh` (new, agent-editable — refuses
  before any file I/O when `CI` is set to any non-empty value or
  `--approved-by <human-identifier>` is omitted/empty; otherwise copies
  candidate → canonical, API / Contract Plan)
- `tests/promote-golden-baseline.ps1` (new, agent-editable — twin)
- `tests/golden-baseline-contract.tests.sh` (new, agent-editable — this
  task's own TDD suite: manifest shape, capture/promote CLI contract)
- `tests/golden-baseline-contract.tests.ps1` (new, agent-editable — twin)
- `specs/epic-195-a7-compatibility/verification/golden-baseline/canonical/`
  (new, committed — the initial canonical capture: per-target sha256,
  script sha256, the pinned pre-capability merge-base commit SHA, fixed
  env vars, Design Decisions "Golden-baseline location")
- `specs/epic-195-a7-compatibility/verification/golden-baseline/.gitignore`
  (new — ignores `candidate/`)
- `tests/run-all.sh` (existing, agent-editable — this suite's
  registration, Global Constraints serialized order)
- `tests/run-all.ps1` (existing, agent-editable — twin registration)

Data Migration: none — net-new scripts and a net-new committed manifest;
no prior version.

Breaking API: no; `capture-golden-baseline.{sh,ps1}` and
`promote-golden-baseline.{sh,ps1}` are wholly new files, and the
`verification/golden-baseline/` tree is net-new.

Rollback: revert this task's commit(s) (infra-spec.md#rollback). The
canonical path is a plain committed file at this stage (no promotion
history yet to reconcile); a bad initial capture is a straightforward
`git revert`, never a special procedure.

### Goal

Author the two named commands (REQ-006c): `capture-golden-baseline.sh
[--write-candidate]` and `promote-golden-baseline.sh <candidate-path>
--approved-by <human-identifier>`, structurally enforcing the fail-closed
guards API / Contract Plan fixes (`CI`-env-var refusal, `--approved-by`
requirement, before any file I/O), and perform the initial canonical
capture against the fixed pre-capability merge-base commit — the current
`main` HEAD at this task's own implementation time, since Epic A1 (the
epic whose first merge defines "pre-capability") remains unmerged
(INV-022; requirements.md Assumptions) — recording that exact SHA, the
fixed environment variables, and every captured target's own sha256 plus
the capturing script's own sha256 in the manifest (AC-018).

### Must Read

- `specs/epic-195-a7-compatibility/requirements.md`
- `specs/epic-195-a7-compatibility/design.md` (API / Contract Plan
  "Golden-baseline capture/promote contract"; Design Decisions
  "Golden-baseline location"; Security Boundaries B1)
- `specs/epic-195-a7-compatibility/infra-spec.md#rollback`
- `specs/epic-195-a7-compatibility/security-spec.md#trust-boundaries`
  (B1)
- `specs/epic-195-a7-compatibility/acceptance-tests.md`
- `specs/epic-195-a7-compatibility/traceability.md`
- `plugins/sdd-quality-loop/scripts/generate-guard-invariants.py` (the
  `--check`, no-write, sha256-comparison convention this task's own
  default (diff-only) invocation mirrors)

### Scope

- TDD Red→Green: write the `CI`-env-var-set and `--approved-by`-omitted
  refusal fixtures (each asserting non-zero exit **and** no file
  touched, before any implementation) before implementing the guard.
- Implement `capture-golden-baseline.sh`'s default (diff-only, read-only)
  and `--write-candidate` (gitignored-candidate-only) modes.
- Implement `promote-golden-baseline.sh`'s fail-closed guard and its
  candidate → canonical copy on success.
- Perform and commit the initial canonical capture (AC-018), never a
  direct hand-edit of the canonical path outside the capture script's own
  output.
- Fixed environment (`TZ`, `LC_ALL`, no ambient `SDD_*`) for every
  captured target (Global Constraints).

### Done When

- [ ] Default `capture-golden-baseline.sh` invocation is read-only:
  writes nothing, exits non-zero on drift, zero on match (AC-001).
- [ ] `--write-candidate` writes only the gitignored candidate path,
  never the canonical path (AC-001; Security Boundaries B1).
- [ ] `promote-golden-baseline.sh` copies candidate → canonical only when
  both guards are satisfied; the manifest records the pinned
  pre-capability commit SHA, fixed env vars, and per-target + script
  sha256 (AC-018).
- [ ] TDD evidence: RED (the `CI`-set and `--approved-by`-omitted
  fixtures against a deliberately permissive script) and GREEN (the full
  suite against the correct implementation). An independent quality-gate
  verdict records PASS.
- [ ] The initial canonical baseline is committed under
  `specs/epic-195-a7-compatibility/verification/golden-baseline/canonical/`
  (Design Decisions "Golden-baseline location").
- [ ] `tests/golden-baseline-contract.tests.sh`/`.ps1` self-register in
  `tests/run-all.sh`/`.ps1`.
- [ ] Implementation report created; quality gate passes; traceability.md
  updated with T-002 → REQ-006 (AC-001, AC-018).

### Out of Scope

- The static CI-workflow-text scan (AC-040) and the direct
  `promote-golden-baseline.sh` runtime-refusal negative-fixture pair
  (AC-041) — both are T-011's own scope (Test Strategy item 9), since
  AC-040 needs the final, fully-registered `.github/workflows/test.yml`
  content to scan.
- Consuming the golden baseline for an actual byte-identical comparison
  (T-003's own scope) and the negative self-check that the byte-identical
  test can actually fail on a mutated fixture (AC-002, T-003).

### Blockers

None

---

## T-003 Extend the byte-identical compatibility suite

Source Issue: https://github.com/aharada54914/sdd-forge/issues/195

Approval: Approved (sudo 2026-08-08T16:33:11Z)

Status: Done

Risk: medium

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. `medium` is justified: this task is the actual byte-comparison
test consumer of T-002's already-secured golden baseline — a normal,
fully-tested feature with observable behavior (byte-for-byte
pass/fail) but it does not itself implement a named Security Boundary
(B1 is T-002's own scope; the boundary this task exercises is already
enforced upstream). It is not `high`: a defect here is caught by its own
required negative self-check (AC-002 — the suite must be shown to fail on
a deliberately mutated fixture), matching this repository's own
precedent for a self-verifying test-authoring task
(`specs/epic-190-a2-capability-registry/tasks.md` T-001's identical
"caught by this task's own suite" reasoning). Required Workflow is
`acceptance-first` per the policy's medium-tier row.

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-001 (AC-002, AC-003, AC-038)

Depends On: T-001 (functional — constructs the F1/F2 Context-absent
fixtures and the CLI submatrix this suite drives), T-002 (functional —
diffs against the committed canonical baseline).

Planned Files:
- `tests/compatibility-byte-identical.tests.sh` (new, agent-editable —
  the REQ-001 canonical-target-inventory suite: deterministic script
  output, exit code, stdout/stderr, template-copy, schema-validator,
  generated directory listing, plugin manifest, each captured per AC-038's
  own format table, diffed against T-002's canonical baseline; the
  required AC-002 negative self-check)
- `tests/compatibility-byte-identical.tests.ps1` (new, agent-editable —
  twin)
- `tests/install.tests.sh` (existing, agent-editable — new fixture cases
  asserting install output is unaffected by `project-context.yaml`
  presence/absence, INV-007)
- `tests/install.tests.ps1` (existing, agent-editable — twin)
- `tests/uninstall.tests.sh` (existing, agent-editable — same, for
  uninstall)
- `tests/uninstall.tests.ps1` (existing, agent-editable — twin)
- `tests/run-all.sh` (existing, agent-editable — this suite's
  registration, Global Constraints serialized order)
- `tests/run-all.ps1` (existing, agent-editable — twin registration)

Data Migration: none.

Breaking API: no; `compatibility-byte-identical.{sh,ps1}` are wholly new
files; `install.tests.{sh,ps1}`/`uninstall.tests.{sh,ps1}` gain fixture
cases only, no existing case is altered.

Rollback: revert this task's commit(s); nothing protected is written
directly (infra-spec.md#rollback).

### Goal

Extend `tests/install.tests.sh`/`tests/uninstall.tests.sh` with
Context-absent fixture cases (INV-007) and author
`tests/compatibility-byte-identical.tests.sh` asserting, for at least one
representative script per AC-038's own canonical target-inventory row —
deterministic script output, exit code, stdout/stderr, template-copy,
schema-validator, install, uninstall, generated directory listing, plugin
manifest — byte-for-byte identity across two independent invocations
against an identical fixture and the fixed environment (AC-003), plus the
Context-absent CLI submatrix's own byte-identical assertion (ADR-0023
item 2). Required negative self-check: the suite fails when a single byte
of the golden baseline differs from a fresh run's output (AC-002).

### Must Read

- `specs/epic-195-a7-compatibility/requirements.md`
- `specs/epic-195-a7-compatibility/design.md` ("REQ-001 canonical target
  inventory" table; Compatibility Matrix F1/F2 rows; Observable×
  fixture-state judgment table)
- `specs/epic-195-a7-compatibility/acceptance-tests.md`
- `specs/epic-195-a7-compatibility/traceability.md`
- `tests/install.tests.sh`, `tests/uninstall.tests.sh` (INV-007 — the
  existing byte-identical-style baseline this task extends, not
  duplicates)
- `tests/lib/fixture-matrix-builder.sh` (T-001's own contract, consumed
  here)
- `tests/loop-inventory.tests.sh:129-133` (INV-002 — the existing
  negative-self-check convention AC-002 follows)

### Scope

- Author fixture cases for F1 (Context-absent, `full`) and F2
  (Context-absent, `lite`) plus the six-cell CLI submatrix, all
  constructed via T-001's `build_fixture`.
- Diff every AC-038 canonical-inventory target's captured bytes against
  T-002's committed canonical baseline; two independent invocations per
  target, fixed environment (Global Constraints).
- Author the required negative self-check: a deliberately mutated
  fixture (one byte changed in a captured target) must turn the suite red
  (AC-002).
- Extend `tests/install.tests.sh`/`tests/uninstall.tests.sh` with
  Context-absent fixture cases proving install/uninstall output is
  unaffected by `project-context.yaml` presence/absence.

### Done When

- [ ] Every AC-038 canonical-inventory target is asserted byte-identical
  across two independent invocations against a fixed, normalized
  environment, for both F1 and F2 (AC-003).
- [ ] The Context-absent CLI submatrix's six cells are each asserted
  byte-identical, exercising the CLI-flag → `AGENTS.md`-marker → default
  priority order (AC-003; ADR-0023 item 2).
- [ ] The negative self-check turns red when a single byte of the golden
  baseline is deliberately mutated (AC-002).
- [ ] `tests/install.tests.sh`/`tests/uninstall.tests.sh` gain
  Context-absent fixture cases with no existing case altered (INV-007).
- [ ] `tests/compatibility-byte-identical.tests.sh`/`.ps1` self-register
  in `tests/run-all.sh`/`.ps1`.
- [ ] Acceptance-first evidence: RED (the negative self-check's own
  mutated fixture) and GREEN (the full suite against the correct golden
  baseline). An independent quality-gate verdict records PASS.
- [ ] Implementation report created; quality gate passes; traceability.md
  updated with T-003 → REQ-001 (AC-002, AC-003, AC-038).

### Out of Scope

- The Resolver-absence spy check (AC-004) — owned by T-008 (Epic A5
  deferred assertions), since design.md's own Non-goals text places it
  inside `TEST-018`/`TEST-019`, not this suite.
- Capturing or promoting the golden baseline itself (T-002).
- F3–F8 (byte-identical is a Context-absent-only target, Compatibility
  Matrix — `N/A` for every Context-present row).

### Blockers

T-001, T-002

---

## T-004 Author the structural compatibility suite

Source Issue: https://github.com/aharada54914/sdd-forge/issues/195

Approval: Approved (sudo 2026-08-08T16:33:11Z)

Status: Planned

Risk: high

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. `high` is justified: this task implements Security Boundary B5
(security-spec.md#trust-boundaries — "a malformed recorded artifact must
never be silently treated as passing"). A silent defect in the AST
canonicalizer (treating a malformed frontmatter block or an unrecognized
heading as passing rather than a hard suite failure) would let the
structural-compatibility gate silently vacuous-pass, exactly the
"silent defect causes material harm" surface the policy's `high` tier
names, on the one gating suite standing between legacy-shaped generation
and a Facet-content leak (AC-005/AC-007). It is not `critical`: no
financial-settlement, physical-safety, or irreversible-destructive
surface. Required Workflow is `tdd` per the policy's high-tier row.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-002 (AC-005, AC-006, AC-007, AC-030, AC-042, AC-043)

Depends On: T-001 (functional — constructs F1–F4 fixtures, including the
F3/F4 `SKIP`-gated variants).

Planned Files:
- `tests/structural-compatibility.tests.sh` (new, agent-editable — the
  gating suite: `full`-track and `lite`-track structural assertions
  (AC-005/AC-006), the F4 Facet-reference-absence named `SKIP` (AC-007),
  the F3/F5/F6 named `SKIP`s (AC-042/AC-043))
- `tests/structural-compatibility.tests.ps1` (new, agent-editable — twin)
- `tests/lib/markdown-ast-canonicalizer.sh` (new, agent-editable — the
  frontmatter-key-sort / heading-order / whitespace-normalization
  algorithm design.md's Design Decisions fixes concretely; a parse
  failure is itself a hard failure, never a silent skip)
- `tests/lib/markdown-ast-canonicalizer.ps1` (new, agent-editable — twin)
- `tests/fixtures/structural-fixture-corpus/` (new — `structural-fixture-corpus/v1`
  recorded-response fixtures, one JSON file per exercised fixture-matrix
  cell: F1/F2 now, F3/F4 recorded but `SKIP`-gated until Epic A1/A4 merge)
- `tests/run-all.sh` (existing, agent-editable — `structural-compatibility.tests.sh`
  registration only, Global Constraints serialized order)
- `tests/run-all.ps1` (existing, agent-editable — twin registration)

Data Migration: none — `structural-fixture-corpus/v1` is a net-new schema
with no prior version.

Breaking API: no; every file here is wholly new.

Rollback: revert this task's commit(s) (infra-spec.md#rollback); the
corpus is refreshed only via the separate, non-gating live-refresh test,
never mutated by the gating suite itself.

### Goal

Author the deterministic recorded-response injection seam attached at
`plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md`'s
fingerprinted `## Required Outputs` anchor (design.md Design Decisions
"Structural-comparison seam," `sha256:075a42200327f735bf1e8627adee2736ad34aabd5cbf7f63f0db475f79f93504`),
the `structural-fixture-corpus/v1` record corpus, and the AST
canonicalizer (frontmatter key-sort, ordered heading comparison,
whitespace normalization) implementing REQ-002's structural assertions
for F1 (`full`-track legacy-seven-layer set, AC-005) and F2 (`lite`-track
three-file set, AC-005) now, with F3/F4/F5/F6 recorded as named `SKIP`
entries (AC-007, AC-042, AC-043) until their cited upstream epics merge.

### Must Read

- `specs/epic-195-a7-compatibility/requirements.md`
- `specs/epic-195-a7-compatibility/design.md` (Design Decisions
  "Structural-comparison seam: anchor, record corpus, parser-failure, and
  normalization algorithm"; Compatibility Matrix; Observable×
  fixture-state judgment table)
- `specs/epic-195-a7-compatibility/security-spec.md#trust-boundaries`
  (B5)
- `specs/epic-195-a7-compatibility/acceptance-tests.md`
- `specs/epic-195-a7-compatibility/traceability.md`
- `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md:116-133`
  (the injection anchor)
- `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/`
  (the `full`-track legacy-seven-layer templates, INV-018)
- `plugins/sdd-lite/templates/requirements-lite.md`,
  `design-lite.md`, `tasks-lite.md` (the `lite`-track three-file set,
  INV-024)
- `tests/lib/fixture-matrix-builder.sh` (T-001's own contract)

### Scope

- TDD Red→Green: write the malformed-corpus-entry fixture (deliberately
  bad frontmatter / unrecognized heading grammar) asserting a hard suite
  failure, before implementing the canonicalizer.
- Implement the AST canonicalizer's three-step algorithm exactly
  (frontmatter key sort — order never compared; heading text+level in
  document order — order IS compared; whitespace/line-ending
  normalization) — never comparing raw, un-normalized bytes (that is
  REQ-001's own disjoint class).
- Record the `structural-fixture-corpus/v1` entries for F1 (`full`-track)
  and F2 (`lite`-track); assert the exact required-file count,
  frontmatter, required headings, and status field names against the
  existing templates, unchanged.
- Author F4's Facet-reference-absence assertion (AC-007) and the F3/F5/F6
  structural-identity assertions (AC-042/AC-043) as named `SKIP` entries
  citing T-010's REQ-007 allowlist manifest (once it exists; until then,
  a local named-`SKIP` matching `LOOP_VALIDATOR_CAPABILITY`'s own
  degradation pattern, `tests/lib/loop-driver.sh:460-519`, AC-016).

### Done When

- [ ] `full`-track (F1) and `lite`-track (F2) structural assertions both
  pass against their own existing templates, unchanged — the `lite`-track
  templates never substituted for the `full`-track clause (AC-005
  `full`-track and `lite`-track clauses, INV-024).
- [ ] `REQ-NNN`/`AC-NNN` identifier format is asserted unchanged in
  Context-absent generation output (AC-006).
- [ ] The F4 Facet-reference-absence assertion is a named `SKIP` citing
  the Epic A4 dependency until it merges (AC-007).
- [ ] The F3 and F5/F6 structural-identity assertions are named `SKIP`s
  citing Epic A1 (F3) and the compound Epic A1+A6 dependency (F5/F6)
  until they merge (AC-042, AC-043).
- [ ] The gating suite runs fully offline against the recorded corpus,
  never a live model call (AC-030); a corpus/canonicalizer parse failure
  is a hard suite failure, never a silent skip.
- [ ] TDD evidence: RED (the malformed-corpus fixture) and GREEN (the
  full suite against the correct canonicalizer). An independent
  quality-gate verdict records PASS.
- [ ] `tests/structural-compatibility.tests.sh`/`.ps1` self-register in
  `tests/run-all.sh`/`.ps1`.
- [ ] Implementation report created; quality gate passes; traceability.md
  updated with T-004 → REQ-002 (AC-005, AC-006, AC-007, AC-030, AC-042,
  AC-043).

### Out of Scope

- Any change to `emit-run-record.sh`, the shared loop-driver, or the
  loop-inventory registry (T-005/T-009).
- The REQ-007 allowlist manifest's own canonical form and its three
  hard-fail checks (T-010) — this task's own named `SKIP`s are wired to
  read from that manifest once T-010 lands; until then they use the
  existing ad hoc `LOOP_VALIDATOR_CAPABILITY`-style degradation.
- The separate, non-gating AC-031 live-model refresh test that
  regenerates `structural-fixture-corpus/v1` entries (T-012) — this task
  builds and records the corpus's own initial F1/F2 entries but never
  live-refreshes them itself.
- F7/F8 (`N/A`, no Foundation epic ever produces these states).

### Blockers

T-001

---

## T-005 Extend the canonical event-trace schema (loop-inventory field + shared driver)

Source Issue: https://github.com/aharada54914/sdd-forge/issues/195

Approval: Approved (sudo 2026-08-08T16:33:11Z)

Status: Planned

Risk: high

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. `high` is justified, not merely asserted: this task edits
Security Boundary B2's own three named files
(security-spec.md#trust-boundaries — `tests/loops/loop-inventory.json`,
`tests/lib/loop-driver.sh`), a cross-epic shared surface every sibling
Epic A2/A3/A5 suite already depends on. A silent defect (a hidden default
that changes an existing consumer's control flow, or a non-additive field
that breaks `assert_terminal`/`assert_artifacts_schema`) breaks another
epic's own suite without warning, exactly the "silent defect causes
material harm" surface the policy's `high` tier names on a
cross-epic-blast-radius change. It is not `critical`: no financial-
settlement, physical-safety, or irreversible-destructive surface — a
revert restores every consumer's prior behavior (infra-spec.md#rollback).
Required Workflow is `tdd` per the policy's high-tier row.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-003 (AC-008, AC-009, AC-039)

Depends On: none within this feature (functional — the schema/driver
additions are self-contained library changes; Global Constraints
serializes this after T-004 for the shared `run-all` append order only).

Planned Files:
- `tests/loops/loop-inventory.json` (existing, agent-editable — one
  additive, optional `capability_applicability` field on the `quality-gate`
  entry only; entry count stays 8, AC-008)
- `tests/lib/loop-driver.sh` (existing, agent-editable — new private
  `_loop_trace_emit <kind> <producer> <value-json>` collector; new public
  `assert_capability_applicability <loop-id> <fixture-state> <observed>`;
  new public `assert_event_trace <golden-trace-path>` comparator;
  `assert_terminal`/`assert_artifacts_schema` themselves unmodified,
  AC-009)
- `tests/lib/loop-driver.ps1` (existing, agent-editable — twin)
- `tests/loop-inventory.tests.sh` (existing, agent-editable — a
  schema-validation case: a pre-epic copy of the registry, with no new
  field, still validates against the unbumped `loop-inventory/v1` schema,
  AC-008)
- `tests/loop-inventory.tests.ps1` (existing, agent-editable — twin)

Data Migration: `capability_applicability` is absent-safe (optional,
additive); no migration for existing `loop-inventory.json` consumers.

Breaking API: no; every change here is additive per design.md's own
Constraint Compliance table.

Rollback: revert this task's commit(s); no existing consumer of the
unmodified no-field baseline is broken by reverting the addition
(infra-spec.md#rollback).

### Goal

Add the additive, optional `capability_applicability` field
(`{"disabled-legacy": ..., "advisory": ..., "required": ...}`) to the
`quality-gate` `loop-inventory` entry only (no new `id`, entry count
stays 8), and add `_loop_trace_emit`/`assert_capability_applicability`/
`assert_event_trace` to `tests/lib/loop-driver.sh`, implementing the
single, trace-wide monotonic-`seq` collector and the pure comparator
design.md's Data Plan and API / Contract Plan fix, without modifying
`assert_terminal` or `assert_artifacts_schema`.

### Must Read

- `specs/epic-195-a7-compatibility/requirements.md`
- `specs/epic-195-a7-compatibility/design.md` (Data Plan "Canonical
  orchestration-event-trace schema," "Collector API," "Per-kind producer
  call sites"; API / Contract Plan `assert_capability_applicability`/
  `_loop_trace_emit`/`assert_event_trace`; Design Decisions
  "`capability_applicability` starts on `quality-gate` only")
- `specs/epic-195-a7-compatibility/security-spec.md#trust-boundaries`
  (B2)
- `specs/epic-195-a7-compatibility/acceptance-tests.md`
- `specs/epic-195-a7-compatibility/traceability.md`
- `tests/lib/loop-driver.sh:1493-1518` (`assert_artifacts_schema`/
  `assert_terminal`, the two functions this task must leave unmodified)
- `tests/loop-inventory.tests.sh:129-133` (the 8-entry count assertion
  this task must not break)

### Scope

- TDD Red→Green: write the schema-validation fixture (a pre-epic registry
  copy still validates) and the `assert_terminal`/`assert_artifacts_schema`
  non-regression fixture before implementing the field addition.
- Add `capability_applicability` to the `quality-gate` entry only —
  every other entry stays exactly as INV-001 records it.
- Implement `_loop_trace_emit` as the sole appender to a
  `loop_fixture_init`-reset `_LOOP_EVENT_TRACE` accumulator, with a
  single trace-wide monotonic `seq` counter (never per-kind).
- Implement `assert_capability_applicability`, reading
  `.loops[] | select(.id == $loop_id) | .capability_applicability[$fixture_state]`.
- Implement `assert_event_trace` as a pure comparator: reads the finished
  trace only, applies each event kind's own value-normalization rule,
  and fails on any `kind`/`producer`/`value`/count mismatch (Data Plan
  "Trace identity") — it never calls `_loop_trace_emit`.

### Done When

- [ ] `tests/loops/loop-inventory.json`'s entry count stays exactly 8
  after this task (AC-008); a pre-epic copy with no new field still
  validates against the unbumped schema.
- [ ] `capability_applicability` is present only on the `quality-gate`
  entry, in the documented three-key shape.
- [ ] `assert_terminal` and `assert_artifacts_schema` are byte-identical
  to their pre-task form; `assert_capability_applicability` is the only
  reader of the new field (AC-009).
- [ ] `_loop_trace_emit`, `assert_capability_applicability`, and
  `assert_event_trace` exist with exactly the signatures API / Contract
  Plan fixes; `assert_event_trace` never calls `_loop_trace_emit`.
- [ ] TDD evidence: RED (the schema-validation and non-regression
  fixtures against a deliberately incorrect field/function) and GREEN
  (the full fixture set against the correct implementation). An
  independent quality-gate verdict records PASS.
- [ ] Implementation report created; quality gate passes; traceability.md
  updated with T-005 → REQ-003 (AC-008, AC-009, AC-039).

### Out of Scope

- `TEST-018` in `tests/loop-consistency.tests.sh` (T-006) and `TEST-019`
  in `tests/loop-escalation.tests.sh` (T-007) — this task authors the
  functions those cases call, not the cases themselves.
- The Epic A5 deferred fixture assertions (T-008).
- `emit-run-record.sh` (T-009) — a separate shared file with its own
  task.
- AC-039's own per-component documentation is design.md's own content
  (already fixed at Impl-Review-Status: Passed); this task's own scope is
  limited to confirming, by construction, that only `quality-gate` reads
  the new field (the mechanical half of AC-039).

### Blockers

None

---

## T-006 Add TEST-018 to tests/loop-consistency.tests.sh

Source Issue: https://github.com/aharada54914/sdd-forge/issues/195

Approval: Approved (sudo 2026-08-08T16:33:11Z)

Status: Planned

Risk: medium

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. `medium` is justified: this task is an integration-test
consumer of T-001's fixture builder and T-005's already-secured driver
functions — a normal, fully-tested suite extension with observable
behavior (event-trace comparison pass/fail) but it does not itself
implement Security Boundary B2 (T-005's own scope); a defect here is
caught by comparing against a committed golden trace, not a silent
control-flow change to a shared file. It is not `high`: no new function
is added to the shared driver by this task. Required Workflow is
`acceptance-first` per the policy's medium-tier row.

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-003 (AC-022, AC-023, AC-024, AC-026, AC-032)

Depends On: T-001 (functional — constructs the Context-absent round-drive
fixture), T-005 (functional — `_loop_trace_emit`/`assert_event_trace`
must exist before this suite can call them).

Planned Files:
- `tests/loop-consistency.tests.sh` (existing, agent-editable — new
  `TEST-018` case, this suite's own next available case number after
  `TEST-017`)
- `tests/loop-consistency.tests.ps1` (existing, agent-editable — twin)
- `tests/fixtures/compatibility-event-trace/` (new — the committed
  golden-trace fixture(s) for a Context-absent round drive's
  skill-invocation-order, review-loop-presence, approval-checkpoint, and
  done-transition event kinds)

Data Migration: none.

Breaking API: no; `TEST-018` is an additive case in an existing suite.

Rollback: revert this task's commit(s) (infra-spec.md#rollback).

### Goal

Add `TEST-018` to `tests/loop-consistency.tests.sh`, driving a
Context-absent round through the shared driver and asserting the
observed skill-invocation-order, review-loop-presence, approval-checkpoint,
and done-transition event-kind values are identical to a recorded golden
trace via `assert_event_trace` — the single oracle T-005 authored.

### Must Read

- `specs/epic-195-a7-compatibility/requirements.md`
- `specs/epic-195-a7-compatibility/design.md` (Data Plan "Per-kind
  producer call sites"; Design Decisions "Suite placement for the
  orchestration-event trace")
- `specs/epic-195-a7-compatibility/acceptance-tests.md`
- `specs/epic-195-a7-compatibility/traceability.md`
- `tests/loop-consistency.tests.sh` (`TEST-008`, the existing
  end-to-end four-round drive this new case extends the pattern of)
- `tests/lib/loop-driver.sh` (T-005's own `_loop_trace_emit`/
  `assert_event_trace` this case calls)

### Scope

- Drive a Context-absent round (F1) through the shared driver via T-001's
  `build_fixture`, with `_loop_trace_emit` wired at each of the four
  event kinds' own named producer call sites this case exercises.
- Record the golden-trace fixture for this exact fixture state.
- Assert observed vs. golden via `assert_event_trace` (never a
  suite-local, ad hoc comparison).

### Done When

- [ ] `TEST-018` exists in `tests/loop-consistency.tests.sh` as the
  suite's own next case after `TEST-017` (AC-032).
- [ ] Skill-invocation-order, review-loop-presence, and
  approval-checkpoint event kinds each match the recorded golden trace
  for a Context-absent round drive (AC-022, AC-023, AC-024).
- [ ] The done-transition event kind is asserted as the last event in the
  round's own event sub-sequence (AC-026).
- [ ] Acceptance-first evidence: the case is written and run against the
  golden trace with an independent quality-gate verdict recording PASS.
- [ ] Implementation report created; quality gate passes; traceability.md
  updated with T-006 → REQ-003 (AC-022, AC-023, AC-024, AC-026, AC-032).

### Out of Scope

- `TEST-019` in `tests/loop-escalation.tests.sh` (T-007) — the
  quality-gate-outcome event kind is that suite's own scope.
- The Epic A5 deferred sub-cases inside `TEST-018` (anchor-fingerprint
  drift, Resolver-non-invocation, Block-surfacing) — T-008's own scope.
- Any Context-present (F3/F4) event-trace assertion — `SKIP`-gated until
  Epic A1 merges (T-010's manifest).

### Blockers

T-001, T-005

---

## T-007 Add TEST-019 to tests/loop-escalation.tests.sh

Source Issue: https://github.com/aharada54914/sdd-forge/issues/195

Approval: Approved (sudo 2026-08-08T16:33:11Z)

Status: Planned

Risk: medium

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly, identical reasoning to T-006: an integration-test consumer of
T-001/T-005, not itself a Security Boundary B2 implementer. Required
Workflow is `acceptance-first` per the policy's medium-tier row.

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-003 (AC-010, AC-019, AC-020, AC-025, AC-027)

Depends On: T-001 (functional — constructs the Context-absent and
F3/F4-invalid round-drive fixtures), T-005 (functional — the collector/
comparator functions this case calls), T-006 (functional — creates the
shared `tests/fixtures/compatibility-event-trace/` directory this task's
own Planned Files entry, below, states is "existing after T-006").

Planned Files:
- `tests/loop-escalation.tests.sh` (existing, agent-editable — new
  `TEST-019` case, this suite's own next available case number after
  `TEST-017`)
- `tests/loop-escalation.tests.ps1` (existing, agent-editable — twin)
- `tests/fixtures/compatibility-event-trace/` (existing after T-006,
  agent-editable — golden-trace fixtures for the quality-gate-outcome
  and `PROJECT_CONTEXT_INVALID` stop event kinds)

Data Migration: none.

Breaking API: no; `TEST-019` is an additive case in an existing suite.

Rollback: revert this task's commit(s) (infra-spec.md#rollback).

### Goal

Add `TEST-019` to `tests/loop-escalation.tests.sh`, asserting the
quality-gate-outcome event kind (escalation-decision producer and, when
capability-aware, the capability-applicability producer always last) and
the done-transition event kind against a recorded golden trace via
`assert_event_trace`, and record the `PROJECT_CONTEXT_INVALID` distinct
stop event for the F3-invalid/F4-invalid fixture variants (`SKIP`-gated
on Epic A1 alone, never the compound Epic A1+A5 gate T-008's own AC-021
uses).

### Must Read

- `specs/epic-195-a7-compatibility/requirements.md`
- `specs/epic-195-a7-compatibility/design.md` (Data Plan "Per-kind
  producer call sites" — `quality-gate-outcome` and `skip-stop-message`'s
  own two-producer shape; Design Decisions "Suite placement")
- `specs/epic-195-a7-compatibility/acceptance-tests.md`
- `specs/epic-195-a7-compatibility/traceability.md`
- `tests/loop-escalation.tests.sh` (`TEST-011`, the existing end-to-end
  quality-gate escalation drive this case extends the pattern of)
- `tests/lib/loop-driver.sh` (T-005's own collector/comparator)

### Scope

- Drive a Context-absent round (F1) and assert the quality-gate-outcome
  and done-transition event kinds against a recorded golden trace.
- Construct the F3-invalid/F4-invalid fixture variants (T-001's
  `valid_or_invalid` parameter) and assert a distinct
  `PROJECT_CONTEXT_INVALID` stop event is recorded — never the
  Context-absent compatibility-fallback trace reused — as a named `SKIP`
  until Epic A1 merges (local ad hoc `SKIP` until T-010's manifest
  exists).
- Assert the F3-invalid/F4-invalid event trace never reaches the
  Context-absent compatibility-fallback path (AC-020).

### Done When

- [ ] `TEST-019` exists in `tests/loop-escalation.tests.sh` as the
  suite's own next case after `TEST-017` (AC-010).
- [ ] The quality-gate-outcome event kind's escalation-decision and
  capability-applicability producers match the golden trace, with the
  capability-applicability event always last when both fire (AC-025).
- [ ] The done-transition event kind is asserted as the last event in
  this round's own sub-sequence (AC-026, this suite's own share).
- [ ] The skip/stop-message event kind's `stop` producer records a
  distinct `PROJECT_CONTEXT_INVALID` event for F3-invalid/F4-invalid,
  named `SKIP` until Epic A1 merges (AC-019, AC-027).
- [ ] F3-invalid/F4-invalid's event trace is asserted to never reach the
  Context-absent fallback path (AC-020).
- [ ] Acceptance-first evidence: the case is written and run against the
  golden trace with an independent quality-gate verdict recording PASS.
- [ ] Implementation report created; quality gate passes; traceability.md
  updated with T-007 → REQ-003 (AC-010, AC-019, AC-020, AC-025, AC-027).

### Out of Scope

- `TEST-018` in `tests/loop-consistency.tests.sh` (T-006).
- The compound Epic A1+A5 Resolver-non-invocation assertion for
  F3-invalid/F4-invalid (AC-021) — T-008's own scope (Epic A5 deferred
  assertions).
- The final, manifest-driven `SKIP` mechanism (T-010) — this task's own
  `SKIP` lines use the existing ad hoc degradation pattern until then.

### Blockers

T-001, T-005, T-006

---

## T-008 Author Epic A5's deferred fixture assertions inside TEST-018/TEST-019

Source Issue: https://github.com/aharada54914/sdd-forge/issues/195

Approval: Approved (sudo 2026-08-08T16:33:11Z)

Status: Planned

Risk: high

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. `high` is justified: this task implements Security Boundary B4
(security-spec.md#trust-boundaries — "a normative citation of another
epic's own spec text must never silently point at content that has since
changed underneath it"); AC-036 is literally the fingerprint-drift
enforcement test this repository relies on to catch exactly the NEW-001
class of failure design.md's own Design Decisions documents. The
Resolver-non-invocation spy (AC-004, AC-021) is also an access-control-
adjacent absence-check: a silent defect (the spy reporting "not invoked"
when it was) would let a Context-absent-or-invalid run silently invoke
capability machinery undetected, exactly the "silent defect causes
material harm" surface the policy's `high` tier names. It is not
`critical`: no financial-settlement, physical-safety, or irreversible-
destructive surface. Required Workflow is `tdd` per the policy's
high-tier row.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-003, REQ-007 (AC-004, AC-021, AC-036, AC-037)

Depends On: T-001 (functional — F3/F4-invalid fixture variants for
AC-021), T-006 (functional — adds sub-cases inside `TEST-018`), T-007
(functional — adds sub-cases inside `TEST-019`).

Planned Files:
- `tests/loop-consistency.tests.sh` (existing, agent-editable —
  anchor-fingerprint-drift `TEST` sub-case inside/after `TEST-018`,
  AC-036)
- `tests/loop-consistency.tests.ps1` (existing, agent-editable — twin)
- `tests/loop-escalation.tests.sh` (existing, agent-editable — the
  Resolver-non-invocation spy sub-case (AC-004, AC-021) and the
  Block-surfaces-not-fallback sub-case (AC-037) inside/after `TEST-019`)
- `tests/loop-escalation.tests.ps1` (existing, agent-editable — twin)

Data Migration: none.

Breaking API: no; every case here is an additive sub-case in an existing
suite.

Rollback: revert this task's commit(s) (infra-spec.md#rollback).

### Goal

Author, inside this feature's own existing suites (never a new suite
file, resolving OQ-001), the three fixture-level assertions Epic A5's own
`design.md` item 10(a)/(b)/(c) fixes: (a) anchor-fingerprint drift —
recompute `FP-A5-CALLER-CONTRACT-10`'s sha256 against the live
`sdd-bootstrap-interviewer/SKILL.md`, failing loudly on drift (AC-036);
(b) Context-absent and F3-invalid/F4-invalid Resolver-non-invocation spy,
adopting A5's own spy-harness fixture directly (AC-004, AC-021); (c) a
REQ-002 Block surfaces as a visible stop/error event, never a silent
fallback to legacy generation (AC-037, `FP-A5-BLOCK-REQ002`).

### Must Read

- `specs/epic-195-a7-compatibility/requirements.md`
- `specs/epic-195-a7-compatibility/design.md` (Design Decisions
  "Cross-epic fingerprint citations"; "OQ-001 resolved")
- `specs/epic-195-a7-compatibility/security-spec.md#trust-boundaries`
  (B4)
- `specs/epic-195-a7-compatibility/acceptance-tests.md`
- `specs/epic-195-a7-compatibility/traceability.md`
- `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md`
  (the live file this task's own anchor-drift case recomputes against)
- Epic A5's `design.md` item 10 at its own then-current HEAD (re-verify
  `FP-A5-CALLER-CONTRACT-10`/`FP-A5-BLOCK-REQ002`/
  `FP-A5-DISABLED-LEGACY-ROW` against Epic A5's own current spec before
  relying on the recorded digests, requirements.md Assumptions)

### Scope

- TDD Red→Green: write each of the three sub-cases' own negative fixture
  (a deliberately drifted anchor window; a fixture where the Resolver
  spy would report a false negative; a Block that silently falls back)
  before the implementation.
- Recompute `FP-A5-CALLER-CONTRACT-10`'s sha256 against the live
  `SKILL.md`; fail loudly on any mismatch (never a silent skip).
- Adopt A5's own spy-harness mechanism for the Context-absent (AC-004)
  and F3-invalid/F4-invalid (AC-021) Resolver-non-invocation checks,
  never a redesigned equivalent.
- Assert a REQ-002 Block (per `FP-A5-BLOCK-REQ002`) surfaces as a visible
  stop/error event in the trace, never silent fallback (AC-037).
- Every sub-case here is a named `SKIP` until its own cited upstream
  epic(s) merge (AC-004: Epic A5; AC-021: Epic A1 **and** Epic A5;
  AC-036/AC-037: Epic A5) — local ad hoc `SKIP` until T-010's manifest
  exists.

### Done When

- [ ] The anchor-fingerprint-drift sub-case recomputes and compares the
  live `SKILL.md`'s own sha256 against `FP-A5-CALLER-CONTRACT-10`,
  failing loudly on drift (AC-036).
- [ ] The Resolver-non-invocation spy fires for both the Context-absent
  fixture (AC-004) and the F3-invalid/F4-invalid fixtures (AC-021),
  reusing A5's own spy-harness mechanism directly.
- [ ] A REQ-002 Block surfaces as a visible stop/error event in the trace
  (AC-037), never silently falling back to legacy generation.
- [ ] Every sub-case here is `SKIP` until its own cited dependency merges
  (AC-016).
- [ ] TDD evidence: RED (each sub-case's own negative fixture) and GREEN
  (the full suite against the correct implementation). An independent
  quality-gate verdict records PASS.
- [ ] Implementation report created; quality gate passes; traceability.md
  updated with T-008 → REQ-003, REQ-007 (AC-004, AC-021, AC-036, AC-037).

### Out of Scope

- The base `TEST-018`/`TEST-019` cases themselves (T-006, T-007).
- The REQ-007 allowlist manifest's own canonical form (T-010) — this
  task's own `SKIP` lines are wired to read from it once T-010 lands.
- Re-specifying any of Epic A5's own remaining fixture assertions this
  package does not adopt (Non-goals).

### Blockers

T-001, T-006, T-007

---

## T-009 Extend emit-run-record.sh with the capability object

Source Issue: https://github.com/aharada54914/sdd-forge/issues/195

Approval: Approved (sudo 2026-08-08T16:33:11Z)

Status: Planned

Risk: high

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. `high` is justified: this task edits Security Boundary B2's
third named file (security-spec.md#trust-boundaries —
`plugins/sdd-quality-loop/scripts/emit-run-record.sh`), a cross-epic
shared surface every existing `v2` consumer (WFI attribution analysis)
already depends on. A silent defect in the no-flag byte-identical
guarantee (AC-011) would silently corrupt every existing consumer's own
input without any capability flag ever being supplied — the "silent
defect causes material harm" surface the policy's `high` tier names.
It is not `critical`: no financial-settlement, physical-safety, or
irreversible-destructive surface. Required Workflow is `tdd` per the
policy's high-tier row.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-003 (AC-011, AC-012, AC-033)

Depends On: none within this feature (functional — an independent
script; Global Constraints serializes this after T-008 for the shared
`run-all` append order only, since it extends an already-registered
suite and adds no new `run-all` line of its own).

Planned Files:
- `plugins/sdd-quality-loop/scripts/emit-run-record.sh` (existing,
  agent-editable — new `--capability-enforcement
  <disabled-legacy|advisory|required>` and `--capability-block-id <id>`
  flags, gated by a new `emit_capability` flag independent of `emit_v2`,
  mirroring `--effort-main`'s exact gating; the no-flag heredoc,
  `:283-304`, stays byte-identical)
- `plugins/sdd-quality-loop/scripts/emit-run-record.ps1` (existing,
  agent-editable — twin)
- `tests/emit-run-record-feature-scope.tests.sh` (existing, agent-editable
  — extended with the four flag-combination outcomes and the
  capability-only golden negative usage-error test)
- `tests/emit-run-record-feature-scope.tests.ps1` (existing,
  agent-editable — twin)

Data Migration: `capability` is a new, additive `v2` sibling object,
gated behind an independent flag; the no-flag `v1` output is unchanged.

Breaking API: no; every existing `v2` consumer that never supplies the
new flags sees byte-identical output (AC-011).

Rollback: revert this task's commit(s); no existing consumer of the
no-flag/effort-only shapes is broken by reverting the addition
(infra-spec.md#rollback).

### Goal

Add `--capability-enforcement <disabled-legacy|advisory|required>` and
`--capability-block-id <id>` to `emit-run-record.sh`, gated by a new,
independent `emit_capability` flag, producing exactly the four
flag-combination outcomes API / Contract Plan fixes: no-flag →
byte-identical `v1` (unchanged); `--effort-*` only → unchanged `v2` with
`effort` only; `--capability-enforcement` only (no `--effort-*`) → a
usage error, non-zero exit, no `$out` file written; both families → `v2`
with both `effort` and the new, additive `capability` object.

### Must Read

- `specs/epic-195-a7-compatibility/requirements.md`
- `specs/epic-195-a7-compatibility/design.md` (API / Contract Plan
  "`emit-run-record.sh` proposed flags"; Design Decisions
  "`emit-run-record.sh`'s capability-only combination is a usage error")
- `specs/epic-195-a7-compatibility/security-spec.md#trust-boundaries`
  (B2)
- `specs/epic-195-a7-compatibility/acceptance-tests.md`
- `specs/epic-195-a7-compatibility/traceability.md`
- `plugins/sdd-quality-loop/scripts/emit-run-record.sh:30-77,185,245-304`
  (the existing `emit_v2`/`effort` gating pattern this task mirrors
  exactly, INV-006)

### Scope

- TDD Red→Green: write the four-flag-combination fixture matrix
  (including the capability-only golden negative usage-error test)
  before implementing the new flags.
- Implement `--capability-enforcement`/`--capability-block-id` parsing,
  gated by `emit_capability`, independent of `emit_v2`.
- Implement the capability-only usage error, matching
  `require_effort_control_value`'s own fail-closed style (`:45-54`).
- Implement the additive `capability` object (`{enforcement, block_id}`,
  `block_id` optional, `null` when not supplied) in the both-flags case.
- Verify the no-flag heredoc is byte-identical to its pre-task form.

### Done When

- [ ] No-flag invocation output is byte-identical to today's
  `sdd-run-record/v1` shape (AC-011).
- [ ] `--effort-*`-only output is unchanged from today's `v2` shape, with
  no `capability` key at all.
- [ ] `--capability-enforcement`-only (no `--effort-*`) exits non-zero
  with no `$out` file written (AC-033).
- [ ] Both flag families together produce `v2` with both `effort` and the
  additive `capability` object, exactly the documented shape (AC-012,
  AC-033).
- [ ] TDD evidence: RED (each of the four combinations against a
  deliberately incorrect implementation) and GREEN (the full suite
  against the correct implementation). An independent quality-gate
  verdict records PASS.
- [ ] Implementation report created; quality gate passes; traceability.md
  updated with T-009 → REQ-003 (AC-011, AC-012, AC-033).

### Out of Scope

- `tests/loops/loop-inventory.json`/`tests/lib/loop-driver.sh` (T-005) —
  a separate shared file with its own task.
- The REQ-007 allowlist manifest (T-010).

### Blockers

None

---

## T-010 Author the REQ-007 SKIP allowlist manifest and its hard-fail checks

Source Issue: https://github.com/aharada54914/sdd-forge/issues/195

Approval: Approved (sudo 2026-08-08T16:33:11Z)

Status: Planned

Risk: high

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. `high` is justified: this task implements Security Boundary B3
(security-spec.md#trust-boundaries — "an upstream-dependent assertion
must have a named, auditable degradation, never an unexplained or
indefinitely-extended `SKIP`") and reuses B4's own fingerprint-recompute
mechanism (`fingerprint_match`). A silent defect in any of the three
hard-fail conditions (dependency-present `SKIP`, unknown `SKIP`,
fingerprint drift) is precisely the fail-open direction INV-023
identifies — a `SKIP` silently outliving its own justification, forever
masking a real coverage gap, the "silent defect causes material harm"
surface the policy's `high` tier names. It is not `critical`: no
financial-settlement, physical-safety, or irreversible-destructive
surface. Required Workflow is `tdd` per the policy's high-tier row.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-007 (AC-016, AC-034, AC-035)

Depends On: T-003, T-004, T-006, T-007, T-008 (functional — this task's
own manifest names, and its evaluator wires up, every named `SKIP` those
five tasks introduced ad hoc: AC-004, AC-007, AC-019, AC-020, AC-021,
AC-036, AC-037, AC-042, AC-043).

Planned Files:
- `tests/fixtures/skip-allowlist-manifest.json` (new, agent-editable —
  `skip-allowlist-manifest/v1`, exactly the five entries design.md's own
  Data Plan jsonc example fixes: AC-004, AC-007, AC-021, AC-042, AC-043)
- `tests/lib/skip-allowlist-evaluator.sh` (new, agent-editable — the
  `merged(<epic-id>)`/`fingerprint_match(<dependency-index>)` primitive
  predicates and the `AND`/`OR` `activation_condition` evaluator)
- `tests/lib/skip-allowlist-evaluator.ps1` (new, agent-editable — twin)
- `tests/skip-allowlist-manifest.tests.sh` (new, agent-editable — the
  three hard-fail checks: dependency-present `SKIP`, unknown `SKIP`,
  fingerprint drift)
- `tests/skip-allowlist-manifest.tests.ps1` (new, agent-editable — twin)
- `tests/loop-consistency.tests.sh`, `tests/loop-escalation.tests.sh`,
  `tests/compatibility-byte-identical.tests.sh`,
  `tests/structural-compatibility.tests.sh` (existing, agent-editable —
  each task's own local ad hoc `SKIP` lines from T-003/T-004/T-006/
  T-007/T-008 are re-pointed to read from this manifest, per AC-016)
- `tests/run-all.sh` (existing, agent-editable — this suite's
  registration, Global Constraints serialized order)
- `tests/run-all.ps1` (existing, agent-editable — twin registration)

Data Migration: none — `skip-allowlist-manifest/v1` is a net-new schema
with no prior version.

Breaking API: no; every file here is either wholly new or gains an
additive re-pointing of an existing `SKIP` line's own source, not a
behavior change to any currently-passing assertion.

Rollback: revert this task's commit(s); no manifest-specific rollback
mechanism is needed beyond restoring the manifest's own prior committed
content, since `fingerprint_match` is recomputed against each cited
epic's current HEAD at evaluation time, never cached
(infra-spec.md#rollback).

### Goal

Author the `skip-allowlist-manifest/v1` JSON array exactly as design.md's
own Data Plan fixes it (five entries: AC-004, AC-007, AC-021, AC-042,
AC-043, each `dependencies[]` an array of `{epic, issue, fingerprints[]}`),
the `merged`/`fingerprint_match` evaluator and its `AND`/`OR`
`activation_condition` grammar, and wire the three hard-fail checks
(AC-035) into the suite run: dependency-present `SKIP`, unknown `SKIP`,
and fingerprint drift — re-pointing every `SKIP` line T-003/T-004/T-006/
T-007/T-008 introduced ad hoc to read from this manifest (AC-016).

### Must Read

- `specs/epic-195-a7-compatibility/requirements.md`
- `specs/epic-195-a7-compatibility/design.md` (Data Plan "REQ-007 SKIP
  allowlist manifest"; "`activation_condition` grammar and evaluator")
- `specs/epic-195-a7-compatibility/security-spec.md#trust-boundaries`
  (B3, B4)
- `specs/epic-195-a7-compatibility/acceptance-tests.md`
- `specs/epic-195-a7-compatibility/traceability.md`
- `tests/lib/loop-driver.sh:460-519` (`loop_validator_skip`'s existing
  named-`SKIP` pattern this manifest extends)

### Scope

- TDD Red→Green: write the three hard-fail fixtures (a `merged(...)`-true
  entry that still emits `SKIP`; an unrecognized `SKIP`-shaped line; a
  `merged(...)`-true entry whose fingerprint no longer matches) before
  implementing the evaluator.
- Author the manifest with exactly design.md's own five entries and
  fingerprint values, unmodified from the recorded jsonc example.
- Implement `merged(<epic-id>)` (spec front matter terminal value **and**
  branch-ancestry check) and `fingerprint_match(<dependency-index>)`
  (sha256 recompute against the cited epic's current HEAD).
- Re-point every ad hoc `SKIP` line from T-003/T-004/T-006/T-007/T-008 to
  read its entry from this manifest.

### Done When

- [ ] The manifest exists with exactly the five documented entries and
  fingerprint values (AC-034).
- [ ] `merged`/`fingerprint_match` evaluate correctly against a fixture
  epic in each of {unmerged, merged-fingerprint-match,
  merged-fingerprint-mismatch} states.
- [ ] The suite hard-fails on dependency-present `SKIP` (AC-035a), on an
  unrecognized `SKIP`-shaped line (AC-035b), and on fingerprint drift
  (AC-035c) — three independent fixtures, each alone sufficient to fail.
- [ ] Every `SKIP` line from T-003/T-004/T-006/T-007/T-008 reads its
  entry from this manifest, not a local ad hoc string (AC-016).
- [ ] TDD evidence: RED (each of the three hard-fail fixtures) and GREEN
  (the full suite against the correct evaluator, including one fully
  clean fixture proving the suite does not fail vacuously). An
  independent quality-gate verdict records PASS.
- [ ] `tests/skip-allowlist-manifest.tests.sh`/`.ps1` self-register in
  `tests/run-all.sh`/`.ps1`.
- [ ] Implementation report created; quality gate passes; traceability.md
  updated with T-010 → REQ-007 (AC-016, AC-034, AC-035).

### Out of Scope

- Authoring any new assertion this manifest gates (T-003/T-004/T-006/
  T-007/T-008's own scope) — this task re-points their `SKIP` sources
  only, it does not add new assertions of its own.
- CI registration of any suite (T-011).

### Blockers

T-003, T-004, T-006, T-007, T-008

---

## T-011 Register every suite and verify the golden-baseline CI-write guards

Source Issue: https://github.com/aharada54914/sdd-forge/issues/195

Approval: Approved (sudo 2026-08-08T16:33:11Z)

Status: Planned

Risk: high

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. `high` is justified: this task authors the two checks
(AC-040/AC-041) that close Security Boundary B1's structural verification
loop (security-spec.md#trust-boundaries — "AC-040's static check
independently verifies CI's own workflow file never references either
mutation-capable command; AC-041 exercises the script's own runtime
refusal directly"). A silent defect (the static scan missing a reference,
or the runtime-refusal fixtures not actually invoking the guard) would
let a future CI job accidentally wire a mutation-capable golden-baseline
command into `.github/workflows/test.yml` undetected — the exact
"Broken Access Control"/"Security Misconfiguration" surface
security-spec.md's own OWASP Mapping names. It is not `critical`: no
financial-settlement, physical-safety, or irreversible-destructive
surface. Required Workflow is `tdd` per the policy's high-tier row.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-005 (AC-015, AC-028), REQ-006 (AC-040, AC-041)

Depends On: T-001, T-002, T-003, T-004, T-005, T-006, T-007, T-008, T-009,
T-010 (functional — this task registers every suite those tasks built
and needs `promote-golden-baseline.sh` from T-002 and the final,
cumulative `.github/workflows/test.yml` content to author AC-040/AC-041).

Planned Files:
- `.github/workflows/test.yml` (existing — protected-file status
  confirmed at implementation time, Protected Files above; registers
  every new/extended `.sh`/`.ps1` suite pair from T-002–T-010, except
  T-012's AC-031 live-refresh test, which is registered as a separate
  non-gating job or omitted from CI entirely)
- `tests/run-all.sh`, `tests/run-all.ps1` (existing, agent-editable —
  cumulative confirmation that every suite T-001–T-010 registered is
  present and correctly ordered)
- `tests/promote-golden-baseline-ci-guard.tests.sh` (new, agent-editable
  — AC-040's static scan of the committed `.github/workflows/test.yml`
  text for `promote-golden-baseline.sh`/`--write-candidate`; AC-041's
  direct runtime-refusal fixture pair against
  `promote-golden-baseline.sh`)
- `tests/promote-golden-baseline-ci-guard.tests.ps1` (new, agent-editable
  — twin)
- if `.github/workflows/test.yml` is confirmed protected at
  implementation time:
  `specs/epic-195-a7-compatibility/human-copy/.github/workflows/test.yml`
  (staged candidate) and
  `specs/epic-195-a7-compatibility/human-copy/MANIFEST.sha256` (new
  entry) — ADR-0011 pattern

Data Migration: none.

Breaking API: no; this task registers existing suite files, it does not
alter their own behavior.

Rollback: revert this task's commit(s); if `test.yml` required
human-copy staging, a human-applied step is separately, explicitly
reverted per infra-spec.md#rollback's own note on that case.

### Goal

Register every `.sh`/`.ps1` suite pair T-002–T-010 authored or extended
into `tests/run-all.sh`, `tests/run-all.ps1`, and
`.github/workflows/test.yml` (confirming that file's live protected-file
status first, Protected Files above), excluding T-012's AC-031 live-model
refresh test from the gating set; author AC-040 (a static scan of the
committed `test.yml` text for `promote-golden-baseline.sh`/
`--write-candidate`) and AC-041 (two independent negative fixtures
exercising `promote-golden-baseline.sh`'s own `CI`-env-var/`--approved-by`
runtime refusal directly).

### Must Read

- `specs/epic-195-a7-compatibility/requirements.md`
- `specs/epic-195-a7-compatibility/design.md` (Test Strategy item 9;
  Deployment / CI Plan; API / Contract Plan "Golden-baseline
  capture/promote contract")
- `specs/epic-195-a7-compatibility/security-spec.md#trust-boundaries`
  (B1); `specs/epic-195-a7-compatibility/security-spec.md#owasp-mapping`
- `specs/epic-195-a7-compatibility/acceptance-tests.md`
- `specs/epic-195-a7-compatibility/traceability.md`
- current live protected-file list (to resolve `.github/workflows/test.yml`'s
  own status before editing it, Protected Files above)
- Epic A5's own `human-copy/` staging precedent for a `test.yml`
  registration alongside a protected-file batch (investigation.md
  cross-epic finding), if staging is required

### Scope

- Confirm `.github/workflows/test.yml`'s live protected-file status;
  stage via `human-copy/` + `MANIFEST.sha256` if protected, edit directly
  otherwise.
- Register every T-002–T-010 suite pair in `tests/run-all.sh`/`.ps1` and
  the resolved `test.yml` path; exclude T-012's live-refresh test from
  both gating registrations.
- TDD Red→Green: write AC-040's negative fixture (a `test.yml` text
  containing either forbidden string) and AC-041's two negative fixtures
  (`CI` set; `--approved-by` omitted) before/alongside the checks.
- Confirm the Compatibility Matrix's own disposition legend (AC-028)
  matches what was actually built: every `ASSERT` cell has a passing
  case, every `SKIP-with-activation` cell reads from T-010's manifest,
  every `N/A` cell has no corresponding case.

### Done When

- [ ] Every new/extended `.sh` suite from T-002–T-010 has a registered
  `.ps1` twin, and both are registered in `tests/run-all.sh`/
  `tests/run-all.ps1` and (resolved) `.github/workflows/test.yml`
  (AC-015).
- [ ] AC-040's static scan hard-fails if `promote-golden-baseline.sh` or
  `--write-candidate` appears anywhere in the committed `test.yml` text.
- [ ] AC-041's two negative fixtures (`CI` set; `--approved-by` omitted)
  each assert a non-zero exit and no write to the canonical path.
- [ ] T-012's AC-031 live-model refresh test is registered as a separate,
  non-gating job or omitted from CI entirely — never inside the gating
  `test.yml` entries.
- [ ] Every Compatibility Matrix cell's own disposition (AC-028) is
  confirmed to match the assembled suite set: `ASSERT` cells have a
  passing case, `SKIP-with-activation` cells read from T-010's manifest,
  `N/A` cells have no case.
- [ ] TDD evidence: RED (AC-040/AC-041's own negative fixtures) and GREEN
  (the full assembled suite set). An independent quality-gate verdict
  records PASS.
- [ ] Implementation report created; quality gate passes; traceability.md
  updated with T-011 → REQ-005 (AC-015, AC-028), REQ-006 (AC-040, AC-041).

### Out of Scope

- Authoring any new compatibility assertion of its own — this task
  registers and cross-verifies T-001–T-010's own deliverables.
- F5–F8 registration (Global Constraints — no builder call, no case, in
  this feature's own Phase 2/3 increment).

### Blockers

T-001, T-002, T-003, T-004, T-005, T-006, T-007, T-008, T-009, T-010

---

## T-012 Author the non-gating AC-031 live-model structural-comparison refresh test

Source Issue: https://github.com/aharada54914/sdd-forge/issues/195

Approval: Approved (sudo 2026-08-08T16:33:11Z)

Status: Planned

Risk: high

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly, revised on task-review round 2 (RISK-APPROPRIATE, Major
finding): `high`, not `medium`, is required. This task is the sole
implementer of the write path for Security Boundary B5
(security-spec.md#trust-boundaries — "a malformed recorded artifact must
never be silently treated as passing"): the corpus's own
`refresh_procedure` field (design.md Data Plan) names this task's
live-model refresh as B5's one sanctioned mutation route for
`tests/fixtures/structural-fixture-corpus/`, the exact artifact T-004's
gating structural-compatibility suite trusts as its comparison oracle
(REQ-002, AC-005/AC-006). That is structurally the identical "silently
canonized as the new compatibility oracle" pattern that earns T-002 its
`high` tier under Boundary B1: a silent defect here (a live-model
response that is schema-valid but semantically wrong, written without
validation against T-004's own structural assertions) would become
T-004's new gating baseline undetected, matching security-spec.md's own
STRIDE-B5 threat text verbatim ("A malformed or subtly-altered
recorded-response fixture ... is silently treated as a passing
structural-compatibility comparison") — the "silent defect causes
material harm" surface the policy's `high` tier names. Unlike B1, the
frozen specification names no structural CI-env-var/`--approved-by`-
equivalent fail-closed guard on this write path: AC-031 only requires the
refresh test to exist, exercise the live model, and stay non-gating;
B5's own mitigation column names procedure ("the corpus is refreshed
only via the separate, non-gating AC-031 ... test, never mutated by the
gating suite itself") and the canonicalizer's existing
parse-failure-is-a-hard-fail discipline (AC-030), not a dedicated
structural refusal comparable to AC-040/AC-041 — no such AC is fabricated
here. The gap is instead compensated by (1) this task's own Done When
now requiring the refresh path to validate a live-model response against
T-004's own structural assertions (the AC-030 canonicalizer) *before*
writing any corpus entry, refusing — non-zero exit, no corpus write — on
a structural mismatch, closing the schema-valid-but-semantically-wrong
gap the shape-only check left open; (2) `high`-tier TDD Red→Green
evidence capturing that refusal path as the Red case; and (3) an
independent quality-gate verdict (risk-gate-matrix.md high-tier row)
that reviews the refreshed corpus content itself, not merely its shape.
It is not `critical`: no financial-settlement, physical-safety, or
irreversible-destructive surface — a bad refreshed entry is a plain
`git revert` of that entry's own commit (infra-spec.md#rollback), and
the gating suite is structurally unaffected by anything this task does
unless a resulting corpus entry is actually merged. Required Workflow is
`tdd` per the policy's high-tier row.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-002 (AC-031)

Depends On: T-001 (functional — constructs the fixture-matrix states this
refresh test drives against a live model), T-004 (functional — this task
regenerates entries in the `structural-fixture-corpus/v1` schema, the AST
canonicalizer, and the fingerprinted injection anchor T-004 authors; it
never defines its own corpus schema or canonicalizer).

Planned Files:
- `tests/structural-compatibility-live-refresh.tests.sh` (new,
  agent-editable — AC-031's separate, explicitly non-gating live-model
  refresh test; never added to the gating `run-all` array, Global
  Constraints)
- `tests/structural-compatibility-live-refresh.tests.ps1` (new,
  agent-editable — twin)
- `tests/fixtures/structural-fixture-corpus/` (existing after T-004,
  agent-editable — this task's own live-model refresh writes/updates
  recorded-response entries via the corpus's own `refresh_procedure`
  field, design.md Data Plan; never mutated by the gating suite itself)

Data Migration: none — the live-refresh test is a net-new, non-gating
script; any corpus entry it writes is an additive update within the
existing `structural-fixture-corpus/v1` schema T-004 defines, never a
schema change of its own.

Breaking API: no; `structural-compatibility-live-refresh.{sh,ps1}` are
wholly new files, and this task alters no gating suite's behavior.

Rollback: revert this task's commit(s) (infra-spec.md#rollback); since
this test never runs in the gating suite or in CI, a revert has zero
blast radius on any consumer's own pass/fail state. A corpus entry this
task's refresh path later writes is likewise a plain committed JSON file
under `structural-fixture-corpus/v1` (no promotion history to
reconcile, unlike T-002's golden baseline) — a bad refreshed entry is a
straightforward `git revert` of that entry's own commit, never a special
procedure.

### Goal

Author the separate, explicitly non-gating
`tests/structural-compatibility-live-refresh.{sh,ps1}` test implementing
AC-031: exercising the structural-compatibility assertions against an
actual live model call to regenerate `structural-fixture-corpus/v1`
entries via the corpus's own `refresh_procedure` field (design.md Data
Plan), with its own result never required for, and never registered
inside, the gating `tests/run-all.sh`/`.github/workflows/test.yml`
entries (AC-015).

### Must Read

- `specs/epic-195-a7-compatibility/requirements.md`
- `specs/epic-195-a7-compatibility/design.md` (Data Plan
  "Structural-comparison seam" — `refresh_procedure` field; Design
  Decisions; Deployment / CI Plan)
- `specs/epic-195-a7-compatibility/security-spec.md#trust-boundaries`
  (B5)
- `specs/epic-195-a7-compatibility/acceptance-tests.md`
- `specs/epic-195-a7-compatibility/traceability.md`
- `tests/lib/fixture-matrix-builder.sh` (T-001's own contract, consumed
  here)
- `tests/structural-compatibility.tests.sh`,
  `tests/lib/markdown-ast-canonicalizer.sh` (T-004's own gating suite and
  canonicalizer this refresh test exercises against a live model instead
  of the recorded corpus)

### Scope

- Implement the live-model refresh test's own invocation path against the
  same structural assertions T-004's gating suite performs, but sourced
  from an actual live model call rather than the recorded
  `structural-fixture-corpus/v1` entries.
- Implement the corpus's own `refresh_procedure` (design.md Data Plan) as
  the only sanctioned regeneration path for `structural-fixture-corpus/v1`
  entries.
- Verify this test is never invoked by
  `tests/run-all.sh`/`.github/workflows/test.yml`; register it, if at
  all, as a separate explicitly non-gating entry only, or leave it
  run-manually-only (Global Constraints).
- Implement the refresh path so it validates a live-model response
  against T-004's own structural assertions (the AC-030 canonicalizer)
  before writing any corpus entry, refusing — non-zero exit, no corpus
  file touched — on a structural mismatch; a schema-valid-but-wrong
  response must never be written as-is (security-spec.md B5).
- TDD Red→Green: write the fixture asserting that refusal path (a
  live-model response engineered to fail the AC-030 structural
  assertions must be rejected — non-zero exit, no corpus write) before
  implementing the validate-then-write logic.

### Done When

- [ ] `tests/structural-compatibility-live-refresh.sh`/`.ps1` exist and
  exercise the structural-compatibility assertions against an actual live
  model call (AC-031).
- [ ] The test's own result is never required for the gating compatibility
  suite's own pass/fail verdict (AC-031).
- [ ] The test is never registered in the gating
  `tests/run-all.sh`/`.github/workflows/test.yml` entries — registered
  instead as a separate, explicitly non-gating entry, or left
  run-manually-only (AC-015, AC-031, Global Constraints).
- [ ] Any corpus entry the refresh path writes follows
  `structural-fixture-corpus/v1`'s own documented schema and the
  `refresh_procedure` field's own contract, never mutating a
  gating-suite-consumed entry outside this sanctioned path
  (security-spec.md B5).
- [ ] Before writing, the refresh path validates the live-model response
  against T-004's own structural assertions (the AC-030 canonicalizer:
  frontmatter parse, required headings, required-file count) and refuses
  — non-zero exit, no corpus file touched — on a structural mismatch, so
  a schema-valid-but-semantically-wrong response can never silently
  become T-004's new gating baseline (security-spec.md B5, STRIDE
  Tampering/Elevation-of-Privilege row).
- [ ] TDD evidence: RED (a live-model response deliberately engineered to
  fail the AC-030 structural assertions, asserting the refresh path
  rejects it — non-zero exit, no corpus write — before the
  validate-then-write logic is implemented) and GREEN (the full suite,
  including a successful refresh against an actual live model call).
  An independent quality-gate verdict records PASS, reviewing the
  refreshed corpus content itself, not only its schema shape.
- [ ] Implementation report created; quality gate passes; traceability.md
  updated with T-012 → REQ-002 (AC-031).

### Out of Scope

- The gating structural-compatibility suite itself, the AST canonicalizer,
  and the `structural-fixture-corpus/v1` schema definition (T-004's own
  scope) — this task only ever refreshes corpus entries via the
  sanctioned path; it does not define the schema or any gating assertion.
- CI registration of any gating suite (T-011).
- F3–F8 corpus entries beyond what T-004's own Compatibility Matrix scope
  already covers (Global Constraints).

### Blockers

T-001, T-004
