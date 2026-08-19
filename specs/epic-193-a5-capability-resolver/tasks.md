# Tasks: epic-193-a5-capability-resolver

Task-Review-Status: Passed

Source: Issue #193 (Epic A5 — Capability Resolver), tracked under epic
#187 (AI-DLC Foundation) /
requirements.md (Spec-Review-Status: Passed) /
design.md (Impl-Review-Status: Passed)

## Lifecycle

`Draft -> Approved -> In Progress -> Implementation Complete -> Done`

A task may enter `Blocked` from any active state. Humans approve tasks.
`implement-task` may set `In Progress`, `Blocked`, or `Implementation
Complete`. Only `quality-gate` may set `Done`.

## Protected Files

This feature inherits, rather than itself creates, a protected-path
situation (design.md Protected-File Statement) — different in kind from
every sibling epic's own protection choice:

1. **Already-reserved, protected-suffix placeholders — two paths, owned
   by Epic A1 (ADR-0019 item 3), not by this feature's own design
   decision.** `plugins/sdd-quality-loop/scripts/resolve-project-
   context.{py,sh,ps1}` and `plugins/sdd-quality-loop/scripts/generated/
   project-context.resolved.json` match `PROTECTED_GATE_SUFFIXES` entries
   Epic A1's own `guard-invariants.json` registration commit adds (a
   suffix match denies a write regardless of whether a file currently
   exists at that path). **T-002 (first to stage this script family) and
   T-007 (last to stage it, layering the publication transaction) each
   re-verify, at their own implementation-start time, whether that Epic
   A1 registration commit has already landed on this branch** (`grep -n
   "resolve-project-context" plugins/sdd-quality-loop/references/
   guard-invariants.json` — at this package's own Phase-2-authoring time
   the reservation is **not yet live** on this worktree, design.md
   Protected-File Statement point 1):
   - **If landed**: `resolve-project-context.py`/`.sh`/`.ps1` are
     developed unprotected-first at a fully testable, non-protected
     location, then the finished, tested *script content* is staged
     under `specs/epic-193-a5-capability-resolver/human-copy/
     plugins/sdd-quality-loop/scripts/resolve-project-context.{py,sh,
     ps1}` with a `MANIFEST.sha256` entry for a human to apply via
     `apply-human-copy` — a **content-population** human-copy (Epic A1
     already performed the suffix *registration*; this feature's own
     tasks never touch `guard-invariants.json`).
   - **If not yet landed**: the task falls back to the sequencing Epic
     A1 itself used for its own concrete-but-not-yet-existing entries —
     author the scripts unprotected-first and let Epic A1's own
     (still-pending) human-copy batch perform the registration in the
     same commit it already plans to, rather than this feature inventing
     a second, competing registration of the identical two paths.
   - Either way, **`generated/project-context.resolved.json` is never a
     human-copy target** (adversarial review "M7 human-copy boundary") —
     it has no fixed "initial content"; it is a pure function of
     whatever `project-context.yaml` a live repository carries,
     recomputed on every Full-track resolve and written only by the
     running Resolver process itself, via T-007's own journaled
     publication transaction, never by a human `cp`.
2. **Never protected, agent-editable directly, no human-copy step**:
   `contracts/resolver-evidence.schema.json` (T-001) and
   `plugins/sdd-quality-loop/scripts/validate-resolver-evidence.{py,sh,
   ps1}` (T-008) — matching Epic A4's own three schema-validator
   precedent (structural validators, not cross-runtime-hashed digest
   primitives).
3. **Per-Feature generated instances, unprotected, agent-writable only
   via the Resolver itself** (never hand-edited): `specs/<feature>/
   facet-manifest.yaml`, `specs/<feature>/capability-summary.yaml`,
   `specs/<feature>/resolver-evidence.yaml`.

**No task below adds a new entry to `PROTECTED_GATE_SUFFIXES`** — this
feature introduces no new protection category (unlike Epic A3's own
`check-component-coverage.*` precedent); its only interaction with the
guard-invariants surface is filling in content at a reservation an
upstream epic already made.

**Hard boundary carried into Phase 2 (requirements.md Non-goals,
design.md Constraint Compliance): no task below edits any file under
`plugins/**`.** REQ-007 documents `sdd-bootstrap-interviewer/SKILL.md`'s
target capability-interview insertion point (design.md Design Decisions,
"caller insertion point"/"anchor fingerprint") as a citation only; the
actual edit — and the `tests/resolve-project-context-caller-contract.
tests.sh`/`.ps1` suite that exercises it (design.md Test Strategy item
10) — is explicitly deferred to that future, not-yet-scheduled
implementation task, not scheduled by this `tasks.md`. AC-029 through
AC-032 (REQ-007's design-content criteria) are already satisfied by
`design.md`/`requirements.md`'s own text, recorded in
`acceptance-tests.md`'s own "Spec-Authoring-Time Manual Review Record" —
no task reproduces that record. AC-042/AC-046/AC-053 (TEST-042/046/053,
the deferred suite's own criteria) are correspondingly out of this
`tasks.md`'s own scope; see "Deferred, Not Scheduled" below.

## Global Constraints

- **Two-commit landing plan per task** (commit A = implementation +
  tests + fixtures + registration + human-copy staging, commit B =
  docs), matching `specs/epic-159-pillar-c/tasks.md`'s and Epic
  A3/A4's own convention: commit A must land before commit B within the
  same task. Each of T-001..T-010 lands its OWN new `## Unreleased`
  block in `CHANGELOG.md` citing issue #193 — never an append to another
  task's own entry (REQ-008/AC-033).
- **Task-decomposition note (four task-review remedy passes across two
  attempts, all tracing back to the same original TASK-SIZE root
  cause)**: the original Phase-2 draft bundled the core evaluation
  engine (steps 0-13) together with all five of its own test suites
  (`cli`/`match`/`lite`/`discovery`/`block`) into one task.
  **Attempt-1 round-1 remedy**: reviewer-b's first TASK-SIZE finding
  (12+ pipeline stages plus five new test suites in one unit of work)
  was addressed by splitting that task into a narrower engine task (the
  core engine plus the `match`/`block` suites) and a new task for the
  `cli`/`discovery`/`lite` suites, renumbering every later task up by
  one. **Attempt-1 round-2 remedy**: reviewer-b's own re-check found the
  round-1 split insufficient — the engine task still bundled the entire
  undivided 12+-stage engine with two full TDD suites (`match` and the
  twelve-fixture `block`) — so it was split once more, taking
  reviewer-b's own stated minimum-sufficient option at the time
  (isolate the `block` suite into its own task; isolating `match` as
  well was deliberately rejected, since it would leave the engine task
  with no test suite of its own, conflicting with its own `Required
  Workflow: tdd`). Round-2 also corrected a DEPENDENCY-OVERLAP finding
  on two tasks that each now correctly cited the new `block`-suite task
  as a Blockers entry. No requirement, acceptance criterion, or test
  suite was dropped or added by either remedy — see
  `reports/task-review/epic-193-a5-capability-resolver/attempt-1/
  round-1/tasks-round-1-proposed-changes.md` and `.../round-2/
  tasks-round-2-proposed-changes.md`. **Attempt-1 round-3 found the
  round-2 remedy still insufficient (BLOCKED, 3 Major, 0 Critical,
  `.../round-3/reviewer-b.json`)**: TASK-SIZE, because round-2's actual
  remedy relocated only the `block` test suite, never the fourteen-step
  engine's own production-code scope, which remained exactly as
  undivided as after round-1; SCOPE-DISJOINT and DEPENDENCY-OVERLAP,
  because the CLI-registration suite/task graph that had grown up around
  the still-undivided engine task carried gaps in its own shared-file
  Blockers edges. **Attempt-2 round-1 remedy, addressing all three
  round-3 findings at their root**: the engine (API / Contract Plan
  steps 0-13, formerly one task) was split into three sequential tasks
  along design.md's own step boundaries — T-002 (steps 0-3), T-003
  (steps 4-9), and T-004 (steps 10-13, at that point still paired with
  the `match` suite) — the former standalone `block`-suite task
  dissolved, its twelve non-transactional fixtures distributed across
  T-002/T-003/T-004 by first-reachable step, and every task from the
  former "cli/discovery/lite" task onward renumbered up (former T-004 →
  T-005, T-005 → T-006, T-006 → T-007, T-007 → T-008, T-008 → T-009),
  with every Blockers entry updated to a direct edge to its correct
  predecessor. **Attempt-2 round-1's own reviewer-b found this
  insufficient in one respect (NEEDS_WORK, 1 Major, 0 Critical,
  `.../round-1/reviewer-b.json`)**: TASK-SIZE on T-004 — pairing the
  steps-10-13 production code with an entirely new 11-TEST-ID `match`
  suite (12 ACs) in one task, joined by "and" in its own title, was
  materially larger than every sibling task (round-1's other two
  findings, SCOPE-DISJOINT and DEPENDENCY-OVERLAP, were independently
  re-verified clean). **This revision's own remedy**: isolate the
  `match` suite out of T-004 into its own new downstream task (T-005),
  Blocked by T-004 (needs the complete, schema-self-validated engine)
  and by T-002 (the immediately preceding CI-registering task, since
  neither T-003 nor T-004 touches the shared registration file) —
  mirroring the identical by-first-reachable-step mechanism already used
  for the block-suite fixtures. T-004 itself keeps only its own
  production code (steps 10-13) and its own three block-suite fixtures,
  remaining independently `tdd`-verified without the `match` suite.
  Every task from the former "cli/discovery/lite" task onward renumbers
  up once more (former T-005 → T-006, T-006 → T-007, T-007 → T-008,
  T-008 → T-009, T-009 → T-010), with every Blockers entry updated to a
  direct edge to its correct new predecessor, both functionally and for
  CI-registration ordering. No requirement, acceptance criterion, or
  test suite is dropped, added, or renamed by any of these four remedy
  passes; every AC-NNN/TEST-NNN citation below is unchanged from
  `acceptance-tests.md`, only its owning task changes. See
  `reports/task-review/epic-193-a5-capability-resolver/attempt-2/
  round-1/tasks-round-1-proposed-changes.md` for this round's own full
  finding and remedy record.
- **Test-suite/CI-registration serialization.** Ten tasks author this
  feature's nine test suites (one task, T-005, owns the `match` suite
  alone; the remaining eight suites are one-per-task except the shared
  `block` suite, below); each NEW suite is registered directly
  (unprotected) in `tests/run-all.sh`/`.ps1` (AC-026) and its own CI
  steps are staged into the shared candidate under `specs/epic-193-a5-
  capability-resolver/human-copy/.github/workflows/test.yml` (R-10
  protected — `test.yml` itself is never written directly) with a
  `MANIFEST.sha256` entry — but only **seven** of the ten tasks actually
  touch that shared registration file, since T-003, T-004, and T-007
  each only append fixtures to an **already-registered** suite (see
  below) without registering anything new. The seven registering tasks
  land, and stage their own CI steps, in this exact order, **each
  directly Blocked by the immediately preceding one in this list**
  (mirroring `specs/epic-191-a3-path-ownership/tasks.md`'s identical
  convention for a shared protected CI file, and making every
  consecutive pair a direct edge, never only a transitive one):
  **T-001 → T-002 → T-005 → T-006 → T-008 → T-009 → T-010.** A task that
  stages after another whose candidate is not yet human-applied appends
  its own suite's steps to that pending staged file rather than starting
  from the unmodified real `test.yml`.
- **`tests/resolve-project-context-block.tests.sh`/`.ps1` is a single,
  shared suite file spanning four tasks in strict sequence**: **T-002
  creates it** (registration + five fixtures for the diagnostic-id rows
  step 0-3's own code makes reachable: `disabled-legacy-invocation`,
  `workflow-combination-invalid`, `project-context-validation-failed`,
  `canonicalizer-invocation-failed`, `dependency-output-malformed` — the
  latter two are generic, multi-site rows design.md treats identically
  regardless of which step triggers them, so one fixture each, authored
  at their own first reachable site, is this row's own complete
  coverage; no later task re-tests an already-covered row); **T-003
  appends** five more fixtures for the rows steps 4-9 make newly
  reachable: `affected-component-resolution-failed`, `registry-
  validation-failed`, `contract-discovery-failed`, `dependency-
  subprocess-failed`, `dsl-warn-on-matched-capability`; **T-004 appends**
  three more — `lite-check-source-undefined`, `output-schema-
  validation-failed`, and the first (digest-mismatch) `snapshot-
  generation-mismatch` fixture, the rows steps 10-13 make newly
  reachable — completing all twelve non-transactional rows AC-010 fixes
  for this feature's own engine (5+5+2 unique rows plus the one shared
  row, `snapshot-generation-mismatch`, whose second fixture is T-007's
  own, below); **T-007 appends** the four transactional-diagnostic
  fixtures (`publication-journal-recovery`, `artifact-publication-
  failed`, `post-publication-generation-mismatch`, and the second,
  `affected_components`-only `snapshot-generation-mismatch` fixture
  pairing with T-004's digest-only one), completing AC-010's full
  sixteen-row matrix and AC-011/012/013/014's own全-Block-fixture
  completeness (Task Mapping, traceability.md). Each contributing task
  only appends its own new fixtures, never touching an earlier
  contributor's own fixtures.
- **`resolve-project-context.{py,sh,ps1}` is one Python-master-plus-
  wrapper component edited by exactly four tasks, in strict sequence**:
  T-002 authors steps 0-3 (argument validation, state derivation,
  Project Context canonicalization, Context Projection assembly); T-003
  authors steps 4-9 (`resolve-component-paths` invocation, Registry
  discovery, `registry_digest`, per-Capability/per-component trigger
  evaluation, matched-Capability conditional-facet evaluation, the
  any-branch WARN check); T-004 authors steps 10-13 (the track branch,
  Resolver Evidence assembly, output schema self-validation, the
  pre-publication snapshot recheck); T-007 layers the crash-recovery
  scan (end of step 0) and step 14's own journaled publication
  transaction (Prepare / Journal / Commit / Post-publication-
  verification / Complete) onto that same script. No task's own diff to
  this file may be developed against a live protected path directly —
  see "Protected Files" above. **T-005 (the `match` suite) and T-006
  (the CLI/discovery/Lite-track test suites) never edit this file** —
  each only adds tests/fixtures exercising the engine T-002/T-003/T-004
  already authored, exactly as the two former "test-only" tasks
  (`cli`/`discovery`/`lite` and `block`) never edited it either.
- **Deferred, not scheduled** (design.md Test Strategy item 10, REQ-007
  Non-goals): `tests/resolve-project-context-caller-contract.tests.sh`/
  `.ps1` is fixed at contract level by `design.md` (Design Decisions,
  "caller insertion point"/"anchor fingerprint" — the recorded sha256
  window fingerprint and section-order index this suite's own future
  fixture will assert against) but is **not** authored by any task
  below — design.md states it "is itself authored once the capability
  interview phase is actually implemented (a future task, Non-goals)."
  **AC-026's own "ten new suites registered" criterion is therefore
  satisfied by this `tasks.md` only for the nine suites T-001..T-010
  build** (`resolve-project-context-cli`, `-block`, `-match`, `-lite`,
  `-discovery`, `resolver-evidence-schema`, `validate-resolver-
  evidence`, `-parity`, `-metamorphic`); the tenth (`-caller-contract`)
  registers alongside that future `SKILL.md`-editing task, not here. No
  task below is scoped to close this gap.
- **No task authors a new ADR** — ADR-0016/0017/0019/0020/0021/0023/0025
  already normatively cover this feature's entire scope (design.md ADR
  Change Log); this feature's own six new orchestration decisions are
  design-level, not ADR-worthy (design.md ADR Change Log items 1-6).
