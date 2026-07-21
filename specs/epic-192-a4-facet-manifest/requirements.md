# Requirements: epic-192-a4-facet-manifest

Spec-Review-Status: Pending
Source Issues: https://github.com/aharada54914/sdd-forge/issues/192,
https://github.com/aharada54914/sdd-forge/issues/187
Epic: https://github.com/aharada54914/sdd-forge/issues/187 (AI-DLC
Foundation tracking) — Epic A4 (Facet Manifest), issue #192, per
`docs/ai-dlc-foundation-decision-v2.md` §19 ("旧A5と順序入替": schema is
fixed before the Capability Resolver, Epic A5, is built)
Investigation: specs/epic-192-a4-facet-manifest/investigation.md
(INV-001..INV-019; OQ-001 retired into Non-goals, OQ-002 open)

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
delivers: the Facet Manifest schema itself (REQ-001); the Lite Capability
Summary schema (REQ-002 — a full-track shape, if one is ever needed, is
deferred to a future ADR, Non-goals); the Context Projection's canonical
shape and the `dependency_pointers` JSON Pointer contract (REQ-003); the
staleness/"semantic output" comparison contract and its normative CLI
(REQ-004, transcribing ADR-0021); the resolver-version policy (REQ-005,
transcribing ADR-0021 item 6); three deterministic schema-validation
scripts plus one staleness-comparator script, plus their fixtures and
tests (REQ-006); the Manifest/Summary storage location and naming
convention (REQ-007); and the documentation/versioning discipline every
Foundation epic's tasks share (REQ-008).

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
  `facet-manifest.affected_components` via a `--facet-manifest <path>` flag
  that is structurally required only in the `advisory`/`required` derived
  states — in the `disabled-legacy` derived state the flag is accepted but
  never consulted for existence (INV-006) — and needs this feature's schema
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
  or ownership-scoped Policy Weakening detector, or the future ADR deciding
  whether a full-track Capability Summary is needed — Non-goals) — Field
  Definitions and Design Decisions record *why* each field has the shape it
  has, not only what the shape is, so a later change can tell whether it
  is compatible or a breaking schema revision.

## Problems

- No Facet Manifest, Capability Summary, or Context Projection schema
  exists anywhere in this repository (INV-002) — Epic A5 cannot be
  specified, let alone built, against an undefined output shape, and Epic
  A3's already-landed `check-component-coverage` already depends on a
  field (`affected_components`) whose type is currently unfixed anywhere
  but a prose sentence in Epic A3's own Assumptions section.
- ADR-0021 fixes the `context_binding`/`resolver` block and the semantic-
  output *definition* precisely (everything except those two blocks — item
  2), but does not itself specify a testable comparison *algorithm*, and
  does not specify field-level array-ordering rules needed to make "compare
  two Facet Manifests" a well-defined structural operation rather than a
  semantically-fuzzy one (Dependencies, ADR-0021 items 2-3).
- Decision document v2 §16's own prose ("Policy Weakening → 全影響Feature
  をBlock") and ADR-0021 item 3 apply the Policy-Weakening rule uniformly
  across the Context/Registry/ownership axes, but only 3 of ADR-0019's 9
  named weakening categories are actually detected by any landed epic, and
  all 3 are Project-Context-scoped only (INV-012) — a schema/contract that
  silently routes every Registry- or ownership-axis digest change through
  the ordinary semantic-output comparison, on the theory that "no detector
  exists yet," would fail open exactly where ADR-0021/decision v2 §16
  demand a hard Block, and would let a real Registry- or ownership-scoped
  weakening (e.g. a required Gate silently removed, `minimum_enforcement`
  silently loosened) pass through undetected. REQ-004's fail-closed
  contract (Goals, below) resolves this without waiting for a Registry- or
  ownership-scoped detector to exist: a changed axis with an indeterminate
  verdict Blocks, the same outcome a real weakening would produce, until a
  future epic supplies that axis's detector.
