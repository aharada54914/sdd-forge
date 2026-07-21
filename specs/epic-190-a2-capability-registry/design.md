# Design: epic-190-a2-capability-registry

Impl-Review-Status: Pending
Feature Type: new machine-readable contract (Capability Registry schema +
instance, plus a versioned lite-upgrade-reason catalog) plus four
deterministic scripts (Predicate DSL evaluator, Registry validator,
`registry_digest` generator, projection generator) added to the existing
`plugins/sdd-quality-loop/` plugin, their protected-file/CI wiring, and a
package-relative Registry discovery contract for standalone installs.

## Technical Summary

Epic A2 introduces one new machine-readable contract (the Capability
Registry, plus a small companion lite-upgrade-reason catalog) and four
deterministic, testable scripts around it: a Predicate DSL evaluator, a
Registry validator, a `registry_digest` generator, and a projection
generator. It introduces no new UI, no new UX surface, and no new runtime
service — every deliverable is a static contract file plus a
Python-master/sh+ps1(+js)-wrapper script pair, following conventions already
in use for guard-invariants and effort-routing v2 (investigation.md INV-009,
INV-010, INV-014). All four scripts, and the Registry-discovery contract
they share, are added to the **existing** `plugins/sdd-quality-loop/`
plugin — this spec does not introduce a new plugin (Design Decisions,
below; INV-015; adversarial spec review 2026-07-22). This document is the
**design for the implementation phase**; no file it describes is created by
this spec commit (requirements.md Non-goals, AC-034).

## Architecture

