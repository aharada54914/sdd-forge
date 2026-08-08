# Tasks: epic-190-a2-capability-registry

Task-Review-Status: Passed

Source: Issue #190 (Epic A2 — Capability Registry), tracked under epic #187
(AI-DLC Foundation) /
requirements.md (Spec-Review-Status: Passed) /
design.md (Impl-Review-Status: Passed)

## Lifecycle

`Draft -> Approved -> In Progress -> Implementation Complete -> Done`

A task may enter `Blocked` from any active state. Humans approve tasks.
`implement-task` may set `In Progress`, `Blocked`, or `Implementation
Complete`. Only `quality-gate` may set `Done`.

## Protected Files

This feature registers new protected paths under R-10 enforcement
(`guard-invariants.json`'s self-hosting protection, INV-009) but does not
touch `check-contract.{sh,ps1,py}`'s required-check-set or
`risk-gate-matrix.md` — unlike other Epics in this repository, Epic A2
introduces no new Gate check of its own into the tier-minimum matrix;
`validate-capability-registry`, `evaluate-predicate`, and
`generate-registry-digest` are standalone primitives, not
`check-contract`-enforced Gates (design.md Protected-File Statement names
only the registration category below).

**One protected-file registration category, staged entirely by T-006 (sole
editor):**

`plugins/sdd-quality-loop/scripts/generate-guard-invariants.py`'s
`load_and_validate()` performs an **exact-match** check between the JSON
source's `protected_gate_suffixes`/`phase2_human_copy_targets` arrays and
its own hardcoded `PHASE2_TARGETS` tuple
(`generate-guard-invariants.py:37-56` defines the tuple;
`:145-147` derives `expected_protected` from it and rejects any JSON whose
`protected_gate_suffixes` diverges; `:153-157` requires
`phase2_human_copy_targets` to equal `PHASE2_TARGETS` exactly). Editing
`guard-invariants.json` alone (design.md's literal Protected-File Statement
text) is therefore insufficient — `generate-guard-invariants.py` itself
must be edited in the same staged change so `PHASE2_TARGETS` gains the
identical seven new entries, mirroring the INV-015 pattern this repository
already applies elsewhere (`specs/epic-191-a3-path-ownership/tasks.md`
Protected Files, situation 1). Seven new paths, all staged under
`specs/epic-190-a2-capability-registry/human-copy/` with a
`MANIFEST.sha256` entry each, for a human to `cp` into place (ADR-0011
pattern):

1. `contracts/capability-registry.schema.json` (T-001)
2. `contracts/capability-registry.json` (T-001)
3. `contracts/lite-upgrade-reason-catalog.json` (T-001)
4. `plugins/sdd-quality-loop/scripts/generate-gate-capabilities.py` (T-006)
5. `plugins/sdd-quality-loop/scripts/generated/gate-capabilities.json`
   (T-006)
6. `plugins/sdd-quality-loop/contracts/capability-registry.json` (T-003,
   vendored copy)
7. `plugins/sdd-quality-loop/contracts/capability-registry.schema.json`
   (T-003, vendored copy)

Six files carry the staged edit itself: `guard-invariants.json`,
`generate-guard-invariants.py`, `generated/guard_invariants.py`, and its
three `generated/guard-invariants.generated.{js,ps1,sh}` siblings
(regenerated to match). **T-006 is the sole editor of this bundle within
this feature** — T-001 and T-003 create paths 1-3 and 6-7 directly as
ordinary, not-yet-protected new files (a path cannot be R-10-protected
before `guard-invariants.json` names it), and T-006 registers all seven at
once after they exist, avoiding the staging race Global Constraints,
below, calls out.

**No task authors or edits `plugins/sdd-quality-loop/references/
risk-gate-matrix.md`, `check-contract.{sh,ps1,py}`, or
`.github/workflows/test.yml`'s CI-step registration is** — wait, correcting:
`.github/workflows/test.yml` registration for the eight new
`tests/*.tests.sh`/`.tests.ps1` pairs (REQ-006) **is** required and **is**
R-10 protected (INV-009); it is staged the same way, appended by each
task's own suite in serialized order (Global Constraints), sharing the one
`specs/epic-190-a2-capability-registry/human-copy/.github/workflows/test.yml`
staged candidate and its own `MANIFEST.sha256` entries.

`tests/run-all.sh`/`.ps1` are **not** protected (INV-014) — new suite
registration there is a direct agent edit, one array-append per task.

**No task authors a new ADR.** ADR-0025 (`docs/adr/
0025-registry-discovery-contract.md`) already exists, accepted 2026-07-21
during the design phase (design.md ADR Change Log) — no implementation
task drafts it.

## Global Constraints

- **Serialized order T-001 → T-002 → T-003 → T-004 → T-005 → T-006 → T-007**
  for every shared-resource append: the `tests/run-all.sh`/`.ps1` array
  (each task appends only its own suite's registration line) and the one
  staged `.github/workflows/test.yml` candidate under `human-copy/` (each
  task appends its own suite's CI steps to whatever the previous task
  already staged, or to the unmodified real file if the previous task's
  candidate has already been human-applied). This ordering is followed even
  where two adjacent tasks have no functional dependency on each other
  (e.g. T-001→T-002) — Global Constraints' shared-array/shared-file
  contention is itself the dependency, per each task's own Blockers
  rationale below, matching this repository's own established convention
  (`specs/epic-191-a3-path-ownership/tasks.md` Global Constraints).
- **`generate-guard-invariants.py` + `guard-invariants.json` + generated
  siblings (Protected Files, above, seven paths / six staged files):
  T-006 is the sole editor** within this feature, staged via human-copy
  after T-001's and T-003's new files exist.
- **Version bumps only via `scripts/bump-version.sh`**; this feature
  introduces no version-mutation path. No task hand-edits a version string
  or executes `scripts/bump-version.sh` (design.md Constraint Compliance).
- **CI resilience** (design.md Test Strategy) applies to every new `.sh`/
  `.ps1`/`.js` suite: no possibly-empty array expanded under `set -u`; every
  directly-created `mktemp` root normalized with `pwd -P` immediately after
  creation; any `jq`/JSON-parsing output consumption piped through
  `tr -d '\r'` unconditionally where cross-platform line endings could
  appear; every fixture is disposable, offline, and self-contained (no live
  LLM, Provider API, or network call — acceptance-tests.md Notes).
- Fixture writes happen inside script/test files only; no task places a
  protected basename together with a write verb on a Bash command line
  outside the staged `human-copy/` procedure.
- No file under `plugins/sdd-capability/` is created by any task
  (Design Decisions — no new plugin; AC-028/TEST-028, verified by T-004's
  suite setup).
- No Predicate DSL operator or field outside the fixed, closed sets (eight
  operators; eight-entry field allowlist) is implemented or tested as
  accepted anywhere in this feature (Global Constraints, design.md; Security
  Boundary B2).
- No secrets, credentials, or provider-specific detail is placed in any
  fixture Registry instance that a task's suite commits (ADR-0018;
  REQ-003(g); Global Constraints, design.md).
- Preserve unrelated changes; implement one task at a time.

---

## T-001 Author the Capability Registry schema, instance, and lite-upgrade-reason catalog

Source Issue: https://github.com/aharada54914/sdd-forge/issues/190

Approval: Approved (sudo 2026-07-22T14:35:32Z)

Status: Done

Risk: medium

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly, not defaulted. `medium` is justified: this task authors a new,
declarative, machine-readable contract with an accompanying schema-
conformance test suite covering every structural rule (draft-07 validation,
required/optional fields, closed vs. open vocabularies) — a normal,
fully-tested feature with observable behavior (schema accept/reject
outcomes) but no sensitive surface of its own: the contract is inert data
at rest until T-004's validator and T-006's projection generator act on it,
and a shape defect is caught by this task's own schema-conformance suite
before any downstream consumer reads it. It is not `high`: this task
touches no authentication, authorization, payment, PII storage, migration,
or externally-visible runtime API — `contracts/capability-registry.json`
is a repository-internal, hand-edited data file, not a network-facing
contract. Required Workflow is `acceptance-first` per the policy's
medium-tier row.

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-001 (AC-001, AC-002, AC-003, AC-004, AC-005, AC-006,
AC-037, AC-038), REQ-006 (share — this task's own suite)

Depends On: none (functional — this is the foundational contract every
other task either validates, evaluates against, digests, or projects).
Nothing in this feature can begin before the Registry schema/instance/
catalog shape exists.

Planned Files:
- `contracts/capability-registry.schema.json` (new, agent-editable until
  T-006 registers it as protected — JSON Schema draft-07, `$id` under this
  repository's GitHub path matching `contracts/
  workflow-state-registry.schema.json`'s convention, `additionalProperties:
  false` at every fully-enumerated object level; API / Contract Plan)
- `contracts/capability-registry.json` (new, agent-editable until T-006
  registers it — the Registry instance, `"schema":
  "capability-registry/v1"`, illustrative/fixture content only per
  INV-002 — no real Capability Pack exists yet)
- `contracts/lite-upgrade-reason-catalog.json` (new, agent-editable until
  T-006 registers it — `"schema": "lite-upgrade-reason-catalog/v1"`,
  `catalog_version: 1`, seeded with ADR-0022's five-token illustrative set;
  Data Plan)
- `tests/capability-registry-schema.tests.sh` (new, agent-editable)
- `tests/capability-registry-schema.tests.ps1` (new, agent-editable)
- `tests/fixtures/capability-registry/` (new fixture tree — minimal-valid
  and maximal-valid instance fixtures, one rejection fixture per
  structurally-invalid case named in Test Strategy item 5)
- `tests/run-all.sh` (existing, agent-editable — this suite's registration)
- `tests/run-all.ps1` (existing, agent-editable — this suite's
  registration)
- `specs/epic-190-a2-capability-registry/human-copy/.github/workflows/test.yml`
  (new staged candidate, agent-editable — this suite's CI steps; R-10
  protected real path, human-copy only)
- `specs/epic-190-a2-capability-registry/human-copy/MANIFEST.sha256` (new,
  agent-editable — SHA-256 entry for the staged `test.yml` candidate)

Data Migration: none — net-new contract, no prior version (Data Plan).

Breaking API: no; `contracts/capability-registry.schema.json`/`.json`/
`lite-upgrade-reason-catalog.json` are wholly new files.

Rollback: revert this task's commit(s). Nothing protected is written
directly (the staged `test.yml` candidate is human-applied only); a revert
PR states explicitly whether an already-applied `test.yml` step should also
be hand-reverted.

### Goal

Author `contracts/capability-registry.schema.json` (JSON Schema, draft-07)
validating `contracts/capability-registry.json`, and
`contracts/lite-upgrade-reason-catalog.json`, exactly per design.md's API /
Contract Plan: `gates[]` items (`id`, `stage`, `blocking`, conditionally-
required `implementation_ref` via schema-level `if`/`then`);
`capabilities[]` items with `required: ["id", "trigger", "required_facets",
"conditional_facets", "review_check_ids", "gate_ids", "delivery_strategy"]`
and optional `lite_policy`/`minimum_enforcement`; the shared
`#/definitions/predicate` `oneOf` closed to the eight operators
(`all`/`any`/`not`/`equals`/`not_equals`/`contains`/`in`/`exists`) and the
eight-entry field allowlist; `delivery_strategy` required with a required,
open, non-empty `kind` string (no enum).

### Must Read

- `specs/epic-190-a2-capability-registry/requirements.md`
- `specs/epic-190-a2-capability-registry/design.md`
- `specs/epic-190-a2-capability-registry/acceptance-tests.md`
- `specs/epic-190-a2-capability-registry/security-spec.md`
- `contracts/workflow-state-registry.schema.json` (the draft-07 styling
  convention this schema follows, INV-010)
- `contracts/agent-model-capabilities.v2.json` (the
  `"schema": "<name>/v1"` self-describing-instance convention, INV-010)

### Scope

- Write the schema-conformance checks first (acceptance-first): TEST-001
  (base schema validates the Registry instance, `additionalProperties:
  false` fixture), TEST-002 (conditional `implementation_ref` requirement),
  TEST-003 (`lite_policy` shape), TEST-004 (`delivery_strategy` required +
  open `kind`, including the missing-`delivery_strategy`-key and
  missing-`kind`-key negative fixtures), TEST-005 (`minimum_enforcement`
  const + optionality), TEST-006 (no top-level `conditions` field),
  TEST-037 (`required_facets`/`conditional_facets[]` entry shape),
  TEST-038 (`review_check_ids` shape).
- CI resilience per Global Constraints.
- Register `capability-registry-schema` (`.sh`/`.ps1`) in
  `tests/run-all.sh`/`.ps1`; stage the `.github/workflows/test.yml`
  candidate with this suite's CI steps under `human-copy/` +
  `MANIFEST.sha256`.

### Done When

- [ ] **Schema shape** — TEST-001..006 pass: draft-07 validates the
  instance; `additionalProperties: false` enforced at every fully-
  enumerated level (AC-001); conditional `implementation_ref` requirement
  (AC-002); `lite_policy` shape (AC-003); `delivery_strategy` required with
  required, open, non-empty `kind` and no enum (AC-004); `minimum_
  enforcement` const + optionality (AC-005); no top-level `conditions`
  field (AC-006).
- [ ] **Facet/review-check entry shapes** — TEST-037/038 pass:
  `required_facets`/`conditional_facets[]` entry-shape fixtures (AC-037);
  `review_check_ids` shape fixtures (AC-038).
- [ ] **Suite/CI registration** — `tests/capability-registry-schema.
  tests.sh`/`.ps1` self-register in `tests/run-all.sh`/`.ps1` (grep
  self-check); the staged `.github/workflows/test.yml` candidate exists
  with a correct `MANIFEST.sha256` entry.
- [ ] **Acceptance-first evidence** — RED (each rejection fixture against a
  deliberately permissive draft schema) and GREEN (the full suite against
  the correct schema). An independent quality-gate verdict records PASS.

### Out of Scope

- The Predicate DSL evaluator (T-002), the Registry discovery contract and
  vendored copies (T-003), the Registry validator (T-004), the
  `registry_digest` generator (T-005), the projection generator and
  protected-file registration (T-006), and the parity/installed-layout
  harness (T-007).
- Any protected-file registration (Protected Files, above — T-006 only).

### Blockers

None

---

## T-002 Author the Predicate DSL evaluator

Source Issue: https://github.com/aharada54914/sdd-forge/issues/190

Approval: Approved (sudo 2026-07-22T16:12:48Z)

Status: Done

Risk: high

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. `high` is justified, not merely asserted: this script is the
concrete implementation of Security Boundary B2 (design.md Security
Boundaries — "No dynamic evaluation... the boundary preventing 'arbitrary
code as configuration'"), the sole mechanism deciding whether every
Capability/Facet triggers. A silent defect here — an operator or field
that should be rejected instead silently accepted, a fail-closed case
silently returning `true`, a `not` arity bug — is exactly the "silent
defect causes material harm" surface the policy's `high` tier names:
Capabilities/Facets would trigger (or fail to trigger) incorrectly with no
visible symptom until a downstream Gate misfires. It is not `critical` (no
financial-settlement, physical-safety, or irreversible-destructive
surface — it emits a boolean + Evidence, and only a consuming Gate turns
that into a blocking outcome, out of this Epic's own scope). Required
Workflow is `tdd` (Red→Green) per the policy's high-tier row.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-002 (AC-007, AC-008, AC-009, AC-010, AC-011, AC-012,
AC-013, AC-040), REQ-006 (share)

Depends On: T-001 (Global Constraints — serialized for the shared
`tests/run-all.sh`/`.ps1` array and `test.yml` staging only; no functional
dependency — this evaluator implements ADR-0020's grammar directly against
caller-supplied `--predicate`/`--component-properties` input, per its own
API contract, and does not read `contracts/capability-registry.json` or
its schema file at runtime).

Planned Files:
- `plugins/sdd-quality-loop/scripts/evaluate-predicate.py` (new,
  agent-editable — Python master: closed 8-operator grammar, fail-closed
  general rule for `equals`/`not_equals`/`contains`/`in`, the `exists`
  exception, `all`/`any` empty-list + no-short-circuit semantics, `not`'s
  strict-unary arity + truth table, depth-first left-to-right stable
  Evidence ordering, `PREDICATE_SCHEMA_ERROR` for malformed/out-of-grammar
  input; API / Contract Plan)
- `plugins/sdd-quality-loop/scripts/evaluate-predicate.sh` (new,
  agent-editable — thin wrapper, INV-014 convention)
- `plugins/sdd-quality-loop/scripts/evaluate-predicate.ps1` (new,
  agent-editable — twin)
- `tests/evaluate-predicate.tests.sh` (new, agent-editable)
- `tests/evaluate-predicate.tests.ps1` (new, agent-editable)
- `tests/fixtures/capability-registry/` (existing after T-001,
  agent-editable — adds one predicate fixture per operator/case named in
  Test Strategy item 1)
- `tests/run-all.sh` (existing, agent-editable — this suite's registration)
- `tests/run-all.ps1` (existing, agent-editable — this suite's
  registration)
- `specs/epic-190-a2-capability-registry/human-copy/.github/workflows/test.yml`
  (staged candidate, agent-editable — this suite's CI steps, appended
  after T-001's; R-10 protected real path)
- `specs/epic-190-a2-capability-registry/human-copy/MANIFEST.sha256`
  (existing, agent-editable — new entry for this task's staged `test.yml`
  candidate)

Data Migration: none — new, additive CLI JSON output shape; no prior
version.

Breaking API: no; `evaluate-predicate` is a wholly new script.

Rollback: revert this task's commit(s); nothing protected is written
directly.

### Goal

Author `evaluate-predicate.{py,sh,ps1}` implementing ADR-0020 in full: the
closed 8-operator grammar; the general fail-closed rule (missing path,
`null`, or type mismatch on `equals`/`not_equals`/`contains`/`in` →
`false` + `WARN`, never an exception); the `exists` exception (path present
→ `true` regardless of value including `null`; path absent → `false` +
`WARN`; type never inspected); `all`(empty→`true`)/`any`(empty→`false`)
with no short-circuit and full-child Evidence recording; `not`'s strict
unary arity (zero or 2+ children → `PREDICATE_SCHEMA_ERROR`) and truth
table with the child's own Evidence (including its `WARN` reason) preserved
under `not`'s `children`; an Evidence JSON Schema-conformant `evidence`
array in fixed depth-first, left-to-right, stable order; a single shared
code path for `trigger` and `conditional_facets[].when` (no second
evaluator).

### Must Read

- `specs/epic-190-a2-capability-registry/requirements.md`
- `specs/epic-190-a2-capability-registry/design.md`
- `specs/epic-190-a2-capability-registry/acceptance-tests.md`
- `specs/epic-190-a2-capability-registry/security-spec.md`
- `docs/adr/0020-conditional-predicate-dsl.md` (the operator/evaluation
  semantics this script implements)
- `plugins/sdd-quality-loop/scripts/check-contract.py` (the Python-master +
  wrapper convention, INV-014)

### Scope

- Write the acceptance checks first (TDD Red→Green): TEST-007 (fail-closed
  general rule × 4 operators × 3 cases), TEST-008 (`exists` exception),
  TEST-009 (`all`/`any` empty-list + no-short-circuit), TEST-010 (`trigger`
  vs. `conditional_facets[].when` byte-identical evidence shape), TEST-011
  (field-allowlist `PREDICATE_SCHEMA_ERROR` + drift-check fixture against
  Epic A1's Project Context schema once it lands — the fixture-based half
  runs today per investigation.md INV-004a), TEST-012 (`not` arity +
  truth table), TEST-013 (Evidence-JSON-Schema conformance + depth-first
  stable ordering), TEST-040 (forbidden-operator-token
  `PREDICATE_SCHEMA_ERROR`, independent of TEST-011's field-allowlist
  fixture).
- CI resilience per Global Constraints.
- Register `evaluate-predicate` in `tests/run-all.sh`/`.ps1`; stage the
  `.github/workflows/test.yml` candidate appended to T-001's staged file
  (or the unmodified real file if T-001's is already human-applied).

### Done When

- [ ] **Fail-closed + exists exception** — TEST-007/008 pass: the general
  fail-closed rule for `equals`/`not_equals`/`contains`/`in` (AC-007);
  `exists`'s present-with-null/present-with-value/absent behavior with no
  type inspection (AC-008).
- [ ] **Logical operators + single code path** — TEST-009/010 pass:
  `all`/`any` empty-list results and no-short-circuit evidence recording
  (AC-009); `trigger`/`conditional_facets[].when` byte-identical evidence
  shape from one shared evaluator (AC-010).
- [ ] **Grammar closure** — TEST-011/040/012 pass: field-allowlist
  `PREDICATE_SCHEMA_ERROR` + drift-check fixture (AC-011); forbidden
  operator token `PREDICATE_SCHEMA_ERROR`, independent of the field-
  allowlist case (AC-040); `not`'s strict unary arity and documented truth
  table with the child's Evidence preserved (AC-012).
  These are independent grammar-closure checks; both AC-011 and AC-040
  target the same `PREDICATE_SCHEMA_ERROR` diagnostic class from two
  distinct causes (a rejected `field` value vs. a rejected `operator`
  token) and are never satisfied by a single shared fixture.
- [ ] **Evidence conformance** — TEST-013 passes: every fixture's
  `evidence` output validates against the Evidence JSON Schema; nested
  `all`-of-`any`-of-comparisons depth-first, left-to-right, stable ordering
  across repeated runs (AC-013).
- [ ] **Suite/CI registration** — `tests/evaluate-predicate.tests.sh`/
  `.ps1` self-register in `tests/run-all.sh`/`.ps1`; the staged `test.yml`
  candidate exists with a correct `MANIFEST.sha256` entry; the LIVE
  `test.yml` is byte-unchanged before/after this task's own commits.
- [ ] **TDD evidence** — RED (each fail-closed/grammar-closure case against
  a deliberately permissive evaluator) and GREEN (the full suite against
  the correct evaluator). An independent quality-gate verdict records
  PASS.

### Out of Scope

- The Registry schema (T-001), the Registry discovery contract and
  vendored copies (T-003), the Registry validator (T-004), the
  `registry_digest` generator (T-005), the projection generator (T-006),
  and the parity/installed-layout harness (T-007).
- Epic A1's Project Context schema itself (Non-goals) — only the drift
  check against it.

### Blockers

T-001

---

## T-003 Author the Registry discovery contract and the vendored-copy packaging step

Source Issue: https://github.com/aharada54914/sdd-forge/issues/190

Approval: Approved (sudo 2026-07-22T16:53:38Z)

Status: Done

Risk: high

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. `high` is justified: this task implements Security Boundary B4
(design.md Security Boundaries — "Discovery fail-closed... never silently
falls back to a stale or absent artifact"), consumed by T-004's validator
(catalog lookup) and T-005's digest generator (Registry lookup). A silent
defect (a stale vendored copy accepted, a version check that passes on a
malformed artifact, a silent fallback instead of fail-closed exit) lets a
standalone-installed plugin operate on wrong or absent Registry data with
no visible symptom — the same "silent defect causes material harm" class
the policy names, on an access-adjacent discovery path multiple downstream
scripts trust unconditionally. It is not `critical` (no settlement/safety/
irreversible surface). Required Workflow is `tdd` per the policy's
high-tier row.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-005 (AC-027 — discovery-contract share of REQ-005; the
projection generator and protected-file registration are T-006's own
share), REQ-006 (share)

Depends On: T-001 (functional — the version-check fixtures this task
authors assert against the real shape of `contracts/capability-registry.
json`/`.schema.json`/`lite-upgrade-reason-catalog.json`, and the vendored
copies this task creates are packaged, not-yet-protected duplicates of
T-001's files), T-002 (Global Constraints — serialized for the shared
`tests/run-all.sh`/`.ps1` array and `test.yml` staging only; no functional
dependency on the evaluator).

Planned Files:
- `plugins/sdd-quality-loop/scripts/registry_discovery.py` (new,
  agent-editable — shared Python helper module, imported by T-004's
  `validate-capability-registry.py` for the catalog lookup and T-005's
  `generate-registry-digest.py` for the Registry lookup: script-relative
  symlink-resolved packaged-copy resolution, `git rev-parse
  --show-toplevel`/`.git`-walk fallback, per-artifact version check table,
  fail-closed diagnostic naming every attempted path; API / Contract Plan
  Registry discovery contract, ADR-0025)
- `plugins/sdd-quality-loop/scripts/vendor-capability-registry.py` (new,
  agent-editable — the vendoring/packaging step, Assumptions/Deployment-CI
  Plan: refreshes the packaged copies below from the canonical `contracts/`
  originals; `--check` mode, no write, sha256 comparison, non-zero exit on
  any stale copy, mirroring `generate-gate-capabilities.py --check`'s own
  contract)
- `plugins/sdd-quality-loop/scripts/vendor-capability-registry.sh` (new,
  agent-editable — thin wrapper)
- `plugins/sdd-quality-loop/scripts/vendor-capability-registry.ps1` (new,
  agent-editable — twin)
- `plugins/sdd-quality-loop/contracts/capability-registry.json` (new,
  agent-editable until T-006 registers it — vendored copy, Components)
- `plugins/sdd-quality-loop/contracts/capability-registry.schema.json`
  (new, agent-editable until T-006 registers it — vendored copy)
- `plugins/sdd-quality-loop/contracts/lite-upgrade-reason-catalog.json`
  (new, agent-editable — vendored copy; not itself on the seven-path
  protected list, Protected Files, above, but refreshed by the same
  vendoring step for discovery-contract completeness)
- `tests/registry-discovery.tests.sh` (new, agent-editable)
- `tests/registry-discovery.tests.ps1` (new, agent-editable)
- `tests/fixtures/capability-registry/` (existing after T-001,
  agent-editable — three installed-layout fixtures (one per runtime), three
  per-artifact version-mismatch fixtures, one neither-location-resolves
  fixture, one vendored-copy-drift fixture)
- `tests/run-all.sh` (existing, agent-editable — this suite's registration)
- `tests/run-all.ps1` (existing, agent-editable — this suite's
  registration)
- `specs/epic-190-a2-capability-registry/human-copy/.github/workflows/test.yml`
  (staged candidate, agent-editable — this suite's CI steps, appended
  after T-002's; R-10 protected real path)
- `specs/epic-190-a2-capability-registry/human-copy/MANIFEST.sha256`
  (existing, agent-editable — new entry for this task's staged `test.yml`
  candidate)

Data Migration: none.

Breaking API: no; `registry_discovery.py` and
`vendor-capability-registry.{py,sh,ps1}` are wholly new; the vendored
`plugins/sdd-quality-loop/contracts/*` copies are new, additive files with
no existing consumer yet.

Rollback: revert this task's commit(s); the vendored copies and discovery
module are additive and independently revertible. Nothing protected is
written directly — the vendored copies are ordinary agent-editable files
until T-006's staged registration is human-applied.

### Goal

Author the script-relative Registry discovery contract (ADR-0025) as a
shared helper: resolve the invoking script's own symlink-resolved real
path, look for a packaged copy at `<script-real-dir>/../contracts/
<filename>`; fall back to `git rev-parse --show-toplevel` (or a `.git`
walk) + `/contracts/<filename>`; verify the discovered artifact against its
own per-artifact version check (Registry: `schema ==
"capability-registry/v1"`; schema file: `$schema` present + `$id` match;
catalog: `schema == "lite-upgrade-reason-catalog/v1"`); fail closed with a
diagnostic naming every attempted path and the version-check result if
neither location resolves or the check fails. Author the vendoring/
packaging step that populates
`plugins/sdd-quality-loop/contracts/capability-registry.json`/`.schema.json`
from the canonical `contracts/` originals, with its own release-gating
`--check` mode.

### Must Read

- `specs/epic-190-a2-capability-registry/requirements.md`
- `specs/epic-190-a2-capability-registry/design.md`
- `specs/epic-190-a2-capability-registry/acceptance-tests.md`
- `specs/epic-190-a2-capability-registry/infra-spec.md`
- `specs/epic-190-a2-capability-registry/security-spec.md`
- `docs/adr/0025-registry-discovery-contract.md` (the accepted ADR this
  task implements)
- `plugins/sdd-quality-loop/scripts/generate-guard-invariants.py` (the
  `--check` no-write, sha256-comparison convention this task's vendoring
  step mirrors)
- `contracts/capability-registry.schema.json`/`.json`,
  `contracts/lite-upgrade-reason-catalog.json` (T-001's outputs this task
  vendors and version-checks)

### Scope

- Write the acceptance checks first (TDD Red→Green): TEST-027's full
  fixture set — three installed-layout fixtures (Claude Code, Codex CLI,
  Copilot CLI: only the packaged copy present, no monorepo `contracts/`,
  no reachable `.git`, no runtime environment variable set in any fixture)
  each proving discovery succeeds via the packaged copy alone; three
  per-artifact version-mismatch fixtures (wrong `schema` value on the
  Registry, missing `$schema`/mismatched `$id` on the schema file, wrong
  `schema` value on the catalog); one neither-location-resolves fixture
  asserting a fail-closed diagnostic naming both attempted paths; one
  vendored-copy-drift fixture asserting the release-gating `--check` mode
  fails when a vendored copy's sha256 diverges from its canonical
  `contracts/*` source.
- CI resilience per Global Constraints.
- Register `registry-discovery` in `tests/run-all.sh`/`.ps1`; stage the
  `.github/workflows/test.yml` candidate appended to T-002's staged file.

### Done When

- [ ] **Discovery resolution** — the three installed-layout fixtures pass:
  discovery succeeds via the script-relative packaged copy alone,
  independent of which host process invoked the script and with no runtime
  environment variable consulted (AC-027, installed-layout portion).
- [ ] **Fail-closed correctness** — the three per-artifact version-mismatch
  fixtures and the neither-location-resolves fixture pass: each yields a
  fail-closed, non-zero-exit diagnostic naming every attempted path (AC-027,
  version-check + fail-closed portions).
- [ ] **Vendored-copy drift gate** — the vendored-copy-drift fixture
  passes: `vendor-capability-registry.py --check` exits non-zero when a
  vendored copy's sha256 diverges from its canonical source, and exits zero
  with no filesystem write against a freshly-vendored tree (AC-027,
  release-gate portion).
- [ ] **Suite/CI registration** — `tests/registry-discovery.tests.sh`/
  `.ps1` self-register in `tests/run-all.sh`/`.ps1`; the staged `test.yml`
  candidate exists with a correct `MANIFEST.sha256` entry; the LIVE
  `test.yml` is byte-unchanged before/after this task's own commits.
- [ ] **TDD evidence** — RED (each fail-closed axis against a fixture that
  would otherwise silently degrade to a stale/absent Registry) and GREEN
  (the full suite against the correct discovery module and vendoring
  step). An independent quality-gate verdict records PASS.

### Out of Scope

- The Registry schema (T-001), the Predicate DSL evaluator (T-002), the
  Registry validator itself (T-004, this task only supplies the discovery
  helper it imports), the `registry_digest` generator itself (T-005, same
  relationship), the projection generator and the seven-path protected-file
  registration (T-006 — this task creates the vendored copies as ordinary,
  not-yet-protected files only), and the parity/installed-layout harness
  (T-007, which additionally invokes all four scripts from within
  simulated runtime contexts).
- Drafting or amending any ADR — ADR-0025 already exists (Protected Files,
  above).

### Blockers

T-001, T-002

---

## T-004 Author the Registry validator and the provider-terms allowlist

Source Issue: https://github.com/aharada54914/sdd-forge/issues/190

Approval: Approved (sudo 2026-07-22T17:16:49Z)

Status: Done

Risk: high

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. `high` is justified, not merely asserted: this script is the
first automated implementation of ADR-0018's provider-neutrality boundary
(Security Boundary B1) in this repository, and independently enforces
referential integrity, Gate-ID/Capability-ID uniqueness, and the
unregistered-script (Gate implementation identity) check that keeps
`stage: implementation` Gates traceable to exactly one script. A silent
defect in any of the nine checks (a-i) lets an untrustworthy Registry
(a leaked provider name, a duplicate Gate ID, an unregistered script, a
dangling reference) pass as validated — the exact "silent defect causes
material harm" surface the policy's `high` tier names on an
access-control-adjacent trust boundary. It is not `critical` (no
settlement/safety/irreversible surface — the validator narrows acceptance,
it does not itself execute anything). Required Workflow is `tdd` per the
policy's high-tier row.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-003 (AC-014, AC-015, AC-016, AC-017, AC-018, AC-019,
AC-020, AC-021, AC-022, AC-039), REQ-005 (share — AC-028 structural
placement check, this suite's own setup fixture), REQ-006 (share)

Depends On: T-001 (functional — validates T-001's schema/instance/
catalog), T-002 (Global Constraints — serialized only), T-003 (functional —
imports `registry_discovery.py` for the lite-upgrade-reason-catalog
lookup).

Planned Files:
- `plugins/sdd-quality-loop/scripts/validate-capability-registry.py` (new,
  agent-editable — nine independently identifiable checks a-i: Gate-ID
  uniqueness, stage-completeness, unregistered-script detection via the
  Gate implementation identity schema, no Pack-owned Gate definitions,
  defense-in-depth `stage`-missing re-assertion, referential integrity,
  Provider-name contamination, lite-upgrade-reason-catalog conformance,
  Capability-ID uniqueness; API / Contract Plan Registry validator
  contract)
- `plugins/sdd-quality-loop/scripts/validate-capability-registry.sh` (new,
  agent-editable — thin wrapper)
- `plugins/sdd-quality-loop/scripts/validate-capability-registry.ps1` (new,
  agent-editable — twin)
- `plugins/sdd-quality-loop/references/provider-terms.json` (new,
  agent-editable — not itself a protected path (Components) — the
  case-insensitive provider-name allowlist consulted by check (g))
- `tests/validate-capability-registry.tests.sh` (new, agent-editable)
- `tests/validate-capability-registry.tests.ps1` (new, agent-editable)
- `tests/fixtures/capability-registry/` (existing after T-001,
  agent-editable — one minimally-mutated fixture per check a-i, the
  bidirectional Gate-implementation-identity fixture set, the
  validator-direct schema-bypassing fixture for check (e), the
  combined-duplicate fixture for check (i), one fully-clean fixture)
- `tests/run-all.sh` (existing, agent-editable — this suite's registration)
- `tests/run-all.ps1` (existing, agent-editable — this suite's
  registration)
- `specs/epic-190-a2-capability-registry/human-copy/.github/workflows/test.yml`
  (staged candidate, agent-editable — this suite's CI steps, appended
  after T-003's; R-10 protected real path)
- `specs/epic-190-a2-capability-registry/human-copy/MANIFEST.sha256`
  (existing, agent-editable — new entry for this task's staged `test.yml`
  candidate)

Data Migration: none.

Breaking API: no; `validate-capability-registry` is a wholly new script.

Rollback: revert this task's commit(s); nothing protected is written
directly.

### Goal

Author `validate-capability-registry.{py,sh,ps1}` implementing all nine
REQ-003(a-i) checks per API / Contract Plan's diagnostic-ID table
(`gate-id-duplicate`, `implementation-ref-missing`, `unregistered-script`,
`pack-owns-gate-definition`, `stage-missing`, `dangling-gate-reference`,
`provider-name-detected`, `unknown-upgrade-reason`,
`capability-id-duplicate`), including the fully-specified Gate
implementation identity schema (canonical `.py`-only reference; sole scan
root `plugins/sdd-quality-loop/scripts/`; `check-`-prefix gate-shaped
selection rule; same-directory/same-basename `.sh`/`.ps1`/`.js` wrapper
grouping; symlink resolution before comparison). Author
`references/provider-terms.json` (cloud-provider, distribution-channel,
and workflow-runtime-product-name categories).

### Must Read

- `specs/epic-190-a2-capability-registry/requirements.md`
- `specs/epic-190-a2-capability-registry/design.md`
- `specs/epic-190-a2-capability-registry/acceptance-tests.md`
- `specs/epic-190-a2-capability-registry/security-spec.md`
- `docs/adr/0018-provider-binding-separation.md` (the provider-neutrality
  boundary check (g) implements)
- `docs/adr/0017-gate-stage-model.md` (the stage-completeness/
  reserved-stage-inertness rules checks (b)/(e) implement)
- `plugins/sdd-quality-loop/scripts/registry_discovery.py` (T-003's
  discovery helper this validator imports for the catalog lookup)
- `plugins/sdd-quality-loop/scripts/check-sdd-structure.sh` (the
  `missing: <item>`-style diagnostic-line convention this validator's
  output format follows)

### Scope

- Write the acceptance checks first (TDD Red→Green): TEST-014 (Gate-ID
  uniqueness), TEST-015 (stage-completeness, stage-scoped), TEST-016
  (Gate implementation identity schema lock), TEST-017 (bidirectional
  unregistered-script completeness lock), TEST-018 (defense-in-depth
  `stage`-missing re-assertion), TEST-019 (no Pack-owned Gate definitions),
  TEST-020 (Provider-name-contamination, per-category + clean-fixture
  false-positive check), TEST-021 (referential integrity, validator-only),
  TEST-022 (lite-upgrade-reason-catalog conformance fail-closed),
  TEST-039 (Capability-ID uniqueness, independent of TEST-014's Gate-ID
  check + the combined-duplicate fixture), TEST-028 (structural placement:
  `plugins/sdd-capability/` absent; every REQ-002..005 script/reference
  file lives under `plugins/sdd-quality-loop/`, run as this suite's own
  setup assertion).
- CI resilience per Global Constraints.
- Register `validate-capability-registry` in `tests/run-all.sh`/`.ps1`;
  stage the `.github/workflows/test.yml` candidate appended to T-003's
  staged file.

### Done When

- [ ] **Uniqueness + completeness** — TEST-014/015/039 pass: Gate-ID
  uniqueness over `gates[]` (AC-014); stage-scoped completeness for
  `stage: implementation` with `artifact`/`promotion` exemption (AC-015);
  Capability-ID uniqueness, independent of Gate-ID uniqueness, plus the
  combined-duplicate fixture proving neither masks the other (AC-039).
- [ ] **Gate implementation identity** — TEST-016/017 pass: the identity
  schema lock (`.py`-only reference, single scan root, `check-` prefix
  rule, wrapper grouping, symlink resolution) (AC-016); the bidirectional
  completeness fixture set (wrapper pair = one implementation,
  out-of-scan-root never flagged, in-scan-root unreferenced master flagged,
  non-`check-*` never scanned) (AC-017).
- [ ] **Defense-in-depth + forward-guard** — TEST-018/019 pass: the
  validator-direct `stage`-missing re-assertion against a schema-bypassing
  fixture (AC-018); no `capability-packs/*/gates.yaml`-shaped file exists
  (AC-019).
- [ ] **Provider-neutrality + referential integrity + catalog conformance**
  — TEST-020/021/022 pass: per-category Provider-name detection with a
  clean-fixture false-positive check (AC-020); `dangling-gate-reference`
  as a validator-level-only check (AC-021); `unknown-upgrade-reason`
  fail-closed against the catalog (AC-022).
- [ ] **Structural placement** — TEST-028 passes: `plugins/sdd-capability/`
  does not exist; every REQ-002..005 script/reference file lives under
  `plugins/sdd-quality-loop/` (AC-028).
- [ ] **Suite/CI registration** — `tests/validate-capability-registry.
  tests.sh`/`.ps1` self-register in `tests/run-all.sh`/`.ps1`; the staged
  `test.yml` candidate exists with a correct `MANIFEST.sha256` entry; the
  LIVE `test.yml` is byte-unchanged before/after this task's own commits.
- [ ] **TDD evidence** — RED (each of the nine checks against a
  deliberately permissive validator) and GREEN (the full suite against the
  correct validator, including the one fully-clean fixture proving the
  suite cannot pass vacuously). An independent quality-gate verdict
  records PASS.

### Out of Scope

- The Registry schema (T-001), the Predicate DSL evaluator (T-002), the
  discovery contract/vendoring step itself (T-003, this task only imports
  its helper), the `registry_digest` generator (T-005), the projection
  generator and protected-file registration (T-006), and the
  parity/installed-layout harness (T-007).
- Any change to `check-contract.{sh,ps1,py}`'s required-check-set or
  `risk-gate-matrix.md` — this validator is a standalone primitive, not a
  new `check-contract`-enforced Gate (Protected Files, above).

### Blockers

T-001, T-002, T-003

---

## T-005 Author the registry_digest generator

Source Issue: https://github.com/aharada54914/sdd-forge/issues/190

Approval: Approved (sudo 2026-07-22T18:32:33Z)

Status: Implementation Complete

Risk: medium

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. `medium` is justified: this task emits a derived, additive
sha256 digest over a canonical-JSON Registry fragment, consumed downstream
by Epic A4/A5's `context_binding.registry_digest` staleness binding (out of
this Epic's own scope, Non-goals) — its blast radius is bounded to
staleness-trigger correctness, not to whether a Gate blocks or an
under-reported Registry passes validation (T-004's validator, not this
digest, is the trust boundary). It does not touch access-control, secrets,
or a Gate-blocking surface, so it falls short of `high`; it is well above
`low` because it introduces real behavioral logic (fragment selection,
dedupe, stable-sort, delegation to Epic A1's canonicalizer) other
components will consume. Required Workflow is `acceptance-first` per the
policy's medium-tier row.

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-004 (AC-023, AC-024, AC-032), REQ-006 (share)

Depends On: T-001 (functional — fragments T-001's `capabilities[]`/
`gates[]` arrays), T-002 (Global Constraints — serialized only), T-003
(functional — imports `registry_discovery.py` to locate the Registry, since
this script's own CLI contract takes no `--registry` path argument), T-004
(Global Constraints — serialized only). **Hard-blocked on Epic A1's
canonicalizer utility existing as a real artifact** (requirements.md
Dependencies; design.md Assumptions: "REQ-004's task is explicitly blocked
(not merely at-risk) until that contract is finalized") — re-verify Epic
A1's canonicalizer's published path, version, and I/O contract at
implementation-start time and record a documented blocker if still absent,
rather than reimplementing RFC 8785/JCS.

Planned Files:
- `plugins/sdd-quality-loop/scripts/generate-registry-digest.py` (new,
  agent-editable — fragment selection (`--capability-ids`/`--gate-ids`/
  `--whole`, at least one required), dedupe, unknown-ID hard failure,
  stable-sort by ID, delegation to Epic A1's canonicalizer for the JCS
  step; API / Contract Plan `registry_digest` generator contract)
- `plugins/sdd-quality-loop/scripts/generate-registry-digest.sh` (new,
  agent-editable — thin wrapper)
- `plugins/sdd-quality-loop/scripts/generate-registry-digest.ps1` (new,
  agent-editable — twin)
- `plugins/sdd-quality-loop/scripts/generate-registry-digest.js` (new,
  agent-editable — third wrapper, matching Epic A1's canonicalizer's own
  sh/ps1/js wrapper set, AC-031 share)
- `tests/generate-registry-digest.tests.sh` (new, agent-editable)
- `tests/generate-registry-digest.tests.ps1` (new, agent-editable)
- `tests/fixtures/capability-registry/` (existing after T-001,
  agent-editable — the fixed fixture Registry, JCS/NFC canonicalization
  vectors, stable-ordering fixtures)
- `tests/run-all.sh` (existing, agent-editable — this suite's registration)
- `tests/run-all.ps1` (existing, agent-editable — this suite's
  registration)
- `specs/epic-190-a2-capability-registry/human-copy/.github/workflows/test.yml`
  (staged candidate, agent-editable — this suite's CI steps, appended
  after T-004's; R-10 protected real path)
- `specs/epic-190-a2-capability-registry/human-copy/MANIFEST.sha256`
  (existing, agent-editable — new entry for this task's staged `test.yml`
  candidate)

Data Migration: none — new, additive CLI output; no prior version.

Breaking API: no; `generate-registry-digest` is a wholly new script.

Rollback: revert this task's commit(s); nothing protected is written
directly.

### Goal

Author `generate-registry-digest.{py,sh,ps1,js}`: parse
`--capability-ids`/`--gate-ids` as deduped comma-separated ID lists (an
unknown ID is a hard `unknown-fragment-id` failure); build the fragment's
`capabilities` sub-array (every named Capability) and `gates` sub-array
(the union of every named Capability's transitive `gate_ids` plus every
directly-named `--gate-ids` entry); stable-sort both sub-arrays by `id`;
call Epic A1's canonicalizer for the RFC 8785/JCS + NFC step; output the
sha256 hex digest. Invoking with none of `--capability-ids`/`--gate-ids`/
`--whole` is a hard `fragment-selector-required` failure, never a silent
`--whole` default; `--whole` selects the entire, author-ordered Registry
unsorted.

### Must Read

- `specs/epic-190-a2-capability-registry/requirements.md`
- `specs/epic-190-a2-capability-registry/design.md`
- `specs/epic-190-a2-capability-registry/acceptance-tests.md`
- `docs/adr/0021-context-projection-staleness.md` (the
  `context_binding.registry_digest` consumption shape this primitive feeds,
  Epic A4/A5's own concern, not implemented here)
- Epic A1's canonicalizer entry point (re-verify presence, published
  version, and I/O contract at implementation-start time; record a
  documented blocker if absent — requirements.md Dependencies)
- `plugins/sdd-quality-loop/scripts/registry_discovery.py` (T-003's
  discovery helper this generator imports)

### Scope

- Write the acceptance checks first (acceptance-first): TEST-023
  (canonicalizer-delegation design-conformance — code-inspection-style
  check that no inline JCS/YAML-1.2-parse path exists), TEST-024
  (fragment-identity lock: order/duplicate-independence, direct
  `--gate-ids` selection, unknown-ID hard failure, `--whole` content-
  sensitivity, `fragment-selector-required` hard failure, union-of-both-
  flags case), TEST-032 (JCS/NFC canonicalization vector set + stable-
  ordering re-confirmation).
- CI resilience per Global Constraints.
- Register `generate-registry-digest` in `tests/run-all.sh`/`.ps1`; stage
  the `.github/workflows/test.yml` candidate appended to T-004's staged
  file.

### Done When

- [ ] **Canonicalizer delegation** — TEST-023 passes (once Epic A1's
  canonicalizer contract is finalized — otherwise this item records the
  documented blocker per Depends On, not a skipped or waived check): the
  implementation calls Epic A1's canonicalizer module for the JCS step;
  no inline RFC 8785 implementation and no YAML-1.2 parse path exists for
  this JSON-authored input (AC-023).
- [ ] **Fragment identity** — TEST-024 passes: order/duplicate-independent
  digests for the identical semantic ID set; direct `--gate-ids` selection
  independent of Capability references; unknown-ID hard failure;
  `--whole` content-sensitivity; the `fragment-selector-required` hard
  failure when no selector flag is supplied; the union case for
  `--capability-ids`+`--gate-ids` together (AC-024).
- [ ] **Canonicalization vectors** — TEST-032 passes: RFC 8785 key-
  ordering/number-formatting vectors and Unicode NFC composed-vs-decomposed
  equivalence each produce identical digests; the stable-ordering fixture
  re-confirms AC-024's sort independent of caller-supplied input order
  (AC-032).
- [ ] **Suite/CI registration** — `tests/generate-registry-digest.
  tests.sh`/`.ps1` self-register in `tests/run-all.sh`/`.ps1`; the staged
  `test.yml` candidate exists with a correct `MANIFEST.sha256` entry; the
  LIVE `test.yml` is byte-unchanged before/after this task's own commits.
- [ ] **Acceptance-first evidence** — RED (a subset/unsorted/duplicate-
  sensitive digest implementation failing the fragment-identity matrix)
  and GREEN (the full suite against the correct implementation, once
  unblocked). An independent quality-gate verdict records PASS.

### Out of Scope

- The Registry schema (T-001), the Predicate DSL evaluator (T-002), the
  discovery contract/vendoring step itself (T-003, this task only imports
  its helper), the Registry validator (T-004), the projection generator and
  protected-file registration (T-006), reimplementing Epic A1's
  canonicalizer (Non-goals), and the `context_binding` binding itself
  (Epic A4/A5's own scope, Non-goals).

### Blockers

T-001, T-002, T-003, T-004

(Additional external precondition, not an in-repository task-ID blocker:
Epic A1's canonicalizer utility must exist as a real, finalized artifact
for this task to reach Done — requirements.md Dependencies, design.md
Assumptions.)

BLOCKED (2026-07-22T18:32Z, implementation session, before any code was
written): re-verified this precondition at task-start per the above and
per requirements.md Dependencies -- still absent. `feature/epic-190-a2-
capability-registry` (this branch) and `main` both contain no Epic A1
artifact of any kind (no `specs/epic-189*` or `specs/*a1*` directory, no
`canonicalize`/`jcs`-named script anywhere in the tree, no
`provider-bindings.yaml`; confirmed via repo-wide `find`/`grep`, not
assumed). Epic A1's own feature branch exists locally
(`feature/epic-189-a1-project-context`, 33 commits ahead of `main`, not
merged into `main` or this branch) but its own canonicalizer task is
*itself* `Status: Blocked` there too (commit `1018c10`,
`specs/epic-189-a1-project-context/tasks.md` T-002 "Author the
canonicalizer (`canonicalize-sdd-yaml`)"): that task's own Required
Reading found design.md's parser-library decision (PyYAML/ruamel.yaml)
unsatisfiable in that implementation session (`ModuleNotFoundError` for
both; no `requirements.txt`/`pyproject.toml`/`Pipfile` anywhere in the
repo; every existing `.py` file imports stdlib only) -- an
architecture/packaging decision A1's own coder correctly did not resolve
by guessing, per that task's `reports/implementation/
epic-189-a1-project-context/T-002.md`. So the canonicalizer does not
exist as a real, finalized artifact in ANY reachable branch of this
repository, not merely an unmerged-but-complete one. Per
requirements.md Dependencies and design.md Assumptions, this is not a
routine approval checkpoint sudo can pass and not something this session
resolves by reimplementing RFC 8785/JCS itself (Non-goals; would
duplicate, not delegate to, Epic A1's canonicalizer, and would need to be
thrown away once the real one lands). No Scope items were started -- this
was found while re-confirming the Depends-On precondition, before writing
any Red test or code. Human decision needed: resolve Epic A1's own T-002
blocker (see that task's Blockers section for the parser-library
question) and land/merge its canonicalizer; only then can T-005 resume
from its own Scope's Red step.

Cross-reference: per coordinator decision 2026-07-22 (option (a),
conditional), T-006 proceeded ahead of this task's Blocked state under
the Global Constraints' serialized-order rule, since T-005 made zero
edits to any shared file before blocking -- see T-006's own
implementation report for the deviation record and the required
future-task obligation (insert T-005's shared-file registration between
T-004's and T-006's entries once T-005 unblocks and lands).

---

## T-006 Author the projection generator and stage the protected-file registration

Source Issue: https://github.com/aharada54914/sdd-forge/issues/190

Approval: Approved (sudo 2026-07-22T18:37:01Z)

Status: Implementation Complete

Risk: high

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly, not defaulted. `high` is justified, not merely asserted: the
generated `gate-capabilities.json` is the file `sdd-quality-loop`'s own
Implementation Gate reads to decide which Gates apply to a triggered
Capability (requirements.md Main Workflows step 5) — an access-control-
adjacent enforcement surface where a silent drift (a stale committed
projection accepted, `--check` failing to detect a mutation) lets the Gate
act on wrong data. **AND** this task is the sole editor of the seven-path
protected-file registration bundle (Protected Files, above) — a silent
mistake here (missing one of `PHASE2_TARGETS`'s new entries, an
out-of-sync generated sibling) either fails to protect a path that should
be protected or corrupts `generate-guard-invariants.py`'s own exact-match
self-hosting check for every OTHER feature's protected paths too, since
`PHASE2_TARGETS`/`BASELINE_SUFFIXES` are shared, repository-wide constants,
not scoped to this Epic. Both surfaces are "silent defect causes material
harm" per the policy's `high` tier. It is not `critical` (no settlement/
safety/irreversible surface — the additive registration is fail-closed
hardening, matching `specs/epic-191-a3-path-ownership/tasks.md` T-004's
identical reasoning for its own protected-file-registration task).
Required Workflow is `tdd` per the policy's high-tier row.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-005 (AC-025, AC-026, AC-029), REQ-006 (AC-030, share)

Depends On: T-001 (functional — reads T-001's validated Registry to
project it; the protected-file registration also needs T-001's three
contract paths to exist), T-002 (Global Constraints — serialized only),
T-003 (functional — the two vendored-copy paths this task's protected-file
registration also covers must exist first), T-004 (Global Constraints —
serialized only; not a functional dependency — the projection generator
reads the Registry directly, it does not invoke the validator as a
subprocess), T-005 (Global Constraints — serialized only; the digest
generator is not on the seven-path protected list and this task does not
consume its output).

Planned Files:
- `plugins/sdd-quality-loop/scripts/generate-gate-capabilities.py` (new,
  agent-editable until this task's own staged registration is
  human-applied — reads `contracts/capability-registry.json` via its
  canonical monorepo-relative path (never the vendored copy, since this
  script is that copy's own producer), writes the `_generated`-headed
  projection; `--check` drift-detection mode, no write; API / Contract
  Plan projection generator contract)
- `plugins/sdd-quality-loop/scripts/generate-gate-capabilities.sh` (new,
  agent-editable until registered — thin wrapper)
- `plugins/sdd-quality-loop/scripts/generate-gate-capabilities.ps1` (new,
  agent-editable until registered — twin)
- `plugins/sdd-quality-loop/scripts/generated/gate-capabilities.json`
  (new, agent-editable until registered — the protected, generated
  projection)
- `tests/generate-gate-capabilities.tests.sh` (new, agent-editable)
- `tests/generate-gate-capabilities.tests.ps1` (new, agent-editable)
- `tests/fixtures/capability-registry/` (existing after T-001,
  agent-editable — the clean-pass fixture Registry + its correctly-
  generated projection, the mutated-projection negative fixture)
- `tests/run-all.sh` (existing, agent-editable — this suite's registration)
- `tests/run-all.ps1` (existing, agent-editable — this suite's
  registration)
- **Protected-file registration bundle (Protected Files, above — six
  staged files, this task's sole responsibility within this feature):**
  - `specs/epic-190-a2-capability-registry/human-copy/plugins/sdd-quality-loop/references/guard-invariants.json`
  - `specs/epic-190-a2-capability-registry/human-copy/plugins/sdd-quality-loop/scripts/generate-guard-invariants.py`
  - `specs/epic-190-a2-capability-registry/human-copy/plugins/sdd-quality-loop/scripts/generated/guard_invariants.py`
  - `specs/epic-190-a2-capability-registry/human-copy/plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.js`
  - `specs/epic-190-a2-capability-registry/human-copy/plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.ps1`
  - `specs/epic-190-a2-capability-registry/human-copy/plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.sh`
- `specs/epic-190-a2-capability-registry/human-copy/.github/workflows/test.yml`
  (staged candidate, agent-editable — this suite's CI steps, appended
  after T-005's; the `generate-gate-capabilities.py --check` step and the
  vendoring step's `--check` step, mirroring
  `generate-guard-invariants.py --check` at `test.yml:30,35`; R-10
  protected real path)
- `specs/epic-190-a2-capability-registry/human-copy/MANIFEST.sha256`
  (existing, agent-editable — seven new entries: the six protected-file
  bundle files above (which double as the source for the seven newly-
  registered paths) plus this task's own `test.yml` entry)

Data Migration: none — the generated projection is a net-new additive
shape.

Breaking API: no; `generate-gate-capabilities` is a wholly new script; the
`guard-invariants.json`/`generate-guard-invariants.py` edits are additive
(seven more protected paths, zero removed).

Rollback: revert this task's commit(s); the new script and suite are
additive and independently revertible. The six staged protected-bundle
files and `.github/workflows/test.yml` are NEVER part of the agent's own
commit history (human-applied only) — a revert PR must separately state
whether any already-human-applied protected-file change should also be
hand-reverted, and by whom.

### Goal

Author `generate-gate-capabilities.{py,sh,ps1}`: without `--check`, write
`plugins/sdd-quality-loop/scripts/generated/gate-capabilities.json`
headed by a top-level `_generated` object (`source`, `schema_version`,
`sha256`, "This file is generated. Do not edit." notice) followed by
`gates` (stage: implementation entries only) and `capability_gate_map`;
with `--check`, recompute in memory and compare byte-for-byte against the
committed file, no write, non-zero exit on any difference. Stage the
seven-path protected-file registration: edit `guard-invariants.json`'s
`protected_gate_suffixes`/`phase2_human_copy_targets` AND
`generate-guard-invariants.py`'s `PHASE2_TARGETS` tuple (Protected Files,
above, the load_and_validate() exact-match requirement) together, and
regenerate the three `generated/guard-invariants.generated.{js,ps1,sh}`
siblings plus `generated/guard_invariants.py` to match — all staged, never
a direct edit.

### Must Read

- `specs/epic-190-a2-capability-registry/requirements.md`
- `specs/epic-190-a2-capability-registry/design.md`
- `specs/epic-190-a2-capability-registry/acceptance-tests.md`
- `specs/epic-190-a2-capability-registry/infra-spec.md`
- `specs/epic-190-a2-capability-registry/security-spec.md`
- `plugins/sdd-quality-loop/scripts/generate-guard-invariants.py:37-56`
  (`PHASE2_TARGETS`, the tuple this task's staged edit extends by seven
  entries), `:129-157` (`load_and_validate()`'s exact-match checks against
  `PHASE2_TARGETS`/`BASELINE_SUFFIXES` that force the generator edit, not
  merely the JSON source edit)
- `plugins/sdd-quality-loop/references/guard-invariants.json` (re-verify
  current `protected_gate_suffixes`/`phase2_human_copy_targets` before
  staging)
- `specs/epic-136-phase2-gates/human-copy/` (the established human-copy
  staging + `MANIFEST.sha256` procedure this task follows)

### Scope

- Write the acceptance checks first (TDD Red→Green): TEST-025 (generated-
  header conformance — `_generated` block shape, no comment-line
  convention), TEST-026 (drift detection — hand-mutated file fails
  `--check`, clean file passes, mtime-unchanged proves no write).
- CI resilience per Global Constraints.
- Register `generate-gate-capabilities` in `tests/run-all.sh`/`.ps1`; stage
  the `.github/workflows/test.yml` candidate appended to T-005's staged
  file, adding the `--check` steps.
- Stage all six protected-file-bundle candidates + `MANIFEST.sha256`
  entries for the seven newly-registered paths; re-verify
  `generate-guard-invariants.py --check` exits 0 against a staged copy of
  the tree with the bundle overlaid.

### Done When

- [ ] **Generated-header + drift detection** — TEST-025/026 pass: the
  `_generated` block carries `source`/`schema_version`/`sha256`/the "Do not
  edit" notice, no comment-line convention anywhere (AC-025); a
  hand-mutated committed projection fails `--check` (non-zero exit), a
  freshly-regenerated one passes (exit zero), and an mtime-unchanged
  assertion proves `--check` performs no write (AC-026).
- [ ] **HUMAN APPLY STEP — protected-file registration (six staged files,
  seven newly-registered paths):** a human maintainer runs `cp` for
  `guard-invariants.json`, `generate-guard-invariants.py`,
  `generated/guard_invariants.py`, and the three
  `generated/guard-invariants.generated.{js,ps1,sh}` siblings from
  `human-copy/`, verifies each file's SHA-256 against `MANIFEST.sha256`,
  and runs `generate-guard-invariants.py --check` against the applied tree
  (exit 0) — confirmed before this task is marked Done (AC-029).
- [ ] **Test-registration procedure proof** — TEST-030 passes: each of the
  eight `tests/*.tests.sh`/`.tests.ps1` pairs this feature's tasks author
  (T-001..T-006's own suites plus T-007's parity/installed-layout harness)
  is registered directly in `tests/run-all.sh`/`.ps1`; the final staged
  `.github/workflows/test.yml` candidate under `human-copy/` carries every
  suite's CI steps with a correct, cumulative `MANIFEST.sha256` entry set
  (AC-030) — this item is the feature-wide confirmation point since
  `test.yml` staging is cumulative and this task lands last among the
  script-authoring tasks; T-007 appends its own suite afterward and its
  own Done When re-confirms the final cumulative state.
- [ ] **Suite registration + structural checks** —
  `tests/generate-gate-capabilities.tests.sh`/`.ps1` self-register in
  `tests/run-all.sh`/`.ps1`; a grep self-check confirms no version string
  was mutated outside `scripts/bump-version.sh`.
- [ ] **TDD evidence** — RED (a hand-broken generator failing the drift
  check) and GREEN (the full suite + the human-applied `--check` exit-0
  proof for both the projection and the protected-file bundle). An
  independent quality-gate verdict records PASS, including confirmation
  that the protected-file bundle has been human-applied and verified.

### Out of Scope

- The Registry schema (T-001), the Predicate DSL evaluator (T-002), the
  discovery contract/vendoring step itself (T-003), the Registry validator
  (T-004), the `registry_digest` generator (T-005), and the
  parity/installed-layout harness (T-007).
- Any change to `check-contract.{sh,ps1,py}`'s required-check-set or
  `risk-gate-matrix.md` (Protected Files, above — this Epic introduces no
  new `check-contract`-enforced Gate).

### Blockers

T-001, T-002, T-003, T-004, T-005

(T-005 satisfied for shared-file-serialization purposes only, per
coordinator decision 2026-07-22 option (a) -- see this task's own
implementation report for the deviation record and the future-task
obligation this creates for T-005.)

PARTIALLY BLOCKED (Done When #2 only, 2026-07-22): the six-file
guard-invariants protected-file registration bundle is staged under
`human-copy/` and independently verified mechanically self-consistent
(`generate-guard-invariants.py --check` exits 0 against the staged
overlay in an isolated tree; the live real files are confirmed
byte-unchanged), but is not recommended for a routine human `cp` --
`PHASE2_TARGETS`/`guard-invariants.json` are shared, repository-wide
constants that at least one other in-flight epic
(`feature/epic-189-a1-project-context`, its own future T-009) will also
need to extend; applying either epic's whole-file-replacement candidate
without a human coordination decision on sequencing risks silently
dropping the other epic's registration. Full detail in this task's own
implementation report (Summary, Unresolved Items). The core projection
generator, its test suite, and this feature's ordinary `test.yml`/
`MANIFEST` staging are unaffected and complete.

---

## T-007 Author the cross-script parity and installed-layout invocation harness

Source Issue: https://github.com/aharada54914/sdd-forge/issues/190

Approval: Draft

Status: Planned

Risk: medium

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. `medium` is justified: this task is test-only (a golden-fixture
parity/invocation harness over the four scripts T-002/T-004/T-005/T-006
already implement and already independently verify), so `high`/`critical`
would be over-classification per the policy's own guidance (a task whose
scope is exclusively test-file changes is not, by itself, a sensitive-
surface change) — but it is not `low` either, since it is not cosmetic or
non-behavioral: it exercises real cross-runtime determinism behavior
(Global Constraints, design.md — byte-identical `.sh`/`.ps1`/`.js` output;
identical exit codes/stdout across three simulated installed-plugin
runtimes) that, if it silently regressed, would mask a real non-determinism
defect in an already-shipped script. Required Workflow is `acceptance-first`
per the policy's medium-tier row.

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-006 (AC-031, AC-033, share)

Depends On: T-002, T-004, T-005, T-006 (functional — this harness invokes
all four scripts' wrapper pairs; it cannot exist meaningfully before every
wrapper pair does). T-003 (Global Constraints — serialized only; this task
also reuses T-003's installed-layout fixture pattern for its own
simulated-runtime contexts, an informational, not blocking, relationship).

Planned Files:
- `tests/capability-registry-parity.tests.sh` (new, agent-editable)
- `tests/capability-registry-parity.tests.ps1` (new, agent-editable)
- `tests/fixtures/capability-registry/` (existing after T-001,
  agent-editable — adds the three simulated installed-plugin-context
  fixtures, one per runtime, shared across all four scripts' invocations)
- `tests/run-all.sh` (existing, agent-editable — this suite's registration)
- `tests/run-all.ps1` (existing, agent-editable — this suite's
  registration)
- `specs/epic-190-a2-capability-registry/human-copy/.github/workflows/test.yml`
  (staged candidate, agent-editable — this suite's CI steps, appended
  after T-006's; R-10 protected real path)
- `specs/epic-190-a2-capability-registry/human-copy/MANIFEST.sha256`
  (existing, agent-editable — new entry for this task's staged `test.yml`
  candidate)

Data Migration: none.

Breaking API: no; `capability-registry-parity` is a wholly new,
integration-level test suite; it modifies no production script.

Rollback: revert this task's commit(s); nothing protected is written
directly.

### Goal

Author a golden-fixture parity harness proving, for each of
`evaluate-predicate`, `validate-capability-registry`,
`generate-registry-digest`, and `generate-gate-capabilities`: (a) the
`.sh`- and `.ps1`-wrapper invocations of identical fixture input produce
byte-identical stdout/output (`generate-registry-digest`'s `.js` wrapper
included); (b) each script's wrapper pair, invoked from within a simulated
Claude Code, Codex CLI, and Copilot CLI installed-plugin context against
the identical fixture input, produces identical exit codes and stdout
across all three runtimes.

### Must Read

- `specs/epic-190-a2-capability-registry/requirements.md`
- `specs/epic-190-a2-capability-registry/design.md`
- `specs/epic-190-a2-capability-registry/acceptance-tests.md`
- `specs/epic-190-a2-capability-registry/infra-spec.md`
- `plugins/sdd-quality-loop/scripts/evaluate-predicate.{py,sh,ps1}` (T-002)
- `plugins/sdd-quality-loop/scripts/validate-capability-registry.{py,sh,ps1}`
  (T-004)
- `plugins/sdd-quality-loop/scripts/generate-registry-digest.{py,sh,ps1,js}`
  (T-005)
- `plugins/sdd-quality-loop/scripts/generate-gate-capabilities.{py,sh,ps1}`
  (T-006)
- `tests/registry-discovery.tests.sh`/`.ps1` (T-003's own installed-layout
  fixture pattern this suite's simulated-runtime fixtures reuse)

### Scope

- Write the acceptance checks first (acceptance-first, integration-level —
  each case spans at least two of the four scripts' wrapper pairs):
  TEST-031 (`.sh`/`.ps1`(/`.js`) golden-fixture parity across all four
  scripts), TEST-033 (3-runtime invocation parity across all four scripts,
  tied to T-003's TEST-027 installed-layout fixtures).
- CI resilience per Global Constraints.
- Register `capability-registry-parity` in `tests/run-all.sh`/`.ps1`; stage
  the `.github/workflows/test.yml` candidate appended to T-006's staged
  file — this is the LAST append; the resulting staged candidate carries
  every one of this feature's eight suites' CI steps in task order.

### Done When

- [ ] **Golden-fixture parity** — TEST-031 passes: for all four scripts,
  `.sh`/`.ps1` invocations of identical fixture input produce byte-
  identical stdout/output; `generate-registry-digest`'s `.js` wrapper
  matches its `.sh`/`.ps1` siblings (AC-031).
- [ ] **3-runtime invocation parity** — TEST-033 passes: each of the four
  scripts' wrapper pair, invoked from within a simulated Claude Code, Codex
  CLI, and Copilot CLI installed-plugin context against identical fixture
  input, yields identical exit codes and stdout across all three runtimes
  (AC-033).
- [ ] **Suite/CI registration + final cumulative check** —
  `tests/capability-registry-parity.tests.sh`/`.ps1` self-register in
  `tests/run-all.sh`/`.ps1`; the staged `test.yml` candidate carries all
  eight of this feature's suites' CI steps in task order with a correct,
  complete `MANIFEST.sha256` entry set (re-confirming T-006's AC-030 item
  at the point the chain closes); the LIVE `test.yml` is byte-unchanged
  before/after this task's own commits; a grep self-check confirms no
  version string was mutated outside `scripts/bump-version.sh`.
- [ ] **Acceptance-first evidence** — RED (a deliberately introduced
  cross-wrapper or cross-runtime divergence fixture failing the parity
  matrix) and GREEN (the full suite against the four correct, already-
  shipped scripts). An independent quality-gate verdict records PASS.

### Out of Scope

- Any change to `evaluate-predicate`, `validate-capability-registry`,
  `generate-registry-digest`, `generate-gate-capabilities`, or
  `registry_discovery.py`'s own implementation — this task only tests
  them.
- Live LLM calls, live Provider API calls, or any network call in any
  fixture (acceptance-tests.md Notes; Global Constraints, above).

### Blockers

T-002, T-003, T-004, T-005, T-006
