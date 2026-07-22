# Tasks: epic-193-a5-capability-resolver

Task-Review-Status: Pending

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
   exists at that path). **T-002 and T-005 each re-verify, at their own
   implementation-start time, whether that Epic A1 registration commit
   has already landed on this branch** (`grep -n "resolve-project-
   context" plugins/sdd-quality-loop/references/guard-invariants.json`
   — at this package's own Phase-2-authoring time the reservation is
   **not yet live** on this worktree, design.md Protected-File Statement
   point 1):
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
     running Resolver process itself, via T-005's own journaled
     publication transaction, never by a human `cp`.
2. **Never protected, agent-editable directly, no human-copy step**:
   `contracts/resolver-evidence.schema.json` (T-001) and
   `plugins/sdd-quality-loop/scripts/validate-resolver-evidence.{py,sh,
   ps1}` (T-006) — matching Epic A4's own three schema-validator
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
  same task. Each of T-001..T-008 lands its OWN new `## Unreleased`
  block in `CHANGELOG.md` citing issue #193 — never an append to another
  task's own entry (REQ-008/AC-033).
- **Task-decomposition note (two task-review remedy rounds, both closing
  TASK-SIZE findings)**: the original Phase-2 draft bundled the core
  evaluation engine (steps 0-13) together with all five of its own test
  suites (`cli`/`match`/`lite`/`discovery`/`block`) into one task.
  **Round-1 remedy**: reviewer-b's first TASK-SIZE finding (12+ pipeline
  stages plus five new test suites in one unit of work) was addressed by
  splitting that task into a narrower T-002 (the core engine plus the
  `match`/`block` suites) and a new T-003 (the `cli`/`discovery`/`lite`
  suites), renumbering every later task up by one. **Round-2 remedy**:
  reviewer-b's own re-check found the round-1 split insufficient — T-002
  still bundled the entire undivided 12+-stage engine with two full TDD
  suites (`match` and the twelve-fixture `block`) — so T-002 was split
  once more, this time taking reviewer-b's own stated minimum-sufficient
  option (isolate the block suite; isolating `match` as well was
  deliberately rejected, since it would leave T-002 with no test suite
  of its own, conflicting with its own `Required Workflow: tdd`): T-002
  now carries only the engine plus `match`; a new T-003 carries the
  twelve-fixture `block` suite; every task from the round-1 T-003
  onward renumbers up by one again (round-1 T-003→T-004, T-004→T-005,
  T-005→T-006, T-006→T-007, T-007→T-008). Round-2 also corrected a
  DEPENDENCY-OVERLAP finding (T-005/T-007, in this final numbering, each
  now correctly cite T-003 as a Blockers entry, and T-007 additionally
  cites T-004 — both real dependencies an earlier revision omitted). No
  requirement, acceptance criterion, or test suite was dropped or added
  by either remedy — see `reports/task-review/epic-193-a5-capability-
  resolver/attempt-1/round-1/tasks-round-1-proposed-changes.md` and
  `.../round-2/tasks-round-2-proposed-changes.md` for the full finding
  and remedy record of each round.
- **Test-suite/CI-registration serialization, T-001 → T-002 → T-003 →
  T-004 → T-006 → T-007 → T-008** (mirroring `specs/epic-191-a3-path-
  ownership/tasks.md`'s identical convention for a shared protected CI
  file): each of T-001, T-002, T-003, T-004, T-006, T-007, T-008
  registers its own **new** suite directly (unprotected) in `tests/
  run-all.sh`/`.ps1` (AC-026) and stages its own suite's CI steps into
  the shared candidate under `specs/epic-193-a5-capability-resolver/
  human-copy/.github/workflows/test.yml` (R-10 protected — `test.yml`
  itself is never written directly) with a `MANIFEST.sha256` entry, in
  that exact order. **T-005 registers no new suite** — it extends
  `tests/resolve-project-context-block.tests.sh`/`.ps1` (already
  registered by T-003) with additional fixtures for the transactional
  diagnostic rows only, and touches neither `tests/run-all.*` nor
  `human-copy/.github/workflows/test.yml`. A task that stages after
  another whose candidate is not yet human-applied appends its own
  suite's steps to that pending staged file rather than starting from
  the unmodified real `test.yml`.
