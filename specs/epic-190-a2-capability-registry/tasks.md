# Tasks: epic-190-a2-capability-registry

Task-Review-Status: Pending

Source: Issue #190 (epic #187, Epic A2 — Capability Registry) /
requirements.md (Spec-Review-Status: Pending) /
design.md (Impl-Review-Status: Pending)

These tasks describe the **implementation phase** that follows this spec's
approval. No task below has been executed by this spec-authoring commit; no
file under `plugins/`, `scripts/`, `contracts/`, `tests/`, or `.github/` has
been created or modified (requirements.md Non-goals, AC-021).

## Lifecycle

Each task is `Planned` until an implementation session picks it up. Do not
implement a task while this spec's `Spec-Review-Status` is `Pending`
(AGENTS.md Rules: "Do not implement Draft tasks"). Task order below is a
dependency order, not a priority order: T-001 must land before T-002/T-003;
T-002 and T-003 may proceed in parallel once T-001 lands; T-004 needs T-001
and Epic A1's canonicalizer; T-005 needs T-001 and T-003 (validate before
projecting); T-006 needs T-002..T-005 to exist to test them.

## Protected Files

Two protected-file surfaces this Epic's implementation phase touches,
neither of which any task edits directly (Design's Protected-File
Statement):
- `plugins/sdd-quality-loop/references/guard-invariants.json` and its four
  generated siblings (`guard_invariants.py`, `guard-invariants.generated.js`/
  `.ps1`/`.sh`) — self-hosting protection (investigation.md INV-009).
- `.github/workflows/test.yml`.

Every task that needs to change either surface stages corrected content
under `specs/epic-190-a2-capability-registry/human-copy/` with a
`MANIFEST.sha256` entry per file (ADR-0011 pattern, matching
`specs/epic-136-phase2-gates/human-copy/` exactly) and calls out the human
`cp` step as its own explicit sub-step under "Done When" — it is never
folded silently into "the task is done."

## Global Constraints

- Every script is a Python master plus thin `.sh`/`.ps1` wrappers (no logic
  duplicated into the wrappers), per the `sdd-hook-guard.sh` convention
  (investigation.md INV-014).
- Every new script and contract file must pass `check-sdd-structure.sh` and
  `check-workflow-state.sh` unchanged in their current behavior (neither
  script is modified by this Epic).
- No task in this Epic implements `stage: artifact` or `stage: promotion`
  Gate behavior (ADR-0017 item 1) — both remain inert reserved enum values.
- No task authors Capability Pack content — no Pack exists yet
  (investigation.md INV-002).

---

## T-001 Scaffold the `sdd-capability` plugin and the Registry contract

### Goal

Create the new `plugins/sdd-capability/` plugin (3-runtime manifest
scaffolding matching every existing plugin) and the Registry contract pair:
`contracts/capability-registry.schema.json` (JSON Schema, draft-07) and
`contracts/capability-registry.json` (`"schema": "capability-registry/v1"`),
per REQ-001.

### Must Read

- `requirements.md` REQ-001, Field Definitions (`gate_ids`,
  `implementation_ref`, `lite_policy`, `delivery_strategy.kind`)
- `design.md` Architecture, Components, API / Contract Plan
  (`contracts/capability-registry.schema.json` section), Design Decisions
  (`contracts/` over `sdd/`; flat top-level `gates[]`; new plugin rationale)
- `docs/adr/0017-gate-stage-model.md` (Gate schema), `docs/adr/0020-conditional-predicate-dsl.md`
  (predicate `#/definitions/predicate` shape), `docs/adr/0022-lite-capability-upgrade.md`
  (`lite_policy` shape)
- `contracts/workflow-state-registry.schema.json` (draft-07 styling
  precedent to match)

### Scope

- Author `contracts/capability-registry.schema.json` exactly per design.md's
  API / Contract Plan (top-level `schema`/`gates`/`capabilities`,
  `#/definitions/predicate` shared by `trigger` and
  `conditional_facets[].when`, `if`/`then` for `implementation_ref`'s
  stage-conditional requirement).
- Author `contracts/capability-registry.json` as an empty-but-valid instance
  (`{"schema": "capability-registry/v1", "gates": [], "capabilities": []}`)
  — no real Capability content is authored in this task (no Pack exists to
  source it from; a fixture-only illustrative Capability, if wanted for
  manual review, belongs under `tests/fixtures/capability-registry/`, not in
  the shipped instance file).
