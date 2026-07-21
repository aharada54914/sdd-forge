# Design: epic-192-a4-facet-manifest

Impl-Review-Status: Pending
Feature Type: three new machine-readable JSON Schema contracts (Facet
Manifest, Capability Summary, Context Projection) plus three deterministic
schema-validation scripts (Python master + `sh`/`ps1` wrappers) added to
the existing `plugins/sdd-quality-loop/` plugin, and a per-Feature
storage-location convention. No Capability Resolver, no generator, and no
live artifact instance is built by this feature (Epic A5's scope).

## Technical Summary

Epic A4 fixes the *output type* the Capability Resolver (Epic A5) must
produce, before Epic A5 exists to produce it (`docs/ai-dlc-foundation-
decision-v2.md` §19). It introduces three new `contracts/*.schema.json`
files (Facet Manifest, Capability Summary, Context Projection) and three
new deterministic validator scripts under the existing `plugins/sdd-
quality-loop/` plugin — no new plugin, matching Epic A2's own rejected-
new-plugin precedent (`specs/epic-190-a2-capability-registry/design.md`
Design Decisions). It introduces no UI, no UX surface, no new runtime
service, and no generator: every deliverable is a static contract file plus
a Python-master/`sh`+`ps1`-wrapper script pair that *checks* conformance
against hand-authored fixtures, never one that *produces* a live instance.
This document is the **design for the implementation phase**; no file it
describes is created by this spec commit (requirements.md Non-goals,
AC-036/AC-037/AC-038 govern what this spec-phase commit itself must satisfy
instead).

## Architecture

```
                    (Epic A1)                    (Epic A2)          (Epic A3)
              project-context.yaml       capability-registry.json   ownership config
                       │                          │                      │
                       │ canonicalize-sdd-yaml     │ evaluate-predicate   │ resolve-component-paths
                       ▼                           ▼                      ▼
        ┌─────────────────────────┐   ┌──────────────────────┐  ┌─────────────────────┐
        │ Context Projection       │   │ Registry (in-memory)  │  │ ownership_digest      │
        │ project-context.resolved │   │ + registry_digest     │  │ + affected_components │
        │ .json  (REQ-003, A1      │   │ (A2, already shipped) │  │ (A3, already Pending) │
        │ reserved path)           │   └──────────┬───────────┘  └──────────┬───────────┘
        └────────────┬─────────────┘              │                         │
                     │                             │                         │
                     └──────────────┬──────────────┴─────────────┬──────────┘
                                     ▼                            ▼
                         (Epic A5, out of scope)      specs/<feature>/facet-manifest.yaml
                         Capability Resolver   ─────►  contracts/facet-manifest.schema.json
                          "resolve-project-              (REQ-001, THIS epic)
                           context" + a Facet-  ─────►  specs/<feature>/capability-summary.yaml
                           Manifest generator            contracts/capability-summary.schema.json
                           (name TBD, Epic A5)            (REQ-002, THIS epic)
                                     │
                                     ▼
                    validate-facet-manifest.{py,sh,ps1}   ◄── plugins/sdd-quality-loop/scripts/
                    validate-capability-summary.{py,sh,ps1}    (REQ-006, THIS epic — deterministic
                    validate-context-projection.{py,sh,ps1}     structural checkers, no generation)
                                     │
                                     ▼
                    Epic A3 `check-component-coverage --facet-manifest <path>`
                    (already-committed consumer, INV-006)
```

This feature owns the boxes labeled "THIS epic" only: three schema files,
three validator script triples, and the storage-location convention
(REQ-007). Every other box already exists (A2) or is already specified in
a sibling, currently-`Pending` package (A1, A3) or reserved as a protected
placeholder (A1's `resolve-project-context`/`project-context.resolved.
json`, INV-007) or is explicitly out of this feature's build scope (the
Resolver itself, Epic A5).

## Components

- `contracts/facet-manifest.schema.json` (new, REQ-001) — see API /
  Contract Plan for the full schema.
- `contracts/capability-summary.schema.json` (new, REQ-002).
- `contracts/context-projection.schema.json` (new, REQ-003).
- `plugins/sdd-quality-loop/scripts/validate-facet-manifest.{py,sh,ps1}`
  (new, REQ-006).
- `plugins/sdd-quality-loop/scripts/validate-capability-summary.{py,sh,
  ps1}` (new, REQ-006).
- `plugins/sdd-quality-loop/scripts/validate-context-projection.{py,sh,
  ps1}` (new, REQ-006).
- `plugins/sdd-quality-loop/contracts/{facet-manifest,capability-summary,
  context-projection}.schema.json` (new — vendored packaged copies, same
  script-relative discovery contract Epic A2's REQ-005 already fixed,
  INV-018).
- `tests/facet-manifest-schema.tests.{sh,ps1}`,
  `tests/capability-summary-schema.tests.{sh,ps1}`,
  `tests/context-projection-schema.tests.{sh,ps1}`,
  `tests/facet-manifest-staleness.tests.{sh,ps1}` (new, REQ-006), plus
  fixture data under `tests/fixtures/facet-manifest/`.
- `specs/<feature>/facet-manifest.yaml`,
  `specs/<feature>/capability-summary.yaml` (new storage-location
  convention, REQ-007 — no instance is committed by this feature itself;
  the convention applies to every *future* Feature once Epic A5 exists).

## Protected-File Statement

**This feature adds no new entry to `guard-invariants.json`'s
`protected_gate_suffixes` or `phase2_human_copy_targets`.**

Reasoning, matching the governing precedent this feature's own
investigation established (INV-013): ADR-0019 item 3 protects exactly six
categories — canonicalizer, hash generator, approval validator, policy-
weakening detector, resolver, generated projection. Epic A2's own
protected-file registration (REQ-005) protects only the artifacts inside
the "generated projection" category: the projection file itself
(`gate-capabilities.json`), its generator, and its *source* contract files
(`contracts/capability-registry.{json,schema.json}`) — because an
unprotected Registry source file would let an agent silently rewrite live
Gate policy. Epic A2's REQ-002/REQ-003/REQ-004 utility scripts
(`evaluate-predicate`, `validate-capability-registry`,
`generate-registry-digest`) carry **no** protected-file registration at
all, because they are general-purpose deterministic tools, not part of a
Gate's live-enforcement causal chain.

This feature's three new schemas and three new validator scripts fall on
the *unprotected* side of that same line, for the same reason:

- `validate-facet-manifest.{py,sh,ps1}`,
  `validate-capability-summary.{py,sh,ps1}`,
  `validate-context-projection.{py,sh,ps1}` are structural conformance
  checkers, directly analogous in role to `validate-capability-registry.py`
  — never invoked automatically inside a live Gate's enforcement path
  (Epic A3's `check-component-coverage` reads a Facet Manifest's *content*
  directly, never through this feature's validator, requirements.md Main
  Workflows).
- `contracts/facet-manifest.schema.json` and `contracts/capability-
  summary.schema.json` are structural *shape* contracts, not policy-
  carrying content the way `contracts/capability-registry.json` is (that
  file's own field *values* — `required_facets`, `gate_ids`,
  `minimum_enforcement` — directly encode Gate policy; a schema file
  constrains shape, not values, and corrupting it would produce a
  schema-invalid Manifest a validator rejects, not a silently-weakened one
  that passes).
- `specs/<feature>/facet-manifest.yaml` and `specs/<feature>/capability-
  summary.yaml` are per-Feature artifacts, protection-analogous to
  `tasks.md` (agent-writable per Feature, reviewed per Feature, never a
  singular repository-wide protected file).

The one artifact this feature's REQ-003 defines a schema for that *is*
already protection-scoped — `project-context.resolved.json` (Context
Projection) — was already reserved by Epic A1's own REQ-007
(`plugins/sdd-quality-loop/scripts/resolve-project-context.{py,sh,ps1}` +
the projection path, both already added to `guard-invariants.json`'s
`protected_gate_suffixes`, INV-007). This feature adds no new guard-
invariants entry for it and does not amend Epic A1's reservation; it only
fixes the schema the file at that already-protected path must conform to
once Epic A5 populates it.

## Layer Specifications

| Layer | Summary | Canonical Detail | Owner | Status |
|---|---|---|---|---|
| UX | N/A — no change: no UI, no UX surface (Technical Summary) | ux-spec.md | — | N/A |
| Frontend | N/A — no change: no browser/client UI, no new runtime service; three new stdlib-only Python scripts + wrappers recorded for completeness | frontend-spec.md | — | N/A |
| Infrastructure | No new runtime deployment; three new schema-conformance CI checks (validator `--check`-equivalent exit codes) wired the same way Epic A2's projection `--check` mode is wired | infra-spec.md | Implementation task owner | Planned |
| Security | No new trust boundary (Security Boundaries, requirements.md); provider-neutrality scan extended to three new schema files | security-spec.md | Implementation task owner | Planned |

Per this task's own scope instruction, `ux-spec.md`/`frontend-spec.md`/
`infra-spec.md`/`security-spec.md` are **not** authored as part of this
spec-phase commit — `check-workflow-state.sh` does not require them while
`Impl-Review-Status` is `Pending` (INV-015), and `check-sdd-structure.sh`
only requires them in `--feature` mode, which this feature's registration
verification does not use (INV-016). This table restates the same N/A/
Planned summary Epic A2's own spec-phase `design.md` already used for an
identical no-UI, no-new-runtime-service shape (`specs/epic-190-a2-
capability-registry/design.md` Layer Specifications).

## Design System Compliance

Not applicable — no UI surface.

## Cross-Layer Dependencies

- REQ-001's `conditional_facets[].evidence` → Epic A2's Evidence JSON
  Schema (structural reuse, not redefinition) — **blocked** until Epic
  A2's `contracts/capability-registry.schema.json` is confirmed unchanged
  at implementation time (Assumptions, requirements.md).
- REQ-003's canonicalization procedure → Epic A1's `canonicalize-sdd-yaml`
  — **blocked** until Epic A1's canonicalizer contract is finalized
  (Dependencies, requirements.md), matching Epic A2's own REQ-004
  dependency on the identical canonicalizer.
- REQ-001's `affected_components` shape → consumed by Epic A3's
  `check-component-coverage --facet-manifest <path>` (already committed,
  reverse dependency, INV-006) — this feature's schema must not diverge
  from Epic A3's already-stated assumption without a coordinated follow-up
  edit to both specs.
- REQ-003's Context Projection schema → populates Epic A1's already-
  reserved `project-context.resolved.json` path (INV-007) — this feature
  does not modify that reservation, only the schema of what eventually
  fills it.
- Every schema and script this feature defines → consumed by Epic A5's
  Capability Resolver (downstream, not a blocking dependency on this
  feature's own implementation, since this feature ships schemas plus
  fixture-validated scripts independent of Epic A5's existence).

## ADR Change Log

No new ADR is proposed by this spec. Every design decision below traces to
ADR-0016 (Workflow Axes Separation), ADR-0019 (Approval Sidecar
Protection, Policy Weakening category scope), ADR-0020 (Conditional
Predicate DSL), or ADR-0021 (Context Projection Staleness) — all four
already `Status: Accepted` (Non-goals, requirements.md).

## Data Plan

New data:
- `contracts/facet-manifest.schema.json`, `contracts/capability-summary.
  schema.json`, `contracts/context-projection.schema.json` — canonical
  JSON Schema draft-07 documents (API / Contract Plan, below).
- `plugins/sdd-quality-loop/contracts/{facet-manifest,capability-summary,
  context-projection}.schema.json` — vendored packaged copies, refreshed
  by the same vendoring step Epic A2's REQ-005 already established
  (Deployment / CI Plan).
- `tests/fixtures/facet-manifest/` — hand-authored fixture instances (not
  Resolver output, since no Resolver exists yet) covering every schema
  field and every REQ-006 semantic check, plus fixture pairs for REQ-004's
  semantic-output comparison and REQ-005's version-bump tiers.

Existing Data Affected: none. This feature adds no field to, and performs
no write against, `contracts/capability-registry.json`,
`contracts/project-context.schema.json`,
`contracts/workflow-state-registry.json`, or any other Epic A1/A2/A3
artifact — it only reads their already-fixed shapes (Dependencies,
requirements.md).

Migration Strategy: none. Every artifact this epic defines is wholly new;
no existing schema, script, or content file is migrated in place.

## API / Contract Plan

### `contracts/facet-manifest.schema.json` (REQ-001)

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://github.com/aharada54914/sdd-forge/contracts/facet-manifest.schema.json",
  "title": "SDD Forge Facet Manifest",
  "type": "object",
  "additionalProperties": false,
  "required": [
    "schema", "feature", "affected_components", "required_facets",
    "conditional_facets", "resolved_gates", "capabilities",
    "lite_eligibility", "context_binding", "resolver"
  ],
  "properties": {
    "schema": { "const": "sdd-facet-manifest/v1" },
    "feature": { "type": "string", "pattern": "^[a-z0-9][a-z0-9-]*$" },
    "affected_components": {
      "type": "array", "items": { "type": "string", "minLength": 1 },
      "uniqueItems": true
    },
    "required_facets": {
      "type": "array", "items": { "type": "string", "minLength": 1 },
      "uniqueItems": true
    },
    "conditional_facets": {
      "type": "array",
      "items": { "$ref": "#/definitions/conditionalFacet" }
    },
    "resolved_gates": {
      "type": "array",
      "items": { "$ref": "#/definitions/resolvedGate" }
    },
    "capabilities": {
      "type": "array", "items": { "type": "string", "minLength": 1 },
      "uniqueItems": true
    },
    "capability_minimum_enforcement": { "const": "required" },
    "lite_eligibility": { "$ref": "#/definitions/liteEligibility" },
    "context_binding": { "$ref": "#/definitions/contextBinding" },
    "resolver": { "$ref": "#/definitions/resolverBlock" }
  },
  "definitions": {
    "conditionalFacet": {
      "type": "object",
      "additionalProperties": false,
      "required": ["facet", "applied", "evidence"],
      "properties": {
        "facet": { "type": "string", "minLength": 1 },
        "applied": { "type": "boolean" },
        "reason": { "type": "string", "minLength": 1 },
        "evidence": { "$ref": "#/definitions/evidenceNode" }
      },
      "if": { "properties": { "applied": { "const": false } } },
      "then": { "required": ["facet", "applied", "reason", "evidence"] },
      "else": { "not": { "required": ["reason"] } }
    },
    "evidenceNode": {
      "type": "object",
      "additionalProperties": false,
      "required": ["operator", "path", "outcome"],
      "properties": {
        "operator": {
          "enum": ["all", "any", "not", "equals", "not_equals",
                   "contains", "in", "exists"]
        },
        "path": { "type": ["string", "null"] },
        "outcome": { "enum": ["match", "no-match", "warn"] },
        "reason": { "type": "string" },
        "children": {
          "type": "array",
          "items": { "$ref": "#/definitions/evidenceNode" }
        }
      },
      "if": { "properties": { "outcome": { "const": "warn" } } },
      "then": { "required": ["operator", "path", "outcome", "reason"] }
    },
    "resolvedGate": {
      "type": "object",
      "additionalProperties": false,
      "required": ["id", "stage", "blocking"],
      "properties": {
        "id": { "type": "string", "pattern": "^[a-z0-9][a-z0-9-]*$" },
        "stage": { "enum": ["implementation", "artifact", "promotion"] },
        "blocking": { "type": "boolean" }
      }
    },
    "liteEligibility": {
      "type": "object",
      "additionalProperties": false,
      "required": ["eligible"],
      "properties": {
        "eligible": { "type": "boolean" },
        "upgrade_reasons": {
          "type": "array", "items": { "type": "string", "minLength": 1 },
          "default": []
        }
      }
    },
    "contextBinding": {
      "type": "object",
      "additionalProperties": false,
      "required": [
        "full_context_revision", "dependency_pointers", "projection_sha256",
        "registry_digest", "ownership_digest"
      ],
      "properties": {
        "full_context_revision": { "$ref": "#/definitions/sha256Digest" },
        "dependency_pointers": {
          "type": "array", "minItems": 1,
          "items": {
            "type": "string",
            "pattern": "^(/([^/~]|~0|~1)*)+$"
          }
        },
        "projection_sha256": { "$ref": "#/definitions/sha256Digest" },
        "registry_digest": { "$ref": "#/definitions/sha256Digest" },
        "ownership_digest": { "$ref": "#/definitions/sha256Digest" }
      }
    },
    "resolverBlock": {
      "type": "object",
      "additionalProperties": false,
      "required": ["version", "rule_set_revision"],
      "properties": {
        "version": { "type": "string", "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$" },
        "rule_set_revision": { "$ref": "#/definitions/sha256Digest" }
      }
    },
    "sha256Digest": {
      "type": "string", "pattern": "^sha256:[0-9a-f]{64}$"
    }
  }
}
```

`#/definitions/evidenceNode` is a structural transcription of Epic A2's own
Evidence JSON Schema (`specs/epic-190-a2-capability-registry/design.md`,
"Predicate DSL evaluator contract" — INV-004), not a redefinition: the
`operator` enum, the `outcome` enum, and the `warn`-requires-`reason`
`if`/`then` are copied verbatim. If Epic A2's Evidence JSON Schema changes
before Epic A5 implements against it, this definition needs a
corresponding follow-up edit (Assumptions, requirements.md) — this spec
does not attempt a live `$ref` across `contracts/` files, since JSON
Schema draft-07 `$ref` resolution across separately-versioned files is
itself a coordination risk this feature avoids by duplicating the (small,
already-stable) Evidence shape instead.

**`dependency_pointers[].pattern`** (`^(/([^/~]|~0|~1)*)+$`) is the
standard RFC 6901 JSON Pointer syntax pattern (zero or more `/`-prefixed
tokens, each token any character except unescaped `/`/`~`, with `~0`/`~1`
escaping `~`/`/`) — it validates *syntax* only; the root-segment
allowlist (`workflow`/`components`/`shared_paths`, AC-017) is a semantic
check REQ-006's validator performs, not expressible as a single regex
without also hard-coding every possible sub-path shape.

### `contracts/capability-summary.schema.json` (REQ-002)

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://github.com/aharada54914/sdd-forge/contracts/capability-summary.schema.json",
  "title": "SDD Forge Capability Summary",
  "type": "object",
  "additionalProperties": false,
  "required": ["schema", "feature", "track", "capabilities"],
  "properties": {
    "schema": { "const": "sdd-capability-summary/v1" },
    "feature": { "type": "string", "pattern": "^[a-z0-9][a-z0-9-]*$" },
    "track": { "enum": ["lite", "full"] },
    "capabilities": {
      "type": "array", "items": { "type": "string", "minLength": 1 },
      "uniqueItems": true
    },
    "required_lite_checks": {
      "type": "array", "items": { "type": "string", "minLength": 1 },
      "uniqueItems": true
    },
    "full_upgrade_required": { "type": "boolean" },
    "facet_manifest_ref": {
      "type": "object",
      "additionalProperties": false,
      "required": ["path", "sha256"],
      "properties": {
        "path": { "type": "string", "minLength": 1 },
        "sha256": { "type": "string", "pattern": "^sha256:[0-9a-f]{64}$" }
      }
    }
  },
  "if": { "properties": { "track": { "const": "lite" } } },
  "then": {
    "required": [
      "schema", "feature", "track", "capabilities",
      "required_lite_checks", "full_upgrade_required"
    ],
    "properties": {
      "facet_manifest_ref": false
    }
  },
  "else": {
    "required": ["schema", "feature", "track", "capabilities", "facet_manifest_ref"],
    "properties": {
      "required_lite_checks": false,
      "full_upgrade_required": false
    }
  }
}
```

(`"properties": {"facet_manifest_ref": false}` under the lite branch, and
the mirrored lite-only-field exclusions under the full branch, are the
standard JSON Schema draft-07 idiom for "this property must not be
present" — a boolean `false` subschema which no value, including absence
in a sibling-conditioned branch's own `additionalProperties: false`
enforcement at the top level, can satisfy, so those fields are only ever
schema-valid under their own track's branch.)

### `contracts/context-projection.schema.json` (REQ-003)

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://github.com/aharada54914/sdd-forge/contracts/context-projection.schema.json",
  "title": "SDD Forge Context Projection",
  "type": "object",
  "additionalProperties": false,
  "required": ["schema", "source_sha256", "workflow", "components", "shared_paths"],
  "properties": {
    "schema": { "const": "sdd-context-projection/v1" },
    "source_sha256": { "type": "string", "pattern": "^sha256:[0-9a-f]{64}$" },
    "provider_bindings_sha256": { "type": "string", "pattern": "^sha256:[0-9a-f]{64}$" },
    "workflow": {
      "type": "object",
      "additionalProperties": false,
      "required": ["spec_profile", "artifact_layout", "capability_enforcement"],
      "properties": {
        "spec_profile": { "enum": ["full", "lite"] },
        "artifact_layout": {
          "enum": ["lite-three-file", "legacy-seven-layer", "facet-hybrid", "facet-native"]
        },
        "capability_enforcement": { "enum": ["advisory", "required"] }
      }
    },
    "components": {
      "type": "object",
      "additionalProperties": false,
      "patternProperties": {
        "^[a-z0-9][a-z0-9-]*$": { "$ref": "#/definitions/projectedComponent" }
      }
    },
    "shared_paths": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["pattern"],
        "oneOf": [
          { "required": ["components"], "properties": { "components": { "type": "array", "items": { "type": "string" } } } },
          { "required": ["classification"], "properties": { "classification": { "const": "cross-cutting" } } }
        ]
      }
    }
  },
  "definitions": {
    "projectedComponent": {
      "type": "object",
      "additionalProperties": false,
      "properties": {
        "artifact_kinds": { "type": "array", "items": { "type": "string" } },
        "runtime_classes": { "type": "array", "items": { "type": "string" } },
        "platform_targets": {
          "type": "array",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": ["os", "architecture"],
            "properties": { "os": { "type": "string" }, "architecture": { "type": "string" } }
          }
        },
        "characteristics": {
          "type": "object",
          "additionalProperties": false,
          "properties": {
            "pii": { "type": "boolean" },
            "ui": { "type": "boolean" },
            "auto_update": { "type": "boolean" },
            "local_persistence": { "type": "boolean" },
            "long_running": { "type": "boolean" },
            "replayable": { "type": "boolean" },
            "human_in_the_loop": { "type": "boolean" }
          }
        },
        "distribution_channels": { "type": "array", "items": { "type": "string" } },
        "data_classification": { "type": "array", "items": { "type": "string" } },
        "provider_binding_ids": { "type": "array", "items": { "type": "string" } },
        "paths": {
          "type": "object",
          "additionalProperties": false,
          "properties": {
            "include": { "type": "array", "items": { "type": "string" } },
            "exclude": { "type": "array", "items": { "type": "string" } }
          }
        }
      }
    }
  }
}
```

`#/definitions/projectedComponent` is Epic A1's own `components[]` item
shape (`contracts/project-context.schema.json`, INV-009) with `id` removed
— it is now the `components` object's own key, per REQ-003's re-keying
step, and every other field is unchanged. `components`'s `patternProperties`
key pattern (`^[a-z0-9][a-z0-9-]*$`) is identical to Epic A1's own
`components[].id` pattern, so any component `id` that validates against
Epic A1's schema also validates as a `context-projection.schema.json` key.

**Generation procedure** (normative for Epic A5's future implementation,
not built by this feature):

1. Read `project-context.yaml`; canonicalize via `canonicalize-sdd-yaml`
   (YAML input mode) to obtain its NFC-normalized, parsed structure and its
   own canonical-form sha256 (`source_sha256`, equal to `context_binding.
   full_context_revision`). If `provider-bindings.yaml` exists, canonicalize
   it the same way and record `provider_bindings_sha256`.
2. Re-key the parsed structure's `components` array into an object keyed
   by each entry's own `id` field, with `id` itself omitted from each
   value (sound only because Epic A1's own content-schema validator
   already guarantees `id` uniqueness upstream, INV-009 — this step
   performs no uniqueness check of its own and must not silently overwrite
   a collision).
3. Assemble `{schema: "sdd-context-projection/v1", source_sha256,
   provider_bindings_sha256?, workflow: <as-is>, components: <re-keyed>,
   shared_paths: <as-is>}`.
4. Feed this assembled JSON object back through `canonicalize-sdd-yaml` a
   **second time**, JSON input mode — the exact two-pass pattern Epic A1's
   own HMAC preimage construction already establishes as precedent
   (`specs/epic-189-a1-project-context/design.md`, "HMAC preimage and
   signing" section, INV-008) — to obtain final RFC 8785 (JCS) canonical
   bytes.
5. Write those bytes to `plugins/sdd-quality-loop/scripts/generated/
   project-context.resolved.json` (Epic A1's already-reserved path,
   INV-007). `projection_sha256` (in every Facet Manifest bound to this
   projection) is the sha256 of exactly these bytes.

### `validate-facet-manifest` contract (REQ-006)

`validate-facet-manifest.py --manifest <path>` → exit 0 (schema-conformant
and every semantic check passes) or non-zero with one diagnostic line per
failed check, in the style of `validate-capability-registry.py`'s
`registry: <check-id>: <detail>` lines (INV-005):
`facet-manifest: <check-id>: <detail>`.

| Check | Diagnostic ID | Scope |
|---|---|---|
| Schema conformance | `schema-invalid` | whole document, against `contracts/facet-manifest.schema.json` |
| Resolved-gate ID uniqueness | `resolved-gate-id-duplicate` | `resolved_gates[]` |
| Facet classification conflict | `facet-classification-conflict` | a facet name present in both `required_facets` and `conditional_facets[].facet` |
| Dependency-pointer root allowlist | `dependency-pointer-root-not-allowlisted` | `context_binding.dependency_pointers[]`, first RFC 6901 segment must be `workflow`, `components`, or `shared_paths` |
| Stable-sort discipline | `array-not-stable-sorted` | `affected_components`, `required_facets`, `capabilities` each lexicographically sorted; `conditional_facets`/`resolved_gates` each sorted by `facet`/`id` respectively |

The schema-conformance check is a hand-rolled, stdlib-only Python
structural validator (no third-party `jsonschema` dependency, INV-014) —
it implements the subset of JSON Schema draft-07 this feature's three
schemas actually use (`type`, `required`, `additionalProperties`,
`properties`, `patternProperties`, `pattern`, `enum`, `const`, `uniqueItems`,
`minItems`, `minLength`, `if`/`then`/`else`, `$ref`/`definitions`), matching
`validate-capability-registry.py`'s own hand-rolled-validator convention,
not a general-purpose JSON Schema engine.

### `validate-capability-summary` contract (REQ-006)

`validate-capability-summary.py --summary <path>` → exit 0 or non-zero
with `capability-summary: <check-id>: <detail>` lines. Checks: schema
conformance (`schema-invalid`, including the `track`-conditioned `if`/
`then`/`else` branch); `facet_manifest_ref.path` (when `track == "full"`)
resolves to an existing, readable file relative to the repository root
(`facet-manifest-ref-unreadable`) — a semantic check the schema's own
`type: string` cannot express.

### `validate-context-projection` contract (REQ-003/REQ-006)

`validate-context-projection.py --projection <path>` → exit 0 or non-zero
with `context-projection: <check-id>: <detail>` lines. Checks: schema
conformance (`schema-invalid`, including the `components` re-keying shape
— a fixture where `components` is still array-typed fails `type: object`
at the schema level, AC-030); every `components` key matches the same
`^[a-z0-9][a-z0-9-]*$` pattern as Epic A1's `id` field
(`component-key-pattern-invalid` — expressible via `patternProperties`
already, so this is schema-level, listed here for completeness of the
diagnostic-id table, not an extra hand-rolled check).

### Discovery contract (REQ-006, all three scripts)

Identical to Epic A2's own REQ-005 discovery contract
(`specs/epic-190-a2-capability-registry/design.md`, "Registry discovery
contract", INV-018), reused rather than re-derived: (1) resolve the
invoking script's own symlink-resolved real path, look for a packaged copy
at the script-relative offset `../contracts/<filename>`; (2) else resolve
via `git rev-parse --show-toplevel` (or a `.git`-directory walk) and use
`<git-root>/contracts/<filename>`; (3) fail closed with a diagnostic naming
both attempted paths if neither resolves. Version check, per artifact:
`facet-manifest.schema.json`/`capability-summary.schema.json`/`context-
projection.schema.json` each require a present `$schema` keyword and a
matching `$id`. A release-gating `--check` mode on the vendoring step
(Deployment / CI Plan) compares each canonical `contracts/<filename>`'s
sha256 against its vendored `plugins/sdd-quality-loop/contracts/
<filename>` counterpart, mirroring Epic A2's own vendored-copy drift check
exactly.

## Test Strategy

Four new `tests/*.tests.sh`/`.tests.ps1` pairs, fixture data under
`tests/fixtures/facet-manifest/`:

1. `facet-manifest-schema` — one fixture per REQ-001 required field
   (parameterized negative test, matching Epic A1's own "Field Requirement
   Matrix" pattern, deleting exactly one field per fixture, INV-009);
   AC-003 (uniqueItems, empty-array positive), AC-004/AC-005 (`applied`/
   `reason`/`evidence` `if`/`then`, Evidence-shape conformance and
   rejection of an out-of-enum operator), AC-006 (`resolved_gates[]`
   shape and `stage` enum), AC-007 (`capability_minimum_enforcement`
   const-or-absent), AC-008 (`lite_eligibility` required/default), AC-009/
   AC-010 (`context_binding`/`resolver` digest/semver pattern conformance
   and rejection), AC-011 (decision document v2 §16's own worked example
   validates once embedded).
2. `facet-manifest-semantics` — one fixture per REQ-006 diagnostic-id
   table row for `validate-facet-manifest`: `resolved-gate-id-duplicate`,
   `facet-classification-conflict`, `dependency-pointer-root-not-
   allowlisted` (AC-017), `array-not-stable-sorted`, plus one fully-clean
   fixture proving a negative (all checks pass on valid input, matching
   Epic A2's own "cannot pass vacuously" discipline).
3. `capability-summary-schema` — AC-012 (`if`/`then`/`else` branch
   validity and cross-branch field rejection), AC-013 (decision document
   v2 §6's own lite example, extended with `schema`/`track`), AC-014
   (`facet_manifest_ref` shape, lite-field rejection under `track: full`).
4. `context-projection-schema` — AC-015 (re-keying proof: two-component
   fixture produces exactly two id-keyed entries, no `id` sub-field),
   AC-016 (end-to-end RFC 6901 resolution of decision document v2 §16's
   own `/components/desktop-client/artifact_kinds` example against a
   fixture Context Projection), AC-018 (malformed-pointer schema
   rejection).
5. `facet-manifest-staleness` — REQ-004's semantic-output comparison
   contract: AC-019 (digest-only change, not stale), AC-020 (same-gate-ID
   stage/blocking change, stale), AC-021 (`evidence`-only change, not
   stale — the explicit gap-closing fixture), AC-022 (minimum-enforcement
   tightening, stale), AC-023 (Policy Weakening short-circuit, comparison
   never evaluated), AC-024 (Registry-digest change with no weakening
   verdict, ordinary path only, INV-012's scope-narrowing proof); REQ-005's
   three version-bump tiers: AC-025 (patch, unchanged, no regeneration),
   AC-026 (minor, both changed and unchanged sub-cases), AC-027 (major,
   forced regardless of semantic output).
6. Parity — all three scripts' `.py`/`.sh`/`.ps1` invocations against every
   fixture above produce byte-identical exit codes and diagnostic output
   (AC-031); three installed-plugin-context discovery fixtures per script
   (AC-032, matching Epic A2's own three-fixture, per-runtime discovery
   proof, INV-018).

Every new suite is registered directly in `tests/run-all.sh`/`.ps1`
(unprotected, INV-018) and staged for `.github/workflows/test.yml`
registration via human-copy (protected, matching Epic A2's own precedent
for CI-registration edits specifically — AC-033).

## Design Decisions (resolving open questions)

- **`evidence` excluded from semantic-output comparison (requirements.md
  Field Definitions, AC-021).** ADR-0021 item 2 defines semantic output as
  "the resolved required/conditional facets, their N/A reasons" and
  explicitly separates `context_binding`/`resolver` as "binding/provenance
  metadata, not output," but never explicitly addresses whether a
  conditional facet's `evidence` sub-tree (the predicate-evaluation trace
  that *produced* `applied`/`reason`) is itself output or provenance. This
  spec resolves the gap by analogy: `evidence` describes *how* a result was
  derived, exactly the same relationship `resolver.rule_set_revision` has
  to the Manifest it describes — a change to evaluator internals that
  leaves `applied`/`reason` unchanged (e.g. a WARN-reason wording tweak in
  a future evaluator patch release) should not, by itself, mark every
  Feature using that facet Stale. The alternative (including `evidence`)
  would make the evaluator's own implementation details part of every
  Feature's staleness surface, which ADR-0020 item 6's Resolver-purity
  guarantee already makes unnecessary for detecting a *real* outcome
  change (a real `applied`/`reason` change always also changes `evidence`,
  since `evidence` is a strict function of the same predicate evaluation —
  but the converse does not hold, and it is the converse this decision
  closes).
- **`na_facets` folded into `conditional_facets[].reason`, not a separate
  array (requirements.md Field Definitions).** A separate `na_facets[]`
  array would duplicate `conditional_facets[].applied == false`
  information in a second location that could drift out of sync (e.g. a
  Resolver bug writing `applied: true` in one array and an `na_facets`
  entry for the same facet in the other) — the single-source-of-truth
  design eliminates that entire failure class by construction, at the cost
  of a marginally less "search for N/A facets" ergonomic shape (mitigated
  by REQ-006's validator being the intended tool for that query, not
  manual array-scanning).
- **`capability_minimum_enforcement`, not `effective_minimum_enforcement`
  (requirements.md Field Definitions).** Naming this field "effective"
  would misleadingly imply it is decision document v2 §10's full
  `max(approved project policy, capability minimum, runtime override)` —
  it is only the middle term. A runtime override is, by construction
  (v2 §10, "override の経路を明示: CLIフラグまたは環境変数"), something
  that can vary per Gate invocation independent of any Facet Manifest
  snapshot; binding it into the Manifest would make the Manifest's own
  purity guarantee (ADR-0020 item 6, "same input always produces the same
  Facet Manifest") meaningless, since a CLI flag is not a Resolver input in
  the sense that term is used elsewhere in this schema.
- **Facet Manifest and Capability Summary are `.yaml`, not `.json`
  (requirements.md REQ-007).** Decision document v2 §6 already fixes
  `capability-summary.yaml`'s extension for the lite track; this feature
  extends that choice consistently to the full track and to the new
  `facet-manifest.yaml` sibling rather than introducing a format split
  between the two co-located, jointly-generated artifacts. The same
  reasoning Epic A1 gives for `project-context.yaml`/`provider-bindings.
  yaml` being YAML despite being schema-validated machine artifacts
  applies here: git-diff readability for a human reviewing a PR. RFC 8785/
  YAML-1.2-core canonicalization (REQ-003, REQ-004's stable-sort
  discipline) applies uniformly regardless of source serialization format,
  so choosing YAML carries no cross-runtime-hashing cost — the canonical
  byte sequence a digest is computed over is never the raw YAML/JSON
  source bytes, always the canonicalizer's JCS output.
- **Full-track Capability Summary references its Facet Manifest by digest,
  never duplicates facet-level content (requirements.md REQ-002, OQ-001).**
  Decision document v2 §19 lists Capability Summary as a fourth, distinct
  Epic A5 output even in the full track, without specifying its content.
  This spec's resolution treats it as a compact, capability-set-only
  companion — `capabilities[]` plus a `facet_manifest_ref` pointer — rather
  than re-deriving lite-only fields (`required_lite_checks`,
  `full_upgrade_required`) that have no meaning once a project is already
  on the full track, or duplicating `required_facets`/`conditional_facets`/
  `resolved_gates`, which would create the same two-sources-of-truth risk
  the `na_facets` decision above avoids.
- **Rejected alternative: a single, un-discriminated Capability Summary
  schema with every field optional.** Considered and rejected because an
  all-optional schema cannot express "exactly these fields for track X, and
  these fields must be absent," which is exactly the invariant
  `facet_manifest_ref` vs. `required_lite_checks`/`full_upgrade_required`
  needs — an accidentally-lite-shaped `track: full` instance (or vice
  versa) would otherwise validate successfully and mislead a downstream
  reader.
- **Major-version-bump precedence over an unrelated digest change
  (requirements.md Edge Cases).** ADR-0021 item 6 places no condition on
  the major tier beyond "every Feature that used the affected Resolver
  version" — this spec states explicitly that a major bump forces
  re-resolve independent of, and regardless of the outcome of, any
  concurrent digest-driven semantic-output comparison, since ADR-0021's own
  text draws no distinction between "major bump alone" and "major bump
  plus something else changed."

## Global Constraints

- Python scripts are stdlib-only — no `jsonschema` or other third-party
  dependency (INV-014, matching every existing `plugins/sdd-quality-loop/
  scripts/*.py`).
- No `.js` wrapper for any of the three new validator scripts — matching
  Epic A2's own precedent that only a hash-generation primitive
  (`generate-registry-digest`) needed cross-runtime `.js` parity for
  determinism verification, not a structural validator
  (`validate-capability-registry` shipped `.py`+`.sh`+`.ps1` only).
- Every array field this feature defines that participates in REQ-004's
  semantic-output comparison must be written stable-sorted before
  serialization (requirements.md Goals, REQ-001) — this is a Resolver
  (Epic A5) implementation obligation this schema's own `array-not-stable-
  sorted` validator check (REQ-006) enforces, not a schema-level
  `additionalProperties`-style structural constraint (JSON Schema
  draft-07 cannot express array-order constraints).
- Resolver purity (ADR-0020 item 6) forbids any timestamp or other
  non-reproducible field anywhere in a Facet Manifest, Capability Summary,
  or Context Projection instance — none of the three schemas above
  includes a `generated_at`-style field, by deliberate omission, not
  oversight.

## Security Boundaries

See requirements.md Security Boundaries — this design introduces no new
trust boundary, no network access, no dynamic code execution, and no
credential handling in any of the three validator scripts.

## External Integrations

None. This feature has no dependency on any provider API, cloud service,
or external network resource — consistent with ADR-0018's provider-
neutrality boundary and this repository's "no external credential" ethos.

## Deployment / CI Plan

- CI (future, implementation phase): each validator script's schema-
  conformance check is wired the same way Epic A2's
  `generate-gate-capabilities.py --check` is wired — a fixture-driven
  `tests/run-all.sh`/`.ps1` registration, not a standalone CI job of its
  own, since these are validators over committed fixtures, not projections
  with a drift-detection mode.
- The vendoring step that refreshes `plugins/sdd-quality-loop/contracts/
  {facet-manifest,capability-summary,context-projection}.schema.json` from
  their canonical `contracts/` originals reuses Epic A2's already-CI-wired
  vendored-copy `--check` mode (Deployment / CI Plan,
  `specs/epic-190-a2-capability-registry/design.md`) — extended to cover
  three more filenames, not a new mechanism.
- `scripts/bump-version.sh`'s existing release gate is unaffected; this
  feature adds no citation-residue or version-mutation surface of its own
  (REQ-008).

## Constraint Compliance

- 3-runtime parity (decision document v2 §7): all three validator scripts
  ship `.py`+`.sh`+`.ps1`, invoked from a Claude Code, Codex CLI, and
  Copilot CLI installed-plugin context in AC-031/AC-032's future test
  fixtures — matching every sibling epic's own 3-environment discipline.
  This feature adds no new UI or interviewer-facing surface, so Epic A0's
  "各Epicの3環境タスク" obligation (decision v2 §7) is fully discharged by
  script-level parity alone, with no separate skill/interviewer-integration
  task required.
- No new plugin (Design Decisions, Epic A2 precedent, INV-013): every new
  script lives under the existing `plugins/sdd-quality-loop/` plugin.

## Assumptions

See requirements.md Assumptions — this design is written against Epic A1's
canonicalizer, Epic A2's Registry schema and Evidence shape, and Epic A3's
`affected_components` read contract exactly as those sibling specs
currently state them, not against a placeholder.

## Open Questions

See requirements.md Open Questions (OQ-001, OQ-002) — neither blocks this
feature's own schema/validator design, both are scoped to a future epic's
implementation-time decision.

## Risks

See requirements.md Risks (schema-drift risk, ambiguity-resolution risk,
reserved-path risk) — each traces to a specific Design Decision above,
where the reasoning behind this feature's own resolution is recorded for a
future adversarial review to evaluate against a stated rationale.