- Decision document v2 §6 fixes the Lite Capability Summary's exact field
  set; §19 lists Capability Summary as a distinct Epic A5 output but
  specifies no separate full-track shape, and no sibling epic names a
  concrete consumer for one — an ambiguity an earlier revision of this spec
  resolved by inventing a full-track schema and a `facet_manifest_ref`
  compressed view, which adversarial review found out of REQ-002's own
  schema-fixing scope (INV-010). This revision fixes only the Lite shape
  and defers the full-track question to a future ADR (Non-goals).
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
- **Epic A2's `registry_digest` primitive — fragment-selection policy
  (hard dependency, this feature's own binding decision)**: Epic A2's
  `generate-registry-digest` accepts `--capability-ids`/`--gate-ids`
  (an explicit fragment) or `--whole` (the entire Registry), and explicitly
  leaves *which* to use as "Epic A5's Resolver concern, not Epic A2's"
  (INV-019). Because this feature, not Epic A5, fixes what
  `context_binding.registry_digest` binds to, REQ-004 fixes that choice as
  `--whole` — the identical full-input-binding argument Epic A3's own
  `ownership_digest` (REQ-005) already establishes: a Capability's
  `trigger` match/no-match outcome is a function of the current Context
  Projection, so no proper subset of "currently-matched capabilities" can
  be soundly treated as "not consumed" by a given resolve (INV-019).
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
  REQ-005 transcribe them into testable schema/comparison contracts. ADR-0021
  item 2 defines semantic output as everything in the Facet Manifest
  *except* the `context_binding` and `resolver` blocks — REQ-004 implements
  that boundary literally (an earlier revision of this spec additionally
  excluded `schema`, `feature`, and `conditional_facets[].evidence`, which
  adversarial review ["B1"] identified as a narrower exclusion than
  ADR-0021 actually fixes; this revision reverts that narrowing). REQ-004
  closes one gap ADR-0021 leaves genuinely implicit — array-ordering
  determinism, needed to make "compare two Facet Manifests" a well-defined
  structural-equality operation rather than a semantically-fuzzy one — but
  does not re-decide, or narrow, anything ADR-0021 already fixes.
- **ADR-0019 (Approval Sidecar Protection) — Policy Weakening category
  scope (hard dependency, detector-availability boundary, not a scope-
  narrowing of REQ-004 itself)**: only 3 of ADR-0019's 9 named weakening
  categories have a live detector, and that detector is Project-Context-
  scoped only (Epic A1's `weakening_verdict`); the other 6 categories are
  `const: "n/a"`, reserved, and no epic in current build scope implements a
  Registry- or ownership-scoped weakening detector at all (INV-012). Unlike
  an earlier revision of this spec, REQ-004 does **not** read this as
  license to route every Registry/ownership digest change through the
  ordinary semantic-output comparison unconditionally — ADR-0021 item 3 and
  decision document v2 §16's own prose apply the Policy-Weakening rule
  uniformly across all three axes (projection/registry/ownership), and a
  missing detector is an availability gap, not a decision that a Registry
  or ownership edit can never be a weakening. REQ-004 instead requires a
  mandatory, explicit weakening-verdict input for **all three** axes on
  every invocation — never expressed by omitting a flag (Goals) — and
  fails closed (Block) whenever a changed axis's verdict is indeterminate —
  see REQ-004 below for the full contract, and Non-goals for the still-true
  fact that this feature does not itself build a Registry- or
  ownership-scoped detector; it only defines what the staleness comparator
  does in that detector's absence.

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
  own `evaluate-predicate` output shape verbatim — an **array** of Evidence
  JSON Schema elements, `{result, evidence: [...]}`'s `evidence` array, not
  a single node — embedded by structural reference, INV-004; a
  `conditional_facets[]` entry's `evidence` is exactly the array
  `evaluate-predicate --predicate <this facet's Capability trigger or
  facet-condition predicate>` returned, so no root-extraction or
  single-node-selection rule is needed)}`, and whose `facet` value MUST be
  **unique** across the whole `conditional_facets[]` array — REQ-006's
  semantic validator rejects a second entry sharing a `facet` name
  (`conditional-facet-duplicate`, AC-047), reversing an earlier revision's
  Edge Cases text that left a same-`facet`, different-outcome duplicate
  unrestricted; see Edge Cases and design.md Design Decisions for why),
  `resolved_gates` (array of `{id, stage (enum: implementation/artifact/
  promotion, copy-consistent with `gates[].stage`), blocking (boolean)}` —
  `id` MUST be unique across `resolved_gates[]`, REQ-006's `resolved-gate-
  id-duplicate` check enforces it),
  `capabilities` (array of unique resolved Capability-id strings),
  `capability_minimum_enforcement` (optional; `const: "required"` only, no
  other value — matching Epic A2's own `minimum_enforcement` field exactly,
  Field Definitions explains why this is *not* the full "effective
  enforcement" of decision v2 §10), `lite_eligibility` (`{eligible
  (boolean, required), upgrade_reasons (array of **unique** strings,
  always present — `[]` when there are none, materialized by the Resolver,
  never merely a JSON Schema `default` annotation, which does not alter
  instance data; written sorted-and-unique, the same canonical-order
  discipline the other stable-sort-mandated arrays below already require,
  a verification-round finding on total order — see the stable-sort
  paragraph below and AC-048)}`, matching the per-Capability `lite_policy`
  shape but representing the Feature-level aggregate), `context_binding`
  (`{full_context_revision,
  dependency_pointers, projection_sha256, registry_digest,
  ownership_digest}`, verbatim from ADR-0021), and `resolver`
  (`{version, rule_set_revision}`, verbatim from ADR-0021). Every array
  REQ-001 defines that participates in semantic-output comparison
  (`affected_components`, `required_facets`, `conditional_facets`,
  `resolved_gates`, `capabilities`, `lite_eligibility.upgrade_reasons`)
  MUST be written stable-sorted (lexicographic by id/facet-name/
  component-id/upgrade-reason-string) — and, for `upgrade_reasons`, unique
  as well (schema-level `uniqueItems`, design.md API / Contract Plan) —
  before serialization — the same fragment-sort discipline Epic A2's
  `generate-registry-digest` already established (INV-005) — so Resolver
  purity (ADR-0020 item 6) extends to array order, not only set
  membership, and REQ-004's comparison can be a plain structural-equality
  check rather than a defensively-re-sorting one. `conditional_facets`'
  own by-`facet` sort, and `resolved_gates`' own by-`id` sort, are each a
  **total order**, not merely a partial one — a lexicographic sort key
  that is not guaranteed unique within the array has no defined relative
  order for two entries that share it, making "the array is
  stable-sorted" ill-defined for that input. `resolved_gates[].id`
  uniqueness is already enforced (`resolved-gate-id-duplicate`, REQ-006);
  this revision closes the identical gap for `conditional_facets[].facet`
  (`conditional-facet-duplicate`, REQ-006, AC-047 — a verification-round
  finding on total order, reversing an earlier revision's Edge Cases text
  that left a same-`facet` duplicate unrestricted).
- **REQ-002** (Capability Summary schema, Lite track only — decision v2 §6):
  Define `contracts/capability-summary.schema.json` fixing exactly decision
  v2 §6's own literal Lite Capability Summary shape, plus this feature's
  usual `schema`/`feature` envelope fields: `schema` (`const:
  "sdd-capability-summary/v1"`), `feature` (string, `^[a-z0-9][a-z0-9-]*$`),
  `track` (`const: "lite"` — a single-valued, constant discriminator kept
  for forward-compatible parsing by a future consumer, not for any
  branching schema logic; **this feature defines no `track: "full"` shape**
  — see Non-goals), `capabilities` (array of unique strings, required),
  `required_lite_checks` (array of unique strings, required),
  `full_upgrade_required` (boolean, required). `additionalProperties: false`
  at the top level — no `facet_manifest_ref` or other full-track-only field
  exists in this schema at all, since this feature ships no full-track
  shape (Non-goals, "M full Summary" adversarial-review finding). Whether,
  and in what shape, a full-track Capability Summary is needed is left to a
  future ADR (Non-goals) — this feature's own scope is limited to fixing
  the shape decision v2 §6 already gives verbatim.
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
  each entry's own `id`; `id` itself omitted since it is now the key; key
  vocabulary is any non-empty string — **identical** to Epic A1's own
  `components[].id` constraint, `{"type":"string","minLength":1}` with no
  character-set restriction, INV-009 — this feature imposes no narrower
  slug-shaped pattern of its own, correcting an earlier revision that did),
  shared_paths (array, as-is, addressed by numeric RFC 6901 index)}`. If
  the source `project-context.yaml` omits `components` and/or
  `shared_paths` (both optional at Epic A1's schema level, INV-009), the
  generation procedure below materializes `components: {}` and/or
  `shared_paths: []` respectively — Context Projection's own `components`/
  `shared_paths` fields remain **required** regardless of what the source
  document omits.
  Fix the generation procedure (for Epic A5 to implement, not for this
  feature to build) as an explicit two-pass canonicalizer invocation, never
  a single call that hands back a ready-to-manipulate parsed structure —
  Epic A1's canonicalizer contract is a stdin/stdout CLI whose only output
  is canonical-JSON *bytes* (or a hash), never a parsed-structure API
  (INV-008; an earlier revision of this spec assumed the latter): (1) run
  `canonicalize-sdd-yaml` in YAML input mode over `project-context.yaml`;
  its canonical-JSON stdout bytes are both hashed (`source_sha256`, equal
  to `context_binding.full_context_revision`) and, separately, parsed by
  the *caller* via a stdlib JSON parser (never a second, independent YAML
  parse) into a manipulable structure; (2) substitute `components: []`/
  `shared_paths: []` for either key that is absent from that structure;
  re-key `components` into the `id`-keyed object (sound only because Epic
  A1 already guarantees `id` uniqueness upstream, INV-009); (3) feed the
  transformed structure back through `canonicalize-sdd-yaml` a **second**
  time, JSON input mode, to obtain final JCS-canonical bytes, whose sha256
  is `projection_sha256`. Fix `dependency_pointers` as RFC 6901 JSON
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
  This root-allowlist check **is** schema-expressible (a `pattern` regex
  combining RFC 6901 syntax with a first-segment alternation, AC-017/
  AC-018) — this feature's schema enforces it directly, not as a separate
  semantic (REQ-006 validator) check; what remains genuinely
  semantic-validator territory, and not schema-expressible, is whether a
  given pointer actually *resolves* to a real value inside a concrete
  Context Projection instance (AC-016).
- **REQ-004** (stale detection contract — decision v2 §16, ADR-0021 items
  2-4): Fix **semantic output**, closed and field-enumerated (not merely
  prose), as **every REQ-001 field except `context_binding` and
  `resolver`** — ADR-0021 item 2's own boundary, applied literally:
  `schema`, `feature`, `affected_components`, `required_facets`,
  `conditional_facets` (compared on `{facet, applied, reason, evidence}` in
  full, `evidence`'s array included — Field Definitions records that an
  earlier revision of this spec excluded `schema`/`feature`/`evidence` as a
  narrower reading than ADR-0021 fixes; that narrowing is reverted, per
  adversarial review "B1"), `resolved_gates`, `capability_minimum_
  enforcement`, `capabilities`, and `lite_eligibility`. Fix the comparison
  as field-by-field structural equality over two Facet Manifest instances
  (old vs. new), safe as a plain equality check because REQ-001 already
  mandates stable-sorted arrays and `lite_eligibility.upgrade_reasons` is
  always-present (never merely defaulted).

  Fix the **Policy Weakening short-circuit**, unified across all three
  axes per ADR-0021 item 3 and decision document v2 §16's own prose (both
  apply "Policy Weakening → Block" uniformly to projection/registry/
  ownership, not to the projection axis alone — reverting an earlier
  revision's narrower reading, per adversarial review "B2"): the staleness
  comparator (design.md's `compare-facet-manifest-staleness` CLI contract)
  takes a **mandatory, explicit weakening-verdict input for each of the
  three axes, on every invocation** — a three-value enum, `weakened`,
  `not-weakened`, or `indeterminate` (no detector supplied a verdict for
  that axis at all), never expressed by omitting the axis's own input.
  **Omitting any of the three inputs is a caller argument error**
  (design.md's CLI contract, exit code 3), not a way to spell
  `indeterminate` — a verification-round finding reversing an earlier
  revision that made the three inputs optional and let flag omission
  stand for `indeterminate`. A caller with no detector for an axis must
  supply `indeterminate` explicitly for that axis; a caller for an axis
  whose digest did not change supplies `not-weakened` for that axis, by
  convention (below) — never `indeterminate`/`weakened` for an axis that
  did not change.
  - Any axis reporting `weakened` → Block unconditionally (no
    semantic-output comparison attempted), re-approval and re-resolve
    required, per ADR-0021 item 3.
  - Any axis whose digest **changed** but whose verdict is
    **indeterminate** → **fail-closed Block** — the same outcome a real
    weakening would produce, until a detector for that axis exists.
    Today, only Epic A1's Project-Context-scoped detector exists (the 3
    live categories, INV-012); no epic in current build scope builds a
    Registry- or ownership-scoped detector (Non-goals, unchanged), so **in
    practice every `registry_digest`- or `ownership_digest`-changing
    transition Blocks under this rule until a future epic supplies that
    axis's verdict** — this is the intended, safety-first consequence of
    closing the fail-open gap "B2" identified, not an oversight. A future
    Registry- or ownership-scoped detector Epic supplies that axis's
    verdict as this comparator's input; it does not need to change this
    contract's shape, only start supplying a non-indeterminate value
    (Assumptions). Concretely, a required Gate silently removed from a
    matching Capability, or a Capability's `minimum_enforcement` silently
    loosened, are the kind of Registry-scoped edits ADR-0019's named
    categories ("removing a required Gate," "weakening enforcement")
    already anticipate as weakening — this feature does not build the
    detector that would classify them, but its fail-closed default is what
    keeps them from silently passing through in the meantime.
  - An axis whose digest is **unchanged** still carries a mandatory,
    explicit weakening-verdict input (above — never omitted), but that
    input has **no Block consequence** for an unchanged axis (nothing to
    have weakened); the fixed caller convention (design.md) is to supply
    `not-weakened` for an unchanged axis specifically, so every axis's
    input is always a meaningful, explicit value, not a placeholder that
    only matters for the changed axes.
  - If **no** axis's digest changed at all (every axis's input is
    `not-weakened`, per the convention above) → continue, WARN-only
    (`fresh`, the same status the metadata-only-refresh branch below also
    reports, distinguished only by the WARN diagnostic).
  - If every changed axis reports `not-weakened` (explicitly, not merely
    "not indeterminate") → ordinary path: recompute and compare semantic
    output. Unchanged semantic output → metadata-only refresh (`context_
    binding`/`resolver` updated, not stale). Changed semantic output →
    selectively stale for that Feature only.
- **REQ-005** (resolver version policy — decision v2 §18.2, ADR-0021 item
  6): Fix the three-way `resolver.version` semver-component rule verbatim:
  **patch** → no regeneration required when semantic output is unchanged;
  **minor** → run the REQ-004 impact assessment, stale only if semantic
  output changes, **regardless of whether any `context_binding` digest
  also changed** (a verification-round finding on the comparator's branch
  order: an earlier revision of `compare-facet-manifest-staleness`
  short-circuited straight to `fresh` whenever no digest changed at all,
  with no exception for a `minor` bump, silently skipping the impact
  assessment this tier requires unconditionally — design.md fixes that
  branch-order defect); **major** → mandatory re-resolve for every Feature
  that used the affected Resolver version, regardless of whether semantic
  output would change (the one case that skips the semantic-output
  comparison entirely, INV-011) — unless REQ-004's Policy-Weakening
  short-circuit already Blocked the transition, in which case Block takes
  precedence over the major-tier's forced-stale outcome (both are
  safety-directed, but Block additionally requires re-approval, a stronger
  outcome than a forced re-resolve). `resolver.version` is schema-validated
  as a three-component semver string (`^\d+\.\d+\.\d+$`); `rule_set_
  revision` is a `sha256:<hex>` digest. A `rule_set_revision` change with
  `resolver.version` unchanged (a same-version rule-table edit) is treated
  as a **minor**-tier transition (run the impact assessment, unconditionally,
  exactly like an ordinary minor bump — never as a silent patch-tier
  no-op, and never as an unconditional major-tier force) and is supplied
  to `compare-facet-manifest-staleness` as its **own explicit
  `--resolver-version-bump minor-rule-set` input** (design.md API /
  Contract Plan), distinct from an ordinary `minor` `resolver.version`
  bump, so the comparator can tell "the version number moved" from "the
  version number didn't move but the rule table did" without inferring
  either from a raw digest diff. The comparator cross-checks the supplied
  `--resolver-version-bump` tier against the actual difference between the
  two input manifests' own `resolver.version`/`resolver.rule_set_revision`
  fields — `none` requires both fields unchanged; `patch`/`minor`/`major`
  each require `resolver.version` to differ at exactly that semver
  component; `minor-rule-set` requires `resolver.version` unchanged **and**
  `rule_set_revision` changed — and rejects any other combination (e.g.
  `--resolver-version-bump patch` against manifests whose `resolver.
  version` actually differs at the minor or major component) as an
  **argument error** (design.md, exit code 3) before evaluating any
  staleness branch, rather than silently trusting a caller-asserted tier
  that contradicts the manifests it was given.
