# Design: epic-190-a2-capability-registry

Impl-Review-Status: Pending
Feature Type: new machine-readable contract (Capability Registry schema +
instance) plus four deterministic scripts (Predicate DSL evaluator, Registry
validator, `registry_digest` generator, projection generator) and their
protected-file/CI wiring

## Technical Summary

Epic A2 introduces one new machine-readable contract (the Capability
Registry) and four deterministic, testable scripts around it: a Predicate
DSL evaluator, a Registry validator, a `registry_digest` generator, and a
projection generator. It introduces no new UI, no new UX surface, and no new
runtime service — every deliverable is a static contract file plus a
Python-master/sh+ps1-wrapper script pair, following conventions already in
use for guard-invariants and effort-routing v2 (investigation.md INV-009,
INV-010, INV-014). This document is the **design for the implementation
phase**; no file it describes is created by this spec commit (requirements.md
Non-goals, AC-021).

## Architecture

```
contracts/capability-registry.schema.json   (JSON Schema, draft-07)
contracts/capability-registry.json          (Registry instance, "schema": "capability-registry/v1")
        │
        ├─► plugins/sdd-capability/scripts/validate-capability-registry.py (+ .sh/.ps1)
        │     Gate-ID uniqueness, stage completeness, unregistered-script
        │     detection, Pack-gate-definition absence, referential
        │     integrity, Provider-name contamination (REQ-003)
        │
        ├─► plugins/sdd-capability/scripts/evaluate-predicate.py (+ .sh/.ps1)
        │     ADR-0020 Predicate DSL evaluator; called with a `trigger` or
        │     `conditional_facets[].when` expression + component properties
        │     (REQ-002)
        │
        ├─► plugins/sdd-capability/scripts/generate-registry-digest.py (+ .sh/.ps1)
        │     calls Epic A1's canonicalizer; outputs sha256 over a named
        │     Registry fragment (REQ-004)
        │
        └─► plugins/sdd-capability/scripts/generate-gate-capabilities.py (+ .sh/.ps1)
              reads the validated Registry, writes the protected projection:
              plugins/sdd-quality-loop/scripts/generated/gate-capabilities.json
              (REQ-005) ──► read by sdd-quality-loop's Implementation Gate
```

`plugins/sdd-capability/` is a **new plugin**, proposed by this spec (Design
Decisions, below) as the home for Capability Registry/Resolver-family
machinery that does not belong to `sdd-quality-loop` (gate execution),
`sdd-lite` (lite track), or `sdd-bootstrap` (interview flow). Epic A1's
canonicalizer, Epic A3's ownership tooling, and Epic A5's Resolver are
expected to either live alongside these scripts in the same plugin or be
consumed by it as a dependency; this spec does not decide Epic A1/A3/A5's own
plugin placement, only Epic A2's.

## Components

- `contracts/capability-registry.schema.json` — JSON Schema (draft-07),
  `$id` under this repository's GitHub path (matching
  `contracts/workflow-state-registry.schema.json`'s `$id` convention),
  `additionalProperties: false` at every fully-enumerated object level.
- `contracts/capability-registry.json` — the Registry instance:
  ```json
  {
    "schema": "capability-registry/v1",
    "gates": [
      {
        "id": "check-update-migration",
        "stage": "implementation",
        "blocking": true,
        "implementation_ref": "plugins/sdd-quality-loop/scripts/check-update-migration.sh"
      }
    ],
    "capabilities": [
      {
        "id": "durable-workflow",
        "trigger": {
          "any": [
            {"scope": "affected_component", "field": "artifact_kinds", "operator": "contains", "value": "durable_workflow"}
          ]
        },
        "required_facets": ["data-spec"],
        "conditional_facets": [
          {
            "facet": "pii-handling-spec",
            "when": {"scope": "affected_component", "field": "characteristics.pii", "operator": "equals", "value": true}
          }
        ],
        "review_check_ids": ["durable-workflow-replay-safety"],
        "gate_ids": ["check-update-migration"],
        "lite_policy": {"eligible": false, "upgrade_reasons": ["durable_workflow"]},
        "minimum_enforcement": "required",
        "delivery_strategy": {"kind": "durable-workflow"}
      }
    ]
  }
  ```
  (Illustrative fixture, not literal shipped content — no Capability Packs
  exist yet, INV-002.)
