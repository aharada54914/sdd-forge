# Design: epic-192-a4-facet-manifest

Impl-Review-Status: Pending
Feature Type: three new machine-readable JSON Schema contracts (Facet
Manifest, Capability Summary — Lite track only — Context Projection) plus
four deterministic scripts (three schema validators and one staleness
comparator; Python master + `sh`/`ps1` wrappers) added to the existing
`plugins/sdd-quality-loop/` plugin, and a per-Feature storage-location
convention. No Capability Resolver, no generator, and no live artifact
instance is built by this feature (Epic A5's scope).

## Technical Summary

Epic A4 fixes the *output type* the Capability Resolver (Epic A5) must
produce, before Epic A5 exists to produce it (`docs/ai-dlc-foundation-
decision-v2.md` §19). It introduces three new `contracts/*.schema.json`
files (Facet Manifest, Capability Summary — Lite track only, Non-goals —
Context Projection) and four new deterministic scripts under the existing
`plugins/sdd-quality-loop/` plugin — no new plugin, matching Epic A2's own
rejected-new-plugin precedent (`specs/epic-190-a2-capability-registry/
design.md` Design Decisions): three schema-conformance validators
(`validate-facet-manifest`, `validate-capability-summary`, `validate-
context-projection`) and one staleness comparator (`compare-facet-manifest-
staleness`, implementing REQ-004's contract, adversarial review "B7"). It
introduces no UI, no UX surface, no new runtime service, and no generator:
every deliverable is a static contract file plus a Python-master/`sh`+
`ps1`-wrapper script pair that *checks* conformance or *compares* two
already-produced instances against hand-authored fixtures, never one that
*produces* a live instance. This document is the **design for the
implementation phase**; no file it describes is created by this spec
commit (requirements.md Non-goals, AC-036/AC-037/AC-038 govern what this
spec-phase commit itself must satisfy instead).

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
                    compare-facet-manifest-staleness.{py,sh,ps1}
                    (REQ-004/REQ-006, THIS epic — old vs. new
                     Manifest + 3-axis weakening verdict + resolver-
                     version-bump tier → fresh|stale|blocked)
                                     │
                                     ▼
                    Epic A3 `check-component-coverage --facet-manifest <path>`
                    (already-committed consumer, INV-006)
```

This feature owns the boxes labeled "THIS epic" only: three schema files,
four scripts (three validators, one comparator), and the storage-location
convention (REQ-007). Every other box already exists (A2) or is already
specified in a sibling, currently-`Pending` package (A1, A3) or reserved as
a protected placeholder (A1's `resolve-project-context`/`project-context.
resolved.json`, INV-007) or is explicitly out of this feature's build
scope (the Resolver itself, Epic A5, and any Registry- or ownership-scoped
Policy-Weakening detector — Non-goals — whose verdict this feature's
comparator only *consumes*, fail-closed in its absence).

## Components

- `contracts/facet-manifest.schema.json` (new, REQ-001) — see API /
  Contract Plan for the full schema.
- `contracts/capability-summary.schema.json` (new, REQ-002, Lite track
  only).
- `contracts/context-projection.schema.json` (new, REQ-003).
- `plugins/sdd-quality-loop/scripts/validate-facet-manifest.{py,sh,ps1}`
  (new, REQ-006).
- `plugins/sdd-quality-loop/scripts/validate-capability-summary.{py,sh,
  ps1}` (new, REQ-006).
- `plugins/sdd-quality-loop/scripts/validate-context-projection.{py,sh,
  ps1}` (new, REQ-006).
- `plugins/sdd-quality-loop/scripts/compare-facet-manifest-staleness.{py,
  sh,ps1}` (new, REQ-004/REQ-006 — the staleness-comparator CLI,
  adversarial review "B7").
- `plugins/sdd-quality-loop/contracts/{facet-manifest,capability-summary,
  context-projection}.schema.json` (new — vendored packaged copies, same
  script-relative discovery contract Epic A2's REQ-005 already fixed,
  INV-018).
- `tests/facet-manifest-schema.tests.{sh,ps1}`,
  `tests/facet-manifest-semantics.tests.{sh,ps1}`,
  `tests/capability-summary-schema.tests.{sh,ps1}`,
  `tests/context-projection-schema.tests.{sh,ps1}`,
  `tests/facet-manifest-staleness.tests.{sh,ps1}`,
  `tests/facet-manifest-parity.tests.{sh,ps1}` (new, REQ-006 — **six**
  suite pairs; an earlier revision of this Components list omitted
  `facet-manifest-semantics` and `facet-manifest-parity` despite both
  being used elsewhere in this document, adversarial review "M
  suite/1:1"), plus fixture data under `tests/fixtures/facet-manifest/`.
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

This feature's three new schemas and four new scripts fall on the
*unprotected* side of that same line, for the same reason:

- `validate-facet-manifest.{py,sh,ps1}`,
  `validate-capability-summary.{py,sh,ps1}`,
  `validate-context-projection.{py,sh,ps1}`, and
  `compare-facet-manifest-staleness.{py,sh,ps1}` are structural conformance
  checkers / comparators, directly analogous in role to `validate-
  capability-registry.py` — never invoked automatically inside a live
  Gate's enforcement path (Epic A3's `check-component-coverage` reads a
  Facet Manifest's *content* directly, never through this feature's
  validator, requirements.md Main Workflows). `compare-facet-manifest-
  staleness`'s own Block outcome (REQ-004's Policy-Weakening short-circuit,
  including its fail-closed branch) is a decision surfaced to whichever
  future Gate or CI process invokes it — this feature does not itself wire
  that outcome into any live enforcement path, since no such caller exists
  yet (Epic A5, Non-goals).
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
| Frontend | N/A — no change: no browser/client UI, no new runtime service; four new stdlib-only Python scripts + wrappers recorded for completeness | frontend-spec.md | — | N/A |
| Infrastructure | No new runtime deployment; four new CI checks (three validators' schema-conformance exit codes, one comparator's fresh/stale/blocked exit codes) wired the same way Epic A2's projection `--check` mode is wired | infra-spec.md | Implementation task owner | Planned |
| Security | No new trust boundary (Security Boundaries, requirements.md); provider-neutrality scan (AC-043) extended to three new schema files and four new scripts | security-spec.md | Implementation task owner | Planned |

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

- REQ-001's `conditional_facets[].evidence` (an array, INV-004/"M Evidence
  array") → Epic A2's `evaluate-predicate` Evidence JSON Schema (structural
  reuse, not redefinition) — **blocked** until Epic A2's `contracts/
  capability-registry.schema.json` is confirmed unchanged at
  implementation time (Assumptions, requirements.md).
- REQ-003's canonicalization procedure, and REQ-006's two YAML-reading
  validators' own subprocess-invocation parse path (`validate-facet-
  manifest`, `validate-capability-summary`; B4) → Epic A1's
  `canonicalize-sdd-yaml` — **blocked** until Epic A1's canonicalizer
  contract is finalized (Dependencies, requirements.md), matching Epic
  A2's own REQ-004 dependency on the identical canonicalizer.
- REQ-001's `affected_components` shape → consumed by Epic A3's
  `check-component-coverage --facet-manifest <path>` (already committed,
  reverse dependency, INV-006) — this feature's schema must not diverge
  from Epic A3's already-stated assumption without a coordinated follow-up
  edit to both specs.
- REQ-003's Context Projection schema → populates Epic A1's already-
  reserved `project-context.resolved.json` path (INV-007) — this feature
  does not modify that reservation, only the schema of what eventually
  fills it.
- REQ-004's `context_binding.registry_digest` binding (`--whole`, INV-019)
  → Epic A2's `generate-registry-digest` fragment-selection CLI — not a
  blocking dependency (the CLI already exists, `Passed`), but this
  feature's own binding-policy decision must not be silently
  re-interpreted by Epic A5 as a fragment call instead.
- REQ-004's Policy-Weakening 3-axis fail-closed contract → a future
  Registry- or ownership-scoped weakening-detector epic's own output
  (not yet built, Non-goals) — not a blocking dependency on *this*
  feature's implementation (the fail-closed default is well-defined with
  zero detectors present), but a forward dependency for that future epic:
  it must supply this comparator's `--registry-weakening`/
  `--ownership-weakening` input, not invent a parallel mechanism.
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
        "evidence": {
          "type": "array",
          "items": { "$ref": "#/definitions/evidenceNode" }
        }
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
      "required": ["eligible", "upgrade_reasons"],
      "properties": {
        "eligible": { "type": "boolean" },
        "upgrade_reasons": {
          "type": "array", "items": { "type": "string", "minLength": 1 },
          "uniqueItems": true
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
            "pattern": "^/(workflow|components|shared_paths)(/([^/~]|~0|~1)*)*$"
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

`conditionalFacet.evidence` is an **array** of `#/definitions/evidenceNode`
elements, matching Epic A2's own `evaluate-predicate` output shape exactly
— `{result: bool, evidence: [...]}`'s `evidence` array member, not a single
node (an earlier revision of this schema used `"evidence": {"$ref":
"#/definitions/evidenceNode"}` directly, a single-node shape; adversarial
review "M Evidence array" identified this as inconsistent with the actual
producer's output contract). Because a `conditional_facets[]` entry's
`evidence` is exactly what `evaluate-predicate` returned for that facet's
governing predicate, no root-extraction rule is needed — the whole array
is copied verbatim from the evaluator's own output.

`#/definitions/evidenceNode` (each array element) is a structural
transcription of Epic A2's own Evidence JSON Schema
(`specs/epic-190-a2-capability-registry/design.md`, "Predicate DSL
evaluator contract" — INV-004), not a redefinition: the `operator` enum,
the `outcome` enum, and the `warn`-requires-`reason` `if`/`then` are copied
verbatim. If Epic A2's Evidence JSON Schema changes before Epic A5
implements against it, this definition needs a corresponding follow-up
edit (Assumptions, requirements.md) — this spec does not attempt a live
`$ref` across `contracts/` files, since JSON Schema draft-07 `$ref`
resolution across separately-versioned files is itself a coordination risk
this feature avoids by duplicating the (small, already-stable) Evidence
shape instead.

**`dependency_pointers[].pattern`**
(`^/(workflow|components|shared_paths)(/([^/~]|~0|~1)*)*$`) combines RFC
6901 JSON Pointer syntax (zero or more `/`-prefixed tokens after the first,
each token any character except unescaped `/`/`~`, with `~0`/`~1` escaping
`~`/`/`) **with** the root-segment allowlist in a single schema-level
`pattern`: the first token is constrained to exactly `workflow`,
`components`, or `shared_paths` by the alternation, and every subsequent
token uses the same syntax-only grammar as before. An earlier revision of
this schema used a syntax-only pattern (`^(/([^/~]|~0|~1)*)+$`) and claimed
the root-segment vocabulary could not be schema-expressed at all,
delegating it to a REQ-006 semantic check (`dependency-pointer-root-
not-allowlisted`) — adversarial review (Minor finding) showed the combined
regex above is expressible in draft-07 directly. That semantic check is
retired (AC-017 now names a schema-level rejection); REQ-006's genuinely
semantic (non-schema-expressible) territory in this area is narrower:
whether a syntactically- and root-valid pointer actually *resolves* to a
real value inside a concrete Context Projection instance (AC-016), which
requires comparing against a second artifact a bare schema `pattern`
cannot see.

### `contracts/capability-summary.schema.json` (REQ-002, Lite track only)

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://github.com/aharada54914/sdd-forge/contracts/capability-summary.schema.json",
  "title": "SDD Forge Capability Summary (Lite track)",
  "type": "object",
  "additionalProperties": false,
  "required": [
    "schema", "feature", "track", "capabilities",
    "required_lite_checks", "full_upgrade_required"
  ],
  "properties": {
    "schema": { "const": "sdd-capability-summary/v1" },
    "feature": { "type": "string", "pattern": "^[a-z0-9][a-z0-9-]*$" },
    "track": { "const": "lite" },
    "capabilities": {
      "type": "array", "items": { "type": "string", "minLength": 1 },
      "uniqueItems": true
    },
    "required_lite_checks": {
      "type": "array", "items": { "type": "string", "minLength": 1 },
      "uniqueItems": true
    },
    "full_upgrade_required": { "type": "boolean" }
  }
}
```

An earlier revision of this schema added a `track` discriminator
(`enum: ["lite","full"]`), a schema-level `if`/`then`/`else` branch, and a
`facet_manifest_ref` object pointing back at a Facet Manifest by digest,
inventing a full-track shape neither decision document v2 §6 nor §19
specifies and no sibling epic names a consumer for (adversarial review "M
full Summary"; requirements.md Non-goals, investigation.md INV-010). This
revision fixes only the Lite shape §6 already gives verbatim, plus this
feature's usual `schema`/`feature` envelope. `track` is retained as a
`const: "lite"` field (not dropped entirely) so a future full-track schema
revision, should a future ADR decide one is needed, can discriminate on
the same field name without a breaking rename — but no `if`/`then`/`else`,
boolean-subschema exclusion, or `facet_manifest_ref` shape exists in this
schema today.

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
      "propertyNames": { "minLength": 1 },
      "additionalProperties": { "$ref": "#/definitions/projectedComponent" }
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
step, and every other field is unchanged. `components`'s key vocabulary
(`propertyNames: {"minLength": 1}` plus a schema-typed
`additionalProperties`, rather than a `patternProperties` regex) is
**identical** to Epic A1's own `components[].id` constraint — any non-empty
string, no character-set restriction — so any component `id` that
validates against Epic A1's schema also validates as a `context-
projection.schema.json` key. An earlier revision of this schema instead
used `patternProperties` keyed on a slug-shaped regex
(`^[a-z0-9][a-z0-9-]*$`), which rejected A1-valid ids containing characters
outside that set (e.g. `Desktop/App`, `Desktop_Client`) and incorrectly
claimed identity with Epic A1's constraint while actually being narrower
(adversarial review "B3"). A component id containing `/` or `~` remains
addressable via `dependency_pointers` using the existing RFC 6901
`~1`/`~0` escapes (requirements.md Edge Cases) — this schema change does
not require a new escaping rule, only makes such ids schema-valid for the
first time.

**Generation procedure** (normative for Epic A5's future implementation,
not built by this feature). An earlier revision described step 1 as
obtaining a "parsed structure" directly from the canonicalizer — Epic A1's
canonicalizer contract has no such API; its only output is canonical-JSON
*bytes* (or a hash) on stdout (INV-008). This revision states the two
distinct sub-steps that output actually requires (adversarial review "M
canonicalizer API"):

1. Run `canonicalize-sdd-yaml` (YAML input mode) over `project-context.
   yaml`. Its canonical-JSON stdout bytes are (a) hashed to obtain
   `source_sha256` (equal to `context_binding.full_context_revision`), and
   (b), *separately*, parsed by the caller via a stdlib JSON parser (e.g.
   Python's `json.loads`) — never a second, independent YAML parse of the
   original file — into a manipulable structure. If `provider-bindings.
   yaml` exists, canonicalize it the same way (hash only; no re-keying) and
   record `provider_bindings_sha256`.
2. If the parsed structure's `components` key is absent, substitute `[]`;
   if `shared_paths` is absent, substitute `[]` (both optional at Epic
   A1's schema level, INV-009 — REQ-003's Context Projection fields remain
   required regardless, "B8"). Re-key `components` into an object keyed by
   each entry's own `id` field, with `id` itself omitted from each value
   (sound only because Epic A1's own content-schema validator already
   guarantees `id` uniqueness upstream, INV-009 — this step performs no
   uniqueness check of its own and must not silently overwrite a
   collision). An empty source `components` array re-keys to `{}`.
3. Assemble `{schema: "sdd-context-projection/v1", source_sha256,
   provider_bindings_sha256?, workflow: <as-is>, components: <re-keyed,
   possibly {}>, shared_paths: <as-is, possibly []>}`.
4. Feed this assembled structure back through `canonicalize-sdd-yaml` a
   **second time**, JSON input mode — the exact two-pass pattern Epic A1's
   own HMAC preimage construction already establishes as precedent
   (`specs/epic-189-a1-project-context/design.md`, "HMAC preimage and
   signing" section, INV-008) — to obtain final RFC 8785 (JCS) canonical
   bytes.
5. Write those bytes to `plugins/sdd-quality-loop/scripts/generated/
   project-context.resolved.json` (Epic A1's already-reserved path,
   INV-007). `projection_sha256` (in every Facet Manifest bound to this
   projection) is the sha256 of exactly these bytes.

### YAML parse contract (REQ-006, `validate-facet-manifest`/`validate-capability-summary` — fixing "B4")

Both scripts target a `.yaml` input file (`facet-manifest.yaml`/
`capability-summary.yaml`, REQ-007). Neither hand-rolls a YAML parser of
any kind. The **only** path from YAML bytes to a Python structure is: (1)
invoke `canonicalize-sdd-yaml` as a subprocess (YAML input mode) over the
input path; (2) `json.loads()` its canonical-JSON stdout. A non-zero
canonicalizer exit is surfaced as this validator's own diagnostic
(`facet-manifest: canonicalizer-invocation-failed: <detail>` /
`capability-summary: canonicalizer-invocation-failed: <detail>`), never
silently swallowed or retried with a fallback parser. (`validate-context-
projection` needs no such step — its target, `project-context.resolved.
json`, is already JSON; it uses stdlib `json.load` directly.)

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
| Conditional-facet duplicate | `conditional-facet-duplicate` | a `facet` value repeated across two or more `conditional_facets[]` entries (verification-round finding on total order — makes `conditional_facets`' own by-`facet` stable-sort, below, a genuine total order, the same status `resolved_gates[].id` already has via `resolved-gate-id-duplicate`) |
| Stable-sort discipline | `array-not-stable-sorted` | `affected_components`, `required_facets`, `capabilities`, `lite_eligibility.upgrade_reasons` each lexicographically sorted; `conditional_facets`/`resolved_gates` each sorted by `facet`/`id` respectively |

(An earlier revision of this table additionally listed a
`dependency-pointer-root-not-allowlisted` semantic check; that check is
retired — the root-allowlist constraint it duplicated is now enforced at
the schema level, by `dependency_pointers[].pattern` itself, "Minor"
finding, API / Contract Plan above.)

The schema-conformance check is a hand-rolled, stdlib-only Python
structural validator (no third-party `jsonschema` dependency, INV-014) —
it implements the closed subset of JSON Schema draft-07 this feature's
three schemas actually use: `type` (including array-form/union types, e.g.
`evidenceNode.path`'s `["string","null"]`), `required`,
`additionalProperties` (both boolean and schema-typed), `properties`,
`propertyNames`, `pattern`, `enum`, `const`, `uniqueItems`, `minItems`,
`minLength`, `if`/`then`/`else`, `not`, `oneOf`, boolean (`true`/`false`)
subschema values, **`items`**, and `$ref`/`definitions` — matching
`validate-capability-registry.py`'s own hand-rolled-validator convention,
not a general-purpose JSON Schema engine.

This list is a **re-enumeration, checked against every keyword the three
committed schemas above actually use** (a verification-round finding: an
earlier revision's list, while already covering `not`/`oneOf`/boolean
subschema values/array-form `type`/`propertyNames`, still omitted
**`items`** — the keyword `evidenceNode.children`, `conditional_facets[
].evidence`, `resolved_gates[]`, `dependency_pointers[]`,
`shared_paths[].components`, and every array-typed `projectedComponent`
field, among others, all depend on to constrain their own elements'
shape; without it, none of those item-level constraints could actually be
enforced by this validator, despite the schemas above declaring them). The
keywords each committed schema instance actually uses, cross-checked
against this list: `facet-manifest.schema.json` uses `type`,
`additionalProperties`, `required`, `properties`, `const`, `pattern`,
`items`, `uniqueItems`, `if`/`then`/`else`, `not`, `enum`, `minItems`,
`minLength`, `$ref`/`definitions`; `capability-summary.schema.json` uses
`type`, `additionalProperties`, `required`, `properties`, `const`,
`items`, `uniqueItems`; `context-projection.schema.json` uses `type`,
`additionalProperties`, `required`, `properties`, `enum`, `propertyNames`,
`items`, `oneOf`, `const`, `$ref`/`definitions`. Every keyword in that
union appears in the implemented list above; the list contains no keyword
none of the three schemas use. An earlier, still-earlier revision of this
list omitted `not`, `oneOf`, boolean subschema values, array-form `type`,
and `propertyNames` despite this feature's own committed schemas using at
least four of the five (adversarial review "B5"; boolean-subschema values
are retained in the implemented set for forward compatibility even though,
after "M full Summary"'s removal of the full-track Capability Summary, no
committed schema instance currently exercises one). `patternProperties` is
**not** in this implemented subset (an earlier revision listed it; B3's
`context-projection.schema.json` fix replaced the one `patternProperties`
usage with `propertyNames` + schema-typed `additionalProperties`, and no
other schema in this feature uses `patternProperties`).

`$schema`, `$id`, and `title` are **not** implemented as validation
keywords by this hand-rolled subset — they are annotation/identifier
keywords, not constraint keywords, and this feature's validators check
them by a different, more specific mechanism: the Discovery contract
(below) requires a present `$schema` keyword and a matching `$id` per
artifact, and `title` carries no normative meaning anywhere in this
feature's schemas or validators at all (it is present in each committed
schema purely as human-readable documentation, matching every existing
`contracts/*.schema.json`'s own convention). Treating `$schema`/`$id`/
`title` as out of the hand-rolled structural validator's own scope, while
still checking `$schema`/`$id` elsewhere (Discovery contract), is a
deliberate split, not an omission — a general-purpose validator would
need to interpret `$schema` to select a metaschema and `$id` to resolve
`$ref` URIs, neither of which this feature's small, closed-subset engine
does (it resolves every `$ref` it uses as a same-document `#/definitions/
...` fragment only, never a separate document).

Each of the three committed schema documents (`facet-manifest.schema.
json`, `capability-summary.schema.json`, `context-projection.schema.json`)
is additionally validated once, at spec-authoring/registration time, not
by an automated `tests/*.tests.sh` regression suite, against the official
draft-07 metaschema — a general metaschema-conformant validator is outside
this hand-rolled subset's deliberately closed scope (INV-014: no
third-party `jsonschema` dependency, and the official metaschema itself
uses keywords — `allOf`/`anyOf`/`dependencies`/`contains`/`multipleOf`/
`format`, among others — this feature's subset does not implement, since
none of this feature's own schemas need them). The result of that one-time
check is recorded in the Spec-Authoring-Time Manual Review Record
(acceptance-tests.md), the same non-regression-suite treatment AC-036/037/
038 already use for other one-shot, registration-time facts.

### `validate-capability-summary` contract (REQ-006, Lite track only)

`validate-capability-summary.py --summary <path>` → exit 0 or non-zero
with `capability-summary: <check-id>: <detail>` lines. Checks: schema
conformance only (`schema-invalid`, against the Lite-only schema above —
an earlier revision's `track`-conditioned `if`/`then`/`else` branch check,
and its `facet_manifest_ref.path`-resolvability check
(`facet-manifest-ref-unreadable`), are both retired along with the
full-track shape that motivated them, "M full Summary"/"M
facet_manifest_ref"). No semantic check beyond schema conformance is
needed for this script — every REQ-002 invariant is schema-expressible now
that there is only one branch.

### `validate-context-projection` contract (REQ-003/REQ-006)

`validate-context-projection.py --projection <path>` → exit 0 or non-zero
with `context-projection: <check-id>: <detail>` lines. Checks: schema
conformance only (`schema-invalid`, including the `components` re-keying
shape — a fixture where `components` is still array-typed fails
`type: object` at the schema level, AC-030). An earlier revision
additionally listed a `component-key-pattern-invalid` check (every
`components` key matches a slug-shaped pattern); that check is retired as
a direct consequence of "B3" — with no character-set restriction left to
enforce (only `propertyNames: {"minLength": 1}`, itself already
schema-level), there is nothing left for a separate semantic check to
catch.

### Discovery contract (REQ-006, all four scripts)

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
matching `$id`. `compare-facet-manifest-staleness` uses the identical
discovery contract to locate `facet-manifest.schema.json` for its own
input-shape validation before comparing (API / Contract Plan, below). A
release-gating `--check` mode on the vendoring step (Deployment / CI Plan)
compares each canonical `contracts/<filename>`'s sha256 against its
vendored `plugins/sdd-quality-loop/contracts/<filename>` counterpart,
mirroring Epic A2's own vendored-copy drift check exactly.

### `compare-facet-manifest-staleness` contract (REQ-004/REQ-006 — normative CLI, fixing "B7")

An earlier revision of this spec described REQ-004's staleness contract
only as prose ("fix the comparison as field-by-field structural
equality...") with no actual CLI, input shape, output shape, exit codes,
or diagnostics — leaving TEST-019 through TEST-027 with nothing concrete
to invoke (adversarial review "B7"). This section fixes that gap. A later
verification round found three further defects in this section's own
first draft of the CLI contract, all fixed below: (1) the three
`--*-weakening` flags were optional, with flag *omission* standing for
`indeterminate` — reversed by making all three mandatory, explicit,
three-valued inputs; (2) branch 3 (digest-unchanged) short-circuited to
`fresh` regardless of `--resolver-version-bump`, silently skipping the
impact assessment REQ-005's `minor` tier requires unconditionally —
reversed by scoping branch 3 to `none`/`patch` only, and adding a
dedicated `minor-rule-set` input for a same-version `rule_set_revision`
edit; (3) this section's own stdout contract (`<status>[:<reason>]`)
disagreed with an earlier revision of AC-044, which fixed a bare
`fresh|stale|blocked` stdout shape — reversed by making `<reason>`
mandatory (this section's shape, not AC-044's, is normative) and by
defining a **separate** exit-3/stderr channel for argument, schema, and
canonicalizer errors, so the verdict channel (stdout, exit 0/1/2) never
needs to represent "the input was malformed" as a fourth pseudo-verdict.

**Invocation:**

```
compare-facet-manifest-staleness.py \
  --old-manifest <path> --new-manifest <path> \
  --projection-weakening {weakened|not-weakened|indeterminate} \
  --registry-weakening {weakened|not-weakened|indeterminate} \
  --ownership-weakening {weakened|not-weakened|indeterminate} \
  --resolver-version-bump {none|patch|minor|minor-rule-set|major}
```

`--old-manifest`/`--new-manifest` are `facet-manifest.yaml` paths (parsed
per the YAML parse contract above). **All three `--*-weakening` flags and
`--resolver-version-bump` are required on every invocation**, whether or
not the corresponding axis's digest changed, or the resolver version
changed at all: an earlier revision made the three `--*-weakening` flags
optional and let flag *omission* stand for `indeterminate`, which this
revision reverses (requirements.md REQ-004) — a caller with no detector
for an axis must pass `--<axis>-weakening indeterminate` explicitly, and a
caller for an axis whose digest did not change passes `--<axis>-weakening
not-weakened` by convention (requirements.md Goals), never `indeterminate`/
`weakened` for an unchanged axis. Omitting any of the three `--*-weakening`
flags, or `--resolver-version-bump`, is an **argument error** (Exit codes,
below), never a valid way to express `indeterminate`.

`--resolver-version-bump` is required — the caller (Epic A5's Resolver)
already knows which semver component, if any, changed between the two
manifests' `resolver.version` values, and whether a same-version
`rule_set_revision` edit occurred (the dedicated `minor-rule-set` value,
requirements.md REQ-005); this script does not itself diff `resolver.
version`/`rule_set_revision` to *infer* the tier, since a caller-supplied
value is unambiguous and a self-inferred one would require this script to
re-implement semver-component comparison for no added safety. It **does**,
however, validate the supplied tier for internal consistency against the
two manifests it was actually given: `none` requires `resolver.version`
and `resolver.rule_set_revision` both unchanged between old/new;
`patch`/`minor`/`major` each require `resolver.version` to actually differ
at exactly that semver component (and no coarser one); `minor-rule-set`
requires `resolver.version` unchanged **and** `resolver.rule_set_revision`
changed. Any other combination (e.g. `--resolver-version-bump patch`
against manifests whose `resolver.version` differs at the minor component,
or `--resolver-version-bump minor-rule-set` against manifests whose
`resolver.version` actually changed) is rejected as an **argument error**
before any branch below is evaluated.

**Output:** exactly one line on stdout, `facet-manifest-staleness:
<status>:<reason>` — always both the status and its reason, colon-joined,
**never** a bare `<status>` alone (this is the normative shape; an earlier
revision of AC-044 asserted a bare `fresh|stale|blocked` stdout contract
that contradicted this section, and this revision resolves that
contradiction in this section's favor by making `<reason>` mandatory,
never omitted) — where `<status>` is one of `fresh`/`stale`/`blocked`, and
`<reason>` (present for every status) is one of: `unchanged` (no axis's
digest differs between old/new `context_binding`, **and**
`--resolver-version-bump` is `none` or `patch`), `metadata-only-refresh`
(the ordinary comparison ran, semantic output unchanged),
`semantic-output-changed` (ditto, but changed), `major-version-forced`
(`--resolver-version-bump major`, no Block fired), `policy-weakening-
blocked:<axis>` (`<axis>` ∈ `projection`/`registry`/`ownership`, that
axis's own flag was `weakened`), or `weakening-verdict-indeterminate:
<axis>` (that axis's digest changed and its flag's explicit value was
`indeterminate`).

**Exit codes:** `0` = `fresh`, `1` = `stale`, `2` = `blocked` — fixed,
matching the status enum 1:1, so a caller can branch on exit code alone
without parsing stdout if it only needs the coarse verdict. A **fourth**
exit code, `3`, is reserved for everything that is not a verdict at all: a
malformed/missing CLI argument (a missing required flag, an out-of-enum
`--*-weakening`/`--resolver-version-bump` value, or a `--resolver-version-
bump` tier inconsistent with the two manifests supplied, Invocation above),
a schema-invalid `--old-manifest`/`--new-manifest` (this script runs
`validate-facet-manifest`'s own schema-conformance check against both
inputs before comparing, Discovery contract below), or a canonicalizer/
subprocess failure reading either YAML file (YAML parse contract above).
Exit-`3` diagnostics are written to **stderr only**, one line each, in the
same `facet-manifest-staleness: <check-id>: <detail>` style the other
three scripts already use for their own diagnostics — never to stdout,
and never sharing stdout's `facet-manifest-staleness: <status>:<reason>`
line, which is reserved exclusively for the three verdict outcomes. This
separates the verdict channel (stdout, exit 0/1/2) from the diagnostic
channel (stderr, exit 3) completely: a caller parsing stdout for a verdict
never needs to distinguish "blocked" from "the input was malformed," and a
caller checking for exit 3 never needs to parse a verdict string that was
never produced. All three runtimes (`.py`/`.sh`/`.ps1`) produce
byte-identical exit-3 diagnostics for the same malformed input, following
the existing diagnostic-determinism contract (below).

**Branch order (highest precedence first), per REQ-004/REQ-005:**

0. Validate arguments: all four required flag groups present and
   in-enum, and `--resolver-version-bump` consistent with the two
   manifests' own `resolver.version`/`rule_set_revision` (Invocation
   above), and both manifests schema-valid — any failure → **exit 3**
   (Exit codes, above), no further branch evaluated.
1. For each axis whose digest differs between `--old-manifest` and
   `--new-manifest`: if that axis's `--*-weakening` value is `weakened` or
   `indeterminate` → **`blocked`** (`policy-weakening-blocked:<axis>` or
   `weakening-verdict-indeterminate:<axis>` respectively). This check runs
   across **all** changed axes before any other branch; if the
   first-encountered result would be `blocked`, no further branch is
   evaluated (Policy-Weakening, including its fail-closed form, always
   takes precedence, requirements.md Edge Cases).
2. Else if `--resolver-version-bump major` → **`stale`**
   (`major-version-forced`), unconditionally, regardless of whether any
   digest changed or what semantic output would show.
3. Else if `--resolver-version-bump` is `none` or `patch` **and** no
   axis's digest differs at all → **`fresh`** (`unchanged`) — no
   semantic-output recomputation is attempted. (Scoped to `none`/`patch`
   only — a verification-round finding: an earlier revision of this
   branch fired whenever no digest changed, regardless of
   `--resolver-version-bump`, which let a `minor` or `minor-rule-set` bump
   with an otherwise-unchanged `context_binding` short-circuit straight to
   `fresh` without ever running the REQ-004 impact assessment REQ-005's
   minor tier requires unconditionally — see branch 4, requirements.md
   REQ-005.)
4. Else (some digest changed, or `--resolver-version-bump` is `minor`/
   `minor-rule-set`, every changed axis reported `not-weakened`, no
   `major` bump) → recompute and structurally compare semantic output
   (REQ-004's field-by-field equality) between `--old-manifest` and
   `--new-manifest`: unchanged → **`fresh`** (`metadata-only-refresh`);
   changed → **`stale`** (`semantic-output-changed`).

This table is the direct normative source TEST-019 through TEST-027,
TEST-039, TEST-040, TEST-044, TEST-045, and TEST-046 implement against.

### Diagnostic determinism contract (REQ-006, all four scripts — fixing "M parity決定論")

An earlier revision left byte-identical `.py`/`.sh`/`.ps1` parity (AC-031)
underspecified: "one diagnostic line per failed check" fixes neither
ordering, path representation, encoding, nor line-ending, so two
independently-correct implementations could still disagree on output
bytes. This feature fixes all four normatively:

- **Order**: diagnostic lines are sorted by the tuple `(check-id, JSON
  Pointer path)`, ascending, `check-id` first. Multiple errors within one
  check-id (e.g. two separate `array-not-stable-sorted` violations) are
  each their own line, ordered by their own JSON Pointer path.
- **Path representation**: any path component in a diagnostic line is an
  RFC 6901 JSON Pointer string (e.g. `/conditional_facets/2/reason`) —
  never a dotted (`conditional_facets.2.reason`) or bracketed
  (`conditional_facets[2].reason`) notation.
- **Encoding**: all script output (stdout and stderr) is UTF-8, with no
  byte-order mark.
- **Line endings**: LF (`\n`) only, on every runtime, including the `.ps1`
  wrapper when run on Windows — the wrapper must not let PowerShell's
  default `Write-Output`/`Write-Host` CRLF behavior leak through (e.g. by
  writing bytes directly, or setting `[Console]::Out.NewLine = "`n"` before
  emitting diagnostics).
- **Exit codes**: fixed at `0`/`1` for the three schema/semantic validators
  (pass/fail, no per-check-id exit code, matching `validate-capability-
  registry.py`'s own convention, INV-005) and `0`/`1`/`2`/`3` for
  `compare-facet-manifest-staleness` (fresh/stale/blocked/argument-or-
  input-error respectively — the last exiting via a stderr diagnostic
  only, never a stdout verdict line, `compare-facet-manifest-staleness`
  contract above).

AC-031's fixture set includes at least one Windows-style path argument
(a backslash-separated `--manifest`/`--summary`/`--projection` value) and
confirms the `.ps1` wrapper's own output for that fixture remains LF-only
and byte-identical to the `.py`/`.sh` outputs for the same logical input,
**including `compare-facet-manifest-staleness`'s own exit-3 stderr
diagnostics** for a malformed-argument fixture (a verification-round
addition ensuring the exit-3 channel is itself covered by the existing
cross-runtime parity discipline, not merely the three verdict exit codes).

## Test Strategy

**Six** new `tests/*.tests.sh`/`.tests.ps1` pairs, fixture data under
`tests/fixtures/facet-manifest/` (an earlier revision's header said "Four"
while its own numbered list ran to six items and its Components section
listed only four file pairs — none of the three agreed; adversarial review
"M suite/1:1" — this revision states one count and keeps Components,
AC-033, and this list in agreement):

1. `facet-manifest-schema` — one fixture per REQ-001 required field
   (parameterized negative test, matching Epic A1's own "Field Requirement
   Matrix" pattern, deleting exactly one field per fixture, INV-009);
   AC-003 (uniqueItems, empty-array positive), AC-004/AC-005 (`applied`/
   `reason`/`evidence` `if`/`then`, Evidence-array-shape conformance and
   rejection of an out-of-enum operator), AC-006 (`resolved_gates[]`
   shape and `stage` enum), AC-007 (`capability_minimum_enforcement`
   const-or-absent, plus the aggregate fixture), AC-008 (`lite_eligibility`
   required `upgrade_reasons`, absent-is-now-rejected), AC-009/AC-010
   (`context_binding`/`resolver` digest/semver pattern conformance and
   rejection), AC-011 (decision document v2 §16's own worked example, with
   a real 64-hex digest, validates once embedded), AC-017/AC-018 (the
   combined syntax+root `dependency_pointers[].pattern`: an out-of-
   allowlist-root fixture and a malformed-RFC-6901 fixture, both rejected
   at the schema level — AC-017 moved here from a semantic-check suite, its
   check having been folded into the schema, "Minor" finding), AC-041
   (`evidenceNode` `outcome: "warn"` requires `reason`), AC-048's own
   schema-level half (`upgrade_reasons`' `uniqueItems: true` rejects a
   duplicate reason string).
2. `facet-manifest-semantics` — one fixture per REQ-006 diagnostic-id
   table row for `validate-facet-manifest`: `resolved-gate-id-duplicate`,
   `facet-classification-conflict`, `conditional-facet-duplicate` (AC-047:
   two `conditional_facets[]` entries sharing one `facet` value, differing
   in `applied`/`reason`/`evidence`, both rejected), `array-not-stable-
   sorted` (its scope now including AC-048's semantic half: an
   `upgrade_reasons` fixture submitted out of lexicographic order is
   rejected), plus one fully-clean fixture proving a negative (all checks
   pass on valid input, matching Epic A2's own "cannot pass vacuously"
   discipline). (An earlier revision's `dependency-pointer-root-not-
   allowlisted` fixture moved to suite 1, above — that check is now
   schema-level, AC-017.)
3. `capability-summary-schema` — AC-012 (Lite-only required-field set),
   AC-013 (decision document v2 §6's own lite example, extended with
   `schema`/`feature`/`track`), AC-014 (`additionalProperties: false`
   rejects a `facet_manifest_ref` or other extra field).
4. `context-projection-schema` — AC-015 (re-keying proof: two-component
   fixture, one with a non-slug-shaped id, produces exactly two id-keyed
   entries with no `id` sub-field; a second fixture proves the
   source-omits-`components`/`shared_paths` materialization rule, "B8"),
   AC-016 (end-to-end RFC 6901 resolution of decision document v2 §16's
   own `/components/desktop-client/artifact_kinds` example against a
   fixture Context Projection), AC-042 (`shared_paths[]` `oneOf` branch
   fixtures).
5. `facet-manifest-staleness` — `compare-facet-manifest-staleness`'s full
   branch table (API / Contract Plan): AC-019 (digest-only change with an
   explicit `not-weakened` verdict, not stale), AC-020 (same-gate-ID
   stage/blocking change, stale), AC-021 (`evidence`-inclusion lock,
   stale — reversing an earlier revision's exclusion fixture), AC-022
   (minimum-enforcement tightening, stale), AC-023 (weakened-verdict Block,
   comparison never evaluated), AC-024 (explicit-`indeterminate`-verdict
   fail-closed Block, plus its forward-compatible not-weakened sub-case),
   AC-039 (no axis changed, all three flags `not-weakened`,
   `--resolver-version-bump none`, `fresh`/`unchanged`, no comparison
   attempted), AC-040 (`ownership_digest` axis parity with AC-019/AC-024,
   both sub-cases with all three flags explicit); REQ-005's version-bump
   tiers: AC-025 (patch, unchanged, no regeneration), AC-026 (minor, both
   changed and unchanged sub-cases, each also with a byte-identical
   `context_binding`), AC-045 (the branch-3 fix itself: `minor`/
   `minor-rule-set` with no digest change still reaches the impact
   assessment, never short-circuits to `fresh`), AC-027 (major, forced
   regardless of semantic output, and its precedence *below* a Block,
   requirements.md Edge Cases), AC-046 (`--resolver-version-bump`/actual-
   version-diff consistency argument-error fixtures, one per tier
   mismatch, plus one consistent-declaration positive fixture per tier);
   AC-044 (the CLI contract itself: mandatory flag presence for all three
   `--*-weakening` flags and `--resolver-version-bump`, the
   `<status>:<reason>` stdout format, the verdict-vs-argument-error exit-
   code mapping including exit 3, and the stdout/stderr channel
   separation).
6. `facet-manifest-parity` — all four scripts' `.py`/`.sh`/`.ps1`
   invocations against every fixture in suites 1-5 produce byte-identical
   exit codes and diagnostic output, following the diagnostic-determinism
   contract above (AC-031, including its Windows-path-separator vector);
   three installed-plugin-context discovery fixtures per script (AC-032,
   matching Epic A2's own three-fixture, per-runtime discovery proof,
   INV-018); the provider-neutrality scan (AC-043) across all three schema
   files and four scripts.

Every new suite is registered directly in `tests/run-all.sh`/`.ps1`
(unprotected, INV-018) and staged for `.github/workflows/test.yml`
registration via human-copy (protected, matching Epic A2's own precedent
for CI-registration edits specifically — AC-033).

## Design Decisions (resolving open questions)

- **`evidence`/`schema`/`feature` are semantic-output-comparison inputs
  after all, reversing an earlier revision (requirements.md Field
  Definitions, AC-021 — adversarial review "B1").** An earlier revision of
  this spec excluded `conditional_facets[].evidence`, `schema`, and
  `feature` from semantic-output comparison by analogy to `context_binding`/
  `resolver` being "binding/provenance metadata." ADR-0021 item 2's own
  text draws that boundary at exactly two blocks — `context_binding` and
  `resolver` — and nowhere else; a three-additional-field exclusion is a
  narrower reading than the ADR fixes, not a gap it leaves implicit for
  this spec to close. This revision reverts to the literal boundary: only
  `context_binding`/`resolver` are excluded. In practice `schema` and
  `feature` never differ between two Facet Manifest revisions being
  compared for the same Feature (their inclusion is harmless, not
  meaningfully load-bearing) — the substantive change is `evidence`:
  a predicate-evaluator internal-detail change (e.g. a WARN-reason wording
  tweak) that leaves `applied`/`reason` unchanged now *does* mark a Feature
  stale, which is a strictly more conservative (safer, not laxer) outcome
  than the earlier revision's exclusion, consistent with this spec's
  overall posture after "B2"'s fail-closed correction elsewhere.
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
  `capability-summary.yaml`'s extension; this feature extends that choice
  consistently to the new `facet-manifest.yaml` sibling rather than
  introducing a format split between the two co-located, jointly-generated
  artifacts. The same reasoning Epic A1 gives for `project-context.yaml`/
  `provider-bindings.yaml` being YAML despite being schema-validated
  machine artifacts applies here: git-diff readability for a human
  reviewing a PR. RFC 8785/YAML-1.2-core canonicalization (REQ-003,
  REQ-004's stable-sort discipline) applies uniformly regardless of source
  serialization format, so choosing YAML carries no cross-runtime-hashing
  cost — the canonical byte sequence a digest is computed over is never the
  raw YAML/JSON source bytes, always the canonicalizer's JCS output.
- **Capability Summary schema is Lite-track-only; a full-track shape is
  deferred to a future ADR, not decided here (requirements.md REQ-002,
  Non-goals — adversarial review "M full Summary").** An earlier revision
  invented a `track`-discriminated schema with a full-track
  `facet_manifest_ref` compressed-view pointer, on the theory that decision
  document v2 §19's listing of Capability Summary as a distinct Epic A5
  output, even in the full track, implied this feature needed to specify
  that shape. §19 fixes only that the *output exists*, not its full-track
  *content* — and no sibling epic names a concrete consumer for one
  (investigation.md INV-010/OQ-001, retired). Inventing a shape nothing
  requires yet is exactly the kind of implementation-time schema decision
  REQ-001/REQ-002's own purpose (fixing Epic A5's output type *before* it
  is built) is supposed to prevent happening ad hoc — deferring an
  actually-undecided question to a future ADR is more consistent with that
  purpose than deciding it prematurely inside this feature's own scope.
  (The full-track compressed-view integrity gaps an earlier adversarial
  review round separately raised — repo-root containment, digest preimage,
  hash/capabilities consistency — are retired along with the artifact they
  critiqued, not separately resolved; a future ADR that reintroduces a
  full-track shape would need to address them fresh, not inherit an
  unresolved integrity design from this revision.)
- **`context_binding.registry_digest` binds via `--whole`, not a
  `--capability-ids`/`--gate-ids` fragment (requirements.md REQ-004,
  Field Definitions — adversarial review "M registry_digest"/INV-019).**
  Epic A2's `generate-registry-digest` leaves fragment selection as "Epic
  A5's Resolver concern," and this feature, not Epic A5, is the one that
  fixes what `registry_digest` binds to — an unfixed choice would let
  different Resolver implementations disagree on a Manifest's own digest
  for the identical Registry state. The `--whole` choice follows Epic A3's
  own `ownership_digest` precedent (REQ-005) by the identical soundness
  argument: a Capability's `trigger` match outcome is a function of the
  current Context Projection, so a Registry edit to a *currently
  non-matching* Capability's `trigger` could start matching on the very
  next resolve without any other input changing — no proper subset of
  "currently-matched capabilities" can be soundly treated as "not consumed"
  by a given resolve, because determining *which* capabilities currently
  match requires evaluating all of them in the first place.
- **Policy-Weakening short-circuit is uniform across all three axes and
  fails closed on an indeterminate verdict (requirements.md REQ-004 —
  adversarial review "B2").** An earlier revision applied the
  Policy-Weakening short-circuit only to the projection axis (the one axis
  with a live detector today) and routed every Registry/ownership digest
  change through the ordinary comparison unconditionally, reading "no
  detector exists yet" as license to treat those axes as never-weakening.
  ADR-0021 item 3 and decision document v2 §16 both state the Block rule
  uniformly across projection/registry/ownership, with no carve-out for
  "axes without a detector" — a missing detector is an availability gap,
  not evidence that a Registry or ownership edit can never be a weakening.
  Fail-closed (Block on indeterminate) is the direct consequence of taking
  that uniform rule seriously without waiting for detector coverage to
  catch up: it produces the same outcome a real weakening would (Block),
  which is the safe default when the comparator cannot tell the two apart.
  The cost is a real one, stated plainly (requirements.md Goals/Edge
  Cases): every `registry_digest`/`ownership_digest`-changing transition
  Blocks today, including ordinary, non-weakening Registry/ownership
  edits, until a future epic's detector starts supplying `not-weakened`
  verdicts. This spec accepts that cost as the correct trade for closing a
  fail-open gap in a staleness contract whose entire purpose is safety
  (ADR-0021's own motivation, "an in-progress Feature can pass its Gate
  with stale, insufficient artifacts").
- **`lite_eligibility.upgrade_reasons` is required, not `default: []`
  (requirements.md AC-008 — adversarial review "M default").** A JSON
  Schema `default` is an annotation consumed by tooling that chooses to
  read it; it never changes what value is actually present in an instance
  document. An earlier revision relied on `default: []` to mean "absent is
  treated as `[]`," which is false for REQ-004's plain structural-equality
  comparator — an absent field and an explicit `[]` are different
  instances under that comparator, and treating them as equivalent would
  require a bespoke normalization rule this schema never stated. Making
  the field required removes the ambiguity at the schema level instead:
  every schema-valid Facet Manifest has an explicit `upgrade_reasons`
  array, `[]` when there is nothing to report, and REQ-004's comparator
  needs no special-case normalization for this field at all.
- **draft-07 subset expansion and metaschema self-check (requirements.md
  REQ-006 — adversarial review "B5").** An earlier revision's implemented-
  keyword list omitted `not`, `oneOf`, boolean subschema values, and
  array-form `type` despite this feature's own three schemas using at
  least three of the four — meaning the stated "hand-rolled validator
  implements the subset this feature's schemas actually use" claim was
  false as written. This revision closes the gap by implementing the
  keywords actually used (API / Contract Plan, `validate-facet-manifest`
  contract) rather than by removing the keyword usages from the schemas —
  `not`/array-form `type` in particular are the most natural expression of
  the invariants they encode (`else: {not: {required: ["reason"]}}`;
  `evidenceNode.path`'s string-or-null shape). Full metaschema conformance
  is checked once, manually, at spec-authoring time rather than folded
  into the closed-subset validator or a third-party dependency, since
  requiring this feature's small, rarely-changing hand-rolled engine to
  also validate the *general* draft-07 metaschema would mean implementing
  most of draft-07 — a scope this feature's own "closed, small subset"
  design explicitly rejects (INV-014).
- **Rejected alternative: keep a track-discriminated Capability Summary
  schema with every field optional.** Superseded by the Lite-only decision
  above — with no `track: "full"` branch remaining, the "all-optional
  schema can't express which fields are required per branch" problem this
  alternative was originally rejected for no longer arises; it is retired
  along with the branch it was about, not independently re-evaluated.
- **Major-version-bump precedence over an unrelated digest change, subject
  to Block precedence (requirements.md Edge Cases).** ADR-0021 item 6
  places no condition on the major tier beyond "every Feature that used
  the affected Resolver version" — this spec states explicitly that a
  major bump forces re-resolve independent of, and regardless of the
  outcome of, any concurrent digest-driven semantic-output comparison,
  since ADR-0021's own text draws no distinction between "major bump
  alone" and "major bump plus something else changed." This revision adds
  one further precedence rule ADR-0021 doesn't need to state because it
  never contemplates the interaction: REQ-004's Policy-Weakening
  short-circuit (including its fail-closed branch, "B2") is evaluated
  *before* the resolver-version-tier check (API / Contract Plan, branch
  order), so a Block always wins over a major-tier forced-stale outcome —
  Block is the strictly stronger safety outcome (re-approval required, not
  merely re-resolve), and nothing in ADR-0021 suggests a version bump
  should be able to launder past a Block.
- **`rule_set_revision`-only change treated as a minor-tier transition,
  now with its own explicit CLI input and a version-diff consistency check
  (requirements.md REQ-005, Edge Cases — extended by a verification-round
  finding on comparator branch order).** ADR-0021 item 6/decision v2 §18.2
  fix patch/minor/major behavior by `resolver.version`'s own semver
  component, but say nothing about a `rule_set_revision` change with
  `resolver.version` left unchanged (a same-version rule-table edit — e.g.
  a hotfix to trigger evaluation logic that a maintainer forgot to bump).
  Treating it as a silent patch-tier no-op would let a real rule-table
  change skip the impact assessment entirely; treating it as an
  unconditional major-tier force is stronger than the evidence warrants
  (the version number itself didn't move). Minor-tier's "run the impact
  assessment, stale only if changed" is the safe middle ground already
  built for exactly this shape of "maybe nothing observable changed, maybe
  something did" uncertainty. An earlier revision of this decision fixed
  *that* the rule-set-only case is minor-tier, but left the comparator
  with no way to *tell* it apart from an ordinary `minor` `resolver.
  version` bump, and — more seriously — left branch 3 (`compare-facet-
  manifest-staleness` contract, above) short-circuiting straight to
  `fresh` whenever no `context_binding` digest changed, with no exception
  for either case: a minor bump or a rule-set-only edit landing with
  every other input unchanged would never actually run the impact
  assessment this very decision requires. This revision closes both gaps
  together: a dedicated `--resolver-version-bump minor-rule-set` input
  (distinct from `minor`) lets the comparator route the rule-set-only case
  correctly without inferring it from a raw digest diff, branch 3 is
  re-scoped to `none`/`patch` only so both `minor` and `minor-rule-set`
  always reach the impact assessment regardless of digest state, and the
  comparator now cross-checks the supplied tier against the two input
  manifests' actual `resolver.version`/`rule_set_revision` difference,
  rejecting a mismatch as an argument error (exit 3) rather than silently
  trusting an assertion the manifests themselves contradict — a caller
  that misclassifies its own transition is a caller bug this feature
  should surface, not silently accept.
- **The three `--*-weakening` inputs are mandatory and three-valued, never
  expressed by flag omission (requirements.md REQ-004, Goals — a
  verification-round finding, extending "B2"'s fail-closed correction).**
  An earlier revision made `--projection-weakening`/`--registry-weakening`/
  `--ownership-weakening` optional CLI flags and let *omitting* a flag
  mean `indeterminate` for that axis, while also stating (inconsistently,
  elsewhere in the same revision) that a required-input contract applied
  and that an axis whose digest was unchanged "needs no verdict." Both of
  those readings undercut the same safety property "B2" established:
  optional flags mean a caller can accidentally under-specify an axis (a
  typo'd flag name, a caller that forgot one axis entirely) and get
  `indeterminate` — and therefore fail-closed Block — by *accident* rather
  than by a detector's actual absence, which is indistinguishable from a
  caller that deliberately, correctly reports "no detector for this axis."
  A comparator whose safety-critical input can be silently defaulted by a
  typo is not meaningfully fail-closed by design, only by coincidence.
  This revision makes all three flags required, with a genuine three-value
  enum (`weakened`/`not-weakened`/`indeterminate`) — a caller must state
  its position on every axis, every time, including an axis it knows is
  unchanged (`not-weakened`, by fixed convention, never a fourth "N/A"
  value this schema does not define) — and treats any omission as an
  argument error the comparator refuses to guess at, rather than a valid
  third way to spell `indeterminate`.
- **`compare-facet-manifest-staleness`'s stdout, exit-code, and error
  contracts are unified into one normative shape (design.md API / Contract
  Plan — a verification-round finding on stdout/exit/error-channel
  unification, closing a self-contradiction "B7" left standing).** An
  earlier revision's own API / Contract Plan fixed a `facet-manifest-
  staleness: <status>[:<reason>]` stdout line, while the *same revision's*
  AC-044 asserted a bare `fresh|stale|blocked` stdout contract with no
  `<reason>` — two normative sections of the same spec package disagreeing
  about the same script's own output shape, with no stated tie-breaker.
  Separately, the same revision defined `0`/`1`/`2` exit codes for the
  three verdicts but never said what a malformed invocation (a missing
  flag, an out-of-enum value, a schema-invalid manifest) should do —
  leaving an implementer to choose between crashing with a Python
  traceback, silently returning one of the three verdict codes for a
  non-verdict situation, or inventing an ad hoc convention no fixture
  could check. This revision resolves both gaps together, in the design
  document's favor for the stdout shape (mandatory `<reason>`, API /
  Contract Plan and AC-044 both now agree) and with a wholly new exit
  code for the error case: exit `3`, stderr-only, in the same
  `facet-manifest-staleness: <check-id>: <detail>` diagnostic style the
  other three scripts already use, with the verdict's stdout line entirely
  absent from an exit-3 invocation. Keeping the verdict channel (stdout,
  0/1/2) and the diagnostic channel (stderr, 3) disjoint — rather than,
  say, adding a fourth stdout status string like `error` — means a caller
  that only ever wants the coarse verdict can keep branching on exit code
  alone (API / Contract Plan's own stated design goal for the exit codes)
  without a new status value it has to explicitly ignore.
- **`conditional_facets[]` forbids two entries sharing one `facet` name,
  making its own by-`facet` sort a total order (requirements.md Edge
  Cases, AC-047 — closing a verification-round finding on total order).**
  An earlier revision left this case unrestricted, reasoning that two
  Capabilities legitimately disagreeing about a Facet's applicability is a
  real Resolver output shape. That reasoning is not wrong about the
  *domain* (two Capabilities' Predicate DSL evaluations over the same
  Facet name genuinely can disagree), but it left REQ-001's own by-`facet`
  stable-sort mandate for `conditional_facets` (Goals) without a defined
  tie-breaker whenever two entries actually did share a `facet` name — a
  lexicographic sort key that is not guaranteed unique is not a total
  order, and "the array is stable-sorted" becomes ambiguous, input-order-
  dependent behavior exactly in the case two Capabilities disagree. This
  revision resolves the tension in favor of the *schema's* soundness
  property, not the domain-modeling convenience: `conditional_facets[].
  facet` values must be unique (REQ-006's `conditional-facet-duplicate`
  check, AC-047), matching `resolved_gates[].id`'s own uniqueness rule
  (`resolved-gate-id-duplicate`) exactly. A Resolver that encounters two
  Capabilities disagreeing about one Facet must resolve that disagreement
  before emitting the Manifest (a future Epic A5 concern, not one this
  schema arbitrates) rather than writing two `conditional_facets[]` rows
  for the same `facet` and relying on array order to convey which one
  "wins."
- **`lite_eligibility.upgrade_reasons` is written sorted-and-unique,
  joining REQ-001's other stable-sort-mandated arrays (requirements.md
  Goals — closing the same total-order verification-round finding,
  AC-048).** An earlier revision made `upgrade_reasons` required (`[]`
  when empty, "M default") but never added it to the stable-sort-mandated
  array list, and never gave it `uniqueItems` at the schema level — two
  Facet Manifest instances differing only in `upgrade_reasons`' own
  element order (or one carrying a duplicate reason string the other
  doesn't) would compare unequal, or equal by accident depending on write
  order, under REQ-004's plain structural-equality comparator, which is
  exactly the input-order-dependent behavior the other stable-sort-
  mandated arrays already avoid. This revision adds `uniqueItems: true` to
  `upgrade_reasons`' own schema definition (API / Contract Plan,
  schema-expressible and therefore enforced there, not left to a REQ-006
  semantic check) and extends the `array-not-stable-sorted` semantic
  check's scope to include `upgrade_reasons`' own lexicographic order
  (sort order itself is not schema-expressible in draft-07, matching every
  other stable-sort-mandated array in this feature).

## Global Constraints

- Python scripts are stdlib-only — no `jsonschema` or other third-party
  dependency (INV-014, matching every existing `plugins/sdd-quality-loop/
  scripts/*.py`).
- No `.js` wrapper for any of the four new scripts — matching Epic A2's own
  precedent that only a hash-generation primitive (`generate-registry-
  digest`) needed cross-runtime `.js` parity for determinism verification,
  not a structural validator (`validate-capability-registry` shipped
  `.py`+`.sh`+`.ps1` only) — `compare-facet-manifest-staleness` is a
  comparator/classifier, not a digest primitive, so it follows the
  validator precedent, not the digest-generator one.
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
- All four scripts' diagnostic output follows the diagnostic determinism
  contract (API / Contract Plan, above): fixed `(check-id, JSON-Pointer-
  path)` sort order, RFC 6901 path representation, UTF-8/LF-only bytes on
  every runtime, and a fixed exit-code convention — this is what makes
  AC-031's byte-identical-parity claim actually checkable, not merely
  aspirational.

## Security Boundaries

See requirements.md Security Boundaries — this design introduces no new
trust boundary, no network access, no dynamic code execution, and no
credential handling in any of the four scripts (including `compare-facet-
manifest-staleness`, which reads only its two `--old-manifest`/
`--new-manifest` file arguments and its CLI flags, performs no
subprocess-of-its-own beyond the same canonicalizer invocation the YAML
parse contract already covers, and writes nothing).

## External Integrations

None. This feature has no dependency on any provider API, cloud service,
or external network resource — consistent with ADR-0018's provider-
neutrality boundary and this repository's "no external credential" ethos.

## Deployment / CI Plan

- CI (future, implementation phase): each validator script's schema-
  conformance check, and the comparator's fresh/stale/blocked exit code,
  are wired the same way Epic A2's `generate-gate-capabilities.py --check`
  is wired — a fixture-driven `tests/run-all.sh`/`.ps1` registration, not
  a standalone CI job of its own, since these are checks/comparisons over
  committed fixtures, not projections with a drift-detection mode.
- The vendoring step that refreshes `plugins/sdd-quality-loop/contracts/
  {facet-manifest,capability-summary,context-projection}.schema.json` from
  their canonical `contracts/` originals reuses Epic A2's already-CI-wired
  vendored-copy `--check` mode (Deployment / CI Plan,
  `specs/epic-190-a2-capability-registry/design.md`) — extended to cover
  three more filenames, not a new mechanism. (This feature adds three new
  schema *files*, not four — `compare-facet-manifest-staleness` has no
  schema of its own to vendor; it validates its two manifest inputs against
  the already-vendored `facet-manifest.schema.json`.)
- `scripts/bump-version.sh`'s existing release gate is unaffected; this
  feature adds no citation-residue or version-mutation surface of its own
  (REQ-008).

## Constraint Compliance

- 3-runtime parity (decision document v2 §7): all four scripts ship
  `.py`+`.sh`+`.ps1`, invoked from a Claude Code, Codex CLI, and Copilot
  CLI installed-plugin context in AC-031/AC-032's future test fixtures —
  matching every sibling epic's own 3-environment discipline. This feature
  adds no new UI or interviewer-facing surface, so Epic A0's "各Epicの3環
  境タスク" obligation (decision v2 §7) is fully discharged by script-level
  parity alone, with no separate skill/interviewer-integration task
  required.
- No new plugin (Design Decisions, Epic A2 precedent, INV-013): every new
  script lives under the existing `plugins/sdd-quality-loop/` plugin.

## Assumptions

See requirements.md Assumptions — this design is written against Epic A1's
canonicalizer (a stdout-bytes CLI, never a parsed-structure API, "M
canonicalizer API"), Epic A2's Registry schema and array-shaped Evidence
output ("M Evidence array"), and Epic A3's state-aware `--facet-manifest`
read contract exactly as those sibling specs currently state them, not
against a placeholder or an earlier revision's narrower reading.

## Open Questions

See requirements.md Open Questions (OQ-002) — Context Projection's
regeneration cadence is scoped to a future epic's implementation-time
decision and does not block this feature's own schema/validator design.
(OQ-001 is retired into Non-goals — requirements.md, investigation.md.)

## Risks

See requirements.md Risks (schema-drift risk, ambiguity-resolution risk —
now scoped to the `registry_digest --whole` binding and the fail-closed
Policy-Weakening contract, not the retired full-track-summary/evidence-
exclusion decisions — reserved-path risk) — each traces to a specific
Design Decision above, where the reasoning behind this feature's own
resolution is recorded for a future adversarial review to evaluate against
a stated rationale.
