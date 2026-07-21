# Requirements: epic-190-a2-capability-registry

Spec-Review-Status: Pending
Source Issues: https://github.com/aharada54914/sdd-forge/issues/190,
https://github.com/aharada54914/sdd-forge/issues/187
Epic: https://github.com/aharada54914/sdd-forge/issues/190 (Epic A2 —
Capability Registry, part of the AI-DLC Foundation tracked by #187)
Investigation: specs/epic-190-a2-capability-registry/investigation.md
(INV-001..INV-016, OQ-001..OQ-004; OQ-002/OQ-003 resolved by orchestrator
ruling 2026-07-22, see investigation.md's Open Questions section)

## Overview

Decision document v2 (`docs/ai-dlc-foundation-decision-v2.md` §13, Q12)
resolves the Registry/Pack dual-source-of-truth problem by making the
Capability Registry the single machine-readable source of truth for
everything a Gate or a Resolver needs to decide "does this Capability apply,
and what does it require": Capability ID, trigger, required/conditional
Facets, review check IDs, Gate IDs and their stage, lite eligibility,
minimum enforcement, and delivery-strategy classification. Capability Packs
keep only human-authored content (questions, templates, checklists,
guidance, examples) — `capability-packs/*/gates.yaml` is abolished
(INV-002).

This feature is Epic A2 of the Foundation Epic set (decision v2 §19). It
delivers, and only delivers: (1) the Registry schema and its placement
decision, (2) a deterministic Predicate DSL evaluator implementing
ADR-0020's operators and evaluation semantics (used for both `trigger` and
`conditional_facets[].when`), (3) Registry-validation checks (Gate ID
uniqueness, stage-completeness, unregistered-script detection via a Gate
implementation identity schema, Pack-gate-definition absence, referential
integrity, Provider-name contamination, and lite-upgrade-reason-catalog
conformance), (4) a `registry_digest` generation primitive built on Epic
A1's canonicalizer (not reimplemented, INV-006), and (5) protected,
generated projection files for `sdd-quality-loop` to consume at gate-check
time, following the guard-invariants precedent exactly (INV-009), plus a
package-relative discovery contract so an installed plugin can locate the
Registry without a full monorepo checkout. This spec covers the **spec
phase only**: no plugin code, script, or generated artifact is created by
this commit. `tasks.md` and `traceability.md` are themselves deferred to a
later, separate commit authored only after this package's `Spec-Review-Status`
and `design.md`'s `Impl-Review-Status` are both `Passed` — this repository's
`check-workflow-state.sh` hard-enforces "tasks.md requires Spec and Impl
Passed" (`plugins/sdd-quality-loop/scripts/check-workflow-state.sh:681-682`)
for any feature registered in `specs/workflow-state-registry.json`, so
authoring `tasks.md` in the same commit as this Pending package would fail
that check for a `profile: full` entry (Non-goals, below).

## Dependencies

- **Epic A1 (Project Context) — hard dependency.** This spec's
  `registry_digest` generation step (REQ-004) calls Epic A1's canonicalizer
  (YAML 1.2 core-schema parse + RFC 8785/JCS canonical JSON + NFC string
  normalization, Python single implementation + sh/ps1/js wrappers —
  decision v2 §18.3, INV-006) as an external dependency; it is not
  reimplemented here. REQ-004's design and tasks are written against the
  canonicalizer's documented contract (canonical-JSON-in, sha256-out).
  **REQ-004's implementation task is blocked** until Epic A1 publishes a
  finalized canonicalizer path, version, and I/O contract (module import
  path or CLI invocation, its own version identifier, and exact stdin/stdout
  shape); if Epic A1 lands with a materially different interface than
  assumed here, REQ-004's task must be revisited before implementation
  begins, not silently adapted (design.md Assumptions; adversarial review
  2026-07-22, Major finding "A1 の schema/canonicalizer を参照せず複製・仮定").
  The Predicate DSL's field allowlist (REQ-002) is likewise not a hand-copied
  second source of truth: it must be generated from, or automatically
  drift-checked against, Epic A1's Project Context schema once that schema
  lands (`distribution_channels` and `data_classification` are themselves an
  Epic A1 schema addition, ADR-0020 item 5); until Epic A1 lands, the
  evaluator's allowlist is implemented and tested against fixture data with
  an explicit drift-check obligation recorded (investigation.md INV-004a),
  not exercised against a real Project Context.
- **Epic A5 (Capability Resolver) — downstream consumer, not a blocker.**
  Epic A5 is the actual consumer of the Predicate DSL evaluator (REQ-002) and
  the `registry_digest` primitive (REQ-004); it binds them into a Facet
  Manifest's `context_binding` (ADR-0021). Epic A2 ships these as
  independently testable, standalone primitives so Epic A5 does not need to
  build them itself. Because the generated projection (REQ-005) carries only
  `stage: implementation` Gate data, Epic A5's need for `trigger`,
  Facets, and `lite_policy` is met by reading the full Registry directly
  through REQ-005's package-relative discovery contract (API / Contract
  Plan, design.md), not through the projection — Epic A2 therefore ships one
  discovery contract that serves both the Implementation Gate (via the
  projection) and Epic A5's Resolver (via the full Registry).
- No dependency on Epic A3 (Component Path Ownership) or Epic A4 (Facet
  Manifest schema): Epic A2's `trigger` evaluation operates only on
  affected-component properties already in scope per ADR-0020 item 4's final
  bullet ("evaluated only against the affected component's properties");
  which components are "affected" is Epic A3's `ownership_digest`/reverse
  coverage concern, consumed by Epic A5, not by Epic A2.

## Target Users

- Registry maintainers who need one file per Capability Registry concept
  (schema, DSL evaluator, validator, digest generator, projection generator)
  instead of duplicating Gate/Facet/enforcement data across
  `capability-packs/*/gates.yaml` and ad hoc Pack content (INV-002).
