# Tasks: sdd-domain-concept-contract

Task-Review-Status: Passed

Source: Issue #290 (Concept Design Layer — Phase 0: Concept Contract
Foundation) /
requirements.md (Spec-Review-Status: Passed) /
design.md (Impl-Review-Status: Passed)

## Lifecycle

`Draft -> Approved -> In Progress -> Implementation Complete -> Done`

A task may enter `Blocked` from any active state. Humans approve tasks.
`implement-task` may set `In Progress`, `Blocked`, or `Implementation Complete`.
Only `quality-gate` may set `Done`.

## Protected Files

None. Every deliverable path in this feature is outside the R-10
enforcement chain: `contracts/domain-contract.*` is absent from
`PROTECTED_GATE_SUFFIXES` (only `contracts/capability-registry.*` and
`contracts/lite-upgrade-reason-catalog.json` are protected under
`contracts/`), and `plugins/sdd-domain/` and `tests/sdd-domain/` carry no
protected entries (INV-008). No human-copy staging is required for any task
below.

Each task re-verifies the then-current `PROTECTED_GATE_SUFFIXES` contents at
its own implementation-start time — this is a live-repository snapshot taken
at task-authoring time, not a permanent guarantee.

## Global Constraints

Applies to every task below.

- **Additive only (REQ-007).** `contracts/domain-contract.v1.schema.json`,
  the four INV-004 v1 consumers (domain-sync / reviewer A / interviewer /
  check-domain-conformance), and the eleven existing
  `tests/sdd-domain/*.Tests.ps1` suites must not change by one byte. T-001
  installs the SHA-256 drift lock that enforces the first of these; T-005
  closes the remaining two.
- **No external dependency (DD-4, INV-005).** The `.sh` side uses `python3`
  stdlib `json` only; the `.ps1` side uses `ConvertFrom-Json` only. No `jq`,
  no `ajv`, no `Test-Json` (PS6+ only — the scripts must stay PS5.1-safe),
  no new pip dependency.
- **Content as data.** The validator never interprets contract content as
  instruction: no command construction, no path dereference from contract
  values, no `eval` / `Invoke-Expression` (security-spec.md).
- **Fixtures are ephemeral (DD-5, INV-006).** Every fixture is a heredoc /
  here-string inside the suite, expanded under `mktemp` scope. No permanent
  `tests/fixtures/` directory is added for this feature.
- **Fixture hygiene (requirements.md Security Boundaries).** No credential
  value, token, personal data, or real customer information appears in any
  fixture, script source, test output, or persisted evidence. Fixtures use
  synthetic domain vocabulary only.
- **Output contract (DD-7).** stderr carries one violation per line in
  `RULE-ID: message` form; stdout carries no parse result; exit code is 0 or
  non-zero only. Every check emits its own RULE-ID so that acceptance tests
  can tell adjacent failure paths apart.
- **ASCII / no-BOM / LF** for every new `.ps1` and `.sh`, per the existing
  hygiene suites.
- **No CI/run-all registration.** The new suite follows the existing
  `tests/sdd-domain/` convention of running outside `run-all` (INV-007,
  OQ-002). Changing that policy is a separate WFI, not this feature.
- **CHANGELOG.** Each task adds one `## Unreleased` entry citing #290.

## Negative Fixture Allocation

The 73 negative fixtures design.md `## Test Strategy` tallies are allocated
across three tasks. Each fixture is authored exactly once; T-005 asserts the
total.

| Task | Acceptance criteria | Fixtures |
|---|---|---|
| T-002 | AC-017 (2), AC-012 (1) | 3 |
| T-003 | AC-024 (29), AC-014 (7), AC-021 (7), AC-023 (8), AC-020 (4), AC-018 (3), AC-019 (3), AC-016 (1) | 62 |
| T-004 | AC-006, AC-007, AC-008, AC-009, AC-010, AC-011 (6), AC-022 (2) | 8 |
| **Total** | | **73** |