- **REQ-006** (schema validation scripts, fixtures, tests — decision v2
  §19 item "schema"): Design three deterministic, stdlib-only-Python-
  master-plus-`sh`/`ps1`-wrapper scripts under
  `plugins/sdd-quality-loop/scripts/`: `validate-facet-manifest.{py,sh,
  ps1}`, `validate-capability-summary.{py,sh,ps1}`, `validate-context-
  projection.{py,sh,ps1}` (no `.js` wrapper — these are structural
  validators, not cross-runtime-hashed digest primitives, matching Epic
  A2's own `validate-capability-registry`/`generate-gate-capabilities`
  precedent of `.py`+`.sh`+`.ps1` only, INV-018), plus a fourth script,
  `compare-facet-manifest-staleness.{py,sh,ps1}`, implementing REQ-004's
  comparator contract (design.md API / Contract Plan gives its full
  normative CLI: inputs, output status enum, exit codes, diagnostics).
  `validate-facet-manifest`/`validate-capability-summary` target `.yaml`
  files (REQ-007); `validate-context-projection` targets the `.json`
  Context Projection artifact directly (stdlib `json.load`, no YAML
  involved). **YAML parse contract (fixing "B4"):** the two YAML-reading
  validators parse their input by exactly one path — invoking Epic A1's
  `canonicalize-sdd-yaml` as a subprocess (YAML input mode) and
  `json.loads()`-ing its canonical-JSON stdout — never a hand-rolled YAML
  parser of any kind; a non-zero canonicalizer exit is surfaced as this
  validator's own diagnostic (design.md), not silently swallowed. This
  makes REQ-006's two YAML-reading validators, like REQ-003, blocked until
  Epic A1's canonicalizer contract is finalized (Dependencies).

  Each script validates its target instance's schema conformance plus a
  small, closed set of semantic checks not expressible in JSON Schema
  draft-07 alone (Field Definitions/design.md enumerate the exact check-id
  table per script, mirroring `validate-capability-registry.py`'s
  `registry: <check-id>: <detail>` diagnostic style). The schema-
  conformance check's own hand-rolled draft-07 subset (design.md) covers
  every constraint keyword this feature's three schemas actually use,
  including `not`, `oneOf`, boolean (`true`/`false`) subschema values,
  array-form (union) `type`, `propertyNames`, and **`items`** (design.md's
  API / Contract Plan re-enumerates every keyword all three schemas use,
  cross-checked for exact coverage — a verification-round finding: `items`
  constrains array-element shape throughout all three schemas
  — `evidenceNode.children`, `conditional_facets[].evidence`,
  `resolved_gates[]`, `dependency_pointers[]`, `shared_paths[].components`,
  and every `projectedComponent` array field among them — and its absence
  from an earlier revision's implemented-keyword list meant none of those
  item-level constraints could actually be executed, despite the same
  earlier revision's own text claiming full coverage of "every keyword
  this feature's schemas actually use"); an earlier, still-earlier
  revision's implemented-keyword list additionally omitted `not`, `oneOf`,
  boolean (`true`/`false`) subschema values, and `propertyNames` despite
  the committed schemas using at least three of them (adversarial review
  "B5"). `$schema`, `$id`, and `title` are **not** implemented as
  validation keywords — design.md states explicitly that they are
  annotation/identifier keywords this feature's discovery contract
  (design.md, "Discovery contract") checks directly (a present `$schema`
  keyword and a matching `$id`), not constraint keywords the hand-rolled
  structural validator needs to interpret. Each of the three committed schema
  documents is additionally validated once, at spec-authoring/registration
  time (not by an automated `tests/*.tests.sh` regression suite — a
  general draft-07-metaschema-conformant validator is out of this
  hand-rolled subset's closed scope, INV-014), against the official
  draft-07 metaschema, and the result recorded in the Spec-Authoring-Time
  Manual Review Record (acceptance-tests.md).

  Each script locates its `contracts/*` artifact via Epic A2's already-fixed
  script-relative-then-git-root-fallback discovery contract (INV-018) — no
  new discovery algorithm is invented. Author `tests/*.tests.sh`+
  `.tests.ps1` pairs and fixture data under `tests/fixtures/facet-manifest/`
  covering schema-conformance positive/negative fixtures per required
  field, each REQ-006 semantic check's positive/negative fixture, REQ-004's
  full staleness-comparator branch table (design.md), REQ-005's three
  version-bump tiers, and REQ-003's `dependency_pointers` root-allowlist
  (now schema-level, AC-017/AC-018) and RFC-6901-well-formedness checks.
  Diagnostic output across all four scripts follows one determinism
  contract (design.md): a fixed `(check-id, JSON-Pointer-path)` sort order,
  RFC 6901 path representation (never dotted/bracket notation), UTF-8
  encoding, LF-only line endings on every runtime including the `.ps1`
  wrapper on Windows, and a fixed `0`/`1` exit-code convention (no
  per-check-id exit code). Every new suite is registered in
  `tests/run-all.sh`/`.ps1` directly (unprotected, matching INV-018's
  precedent) and staged for `.github/workflows/test.yml` registration via
  human-copy (protected, matching INV-018's precedent for CI-registration
  edits specifically, not for the validator scripts themselves, which this
  feature does not protect — Protected-File Statement, design.md).
- **REQ-007** (Manifest/Summary storage location and naming — decision v2
  §19 item "Manifest の保存場所・命名"): Fix `specs/<feature>/facet-
  manifest.yaml` and `specs/<feature>/capability-summary.yaml` as the
  per-Feature storage location, directly alongside `requirements.md`/
  `design.md`/etc. — the exact naming/placement decision document v2 §6
  already fixes for `capability-summary.yaml` (INV-010), extended
  consistently to the new `facet-manifest.yaml` sibling (Design Decisions
  records why `.yaml`, not `.json`, is
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
  no epic in current build scope builds detection for any of ADR-0019's 6
  named-but-reserved categories (INV-012); that remains a future epic's own
  spec. REQ-004's fail-closed contract (Goals) means this feature does not
  need that detector to exist in order to be safe in its absence — a
  changed Registry/ownership axis Blocks (fail-closed) until a future
  epic's detector supplies a non-indeterminate verdict; this feature only
  fixes what the comparator does with that verdict once supplied, it does
  not build the detector itself.
- Defining a full-track Capability Summary shape, or any artifact
  referencing a Facet Manifest by digest from within a Capability Summary
  — REQ-002 fixes only the Lite Capability Summary shape decision v2 §6
  already gives verbatim. Whether a full-track Capability Summary is needed
  at all, what it would contain, and who would consume it are questions
  left to a future ADR, not resolved by this feature (an earlier revision
  of this spec resolved them itself; adversarial review "M full Summary"
  found that out of REQ-002's own schema-fixing scope, and finding "M
  facet_manifest_ref" — a full-track compressed-view integrity gap —
  is retired as a consequence, since the artifact it critiqued no longer
  exists in this spec).
- Modifying `contracts/capability-registry.schema.json`,
  `contracts/project-context.schema.json`,
  `contracts/approval-sidecar.schema.json`, or any other Epic A1/A2/A3
  contract file — this feature only *reads* their already-fixed shapes
  (Dependencies) and adds new contract files of its own.
- Authoring a new ADR — ADR-0020 and ADR-0021 already normatively cover
  this feature's DSL-reuse and staleness surface; this feature transcribes
  them into schemas and testable contracts, it does not re-decide them.
- Deciding *when* Context Projection is regenerated (CI cadence,
  on-demand, etc. — OQ-002) — an Epic A5-or-later wiring decision this
  feature's schema work does not need to resolve to be complete.
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
- AC-005 (REQ-001): `conditional_facets[].evidence` is an **array**,
  validating element-wise against Epic A2's own `evaluate-predicate`
  Evidence JSON Schema, embedded verbatim (by `$ref` to a local copy or by
  structural duplication with an explicit provenance comment citing
  `specs/epic-190-a2-capability-registry/design.md`'s "Predicate DSL
  evaluator contract" section — design.md fixes which) — the exact array
  shape `{result, evidence: [...]}`'s `evidence` member has, not a single
  node (an earlier revision of this spec used a single-node shape,
  adversarial review "M Evidence array"); a fixture whose array contains an
  element with an `operator` value outside Epic A2's fixed 8-operator enum
  is rejected.
- AC-006 (REQ-001): `resolved_gates[]` items are `{id (string, same
  pattern as Epic A2's `gates[].id`), stage (enum: implementation/
  artifact/promotion), blocking (boolean)}`, `additionalProperties:
  false`, all three required; a fixture with a `stage` value outside the
  three-value enum is rejected.
- AC-007 (REQ-001): `capability_minimum_enforcement`, when present, is
  `const: "required"` — no other value validates; a fixture with any other
  string value is rejected; a fixture with the field entirely absent is
  accepted. An aggregate fixture confirms the Feature-level rule this field
  represents: across every resolved Capability, if every one's own
  `minimum_enforcement` is absent, the Feature-level field is absent; if at
  least one reports `required`, the Feature-level field is `required`.
- AC-008 (REQ-001): `lite_eligibility` is `{eligible (boolean, required),
  upgrade_reasons (array of non-empty strings, required)}`,
  `additionalProperties: false`; a fixture missing `eligible` is rejected;
  a fixture missing `upgrade_reasons` entirely is now **rejected** (an
  earlier revision of this spec made it optional-with-a-schema-`default`,
  which does not materialize `[]` on an absent instance — adversarial
  review "M default"); a fixture with `upgrade_reasons: []` explicitly
  present is accepted; an equivalence-test fixture confirms a
  Resolver-written manifest with `upgrade_reasons: []` and a
  (schema-invalid, rejected) manifest omitting the field entirely are
  *not* treated as equal by REQ-004's structural-equality comparator —
  they cannot both be valid inputs to it in the first place.
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
  `context_binding`/`resolver` example, with its illustrative `sha256:...`
  ellipsis replaced by a shape-equivalent, real 64-hex-digit sha256 value
  in each digest field (`full_context_revision: sha256:<64 hex chars>`,
  `dependency_pointers: [/components/desktop-client/artifact_kinds,
  /workflow/capability_enforcement]`, `resolver.version: 1.1.0`,
  `resolver.rule_set_revision: sha256:<64 hex chars>`) validates
  successfully against `contracts/facet-manifest.schema.json` once
  embedded in an otherwise-minimal-valid Facet Manifest — proving this
  schema does not silently diverge from the decision document's own worked
  example (an earlier revision of this fixture used the literal
  `sha256:...` ellipsis itself, which cannot satisfy the schema's
  `^sha256:[0-9a-f]{64}$` pattern — adversarial review "B6").
- AC-012 (REQ-002): `contracts/capability-summary.schema.json` exists;
  `required` at the top level is exactly `["schema","feature","track",
  "capabilities","required_lite_checks","full_upgrade_required"]`, and
  `track` is `const: "lite"` (this feature ships no other track value's
  shape — Non-goals); a fixture missing any required field is rejected.
- AC-013 (REQ-002): A fixture matching decision document v2 §6's literal
  example (`capabilities: [desktop-local]`, `required_lite_checks: [build,
  test, installer-dry-run]`, `full_upgrade_required: false`) validates
  successfully once `schema`, `feature`, and `track: "lite"` are added —
  the three fields this schema adds beyond decision v2's own prose example
  (an earlier revision of this AC named only two of the three required
  additions, omitting `feature`, adversarial review "B6").
- AC-014 (REQ-002): A fixture carrying an extra, undefined property (e.g.
  a `facet_manifest_ref` object, or any other field outside this schema's
  fixed six-field set) is rejected by `additionalProperties: false` — a
  regression lock against reintroducing the full-track fields an earlier
  revision of this schema defined (Non-goals) without an explicit,
  future-ADR-authorized schema revision.
- AC-015 (REQ-003): `contracts/context-projection.schema.json` exists;
  `components` is `type: object` with `propertyNames: {"minLength": 1}`
  and `additionalProperties: {"$ref": "#/definitions/projectedComponent"}`
  — a non-empty-string key vocabulary **identical** to Epic A1's own
  `components[].id` constraint, no character-set restriction (an earlier
  revision instead used `patternProperties` keyed on a slug-shaped regex
  that rejected A1-valid ids like `Desktop/App`/`Desktop_Client`,
  adversarial review "B3") — each value shaped identically to Epic A1's
  `components[]` item minus the now-redundant `id` field. A fixture
  representing a raw `project-context.yaml` with two components,
  **one of them using a non-slug-shaped id** (e.g. `Desktop/App`),
  transformed per REQ-003's procedure, produces an object with exactly two
  keys equal to those components' `id` values verbatim (including the
  non-slug one), and each value's own `id` key is absent (proving the
  re-keying step, not merely a copy). A second fixture, representing a raw
  `project-context.yaml` that omits `components` and/or `shared_paths`
  entirely (both optional at Epic A1's schema level), transformed per
  REQ-003's procedure, produces `components: {}` and/or `shared_paths: []`
  respectively (B8's source-omission normalization rule, Goals).
- AC-016 (REQ-003): A fixture where `dependency_pointers` contains
  `/components/desktop-client/artifact_kinds` (decision document v2 §16's
  own example) resolves, via RFC 6901 pointer resolution, to a real value
  inside a fixture Context Projection instance shaped per AC-015 — an
  end-to-end proof the re-keyed shape is what the decision document's own
  pointer syntax actually requires, not merely schema-shape-compatible by
  coincidence. This remains the one genuinely semantic (non-schema-
  expressible) check in the `dependency_pointers` area: whether a pointer
  *resolves* to a real value inside a concrete Context Projection instance.
- AC-017 (REQ-003): A `dependency_pointers` entry whose first path segment
  is not one of `workflow`/`components`/`shared_paths` (e.g. `/schema` or
  `/nonexistent`) is rejected at the **schema** level, by the same combined
  syntax-plus-root-vocabulary `pattern` AC-018 exercises — not by a
  separate REQ-006 semantic check. An earlier revision of this AC claimed
  first-segment vocabulary could not be schema-expressed and required a
  named semantic diagnostic (`dependency-pointer-root-not-allowlisted`);
  adversarial review (Minor finding) showed a regex combining syntax and
  root constraint (`^/(workflow|components|shared_paths)(/([^/~]|~0|~1)*)*
  $`) is expressible in draft-07 directly, so this feature's schema now
  enforces it there, and REQ-006's semantic-check budget is reserved for
  the genuinely non-schema-expressible existence-resolution check (AC-016).
- AC-018 (REQ-003): A `dependency_pointers` entry that is syntactically
  malformed RFC 6901 (e.g. `components/desktop-client` with no leading
  `/`, or containing an unescaped bare `~`), **or** that is well-formed
  RFC 6901 but whose first segment is outside the `workflow`/`components`/
  `shared_paths` allowlist, is rejected by the schema's own `pattern`
  keyword on `dependency_pointers[].items` — both are pure schema-level
  rejections now (AC-017's case folded into this same mechanism).
- AC-019 (REQ-004): A fixture pair of Facet Manifest instances differing
  only in `context_binding.registry_digest` (all other fields, including
  every REQ-004-scoped semantic-output field, byte-identical), **with an
  explicit `not-weakened` registry-axis weakening verdict supplied**
  (REQ-004 requires one whenever that axis's digest changes — without it
  this fixture would Block under the fail-closed rule instead, AC-024), is
  classified by `compare-facet-manifest-staleness` as **not stale**
  (metadata-only refresh) — the direct AC-021-of-ADR-0021 analog this
  feature's own contract must reproduce.
- AC-020 (REQ-004): A fixture pair differing in `context_binding.registry_
  digest` **and** in `resolved_gates[]`'s `blocking` value for a gate whose
  `id` is unchanged (ADR-0021 item 2's explicit "stage/blocking changes on
  the same gate ID" clause), with an explicit `not-weakened` registry-axis
  verdict supplied, is classified as **stale** — proving the comparison
  contract implements ADR-0021's specific same-ID/changed-attribute
  clause, not merely a naive set-membership diff over gate IDs.
- AC-021 (REQ-004): A fixture pair with an explicit `not-weakened`
  registry-axis verdict supplied (triggering the ordinary comparison path)
  where the only semantic-output field-level difference is
  `conditional_facets[].evidence` (identical `facet`/`applied`/`reason`
  for every entry) is classified as **stale** — the fixture that proves
  REQ-004's reversal of an earlier revision's `evidence`-exclusion decision
  (Goals/Field Definitions, adversarial review "B1") is actually
  implemented, not merely documented. (An earlier revision of this AC
  asserted the opposite outcome — not-stale — as proof of the exclusion
  this revision reverts.)
- AC-022 (REQ-004): A fixture pair differing only in `capability_minimum_
  enforcement` going from absent to `"required"` (a tightening, ADR-0021
  item 2's explicit minimum-enforcement-tightening clause), with an
  explicit `not-weakened` registry-axis verdict supplied, is classified as
  **stale**.
- AC-023 (REQ-004): A fixture representing a `weakened` verdict on **any**
  one axis (the concrete fixture uses the projection axis, since Epic A1's
  is the only axis with a live detector today, INV-012) short-circuits to
  Block **without** evaluating the semantic-output comparison at all (a
  fixture whose semantic-output fields are, deliberately, byte-identical
  old-vs-new still results in Block, proving the short-circuit precedes,
  and does not depend on, the comparison outcome) — REQ-004's Goals record
  this as a uniform, three-axis rule, not a projection-only one; the
  fixture is projection-axis only because no other axis has a detector to
  produce a `weakened` verdict with yet.
- AC-024 (REQ-004, fail-closed lock, reversing an earlier revision's
  fail-open reading — adversarial review "B2"; revised — verification-round
  finding on mandatory weakening inputs): two sub-case fixtures over a
  `registry_digest` change (a `minimum_enforcement` field removed from a
  Capability — informally "looks like" a weakening — is used as the
  concrete edit for both sub-cases), each supplying all three required
  `--*-weakening` inputs explicitly (REQ-004 — no flag is ever omitted):
  (1) an explicit **`indeterminate`** registry-axis weakening verdict is
  supplied (the ordinary case today, since no Registry-scoped detector
  exists, INV-012, so a caller with no detector for that axis must pass
  `indeterminate` explicitly rather than omit the flag — reversing an
  earlier revision, which represented this case by flag omission) → the
  comparator returns **Block** (`weakening-verdict-indeterminate:registry`),
  never proceeding to the ordinary semantic-output comparison path —
  proving the fail-closed rule is a hard boundary, not a judgment call
  left to the comparator; (2) an explicit `not-weakened` registry-axis
  verdict *is* supplied instead (simulating a future Registry-scoped
  detector) → the comparator proceeds to the ordinary semantic-output
  comparison path and classifies the Feature per its actual output
  difference — proving the contract is forward-compatible with a future
  detector without needing its own shape to change once one exists. A
  companion fixture (AC-044) proves the distinct case — omitting a
  `--*-weakening` flag entirely — is an **argument error** (exit 3), not a
  third way to spell `indeterminate`.
- AC-025 (REQ-005): A `resolver.version` patch-only bump (e.g. `1.1.0` →
  `1.1.1`) with byte-identical semantic output requires no regeneration
  (no Stale marking, no forced re-resolve) — a positive fixture proving the
  patch tier's "no-op when unchanged" behavior.
- AC-026 (REQ-005): A `resolver.version` minor bump (e.g. `1.1.0` →
  `1.2.0`) triggers the REQ-004 impact assessment and is marked Stale only
  when semantic output actually changed as part of that assessment — a
  fixture pair proving both the changed and unchanged sub-cases, **each
  also confirmed with a `context_binding` that is byte-identical old-vs-new
  (no axis digest differs at all)** — a minor bump alone, with no digest
  change, still runs the impact assessment rather than short-circuiting to
  `fresh` (see AC-045, which locks the comparator-branch fix this
  requirement depends on).
- AC-027 (REQ-005): A `resolver.version` major bump (e.g. `1.1.0` →
  `2.0.0`) forces every Feature that used the affected Resolver version to
  re-resolve, even in a fixture where semantic output is otherwise
  byte-identical — proving the major tier skips the semantic-output
  comparison entirely (INV-011), not merely makes staleness more likely.
- AC-028 (REQ-006, revised — verification-round finding on total order):
  `validate-facet-manifest.py --manifest <path>` exits 0 on a fully
  schema-conformant, semantically-consistent fixture, and non-zero with a
  `facet-manifest: <check-id>: <detail>` diagnostic line (matching
  `validate-capability-registry.py`'s own diagnostic style, INV-005/
  design.md) for each of: `schema-invalid`, `resolved-gate-id-duplicate`
  (two `resolved_gates[]` entries sharing an `id`),
  `facet-classification-conflict` (a facet name present in both
  `required_facets` and `conditional_facets`), `conditional-facet-
  duplicate` (two `conditional_facets[]` entries sharing a `facet` value,
  AC-047), and `array-not-stable-sorted` (one fixture per REQ-001
  stable-sort-mandated array, including `lite_eligibility.upgrade_reasons`
  (AC-048), each submitted out of lexicographic order — an earlier
  revision of this AC omitted this diagnostic despite design.md's own
  diagnostic-id table listing it, adversarial review "M suite/1:1";
  `dependency-pointer-root-not-allowlisted` is retired from this table,
  folded into the schema level, AC-017).
- AC-029 (REQ-006): `validate-capability-summary.py --summary <path>`
  exits 0 on a valid Lite Capability Summary fixture (AC-013's own worked
  example) and non-zero — `capability-summary: schema-invalid: <detail>`
  — on a fixture missing any required field, and on a fixture carrying an
  extra/unknown property (AC-014).
- AC-030 (REQ-006): `validate-context-projection.py --projection <path>`
  exits 0 on a valid re-keyed fixture, **including one whose `components`
  keys include a non-slug-shaped id** (AC-015's `Desktop/App` fixture,
  proving B3's relaxation is enforced by the validator, not merely the
  schema file), and non-zero on a fixture where `components` is still
  array-shaped (not re-keyed) — proving the validator actually enforces
  the re-keying transform, not merely generic JSON-Schema `type: object`
  conformance. (An earlier revision of this AC additionally named a
  `component-key-pattern-invalid` check; that check is retired as a direct
  consequence of B3 — with no character-set restriction left to check,
  `propertyNames: {"minLength": 1}` at the schema level is the only
  remaining constraint, and it is already exercised by AC-015/AC-029's
  positive fixtures.)
- AC-031 (REQ-006): All four scripts' (`validate-facet-manifest`,
  `validate-capability-summary`, `validate-context-projection`,
  `compare-facet-manifest-staleness`) `.py`/`.sh`/`.ps1` wrapper
  invocations produce identical exit codes and identical diagnostic
  output for every fixture in the suite (dual/triple-runtime parity,
  matching Epic A2's own parity discipline, INV-018), following the fixed
  diagnostic-determinism contract (design.md): identical sort order,
  identical RFC 6901 path representation, UTF-8/LF-only output on every
  runtime including the `.ps1` wrapper on Windows. The fixture set
  includes at least one Windows-style path argument (e.g. a backslash-
  separated `--manifest` value) and confirms the `.ps1` wrapper's own
  output remains LF-only and byte-identical to the `.py`/`.sh` outputs for
  that same fixture (adversarial review "M parity決定論").
- AC-032 (REQ-006): Each script's discovery contract, when only the
  script-relative packaged copy of its `contracts/*` artifact is present
  (no monorepo `contracts/`, no reachable `.git`), still resolves and
  validates correctly — one fixture per script per runtime, matching Epic
  A2's own three-fixture, per-runtime discovery proof (INV-018).
- AC-033 (REQ-006): Every new `tests/*.tests.sh`/`.tests.ps1` pair this
  feature adds — **six** in total (`facet-manifest-schema`,
  `facet-manifest-semantics`, `capability-summary-schema`,
  `context-projection-schema`, `facet-manifest-staleness`,
  `facet-manifest-parity`; an earlier revision's design.md said "four" in
  one place while listing five-then-six suites elsewhere, adversarial
  review "M suite/1:1") — is registered in `tests/run-all.sh`/`.ps1`
  directly; the corresponding `.github/workflows/test.yml` registration is
  staged under `specs/epic-192-a4-facet-manifest/human-copy/` (a Phase 2
  artifact, scheduled by this feature's future `tasks.md`, not committed
  by this spec-phase package).
- AC-034 (REQ-007): A fixture directory tree with `specs/<feature>/
  facet-manifest.yaml` and `specs/<feature>/capability-summary.yaml`
  present alongside `requirements.md`/`design.md`/`acceptance-tests.md`
  passes `check-sdd-structure.sh`'s repository-root-level checks unchanged
  (neither file's presence or absence affects that script's per-repo-root
  required-item list, INV-016) — proving REQ-007's placement introduces no
  regression against an already-fixed validator.
- AC-035 (REQ-008): a grep-based self-check confirms no version string is
  mutated anywhere in this feature's diff outside a
  `scripts/bump-version.sh` invocation (matching Epic A3's AC-049); every
  implementation task this feature's future `tasks.md` schedules lands its
  own `CHANGELOG.md` `## Unreleased` entry citing #192 (REQ-008, an earlier
  revision of this AC checked only the version-mutation half of REQ-008,
  adversarial review "M suite/1:1"); no new `docs/adr/00NN-*.md` file is
  added by this feature's future tasks (Non-goals).
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
- AC-039 (REQ-004, new — adversarial review "M suite/1:1"): A fixture pair
  where **none** of the three `context_binding` digests (`projection_
  sha256`, `registry_digest`, `ownership_digest`) changed, **all three
  weakening-verdict flags explicitly `not-weakened`, and
  `--resolver-version-bump none`**, is classified `fresh` with a `WARN`-only
  diagnostic, and the comparator does not attempt to recompute or compare
  semantic output at all (distinct from the metadata-only-refresh branch,
  AC-019, which *does* run the comparison and finds it unchanged, and
  distinct from AC-045's `minor`/`minor-rule-set` fixtures, which also have
  no digest change but *do* run the comparison) — the "no axis changed"
  branch REQ-004 names but an earlier revision left untested.
- AC-040 (REQ-004, new — adversarial review "M suite/1:1"; revised —
  verification-round finding on mandatory weakening inputs): the
  `ownership_digest` axis's own parity with AC-019/AC-024's
  `registry_digest` fixtures, both sub-cases supplying all three required
  `--*-weakening` inputs explicitly (REQ-004 — no flag is ever omitted):
  (1) a fixture pair differing only in `context_binding.ownership_digest`,
  with an explicit `not-weakened` ownership-axis verdict supplied, is
  classified **not stale** (metadata-only refresh); (2) the same digest
  change with an explicit **`indeterminate`** ownership-axis verdict
  supplied (reversing an earlier revision, which represented this case by
  flag omission) is classified **Block**
  (`weakening-verdict-indeterminate:ownership`) — proving the fail-closed
  rule (REQ-004) applies uniformly to the ownership axis, not only the
  registry axis.
- AC-041 (REQ-001/REQ-006, new — adversarial review "M suite/1:1"): An
  `evidenceNode` array element with `outcome: "warn"` and no `reason` is
  rejected (the embedded Evidence schema's own `if`/`then` branch,
  AC-005); the identical element with a non-empty `reason` present is
  accepted.
- AC-042 (REQ-003, new — adversarial review "M suite/1:1"): `shared_paths[]`
  items' `oneOf` branch: a fixture entry with `pattern` plus `components`
  (a bounded entry) validates; a fixture entry with `pattern` plus
  `classification: "cross-cutting"` (an unbounded entry) validates; a
  fixture entry carrying **both** `components` and `classification`, and a
  fixture entry carrying **neither**, are each rejected by the `oneOf`'s
  exactly-one-branch requirement.
- AC-043 (Security Boundaries, new — adversarial review "M suite/1:1"): a
  repository-scan fixture confirms none of this feature's three schema
  files or four validator/comparator scripts contains a cloud-provider,
  distribution-channel, or workflow-runtime-product name from the same
  provider-neutrality allowlist Epic A2's own scan already uses (ADR-0018);
  a clean fixture proves the scan does not false-positive on provider-
  neutral vocabulary already present in this feature's own schemas (e.g.
  `distribution_channels` as a field name).
- AC-044 (REQ-006, new — adversarial review "B7"; revised —
  verification-round finding on stdout/exit/error-channel unification):
  `compare-facet-manifest-staleness`'s own CLI contract exists as
  design.md specifies: invoked with `--old-manifest`/`--new-manifest`/
  **all three** `--*-weakening` flags (each **required** on every
  invocation — an earlier revision made them optional with omission
  standing for `indeterminate`, which this revision reverses, Goals)/
  `--resolver-version-bump`, it emits exactly one line,
  `facet-manifest-staleness: <status>:<reason>` (never a bare `<status>`
  alone — an earlier revision of this AC fixed a bare `fresh|stale|blocked`
  stdout contract that contradicted design.md's own `<status>[:<reason>]`
  shape; this revision makes `<reason>` mandatory and resolves the
  contradiction in design.md's favor), on stdout, and exits `0`/`1`/`2`
  for `fresh`/`stale`/`blocked` respectively — a fixture per exit code
  proves the exit-code-to-status mapping is fixed, not merely the status
  string. A **fourth** fixture class proves the separate error channel:
  omitting a required flag, an out-of-enum `--*-weakening`/
  `--resolver-version-bump` value, a `--resolver-version-bump` tier
  inconsistent with the two manifests supplied (AC-046), or a
  schema-invalid `--old-manifest`/`--new-manifest`, each exit **`3`** with
  a diagnostic on **stderr** only (`facet-manifest-staleness: <check-id>:
  <detail>`) — stdout carries no `facet-manifest-staleness:` line at all
  for an exit-3 invocation, proving the verdict channel (stdout, exit
  0/1/2) and the diagnostic channel (stderr, exit 3) are fully separated,
  never sharing a line format or an exit code, and byte-identical across
  all three runtimes (AC-031's diagnostic-determinism contract, extended
  to this script's exit-3 case, design.md).
- AC-045 (REQ-004/REQ-005, new — verification-round finding on comparator
  branch order): a fixture pair whose `context_binding` (`projection_
  sha256`/`registry_digest`/`ownership_digest`) is byte-identical old-vs-
  new (no axis digest differs at all, all three weakening flags
  `not-weakened`) but whose `resolver.version` differs at the minor
  component (`--resolver-version-bump minor`) is classified per REQ-004's
  ordinary comparison path (`fresh`/`metadata-only-refresh` or `stale`/
  `semantic-output-changed`, depending on a companion semantic-output-
  difference fixture), **never** short-circuited straight to `fresh`/
  `unchanged` without running the comparison — proving the digest-
  unchanged short-circuit (compare-facet-manifest-staleness branch 3,
  design.md) is scoped to `none`/`patch` bumps only, and does not
  intercept a `minor` bump whose semantic output the impact assessment
  must still evaluate (REQ-005). A parity fixture confirms the identical
  outcome for `--resolver-version-bump minor-rule-set` (a same-version
  `rule_set_revision` edit) under the same digest-unchanged condition.
- AC-046 (REQ-005, new — verification-round finding on comparator branch
  order): `compare-facet-manifest-staleness` rejects, as an **argument
  error** (exit 3, not a verdict), a `--resolver-version-bump` value
  inconsistent with the actual `resolver.version`/`rule_set_revision`
  difference between `--old-manifest` and `--new-manifest` — fixtures
  cover: `--resolver-version-bump patch` against manifests whose `resolver.
  version` actually differs at the minor or major component;
  `--resolver-version-bump minor` against manifests whose `resolver.
  version` is unchanged (the `minor-rule-set` case, misdeclared); and
  `--resolver-version-bump minor-rule-set` against manifests whose
  `resolver.version` actually changed, or whose `rule_set_revision` is
  unchanged. A positive fixture per tier (`none`/`patch`/`minor`/
  `minor-rule-set`/`major`) confirms a *consistent* declaration is accepted
  and proceeds to the ordinary branch table.
- AC-047 (REQ-001/REQ-006, new — verification-round finding on total
  order): a fixture with two `conditional_facets[]` entries sharing one
  `facet` value (differing in `applied`/`reason`/`evidence`) is rejected
  by `validate-facet-manifest.py` with `facet-manifest: conditional-facet-
  duplicate: <detail>`; a fixture with every `conditional_facets[]` entry
  carrying a distinct `facet` value is accepted — proving `conditional_
  facets`' own by-`facet` stable-sort requirement (Goals) now has a
  genuine total order to sort against, reversing an earlier revision's
  Edge Cases text that left this same-facet, different-outcome case
  unrestricted.
- AC-048 (REQ-001/REQ-006, new — verification-round finding on total
  order): `lite_eligibility.upgrade_reasons` rejects a duplicate string at
  the **schema** level (`uniqueItems: true`, API / Contract Plan) and
  rejects an out-of-lexicographic-order, duplicate-free fixture at the
  **semantic** level (`array-not-stable-sorted`'s scope extended to this
  field, design.md diagnostic table) — proving `upgrade_reasons` now
  carries the same sorted-and-unique canonical-order discipline REQ-001's
  other semantic-output-comparison arrays already have (Goals), so
  REQ-004's plain structural-equality comparator needs no special-case
  normalization for this field either.

## Field Definitions

- **Facet Manifest**: the per-Feature artifact at `specs/<feature>/
  facet-manifest.yaml`, schema `sdd-facet-manifest/v1`. Its content, minus
  only `context_binding`/`resolver`, is exactly ADR-0021's "semantic
  output" (REQ-004) — `schema`, `feature`, and `conditional_facets[
  ].evidence` are part of that comparison too (adversarial review "B1"
  reverted an earlier, narrower exclusion of all three).
- **Capability Summary**: the per-Feature artifact at `specs/<feature>/
  capability-summary.yaml`, schema `sdd-capability-summary/v1`, Lite track
  only — decision v2 §6's own shape verbatim. This feature defines no
  full-track shape (Non-goals; an earlier revision's `track`-discriminated,
  full-track-including schema is retired, adversarial review "M full
  Summary").
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
- **`context_binding.registry_digest`**: bound via Epic A2's
  `generate-registry-digest --whole` (the entire Registry), never a
  `--capability-ids`/`--gate-ids` fragment of only the currently-matched
  Capabilities — the same full-input-binding soundness argument Epic A3's
  own `ownership_digest` already establishes (INV-019): a Capability's
  `trigger` match outcome is a function of the current Context Projection,
  so no proper subset of "currently-matched capabilities" can be soundly
  treated as "not consumed" by a given resolve.
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
- **Semantic output** (REQ-004, ADR-0021 item 2's own boundary, applied
  literally): every REQ-001 field except `context_binding` and
  `resolver` — `schema`, `feature`, `affected_components`,
  `required_facets`, `conditional_facets` (on the full `{facet, applied,
  reason, evidence}` shape, `evidence`'s array included), `resolved_gates`,
  `capability_minimum_enforcement`, `capabilities`, `lite_eligibility`.
  Only `context_binding` and `resolver` are binding/provenance metadata,
  excluded from comparison (an earlier revision additionally excluded
  `schema`, `feature`, and `evidence`; adversarial review "B1" reverted
  that narrowing as inconsistent with ADR-0021's own text).
- **Policy Weakening (as scoped by this feature)**: the *concept* is
  three-axis (projection/registry/ownership), matching ADR-0021 item 3 and
  decision document v2 §16's own uniform "Policy Weakening → Block" rule —
  not projection-only, as an earlier revision of this spec read it. What
  is currently *detected* is narrower: only Epic A1's Project-Context-
  scoped `weakening_verdict.policy_weakening: true` outcome, for the 3
  currently-live categories (`capability_enforcement_weakened`,
  `component_path_narrowed`, `spec_profile_full_to_lite`), exists as a
  real detector today (INV-012); no Registry- or ownership-scoped detector
  exists in this Foundation's current build scope (Non-goals, unchanged).
  REQ-004's fail-closed contract is precisely what lets this feature state
  a uniform three-axis *rule* without yet having three-axis detector
  *coverage*: an axis with no detector Blocks (fail-closed) instead of
  silently passing, whenever that axis's digest changes.

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
   capability-summary.yaml` (`track: "lite"`, REQ-002) — this feature ships
   no other track's shape; whether a full-track project needs a separate
   Capability Summary is a future ADR's question (Non-goals).
3. A reviewer or CI process runs `validate-facet-manifest.py --manifest
   specs/<feature>/facet-manifest.yaml` (REQ-006) before trusting the
   Manifest's content for any downstream Gate reasoning.
4. When `project-context.yaml`, `contracts/capability-registry.json`, or
   the path-ownership declaration changes, Epic A5's Resolver (out of
   scope here) re-runs for every potentially-affected Feature, recomputes
   the three digests, and calls `compare-facet-manifest-staleness`
   (REQ-004/REQ-006) with a weakening verdict for each changed axis. Any
   `weakened` or indeterminate (no detector yet) verdict on a changed axis
   Blocks the Feature unconditionally; otherwise a fresh semantic output is
   computed and compared to decide, per Feature, whether to selectively
   mark it Stale or refresh metadata only.
5. A `resolver.version` bump follows REQ-005's three-tier rule to decide
   whether re-resolution is required at all, and if so, whether the
   REQ-004 comparison or an unconditional re-resolve applies (subject to
   the same Policy-Weakening precedence, REQ-005).

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
  different resolved Capabilities — an earlier revision of this spec
  treated this as a legitimate, representable Resolver output (two
  Capabilities disagreeing about one Facet's applicability) and left it
  unrestricted; this revision **forbids** it (a verification-round finding
  on `conditional_facets`' own total order, design.md Design Decisions):
  REQ-006's new `conditional-facet-duplicate` semantic check (AC-047)
  rejects a second `conditional_facets[]` entry sharing a `facet` value
  with an earlier one, regardless of `applied`/`reason`/`evidence` content.
  This is a **narrower** rule than `facet-classification-conflict`
  (AC-028), which guards a different pair — a facet appearing in both
  `required_facets` and `conditional_facets` — not the same-array-twice
  case this Edge Case now forbids. Without this prohibition,
  `conditional_facets`' own by-`facet` stable-sort requirement (Goals,
  REQ-001) has no defined tie-breaker for two entries sharing one `facet`
  name, making "the array is stable-sorted" an ill-defined check for that
  input; forbidding the duplicate makes the by-`facet` sort a genuine
  total order, the same status `resolved_gates`' own by-`id` sort already
  has via `resolved-gate-id-duplicate`. A Resolver that needs to represent
  two Capabilities' differing views of one Facet's applicability must
  resolve that disagreement upstream (e.g. Capability-level precedence, a
  future Epic A5 concern) before writing a single `conditional_facets[]`
  entry for that `facet` name — this feature's schema and validator do not
  themselves define that precedence rule, only that the Manifest's own
  array may not carry the unresolved disagreement forward as two rows.
- `dependency_pointers` containing a pointer into `/shared_paths/N/...`
  (a numeric-indexed pointer, not an `id`-keyed one, since `shared_paths[]`
  is not re-keyed by REQ-003) — schema-valid and root-allowlisted (its
  first segment is `shared_paths`), and Field Definitions/design.md note
  explicitly that `shared_paths[]` entries have no natural unique key the
  way `components[]` entries do (`pattern` is not guaranteed unique), so
  numeric-index addressing is the only sound RFC-6901 form available for
  this one root.
- A component `id` containing a literal `/` or `~` (schema-valid under
  B3's relaxed, A1-identical `components` key vocabulary — Field
  Definitions) requires the standard RFC 6901 escaping (`~1`/`~0`
  respectively) when it appears as a `dependency_pointers[]` token — e.g.
  a component id `Desktop/App` is addressed as
  `/components/Desktop~1App/artifact_kinds`, never a raw, unescaped `/`
  inside the token. This is the existing `dependency_pointers[].pattern`'s
  own escaping grammar (design.md), not a new rule B3 introduces; it is
  noted here because B3 makes such ids schema-valid for the first time.
- A `registry_digest` or `ownership_digest` change with an indeterminate
  weakening verdict for that axis (no detector supplies one) Blocks under
  REQ-004's fail-closed rule *even when the underlying edit is, in fact, a
  tightening* (e.g. a `minimum_enforcement` field newly added) — the
  comparator has no way to distinguish a tightening from a weakening
  without a real detector, so it treats every indeterminate, changed axis
  identically regardless of the edit's actual direction; this is the
  accepted cost of fail-closed safety (Goals), not a bug to route around
  case-by-case.
- A `resolver.version` **major** bump landing in the same transition as a
  `registry_digest` change whose semantic output would *not* otherwise
  have changed — REQ-005's major-tier rule (AC-027) still forces re-
  resolve; the two triggers are independent, not mutually exclusive, and
  the major-version rule always wins over the ordinary comparison path
  when both are present in the same transition, *unless* REQ-004's
  Policy-Weakening short-circuit (including its fail-closed branch) has
  already Blocked the transition, in which case Block takes precedence
  over the major tier's forced-stale outcome (design.md's Design
  Decisions states this precedence explicitly, since ADR-0021 item 6
  places no condition on the major tier's applicability, but also never
  contemplates it overriding a Block).

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
  in REQ-006's test suite (AC-043) asserts this directly (a scan of every
  string literal in all three committed schema files, plus the four
  validator/comparator scripts' own source, against the same allowlist
  Epic A2's provider-contamination check already uses).

## Assumptions

- Epic A1's canonicalizer (`canonicalize-sdd-yaml.{py,sh,ps1,js}`) lands
  with the exact CLI/library shape `specs/epic-189-a1-project-context/
  design.md` already fixes — a stdin/stdout CLI whose only output is
  canonical-JSON bytes (or a hash), never a parsed-structure library API
  (INV-008; an earlier revision of REQ-003 assumed the latter, adversarial
  review "M canonicalizer API"). REQ-003's two-pass canonicalization
  procedure, and REQ-006's YAML-reading validators' own single canonicalizer-
  subprocess parse path (B4), are both written against that stdout-bytes
  shape, not a placeholder or a richer API.
- Epic A2's `contracts/capability-registry.schema.json` and its
  `evaluate-predicate` Evidence JSON Schema (an array-of-nodes output
  shape, `{result, evidence: [...]}`) land unchanged from
  `specs/epic-190-a2-capability-registry/design.md`'s already-`Passed`
  shape; if either changes before Epic A2 reaches implementation, this
  feature's REQ-001 `conditional_facets[].evidence` and `resolved_gates[
  ].stage` fields would need a corresponding follow-up revision (out of
  this spec's own scope to predict).
- Epic A3's `--facet-manifest <path>` read contract (INV-006) — structurally
  required in the `advisory`/`required` derived states, accepted-if-present-
  but-never-consulted in `disabled-legacy` — lands unchanged from
  `specs/epic-191-a3-path-ownership/requirements.md`'s current, still-
  `Pending` shape; this feature treats that shape as fixed because it is
  already committed prose in a sibling spec, not because Epic A3 has itself
  passed review yet.
- A future epic (not this one) will eventually build Registry- or
  ownership-scoped Policy Weakening detection. REQ-004's fail-closed
  contract (Goals) does not depend on this happening to be safe in the
  meantime — it Blocks a changed, indeterminate-verdict axis today — but it
  is written to compose cleanly once that detector exists: the detector
  only needs to start supplying a `weakened`/`not-weakened` verdict for its
  axis (in place of today's indeterminate default) for the ordinary
  semantic-output comparison path to become reachable for that axis again
  (a new weakening category being promoted from `const: "n/a"` to a live
  `enum` value in Epic A1's schema is the identical mechanism for the
  Project-Context axis's own 6 reserved categories).

## Open Questions

- OQ-002 (REQ-003): Context Projection's regeneration cadence (CI-gated
  drift check vs. on-demand) — an Epic A5 CI-wiring decision, not a schema
  decision (INV-007's investigation entry). (OQ-001, whether/what shape a
  full-track Capability Summary needs, is retired into Non-goals —
  investigation.md.)

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
- **Ambiguity-resolution risk**: REQ-004's fail-closed treatment of an
  indeterminate weakening verdict, and REQ-004's `registry_digest --whole`
  binding policy, are this feature's own, explicitly-flagged resolutions of
  gaps ADR-0021/Epic A2 leave implicit, not literal transcriptions — a
  future adversarial review could reasonably propose a different
  resolution; this spec records the reasoning behind each (Design
  Decisions, design.md) precisely so that disagreement, if it comes, can
  be evaluated against a stated rationale rather than a bare assertion. (An
  earlier revision carried this same risk for REQ-002's full-track
  Capability Summary shape and REQ-004's `evidence`-exclusion decision;
  both are retired — the former into Non-goals, the latter reverted to
  ADR-0021's literal boundary — so neither is a live ambiguity-resolution
  risk in this revision.)
- **Reserved-path risk**: REQ-003 fixes Context Projection's schema at
  Epic A1's already-reserved path
  (`plugins/sdd-quality-loop/scripts/generated/project-context.resolved.
  json`). If Epic A5 later finds that path unsuitable (e.g. a naming
  collision, or a discovery-contract mismatch discovered during
  implementation), amending it requires an explicit `guard-invariants`
  diff in Epic A5's own spec (per Epic A1's own reservation text,
  INV-007) — this feature does not, and structurally cannot, pre-empt that
  future amendment.
