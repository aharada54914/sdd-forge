# Requirements: epic-190-a2-capability-registry

Spec-Review-Status: Pending
Source Issues: https://github.com/aharada54914/sdd-forge/issues/190,
https://github.com/aharada54914/sdd-forge/issues/187
Epic: https://github.com/aharada54914/sdd-forge/issues/190 (Epic A2 —
Capability Registry, part of the AI-DLC Foundation tracked by #187)
Investigation: specs/epic-190-a2-capability-registry/investigation.md
(INV-001..INV-014, OQ-001..OQ-004)

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
uniqueness, stage-completeness, unregistered-script detection, Pack-gate-
definition absence, Provider-name contamination), (4) a `registry_digest`
generation primitive built on Epic A1's canonicalizer (not reimplemented,
INV-006), and (5) protected, generated projection files for
`sdd-quality-loop` to consume at gate-check time, following the
guard-invariants precedent exactly (INV-009). This spec covers the **spec
phase only**: no plugin code, script, or generated artifact is created by
this commit; `tasks.md` schedules that work for the implementation phase.

## Dependencies

- **Epic A1 (Project Context) — hard dependency.** This spec's
  `registry_digest` generation step (REQ-004) calls Epic A1's canonicalizer
  (YAML 1.2 core-schema parse + RFC 8785/JCS canonical JSON + NFC string
  normalization, Python single implementation + sh/ps1/js wrappers —
  decision v2 §18.3, INV-006) as an external dependency; it is not
  reimplemented here. REQ-004's design and tasks are written against the
  canonicalizer's documented contract (canonical-JSON-in, sha256-out); if
  Epic A1 lands with a materially different canonicalizer interface,
  REQ-004's implementation task must be revisited before Epic A2's own
  implementation phase begins. The Predicate DSL's field allowlist (REQ-002)
  also depends on Epic A1 adding `distribution_channels` and
  `data_classification` as first-class Project Context schema fields
  (ADR-0020 item 5); until Epic A1 lands those fields, the evaluator's
  allowlist can be implemented and tested against fixture data but cannot be
  exercised against a real Project Context.
- **Epic A5 (Capability Resolver) — downstream consumer, not a blocker.**
  Epic A5 is the actual consumer of the Predicate DSL evaluator (REQ-002) and
  the `registry_digest` primitive (REQ-004); it binds them into a Facet
  Manifest's `context_binding` (ADR-0021). Epic A2 ships these as
  independently testable, standalone primitives so Epic A5 does not need to
  build them itself.
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
  independently — defeating ADR-0021's staleness-binding guarantee.
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
  is an open string array, not a closed enum (INV-007, OQ-001).
  `minimum_enforcement`, when present, is the literal string `required`
  (decision v2 §10: "Registry 側は `minimum_enforcement: required` を持てる" —
  no other value is defined). `delivery_strategy.kind` is one of
  `developer-tooling`, `cli-library`, `desktop`, `cloud-service`,
  `durable-workflow` (OQ-003: inferred from decision v2 §17's Pack rollout
  order, flagged as an inference, not a directly-stated enum). `trigger` is
  a single Predicate DSL expression (REQ-002); "conditions" from decision
  v2's field list is not a separate schema field (OQ-002).
