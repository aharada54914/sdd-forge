# Requirements: epic-192-a4-facet-manifest

Spec-Review-Status: Pending
Source Issues: https://github.com/aharada54914/sdd-forge/issues/192,
https://github.com/aharada54914/sdd-forge/issues/187
Epic: https://github.com/aharada54914/sdd-forge/issues/187 (AI-DLC
Foundation tracking) — Epic A4 (Facet Manifest), issue #192, per
`docs/ai-dlc-foundation-decision-v2.md` §19 ("旧A5と順序入替": schema is
fixed before the Capability Resolver, Epic A5, is built)
Investigation: specs/epic-192-a4-facet-manifest/investigation.md
(INV-001..INV-018, OQ-001..OQ-002)

## Overview

`docs/ai-dlc-foundation-decision-v2.md` §19 sequences Epic A4 (Facet
Manifest) before Epic A5 (Capability Resolver) specifically so the shape of
the Resolver's output is fixed before the Resolver itself is built. Three
sibling epics already committed to concrete parts of that shape before this
spec exists: Epic A2 (Capability Registry, `Spec-Review-Status: Passed`)
fixed what a Facet Manifest resolves *from* (`required_facets`,
`conditional_facets`, `gate_ids`, `minimum_enforcement`, the Predicate DSL
and its Evidence shape); Epic A3 (Component Path Ownership) fixed the exact
read contract for `facet-manifest.affected_components`
(`--facet-manifest <path>`, a flat component-id list) as a **hard, already-
committed dependency** on this epic; and Epic A1 (Project Context) reserved
the Resolver script name and the Context Projection's generated-artifact
path as a protected, forced-handoff placeholder. This feature (Epic A4)
delivers: the Facet Manifest schema itself (REQ-001); the Capability
Summary schema and its lite/full relationship (REQ-002); the Context
Projection's canonical shape and the `dependency_pointers` JSON Pointer
contract (REQ-003); the staleness/"semantic output" comparison contract
(REQ-004, transcribing ADR-0021); the resolver-version policy (REQ-005,
transcribing ADR-0021 item 6); three deterministic schema-validation
scripts plus their fixtures and tests (REQ-006); the Manifest/Summary
storage location and naming convention (REQ-007); and the documentation/
versioning discipline every Foundation epic's tasks share (REQ-008).

This feature does **not** build the Capability Resolver, does not produce
any live Facet Manifest, Capability Summary, or Context Projection instance
for a real Feature, and does not implement Policy Weakening detection for
the Registry or ownership axes (Non-goals) — see Dependencies for exactly
which parts of Epics A1/A2/A3's own schemas this feature treats as fixed,
not renegotiable, inputs.

## Target Users

- **Epic A5 (Capability Resolver)**, the direct and primary consumer of
  every schema this feature defines — it is the epic that will actually
  write `resolve-project-context.{py,sh,ps1}` and whatever Facet-Manifest-
  generating script it introduces, against the contracts this feature
  fixes (decision document v2 §19 Epic A5).
- **Epic A3's `check-component-coverage`**, which already reads
  `facet-manifest.affected_components` via a structurally required
  `--facet-manifest <path>` flag (INV-006) and needs this feature's schema
  to land with the exact shape A3 already assumed, not a different one.
- **A human or agent reviewing a Feature's Facet Manifest** to understand
  why a Facet was or was not included, which Gates apply, and whether the
  Feature is stale relative to the current Project Context/Registry/
  ownership declarations — the audience the `evidence`/`reason` fields
  (REQ-001) and the `capability-summary.yaml` compact view (REQ-002) serve.
- **CI and any future Gate script** that needs to determine, deterministically
  and without re-running the Resolver, whether a committed Facet Manifest
  is even well-formed (REQ-006's validators) before trusting its content.
- **Maintainers extending this schema in a future epic** (e.g. a Registry-
  or ownership-scoped Policy Weakening detector, OQ-001's Capability
  Summary consumer) — Field Definitions and Design Decisions record *why*
  each field has the shape it has, not only what the shape is, so a later
  change can tell whether it is compatible or a breaking schema revision.

## Problems

- No Facet Manifest, Capability Summary, or Context Projection schema
  exists anywhere in this repository (INV-002) — Epic A5 cannot be
  specified, let alone built, against an undefined output shape, and Epic
  A3's already-landed `check-component-coverage` already depends on a
  field (`affected_components`) whose type is currently unfixed anywhere
  but a prose sentence in Epic A3's own Assumptions section.
- ADR-0021 fixes the `context_binding`/`resolver` block and the semantic-
  output *definition* precisely, but does not itself specify a testable
  comparison *algorithm*, does not specify which parts of a
  `conditional_facets[]` entry participate in that comparison (its
  `evidence` sub-tree is provenance detail the ADR never explicitly
  addresses), and does not specify field-level array-ordering rules needed
  to make "compare two Facet Manifests" a well-defined structural
  operation rather than a semantically-fuzzy one (Dependencies,
  ADR-0021 items 2-3).
- Decision document v2 §16's own prose ("Policy Weakening → 全影響Feature
  をBlock") reads as applying uniformly across the Context/Registry/
  ownership axes, but only 3 of ADR-0019's 9 named weakening categories are
  actually detected by any landed epic, and all 3 are Project-Context-
  scoped only (INV-012) — a schema/contract that silently assumes a
  Registry- or ownership-scoped weakening detector exists would describe a
  mechanism no epic currently builds, and would leave REQ-004's staleness
  contract unimplementable as literally written.
- Decision document v2 §6 fixes the Lite Capability Summary's exact field
  set but names Capability Summary as a fourth, distinct Epic A5 output
  even in the full track, without specifying what a full-track Capability
  Summary contains — an ambiguity that would otherwise reach Epic A5
  unresolved and force an implementation-time schema decision without
  spec-phase review (INV-010).
- No storage location or file-naming convention for a per-Feature Facet
  Manifest or Capability Summary exists; `specs/<feature>/` already holds
  seven- or four-file conventions (legacy-seven-layer, lite-three-file) but
  no precedent for a Resolver-generated, schema-validated artifact
  alongside them.

## Dependencies

- **Epic A1 (Project Context) — schema shape and canonicalizer (hard,
  already-committed dependencies)**: this feature's `context_binding`
  fields (`full_context_revision`, `projection_sha256`) and REQ-003's
  Context Projection re-keying step are sound only because Epic A1 already
  fixes `contracts/project-context.schema.json`'s top-level shape
  (`schema`/`workflow`/`components`/`shared_paths`) and enforces
  `components[].id` uniqueness at content-validation time, not schema time
  (INV-009, M18). This feature does not redefine, and must not contradict,
  that schema. REQ-003's canonicalization procedure is Epic A1's
  `canonicalize-sdd-yaml.py` applied twice (raw YAML pass, then a second
  JSON-input pass over the re-keyed structure) — the exact two-pass pattern
  Epic A1's own HMAC preimage construction already establishes as
  precedent (INV-008) — never a reimplementation of JCS or YAML 1.2
  parsing. **This feature's REQ-003 is blocked until Epic A1's
  canonicalizer contract is finalized**, matching Epic A2's own REQ-004
  dependency statement on the same canonicalizer.
- **Epic A1's reserved Resolver/Context-Projection paths (hard dependency,
  binding on naming, not on building)**: `plugins/sdd-quality-loop/
  scripts/resolve-project-context.{py,sh,ps1}` and `plugins/sdd-quality-
  loop/scripts/generated/project-context.resolved.json` are already
  reserved, protected-suffix-shaped placeholders in `guard-invariants.json`
  (INV-007). REQ-003 fixes Context Projection's schema *at that exact
  reserved path* — it does not propose an alternative path, and it does
  not build the generator (Epic A5 does; Non-goals).