```
contracts/capability-registry.schema.json   (JSON Schema, draft-07)
contracts/capability-registry.json          (Registry instance, "schema": "capability-registry/v1")
contracts/lite-upgrade-reason-catalog.json  (versioned catalog, "schema": "lite-upgrade-reason-catalog/v1")
        │
        ├─► plugins/sdd-quality-loop/scripts/validate-capability-registry.py (+ .sh/.ps1)
        │     Gate-ID uniqueness, stage completeness, unregistered-script
        │     detection (Gate implementation identity), Pack-gate-definition
        │     absence, referential integrity, Provider-name contamination,
        │     lite-upgrade-reason-catalog conformance (REQ-003(a-h))
        │
        ├─► plugins/sdd-quality-loop/scripts/evaluate-predicate.py (+ .sh/.ps1)
        │     ADR-0020 Predicate DSL evaluator; called with a `trigger` or
        │     `conditional_facets[].when` expression + component properties
        │     (REQ-002)
        │
        ├─► plugins/sdd-quality-loop/scripts/generate-registry-digest.py (+ .sh/.ps1/.js)
        │     calls Epic A1's canonicalizer; outputs sha256 over a named
        │     Registry fragment (REQ-004)
        │
        └─► plugins/sdd-quality-loop/scripts/generate-gate-capabilities.py (+ .sh/.ps1)
              reads the validated Registry (via its canonical monorepo-
              relative path — this script is the projection's producer, so
              it never reads the packaged/vendored copy), writes the
              protected projection:
              plugins/sdd-quality-loop/scripts/generated/gate-capabilities.json
              (REQ-005) ──► read by sdd-quality-loop's own Implementation Gate

Registry discovery contract (REQ-005), shared by every script above except
the projection generator itself — script-relative, not runtime-variable-
relative (P10):
  1. packaged copy at a fixed offset from the invoking script's own
     symlink-resolved real path: <script-real-dir>/../contracts/capability-registry.json
  2. git-root fallback: `git rev-parse --show-toplevel` (or a `.git` walk)
     + /contracts/capability-registry.json
  3. neither resolves, or the artifact's own per-artifact version check
     (API / Contract Plan) fails → fail closed with a diagnostic naming
     every attempted path
  4. release gate: a `--check` mode compares each canonical `contracts/*`
     file's sha256 against its vendored `plugins/sdd-quality-loop/contracts/*`
     counterpart, failing CI on any stale copy
```

No new plugin is introduced. `plugins/sdd-quality-loop/` already carries a
complete, working 3-environment manifest (`.claude-plugin/plugin.json`,
`.codex-plugin/`, `copilot-agents/`, `hooks/{claude-hooks.json,hooks.json,
copilot-hooks.json}`) — Design Decisions, below, records the new-plugin
alternative this spec's first draft proposed, and why it is rejected.

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
        "implementation_ref": "plugins/sdd-quality-loop/scripts/check-update-migration.py"
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
  exist yet, INV-002. `delivery_strategy.kind`'s value `"durable-workflow"`
  is an arbitrary, non-empty string in this example, not a member of a
  closed enum — see API / Contract Plan.)
- `contracts/lite-upgrade-reason-catalog.json` — the versioned catalog
  REQ-003(h) validates `upgrade_reasons` tokens against:
  ```json
  {
    "schema": "lite-upgrade-reason-catalog/v1",
    "catalog_version": 1,
    "reasons": ["public_distribution", "production_cloud_runtime",
      "durable_workflow", "external_identity", "pii"]
  }
  ```
  (Illustrative starting set — ADR-0022's YAML example's five tokens; the
  broader eleven-category prose list, ADR-0022's own item 4, is Epic A6's
  decision about what to *add* to this catalog, not this spec's. The catalog
  is additive/versioned: a new `catalog_version` may add reasons without
  changing `capability-registry.schema.json`.)
- `plugins/sdd-quality-loop/scripts/evaluate-predicate.{py,sh,ps1}` — the
  Predicate DSL evaluator. Python master implements the actual
  operator/evaluation-semantics logic; `.sh`/`.ps1` are thin argument-
  forwarding wrappers (the `sdd-hook-guard.sh` pattern, INV-014). Input:
  a predicate expression (JSON) + a nested property object (the affected
  component's allowlisted fields, addressed by dotted path the same way
  Epic A1's Project Context schema nests `characteristics.*` — not a
  flattened-key-only map). Output: `{"result": bool, "evidence": [...]}`
  conforming to the Evidence JSON Schema (API / Contract Plan).
- `plugins/sdd-quality-loop/scripts/validate-capability-registry.{py,sh,ps1}`
  — the Registry validator (REQ-003 checks a-h).
- `plugins/sdd-quality-loop/scripts/generate-registry-digest.{py,sh,ps1,js}`
  — the `registry_digest` primitive (REQ-004), depends on Epic A1's
  canonicalizer module (imported, not vendored/reimplemented); ships a
  `.js` wrapper in addition to `.sh`/`.ps1` because it calls Epic A1's
  canonicalizer, which itself ships sh/ps1/js wrappers (decision v2 §18.3,
  INV-006) — the digest generator's own wrapper set mirrors its dependency's.
- `plugins/sdd-quality-loop/scripts/generate-gate-capabilities.{py,sh,ps1}`
  — the projection generator (REQ-005), `--check` mode for CI drift
  detection, mirroring `generate-guard-invariants.py`'s own `--check`
  contract exactly.
- `plugins/sdd-quality-loop/references/provider-terms.json` — the Provider-
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
- `plugins/sdd-quality-loop/contracts/capability-registry.json`/`.schema.json`
  (packaged, plugin-relative copies) — vendored from the canonical
  `contracts/` originals at packaging time so a standalone-installed plugin
  can discover the Registry without a monorepo checkout (Registry discovery
  contract, API / Contract Plan). The vendoring/packaging step itself
  (wiring into `scripts/bump-version.sh` or an equivalent) is
  implementation-phase work, not designed field-by-field here (Assumptions).
- `plugins/sdd-quality-loop/scripts/generated/gate-capabilities.json` — the
  protected, generated projection (REQ-005), headed by a top-level
  `"_generated"` metadata object (`source`, `schema_version`, `sha256`, and
  a "This file is generated. Do not edit." notice string) — the **sole**
  normative header format; no comment-line convention is used anywhere for
  this file, since `# ...`/`// ...` comments are not valid JSON (see API /
  Contract Plan for the exact shape).

## Protected-File Statement

Two categories of protected-file interaction, both via human-copy
(`specs/epic-190-a2-capability-registry/human-copy/` + `MANIFEST.sha256`,
ADR-0011 pattern — INV-009):

1. **Registering new protected paths.** `guard_invariants.py`'s
   `PROTECTED_GATE_SUFFIXES` and `PHASE2_HUMAN_COPY_TARGETS` lists are
   generated from `plugins/sdd-quality-loop/references/guard-invariants.json`
   by `generate-guard-invariants.py`, and both the source JSON and every
   generated output are themselves protected (INV-009) — self-hosting. Epic
   A2's implementation phase must add these paths to `guard-invariants.json`'s
   source list:
   - `contracts/capability-registry.schema.json`
   - `contracts/capability-registry.json`
   - `contracts/lite-upgrade-reason-catalog.json`
   - `plugins/sdd-quality-loop/scripts/generate-gate-capabilities.py`
   - `plugins/sdd-quality-loop/scripts/generated/gate-capabilities.json`
   - `plugins/sdd-quality-loop/contracts/capability-registry.json`/`.schema.json`
     (the packaged, plugin-relative vendored copies — protecting these
     prevents the vendored copy from silently drifting from the canonical
     `contracts/` originals between packaging runs)

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

| Layer | Summary | Canonical Detail | Owner | Status |
|---|---|---|---|---|
| UX | N/A — no change: no UI, no UX surface (Technical Summary) | [UX specification](ux-spec.md) | — | N/A |
| Frontend | N/A — no change: no browser/client UI, no new runtime service; script/runtime inventory recorded for completeness | [Frontend specification](frontend-spec.md#technology-stack) | — | N/A |
| Infrastructure | No new runtime deployment; CI drift checks (`--check` modes) plus release-gating vendored-copy check, 3-environment (Claude Code / Codex CLI / Copilot CLI) standalone-install discovery | [Infrastructure specification](infra-spec.md#deployment-topology) | Implementation task owner | Planned |
| Security | Provider-neutrality (B1) / no-dynamic-evaluation (B2) / protected-file integrity (B3) / discovery fail-closed (B4) — STRIDE/OWASP detail expanded from Security Boundaries below | [Security specification](security-spec.md#trust-boundaries) | Implementation task owner | Planned |

Detailed layer content lives in the dedicated files linked above, expanded
from — and not contradicting — the summary boundaries and constraints this
document already fixes (Security Boundaries, Deployment / CI Plan, Global
Constraints). It remains true that Epic A2 has no UX, frontend, or
infrastructure-*provisioning* layer of its own (schema + deterministic
script + generated-artifact work, covered in full by Components and API /
Contract Plan) — the linked files restate that same scope in the review
harness's required per-layer file shape, they do not expand it.

## Design System Compliance

Not applicable — no UI surface.

## Cross-Layer Dependencies

- REQ-004 (`registry_digest`) → Epic A1's canonicalizer (Dependencies,
  requirements.md) — **blocked** until Epic A1 publishes a finalized path,
  version, and I/O contract.
- REQ-002's field allowlist → Epic A1's Project Context schema, generated
  from/drift-checked against it rather than hand-copied
  (`distribution_channels`, `data_classification` for full exercise against
  real data; fixture-based testing does not require Epic A1 to land first,
  investigation.md INV-004a).
- REQ-005's generated projection → consumed by `sdd-quality-loop`'s own
  Implementation Gate (same plugin, not a cross-plugin dependency, since
  Design Decisions rejects a separate plugin).
- REQ-002/REQ-004 (and, for full Capability data, the Registry itself via
  REQ-005's discovery contract) → consumed by Epic A5's Resolver (downstream,
  not a blocking dependency on Epic A2's own implementation — Dependencies,
  requirements.md); this makes `plugins/sdd-quality-loop/` a shared-library
  dependency for whichever plugin implements Epic A5, the same way other
  Epics already depend on shared plugins.

## ADR Change Log

No new ADR is proposed by this spec. Every design decision below traces to
an existing ADR (0017, 0018, 0020, 0021, 0022) or decision v2 §§3, 6, 10, 11,
13, 16, 18.3, 19. Two judgment calls this spec's first draft made were
corrected by orchestrator ruling (2026-07-22, adversarial spec review) rather
than left as open design decisions: (1) `delivery_strategy.kind` is now an
open, non-empty string with no inferred vocabulary (was: a closed four/five-
value enum inferred from decision v2 §17); (2) "conditions" is confirmed as
describing the DSL body itself, not a third schema field (was: flagged for
human confirmation, now resolved). Where this spec still makes a judgment
call the ADRs leave open (`implementation_ref`'s Gate-implementation-identity
mechanism, `upgrade_reasons`'s catalog-based fail-closed check without a
frozen vocabulary), it is recorded below under Design Decisions and
cross-referenced to investigation.md's Open Questions, not silently folded
into an ADR's scope.

## Data Plan

- `contracts/capability-registry.json` is the primary new persistent data
  file this spec's implementation phase creates at the contract layer
  (REQ-001). It is hand-edited by Registry maintainers (no UI), validated by
  REQ-003, and projected by REQ-005. No database, no migration, no runtime
  storage.
- `contracts/lite-upgrade-reason-catalog.json` is a second, small persistent
  data file (REQ-003(h)) — versioned and additive; new catalog versions add
  reasons, never remove or redefine existing ones within Foundation's scope.
- `plugins/sdd-quality-loop/scripts/generated/gate-capabilities.json` and
  `plugins/sdd-quality-loop/contracts/capability-registry.json`/`.schema.json`
  are derived data (regenerated/vendored from the `contracts/` originals
  above), never hand-edited (protected).
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
  where the schema language already provides one). A `stage: artifact`/
  `promotion` entry with no `implementation_ref` passes schema validation and
  is exempt from every completeness check (reserved-stage inertness, AC-002)
  — a dedicated positive fixture (`stage: implementation` + valid
  `implementation_ref` passes) and negative fixture (`stage: implementation`
  + missing `implementation_ref` is rejected) both exist in Test Strategy
  item 5. `minimum_enforcement` is a separate, `capabilities[]`-level
  optional field (AC-005) with its own positive/negative/optionality
  fixtures, unrelated to `gates[].stage`.

`capabilities[]` item (`additionalProperties: false`, **`required`:
`["id", "trigger", "required_facets", "conditional_facets",
"review_check_ids", "gate_ids", "delivery_strategy"]`** — closing the
2026-07-22 verification pass's NEW Major finding, which correctly noted
this spec's prior draft never stated an explicit `required` list, leaving
`delivery_strategy` schema-valid-when-absent even though decision v2 §13
lists delivery-strategy classification among the fixed set of things every
Capability entry in the sole machine-readable source of truth must carry.
`lite_policy` and `minimum_enforcement` are the only two genuinely optional
fields — decision v2 itself makes both conditional (lite-track applicability
and an above-default enforcement floor, respectively), so their absence is
meaningful, not an omission):
- `id` (string, same pattern as `gates[].id`)
- `trigger` (`$ref: "#/definitions/predicate"`)
- `required_facets` (array of strings, `uniqueItems: true`; may be `[]`)
- `conditional_facets` (array of `{facet: string, when: predicate}`,
  `additionalProperties: false`; may be `[]`)
- `review_check_ids` (array of strings, `uniqueItems: true`; may be `[]`)
- `gate_ids` (array of strings, `uniqueItems: true`; may be `[]` — a
  Capability with no Gates is still schema-valid, only `delivery_strategy`
  is the field this ruling closes as required. Referential integrity
  against `gates[].id` is a validator-level check only, REQ-003(f) — JSON
  Schema draft-07 cannot express "must equal one of this sibling array's
  runtime values", so the schema's own constraint on `gate_ids` stops at
  type/syntax: array of unique strings. No part of this schema claims a
  schema-level dynamic reference check.)
- `lite_policy` (optional; `{eligible: boolean (required), upgrade_reasons:
  array of non-empty strings (optional, default [])}`, `additionalProperties:
  false`; each `upgrade_reasons` token's membership in
  `contracts/lite-upgrade-reason-catalog.json` is a REQ-003(h) validator
  check, not a schema-level enum — the schema only constrains shape)
- `minimum_enforcement` (optional; `const: "required"` — no other value is
  defined by decision v2 §10, so the schema does not invent one)
- `delivery_strategy` (**required**, `required: ["kind"]`,
  `{kind: string, minLength: 1}`, `additionalProperties: false` — **no
  enum**. Both `delivery_strategy` itself and its `kind` property are
  required — a Capability entry missing either fails schema validation;
  Test Strategy item 5 adds a missing-`delivery_strategy` fixture and a
  missing-`kind` fixture, both rejected, alongside the existing
  present-but-empty/non-string `kind` rejection. Decision v2 requires only
  that the field exist (`docs/ai-dlc-foundation-decision-v2.md:401`); it
  reserves vocabulary-freezing for a later, real-case ADR (`:118-120`,
  `:399-402`, `:488-492`), the same pattern ADR-0017 already applies to the
  Artifact/Promotion Gate vocabulary. This spec's first draft inferred a
  closed enum from decision v2 §17's Pack rollout order and is corrected by
  orchestrator ruling 2026-07-22 — see Design Decisions.)

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
The `field` enum above is generated from, or drift-checked against, Epic
A1's Project Context schema once it lands (AC-011, INV-004a) rather than
maintained as a second, hand-copied list.

`not`'s schema shape (`{"not": <predicate>}`, a single required property
holding one predicate object, not an array) already enforces arity exactly 1
structurally — a construction that supplies zero or more than one child
under `not` cannot even parse against this schema, so it is rejected as
`PREDICATE_SCHEMA_ERROR` before evaluation, not accepted and misinterpreted
(AC-012). The evaluator's own truth table for `not`: child result `true` →
`not` result `false`; child result `false` → `not` result `true`; child
result `false`+`WARN` → `not` result `false` (the `WARN` reason is preserved
on the child's own Evidence entry, not inherited by `not` itself, since `not`
inverts a boolean, not a WARN flag).

### Predicate DSL evaluator contract (REQ-002)

`evaluate-predicate.py --predicate <path|-> --component-properties <path|->`
→ stdout JSON `{"result": bool, "evidence": [...]}`, exit 0 always (the
evaluator itself never fails on a well-formed predicate — a `false` result
with a `WARN` reason is a normal, successful evaluation, not an error, per
ADR-0020's fail-closed-not-fail-loud design). Malformed input (invalid JSON,
a field outside the allowlist, an operator outside the fixed set, or a `not`
node whose shape does not parse against `#/definitions/predicate`) is a
distinct, non-zero-exit `PREDICATE_SCHEMA_ERROR` — this is a construction-
time error, not a fail-closed evaluation outcome, and must not be conflated
with a `WARN`.

**Evidence JSON Schema** (each array element of the `evidence` output):
```json
{
  "type": "object",
  "additionalProperties": false,
  "required": ["operator", "path", "outcome"],
  "properties": {
    "operator": {"enum": ["all", "any", "not", "equals", "not_equals",
      "contains", "in", "exists"]},
    "path": {"type": ["string", "null"]},
    "outcome": {"enum": ["match", "no-match", "warn"]},
    "reason": {"type": "string"},
    "children": {"type": "array", "items": {"$ref": "#"}}
  },
  "if": {"properties": {"outcome": {"const": "warn"}}},
  "then": {"required": ["operator", "path", "outcome", "reason"]}
}
```
`path` is `null` for logical nodes (`all`/`any`/`not`), which instead carry a
`children` array — nested logical trees record their children's Evidence in
a fixed **depth-first, left-to-right, stable order** regardless of outcome
(AC-013), so that two evaluations of the identical predicate tree against
the identical component properties always produce byte-identical `evidence`
output (Global Constraints' determinism requirement extends to Evidence
shape, not just the boolean `result`).

### Registry validator contract (REQ-003)

`validate-capability-registry.py --registry <path>` → exit 0 (all checks
pass) or non-zero with one diagnostic line per failed check, in the style of
`check-sdd-structure.sh`'s `missing: <item>` lines (`registry: <check-id>:
<detail>`). Each of the nine checks (a-i in requirements.md REQ-003) is an
independently identifiable, independently testable failure mode:

| Check | Diagnostic ID | Scope |
|---|---|---|
| (a) Gate ID uniqueness | `gate-id-duplicate` | top-level `gates[]` |
| (b) stage-completeness | `implementation-ref-missing` | `stage: implementation` gates |
| (c) unregistered-script detection | `unregistered-script` | Gate implementation identity (below) |
| (d) no Pack-owned Gate definitions | `pack-owns-gate-definition` | repository-wide forward-guard |
| (e) no missing `stage` (defense-in-depth) | `stage-missing` | top-level `gates[]`, validator-direct |
| (f) referential integrity | `dangling-gate-reference` | `capabilities[].gate_ids` |
| (g) Provider-name contamination | `provider-name-detected` | every string-valued field |
| (h) lite-upgrade-reason-catalog conformance | `unknown-upgrade-reason` | `lite_policy.upgrade_reasons` |
| (i) Capability ID uniqueness | `capability-id-duplicate` | top-level `capabilities[]`, independent of (a) |

**Gate implementation identity** (check (c), OQ-004, this spec's own
proposal, **fully closed per orchestrator ruling 2026-07-22 — P8**): a
configuration fixes, concretely, not by example, all four of the following:
1. **Canonical reference.** `gates[].implementation_ref` names exactly one
   file: the Python master script (`.py`), and only the `.py` path — never
   an `.sh`/`.ps1`/`.js` wrapper. The illustrative fixture in Components,
   above, is corrected to `"implementation_ref":
   "plugins/sdd-quality-loop/scripts/check-update-migration.py"` (was,
   incorrectly, its `.sh` wrapper in this spec's prior draft).
2. **Scan roots.** Exactly one concrete, enumerated value —
   `["plugins/sdd-quality-loop/scripts/"]` — not an illustrative pattern
   like `plugins/*/scripts/`. Extending this list to a second literal
   directory (e.g. if a future plugin also ships Gate scripts) is itself a
   Registry-validator config change, reviewed like any other validator
   behavior change, not an implicit wildcard match.
3. **Gate-shaped script selection rule.** Within a scan root, a script is
   "gate-shaped" (subject to the unregistered-script check at all) if and
   only if its basename starts with the `check-` prefix — the existing
   repository convention already followed by `check-contract.py`,
   `check-placeholders.py`, `check-task-state.py`,
   `check-workflow-state.py`, and every other script under
   `plugins/sdd-quality-loop/scripts/` that implements a Gate-style check.
   A script under the scan root whose basename does **not** start with
   `check-` (e.g. `emit-run-record.py`, `kill-switch.js`) is out of scope
   for this identity check entirely — never scanned, never flagged
   `unregistered-script`, regardless of whether any `gates[]` entry
   references it.
4. **Wrapper grouping.** For a `check-<name>.py` master, its wrapper group
   is every sibling file in the **same directory** sharing the identical
   basename `check-<name>` across the recognized wrapper extensions
   (`.sh`, `.ps1`, `.js`); a `.sh`/`.ps1`/`.js` file in that group is never
   itself independently gate-shaped or independently unregistered — it is
   part of the one implementation identity its `.py` master defines. A
   symlinked script (master or wrapper) resolves to its target path before
   grouping or comparison.

Discovery rules built on the above: every `check-`-prefixed `.py` file under
`plugins/sdd-quality-loop/scripts/` is exactly one implementation identity;
a `check-`-prefixed `.py` master with no `gates[].implementation_ref`
naming its own path is `unregistered-script`; a script outside
`plugins/sdd-quality-loop/scripts/` (e.g. a future external Capability
Pack's own script directory) is never flagged, structurally exempt because
it is outside the one configured scan root, not merely untested (Test
Strategy item 2's bidirectional fixture set).

**lite-upgrade-reason-catalog conformance** (check (h)): every string in
every `capabilities[].lite_policy.upgrade_reasons` array must appear in
`contracts/lite-upgrade-reason-catalog.json`'s `reasons` array (loaded via
the same Registry discovery contract, REQ-005); an entry absent from the
catalog is `unknown-upgrade-reason` — fail-closed, not a silent pass. Adding
a new reason to Epic A6's vocabulary is a catalog edit (a new
`catalog_version`), not a schema change.

### `registry_digest` generator contract (REQ-004)

`generate-registry-digest.py (--capability-ids <id[,id...]> | --gate-ids
<id[,id...]> | --whole)` (the first two flags may be combined; at least one
of the three forms is required) → stdout the sha256 hex digest of the
canonical-JSON (via Epic A1's canonicalizer) serialization of the selected
fragment. Fragment construction:
1. Parse `--capability-ids`/`--gate-ids` as comma-separated ID lists;
   dedupe each list.
2. Any ID not present in the Registry (`capabilities[].id` or `gates[].id`
   respectively) is a hard failure (`unknown-fragment-id`, non-zero exit) —
   never a silent no-op.
3. The fragment's `capabilities` sub-array is every named Capability;
   its `gates` sub-array is the union of every named Capability's
   transitively-referenced `gate_ids` **and** every directly-named
   `--gate-ids` entry.
4. Both sub-arrays are stable-sorted by `id` (lexicographic) before
   serialization — this is the step that guarantees two callers requesting
   the identical semantic ID set in a different order, or with input
   duplicates, produce an identical digest, since JCS canonicalizes object
   key order but not array order (Problems, requirements.md).
`--whole` selects the entire Registry (its own `gates`/`capabilities` arrays,
already author-ordered, are not re-sorted — `--whole`'s determinism instead
follows directly from hashing the one committed file). No other output.

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
This `_generated` object is the **only** header/provenance contract this
spec defines for the projection — there is no comment-line ("# Generated
...") variant anywhere in this package (Blocker finding, adversarial review
2026-07-22, now closed). With `--check`: recomputes the same content in
memory, compares byte-for-byte against the committed file, exits non-zero on
any difference (no write, no filesystem mutation of any kind — asserted via
mtime-unchanged in Test Strategy item 4), matching
`generate-guard-invariants.py --check`'s contract exactly. The generator
always reads its source Registry via the canonical monorepo-relative
`contracts/` path (never the packaged/vendored copy under its own plugin
directory), since it is that vendored copy's own producer.

### Registry discovery contract (REQ-005)

**Fully closed per orchestrator ruling 2026-07-22 — P10.** The prior draft's
dependence on a runtime-specific plugin-root environment variable
(`${CLAUDE_PLUGIN_ROOT}` and undefined "Codex/Copilot analogs") is dropped.
Discovery is **script-relative**, not runtime-variable-relative, so it works
identically regardless of which host process invoked the script:

1. **Script-relative packaged copy.** Resolve the currently-executing
   script's own file path to its real, symlink-resolved location (the
   equivalent of `os.path.realpath(__file__)`/`readlink -f "$0"` — a script
   invoked through a symlinked entry point, e.g. from an installed plugin's
   own layout, still resolves to its true on-disk directory). From that real
   directory, look for the packaged copy at the fixed, script-relative
   offset `../contracts/<filename>` (i.e., for a script at
   `.../plugins/sdd-quality-loop/scripts/<name>.py`, the packaged copy is
   `.../plugins/sdd-quality-loop/contracts/<filename>`, Components). If it
   exists, use it — no environment variable of any kind is consulted.
2. **git-root fallback.** Otherwise, resolve the repository root via
   `git rev-parse --show-toplevel` (falling back to walking upward from the
   script's real directory to the nearest `.git` file/directory if the `git`
   command itself is unavailable), and use
   `<git-root>/contracts/<filename>` (the in-repo development case).
3. **Fail closed.** If neither location resolves, or the version check
   (below) fails, exit non-zero with a diagnostic naming both attempted
   paths and the version-check result — never silently proceed with a
   stale or absent artifact.

**Version check — a per-artifact key, not one shared rule** (closing the
prior draft's contradiction, which defined only a `capability-registry/v1`
`schema` check and then claimed it also covered the JSON Schema file and the
reason catalog):

| Artifact | Version check |
|---|---|
| `capability-registry.json` | top-level `schema == "capability-registry/v1"` |
| `capability-registry.schema.json` | top-level `$schema` keyword is present (confirms it is a JSON Schema document, not a data instance) **and** `$id` equals this schema's own declared `$id` (API / Contract Plan, matching `workflow-state-registry.schema.json`'s `$id` convention) |
| `lite-upgrade-reason-catalog.json` | top-level `schema == "lite-upgrade-reason-catalog/v1"` |

Each check is independent and specific to its artifact's own shape; no
script applies the `capability-registry.json` rule to the schema file or the
catalog, or vice versa.

**Vendored-copy drift check (release gate / CI contract).** The
vendoring/packaging step (Deployment / CI Plan) that refreshes
`plugins/sdd-quality-loop/contracts/*` from the canonical `contracts/*`
originals must itself support a `--check` mode, mirroring
`generate-gate-capabilities.py --check`'s own no-write, non-zero-exit-on-
mismatch contract: for each of the three artifacts, compute the sha256 of
the canonical `contracts/<filename>` and compare it to the sha256 of
`plugins/sdd-quality-loop/contracts/<filename>`; any mismatch is a
non-zero-exit failure naming the stale file. This check runs in CI (wired
alongside `generate-gate-capabilities.py --check`, Deployment / CI Plan)
and gates any release/version bump — `scripts/bump-version.sh` must not
proceed while a vendored copy is stale relative to its canonical source,
closing the staleness gap this spec's prior draft left unaddressed (Risks).

Three fixtures (Test Strategy item 8) simulate a standalone install per
runtime (only the packaged copy present at the script-relative path, no
monorepo `contracts/`, no `.git` marker reachable) to prove step 1 alone is
sufficient, independent of which host process invoked the script.

## Test Strategy

Eight new `tests/*.tests.sh`/`.tests.ps1` pairs (REQ-006), each with fixture
data under `tests/fixtures/capability-registry/`:
1. `evaluate-predicate` — every operator × {matching, non-matching, missing
   path, null value, type mismatch} where applicable; `exists` × {present-
   with-null (true), present-with-value (true), absent (false+WARN)};
   `all`/`any` × {empty list, all-true, all-false, mixed} with an assertion
   that every child's evidence entry is present even when the parent's
   result was already determined by an earlier child (proving no short-
   circuit); `not` × {child true, child false, child false+WARN} against the
   documented truth table, plus a fixture where a malformed `not` shape
   (zero or two children) is rejected as `PREDICATE_SCHEMA_ERROR`; a
   fixture using an operator token outside the closed 8-operator set (e.g.
   `regex`, `jsonpath`) is rejected as `PREDICATE_SCHEMA_ERROR` (AC-040),
   independent of TEST-011's field-allowlist fixture; a
   `trigger`-labeled fixture asserting it is evaluated by the identical code
   path as a `conditional_facets[].when` fixture (byte-identical evidence
   shape); Evidence-JSON-Schema conformance for every fixture's `evidence`
   output; a nested `all`-of-`any`-of-comparisons fixture asserting
   depth-first, left-to-right, stable Evidence ordering.
2. `validate-capability-registry` — one fixture per REQ-003 check (a-i),
   each a minimal Registry mutation isolating exactly one failure mode
   (including a bidirectional Gate-implementation-identity fixture set for
   check (c): an sh+ps1 wrapper pair counted as one registered
   implementation, an out-of-scan-root script not flagged, an in-scan-root
   script with no `implementation_ref` flagged; a validator-direct,
   schema-bypassing fixture for check (e)'s defense-in-depth re-assertion;
   and, for check (i), a two-`capabilities[]`-entries-share-one-`id` fixture
   plus a combined fixture carrying one `gates[].id` duplicate and one
   `capabilities[].id` duplicate simultaneously, asserting both diagnostics
   surface and neither masks the other), plus one fully-clean fixture
   proving a negative (all checks pass on
   valid input) so the suite cannot pass vacuously. This suite's setup also
   runs a one-off repository-structure assertion (AC-028) confirming
   `plugins/sdd-capability/` does not exist and every script/reference file
   this spec designs lives under `plugins/sdd-quality-loop/` — a structural
   check for Design Decisions' rejected-new-plugin ruling, not a Registry-
   content check.
3. `generate-registry-digest` — a fixed fixture Registry, asserting (a) the
   `.sh`-, `.ps1`-, and `.js`-wrapper invocations of the digest generator
   produce an identical sha256 (dual/triple-runtime determinism, decision v2
   §18.3), (b) a single-character mutation to the fragment changes the
   digest (negative self-check proving the hash is content-sensitive), (c)
   requesting the identical semantic ID set via `--capability-ids`/
   `--gate-ids` in a different order, or with input duplicates, produces an
   identical digest (stable-sort/dedupe, AC-024), (d) an unknown ID in
   either flag is a hard failure, (e) a JCS/NFC canonicalization vector
   set (RFC 8785 key-ordering/number-formatting edge cases; Unicode NFC
   composed-vs-decomposed string equivalence) produces identical digests for
   canonically-equivalent-but-differently-encoded input, (f) invoking with
   none of `--capability-ids`/`--gate-ids`/`--whole` is a hard failure
   (`fragment-selector-required`, AC-024) rather than a silent `--whole`
   default, and (g) `--capability-ids`+`--gate-ids` supplied together
   selects the union of both ID sets' entries (AC-024).
4. `generate-gate-capabilities --check` — a clean pass against a valid
   fixture Registry + its correctly-generated projection, and a mutated-
   projection negative case (hand-edit the generated file, confirm `--check`
   fails) proving the drift check is live; an mtime-unchanged assertion
   proves `--check` never writes.
5. Schema-conformance — `contracts/capability-registry.schema.json` validates
   both a minimal-valid and a maximal-valid fixture instance, and rejects one
   fixture per structurally-invalid case (missing `implementation_ref` on a
   `stage: implementation` Gate, a non-string/empty `delivery_strategy.kind`,
   a `capabilities[]` entry with no `delivery_strategy` key at all, a
   `delivery_strategy` object present but with no `kind` key, a non-boolean
   `lite_policy.eligible`, an extra `conditions` key on a `capabilities[]`
   entry, a non-string or empty-string element in `review_check_ids`); a
   `review_check_ids: []` fixture passes; a `minimum_enforcement` positive
   fixture
   (`"required"` accepted), negative fixture (any other value rejected), and
   optionality fixture (a `capabilities[]` entry with no `minimum_enforcement`
   key at all also passes); a reserved-stage inertness fixture (`stage:
   artifact`/`promotion` `gates[]` entry, no `implementation_ref`, passes
   and is exempt from every completeness check); a `required_facets`/
   `conditional_facets[]` entry-shape fixture (AC-037: a non-string
   `required_facets` element and a malformed `conditional_facets[]` entry
   are each rejected; an empty-array fixture for both passes).
6. Provider-name-contamination — one fixture per allowlisted term category
   (cloud provider, distribution channel, workflow-runtime product name)
   confirming each is caught, plus a clean fixture proving the scan does not
   false-positive on provider-neutral vocabulary already in
   `contracts/capability-registry.json`'s own schema field names (e.g.
   `durable_workflow` as an `artifact_kinds` value is provider-neutral per
   ADR-0018 and must not itself trigger the scan — only a *provider name*
   like `durable-functions`, the Azure product name, does).
7. Parity — all four scripts' `.sh`/`.ps1` wrapper invocations (and
   `generate-registry-digest`'s `.js` wrapper) produce byte-identical output
   for identical fixture input (golden-fixture comparison, not merely
   independent correctness); each script's wrapper pair is additionally
   invoked from within a Claude Code, a Codex CLI, and a Copilot CLI
   installed-plugin context against the same fixture input, asserting
   identical exit codes and stdout across all three runtimes.
8. Registry discovery — three fixtures (one per runtime) simulate a
   standalone install (only the packaged copy at the script-relative offset
   `contracts/capability-registry.json`/`.schema.json`/
   `lite-upgrade-reason-catalog.json` present, no monorepo `contracts/`, no
   reachable `.git`, and no runtime environment variable set) and prove
   discovery succeeds via the packaged copy alone, independent of which
   host process invoked the script; three per-artifact version-mismatch
   fixtures (one per artifact's own version-check rule, API / Contract
   Plan) and a neither-location-resolves fixture prove the fail-closed
   diagnostic fires and names both attempted paths; a further fixture
   proves the release-gating `--check` mode fails when a vendored copy's
   sha256 diverges from its canonical `contracts/*` source.

All eight pairs are registered directly in `tests/run-all.sh`/`.ps1`
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
  Registry is a different artifact with different provenance). **This is a
  repo-local design/ADR-adjacent judgment call this spec makes, not a
  necessity decision v2 or any ADR compels** — decision v2 fixes neither the
  Registry's storage location nor its serialization format (adversarial
  review 2026-07-22, "OK" finding, confirming no deviation but requesting
  this framing be explicit). The valid JSON metadata shape this spec commits
  to is the `"schema": "capability-registry/v1"` self-describing-instance
  convention already used by `contracts/agent-model-capabilities.v2.json`,
  not a bare, schema-less JSON file.
- **A flat, top-level `gates[]` array, not per-Capability (INV-003).**
  ADR-0017's own schema example presents `gates:` as a flat, ungrouped list.
  A flat list makes "Gate ID uniqueness" a single array's `uniqueItems`-style
  constraint instead of a cross-capability de-duplication problem, and lets
  multiple Capabilities share one Gate (e.g. two Capabilities that both
  require `check-component-coverage`) without duplicating its definition.
- **"conditions" is not a third schema field (OQ-002, RESOLVED 2026-07-22).**
  ADR-0020 defines exactly one condition concept. The orchestrator's ruling
  confirms decision v2 §13's "trigger / conditions" as two words for the
  same DSL body (not two fields), avoiding an undocumented field. This is no
  longer flagged for human confirmation at spec review — it is the
  confirmed interpretation pending decision v2's own next revision, which is
  expected to make it explicit (investigation.md OQ-002).
- **`delivery_strategy.kind` is a reserved, open, non-empty string, not a
  closed enum (OQ-003, RESOLVED and REVERSED 2026-07-22) — and, since the
  same day's verification pass, `delivery_strategy`/`kind` are both
  required, not merely typed-when-present.** This spec's first draft
  inferred a closed enum (`developer-tooling`, `cli-library`, `desktop`,
  `cloud-service`, `durable-workflow`) from decision v2 §17's Pack rollout
  order, and inconsistently described it as a "four-value enum" while
  listing five literals. The adversarial review correctly identified both
  the internal miscount and, more fundamentally, that decision v2 requires
  only the field's *existence*, explicitly deferring vocabulary-freezing to
  a real cloud-service delivery case and its own later ADR
  (`docs/ai-dlc-foundation-decision-v2.md:118-120,399-402,488-492`) — the
  same pattern ADR-0017 already applies to the Artifact/Promotion Gate
  vocabulary. The schema types `delivery_strategy.kind` as any non-empty
  string; no enum is defined in Foundation. The 2026-07-22 verification pass
  then identified a second, distinct gap in this same area (a **NEW Major
  finding**, not a re-opening of OQ-003): this spec's schema left
  `delivery_strategy` itself `optional`, so a Capability entry could be
  schema-valid while carrying no delivery classification at all —
  undermining decision v2 §13's "sole machine-readable source of truth"
  premise regardless of what vocabulary `kind` allows. `capabilities[]`'s
  own `required` list (API / Contract Plan) now names `delivery_strategy`
  explicitly, and `delivery_strategy`'s own object schema requires `kind`;
  the field's *vocabulary* remains open (OQ-003's resolution stands), only
  its *presence* is now mandatory.
- **`upgrade_reasons` remains an open string array; a versioned catalog now
  enforces fail-closed validation (OQ-001, partially resolved 2026-07-22).**
  ADR-0022's YAML example and its own prose disagree on the count and
  membership of this set; freezing either list into a closed schema enum
  would still silently pick a side, so the schema itself remains open. The
  adversarial review correctly noted that an *unconstrained* open string
  makes Epic A6's upgrade determination typo-dependent with no automated
  safety net. REQ-003(h) closes that gap without freezing the vocabulary:
  every token must resolve against `contracts/lite-upgrade-reason-catalog.json`,
  a small, separately-versioned contract Epic A6 (or a human, ahead of Epic
  A6) can extend by adding a catalog version — an unrecognized token still
  fails validation today, but the catalog's own membership is not baked into
  `capability-registry.schema.json`.
- **Registry-authoring/validation/digest/projection scripts live in the
  existing `plugins/sdd-quality-loop/` plugin — a new `plugins/sdd-capability/`
  plugin is a rejected alternative.** This spec's first draft proposed a new
  plugin, reasoning that none of `sdd-quality-loop` (gate *execution*, not
  Registry *authoring*/*validation*), `sdd-lite` (lite track specifically),
  or `sdd-bootstrap` (interview flow) is an ideal semantic home. The
  adversarial review correctly identified that decision v2 §16 makes
  sh+ps1 scripts, a 3-environment (Claude/Codex/Copilot) plugin
  configuration, and environment-specific tests a **per-Epic Done
  condition** with no deferral to a later Epic (INV-015) — a new plugin
  would have had to stand up its own manifest, install/uninstall path, and
  3-environment test wiring for no offsetting benefit over semantic
  separation alone, and this spec's first draft scoped none of that
  packaging cost into REQ/AC/TEST. Per orchestrator ruling 2026-07-22, the
  new-plugin alternative is rejected; every script and reference file this
  spec designs is added to the existing `plugins/sdd-quality-loop/` plugin,
  which already carries a working 3-environment manifest, so no new
  packaging surface is introduced.