- REQ-002 (Predicate DSL evaluator): Design a deterministic evaluator
  (Python master + sh/ps1 wrappers, per the `sdd-hook-guard` pattern —
  INV-014) implementing ADR-0020 in full: logical operators `all` (empty →
  `true`) / `any` (empty → `false`) / `not` (unary, no short-circuit,
  every predicate evaluated and recorded); comparison operators `equals` /
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
  `data_classification` (ADR-0020 item 5; the latter two fields are an Epic
  A1 dependency per this spec's Dependencies section). The evaluator must
  emit an Evidence record for every predicate it evaluates (operator, path,
  matched value or WARN reason, result), consumable by Epic A5's Resolver
  Evidence output.
- REQ-003 (Registry validation): Design a validation script/check-suite (same
  Python-master + sh/ps1-wrapper convention) enforcing: (a) **Gate ID
  uniqueness** across the top-level `gates` array; (b) **stage-completeness**
  — every `gates[]` entry with `stage: implementation` carries a non-empty
  `implementation_ref` pointing to an existing script path (`artifact`/
  `promotion`-stage entries are exempt, per ADR-0017 item 1); (c)
  **unregistered-script detection** — every script matching the configured
  gate-script naming convention under the configured scan directories is
  referenced by exactly one `gates[].implementation_ref` (OQ-004: this
  bidirectional check is this spec's own design proposal, not directly
  stated in decision v2/ADRs, and is flagged as such in design.md); (d)
  **no Pack-owned Gate definitions** — no file matching
  `capability-packs/*/gates.yaml` (or a plugin-nested equivalent) exists
  anywhere in the repository (INV-002, a forward-guard since no Pack
  exists yet); (e) **no missing `stage`** on any `gates[]` entry (schema
  already requires this; the validator re-asserts it as defense-in-depth,
  matching decision v2 §13's own redundant listing of "stage欠落なし"); (f)
  **referential integrity** — every `capabilities[].gate_ids` entry resolves
  to a defined `gates[].id`; (g) **Provider-name contamination** — every
  string-valued field in `contracts/capability-registry.json` is scanned
  against a maintained, allowlist-based term list (design.md proposes
  `plugins/sdd-capability/references/provider-terms.json`) of known provider-
  identifying tokens (e.g. `azure`, `aws`, `gcp`, `durable-functions`,
  `step-functions`, `app-store`, `google-play`); any match fails validation
  (ADR-0018's boundary, INV-008 — this is the first automated
  implementation of that boundary rule in this repository).
- REQ-004 (`registry_digest` generation): Design a script that computes a
  sha256 digest over a canonical-JSON serialization (RFC 8785/JCS, NFC
  string normalization — decision v2 §18.3) of either the whole Registry or
  a named subset of it ("a Registry fragment", per ADR-0021's own phrasing —
  the fragment selection itself is Epic A5's Resolver concern, not Epic
  A2's; this script accepts an explicit list of Capability/Gate IDs as its
  fragment-selection input and is silent about how Epic A5 chooses that
  list). The script calls Epic A1's canonicalizer for the canonicalization
  step (Dependencies section) rather than reimplementing JCS. Because
  `contracts/capability-registry.json` is authored directly in JSON (REQ-001;
  INV-010), the YAML-1.2-parse precondition in decision v2 §18.3 does not
  apply to this input — only the canonical-JSON + NFC + sha256 steps do; this
  narrowing is stated explicitly in design.md, not silently assumed.
- REQ-005 (projection generation and protection): Design a generator
  (mirroring `generate-guard-invariants.py` exactly — INV-009) that reads
  `contracts/capability-registry.json` and `contracts/capability-registry.schema.json`
  and writes `plugins/sdd-quality-loop/scripts/generated/gate-capabilities.json`,
  headed with the same `sha256=<hex>` / "This file is generated. Do not edit."
  comment convention. The generator supports a `--check` mode (no write,
  drift detection, wired into `.github/workflows/test.yml` per the
  `generate-guard-invariants.py --check` precedent — INV-009). The generated
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
  same evaluator/allowlist); the Registry validator (Gate ID duplication,
  missing `implementation_ref` on a `stage: implementation` Gate, an
  unregistered gate-shaped script, a `capability-packs/*/gates.yaml`-shaped
  fixture file, a dangling `gate_ids` reference, a Provider-name-contaminated
  fixture); `registry_digest` determinism (dual-runtime hash equality via a
  fixed fixture, per decision v2 §18.3's own requirement); and the projection
  generator's `--check` mode (clean pass, and a mutated-source negative case
  that must fail `--check`). Every new suite is registered directly in
  `tests/run-all.sh`/`.ps1` (unprotected, INV-014) and staged for
  `.github/workflows/test.yml` registration via human-copy (protected,
  INV-009/INV-014).

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
- Freezing a closed enum for `lite_policy.upgrade_reasons` (OQ-001) or for
  `delivery_strategy.kind` beyond the four values inferred in REQ-001
  (OQ-003) — both are left open pending a human decision or a later ADR.
- Implementing the Artifact Gate or Promotion Gate stages, or their check
  inventories — both remain reserved enum values with vocabulary deferred to
  `sdd-delivery` (ADR-0017 items 3-4); this spec's `stage` enum reserves the
  values but implements no behavior for them.
- Writing any actual plugin code, contract file, generated projection, or
  test file — this is the spec phase; `tasks.md` schedules that work for the
  implementation phase and no file under `plugins/`, `scripts/`, `contracts/`,
  `tests/`, or `.github/` is created or modified by this commit.
- Modifying `AGENTS.md`'s "Active Spec Directories" or
  `specs/workflow-state-registry.json` in this commit — that registration is
  isolated to its own, separate commit (orchestrator instruction, to
  minimize conflicts with parallel Epic A1/A3 work).

## User Stories

As a Registry maintainer, I can add a new Capability entry with a `trigger`,
required/conditional Facets, a Gate reference list, a `lite_policy`, and a
`delivery_strategy.kind`, and know the validator will catch a duplicate Gate
ID, a missing implementation for a `stage: implementation` Gate, or a leaked
provider name before the Registry is trusted as a source of truth. As an
Epic A5 implementer, I call the Predicate DSL evaluator with a `trigger` or
`conditional_facets[].when` expression and an affected component's
properties, and get back a boolean plus an Evidence record I can fold
directly into Resolver Evidence, without needing to re-derive ADR-0020's
fail-closed/`exists`-exception semantics myself. As a CI maintainer, I run
the projection generator's `--check` mode and know immediately whether
`gate-capabilities.json` has drifted from `contracts/capability-registry.json`,
without a human needing to eyeball a diff. As a human reviewer, I see every
place this spec had to make a judgment call the source documents left
ambiguous (OQ-001..OQ-004) called out explicitly, rather than silently
resolved.

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
- AC-003: Every `capabilities[]` entry's `gate_ids` array contains only IDs
  present in the top-level `gates[]` array (schema-level `$ref`/enum
  constraint, cross-checked again by REQ-003(f)'s validator). (REQ-001)
- AC-004: `lite_policy.upgrade_reasons` is typed as an array of non-empty
  strings (open vocabulary), not a closed enum; `lite_policy.eligible` is
  typed boolean and required whenever `lite_policy` is present. (REQ-001,
  OQ-001)
- AC-005: `delivery_strategy.kind` is constrained to
  `{developer-tooling, cli-library, desktop, cloud-service,
  durable-workflow}`; design.md documents this enum as an inference from
  decision v2 §17, not a directly-quoted requirement. (REQ-001, OQ-003)
- AC-006: The DSL evaluator design specifies, for each of
  `equals`/`not_equals`/`contains`/`in`: missing path → `false` + `WARN`;
  `null` value → `false` + `WARN`; type mismatch → `false` + `WARN`; no
  operator ever raises an exception for these three cases. (REQ-002)
- AC-007: The DSL evaluator design specifies `exists` returns `true` when the
  path is present regardless of the value (including `null`), and `false` +
  `WARN` when the path is absent; type is never inspected for `exists`.
  (REQ-002)
- AC-008: The DSL evaluator design specifies `all` of an empty predicate list
  evaluates to `true`, `any` of an empty predicate list evaluates to `false`,
  and neither `all` nor `any` short-circuits — every child predicate's result
  is recorded in Evidence regardless of whether it could change the outcome.
  (REQ-002)
- AC-009: `trigger` and `conditional_facets[].when` are specified to share
  exactly one evaluator implementation and exactly one field allowlist — the
  design contains no second, separate condition-evaluation code path.
  (REQ-002)
- AC-010: The field allowlist enumerated in design.md matches ADR-0020 item 5
  exactly (8 dotted paths), with `distribution_channels`/`data_classification`
  flagged as an Epic A1 schema dependency. (REQ-002)
- AC-011: The Registry validator design specifies a Gate-ID-uniqueness check
  over the top-level `gates[]` array (not per-Capability). (REQ-003)
- AC-012: The Registry validator design specifies that every `stage:
  implementation` Gate must resolve `implementation_ref` to an existing file
  path, and that `stage: artifact`/`promotion` Gates are exempt from this
  check (ADR-0017 item 1). (REQ-003)
- AC-013: The Registry validator design specifies a repository-wide check
  that no `capability-packs/*/gates.yaml`-shaped file exists. (REQ-003)
- AC-014: The Registry validator design specifies a Provider-name-
  contamination scan against a maintained term allowlist, covering every
  string-valued field in the Registry instance file, with the check
  documented as the first automated implementation of ADR-0018's boundary
  rule in this repository (not a pre-existing check being extended).
  (REQ-003)
- AC-015: The Registry validator design specifies a referential-integrity
  check: every `capabilities[].gate_ids` entry must resolve to a defined
  `gates[].id`, and the design records this as validator-level defense-in-
  depth in addition to (not instead of) the schema-level constraint (AC-003).
  (REQ-003)
- AC-016: The `registry_digest` generator design specifies it calls into Epic
  A1's canonicalizer rather than reimplementing RFC 8785 (JCS) or YAML 1.2
  parsing, and explicitly states the YAML-1.2-parse step does not apply to
  this JSON-authored input. (REQ-004)
- AC-017: The `registry_digest` generator design accepts an explicit
  Capability/Gate ID list as its fragment-selection input, and documents that
  fragment-selection policy itself is Epic A5's concern, not Epic A2's.
  (REQ-004)
- AC-018: The projection generator design specifies output header format
  byte-for-byte matching guard-invariants' convention
  (`# Generated from <source>; schema_version=<n>; sha256=<hex>` /
  `# This file is generated. Do not edit.`), and a `--check` mode with the
  same no-write, drift-detecting contract as
  `generate-guard-invariants.py --check`. (REQ-005)
- AC-019: tasks.md schedules the protected-file registration (adding the new
  paths to `guard-invariants.json`'s protected-suffix and human-copy-target
  lists, and to `.github/workflows/test.yml`) as a task carried out via
  `specs/epic-190-a2-capability-registry/human-copy/` +
  a `MANIFEST.sha256`, never as a direct edit to a protected file. (REQ-005)
- AC-020: tasks.md schedules `tests/*.tests.sh`/`.tests.ps1` pairs for every
  REQ-002..REQ-005 deliverable, each pair covering at minimum the cases
  listed in REQ-006, and each pair's `tests/run-all.sh`/`.ps1` registration
  as a direct (unprotected) edit while its `.github/workflows/test.yml`
  registration is staged via human-copy. (REQ-006)
- AC-021: No file under `plugins/`, `scripts/`, `contracts/`, `tests/`, or
  `.github/` is created or modified by this commit; `git status`/`git diff`
  at spec-authoring time shows changes confined to
  `specs/epic-190-a2-capability-registry/`. (Non-goals)
- AC-022: Every open question this spec could not resolve from decision v2 or
  an ADR alone (OQ-001..OQ-004) is recorded in investigation.md and
  cross-referenced from the relevant REQ/AC, rather than resolved silently.
  (User Stories, Dependencies)

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
- `implementation_ref` (REQ-001, REQ-003; this spec's own proposal, OQ-004)
  — a file path on a `gates[]` entry pointing at the script that implements
  a `stage: implementation` Gate's check; required for `implementation`-stage
  entries, meaningless (and not required) for reserved `artifact`/`promotion`
  entries.
- `registry_digest` (REQ-004; ADR-0021) — a sha256 digest, computed over a
  canonical-JSON (RFC 8785/JCS) serialization of a named Registry fragment,
  used by Epic A4/A5 to bind Facet Manifest staleness to Registry content
  changes; the digest **primitive** is Epic A2's deliverable, the fragment-
  selection policy and the `context_binding.registry_digest` binding itself
  are Epic A4/A5's.
- `lite_policy` (REQ-001; ADR-0022) — per-Capability lite-track eligibility:
  `eligible` (boolean) and `upgrade_reasons` (open string array, OQ-001).
- `delivery_strategy.kind` (REQ-001; OQ-003) — a classification tag on each
  Capability describing which future `sdd-delivery` pipeline shape applies;
  recorded now (cheap, knowable at Registry-authoring time) while the
  Artifact/Promotion Gate check inventories themselves stay deferred
  (ADR-0017 items 3-4).
- `Registry fragment` (REQ-004; ADR-0021's own phrasing) — a named subset of
  the Registry (an explicit list of Capability/Gate IDs) whose canonical
  serialization is what `registry_digest` actually hashes, as opposed to the
  whole Registry file.

## Roles and Permissions

- Agent (this spec's author): authors all six spec-package files under
  `specs/epic-190-a2-capability-registry/` directly (unprotected). Does not
  touch `plugins/`, `scripts/`, `contracts/`, `tests/`, `.github/`, or
  `docs/` in this commit (Non-goals, AC-021). Does not write "Approved" in
  any Status/approval field (orchestrator instruction — Spec-Review-Status
  stays `Pending`, for a human to change).
- Human maintainer: reviews and approves this spec (changes
  `Spec-Review-Status` to `Passed`/`Approved` only after their own review);
  at the implementation phase, runs the `cp` step for every protected-file
  change tasks.md schedules (guard-invariants registration additions,
  `.github/workflows/test.yml` registration), verifying each copied file's
  SHA-256 against its `MANIFEST.sha256` entry before the corresponding task
  can be marked Done; resolves OQ-001..OQ-004 either by direct instruction or
  by a follow-up ADR.
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
   `stage: implementation` Gates, unregistered-script detection, Pack-gate-
   definition absence, referential integrity, and Provider-name
   contamination. Any failure blocks the change.
3. The `registry_digest` generator (REQ-004) computes a sha256 digest over a
   canonical-JSON serialization of a caller-specified Registry fragment,
   calling Epic A1's canonicalizer for the JCS step.
4. The projection generator (REQ-005) regenerates
   `plugins/sdd-quality-loop/scripts/generated/gate-capabilities.json` from
   the validated Registry, heading it with a `sha256=<hex>` / "Do not edit"
   comment; CI's `--check` mode fails the build if the committed projection
   has drifted from what regeneration would produce.
5. `sdd-quality-loop`'s Implementation Gate reads the generated
   `gate-capabilities.json` (never the authoring-format Registry directly)
   to decide which `stage: implementation` Gates apply to a given Feature's
   triggered Capabilities.
6. Epic A5's Resolver calls the Predicate DSL evaluator (REQ-002) to resolve
   `trigger` and `conditional_facets[].when` against a Feature's affected
   components, and calls the `registry_digest` generator (REQ-004) to bind
   the Registry fragment it consumed into the Facet Manifest's
   `context_binding` (Epic A4/A5 work, out of this spec's scope, but this is
   the intended consumption path).