- Scaffold `plugins/sdd-capability/` with the same 3-runtime manifest shape
  every other plugin in this repository already has (`.plugin/plugin.json`
  or equivalent — mirror an existing plugin's manifest set exactly; do not
  invent a new manifest shape).
- Register `contracts/capability-registry.schema.json` and
  `contracts/capability-registry.json` in this Epic's own human-copy staging
  ONLY if T-005 determines they must become protected files before T-005
  lands (design.md Protected-File Statement lists them as targets for
  protection) — otherwise this task creates them as ordinary, unprotected
  files and T-005 handles the protection registration once the projection
  generator that reads them exists. (This ordering avoids protecting a file
  before anything consumes it, which would make T-001 depend on human-copy
  before there is anything to protect against.)

### Done When

- `contracts/capability-registry.schema.json` validates the empty instance
  file and rejects fixtures per TEST-001..TEST-005.
- `plugins/sdd-capability/` exists with manifest parity to an existing
  plugin (3 runtimes), verified by whatever manifest-parity check this
  repository already runs across plugins (do not invent a new one; reuse
  it).
- `tests/capability-registry-schema.tests.sh`/`.ps1` (TEST-001..TEST-005)
  pass, registered directly in `tests/run-all.sh`/`.ps1`.

### Out of Scope

- The evaluator, validator, digest generator, and projection generator
  (T-002..T-005).
- Any protected-file human-copy staging (deferred to T-005, per Scope above).

### Blockers

- None. This is the first task; it has no upstream dependency within this
  Epic.

---

## T-002 Author the Predicate DSL evaluator

### Goal

Implement `plugins/sdd-capability/scripts/evaluate-predicate.py` (+ `.sh`/
`.ps1` wrappers) per ADR-0020's full operator and evaluation-semantics
specification, per REQ-002.

### Must Read

- `requirements.md` REQ-002, AC-006..AC-010
- `design.md` API / Contract Plan ("Predicate DSL evaluator contract"),
  Test Strategy item 1
- `docs/adr/0020-conditional-predicate-dsl.md` (normative; read in full, not
  summarized — the `exists` exception and the fail-closed general rule are
  easy to invert by accident)

### Scope

- Python master implements: `all`/`any`/`not` (no short-circuit; every child
  predicate evaluated and its result recorded); `equals`/`not_equals`/
  `contains`/`in` (fail-closed + `WARN` on missing path, `null`, or type
  mismatch, uniformly, never an exception); `exists` (path-presence only,
  `true` even when the value is `null`, `false` + `WARN` when absent, no
  type inspection).
- `field` values are validated against ADR-0020 item 5's 8-path allowlist
  before evaluation; an out-of-allowlist `field` is a `PREDICATE_SCHEMA_ERROR`
  (construction-time), never a `WARN` (evaluation-time) — these two failure
  classes must not be conflated (design.md API / Contract Plan).
- `.sh`/`.ps1` wrappers forward arguments and stdin/stdout only; no
  operator logic is duplicated into either wrapper (Global Constraints).
- Output includes a full Evidence array (operator, field, outcome, reason)
  for every predicate evaluated, per design.md's evaluator contract shape.

### Done When

- `tests/evaluate-predicate.tests.sh`/`.ps1` (TEST-006..TEST-010) pass,
  registered directly in `tests/run-all.sh`/`.ps1`.
- A fixture asserting `trigger` and `conditional_facets[].when` share one
  code path (TEST-009) passes.
- Dual-runtime (`.sh` vs. `.ps1`) invocation of an identical predicate +
  property fixture produces byte-identical JSON output.

### Out of Scope

- Wiring this evaluator into an actual Resolver (Epic A5).
- Any change to the field allowlist beyond ADR-0020 item 5's 8 paths —
  `distribution_channels`/`data_classification` are consumed here as
  allowlist entries only; their presence in a real Project Context is an
  Epic A1 concern (requirements.md Dependencies).

### Blockers