- `plugins/sdd-capability/scripts/evaluate-predicate.{py,sh,ps1}` — the
  Predicate DSL evaluator. Python master implements the actual
  operator/evaluation-semantics logic; `.sh`/`.ps1` are thin argument-
  forwarding wrappers (the `sdd-hook-guard.sh` pattern, INV-014). Input:
  a predicate expression (JSON) + a flat property map (the affected
  component's allowlisted fields). Output: `{"result": bool, "evidence":
  [{"operator": ..., "field": ..., "outcome": "match"|"no-match"|"warn",
  "reason": ...}, ...]}`.
- `plugins/sdd-capability/scripts/validate-capability-registry.{py,sh,ps1}`
  — the Registry validator (REQ-003 checks a-g).
- `plugins/sdd-capability/scripts/generate-registry-digest.{py,sh,ps1}` —
  the `registry_digest` primitive (REQ-004), depends on Epic A1's
  canonicalizer module (imported, not vendored/reimplemented).
- `plugins/sdd-capability/scripts/generate-gate-capabilities.{py,sh,ps1}` —
  the projection generator (REQ-005), `--check` mode for CI drift detection,
  mirroring `generate-guard-invariants.py`'s own `--check` contract exactly.
- `plugins/sdd-capability/references/provider-terms.json` — the Provider-
  name-contamination allowlist: a maintained, versioned list of known
  provider-identifying tokens (`azure`, `aws`, `amazon`, `gcp`,
  `google-cloud`, `durable-functions`, `step-functions`, `lambda`, `s3`,
  `cosmos-db`, `dynamodb`, `app-store`, `google-play`, `ms-store`,
  `microsoft-store`, `argo`), consulted case-insensitively by REQ-003(g).
  This list is itself provider-neutral data (it names providers only to
  detect their names, the same way a profanity filter's word list is not
  itself profane) and is not registered as a protected file — it is
  expected to grow as new providers are named in real Provider Bindings
  (ADR-0018 item 4).
- `plugins/sdd-quality-loop/scripts/generated/gate-capabilities.json` — the
  protected, generated projection (REQ-005), headed
  `# Generated from contracts/capability-registry.json; schema_version=1;
  sha256=<hex>` / `// This file is generated. Do not edit.` (JSON comments
  are not valid JSON; the header is carried as a top-level `"_generated"`
  metadata object instead, matching JSON's own constraints — see API /
  Contract Plan below for the exact shape).

## Protected-File Statement

Two categories of protected-file interaction, both via human-copy
(`specs/epic-190-a2-capability-registry/human-copy/` + `MANIFEST.sha256`,
ADR-0011 pattern — INV-009):

1. **Registering new protected paths.** `guard_invariants.py`'s
   `PROTECTED_GATE_SUFFIXES` and `PHASE2_HUMAN_COPY_TARGETS` lists are
   generated from `plugins/sdd-quality-loop/references/guard-invariants.json`
   by `generate-guard-invariants.py`, and both the source JSON and every
   generated output are themselves protected (INV-009) — self-hosting. Epic
   A2's implementation phase must add these five new paths to
   `guard-invariants.json`'s source list:
   - `contracts/capability-registry.schema.json`
   - `contracts/capability-registry.json`
   - `plugins/sdd-capability/scripts/generate-gate-capabilities.py`
   - `plugins/sdd-quality-loop/scripts/generated/gate-capabilities.json`
   - (the three per-language generated siblings, if REQ-005's
     implementation phase mirrors guard-invariants' 4-language generation —
     Open Questions notes this is not mandated by decision v2, only the
     JSON output is)

   Because this is a protected-file **addition** (editing
   `guard-invariants.json` and regenerating its own generated outputs), it
   cannot be a direct agent edit; it is staged as corrected file content
   under `specs/epic-190-a2-capability-registry/human-copy/` with a
   `MANIFEST.sha256` entry per file, for a human to `cp` into place — the
   exact procedure `specs/epic-136-phase2-gates/human-copy/` already
   demonstrates for this same file set.
