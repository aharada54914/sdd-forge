# Tasks: epic-192-a4-facet-manifest

Task-Review-Status: Pending

Source: Issue #192 (Epic A4 — Facet Manifest), tracked under epic #187 (AI-DLC
Foundation) /
requirements.md (Spec-Review-Status: Passed) /
design.md (Impl-Review-Status: Passed)

## Lifecycle

`Draft -> Approved -> In Progress -> Implementation Complete -> Done`

A task may enter `Blocked` from any active state. Humans approve tasks.
`implement-task` may set `In Progress`, `Blocked`, or `Implementation Complete`.
Only `quality-gate` may set `Done`.

## Protected Files

This feature's own Protected-File Statement (design.md) is explicit: **this
feature adds no new entry to `guard-invariants.json`'s
`protected_gate_suffixes` or `phase2_human_copy_targets`.** Every schema file
(`contracts/facet-manifest.schema.json`,
`contracts/capability-summary.schema.json`,
`contracts/context-projection.schema.json`), every script
(`validate-facet-manifest`, `validate-capability-summary`,
`validate-context-projection`, `compare-facet-manifest-staleness`, each
`.py`+`.sh`+`.ps1`), their vendored `plugins/sdd-quality-loop/contracts/`
copies, every new `tests/*.tests.{sh,ps1}` pair, `tests/fixtures/
facet-manifest/`, and `tests/run-all.{sh,ps1}` (append-only) are **unprotected
and agent-editable directly** — no task below stages any of them under
`human-copy/`.

The **one** protected surface this feature's tasks touch is
`.github/workflows/test.yml` (R-10 protected, matching every sibling epic's
CI-registration precedent). No task writes it directly. Each of T-001..T-005
stages its own suite's CI steps, appended to the prior task's staged
candidate, under
`specs/epic-192-a4-facet-manifest/human-copy/.github/workflows/test.yml` with
a `specs/epic-192-a4-facet-manifest/human-copy/MANIFEST.sha256` entry. A human
maintainer runs the `cp` + SHA-256 verification once all six suites are
staged (after T-005), and re-runs `tests/run-all.sh`/`.ps1` against the
applied tree before any task depending on a green CI is marked Done.

**No task below writes any other protected path.** Reading a protected path is
not in scope for any task here — this feature reads no Epic A1/A2/A3
protected artifact (design.md Data Plan: "Existing Data Affected: none").

## External Checkout Constraints