- T-001 (Registry schema, for the shared `#/definitions/predicate` shape
  this evaluator's input format must match).

---

## T-003 Author the Registry validator and the Provider-name allowlist

### Goal

Implement `plugins/sdd-capability/scripts/validate-capability-registry.py`
(+ `.sh`/`.ps1`) and `plugins/sdd-capability/references/provider-terms.json`,
covering REQ-003 checks (a)-(g).

### Must Read

- `requirements.md` REQ-003, AC-011..AC-015
- `design.md` Components (`validate-capability-registry`,
  `provider-terms.json`), API / Contract Plan ("Registry validator
  contract"), Test Strategy item 2 and item 6
- `docs/adr/0018-provider-binding-separation.md` (the boundary rule this
  check operationalizes for the first time — investigation.md INV-008)
- `docs/adr/0017-gate-stage-model.md` item 1 (stage exemption for
  `artifact`/`promotion`)

### Scope

- Implement checks (a) Gate-ID uniqueness, (b) stage-completeness for
  `stage: implementation` Gates (exempting `artifact`/`promotion`), (c)
  unregistered-script detection (bidirectional: every configured-directory
  gate-shaped script must be referenced by exactly one `implementation_ref`,
  and vice versa — design.md flags this as this spec's own proposal,
  OQ-004), (d) no `capability-packs/*/gates.yaml`-shaped file exists
  anywhere in the repository, (e) no missing `stage` on any `gates[]` entry
  (defense-in-depth beyond the schema), (f) every `gate_ids` entry resolves
  to a defined `gates[].id`, (g) Provider-name contamination scan against
  `provider-terms.json`.
- Seed `provider-terms.json` with, at minimum, the token set design.md's
  Components section lists (`azure`, `aws`, `amazon`, `gcp`, `google-cloud`,
  `durable-functions`, `step-functions`, `lambda`, `s3`, `cosmos-db`,
  `dynamodb`, `app-store`, `google-play`, `ms-store`, `microsoft-store`,
  `argo`); document in the file itself (a `_comment`/README-style top-level
  key, or a companion note) that this list is expected to grow as new
  Provider Bindings are named (ADR-0018 item 4) and is not itself protected.
- Diagnostic output format: one line per failing check, `registry:
  <check-id>: <detail>`, matching `check-sdd-structure.sh`'s `missing:
  <item>` style (design.md API / Contract Plan).

### Done When

- `tests/validate-capability-registry.tests.sh`/`.ps1` (TEST-011..TEST-015)
  pass, registered directly in `tests/run-all.sh`/`.ps1`, one fixture per
  check plus one fully-clean fixture proving no false positive.
- The Provider-name scan's clean-fixture case (TEST-014's second half)
  passes without flagging provider-neutral vocabulary already present in
  the Registry schema itself (e.g. `durable_workflow` as an
  `artifact_kinds` enum value).

### Out of Scope

- Cross-checking `review_check_ids` against real Pack `review-checklist.md`
  content — no Pack exists (investigation.md INV-002; requirements.md
  Non-goals).
- The projection generator (T-005) — this task only validates the
  authoring-format Registry, it does not generate anything.

### Blockers

- T-001 (Registry schema and instance file to validate against).

---

## T-004 Author the `registry_digest` generator

### Goal

Implement `plugins/sdd-capability/scripts/generate-registry-digest.py`
(+ `.sh`/`.ps1`), calling Epic A1's canonicalizer for the RFC 8785 (JCS)
canonical-JSON step, per REQ-004.

### Must Read

- `requirements.md` REQ-004, Dependencies section, AC-016..AC-017
- `design.md` API / Contract Plan ("`registry_digest` generator contract"),
  Test Strategy item 3, Assumptions (canonicalizer interface stability)
- `docs/ai-dlc-foundation-decision-v2.md` §18.3 (canonical-hash contract)
- `docs/adr/0021-context-projection-staleness.md` (why "Registry fragment,"
  not "whole Registry," is the digest's unit — lines 30-46)

### Scope

- Implement `--registry <path> --capability-ids <id[,id...]> | --whole`:
  resolve the requested fragment (named Capabilities plus every `gates[]`
  entry they reference via `gate_ids`, transitively, for `--capability-ids`;
  the whole file for `--whole`), canonicalize via Epic A1's canonicalizer
  (import/call, do not reimplement JCS or NFC normalization — requirements.md
  Dependencies, explicit instruction not to reimplement), sha256 the result,
  print the hex digest and nothing else.
- If Epic A1's canonicalizer is not yet available/importable at
  implementation time, this task is blocked (see Blockers) — do not
  reimplement a substitute canonicalizer as a workaround; that would
  reintroduce exactly the divergent-hash risk this design avoids
  (requirements.md Problems).
- Document explicitly, in this script's own header comment, that the
  YAML-1.2-parse precondition in decision v2 §18.3 does not apply to this
  input (the Registry is authored directly in JSON, per T-001) — only the
  canonical-JSON + NFC + sha256 steps apply.

### Done When

- `tests/generate-registry-digest.tests.sh`/`.ps1` (TEST-016..TEST-017)
  pass, registered directly in `tests/run-all.sh`/`.ps1`.
- Dual-runtime (`.sh` vs. `.ps1`) invocation against an identical fixture
  fragment produces an identical sha256.
- A single-character mutation to the selected fragment changes the digest;
  a mutation to an unrelated, non-selected part of the Registry does not
  (fragment-scoping proof, TEST-017).

### Out of Scope

- Binding this digest into a Facet Manifest's `context_binding` (Epic A4/A5).
- Choosing which Capability/Gate IDs constitute "the fragment used" for a
  real Feature — that selection policy is Epic A5's (requirements.md
  Field Definitions, `Registry fragment`).

### Blockers

- T-001 (Registry file to hash).
- **Epic A1's canonicalizer must exist and be importable.** If Epic A1 has
  not landed by the time this task is picked up, this task cannot be marked
  Done — it may be authored and unit-tested against a stub canonicalizer
  interface in the interim, but its acceptance tests (TEST-016/TEST-017)
  require the real dependency (requirements.md Dependencies: "if Epic A1
  lands with a materially different canonicalizer interface, REQ-004's
  implementation task must be revisited").

---

## T-005 Author the projection generator and stage its protected-file registration

### Goal

Implement `plugins/sdd-capability/scripts/generate-gate-capabilities.py`
(+ `.sh`/`.ps1`, `--check` mode) and stage the protected-file additions it
requires (new paths added to `guard-invariants.json`'s protected-suffix and
human-copy-target lists) through human-copy, per REQ-005.

### Must Read

- `requirements.md` REQ-005, AC-018..AC-020
- `design.md` API / Contract Plan ("Projection generator contract"),
  Protected-File Statement, Test Strategy item 4
- `plugins/sdd-quality-loop/scripts/generate-guard-invariants.py` (the
  precedent this generator mirrors exactly — read the whole file, not a
  summary, since the header format and `--check` contract must match
  byte-for-byte in spirit)
- `specs/epic-136-phase2-gates/human-copy/` (the staging structure and
  `MANIFEST.sha256` format to reproduce)

### Scope

- Implement the generator per design.md's exact contract: reads
  `contracts/capability-registry.json` (post-T-003-validation), writes
  `plugins/sdd-quality-loop/scripts/generated/gate-capabilities.json` with
  the `_generated` header block (`source`, `schema_version`, `sha256`,
  "Do not edit" notice), including only `stage: implementation` Gates
  (ADR-0017 item 1 — `artifact`/`promotion` entries are omitted from the
  projection `sdd-quality-loop` actually reads, since Foundation implements
  no behavior for them).
- Implement `--check`: recompute in memory, compare byte-for-byte against
  the committed file, exit non-zero on any difference, no write.
- **Protected-file registration (human-copy step, explicit sub-step, not
  folded into "the task is done"):**
  1. Stage the corrected `guard-invariants.json` content (adding
     `contracts/capability-registry.schema.json`,
     `contracts/capability-registry.json`,
     `plugins/sdd-capability/scripts/generate-gate-capabilities.py`, and
     `plugins/sdd-quality-loop/scripts/generated/gate-capabilities.json` to
     both `PROTECTED_GATE_SUFFIXES`-equivalent and
     `PHASE2_HUMAN_COPY_TARGETS`-equivalent source lists) under
     `specs/epic-190-a2-capability-registry/human-copy/plugins/sdd-quality-loop/references/guard-invariants.json`,
     with a `MANIFEST.sha256` entry.
  2. Stage the regenerated `guard_invariants.py` and its three generated
     siblings (`.js`/`.ps1`/`.sh`) that result from re-running
     `generate-guard-invariants.py` against the staged `guard-invariants.json`,
     each under the matching `specs/epic-190-a2-capability-registry/human-copy/`
     path, each with its own `MANIFEST.sha256` entry.
  3. **A human maintainer runs the `cp` step for every staged file above,
     verifying each file's SHA-256 against `MANIFEST.sha256` before this
     task's guard-invariants-registration half can be marked Done.** This is
     a separate, explicit sub-step from authoring the generator script
     itself — the generator can be Done (tests passing against an
     unregistered-but-functional script) before the human-copy step
     completes; the *protection registration* specifically waits on the
     human.

### Done When

- `tests/generate-gate-capabilities.tests.sh`/`.ps1` (TEST-018..TEST-019)
  pass, registered directly in `tests/run-all.sh`/`.ps1`.
- The human-copy staging directory
  (`specs/epic-190-a2-capability-registry/human-copy/`) contains every file
  named in Scope step 1-2, each with a correct `MANIFEST.sha256` entry
  (TEST-020 part a).
- The live `guard-invariants.json` and its generated siblings remain
  byte-identical to their pre-task state until a human applies the staged
  content (TEST-020 part b).
- After a human `cp`, `guard_invariants.py`'s `PROTECTED_GATE_SUFFIXES`
  contains the four new paths (TEST-020 part c).

### Out of Scope

- Any other change to `guard-invariants.json` beyond the four new path
  additions this task requires.
- `.github/workflows/test.yml` registration for the new test suites — that
  is T-006's human-copy step, staged separately (a different protected file,
  a different `MANIFEST.sha256` entry, potentially applied in a different
  human `cp` pass).

### Blockers

- T-001 (Registry contract to project).
- T-003 (validator — the generator should refuse to project an
  invalid Registry; wiring `validate-capability-registry.py` as a
  precondition of `generate-gate-capabilities.py` is part of this task's
  Scope, not a separate task).
- Human maintainer availability for the `cp` step (Scope, sub-step 3) —
  this task's script-authoring half does not block on this, but its
  protected-file-registration half does, and both halves must be true for
  the task to be fully Done.

---

## T-006 Author the test suites and stage `test.yml` registration

### Goal

Author all six `tests/*.tests.sh`/`.tests.ps1` pairs (REQ-006), register
them directly in `tests/run-all.sh`/`.ps1`, and stage their
`.github/workflows/test.yml` registration via human-copy.

### Must Read

- `requirements.md` REQ-006
- `design.md` Test Strategy (all six items), Protected-File Statement
- `tests/run-all.sh`/`.ps1` (registration style precedent — direct,
  unprotected edit)
- `.github/workflows/test.yml:30,35,126,130` (the exact step-registration
  style for a Python `--check` step and a `.sh`/`.ps1` test pair,
  precedent to mirror)

### Scope

- Author `tests/capability-registry-schema.tests.sh`/`.ps1`,
  `tests/evaluate-predicate.tests.sh`/`.ps1`,
  `tests/validate-capability-registry.tests.sh`/`.ps1`,
  `tests/generate-registry-digest.tests.sh`/`.ps1`,
  `tests/generate-gate-capabilities.tests.sh`/`.ps1`, and fixture data under
  `tests/fixtures/capability-registry/`, covering every case listed in
  design.md's Test Strategy and acceptance-tests.md's TEST-001..TEST-019.
- Register all ten new files directly in `tests/run-all.sh`/`.ps1`
  (unprotected — investigation.md INV-014 confirms this file is not
  guard-invariants-protected).
- **`.github/workflows/test.yml` registration (human-copy step, explicit
  sub-step):**
  1. Stage the corrected `.github/workflows/test.yml` content (adding a
     `generate-gate-capabilities.py --check` step alongside the existing
     `generate-guard-invariants.py --check` steps, plus one step per new
     `.sh`/`.ps1` suite pair, mirroring the existing
     `agent-capabilities-v2` steps' style) under
     `specs/epic-190-a2-capability-registry/human-copy/.github/workflows/test.yml`,
     with a `MANIFEST.sha256` entry.
  2. **A human maintainer runs the `cp` step, verifying SHA-256 against
     `MANIFEST.sha256`, before this task can be marked Done.** As with
     T-005, script/test authoring can be Done before this specific
     sub-step completes; CI registration specifically waits on the human.

### Done When

- All six suite pairs pass locally (`bash tests/<name>.tests.sh` and
  `./tests/<name>.tests.ps1` on a pwsh-capable host).
- `tests/run-all.sh`/`.ps1` list every new suite (grep-based self-check).
- The human-copy staging directory contains the corrected `test.yml` with a
  correct `MANIFEST.sha256` entry; after a human `cp`, a self-registration
  grep against the live `test.yml` confirms every new step is present
  (mirrors the `epic-159-pillar-c` AC-027 three-part verification pattern).

### Out of Scope

- Any test suite change unrelated to this Epic's own new scripts.
- `tests/validate-repository.ps1` changes — this Epic introduces no new
  cross-file consistency check beyond what T-001..T-005's own tests already
  cover; if a future review finds one is needed, that is a follow-up task,
  not silently folded in here.

### Blockers

- T-002, T-003, T-004, T-005 (there is nothing to test until each script
  exists).
- Human maintainer availability for the `test.yml` `cp` step (Scope,
  sub-step 2) — same split as T-005: authoring is not blocked on the human
  step, full Done status is.