- **`implementation_ref` and the Gate implementation identity mechanism are
  this spec's own proposal (OQ-004, materially expanded 2026-07-22, and
  fully closed 2026-07-22 — orchestrator ruling P8).** Neither decision v2
  nor any ADR specifies a mechanism for "no unregistered script"; this
  spec's first draft proposed a bare field-plus-scanned-directories
  mechanism that left scan roots, recognized extensions, symlinks,
  sh/ps1(/js)-wrapper grouping, the gate-shaped-script selection rule, and
  `implementation_ref`'s own canonical extension undefined or
  self-contradictory (the first-draft's illustrative fixture pointed
  `implementation_ref` at a `.sh` wrapper while Field Definitions named the
  Python master — the two disagreed on which file is canonical). API /
  Contract Plan's Gate implementation identity schema now fixes all four
  dimensions concretely rather than by example: `implementation_ref` is
  always the `.py` master path; the sole scan root is the concrete literal
  `plugins/sdd-quality-loop/scripts/`; a script is gate-shaped only if its
  basename starts with `check-` (the repository's own existing convention —
  `check-contract.py`, `check-placeholders.py`, `check-task-state.py`,
  etc.); and a wrapper group is same-basename, same-directory `.sh`/`.ps1`/
  `.js` siblings of one `check-*.py` master. This remains this spec's own
  proposal, not found verbatim in decision v2 or an ADR.
