# Requirements: epic-194-a6-lite-integration

Spec-Review-Status: Pending
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
(INV-001..INV-013; OQ-001..OQ-003)

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
     (`"schema": "lite-check-catalog/v1"`), seeded with the one concrete
     check-id decision document v2 §6's own worked example names beyond
     `lite-gate`'s already-existing five baseline checks —
     `installer-dry-run` — and explicitly left open for additive,
     `catalog_version`-bumped growth as real Capabilities are authored
     (this feature does not invent a larger seed vocabulary decision
     document v2/ADR-0022 does not itself name — Non-goals, below).
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
     needs no new generation logic — it already reads the full validated
     Registry and re-derives its projection from it on every regeneration,
     so the new field passively flows through the existing `--check`
     drift-detection mode once the v1.1 schema and this feature's new
     catalog land; this feature adds no new generator, only records that
     the existing one's regeneration/`--check` cycle must re-run once
     (Non-goals, below — this feature does not touch `generate-gate-
     capabilities.{py,sh,ps1}` itself, which is A2-owned).
- **REQ-002** (Capability-aware risk-upgrade wiring — ADR-0022's own
  Consequences section, "Epic A6 must wire these reasons into the existing
  risk-upgrade gate rather than duplicating upgrade logic"): Extend
  `check-risk-upgrade.{sh,ps1}`'s existing single-positional-argument
  contract (investigation.md INV-009) with a second, **optional** input —
  a path to a small, already-computed JSON fragment (produced upstream,
  outside this script, by whichever Capability-matching mechanism REQ-005
  and Open Questions below settle on: `{"upgrade_reasons": [<token>,
  ...]}, "checked"`) — merged into the existing trigger-reporting output
  exactly the way a seventh-through-Nth keyword-table row would be, without
  adding a seventh row to the keyword table itself and without this script
  re-deriving, re-evaluating, or duplicating any Predicate-DSL/Registry-
  matching logic (INV-009's own "(a) vs (b)" framing; this feature adopts
  (a) — extending the one existing script's own I/O contract — because
  ADR-0022's own Consequences text names "the existing risk-upgrade gate"
  by name, not a new composed wrapper). When the optional second argument
  is absent (every existing call site, until REQ-005's callers are
  updated), behavior is byte-identical to today's (Non-goals: no change to
  the six-row keyword table, its ordering, or its exit-code contract for
  the already-documented single-argument invocation). When present and
  non-empty, the script's own `full-required: ...` output line's
  `triggers=` list includes the supplied Capability-derived token(s)
  appended after the existing keyword-derived ones (ordering: keyword
  triggers first, in their existing fixed order; Capability-derived
  triggers appended in the order the caller supplied them), and the exit
  code is `10` whenever either source produces at least one trigger token
  — the merge is a logical OR over the two independent sources, never a
  reason for the keyword scan itself to change. This is a protected-file
  edit (three files: `risk-upgrade-policy.md`, `check-risk-upgrade.sh`,
  `check-risk-upgrade.ps1` — investigation.md INV-008) staged through
  `specs/epic-194-a6-lite-integration/human-copy/` (ADR-0011 pattern,
  ADR-0022 item 5) at implementation time, not applied directly.
