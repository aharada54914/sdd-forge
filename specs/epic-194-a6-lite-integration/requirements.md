# Requirements: epic-194-a6-lite-integration

Spec-Review-Status: Passed
Source Issues: https://github.com/aharada54914/sdd-forge/issues/194,
https://github.com/aharada54914/sdd-forge/issues/187
Epic: https://github.com/aharada54914/sdd-forge/issues/187 (AI-DLC
Foundation tracking) — Epic A6 (Lite統合), issue #194, per
`docs/ai-dlc-foundation-decision-v2.md` §19 ("Epic A6：Lite統合") and §6
(Q5: liteトラックとの関係). ADR-0022 (Lite Capability Upgrade) is this
feature's own primary normative source; ADR-0016 (Workflow Axes Separation)
and ADR-0017 (Gate Stage Model) are structural context this feature reuses
unmodified.
Investigation: specs/epic-194-a6-lite-integration/investigation.md
(INV-001..INV-021; OQ-001..OQ-003, all three closed/resolved by
orchestrator ruling 2026-07-22 — see investigation.md's Open Questions
section, its Adversarial Spec Review Response, and its Adversarial Final
Verification Response)

## Overview

`docs/ai-dlc-foundation-decision-v2.md` §6 confirms the existing `sdd-lite`
implementation's own design (three-file generation, skipped review loops, a
pre-generation risk-upgrade gate, a ship-time recheck, `lite-gate`'s
independent re-verification — all verified against live code, decision v2
§6 opening line) and directs that Capability enforcement (ADR-0016's three
workflow axes; ADR-0020's Predicate DSL; the Registry Epic A2 defines) be
*extended* to that track without forcing every lite project through the
full Capability pipeline. §19 fixes Epic A6's own deliverable list
verbatim: "Capability-aware risk-upgrade / lite eligibility /
capability-summary.yaml / lite gate checks / full upgrade / artifact生成前
Block / 保護ファイル（lite-spec SKILL / risk-upgrade-policy）変更の
human-copy工程." Four sibling Foundation epics (A2 Registry, A3 Path
Ownership, A4 Facet Manifest, A5 Capability Resolver) each already fix a
piece of the machinery this feature connects; per this task's own
instruction, this package adds no independent design judgment beyond what
those sibling packages, ADR-0022, and decision document v2 §6/§19 already
state, and records as an Open Question (below) any point where those
sources are genuinely silent rather than resolving it unilaterally.

This is a **Phase 1 (specification) package only** — `requirements.md`,
`design.md`, `investigation.md`, `acceptance-tests.md`. No implementation
code, no `contracts/*.schema.json` file, no `plugins/**`/`scripts/**`/
`tests/**` edit, and no `tasks.md`/`traceability.md` exists yet (Non-goals,
below); those are Phase 2, per `AGENTS.md`'s Required Workflow and this
task's own explicit instruction.

## Target Users

- **A Capability author** (a maintainer of a Capability Pack, or of this
  repository's own bundled Capabilities once any exist) who needs to
  declare, per Capability, which Lite-specific checks a Lite-track Feature
  matching that Capability must run, and which project characteristics
  force that Capability's use out of the Lite track entirely.
- **A `lite-spec`/`lite-gate` invoker** (a human or agent running the
  `sdd-lite` flow) who needs the existing risk-upgrade gate and the
  existing lightweight quality gate to stay exactly as fast and
  self-contained as they are today, while gaining Capability-awareness
  where the Registry actually defines it.
- **A future Epic A2 Registry maintainer** who needs this feature's own
  schema-extension design to be additive and non-breaking against every
  Registry instance A2's own Phase 2 implementation, and any real
  Capability Pack authored against the v1 shape, will already have
  produced.
- **A human reviewer/spec-review-loop** who needs every REQ below to cite
  the sibling-epic or ADR text it is wiring to, per this repository's own
  "Spec factual-claim evidence citations" convention (`AGENTS.md`).

## Problems

- Without a Registry field a Lite Feature's matched Capabilities can
  contribute Lite-specific check IDs to, decision document v2 §6's own
  worked Capability Summary example (`required_lite_checks: [build, test,
  installer-dry-run]`) and ADR-0022 item 4's own text ("`lite-gate` runs...
  only the Lite-specific checks **defined by the Registry**") both
  presuppose a source that does not exist in any landed spec — confirmed
  independently by this feature's own investigation (INV-003/INV-004) and
  by Epic A5's own investigation (INV-019, cited verbatim in INV-004),
  which already names this exact gap as this feature's own prerequisite,
  not a risk it can resolve on its own authority.
- Without this field, Epic A5's Lite-track Resolver path Blocks
  (`lite-check-source-undefined`) for essentially every real Lite Feature
  with at least one matched Capability (A5 `design.md:1729-1748`,
  INV-004) — the Lite track's own Capability-awareness is presently inert
  in practice, not merely undocumented.
- `contracts/lite-upgrade-reason-catalog.json`'s own seeded vocabulary
  (ADR-0022's five YAML-example tokens) does not yet cover the eleven-
  category forced-upgrade list ADR-0022's own prose names (cloud
  production, a Durable Workflow, a public package registry, Store
  distribution, auto-update, Stable distribution involving code signing,
  external authentication, PII, payments, multiple tenants, a high-risk
  migration) — A2's own spec explicitly defers that expansion to this
  feature (INV-007).
- `check-risk-upgrade.{sh,ps1}`'s existing keyword-scan gate has no input
  channel for a Capability-derived forced-upgrade reason today (INV-009) —
  ADR-0022's own Consequences section already names the resulting
  obligation: "Epic A6 must wire these reasons into the existing
  risk-upgrade gate rather than duplicating upgrade logic."
- `lite-gate`'s existing five checks (placeholder-scan, lint, typecheck,
  build, test) have no mechanism to also run whatever Lite-specific checks
  a matched Capability's own Registry entry names — decision document v2
  §6 and ADR-0022 item 4 both require this while equally requiring
  `lite-gate` "never grows into a second `quality-gate`" (ADR-0022 item 4).
- `lite-spec`'s and `risk-upgrade-policy.md`'s and `check-risk-upgrade.
  {sh,ps1}`'s protected status (epic-136 Phase 2, ADR-0022 item 5) means
  any of this feature's own edits to those four files cannot be applied
  directly — the human-copy flow (`specs/<feature>/human-copy/` +
  `apply-protected-files`, ADR-0011) must be planned as part of this
  feature's own implementation-phase cost, not discovered late (ADR-0022's
  own Consequences section states this explicitly).

## Dependencies