2. **Registering new tests in `.github/workflows/test.yml`.** `test.yml` is
   independently protected (INV-009). Every `tests/*.tests.sh`/`.tests.ps1`
   pair REQ-006 adds is staged the same way:
   `specs/epic-190-a2-capability-registry/human-copy/.github/workflows/test.yml`
   + its own `MANIFEST.sha256` entry.

`tests/run-all.sh`/`.ps1` are **not** protected (INV-014, confirmed via the
`agent-capabilities-v2` precedent) — new suite registration there is a
direct agent edit.

## Layer Specifications

Not applicable. Epic A2 has no UX, frontend, or infrastructure-provisioning
layer; it is schema + deterministic script + generated-artifact work,
covered in full by Components and API / Contract Plan below.

## Design System Compliance

Not applicable — no UI surface.

## Cross-Layer Dependencies

- REQ-004 (`registry_digest`) → Epic A1's canonicalizer (Dependencies,
  requirements.md).
- REQ-002's field allowlist → Epic A1's Project Context schema additions
  (`distribution_channels`, `data_classification`) for full exercise against
  real data (fixture-based testing does not require Epic A1 to land first).
- REQ-005's generated projection → consumed by `sdd-quality-loop`'s
  Implementation Gate (an Epic A2 output, an Epic-A0-already-decided
  consumer per ADR-0017, not a new dependency Epic A2 introduces).
- REQ-002/REQ-004 → consumed by Epic A5's Resolver (downstream, not a
  blocking dependency on Epic A2's own implementation — Dependencies,
  requirements.md).

## ADR Change Log