## T-001 Author the v2 schema file and install the v1 drift lock

Source Issue: https://github.com/aharada54914/sdd-forge/issues/290

Approval: Approved (sudo 2026-08-18T15:08:24Z)

Status: Done

Risk: medium

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md` directly,
not defaulted. `medium` is the honest tier: this task adds a declaration file
that no consumer reads yet — design.md's Architecture states the downstream
Phase 1/3 consumers are "本 feature ではまだ接続しない" — so a defect here
causes no material harm today and is caught by the T-003/T-004 negative
fixtures and by T-005's drift lock before any consumer exists. It is not
`high`: the schema touches no authentication, authorization, billing, data
mutation, access control, or secrets surface, and it is not yet a live public
API contract. It is not `low`: the file is not cosmetic — it fixes the
required-field set and the three regex patterns that every later check in
this feature and every later Phase depends on.

Required Workflow: acceptance-first

Requirements: REQ-001, REQ-002, REQ-003

### Goal

Author `contracts/domain-contract.v2.schema.json` as a standalone draft-07
schema declaring `schema` const `domain-contract/v2`, root required
`schema` / `meta` / `contexts` / `concepts`, the concept object with its
seven required fields and three patterns, the optional fields with their
nested required sub-fields, and `contexts[].terms[].concept_id` as an
optional field carrying the concept-id pattern. Duplicate the v1
`boundedContext` / `term` / `aggregate` / `contextRelation` definitions into
the file rather than `$ref`-ing v1 (DD-3). Create
`tests/sdd-domain/contract-v2-schema.Tests.ps1` with the schema-shape
assertions and the v1 byte-identity drift lock.

### Must Read

- `specs/sdd-domain-concept-contract/requirements.md` (REQ-001, REQ-002,
  REQ-003; Field Definitions is the authority for every type, pattern,
  required flag, minItems, and minLength)
- `specs/sdd-domain-concept-contract/design.md` (DD-1, DD-3; `## v2 Schema
  Shape` is the worked example this schema must accept)
- `specs/sdd-domain-concept-contract/acceptance-tests.md` (AC-001, AC-002)
- `contracts/domain-contract.v1.schema.json` (the definitions being
  duplicated, and the file whose hash the drift lock pins)
- `tests/sdd-domain/contract-schema.Tests.ps1` (the v1 suite whose shape and
  Pester conventions the new suite follows)

### Scope

Commit A (schema + suite skeleton + drift lock):
- Write the acceptance checks first: TEST-001 asserts the file exists,
  declares draft-07, `schema` const `domain-contract/v2`, root required
  `schema`/`meta`/`contexts`/`concepts`, and a `meta` definition of the same
  shape as v1 (version / status / generated_from). TEST-002 asserts the
  SHA-256 of `contracts/domain-contract.v1.schema.json` equals the value
  recorded at feature start.
- Record the v1 baseline SHA-256 as a literal in the suite and in this task's
  implementation report — this is the value TEST-002 pins.
- Author `contracts/domain-contract.v2.schema.json`: `additionalProperties:
  false` at every level; `concepts` with `minItems: 1`; concept required
  `id` / `name` / `context` / `definition` / `essence` / `responsibilities` /
  `evidence`; patterns `^CONCEPT-[A-Z][A-Z0-9-]*$` (id),
  `^[A-Z][A-Za-z0-9]*$` (name), `^[a-z][a-z0-9]*(-[a-z0-9]+)*$` (context);
  `minLength: 1` on every declared string value and `minItems: 1` on
  `responsibilities` / `evidence` / `distinguished_from[].reasons`; optional
  `must_not_own` / `stakeholder_perspectives` (required actor, concern) /
  `distinguished_from` (required concept_id with the id pattern, reasons);
  `contexts[].terms[].concept_id` optional with the id pattern.

Commit B (documentation):
- CREATE the `CHANGELOG.md` `## Unreleased` entry citing #290.

### Done When