- **Epic A2 (Capability Registry) — Registry schema shape, validator
  check-suite pattern, `lite_policy`'s current two-key shape, the
  `lite-upgrade-reason-catalog.json` additive-versioning mechanism, and the
  script-relative discovery contract (hard, already-`Passed` dependency,
  content-frozen)**: `contracts/capability-registry.schema.json`'s
  `capabilities[]` shape (investigation.md INV-003) is the fixed vocabulary
  this feature's REQ-001 extends by exactly one new key inside `lite_
  policy` — this feature introduces no new top-level `capabilities[]`
  field, no new Gate-stage enum value, and no new Predicate DSL operator.
  This feature's own new field explicitly reuses A2's own `upgrade_
  reasons`/`lite-upgrade-reason-catalog.json` pattern (open string array,
  catalog-validated at the validator level, not schema-level enum,
  additive `catalog_version` growth) rather than inventing a second
  validation mechanism (Field Definitions, below). This feature does not
  itself author `contracts/capability-registry.schema.json` (that file
  does not exist yet anywhere, INV-013 — Epic A2's own Phase 2 does, and
  this feature's own schema-revision design is handed to that same Phase
  2 implementation, or to a follow-up Epic-A2-owned revision task, per
  A5's own Dependencies section's identical framing of this same gap,
  "owner: Epic A2's own maintainers" reused verbatim from A5's own text —
  this feature is the spec that fixes *what* the revision must contain,
  the same relationship A4 has to A2's Registry schema itself).
- **Epic A4 (Facet Manifest) — the Capability Summary schema (hard,
  already-`Passed` dependency, content-frozen)**: `contracts/capability-
  summary.schema.json`'s exact shape (investigation.md INV-005) is what
  this feature's `lite-gate` extension (REQ-003/REQ-004) reads; this
  feature adds no field to it and defines no alternate or Full-track
  shape (A4's own Non-goals already reserve that question). This feature's
  own new Registry field's *name* (`required_lite_checks`, Field
  Definitions) is chosen to match A4's already-frozen Capability-Summary
  field of the identical name exactly, following the same non-renaming
  precedent A2/A4 already established for `required_facets` (declared per-
  Capability, unioned verbatim into the Feature-level output under the
  same name, unlike `lite_policy`→`lite_eligibility` or `minimum_
  enforcement`→`capability_minimum_enforcement`, both of which *are*
  renamed because they carry an aggregation-specific derived shape,
  investigation.md INV-006) — this feature does not invent that naming
  choice, it is the most direct reading of A5's own Resolver-side text
  already using the name `required_lite_checks` for the per-Capability
  contribution it cannot yet source (A5 `design.md:947`, INV-004).
- **Epic A5 (Capability Resolver) — the Lite-track Resolver contract this
  feature's REQ-003 consumes, and the `lite-check-source-undefined`
  Block condition this feature's REQ-001 is the named prerequisite for
  (soft dependency: A5's own `Spec-Review-Status` is `Pending`,
  investigation.md INV-002 — this feature treats A5's current text as the
  best available statement of the contract, not as frozen)**: A5's own
  `requirements.md` Dependencies section (`:119-152`) already names this
  feature (Epic A6) as the owner of the Registry-schema revision A5's own
  Lite-track resolve path needs (investigation.md INV-004) — this feature
  is not inventing that ownership relationship, it is fulfilling a
  prerequisite A5's own package already recorded against it, by name. This
  feature's own REQ-003 (Capability Summary consumption) reads only the
  artifact A5's Resolver writes (`specs/<feature>/capability-summary.
  yaml`, A4-schema'd) — this feature does not re-derive `affected_
  components`, does not re-evaluate any Capability `trigger`, and does not
  reimplement A5's own union-match aggregation rule for `required_lite_
  checks` (investigation.md INV-006) inside `lite-gate` or anywhere else
  this feature touches. Because A5 is not yet `Passed`, this feature's own
  Risks (below) record that A5's exact field names/aggregation rule could
  still change before this feature reaches implementation, and that this
  feature's own REQ-001 field-naming choice (`required_lite_checks`,
  matching A5's own current text) is the best-grounded choice available
  today, not a guarantee against later drift.
- **Epic A3 (Component Path Ownership) — no direct schema dependency; cited
  only for the `workflow.capability_enforcement` three-state derivation
  rule this feature's own REQ-005 discussion of the pre-generation gate's
  timing constraint refers to (soft, informational)**: this feature does
  not call `resolve-component-paths` or any A3 script directly, and does
  not redefine A3's own `disabled-legacy`/`advisory`/`required` derivation
  (ADR-0016 item 4) — Open Questions (below) name where that derivation's
  own timing interacts with this feature's own pre-generation gate scope.
- **ADR-0011 (Handle-relative protected-file publication, human-copy
  flow)**, **ADR-0016 (Workflow Axes Separation)**, **ADR-0017 (Gate Stage
  Model)**, and **ADR-0022 (Lite Capability Upgrade)** are Accepted, not
  proposed by this feature; this feature transcribes their already-fixed
  rules into a concrete extension of already-existing scripts/skills, it
  does not re-decide any of them. ADR-0022 item 5 is this feature's own
  direct authorization to use the human-copy flow for its REQ-002 edits to
  the three protected `sdd-lite` scripts/policy file (`risk-upgrade-
  policy.md`, `check-risk-upgrade.sh`, `check-risk-upgrade.ps1`) and its
  REQ-005 edits to `lite-spec/SKILL.md`; investigation.md INV-008/OQ-001
  records why `lite-gate/SKILL.md` (REQ-004) is scoped as a **direct**
  edit instead, on the currently-live `guard-invariants.json` evidence.
  This feature's own human-copy staging additionally requires a
  **feature-scoped anchored runner** capable of reading `specs/epic-194-
  a6-lite-integration/human-copy/` — the only runner that exists today,
  `specs/epic-136-phase2-gates/human-copy/apply-protected-files.ps1`, is
  hard-anchored to its own fixed `specs/epic-136-phase2-gates/human-copy`
  prefix and additionally requires a staged canonical `guard-invariants.
  json` copy this feature does not stage (investigation.md INV-019,
  2026-07-22 adversarial review, Major [M3]) — this feature therefore
  names, as part of its own REQ-002/REQ-005 scope, the contract such a
  runner must satisfy (design.md Protected-File Statement, revised), for
  a future implementation task to author and have security-reviewed,
  rather than assuming the Epic-136 runner applies unmodified.
- **A5's own soft dependency on this feature, restated for symmetry**: A5's
  own `requirements.md` Dependencies section (`:201-206`) separately names
  "a future epic (plausibly A6/A8)" as the decider of when `compare-facet-
  manifest-staleness` is invoked — this feature does not take up that
  question (Non-goals, below); it is out of scope for the same reason A5
  left it out of its own scope (no caller is named by any正本 text).

## Goals

- **REQ-001** (Registry `lite_policy` v1.1 additive extension and
  `lite-upgrade-reason-catalog.json` vocabulary growth — decision v2 §6,
  ADR-0022 items 2-3, this feature's own Dependencies section above):
  Author the *design* (schema fragment, migration rule, validator-check
  addition, projection-ripple note — not the live `contracts/*` file,
  which Epic A2's own Phase 2 or a follow-up revision task applies,
  Dependencies above) for:
  1. A third key on the Registry's `lite_policy` object,
     `required_lite_checks` (array of unique, non-empty strings; optional;
     default `[]` when `lite_policy` itself is present but the key is
     omitted — matching `upgrade_reasons`'s own optionality/default
     pattern exactly, investigation.md INV-003): `lite_policy` becomes
     `{eligible: boolean (required), upgrade_reasons: array of non-empty
     strings (optional, default []), required_lite_checks: array of
     unique non-empty strings (optional, default [])}`,
     `additionalProperties: false` (three keys, not two). Each token is
     validated at the validator level (a new check, analogous to A2's own
     REQ-003(h) "lite-upgrade-reason-catalog conformance") against a new,
     A6-owned versioned catalog, `contracts/lite-check-catalog.json`
     (`"schema": "lite-check-catalog/v1"`), seeded with the three concrete
     check-ids ADR-0022 item 3's own worked `capability-summary.yaml`
     example names verbatim (`required_lite_checks: [build, test,
     installer-dry-run]`) — `build`, `test`, `installer-dry-run` — not the
     single `installer-dry-run` token an earlier revision of this design
     seeded (2026-07-22 adversarial review, Major [M1], investigation.md
     INV-017: the single-token seed rejected this same feature's own
     `build`/`installer-dry-run` Registry-declaration fixture at validator
     check (j), and A4's own AC-013 fixture independently fixes the
     identical three-token canonical example). `build`/`test` are
     Registry-catalog-legitimate tokens even though `lite-gate` treats a
     Registry-sourced `build`/`test` declaration as a no-op against its own
     already-existing baseline checks of the same name (REQ-004, AC-015) —
     the catalog governs which tokens a Capability author may legitimately
     *declare*, independent of whether `lite-gate` executes a given token
     as a new check or recognizes it as already covered. The catalog
     remains explicitly left open for additive, `catalog_version`-bumped
     growth beyond these three as real Capabilities are authored (this
     feature does not invent a larger seed vocabulary beyond what
     ADR-0022/A4's own canonical example already names — Non-goals,
     below).
  2. Growing `contracts/lite-upgrade-reason-catalog.json`'s own `reasons`
     array (a `catalog_version` bump, no schema change — A2's own additive
     mechanism, investigation.md INV-007) from its current five-token seed
     to cover ADR-0022's full forced-upgrade prose list. This feature maps
     the prose to snake_case tokens, keeping every already-seeded token
     (`public_distribution`, `production_cloud_runtime`, `durable_
     workflow`, `external_identity`, `pii`) unchanged and additive-only,
     and adding: `public_package_registry`, `store_distribution`, `auto_
     update`, `code_signing`, `payments`, `multi_tenant`, `high_risk_
     migration` (Field Definitions, below, states the mapping and why it
     is additive rather than a rename of any existing token — an existing
     Registry instance that already declares `upgrade_reasons:
     [public_distribution]` remains valid and semantically unchanged).
  3. **Migration rule** (decision v2 §6/ADR-0022, and this task's own
     instruction): additive only. A v1 Registry instance (one authored
     against the pre-extension, two-key `lite_policy` shape) remains
     schema-valid under the v1.1 schema with no change — `required_lite_
     checks` simply defaults to `[]` wherever absent, meaning that
     Capability contributes nothing to any Lite Feature's aggregated
     `required_lite_checks` and — per the combination matrix's own "lite ×
     lite-three-file × required → Lite専用Gateを持つCapabilityだけ利用可能"
     row (decision v2 §6) — is not among the Capabilities usable under
     `capability_enforcement: required` on the Lite track until a
     Capability author opts in by adding the new field (this is the
     literal meaning of this task's own "v1 Registry は field 欠落 = Lite
     不可のまま有効" instruction: the Registry instance stays valid; the
     *Capability* stays outside the required-enforcement Lite surface
     until its own author opts in).
  4. **Schema version.** No existing `contracts/*.schema.json` in this
     repository uses a decimal (`vN.M`) wire-level `schema` const string
     anywhere (investigation-time grep across every `contracts/*.schema.
     json` in this worktree found only integer `vN` forms) — this feature
     therefore does **not** propose changing the Registry instance's own
     top-level `"schema": "capability-registry/v1"` discriminator string
     (an additive, backward-compatible field addition does not change
     which major shape a document conforms to; both a field-absent and a
     field-present instance are equally valid `capability-registry/v1`
     documents). "v1.1" (this task's own and this feature's own framing)
     names the schema *file's* own additive revision for human/changelog
     tracking, following the same "additive/versioned, not a closed enum"
     posture A2 already established for the reason catalog's own
     `catalog_version` — this feature records the distinction explicitly
     rather than inventing a wire-level minor-version field no sibling
     contract in this repository uses (Field Definitions, below).
  5. **Validator and projection ripple.** A2's own validator design
     (REQ-003, checks (a)-(i)) gains one new, independently identifiable
     check — "(j) lite-check-catalog conformance" — mirroring check (h)'s
     own shape exactly (every `lite_policy.required_lite_checks` token
     must resolve against `contracts/lite-check-catalog.json`'s own
     `checks` array; unrecognized token fails validation, fail-closed;
     the catalog's own vocabulary stays additive). A2's own projection
     generator (REQ-005, `generate-gate-capabilities.{py,sh,ps1}` →
     `plugins/sdd-quality-loop/scripts/generated/gate-capabilities.json`)
     never carries `lite_policy`/`required_lite_checks` in any version —
     the generated projection's own shape is, and remains, `stage:
     implementation` Gate data only (A2's own REQ-005 scope, investigation.
     md INV-018). Epic A5's Resolver — the actual consumer of this
     feature's new field — reads it directly from the **full, validated
     Registry**, through A2's own package-relative discovery contract,
     exactly the same route A5 already uses for `trigger`/`required_
     facets` today (A2 `requirements.md` Dependencies, "Epic A5...
     downstream consumer," cited verbatim in investigation.md INV-018) —
     never through the projection. This corrects an earlier revision of
     this item, which characterized the new field as "passively flowing
     through" the projection generator's own `--check` cycle (2026-07-22
     adversarial review, Major [M2]); that characterization was wrong on
     two independent counts (the projection never carries this field, and
     A5 never reads the projection for it). The **only** real ripple to
     `generate-gate-capabilities` is that its own `_generated` header's
     `sha256` value (hashing the full, committed Registry **file**, not
     any field within it) changes once the v1.1 schema/instance and this
     feature's new catalog land — a metadata-hash re-generation the
     existing `--check` drift-detection mode already handles today for any
     Registry byte-change, with no generation-*logic* change of any kind.
     This feature still adds no new generator and does not touch
     `generate-gate-capabilities.{py,sh,ps1}` itself (Non-goals, below,
     unchanged) — design.md's own Test Strategy separately confirms the
     field's own absence from the projection's own output shape (design.md
     Test Strategy, item 11).
- **REQ-002** (Capability-aware risk-upgrade wiring — ADR-0022's own
  Consequences section, "Epic A6 must wire these reasons into the existing
  risk-upgrade gate rather than duplicating upgrade logic"): Extend
  `check-risk-upgrade.{sh,ps1}`'s existing single-positional-argument
  contract (investigation.md INV-009) with a second, **optional** input —
  a path to a small, already-computed JSON fragment (produced upstream,
  outside this script, by the REQ-005/OQ-002-resolved Capability-matching
  mechanism: `{"capabilities": [{"id": <capability-id>, "eligible":
  <boolean>, "upgrade_reasons": [<token>, ...]}, ...]}`, Field Definitions
  below) — merged into the existing trigger-reporting output exactly the
  way a seventh-through-Nth keyword-table row would be, without adding a
  seventh row to the keyword table itself and without this script
  re-deriving, re-evaluating, or duplicating any Predicate-DSL/Registry-
  matching logic (INV-009's own "(a) vs (b)" framing; this feature adopts
  (a) — extending the one existing script's own I/O contract — because
  ADR-0022's own Consequences text names "the existing risk-upgrade gate"
  by name, not a new composed wrapper).

  **Two distinct input states, not one (2026-07-22 adversarial review,
  Blocker [B3], reversing an earlier revision's single "absent-or-invalid"
  degrade path):**
  1. **Second argument omitted entirely** (every existing call site, until
     REQ-005's callers are updated): behavior is byte-identical to today's
     (Non-goals: no change to the six-row keyword table, its ordering, or
     its exit-code contract for the already-documented single-argument
     invocation). This is the *only* condition this REQ's "legacy,
     keyword-only-compatible" guarantee (AC-007) covers.
  2. **Second argument supplied**: the file at that path is now read and
     validated eagerly. If it is unreadable, not valid UTF-8 JSON, or does
     not conform to the fragment shape (Field Definitions below — a
     missing `capabilities` key, a non-array value, or any array entry
     missing `id`/`eligible`) — the script exits `2`
     ("`risk-upgrade: capability-reasons fragment invalid`"), the same
     usage-error exit code `check-risk-upgrade` already uses for a
     missing/unreadable primary source file (investigation.md INV-009),
     and performs **no** trigger reporting of any kind. This reverses an
     earlier revision of this REQ, which silently degraded any such
     failure to "no Capability-derived trigger" (an accepted, non-erroring
     path) and simultaneously, self-contradictorily, described that same
     degrade as "fail-closed" (investigation.md INV-014) — a *supplied*
     fragment the caller could not produce correctly is evidence of an
     upstream defect, not a legitimate "nothing to report" state, and must
     Block rather than silently pass the Feature through as if no
     Capability-derived signal existed at all.

  On a **successfully validated, supplied** fragment: every entry whose
  own `eligible` is `false` contributes to `capability_triggers[]`, in the
  fragment's own array order — its own `upgrade_reasons` tokens if the
  array is non-empty, or, if `upgrade_reasons` is empty/absent, a single
  synthetic token, `ineligible:<id>` (its own Capability `id`), so an
  ineligible-with-no-named-reason Capability still produces a non-empty,
  diagnostically-named trigger rather than silently contributing nothing
  (2026-07-22 adversarial review, Blocker [B4] — Edge Cases, below,
  restates this scope). An entry whose own `eligible` is `true`
  contributes nothing. The script's own `full-required: ...` output
  line's `triggers=` list places every keyword-derived token (in the
  existing fixed table order) before every Capability-derived token (in
  the order just described), and the exit code is `10` whenever either
  source produces at least one trigger token — the merge is a logical OR
  over the two independent sources, never a reason for the keyword scan
  itself to change.

  This is a protected-file edit (three files: `risk-upgrade-policy.md`,
  `check-risk-upgrade.sh`, `check-risk-upgrade.ps1` — investigation.md
  INV-008) staged through `specs/epic-194-a6-lite-integration/human-copy/`
  (ADR-0011 pattern, ADR-0022 item 5) at implementation time, not applied
  directly — the feature-scoped anchored runner this staging requires is
  itself a new design obligation this feature now names explicitly
  (Dependencies, above; design.md Protected-File Statement; 2026-07-22
  adversarial review, Major [M3]).
- **REQ-003** (Capability Summary consumption contract for `lite-gate` —
  decision v2 §6, "lite-gateは...Registryで定義されたLite専用チェックだけを
  実行する"): Define the read-only contract `lite-gate` uses to source
  which Lite-specific checks a given Task's Feature must additionally run,
  beyond its own existing five.

  **Absent-Summary handling is no longer a single, uniform "zero checks,
  no error" rule (2026-07-22 adversarial review, Blocker [B6], revising an
  earlier revision that treated every absent-Summary case identically):**
  `lite-gate` first reads `workflow.capability_enforcement` directly from
  the Project Context, if one exists (a read of an already-derived value,
  not a re-derivation of A3's own three-state logic, matching the "reads a
  value another mechanism already derived" discipline this REQ already
  applies to `required_lite_checks`/`full_upgrade_required` themselves).
  - **No Project Context at all** (`disabled-legacy`, ADR-0016 item 4's
    own "capability mechanism does not run" condition, requirements.md
    Edge Cases "Compatibility fallback"): an absent `capability-summary.
    yaml` is legitimate — `lite-gate` treats the Feature as carrying zero
    Registry-sourced Lite-specific checks, running only its existing five
    baseline checks, no error, no Block (unchanged from an earlier
    revision's own rule for this one case).
  - **Project Context present, `capability_enforcement` is `advisory` or
    `required`** (active): a successful Lite-track Resolver invocation
    *always* stages a Capability Summary, zero-matched-Capability included
    (a schema-valid, empty-array Summary, investigation.md INV-016) — an
    absent `capability-summary.yaml` under this condition can only mean
    the Resolver Blocked, failed, was never run, or the file was removed
    after the fact, never a legitimate "nothing to check" state.
    `lite-gate` therefore treats this case as `VERDICT: FAIL`, `Status`
    unchanged, reason "`capability-summary.yaml` missing under active
    `capability_enforcement`" — never a silent fallback to the five
    baseline checks alone (this is the pre-Epic-A5-implementation gap's
    own honest treatment once A5 reaches `Passed`: before that point, this
    condition is expected to fire on every real active-enforcement Lite
    Feature, which is itself the correct, fail-closed signal that the
    prerequisite chain is incomplete, not a defect in this REQ's own
    design).

  If present, `lite-gate` validates the Summary against `contracts/
  capability-summary.schema.json` (A4-owned, content-frozen, this feature
  does not re-derive or duplicate that validation logic — it calls A4/A5's
  own future `validate-capability-summary` script, the same "call the
  owning epic's own validator, do not reimplement it" discipline A5's own
  package already applies to A2's `evaluate-predicate` and A1's
  canonicalizer); a schema-invalid Summary is `VERDICT: FAIL` per the
  existing Edge Case, unchanged. On a schema-valid Summary, `lite-gate`
  reads two fields: `required_lite_checks` (the array A5's Resolver
  already aggregates via union-match across matched Capabilities,
  investigation.md INV-006 — this feature does not re-aggregate it), and
  `full_upgrade_required` — **no longer read-only/informational only**
  (2026-07-22 adversarial review, Blocker [B2], resolving OQ-003): `true`
  is itself a `VERDICT: FAIL` condition (REQ-004's own Step 2a states the
  exact position), an independent backstop re-check against a stale or
  mis-set Summary, never assuming its own written existence already proves
  every full-upgrade determination happened correctly upstream
  (investigation.md, OQ-003 resolution). This feature defines no new file
  and no new schema for this REQ — it is a consumption contract only, over
  an artifact A4/A5 already fully type and produce.
- **REQ-004** (`lite-gate` extension to execute Registry-sourced Lite-
  specific checks — decision v2 §6, ADR-0022 item 4): Extend `lite-gate/
  SKILL.md`'s existing five-step Process (investigation.md INV-010) with
  **two** additional steps, both inserted between the existing Step 2
  (project lint/typecheck/build/test) and Step 3 (quality-report
  generation):

  **Step 2a (NEW, resolves OQ-003, Blocker [B2]) — `full_upgrade_required`
  backstop re-check.** Immediately after REQ-003's own Summary-presence/
  schema-validation handling: if the Summary is present, schema-valid, and
  `full_upgrade_required: true`, `VERDICT: FAIL`, `Status` unchanged,
  reason names the field and directs to the full SDD workflow — this
  feature's own independent backstop, not a restatement of REQ-005's own
  pre-generation Block (a different position, and, per investigation.md
  INV-015, a Resolver output that cannot on its own distinguish an
  `advisory`-tolerated from a `required`-Blocking absence, making this
  feature's own explicit re-check the only place this specific signal is
  guaranteed checked post-resolve). `false` continues to Step 2b.

  **Step 2b (Registry-sourced check execution, position unchanged from an
  earlier revision):** for every check-id in REQ-003's own sourced
  `required_lite_checks` list that is **not** already one of the five
  baseline check names (`placeholder`, `lint`, `typecheck`, `build`,
  `test` — a Registry-sourced list may legitimately repeat a baseline
  name, ADR-0022 item 3's own worked example lists `build`/`test`
  alongside `installer-dry-run`, investigation.md INV-017; a repeated
  baseline name is a no-op, not a second execution, Edge Cases below),
  `lite-gate` first re-validates the id against the check-id identifier
  grammar (Field Definitions, below, `^[a-z0-9][a-z0-9-]*$` — 2026-07-22
  adversarial final verification, NEW-01, investigation.md INV-021) — a
  grammar-failing id is `VERDICT: FAIL` before any discovery is
  attempted, never passed through as a literal path segment — then
  resolves an executable command for a grammar-valid check-id via a
  **bounded, portable, safety-hardened command-discovery contract**
  (design.md API / Contract Plan, "Lite-check command-discovery
  contract," NEW — 2026-07-22 adversarial review, Blocker [B7];
  safety-hardened, NEW-01): a repo-root `package.json`'s own
  `scripts[<id>]` entry (invoked with `id` passed as a direct argv
  element, never shell-interpolated), or else **both** members of a
  repo-root `scripts/<id>.sh` **and** `scripts/<id>.ps1` pair (a check-id
  is mapped by this step only when both runtime members exist, pass a
  canonical-path repo-root-`scripts/`-containment proof, and are regular
  files — never symlinks/reparse points; "pair" means the two-file
  dual-runtime set, not "whichever member matches the currently-running
  runtime," resolving an earlier ambiguity between this text and design.md
  API / Contract Plan), checked in that fixed order; a mapped check-id
  runs the same self-executing, self-capturing way `lite-gate` already
  runs its own lint/typecheck/build/test commands (never trusting an
  implementer's self-report — ADR-0022 item 4's own "`lite-gate` never
  grows into a second `quality-gate`" boundary means this feature adds
  *execution* of a bounded, Registry-named check list, never evidence-
  bundle machinery, cross-model verification, or any other `quality-gate`-
  only mechanism), recording each one's PASS/FAIL in the same `reports/
  quality-gate/<task-id>.md` quality report the existing Process already
  writes, using the same "any FAIL → `VERDICT: FAIL`, no `Status` change"
  rule the existing Steps 1-2 already apply.

  **An unmapped Registry-sourced check-id is now `VERDICT: FAIL`, not
  `N/A` (2026-07-22 adversarial review, Blocker [B7], reversing an earlier
  revision's rule):** a `required_lite_checks` declaration is a Capability
  author's own promise that this check runs; a check-id neither
  `package.json` nor the `scripts/<id>.{sh,ps1}` convention can resolve to
  a command — including a check-id that fails the identifier grammar
  before discovery is even attempted, whose `scripts/<id>` candidate is a
  symlink/reparse point or resolves outside `scripts/`, or that stages
  only one runtime member of the `.sh`/`.ps1` pair (Field Definitions,
  below, NEW-01, investigation.md INV-021) — means that promise cannot be
  kept, and this feature no longer lets that state PASS the gate
  silently. `N/A` remains the correct, unchanged outcome **only** for
  Step 2's own **pre-existing, non-Registry-sourced** convention — a
  missing local lint/typecheck project command/config (`SKILL.md:37`) —
  an orthogonal convention this REQ does not touch or extend to
  Registry-sourced check-ids (Non-goals, below, revised).

  Per investigation.md INV-008, and per OQ-001's now-**closed** ruling
  (investigation.md, Minor finding), this is a **direct** edit to
  `lite-gate/SKILL.md` (currently unprotected), not a human-copy one —
  re-verified against the then-current `guard-invariants.json` at
  implementation-start time (Roles and Permissions, below), not an open
  design question this package still carries forward.
- **REQ-005** (Full-upgrade forced path — decision v2 §19, "full upgrade
  経路: Lite不適格 capability 検出時の full への強制昇格（artifact 生成前
  Block — lite-spec の risk-upgrade gate と同じ位置）"): At the identical
  position `lite-spec`'s existing Risk-Upgrade Gate already occupies
  (before beginning the Process or creating any file under
  `specs/<feature>/`, investigation.md INV-010), a Lite-ineligible-
  Capability detection Blocks lite-artifact creation exactly the way an
  existing keyword-trigger match already does — same exit-code contract
  (`10`, `full-required: ...`), same "direct the user to `/sdd-bootstrap:
  sdd-bootstrap-interviewer`" handoff, same "`--lite` never overrides this
  decision" rule (`lite-spec/SKILL.md:45-48`).

  **The signal source is now fixed (2026-07-22 adversarial review, Blocker
  [B1], resolving OQ-002 — investigation.md's Open Questions section
  states the full ruling):** before this Block runs, `lite-spec` evaluates
  every Registry Capability's own `trigger` (via A2's `evaluate-predicate`,
  one call per Capability × declared component) against every component
  the Project Context (Epic A1) already declares — Project-Context-wide,
  diff-independent (OQ-002's own candidate (a)) — and assembles the result
  into REQ-002's own Capability-derived trigger fragment shape (Field
  Definitions), which it passes to `check-risk-upgrade` as the new second
  argument at this exact call site. Any matched, ineligible Capability
  (`lite_policy.eligible: false`) Blocks here, via REQ-002's own
  merged-trigger output contract — this REQ does not define a second,
  independent Block mechanism.

  **This intake-time Block is a first, early-exit stage, not the sole
  enforcement point:** the existing `ship`-time recheck (the second
  `check-risk-upgrade` invocation, investigation.md INV-010, Main
  Workflows step 6) remains independently mandatory, unmodified in
  position, and is not superseded by this REQ's own intake-time addition —
  both stages are normative (OQ-002 resolution, investigation.md). A
  Feature that touches a component not yet accurately reflected in the
  Project Context at intake time (added or changed after intake) can still
  be caught only at the `ship`-time stage; this is an accepted, defense-
  in-depth property of the two-stage design, not a gap this REQ leaves
  uncovered.

  This is a protected-file edit to `lite-spec/SKILL.md` (investigation.md
  INV-008), staged through the same `specs/epic-194-a6-lite-integration/
  human-copy/` flow as REQ-002 (Dependencies, above, records the
  feature-scoped-runner obligation this staging now names explicitly,
  Major [M3]).
- **REQ-006** (tests — design-phase target, matching A2/A4/A5's own REQ-
  00N precedent of describing, not authoring, `tests/*.tests.sh` +
  `.tests.ps1` pairs in a Phase 1 package): Fix the fixture inventory a
  future implementation task's test suite must cover: (a) an
  **eligible** Capability (matched, `lite_policy.eligible: true`, non-
  empty `required_lite_checks`) resolves without a forced upgrade and
  contributes its own checks to the aggregate; (b) an **ineligible**
  Capability (matched, `lite_policy.eligible: false`, non-empty `upgrade_
  reasons`) forces `full-required` at REQ-005's own Block position, citing
  the matched Capability's own `upgrade_reasons` tokens; (c) a **v1
  Registry compatibility** fixture — a Capability entry with no `required_
  lite_checks` key at all remains schema-valid under the v1.1 schema and
  contributes `[]` to the aggregate (REQ-001 item 3's migration rule,
  made mechanically testable); (d) a **Capability Summary consumption**
  fixture — `lite-gate` given a well-formed `capability-summary.yaml`
  correctly runs every additional `required_lite_checks` entry and records
  each in the quality report (REQ-003/REQ-004); (e) an **unmapped required
  check-id** fixture (revised, Blocker [B7]; safety-hardened, NEW-01) — a
  Registry-sourced check-id neither the `package.json`-script nor the
  `scripts/<id>.{sh,ps1}` command-discovery contract can resolve is
  `VERDICT: FAIL`, never `N/A` and never a silent skip (REQ-004); a
  companion fixture confirms Step 2's own pre-existing, non-Registry-
  sourced missing-local-command convention is unchanged (still `N/A`);
  paired POSIX/PowerShell negative fixtures further confirm a
  grammar-invalid id (`../`, a path separator, an option-like prefix
  such as `--help`), a `scripts/<id>` symlink/reparse point that
  escapes or resolves inside `scripts/`, and a pair with only one
  runtime member staged are each `VERDICT: FAIL` via this same
  unmapped/grammar-failure path, never a partial-runtime pass (Field
  Definitions, design.md API / Contract Plan, "Lite-check
  command-discovery contract"); (f) an **unknown-catalog-token** fixture — a
  `required_lite_checks` or `upgrade_reasons` token absent from its own
  catalog fails Registry validation, fail-closed (REQ-001 item 5); (g) a
  **disabled-legacy missing-Capability-Summary** fixture — `lite-gate`
  given no `capability-summary.yaml` at all, and no Project Context, runs
  its existing five baseline checks only, unchanged from today's behavior
  (REQ-003's own absent-artifact rule, disabled-legacy case only); (h) a
  **`full_upgrade_required: true`** fixture — `lite-gate`'s own Step 2a
  Blocks (`VERDICT: FAIL`) on a schema-valid Summary carrying this value,
  independent of REQ-005's own pre-generation Block ever having fired
  (REQ-004, Blocker [B2]); (i) a **supplied-but-invalid capability-reasons
  fragment** fixture — `check-risk-upgrade` given a `--capability-reasons`
  path to an unreadable/malformed/shape-invalid file exits `2`, never
  degrading to `lite-eligible` (REQ-002, Blocker [B3]); (j) an
  **ineligible-with-no-reasons** fixture — a fragment entry with
  `eligible: false` and an empty/absent `upgrade_reasons` still produces a
  non-empty `triggers=` entry (`ineligible:<id>`) and exit `10` (REQ-002,
  Blocker [B4]); (k) an **active-enforcement missing-Capability-Summary**
  fixture (NEW, Blocker [B6]) — `lite-gate` given `workflow.capability_
  enforcement: advisory` or `required` and no `capability-summary.yaml` is
  `VERDICT: FAIL`, distinct from fixture (g)'s disabled-legacy case
  (REQ-003); (l) a **required-enforcement matched-Capability field-
  absence** fixture (NEW, Blocker [B5]) — a matched Capability under
  `capability_enforcement: required` whose own `lite_policy` carries no
  `required_lite_checks` key at all is documented as the trigger condition
  for A5's own (extended) `lite-check-source-undefined` diagnostic,
  distinct from the same Capability matched under `advisory` (tolerated)
  and from a zero-matched-Capability resolve (a third, non-Blocking
  state) — this fixture documents the contract this feature's own REQ-001
  states for A5's Resolver to enforce, not a fixture this feature's own
  test suite executes against A5's code (REQ-001, out of this feature's
  own build scope, Non-goals). Every fixture pair this feature's own test
  suite executes (fixtures a-k) is authored `bash`+`ps1`, matching this
  repository's own established cross-runtime test convention
  (investigation.md, and every sibling epic's own REQ-00N precedent).

## Non-goals

- This feature does not author or edit `contracts/capability-registry.
  schema.json`, `contracts/capability-registry.json`,
  `contracts/capability-summary.schema.json`, `contracts/facet-manifest.
  schema.json`, or any other file under `contracts/**` — those either
  belong to Epic A2/A4 (already `Passed`, content-frozen) or do not yet
  exist anywhere (investigation.md INV-013). REQ-001 is a design for a
  future revision Epic A2's own Phase 2 (or a follow-up A2-owned
  revision task) applies, matching A5's own identical framing of the same
  gap (Dependencies, above).
- This feature does not author or edit any file under `plugins/**`,
  `scripts/**`, `tests/**`, `.github/**`, or `docs/**` in this Phase 1
  commit (this task's own explicit boundary) — every script/skill edit
  REQ-002/REQ-004/REQ-005 names is a **design**, applied by a future
  implementation task, exactly as A2/A4/A5's own Phase 1 packages already
  do for their own new scripts.
- This feature does not reimplement, extend, or duplicate A5's own
  `workflow-combination-invalid` Block (the two explicitly-invalid rows of
  decision v2 §6's own combination matrix — `lite × legacy-seven-layer /
  facet-*` and `full × lite-three-file`) — A5's own REQ-002 already
  implements this exact check (investigation.md, A5 `requirements.md:340-
  355`); this feature's own REQ-005 Block is a **different** condition
  (a Lite-ineligible Capability under an otherwise-valid `lite ×
  lite-three-file` combination), never a restatement of A5's own combination-
  validity check.
- This feature does not reimplement A2's Predicate DSL evaluator
  (`evaluate-predicate`), A3's `resolve-component-paths`, or A5's Resolver
  pipeline (Context Projection generation, `affected_components`
  derivation, the `trigger`/`conditional_facets[].when` evaluation loop,
  or the union-match aggregation rule for `lite_eligibility`/`required_
  lite_checks`) anywhere this feature touches — every REQ above either
  reads an artifact one of those mechanisms already produces (REQ-003) or
  merges an already-computed signal into an existing gate's own output
  (REQ-002/REQ-005), never re-deriving the signal itself (REQ-005's own
  OQ-002-resolved pre-generation evaluation, above, calls A2's
  `evaluate-predicate` CLI directly, once per Registry Capability ×
  Project-Context-declared component — an invocation, not a reimplementation
  of its own operator/evidence logic). This feature's own REQ-001 Field
  Definitions statement of the per-matched-Capability `required_lite_
  checks`-key-presence contract under `required` enforcement (Blocker
  [B5]) is a **specification of the exact trigger condition** A5's own
  already-existing `lite-check-source-undefined` diagnostic (A5
  `requirements.md` REQ-002 table) must enforce once this field exists —
  it is not a second, A6-owned Block mechanism, and this feature's own
  build scope still does not implement it inside A5's Resolver.
- This feature's `lite-check-catalog.json` seed is fixed at exactly the
  three check-ids ADR-0022 item 3's own worked example and A4's own AC-013
  canonical fixture both name (`build`, `test`, `installer-dry-run`,
  investigation.md INV-017) — not a larger, invented vocabulary beyond
  what those two sources already establish; a larger seed is still left to
  real Capability authorship, matching A2's own identical restraint for
  the (now-being-expanded) `lite-upgrade-reason-catalog.json`'s own
  original five-token seed (investigation.md INV-007).
- This feature does not touch `generate-gate-capabilities.{py,sh,ps1}` (the
  A2-owned Registry projection generator), and does not claim it ever
  carries `lite_policy`/`required_lite_checks` in its own generated output
  (investigation.md INV-018, correcting an earlier revision's "passive
  flow through the projection" characterization, REQ-001 item 5) — the
  only ripple this feature records is the projection's own `_generated.
  sha256` metadata value changing once the Registry file's bytes change,
  an existing `--check`-cycle re-run, not new generation logic.
- This feature does not, on its own authority, unilaterally expand
  ADR-0022's own protected-file inventory (OQ-001, now **closed** —
  investigation.md — this feature's own design proceeds on the currently
  live, unprotected status) or invent a Capability-matching evaluation
  mechanism beyond what OQ-002's resolution (investigation.md, Blocker
  [B1]) already fixes (candidate (a), A2's own `evaluate-predicate`,
  applied against Project-Context-declared components) — both are closed
  decisions this package now states normatively (Open Questions, below,
  restates each as CLOSED/RESOLVED, not as a question still awaiting
  spec-review/human ruling).
- This feature does not build `sdd-delivery`, an Artifact Gate, or a
  Promotion Gate (ADR-0017's own Foundation-exempted, reserved stages) —
  out of scope for the entire Foundation epic set, not only this feature.

## User Stories

- As a Capability author, I want to declare, per Capability, which
  Lite-specific checks a matching Lite Feature must run, so that
  `lite-gate` enforces exactly what my Capability needs without me having
  to hand-edit every Feature's own quality report.
- As a `lite-spec` invoker, I want a Feature that touches a Lite-
  ineligible Capability to be redirected to the full SDD workflow before
  any lite artifact is created, the same way an existing keyword match
  (e.g. `secret`) already redirects me today, so I never build a lite
  three-file spec for work the Registry itself says needs full rigor.
- As a `lite-gate` invoker, I want the gate to keep running in the same
  bounded, self-verifying, no-evidence-bundle way it does today for a
  Feature with no matched Registry Capabilities, so adopting Capability-
  awareness never makes an ordinary internal-tool Lite Feature slower or
  heavier.
- As a Registry maintainer editing an existing v1 Capability entry, I want
  my entry to remain valid with no edit required, so the schema extension
  never forces a mass migration across every already-authored Capability.
- As a human reviewer, I want every new Registry field's own catalog-
  token vocabulary validated fail-closed against a versioned catalog, so a
  typo'd or unrecognized token in `required_lite_checks`/`upgrade_reasons`
  is caught at Registry-validation time, not silently ignored at
  `lite-gate` run time.

## Acceptance Criteria

| ID | REQ | Criterion |
|---|---|---|
| AC-001 | REQ-001 | The designed `lite_policy` schema fragment has exactly three keys — `eligible` (boolean, required), `upgrade_reasons` (array of non-empty strings, optional, default `[]`), `required_lite_checks` (array of unique strings each matching the check-id grammar `^[a-z0-9][a-z0-9-]*$`, optional, default `[]`, NEW-01) — `additionalProperties: false`; a fixture `lite_policy` object with a fourth key is documented as schema-invalid. |
| AC-002 | REQ-001 | A fixture `capabilities[]` entry whose `lite_policy` carries only `{eligible, upgrade_reasons}` (the current, pre-extension, two-key shape) is documented as still schema-valid under the v1.1 design, with `required_lite_checks` treated as `[]` by every consumer (REQ-003's own absent/default handling). |
| AC-003 | REQ-001 | `contracts/lite-check-catalog.json`'s designed shape is `{schema: const "lite-check-catalog/v1", catalog_version: integer, checks: array of unique strings each matching the check-id grammar ^[a-z0-9][a-z0-9-]*$ (NEW-01)}`, seeded with exactly `["build", "test", "installer-dry-run"]` (revised, Blocker [M1] — matching ADR-0022 item 3's own worked example and A4's own AC-013 canonical fixture); a `required_lite_checks` token absent from this array is documented as validator-rejected (fail-closed), never a schema-level enum. |
| AC-004 | REQ-001 | `contracts/lite-upgrade-reason-catalog.json`'s designed `catalog_version`-2 `reasons` array is the original five tokens (`public_distribution`, `production_cloud_runtime`, `durable_workflow`, `external_identity`, `pii`) plus exactly seven new ones (`public_package_registry`, `store_distribution`, `auto_update`, `code_signing`, `payments`, `multi_tenant`, `high_risk_migration`) — twelve total, no token removed or renamed. |
| AC-005 | REQ-001 | The designed validator check-suite addition is named "(j) lite-check-catalog conformance," documented with the same fail-closed, validator-level (not schema-level) posture as check (h), and is independently testable from check (h) (a fixture with an unknown `required_lite_checks` token but a fully valid `upgrade_reasons` array fails only check (j)). |
| AC-006 | REQ-001 | The design records that no `contracts/*.schema.json` in this repository uses a decimal `schema` const string anywhere (investigation.md, repository-wide grep evidence cited) and that this feature does not propose one — `"schema": "capability-registry/v1"` is unchanged by this extension. |
| AC-007 | REQ-002 | `check-risk-upgrade.{sh,ps1}`'s designed extension accepts a second, optional argument; with it omitted, the documented behavior (six-row keyword table, exit codes `0`/`2`/`10`, output text) is byte-identical to today's live scripts (investigation.md INV-009's citation is the baseline this AC is checked against). |
| AC-008 | REQ-002 | With the second argument present and naming at least one Capability-derived trigger token, the documented output's `triggers=` list places every keyword-derived token (in the existing fixed table order) before every Capability-derived token (in caller-supplied order), and the exit code is `10`. |
| AC-009 | REQ-002 | The design states explicitly that the six-row keyword table itself gains no new row and no reordering, and that no Predicate-DSL/Registry-matching logic is duplicated inside `check-risk-upgrade.{sh,ps1}` — the second argument is documented as a path to an already-computed fragment, never a Registry or Project-Context path this script itself parses beyond that fragment's own two documented keys. |
| AC-010 | REQ-002 | The design names all three protected-file targets this REQ edits (`risk-upgrade-policy.md`, `check-risk-upgrade.sh`, `check-risk-upgrade.ps1`) and states the human-copy flow (`specs/epic-194-a6-lite-integration/human-copy/` + a feature-scoped anchored runner, ADR-0011) as their only legitimate implementation-phase application path, citing investigation.md INV-008's confirmation that all three are currently protected and INV-019's confirmation that the Epic-136 runner cannot itself read this feature's own staged directory (Major [M3], AC-031). |
| AC-011 | REQ-003 | The design states the absent-`capability-summary.yaml` case resolves identically to today's behavior **only** when no Project Context exists (`disabled-legacy`) — `lite-gate` treats the Feature as contributing zero Registry-sourced checks, running only its existing five baseline checks, no error, no Block; a zero-matched-Capability resolve under an *active* Project Context instead produces a schema-valid, empty-array Summary (present, not absent) per AC-030, below (narrowed, Blocker [B6]). |
| AC-012 | REQ-003 | The design states this feature calls a schema validator for `capability-summary.yaml` (A4/A5-owned, not reimplemented here) before trusting `required_lite_checks`/`full_upgrade_required`, and cites `contracts/capability-summary.schema.json`'s exact frozen shape (investigation.md INV-005) as the contract being validated against. |
| AC-013 | REQ-003 | The design states this feature does not re-aggregate `required_lite_checks` across Capabilities itself — it reads the single, already-aggregated array A5's Resolver writes, citing investigation.md INV-006's union-match reasoning as the aggregation rule this feature relies on without re-deriving. |
| AC-014 | REQ-004 | The design places the new Registry-sourced-check step between `lite-gate/SKILL.md`'s existing Step 2 and Step 3, preserving the existing Step 1/Step 2/Step 5 numbering's own relative order and the existing "順序が重要" ordering note (investigation.md INV-010's citation of the live file is the baseline). |
| AC-015 | REQ-004 | The design states a Registry-sourced check-id that duplicates one of the five baseline names is a no-op (not re-executed a second time, not double-recorded in the quality report). |
| AC-016 | REQ-004 | The design states an unmapped Registry-sourced check-id (one the command-discovery contract cannot resolve, now including a check-id that fails the identifier grammar, resolves outside `scripts/`, is a symlink/reparse point, or stages only one `.sh`/`.ps1` runtime member, NEW-01) is `VERDICT: FAIL` with a stated reason — never `N/A` and never a silently-dropped entry; `N/A` remains reserved for Step 2's own pre-existing, non-Registry-sourced missing-local-command convention only (reversed, Blocker [B7]; safety-hardened, NEW-01). |
| AC-017 | REQ-004 | The design states this REQ's own file target, `lite-gate/SKILL.md`, is edited **directly** (not via human-copy), citing investigation.md INV-008's live `guard-invariants.json` evidence that it is not currently a protected file, and records OQ-001's now-**closed** ruling (investigation.md, Minor finding) as the reason this is a definitive design choice, re-verified against the then-current `guard-invariants.json` at implementation-start time (Roles and Permissions, above), not an open question this choice still awaits. |
| AC-018 | REQ-004 | The design states no evidence-bundle, cross-model-verification, second-approval, or other `quality-gate`-only mechanism is added to `lite-gate` by this REQ — only bounded execution of a Registry-named, already-capped check list, preserving ADR-0022 item 4's "never grows into a second `quality-gate`" boundary. |
| AC-019 | REQ-005 | The design fixes the Block's position (identical to the existing Risk-Upgrade Gate's own position, before any `specs/<feature>/` file is created), exit code (`10`), message shape (`full-required: ...`), and non-overridability (`--lite` never overrides), all citing `lite-spec/SKILL.md`'s live Risk-Upgrade Gate section (investigation.md INV-010) as the pattern being matched. |
| AC-020 | REQ-005 | The design selects candidate (a) (Project-Context-wide, diff-independent evaluation via A2's `evaluate-predicate` against every Project-Context-declared component) as the pre-generation Block's Capability-derived signal source, and states this Block is layered with — never a replacement for — the existing `ship`-time recheck (REQ-002's own second invocation point), both stages normative — closing OQ-002 as resolved (investigation.md, Blocker [B1]), not as an open question awaiting further ruling. |
| AC-021 | REQ-005 | The design names `lite-spec/SKILL.md` as the sole file this REQ edits, confirms it is currently protected (investigation.md INV-008), and states the same human-copy flow REQ-002 uses applies here too — no separate, REQ-005-specific application mechanism is invented. |
| AC-022 | REQ-006 | The design's fixture inventory (a)-(l) maps 1:1 to at least one REQ-001..REQ-005 Acceptance Criterion each — no fixture is listed with no corresponding AC it exercises, and no REQ-001..REQ-005 AC that names a testable behavior (AC-002, AC-007, AC-008, AC-011, AC-015, AC-016, AC-026, AC-027, AC-028, AC-030) is left with no corresponding fixture. |
| AC-023 | Global | This package's own registration commit does not create `tasks.md`, `traceability.md`, or any file outside `specs/epic-194-a6-lite-integration/**` and the two registration edits (`AGENTS.md`, `specs/workflow-state-registry.json`) — confirmed by `git status`/`git diff --stat` at commit time. |
| AC-024 | Global | `Spec-Review-Status` (this file) and `Impl-Review-Status` (`design.md`) both read `Pending` at commit time — this package does not write `Approved`/`Passed` anywhere (this task's own explicit instruction). |
| AC-025 | Global | After this package's registration commit, `bash scripts/check-sdd-structure.sh .` and `bash plugins/sdd-quality-loop/scripts/check-workflow-state.sh` both exit `0` (investigation.md INV-011's baseline run, re-run post-registration). |
| AC-026 | REQ-003/REQ-004 | The design states `lite-gate`'s own Step 2a Blocks (`VERDICT: FAIL`, `Status` unchanged) whenever a schema-valid Capability Summary's own `full_upgrade_required` field reads `true`, treats `false` as a pass-through to Step 2b, and relies on REQ-003's own existing schema-validation Edge Case for an invalid/missing value — resolving OQ-003 (Blocker [B2]). |
| AC-027 | REQ-002 | The design states a **supplied** `--capability-reasons`/`-CapabilityReasons` path whose file is unreadable, not valid UTF-8 JSON, or shape-invalid (Field Definitions) causes `check-risk-upgrade` to exit `2` with no trigger reporting — never a silent degrade to "no Capability-derived trigger"; the byte-identical guarantee (AC-007) is stated as applying **only** to the second-argument-omitted case (Blocker [B3]). |
| AC-028 | REQ-002 | The design states a Capability-derived fragment entry with `eligible: false` and an empty/absent `upgrade_reasons` array still contributes exactly one synthetic trigger token (`ineligible:<id>`) to the merged `triggers=` output and exit code `10` — never silently contributing nothing (Blocker [B4]). |
| AC-029 | REQ-001 | The design's Field Definitions state that a matched Capability under `workflow.capability_enforcement: required` whose own `lite_policy` carries no `required_lite_checks` key at all is not usable on the Lite track, and name A5's own existing `lite-check-source-undefined` diagnostic (A5 `requirements.md` REQ-002 table) as the mechanism whose trigger condition this field's existence extends to cover this exact per-matched-Capability case — distinguishing this state from an `advisory`-tolerated absence and from a zero-matched-Capability resolve (Blocker [B5]). This AC records this feature's own half of a cross-epic contract: it is a specification A6 states for A5's Resolver to enforce (Non-goals, above), and becomes fully normative once A5's own addendum narrowing the `lite-check-source-undefined` trigger condition and its REQ-003/AC-016 byte-identity guarantee to this exact case (orchestrator ruling 2026-07-22, B5) is itself normalized in A5's own package — a dependency this AC states in the A6→A5 direction, not the reverse, and this package's own Spec-Review-Status is not itself blocked on that addendum landing first. |
| AC-030 | REQ-003 | The design states an absent `capability-summary.yaml` under an active (`advisory`/`required`) `workflow.capability_enforcement` is `VERDICT: FAIL`, distinct from the same absence under `disabled-legacy` (AC-011) — and that a zero-matched-Capability resolve under active enforcement instead produces a *present*, schema-valid, empty-array Summary, never an absence (Blocker [B6]). |
| AC-031 | REQ-002/REQ-005 | The design's Protected-File Statement names the contract a future feature-scoped anchored runner must satisfy to apply this feature's own `specs/epic-194-a6-lite-integration/human-copy/` batch — a three-way exact-set match (declared four-target list = `MANIFEST.sha256` target set = enumerated payload file set, payload defined as staged paths excluding this batch's own control files — `MANIFEST.sha256`, the runner, and any machine-readable inventory, investigation.md INV-020), per-target sha256 verification against `MANIFEST.sha256`, and post-copy re-verification of every installed file's own hash — since `specs/epic-136-phase2-gates/human-copy/apply-protected-files.ps1` is hard-anchored to its own fixed prefix and cannot read this feature's own staged directory (investigation.md INV-019, Major [M3]). |

## Field Definitions

- `lite_policy.required_lite_checks` (REQ-001; ADR-0022 item 4; decision v2
  §6) — per-Capability array of Lite-specific check-id strings this
  Capability contributes when matched on the Lite track; `uniqueItems:
  true`; optional, default `[]`; each token validated at the new
  validator check (j) against `contracts/lite-check-catalog.json`, not by
  a schema-level enum (mirroring `upgrade_reasons`'s own REQ-003(h)
  posture exactly, investigation.md INV-003). Named identically to the
  Capability-Summary aggregate field A4 already fixed
  (`required_lite_checks`, investigation.md INV-005) because the
  aggregation is a plain union (investigation.md INV-006), the same
  non-renaming relationship `required_facets` already has between its own
  per-Capability and Feature-level forms — unlike `lite_policy`→`lite_
  eligibility` or `minimum_enforcement`→`capability_minimum_enforcement`,
  which rename because they carry a derived, non-union aggregation
  (AND/`max()` respectively). Under `workflow.capability_enforcement:
  required` specifically, a matched Capability's own `lite_policy.
  required_lite_checks` **key** (not merely a non-empty value) must be
  present for that Capability to be usable on the Lite track (Edge Cases,
  below; Blocker [B5], investigation.md INV-015) — the key's mere
  presence, empty array included, is what "opted in" means; total absence
  of the key is what the combination matrix's own "Lite専用Gateを持つ
  Capabilityだけ利用可能" required-enforcement row excludes. This is a
  specification of the exact trigger condition A5's own already-existing
  `lite-check-source-undefined` diagnostic (A5 `requirements.md` REQ-002
  table) must enforce once this field exists — not a second, A6-owned
  Block mechanism (Non-goals, above).
- `contracts/lite-check-catalog.json` (REQ-001; new, A6-owned) — the
  versioned catalog `required_lite_checks` tokens validate against:
  `{schema: const "lite-check-catalog/v1", catalog_version: integer,
  checks: array of unique strings, each matching the check-id identifier
  grammar below}`. Seeded with `["build", "test", "installer-dry-run"]`
  (revised, Blocker [M1], investigation.md INV-017 — no larger seed
  beyond these three canonical, ADR-0022/A4-named tokens is正本-mandated).
  Additive/versioned exactly like `lite-upgrade-reason-catalog.json` — a
  later `catalog_version` may add check-ids without a `capability-
  registry.schema.json` change.
- **Check-id identifier grammar (NEW, 2026-07-22 adversarial final
  verification, NEW-01, investigation.md INV-021)** — every
  `required_lite_checks`/`lite-check-catalog.json` `checks[]` token (a
  "check-id") matches `^[a-z0-9][a-z0-9-]*$`: this repository's own
  lowercase-hyphenated identifier convention (the same shape every
  existing check-id this design already names — `build`, `test`,
  `installer-dry-run` — already has). This grammar is not cosmetic:
  `lite-gate`'s own command-discovery contract (REQ-004 Step 2b; design.md
  API / Contract Plan) interpolates a check-id into a
  `scripts/<id>.{sh,ps1}` filesystem path, and an unconstrained string
  (e.g. one containing `../`, a path separator, or an option-like prefix
  such as `--`) could otherwise defeat the "bounded to `scripts/`" claim
  this design already makes for that lookup. The grammar is enforced
  fail-closed at three independent points, none of which trusts the
  others: (1) `contracts/lite-check-catalog.json`'s own `checks[]` item
  schema (Data Plan, design.md); (2) the Registry's `lite_policy.
  required_lite_checks[]` item schema (Data Plan, design.md — the same
  pattern, at Capability-declaration time); (3) `lite-gate` itself,
  re-validating every id read from `capability-summary.yaml` immediately
  before Step 2b's own discovery loop, independent of whether either
  upstream schema actually ran (REQ-004, Step 2b). A grammar-failing id is
  `VERDICT: FAIL` at whichever of these three points first sees it, never
  silently truncated, escaped, or passed through as a literal path
  segment.
- `lite-upgrade-reason-catalog.json` vocabulary growth (REQ-001;
  investigation.md INV-007) — the `catalog_version`-2 mapping from
  ADR-0022's forced-upgrade prose to snake_case tokens:

  | ADR-0022 prose phrase | Token | Status |
  |---|---|---|
  | cloud production | `production_cloud_runtime` | already seeded (`catalog_version` 1) |
  | a Durable Workflow | `durable_workflow` | already seeded |
  | (general) | `public_distribution` | already seeded |
  | external authentication | `external_identity` | already seeded |
  | PII | `pii` | already seeded |
  | a public package registry | `public_package_registry` | new (`catalog_version` 2) |
  | Store distribution | `store_distribution` | new |
  | auto-update | `auto_update` | new |
  | Stable distribution involving code signing | `code_signing` | new |
  | payments | `payments` | new |
  | multiple tenants | `multi_tenant` | new |
  | a high-risk migration | `high_risk_migration` | new |

  No already-seeded token is removed, renamed, or redefined — an existing
  Registry instance's `upgrade_reasons` array remains valid and
  semantically unchanged (REQ-001 item 3's migration rule, restated for
  this catalog specifically).
- Capability-derived trigger fragment (REQ-002; new, A6-owned, in-process/
  CLI JSON structure — not a `contracts/` schema file, the same "not a
  repository contract, an in-process/CLI JSON structure" classification
  A3's own Resolver-output shape already uses, investigation.md, A5
  INV-018 citing A3's precedent) — `{"capabilities": [{"id":
  <capability-id, non-empty string>, "eligible": <boolean>,
  "upgrade_reasons": [<token>, ...] (optional, default [])}, ...]}`
  (revised, 2026-07-22 adversarial review, Blocker [B4] — an earlier
  revision flattened this to a bare `{"upgrade_reasons": [...]}` array
  with no per-Capability `id`/`eligible` field, which could not represent
  an `eligible: false` Capability that names no specific `upgrade_reasons`
  token, requirements.md Edge Cases). Each `<token>` is a `lite_policy.
  upgrade_reasons` value already validated against `lite-upgrade-reason-
  catalog.json` by whichever upstream mechanism computed it (REQ-005, OQ-002
  resolved); `check-risk-upgrade.{sh,ps1}`'s own new optional second
  argument is a path to a file containing exactly this JSON shape —
  REQ-002's own two-input-state distinction (omitted vs. supplied-and-
  invalid, Blocker [B3]) governs how a malformed instance of this shape is
  handled.
- `full_upgrade_required` (REQ-003/REQ-004; A4-owned field, this feature
  only reads it, never writes it) — see investigation.md INV-005 for its
  frozen definition; this feature's own use of it is now a Blocking
  backstop check (`lite-gate` Step 2a, REQ-004), resolving OQ-003
  (investigation.md, Blocker [B2]) — `true` is `VERDICT: FAIL`, `false`
  continues normally, and an invalid/missing value is already covered by
  REQ-003's own schema-validation Edge Case.
- Schema-file "v1.1" (REQ-001 item 4) — a human/changelog-facing label for
  this feature's own additive revision of `contracts/capability-registry.
  schema.json`'s design; not a wire-level field or a change to the
  Registry instance's own `"schema": "capability-registry/v1"` const
  string (Field Definitions text above; AC-006).

## Roles and Permissions

- **Agent (this spec's author)**: authors all four Phase-1 spec-package
  files (`investigation.md`, `requirements.md`, `design.md`, `acceptance-
  tests.md`) under `specs/epic-194-a6-lite-integration/` directly
  (unprotected), plus the two registration edits (`AGENTS.md`'s Active
  Spec Directories list, `specs/workflow-state-registry.json`'s `entries`
  array) in a separate, isolated commit. Does not touch `plugins/`,
  `scripts/`, `contracts/`, `tests/`, `.github/`, or `docs/` in either
  commit (Non-goals, AC-023). Does not write `Approved`/`Passed` in any
  Status/approval field (this task's own instruction — both review-status
  headers stay `Pending`, for a human/spec-review-loop to change).
- **Human maintainer / spec-review-loop**: reviews and approves this
  package (changes `Spec-Review-Status`/`Impl-Review-Status` to `Passed`
  only after independent review). OQ-001, OQ-002, and OQ-003 (Open
  Questions, below) are already closed/resolved by orchestrator ruling
  2026-07-22 (investigation.md's own Open Questions section states the
  full ruling for each), the same "orchestrator ruling" pattern A2's own
  OQ-002/OQ-003 were closed by (investigation.md INV-002's citation of
  A2's precedent) — this package's own remaining review step is
  Spec-Review-Status/Impl-Review-Status approval, not further OQ
  disposition.
- **Epic A2's own Phase 2 implementer (or a follow-up A2-owned revision
  task)**: the sole intended author of the live `contracts/capability-
  registry.schema.json`/`.json` v1.1 edit and the live `contracts/lite-
  check-catalog.json`/`lite-upgrade-reason-catalog.json` catalog-version
  bumps this feature's REQ-001 designs — this feature defines the target
  shape, it does not apply it (Dependencies, above; Non-goals).
  Registers the two new/changed catalog files and the schema edit as
  protected (`guard-invariants.json`), the same registration A2's own
  REQ-005 already plans for its own new artifacts.
- **A future implementation task (Epic A6 Phase 2)**: the sole intended
  author of the live `check-risk-upgrade.{sh,ps1}`/`risk-upgrade-policy.
  md`/`lite-spec/SKILL.md` human-copy edits (REQ-002/REQ-005) and the live
  `lite-gate/SKILL.md` direct edit (REQ-004), and of the
  `tests/*.tests.sh`/`.tests.ps1` pairs REQ-006 describes. Re-verifies
  `lite-gate/SKILL.md`'s then-current protection status before choosing a
  direct edit or a human-copy one (the same "live-repository snapshot,
  re-verified at implementation-start time" disclaimer A3's own package
  already applies, investigation.md OQ-001 citing that precedent by
  pattern).
- **CI (future, implementation phase)**: runs the extended `validate-
  capability-registry` (new check (j)), the projection generator's
  `--check` mode (REQ-001 item 5), and the new `tests/*.tests.sh`/`.tests.
  ps1` pairs once a human has applied every human-copy-staged file.

## Main Workflows

1. A Registry maintainer (Epic A2's own future tooling) edits a
   `capabilities[]` entry to add `lite_policy.required_lite_checks`
   and/or a broader `upgrade_reasons` set, drawing tokens from
   `lite-check-catalog.json`/`lite-upgrade-reason-catalog.json`
   respectively; `validate-capability-registry`'s extended check-suite
   (REQ-001 item 5, checks (h) and the new (j)) rejects any unrecognized
   token, fail-closed.
2. A human or agent starts the `sdd-lite` flow (`lite-spec`) for a new
   Feature. Before creating any `specs/<feature>/` file, the extended
   Risk-Upgrade Gate (REQ-005) runs: the existing keyword scan
   (`check-risk-upgrade`, REQ-002's own byte-identical no-second-argument
   path) **and** a Capability-derived check (OQ-002 resolved: Registry
   `trigger`s evaluated against every Project-Context-declared component,
   via A2's `evaluate-predicate`, merged into `check-risk-upgrade`'s own
   second argument). Either source's Block redirects the user to
   `/sdd-bootstrap:sdd-bootstrap-interviewer`, unconditionally (`--lite`
   never overrides).
3. If neither source Blocks, `lite-spec` proceeds exactly as it does
   today (three-file generation; this feature does not touch that part of
   the Process).
4. At implementation time, Epic A5's Resolver (out of this feature's own
   build scope) resolves the Feature's matched Capabilities and writes
   `specs/<feature>/capability-summary.yaml` (A4-schema'd), aggregating
   every matched Capability's own `required_lite_checks` via union-match
   (investigation.md INV-006) and setting `full_upgrade_required`
   accordingly — under `required` enforcement specifically, a matched
   Capability whose own `required_lite_checks` key is entirely absent
   Blocks this step instead (A5's own extended `lite-check-source-
   undefined` diagnostic, Field Definitions/Edge Cases, above, Blocker
   [B5]).
5. After `implement-task`, `lite-gate` runs (REQ-003/REQ-004): it locates
   and validates `capability-summary.yaml` (absent is a valid,
   zero-extra-checks state only under `disabled-legacy`, REQ-003, Blocker
   [B6]), Blocks on `full_upgrade_required: true` (Step 2a, Blocker [B2]),
   runs its own five baseline checks plus every additional `required_lite_
   checks` entry the Summary names — FAILing, not `N/A`-ing, any such
   entry its own command-discovery contract cannot resolve (REQ-004,
   Blocker [B7]) — and writes the combined PASS/FAIL result to the same
   single quality report the existing Process already produces, unchanged
   in every other respect (no evidence-bundle, no cross-model
   verification).
6. At `ship` time, the existing second `check-risk-upgrade` invocation
   (task-block + `requirements.md` recheck, investigation.md INV-010)
   continues to run exactly as documented today; REQ-002's own optional
   second-argument extension is available to it too, on the same terms as
   `lite-spec`'s own call site — this is the OQ-002-resolved mandatory
   second stage (Open Questions, above), not merely an optional extension
   of convenience.

## Edge Cases

- **v1 Registry, field absent entirely, distinguished from present-empty
  and from zero-match (revised, Blocker [B5])**: a Capability entry
  authored before this extension has no `required_lite_checks` key at all
  (not even `lite_policy` itself, if the Capability predates that too) —
  schema-valid under v1.1 with no change (REQ-001 item 3); contributes
  `[]` to any Lite Feature that matches it under `advisory` enforcement
  (REQ-003's own default handling), exactly as today. Under `required`
  enforcement specifically, three states are distinct, not two: (1) the
  key **entirely absent** — this Capability is excluded from the "Lite専用
  Gateを持つCapability" set the combination matrix's `required`-enforcement
  row names, and A5's own extended `lite-check-source-undefined`
  diagnostic Blocks the Resolver's own aggregation step for any Feature
  that matches it (Field Definitions, above, AC-029); (2) the key
  **present but `[]`** — a Capability author's explicit, valid opt-in
  contributing zero checks, usable under `required`; (3) **zero matched
  Capabilities at all** — a third, non-Blocking state producing a
  schema-valid, empty Capability Summary regardless of enforcement state
  (AC-030, below, Blocker [B6]).
- **Capability ineligible with empty `upgrade_reasons`**: `lite_policy:
  {eligible: false}` with `upgrade_reasons` omitted or `[]` is schema-
  valid (that field stays optional) — REQ-005's Block still fires (keyed
  on `eligible: false` alone, not on a non-empty `upgrade_reasons`); the
  Capability-derived trigger fragment (Field Definitions, above, revised)
  represents this exact state with a synthetic `ineligible:<id>` token
  (Blocker [B4], AC-028) rather than an empty, contentless trigger — this
  feature's design records this as a legitimate, fully-diagnosable Block
  rather than a validation failure.
- **`required_lite_checks` present but Capability `eligible: false`**: no
  cross-field validator rule forbids this combination (Non-goals — this
  feature does not invent one); because REQ-005's own Block already
  prevents the Capability from ever being matched on a completed Lite
  resolve, any such `required_lite_checks` entries are simply never
  aggregated into a live Capability Summary in practice — a Capability
  author declaring both is not itself an error.
- **Registry-sourced check-id equals a baseline name**: no-op, not a
  second execution or a second report line (AC-015).
- **Registry-sourced check-id with no discoverable command (revised,
  Blocker [B7]; safety-hardened, NEW-01)**: `VERDICT: FAIL` with a stated
  reason (AC-016) — never `N/A` and never a silently-dropped entry. `N/A`
  remains the correct outcome only for Step 2's own pre-existing,
  non-Registry-sourced convention (a missing local lint/typecheck project
  command/config), which this REQ does not touch or extend to
  Registry-sourced check-ids. This "no discoverable command" category
  itself now includes, without becoming a distinct outcome (Field
  Definitions, above, NEW-01): an id failing the check-id grammar, a
  `scripts/<id>` candidate that is a symlink/reparse point or that
  canonicalizes outside `scripts/`, and a `scripts/<id>.{sh,ps1}` pair
  with only one runtime member staged — each is `VERDICT: FAIL` via this
  same rule, never treated as resolved.
- **`capability-summary.yaml` present but fails schema validation**:
  `lite-gate` treats this the same way it would treat a malformed
  `reports/implementation/<task-id>.md` today — a `VERDICT: FAIL` with the
  validation failure named as the reason, `Status` unchanged, differing
  from the "absent under `disabled-legacy`" case (AC-011) precisely
  because that one case is a defined, valid zero-checks state while
  "present but invalid" is evidence of an upstream (Resolver or hand-edit)
  defect this feature's own Non-goals do not authorize silently ignoring.
- **`capability-summary.yaml` absent under active `capability_
  enforcement` (NEW, Blocker [B6])**: `workflow.capability_enforcement` is
  `advisory` or `required` (an active Project Context exists), and no
  `capability-summary.yaml` exists at all — `VERDICT: FAIL`, `Status`
  unchanged, reason "`capability-summary.yaml` missing under active
  `capability_enforcement`" (AC-030). Distinct from the `disabled-legacy`
  absent case (AC-011), which stays legitimate, and from the
  zero-matched-Capability case, which is *present*, schema-valid, and
  empty, never absent (investigation.md INV-016).
- **`workflow.spec_profile`/`artifact_layout` name one of decision v2 §6's
  two explicitly-invalid combination rows**: out of this feature's own
  scope (Non-goals) — A5's own `workflow-combination-invalid` Block
  already covers this at the Resolver level; this feature's REQ-005 Block
  is orthogonal (a valid `lite × lite-three-file` combination whose
  matched Capability is itself ineligible), never a restatement.
- **Compatibility fallback (no Project Context, decision v2 §6's two
  "(非活性)" matrix rows)**: the capability mechanism does not run at all
  (ADR-0016 item 4's own "outside that computation's domain" framing) —
  this feature's REQ-002/REQ-005 extensions are therefore inert (the
  optional second argument/Capability-derived signal source is never
  populated) whenever the project has no Project Context; `check-risk-
  upgrade`'s existing single-argument keyword scan continues to run
  exactly as it does today, unaffected; this is also the `disabled-legacy`
  condition REQ-003's own absent-Summary rule (AC-011) treats as
  legitimate, since no Project Context means no `capability_enforcement`
  value to read in the first place.

## Security Boundaries

- No new write surface: every REQ above either extends an existing,
  already-audited exit-code contract (REQ-002, REQ-005) or reads an
  already-schema-validated artifact another epic's own Resolver writes
  (REQ-003) — this feature introduces no new agent-writable approval-like
  record, and does not touch `SDD_SUDO`, the Approval Sidecar, or any
  hook-guard mechanism.
- Fail-closed by construction, mirroring A2's own posture: an unrecognized
  catalog token (REQ-001), a schema-invalid Capability Summary (Edge
  Cases), a Capability Summary absent under active `capability_
  enforcement` (Edge Cases, Blocker [B6]), `full_upgrade_required: true`
  (REQ-004 Step 2a, Blocker [B2]), an unmapped `required_lite_checks`
  check-id (REQ-004, Blocker [B7] — including a check-id that fails the
  required identifier grammar or whose `scripts/<id>` candidate resolves
  outside `scripts/` or is a symlink/reparse point, NEW-01, investigation.
  md INV-021), and a **supplied-but-invalid**
  `--capability-reasons` fragment file (REQ-002, exit `2` — Blocker [B3],
  correcting an earlier revision that treated this same case as a silent
  degrade and mislabeled it "fail-closed," investigation.md INV-014) all
  either Block or fail the gate, never silently pass. The only condition
  that legitimately degrades rather than Blocks is the second argument's
  own **total absence** (REQ-002's own byte-identical legacy path, AC-007)
  — a caller that never attempts to supply a Capability-derived signal at
  all, as opposed to one that attempted to and failed.
- The three-file/four-file protected-file boundary (investigation.md
  INV-008) is read, not redefined, by this feature — REQ-002/REQ-005's own
  human-copy staging follows ADR-0011's already-Accepted mechanism
  verbatim; this feature does not propose a new protection mechanism, and
  OQ-001's now-**closed** ruling confirms this feature's own inventory
  stays at the existing four files (investigation.md, Minor finding) —
  REQ-004's `lite-gate/SKILL.md` edit remains outside the protected-file
  boundary by design, not by an unresolved question.
- No Provider-name contamination surface is added — `build`/`test`/
  `installer-dry-run` (the lite-check-catalog seed, revised, investigation.
  md INV-017) and the twelve upgrade-reason tokens (Field Definitions) are
  all provider-neutral, matching A2's own REQ-003(g) boundary (ADR-0018)
  this feature does not touch but also does not violate.

## Assumptions

- A2's, A3's, and A4's already-`Passed` schemas will not change in a way
  that breaks this feature's own citations before this feature reaches its
  own spec review — if any of the three re-opens, this feature's own
  Dependencies section (above) and design.md must be re-checked against
  the new text before proceeding (matching the general re-verification
  discipline every sibling epic's own Phase 1 package already states for
  a "live-repository snapshot" citation).
- A5's current text (`Spec-Review-Status: Pending`) is the best available
  statement of the Lite-track Resolver contract this feature's REQ-003
  consumes; this feature's own field-naming choice (`required_lite_
  checks`, matching A5's own current usage) is treated as provisional
  until A5 itself reaches `Passed` (Dependencies, above; Risks, below).
- `lite-gate/SKILL.md`'s currently-unprotected status (investigation.md
  INV-008) reflects the live, current `guard-invariants.json` at
  investigation time and could change before this feature reaches
  implementation — REQ-004's own "direct edit" scoping is re-verified at
  implementation-start time, not assumed permanently true (Roles and
  Permissions, above).
- No Capability Pack exists yet anywhere in this repository (investigation.
  md INV-013, matching A2's own INV-002) — every fixture this feature's
  REQ-006 names is synthetic, not drawn from a real, shipped Capability.

## Open Questions

All three of this section's own open questions were closed/resolved by
orchestrator ruling on 2026-07-22 (investigation.md's own Open Questions
section states the full ruling for each; REQ-001/REQ-003/REQ-004/REQ-005
above already state the resolved behavior normatively). Retained here, in
closed form, because this section is cited by name elsewhere in this
package ("Open Questions, below").

- **OQ-001** (investigation.md OQ-001). **CLOSED.** `lite-gate/SKILL.md`
  is not added to `guard-invariants.json`'s protected-file inventory by
  this feature's own authority — REQ-004's edit is a **direct** edit,
  definitively, not a question pending human ruling. The live
  `guard-invariants.json` state is still re-verified at a future
  implementation task's own start time (Roles and Permissions, above) —
  that re-verification is a live-repository-snapshot check, not an open
  design question this package itself still carries.
- **OQ-002** (investigation.md OQ-002). **RESOLVED.** Candidate (a) is
  selected: `lite-spec`'s pre-generation Risk-Upgrade Gate evaluates
  Registry `trigger`s directly against every component the Project
  Context already declares (diff-independent, via A2's
  `evaluate-predicate`), and Blocks on any ineligible match, at the exact
  position decision document v2 §19 names. This intake-time Block is
  layered with, not a substitute for, the existing `ship`-time recheck —
  both stages are now normative (REQ-005, above).
- **OQ-003** (investigation.md OQ-003). **RESOLVED.** `lite-gate`'s own
  REQ-004 Step 2a performs an independent `full_upgrade_required`
  re-check: `true` is `VERDICT: FAIL`; a written Capability Summary's mere
  existence is not, on its own, treated as sufficient proof every
  full-upgrade determination already happened upstream.

## Risks

- **A5 is not yet `Passed`** (investigation.md INV-002) — this feature's
  own `required_lite_checks` field name, and its reliance on A5's stated
  union-match aggregation rule (INV-006), are both grounded in A5's
  *current* text; a later A5 revision that renames the field or changes
  the aggregation rule would require a corresponding revision to this
  feature's own REQ-001/REQ-003 before implementation. This risk is
  structurally the same one A5's own Dependencies section already
  accepts in the opposite direction (A5 depends on this feature's own
  not-yet-existing Registry field) — both epics carry a live,
  acknowledged cross-epic dependency on a sibling that has not yet
  reached `Passed`.
- **The intake-time Block (OQ-002, resolved, candidate (a)) is a
  defense-in-depth, early-exit optimization, not the sole enforcement
  point** — a Feature that later touches components the initial,
  whole-project Project-Context evaluation did not consider relevant
  (added or changed after intake) could still surface a Lite-ineligible
  Capability only at `ship` time, via the already-existing, still-
  mandatory second `check-risk-upgrade` invocation (REQ-005, above) —
  this is not a gap this feature's own REQ-005 leaves uncovered (the
  `ship`-time recheck already exists, is unmodified in position, and
  already Blocks unconditionally); it is the accepted cost of resolving
  OQ-002 with a diff-independent candidate rather than deferring
  Capability-awareness entirely to `ship` time (candidate (b), rejected).
- **The eleven-category-to-token mapping (Field Definitions,
  `lite-upgrade-reason-catalog.json` growth) is this feature's own
  interpretation of ADR-0022's prose**, not a table the ADR itself
  provides verbatim — a future spec-review pass may find a different
  tokenization more consistent with the existing five-token seed's own
  naming convention; this is recorded here as a low-cost, anticipated
  follow-up, the same way A5's own Design Decisions section already
  flags its own new (non-upstream-fixed) decisions for possible future
  ADR treatment.
- **`build`/`test`/`installer-dry-run` as the `lite-check-catalog.json`
  seed** (revised, three tokens, investigation.md INV-017) may still prove
  too narrow once a real Capability Pack is authored — this feature's own
  Non-goals deliberately does not pre-populate a larger catalog beyond
  what ADR-0022 item 3's own worked example and A4's own AC-013 canonical
  fixture already name, accepting the risk that a first real Capability
  author will need to propose a `catalog_version`-2 addition of their own
  (the catalog's own additive mechanism, REQ-001, is designed to make
  that a low-cost, non-breaking follow-up, not a schema revision).