This worktree's current checkout does not contain Epic A1's canonicalizer
(`canonicalize-sdd-yaml.{py,sh,ps1,js}`), nor Epic A2's
`validate-capability-registry.py`/`generate-registry-digest` precedent
scripts, nor any of the sibling epics' own `specs/` directories — `ls specs/`
in this checkout lists no `epic-189-a1-*`, `epic-190-a2-*`,
`epic-191-a3-*`, or `epic-193-a5-*` directory. `requirements.md`/`design.md`
already treat these as external, not-yet-landed Assumptions (requirements.md
Assumptions; design.md Cross-Layer Dependencies) and transcribe every shape
this feature borrows from them **verbatim, by structural duplication**, not
by a live cross-file `$ref` or a read of a sibling spec file — so no task
below needs to read a sibling epic's spec file to be authored or
implemented; `design.md` is self-sufficient for every schema/script this
feature defines. Each of T-001/T-002 (the two YAML-reading validators) must
re-verify Epic A1's canonicalizer's actual presence and CLI shape at its own
implementation-start time (matching AGENTS.md's "live-repository snapshot,
not a permanent guarantee" convention) — this is a **Done-gating**
condition for the fixtures that require a working canonicalizer subprocess,
not a **start** blocker (see each task's own Blockers section).

## Global Constraints

- **Two-commit landing plan per task** (commit A = implementation — schema/
  script/suite/fixture edits + `tests/run-all.{sh,ps1}` registration +
  staging this task's `.github/workflows/test.yml` candidate under
  `human-copy/`; commit B = the task's own `CHANGELOG.md` bullet entry).
  Commit A must land before commit B within the same task. Each of
  T-001..T-005 adds its **own** new bullet entry under the repository's
  existing single `## Unreleased` header (CHANGELOG.md's own convention —
  one `## Unreleased` H2, `### 追加`/equivalent subsection, one bullet per
  landing change) citing issue #192 — never edits or removes another task's
  own bullet entry.
- **Serialized `tests/run-all.sh`/`.ps1` array-append and
  `.github/workflows/test.yml` human-copy staging: T-001 → T-002 → T-003 →
  T-004 → T-005**, matching every sibling epic's own established convention
  for a shared, order-sensitive registration file. Each task appends only
  its OWN suite's registration line(s)/CI step(s), after the prior task's,
  never rewriting or reordering an earlier task's entry. A task that lands
  after another whose candidate is not yet human-applied appends to that
  pending staged file rather than starting from the unmodified real
  `test.yml`.
- **Version bumps only via `scripts/bump-version.sh`**; this feature
  introduces no version-mutation path of its own (REQ-008). No task
  hand-edits a version string.
- **CI resilience** (design.md Test Strategy; Diagnostic determinism
  contract) applies to every new `.sh`/`.ps1` suite: no possibly-empty array
  expanded under `set -u`; any `jq` output consumption piped through
  `tr -d '\r'` unconditionally; UTF-8, LF-only diagnostic output on every
  runtime including the `.ps1` wrapper on Windows; a fixed
  `(check-id, JSON-Pointer-path)` diagnostic sort order.
- **No new ADR** — ADR-0016/0019/0020/0021 already normatively cover this
  feature's entire surface (design.md ADR Change Log; Non-goals). No task
  below adds a `docs/adr/00NN-*.md` file.
- Fixture writes happen inside script/test files or `tests/fixtures/
  facet-manifest/` only; no task places a protected basename together with a
  write verb on a Bash command line.
- Every array field a task writes that participates in REQ-004's
  semantic-output comparison (`affected_components`, `required_facets`,
  `conditional_facets`, `resolved_gates`, `capabilities`,
  `lite_eligibility.upgrade_reasons`) is validated stable-sorted by that
  same task's own `array-not-stable-sorted` semantic check (T-001) — this is
  a fixture/validator-authoring obligation for T-001, not a runtime
  constraint any task's own script enforces on itself (no task in this
  feature writes a live Facet Manifest instance; Epic A5 does).
- Preserve unrelated changes; implement one task at a time.

---

## T-001 Author the Facet Manifest schema, its validator, and its two test suites

Source Issue: https://github.com/aharada54914/sdd-forge/issues/192

Approval: Draft

Status: Planned

Risk: high

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md` directly.
`high` is justified, not merely asserted: `contracts/facet-manifest.schema.json`
is a **public API contract** in the policy's own sense — it fixes the output
type Epic A5's Resolver must produce, and Epic A3's already-committed
`check-component-coverage --facet-manifest <path>` already reads
`affected_components` against the exact shape this schema fixes (INV-006, a
hard reverse dependency). A silent defect here (e.g., a schema that
under-constrains `resolved_gates[].id` uniqueness, or a validator that
accepts a non-`sha256:<64hex>` `context_binding` digest) is exactly the
"silent defect causes material harm" surface the policy's `high` tier names:
a downstream Gate would silently trust a malformed or under-specified
Manifest. It is not `critical` (no settlement/safety/irreversible-destructive
surface — this feature ships a structural checker, never a live Gate
enforcement wiring, design.md Protected-File Statement). Required Workflow is
therefore `tdd` (Red→Green) per the policy's high-tier row.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-001, REQ-006 (share — AC-017, AC-018, AC-028, AC-041,
AC-047, AC-048), REQ-007 (share — AC-034), REQ-008 (share — AC-035)

Depends On: none (functional — root of this feature's dependency graph; the
Facet Manifest schema is authored from `design.md`'s own fully-specified API
block, no sibling schema or script needed).

Planned Files:
- `contracts/facet-manifest.schema.json` (new, agent-editable — draft-07
  schema per design.md API / Contract Plan: the 10-field top-level
  `required` set, `conditionalFacet`/`evidenceNode`/`resolvedGate`/
  `liteEligibility`/`contextBinding`/`resolverBlock`/`sha256Digest`
  definitions, the combined syntax+root-allowlist
  `dependency_pointers[].pattern`)
- `plugins/sdd-quality-loop/scripts/validate-facet-manifest.py` (new,
  agent-editable — hand-rolled, stdlib-only draft-07 subset validator +
  five semantic checks + YAML parse contract, design.md `validate-facet-
  manifest` contract)
- `plugins/sdd-quality-loop/scripts/validate-facet-manifest.sh` (new,
  agent-editable — thin wrapper)
- `plugins/sdd-quality-loop/scripts/validate-facet-manifest.ps1` (new,
  agent-editable — twin; LF-only diagnostic output per the determinism
  contract)
- `plugins/sdd-quality-loop/contracts/facet-manifest.schema.json` (new,
  agent-editable — vendored packaged copy, Discovery contract)
- `tests/facet-manifest-schema.tests.sh` / `.ps1` (new, agent-editable)
- `tests/facet-manifest-semantics.tests.sh` / `.ps1` (new, agent-editable)
- `tests/fixtures/facet-manifest/` (new fixture tree — base shape +
  this task's schema/semantic fixtures; extended by later tasks)
- `tests/run-all.sh` / `.ps1` (existing, agent-editable — this task's
  2-suite registration, first in the serialized order)
- `specs/epic-192-a4-facet-manifest/human-copy/.github/workflows/test.yml`
  (new staged candidate, agent-editable — this task's 2 suites' CI steps;
  R-10 protected real path, human-copy only)
- `specs/epic-192-a4-facet-manifest/human-copy/MANIFEST.sha256` (new,
  agent-editable — SHA-256 entries for the staged candidate)
- `specs/epic-192-a4-facet-manifest/verification/T-001/` (new — Red/Green
  logs; the one-time draft-07 metaschema conformance record for
  `facet-manifest.schema.json`, acceptance-tests.md "Spec-Authoring-Time
  Manual Review Record")
- `CHANGELOG.md` (existing, agent-editable — this task's own new bullet
  under the existing `## Unreleased` header, citing #192)

Data Migration: none — wholly new contract file and scripts (design.md Data
Plan: "Migration Strategy: none").

Breaking API: no; `contracts/facet-manifest.schema.json` and
`validate-facet-manifest` are wholly new; no existing schema or script
changes.

Rollback: revert this task's two commits (B then A, or both) via `git
revert`; nothing protected is written directly. The only protected surface
staged is `.github/workflows/test.yml`'s human-copy candidate — a revert
re-stages a corrected candidate for a human to re-`cp`; if T-001's steps were
already human-applied, the revert PR states explicitly whether a human
should also hand-revert the applied CI steps.

### Goal

Author `contracts/facet-manifest.schema.json` verbatim per design.md's API /
Contract Plan JSON block; author `validate-facet-manifest.{py,sh,ps1}`
implementing the closed hand-rolled draft-07 subset (`type` incl. array-form/
union types, `required`, `additionalProperties`, `properties`,
`propertyNames`, `pattern`, `enum`, `const`, `uniqueItems`, `minItems`,
`minLength`, `if`/`then`/`else`, `not`, `oneOf`, boolean subschema values,
`items`, `$ref`/`definitions`) plus the five semantic checks
(`schema-invalid`, `resolved-gate-id-duplicate`, `facet-classification-
conflict`, `conditional-facet-duplicate`, `array-not-stable-sorted` —
including `lite_eligibility.upgrade_reasons`'s own scope) and the YAML parse
contract (the sole YAML→structure path is a `canonicalize-sdd-yaml`
subprocess invocation + `json.loads`, never a hand-rolled parser; a non-zero
canonicalizer exit surfaces as `facet-manifest: canonicalizer-invocation-
failed: <detail>`, never swallowed). Author `tests/facet-manifest-
schema.tests.{sh,ps1}` and `tests/facet-manifest-semantics.tests.{sh,ps1}`
per design.md Test Strategy items 1-2. Register both suites in
`tests/run-all.{sh,ps1}` and stage this task's CI steps under `human-copy/`.

### Must Read

- `specs/epic-192-a4-facet-manifest/requirements.md`
- `specs/epic-192-a4-facet-manifest/design.md` (API / Contract Plan
  `facet-manifest.schema.json` block; `validate-facet-manifest` contract;
  YAML parse contract; Diagnostic determinism contract; Discovery contract;
  Test Strategy items 1-2)
- `specs/epic-192-a4-facet-manifest/acceptance-tests.md` (AC-001..011,
  AC-017, AC-018, AC-028, AC-034, AC-035, AC-041, AC-047, AC-048 rows; the
  Spec-Authoring-Time Manual Review Record's draft-07 metaschema note)
- `specs/epic-192-a4-facet-manifest/security-spec.md` (Trust Boundaries B1,
  B2; STRIDE rows for B1/B2; Security Tests TEST-009/TEST-031)
- Epic A1's canonicalizer CLI shape and Epic A2's `validate-capability-
  registry.py` diagnostic-style/hand-rolled-validator precedent are cited
  normatively inside design.md itself (API / Contract Plan; YAML parse
  contract) — this checkout contains neither script (External Checkout
  Constraints, above); do not attempt to read a sibling epic's spec file
  that is absent from this worktree. Re-verify the canonicalizer's actual
  presence and CLI shape via `ls plugins/sdd-quality-loop/scripts/
  canonicalize-sdd-yaml*` at this task's own implementation-start time.

### Scope

Commit A (implementation — schema + validator + two suites + fixtures + CI
wiring):
- Write the acceptance checks first (TDD Red→Green): TEST-001 (`$id`
  convention + draft-07 existence), TEST-002 (required-field matrix, one
  fixture per top-level required field), TEST-003 (`uniqueItems` +
  empty-array), TEST-004 (`applied`/`reason` `if`/`then`/`else`), TEST-005
  (Evidence-array-shape conformance, out-of-enum `operator` rejection),
  TEST-006 (`resolved_gates[]` shape + `stage` enum), TEST-007
  (`capability_minimum_enforcement` const/absent + aggregate fixture),
  TEST-008 (`lite_eligibility` required, `upgrade_reasons` absent now
  rejected), TEST-009 (digest pattern + `minItems`), TEST-010 (semver
  pattern), TEST-011 (decision document v2 §16 worked-example
  conformance), TEST-017/TEST-018 (combined syntax+root
  `dependency_pointers[].pattern`), TEST-041 (`evidenceNode` `outcome:
  "warn"` requires `reason`), TEST-048's schema half (`upgrade_reasons`
  `uniqueItems`), TEST-028 (the five-row semantic diagnostic-id table, one
  fixture per row, plus one fully-clean fixture proving a negative),
  TEST-047 (`conditional-facet-duplicate`), TEST-048's semantic half
  (`upgrade_reasons` out-of-order rejection).
- CI resilience per Global Constraints.
- Register `facet-manifest-schema`/`facet-manifest-semantics` (`.sh`/`.ps1`)
  in `tests/run-all.sh`/`.ps1`; stage the `.github/workflows/test.yml`
  candidate with this task's CI steps under `human-copy/` +
  `MANIFEST.sha256`.
- Vendor `plugins/sdd-quality-loop/contracts/facet-manifest.schema.json`
  from the canonical `contracts/facet-manifest.schema.json` (byte-identical
  copy at authoring time; T-005 later adds the automated `--check` drift
  gate across all three schema files).
- Validate `contracts/facet-manifest.schema.json` once, manually, against
  the official draft-07 metaschema (`http://json-schema.org/draft-07/
  schema#`) using a tool outside this feature's own closed-subset engine;
  record the result in `specs/epic-192-a4-facet-manifest/verification/
  T-001/metaschema-conformance.md`.

Commit B (documentation):
- Add this task's own new bullet under the existing `## Unreleased` header
  in `CHANGELOG.md`, citing #192.

### Done When

- [ ] **Schema shape** — TEST-001..011, TEST-017, TEST-018, TEST-041,
  TEST-048 (schema half) pass against `tests/facet-manifest-
  schema.tests.sh` (`sh tests/facet-manifest-schema.tests.sh` exits 0):
  `$id`/draft-07 existence (AC-001); the exact 10-field `required` matrix
  and `capability_minimum_enforcement`'s sole-optional status (AC-002);
  `uniqueItems`+empty-array acceptance on `affected_components`/
  `required_facets`/`capabilities` (AC-003); the `applied`/`reason`
  `if`/`then`/`else` branch pair (AC-004); Evidence-array-shape conformance
  + out-of-enum `operator` rejection (AC-005); `resolved_gates[]` shape +
  `stage` enum (AC-006); `capability_minimum_enforcement` const/absent +
  aggregate fixture (AC-007); `lite_eligibility` required, `upgrade_reasons`
  absent rejected (AC-008); digest pattern + `minItems: 1` (AC-009); semver
  pattern (AC-010); the decision-document worked example (AC-011); the
  combined syntax+root `dependency_pointers[].pattern` (AC-017, AC-018);
  `evidenceNode` `outcome: "warn"` requires `reason` (AC-041);
  `upgrade_reasons`' schema-level `uniqueItems` (AC-048 schema half).
- [ ] **Semantic checks** — TEST-028, TEST-047, TEST-048 (semantic half)
  pass against `tests/facet-manifest-semantics.tests.sh` (`sh tests/
  facet-manifest-semantics.tests.sh` exits 0): one fixture per diagnostic-id
  table row (`schema-invalid`, `resolved-gate-id-duplicate`,
  `facet-classification-conflict`, `conditional-facet-duplicate`,
  `array-not-stable-sorted`) plus one fully-clean fixture proving a negative
  (AC-028); `conditional_facets[]` same-`facet`-value rejection (AC-047);
  `upgrade_reasons` out-of-lexicographic-order rejection (AC-048 semantic
  half).
- [ ] **REQ-007 placement regression** — TEST-034 passes: a fixture
  `specs/<feature>/` tree with `facet-manifest.yaml`/`capability-
  summary.yaml` present alongside `requirements.md`/`design.md`/
  `acceptance-tests.md` passes `check-sdd-structure.sh`'s repository-root-
  level checks unchanged (AC-034).
- [ ] **Suite/CI registration + governance** — `tests/facet-manifest-
  schema.tests.sh`/`.ps1` and `tests/facet-manifest-semantics.tests.sh`/
  `.ps1` self-register in `tests/run-all.sh`/`.ps1` (grep self-check); the
  staged `.github/workflows/test.yml` candidate exists with correct
  `MANIFEST.sha256` entries and the LIVE `test.yml` is byte-unchanged
  before/after this task's commits; `CHANGELOG.md` gains this task's own
  new bullet under `## Unreleased` citing #192 (AC-035 share); a grep
  self-check confirms no version string was mutated outside
  `scripts/bump-version.sh` (AC-035 share).
- [ ] **Metaschema conformance record** — `specs/epic-192-a4-facet-
  manifest/verification/T-001/metaschema-conformance.md` records the
  one-time result of validating `contracts/facet-manifest.schema.json`
  against the official draft-07 metaschema (acceptance-tests.md
  "Spec-Authoring-Time Manual Review Record").
- [ ] **TDD evidence** — RED (each schema/semantic fixture against a
  deliberately non-conformant schema/validator) and GREEN (the full suite
  against the correct schema/validator), captured in
  `specs/epic-192-a4-facet-manifest/verification/T-001/{red,green}-sh.log`.
  An independent quality-gate verdict (a named reviewer distinct from the
  implementing agent) records PASS.

### Out of Scope

- `contracts/capability-summary.schema.json` / `contracts/context-
  projection.schema.json` and their validators (T-002, T-003).
- `compare-facet-manifest-staleness` (T-004).
- The cross-script byte-identical parity suite, the installed-layout
  discovery fixtures, and the provider-neutrality scan (T-005) — the
  vendored-copy `--check` drift-gate mechanism itself is T-005's, not
  T-001's; T-001 only creates the initial byte-identical vendored copy.
- Building the Capability Resolver or writing any live `facet-manifest.yaml`
  instance (Non-goals, requirements.md).

### Blockers

None

(Not a task-ID blocker, but an external Done-gating condition: Epic A1's
canonicalizer must exist as a real, invocable artifact for the YAML
parse-contract fixtures — the successful-round-trip case and the
`canonicalizer-invocation-failed` fail-closed case — to actually run;
until then those specific fixtures are red and this task cannot reach Done,
per External Checkout Constraints above. Every schema-only and
semantic-check fixture that does not require an actual canonicalizer
subprocess invocation is unaffected and can proceed to Done independently.)

---

## T-002 Author the Capability Summary schema, its validator, and its test suite

Source Issue: https://github.com/aharada54914/sdd-forge/issues/192

Approval: Draft

Status: Planned

Risk: high

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly (revised at task-review round 1 per reviewer-b's RISK-APPROPRIATE
finding — the original `medium` classification self-certified a narrowing
the policy forbids; see below). `high` is justified, not merely asserted:
the policy's `high` tier names "public API contracts" as a sensitive
surface, and `contracts/capability-summary.schema.json` is exactly that —
design.md's own Cross-Layer Dependencies states "Every schema and script
this feature defines → consumed by Epic A5's Capability Resolver," the same
downstream-consumer relationship T-001's Facet Manifest schema (already
`high`) carries. The policy also states explicitly, "An agent MUST NOT
self-certify its own risk tier as the basis for relaxing a gate" — this
task's original Risk Rationale did exactly that, arguing the artifact's
*current* absence of an already-committed downstream reader (unlike
`affected_components`, INV-006) made it materially lower-risk than T-001's
sibling schema; the policy's "public API contracts" trigger names no such
carve-out, so that narrowing is not a valid basis for a tier below `high`.
Required Workflow is therefore `tdd` (Red→Green) per the policy's high-tier
row.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-002, REQ-006 (share — AC-029), REQ-008 (share — AC-035)

Depends On: none (functional — `capability-summary.schema.json` is
independent of `facet-manifest.schema.json`; both are authored directly
from design.md's own API / Contract Plan). Serialized after T-001 for the
shared `tests/run-all.sh`/`.ps1` array and `.github/workflows/test.yml`
staging (Global Constraints).

Planned Files:
- `contracts/capability-summary.schema.json` (new, agent-editable — the
  Lite-only six-field schema, design.md API / Contract Plan)
- `plugins/sdd-quality-loop/scripts/validate-capability-summary.py` (new,
  agent-editable — schema-conformance-only check, no semantic check beyond
  it, design.md `validate-capability-summary` contract)
- `plugins/sdd-quality-loop/scripts/validate-capability-summary.sh` (new,
  agent-editable — thin wrapper)
- `plugins/sdd-quality-loop/scripts/validate-capability-summary.ps1` (new,
  agent-editable — twin)
- `plugins/sdd-quality-loop/contracts/capability-summary.schema.json` (new,
  agent-editable — vendored packaged copy)
- `tests/capability-summary-schema.tests.sh` / `.ps1` (new, agent-editable)
- `tests/fixtures/facet-manifest/` (existing after T-001, agent-editable —
  adds this task's Capability Summary fixtures)
- `tests/run-all.sh` / `.ps1` (existing, agent-editable — this task's
  1-suite registration, appended after T-001's)
- `specs/epic-192-a4-facet-manifest/human-copy/.github/workflows/test.yml`
  (existing after T-001, agent-editable — this task's CI step appended)
- `specs/epic-192-a4-facet-manifest/human-copy/MANIFEST.sha256` (existing,
  agent-editable — new entry for this task's staged additions)
- `specs/epic-192-a4-facet-manifest/verification/T-002/` (new — acceptance-
  first Red/Green logs; the metaschema conformance record for
  `capability-summary.schema.json`)
- `CHANGELOG.md` (existing, agent-editable — this task's own new bullet)

Data Migration: none.

Breaking API: no; wholly new contract file and script.

Rollback: revert this task's two commits; nothing protected is written
directly; the staged `test.yml` addition is human-applied only.

### Goal

Author `contracts/capability-summary.schema.json` verbatim per design.md's
API / Contract Plan (Lite-only, `additionalProperties: false`, no `track:
"full"` branch); author `validate-capability-summary.{py,sh,ps1}`
(schema-conformance check only, reusing T-001's hand-rolled draft-07 subset
engine's same keyword coverage, no new keyword needed). Author
`tests/capability-summary-schema.tests.{sh,ps1}` per design.md Test
Strategy item 3. Register the suite, stage this task's CI step.

### Must Read

- `specs/epic-192-a4-facet-manifest/requirements.md`
- `specs/epic-192-a4-facet-manifest/design.md` (API / Contract Plan
  `capability-summary.schema.json` block; `validate-capability-summary`
  contract; Design Decisions "Capability Summary schema is
  Lite-track-only")
- `specs/epic-192-a4-facet-manifest/acceptance-tests.md` (AC-012, AC-013,
  AC-014, AC-029, AC-035 rows)
- `specs/epic-192-a4-facet-manifest/security-spec.md` (Trust Boundaries B1
  — this validator shares the same YAML parse contract as T-001's)
- `plugins/sdd-quality-loop/scripts/validate-facet-manifest.py` (T-001's
  hand-rolled draft-07 subset engine and YAML parse contract, this task's
  own direct precedent within this checkout)

### Scope

Commit A (implementation — schema + validator + suite + fixtures + CI
wiring):
- Write the acceptance checks first (TDD Red→Green): TEST-012 (Lite-only
  required-field set), TEST-013 (decision v2 §6 worked example, `schema`/
  `feature`/`track` added), TEST-014 (`additionalProperties: false`
  rejects a `facet_manifest_ref`/extra field), TEST-029 (`validate-
  capability-summary.py` exit-0/non-zero contract over AC-013/AC-014's own
  fixtures).
- CI resilience per Global Constraints.
- Register `capability-summary-schema` in `tests/run-all.sh`/`.ps1`; stage
  the `.github/workflows/test.yml` candidate appended to T-001's staged
  file.
- Vendor `plugins/sdd-quality-loop/contracts/capability-summary.schema.json`.
- Validate `contracts/capability-summary.schema.json` once, manually,
  against the official draft-07 metaschema; record the result.

Commit B (documentation):
- Add this task's own new bullet under `## Unreleased` in `CHANGELOG.md`,
  citing #192.

### Done When

- [ ] **Schema shape + worked example + regression lock** — TEST-012,
  TEST-013, TEST-014 pass against `tests/capability-summary-
  schema.tests.sh` (`sh tests/capability-summary-schema.tests.sh` exits 0):
  the exact six-field `required` set and `track: "lite"` const (AC-012);
  decision v2 §6's own example plus `schema`/`feature`/`track` (AC-013);
  `additionalProperties: false` rejects an extra/full-track-only field
  (AC-014).
- [ ] **Validator contract** — TEST-029 passes: `validate-capability-
  summary.py --summary <path>` exits 0 on AC-013's fixture and non-zero
  with `capability-summary: schema-invalid: <detail>` on AC-014's fixture
  (AC-029).
- [ ] **Suite/CI registration + governance** — `tests/capability-summary-
  schema.tests.sh`/`.ps1` self-register in `tests/run-all.sh`/`.ps1`; the
  staged `.github/workflows/test.yml` candidate carries this task's
  appended CI step with a correct `MANIFEST.sha256` entry, LIVE `test.yml`
  byte-unchanged before/after; `CHANGELOG.md` gains this task's own bullet
  (AC-035 share); no version string mutated outside
  `scripts/bump-version.sh` (AC-035 share).
- [ ] **Metaschema conformance record** — `specs/epic-192-a4-facet-
  manifest/verification/T-002/metaschema-conformance.md` records the
  one-time draft-07 metaschema check result for `capability-
  summary.schema.json`.
- [ ] **TDD evidence** — RED (each fixture against a deliberately
  non-conformant schema/validator) and GREEN (the full suite against the
  correct schema/validator), captured in `specs/epic-192-a4-facet-manifest/
  verification/T-002/{red,green}-sh.log`. An independent quality-gate
  verdict (a named reviewer distinct from the implementing agent) records
  PASS.

### Out of Scope

- `contracts/facet-manifest.schema.json` (T-001), `contracts/context-
  projection.schema.json` (T-003), `compare-facet-manifest-staleness`
  (T-004), the cross-script parity suite (T-005).
- Any full-track Capability Summary shape (Non-goals).

### Blockers

T-001

(Not a task-ID blocker, but the same external Done-gating condition as
T-001: Epic A1's canonicalizer must exist as a real artifact for this
validator's own YAML parse-contract fixtures to run — see External Checkout
Constraints, above.)

---

## T-003 Author the Context Projection schema and its validator and test suite

Source Issue: https://github.com/aharada54914/sdd-forge/issues/192

Approval: Draft

Status: Planned

Risk: high

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. `high` is justified: `contracts/context-projection.schema.json`
fixes the shape of the artifact at Epic A1's **already-reserved, protected**
path (`plugins/sdd-quality-loop/scripts/generated/project-context.
resolved.json`, INV-007) — every `dependency_pointers` RFC 6901 resolution
this feature and every downstream Facet-Manifest consumer performs is only
sound if the re-keying step this schema fixes is correct. A silent defect
(e.g., a `components` key vocabulary narrower than Epic A1's own constraint,
"B3", or a `shared_paths[]` `oneOf` that silently accepts a malformed
bounded/unbounded entry) would corrupt every future pointer-resolution
consumer without any visible symptom until a specific pointer failed to
resolve — the policy's "silent defect causes material harm" surface. It is
not `critical` (no settlement/safety surface; this task builds only the
schema/validator, never the generator that writes to the reserved path —
Non-goals). Required Workflow is therefore `tdd` per the policy's high-tier
row.

Required Workflow: tdd

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-003, REQ-006 (share — AC-030, AC-042), REQ-008 (share —
AC-035)

Depends On: none (functional — `context-projection.schema.json` is
independent of the other two schemas; `validate-context-projection` reads
JSON directly, no YAML/canonicalizer dependency at all, design.md
`validate-context-projection` contract). Serialized after T-002 for the
shared `tests/run-all.sh`/`.ps1` array and `.github/workflows/test.yml`
staging (Global Constraints).

Planned Files:
- `contracts/context-projection.schema.json` (new, agent-editable — the
  re-keyed `components` object shape (`propertyNames: {"minLength": 1}` +
  schema-typed `additionalProperties`, B3's relaxation), `shared_paths[]`
  `oneOf` branch, `projectedComponent` definition, design.md API / Contract
  Plan)
- `plugins/sdd-quality-loop/scripts/validate-context-projection.py` (new,
  agent-editable — schema-conformance-only check, stdlib `json.load`, no
  YAML/canonicalizer subprocess)
- `plugins/sdd-quality-loop/scripts/validate-context-projection.sh` (new,
  agent-editable — thin wrapper)
- `plugins/sdd-quality-loop/scripts/validate-context-projection.ps1` (new,
  agent-editable — twin)
- `plugins/sdd-quality-loop/contracts/context-projection.schema.json` (new,
  agent-editable — vendored packaged copy)
- `tests/context-projection-schema.tests.sh` / `.ps1` (new, agent-editable)
- `tests/fixtures/facet-manifest/` (existing, agent-editable — adds this
  task's Context Projection fixtures: the two-component re-keying fixture
  with one non-slug-shaped id, the source-omission fixture,
  `dependency_pointers` end-to-end resolution fixture, `shared_paths[]`
  `oneOf` fixtures)
- `tests/run-all.sh` / `.ps1` (existing, agent-editable — this task's
  1-suite registration, appended after T-002's)
- `specs/epic-192-a4-facet-manifest/human-copy/.github/workflows/test.yml`
  (existing, agent-editable — this task's CI step appended)
- `specs/epic-192-a4-facet-manifest/human-copy/MANIFEST.sha256` (existing,
  agent-editable — new entry)
- `specs/epic-192-a4-facet-manifest/verification/T-003/` (new — Red/Green
  logs; metaschema conformance record for `context-projection.schema.json`)
- `CHANGELOG.md` (existing, agent-editable — this task's own new bullet)

Data Migration: none — this task writes no instance at Epic A1's reserved
path; it only fixes the schema that a future Epic A5 write must satisfy
(design.md API / Contract Plan, "Generation procedure... normative for Epic
A5's future implementation, not built by this feature").

Breaking API: no; wholly new contract file and script; Epic A1's own
reservation of the target path is unmodified (design.md Cross-Layer
Dependencies).

Rollback: revert this task's two commits; nothing protected is written
directly (this task never writes to the reserved `project-context.
resolved.json` path itself — only the schema it must conform to, at an
unprotected `contracts/` location).

### Goal

Author `contracts/context-projection.schema.json` verbatim per design.md's
API / Contract Plan (the re-keyed `components` object with A1-identical key
vocabulary, "B3"; the `shared_paths[]` bounded/unbounded `oneOf`;
`projectedComponent`). Author `validate-context-projection.{py,sh,ps1}`
(schema-conformance only, `json.load`, no YAML parse contract). Author
`tests/context-projection-schema.tests.{sh,ps1}` per design.md Test
Strategy item 4, including the end-to-end RFC 6901 resolution proof and the
source-omission normalization fixture ("B8"). Register the suite, stage
this task's CI step.

### Must Read

- `specs/epic-192-a4-facet-manifest/requirements.md`
- `specs/epic-192-a4-facet-manifest/design.md` (API / Contract Plan
  `context-projection.schema.json` block; "Generation procedure" — read for
  the re-keying shape it fixes, not to build the procedure itself, which is
  Non-goals; `validate-context-projection` contract)
- `specs/epic-192-a4-facet-manifest/acceptance-tests.md` (AC-015, AC-016,
  AC-030, AC-042, AC-035 rows)
- `specs/epic-192-a4-facet-manifest/infra-spec.md` (Deployment Topology —
  the reserved-path context this schema fixes)

### Scope

Commit A (implementation — schema + validator + suite + fixtures + CI
wiring):
- Write the acceptance checks first (TDD Red→Green): TEST-015 (re-keying
  proof: two-component fixture, one non-slug-shaped id, exactly two
  id-keyed entries, no `id` sub-field; source-omission normalization
  fixture, "B8"), TEST-016 (end-to-end RFC 6901 resolution of `/components/
  desktop-client/artifact_kinds` against an AC-015-shaped fixture),
  TEST-030 (`validate-context-projection.py` exit-0/non-zero contract,
  including the non-slug-key positive fixture and the still-array-shaped
  `components` negative fixture), TEST-042 (`shared_paths[]` `oneOf`:
  bounded-valid, unbounded-valid, both-rejected, neither-rejected).
- CI resilience per Global Constraints.
- Register `context-projection-schema` in `tests/run-all.sh`/`.ps1`; stage
  the `.github/workflows/test.yml` candidate appended to T-002's staged
  file.
- Vendor `plugins/sdd-quality-loop/contracts/context-projection.schema.json`.
- Validate `contracts/context-projection.schema.json` once, manually,
  against the official draft-07 metaschema; record the result.

Commit B (documentation):
- Add this task's own new bullet under `## Unreleased` in `CHANGELOG.md`,
  citing #192.

### Done When

- [ ] **Re-keying + source-omission proof** — TEST-015 passes against
  `tests/context-projection-schema.tests.sh` (`sh tests/context-projection-
  schema.tests.sh` exits 0): a two-component fixture with one non-slug-
  shaped id (e.g. `Desktop/App`) re-keys to exactly two id-valued keys, no
  `id` sub-field; a source omitting `components`/`shared_paths` re-keys to
  `components: {}`/`shared_paths: []` (AC-015).
- [ ] **End-to-end pointer resolution** — TEST-016 passes: `/components/
  desktop-client/artifact_kinds` resolves via RFC 6901 against an
  AC-015-shaped fixture to a real value (AC-016).
- [ ] **Validator enforcement** — TEST-030 passes: `validate-context-
  projection.py --projection <path>` exits 0 on a valid re-keyed fixture
  including the non-slug-key case, and non-zero on a still-array-shaped
  `components` fixture (AC-030).
- [ ] **`shared_paths[]` oneOf branch** — TEST-042 passes: a bounded entry
  (`pattern`+`components`) and an unbounded entry (`pattern`+
  `classification: "cross-cutting"`) each validate; an entry carrying both,
  and an entry carrying neither, are each rejected (AC-042).
- [ ] **Suite/CI registration + governance** — `tests/context-projection-
  schema.tests.sh`/`.ps1` self-register in `tests/run-all.sh`/`.ps1`; the
  staged `.github/workflows/test.yml` candidate carries this task's
  appended CI step with a correct `MANIFEST.sha256` entry, LIVE `test.yml`
  byte-unchanged before/after; `CHANGELOG.md` gains this task's own bullet
  (AC-035 share); no version string mutated outside
  `scripts/bump-version.sh` (AC-035 share).
- [ ] **Metaschema conformance record** — `specs/epic-192-a4-facet-
  manifest/verification/T-003/metaschema-conformance.md` records the
  one-time draft-07 metaschema check result for `context-
  projection.schema.json`.
- [ ] **TDD evidence** — RED (each fixture against a deliberately
  non-conformant schema/validator, including a still-array-shaped
  `components` case) and GREEN (the full suite), captured in
  `specs/epic-192-a4-facet-manifest/verification/T-003/{red,green}-sh.log`.
  An independent quality-gate verdict records PASS.

### Out of Scope

- `contracts/facet-manifest.schema.json` (T-001), `contracts/capability-
  summary.schema.json` (T-002), `compare-facet-manifest-staleness`
  (T-004), the cross-script parity suite (T-005).
- Building the Context Projection generator or writing any instance at
  Epic A1's reserved path (Non-goals — Epic A5's scope).
- Deciding Context Projection's regeneration cadence (OQ-002, an Epic A5
  CI-wiring decision).

### Blockers

T-001, T-002

---

## T-004 Author the staleness comparator and its test suite

Source Issue: https://github.com/aharada54914/sdd-forge/issues/192

Approval: Draft

Status: Planned

Risk: high

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. `high` is justified, not merely asserted: `compare-facet-manifest-
staleness` implements REQ-004's Policy-Weakening fail-closed contract —
security-spec.md's own B3 boundary — whose entire purpose is to prevent a
weakened or indeterminate-verdict axis from being laundered into a `fresh`/
`stale` verdict (ADR-0021's own motivation, "an in-progress Feature can pass
its Gate with stale, insufficient artifacts"). A silent defect here (e.g.,
treating an omitted `--*-weakening` flag as `indeterminate` instead of an
argument error, or short-circuiting to `fresh` on a `minor`/`minor-rule-set`
bump with no digest change) is precisely the "silent defect causes material
harm" surface the policy's `high` tier names — a downstream Gate/CI caller
would trust a `fresh` verdict that should have Blocked. It is not `critical`
(this feature wires no live Gate/CI caller yet — Non-goals; the comparator's
own Block outcome is "a decision surfaced to whichever future Gate or CI
process invokes it," design.md Protected-File Statement). Required Workflow
is therefore `tdd` per the policy's high-tier row.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-004, REQ-005, REQ-006 (share — AC-044, AC-045, AC-046),
REQ-008 (share — AC-035)

Depends On: T-001 (functional — `compare-facet-manifest-staleness` uses the
identical Discovery contract T-001 established to locate `facet-manifest.
schema.json` for its own input-shape validation before comparing, design.md
Discovery contract; it also runs `validate-facet-manifest`'s own
schema-conformance check against both `--old-manifest`/`--new-manifest`
inputs before any branch, API / Contract Plan branch 0). Serialized after
T-003 for the shared `tests/run-all.sh`/`.ps1` array and
`.github/workflows/test.yml` staging (Global Constraints; T-002/T-003 are
not functional dependencies — the comparator consumes only Facet Manifest
instances, never Capability Summary or Context Projection).

Planned Files:
- `plugins/sdd-quality-loop/scripts/compare-facet-manifest-staleness.py`
  (new, agent-editable — the normative CLI: `--old-manifest`/
  `--new-manifest`/three mandatory `--*-weakening` flags/
  `--resolver-version-bump`; the 5-branch precedence table (argument
  validation → Policy-Weakening short-circuit → major-forced → digest-
  unchanged-none/patch-only short-circuit → ordinary semantic-output
  comparison); the `<status>:<reason>` stdout contract; exit codes
  `0`/`1`/`2`/`3`; the stdout/stderr channel separation, design.md
  `compare-facet-manifest-staleness` contract)
- `plugins/sdd-quality-loop/scripts/compare-facet-manifest-staleness.sh`
  (new, agent-editable — thin wrapper; no `.js` wrapper, design.md Global
  Constraints)
- `plugins/sdd-quality-loop/scripts/compare-facet-manifest-staleness.ps1`
  (new, agent-editable — twin; LF-only exit-3 stderr diagnostics)
- `tests/facet-manifest-staleness.tests.sh` / `.ps1` (new, agent-editable)
- `tests/fixtures/facet-manifest/` (existing, agent-editable — adds this
  task's staleness fixture pairs: REQ-004's full branch table + REQ-005's
  version-bump tiers + the argument-error class)
- `tests/run-all.sh` / `.ps1` (existing, agent-editable — this task's
  1-suite registration, appended after T-003's)
- `specs/epic-192-a4-facet-manifest/human-copy/.github/workflows/test.yml`
  (existing, agent-editable — this task's CI step appended)
- `specs/epic-192-a4-facet-manifest/human-copy/MANIFEST.sha256` (existing,
  agent-editable — new entry)
- `specs/epic-192-a4-facet-manifest/verification/T-004/` (new — Red/Green
  logs)
- `CHANGELOG.md` (existing, agent-editable — this task's own new bullet)

Data Migration: none. `compare-facet-manifest-staleness` has no schema of
its own to vendor (design.md Deployment / CI Plan: "This feature adds three
new schema files, not four").

Breaking API: no; wholly new script; no existing contract or script
changes.

Rollback: revert this task's two commits; nothing protected is written
directly; the comparator itself writes nothing (security-spec.md: "writes
nothing").

### Goal

Author `compare-facet-manifest-staleness.{py,sh,ps1}` implementing REQ-004's
Policy-Weakening fail-closed contract (three mandatory, explicit
`--*-weakening` inputs, never expressed by flag omission) and REQ-005's
three-tier `resolver.version` policy (patch/minor/major, plus the dedicated
`minor-rule-set` input), per design.md's normative CLI/branch-order/exit-
code/diagnostic-channel contract exactly. Author `tests/facet-manifest-
staleness.tests.{sh,ps1}` per design.md Test Strategy item 5, covering
REQ-004's full branch table, REQ-005's version-bump tiers, and the argument-
error class. Register the suite, stage this task's CI step.

### Must Read

- `specs/epic-192-a4-facet-manifest/requirements.md` (REQ-004, REQ-005 in
  full; Edge Cases — Policy-Weakening/major-bump precedence)
- `specs/epic-192-a4-facet-manifest/design.md` (`compare-facet-manifest-
  staleness` contract in full: Invocation, Output, Exit codes, Branch
  order; Design Decisions — the mandatory-weakening-inputs and
  branch-order-fix decisions)
- `specs/epic-192-a4-facet-manifest/acceptance-tests.md` (AC-019..027,
  AC-039, AC-040, AC-044, AC-045, AC-046, AC-035 rows)
- `specs/epic-192-a4-facet-manifest/security-spec.md` (Trust Boundaries B3;
  STRIDE B3 rows; Security Tests TEST-023/024/040/044/046)
- `plugins/sdd-quality-loop/scripts/validate-facet-manifest.py` (T-001's
  schema-conformance check this script invokes on both `--old-manifest`/
  `--new-manifest` before comparing, branch 0)

### Scope

Commit A (implementation — comparator + suite + fixtures + CI wiring):
- Write the acceptance checks first (TDD Red→Green): TEST-019 (digest-only
  change, explicit `not-weakened`, not stale), TEST-020 (same-gate-ID
  attribute change, stale), TEST-021 (`evidence`-inclusion lock, stale —
  the reversed "B1" fixture), TEST-022 (minimum-enforcement tightening,
  stale), TEST-023 (Policy-Weakening short-circuit, comparison never
  evaluated), TEST-024 (indeterminate-verdict fail-closed Block + forward-
  compatible not-weakened sub-case), TEST-025 (patch-tier no-op),
  TEST-026 (minor-tier impact assessment, both sub-cases, byte-identical
  `context_binding`), TEST-027 (major-tier forced-regardless + Block
  precedence), TEST-039 (no-axis-changed WARN-only `fresh`, no comparison
  attempted), TEST-040 (ownership-axis parity, both sub-cases), TEST-044
  (the CLI contract itself: mandatory-flag presence, `<status>:<reason>`
  stdout, exit-code mapping, the exit-3/stderr argument-error class),
  TEST-045 (branch-3 digest-unchanged short-circuit scoped to `none`/
  `patch` only; `minor`/`minor-rule-set` still reach the impact
  assessment), TEST-046 (`--resolver-version-bump`/actual-diff consistency
  argument-error fixtures, one per tier mismatch, plus one consistent
  positive fixture per tier).
- CI resilience per Global Constraints.
- Register `facet-manifest-staleness` in `tests/run-all.sh`/`.ps1`; stage
  the `.github/workflows/test.yml` candidate appended to T-003's staged
  file.

Commit B (documentation):
- Add this task's own new bullet under `## Unreleased` in `CHANGELOG.md`,
  citing #192.

### Done When

- [ ] **REQ-004 branch table** — TEST-019..024, TEST-039, TEST-040 pass
  against `tests/facet-manifest-staleness.tests.sh` (`sh tests/facet-
  manifest-staleness.tests.sh` exits 0): digest-only + `not-weakened` → not
  stale (AC-019); same-gate-ID attribute change → stale (AC-020);
  `evidence`-inclusion → stale (AC-021); minimum-enforcement tightening →
  stale (AC-022); `weakened`-verdict short-circuit, comparison never
  evaluated (AC-023); `indeterminate`-verdict fail-closed Block + forward-
  compatible sub-case (AC-024); no-axis-changed WARN-only `fresh`, no
  comparison attempted (AC-039); ownership-axis parity, both sub-cases
  (AC-040).
- [ ] **REQ-005 version-bump tiers** — TEST-025, TEST-026, TEST-027,
  TEST-045 pass: patch-tier no-op (AC-025); minor-tier impact assessment,
  both sub-cases, including the byte-identical-`context_binding` case
  (AC-026); major-tier forced-regardless + Block precedence (AC-027);
  branch-3 short-circuit scoped to `none`/`patch` only, `minor`/
  `minor-rule-set` always reach the impact assessment (AC-045).
- [ ] **CLI contract + argument-error class** — TEST-044, TEST-046 pass:
  mandatory-flag presence for all three `--*-weakening` flags and
  `--resolver-version-bump`; `<status>:<reason>` stdout (never bare);
  exit-`0`/`1`/`2` verdict mapping; exit-`3` stderr-only diagnostic channel
  with no stdout verdict line for a malformed invocation (AC-044);
  `--resolver-version-bump`/actual-manifest-diff consistency rejected as
  exit-3 argument error, one fixture per tier mismatch plus one consistent
  positive per tier (AC-046).
- [ ] **Suite/CI registration + governance** — `tests/facet-manifest-
  staleness.tests.sh`/`.ps1` self-registers in `tests/run-all.sh`/`.ps1`;
  the staged `.github/workflows/test.yml` candidate carries this task's
  appended CI step with a correct `MANIFEST.sha256` entry, LIVE `test.yml`
  byte-unchanged before/after; `CHANGELOG.md` gains this task's own bullet
  (AC-035 share); no version string mutated outside
  `scripts/bump-version.sh` (AC-035 share).
- [ ] **TDD evidence** — RED (each branch-table row and argument-error
  fixture against a deliberately incorrect comparator) and GREEN (the full
  branch table + argument-error class against the correct comparator),
  captured in `specs/epic-192-a4-facet-manifest/verification/T-004/
  {red,green}-sh.log`. An independent quality-gate verdict records PASS.

### Out of Scope

- The three schema files and their own validators (T-001, T-002, T-003).
- The cross-script byte-identical parity suite, the installed-layout
  discovery fixtures, and the provider-neutrality scan (T-005).
- Wiring `compare-facet-manifest-staleness`'s verdict into any live Gate or
  CI enforcement path (Non-goals — Epic A5/a future epic's scope; design.md
  Protected-File Statement).
- Building a Registry- or ownership-scoped Policy-Weakening detector
  (Non-goals) — this task only consumes a caller-supplied verdict, fail-
  closed in its absence.

### Blockers

T-001, T-002, T-003

---

## T-005 Vendored-copy drift gate and the cross-script parity suite

Source Issue: https://github.com/aharada54914/sdd-forge/issues/192

Approval: Draft

Status: Planned

Risk: medium

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. `medium` is justified: this task is verification/packaging work
over the four already-implemented scripts (T-001..T-004) — proving
byte-identical `.py`/`.sh`/`.ps1` parity, installed-layout discovery, and a
provider-neutrality scan — not the introduction of new decision-bearing
logic of its own. A defect here (e.g., a `.ps1` wrapper emitting CRLF, or a
vendored-copy drift going undetected) degrades cross-runtime determinism and
packaging integrity but does not itself corrupt a Manifest, Gate verdict, or
digest — the sensitive logic it exercises was already independently risk-
classified `high` in the tasks that built it (T-001, T-003, T-004). It is
not `low`: it has observable, testable behavior (byte-identical diagnostic
output) that a competent implementer must verify, not a cosmetic change.
Required Workflow is therefore `acceptance-first` per the policy's
medium-tier row.

Required Workflow: acceptance-first

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-006 (this task's own primary scope — the cross-cutting
diagnostic-determinism-parity, installed-layout-discovery, and provider-
neutrality obligations, AC-031, AC-032, AC-033, AC-043), REQ-008 (share —
AC-035)

Depends On: T-001, T-002, T-003, T-004 (functional — the parity suite
invokes all four scripts' `.py`/`.sh`/`.ps1` triples against every fixture
from suites 1-5, the installed-layout discovery fixtures need all three
vendored schema copies to already exist, and the provider-neutrality scan
targets all three schema files + all four scripts' own source, design.md
Test Strategy item 6). Serialized after T-004 for the shared `tests/run-
all.sh`/`.ps1` array and `.github/workflows/test.yml` staging (Global
Constraints) — this task also lands the FINAL staged `test.yml` candidate
carrying all six suites' CI steps.

Planned Files:
- `plugins/sdd-quality-loop/scripts/generate-vendored-contracts-check.py`
  (new, agent-editable — or, if a suitable Epic A2 vendoring `--check`
  mechanism is confirmed present in this checkout at implementation-start
  time, extend it in place instead of authoring a new script; re-verify
  presence via `ls plugins/sdd-quality-loop/scripts/*vendor*` /
  `*--check*` before choosing which; design.md Deployment / CI Plan
  states the extension reuses "Epic A2's already-CI-wired vendored-copy
  `--check` mode... extended to cover three more filenames, not a new
  mechanism" — this checkout's absence of Epic A2's own scripts, External
  Checkout Constraints, means this task must re-verify that claim against
  the actual live repository state before choosing extend-vs-author)
- `tests/facet-manifest-parity.tests.sh` / `.ps1` (new, agent-editable)
- `tests/fixtures/facet-manifest/` (existing, agent-editable — adds the
  Windows-style path-argument fixture and the provider-neutrality clean/
  dirty fixtures)
- `tests/run-all.sh` / `.ps1` (existing, agent-editable — this task's
  1-suite registration, appended after T-004's; the array is now complete,
  all six suites registered)
- `specs/epic-192-a4-facet-manifest/human-copy/.github/workflows/test.yml`
  (existing, agent-editable — this task's CI step appended; the FINAL
  staged candidate, all six suites' CI steps present)
- `specs/epic-192-a4-facet-manifest/human-copy/MANIFEST.sha256` (existing,
  agent-editable — final entry)
- `specs/epic-192-a4-facet-manifest/verification/T-005/` (new — acceptance-
  first Red/Green logs)
- `CHANGELOG.md` (existing, agent-editable — this task's own new bullet)

Data Migration: none.

Breaking API: no; the vendoring `--check` extension is additive (three more
filenames covered, no existing filename's check changed); the parity suite
introduces no new script contract of its own, only tests existing ones.

Rollback: revert this task's two commits; nothing protected is written
directly. After this task, a human maintainer applies the complete staged
`.github/workflows/test.yml` candidate (all six suites) via `cp` + SHA-256
verification against `MANIFEST.sha256`, and re-runs `tests/run-all.sh`/
`.ps1` to confirm green before any Done-gated consumer of a passing CI
relies on it.

Note on scope breadth (TASK-SIZE): this task's two work areas (the
vendored-copy `--check` drift-gate extension and the `facet-manifest-parity`
suite) are bundled because design.md's own Test Strategy item 6 and
Deployment / CI Plan describe them as one unit — the parity suite's own
AC-032 installed-layout-discovery fixtures are the mechanism that exercises
the vendored copies the `--check` gate protects, so splitting them into
separate tasks would require one task's suite to depend on artifacts a
sibling task has not yet landed, with no independent value to either half
in isolation.

### Goal

Extend (or, if none is confirmed present in this checkout, author) the
vendored-copy `--check` drift-gate mechanism to cover all three of this
feature's schema files. Author `tests/facet-manifest-parity.tests.{sh,ps1}`
per design.md Test Strategy item 6: byte-identical `.py`/`.sh`/`.ps1`
diagnostic-output parity across all four scripts and every fixture from
suites 1-5 (AC-031); three installed-layout discovery fixtures per script,
one per runtime (AC-032); the six-suite test-registration procedure proof
(AC-033); the provider-neutrality scan across all three schema files and
four scripts' source (AC-043). Register the suite; land the final,
complete staged `.github/workflows/test.yml` candidate.

### Must Read

- `specs/epic-192-a4-facet-manifest/requirements.md` (Security Boundaries;
  REQ-006's parity/discovery/provider-neutrality clauses)
- `specs/epic-192-a4-facet-manifest/design.md` (Discovery contract;
  Diagnostic determinism contract; Test Strategy item 6; Deployment / CI
  Plan)
- `specs/epic-192-a4-facet-manifest/acceptance-tests.md` (AC-031, AC-032,
  AC-033, AC-043, AC-035 rows)
- `specs/epic-192-a4-facet-manifest/security-spec.md` (Trust Boundaries B4,
  B5; STRIDE B4/B5 rows; Security Tests TEST-031/032/043; SBOM and Supply
  Chain)
- `plugins/sdd-quality-loop/scripts/validate-facet-manifest.{py,sh,ps1}`,
  `validate-capability-summary.{py,sh,ps1}`,
  `validate-context-projection.{py,sh,ps1}`,
  `compare-facet-manifest-staleness.{py,sh,ps1}` (T-001..T-004's four
  scripts this suite tests)
- `tests/facet-manifest-schema.tests.sh`, `tests/facet-manifest-
  semantics.tests.sh`, `tests/capability-summary-schema.tests.sh`,
  `tests/context-projection-schema.tests.sh`, `tests/facet-manifest-
  staleness.tests.sh` (the five prior suites whose fixtures this suite
  replays across all three runtimes)

### Scope

Commit A (implementation — vendoring extension + parity suite + fixtures +
final CI wiring):
- Write the acceptance checks first (acceptance-first): TEST-031
  (byte-identical `.py`/`.sh`/`.ps1` exit codes and diagnostic output
  across all four scripts and every fixture from suites 1-5, including at
  least one Windows-style backslash-separated path argument and the
  `compare-facet-manifest-staleness` exit-3 stderr channel), TEST-032
  (three installed-layout discovery fixtures per script — only the
  packaged `plugins/sdd-quality-loop/contracts/*.schema.json` copy present,
  no monorepo `contracts/`, no reachable `.git`), TEST-033 (all six
  `tests/*.tests.sh`/`.tests.ps1` pairs registered in `tests/run-all.sh`/
  `.ps1`; the staged `.github/workflows/test.yml` candidate exists with a
  correct `MANIFEST.sha256` entry), TEST-043 (provider-neutrality scan
  across all three schema files and four scripts' source against Epic A2's
  provider-neutrality allowlist, plus a clean fixture proving no false
  positive on this feature's own vocabulary, e.g. `distribution_channels`).
- CI resilience per Global Constraints.
- Register `facet-manifest-parity` in `tests/run-all.sh`/`.ps1` — the array
  is now complete, all six suites present; stage the FINAL
  `.github/workflows/test.yml` candidate appended to T-004's staged file.
- Extend (or author) the vendored-copy `--check` mechanism to cover
  `facet-manifest.schema.json`/`capability-summary.schema.json`/
  `context-projection.schema.json`; confirm it exits 0 against the three
  vendored copies T-001/T-002/T-003 already created.

Commit B (documentation):
- Add this task's own new bullet under `## Unreleased` in `CHANGELOG.md`,
  citing #192.

### Done When

- [ ] **Byte-identical parity** — TEST-031 passes against `tests/facet-
  manifest-parity.tests.sh` (`sh tests/facet-manifest-parity.tests.sh`
  exits 0): `.py`/`.sh`/`.ps1` invocations of all four scripts against
  every fixture from suites 1-5 produce byte-identical exit codes and
  diagnostic output, including the Windows-style path-argument fixture and
  `compare-facet-manifest-staleness`'s exit-3 stderr channel (AC-031).
- [ ] **Installed-layout discovery** — TEST-032 passes: three fixtures per
  script (one per runtime) with only the packaged vendored copy present
  each resolve and validate correctly (AC-032).
- [ ] **Six-suite registration proof** — TEST-033 passes: all six
  `tests/*.tests.sh`/`.tests.ps1` pairs are registered directly in
  `tests/run-all.sh`/`.ps1` (grep self-check); the final staged
  `.github/workflows/test.yml` candidate carries all six suites' CI steps
  with a correct `MANIFEST.sha256` entry (AC-033).
- [ ] **Provider-neutrality scan** — TEST-043 passes: no hit against Epic
  A2's provider-neutrality allowlist across all three schema files and
  four scripts' source; a clean fixture confirms no false positive on this
  feature's own vocabulary (AC-043).
- [ ] **Vendored-copy drift gate** — the `--check` mode (extended or newly
  authored) exits 0 against the three schema files' vendored copies;
  command output (`<vendoring-script> --check`) recorded in
  `specs/epic-192-a4-facet-manifest/verification/T-005/vendor-check.log`.
- [ ] **Governance** — `CHANGELOG.md` gains this task's own bullet under
  `## Unreleased` citing #192 (AC-035 share); a grep self-check confirms no
  version string was mutated outside `scripts/bump-version.sh` (AC-035
  share).
- [ ] **Acceptance-first evidence** — RED (each parity/discovery/
  provider-neutrality fixture against a deliberately mismatched wrapper,
  missing vendored copy, or provider-name-contaminated schema/script) and
  GREEN (the full suite), captured in `specs/epic-192-a4-facet-manifest/
  verification/T-005/{red,green}-sh.log`.

### Out of Scope

- Authoring the three schemas or four scripts' own primary logic (T-001..
  T-004) — this task only tests and packages them.
- Building the Capability Resolver or any live artifact instance
  (Non-goals).
- Human application of the staged `.github/workflows/test.yml` candidate
  (a human-only `cp` + SHA-256 verification step, per Protected Files
  above — not an agent action any task performs).

### Blockers

T-001, T-002, T-003, T-004