- **`tests/resolve-project-context-block.tests.sh`/`.ps1` is a single,
  shared suite file spanning two tasks in strict sequence**: T-003
  creates it (registration + the twelve non-transactional REQ-002
  diagnostic-id fixtures, API / Contract Plan steps 0-13 excluding the
  crash-recovery scan and step 14's own commit); T-005 appends the four
  transactional-diagnostic fixtures (`publication-journal-recovery`,
  `artifact-publication-failed`, `post-publication-generation-mismatch`,
  and the second, `affected_components`-only `snapshot-generation-
  mismatch` fixture pairing with T-003's digest-only one) without
  touching T-003's own fixtures. AC-010's full sixteen-row matrix, and
  AC-011/012/013/014's own全-Block-fixture completeness, are each
  satisfied only once T-005 lands — T-003's own Done When scopes these
  four criteria to its own twelve fixtures; T-005's own Done When
  completes them (Task Mapping, traceability.md).
- **`resolve-project-context.{py,sh,ps1}` is one Python-master-plus-
  wrapper component edited by exactly two tasks, in sequence**: T-002
  authors the full evaluation pipeline (API / Contract Plan steps
  0-13 — argument validation, state derivation, canonicalization,
  Context Projection assembly, `resolve-component-paths` invocation,
  Registry discovery, trigger/conditional-facet evaluation, WARN check,
  track branch, Facet-Manifest-or-Capability-Summary staging, Resolver
  Evidence assembly, output schema self-validation, pre-publication
  snapshot recheck); T-005 layers the crash-recovery scan (end of step
  0) and step 14's own journaled publication transaction (Prepare /
  Journal / Commit / Post-publication-verification / Complete) onto that
  same script. Neither task's own diff to this file may be developed
  against a live protected path directly — see "Protected Files" above.
  **T-003 and T-004 never edit this file** — each only adds tests/
  fixtures exercising the engine T-002 already authored.
- **Deferred, not scheduled** (design.md Test Strategy item 10, REQ-007
  Non-goals): `tests/resolve-project-context-caller-contract.tests.sh`/
  `.ps1` is fixed at contract level by `design.md` (Design Decisions,
  "caller insertion point"/"anchor fingerprint" — the recorded sha256
  window fingerprint and section-order index this suite's own future
  fixture will assert against) but is **not** authored by any task
  below — design.md states it "is itself authored once the capability
  interview phase is actually implemented (a future task, Non-goals)."
  **AC-026's own "ten new suites registered" criterion is therefore
  satisfied by this `tasks.md` only for the nine suites T-001..T-008
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
  T-007's own Done When, run against every script this feature adds.
- Preserve unrelated changes; implement one task at a time.

---

## T-001 Author `contracts/resolver-evidence.schema.json` and its schema-conformance suite

Source Issue: https://github.com/aharada54914/sdd-forge/issues/193

Approval: Draft

Status: Planned

Risk: medium

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. Not `high`: this schema has no upstream dependency of its own
(design.md Cross-Layer Dependencies — "the one artifact this feature is
free to shape itself") and an under-constrained schema is itself caught
downstream by T-005's `validate-resolver-evidence` semantic checks before
any Resolver Evidence instance is ever trusted by a caller — a schema
defect here degrades to a T-005-catchable defect, not a silent
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
until T-002/T-003 land).

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
  T-005 will reuse; read here for the schema-document shape it expects)

### Scope