No new ADR is proposed by this spec. Every design decision below traces to
an existing ADR (0017, 0018, 0020, 0021, 0022) or decision v2 §§3, 6, 10, 11,
13, 16, 18.3, 19. Where this spec makes a judgment call the ADRs leave open
(plugin placement, `implementation_ref`'s bidirectional unregistered-script
check, the `delivery_strategy.kind` enum, `upgrade_reasons`'s openness), it
is recorded below under Design Decisions and cross-referenced to
investigation.md's OQ-001..OQ-004, not silently folded into an ADR's scope.

## Data Plan

- `contracts/capability-registry.json` is the only new persistent data file
  this spec's implementation phase creates at the contract layer (REQ-001).
  It is hand-edited by Registry maintainers (no UI), validated by REQ-003,
  and projected by REQ-005. No database, no migration, no runtime storage.
- `plugins/sdd-quality-loop/scripts/generated/gate-capabilities.json` is
  derived data (regenerated from the above), never hand-edited (protected).
- No data is deleted or migrated; this is a net-new contract with no prior
  version.

## API / Contract Plan

### `contracts/capability-registry.schema.json` (REQ-001)

Top-level required properties: `schema` (`const: "capability-registry/v1"`),
`gates` (array, `minItems: 0`), `capabilities` (array, `minItems: 0`).

`gates[]` item (`additionalProperties: false`):
- `id` (string, pattern `^[a-z0-9][a-z0-9-]*$`, matching
  `workflow-state-registry.schema.json`'s `feature` pattern convention)
- `stage` (enum: `implementation`, `artifact`, `promotion`)
- `blocking` (boolean)
- `implementation_ref` (string; **required if** `stage == "implementation"`,
  expressed via a schema-level `if`/`then` — matching JSON Schema draft-07's
  conditional-subschema feature, avoiding a hand-rolled cross-field check
  where the schema language already provides one)

`capabilities[]` item (`additionalProperties: false`):
- `id` (string, same pattern as `gates[].id`)
- `trigger` (`$ref: "#/definitions/predicate"`)
- `required_facets` (array of strings, `uniqueItems: true`)
- `conditional_facets` (array of `{facet: string, when: predicate}`,
  `additionalProperties: false`)
- `review_check_ids` (array of strings, `uniqueItems: true`)
- `gate_ids` (array of strings, `uniqueItems: true`; referential integrity
  against `gates[].id` is a validator-level check, REQ-003(f), not a
  schema-level `$ref` — JSON Schema draft-07 cannot express "must equal one
  of this sibling array's runtime values")
- `lite_policy` (optional; `{eligible: boolean (required), upgrade_reasons:
  array of non-empty strings (optional, default [])}`, `additionalProperties:
  false`)
- `minimum_enforcement` (optional; `const: "required"` — no other value is
  defined by decision v2 §10, so the schema does not invent one)
- `delivery_strategy` (optional; `{kind: enum[developer-tooling, cli-library,
  desktop, cloud-service, durable-workflow]}`, `additionalProperties: false`)

`#/definitions/predicate` (shared by `trigger` and
`conditional_facets[].when`, ADR-0020 item 4's "no second condition
language"):
```json
{
  "oneOf": [
    {"type": "object", "additionalProperties": false, "required": ["all"],
     "properties": {"all": {"type": "array", "items": {"$ref": "#/definitions/predicate"}}}},
    {"type": "object", "additionalProperties": false, "required": ["any"],
     "properties": {"any": {"type": "array", "items": {"$ref": "#/definitions/predicate"}}}},
    {"type": "object", "additionalProperties": false, "required": ["not"],
     "properties": {"not": {"$ref": "#/definitions/predicate"}}},
    {"type": "object", "additionalProperties": false,
     "required": ["scope", "field", "operator"],
     "properties": {
       "scope": {"const": "affected_component"},
       "field": {"enum": ["artifact_kinds", "runtime_classes",
         "characteristics.pii", "characteristics.ui",
         "characteristics.auto_update", "characteristics.local_persistence",
         "distribution_channels", "data_classification"]},
       "operator": {"enum": ["equals", "not_equals", "contains", "in", "exists"]},
       "value": {}
     }}
  ]
}
```
`value` is required for every operator except `exists` (schema-level `if`/
`then`, matching ADR-0020: `exists` "tests only whether the path exists").

### Predicate DSL evaluator contract (REQ-002)

`evaluate-predicate.py --predicate <path|-> --component-properties <path|->`
→ stdout JSON `{"result": bool, "evidence": [...]}`, exit 0 always (the
evaluator itself never fails on a well-formed predicate — a `false` result
with a `WARN` reason is a normal, successful evaluation, not an error, per
ADR-0020's fail-closed-not-fail-loud design). Malformed input (invalid JSON,
a field outside the allowlist, an operator outside the fixed set) is a
distinct, non-zero-exit `PREDICATE_SCHEMA_ERROR` — this is a construction-
time error, not a fail-closed evaluation outcome, and must not be conflated
with a `WARN`.

### Registry validator contract (REQ-003)

`validate-capability-registry.py --registry <path>` → exit 0 (all checks
pass) or non-zero with one diagnostic line per failed check, in the style of
`check-sdd-structure.sh`'s `missing: <item>` lines (`registry: <check-id>:
<detail>`). Each of the seven checks (a-g in requirements.md REQ-003) is an
independently identifiable, independently testable failure mode.

### `registry_digest` generator contract (REQ-004)

`generate-registry-digest.py --registry <path> --capability-ids <id[,id...]>
| --whole` → stdout the sha256 hex digest of the canonical-JSON (via Epic
A1's canonicalizer) serialization of the selected fragment (the listed
Capabilities plus every `gates[]` entry any of them reference via
`gate_ids`, transitively — "the Registry fragment used" per ADR-0021).
`--whole` selects the entire Registry. No other output.

### Projection generator contract (REQ-005)

`generate-gate-capabilities.py [--check]` → without `--check`, writes
`plugins/sdd-quality-loop/scripts/generated/gate-capabilities.json`:
```json
{
  "_generated": {
    "source": "contracts/capability-registry.json",
    "schema_version": 1,
    "sha256": "<hex>",
    "notice": "This file is generated. Do not edit."
  },
  "gates": [ /* stage: implementation entries only, per ADR-0017 item 1 —
                artifact/promotion entries are reserved and carry no
                Foundation-time gate-execution behavior, so the projection
                sdd-quality-loop actually reads omits them */ ],
  "capability_gate_map": { "<capability-id>": ["<gate-id>", ...] }
}
```
With `--check`: recomputes the same content in memory, compares byte-for-byte
against the committed file, exits non-zero on any difference (no write),
matching `generate-guard-invariants.py --check`'s contract exactly.

## Test Strategy

Six new `tests/*.tests.sh`/`.tests.ps1` pairs (REQ-006), each with fixture
data under `tests/fixtures/capability-registry/`:
1. `evaluate-predicate` — every operator × {matching, non-matching, missing
   path, null value, type mismatch} where applicable; `exists` × {present-
   with-null (true), present-with-value (true), absent (false+WARN)};
   `all`/`any` × {empty list, all-true, all-false, mixed} with an assertion
   that every child's evidence entry is present even when the parent's
   result was already determined by an earlier child (proving no short-
   circuit); a `trigger`-labeled fixture asserting it is evaluated by the
   identical code path as a `conditional_facets[].when` fixture (byte-
   identical evidence shape).
2. `validate-capability-registry` — one fixture per REQ-003 check (a-g),
   each a minimal Registry mutation isolating exactly one failure mode, plus
   one fully-clean fixture proving a negative (all checks pass on valid
   input) so the suite cannot pass vacuously.
3. `generate-registry-digest` — a fixed fixture Registry, asserting (a) the
   `.sh`- and `.ps1`-wrapper invocations of the digest generator produce an
   identical sha256 (dual-runtime determinism, decision v2 §18.3), and (b) a
   single-character mutation to the fragment changes the digest (negative
   self-check proving the hash is content-sensitive, not a constant).
4. `generate-gate-capabilities --check` — a clean pass against a valid
   fixture Registry + its correctly-generated projection, and a mutated-
   projection negative case (hand-edit the generated file, confirm `--check`
   fails) proving the drift check is live.
5. Schema-conformance — `contracts/capability-registry.schema.json` validates
   both a minimal-valid and a maximal-valid fixture instance, and rejects one
   fixture per structurally-invalid case (missing `implementation_ref` on a
   `stage: implementation` Gate, an out-of-enum `delivery_strategy.kind`, a
   non-boolean `lite_policy.eligible`).
6. Provider-name-contamination — one fixture per allowlisted term category
   (cloud provider, distribution channel, workflow-runtime product name)
   confirming each is caught, plus a clean fixture proving the scan does not
   false-positive on provider-neutral vocabulary already in
   `contracts/capability-registry.json`'s own schema field names (e.g.
   `durable_workflow` as an `artifact_kinds` value is provider-neutral per
   ADR-0018 and must not itself trigger the scan — only a *provider name*
   like `durable-functions`, the Azure product name, does).

All six pairs are registered directly in `tests/run-all.sh`/`.ps1`
(unprotected) and staged via human-copy for `.github/workflows/test.yml`
(protected) — Protected-File Statement, above.

## Design Decisions (resolving open questions)

- **`contracts/` over `sdd/` (OQ: file placement, INV-010).** `sdd/` holds
  per-project, human-authored instance config (`project-context.yaml`,
  `provider-bindings.yaml` — one per consuming project, ADR-0016/ADR-0018).
  The Capability Registry is framework-shipped and shared across every
  consuming project — the same nature as `contracts/agent-model-
  capabilities.v2.json`, not `sdd/project-context.yaml`. Every existing file
  under `contracts/` is JSON (13/13); the YAML-styled schema examples in
  decision v2 §11/ADR-0017/ADR-0020 illustrate the DSL/Gate *concepts*
  readably, they do not fix an on-disk authoring format for the Registry
  specifically (Project Context and Provider Bindings, which those same
  documents also show in YAML, genuinely are YAML files on disk — the
  Registry is a different artifact with different provenance). This is a
  judgment call flagged for human confirmation at spec review; a reviewer
  who intended literal YAML should say so before REQ-001's implementation
  task begins.
- **A flat, top-level `gates[]` array, not per-Capability (INV-003).**
  ADR-0017's own schema example presents `gates:` as a flat, ungrouped list.
  A flat list makes "Gate ID uniqueness" a single array's `uniqueItems`-style
  constraint instead of a cross-capability de-duplication problem, and lets
  multiple Capabilities share one Gate (e.g. two Capabilities that both
  require `check-component-coverage`) without duplicating its definition.
- **"conditions" is not a third schema field (OQ-002).** ADR-0020 defines
  exactly one condition concept. Treating decision v2 §13's "trigger /
  conditions" as two words for the same DSL body (not two fields) avoids
  inventing an undocumented field; flagged for human confirmation.
- **`delivery_strategy.kind`'s four-value enum is an inference (OQ-003).**
  Decision v2 never defines this vocabulary directly; the four values are
  read off decision v2 §17's Pack rollout order, the only place in the
  source documents that enumerates delivery-shape categories. A human
  reviewer may prefer a different, smaller, or larger set.
- **`upgrade_reasons` is an open string array, not a closed enum (OQ-001).**
  ADR-0022's YAML example and its own prose disagree on the count and
  membership of this set; freezing either list into a closed enum would
  silently pick a side. An open array lets Epic A6 (which actually consumes
  this field, per ADR-0022 item 4) populate it without a schema change,
  deferring the vocabulary-freezing decision to where it can be made with
  real lite-track upgrade cases in hand — the same reasoning ADR-0017 already
  applies to the Artifact/Promotion Gate vocabulary.
- **A new `plugins/sdd-capability/` plugin, not an existing one.** None of
  `sdd-quality-loop` (gate *execution*, not Registry *authoring*/
  *validation*), `sdd-lite` (lite track specifically), or `sdd-bootstrap`
  (interview flow) is a good semantic home for Registry-authoring/
  validation/digest/projection scripts that Epic A1/A3/A5 will also need to
  extend. This mirrors how `sdd-domain` and `sdd-ship` are each their own
  plugin for their own concern rather than folded into `sdd-quality-loop`.
  A human reviewer may instead prefer housing this inside an existing
  plugin; this spec's tasks.md schedules the new-plugin scaffold as its own,
  separately reversible task specifically so that preference is cheap to
  apply at implementation-task-review time.
- **`implementation_ref` and the bidirectional unregistered-script check are
  this spec's own proposal (OQ-004).** Neither decision v2 nor any ADR
  specifies a mechanism for "no unregistered script"; this spec proposes the
  minimum mechanism that makes the check computable (a field naming the
  implementing script, plus a configured scan-directory list) and flags it
  as new, not quoted, design.

## Global Constraints

- No arbitrary code execution in the Predicate DSL (ADR-0020 item 3) — the
  schema-level `oneOf` in API / Contract Plan structurally excludes any
  operator or field outside the fixed, closed set; there is no "raw
  expression" escape hatch anywhere in the grammar.
- Determinism: the evaluator, the validator, and the digest generator must
  each produce byte-identical output for identical input, across `.sh` and
  `.ps1` invocations of the same Python master (Test Strategy item 3;
  decision v2 §18.3's dual-runtime fixture requirement).
- No secrets, credentials, or provider-specific detail anywhere in
  `contracts/capability-registry.json` (ADR-0018; enforced by REQ-003(g)).

## Security Boundaries

- **B1 — Provider-neutrality.** REQ-003(g) is the only enforcement boundary
  in this spec; a Capability entry that names a real provider fails
  validation before it can be trusted as a source of truth (ADR-0018).
- **B2 — No dynamic evaluation.** The Predicate DSL's closed grammar
  (Global Constraints) is the boundary preventing "arbitrary code as
  configuration" (ADR-0020's own stated risk).
- **B3 — Protected-file integrity.** Every write to a guard-invariants-
  protected path (Protected-File Statement) goes through human-copy with a
  SHA-256 manifest; no script this spec designs writes to a protected path
  directly.

## External Integrations

None. Every deliverable is repository-internal (contract file + script);
no network call, no external service, no Provider API (explicitly forbidden
in the DSL, ADR-0020 item 3).

## Deployment / CI Plan

- `.github/workflows/test.yml` gains (via human-copy, Protected-File
  Statement): a `generate-gate-capabilities.py --check` step (mirroring
  `generate-guard-invariants.py --check` at `test.yml:30,35`) and steps
  running each of the six new `tests/*.tests.sh`/`.tests.ps1` pairs.
- No release-version bump is implied by this Epic alone; any version bump
  goes exclusively through `scripts/bump-version.sh`, per the repository-wide
  convention already stated in prior specs (e.g.
  `specs/epic-159-pillar-c/requirements.md` REQ-009) and not repeated in
  full here since this spec introduces no new bump-version exception.

## Constraint Compliance

- Foundation implements only `stage: implementation` Gates (ADR-0017 item
  1): the schema reserves `artifact`/`promotion` as enum values (API /
  Contract Plan), the projection generator omits non-implementation-stage
  Gates from `gate-capabilities.json` (API / Contract Plan), and the
  validator's stage-completeness check (REQ-003(b)) exempts them explicitly.
- No plugin, script, contract, test, or `.github` file is created or
  modified by this spec commit (Non-goals, AC-021) — every path named above
  is a target for the implementation phase's tasks.md, not this commit's
  diff.

## Assumptions

- Epic A1's canonicalizer will expose a stable, importable interface (module
  or CLI) by the time Epic A2's implementation phase begins; if it instead
  ships as an inline, non-reusable script, REQ-004's task will need a small
  adapter, not a redesign.
- No Capability Pack exists yet, so REQ-003(d)'s Pack-gate-definition check
  and REQ-003(c)'s unregistered-script check are validated against
  synthetic, this-spec-authored fixtures rather than real Pack content
  (Test Strategy).
- `plugins/sdd-capability/` is a new plugin; its `.plugin`/`.claude-plugin`/
  `.codex-plugin` manifest scaffolding (matching every other plugin in this
  repository) is implementation-phase work, scheduled in tasks.md, not
  designed field-by-field here since manifest shape is unrelated to Epic
  A2's registry/DSL/validator/digest/projection scope.

## Open Questions

Carried forward from investigation.md (not re-litigated here, only indexed
for a reviewer's convenience): OQ-001 (`lite_policy.upgrade_reasons`
vocabulary), OQ-002 ("conditions" vs. `trigger` field semantics), OQ-003
(`delivery_strategy.kind` enum membership), OQ-004 (unregistered-script check
mechanism). A fifth, design-only question: whether the generated projection
should mirror guard-invariants' full four-language generation (`.py`, `.js`,
`.sh`, `.ps1`) or ship only the JSON projection `sdd-quality-loop` actually
reads (API / Contract Plan proposes JSON-only, since no consumer for a
`.py`/`.js`/`.sh`/`.ps1` *rendering* of the Registry has been identified
anywhere in decision v2 or the ADRs — guard-invariants needs four languages
because `sdd-hook-guard` itself ships in four languages; `gate-capabilities.json`
has exactly one identified consumer, `sdd-quality-loop`'s gate skill, which
decision v2 does not require to exist in four languages itself).

## Risks

- **Plugin-placement churn.** If a human reviewer disagrees with the new
  `plugins/sdd-capability/` plugin (Design Decisions), every script path in
  this design shifts; mitigated by scheduling plugin scaffolding as its own,
  early, separately-reversible task (tasks.md) rather than interleaving it
  with schema/evaluator work.
- **`contracts/` vs. `sdd/` reversal.** If a human reviewer intended literal
  YAML authoring for the Registry (contradicting this spec's JSON choice),
  REQ-001/REQ-004's canonicalization story changes materially (the YAML-1.2-
  parse step would then apply, per decision v2 §18.3) — mitigated by
  flagging this explicitly rather than burying it (Design Decisions).
- **OQ-004's bidirectional unregistered-script check may be more expensive
  to maintain than valuable** once real Capability Packs exist and ship
  their own check scripts outside this repository's own `plugins/` tree
  (e.g. a downstream consumer's custom Gate script). This spec's version of
  the check only scans configured, in-repository directories; a
  Pack-shipped-elsewhere script would need its own `implementation_ref`
  entry and would not be flagged as "unregistered" merely for living outside
  the scanned set — this asymmetry is worth revisiting once a real
  Capability Pack exists (decision v2 §17's rollout order).