- **Epic A2 (Capability Registry) — schema shape (hard, already-`Passed`
  dependency)**: `contracts/capability-registry.schema.json`'s
  `capabilities[]`/`gates[]` shapes (`required_facets`, `conditional_facets`,
  `gate_ids`, `minimum_enforcement`, `lite_policy`, `stage`, `blocking`)
  and the shared `#/definitions/predicate`/Evidence JSON Schema (INV-004,
  INV-005) are the fixed vocabulary REQ-001's `required_facets`,
  `conditional_facets`, `resolved_gates`, and `capability_minimum_
  enforcement` fields resolve into. This feature introduces no new Gate-
  stage enum value, no new predicate operator, and no new Evidence shape —
  it structurally reuses Epic A2's, by reference (Field Definitions).
- **Epic A3 (Component Path Ownership) — read contract on
  `affected_components` (hard, reverse dependency)**: Epic A3's
  `check-component-coverage` already ships (in its own, currently-Pending
  spec) a `--facet-manifest <path>` flag whose Fail-2/Fail-4 conditions
  read `facet-manifest.affected_components` as a flat, component-id-keyed
  list (INV-006). REQ-001 must produce exactly that shape; a nested or
  differently-typed `affected_components` would be a breaking change to an
  already-specified sibling epic, not merely an internal Epic A4 choice.
- **ADR-0021 (Context Projection Staleness) and ADR-0020 (Conditional
  Predicate DSL)** are Accepted, not proposed by this feature; REQ-004/
  REQ-005 transcribe them into testable schema/comparison contracts and
  close two gaps ADR-0021 leaves implicit (whether `evidence` participates
  in the semantic-output comparison; array-ordering determinism) rather
  than re-deciding anything ADR-0021 already fixed.
- **ADR-0019 (Approval Sidecar Protection) — Policy Weakening category
  scope (hard dependency, scope-narrowing)**: only 3 of ADR-0019's 9 named
  weakening categories are live in Epic A1's schema; the other 6 are
  `const: "n/a"`, reserved (INV-012). REQ-004 depends on this fact to scope
  its own Policy-Weakening-short-circuit clause correctly; it is not a
  choice this feature is free to make differently.

## Goals