Commit A (implementation — schema + suite + fixtures + CI wiring):
- Write the acceptance checks first (`acceptance-first`, per risk-gate-
  matrix medium tier — author the fixture-level acceptance checks before
  the schema they exercise, no formal Red→Green TDD cycle required):
  TEST-017 (existence + `$id` convention), TEST-018
  (all-Capabilities-recorded, exact-set — as a schema-conformant-vs.-
  malformed fixture pair, not a live-Registry check, which is T-005's own
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
  (T-005, which read and enforce this schema but is a separate component
  with its own closed check-id enum), and every other test suite (T-002
  through T-007).
- Any live-Registry or live-Resolver-invocation fixture — every fixture
  this task authors is a hand-crafted instance validated directly
  against this task's own schema document.

### Blockers

None

---

## T-002 Author `resolve-project-context.{py,sh,ps1}`'s core evaluation engine (steps 0-13)

Source Issue: https://github.com/aharada54914/sdd-forge/issues/193

Approval: Draft

Status: Planned

Risk: high

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly, not defaulted. `high` is justified: this task authors the
resolver every downstream Facet Manifest/Capability Summary/Resolver
Evidence instance depends on — the union-match rule, the facet-name
aggregation rule, and the any-branch WARN-Block scope (design.md Design
Decisions) are this feature's own new orchestration decisions with no
upstream contract fixing them (design.md ADR Change Log items 1-3); a
silent misclassification here (an under-matched Capability, a
WARN-producing branch that silently collapses to `false`, requirements.md
Risks) defeats decision document v2 §19's own "曖昧な場合は Block"
governing rule, exactly the "silent defect causes material harm" surface
the policy's `high` tier names. It is not `critical` because this task's
own scope (steps 0-13, staging only) writes nothing to a live path by
itself — T-004 owns the one step (14) with an irreversible filesystem
effect. Required Workflow is `tdd` per the policy's high-tier row.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-001 (steps 0-13 — the core evaluation engine only; the
CLI required-flag-matrix's own dedicated coverage (AC-001), the
discovery-contract-reuse suite's own dedicated coverage (AC-002/AC-028),
and the Lite-track suite's own dedicated coverage (AC-009) are each
T-004's own, exercised against this task's own already-authored engine —
task-review round-1 remedy, closing a TASK-SIZE finding), REQ-002 (share
— twelve of sixteen non-transactional diagnostic-id rows:
`disabled-legacy-invocation`, `workflow-combination-invalid`,
`project-context-validation-failed`, `affected-component-resolution-
failed`, `registry-validation-failed`, `contract-discovery-failed`,
`canonicalizer-invocation-failed`, `dependency-subprocess-failed`,
`dependency-output-malformed`, `dsl-warn-on-matched-capability`,
`lite-check-source-undefined`, `output-schema-validation-failed`,
`snapshot-generation-mismatch` — the sole step-13 row also lands here
since step 13 is this task's own last step; the twelve-fixture suite
that exercises this set is T-003's own, task-review round-2 remedy,
closing a second TASK-SIZE finding; the three step-0/14 transactional
rows are T-005's own), REQ-003 (state derivation), REQ-004 (share —
Resolver Evidence assembly logic; schema is T-001's own), REQ-005 (share
— determinism baseline: stable sort, no clock/network/provider-API
reads in this task's own code), REQ-006 (share — fixture-matrix items
a-d, f, g — item e's own fixture suite is T-003's/T-005's), REQ-008
(share — CHANGELOG)

Depends On: T-001 (step 12's own output-schema self-validation validates
the staged Resolver Evidence instance against T-001's own schema before
this task's own suite can assert AC-055/AC-012 against a real staged
instance). **Assumption re-verified at this task's own start time,
not merely inherited from requirements.md** (requirements.md
Assumptions; design.md Assumptions): Epic A1's `canonicalize-sdd-yaml`,
Epic A2's `evaluate-predicate`/`generate-registry-digest`/ADR-0025
discovery, and Epic A3's `resolve-component-paths` must each be present,
landed unmodified from their own `Spec-Review-Status: Passed` contracts,
in this repository before this task's own `match` suite can execute
meaningfully (this task's own script invokes them as real subprocesses,
not mocked stand-ins, matching this Epic set's own established
integration-test convention) — if any is absent at this task's own
implementation-start time, this task is blocked pending that sibling
epic's own landing, per requirements.md Assumptions.

Planned Files:
- `specs/epic-193-a5-capability-resolver/human-copy/plugins/sdd-quality-
  loop/scripts/resolve-project-context.py` (new staged candidate,
  agent-editable — see "Protected Files" above for the live-repository
  branch check; developed unprotected-first at a non-protected location
  before staging)
- `specs/epic-193-a5-capability-resolver/human-copy/plugins/sdd-quality-
  loop/scripts/resolve-project-context.sh` (new staged candidate —
  thin dispatcher, `python3`/`python` resolution only, no native
  fallback, matching `canonicalize-sdd-yaml`'s own dispatch shape)
- `specs/epic-193-a5-capability-resolver/human-copy/plugins/sdd-quality-
  loop/scripts/resolve-project-context.ps1` (new staged candidate —
  twin)
- `specs/epic-193-a5-capability-resolver/human-copy/MANIFEST.sha256`
  (edited — three new SHA-256 entries for the staged script candidates)
- `tests/resolve-project-context-match.tests.sh` / `.ps1` (new)
- `tests/fixtures/capability-resolver/` (new fixture tree — match
  fixtures only; design.md Test Strategy item 3; the Block-diagnostic
  fixture tree is T-003's own)
- `tests/run-all.sh` / `.ps1` (existing, agent-editable — one suite's
  registration: match)
- `specs/epic-193-a5-capability-resolver/human-copy/.github/workflows/
  test.yml` (appended, agent-editable — this task's own one suite's CI
  steps)
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
implementing API / Contract Plan steps 0 through 13: argument validation
and `--feature` pattern check (exit 2 on failure — implemented here; its
own dedicated required-flag-matrix test suite is T-004's own); state
derivation (REQ-003, `disabled-legacy-invocation` short-circuit before
any Registry/ownership/Context-Projection work); `workflow-combination-
invalid` check (M3); Project Context canonicalization and its own
`project-context-validation-failed` structural re-validation; Context
Projection assembly (Epic A4's own two-pass-canonicalizer procedure,
verbatim, staged only); `resolve-component-paths` invocation
(`affected-component-resolution-failed` on non-zero exit) with its own
snapshot; Registry discovery via ADR-0025 (`contract-discovery-failed`,
`registry-validation-failed`, implemented here — its own dedicated
discovery-contract-reuse test suite is T-004's own) and `registry_digest
--whole`; per-Capability, per-affected-component trigger evaluation and
matched-Capability conditional-facet evaluation, both with no
short-circuit (`canonicalizer-invocation-failed`/`dependency-subprocess-
failed`/`dependency-output-malformed` on any dependency subprocess
failure — this evaluation logic's own Block-diagnostic test coverage,
including the twelve-fixture non-transactional Block matrix, is T-003's
own, exercised against this task's own already-authored engine —
task-review round-2 remedy, closing a second TASK-SIZE finding); the
any-branch WARN check (`dsl-warn-on-matched-capability`, B2's widened
scope); the track branch (before any publication, B4) staging a Facet
Manifest (`full`) or a Capability Summary (`lite`, subject to
`lite-check-source-undefined`, narrowed per the cross-epic B5 addendum,
implemented here — its own dedicated Lite-track test suite is T-004's
own); Resolver Evidence assembly (every capability, every diagnostic,
canonical `dependency_pointers[]`/`resolver.version`/`resolver.
rule_set_revision`, B9); output schema self-validation against every
staged artifact's own governing schema (`output-schema-validation-
failed`, with the self-referential Evidence-fails-its-own-check
exception writing nothing, B3); and the pre-publication snapshot recheck
(`snapshot-generation-mismatch`, re-deriving `affected_components` as
well as re-hashing every snapshot, B8). This task stages every artifact
in memory only — it never performs step 14's own live commit (T-005's
own scope).

### Must Read

- `specs/epic-193-a5-capability-resolver/requirements.md` (REQ-001
  through REQ-003, REQ-005, REQ-006 items a-d/f/g, Dependencies, Edge
  Cases, Field Definitions, Main Workflows 1-4)
- `specs/epic-193-a5-capability-resolver/design.md` (`## Architecture`;
  `## Components`; `### resolve-project-context.{py,sh,ps1} CLI contract
  (REQ-001)`, steps 0-13; `## Design Decisions` — union-match,
  facet-name aggregation, any-branch WARN scope; `## Test Strategy`
  item 3; `## Global Constraints`; `## Security Boundaries`)
- `specs/epic-193-a5-capability-resolver/acceptance-tests.md` (AC-003
  through AC-008, AC-016, AC-043, AC-044, AC-052, AC-056 — this task's
  own `match` suite; AC-010 through AC-015, AC-038, AC-040, AC-041,
  AC-048, AC-055 are cited for the diagnostic *behavior* this task's own
  code must implement correctly, even though their own dedicated test
  suite is T-003's)
- `specs/epic-193-a5-capability-resolver/investigation.md` (INV-003,
  INV-005 through INV-013, INV-019, INV-020)
- `specs/epic-193-a5-capability-resolver/security-spec.md`
  (`#trust-boundaries`)
- Epic A1's `canonicalize-sdd-yaml` CLI contract, Epic A2's `evaluate-
  predicate`/`generate-registry-digest`/ADR-0025 discovery contract, and
  Epic A3's `resolve-component-paths` CLI contract (the four already-
  fixed upstream contracts this task's own script invokes verbatim)
- `docs/adr/0016-workflow-axes-separation.md`, `docs/adr/0020-
  conditional-predicate-dsl.md`, `docs/adr/0021-context-projection-
  staleness.md`

### Scope

Commit A (implementation — engine + one suite + fixture tree + CI
wiring):
- Write the acceptance checks first (TDD Red→Green): TEST-003 (Context
  Projection byte-identity), TEST-004 (`resolve-component-paths`
  pass-through), TEST-005 (`registry_digest --whole` binding), TEST-006
  (union-match), TEST-007 (field-assembly conformance), TEST-008 (Facet
  Manifest schema-conformance), TEST-016 (advisory/required byte-
  identity, excluding the `lite-check-source-undefined` divergent
  branch), TEST-043 (cross-Capability facet-name aggregation), TEST-044
  (provenance canonicalization — `dependency_pointers[]`/`resolver.
  version`/`resolver.rule_set_revision`), TEST-052 (same-Capability
  duplicate-facet predicate-instance), TEST-056 (`diagnostics[]`
  warn/block cardinality). This task's own suite exercises the engine's
  match/no-match/aggregation/WARN/provenance behavior; the twelve-
  fixture non-transactional Block-diagnostic matrix this same engine
  code must also correctly implement (`disabled-legacy-invocation`
  through `snapshot-generation-mismatch`) is proven Red→Green by T-003's
  own suite against this task's already-authored engine, not duplicated
  here (task-review round-2 remedy, closing a second TASK-SIZE finding
  — see Global Constraints, "Task-decomposition note, round 2").
- Author `resolve-project-context.py` (steps 0-13) + `.sh`/`.ps1`
  wrappers per the Protected Files branch this task's own start-time
  check selects — including the diagnostic-emitting code paths for all
  twelve non-transactional REQ-002 rows, even though this task's own
  Red→Green suite does not directly exercise them.
- CI resilience and diagnostic determinism per Global Constraints (UTF-8/
  no-BOM/LF-only; no dependency subprocess's own raw stderr ever
  embedded in a `<detail>` field, M8).
- Register `resolve-project-context-match` (`.sh`/`.ps1`) in `tests/
  run-all.sh`/`.ps1`; stage the `.github/workflows/test.yml` candidate
  with this suite's CI steps under `human-copy/`, appending to T-001's
  own staged candidate; update `MANIFEST.sha256` with this task's own
  three staged script entries plus the appended `test.yml` entry.

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
- [ ] **Diagnostic-emitting code paths implemented (verified by T-003,
  not this task)** — every one of the twelve non-transactional REQ-002
  diagnostic rows (`disabled-legacy-invocation` through
  `snapshot-generation-mismatch`) has a correct code path in this task's
  own script, ready for T-003's own Red→Green suite to exercise; this
  task's own Done When does not itself require those fixtures passing —
  that is T-003's own Done When (AC-010 [twelve of sixteen], AC-011
  [share], AC-012 [share], AC-013, AC-014 [share], AC-015, AC-038
  [share], AC-040 [share, first fixture], AC-041, AC-048, AC-055).
- [ ] **Fixture + suite/CI registration** — `tests/resolve-project-
  context-match.tests.sh`/`.ps1` self-registers in `tests/run-all.sh`/
  `.ps1` (grep self-check); the staged `.github/workflows/test.yml`
  candidate carries this task's own one suite's steps appended after
  T-001's, with correct `MANIFEST.sha256` entries; the LIVE `test.yml`
  is byte-unchanged before/after this task's own commits.
- [ ] **Governance** — `CHANGELOG.md` gains a NEW `## Unreleased` entry
  citing #193 (AC-033 share); no version string mutated outside
  `scripts/bump-version.sh` (AC-034 share); `git diff --stat` confirms no
  path under `plugins/**` in either of this task's own commits (AC-032).
- [ ] **TDD evidence** — RED (each `match`-suite fixture against a
  deliberately broken pipeline) and GREEN (the full suite against the
  correct pipeline). An independent quality-gate verdict records PASS.

### Out of Scope

- The twelve-fixture non-transactional Block-diagnostic suite
  (AC-010..AC-015, AC-038, AC-040 [first fixture], AC-041, AC-048,
  AC-055, `tests/resolve-project-context-block.tests.sh`/`.ps1`) — this
  task implements every diagnostic-emitting code path it exercises, but
  its own dedicated test suite is T-003's own (task-review round-2
  remedy, closing a second TASK-SIZE finding).
- The CLI required-flag-matrix suite (AC-001, TEST-001), the discovery-
  contract-reuse suite (AC-002/AC-028, TEST-002/TEST-028), and the
  Lite-track suite (AC-009, TEST-009) — this task implements the code
  each of these exercises (argument validation, ADR-0025 discovery,
  Lite-track staging), but their own dedicated test suites are T-004's
  own (task-review round-1 remedy, closing the first TASK-SIZE finding).
- Step 0's own crash-recovery scan and step 14's own journaled
  publication transaction/commit (T-005's own scope) — this task's
  script stages every artifact in memory only and never performs a live
  filesystem rename of any of them.
- `publication-journal-recovery`, `artifact-publication-failed`, and
  `post-publication-generation-mismatch` (T-005's own three diagnostic
  rows).
- `validate-resolver-evidence` (T-006), the dual-runtime parity suite
  (T-007), and the metamorphic completeness suite (T-008).
- `contracts/resolver-evidence.schema.json` itself (T-001's own
  deliverable — this task only consumes it at step 12).
- Any edit to `plugins/**`, including `sdd-bootstrap-interviewer/
  SKILL.md` — REQ-007's target integration contract remains
  design-only (Non-goals; see "Deferred, Not Scheduled", Global
  Constraints).

### Blockers

T-001

---

## T-003 Author `resolve-project-context`'s non-transactional Block-diagnostic test suite

Source Issue: https://github.com/aharada54914/sdd-forge/issues/193

Approval: Draft

Status: Planned

Risk: medium

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. `medium`: this task adds no new production code path of its
own — it exercises T-002's own already-authored engine's diagnostic-
emitting code paths from twelve independent angles — a defect here is a
false-negative test-coverage gap (a REQ-002 diagnostic condition going
unverified), not itself a source of production-time silent
misclassification, matching T-004's/T-006's/T-007's own identical
"test-only task" rationale (task-review round-1 remedy precedent). Not
`low`: this suite proves decision document v2 §19's own governing
"曖昧な場合は Block" rule for twelve of its sixteen concrete conditions —
a gap here would let one of those Block conditions ship silently
unverified, exactly the surface T-002's own `high` classification names
as consequential. Required Workflow is `acceptance-first` per the
risk-gate-matrix's own medium-tier row (`tdd` is reserved for
high/critical).

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-002 (share — twelve of sixteen non-transactional
diagnostic-id rows, exercising T-002's own already-authored engine; the
four transactional rows are T-005's own — task-review round-2 remedy,
closing a TASK-SIZE finding on the original round-1-remedied T-002),
REQ-006 (share — fixture-matrix item e's twelve non-transactional rows),
REQ-008 (share — CHANGELOG)

Depends On: T-002 (needs the core evaluation engine's own diagnostic-
emitting code paths to already exist to test against; this task's own
fixtures invoke `resolve-project-context` as a real subprocess).

Planned Files:
- `tests/resolve-project-context-block.tests.sh` / `.ps1` (new — the
  twelve non-transactional diagnostic fixtures only; T-005 appends four
  more transactional-diagnostic fixtures to this same file later)
- `tests/fixtures/capability-resolver/` (extended — the twelve block
  fixtures; design.md Test Strategy item 2, non-transactional portion)
- `tests/run-all.sh` / `.ps1` (existing, agent-editable — this suite's
  registration)
- `specs/epic-193-a5-capability-resolver/human-copy/.github/workflows/
  test.yml` (appended, agent-editable — this suite's CI steps, appended
  after T-002's own)
- `specs/epic-193-a5-capability-resolver/human-copy/MANIFEST.sha256`
  (edited — appended entry)
- `CHANGELOG.md` (existing, agent-editable — CREATE the `## Unreleased`
  entry citing #193)

Data Migration: none.

Breaking API: no; this task adds only test files and fixtures — it never
edits `resolve-project-context.{py,sh,ps1}` itself.

Rollback: revert this task's two commits (B then A, or both). Nothing
protected is touched.

### Goal

Author `resolve-project-context-block`'s twelve non-transactional
diagnostic-id fixtures (`disabled-legacy-invocation`, `workflow-
combination-invalid`, `project-context-validation-failed`,
`affected-component-resolution-failed`, `registry-validation-failed`,
`contract-discovery-failed`, `canonicalizer-invocation-failed`,
`dependency-subprocess-failed`, `dependency-output-malformed`,
`dsl-warn-on-matched-capability`, `lite-check-source-undefined`,
`output-schema-validation-failed`, `snapshot-generation-mismatch` [first,
digest-mismatch fixture only — the `affected_components`-set-only
companion fixture is T-005's own]), each independently triggerable, each
asserting correct exit code, correct diagnostic line, no partial
artifact, and correct Resolver Evidence content — exercising T-002's own
already-authored engine.

### Must Read

- `specs/epic-193-a5-capability-resolver/requirements.md` (REQ-002 in
  full)
- `specs/epic-193-a5-capability-resolver/design.md` (`## Test Strategy`
  item 2, non-transactional rows; `## API / Contract Plan`, the
  sixteen-row Block diagnostic-id table)
- `specs/epic-193-a5-capability-resolver/acceptance-tests.md` (AC-010
  through AC-015, AC-038, AC-040 [first fixture], AC-041, AC-048,
  AC-055)

### Scope

Commit A (implementation — suite + fixtures + CI wiring):
- Write the acceptance checks first (`acceptance-first`, per risk-gate-
  matrix medium tier): TEST-010 (twelve non-transactional Block
  fixtures, exit code + diagnostic line + no-partial-artifact + Evidence
  content each), TEST-011/TEST-012/TEST-013/TEST-014/TEST-015 (scoped to
  these twelve fixtures), TEST-038 (staged-generation lock for
  `lite-check-source-undefined`/`output-schema-validation-failed`/
  `snapshot-generation-mismatch`), TEST-040 (first fixture — digest-
  mismatch `snapshot-generation-mismatch`), TEST-041 (both
  `workflow-combination-invalid` rows), TEST-048 (pre-publication
  `affected_components` re-derivation lock), TEST-055 (`output-schema-
  validation-failed` dual-artifact-scope, both sub-cases).
- Register `resolve-project-context-block` (`.sh`/`.ps1`) in `tests/
  run-all.sh`/`.ps1`; stage the `.github/workflows/test.yml` candidate
  with this suite's CI steps under `human-copy/`, appended after T-002's
  own; update `MANIFEST.sha256`.

Commit B (documentation):
- CREATE the `CHANGELOG.md` `## Unreleased` entry citing #193.

### Done When

- [ ] **Non-transactional Block matrix (twelve of sixteen rows)** —
  TEST-010..TEST-015 pass for `disabled-legacy-invocation`,
  `workflow-combination-invalid`, `project-context-validation-failed`,
  `affected-component-resolution-failed`, `registry-validation-failed`,
  `contract-discovery-failed`, `canonicalizer-invocation-failed`,
  `dependency-subprocess-failed`, `dependency-output-malformed`,
  `dsl-warn-on-matched-capability`, `lite-check-source-undefined`,
  `output-schema-validation-failed`, `snapshot-generation-mismatch`:
  correct exit code, correct diagnostic line (never raw dependency
  stderr, M8), no partial artifact, correct Resolver Evidence content
  (AC-010 [twelve of sixteen], AC-011 [share], AC-012 [share], AC-013,
  AC-014 [share], AC-015). TEST-038/TEST-040/TEST-041/TEST-048/TEST-055
  pass for this task's own diagnostics (AC-038, AC-040, AC-041, AC-048,
  AC-055).
- [ ] **Fixture + suite/CI registration** — self-registers in `tests/
  run-all.sh`/`.ps1`; staged `.github/workflows/test.yml` candidate
  carries this suite's steps appended after T-002's own, with a correct
  `MANIFEST.sha256` entry; LIVE `test.yml` byte-unchanged before/after.
- [ ] **Governance** — `CHANGELOG.md` gains a NEW `## Unreleased` entry
  citing #193 (AC-033 share); no version string mutated outside
  `scripts/bump-version.sh` (AC-034 share); `git diff --stat` confirms
  no path under `plugins/**` (AC-032).
- [ ] **Acceptance evidence** — every fixture written before the
  behavior it exercises, failing against a deliberately regressed
  engine (a diagnostic that silently stops firing, or fires with the
  wrong id/exit-code) and passing against T-002's own correct engine
  (`acceptance-first`, no formal Red→Green TDD cycle required at
  `medium` tier). An independent quality-gate verdict records PASS.

### Out of Scope

- Any change to `resolve-project-context.{py,sh,ps1}` itself — this task
  only adds tests/fixtures exercising the engine T-002 already built.
- The `resolve-project-context-match` suite (T-002's own), the CLI/
  discovery/lite suites (T-004's own), the four transactional diagnostic
  rows and the second `snapshot-generation-mismatch` fixture (T-005's
  own), `validate-resolver-evidence` (T-006), the parity suite (T-007),
  and the metamorphic suite (T-008).

### Blockers

T-002

---

## T-004 Author `resolve-project-context`'s CLI-validation, discovery-contract, and Lite-track test suites

Source Issue: https://github.com/aharada54914/sdd-forge/issues/193

Approval: Draft

Status: Planned

Risk: medium

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. `medium`: this task adds no new production code path of its
own — it exercises T-002's own already-authored core engine from three
additional angles (CLI usage-error surface, discovery-contract reuse,
Lite-track output-set exclusivity) — a defect here is a false-negative
test-coverage gap for a surface the engine itself already implements,
not itself a source of production-time silent misclassification. Not
`low`: the Lite-track suite specifically proves the track-exclusive
publication-set guarantee (B4 — a Lite resolve never also writes
`facet-manifest.yaml`/`project-context.resolved.json`), one of this
feature's own adversarially-reviewed corrections to an earlier revision
that violated Epic A4's own track-exclusive Capability Summary contract;
a gap here would let that regression ship silently. Required Workflow is
`acceptance-first` per the risk-gate-matrix's own medium-tier row (`tdd`
is reserved for high/critical).

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-001 (share — AC-001 CLI required-flag matrix, AC-002/
AC-028 discovery-contract reuse, AC-009 Lite-track schema-conformance:
three of REQ-001's own test surfaces, split out of T-002 by task-review
round-1 remedy, closing a TASK-SIZE finding), REQ-006 (share — fixture-
matrix items covering the discovery-contract and Lite-track portions),
REQ-008 (share — CHANGELOG)

Depends On: T-002 (needs the core evaluation engine — argument
validation, ADR-0025 discovery, Lite-track staging — to already exist to
test against). Carries forward T-002's own re-verified Assumption: Epic
A1/A2/A3's already-`Spec-Review-Status: Passed` CLIs must be present in
this repository for this task's own suites to execute meaningfully (this
task's own fixtures invoke `resolve-project-context` as a real
subprocess).

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
  CI steps, appended after T-002's own)
- `specs/epic-193-a5-capability-resolver/human-copy/MANIFEST.sha256`
  (edited — appended entry for the `test.yml` candidate update)
- `CHANGELOG.md` (existing, agent-editable — CREATE the `## Unreleased`
  entry citing #193)

Data Migration: none.

Breaking API: no; this task adds only test files and fixtures — it never
edits `resolve-project-context.{py,sh,ps1}` itself.

Rollback: revert this task's two commits (B then A, or both). Nothing
protected is touched (this task never edits the human-copy script
candidates T-002 already staged).

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
test suites, each exercising T-002's own already-authored core engine.

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
  steps under `human-copy/`, appending to T-002's own staged candidate;
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
  suites' steps appended after T-002's own, with a correct
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
  only adds tests/fixtures exercising the engine T-002 already built.
- The `resolve-project-context-match` suite (T-002's own), the
  non-transactional Block-diagnostic suite (T-003's own),
  `validate-resolver-evidence` (T-006), the parity suite (T-007), and
  the metamorphic suite (T-008).

### Blockers

T-002

---

## T-005 Layer the Resolver publication transactional bundle contract onto `resolve-project-context.{py,sh,ps1}`

Source Issue: https://github.com/aharada54914/sdd-forge/issues/193

Approval: Draft

Status: Planned

Risk: high

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. `high` is justified and, unlike T-002, also touches a genuine
irreversible-filesystem surface: this task authors the ONLY code path in
this feature that ever writes a live artifact — a defect here (a crash
between two renames left unrecovered, an `unlink`-based rollback that
destroys pre-existing live bytes with no restore, adversarial review "B1
atomicity") can silently corrupt or lose a Feature's own already-published
Facet Manifest/Capability Summary/Resolver Evidence, exactly the kind of
"material harm from a silent defect" the policy's `high` tier names, and
the closest this feature comes to a `critical`-adjacent surface (still
`high`, not `critical`, because no financial-settlement or physical-safety
surface is touched, matching this Epic set's own established `high`
ceiling for classification/publication-integrity work, e.g. Epic A3
T-001's identical rationale). Required Workflow is `tdd` per the policy's
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

Depends On: T-002 (extends the same `resolve-project-context.{py,sh,
ps1}` script with the commit-phase logic; T-002's own staged-artifact
assembly is this task's own transaction's input), T-003 (this task
appends its own four transactional-diagnostic fixtures to T-003's own
already-registered `resolve-project-context-block.tests.sh`/`.ps1` file
— task-review round-2 remedy, correcting a DEPENDENCY-OVERLAP finding on
an earlier revision that omitted this real dependency).

Planned Files:
- `specs/epic-193-a5-capability-resolver/human-copy/plugins/sdd-quality-
  loop/scripts/resolve-project-context.py` (updated staged candidate —
  adds the crash-recovery scan and the journaled publication
  transaction; re-verify this path's own then-current protection status
  per "Protected Files" above, since T-002's own human-copy application
  may or may not have already been applied by a human at this task's
  own start time)
- `specs/epic-193-a5-capability-resolver/human-copy/plugins/sdd-quality-
  loop/scripts/resolve-project-context.sh` / `.ps1` (updated staged
  candidates — twins)
- `specs/epic-193-a5-capability-resolver/human-copy/MANIFEST.sha256`
  (edited — updated SHA-256 entries for the three updated staged
  candidates)
- `tests/resolve-project-context-block.tests.sh` / `.ps1` (edited —
  appends the four transactional-diagnostic fixtures to T-003's own
  file; no new suite registration)
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
hand-revert that applied content back to T-002's own prior version.

### Goal

Layer API / Contract Plan step 14 ("Resolver publication transactional
bundle contract") onto T-002's own staged-artifact pipeline: the
mandatory crash-recovery scan (runs on every invocation, immediately
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
  injected source mutation after the pre-publication recheck (T-002's
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
  all sixteen REQ-002 diagnostic-id rows across T-002's twelve and this
  task's four, plus one fully-clean fixture proving a negative
  (AC-010); TEST-011/TEST-012/TEST-014 are now complete across all
  sixteen rows (AC-011, AC-012, AC-014); TEST-038 now covers every
  named staged-generation example (AC-038).
- [ ] **Staged-generation/journaled-transactional-publication lock** —
  TEST-038 confirms no earlier-staged artifact from ANY Block fixture
  (T-002's or this task's own) ever reached a live path (AC-038,
  complete).
- [ ] **Governance** — `CHANGELOG.md` gains a NEW `## Unreleased` entry
  citing #193 (AC-033 share); no version string mutated outside
  `scripts/bump-version.sh` (AC-034 share); `git diff --stat` confirms
  no path under `plugins/**` in either of this task's own commits
  (AC-032).
- [ ] **TDD evidence** — RED (each transactional fixture against a
  deliberately broken commit/recovery path) and GREEN (the full suite).
  An independent quality-gate verdict records PASS.

### Out of Scope

- Steps 0-13's own evaluation logic (T-002's own scope) — this task
  never changes the union-match rule, the facet-name aggregation rule,
  the WARN check, or any of the twelve non-transactional diagnostic
  rows.
- `validate-resolver-evidence` (T-006), the parity suite (T-007), the
  metamorphic suite (T-008).
- Registering a new test suite in `tests/run-all.*` or staging a new
  `.github/workflows/test.yml` CI step — this task only edits fixtures
  inside T-002's already-registered `resolve-project-context-block`
  suite.

### Blockers

T-002, T-003

---

## T-006 Author `validate-resolver-evidence.{py,sh,ps1}` and its provenance-binding suite

Source Issue: https://github.com/aharada54914/sdd-forge/issues/193

Approval: Draft

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
enforces), T-005 (the reader-side `RESOLVER_PUBLICATION_IN_PROGRESS`
journal check, AC-054, needs a real `TRANSACTION.json` shape identical to
T-005's own journal format to fixture against; realistic Resolver
Evidence/Facet-Manifest sibling-artifact fixtures for the provenance-
binding checks are likewise most directly produced by T-002/T-005's own
working pipeline, though hand-crafted fixtures suffice where a real
invocation is impractical).

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
  suite's CI steps under `human-copy/`, appended after T-004's own (the
  last suite-owning task before this one — T-005 registers no new suite);
  update `MANIFEST.sha256`.

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
  carries this suite's own steps appended after T-004's own, with a
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

- `resolve-project-context` itself (T-002/T-005) — this task never
  re-runs any predicate evaluation; every check is structural/set-
  membership/provenance-binding against already-recorded evidence.
- The dual-runtime parity suite (T-007) and the metamorphic completeness
  suite (T-008), though both depend on this task's own validator.
- Extending `contracts/resolver-evidence.schema.json` itself (T-001's
  own, content-frozen-once-passed deliverable) — `schema-invalid` reads
  it, never edits it.

### Blockers

T-001, T-005

---

## T-007 Author the dual-runtime parity and determinism suite

Source Issue: https://github.com/aharada54914/sdd-forge/issues/193

Approval: Draft

Status: Planned

Risk: medium

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. `medium`: this task adds no new production code path of its
own (it is a test suite exercising T-002/T-003/T-004/T-005/T-006's own
already-built scripts across runtimes) — a defect here is a
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

Depends On: T-002 (core evaluation engine), T-003 (design.md Test
Strategy item 5 requires byte-identical parity "across every fixture
above" — items 1-4, which include T-003's own non-transactional Block
fixtures), T-004 (item 1's own CLI fixtures and item 6's own discovery
fixtures — task-review round-2 remedy, correcting a DEPENDENCY-OVERLAP
finding on an earlier revision that omitted this real dependency), T-005
(needs the full evaluation-plus-publication pipeline, every track, every
diagnostic, to compare across `.py`/`.sh`/`.ps1`), T-006
(`validate-resolver-evidence` has its own `.py`/`.sh`/`.ps1` triad and
participates in this same parity guarantee).

Planned Files:
- `tests/resolve-project-context-parity.tests.sh` / `.ps1` (new)
- `tests/fixtures/capability-resolver/parity/` (new — reuses fixture
  inputs from T-002/T-003/T-004/T-005/T-006's own suites where
  practical; includes at least one Windows-style, `\`-separated path
  argument)
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
  with this suite's CI steps under `human-copy/`, appended after T-006's
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
  carries this suite's steps appended after T-006's own, with a correct
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
  T-006 already built.
- The metamorphic completeness suite (T-008).

### Blockers

T-002, T-003, T-004, T-005, T-006

---

## T-008 Author the metamorphic completeness suite

Source Issue: https://github.com/aharada54914/sdd-forge/issues/193

Approval: Draft

Status: Planned

Risk: medium

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. `medium`, for the identical reason T-007 is `medium`: this task
adds no new production code path (it exercises T-002/T-005/T-006's own
already-built scripts from additional angles) — a gap here is a
false-negative coverage gap for the completeness/invariance properties
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

Depends On: T-002, T-005 (the full evaluation-plus-publication pipeline
this suite's own TT/TF/FT/FF and order-permutation fixtures exercise),
T-006 (`validate-resolver-evidence`'s own exact-set checks are this
suite's own assertion mechanism for the nested-array-completeness
fixture, item (f) below).

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
  after T-007's own (the final entry in this feature's own staged
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
  carries this suite's steps appended after T-007's own (the final
  entry), with a correct `MANIFEST.sha256` entry; LIVE `test.yml`
  byte-unchanged before/after.
- [ ] **Governance** — `CHANGELOG.md` gains a NEW `## Unreleased` entry
  citing #193 (AC-033 share); no version string mutated outside
  `scripts/bump-version.sh` (AC-034 share); `git diff --stat` confirms
  no path under `plugins/**` (AC-032).
- [ ] **Feature-wide fixture-matrix completeness** — a final check
  confirms every REQ-006 fixture-matrix item (a-h) and every one of the
  nine suites T-001..T-008 build is present and independently invocable
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

T-002, T-005, T-006