- Epic A5 (Resolver) implementers who need a pure, deterministic, fully
  Evidence-recording Predicate DSL evaluator they can call rather than
  re-deriving ADR-0020's semantics themselves.
- `sdd-quality-loop`'s Implementation Gate, which needs a generated,
  protected `gate-capabilities.json` projection it can read without parsing
  the authoring-format Registry directly (mirrors how
  `sdd-hook-guard.py` reads `guard_invariants.py`, never
  `guard-invariants.json` — INV-009).
- CI maintainers who need a `--check` drift gate proving the generated
  projection always matches the source Registry, and a completeness-test
  suite proving every `stage: implementation` Gate has exactly one
  registered implementation.
- Future Capability Pack authors (no Packs exist yet — INV-002) who need the
  Registry/Pack boundary and the Provider-neutrality boundary (ADR-0018)
  enforced automatically from the first Pack onward, not retrofitted later.
- Operators of a standalone-installed `sdd-quality-loop` plugin (Claude Code,
  Codex CLI, or Copilot CLI) who need the Registry discoverable without a
  full monorepo checkout present (REQ-005's discovery contract).

## Problems

- Without a single Registry schema, a future Capability Pack could
  reintroduce `gates.yaml`-shaped Gate definitions inside a Pack, recreating
  the dual-source-of-truth problem decision v2 §13 explicitly abolishes
  (INV-002).
- Without a shared, tested Predicate DSL evaluator, `trigger` and
  `conditional_facets[].when` evaluation could be implemented divergently by
  whichever Epic (A2, A5, or a Pack-specific script) needs it first, breaking
  ADR-0020's "no second condition language" guarantee and its determinism
  requirement (same input → same output, across runtimes).
- Without an automated Provider-name-contamination check, ADR-0018's boundary
  ("A Capability Pack never carries a provider name") is enforced only by
  human review discipline — the "existing review rule" ADR-0018 refers to has
  no automated implementation anywhere in this repository today (INV-008).
- Without a `registry_digest` generation primitive built on Epic A1's
  canonicalizer, Epic A4/A5 would each need to reinvent Registry-fragment
  canonicalization, risking a divergent hash between the Facet Manifest's
  `context_binding.registry_digest` and whatever a human or CI tool computes
  independently — defeating ADR-0021's staleness-binding guarantee. Without a
  fixed fragment shape and ID-ordering rule, two callers requesting the same
  semantic fragment in a different order (or with duplicate IDs) could
  produce two different digests for identical content, since JCS normalizes
  object keys but not array order.
- Without projecting the Registry into a generated, protected,
  `sdd-quality-loop`-local file (mirroring guard-invariants), the
  Implementation Gate would need to parse the authoring-format Registry
  directly at gate-check time, coupling gate execution to the Registry's
  schema evolution and losing the "sha256 header + Do not edit" tamper-
  evidence guard-invariants already provides (INV-009).
- Without a Gate-ID uniqueness and stage-completeness check, a Registry edit
  could silently introduce a duplicate Gate ID (ambiguous which definition
  applies) or a `stage: implementation` Gate with no corresponding script,
  violating ADR-0017's Implementation Gate scope invariant.
- Without a package-relative discovery contract, an installed
  `sdd-quality-loop` plugin (standalone, no surrounding monorepo checkout)
  has no defined way to locate `contracts/capability-registry.json`; every
  script that reads the Registry would either assume a repository-root-
  relative path that does not exist in an installed context, or silently
  fall back to stale/absent data (INV-016).

## Goals

- REQ-001 (Registry schema and placement): Author
  `contracts/capability-registry.schema.json` (JSON Schema, draft-07, styled
  like `contracts/workflow-state-registry.schema.json` — INV-010) and the
  Registry instance file `contracts/capability-registry.json`
  (`"schema": "capability-registry/v1"`, styled like
  `contracts/agent-model-capabilities.v2.json` — INV-010). Top-level shape:
  a `capabilities` array (`id`, `trigger`, `required_facets`,
  `conditional_facets`, `review_check_ids`, `gate_ids`, `lite_policy`,
  `minimum_enforcement`, `delivery_strategy`) and a top-level `gates` array
  (`id`, `stage`, `blocking`, `implementation_ref`), referenced by ID from
  each Capability's `gate_ids` (INV-003: ADR-0017's schema example is a flat
  top-level list, not per-Capability). `stage` is one of `implementation` /
  `artifact` / `promotion`; `artifact` and `promotion` are reserved enum
  values with **no** completeness-test obligation in Foundation (ADR-0017
  item 1). `lite_policy.eligible` is a boolean; `lite_policy.upgrade_reasons`
  is an open string array, not a closed enum (INV-007, OQ-001) — each token
  is validated at the REQ-003(h) validator level against a versioned catalog,
  not constrained by the schema itself. `minimum_enforcement`, when present,
  is the literal string `required` (decision v2 §10: "Registry 側は
  `minimum_enforcement: required` を持てる" — no other value is defined).
  `delivery_strategy.kind` is a **reserved, open, non-empty string** with no
  defined vocabulary in Foundation (OQ-003, **resolved by orchestrator ruling
  2026-07-22**: decision v2 requires only that the field exist; it reserves
  vocabulary-freezing for a real cloud-service delivery case and a later ADR,
  the same pattern already applied to the Artifact/Promotion Gate vocabulary
  — this spec does **not** infer a closed enum from decision v2 §17's Pack
  rollout order). `trigger` is a single Predicate DSL expression (REQ-002);
  the schema holds the Predicate DSL in exactly two places — `trigger` and
  `conditional_facets[].when` — and has no top-level `conditions` field
  (OQ-002, **resolved by orchestrator ruling 2026-07-22**: decision v2 §13's
  "trigger / conditions" names the DSL body itself, not a third field).
- REQ-002 (Predicate DSL evaluator): Design a deterministic evaluator
  (Python master + sh/ps1 wrappers, per the `sdd-hook-guard` pattern —
  INV-014) implementing ADR-0020 in full: logical operators `all` (empty →
  `true`) / `any` (empty → `false`) / `not` (**strictly unary**, arity
  exactly 1 — a `not` node with zero or two-or-more children is a
  `PREDICATE_SCHEMA_ERROR`, not a valid predicate; no short-circuit, every
  predicate evaluated and recorded); comparison operators `equals` /
  `not_equals` / `contains` (`array ∋ scalar` only) / `in` (`scalar ∈ array
  literal` only) / `exists`. General rule: missing path, `null`, or type
  mismatch on `equals`/`not_equals`/`contains`/`in` → predicate is `false` +
  a recorded `WARN`, never an exception. `exists` is the sole, explicit
  exception: path present → `true` even when the value is `null`; path
  absent → `false` + `WARN`; type is irrelevant. `trigger` reuses the exact
  same evaluator and the exact same field allowlist as
  `conditional_facets[].when` (ADR-0020 item 4's last bullet — "no second
  condition language"). Every operator forbidden by ADR-0020 (regex,
  arbitrary JSONPath, shell, JS, Python, dynamic code, Provider API calls,
  time-/network-dependent conditions) must be structurally inexpressible in
  the DSL's own grammar, not merely undocumented. Field allowlist:
  `artifact_kinds`, `runtime_classes`, `characteristics.pii`,
  `characteristics.ui`, `characteristics.auto_update`,
  `characteristics.local_persistence`, `distribution_channels`,
  `data_classification` (ADR-0020 item 5) — this list is generated from, or
  drift-checked against, Epic A1's Project Context schema once it lands, not
  a second, hand-maintained source of truth (Dependencies, INV-004a). The
  evaluator must emit a Evidence record for every predicate it evaluates,
  conforming to a published Evidence JSON Schema (`operator`, `path` using
  the same nested/dotted-path traversal convention as Epic A1's Project
  Context schema, `outcome` ∈ {`match`, `no-match`, `warn`}, and a `reason`
  whenever `outcome == "warn"`), consumable by Epic A5's Resolver Evidence
  output. Nested logical (`all`/`any`/`not`) trees record their children's
  Evidence in a fixed depth-first, left-to-right, stable order.
- REQ-003 (Registry validation): Design a validation script/check-suite (same
  Python-master + sh/ps1-wrapper convention) enforcing eight independently
  identifiable, independently testable checks:
  - (a) **Gate ID uniqueness** across the top-level `gates` array;
  - (b) **stage-completeness** — every `gates[]` entry with `stage:
    implementation` carries a non-empty `implementation_ref` pointing to an
    existing script path (`artifact`/`promotion`-stage entries are exempt,
    per ADR-0017 item 1);
  - (c) **unregistered-script detection**, defined via a **Gate
    implementation identity** schema (OQ-004: this spec's own design
    proposal, not directly stated in decision v2/ADRs): `implementation_ref`
    names a canonical implementation identity grouping a Python master
    script with its recognized wrapper extensions (`.sh`, `.ps1`, and `.js`
    where applicable) under a fixed set of configured scan roots; a
    symlinked script resolves to its target before comparison; two `gates[]`
    entries must not resolve to the same wrapper group; a script outside the
    configured scan roots (e.g. a future external Capability Pack's own
    script directory) is never flagged unregistered. Subject to this
    identity schema, every script matching the configured gate-script naming
    convention under the configured scan directories is referenced by
    exactly one `gates[].implementation_ref`;
  - (d) **no Pack-owned Gate definitions** — no file matching
    `capability-packs/*/gates.yaml` (or a plugin-nested equivalent) exists
    anywhere in the repository (INV-002, a forward-guard since no Pack
    exists yet);
  - (e) **no missing `stage`** on any `gates[]` entry (schema already
    requires this; the validator re-asserts it independently as
    defense-in-depth, exercised against a fixture that bypasses schema
    validation, matching decision v2 §13's own redundant listing of
    "stage欠落なし");
  - (f) **referential integrity** — every `capabilities[].gate_ids` entry
    resolves to a defined `gates[].id`; this is a **validator-level check
    only** (JSON Schema draft-07 cannot express a sibling-array runtime-value
    cross-reference — the schema's own role for `gate_ids` is limited to
    type/syntax constraints);
  - (g) **Provider-name contamination** — every string-valued field in
    `contracts/capability-registry.json` is scanned against a maintained,
    allowlist-based term list (design.md proposes
    `plugins/sdd-quality-loop/references/provider-terms.json`) of known
    provider-identifying tokens (e.g. `azure`, `aws`, `gcp`,
    `durable-functions`, `step-functions`, `app-store`, `google-play`); any
    match fails validation (ADR-0018's boundary, INV-008 — this is the first
    automated implementation of that boundary rule in this repository);
  - (h) **lite-upgrade-reason-catalog conformance** — every
    `lite_policy.upgrade_reasons` token resolves against a versioned catalog
    (`contracts/lite-upgrade-reason-catalog.json`, a new implementation-phase
    contract); an unrecognized token fails validation (fail-closed), while
    the catalog's own vocabulary remains additive/versioned, not frozen into
    a closed schema enum (OQ-001, adversarial review 2026-07-22).
- REQ-004 (`registry_digest` generation): Design a script that computes a
  sha256 digest over a canonical-JSON serialization (RFC 8785/JCS, NFC
  string normalization — decision v2 §18.3) of either the whole Registry or
  a named subset of it ("a Registry fragment", per ADR-0021's own phrasing —
  the fragment selection itself is Epic A5's Resolver concern, not Epic
  A2's). The script accepts an explicit `--capability-ids` list, an explicit
  `--gate-ids` list, or both (at least one required, or `--whole` for the
  entire Registry) as its fragment-selection input; duplicate IDs in the
  input are deduped before hashing; an ID not present in the Registry is a
  hard failure, never a silent no-op; the resulting fragment's `capabilities`
  and `gates` sub-arrays are stable-sorted by ID before serialization, so
  that requesting the identical semantic ID set in a different order or with
  duplicates always produces the identical digest (Problems). The script
  calls Epic A1's canonicalizer for the canonicalization step (Dependencies
  section) rather than reimplementing JCS; **this task is blocked until Epic
  A1's canonicalizer contract is finalized** (Dependencies). Because
  `contracts/capability-registry.json` is authored directly in JSON (REQ-001;
  INV-010), the YAML-1.2-parse precondition in decision v2 §18.3 does not
  apply to this input — only the canonical-JSON + NFC + sha256 steps do; this
  narrowing is stated explicitly in design.md, not silently assumed.
- REQ-005 (projection generation, protection, and discovery): Design a
  generator (mirroring `generate-guard-invariants.py` exactly — INV-009)
  that reads `contracts/capability-registry.json` and
  `contracts/capability-registry.schema.json` and writes
  `plugins/sdd-quality-loop/scripts/generated/gate-capabilities.json`,
  headed with a top-level `_generated` metadata object (`source`,
  `schema_version`, `sha256`, and a "This file is generated. Do not edit."
  notice string) as the **sole normative header format** — no comment-line
  ("# Generated...") header contract exists anywhere in this document. The
  generator supports a `--check` mode (no write, drift detection, wired into
  `.github/workflows/test.yml` per the `generate-guard-invariants.py --check`
  precedent — INV-009). This same script family, the Registry-validation
  script (REQ-003), the Predicate DSL evaluator (REQ-002), and the
  `registry_digest` generator (REQ-004) are all added to the existing
  `plugins/sdd-quality-loop/` plugin — **no new plugin is introduced**
  (adversarial review 2026-07-22, Major finding "新規 sdd-capability plugin
  は3環境packagingコストを無視"; design.md Design Decisions records the
  rejected new-plugin alternative in one paragraph, INV-015). REQ-005 also
  defines a **package-relative Registry discovery contract**: any script
  that reads the Registry first checks a packaged, plugin-relative copy
  (`plugins/sdd-quality-loop/contracts/capability-registry.json`/`.schema.json`,
  vendored at packaging time — implementation-phase work) via the plugin-root
  environment-variable convention already used by this repository's hooks
  (`${CLAUDE_PLUGIN_ROOT}`, INV-016, and its Codex/Copilot analogs), then
  falls back to the monorepo-relative `contracts/` path (found by walking up
  from the script's own location to a repository-root marker, `AGENTS.md`)
  for in-repo development; if neither resolves, or the discovered file's
  `schema` field is outside a small supported-version set, the script fails
  closed with a diagnostic naming every path it attempted. The generated
  projection file, the generator script itself, and
  `contracts/capability-registry.json`/`.schema.json` must all be registered
  as protected files (added to `guard-invariants.json`'s
  `_PROTECTED_GATE_SUFFIXES` and `PHASE2_HUMAN_COPY_TARGETS`, which are
  themselves protected — INV-009) — this registration itself must be staged
  through `specs/epic-190-a2-capability-registry/human-copy/` (ADR-0011
  pattern) rather than edited directly.
- REQ-006 (tests): Author `tests/*.tests.sh` + `.tests.ps1` pairs (INV-014)
  and fixture data covering: the Predicate DSL evaluator (every operator,
  the fail-closed general rule, the `exists` exception, `all`/`any` empty-
  list behavior, no-short-circuit evidence recording, `trigger` reusing the
  same evaluator/allowlist, `not`'s unary arity and truth table with child
  Evidence, Evidence-JSON-Schema conformance and depth-first stable
  ordering); the Registry validator (all eight REQ-003(a-h) checks,
  including the Gate implementation identity's wrapper-pair/scan-root/
  symlink/external-Pack bidirectional fixtures and the lite-upgrade-reason-
  catalog fail-closed check); `registry_digest` determinism, fragment
  identity (stable ID sort, dedupe, unknown-ID failure), and JCS/NFC
  canonicalization vectors; the projection generator's `--check` mode
  (clean pass, and a mutated-source negative case); and the Registry
  discovery contract's three installed-layout fixtures (one per runtime).
  Every new suite is registered directly in `tests/run-all.sh`/`.ps1`
  (unprotected, INV-014) and staged for `.github/workflows/test.yml`
  registration via human-copy (protected, INV-009/INV-014). All four scripts
  (`evaluate-predicate`, `validate-capability-registry`,
  `generate-registry-digest`, `generate-gate-capabilities`) additionally
  carry golden-fixture parity tests proving byte-identical `.sh`/`.ps1`
  output (`generate-registry-digest` also ships and parity-tests a `.js`
  wrapper, matching Epic A1's canonicalizer's own wrapper set), and each
  script's wrapper pair is invoked from within a Claude Code, a Codex CLI,
  and a Copilot CLI installed-plugin context to prove 3-runtime invocation
  parity, not merely bare-shell parity.

## Non-goals

- Implementing Epic A1's Project Context schema, canonicalizer, or
  `sdd/provider-bindings.yaml` — those are Epic A1's own deliverables,
  consumed here only as a dependency (Dependencies section).
- Implementing Epic A5's Resolver, Facet Manifest binding, or Resolver
  Evidence output format — Epic A2 ships the DSL evaluator and digest
  primitive that Epic A5 will call; it does not build the Resolver itself.
- Authoring any Capability Pack content (`questions.md`, `templates/`,
  `review-checklist.md`, `guidance.md`, `examples/`, `policy-examples/`) —
  no Pack exists yet (INV-002); REQ-003(d)'s Pack-gate-definition check is a
  forward-guard only.
- Freezing a versioned reason catalog's own vocabulary for
  `lite_policy.upgrade_reasons` beyond requiring every token to resolve
  against *some* catalog entry (REQ-003(h), OQ-001) — the catalog's content
  itself is Epic A6's decision (ADR-0022 item 4), not this spec's; and
  freezing `delivery_strategy.kind` to any vocabulary at all (OQ-003,
  resolved 2026-07-22: the field is an open, non-empty string in Foundation,
  full stop) — both are left open pending a human decision or a later ADR.
- Implementing the Artifact Gate or Promotion Gate stages, or their check
  inventories — both remain reserved enum values with vocabulary deferred to
  `sdd-delivery` (ADR-0017 items 3-4); this spec's `stage` enum reserves the
  values but implements no behavior for them.
- Introducing a new plugin (`plugins/sdd-capability/` or otherwise) for this
  scope — REQ-002..REQ-005's Registry-authoring/validation/digest/projection
  scripts are added to the existing `plugins/sdd-quality-loop/` plugin,
  which already carries a complete 3-environment manifest (design.md Design
  Decisions; INV-015; adversarial review 2026-07-22).
- Writing any actual plugin code, contract file, generated projection, or
  test file — this is the spec phase; `tasks.md` (once authored) schedules
  that work for the implementation phase and no file under `plugins/`,
  `scripts/`, `contracts/`, `tests/`, or `.github/` is created or modified by
  this commit.
- **Authoring `tasks.md` or `traceability.md` in this commit.** This
  repository's workflow-state model treats them as Phase 2 artifacts,
  authored only after `Spec-Review-Status` (this document) and
  `Impl-Review-Status` (design.md) are both `Passed` — `check-workflow-state.sh`
  hard-fails any registered, non-legacy feature whose `tasks.md` exists while
  either status is not `Passed`
  (`plugins/sdd-quality-loop/scripts/check-workflow-state.sh:681-682`, "tasks.md
  requires Spec and Impl Passed"). This session's own reference spec
  (`specs/epic-159-pillar-c/requirements.md` Non-goals) states the same
  convention in different words: "tasks.md and traceability.md (Phase 2
  artifacts, authored after spec approval)". This package is therefore four
  files (`investigation.md`, `requirements.md`, `design.md`,
  `acceptance-tests.md`); `tasks.md`/`traceability.md` content already drafted
  during this spec's authoring is preserved outside the repository
  (scratchpad) for reuse once a human passes this spec's review, rather than
  discarded.
- Modifying `AGENTS.md`'s "Active Spec Directories" or
  `specs/workflow-state-registry.json` in this commit — that registration is
  isolated to its own, separate commit (orchestrator instruction, to
  minimize conflicts with parallel Epic A1/A3 work).

## User Stories

As a Registry maintainer, I can add a new Capability entry with a `trigger`,
required/conditional Facets, a Gate reference list, a `lite_policy`, and a
`delivery_strategy.kind`, and know the validator will catch a duplicate Gate
ID, a missing implementation for a `stage: implementation` Gate, an
unregistered gate-shaped script, an unrecognized `upgrade_reasons` token, or
a leaked provider name before the Registry is trusted as a source of truth.
As an Epic A5 implementer, I call the Predicate DSL evaluator with a
`trigger` or `conditional_facets[].when` expression and an affected
component's properties, and get back a boolean plus an Evidence record I can
fold directly into Resolver Evidence, without needing to re-derive
ADR-0020's fail-closed/`exists`-exception semantics myself; when I need the
full Capability data (`trigger`, Facets, `lite_policy`) rather than just Gate
data, I locate the Registry through the same package-relative discovery
contract the Implementation Gate uses. As a CI maintainer, I run the
projection generator's `--check` mode and know immediately whether
`gate-capabilities.json` has drifted from `contracts/capability-registry.json`,
without a human needing to eyeball a diff. As an operator running the
`sdd-quality-loop` plugin standalone (no monorepo checkout), I get a clear,
fail-closed diagnostic — not a silent miss — if the Registry cannot be
located or its schema version is unsupported. As a human reviewer, I see
every place this spec had to make a judgment call the source documents left
ambiguous (OQ-001, OQ-004 — OQ-002/OQ-003 are resolved by orchestrator ruling
2026-07-22) called out explicitly, rather than silently resolved.

## Acceptance Criteria

- AC-001: `contracts/capability-registry.schema.json` validates
  `contracts/capability-registry.json` under a draft-07 JSON Schema styled
  like `contracts/workflow-state-registry.schema.json`; `additionalProperties:
  false` at every object level that decision v2/ADR-0017/ADR-0020/ADR-0022
  fully enumerate. (REQ-001)
- AC-002: Every `gates[]` entry has `id`, `stage` (one of `implementation` /
  `artifact` / `promotion`), and `blocking` (boolean); `stage:
  implementation` entries additionally require a non-empty
  `implementation_ref`. (REQ-001)
- AC-003: `lite_policy.upgrade_reasons` is typed as an array of non-empty
  strings (open vocabulary), not a closed enum; `lite_policy.eligible` is
  typed boolean and required whenever `lite_policy` is present. (REQ-001,
  OQ-001)
- AC-004: `delivery_strategy.kind` is typed as a non-empty string with **no**
  enum constraint; design.md documents this as a reserved field whose
  semantics are deferred to a future real-case ADR (orchestrator ruling
  2026-07-22), not inferred from decision v2 §17's Pack rollout order.
  (REQ-001, OQ-003)
- AC-005: `minimum_enforcement` has a positive schema test (`"required"`
  accepted) and a negative test (any other string value rejected); a
  `stage: artifact`/`promotion` `gates[]` entry with no `implementation_ref`
  and no `minimum_enforcement` passes schema validation and is exempt from
  every Foundation-time completeness check (reserved-stage inertness).
  (REQ-001)
- AC-006: The schema defines the Predicate DSL in exactly two locations —
  `capabilities[].trigger` and `capabilities[].conditional_facets[].when` —
  and has no top-level `conditions` field or property named `conditions`
  anywhere; a fixture asserting `additionalProperties: false` rejects a
  `capabilities[]` entry carrying an extra `conditions` key. (REQ-001,
  OQ-002)
- AC-007: The DSL evaluator design specifies, for each of
  `equals`/`not_equals`/`contains`/`in`: missing path → `false` + `WARN`;
  `null` value → `false` + `WARN`; type mismatch → `false` + `WARN`; no
  operator ever raises an exception for these three cases. (REQ-002)
- AC-008: The DSL evaluator design specifies `exists` returns `true` when the
  path is present regardless of the value (including `null`), and `false` +
  `WARN` when the path is absent; type is never inspected for `exists`.
  (REQ-002)
- AC-009: The DSL evaluator design specifies `all` of an empty predicate list
  evaluates to `true`, `any` of an empty predicate list evaluates to `false`,
  and neither `all` nor `any` short-circuits — every child predicate's result
  is recorded in Evidence regardless of whether it could change the outcome.
  (REQ-002)
- AC-010: `trigger` and `conditional_facets[].when` are specified to share
  exactly one evaluator implementation and exactly one field allowlist — the
  design contains no second, separate condition-evaluation code path.
  (REQ-002)
- AC-011: The field allowlist is generated from, or automatically
  drift-checked against, Epic A1's Project Context schema rather than
  hand-duplicated; a drift-check fixture fails when A2's local allowlist
  copy and A1's schema-declared field set diverge. (REQ-002)
- AC-012: `not` is specified as strictly unary (arity exactly 1): a `not`
  node with zero or two-or-more children is a `PREDICATE_SCHEMA_ERROR`; a
  fixture demonstrates the negated child's own Evidence entry is still
  recorded even though `not` inverts the boolean result (truth table: child
  `true` → `not` result `false`; child `false` → `not` result `true`; child
  `WARN` → `not` result `false`, `WARN` preserved in the child's own Evidence
  entry). (REQ-002)
- AC-013: Every predicate evaluation's Evidence entry conforms to a
  published Evidence JSON Schema (`operator`, `path` using the same
  nested/dotted-path traversal convention as Epic A1's Project Context
  schema — not a flattened-key-only map —, `outcome` ∈ {`match`, `no-match`,
  `warn`}, `reason` populated whenever `outcome == "warn"`); nested logical
  (`all`/`any`/`not`) trees record their children's Evidence in a fixed
  depth-first, left-to-right, stable order. (REQ-002)
- AC-014: The Registry validator design specifies a Gate-ID-uniqueness check
  over the top-level `gates[]` array (not per-Capability). (REQ-003(a))
- AC-015: The Registry validator design specifies that every `stage:
  implementation` Gate must resolve `implementation_ref` to an existing file
  path, and that `stage: artifact`/`promotion` Gates are exempt from this
  check (ADR-0017 item 1). (REQ-003(b))
- AC-016: The Gate implementation identity schema is specified:
  `implementation_ref` names a canonical implementation identity grouping a
  Python master script with its recognized wrapper extensions (`.sh`,
  `.ps1`, and `.js` where applicable) under a fixed set of configured scan
  roots; a symlinked script resolves to its target before comparison; two
  `gates[]` entries must not resolve to the same wrapper group; a script
  outside the configured scan roots is never flagged unregistered.
  (REQ-003(c))
- AC-017: The Registry validator design specifies unregistered-script
  detection: every script matching the naming convention under the
  configured scan roots (per AC-016) is referenced by exactly one
  `gates[].implementation_ref`; a bidirectional fixture set proves (i) an
  sh+ps1 wrapper pair for one Python master counts as one registered
  implementation, not two unregistered scripts, (ii) a script outside the
  scan roots is not flagged, and (iii) an in-scan-root script with no
  `implementation_ref` is flagged unregistered. (REQ-003(c))
- AC-018: The Registry validator design specifies that it independently
  re-asserts no `gates[]` entry lacks `stage`, exercised against a fixture
  constructed to bypass schema validation (a validator-direct call), proving
  the validator's own defense-in-depth check fires even when schema
  validation is skipped. (REQ-003(e))
- AC-019: The Registry validator design specifies a repository-wide check
  that no `capability-packs/*/gates.yaml`-shaped file exists. (REQ-003(d))
- AC-020: The Registry validator design specifies a Provider-name-
  contamination scan against a maintained term allowlist, covering every
  string-valued field in the Registry instance file, with the check
  documented as the first automated implementation of ADR-0018's boundary
  rule in this repository (not a pre-existing check being extended).
  (REQ-003(g))
- AC-021: The Registry validator design specifies a referential-integrity
  check — every `capabilities[].gate_ids` entry must resolve to a defined
  `gates[].id` — as a **validator-level check only**; the schema's own role
  for `gate_ids` is limited to type/syntax constraints (`uniqueItems`,
  array-of-strings) because JSON Schema draft-07 cannot express a
  sibling-array runtime-value cross-reference. No AC in this document claims
  a schema-level dynamic reference check. (REQ-003(f))
- AC-022: The Registry validator design specifies that every
  `lite_policy.upgrade_reasons` token resolves against a versioned catalog
  (`contracts/lite-upgrade-reason-catalog.json`); an unrecognized token fails
  validation (fail-closed); the catalog's own vocabulary is
  additive/versioned and is not frozen by this schema or validator contract.
  (REQ-003(h))
- AC-023: The `registry_digest` generator design specifies it calls into Epic
  A1's canonicalizer rather than reimplementing RFC 8785 (JCS) or YAML 1.2
  parsing, explicitly states the YAML-1.2-parse step does not apply to this
  JSON-authored input, and records REQ-004's implementation task as blocked
  until Epic A1's canonicalizer publishes a finalized path, version, and I/O
  contract. (REQ-004)
- AC-024: The `registry_digest` generator design specifies its
  fragment-selection API accepts an explicit `--capability-ids` list, an
  explicit `--gate-ids` list, or both; duplicate IDs in the input are
  deduped before hashing; an ID not present in the Registry is a hard
  failure, never a silent no-op; the fragment's `capabilities` and `gates`
  sub-arrays are stable-sorted by ID before serialization so identical
  semantic ID sets always produce identical digests regardless of input
  order or duplication. (REQ-004)
- AC-025: The projection generator design specifies the output header is
  carried exclusively as a top-level `_generated` object (`source`,
  `schema_version`, `sha256`, and a "This file is generated. Do not edit."
  notice string); no comment-line ("# Generated...") header contract exists
  anywhere in this document or in design.md. (REQ-005)
- AC-026: The projection generator design specifies a `--check` mode: a
  hand-mutated committed projection causes `--check` to exit non-zero; a
  freshly, correctly regenerated projection causes `--check` to exit zero;
  no filesystem write occurs in `--check` mode. (REQ-005)
- AC-027: The design specifies a package-relative Registry-discovery
  contract usable from each of the three supported runtimes (Claude Code,
  Codex CLI, Copilot CLI): a script locates
  `contracts/capability-registry.json`/`.schema.json` via a packaged,
  plugin-relative path first, falls back to a monorepo-relative path for
  in-repo development, verifies the discovered Registry's `schema` field
  against a small supported-version set, and fails closed with a diagnostic
  naming every attempted path if neither location resolves or the version
  check fails; three fixtures (one per runtime) simulate a standalone
  install (no monorepo checkout, no `AGENTS.md` marker) and prove discovery
  succeeds via the packaged copy alone. (REQ-005)
- AC-028: The design specifies that the projection generator, the
  Registry-authoring/validation/digest scripts (REQ-002/003/004), and the
  generated projection all live under the existing `plugins/sdd-quality-loop/`
  plugin; no new plugin is introduced; design.md's Design Decisions records
  the rejected new-plugin alternative in a single paragraph, including why
  (3-environment packaging cost with no offsetting benefit shown). (REQ-005)
- AC-029: tasks.md schedules the protected-file registration (adding the new
  paths to `guard-invariants.json`'s protected-suffix and human-copy-target
  lists, and to `.github/workflows/test.yml`) as a task carried out via
  `specs/epic-190-a2-capability-registry/human-copy/` +
  a `MANIFEST.sha256`, never as a direct edit to a protected file. (REQ-005)
- AC-030: tasks.md schedules `tests/*.tests.sh`/`.tests.ps1` pairs for every
  REQ-002..REQ-005 deliverable, each pair covering at minimum the cases
  listed in REQ-006, and each pair's `tests/run-all.sh`/`.ps1` registration
  as a direct (unprotected) edit while its `.github/workflows/test.yml`
  registration is staged via human-copy. (REQ-006)
- AC-031: All four scripts (`evaluate-predicate`,
  `validate-capability-registry`, `generate-registry-digest`,
  `generate-gate-capabilities`) have golden-fixture parity tests proving
  their `.sh`- and `.ps1`-wrapper invocations produce byte-identical output
  for identical input; `generate-registry-digest` additionally ships and
  parity-tests a `.js` wrapper, matching Epic A1's canonicalizer's own
  sh/ps1/js wrapper set. (REQ-006)
- AC-032: A JCS/NFC canonicalization vector fixture set covers RFC 8785
  key-ordering/number-formatting edge cases and Unicode NFC composed-vs-
  decomposed string equivalence, asserting the digest generator produces
  identical digests for canonically-equivalent-but-differently-encoded
  input; a stable-ordering fixture confirms AC-024's ID-array sort applies
  regardless of caller-supplied input order. (REQ-006)
- AC-033: Each of the four scripts' wrapper pair is invoked from within a
  Claude Code, a Codex CLI, and a Copilot CLI installed-plugin context
  against the same fixture input, asserting identical exit codes and stdout
  across all three runtimes (ties to AC-027's installed-layout fixtures).
  (REQ-006)
- AC-034: No file under `plugins/`, `scripts/`, `contracts/`, `tests/`, or
  `.github/` is created or modified by this commit; `git status`/`git diff`
  at spec-authoring time shows changes confined to
  `specs/epic-190-a2-capability-registry/`. This is a one-time,
  spec-commit-bound manual review record, not a Planned, automated
  implementation-phase test — implementing REQ-001..006 will necessarily
  touch those paths, so an automated test asserting otherwise would fail by
  construction the moment implementation begins. (Non-goals)
- AC-035: Every open question this spec could not resolve from decision v2
  or an ADR alone (OQ-001, OQ-004 — OQ-002/OQ-003 are resolved by
  orchestrator ruling 2026-07-22) is recorded in investigation.md and
  cross-referenced from the relevant REQ/AC. This is a Phase-1 check, doable
  now without `traceability.md`. (User Stories, Dependencies)
- AC-036: A full OQ-to-task traceability audit (every OQ's resolution traced
  through `traceability.md`'s requirement/design/task/test columns) is
  deferred to Phase 2, once `traceability.md` exists; its target is
  `traceability.md` itself, which does not exist during this Phase 1
  package. (User Stories, Dependencies)

## Field Definitions

- `trigger` (REQ-002; ADR-0020) — a single Predicate DSL expression,
  evaluated against an affected component's properties, that decides whether
  a Capability applies to that component at all. Uses the same evaluator and
  field allowlist as `conditional_facets[].when`.
- `conditional_facets[].when` (REQ-002; ADR-0020) — a Predicate DSL
  expression, evaluated per affected component, deciding whether a specific
  Facet is included once its owning Capability has already been triggered.
- `gate_ids` (REQ-001; ADR-0017, INV-003) — a Capability's reference list
  into the Registry's single, top-level `gates[]` array; Capabilities never
  embed their own Gate definitions (that duplication is exactly what
  decision v2 §13 abolishes).
- `implementation_ref` (REQ-001, REQ-003(c); this spec's own proposal,
  OQ-004) — a canonical implementation identity on a `gates[]` entry naming
  the Python-master script (and, implicitly, its recognized sh/ps1/js
  wrapper siblings under the configured scan roots) that implements a
  `stage: implementation` Gate's check; required for `implementation`-stage
  entries, meaningless (and not required) for reserved `artifact`/`promotion`
  entries.
- `registry_digest` (REQ-004; ADR-0021) — a sha256 digest, computed over a
  canonical-JSON (RFC 8785/JCS) serialization of a named Registry fragment,
  used by Epic A4/A5 to bind Facet Manifest staleness to Registry content
  changes; the digest **primitive** is Epic A2's deliverable, the fragment-
  selection policy and the `context_binding.registry_digest` binding itself
  are Epic A4/A5's.
- `lite_policy` (REQ-001, REQ-003(h); ADR-0022) — per-Capability lite-track
  eligibility: `eligible` (boolean) and `upgrade_reasons` (open string array,
  OQ-001, each token validated against a versioned reason catalog at the
  REQ-003(h) validator level, not by the schema).
- `delivery_strategy.kind` (REQ-001; OQ-003, resolved 2026-07-22) — a
  reserved, open, non-empty string tag on each Capability, recorded now
  (cheap, knowable at Registry-authoring time) with no defined vocabulary in
  Foundation; a future `sdd-delivery` ADR, triggered by a real delivery case,
  defines its semantics and (if warranted) a closed vocabulary.
- `Registry fragment` (REQ-004; ADR-0021's own phrasing) — a named subset of
  the Registry, selected by an explicit, deduped list of Capability and/or
  Gate IDs (stable-sorted before serialization), whose canonical
  serialization is what `registry_digest` actually hashes, as opposed to the
  whole Registry file.
- Registry discovery contract (REQ-005) — the package-relative,
  version-verified lookup procedure (packaged plugin-relative path, then
  monorepo-relative fallback, then fail-closed) every Registry-reading
  script uses to locate `contracts/capability-registry.json`/`.schema.json`,
  whether running inside this monorepo or inside a standalone-installed
  `sdd-quality-loop` plugin.

## Roles and Permissions

- Agent (this spec's author): authors all four Phase-1 spec-package files
  (`investigation.md`, `requirements.md`, `design.md`,
  `acceptance-tests.md`; `tasks.md`/`traceability.md` are Phase 2, Non-goals)
  under `specs/epic-190-a2-capability-registry/` directly (unprotected).
  Does not touch `plugins/`, `scripts/`, `contracts/`, `tests/`, `.github/`,
  or `docs/` in this commit (Non-goals, AC-034). Does not write "Approved" in
  any Status/approval field (orchestrator instruction — Spec-Review-Status
  stays `Pending`, for a human to change).
- Human maintainer: reviews and approves this spec (changes
  `Spec-Review-Status` to `Passed`/`Approved` only after their own review);
  at the implementation phase, runs the `cp` step for every protected-file
  change tasks.md schedules (guard-invariants registration additions,
  `.github/workflows/test.yml` registration), verifying each copied file's
  SHA-256 against its `MANIFEST.sha256` entry before the corresponding task
  can be marked Done; resolves OQ-001 and OQ-004 either by direct instruction
  or by a follow-up ADR (OQ-002/OQ-003 are already resolved, orchestrator
  ruling 2026-07-22).
- CI (future, implementation phase): runs the projection generator's
  `--check` mode and the new `tests/*.tests.sh`/`.tests.ps1` pairs once a
  human has applied the human-copy-staged `.github/workflows/test.yml`
  registration.

## Main Workflows

1. A Registry maintainer edits `contracts/capability-registry.json` to add or
   change a Capability (trigger, required/conditional Facets, Gate
   references, `lite_policy`, `delivery_strategy`) or a Gate
   (`id`/`stage`/`blocking`/`implementation_ref`).
2. The Registry validator (REQ-003) runs against the edited file: schema
   validation, Gate-ID uniqueness, stage-completeness for
   `stage: implementation` Gates, unregistered-script detection (Gate
   implementation identity), Pack-gate-definition absence, referential
   integrity, Provider-name contamination, and lite-upgrade-reason-catalog
   conformance. Any failure blocks the change.
3. The `registry_digest` generator (REQ-004) computes a sha256 digest over a
   canonical-JSON serialization of a caller-specified Registry fragment
   (`--capability-ids`/`--gate-ids`/`--whole`, stable-sorted and deduped),
   calling Epic A1's canonicalizer for the JCS step.
4. The projection generator (REQ-005) regenerates
   `plugins/sdd-quality-loop/scripts/generated/gate-capabilities.json` from
   the validated Registry, heading it with a top-level `_generated` metadata
   object; CI's `--check` mode fails the build if the committed projection
   has drifted from what regeneration would produce.
5. `sdd-quality-loop`'s Implementation Gate reads the generated
   `gate-capabilities.json` (never the authoring-format Registry directly)
   to decide which `stage: implementation` Gates apply to a given Feature's
   triggered Capabilities; both it and Epic A5's Resolver locate the
   Registry (or its generated projection) via REQ-005's package-relative
   discovery contract, whether running in-repo or as a standalone-installed
   plugin.
6. Epic A5's Resolver calls the Predicate DSL evaluator (REQ-002) to resolve
   `trigger` and `conditional_facets[].when` against a Feature's affected
   components, and calls the `registry_digest` generator (REQ-004) to bind
   the Registry fragment it consumed into the Facet Manifest's
   `context_binding` (Epic A4/A5 work, out of this spec's scope, but this is
   the intended consumption path).