- **Registry discovery is script-relative with a git-root fallback, not a
  runtime-plugin-variable or repository-root-relative assumption
  (fully closed 2026-07-22 — orchestrator ruling P10).** The adversarial
  review correctly identified that this spec's first draft designed the
  projection generator to read a hardcoded top-level `contracts/` path with
  no discovery story for a standalone-installed plugin, and that its second
  draft's fix depended on a runtime-specific plugin-root environment
  variable (`${CLAUDE_PLUGIN_ROOT}`) plus undefined "Codex/Copilot analogs"
  — a dependency that could not be verified for two of the three supported
  runtimes. API / Contract Plan's discovery contract now resolves the
  packaged copy relative to the invoking script's own symlink-resolved real
  path (no environment variable of any kind), falls back to a `git`-resolved
  repository root, defines a distinct version check per artifact (the
  Registry instance, the JSON Schema file, and the reason catalog each have
  different shapes and cannot share one check), and adds a release-gating
  `--check` mode comparing each vendored copy's sha256 against its canonical
  source — closing the staleness gap the first two drafts left open. It
  fails closed rather than silently falling back to a stale or absent
  Registry.

## Global Constraints

- No arbitrary code execution in the Predicate DSL (ADR-0020 item 3) — the
  schema-level `oneOf` in API / Contract Plan structurally excludes any
  operator or field outside the fixed, closed set; there is no "raw
  expression" escape hatch anywhere in the grammar.