- **Version bumps only via `scripts/bump-version.sh`**; no task
  hand-edits a version string or executes that script itself
  (REQ-008/AC-034 — a grep-based self-check on each task's own diff).
- **Stdlib-only Python** (investigation.md INV-011, design.md Global
  Constraints) — no third-party dependency in any script this feature
  adds, matching every existing script under `plugins/sdd-quality-loop/
  scripts/`.
- **Diagnostic determinism contract** (design.md Global Constraints,
  reusing Epic A4's own verbatim): UTF-8, no BOM, LF-only line endings on
  every runtime including the `.ps1` wrapper on Windows, for every
  diagnostic line this feature's scripts emit; every `<detail>` field is
  a canonical, Resolver-owned sentence, never a dependency subprocess's
  own raw stderr text (M8).
- **Closed enums, never extended by any task**: `resolve-project-
  context`'s own sixteen-value `diagnostics[].id` enum (REQ-002) and
  `validate-resolver-evidence`'s own, independent twelve-value check-id
  enum (REQ-004) — the two enums never share a member.
- **No code path reads the clock, the network, or a provider API**
  anywhere in this feature's own orchestration logic (REQ-005/Security
  Boundaries) — a repository-wide grep self-check (AC-025) is part of
  T-009's own Done When, run against every script this feature adds.
- Preserve unrelated changes; implement one task at a time.

---
## T-001 Author `contracts/resolver-evidence.schema.json` and its schema-conformance suite

Source Issue: https://github.com/aharada54914/sdd-forge/issues/193

Approval: Approved (sudo 2026-07-22T17:18:41Z)

Status: Done

Risk: medium

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. Not `high`: this schema has no upstream dependency of its own
(design.md Cross-Layer Dependencies — "the one artifact this feature is
free to shape itself") and an under-constrained schema is itself caught
downstream by T-008's `validate-resolver-evidence` semantic checks before
any Resolver Evidence instance is ever trusted by a caller — a schema
defect here degrades to a T-008-catchable defect, not a silent
production-time misclassification. Not `low`: this schema is the sole
structural contract every other task's own fixtures validate against: an
error here (a wrong `required` list, a wrong `enum`, a missing `if`/
`then` pair) would propagate into every downstream task's own fixture
authoring before being caught. Required Workflow is `acceptance-first`
per the risk-gate-matrix's own medium-tier row (`tdd` is reserved for
high/critical; `medium` requires acceptance-tests/regression coverage
written before implementation, not a red→green TDD cycle).

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-004 (schema), REQ-006 (share — fixture-matrix item e,
one row of REQ-002's sixteen), REQ-008 (share — CHANGELOG)

Depends On: none (functional — REQ-004's own schema has no upstream
dependency, design.md Cross-Layer Dependencies). Not blocked by, and does
not block, Epic A1/A2/A3/A4's own CLI landing status — every fixture this
task authors is a hand-crafted YAML/JSON Resolver Evidence instance
validated directly against this task's own schema document, never an
invocation of `resolve-project-context` itself (which does not yet exist
until T-002/T-003/T-004 land).

Planned Files:
- `contracts/resolver-evidence.schema.json` (new, agent-editable —
  JSON Schema draft-07; `schema`/`feature`/`state`/`context_binding`/
  `resolver`/`capability_evaluations[]`/`diagnostics[]`, with
  `capabilityEvaluation`/`componentEvaluation`/`evidenceNode`/
  `diagnostic`/`sha256Digest` definitions; design.md API / Contract Plan
  gives the exact document verbatim)
- `tests/resolver-evidence-schema.tests.sh` (new, agent-editable)
- `tests/resolver-evidence-schema.tests.ps1` (new, agent-editable)
- `tests/fixtures/capability-resolver/resolver-evidence-schema/` (new
  fixture tree — a schema-conformant instance per required-field
  combination, a `diagnostics: []` clean-success instance (AC-020), a
  matched-Capability instance with `conditional_facet_evaluations[]`
  present and an unmatched-Capability instance with the key omitted
  (AC-019's `if`/`then` schema branch), and one instance per required-
  field omission / wrong-type / wrong-enum-value negative case)
- `tests/run-all.sh` (existing, agent-editable — this suite's
  registration)
- `tests/run-all.ps1` (existing, agent-editable)
- `specs/epic-193-a5-capability-resolver/human-copy/.github/workflows/
  test.yml` (new staged candidate, agent-editable — this suite's CI
  steps; R-10 protected real path, human-copy only)
- `specs/epic-193-a5-capability-resolver/human-copy/MANIFEST.sha256`
  (new, agent-editable — SHA-256 entry for the staged `test.yml`
  candidate)
- `CHANGELOG.md` (existing, agent-editable — CREATE the `## Unreleased`
  entry citing #193)

Data Migration: none — new, additive contract document; no prior version
to migrate from.

Breaking API: no; `resolver-evidence.schema.json` is a wholly new
contract file; no existing script's contract changes.

Rollback: revert this task's two commits (B then A, or both). Nothing
protected is touched.

### Goal

Author `contracts/resolver-evidence.schema.json` exactly as design.md's
own API / Contract Plan fixes it (draft-07, `$id` matching every other
`contracts/*.schema.json`'s convention, `additionalProperties: false`
throughout, the sixteen-value `diagnostics[].id` enum in requirements.md
REQ-002's own row order, `conditional_facet_evaluations[].
declaration_index` as a 0-based integer, `matched: false` ⇒ no
`conditional_facet_evaluations` key via `if`/`then`, `outcome: "warn"` ⇒
`reason` required via a nested `if`/`then`) and its own schema-
conformance test suite.

### Must Read

- `specs/epic-193-a5-capability-resolver/requirements.md` (REQ-004,
  Field Definitions "Resolver Evidence")
- `specs/epic-193-a5-capability-resolver/design.md` (`## Data Plan`;
  `### contracts/resolver-evidence.schema.json (REQ-004)`, API / Contract
  Plan — gives the schema document verbatim)
- `specs/epic-193-a5-capability-resolver/acceptance-tests.md` (AC-017,
  AC-018, AC-019, AC-020)
- `specs/epic-193-a5-capability-resolver/investigation.md` (INV-004,
  INV-011, INV-018)
- `contracts/facet-manifest.schema.json`, `contracts/capability-
  summary.schema.json`, `contracts/context-projection.schema.json`
  (Epic A4) — the `$id`/`$schema`/draft-07 convention this new schema
  matches
- `plugins/sdd-quality-loop/scripts/validate-facet-manifest.py` (Epic
  A4's own hand-rolled, stdlib-only draft-07-subset validator pattern
  T-008 will reuse; read here for the schema-document shape it expects)

### Scope

Commit A (implementation — schema + suite + fixtures + CI wiring):
- Write the acceptance checks first (`acceptance-first`, per risk-gate-
  matrix medium tier — author the fixture-level acceptance checks before
  the schema they exercise, no formal Red→Green TDD cycle required):
  TEST-017 (existence + `$id` convention), TEST-018
  (all-Capabilities-recorded, exact-set — as a schema-conformant-vs.-
  malformed fixture pair, not a live-Registry check, which is T-008's own
  scope), TEST-019 (conditional-facet scoping / `if`/`then` branch),
  TEST-020 (always-emit-on-success, `diagnostics: []`).
- Author `contracts/resolver-evidence.schema.json` verbatim per
  design.md's own API / Contract Plan document.
- Register `resolver-evidence-schema` (`.sh`/`.ps1`) in `tests/run-all.
  sh`/`.ps1`; stage the `.github/workflows/test.yml` candidate with this
  suite's CI steps under `human-copy/` + `MANIFEST.sha256`.

Commit B (documentation):
- CREATE the `CHANGELOG.md` `## Unreleased` entry citing #193.

### Done When

- [ ] **Schema existence and convention** — TEST-017 passes: the schema
  file exists, is valid draft-07 (validated once against the official
  metaschema per acceptance-tests.md's own "Draft-07 metaschema
  conformance" record), and its `$id` matches every other
  `contracts/*.schema.json`'s convention (AC-017).
- [ ] **Structural completeness** — TEST-018/TEST-019 pass: a fixture
  pair (schema-conformant vs. each required-field-omission/wrong-type
  negative case) proves the schema's own `required`/`additionalProperties:
  false`/`if`-`then` rules are exactly as design.md fixes them, including
  the `matched: false` ⇒ no `conditional_facet_evaluations` key branch
  and the `outcome: "warn"` ⇒ `reason`-required branch (AC-018, AC-019).
- [ ] **Always-emit-on-success fixture** — TEST-020 passes: a hand-
  authored, fully successful-resolve-shaped instance with
  `diagnostics: []` validates cleanly (AC-020).
- [ ] **Suite/CI registration** — `tests/resolver-evidence-schema.
  tests.sh`/`.ps1` self-register in `tests/run-all.sh`/`.ps1` (grep
  self-check); the staged `.github/workflows/test.yml` candidate exists
  with a correct `MANIFEST.sha256` entry and the LIVE `test.yml` is
  byte-unchanged before/after this task's own commits.
- [ ] **Governance** — `CHANGELOG.md` gains a NEW `## Unreleased` entry
  citing #193 (AC-033 share); a grep self-check confirms no version
  string was mutated outside a `scripts/bump-version.sh` invocation
  (AC-034 share); a `git diff --stat` confirms no path under `plugins/**`
  appears in either of this task's own commits (AC-032, restated as a
  per-task check).
- [ ] **Acceptance evidence** — every fixture written before the schema
  it exercises, failing against a deliberately under-constrained or
  absent schema and passing against the correct schema (`acceptance-
  first`, no formal Red→Green TDD cycle required at `medium` tier). An
  independent quality-gate verdict records PASS.

### Out of Scope

- The Resolver script family itself (T-002/T-003/T-004), `validate-
  resolver-evidence`'s own semantic exact-set/provenance-binding checks
  (T-008, which read and enforce this schema but is a separate component
  with its own closed check-id enum), and every other test suite (T-002
  through T-010).
- Any live-Registry or live-Resolver-invocation fixture — every fixture
  this task authors is a hand-crafted instance validated directly
  against this task's own schema document.

### Blockers

None

---
## T-002 Author `resolve-project-context.{py,sh,ps1}`'s input-validation and Context-normalization stage (steps 0-3)

Source Issue: https://github.com/aharada54914/sdd-forge/issues/193

Approval: Approved (sudo 2026-07-22T18:36:32Z)

Status: Done

Risk: high

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly, not defaulted. `high` is justified: this task authors the
state-derivation Block checks (`disabled-legacy-invocation`,
`workflow-combination-invalid`) and the Project Context/Context
Projection canonicalization every later stage's own union-match (T-003)
and facet-name-aggregation/provenance (T-004) decisions operate on
unconditionally, with no re-validation downstream except the
pre-publication recheck (T-004's own step 13) — design.md's own step 2
"Snapshot (B8)" rule fixes this task's own canonicalized bytes as the
invocation's single, trusted-for-the-rest-of-the-run Project Context
snapshot. A silent defect here (a missed `workflow-combination-invalid`
row, or a canonicalization that silently drops or reorders a field) would
propagate undetected into every downstream Capability-match/facet-
aggregation decision, defeating decision document v2 §19's own "曖昧な
場合は Block" governing rule exactly as the original, undivided engine
task's own Risk Rationale named — this task's own Block conditions are
that rule's first, and only, line of defense before any evaluation work
begins. It is not `critical` because this task's own scope (steps 0-3,
staging only) writes nothing to a live path by itself — T-007 owns the
one step (14) with an irreversible filesystem effect. Required Workflow
is `tdd` per the policy's high-tier row.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-001 (steps 0-3 only — argument validation, state
derivation, Project Context canonicalization, Context Projection
assembly; the CLI required-flag-matrix's own dedicated coverage (AC-001)
is T-006's own, exercised against this task's own already-authored code),
REQ-002 (share — five of sixteen non-transactional diagnostic-id rows:
`disabled-legacy-invocation`, `workflow-combination-invalid`,
`project-context-validation-failed`, `canonicalizer-invocation-failed`,
`dependency-output-malformed` — the latter two are generic, multi-site
rows this task covers at their own first reachable site, per Global
Constraints "Test-suite/CI-registration serialization"), REQ-003 (state
derivation, in full — this task's own entire scope), REQ-005 (share —
determinism baseline: stable canonicalization, no clock/network/
provider-API reads in this task's own code), REQ-006 (share — fixture-
matrix item e's five rows), REQ-008 (share — CHANGELOG)

Depends On: T-001 (no functional need for the schema itself — step 12's
own consumption of it is T-004's own scope — but this task registers the
`resolve-project-context-block` suite, the second entry in the fixed
CI-registration order, appending its own staged CI steps immediately
after T-001's own staged candidate; a direct Blockers entry is required
for that shared-file ordering alone, task-review attempt-2 remedy). **No
re-verified upstream-CLI Assumption beyond Epic A1's `canonicalize-sdd-
yaml`** (this task's own steps 2-3 invoke it as a real subprocess, twice,
per Epic A4's own two-pass procedure; Epic A2/A3's own CLIs are not
invoked until T-003's own steps 4-6) — re-verified at this task's own
start time, not merely inherited from requirements.md (requirements.md
Assumptions; design.md Assumptions): `canonicalize-sdd-yaml` must be
present, landed unmodified from its own `Spec-Review-Status: Passed`
contract, before this task's own fixtures can execute meaningfully; if
absent at this task's own implementation-start time, this task is
blocked pending Epic A1's own landing, per requirements.md Assumptions.

Planned Files:
- `specs/epic-193-a5-capability-resolver/human-copy/plugins/sdd-quality-
  loop/scripts/resolve-project-context.py` (new staged candidate,
  agent-editable — see "Protected Files" above for the live-repository
  branch check; developed unprotected-first at a non-protected location
  before staging; this task authors only steps 0-3 — any input that
  would proceed past step 3 into not-yet-authored step 4 is out of this
  task's own Done When and is never exercised by this task's own
  fixtures, matching the ordinary incremental-authoring state of a
  script family under active, multi-task construction)
- `specs/epic-193-a5-capability-resolver/human-copy/plugins/sdd-quality-
  loop/scripts/resolve-project-context.sh` (new staged candidate —
  thin dispatcher, `python3`/`python` resolution only, no native
  fallback, matching `canonicalize-sdd-yaml`'s own dispatch shape)
- `specs/epic-193-a5-capability-resolver/human-copy/plugins/sdd-quality-
  loop/scripts/resolve-project-context.ps1` (new staged candidate —
  twin)
- `specs/epic-193-a5-capability-resolver/human-copy/MANIFEST.sha256`
  (edited — three new SHA-256 entries for the staged script candidates)
- `tests/resolve-project-context-block.tests.sh` / `.ps1` (new — this
  task creates the file; five fixtures only, see Global Constraints
  "`tests/resolve-project-context-block.tests.sh`/`.ps1` is a single,
  shared suite file spanning four tasks in strict sequence")
- `tests/fixtures/capability-resolver/` (new fixture tree — the five
  Block fixtures this task's own step range makes reachable)
- `tests/run-all.sh` / `.ps1` (existing, agent-editable — this suite's
  registration: `resolve-project-context-block`)
- `specs/epic-193-a5-capability-resolver/human-copy/.github/workflows/
  test.yml` (appended, agent-editable — this task's own one suite's CI
  steps, appended after T-001's own)
- `CHANGELOG.md` (existing, agent-editable — CREATE the `## Unreleased`
  entry citing #193)

Data Migration: none — new, additive CLI; no prior version to migrate
from.

Breaking API: no; `resolve-project-context` is a wholly new script; no
existing script's contract changes (this task never edits `resolve-
component-paths`/`evaluate-predicate`/`generate-registry-digest`/
`canonicalize-sdd-yaml` themselves).

Rollback: revert this task's two commits (B then A, or both). If the
human-copy candidate under `human-copy/` was already applied to the live
protected path by a human `cp`, a revert PR states explicitly whether a
human should also hand-revert that applied content — this task's own
commits never touch the live protected path directly.

### Goal

Author `resolve-project-context.py` (+ `.sh`/`.ps1` wrappers)
implementing API / Contract Plan steps 0 through 3: argument validation
and `--feature` pattern check (exit 2 on failure — implemented here; its
own dedicated required-flag-matrix test suite is T-006's own); state
derivation (REQ-003) — `disabled-legacy-invocation` short-circuit before
any Registry/ownership/Context-Projection work, `workflow-combination-
invalid` check against decision document v2 §6's own combination matrix
(M3), and `project-context-validation-failed` on a schema-invalid but
present Context; Project Context canonicalization via `canonicalize-sdd-
yaml` with its own `canonicalizer-invocation-failed`/`dependency-output-
malformed` Blocks and invocation-start snapshot (B8); Context Projection
assembly (Epic A4's own two-pass-canonicalizer procedure, verbatim,
staged only, never written to a live path). This task stages every
artifact in memory only — it never invokes `resolve-component-paths`,
Registry discovery, or any predicate evaluation (T-003's own scope), and
never performs step 14's own live commit (T-007's own scope).

### Must Read

- `specs/epic-193-a5-capability-resolver/requirements.md` (REQ-001,
  REQ-002 [the five rows above], REQ-003, REQ-005, REQ-006 item e's
  five rows, Dependencies, Edge Cases, Field Definitions)
- `specs/epic-193-a5-capability-resolver/design.md` (`## Architecture`;
  `## Components`; `### resolve-project-context.{py,sh,ps1} CLI contract
  (REQ-001)`, steps 0-3; `## Test Strategy` items 2 (rows this task
  covers) and 3 (context for the fuller pipeline this task's own output
  feeds); `## Global Constraints`; `## Security Boundaries`)
- `specs/epic-193-a5-capability-resolver/acceptance-tests.md` (AC-010
  through AC-015 [this task's own five rows' share], AC-038 [share],
  AC-041 — this task's own dedicated `workflow-combination-invalid`
  matrix; AC-003 is cited for the Context Projection assembly
  *behavior* this task's own code must implement correctly, even though
  its own byte-identity assertion is proven only once the full pipeline
  exists, T-005's own `match`-suite scope)
- `specs/epic-193-a5-capability-resolver/investigation.md` (INV-003,
  INV-006, INV-007, INV-013)
- `specs/epic-193-a5-capability-resolver/security-spec.md`
  (`#trust-boundaries`)
- Epic A1's `canonicalize-sdd-yaml` CLI contract (the one already-fixed
  upstream contract this task's own script invokes verbatim)
- `docs/adr/0016-workflow-axes-separation.md`, `docs/adr/0021-context-
  projection-staleness.md`

### Scope

Commit A (implementation — stage-1 engine + block-suite creation +
five fixtures + CI wiring):
- Write the acceptance checks first (TDD Red→Green): the five block-suite
  fixtures this task's own step range makes reachable —
  `disabled-legacy-invocation` (absent/derives-`disabled-legacy` `--config`
  target), `workflow-combination-invalid` (one fixture per decision
  document v2 §6's own two explicitly-invalid rows, AC-041),
  `project-context-validation-failed` (schema-invalid but present
  Context), `canonicalizer-invocation-failed` (a `canonicalize-sdd-yaml`
  non-zero-exit fixture), `dependency-output-malformed` (a zero-exit,
  unparseable-stdout fixture) — each asserting the correct exit code
  (AC-013), the correct diagnostic line (AC-014, never raw dependency
  stderr, M8), no partial artifact (AC-011 — trivially satisfied here,
  since no artifact is ever staged before any of these five Blocks can
  fire), and correct Resolver Evidence content (AC-012, including
  `disabled-legacy-invocation`'s own minimal-record exception).
- Author `resolve-project-context.py` (steps 0-3) + `.sh`/`.ps1`
  wrappers per the Protected Files branch this task's own start-time
  check selects.
- CI resilience and diagnostic determinism per Global Constraints (UTF-8/
  no-BOM/LF-only; no dependency subprocess's own raw stderr ever
  embedded in a `<detail>` field, M8).
- Create and register `resolve-project-context-block` (`.sh`/`.ps1`) in
  `tests/run-all.sh`/`.ps1`; stage the `.github/workflows/test.yml`
  candidate with this suite's CI steps under `human-copy/`, appending to
  T-001's own staged candidate; update `MANIFEST.sha256` with this
  task's own three staged script entries plus the new `test.yml` entry.

Commit B (documentation):
- CREATE the `CHANGELOG.md` `## Unreleased` entry citing #193.

### Done When

- [ ] **State-derivation and normalization Block matrix (five of
  sixteen rows)** — `disabled-legacy-invocation`,
  `workflow-combination-invalid` (both invalid-combination rows,
  AC-041), `project-context-validation-failed`, `canonicalizer-
  invocation-failed`, `dependency-output-malformed`: correct exit code,
  correct diagnostic line (never raw dependency stderr, M8), no partial
  artifact, correct Resolver Evidence content (AC-010 [five of sixteen
  rows], AC-011 [share], AC-012 [share], AC-013 [share], AC-014
  [share]).
- [ ] **`disabled-legacy` short-circuit lock** — a fixture confirms no
  `resolve-component-paths`/Registry-discovery subprocess is ever
  invoked (a mock/spy harness on the subprocess boundary — trivially
  true at this task's own completion, since this task's own code never
  calls either) before the `disabled-legacy-invocation` Block fires
  (AC-015).
- [ ] **Fixture + suite/CI registration** — `tests/resolve-project-
  context-block.tests.sh`/`.ps1` self-registers in `tests/run-all.sh`/
  `.ps1` (grep self-check); the staged `.github/workflows/test.yml`
  candidate carries this task's own one suite's steps appended after
  T-001's, with correct `MANIFEST.sha256` entries; the LIVE `test.yml`
  is byte-unchanged before/after this task's own commits.
- [ ] **Governance** — `CHANGELOG.md` gains a NEW `## Unreleased` entry
  citing #193 (AC-033 share); no version string mutated outside
  `scripts/bump-version.sh` (AC-034 share); `git diff --stat` confirms no
  path under `plugins/**` appears in either of this task's own commits
  (AC-032).
- [ ] **TDD evidence** — RED (each of the five fixtures against a
  deliberately broken or absent steps-0-3 implementation) and GREEN (the
  full five-fixture set against the correct implementation). An
  independent quality-gate verdict records PASS.

### Out of Scope

- Steps 4-13 of the evaluation engine (`resolve-component-paths`
  invocation, Registry discovery, `registry_digest`, trigger/
  conditional-facet evaluation, the WARN check, the track branch,
  Resolver Evidence assembly, output schema self-validation, the
  pre-publication recheck — T-003's and T-004's own scope).
- The eleven remaining non-transactional Block-diagnostic fixtures
  (`affected-component-resolution-failed` through the second
  `snapshot-generation-mismatch` fixture — T-003's and T-004's own
  contributions to this same shared suite file) and the four
  transactional-diagnostic fixtures (T-007's own).
- The `resolve-project-context-match` suite (T-005's own), the CLI
  required-flag-matrix suite (AC-001, TEST-001), the discovery-contract-
  reuse suite (AC-002/AC-028, TEST-002/TEST-028), and the Lite-track
  suite (AC-009, TEST-009) — this task implements none of the code those
  exercise; their own dedicated test suites are T-006's own.
- Step 0's own crash-recovery scan and step 14's own journaled
  publication transaction/commit (T-007's own scope).
- `validate-resolver-evidence` (T-008), the dual-runtime parity suite
  (T-009), and the metamorphic completeness suite (T-010).
- `contracts/resolver-evidence.schema.json` itself (T-001's own
  deliverable — this task does not yet consume it; consumption begins at
  T-004's own step 12).
- Any edit to `plugins/**`, including `sdd-bootstrap-interviewer/
  SKILL.md` — REQ-007's target integration contract remains
  design-only (Non-goals; see "Deferred, Not Scheduled", Global
  Constraints).

### Blockers
T-001

---
## T-003 Author `resolve-project-context.{py,sh,ps1}`'s Registry-discovery and Capability-evaluation stage (steps 4-9)

Source Issue: https://github.com/aharada54914/sdd-forge/issues/193

Approval: Approved (sudo 2026-08-08T16:04:17Z)

Status: Implementation Complete

Risk: high

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly, not defaulted. `high` is justified: this task directly
implements the multi-affected-component union-match rule (step 7) and
the any-branch WARN-Block scope (step 9) — design.md ADR Change Log
items 1 and 3, the two of this feature's own six new orchestration
decisions with no upstream contract fixing them, and the same decision-
document-v2-§19 "曖昧な場合は Block" governing rule the original,
undivided engine task's own Risk Rationale named. A silent
misclassification here (an under-matched Capability, or a WARN-producing
branch that silently collapses to a clean `false`/`applied: false`
outcome) defeats that governing rule exactly as adversarial review "B2
WARN" already found once in an earlier design revision (design.md API /
Contract Plan step 9) — this is the single stage in the whole pipeline
where the match/WARN decision is actually *computed*; T-004's own
track-branch/facet-aggregation stage only consumes this task's already-
computed `capability_evaluations[]`, it does not itself decide match or
WARN. It is not `critical` because this task's own scope (steps 4-9,
staging only) writes nothing to a live path by itself — T-007 owns the
one step (14) with an irreversible filesystem effect. Required Workflow
is `tdd` per the policy's high-tier row.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-001 (steps 4-9 only — `resolve-component-paths`
invocation, Registry discovery via ADR-0025, `registry_digest --whole`,
per-Capability/per-component trigger evaluation, matched-Capability
conditional-facet evaluation, the any-branch WARN check; the discovery-
contract-reuse suite's own dedicated coverage (AC-002/AC-028) is T-006's
own, exercised against this task's own already-authored code), REQ-002
(share — five more of sixteen non-transactional diagnostic-id rows:
`affected-component-resolution-failed`, `registry-validation-failed`,
`contract-discovery-failed`, `dependency-subprocess-failed`,
`dsl-warn-on-matched-capability`), REQ-004 (share — the per-Capability/
per-component evaluation records this task assembles are Resolver
Evidence's own `capability_evaluations[].trigger_evaluations[]`/
`conditional_facet_evaluations[]` content; final assembly into a written
Evidence structure is T-004's own), REQ-005 (share — determinism
baseline: ascending-lexicographic per-component fan-out, no short-
circuit, no clock/network/provider-API reads in this task's own code),
REQ-006 (share — fixture-matrix item e's five rows), REQ-008 (share —
CHANGELOG)

Depends On: T-002 (this task's own steps 4-9 execute only after step
0-3's own state derivation and Context Projection assembly have already
succeeded; this task's own code is appended directly onto T-002's own
staged script, and this task's own block-suite fixtures are appended
directly onto T-002's own `tests/resolve-project-context-block.tests.sh`/
`.ps1` file — a single Blockers entry serves both the functional and the
shared-file-ordering purpose, since T-002 is both the immediately
preceding engine stage and the immediately preceding contributor to this
same suite file). **Assumption re-verified at this task's own start
time, not merely inherited from requirements.md** (requirements.md
Assumptions; design.md Assumptions): Epic A2's `evaluate-predicate`/
`generate-registry-digest`/ADR-0025 discovery and Epic A3's `resolve-
component-paths` must each be present, landed unmodified from their own
`Spec-Review-Status: Passed` contracts, in this repository before this
task's own fixtures can execute meaningfully (this task's own script
invokes them as real subprocesses, not mocked stand-ins, matching this
Epic set's own established integration-test convention) — if either is
absent at this task's own implementation-start time, this task is
blocked pending that sibling epic's own landing, per requirements.md
Assumptions.

Planned Files:
- `specs/epic-193-a5-capability-resolver/human-copy/plugins/sdd-quality-
  loop/scripts/resolve-project-context.py` (updated staged candidate —
  adds steps 4-9 onto T-002's own steps 0-3; re-verify this path's own
  then-current protection status per "Protected Files" above, since
  T-002's own human-copy candidate may or may not already reflect a
  landed Epic A1 registration by this task's own start time)
- `specs/epic-193-a5-capability-resolver/human-copy/plugins/sdd-quality-
  loop/scripts/resolve-project-context.sh` / `.ps1` (updated staged
  candidates — twins)
- `specs/epic-193-a5-capability-resolver/human-copy/MANIFEST.sha256`
  (edited — updated SHA-256 entries for the three updated staged
  candidates)
- `tests/resolve-project-context-block.tests.sh` / `.ps1` (edited —
  appends five fixtures to T-002's own file; no new suite registration)
- `tests/fixtures/capability-resolver/` (extended — the five Block
  fixtures this task's own step range makes reachable)
- `CHANGELOG.md` (existing, agent-editable — CREATE the `## Unreleased`
  entry citing #193)

Data Migration: none.

Breaking API: no; this task only extends `resolve-project-context`'s own
internal evaluation logic, adding no new CLI flag and changing no
already-fixed output shape.

Rollback: revert this task's two commits (B then A, or both). If this
task's own updated human-copy candidate was already applied to the live
protected path, a revert PR states explicitly whether a human should
also hand-revert that applied content back to T-002's own prior version.

### Goal

Extend `resolve-project-context.py` (+ `.sh`/`.ps1` wrappers) with API /
Contract Plan steps 4 through 9, onto T-002's own steps 0-3:
`resolve-component-paths` invocation (`affected-component-resolution-
failed` on non-zero exit, its own canonical `<detail>` sentence never the
upstream's raw stderr, M8) with its own snapshot (B8); Registry discovery
via ADR-0025 (`contract-discovery-failed`, `registry-validation-failed`,
implemented here — its own dedicated discovery-contract-reuse test suite
is T-006's own) and `registry_digest --whole`; per-Capability,
per-affected-component trigger evaluation and matched-Capability
conditional-facet evaluation, both with no short-circuit
(`dependency-subprocess-failed`/`dependency-output-malformed` — the
latter already covered by T-002's own fixture, one fixture per row, no
duplication — on any dependency subprocess failure); the any-branch WARN
check (`dsl-warn-on-matched-capability`, B2's widened scope, across
every evaluation from both this task's own steps). This task stages
every evaluation result in this invocation's own in-memory evaluation
set only — it never assembles the track-branch output or Resolver
Evidence itself (T-004's own scope), and never performs step 14's own
live commit (T-007's own scope).

### Must Read

- `specs/epic-193-a5-capability-resolver/requirements.md` (REQ-001,
  REQ-002 [the five rows above], REQ-004 share, REQ-005, REQ-006 item e's
  five rows, Dependencies, Edge Cases, Field Definitions, Main Workflows
  1-4)
- `specs/epic-193-a5-capability-resolver/design.md` (`### resolve-
  project-context.{py,sh,ps1} CLI contract (REQ-001)`, steps 4-9; `##
  Design Decisions` — union-match, any-branch WARN scope; `## ADR Change
  Log` items 1 and 3; `## Discovery contract`; `## Test Strategy` items
  2 (rows this task covers) and 3; `## Global Constraints`; `## Security
  Boundaries`)
- `specs/epic-193-a5-capability-resolver/acceptance-tests.md` (AC-010
  through AC-015 [this task's own five rows' share], AC-038 [share] —
  this task's own dedicated Block-fixture coverage; AC-004 through
  AC-006 are cited for the trigger/conditional-facet-evaluation
  *behavior* this task's own code must implement correctly, even though
  their own byte-identity/union-match assertions are proven only once
  the full pipeline exists, T-005's own `match`-suite scope)
- `specs/epic-193-a5-capability-resolver/investigation.md` (INV-005
  through INV-013, INV-020)
- `specs/epic-193-a5-capability-resolver/security-spec.md`
  (`#trust-boundaries`)
- Epic A2's `evaluate-predicate`/`generate-registry-digest`/ADR-0025
  discovery contract, and Epic A3's `resolve-component-paths` CLI
  contract (the already-fixed upstream contracts this task's own script
  invokes verbatim)
- `docs/adr/0020-conditional-predicate-dsl.md`

### Scope

Commit A (implementation — stage-2 engine + five block-suite fixtures):
- Write the acceptance checks first (TDD Red→Green): five block-suite
  fixtures — `affected-component-resolution-failed` (a `resolve-
  component-paths` non-zero-exit fixture, asserting the canonical
  `<detail>` sentence, never raw upstream stderr, M8), `registry-
  validation-failed`, `contract-discovery-failed` (Registry/schema
  resolution or `validate-capability-registry` failures), `dependency-
  subprocess-failed` (a generic `evaluate-predicate`/`generate-registry-
  digest` non-zero-exit fixture), `dsl-warn-on-matched-capability` (one
  fixture per B2's widened quantifier: a WARN on an unmatched
  Capability's own trigger, and a WARN on a matched Capability's own
  non-determining branch) — each asserting the correct exit code
  (AC-013), the correct diagnostic line (AC-014, M8), no partial
  artifact (AC-011 — trivially satisfied, since T-002/T-003's own
  combined scope never stages a live-path artifact), and correct
  Resolver Evidence content (AC-012), including every evaluation this
  invocation already performed through step 8 for the `dsl-warn-on-
  matched-capability` fixtures specifically (the record is maximally
  informative for the caller diagnosing it, per design.md step 9).
- Extend `resolve-project-context.py`'s own steps 4-9 per the Protected
  Files branch T-002's own start-time check already selected.
- CI resilience and diagnostic determinism per Global Constraints,
  applied to this task's own new code paths.
- Append this task's own five fixtures to `tests/resolve-project-
  context-block.tests.sh`/`.ps1` (already registered by T-002) — no new
  suite registration, no edit to `tests/run-all.*` or the staged
  `test.yml` candidate.

Commit B (documentation):
- CREATE the `CHANGELOG.md` `## Unreleased` entry citing #193.

### Done When

- [ ] **Registry-discovery and Capability-evaluation Block matrix (five
  more of sixteen rows, ten of sixteen complete)** —
  `affected-component-resolution-failed`, `registry-validation-failed`,
  `contract-discovery-failed`, `dependency-subprocess-failed`,
  `dsl-warn-on-matched-capability` (both B2-widened fixtures): correct
  exit code, correct diagnostic line (never raw dependency stderr, M8),
  no partial artifact, correct Resolver Evidence content (AC-010 [five
  more of sixteen rows, ten complete], AC-011 [share], AC-012 [share],
  AC-013 [share], AC-014 [share]).
- [ ] **Fixture registration (append-only)** — `tests/resolve-project-
  context-block.tests.sh`/`.ps1` gains this task's own five new fixtures
  without modifying any of T-002's own five; `tests/run-all.*` and the
  staged `test.yml` candidate are byte-unchanged by this task (no new
  suite registered).
- [ ] **Governance** — `CHANGELOG.md` gains a NEW `## Unreleased` entry
  citing #193 (AC-033 share); no version string mutated outside
  `scripts/bump-version.sh` (AC-034 share); `git diff --stat` confirms no
  path under `plugins/**` in either of this task's own commits (AC-032).
- [ ] **TDD evidence** — RED (each of the five fixtures against a
  deliberately broken or absent steps-4-9 implementation) and GREEN (all
  ten block-suite fixtures — T-002's own five plus this task's own five —
  together). An independent quality-gate verdict records PASS.

### Out of Scope

- Steps 0-3 (T-002's own scope, already authored) and steps 10-13 (the
  track branch, Resolver Evidence assembly, output schema
  self-validation, the pre-publication recheck — T-004's own scope).
- The remaining three non-transactional Block-diagnostic fixtures
  (`lite-check-source-undefined`, `output-schema-validation-failed`, the
  first `snapshot-generation-mismatch` fixture — T-004's own) and the
  four transactional-diagnostic fixtures (T-007's own).
- The `resolve-project-context-match` suite (T-005's own), the CLI
  required-flag-matrix suite, the discovery-contract-reuse suite, and
  the Lite-track suite (T-006's own).
- Step 0's own crash-recovery scan and step 14's own journaled
  publication transaction/commit (T-007's own scope).
- `validate-resolver-evidence` (T-008), the dual-runtime parity suite
  (T-009), and the metamorphic completeness suite (T-010).
- Any edit to `plugins/**`.

### Blockers

T-002

---
## T-004 Author `resolve-project-context.{py,sh,ps1}`'s track-branch and Evidence-assembly stage (steps 10-13)

Source Issue: https://github.com/aharada54914/sdd-forge/issues/193

Approval: Approved (sudo 2026-08-08T16:04:17Z)

Status: Implementation Complete

Risk: high

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly, not defaulted. `high` is justified: this task implements the
cross-Capability facet-name aggregation rule (step 10a, design.md ADR
Change Log item 2), the track-exclusive publication-set rule (step 10,
item 5), the `dependency_pointers[]`/`resolver.version`/`rule_set_
revision` provenance-canonicalization rule (step 11, item 6), and the
pre-publication snapshot recheck (step 13, item 4's own recheck half) —
four of this feature's own six new orchestration decisions with no
upstream contract fixing them. Every downstream Gate-chain caller's own
trust in a resolve's completeness rests on this task's own aggregation/
assembly logic being correct, and this task's own output-schema
self-validation (step 12) and pre-publication recheck (step 13) are this
feature's own last chance to catch a staged-generation defect before
T-007's own transaction ever commits it to a live path — a silent
aggregation defect (an under-counted facet contribution) or an
un-caught TOCTOU race (a stale snapshot published past its own recheck
window) is exactly the "silent defect causes material harm" surface the
policy's high tier names, and both B7 (facet-name aggregation) and B8
(the recheck's own set-comparison requirement) are adversarial-review
corrections to an earlier revision that got this task's own logic wrong.
It is not `critical` because this task's own scope (steps 10-13, staging
only) writes nothing to a live path by itself — T-007 owns the one step
(14) with an irreversible filesystem effect. Required Workflow is `tdd`
per the policy's high-tier row.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-001 (steps 10-13 only — the track branch, Resolver
Evidence assembly, output schema self-validation, the pre-publication
snapshot recheck; the Lite-track suite's own dedicated coverage (AC-009)
is T-006's own, exercised against this task's own already-authored code;
the full-pipeline `match`-suite coverage — AC-003 through AC-008, AC-016,
AC-043, AC-044, AC-052, AC-056 — is T-005's own, split out of this task
by task-review attempt-2 round-1's own second remedy, closing a
TASK-SIZE finding), REQ-002 (share — three more of sixteen non-
transactional diagnostic-id rows: `lite-check-source-undefined`,
`output-schema-validation-failed`, and the first, digest-mismatch
`snapshot-generation-mismatch` fixture — its own second, `affected_
components`-only companion fixture is T-007's own), REQ-004 (share —
Resolver Evidence assembly logic in full; schema is T-001's own), REQ-005
(share — determinism baseline: stable sort of every semantic-output
array, no clock/network/provider-API reads in this task's own code),
REQ-006 (share — fixture-matrix item e's own remaining three rows; items
a-d/f/g, the `match`-suite's own fixture-matrix items, are T-005's own),
REQ-008 (share — CHANGELOG)

Depends On: T-001 (this task's own step 12, output schema
self-validation, validates the staged Resolver Evidence instance against
T-001's own schema before this task's own Done When can be satisfied),
T-003 (this task's own steps 10-13 consume T-002/T-003's own
already-computed `capability_evaluations[]` in memory, and this task's
own block-suite fixtures are appended directly onto T-003's own
contribution to `tests/resolve-project-context-block.tests.sh`/`.ps1` —
a single Blockers entry on T-003 serves both the functional and the
shared-file-ordering purpose, since T-003 is the immediately preceding
engine stage and the immediately preceding contributor to this same
suite file; T-002's own contribution is reached only transitively via
T-003, which is sufficient here since — unlike the match-suite task,
T-005, below — this task no longer touches the CI-registration file at
all, so no direct-edge-for-shared-file-ordering exception applies).
**Assumption re-verified at this task's own start time**, carried
forward unchanged from T-002/T-003 (requirements.md Assumptions;
design.md Assumptions): Epic A1/A2/A3's already-`Spec-Review-Status:
Passed` CLIs must remain present, landed unmodified, in this repository
for this task's own block-suite fixtures to execute meaningfully (this
task's own fixtures invoke the assembled `resolve-project-context` as a
real subprocess, not a mocked stand-in, matching this Epic set's own
established integration-test convention).

Planned Files:
- `specs/epic-193-a5-capability-resolver/human-copy/plugins/sdd-quality-
  loop/scripts/resolve-project-context.py` (updated staged candidate —
  adds steps 10-13 onto T-002/T-003's own steps 0-9, completing the
  staged-only evaluation pipeline; re-verify this path's own
  then-current protection status per "Protected Files" above)
- `specs/epic-193-a5-capability-resolver/human-copy/plugins/sdd-quality-
  loop/scripts/resolve-project-context.sh` / `.ps1` (updated staged
  candidates — twins)
- `specs/epic-193-a5-capability-resolver/human-copy/MANIFEST.sha256`
  (edited — updated SHA-256 entries for the three updated staged
  candidates)
- `tests/resolve-project-context-block.tests.sh` / `.ps1` (edited —
  appends three fixtures to T-002/T-003's own file; no new suite
  registration for this file)
- `tests/fixtures/capability-resolver/` (extended — the three additional
  Block fixtures this task's own step range makes reachable)
- `CHANGELOG.md` (existing, agent-editable — CREATE the `## Unreleased`
  entry citing #193)

Data Migration: none — new, additive CLI; no prior version to migrate
from.

Breaking API: no; `resolve-project-context` is a wholly new script; no
existing script's contract changes (this task never edits `resolve-
component-paths`/`evaluate-predicate`/`generate-registry-digest`/
`canonicalize-sdd-yaml` themselves).

Rollback: revert this task's two commits (B then A, or both). If the
human-copy candidate under `human-copy/` was already applied to the live
protected path by a human `cp`, a revert PR states explicitly whether a
human should also hand-revert that applied content — this task's own
commits never touch the live protected path directly.

### Goal

Complete `resolve-project-context.py` (+ `.sh`/`.ps1` wrappers) by
implementing API / Contract Plan steps 10 through 13, onto T-002/T-003's
own steps 0-9: the track branch (before any publication, B4) staging a
Facet Manifest (`full` — cross-Capability facet-name aggregation, B7) or
a Capability Summary (`lite`, subject to `lite-check-source-undefined`,
narrowed per the cross-epic B5 addendum, implemented here — its own
dedicated Lite-track test suite is T-006's own); Resolver Evidence
assembly (every capability, every diagnostic, canonical `dependency_
pointers[]`/`resolver.version`/`resolver.rule_set_revision`, B9); output
schema self-validation against every staged artifact's own governing
schema (`output-schema-validation-failed`, with the self-referential
Evidence-fails-its-own-check exception writing nothing, B3); and the
pre-publication snapshot recheck (`snapshot-generation-mismatch`,
re-deriving `affected_components` as well as re-hashing every snapshot,
B8). This task stages every artifact in memory only — it never performs
step 14's own live commit (T-007's own scope). Once steps 0-13 are all
present for the first time across T-002/T-003/T-004 combined, this
task's own already-authored code is what T-005's own `match` suite
exercises end-to-end — authoring that suite is T-005's own scope, not
this task's (task-review attempt-2 round-1's own second remedy: an
earlier revision of this task also authored the `match` suite itself,
which reviewer-b's own TASK-SIZE check found materially oversized
relative to every sibling task; this task's own scope is now limited to
its own production code and its own three block-suite fixtures).

### Must Read

- `specs/epic-193-a5-capability-resolver/requirements.md` (REQ-001,
  REQ-002 [the three rows above], REQ-004, REQ-005, REQ-006 item e's
  remaining three rows, Dependencies, Edge Cases, Field Definitions,
  Main Workflows 1-4)
- `specs/epic-193-a5-capability-resolver/design.md` (`## Architecture`;
  `## Components`; `### resolve-project-context.{py,sh,ps1} CLI contract
  (REQ-001)`, steps 10-13; `## Design Decisions` — facet-name
  aggregation, track-exclusive publication set, provenance
  canonicalization; `## ADR Change Log` items 2, 4, 5, 6; `## Test
  Strategy` item 2 (rows this task covers); `## Global Constraints`;
  `## Security Boundaries`)
- `specs/epic-193-a5-capability-resolver/acceptance-tests.md` (AC-010
  through AC-015, AC-038, AC-040 [first fixture], AC-041 [share], AC-048
  are cited for the diagnostic *behavior* this task's own code must
  implement correctly for the three rows below; AC-003 through AC-008,
  AC-016, AC-043, AC-044, AC-052, AC-056 name the full-pipeline
  *behavior* this task's own production code must implement correctly,
  even though their own dedicated test suite, `match`, is T-005's own)
- `specs/epic-193-a5-capability-resolver/investigation.md` (INV-003,
  INV-005 through INV-013, INV-019, INV-020)
- `specs/epic-193-a5-capability-resolver/security-spec.md`
  (`#trust-boundaries`)
- Epic A4's own `validate-facet-manifest`/`validate-capability-summary`/
  `validate-context-projection` (the three already-fixed downstream
  schemas step 12 validates staged artifacts against)
- `docs/adr/0021-context-projection-staleness.md`

### Scope

Commit A (implementation — stage-3 engine + three block-suite fixtures):
- Write the acceptance checks first (TDD Red→Green): three more
  block-suite fixtures — `lite-check-source-undefined` (the
  B5-narrowed required-missing state), `output-schema-validation-failed`
  (both sub-cases, AC-055: Resolver Evidence itself fails, and a
  non-Evidence staged artifact fails), the first, digest-mismatch
  `snapshot-generation-mismatch` fixture (AC-040 share).
- Author `resolve-project-context.py`'s own steps 10-13 per the
  Protected Files branch T-002's own start-time check already selected —
  including the full production logic (union-match consumption, track
  branch, facet-name aggregation, Evidence assembly, output schema
  self-validation, pre-publication recheck) that T-005's own downstream
  `match` suite will exercise, even though this task's own Done When
  below does not itself require that suite passing.
- CI resilience and diagnostic determinism per Global Constraints,
  applied to this task's own new code paths.
- Append this task's own three fixtures to `tests/resolve-project-
  context-block.tests.sh`/`.ps1` (already registered by T-002; extended
  by T-003) — no new registration; no edit to `tests/run-all.*` or the
  staged `test.yml` candidate (this task registers no new suite).

Commit B (documentation):
- CREATE the `CHANGELOG.md` `## Unreleased` entry citing #193.

### Done When

- [ ] **Track-branch and Evidence-assembly Block matrix (three more of
  sixteen rows, thirteen of sixteen complete)** — `lite-check-source-
  undefined`, `output-schema-validation-failed` (both sub-cases,
  AC-055), first `snapshot-generation-mismatch` fixture (AC-040 share):
  correct exit code, correct diagnostic line, no partial artifact (AC-038
  — the staged-generation lock specifically proven for these three, each
  reached only after Context Projection and/or Facet Manifest/Capability
  Summary is already staged in memory), correct Resolver Evidence
  content (AC-010 [three more of sixteen rows, thirteen complete],
  AC-011 [share], AC-012 [share], AC-013 [share], AC-014 [share]).
- [ ] **Fixture registration (append-only)** — the block-suite's own
  three new fixtures append cleanly onto T-002/T-003's own ten without
  modifying them; `tests/run-all.*` and the staged `test.yml` candidate
  are byte-unchanged by this task (no new suite registered — this task
  never touches the CI-registration file).
- [ ] **Governance** — `CHANGELOG.md` gains a NEW `## Unreleased` entry
  citing #193 (AC-033 share); no version string mutated outside
  `scripts/bump-version.sh` (AC-034 share); `git diff --stat` confirms no
  path under `plugins/**` in either of this task's own commits (AC-032).
- [ ] **TDD evidence** — RED (each of the three block-suite fixtures
  against a deliberately broken or absent steps-10-13 implementation)
  and GREEN (all thirteen block-suite fixtures — T-002's own five,
  T-003's own five, and this task's own three — together). An
  independent quality-gate verdict records PASS.

### Out of Scope

- Steps 0-9 (T-002's and T-003's own scope, already authored).
- The thirteen non-transactional Block-diagnostic fixtures T-002/T-003
  already own (`disabled-legacy-invocation` through `dsl-warn-on-
  matched-capability`) and the four transactional-diagnostic fixtures
  (T-007's own).
- The `resolve-project-context-match` suite (TEST-003 through TEST-008,
  TEST-016, TEST-043, TEST-044, TEST-052, TEST-056 — T-005's own scope,
  split out of this task by task-review attempt-2 round-1's own second
  remedy) — this task authors the production code that suite exercises
  but does not itself author, register, or land the suite.
- The CLI required-flag-matrix suite (AC-001, TEST-001), the discovery-
  contract-reuse suite (AC-002/AC-028, TEST-002/TEST-028), and the
  Lite-track suite (AC-009, TEST-009) — this task implements the code
  each of these exercises (argument validation is T-002's own; ADR-0025
  discovery is T-003's own; Lite-track staging is this task's own), but
  their own dedicated test suites are T-006's own.
- Step 0's own crash-recovery scan and step 14's own journaled
  publication transaction/commit (T-007's own scope) — this task's
  script stages every artifact in memory only and never performs a live
  filesystem rename of any of them.
- `publication-journal-recovery`, `artifact-publication-failed`, and
  `post-publication-generation-mismatch` (T-007's own three diagnostic
  rows), and the second, `affected_components`-only `snapshot-
  generation-mismatch` fixture (T-007's own).
- `validate-resolver-evidence` (T-008), the dual-runtime parity suite
  (T-009), and the metamorphic completeness suite (T-010).
- `contracts/resolver-evidence.schema.json` itself (T-001's own
  deliverable — this task only consumes it at step 12).
- Any edit to `plugins/**`, including `sdd-bootstrap-interviewer/
  SKILL.md` — REQ-007's target integration contract remains
  design-only (Non-goals; see "Deferred, Not Scheduled", Global
  Constraints).

### Blockers

T-001, T-003

---
## T-005 Author `resolve-project-context`'s full-pipeline match/no-match/conditional/WARN suite

Source Issue: https://github.com/aharada54914/sdd-forge/issues/193

Approval: Approved (sudo 2026-08-08T16:04:17Z)

Status: Planned

Risk: medium

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. `medium`: this task adds no new production code path of its
own — it exercises T-002/T-003/T-004's own already-built core engine
end-to-end (the union-match rule, the facet-name aggregation rule, the
any-branch WARN scope, provenance canonicalization), all of which T-004's
own Risk: high production code already implements — a defect here is a
false-negative test-coverage gap (one of REQ-006's own fixture-matrix
items a-d/f/g going unverified), not itself a source of production-time
silent misclassification, matching this document's own established
"test-only task" rationale for T-006/T-008/T-009 (cli/discovery/lite,
parity, metamorphic). Not `low`: this suite proves decision document
v2 §19's own governing "曖昧な場合は Block" rule for the full evaluation
pipeline's own match/WARN/aggregation behavior in combination — a gap
here would let a regression in T-002/T-003/T-004's own combined logic
ship silently unverified, exactly the surface those tasks' own `high`
classification names as consequential. Required Workflow is
`acceptance-first` per the risk-gate-matrix's own medium-tier row (`tdd`
is reserved for high/critical).

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-001 (share — AC-003 through AC-008, AC-016, AC-043,
AC-044, AC-052, AC-056: the full-pipeline correctness/byte-identity/
aggregation/provenance test surface, split out of T-004 by task-review
attempt-2 round-1's own second remedy, closing a TASK-SIZE finding —
T-004's own title previously joined its production code with this
suite under one "and"-connected title, materially larger than every
sibling task), REQ-004 (share — this suite's own field-assembly/
schema-conformance/provenance assertions exercise T-004's already-
authored Evidence-assembly logic; the schema itself is T-001's own),
REQ-005 (share — byte-identity/aggregation locks: TEST-016, TEST-043,
TEST-044, TEST-052, TEST-056), REQ-006 (share — fixture-matrix items
a-d, f, g), REQ-008 (share — CHANGELOG)

Depends On: T-002 (this task registers the new `resolve-project-context-
match` suite, whose own staged CI steps append directly after T-002's
own staged candidate in the fixed CI-registration order — neither T-003
nor T-004 touches that shared file, so a direct Blockers entry on T-002
is required in addition to T-004, closing the exact class of gap
round-3's DEPENDENCY-OVERLAP finding named and this round's own
reviewer-b-suggested remedy applies identically), T-004 (needs the
complete, schema-self-validated evaluation engine — steps 0-13 in full —
to run this suite's own full-pipeline subprocess fixtures meaningfully;
T-004's own step 12 output-schema self-validation is itself this task's
own precondition for a real staged instance to exist at all). **Assumption
re-verified at this task's own start time**, carried forward unchanged
from T-002/T-003/T-004 (requirements.md Assumptions; design.md
Assumptions): Epic A1/A2/A3's already-`Spec-Review-Status: Passed` CLIs
must remain present, landed unmodified, in this repository for this
task's own suite to execute meaningfully (this task's own fixtures
invoke the assembled `resolve-project-context` as a real subprocess, not
a mocked stand-in, matching this Epic set's own established
integration-test convention).

Planned Files:
- `tests/resolve-project-context-match.tests.sh` / `.ps1` (new)
- `tests/fixtures/capability-resolver/` (extended — match fixtures;
  design.md Test Strategy item 3)
- `tests/run-all.sh` / `.ps1` (existing, agent-editable — this suite's
  registration: `match`)
- `specs/epic-193-a5-capability-resolver/human-copy/.github/workflows/
  test.yml` (appended, agent-editable — this task's own one suite's CI
  steps, appended after T-002's own)
- `specs/epic-193-a5-capability-resolver/human-copy/MANIFEST.sha256`
  (edited — appended entry for the `test.yml` candidate update)
- `CHANGELOG.md` (existing, agent-editable — CREATE the `## Unreleased`
  entry citing #193)

Data Migration: none.

Breaking API: no; this task adds only test files and fixtures — it never
edits `resolve-project-context.{py,sh,ps1}` itself.

Rollback: revert this task's two commits (B then A, or both). Nothing
protected is touched (this task never edits the human-copy script
candidates T-002/T-003/T-004 already staged).

### Goal

Author `resolve-project-context-match` (design.md Test Strategy item 3),
the full match/no-match/conditional/WARN fixture matrix exercising
T-002/T-003/T-004's own already-authored, complete evaluation pipeline
(steps 0-13): Context Projection byte-identity (AC-003); `resolve-
component-paths` pass-through (AC-004); `registry_digest --whole`
binding (AC-005); union-match (AC-006); field-assembly conformance
(AC-007); Facet Manifest schema-conformance (AC-008); advisory/required
byte-identity excluding the `lite-check-source-undefined` divergent
branch (AC-016); cross-Capability facet-name aggregation (AC-043);
provenance canonicalization — `dependency_pointers[]`/`resolver.version`/
`resolver.rule_set_revision` (AC-044); same-Capability duplicate-facet
predicate-instance keying (AC-052); `diagnostics[]` warn/block
cardinality (AC-056). This task never edits the engine itself — it is a
test-only task exercising the engine T-002/T-003/T-004 already built,
via real subprocess invocations matching this Epic set's own established
integration-test convention.

### Must Read

- `specs/epic-193-a5-capability-resolver/requirements.md` (REQ-001,
  REQ-004 share, REQ-005 share, REQ-006 items a-d/f/g, Main Workflows
  1-4)
- `specs/epic-193-a5-capability-resolver/design.md` (`## Design
  Decisions` — union-match, facet-name aggregation, provenance
  canonicalization; `## ADR Change Log` items 1, 2, 6; `## Test
  Strategy` item 3 in full)
- `specs/epic-193-a5-capability-resolver/acceptance-tests.md` (AC-003
  through AC-008, AC-016, AC-043, AC-044, AC-052, AC-056)
- `specs/epic-193-a5-capability-resolver/investigation.md` (INV-003,
  INV-005 through INV-013, INV-020)
- Epic A4's own `validate-facet-manifest` (the already-fixed downstream
  schema this suite's own Facet Manifest fixtures validate against)

### Scope

Commit A (implementation — suite creation + fixture tree + CI wiring):
- Write the acceptance checks first (`acceptance-first`, per risk-gate-
  matrix medium tier): TEST-003 (Context Projection byte-identity),
  TEST-004 (`resolve-component-paths` pass-through), TEST-005
  (`registry_digest --whole` binding), TEST-006 (union-match), TEST-007
  (field-assembly conformance), TEST-008 (Facet Manifest schema-
  conformance), TEST-016 (advisory/required byte-identity, excluding the
  `lite-check-source-undefined` divergent branch), TEST-043
  (cross-Capability facet-name aggregation), TEST-044 (provenance
  canonicalization), TEST-052 (same-Capability duplicate-facet
  predicate-instance), TEST-056 (`diagnostics[]` warn/block
  cardinality).
- Create and register `resolve-project-context-match` (`.sh`/`.ps1`) in
  `tests/run-all.sh`/`.ps1`; stage the `.github/workflows/test.yml`
  candidate with this new suite's CI steps under `human-copy/`,
  appending to T-002's own staged candidate (the immediately preceding
  registering task in the fixed CI order); update `MANIFEST.sha256` with
  the appended `test.yml` entry.

Commit B (documentation):
- CREATE the `CHANGELOG.md` `## Unreleased` entry citing #193.

### Done When

- [ ] **Pipeline correctness** — TEST-003..TEST-008 pass: Context
  Projection byte-identity (AC-003), `resolve-component-paths`
  pass-through (AC-004), `registry_digest --whole` binding (AC-005),
  union-match (AC-006), field-assembly conformance (AC-007), Facet
  Manifest schema-conformance (AC-008).
- [ ] **Byte-identity / aggregation / provenance locks** — TEST-016
  (advisory/required, excluding the B5-divergent branch), TEST-043
  (cross-Capability facet-name aggregation), TEST-044 (provenance
  canonicalization), TEST-052 (same-Capability duplicate-facet), TEST-056
  (`diagnostics[]` warn/block cardinality) each pass (AC-016, AC-043,
  AC-044, AC-052, AC-056).
- [ ] **Fixture + suite/CI registration** — `tests/resolve-project-
  context-match.tests.sh`/`.ps1` self-registers in `tests/run-all.sh`/
  `.ps1` (grep self-check); the staged `.github/workflows/test.yml`
  candidate carries this task's own one suite's steps appended after
  T-002's own, with correct `MANIFEST.sha256` entries; the LIVE
  `test.yml` is byte-unchanged before/after this task's own commits.
- [ ] **Governance** — `CHANGELOG.md` gains a NEW `## Unreleased` entry
  citing #193 (AC-033 share); no version string mutated outside
  `scripts/bump-version.sh` (AC-034 share); `git diff --stat` confirms no
  path under `plugins/**` in either of this task's own commits (AC-032).
- [ ] **Acceptance evidence** — every fixture written before the
  behavior it exercises, failing against a deliberately broken pipeline
  (an under-matched Capability, a mis-aggregated facet, a non-canonical
  provenance field) and passing against T-002/T-003/T-004's own correct
  pipeline (`acceptance-first`, no formal Red→Green TDD cycle required
  at `medium` tier). An independent quality-gate verdict records PASS.

### Out of Scope

- Any change to `resolve-project-context.{py,sh,ps1}` itself — this task
  only adds tests/fixtures exercising the engine T-002/T-003/T-004
  already built.
- The `resolve-project-context-block` suite (T-002/T-003/T-004/T-007's
  own, spanning four tasks), the CLI required-flag-matrix suite, the
  discovery-contract-reuse suite, and the Lite-track suite (T-006's
  own).
- `validate-resolver-evidence` (T-008), the dual-runtime parity suite
  (T-009), and the metamorphic completeness suite (T-010).

### Blockers

T-002, T-004

---
## T-006 Author `resolve-project-context`'s CLI-validation, discovery-contract, and Lite-track test suites

Source Issue: https://github.com/aharada54914/sdd-forge/issues/193

Approval: Approved (sudo 2026-08-08T16:04:17Z)

Status: Planned

Risk: medium

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. `medium`: this task adds no new production code path of its
own — it exercises T-002/T-003/T-004's own already-built core engine
from three additional angles (CLI usage-error surface, discovery-
contract reuse, Lite-track output-set exclusivity) — a defect here is a
false-negative test-coverage gap for a surface the engine itself already
implements, not itself a source of production-time silent
misclassification. Not `low`: the Lite-track suite specifically proves
the track-exclusive publication-set guarantee (B4 — a Lite resolve never
also writes `facet-manifest.yaml`/`project-context.resolved.json`), one
of this feature's own adversarially-reviewed corrections to an earlier
revision that violated Epic A4's own track-exclusive Capability Summary
contract; a gap here would let that regression ship silently. Required
Workflow is `acceptance-first` per the risk-gate-matrix's own medium-tier
row (`tdd` is reserved for high/critical).

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-001 (share — AC-001 CLI required-flag matrix, AC-002/
AC-028 discovery-contract reuse, AC-009 Lite-track schema-conformance:
three of REQ-001's own test surfaces, split out of the then-undivided
core-engine task by task-review attempt-1 round-1 remedy, closing a
TASK-SIZE finding, and now exercised against T-002/T-003/T-004's own
further-split engine following the attempt-2 remedies), REQ-006 (share —
fixture-matrix items covering the discovery-contract and Lite-track
portions), REQ-008 (share — CHANGELOG)

Depends On: T-004 (needs the complete core evaluation engine — argument
validation (T-002's own scope), ADR-0025 discovery (T-003's own scope),
Lite-track staging (T-004's own scope) — to already exist to test
against), T-005 (this task's own three suites append their own staged CI
steps directly after T-005's own staged `match`-suite candidate — the
immediately preceding suite-registering task in the fixed CI-
registration order, since neither T-003 nor T-004 touches that shared
file; a direct Blockers entry on T-005 is required in addition to T-004,
closing the exact class of gap round-3's DEPENDENCY-OVERLAP finding
named). Carries forward T-002/T-003/T-004's own re-verified Assumption:
Epic A1/A2/A3's already-`Spec-Review-Status: Passed` CLIs must be
present in this repository for this task's own suites to execute
meaningfully (this task's own fixtures invoke `resolve-project-context`
as a real subprocess).

Planned Files:
- `tests/resolve-project-context-cli.tests.sh` / `.ps1` (new)
- `tests/resolve-project-context-lite.tests.sh` / `.ps1` (new)
- `tests/resolve-project-context-discovery.tests.sh` / `.ps1` (new)
- `tests/fixtures/capability-resolver/` (extended — cli/lite/discovery
  fixtures; design.md Test Strategy items 1, 4, 6)
- `tests/run-all.sh` / `.ps1` (existing, agent-editable — three suites'
  registration: cli, lite, discovery)
- `specs/epic-193-a5-capability-resolver/human-copy/.github/workflows/
  test.yml` (appended, agent-editable — this task's own three suites'
  CI steps, appended after T-005's own)
- `specs/epic-193-a5-capability-resolver/human-copy/MANIFEST.sha256`
  (edited — appended entry for the `test.yml` candidate update)
- `CHANGELOG.md` (existing, agent-editable — CREATE the `## Unreleased`
  entry citing #193)

Data Migration: none.

Breaking API: no; this task adds only test files and fixtures — it never
edits `resolve-project-context.{py,sh,ps1}` itself.

Rollback: revert this task's two commits (B then A, or both). Nothing
protected is touched (this task never edits the human-copy script
candidates T-002/T-003/T-004 already staged).

### Goal

Author `resolve-project-context-cli` (AC-001: one fixture per required
flag — `--config`, `--target-rev`, `--feature` — each deleted in turn,
each rejected as a usage error, exit 2; `--source-rev` omission defaults
to `HEAD`), `resolve-project-context-discovery` (AC-002: every
`contracts/*` artifact this feature's scripts locate resolves via the
identical ADR-0025 script-relative-then-git-root-fallback procedure, no
environment variable consulted; AC-028: three installed-standalone-
plugin-layout discovery fixtures, one per runtime), and
`resolve-project-context-lite` (AC-009: the B5-narrowed
advisory-missing and zero-match non-Blocking Lite-track states, each
confirming the written `capability-summary.yaml` validates via
`validate-capability-summary` and this same invocation writes neither
`facet-manifest.yaml` nor `project-context.resolved.json`, B4)
test suites, each exercising T-002/T-003/T-004's own already-authored
core engine.

### Must Read

- `specs/epic-193-a5-capability-resolver/requirements.md` (REQ-001,
  Main Workflows 2/3)
- `specs/epic-193-a5-capability-resolver/design.md` (`### resolve-
  project-context.{py,sh,ps1} CLI contract (REQ-001)` step 0; `##
  Discovery contract`; `## Design Decisions`, "track-exclusive
  publication set"; `## Test Strategy` items 1, 4, 6)
- `specs/epic-193-a5-capability-resolver/acceptance-tests.md` (AC-001,
  AC-002, AC-009, AC-028)
- `specs/epic-193-a5-capability-resolver/investigation.md` (INV-005,
  INV-019)

### Scope

Commit A (implementation — three suites + fixtures + CI wiring):
- Write the acceptance checks first (`acceptance-first`, per risk-gate-
  matrix medium tier): TEST-001 (CLI required-flag matrix), TEST-002
  (discovery-contract reuse), TEST-009 (Capability Summary
  schema-conformance, track-exclusive, per the B5-narrowed
  advisory-missing/zero-match states), TEST-028 (three
  installed-standalone-plugin discovery fixtures, one per runtime).
- Register `resolve-project-context-cli`/`-lite`/`-discovery` (`.sh`/
  `.ps1`, three suites) in `tests/run-all.sh`/`.ps1`; stage the
  `.github/workflows/test.yml` candidate with these three suites' CI
  steps under `human-copy/`, appending to T-005's own staged candidate;
  update `MANIFEST.sha256` with the appended `test.yml` entry.

Commit B (documentation):
- CREATE the `CHANGELOG.md` `## Unreleased` entry citing #193.

### Done When

- [ ] **CLI/argument-validation** — TEST-001 passes: each required flag
  rejected as a usage error (exit 2) when omitted; `--source-rev`
  omission resolves to `HEAD` (AC-001).
- [ ] **Discovery reuse** — TEST-002 passes: every `contracts/*` artifact
  the engine locates resolves via ADR-0025 unmodified, no environment
  variable consulted (AC-002); TEST-028 passes: three
  installed-standalone-plugin-layout fixtures, one per runtime (AC-028).
- [ ] **Lite-track output-set exclusivity** — TEST-009 passes: the
  B5-narrowed advisory-missing and zero-match fixtures each confirm
  `capability-summary.yaml` validates and neither `facet-manifest.yaml`
  nor `project-context.resolved.json` is written (AC-009).
- [ ] **Fixture + suite/CI registration** — the three suites self-
  register in `tests/run-all.sh`/`.ps1` (grep self-check); the staged
  `.github/workflows/test.yml` candidate carries this task's own three
  suites' steps appended after T-005's own, with a correct
  `MANIFEST.sha256` entry; the LIVE `test.yml` is byte-unchanged
  before/after this task's own commits.
- [ ] **Governance** — `CHANGELOG.md` gains a NEW `## Unreleased` entry
  citing #193 (AC-033 share); no version string mutated outside
  `scripts/bump-version.sh` (AC-034 share); `git diff --stat` confirms no
  path under `plugins/**` in either of this task's own commits (AC-032).
- [ ] **Acceptance evidence** — every fixture written before the
  behavior it exercises, failing against a deliberately regressed
  invocation (e.g. a required flag silently defaulted, a discovery
  fallback consulting an environment variable, a Lite resolve also
  writing `facet-manifest.yaml`) and passing against the correct engine
  (`acceptance-first`, no formal Red→Green TDD cycle required at
  `medium` tier). An independent quality-gate verdict records PASS.

### Out of Scope

- Any change to `resolve-project-context.{py,sh,ps1}` itself — this task
  only adds tests/fixtures exercising the engine T-002/T-003/T-004
  already built.
- The `resolve-project-context-match` suite (T-005's own), the
  non-transactional Block-diagnostic suite (T-002/T-003/T-004's own,
  spanning three tasks), `validate-resolver-evidence` (T-008), the
  parity suite (T-009), and the metamorphic suite (T-010).

### Blockers

T-004, T-005

---
## T-007 Layer the Resolver publication transactional bundle contract onto `resolve-project-context.{py,sh,ps1}`

Source Issue: https://github.com/aharada54914/sdd-forge/issues/193

Approval: Approved (sudo 2026-08-08T16:04:17Z)

Status: Planned

Risk: high

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. `high` is justified and, unlike T-002/T-003/T-004, also touches
a genuine irreversible-filesystem surface: this task authors the ONLY
code path in this feature that ever writes a live artifact — a defect
here (a crash between two renames left unrecovered, an `unlink`-based
rollback that destroys pre-existing live bytes with no restore,
adversarial review "B1 atomicity") can silently corrupt or lose a
Feature's own already-published Facet Manifest/Capability Summary/
Resolver Evidence, exactly the kind of "material harm from a silent
defect" the policy's `high` tier names, and the closest this feature
comes to a `critical`-adjacent surface (still `high`, not `critical`,
because no financial-settlement or physical-safety surface is touched,
matching this Epic set's own established `high` ceiling for
classification/publication-integrity work, e.g. Epic A3 T-001's
identical rationale). Required Workflow is `tdd` per the policy's
high-tier row.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-001 (step 0's crash-recovery scan, step 14's
transaction), REQ-002 (share — the four transactional diagnostic-id rows:
`publication-journal-recovery`, `artifact-publication-failed`,
`post-publication-generation-mismatch`, and the `affected_components`-
only `snapshot-generation-mismatch` companion fixture), REQ-004 (share —
Resolver Evidence is committed via this same transaction), REQ-005
(share — determinism preserved across a crash/rollback), REQ-006 (share —
fixture-matrix item e's four remaining rows), REQ-008 (share —
CHANGELOG)

Depends On: T-004 (extends the same `resolve-project-context.{py,sh,
ps1}` script with the commit-phase logic; T-004's own staged-artifact
assembly, steps 0-13 complete, is this task's own transaction's input;
this task also appends its own four transactional-diagnostic fixtures
directly onto T-004's own contribution to `tests/resolve-project-
context-block.tests.sh`/`.ps1` — a single Blockers entry serves both
purposes, since T-004 is both the completed engine and the immediately
preceding contributor to this same suite file; T-003's own contribution
to that file is not the immediate predecessor, so a transitive-only
dependency on T-003 would not suffice, task-review attempt-2 remedy).
This task registers no new suite and touches neither `tests/run-all.*`
nor the staged `human-copy/.github/workflows/test.yml` candidate, so it
needs no separate CI-registration-order Blockers entry.

Planned Files:
- `specs/epic-193-a5-capability-resolver/human-copy/plugins/sdd-quality-
  loop/scripts/resolve-project-context.py` (updated staged candidate —
  adds the crash-recovery scan and the journaled publication
  transaction; re-verify this path's own then-current protection status
  per "Protected Files" above, since T-004's own human-copy application
  may or may not have already been applied by a human at this task's
  own start time)
- `specs/epic-193-a5-capability-resolver/human-copy/plugins/sdd-quality-
  loop/scripts/resolve-project-context.sh` / `.ps1` (updated staged
  candidates — twins)
- `specs/epic-193-a5-capability-resolver/human-copy/MANIFEST.sha256`
  (edited — updated SHA-256 entries for the three updated staged
  candidates)
- `tests/resolve-project-context-block.tests.sh` / `.ps1` (edited —
  appends the four transactional-diagnostic fixtures to T-002/T-003/
  T-004's own file; no new suite registration)
- `tests/fixtures/capability-resolver/` (extended — journal/crash-
  recovery/post-publication-race fixtures, including a test-harness-only
  kill hook and journal-corruption fixture)
- `CHANGELOG.md` (existing, agent-editable — CREATE the `## Unreleased`
  entry citing #193)

Data Migration: none.

Breaking API: no; this task only extends `resolve-project-context`'s own
internal commit logic, adding no new CLI flag and changing no already-
fixed output shape.

Rollback: revert this task's two commits (B then A, or both). If this
task's own updated human-copy candidate was already applied to the live
protected path, a revert PR states explicitly whether a human should also
hand-revert that applied content back to T-004's own prior version.

### Goal

Layer API / Contract Plan step 14 ("Resolver publication transactional
bundle contract") onto T-002/T-003/T-004's own staged-artifact pipeline:
the mandatory crash-recovery scan (runs on every invocation, immediately
after step 0's argument validation, scoped to the invocation's own
`--feature` value, before step 1 begins) converging any stale
`TRANSACTION.json` journal to one of two terminal states
(fully-applied/fully-reverted) or Blocking `publication-journal-recovery`
if recovery cannot safely complete; and the commit itself — Prepare
(re-hash every staged candidate together, byte-exact PRE-transaction
backup for any target with existing live content), Journal (write
`TRANSACTION.json` before any live rename, itself all-or-nothing),
Commit (rename each target atomically, in journal order), Post-
publication verification (a third `resolve-component-paths` invocation
plus fresh digest/`affected_components` recompute; a mismatch rolls every
just-completed rename back via the journal and Blocks
`post-publication-generation-mismatch`), Complete (delete the journal,
exit 0). An in-process write/fsync/rename failure during Prepare/Journal/
Commit Blocks `artifact-publication-failed`, with journal-based rollback
of any already-completed rename in the same commit sub-sequence — never a
bare `unlink`.

### Must Read

- `specs/epic-193-a5-capability-resolver/requirements.md` (REQ-002's
  four transactional diagnostic-id rows, Security Boundaries, Edge
  Cases — the TOCTOU/crash paragraphs)
- `specs/epic-193-a5-capability-resolver/design.md` (`### Resolver
  publication transactional bundle contract (REQ-001/REQ-002, NEW)` in
  full — Prepare/Journal/Commit/Post-publication-verification/Complete,
  the crash-recovery scan, the reader-side generation-consistency check,
  the single-writer assumption; `## Test Strategy` item 2's own
  transactional fixtures; `## Security Boundaries`)
- `specs/epic-193-a5-capability-resolver/acceptance-tests.md` (AC-010
  [remaining four rows], AC-011 [share], AC-012 [share], AC-014 [share],
  AC-038 [share], AC-039, AC-040 [second fixture, share], AC-047,
  AC-049)
- `specs/epic-193-a5-capability-resolver/infra-spec.md`
  (`#journal-recovery`, `#rollback`)
- Epic A1's own already-fixed multi-target transactional bundle contract
  (`design.md:927-1016` in the Epic A1 worktree, "Human-copy publisher
  transactional bundle contract") — the reference implementation this
  task's own journal/recovery mechanism applies isomorphically, per
  design.md's own explicit citation

### Scope

Commit A (implementation — transactional commit + four fixtures):
- Write the acceptance checks first (TDD Red→Green): TEST-010 (the
  remaining four diagnostic-id rows: `publication-journal-recovery`,
  `artifact-publication-failed`, `post-publication-generation-mismatch`,
  and the second `snapshot-generation-mismatch` fixture — actually the
  `affected_components`-only variant is TEST-040's own second fixture,
  authored here since it exercises step-14-adjacent timing; see
  Global Constraints), TEST-011/TEST-012/TEST-014 (extended to cover
  these four fixtures), TEST-038 (extended for the transactional
  staged-generation lock), TEST-039 (`artifact-publication-failed`/
  journal-rollback), TEST-047 (journal-based crash recovery, including
  the journal-corruption companion), TEST-049 (post-publication
  verification/race).
- Extend `resolve-project-context.py`'s own step 0 (crash-recovery scan)
  and step 14 (journaled transaction) per the design.md contract
  verbatim.
- CI resilience/diagnostic determinism per Global Constraints, applied
  to this task's own new code paths (journal read/write, byte-exact
  pre-image backup, rollback).

Commit B (documentation):
- CREATE the `CHANGELOG.md` `## Unreleased` entry citing #193.

### Done When

- [ ] **Crash-recovery scan** — TEST-047 passes: a fixture simulating a
  hard crash between two renames of a multi-target Full-track commit
  (test-harness-only kill hook) confirms the next invocation's own scan
  converges every target back to its own PRE-transaction bytes before
  proceeding with a separate resolve; a companion fixture corrupting the
  journal's own recorded pre-image backup confirms the next invocation
  Blocks `publication-journal-recovery` before any Registry/ownership/
  Context-Projection work begins (AC-047).
- [ ] **In-process publication failure** — TEST-039 passes: an injected
  write/rename failure on a staged output path after every earlier step
  succeeded Blocks `artifact-publication-failed`; a second,
  already-completed rename in the same commit sub-sequence is rolled
  back to its own PRE-transaction live bytes via the journal — never a
  bare `unlink` — and the rollback attempt is itself recorded in this
  diagnostic's own `detail` (AC-039).
- [ ] **Post-publication verification / race** — TEST-049 passes: an
  injected source mutation after the pre-publication recheck (T-004's
  own step 13) has already passed but before step 14's own last rename
  completes confirms `post-publication-generation-mismatch` fires only
  after every rename has already, briefly, succeeded; every one of those
  renames is rolled back to its own PRE-transaction state via the
  journal before this invocation exits; the rollback is journal-based,
  never a bare `unlink` (AC-049).
- [ ] **Second `snapshot-generation-mismatch` fixture** — TEST-040's own
  companion fixture passes: every digest, including `ownership_digest`,
  stays byte-identical between snapshot and recheck, but a re-derived
  `affected_components` set differs (worktree/index/untracked mutation
  only), confirming the Block fires on the set difference alone (AC-040
  share).
- [ ] **Full sixteen-row Block matrix complete** — TEST-010 now covers
  all sixteen REQ-002 diagnostic-id rows across T-002's five, T-003's
  five, T-004's three, and this task's four, plus one fully-clean
  fixture proving a negative (AC-010); TEST-011/TEST-012/TEST-014 are
  now complete across all sixteen rows (AC-011, AC-012, AC-014); TEST-038
  now covers every named staged-generation example (AC-038).
- [ ] **Staged-generation/journaled-transactional-publication lock** —
  TEST-038 confirms no earlier-staged artifact from ANY Block fixture
  (T-002's, T-003's, T-004's, or this task's own) ever reached a live
  path (AC-038, complete).
- [ ] **Governance** — `CHANGELOG.md` gains a NEW `## Unreleased` entry
  citing #193 (AC-033 share); no version string mutated outside
  `scripts/bump-version.sh` (AC-034 share); `git diff --stat` confirms
  no path under `plugins/**` in either of this task's own commits
  (AC-032).
- [ ] **TDD evidence** — RED (each transactional fixture against a
  deliberately broken commit/recovery path) and GREEN (the full suite).
  An independent quality-gate verdict records PASS.

### Out of Scope

- Steps 0-13's own evaluation logic (T-002/T-003/T-004's own scope) —
  this task never changes the union-match rule, the facet-name
  aggregation rule, the WARN check, or any of the thirteen
  non-transactional diagnostic rows.
- The `resolve-project-context-match` suite (T-005's own), the CLI/
  discovery/Lite suites (T-006's own), `validate-resolver-evidence`
  (T-008), the parity suite (T-009), the metamorphic suite (T-010).
- Registering a new test suite in `tests/run-all.*` or staging a new
  `.github/workflows/test.yml` CI step — this task only edits fixtures
  inside T-002's already-registered `resolve-project-context-block`
  suite.

### Blockers

T-004

---
## T-008 Author `validate-resolver-evidence.{py,sh,ps1}` and its provenance-binding suite

Source Issue: https://github.com/aharada54914/sdd-forge/issues/193

Approval: Approved (sudo 2026-08-08T16:04:17Z)

Status: Planned

Risk: high

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. `high` is justified on the identical "footgun-prevention/
tamper-evidence exposure" surface Epic A3's own `check-component-
coverage` (T-006 there) established for a structural validator: this
script closes the "point the validator at a different, smaller Registry"
and "supply an arbitrary affected-component subset" attacks (adversarial
review "B6 provenance binding") — a defect here (the identical earlier-
revision gap this design's own remedy already names: "the validator
trusts a caller-supplied `--registry`/`--affected-components` as ground
truth") would let a self-consistent-but-wrong Resolver Evidence instance
pass validation, silently defeating the one mechanism a future Gate-chain
caller (requirements.md Target Users) relies on to trust that instance's
own provenance without re-invoking the Resolver. Required Workflow is
`tdd` per the policy's high-tier row.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-004 (validator), REQ-005 (share — stable-sort check
`array-not-stable-sorted`), REQ-006 (share — fixture-matrix item h's
provenance-binding pair), REQ-008 (share — CHANGELOG)

Depends On: T-001 (schema this validator's own `schema-invalid` check
enforces), T-007 (the reader-side `RESOLVER_PUBLICATION_IN_PROGRESS`
journal check, AC-054, needs a real `TRANSACTION.json` shape identical to
T-007's own journal format to fixture against; realistic Resolver
Evidence/Facet-Manifest sibling-artifact fixtures for the provenance-
binding checks are likewise most directly produced by T-002/T-003/T-004/
T-007's own working pipeline, though hand-crafted fixtures suffice where
a real invocation is impractical), T-006 (this task registers the new
`validate-resolver-evidence` suite, whose own staged CI steps append
directly after T-006's own staged candidate — the immediately preceding
suite-registering task in the fixed CI-registration order, since T-007
never touches the shared registration file; a direct Blockers entry on
T-006 is required in addition to T-007, closing the exact class of gap
round-3's DEPENDENCY-OVERLAP finding named).

Planned Files:
- `plugins/sdd-quality-loop/scripts/validate-resolver-evidence.py` (new,
  agent-editable — not protected, direct write; hand-rolled, stdlib-only
  draft-07-subset validator, matching Epic A4's own three validators'
  precedent)
- `plugins/sdd-quality-loop/scripts/validate-resolver-evidence.sh` (new,
  agent-editable — thin wrapper)
- `plugins/sdd-quality-loop/scripts/validate-resolver-evidence.ps1`
  (new, agent-editable — twin)
- `tests/validate-resolver-evidence.tests.sh` / `.ps1` (new)
- `tests/fixtures/capability-resolver/validate-resolver-evidence/` (new
  fixture tree — one fixture per twelve-value check-id, plus one clean
  fixture, plus the provenance-binding and reader-side-journal-check
  fixture pairs)
- `tests/run-all.sh` / `.ps1` (existing, agent-editable — this suite's
  registration)
- `specs/epic-193-a5-capability-resolver/human-copy/.github/workflows/
  test.yml` (appended, agent-editable — this suite's CI steps)
- `specs/epic-193-a5-capability-resolver/human-copy/MANIFEST.sha256`
  (edited — appended entry)
- `CHANGELOG.md` (existing, agent-editable — CREATE the `## Unreleased`
  entry citing #193)

Data Migration: none — new, additive CLI; no prior version to migrate
from.

Breaking API: no; `validate-resolver-evidence` is a wholly new script.

Rollback: revert this task's two commits (B then A, or both). Nothing
protected is touched (this script and its schema are both agent-editable
directly).

### Goal

Author `validate-resolver-evidence.py` (+ `.sh`/`.ps1` wrappers)
implementing the closed, twelve-value check-id enum: `schema-invalid`,
`registry-digest-unbound` (checked before any exact-set check, B6),
`capability-set-mismatch`, `capability-evaluation-id-duplicate`,
`affected-component-provenance-mismatch` (B6), `trigger-evaluation-set-
mismatch`, `component-evaluation-id-duplicate`, `matched-result-
contradiction` (bidirectional), `conditional-facet-set-mismatch`
(`declaration_index`-keyed, never `facet`-name-keyed, B7),
`conditional-facet-evaluation-set-mismatch`, `applied-result-
contradiction` (bidirectional), `array-not-stable-sorted`. Implement the
provenance-binding procedure (Registry via self-resolved-or-override
`generate-registry-digest --whole` bound to `context_binding.
registry_digest`; affected-component set derived from `context_binding.
dependency_pointers[]`, cross-checked against a co-located Facet
Manifest's own, any CLI override required to match) and the reader-side
`RESOLVER_PUBLICATION_IN_PROGRESS` generation-consistency check before
reading `--evidence`/`--manifest`.

### Must Read

- `specs/epic-193-a5-capability-resolver/requirements.md` (REQ-004's
  `validate-resolver-evidence` paragraph)
- `specs/epic-193-a5-capability-resolver/design.md` (`### validate-
  resolver-evidence.{py,sh,ps1} contract (REQ-004)` in full; `##
  Discovery contract`)
- `specs/epic-193-a5-capability-resolver/acceptance-tests.md` (AC-021,
  AC-050, AC-051, AC-054)
- `specs/epic-193-a5-capability-resolver/security-spec.md`
  (`#trust-boundaries`, `#stride-analysis`)
- `plugins/sdd-quality-loop/scripts/validate-facet-manifest.py`,
  `validate-capability-summary.py`, `validate-context-projection.py`
  (Epic A4) — the three-validator diagnostic-line convention and
  hand-rolled draft-07-subset pattern this script matches, generalized
  here with the added provenance-binding/exact-set inputs Epic A4's
  three validators do not themselves need

### Scope

Commit A (implementation — validator + suite + fixtures + CI wiring):
- Write the acceptance checks first (TDD Red→Green): TEST-021 (one
  fixture per twelve-value check-id, plus one clean fixture), TEST-050
  (Registry provenance-binding — `--registry` override mismatch fires
  `registry-digest-unbound` before `capability-set-mismatch`; default
  self-discovery performs the identical binding check), TEST-051
  (affected-component provenance-binding — co-located Manifest mismatch
  fires without a CLI override; an explicit contradicting override fires
  the identical check-id), TEST-054 (reader-side journal-check —
  a live `TRANSACTION.json` naming the `resolver-evidence.yaml` path
  about to be read fails this validator closed).
- Author `validate-resolver-evidence.py` + `.sh`/`.ps1` wrappers.
- Register `validate-resolver-evidence` (`.sh`/`.ps1`) in `tests/run-all.
  sh`/`.ps1`; stage the `.github/workflows/test.yml` candidate with this
  suite's CI steps under `human-copy/`, appended after T-006's own (the
  last suite-owning task before this one — T-007 registers no new
  suite); update `MANIFEST.sha256`.

Commit B (documentation):
- CREATE the `CHANGELOG.md` `## Unreleased` entry citing #193.

### Done When

- [ ] **Twelve-value check-id matrix** — TEST-021 passes: one
  independently-triggerable fixture per check-id, plus one clean
  fixture (AC-021).
- [ ] **Provenance binding** — TEST-050 passes: the `registry-digest-
  unbound` binding-before-exact-set ordering, both self-discovery and
  override paths (AC-050); TEST-051 passes: `affected-component-
  provenance-mismatch` fires on a Manifest-Evidence mismatch without a
  CLI override, and on an override that contradicts both sibling
  artifacts (AC-051).
- [ ] **Reader-side journal check** — TEST-054 passes: this validator
  fails closed, never reading possibly-torn cross-file state, when a
  live transaction journal names the path it is about to read (AC-054).
- [ ] **Stable-sort check** — `array-not-stable-sorted` fires correctly
  on an out-of-order `capability_evaluations[]`/`diagnostics[]` fixture
  (REQ-005 share).
- [ ] **Fixture + suite/CI registration** — `tests/validate-resolver-
  evidence.tests.sh`/`.ps1` self-register in `tests/run-all.sh`/`.ps1`
  (grep self-check); the staged `.github/workflows/test.yml` candidate
  carries this suite's own steps appended after T-006's own, with a
  correct `MANIFEST.sha256` entry; the LIVE `test.yml` is byte-unchanged
  before/after this task's own commits.
- [ ] **Governance** — `CHANGELOG.md` gains a NEW `## Unreleased` entry
  citing #193 (AC-033 share); no version string mutated outside
  `scripts/bump-version.sh` (AC-034 share); `git diff --stat` confirms
  no path under `plugins/**` in either of this task's own commits
  (AC-032).
- [ ] **TDD evidence** — RED (each check-id fixture against a
  deliberately permissive validator) and GREEN (the full suite). An
  independent quality-gate verdict records PASS.

### Out of Scope

- `resolve-project-context` itself (T-002/T-003/T-004/T-007) — this task
  never re-runs any predicate evaluation; every check is structural/set-
  membership/provenance-binding against already-recorded evidence.
- The dual-runtime parity suite (T-009) and the metamorphic completeness
  suite (T-010), though both depend on this task's own validator.
- Extending `contracts/resolver-evidence.schema.json` itself (T-001's
  own, content-frozen-once-passed deliverable) — `schema-invalid` reads
  it, never edits it.

### Blockers

T-001, T-006, T-007

---
## T-009 Author the dual-runtime parity and determinism suite

Source Issue: https://github.com/aharada54914/sdd-forge/issues/193

Approval: Approved (sudo 2026-08-08T16:04:17Z)

Status: Planned

Risk: medium

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. `medium`: this task adds no new production code path of its
own (it is a test suite exercising T-002/T-003/T-004/T-006/T-007/T-008's
own already-built scripts across runtimes) — a defect here is a
false-negative test gap (REQ-005's own byte-identity/determinism
guarantee going unverified for some input), not itself a source of
production-time silent misclassification. Not `low`: REQ-005's own
dual-runtime parity guarantee is one of this feature's own named,
adversarially-reviewed guarantees (requirements.md REQ-005, "OK-3
reinforcement"), and a gap in this suite's own coverage would let a
`.sh`/`.ps1` divergence ship silently on whichever runtime this suite
under-tests. Required Workflow is `acceptance-first` per the
risk-gate-matrix's own medium-tier row (`tdd` is reserved for
high/critical).

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-005 (parity/determinism proof; AC-022, AC-023, AC-024,
AC-025), REQ-006 (share — REQ-005's own dual-runtime parity suite item),
REQ-008 (share — CHANGELOG)

Depends On: T-002, T-003, T-004 (the core evaluation engine, in its
three sequential stages), T-005 (design.md Test Strategy item 5 requires
byte-identical parity "across every fixture above" — items 1-4, which
include T-005's own `match`-suite fixtures), T-006 (design.md Test
Strategy item 5 also requires parity across item 1's own CLI fixtures and
item 6's own discovery fixtures, T-006's own), T-007 (needs the full
evaluation-plus-publication pipeline, every track, every diagnostic, to
compare across `.py`/`.sh`/`.ps1`), T-008 (`validate-resolver-evidence`
has its own `.py`/`.sh`/`.ps1` triad and participates in this same parity
guarantee; T-008 is also the immediately preceding suite-registering
task in the fixed CI-registration order, so this entry directly serves
both the functional and the shared-file-ordering purpose).

Planned Files:
- `tests/resolve-project-context-parity.tests.sh` / `.ps1` (new)
- `tests/fixtures/capability-resolver/parity/` (new — reuses fixture
  inputs from T-002/T-003/T-004/T-005/T-006/T-007/T-008's own suites
  where practical; includes at least one Windows-style, `\`-separated
  path argument)
- `tests/run-all.sh` / `.ps1` (existing, agent-editable — this suite's
  registration)
- `specs/epic-193-a5-capability-resolver/human-copy/.github/workflows/
  test.yml` (appended, agent-editable — this suite's CI steps)
- `specs/epic-193-a5-capability-resolver/human-copy/MANIFEST.sha256`
  (edited — appended entry)
- `CHANGELOG.md` (existing, agent-editable — CREATE the `## Unreleased`
  entry citing #193)

Data Migration: none.

Breaking API: no; this task adds only test files and fixtures.

Rollback: revert this task's two commits (B then A, or both). Nothing
protected is touched.

### Goal

Author `resolve-project-context-parity`: (a) two `.py` invocations of the
identical input produce byte-identical output across the invocation's own
track-exclusive output set (AC-022); (b) `.py`/`.sh`/`.ps1` invocations
of the identical input produce byte-identical output plus identical
stdout/stderr/exit code, restricted to this feature's own emitted
content — never comparing a dependency subprocess's own raw stderr, M8
(AC-023); (c) every semantic-output array this feature writes is
stable-sorted, proven against an intentionally-out-of-order Registry
`capabilities[]` declaration order (AC-024); (d) a repository-wide grep
self-check confirms no Resolver-owned script reads
`datetime.now()`/`time.time()`/any network primitive/any provider-API
client (AC-025).

### Must Read

- `specs/epic-193-a5-capability-resolver/requirements.md` (REQ-005 in
  full)
- `specs/epic-193-a5-capability-resolver/design.md` (`## Test Strategy`
  item 5; `## Global Constraints`; `## Security Boundaries`)
- `specs/epic-193-a5-capability-resolver/acceptance-tests.md` (AC-022
  through AC-025)
- Epic A4's own "Diagnostic determinism contract" (`design.md:956-985`
  in the Epic A4 worktree) and parity-suite convention this task's own
  suite matches

### Scope

Commit A (implementation — suite + fixtures + CI wiring):
- Write the acceptance checks first (`acceptance-first`, per risk-gate-
  matrix medium tier): TEST-022 (repeated-invocation determinism),
  TEST-023 (dual-runtime parity, including a Windows-style path fixture),
  TEST-024 (stable-sort discipline), TEST-025 (no-nondeterministic-source
  grep, repository-wide).
- Register `resolve-project-context-parity` (`.sh`/`.ps1`) in `tests/
  run-all.sh`/`.ps1`; stage the `.github/workflows/test.yml` candidate
  with this suite's CI steps under `human-copy/`, appended after T-008's
  own; update `MANIFEST.sha256`.

Commit B (documentation):
- CREATE the `CHANGELOG.md` `## Unreleased` entry citing #193.

### Done When

- [ ] **Repeated-invocation determinism** — TEST-022 passes (AC-022).
- [ ] **Dual-runtime parity** — TEST-023 passes, including the
  Windows-style path fixture, restricted to this feature's own emitted
  content (AC-023).
- [ ] **Stable-sort discipline** — TEST-024 passes against an
  intentionally-out-of-order Registry declaration (AC-024).
- [ ] **No-nondeterministic-source lock** — TEST-025's repository-wide
  grep confirms no `datetime.now()`/`time.time()`/network/provider-API
  call anywhere in `resolve-project-context.*` or `validate-resolver-
  evidence.*` (AC-025).
- [ ] **Fixture + suite/CI registration** — self-registers in `tests/
  run-all.sh`/`.ps1`; staged `.github/workflows/test.yml` candidate
  carries this suite's steps appended after T-008's own, with a correct
  `MANIFEST.sha256` entry; LIVE `test.yml` byte-unchanged before/after.
- [ ] **Governance** — `CHANGELOG.md` gains a NEW `## Unreleased` entry
  citing #193 (AC-033 share); no version string mutated outside
  `scripts/bump-version.sh` (AC-034 share); `git diff --stat` confirms
  no path under `plugins/**` (AC-032).
- [ ] **Acceptance evidence** — every fixture written before the
  behavior it exercises, failing against a deliberately introduced
  cross-runtime or ordering divergence and passing against the correct
  pipeline (`acceptance-first`, no formal Red→Green TDD cycle required
  at `medium` tier). An independent quality-gate verdict records PASS.

### Out of Scope

- Any change to `resolve-project-context.{py,sh,ps1}` or
  `validate-resolver-evidence.{py,sh,ps1}` themselves — this task only
  adds tests/fixtures exercising the scripts T-002/T-003/T-004/T-005/
  T-006/T-007/T-008 already built.
- The metamorphic completeness suite (T-010).

### Blockers

T-002, T-003, T-004, T-005, T-006, T-007, T-008

---
## T-010 Author the metamorphic completeness suite

Source Issue: https://github.com/aharada54914/sdd-forge/issues/193

Approval: Approved (sudo 2026-08-08T16:04:17Z)

Status: Planned

Risk: medium

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. `medium`, for the identical reason T-009 is `medium`: this task
adds no new production code path (it exercises T-002/T-003/T-004/T-007/
T-008's own already-built scripts from additional angles) — a gap here is
a false-negative coverage gap for the completeness/invariance properties
adversarial review "M10" specifically found unfixtured in an earlier
revision, not itself a new production-time defect source. Required
Workflow is `acceptance-first` per the risk-gate-matrix's own medium-tier
row (`tdd` is reserved for high/critical).

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-005 (share — metamorphic output-invariance proof),
REQ-006 (metamorphic-completeness suite item h; AC-045), REQ-008 (share —
CHANGELOG)

Depends On: T-004 (the full evaluation-plus-publication pipeline this
suite's own TT/TF/FT/FF and order-permutation fixtures exercise starts
from the completed evaluation engine), T-007 (needs the completed
publication pipeline for the same fixtures), T-008 (`validate-resolver-
evidence`'s own exact-set checks are this suite's own assertion mechanism
for the nested-array-completeness fixture, item (f)), T-009 (this task
registers the final suite in the fixed CI-registration order, whose own
staged CI steps append directly after T-009's own staged candidate — a
direct Blockers entry on T-009 is required in addition to T-004/T-007/
T-008, closing the exact class of gap round-3's DEPENDENCY-OVERLAP
finding named: an earlier revision cited only the functional
predecessors and omitted the immediately preceding CI-registering task).

Planned Files:
- `tests/resolve-project-context-metamorphic.tests.sh` / `.ps1` (new)
- `tests/fixtures/capability-resolver/metamorphic/` (new)
- `tests/run-all.sh` / `.ps1` (existing, agent-editable — this suite's
  registration)
- `specs/epic-193-a5-capability-resolver/human-copy/.github/workflows/
  test.yml` (appended, agent-editable — this suite's CI steps)
- `specs/epic-193-a5-capability-resolver/human-copy/MANIFEST.sha256`
  (edited — appended entry)
- `CHANGELOG.md` (existing, agent-editable — CREATE the `## Unreleased`
  entry citing #193)

Data Migration: none.

Breaking API: no; this task adds only test files and fixtures.

Rollback: revert this task's two commits (B then A, or both). Nothing
protected is touched.

### Goal

Author `resolve-project-context-metamorphic` covering design.md's own
Test Strategy item 9 in full: (a) all four true/false combinations of a
2-affected-component `trigger` result (TT/TF/FT/FF), asserting `matched`
exactly per the union-match rule in every case; (b) the identical
fixture's own `affected_components[]` fed in each of its 2 possible
orderings, asserting byte-identical output; (c) a 3-affected-component
fixture with more than one `true` evaluation, asserting the Capability is
recorded exactly once; (d) an `applied: false` `conditional_facets[]`
fixture whose `reason` is asserted verbatim against the exact template;
(e) one fixture per WARN branch (matched-capability-trigger,
unmatched-capability-trigger, matched-capability-conditional-facet), each
independently Blocking; (f) a nested-array-completeness fixture asserted
via `validate-resolver-evidence`'s own exact-set checks passing on a
complete fixture and failing on an intentionally-corrupted copy; (g) a
dependency-invocation-order spy fixture asserting the exact subprocess
call order and that a forced non-zero exit at each position Blocks with
that position's own correct diagnostic id and invokes no later-ordered
subprocess.

### Must Read

- `specs/epic-193-a5-capability-resolver/requirements.md` (REQ-005's
  "M10 metamorphic completeness" language, REQ-006 item h)
- `specs/epic-193-a5-capability-resolver/design.md` (`## Test Strategy`
  item 9 in full)
- `specs/epic-193-a5-capability-resolver/acceptance-tests.md` (AC-045)

### Scope

Commit A (implementation — suite + fixtures + CI wiring):
- Write the acceptance checks first (`acceptance-first`, per risk-gate-
  matrix medium tier): TEST-045, covering design.md Test Strategy item
  9's own sub-items (a) through (g).
- Register `resolve-project-context-metamorphic` (`.sh`/`.ps1`) in
  `tests/run-all.sh`/`.ps1`; stage the `.github/workflows/test.yml`
  candidate with this suite's CI steps under `human-copy/`, appended
  after T-009's own (the final entry in this feature's own staged
  candidate); update `MANIFEST.sha256`.

Commit B (documentation):
- CREATE the `CHANGELOG.md` `## Unreleased` entry citing #193.

### Done When

- [ ] **Metamorphic completeness** — TEST-045 passes: TT/TF/FT/FF
  combination matrix; order-invariance; >1-true-component
  single-recording; verbatim `reason` template; all three WARN-branch
  fixtures independently Blocking; nested-array-completeness via
  `validate-resolver-evidence`; dependency-invocation-order spy fixture
  with per-position forced-failure sub-fixtures (AC-045).
- [ ] **Fixture + suite/CI registration** — self-registers in `tests/
  run-all.sh`/`.ps1`; staged `.github/workflows/test.yml` candidate
  carries this suite's steps appended after T-009's own (the final
  entry), with a correct `MANIFEST.sha256` entry; LIVE `test.yml`
  byte-unchanged before/after.
- [ ] **Governance** — `CHANGELOG.md` gains a NEW `## Unreleased` entry
  citing #193 (AC-033 share); no version string mutated outside
  `scripts/bump-version.sh` (AC-034 share); `git diff --stat` confirms
  no path under `plugins/**` (AC-032).
- [ ] **Feature-wide fixture-matrix completeness** — a final check
  confirms every REQ-006 fixture-matrix item (a-h) and every one of the
  nine suites T-001..T-010 build is present and independently invocable
  under `tests/fixtures/capability-resolver/` (AC-026 [nine of ten
  suites, per Global Constraints' own "Deferred, Not Scheduled" note],
  AC-027).
- [ ] **Acceptance evidence** — every metamorphic fixture written before
  the behavior it exercises, failing against a deliberately incomplete or
  order-sensitive pipeline and passing against the correct one
  (`acceptance-first`, no formal Red→Green TDD cycle required at
  `medium` tier). An independent quality-gate verdict records PASS.

### Out of Scope

- Any change to `resolve-project-context.{py,sh,ps1}` or
  `validate-resolver-evidence.{py,sh,ps1}` themselves.
- The `tests/resolve-project-context-caller-contract.tests.sh`/`.ps1`
  suite (design.md Test Strategy item 10) — deferred to a future,
  not-yet-scheduled task that also edits `sdd-bootstrap-interviewer/
  SKILL.md` (Global Constraints, "Deferred, Not Scheduled").

### Blockers

T-004, T-007, T-008, T-009