- [ ] **Schema shape** — TEST-001 passes: the file exists and declares
  draft-07, the `domain-contract/v2` const, the four root required keys, and
  a v1-shaped `meta` definition (AC-001).
- [ ] **v1 drift lock** — TEST-002 passes: `domain-contract.v1.schema.json`
  hashes to the recorded baseline (AC-002).
- [ ] **Field parity** — every type, pattern, required flag, minItems, and
  minLength in the schema file matches requirements.md Field Definitions
  exactly; any divergence is a defect in this task, not in Field Definitions.
- [ ] **v1 untouched** — `git diff` for this task shows no change to
  `contracts/domain-contract.v1.schema.json`, to any INV-004 consumer, or to
  any pre-existing `tests/sdd-domain/*.Tests.ps1` file.
- [ ] Suite file is ASCII / no-BOM / LF and passes the existing hygiene
  suites.
- [ ] `CHANGELOG.md` `## Unreleased` entry citing #290 exists.

### Out of Scope

- The validator scripts (T-002, T-003, T-004).
- Any fixture beyond what TEST-001/TEST-002 need (T-002 through T-005).
- Deleting or modifying `contracts/domain-contract.v1.schema.json` — its
  final disposition is OQ-001, deferred to Phase 3.

### Blockers

None

## T-002 Author the validator twins: fail-closed parse and version dispatch

Source Issue: https://github.com/aharada54914/sdd-forge/issues/290

Approval: Approved (sudo 2026-08-18T15:08:24Z)

Status: Done

Risk: high

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md` directly,
not defaulted. `high` is justified, not merely asserted: this task owns the
untrusted-input boundary. security-spec.md names it explicitly — "A validator
that best-effort-parses malformed input, executes contract content, or
silently passes an invalid contract would weaken every downstream gate built
on it" — and contract JSON is untrusted data that may carry text originating
from interview or seed material. A silent defect here (best-effort parse of a
truncated file, a raw interpreter exception escaping, or a v1 contract
accepted as v2) is exactly the "silent defect causes material harm" surface
the policy's `high` tier names, because every later Phase's deterministic gate
inherits this validator's verdict and every structural check in T-003 runs
only after this boundary has admitted the input. It is not `critical`: nothing
here touches financial settlement, medical, physical-safety,
legal/regulatory, or irreversible destructive operations — the worst outcome
is a wrong verdict on a version-controlled text file.

Required Workflow: tdd

Requirements: REQ-004

Rollback: Revert Commit A and Commit B. Both validator scripts are new files
with no consumer wired in Phase 0 (design.md `## Deployment / CI Plan`:
"Phase 0 では consumer を 1 つも接続しない"), so reverting deletes them and
returns the tree to T-001's state with no data, state, or registration to
unwind. No feature flag or migration rollback applies — there is no datastore
and no runtime deployment.

### Goal

Author `plugins/sdd-domain/scripts/validate-domain-contract.sh` and
`.ps1` implementing REQ-004 steps (a) and (b): fail-closed JSON parse of the
single path argument, and `schema`-value dispatch that rejects anything other
than `domain-contract/v2` with a named error. Establish the shared skeleton
both twins use — argument handling, the `RULE-ID: message` stderr emitter,
the violation accumulator that later checks append to, and exit-code
discipline (0 or non-zero only, never a partial verdict). Author the three
boundary negative fixtures.

### Must Read

- `specs/sdd-domain-concept-contract/requirements.md` (REQ-004(a) and (b);
  Edge Cases — the truncated-input and oversized-input rules and the
  v1-contract rejection message)
- `specs/sdd-domain-concept-contract/design.md` (DD-4, DD-6, DD-7;
  `## Architecture` pipeline steps 1-2; `## Error Handling` — the
  `V2-WRONG-SCHEMA` rule and the fail-closed contract)
- `specs/sdd-domain-concept-contract/acceptance-tests.md` (AC-012, AC-017)
- `specs/sdd-domain-concept-contract/security-spec.md` (fail-closed parsing;
  content-as-data; no-secrets-in-fixtures)