- Determinism: the evaluator (including its Evidence output's depth-first
  ordering), the validator, and the digest generator (including its
  fragment's stable ID sort) must each produce byte-identical output for
  identical input, across `.sh`, `.ps1`, and (for the digest generator)
  `.js` invocations of the same Python master (Test Strategy items 1, 3, 7;
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
- **B4 — Discovery fail-closed.** The Registry discovery contract
  (API / Contract Plan) never silently falls back to a stale or absent
  artifact: an unresolved path or a failed per-artifact version check is a
  non-zero-exit diagnostic, not a degraded-but-successful run; the
  vendored-copy drift check (same section) additionally gates any release
  from shipping a stale packaged copy in the first place.

## External Integrations

None. Every deliverable is repository-internal (contract file + script);
no network call, no external service, no Provider API (explicitly forbidden
in the DSL, ADR-0020 item 3).

## Deployment / CI Plan

- `.github/workflows/test.yml` gains (via human-copy, Protected-File
  Statement): a `generate-gate-capabilities.py --check` step (mirroring
  `generate-guard-invariants.py --check` at `test.yml:30,35`), the
  vendoring/packaging step's own `--check` mode (P10, Registry discovery
  contract — sha256 comparison of each canonical `contracts/*` file against
  its vendored `plugins/sdd-quality-loop/contracts/*` counterpart, as a
  release gate), and steps running each of the eight new
  `tests/*.tests.sh`/`.tests.ps1` pairs, including the 3-runtime invocation
  parity suite (Test Strategy item 7) and the Registry-discovery
  installed-layout suite (Test Strategy item 8).
- No release-version bump is implied by this Epic alone; any version bump
  goes exclusively through `scripts/bump-version.sh`, per the repository-wide
  convention already stated in prior specs (e.g.
  `specs/epic-159-pillar-c/requirements.md` REQ-009) and not repeated in
  full here since this spec introduces no new bump-version exception. The
  packaged/vendored `contracts/` copy under `plugins/sdd-quality-loop/`
  (Components) is refreshed as part of this same version-bump/packaging
  step and gated by its own `--check` mode (above) before the bump may
  proceed; the exact wiring into `scripts/bump-version.sh` is
  implementation-phase work (Assumptions).

## Constraint Compliance

- Foundation implements only `stage: implementation` Gates (ADR-0017 item
  1): the schema reserves `artifact`/`promotion` as enum values (API /
  Contract Plan), the projection generator omits non-implementation-stage
  Gates from `gate-capabilities.json` (API / Contract Plan), and the
  validator's stage-completeness check (REQ-003(b)) exempts them explicitly.
- No plugin, script, contract, test, or `.github` file is created or
  modified by this spec commit (Non-goals, AC-034) — every path named above
  is a target for the implementation phase's tasks.md, not this commit's
  diff.
- No new plugin is introduced (Design Decisions) — every script this spec
  designs is added to `plugins/sdd-quality-loop/`'s existing manifest.

## Assumptions

- Epic A1's canonicalizer will expose a stable, importable interface (module
  or CLI), with a published version identifier and I/O contract, by the
  time Epic A2's implementation phase begins; REQ-004's task is explicitly
  **blocked** (not merely at-risk) until that contract is finalized
  (Dependencies, requirements.md) — if it instead ships as an inline,
  non-reusable script, REQ-004's task needs a small adapter, not a redesign,
  but the task cannot start before the contract exists.