- **REQ-003** (Capability Summary consumption contract for `lite-gate` —
  decision v2 §6, "lite-gateは...Registryで定義されたLite専用チェックだけを
  実行する"): Define the read-only contract `lite-gate` uses to source
  which Lite-specific checks a given Task's Feature must additionally run,
  beyond its own existing five: locate `specs/<feature>/capability-
  summary.yaml` (A5's own reserved output path, A4-schema'd,
  investigation.md INV-005); if absent, treat the Feature as carrying zero
  Registry-sourced Lite-specific checks (Edge Cases, below — this is the
  pre-Epic-A5-implementation and the zero-matched-Capability case alike,
  both legitimate, both meaning "nothing beyond the five baseline checks");
  if present, validate it against `contracts/capability-summary.schema.
  json` (A4-owned, content-frozen, this feature does not re-derive or
  duplicate that validation logic — it calls A4/A5's own future
  `validate-capability-summary` script, the same "call the owning epic's
  own validator, do not reimplement it" discipline A5's own package
  already applies to A2's `evaluate-predicate` and A1's canonicalizer);
  read `required_lite_checks` (the array A5's Resolver already aggregates
  via union-match across matched Capabilities, investigation.md INV-006 —
  this feature does not re-aggregate it) and `full_upgrade_required`
  (Open Questions, below, states this feature's own scope boundary around
  that field). This feature defines no new file and no new schema for this
  REQ — it is a consumption contract only, over an artifact A4/A5 already
  fully type and produce.
- **REQ-004** (`lite-gate` extension to execute Registry-sourced Lite-
  specific checks — decision v2 §6, ADR-0022 item 4): Extend `lite-gate/
  SKILL.md`'s existing five-step Process (investigation.md INV-010) with
  one additional step, inserted between the existing Step 2 (project
  lint/typecheck/build/test) and Step 3 (quality-report generation): for
  every check-id in REQ-003's own sourced `required_lite_checks` list that
  is **not** already one of the five baseline check names (`placeholder`,
  `lint`, `typecheck`, `build`, `test` — a Registry-sourced list may
  legitimately repeat a baseline name, decision v2 §6's own worked example
  lists `build`/`test` alongside `installer-dry-run`; a repeated baseline
  name is a no-op, not a second execution, Edge Cases below), run that
  check the same self-executing, self-capturing way `lite-gate` already
  runs its own lint/typecheck/build/test commands (never trusting an
  implementer's self-report — ADR-0022 item 4's own "`lite-gate` never
  grows into a second `quality-gate`" boundary means this feature adds
  *execution* of a bounded, Registry-named check list, never evidence-
  bundle machinery, cross-model verification, or any other `quality-gate`-
  only mechanism), and record each one's PASS/FAIL in the same `reports/
  quality-gate/<task-id>.md` quality report the existing Process already
  writes, using the same "any FAIL → `VERDICT: FAIL`, no `Status` change"
  rule the existing Steps 1-2 already apply. Where a Registry-sourced
  check-id names a check `lite-gate` has no concrete command for (a
  Registry entry can declare `required_lite_checks: [installer-dry-run]`
  with no repository-local convention yet for what command that check-id
  maps to), record it `N/A` with a stated reason, the same convention
  Step 2 already uses for a missing project lint/typecheck/build/test
  command (`SKILL.md:37`) — this feature does not invent a second,
  stricter failure mode for an unmapped check-id (Non-goals). Per
  investigation.md INV-008/OQ-001, this is a **direct** edit to `lite-gate/
  SKILL.md` (currently unprotected), not a human-copy one, on the
  currently-live `guard-invariants.json` evidence — Open Questions
  restates the ambiguity for human ruling.
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
  decision" rule (`lite-spec/SKILL.md:45-48`). What supplies the Lite-
  ineligible-Capability signal at this exact pre-generation position is
  genuinely unresolved by every正本 source this feature can cite
  (investigation.md OQ-002) — this REQ therefore states the **Block
  contract** (position, exit code, message shape, non-overridability)
  as fixed, and leaves the **signal source** to one of the two named
  candidates in Open Questions below, for spec-review or human ruling
  before this feature's own design.md commits to one. Either candidate
  reuses REQ-002's own merged-trigger output contract — this REQ does not
  define a second, independent Block mechanism. This is a protected-file
  edit to `lite-spec/SKILL.md` (investigation.md INV-008), staged through
  the same `specs/epic-194-a6-lite-integration/human-copy/` flow as
  REQ-002.
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
  each in the quality report (REQ-003/REQ-004); (e) an **unmapped check-id**
  fixture — a Registry-sourced check-id `lite-gate` has no command mapping
  for is recorded `N/A` with a reason, never a silent skip or a false
  PASS/FAIL (REQ-004); (f) an **unknown-catalog-token** fixture — a
  `required_lite_checks` or `upgrade_reasons` token absent from its own
  catalog fails Registry validation, fail-closed (REQ-001 item 5); (g) a
  **missing-Capability-Summary** fixture — `lite-gate` given no
  `capability-summary.yaml` at all runs its existing five baseline checks
  only, unchanged from today's behavior (REQ-003's own absent-artifact
  rule). Every fixture pair is authored `bash`+`ps1`, matching this
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
  (REQ-002/REQ-005), never re-deriving the signal itself.
- This feature does not invent a `catalog_version` seed vocabulary for
  `lite-check-catalog.json` beyond the single concretely-named check-id
  decision document v2 §6 itself provides (`installer-dry-run`) — a larger
  seed list is left to real Capability authorship, matching A2's own
  identical restraint for the (now-being-expanded) `lite-upgrade-reason-
  catalog.json`'s own original five-token seed (investigation.md INV-007).
- This feature does not touch `generate-gate-capabilities.{py,sh,ps1}` (the
  A2-owned Registry projection generator) — REQ-001 item 5 records only
  that its existing `--check` drift-detection cycle must re-run once the
  new field lands, not that this feature adds new generation logic to it.
- This feature does not decide OQ-001 (whether `lite-gate/SKILL.md` should
  be newly registered as a protected file) or OQ-002 (what supplies the
  Capability-aware signal at `lite-spec`'s pre-generation gate) on its own
  authority — both are recorded as Open Questions for spec-review/human
  ruling, per this task's own instruction not to add independent design
  judgment where the正本 is silent.
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
| AC-001 | REQ-001 | The designed `lite_policy` schema fragment has exactly three keys — `eligible` (boolean, required), `upgrade_reasons` (array of non-empty strings, optional, default `[]`), `required_lite_checks` (array of unique non-empty strings, optional, default `[]`) — `additionalProperties: false`; a fixture `lite_policy` object with a fourth key is documented as schema-invalid. |
| AC-002 | REQ-001 | A fixture `capabilities[]` entry whose `lite_policy` carries only `{eligible, upgrade_reasons}` (the current, pre-extension, two-key shape) is documented as still schema-valid under the v1.1 design, with `required_lite_checks` treated as `[]` by every consumer (REQ-003's own absent/default handling). |
| AC-003 | REQ-001 | `contracts/lite-check-catalog.json`'s designed shape is `{schema: const "lite-check-catalog/v1", catalog_version: integer, checks: array of unique non-empty strings}`, seeded with exactly `["installer-dry-run"]`; a `required_lite_checks` token absent from this array is documented as validator-rejected (fail-closed), never a schema-level enum. |
| AC-004 | REQ-001 | `contracts/lite-upgrade-reason-catalog.json`'s designed `catalog_version`-2 `reasons` array is the original five tokens (`public_distribution`, `production_cloud_runtime`, `durable_workflow`, `external_identity`, `pii`) plus exactly seven new ones (`public_package_registry`, `store_distribution`, `auto_update`, `code_signing`, `payments`, `multi_tenant`, `high_risk_migration`) — twelve total, no token removed or renamed. |
| AC-005 | REQ-001 | The designed validator check-suite addition is named "(j) lite-check-catalog conformance," documented with the same fail-closed, validator-level (not schema-level) posture as check (h), and is independently testable from check (h) (a fixture with an unknown `required_lite_checks` token but a fully valid `upgrade_reasons` array fails only check (j)). |
| AC-006 | REQ-001 | The design records that no `contracts/*.schema.json` in this repository uses a decimal `schema` const string anywhere (investigation.md, repository-wide grep evidence cited) and that this feature does not propose one — `"schema": "capability-registry/v1"` is unchanged by this extension. |
| AC-007 | REQ-002 | `check-risk-upgrade.{sh,ps1}`'s designed extension accepts a second, optional argument; with it omitted, the documented behavior (six-row keyword table, exit codes `0`/`2`/`10`, output text) is byte-identical to today's live scripts (investigation.md INV-009's citation is the baseline this AC is checked against). |
| AC-008 | REQ-002 | With the second argument present and naming at least one Capability-derived trigger token, the documented output's `triggers=` list places every keyword-derived token (in the existing fixed table order) before every Capability-derived token (in caller-supplied order), and the exit code is `10`. |
| AC-009 | REQ-002 | The design states explicitly that the six-row keyword table itself gains no new row and no reordering, and that no Predicate-DSL/Registry-matching logic is duplicated inside `check-risk-upgrade.{sh,ps1}` — the second argument is documented as a path to an already-computed fragment, never a Registry or Project-Context path this script itself parses beyond that fragment's own two documented keys. |
| AC-010 | REQ-002 | The design names all three protected-file targets this REQ edits (`risk-upgrade-policy.md`, `check-risk-upgrade.sh`, `check-risk-upgrade.ps1`) and states the human-copy flow (`specs/epic-194-a6-lite-integration/human-copy/` + `apply-protected-files`, ADR-0011) as their only legitimate implementation-phase application path, citing investigation.md INV-008's confirmation that all three are currently protected. |
| AC-011 | REQ-003 | The design states the absent-`capability-summary.yaml` case (both "A5 not yet implemented" and "zero matched Capabilities") resolves identically: `lite-gate` treats the Feature as contributing zero Registry-sourced checks, running only its existing five baseline checks — no error, no Block. |
| AC-012 | REQ-003 | The design states this feature calls a schema validator for `capability-summary.yaml` (A4/A5-owned, not reimplemented here) before trusting `required_lite_checks`/`full_upgrade_required`, and cites `contracts/capability-summary.schema.json`'s exact frozen shape (investigation.md INV-005) as the contract being validated against. |
| AC-013 | REQ-003 | The design states this feature does not re-aggregate `required_lite_checks` across Capabilities itself — it reads the single, already-aggregated array A5's Resolver writes, citing investigation.md INV-006's union-match reasoning as the aggregation rule this feature relies on without re-deriving. |
| AC-014 | REQ-004 | The design places the new Registry-sourced-check step between `lite-gate/SKILL.md`'s existing Step 2 and Step 3, preserving the existing Step 1/Step 2/Step 5 numbering's own relative order and the existing "順序が重要" ordering note (investigation.md INV-010's citation of the live file is the baseline). |
| AC-015 | REQ-004 | The design states a Registry-sourced check-id that duplicates one of the five baseline names is a no-op (not re-executed a second time, not double-recorded in the quality report). |
| AC-016 | REQ-004 | The design states an unmapped Registry-sourced check-id is recorded `N/A` with a stated reason, using the same convention Step 2 already uses for a missing project command — never a FAIL, and never a silently-dropped entry. |
| AC-017 | REQ-004 | The design states this REQ's own file target, `lite-gate/SKILL.md`, is edited **directly** (not via human-copy), citing investigation.md INV-008's live `guard-invariants.json` evidence that it is not currently a protected file, and separately records OQ-001 as an open ruling this choice is contingent on. |
| AC-018 | REQ-004 | The design states no evidence-bundle, cross-model-verification, second-approval, or other `quality-gate`-only mechanism is added to `lite-gate` by this REQ — only bounded execution of a Registry-named, already-capped check list, preserving ADR-0022 item 4's "never grows into a second `quality-gate`" boundary. |
| AC-019 | REQ-005 | The design fixes the Block's position (identical to the existing Risk-Upgrade Gate's own position, before any `specs/<feature>/` file is created), exit code (`10`), message shape (`full-required: ...`), and non-overridability (`--lite` never overrides), all citing `lite-spec/SKILL.md`'s live Risk-Upgrade Gate section (investigation.md INV-010) as the pattern being matched. |
| AC-020 | REQ-005 | The design does not select between OQ-002's two named candidate signal sources — it states both, cites the exact textual gap that makes neither one正本-mandated (investigation.md OQ-002), and defers the choice to spec-review/human ruling before committing design.md to one. |
| AC-021 | REQ-005 | The design names `lite-spec/SKILL.md` as the sole file this REQ edits, confirms it is currently protected (investigation.md INV-008), and states the same human-copy flow REQ-002 uses applies here too — no separate, REQ-005-specific application mechanism is invented. |
| AC-022 | REQ-006 | The design's fixture inventory (a)-(g) maps 1:1 to at least one REQ-001..REQ-005 Acceptance Criterion each — no fixture is listed with no corresponding AC it exercises, and no REQ-001..REQ-005 AC that names a testable behavior (AC-002, AC-007, AC-008, AC-011, AC-015, AC-016) is left with no corresponding fixture. |
| AC-023 | Global | This package's own registration commit does not create `tasks.md`, `traceability.md`, or any file outside `specs/epic-194-a6-lite-integration/**` and the two registration edits (`AGENTS.md`, `specs/workflow-state-registry.json`) — confirmed by `git status`/`git diff --stat` at commit time. |
| AC-024 | Global | `Spec-Review-Status` (this file) and `Impl-Review-Status` (`design.md`) both read `Pending` at commit time — this package does not write `Approved`/`Passed` anywhere (this task's own explicit instruction). |
| AC-025 | Global | After this package's registration commit, `bash scripts/check-sdd-structure.sh .` and `bash plugins/sdd-quality-loop/scripts/check-workflow-state.sh` both exit `0` (investigation.md INV-011's baseline run, re-run post-registration). |

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
  (AND/`max()` respectively).
- `contracts/lite-check-catalog.json` (REQ-001; new, A6-owned) — the
  versioned catalog `required_lite_checks` tokens validate against:
  `{schema: const "lite-check-catalog/v1", catalog_version: integer,
  checks: array of unique non-empty strings}`. Seeded with
  `["installer-dry-run"]` only (Non-goals: no larger seed is正本-
  mandated). Additive/versioned exactly like `lite-upgrade-reason-
  catalog.json` — a later `catalog_version` may add check-ids without a
  `capability-registry.schema.json` change.
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
  INV-018 citing A3's precedent) — `{"upgrade_reasons": [<token>, ...]}`,
  where each `<token>` is a `lite_policy.upgrade_reasons` value already
  validated against `lite-upgrade-reason-catalog.json` by whichever
  upstream mechanism computed it (REQ-005/Open Questions); `check-risk-
  upgrade.{sh,ps1}`'s own new optional second argument is a path to a file
  containing exactly this JSON shape.
- `full_upgrade_required` (REQ-003; A4-owned field, this feature only
  reads it) — see investigation.md INV-005 for its frozen definition; this
  feature's own scope boundary around it is stated in Open Questions
  (OQ-003), not resolved here.
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
  only after independent review); resolves OQ-001, OQ-002, and OQ-003
  (Open Questions, below) either by direct instruction or by a follow-up
  ruling, the same "orchestrator ruling" pattern A2's own OQ-001/OQ-003/
  OQ-004 were closed by (investigation.md INV-002's citation of A2's
  precedent).
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
   path) and, per whichever Open-Questions candidate is later ruled on, a
   Capability-derived check. Either source's Block redirects the user to
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
   accordingly.
5. After `implement-task`, `lite-gate` runs (REQ-003/REQ-004): it locates
   and validates `capability-summary.yaml` if present (absent is a valid,
   zero-extra-checks state, REQ-003), runs its own five baseline checks
   plus every additional `required_lite_checks` entry the Summary names,
   and writes the combined PASS/FAIL result to the same single quality
   report the existing Process already produces, unchanged in every other
   respect (no evidence-bundle, no cross-model verification).
6. At `ship` time, the existing second `check-risk-upgrade` invocation
   (task-block + `requirements.md` recheck, investigation.md INV-010)
   continues to run exactly as documented today; REQ-002's own optional
   second-argument extension is available to it too, on the same terms as
   `lite-spec`'s own call site.

## Edge Cases

- **v1 Registry, field absent entirely**: a Capability entry authored
  before this extension has no `required_lite_checks` key at all (not
  even `lite_policy` itself, if the Capability predates that too) —
  schema-valid under v1.1 with no change (REQ-001 item 3); contributes
  `[]` to any Lite Feature that matches it (REQ-003's own default
  handling); such a Capability is excluded from the "Lite専用Gateを持つ
  Capability" set the combination matrix's `required`-enforcement row
  names, but remains usable under `advisory` enforcement exactly as
  today.
- **Capability ineligible with empty `upgrade_reasons`**: `lite_policy:
  {eligible: false}` with `upgrade_reasons` omitted or `[]` is schema-
  valid (that field stays optional) — REQ-005's Block still fires (keyed
  on `eligible: false` alone, not on a non-empty `upgrade_reasons`), but
  the emitted diagnostic names no specific reason token; this feature's
  design records this as a legitimate, if less-informative, Block rather
  than a validation failure.
- **`required_lite_checks` present but Capability `eligible: false`**: no
  cross-field validator rule forbids this combination (Non-goals — this
  feature does not invent one); because REQ-005's own Block already
  prevents the Capability from ever being matched on a completed Lite
  resolve, any such `required_lite_checks` entries are simply never
  aggregated into a live Capability Summary in practice — a Capability
  author declaring both is not itself an error.
- **Registry-sourced check-id equals a baseline name**: no-op, not a
  second execution or a second report line (AC-015).
- **Registry-sourced check-id with no local command mapping**: `N/A` with
  a stated reason (AC-016), never treated the same as a FAIL.
- **`capability-summary.yaml` present but fails schema validation**:
  `lite-gate` treats this the same way it would treat a malformed
  `reports/implementation/<task-id>.md` today — a `VERDICT: FAIL` with the
  validation failure named as the reason, `Status` unchanged, differing
  from the "absent" case (AC-011) precisely because "absent" is a defined,
  valid zero-checks state while "present but invalid" is evidence of an
  upstream (Resolver or hand-edit) defect this feature's own Non-goals do
  not authorize silently ignoring.
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
  exactly as it does today, unaffected.

## Security Boundaries

- No new write surface: every REQ above either extends an existing,
  already-audited exit-code contract (REQ-002, REQ-005) or reads an
  already-schema-validated artifact another epic's own Resolver writes
  (REQ-003) — this feature introduces no new agent-writable approval-like
  record, and does not touch `SDD_SUDO`, the Approval Sidecar, or any
  hook-guard mechanism.
- Fail-closed by construction, mirroring A2's own posture: an unrecognized
  catalog token (REQ-001), a schema-invalid Capability Summary (Edge
  Cases), and a missing/unreadable second-argument fragment file
  (REQ-002 — treated as "no Capability-derived trigger," never as a parse
  error that silently permits a Lite-ineligible Capability through) all
  either Block or degrade to the strictest defined behavior, never the
  most permissive one.
- The three-file/four-file protected-file boundary (investigation.md
  INV-008) is read, not redefined, by this feature — REQ-002/REQ-005's own
  human-copy staging follows ADR-0011's already-Accepted mechanism
  verbatim; this feature does not propose a new protection mechanism, only
  (via OQ-001) asks whether one already-Accepted mechanism's *inventory*
  should grow by one file.
- No Provider-name contamination surface is added — `installer-dry-run`
  and the twelve upgrade-reason tokens (Field Definitions) are all
  provider-neutral, matching A2's own REQ-003(g) boundary (ADR-0018) this
  feature does not touch but also does not violate.

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

- **OQ-001** (investigation.md OQ-001): Should `lite-gate/SKILL.md` be
  newly added to `guard-invariants.json`'s `protected_gate_suffixes`/
  `phase2_human_copy_targets`, given REQ-004's extension makes it
  enforcement-critical in a way closer to the four files ADR-0022 item 5
  already protects than to an ordinary, freely-editable skill file? This
  feature's own design proceeds on the current, `guard-invariants.json`-
  confirmed basis (direct edit) pending this ruling.
- **OQ-002** (investigation.md OQ-002): At `lite-spec`'s pre-generation
  Risk-Upgrade Gate position (before any Feature-specific code diff
  exists), what supplies the Capability-derived signal REQ-005's Block
  consumes? Candidate (a): evaluate Registry `trigger`s directly against
  every component the Project Context already declares (diff-independent,
  reusing only A2's `evaluate-predicate`, not A5's full Resolver
  pipeline). Candidate (b): scope REQ-005's own Capability-awareness to
  the existing `ship`-time recheck only (where a real diff already
  exists), leaving the pre-generation gate's Capability-awareness inert
  until then. This feature's design.md does not choose between the two
  without this ruling.
- **OQ-003** (investigation.md OQ-003): Does `lite-gate`'s own REQ-003/
  REQ-004 extension need an independent `full_upgrade_required` re-check
  of its own, or may it treat a Capability Summary's mere existence
  (already schema-validated, REQ-003) as sufficient proof every full-
  upgrade determination already happened upstream (REQ-005, at Resolver
  time)? Left to spec-review ruling; this feature's own REQ-003 does not
  currently read `full_upgrade_required` for any Blocking decision of its
  own, only per REQ-003's stated (read-only, non-Blocking) contract.

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
- **OQ-002 is a genuine, unresolved timing gap**, not a drafting
  omission — if spec review selects candidate (a) (Project-Context-wide,
  diff-independent evaluation), a Feature that later touches components
  the initial, whole-project evaluation did not consider relevant could
  still surface a Lite-ineligible Capability only at `ship` time, via the
  already-existing second `check-risk-upgrade` invocation — this is not a
  gap this feature's own REQ-005 leaves uncovered (the `ship`-time
  recheck already exists and already Blocks unconditionally), but it does
  mean candidate (a)'s own pre-generation Block is a defense-in-depth,
  early-exit optimization, not the sole enforcement point, regardless of
  which candidate is chosen.
- **The eleven-category-to-token mapping (Field Definitions,
  `lite-upgrade-reason-catalog.json` growth) is this feature's own
  interpretation of ADR-0022's prose**, not a table the ADR itself
  provides verbatim — a future spec-review pass may find a different
  tokenization more consistent with the existing five-token seed's own
  naming convention; this is recorded here as a low-cost, anticipated
  follow-up, the same way A5's own Design Decisions section already
  flags its own new (non-upstream-fixed) decisions for possible future
  ADR treatment.
- **`installer-dry-run` as the sole `lite-check-catalog.json` seed** may
  prove too narrow once a real Capability Pack is authored — this
  feature's own Non-goals deliberately does not pre-populate a larger
  catalog decision document v2/ADR-0022 does not itself name, accepting
  the risk that a first real Capability author will need to propose a
  `catalog_version`-2 addition of their own (the catalog's own additive
  mechanism, REQ-001, is designed to make that a low-cost, non-breaking
  follow-up, not a schema revision).