- `contracts/domain-contract.v2.schema.json` (T-001's output — the version
  string this dispatch admits)
- an existing `plugins/sdd-domain/scripts/*.sh` / `.ps1` pair (the house
  wrapper conventions, argument handling, and exit-code discipline)

### Scope

Ordering: this task follows T-001 because the dispatch admits the version
string T-001's schema declares, and the suite file T-001 creates is where
these fixtures live.

Commit A (implementation — TDD Red→Green):
- Write the acceptance checks first and capture the Red run: AC-017 (2
  fixtures — truncated JSON, >10MB file: non-zero exit, one-line stderr, no
  partial stdout, no stack trace or raw interpreter exception), AC-012 (1 —
  a `domain-contract/v1` contract rejected by name with `V2-WRONG-SCHEMA`).
- Author both twins to Green for steps (a) and (b). `.sh`: a single `python3`
  stdlib invocation that owns parse and dispatch and leaves a structured
  handle for T-003's checks. `.ps1`: `ConvertFrom-Json` inside a fail-closed
  wrapper, PS5.1-safe.
- Establish the shared emitter and accumulator: one `RULE-ID: message` line
  per violation on stderr, nothing on stdout, exit non-zero when the
  accumulator is non-empty. T-003 and T-004 append their checks to this
  accumulator rather than introducing a second output path.
- Missing argument, unreadable path, and non-existent file also exit non-zero
  with a one-line cause, per the Edge Cases fail-closed rule.

Commit B (documentation):
- CREATE the `CHANGELOG.md` `## Unreleased` entry citing #290.

### Done When

- [ ] **Red→Green evidence captured** — the failing run of every acceptance
  check above is recorded before the implementation commit, per
  `Required Workflow: tdd`.
- [ ] **Fail-closed** — AC-017 passes for both fixtures: non-zero exit, no
  partial result on stdout, no stack trace or raw interpreter exception on
  stderr.
- [ ] **Argument and path errors** — a missing argument, an unreadable path,
  and a non-existent file each exit non-zero with a one-line cause and no
  stack trace.
- [ ] **Version dispatch** — AC-012 passes: a v1 contract is rejected with a
  `V2-WRONG-SCHEMA` line naming the v2-only constraint.
- [ ] **Requirement traceability** — traceability.md rows for REQ-004 record
  this task's evidence paths.
- [ ] **Independent review verdict recorded** for this task.
- [ ] **Provenance** recorded with `spec_revision` and environment.
- [ ] `CHANGELOG.md` `## Unreleased` entry citing #290 exists, and no external
  dependency was introduced — both twins run on a host with only `python3`
  (sh side) or Windows PowerShell 5.1 (ps1 side).

### Out of Scope

- The structural check pass (c) — T-003.
- Cross-reference checks (d)-(i) — T-004.
- Positive fixtures, twin parity, and the existing-suite non-regression run —
  T-005.
- Any change to the schema file authored in T-001.

### Blockers

T-001

## T-003 Add the ordered structural check pass to the validator twins

Source Issue: https://github.com/aharada54914/sdd-forge/issues/290

Approval: Approved (sudo 2026-08-18T15:08:24Z)

Status: Done

Risk: high

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md` directly,
not defaulted. `high` is justified: this pass is what makes the schema
declaration enforceable, and its ordering rule is load-bearing. REQ-004(c)
fixes that type conformance must precede pattern, minLength, and minItems, and
that a type-mismatched value must not be handed to those checks — get the
order wrong and a mistyped field produces a raw interpreter exception, which
security-spec.md names as a fail-closed violation. A structural violation
passing unreported is the same "silent defect causes material harm" surface
the policy's `high` tier names: every later Phase's deterministic gate
inherits this verdict. It is not `critical`: no financial, medical,
physical-safety, legal/regulatory, or irreversible-destructive surface is
touched — the worst outcome is a wrong verdict on a version-controlled text
file.

Required Workflow: tdd

Requirements: REQ-002, REQ-004

Rollback: Revert Commit A and Commit B. The change is confined to the two
validator scripts T-002 created and to fixtures inside the T-001 suite file;
no consumer is wired in Phase 0 (design.md `## Deployment / CI Plan`), so
reverting returns both twins to their T-002 state — parse and dispatch still
green — with no data, state, or registration to unwind. No feature flag or
migration rollback applies.