- No Capability Pack exists yet, so REQ-003(d)'s Pack-gate-definition check
  and REQ-003(c)'s unregistered-script check are validated against
  synthetic, this-spec-authored fixtures rather than real Pack content
  (Test Strategy).
- No new plugin manifest is needed: `plugins/sdd-quality-loop/`'s existing
  `.claude-plugin/plugin.json`, `.codex-plugin/`, `copilot-agents/`, and
  `hooks/*` are structurally unaffected by this spec's additions — only its
  `scripts/`/`references/`/`contracts/` inventories grow. The
  vendoring/packaging step that refreshes
  `plugins/sdd-quality-loop/contracts/*` (Components, Deployment/CI Plan) is
  scheduled as its own implementation-phase task, not designed field-by-
  field here, since the packaging mechanism itself (e.g. wiring into
  `scripts/bump-version.sh`) is unrelated to Epic A2's registry/DSL/
  validator/digest/projection scope.

## Open Questions

Carried forward from investigation.md (not re-litigated here, only indexed
for a reviewer's convenience): OQ-001 (`lite_policy.upgrade_reasons`
catalog's own vocabulary — still Epic A6's decision, ADR-0022 item 4) and
OQ-004 (Gate implementation identity mechanism — this spec's own proposal,
now materially expanded, still not found verbatim in an ADR). OQ-002
("conditions" vs. `trigger` field semantics) and OQ-003
(`delivery_strategy.kind` vocabulary) are **resolved** by orchestrator ruling
2026-07-22 (investigation.md's Open Questions section) and are not reopened
by this document. A fifth, design-only question, unchanged from this spec's
first draft: whether the generated projection should mirror guard-
invariants' full four-language generation (`.py`, `.js`, `.sh`, `.ps1`) or
ship only the JSON projection `sdd-quality-loop` actually reads (API /
Contract Plan proposes JSON-only, since no consumer for a `.py`/`.js`/`.sh`/
`.ps1` *rendering* of the Registry has been identified anywhere in decision
v2 or the ADRs — guard-invariants needs four languages because
`sdd-hook-guard` itself ships in four languages; `gate-capabilities.json`
has exactly one identified consumer, `sdd-quality-loop`'s own gate skill,
which decision v2 does not require to exist in four languages itself).

## Risks

- **`contracts/` vs. `sdd/` reversal.** If a human reviewer intended literal
  YAML authoring for the Registry (contradicting this spec's JSON choice,
  which Design Decisions now states explicitly is a repo-local judgment, not
  a source-document necessity), REQ-001/REQ-004's canonicalization story
  changes materially (the YAML-1.2-parse step would then apply, per decision
  v2 §18.3) — mitigated by flagging this explicitly rather than burying it
  (Design Decisions).
- **OQ-004's Gate implementation identity mechanism may be more expensive to
  maintain than valuable** once real Capability Packs exist and ship their
  own check scripts outside this repository's own `plugins/` tree (e.g. a
  downstream consumer's custom Gate script). This spec's version of the
  check scans exactly one concrete scan root
  (`plugins/sdd-quality-loop/scripts/`), so extending it to a second
  directory later (e.g. a future plugin that also ships Gate scripts) is a
  deliberate validator-config change, not an implicit wildcard match; a
  Pack-shipped-elsewhere script would need its own `implementation_ref`
  entry and would not be flagged as "unregistered" merely for living outside
  the one scanned root (this is now a structural exemption, not an untested
  asymmetry — API / Contract Plan) — worth revisiting once a real
  Capability Pack exists (decision v2 §17's rollout order).
- **Vendored-copy staleness (closed 2026-07-22 — orchestrator ruling
  P10).** The packaged, plugin-relative `contracts/*` copies (Components,
  Registry discovery contract) are only as fresh as the packaging step that
  last refreshed them; if that step were not run at every release, a
  standalone-installed plugin could read a stale Registry. This is now a
  designed CI/release-gate contract, not an unmitigated risk: the
  vendoring/packaging step's own `--check` mode (API / Contract Plan)
  compares each canonical `contracts/*` file's sha256 against its vendored
  counterpart and fails the release/version-bump if any mismatch is found —
  wired alongside `generate-gate-capabilities.py --check` in CI (Deployment/
  CI Plan). The residual risk is narrower: the exact wiring of this check
  into `scripts/bump-version.sh` is implementation-phase work, so a task
  that adds a version bump without also running this check would still slip
  through until that wiring lands.