- **REQ-001** (Facet Manifest schema — decision v2 §19 item 1, §16, §12):
  Define `contracts/facet-manifest.schema.json` (JSON Schema draft-07,
  matching every existing `contracts/*.schema.json`'s `$schema`/`$id`
  convention, INV-014) fixing every field decision document v2 §16/§12 and
  ADR-0021 name: `schema` (`const: "sdd-facet-manifest/v1"`), `feature`
  (string, `^[a-z0-9][a-z0-9-]*$`, matching
  `workflow-state-registry.schema.json`'s `feature` pattern), `affected_
  components` (array of unique component-id strings — INV-006's exact flat
  shape, `additionalItems` forbidden, no nested object), `required_facets`
  (array of unique facet-name strings), `conditional_facets` (array of
  `{facet, applied (boolean), reason (required iff `applied == false`,
  forbidden iff `applied == true` — schema-level `if`/`then`, matching
  Epic A2's own `exists`-operator `if`/`then` pattern), evidence (Epic A2's
  Evidence JSON Schema, embedded by structural reference, INV-004)}`),
  `resolved_gates` (array of `{id, stage (enum: implementation/artifact/
  promotion, copy-consistent with `gates[].stage`), blocking (boolean)}`),
  `capabilities` (array of unique resolved Capability-id strings),
  `capability_minimum_enforcement` (optional; `const: "required"` only, no
  other value — matching Epic A2's own `minimum_enforcement` field exactly,
  Field Definitions explains why this is *not* the full "effective
  enforcement" of decision v2 §10), `lite_eligibility` (`{eligible
  (boolean, required), upgrade_reasons (array of strings, default `[]`)}`,
  matching the per-Capability `lite_policy` shape but representing the
  Feature-level aggregate), `context_binding` (`{full_context_revision,
  dependency_pointers, projection_sha256, registry_digest,
  ownership_digest}`, verbatim from ADR-0021), and `resolver`
  (`{version, rule_set_revision}`, verbatim from ADR-0021). Every array
  REQ-001 defines that participates in semantic-output comparison
  (`affected_components`, `required_facets`, `conditional_facets`,
  `resolved_gates`, `capabilities`) MUST be written stable-sorted
  (lexicographic by id/facet-name/component-id) before serialization — the
  same fragment-sort discipline Epic A2's `generate-registry-digest`
  already established (INV-005) — so Resolver purity (ADR-0020 item 6)
  extends to array order, not only set membership, and REQ-004's
  comparison can be a plain structural-equality check rather than a
  defensively-re-sorting one.
- **REQ-002** (Capability Summary schema — decision v2 §6, §19): Define
  `contracts/capability-summary.schema.json` with a `track` discriminator
  (`enum: ["lite","full"]`) and a schema-level `if`/`then`/`else` on that
  discriminator: when `track == "lite"`, require exactly decision v2 §6's
  fields (`capabilities`, `required_lite_checks`, `full_upgrade_required`);
  when `track == "full"`, require `capabilities` plus a `facet_manifest_
  ref` object (`{path, sha256}`) pointing back at this Feature's own
  `facet-manifest.yaml` (design.md Design Decisions records the reasoning:
  a full-track Capability Summary is a compact, capability-set-only
  companion to the Facet Manifest, never a duplicate of its facet-level
  reasoning — INV-010/OQ-001). `capabilities` is required and shaped
  identically (array of unique strings) in both tracks.
- **REQ-003** (Context Projection canonical shape — decision v2 §19 item 1
  "context projection hash", §18.3, ADR-0021's `dependency_pointers`):
  Define `contracts/context-projection.schema.json` for the artifact at
  Epic A1's already-reserved path,
  `plugins/sdd-quality-loop/scripts/generated/project-context.resolved.json`
  (INV-007): `{schema (const "sdd-context-projection/v1"), source_sha256
  (project-context.yaml's own canonical-form sha256, equal to
  context_binding.full_context_revision), provider_bindings_sha256
  (optional), workflow (verbatim from project-context.yaml), components
  (object, re-keyed from project-context.yaml's `components[]` array by
  each entry's own `id`, `id` itself omitted since it is now the key),
  shared_paths (array, as-is, addressed by numeric RFC 6901 index)}`.
  Fix the generation procedure (for Epic A5 to implement, not for this
  feature to build): canonicalize `project-context.yaml` via `canonicalize-
  sdd-yaml` (YAML input mode) to obtain its NFC-normalized parsed
  structure; re-key `components[]` into the `id`-keyed object (sound only
  because Epic A1 already guarantees `id` uniqueness upstream, INV-009);
  feed the transformed structure back through `canonicalize-sdd-yaml` a
  second time (JSON input mode) to obtain final JCS-canonical bytes, whose
  sha256 is `projection_sha256`. Fix `dependency_pointers` as RFC 6901 JSON
  Pointer strings addressing into this re-keyed projection (e.g.
  `/components/desktop-client/artifact_kinds`,
  `/workflow/capability_enforcement` — decision v2 §16's own literal
  examples are both valid, unmodified RFC 6901 pointers against this
  specific re-keyed shape, which is exactly why the re-keying step is
  required: a raw, un-re-keyed `components[]` array has no RFC-6901-
  addressable key named `desktop-client`). Each pointer's first path
  segment MUST be one of `workflow`, `components`, or `shared_paths` (the
  three non-`schema` top-level Project Context keys, INV-009) — this is a
  narrower, structurally-derived allowlist-root check, not the DSL's own
  8-field predicate allowlist (ADR-0020 item 5), and Field Definitions
  states explicitly that these are two different, non-substitutable scopes.
- **REQ-004** (stale detection contract — decision v2 §16, ADR-0021 items
  2-4): Fix **semantic output**, closed and field-enumerated (not merely
  prose), as exactly: `affected_components`, `required_facets`,
  `conditional_facets` compared on `{facet, applied, reason}` **only**
  (`evidence` is explicitly excluded — Field Definitions states this is a
  deliberate closing of a gap ADR-0021's prose leaves implicit, reasoning
  by analogy to `context_binding`/`resolver` being "binding/provenance
  metadata, not output"), `resolved_gates`, `capability_minimum_
  enforcement`, `capabilities`, and `lite_eligibility` — i.e. every REQ-001
  field **except** `schema`, `feature`, `context_binding`, and `resolver`.
  Fix the comparison as field-by-field structural equality over two Facet
  Manifest instances (old vs. new), safe as a plain equality check because
  REQ-001 already mandates stable-sorted arrays. Fix the **Policy
  Weakening short-circuit**, correctly scoped per INV-012: when Epic A1's
  Project-Context-scoped weakening detector (the 3 live categories) reports
  `weakening_verdict.policy_weakening: true` for the transition a Feature's
  `context_binding.full_context_revision` is bound to, that Feature is
  Blocked unconditionally (no semantic-output comparison is even
  attempted) and requires re-approval and re-resolve, per ADR-0021 item 3.
  For a `registry_digest` or `ownership_digest` change, **no** weakening-
  style short-circuit applies — every such change goes through the
  ordinary re-run-and-compare-semantic-output path, because no epic in
  this Foundation's current scope builds Registry- or ownership-scoped
  weakening detection (INV-012, explicitly closing an ambiguity decision
  document v2 §16's prose leaves open). Unchanged digests → continue,
  WARN-only. Changed digest(s), unchanged semantic output → metadata-only
  refresh, not stale. Changed digest(s), changed semantic output →
  selectively stale for that Feature only.
- **REQ-005** (resolver version policy — decision v2 §18.2, ADR-0021 item
  6): Fix the three-way `resolver.version` semver-component rule verbatim:
  **patch** → no regeneration required when semantic output is unchanged;
  **minor** → run the REQ-004 impact assessment, stale only if semantic
  output changes; **major** → mandatory re-resolve for every Feature that
  used the affected Resolver version, regardless of whether semantic
  output would change (the one case that skips the semantic-output
  comparison entirely, INV-011). `resolver.version` is schema-validated as
  a three-component semver string (`^\d+\.\d+\.\d+$`); `rule_set_revision`
  is a `sha256:<hex>` digest.
- **REQ-006** (schema validation scripts, fixtures, tests — decision v2
  §19 item "schema"): Design three deterministic, stdlib-only-Python-
  master-plus-`sh`/`ps1`-wrapper scripts under
  `plugins/sdd-quality-loop/scripts/`: `validate-facet-manifest.{py,sh,
  ps1}`, `validate-capability-summary.{py,sh,ps1}`, `validate-context-
  projection.{py,sh,ps1}` (no `.js` wrapper — these are structural
  validators, not cross-runtime-hashed digest primitives, matching Epic
  A2's own `validate-capability-registry`/`generate-gate-capabilities`
  precedent of `.py`+`.sh`+`.ps1` only, INV-018). Each validates its
  target instance's schema conformance plus a small, closed set of
  semantic checks not expressible in JSON Schema draft-07 alone (Field
  Definitions/design.md enumerate the exact check-id table per script,
  mirroring `validate-capability-registry.py`'s `registry: <check-id>:
  <detail>` diagnostic style). Each script locates its `contracts/*`
  artifact via Epic A2's already-fixed script-relative-then-git-root-
  fallback discovery contract (INV-018) — no new discovery algorithm is
  invented. Author `tests/*.tests.sh`+`.tests.ps1` pairs and fixture data
  under `tests/fixtures/facet-manifest/` covering schema-conformance
  positive/negative fixtures per required field, each REQ-006 semantic
  check's positive/negative fixture, REQ-004's semantic-output comparison
  (unchanged/changed-metadata-only/changed-and-stale/major-version-forced
  cases), REQ-005's three version-bump tiers, and REQ-003's `dependency_
  pointers` allowlist-root and RFC-6901-well-formedness checks. Every new
  suite is registered in `tests/run-all.sh`/`.ps1` directly (unprotected,
  matching INV-018's precedent) and staged for `.github/workflows/test.yml`
  registration via human-copy (protected, matching INV-018's precedent for
  CI-registration edits specifically, not for the validator scripts
  themselves, which this feature does not protect — Protected-File
  Statement, design.md).
- **REQ-007** (Manifest/Summary storage location and naming — decision v2
  §19 item "Manifest の保存場所・命名"): Fix `specs/<feature>/facet-
  manifest.yaml` and `specs/<feature>/capability-summary.yaml` as the
  per-Feature storage location, directly alongside `requirements.md`/
  `design.md`/etc. — the exact naming/placement decision document v2 §6
  already fixes for the lite-track `capability-summary.yaml` (INV-010),
  extended consistently to the full track and to the new `facet-manifest.
  yaml` sibling (Design Decisions records why `.yaml`, not `.json`, is
  chosen for a Resolver-*generated* artifact: for git-diff-reviewability by
  a human reading a PR, the same reason `project-context.yaml`/`provider-
  bindings.yaml` are YAML despite also being schema-validated machine
  artifacts, and RFC 8785/YAML-1.2-core canonicalization applies uniformly
  regardless of source format so this choice carries no cross-runtime-
  hashing cost). Both files are unprotected, per-Feature, agent-writable-
  only-via-the-Resolver artifacts (Protected-File Statement) — never
  hand-edited, the same convention `tasks.md` establishes for a different
  generated-then-reviewed artifact class.
- **REQ-008** (documentation/versioning discipline — matching every
  sibling epic's own REQ, e.g. Epic A3 REQ-008): every implementation task
  this spec's future task phase schedules lands its own `CHANGELOG.md`
  `## Unreleased` entry citing #192; no new ADR is authored (ADR-0020/
  ADR-0021 already normatively cover this feature's entire staleness/DSL
  surface, Non-goals); a grep-based self-check confirms no version string
  is mutated anywhere in this feature's diff outside a
  `scripts/bump-version.sh` invocation, matching Epic A3's own AC-049
  precedent.

## Non-goals

- Building the Capability Resolver (Epic A5) or producing any live Facet
  Manifest, Capability Summary, or Context Projection instance for a real
  Feature — this feature ships schemas, a canonicalization/re-keying
  *procedure* description, and validators that check conformance against
  hand-authored fixtures, never a generator.
- Implementing `resolve-project-context.{py,sh,ps1}` — Epic A1 reserved
  this name/path (INV-007); this feature fixes only what the file it
  eventually produces must contain (REQ-003).
- Implementing a Registry- or ownership-scoped Policy Weakening detector —
  REQ-004 explicitly scopes the weakening short-circuit to the 3 currently-
  live, Project-Context-scoped categories only (INV-012); building
  detection for any of ADR-0019's other 6 named-but-reserved categories is
  a future epic's own spec.
- Modifying `contracts/capability-registry.schema.json`,
  `contracts/project-context.schema.json`,
  `contracts/approval-sidecar.schema.json`, or any other Epic A1/A2/A3
  contract file — this feature only *reads* their already-fixed shapes
  (Dependencies) and adds three wholly new contract files of its own.
- Authoring a new ADR — ADR-0020 and ADR-0021 already normatively cover
  this feature's DSL-reuse and staleness surface; this feature transcribes
  them into schemas and testable contracts, it does not re-decide them.
- Deciding *when* Context Projection is regenerated (CI cadence,
  on-demand, etc. — OQ-002) or which future consumer reads a full-track
  Capability Summary (OQ-001) — both are Epic A5-or-later wiring decisions
  this feature's schema work does not need to resolve to be complete.
- Running `spec-review-loop`/`impl-review-loop` against this package, or
  authoring `tasks.md`/`traceability.md` — this spec package is Phase 1
  only (`Spec-Review-Status: Pending`, `Impl-Review-Status: Pending`,
  INV-015); Phase 2 artifacts are authored after both reviews pass.

## User Stories

- As Epic A5's implementer, I need `contracts/facet-manifest.schema.json`
  and `contracts/context-projection.schema.json` to already exist and be
  internally consistent with Epic A1/A2/A3's already-landed schemas, so
  that building the Resolver is a matter of implementing a fixed contract,
  not making schema decisions mid-implementation.
- As Epic A3's `check-component-coverage`, I need `affected_components` to
  be exactly the flat, component-id-keyed list my own spec already assumed
  (INV-006), so that my already-`Pending` spec's Dependencies section
  resolves cleanly rather than requiring a retroactive edit.
- As a reviewer reading a Facet Manifest for a Feature I did not resolve
  myself, I need `conditional_facets[].reason` and `.evidence` to tell me
  *why* a Facet was or was not applied, and `resolved_gates` to tell me
  exactly which Gates block my Task, without needing to re-run the
  Resolver or read the Registry myself.
- As a maintainer investigating why a Feature suddenly shows Stale, I need
  REQ-004's semantic-output definition to be precise enough that I can
  determine, by inspecting two committed Facet Manifest revisions, exactly
  which field changed and therefore why staleness fired — not merely that
  "something in Context/Registry/ownership changed."
- As the schema-validation script's caller (CI or a human), I need a
  single deterministic command (`validate-facet-manifest.py --manifest
  <path>`) that tells me, with a stable diagnostic id, whether a committed
  Facet Manifest is well-formed, before I trust any Gate or reviewer
  reasoning built on top of it.

## Acceptance Criteria

- AC-001 (REQ-001): `contracts/facet-manifest.schema.json` exists, is valid
  JSON Schema draft-07, and its `$id` follows the exact convention every
  other `contracts/*.schema.json` in this repository already uses
  (INV-014).
- AC-002 (REQ-001): The schema's `required` list at the top level is
  exactly `["schema","feature","affected_components","required_facets",
  "conditional_facets","resolved_gates","capabilities","lite_eligibility",
  "context_binding","resolver"]`; `capability_minimum_enforcement` is the
  only top-level optional field, and its absence is schema-valid (a
  Feature whose resolved Capabilities carry no `minimum_enforcement` at
  all).
- AC-003 (REQ-001): `affected_components`, `required_facets`, and
  `capabilities` are each `{"type":"array","items":{"type":"string"},
  "uniqueItems":true}`; a fixture with a duplicate entry in any of the
  three is rejected; a fixture with `[]` in any of the three is accepted
  (an edge case, not an error — Edge Cases).
- AC-004 (REQ-001): `conditional_facets[]` items are
  `additionalProperties: false` with `required: ["facet","applied",
  "evidence"]`; a schema-level `if`/`then` requires `reason` present and
  non-empty when `applied == false`, and a second `if`/`then` (or a
  `not: {required: ["reason"]}` under the `applied == true` branch)
  rejects `reason`'s presence when `applied == true`; both branches have a
  positive and a negative fixture.
- AC-005 (REQ-001): `conditional_facets[].evidence` validates against Epic
  A2's own Evidence JSON Schema, embedded verbatim (by `$ref` to a local
  copy or by structural duplication with an explicit provenance comment
  citing `specs/epic-190-a2-capability-registry/design.md`'s "Predicate
  DSL evaluator contract" section — design.md fixes which); a fixture
  using an `operator` value outside Epic A2's fixed 8-operator enum is
  rejected.
- AC-006 (REQ-001): `resolved_gates[]` items are `{id (string, same
  pattern as Epic A2's `gates[].id`), stage (enum: implementation/
  artifact/promotion), blocking (boolean)}`, `additionalProperties:
  false`, all three required; a fixture with a `stage` value outside the
  three-value enum is rejected.
- AC-007 (REQ-001): `capability_minimum_enforcement`, when present, is
  `const: "required"` — no other value validates; a fixture with any other
  string value is rejected; a fixture with the field entirely absent is
  accepted.
- AC-008 (REQ-001): `lite_eligibility` is `{eligible (boolean, required),
  upgrade_reasons (array of non-empty strings, default `[]`)}`,
  `additionalProperties: false`; a fixture missing `eligible` is rejected;
  a fixture with `upgrade_reasons` absent defaults to `[]` and is accepted.
- AC-009 (REQ-001): `context_binding` is `{full_context_revision,
  projection_sha256, registry_digest, ownership_digest: each
  "^sha256:[0-9a-f]{64}$", dependency_pointers: array of RFC-6901-pattern
  strings with `minItems: 1`}`, all five required, `additionalProperties:
  false`; a fixture with any digest field in a non-`sha256:<64-hex>` shape
  is rejected; a fixture with `dependency_pointers: []` is rejected
  (minItems violation).
- AC-010 (REQ-001): `resolver` is `{version: "^\d+\.\d+\.\d+$",
  rule_set_revision: "^sha256:[0-9a-f]{64}$"}`, both required,
  `additionalProperties: false`; a fixture with a two-component version
  string (e.g. `"1.1"`) is rejected.
- AC-011 (REQ-001): A fixture representing decision document v2 §16's own
  literal `context_binding`/`resolver` example
  (`full_context_revision: sha256:...`, `dependency_pointers:
  [/components/desktop-client/artifact_kinds,
  /workflow/capability_enforcement]`, `resolver.version: 1.1.0`) validates
  successfully against `contracts/facet-manifest.schema.json` once
  embedded in an otherwise-minimal-valid Facet Manifest — proving this
  schema does not silently diverge from the decision document's own
  worked example.
- AC-012 (REQ-002): `contracts/capability-summary.schema.json` exists,
  `track` is `enum: ["lite","full"]` and required; a schema-level `if`/
  `then`/`else` on `track` enforces `required_lite_checks`+`full_upgrade_
  required` present-and-required only when `track == "lite"`, and
  `facet_manifest_ref` present-and-required only when `track == "full"`;
  `capabilities` is required in both branches.
- AC-013 (REQ-002): A fixture matching decision document v2 §6's literal
  example (`capabilities: [desktop-local]`, `required_lite_checks: [build,
  test, installer-dry-run]`, `full_upgrade_required: false`) validates
  successfully once `track: lite` and `schema` are added (the two fields
  this schema adds beyond decision v2's own prose example, since v2's
  example predates this feature's `schema`/`track` discriminator).
- AC-014 (REQ-002): A `track: full` fixture with `facet_manifest_ref:
  {path: "specs/<feature>/facet-manifest.yaml", sha256: "sha256:..."}`
  validates; a `track: full` fixture carrying `required_lite_checks` (a
  lite-only field) is rejected by the `if`/`then`/`else`'s `else`-branch
  `additionalProperties: false`.
- AC-015 (REQ-003): `contracts/context-projection.schema.json` exists;
  `components` is `type: object` with `patternProperties` keyed on the
  same `id` pattern REQ-001/Epic A2 already use
  (`^[a-z0-9][a-z0-9-]*$`), each value shaped identically to Epic A1's
  `components[]` item minus the now-redundant `id` field; a fixture
  representing a raw `project-context.yaml` with two components,
  transformed per REQ-003's procedure, produces an object with exactly two
  keys equal to those components' `id` values, and each value's own `id`
  key is absent (proving the re-keying step, not merely a copy).
- AC-016 (REQ-003): A fixture where `dependency_pointers` contains
  `/components/desktop-client/artifact_kinds` (decision document v2 §16's
  own example) resolves, via RFC 6901 pointer resolution, to a real value
  inside a fixture Context Projection instance shaped per AC-015 — an
  end-to-end proof the re-keyed shape is what the decision document's own
  pointer syntax actually requires, not merely schema-shape-compatible by
  coincidence.
- AC-017 (REQ-003): A `dependency_pointers` entry whose first path segment
  is not one of `workflow`/`components`/`shared_paths` (e.g.
  `/schema` or `/nonexistent`) is rejected by REQ-006's validator with a
  named diagnostic (`dependency-pointer-root-not-allowlisted`) — a schema-
  level `pattern` alone cannot express this (it constrains syntax, not the
  first-segment vocabulary), so this is one of REQ-006's semantic (not
  pure-schema) checks.
- AC-018 (REQ-003): A `dependency_pointers` entry that is syntactically
  malformed RFC 6901 (e.g. `components/desktop-client` with no leading
  `/`, or containing an unescaped bare `~`) is rejected — this one *is*
  expressible via the schema's own `pattern` keyword on
  `dependency_pointers[].items`, and AC-018's fixture is a pure schema-
  level rejection, distinct from AC-017's semantic-level one.
- AC-019 (REQ-004): A fixture pair of Facet Manifest instances differing
  only in `context_binding.registry_digest` (all other fields, including
  every REQ-004-scoped semantic-output field, byte-identical) is classified
  by the design's documented comparison contract as **not stale**
  (metadata-only refresh) — the direct AC-021-of-ADR-0021 analog this
  feature's own contract must reproduce.
- AC-020 (REQ-004): A fixture pair differing in `context_binding.registry_
  digest` **and** in `resolved_gates[]`'s `blocking` value for a gate whose
  `id` is unchanged (ADR-0021 item 2's explicit "stage/blocking changes on
  the same gate ID" clause) is classified as **stale** — proving the
  comparison contract implements ADR-0021's specific same-ID/changed-
  attribute clause, not merely a naive set-membership diff over gate IDs.
- AC-021 (REQ-004): A fixture pair differing only in `conditional_facets[
  ].evidence` (identical `facet`/`applied`/`reason` for every entry) is
  classified as **not stale** — the fixture that proves REQ-004's
  explicit, closed-gap decision to exclude `evidence` from semantic-output
  comparison (Goals/Field Definitions) is actually implemented, not merely
  documented.
- AC-022 (REQ-004): A fixture pair differing only in `capability_minimum_
  enforcement` going from absent to `"required"` (a tightening, ADR-0021
  item 2's explicit minimum-enforcement-tightening clause) is classified
  as **stale**.
- AC-023 (REQ-004): A fixture representing an Epic-A1-reported
  `weakening_verdict.policy_weakening: true` transition short-circuits to
  Block **without** evaluating the semantic-output comparison at all (a
  fixture whose semantic-output fields are, deliberately, byte-identical
  old-vs-new still results in Block, proving the short-circuit precedes,
  and does not depend on, the comparison outcome).
- AC-024 (REQ-004): A fixture representing a `registry_digest` change with
  no corresponding Epic-A1 weakening verdict (the ordinary case, since no
  Registry-scoped weakening detector exists, INV-012) goes through the
  ordinary semantic-output comparison path, never the Block short-circuit
  — even when the underlying Registry edit would, informally, "look like"
  a weakening (e.g. a `minimum_enforcement` field being removed from a
  Capability) — proving REQ-004's scope-narrowing decision (Goals) is
  actually implemented as a hard boundary, not a judgment call left to the
  comparator.
- AC-025 (REQ-005): A `resolver.version` patch-only bump (e.g. `1.1.0` →
  `1.1.1`) with byte-identical semantic output requires no regeneration
  (no Stale marking, no forced re-resolve) — a positive fixture proving the
  patch tier's "no-op when unchanged" behavior.
- AC-026 (REQ-005): A `resolver.version` minor bump (e.g. `1.1.0` →
  `1.2.0`) triggers the REQ-004 impact assessment and is marked Stale only
  when semantic output actually changed as part of that assessment — a
  fixture pair proving both the changed and unchanged sub-cases.
- AC-027 (REQ-005): A `resolver.version` major bump (e.g. `1.1.0` →
  `2.0.0`) forces every Feature that used the affected Resolver version to
  re-resolve, even in a fixture where semantic output is otherwise
  byte-identical — proving the major tier skips the semantic-output
  comparison entirely (INV-011), not merely makes staleness more likely.
- AC-028 (REQ-006): `validate-facet-manifest.py --manifest <path>` exits 0
  on a fully schema-conformant, semantically-consistent fixture, and
  non-zero with a `facet-manifest: <check-id>: <detail>` diagnostic line
  (matching `validate-capability-registry.py`'s own diagnostic style,
  INV-005/design.md) for each of: schema-invalid, `resolved-gate-id-
  duplicate` (two `resolved_gates[]` entries sharing an `id`),
  `facet-classification-conflict` (a facet name present in both
  `required_facets` and `conditional_facets`), and `dependency-pointer-
  root-not-allowlisted` (AC-017's check).
- AC-029 (REQ-006): `validate-capability-summary.py --summary <path>`
  exits 0 on both a valid `track: lite` and a valid `track: full` fixture,
  and non-zero on a fixture mixing lite-only and full-only fields (AC-014).
- AC-030 (REQ-006): `validate-context-projection.py --projection <path>`
  exits 0 on a valid re-keyed fixture and non-zero on a fixture where
  `components` is still array-shaped (not re-keyed) — proving the
  validator actually enforces the re-keying transform, not merely generic
  JSON-Schema `type: object` conformance.
- AC-031 (REQ-006): All three scripts' `.py`/`.sh`/`.ps1` wrapper
  invocations produce identical exit codes and identical diagnostic
  output for every fixture in the suite (dual/triple-runtime parity,
  matching Epic A2's own parity discipline, INV-018).
- AC-032 (REQ-006): Each script's discovery contract, when only the
  script-relative packaged copy of its `contracts/*` artifact is present
  (no monorepo `contracts/`, no reachable `.git`), still resolves and
  validates correctly — one fixture per script per runtime, matching Epic
  A2's own three-fixture, per-runtime discovery proof (INV-018).
- AC-033 (REQ-006): Every new `tests/*.tests.sh`/`.tests.ps1` pair this
  feature adds is registered in `tests/run-all.sh`/`.ps1` directly; the
  corresponding `.github/workflows/test.yml` registration is staged under
  `specs/epic-192-a4-facet-manifest/human-copy/` (a Phase 2 artifact,
  scheduled by this feature's future `tasks.md`, not committed by this
  spec-phase package).
- AC-034 (REQ-007): A fixture directory tree with `specs/<feature>/
  facet-manifest.yaml` and `specs/<feature>/capability-summary.yaml`
  present alongside `requirements.md`/`design.md`/`acceptance-tests.md`
  passes `check-sdd-structure.sh`'s repository-root-level checks unchanged
  (neither file's presence or absence affects that script's per-repo-root
  required-item list, INV-016) — proving REQ-007's placement introduces no
  regression against an already-fixed validator.
- AC-035 (REQ-008): a grep-based self-check confirms no version string is
  mutated anywhere in this feature's diff outside a
  `scripts/bump-version.sh` invocation (matching Epic A3's AC-049); no new
  `docs/adr/00NN-*.md` file is added by this feature's future tasks
  (Non-goals).
- AC-036 (Global): This spec package's own `requirements.md` carries
  `Spec-Review-Status: Pending`, `design.md` carries `Impl-Review-Status:
  Pending`, and no `tasks.md`/`traceability.md` file exists in this
  Feature's directory — `check-workflow-state.sh`, run against the live
  registry with `--feature epic-192-a4-facet-manifest`, exits 0
  (INV-015).
- AC-037 (Global): `check-sdd-structure.sh`, run without a feature
  argument (`sh scripts/check-sdd-structure.sh .`), exits 0 after this
  feature's registration commit (INV-016).
- AC-038 (Global): `specs/workflow-state-registry.json`'s new entry for
  `epic-192-a4-facet-manifest` is exactly `{"feature":
  "epic-192-a4-facet-manifest", "profile": "full"}` — no additional keys —
  and the file continues to validate against
  `contracts/workflow-state-registry.schema.json` (INV-017).

## Field Definitions

- **Facet Manifest**: the per-Feature artifact at `specs/<feature>/
  facet-manifest.yaml`, schema `sdd-facet-manifest/v1`. Its content, minus
  `schema`/`feature`/`context_binding`/`resolver`, is exactly ADR-0021's
  "semantic output" (REQ-004).
- **Capability Summary**: the per-Feature artifact at `specs/<feature>/
  capability-summary.yaml`, schema `sdd-capability-summary/v1`, `track`-
  discriminated between the lite track (decision v2 §6's own shape) and
  the full track (this feature's own, explicitly-scoped decision, INV-010/
  OQ-001).
- **Context Projection**: the single, repository-wide (not per-Feature)
  generated artifact at `plugins/sdd-quality-loop/scripts/generated/
  project-context.resolved.json` (Epic A1's reserved path, INV-007),
  schema `sdd-context-projection/v1` — a canonicalized, RFC-6901-
  addressable re-keying of the *current* `project-context.yaml` (and
  optionally `provider-bindings.yaml`), never a per-Feature filtered
  subset.
- **`context_binding.dependency_pointers`**: RFC 6901 JSON Pointer strings
  addressing into the Context Projection (never into raw
  `project-context.yaml`, which is not reliably RFC-6901-addressable
  because `components[]` is an array with no stable per-item key until
  Context Projection's own re-keying step runs, REQ-003). Distinct in
  scope from ADR-0020's DSL field allowlist: the DSL allowlist constrains
  which *fields* a `when`/`trigger` predicate may compare against;
  `dependency_pointers` records every Project-Context input the Resolver
  *actually consulted* for any reason, a broader and structurally
  different concept that only shares the same three top-level roots
  (`workflow`/`components`/`shared_paths`) by virtue of both being scoped
  to Project Context, not by definitional identity.
- **`capability_minimum_enforcement`**: the `max()` of every resolved
  Capability's `minimum_enforcement` field (Epic A2 schema) — i.e. "the
  Registry-derived input to the effective-enforcement computation"
  (ADR-0021 item 2's own phrase). This is deliberately **not** decision
  document v2 §10's full `effective enforcement = max(approved project
  policy, capability minimum, runtime override)` — the other two terms
  (`workflow.capability_enforcement`, a runtime CLI/env override) are not
  Resolver inputs bound at resolve time (a runtime override in particular
  can vary per-invocation, independent of any Facet Manifest snapshot),
  so the Facet Manifest binds only the term that *is* a Resolver output;
  the full effective-enforcement computation happens downstream, at Gate-
  execution time, combining this field with the other two axes.
- **`na_facets` (deliberately not a separate top-level field)**: ADR-0021
  item 2 says "the resolved required/conditional facets, their N/A
  reasons" — this feature reads "their" as belonging to the facets
  themselves, not a second, independently-maintained list, and therefore
  folds N/A reasoning directly into `conditional_facets[].reason`
  (present iff `applied == false`) rather than introducing a parallel
  `na_facets[]` array that could drift out of sync with `conditional_
  facets[]`'s own `applied` value. `required_facets` entries are never
  N/A by construction: a `required_facets` entry only exists in the
  Manifest because its owning Capability's `trigger` matched (a Capability
  whose trigger does not match contributes none of its facets, required or
  conditional, to the Manifest at all — Edge Cases).
- **Semantic output** (REQ-004, ADR-0021 item 2, this feature's exact
  field enumeration): `affected_components`, `required_facets`,
  `conditional_facets` (on `{facet, applied, reason}` only — `evidence`
  excluded), `resolved_gates`, `capability_minimum_enforcement`,
  `capabilities`, `lite_eligibility`. Everything else in a Facet Manifest
  (`schema`, `feature`, `context_binding`, `resolver`) is binding/
  provenance metadata, excluded from comparison.
- **Policy Weakening (as scoped by this feature)**: the Epic-A1-reported
  transition-level `weakening_verdict.policy_weakening: true` outcome for
  the 3 currently-live categories only (`capability_enforcement_weakened`,
  `component_path_narrowed`, `spec_profile_full_to_lite`) — never a
  Registry- or ownership-scoped concept in this Foundation's current
  build scope (INV-012).

## Roles and Permissions

- **Epic A5's Resolver implementer**: the sole intended writer of live
  `facet-manifest.yaml`/`capability-summary.yaml`/`project-context.
  resolved.json` instances; this feature defines the contract those
  writes must satisfy but performs no writes itself.
- **A human or agent reviewer**: read-only consumer of all three artifacts
  and of REQ-006's validator scripts' diagnostic output; never hand-edits
  a Resolver-generated instance (Field Definitions, REQ-007).
- **`check-component-coverage` (Epic A3)**: read-only consumer of
  `facet-manifest.affected_components` via `--facet-manifest <path>`
  (INV-006) — this feature's schema is a contract *to* that consumer, not
  a component this feature modifies.
- **`spec-review-loop`/`impl-review-loop`**: not yet invoked against this
  package (`Spec-Review-Status: Pending`); this feature's own registration
  commit does not claim otherwise (Non-goals, Global ACs).

## Main Workflows

1. Epic A5's Resolver (out of this feature's build scope) resolves a
   Feature: it reads Project Context, Capability Registry, and path-
   ownership declarations; computes `affected_components` (from Epic A3's
   resolver output), the matching `capabilities[]` (via each Capability's
   `trigger`, ADR-0020), their `required_facets`/`conditional_facets`
   (the latter evaluated via the same DSL/Evidence machinery), the union
   of their `gate_ids` resolved into `resolved_gates[]`, `capability_
   minimum_enforcement`, and `lite_eligibility`; and writes
   `specs/<feature>/facet-manifest.yaml` conforming to
   `contracts/facet-manifest.schema.json` (REQ-001).
2. In the lite track, the Resolver instead writes only `specs/<feature>/
   capability-summary.yaml` with `track: lite` (REQ-002); in the full
   track, it writes both `facet-manifest.yaml` and a `track: full`
   `capability-summary.yaml` referencing the former by digest.
3. A reviewer or CI process runs `validate-facet-manifest.py --manifest
   specs/<feature>/facet-manifest.yaml` (REQ-006) before trusting the
   Manifest's content for any downstream Gate reasoning.
4. When `project-context.yaml`, `contracts/capability-registry.json`, or
   the path-ownership declaration changes, Epic A5's Resolver (out of
   scope here) re-runs for every potentially-affected Feature, recomputes
   the three digests plus a fresh semantic output, and applies REQ-004's
   comparison to decide, per Feature, whether to selectively mark it
   Stale, refresh metadata only, or (if Epic A1 reports a live-category
   weakening verdict) Block unconditionally.
5. A `resolver.version` bump follows REQ-005's three-tier rule to decide
   whether re-resolution is required at all, and if so, whether the
   REQ-004 comparison or an unconditional re-resolve applies.

## Edge Cases

- A Capability whose `trigger` does not match contributes **none** of its
  `required_facets`/`conditional_facets`/`gate_ids` to the Manifest — this
  is not represented as N/A entries for each of that Capability's facets;
  it is simply absent from `capabilities[]`, and by extension absent from
  every field derived from it (Field Definitions' `na_facets` entry).
- `affected_components: []` — schema-valid (AC-003) but only reachable in
  practice for a Feature whose diff, per Epic A3's resolver, touches zero
  paths (an empty changed-path set — Epic A3's own Edge Cases document
  this as "the Gate passes vacuously"); this feature's schema does not
  forbid it, since forbidding it would be a policy decision belonging to
  Epic A3's Gate, not to this feature's schema.
- `capability_minimum_enforcement` absent **and** `capabilities: []` — a
  Feature that resolved to zero matching Capabilities (e.g. a `disabled-
  legacy` project, ADR-0016 §4) still produces a schema-valid, minimally-
  populated Facet Manifest, not an error — `required_facets`, `conditional_
  facets`, `resolved_gates` are all schema-valid as `[]`.
- Two `conditional_facets[]` entries for the same `facet` name from two
  different resolved Capabilities, one `applied: true` and one `applied:
  false` — REQ-006's `facet-classification-conflict` check (AC-028) only
  guards against a facet appearing in *both* `required_facets` and
  `conditional_facets`; it does not forbid this same-facet-different-
  outcome case within `conditional_facets[]` alone, since two Capabilities
  legitimately disagreeing about one Facet's applicability is a real,
  representable Resolver output, not a malformed one — design.md's Design
  Decisions records this as a considered, not overlooked, scope boundary.
- `dependency_pointers` containing a pointer into `/shared_paths/N/...`
  (a numeric-indexed pointer, not an `id`-keyed one, since `shared_paths[]`
  is not re-keyed by REQ-003) — schema-valid and root-allowlisted (its
  first segment is `shared_paths`), and Field Definitions/design.md note
  explicitly that `shared_paths[]` entries have no natural unique key the
  way `components[]` entries do (`pattern` is not guaranteed unique), so
  numeric-index addressing is the only sound RFC-6901 form available for
  this one root.
- A `resolver.version` **major** bump landing in the same transition as a
  `registry_digest` change whose semantic output would *not* otherwise
  have changed — REQ-005's major-tier rule (AC-027) still forces re-
  resolve; the two triggers are independent, not mutually exclusive, and
  the major-version rule always wins when both are present in the same
  transition (design.md's Design Decisions states this explicitly as the
  intended precedence, since ADR-0021 item 6 places no condition on the
  major tier's applicability).

## Security Boundaries

- No new trust boundary is crossed: this feature defines schemas and
  read-only structural validators over files already inside the
  repository's own trust boundary (git-tracked, review-gated).
  `validate-*.py` scripts perform no network access, no dynamic code
  execution, and no credential handling — matching every existing
  `plugins/sdd-quality-loop/scripts/validate-*.py` in this repository.
- `context_binding`'s four digest fields are read-only provenance data
  this feature's schema constrains to a fixed `sha256:<hex>` shape; this
  feature performs no HMAC signing, no approval-sidecar-style tamper
  protection of its own — Facet Manifest integrity is a function of it
  being an ordinary, git-tracked, human/CI-reviewed file, not a
  cryptographically-protected one (unlike `sdd/project-context.approval.
  json`, which Epic A1 does protect this way). This is a deliberate scope
  boundary, not an oversight: the Facet Manifest's *inputs*
  (Project Context, Registry, ownership) are each independently protected
  or approval-gated by their owning epic; the Manifest itself is a
  derived, reproducible artifact any reviewer can regenerate and diff
  against, so it does not itself need independent cryptographic
  protection.
- Provider-name neutrality (ADR-0018's boundary, already enforced by Epic
  A2's Registry validator) is not re-implemented here: this feature's
  three schemas carry no provider-specific vocabulary of their own (no
  field name or enum value anywhere in `facet-manifest.schema.json`,
  `capability-summary.schema.json`, or `context-projection.schema.json`
  names a cloud provider, product, or distribution channel) — a fixture
  in REQ-006's test suite asserts this directly (a scan of every string
  literal in all three committed schema files against the same allowlist
  Epic A2's provider-contamination check already uses).

## Assumptions

- Epic A1's canonicalizer (`canonicalize-sdd-yaml.{py,sh,ps1,js}`) lands
  with the exact CLI/library shape `specs/epic-189-a1-project-context/
  design.md` already fixes (stdin/stdout, YAML-or-JSON input mode,
  `--hash-only`); REQ-003's two-pass canonicalization procedure is written
  against that fixed shape, not a placeholder.
- Epic A2's `contracts/capability-registry.schema.json` and its Evidence
  JSON Schema land unchanged from `specs/epic-190-a2-capability-registry/
  design.md`'s already-`Passed` shape; if either changes before Epic A2
  reaches implementation, this feature's REQ-001 `conditional_facets[
  ].evidence` and `resolved_gates[].stage` fields would need a
  corresponding follow-up revision (out of this spec's own scope to
  predict).
- Epic A3's `--facet-manifest <path>` read contract (INV-006) lands
  unchanged from `specs/epic-191-a3-path-ownership/requirements.md`'s
  current, still-`Pending` shape; this feature treats that shape as fixed
  because it is already committed prose in a sibling spec, not because
  Epic A3 has itself passed review yet.
- A future epic (not this one) will eventually build Registry- or
  ownership-scoped Policy Weakening detection; REQ-004's scope-narrowing
  decision (INV-012) is written to be forward-compatible with that
  addition (a new weakening category being promoted from `const: "n/a"`
  to a live `enum` value in Epic A1's schema would extend REQ-004's
  short-circuit condition, not contradict it), but this feature does not
  itself build or schedule that work.

## Open Questions

- OQ-001 (REQ-002): which future consumer reads a full-track Capability
  Summary instead of its source Facet Manifest — left to whichever future
  epic introduces that consumer (INV-010).
- OQ-002 (REQ-003): Context Projection's regeneration cadence (CI-gated
  drift check vs. on-demand) — an Epic A5 CI-wiring decision, not a schema
  decision (INV-007's investigation entry).

## Risks

- **Schema drift risk**: this feature's REQ-001/REQ-002/REQ-003 schemas are
  authored against Epic A1/A2/A3's *current*, not-yet-`Passed` (A1, A3) or
  recently-`Passed` (A2) spec content. If any of those three specs'
  field shapes change materially during their own review loops, this
  feature's schemas would need a follow-up revision before Epic A5 could
  safely build against them — mitigated by this spec citing exact section/
  line-level sources for every borrowed shape (Dependencies, Field
  Definitions) so a future diff against the landed shape is mechanical,
  not archaeological.
- **Ambiguity-resolution risk**: REQ-002's full-track Capability Summary
  shape and REQ-004's `evidence`-exclusion-from-semantic-output decision
  are this feature's own, explicitly-flagged resolutions of gaps the
  decision document and ADR-0021 leave implicit, not literal transcriptions
  — a future adversarial review could reasonably propose a different
  resolution; this spec records the reasoning behind each (Design
  Decisions, design.md) precisely so that disagreement, if it comes, can
  be evaluated against a stated rationale rather than a bare assertion.
- **Reserved-path risk**: REQ-003 fixes Context Projection's schema at
  Epic A1's already-reserved path
  (`plugins/sdd-quality-loop/scripts/generated/project-context.resolved.
  json`). If Epic A5 later finds that path unsuitable (e.g. a naming
  collision, or a discovery-contract mismatch discovered during
  implementation), amending it requires an explicit `guard-invariants`
  diff in Epic A5's own spec (per Epic A1's own reservation text,
  INV-007) — this feature does not, and structurally cannot, pre-empt that
  future amendment.