### Goal

Extend both validator twins with REQ-004 step (c): the structural check pass
in the order REQ-004(c) fixes — JSON type conformance first, then required-key
presence, then pattern, minLength, and minItems — where a type-mismatched
value must not be handed to the later checks. Enumerate every violation
through T-002's accumulator rather than stopping at the first. Author the 62
structural negative fixtures.

### Must Read

- `specs/sdd-domain-concept-contract/requirements.md` (REQ-002 and its Field
  Definitions table — the authority for every type, pattern, required flag,
  minItems, and minLength; REQ-004(c) and its precedence rule)
- `specs/sdd-domain-concept-contract/design.md` (DD-7; `## Architecture`
  pipeline step 3 and its explicit precedence note; `## Error Handling`
  structural RULE-ID family)
- `specs/sdd-domain-concept-contract/acceptance-tests.md` (AC-014, AC-016,
  AC-018, AC-019, AC-020, AC-021, AC-023, AC-024, and the Negative-path
  coverage matrix, whose blank-cell-free state is the completeness criterion)
- `contracts/domain-contract.v2.schema.json` (T-001's output — the
  declaration this pass enforces)
- `plugins/sdd-domain/scripts/validate-domain-contract.sh` and `.ps1`
  (T-002's output — the accumulator and emitter this pass appends to)

### Scope

Ordering: this task follows T-002 because it appends to the accumulator and
emitter T-002 establishes, and it runs only on input T-002's parse and
dispatch have already admitted.

Commit A (implementation — TDD Red→Green):
- Write the acceptance checks first and capture the Red run: AC-024 (29 — one
  per typed field, asserting no raw exception and that type violations are
  reported as type violations, not as pattern or minLength violations),
  AC-014 (7 — each required concept key absent), AC-021 (7 — each root and
  meta required key absent), AC-016 (1 — `concepts: []`), AC-018 (3 —
  id/name/context pattern violations), AC-019 (3 — minItems violations),
  AC-023 (8 — minLength violations), AC-020 (4 — nested required omissions
  inside the optional object arrays; the optional-absent acceptance case is
  T-005's AC-026 and is not authored here).
- Extend both twins to Green with the RULE-IDs design.md fixes:
  `V2-TYPE-MISMATCH` (carrying field name and expected type),
  `V2-MISSING-KEY`, `V2-PATTERN`, `V2-EMPTY-ARRAY`, `V2-EMPTY-STRING`.
- Implement the precedence gate explicitly: a value failing the type check is
  recorded and then excluded from pattern, minLength, and minItems evaluation.

Commit B (documentation):
- CREATE the `CHANGELOG.md` `## Unreleased` entry citing #290.

### Done When

- [ ] **Red→Green evidence captured** — the failing run of every acceptance
  check above is recorded before the implementation commit, per
  `Required Workflow: tdd`.
- [ ] **Type precedence** — AC-024's 29 fixtures pass, and (9)(10)(11) are
  reported as type violations rather than pattern violations while
  (17)(18)(19) are reported as type violations rather than minLength
  violations, proving the ordering REQ-004(c) fixes.
- [ ] **Structural checks** — AC-014, AC-016, AC-018, AC-019, AC-020,
  AC-021, AC-023 all pass, each fixture producing a violation line whose
  RULE-ID and field name identify which check fired.
- [ ] **Enumeration** — a fixture carrying two independent violations
  produces two stderr lines, proving the validator does not stop at the
  first.
- [ ] **Fixture count** — this task contributes exactly 62 negative fixtures,
  matching the Negative Fixture Allocation table; T-005 asserts the 73 total.
- [ ] **Requirement traceability** — traceability.md rows for REQ-002 and
  REQ-004 record this task's evidence paths.
- [ ] **Independent review verdict recorded** for this task.
- [ ] **Provenance** recorded with `spec_revision` and environment, and the
  `CHANGELOG.md` `## Unreleased` entry citing #290 exists.

### Out of Scope

- Fail-closed parse and version dispatch (a)-(b) — T-002.
- Cross-reference checks (d)-(i) — T-004.
- Positive fixtures, twin parity, and the existing-suite non-regression run —
  T-005.
- Any change to the schema file authored in T-001.

### Blockers

T-002

## T-004 Add the cross-reference integrity checks to the validator twins

Source Issue: https://github.com/aharada54914/sdd-forge/issues/290

Approval: Approved (sudo 2026-08-18T15:08:24Z)

Status: Done

Risk: high

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md` directly,
not defaulted. `high` is justified: these six checks are the entire reason
this validator exists rather than a plain JSON Schema run — DD-1 records that
draft-07 cannot express referential integrity, so duplicate ids, dangling
`context` / `distinguished_from` / `term` references, self-contradictory
responsibility sets, and within-context name collisions are caught here or
nowhere. A missed check silently passes an invalid contract, which is the
precise failure security-spec.md warns "would weaken every downstream gate
built on it", and the defect would surface only when a later Phase's gate
consumed the bad contract. It is not `critical`: no financial, medical,
safety, regulatory, or irreversible-destructive surface is touched.

Required Workflow: tdd

Requirements: REQ-003, REQ-004

Rollback: Revert Commit A and Commit B. The change is confined to the two
validator scripts and to fixtures inside the T-001 suite file; no consumer is
wired in Phase 0 (design.md `## Deployment / CI Plan`), so reverting returns
both twins to their T-003 state — parse, dispatch, and the structural pass
still green — with no data, state, or registration to unwind. No feature flag
or migration rollback applies.

### Goal

Extend both validator twins with REQ-004 steps (d) through (i): concept `id`
duplication, dangling `concept.context`, dangling
`distinguished_from.concept_id` including the self-reference case, dangling
`term.concept_id`, the self-contradiction check for a string appearing in
both `responsibilities` and `must_not_own` of one concept, and `name`
duplication within a single context while permitting the same name across
different contexts. Add the pattern check for the two reference fields that
share the concept-id pattern. Author the eight cross-reference negative
fixtures.

### Must Read

- `specs/sdd-domain-concept-contract/requirements.md` (REQ-003; REQ-004(d)
  through (i); Edge Cases — the cross-context same-name rule and the
  self-reference rule)
- `specs/sdd-domain-concept-contract/design.md` (DD-1 and its INV-003
  rationale; `## Architecture` pipeline step 4; `## Error Handling`
  cross-reference RULE-ID family)
- `specs/sdd-domain-concept-contract/acceptance-tests.md` (AC-006, AC-007,
  AC-008, AC-009, AC-010, AC-011, AC-022)
- `plugins/sdd-domain/scripts/validate-domain-contract.sh` and `.ps1`
  (T-002/T-003 output — the pass this extends)

### Scope

Ordering: this task follows T-003 because these checks extend the same two
script files and run after the structural pass in the design.md pipeline
order — a contract whose types and required keys are already known-good.

Commit A (implementation — TDD Red→Green):
- Write the acceptance checks first and capture the Red run: AC-006
  (duplicate concept id, stderr naming the duplicated id), AC-007 (dangling
  `concept.context`), AC-008 (dangling `distinguished_from.concept_id`,
  including a self-referencing case), AC-009 (dangling `term.concept_id`),
  AC-010 (identical string in `responsibilities` and `must_not_own` of one
  concept — exact string equality per REQ-004(h)), AC-011 (duplicate `name`
  within one context, paired with AC-005's cross-context positive owned by
  T-005), AC-022 (2 — pattern violations on
  `distinguished_from[].concept_id` and `contexts[].terms[].concept_id`,
  reported as pattern violations distinct from the dangling-reference
  errors).
- Extend both twins to Green with the RULE-IDs design.md fixes:
  `V2-DUP-CONCEPT-ID`, `V2-DANGLING-CONTEXT`, `V2-DANGLING-DISTINCTION`,
  `V2-DANGLING-TERM`, `V2-SELF-CONTRADICTION`, `V2-DUP-NAME-IN-CONTEXT`.

Commit B (documentation):
- CREATE the `CHANGELOG.md` `## Unreleased` entry citing #290.

### Done When

- [ ] **Red→Green evidence captured** for every acceptance check above, per
  `Required Workflow: tdd`.
- [ ] **Six integrity checks** — AC-006 through AC-011 pass, each fixture
  producing a violation line whose RULE-ID identifies which check fired,
  including AC-008's self-referencing fixture, which is rejected per the Edge
  Cases rule that `distinguished_from` pointing at its own concept is invalid.
- [ ] **Reference-field patterns** — AC-022's two fixtures are reported as
  pattern violations, textually distinguishable from AC-008/AC-009's
  dangling-reference errors.
- [ ] **Cross-context permissiveness** — the same-name-different-context case
  is not reported by the AC-011 check; the positive proof is T-005's AC-005.
- [ ] **Fixture count** — this task contributes exactly 8 negative fixtures,
  matching the Negative Fixture Allocation table; T-005 asserts the 73 total.
- [ ] **Requirement traceability** — traceability.md rows for REQ-003 and
  REQ-004 record this task's evidence paths.
- [ ] **Independent review verdict recorded** for this task.
- [ ] **Provenance** recorded with `spec_revision` and environment, and the
  `CHANGELOG.md` `## Unreleased` entry citing #290 exists.

### Out of Scope

- Fail-closed parse and version dispatch (a)-(b) — T-002.
- The structural check pass (c) — T-003.
- Positive fixtures and twin parity — T-005.
- Any change to the schema file authored in T-001.

### Blockers

T-003

## T-005 Complete the positive corpus, twin parity, and non-regression closure

Source Issue: https://github.com/aharada54914/sdd-forge/issues/290

Approval: Approved (sudo 2026-08-18T15:08:24Z)

Status: Done

Risk: medium

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md` directly,
not defaulted. `medium` is the honest tier: this task ships test code only —
no validator or schema behavior changes — so it cannot itself cause a wrong
verdict on any contract. Its failure mode is a weaker safety net (a
stuck-shut validator not caught, or a twin divergence not caught), which is
a real but second-order harm and matches requirements.md's own rating of R1,
R2, and R3 as 低. It is not `high`: no sensitive surface is touched and no
silent defect here can produce material harm without a separate defect in
T-002, T-003, or T-004. It is not `low`: the work is behavioral test
authoring with real assertions, not cosmetic.

Required Workflow: acceptance-first

Requirements: REQ-005, REQ-006, REQ-007

### Goal

Author the five positive fixture families and the twin-parity harness, and
close the REQ-007 non-regression guarantee. The positive corpus proves the
validator is not stuck-shut: a fully populated contract, an
all-optionals-absent contract, a cross-context same-name contract, a
term-to-concept link, and the two pattern boundary values must all be
accepted with exit 0. The parity harness proves both twins agree on every
fixture in the corpus.

### Must Read

- `specs/sdd-domain-concept-contract/requirements.md` (REQ-005 (a) through
  (f) and its positive-coverage rule; REQ-006; REQ-007)
- `specs/sdd-domain-concept-contract/design.md` (DD-5; `## Test Strategy` —
  the 5 positive families, the 73-fixture negative total, and the note that
  value-retention is asserted suite-side because the validator emits only an
  exit code and stderr)
- `specs/sdd-domain-concept-contract/acceptance-tests.md` (AC-003, AC-004,
  AC-005, AC-013, AC-015, AC-025, AC-026, and the Positive-capability matrix,
  whose rows this task's fixtures must satisfy)
- `plugins/sdd-domain/scripts/validate-domain-contract.sh` and `.ps1`
  (T-002/T-003/T-004 output — the twins under parity test)

### Scope

Ordering: this task follows T-002, T-003, and T-004 because the parity
harness and the positive corpus exercise the complete validator, and the
73-fixture tally can only be verified once all three negative-fixture tasks
have landed. All three are named explicitly so the tally dependency is stated
rather than left implicit in the T-002 -> T-003 -> T-004 chain.

Commit A (positive corpus + parity + non-regression):
- Author the acceptance checks: AC-003 (Purchase/Fulfillment fixture with all
  seven required fields named, all three optional fields populated including
  a valid `stakeholder_perspectives` entry, plus the boundary values — a
  concept named `APIOrder` and a context named `order-taking-2` — all
  accepted, with the three optional fields' values asserted preserved),
  AC-004 (Book/Bookshelf fixture realizing REQ-005(b) exactly:
  `Book.must_not_own` carrying display position, Placement holding the
  ordering responsibility), AC-005 (two contexts carrying the same concept
  name with distinct ids, accepted), AC-025 (a term whose `concept_id`
  resolves to an existing concept, accepted, with a structural assertion that
  the v2 schema declares the field optional with the concept-id pattern and
  that the value survives validation), AC-026 (a concept with none of
  `must_not_own`, `stakeholder_perspectives`, or `distinguished_from`,
  accepted).
- Author AC-013: run every fixture in the corpus — all 5 positive families
  and all 73 negatives — through both twins and assert identical exit code
  and identical violation count. On a host without `bash` on PATH, emit a
  named SKIP per the existing twin-check degradation convention rather than
  a silent pass.
- Author AC-015: run the unmodified `tests/sdd-domain/contract-schema.Tests.ps1`
  (v1) and assert green, and assert this feature's diff touches none of the
  INV-004 consumers or the eleven pre-existing suites.

Commit B (documentation):
- CREATE the `CHANGELOG.md` `## Unreleased` entry citing #290.

### Done When

- [ ] **Positive families** — AC-003, AC-004, AC-005, AC-025, AC-026 all pass
  with exit 0, and each fixture's Test Target content matches the REQ-005
  clause it realizes.
- [ ] **Boundary positives** — `APIOrder` and `order-taking-2` are accepted,
  proving the name and context patterns are not stuck-shut (paired with
  AC-018's negatives).
- [ ] **Optional two-state** — AC-003 proves the populated state is accepted
  and AC-026 proves the all-absent state is accepted; neither optional field
  has been accidentally made required.
- [ ] **Twin parity** — AC-013 passes across the full corpus with identical
  exit codes and violation counts, or emits a named SKIP on a bash-less host.
- [ ] **Fixture total** — the suite's negative fixture count is 73, matching
  both the Negative Fixture Allocation table (3 + 62 + 8) and the tally
  acceptance-tests.md derives from its own AC table; a divergence means a
  fixture was dropped or duplicated.
- [ ] **Non-regression** — AC-015 passes: the v1 suite runs unmodified and
  green, and the feature diff touches no INV-004 consumer and no pre-existing
  `tests/sdd-domain/*.Tests.ps1`.
- [ ] **Fixture hygiene** — every fixture is heredoc/here-string defined and
  mktemp-scoped with no permanent fixture directory added, and no credential
  value, token, personal data, or real customer information appears in any
  fixture, script source, test output, or persisted evidence.
- [ ] `CHANGELOG.md` `## Unreleased` entry citing #290 exists.

### Out of Scope

- Any change to the validator twins or the schema file — if a positive
  fixture fails, the defect belongs to T-002, T-003, or T-004 and is fixed
  there.
- Registering the suite in `tests/run-all.*` or the CI workflow (INV-007,
  OQ-002 — a separate WFI).

### Blockers

T-002, T-003, T-004
