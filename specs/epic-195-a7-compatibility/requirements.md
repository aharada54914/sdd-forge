# Requirements: epic-195-a7-compatibility

Spec-Review-Status: Pending
Source Issue: https://github.com/aharada54914/sdd-forge/issues/195 (Epic A7,
tracked under #187 / Epic A0 #188)

## Overview

Epic A7 ("Compatibility") specifies the three-part compatibility test
suite required by `docs/ai-dlc-foundation-decision-v2.md` §4 (Q3) and §19:
a **byte-identical deterministic test**, a **structural compatibility
test**, and an **orchestration event test**. Their combined purpose is to
prove that adopting the Multi-target AI-DLC capability machinery (Epics
A1–A6: Project Context, Capability Registry, Component Path Ownership,
Facet Manifest, Capability Resolver, Lite integration) never changes
observable behavior for a project that has not opted in
(`project-context.yaml` absent — INV-009), and that once a project does
opt in, every deviation from legacy behavior is either byte-identical
(unaffected code paths) or event-identical (an explicitly modeled,
inventory-registered capability event), never silent drift. Per §4.3 and
§19, the orchestration-event kind is built as capability-event additions
to the already-existing `loop-inventory/v1` registry, shared loop driver,
`loop-consistency`/`loop-escalation` suites, and `emit-run-record.sh`
(INV-001 through INV-006) — this epic registers no ninth loop and creates
no parallel test harness. Compatibility itself is judged against a
versioned canonical event-trace schema and a governed, pre-capability
golden baseline this package fixes (REQ-003, REQ-006) — not against ad
hoc, suite-local assertions — so a future implementer has exactly one
comparison oracle per compatibility claim, never several competing ones.

This package is Phase 1 (specification) only: `investigation.md`,
`requirements.md`, `design.md`, `acceptance-tests.md`. No test code,
fixtures, or registry edits are produced by this task; `tasks.md` and
`traceability.md` follow in a later phase once this package passes
`spec-review-loop`.

> Amendment note (2026-08-23): the Phase 1 framing in the paragraph
> above — and the matching Phase 2/3 deferral in Non-goals — described
> this package at its authoring time and is retained unchanged as a
> record of what was claimed then. This package has since been amended
> under a human-approved frozen-document amendment. The dated verbatim
> approval record, the full amendment commit hashes, the SHA-256 of each
> amended document as of each amendment commit, and commit/SHA-256
> citations for every later-phase artifact this package references
> (`tasks.md`, `traceability.md`/`traceability.json`, and the T-005/
> T-006 `assert_terminal` re-baseline AC-009's provenance note names)
> are recorded in `investigation.md` under `## Amendment Re-Review
> Context`. That entry's citations are the authoritative framing; the
> paragraphs above describe authoring time, not the present state.

## Target Users

- **sdd-forge maintainers** shipping Epics A1–A6, who need a compatibility
  gate that fails loudly if a capability-machinery change silently alters
  legacy (`project-context.yaml`-absent) behavior.
- **A future CI run** (`.github/workflows/test.yml`) that must be able to
  run these compatibility suites unattended, on the existing three-OS
  matrix, without a live Project Context anywhere in the fixture tree
  except where a fixture deliberately creates one.
- **Epic A1/A2/A3/A5 implementers**, who need a fixed, reviewable contract
  for exactly which fields/events their own work must add to the shared
  registry, driver, and run-record — so this epic's tests do not become a
  moving target each of those epics has to renegotiate.

## Problems

- Decision doc §4 requires three named compatibility test kinds, but none
  exists in the repository today; the "現行" (current) legacy behavior
  those tests must pin has no committed golden baseline (INV-017).
- Without a formal fixture matrix, "Project Context absent" is the only
  state anyone has tested (implicitly, by every existing suite); the other
  seven valid rows decision doc §6 names — absent-with-lite-marker,
  present-lite-advisory, present-lite-required, present-advisory,
  present-required, present-facet-hybrid-required,
  present-facet-native-required (INV-011) — have no test surface at all,
  on `main` or on any unmerged Epic A branch.
- Epic A7 is being specified while Epic A1 (Project Context), A2
  (Registry), A3 (Path Ownership), and A5 (Resolver) are still unmerged
  (INV-013–INV-016); a naive orchestration-event spec would either wait
  for all four to land (blocking Epic A0's stated implementation order,
  decision doc §20: "最初の実装単位は A0〜A3") or assert against code that
  does not exist yet. Neither is acceptable; the spec must be written so
  its Phase-2/3 tasks can implement the "Context absent" assertions
  immediately and the "Context present" assertions incrementally as each
  upstream epic lands.
- `tests/loop-inventory.tests.sh` hardcodes the loop count at exactly 8
  (INV-002); any future task that adds a capability event without reading
  this requirement first risks either breaking that hardcoded check by
  registering a new loop kind, or silently under-specifying the extension
  by not updating it at all.
- Neither the shared loop driver nor either loop suite collects an
  ordered, multi-kind event trace today (INV-021); without a versioned
  canonical schema fixing every required event kind's own producer,
  ordering rule, and value-normalization, "event-identical" has no
  comparison oracle to test against, and REQ-003's six named observables
  risk collapsing into whichever ad hoc assertion a Phase 2 implementer
  happens to write first.
- A `SKIP` degradation rule that only checks the forward direction
  (unmerged dependency → `SKIP`) is fail-open by construction (INV-023):
  nothing catches a `SKIP` line surviving after its dependency has
  merged, an unrecognized `SKIP` message, or a cited upstream contract
  that has drifted from what this package records.

## Goals

- **REQ-001** (Byte-identical deterministic test): specify a compatibility
  test kind that proves, under a fixed, normalized fixture and a
  `project-context.yaml`-absent repository state, that deterministic
  script output, exit codes, stdout/stderr, template-copy results, schema
  validator behavior, the "resolver not called" legacy code path,
  generated directory listings, plugin manifests, and install/uninstall
  results are byte-for-byte identical to a recorded golden baseline
  (decision doc §4.1). It extends `tests/install.tests.sh` /
  `tests/uninstall.tests.sh` (INV-007) rather than duplicating their
  fixture harness. REQ-001's own target list is decomposed into a single
  canonical inventory table (design.md) so every target — including
  generated directory listings and plugin manifests — is paired 1:1 with
  an exact capture format and an AC/TEST (AC-038).
- **REQ-002** (Structural compatibility test): specify a test kind that
  compares LLM-generated specification artifacts structurally —
  required-file count, frontmatter, required headings, status fields,
  `REQ-NNN`/`AC-NNN` identifier format, absence of Facet-Manifest
  references in legacy mode, and absence of any capability-related
  generated file in legacy mode (decision doc §4.2) — through a
  deterministic, versioned recorded-response injection seam and a
  Markdown/frontmatter AST canonicalizer (AC-030), never a live model
  call in the gating suite (AC-031).
- **REQ-003** (Orchestration event test — capability-event extension over
  a versioned canonical trace schema): specify (a) a single, versioned
  canonical orchestration-event-trace schema (`compatibility-event-trace/v1`,
  design.md) naming, independently, each of the six event kinds decision
  doc §4.3 requires — skill-invocation order, review-loop presence,
  approval-checkpoint, quality-gate outcome, Done-transition, and
  skip/stop message — together with that kind's own producer, its
  ordering rule relative to the other kinds, and its value-normalization
  rule (AC-022–AC-027); (b) the exact additive fields/events this epic
  adds to `tests/loops/loop-inventory.json`, `tests/lib/loop-driver.sh`,
  `tests/loop-consistency.tests.sh`, `tests/loop-escalation.tests.sh`, and
  `emit-run-record.sh` (INV-001–INV-006, INV-021) to produce and compare
  that schema, without registering a new loop `id` and without creating a
  new `tests/*.tests.sh` file — capability events extend the existing
  `quality-gate` loop entry because a capability event has no independent
  cap/round/terminal lifecycle of its own; it is semantically an outcome
  of the already-existing quality-gate loop, never a ninth loop (this is
  the design's own basis for the "no new loop `id`" decision, never
  `loop-inventory.tests.sh`'s current `length == 8` assertion value,
  INV-002); and (c) which of the two review-loop suites owns which event
  kind: `tests/loop-escalation.tests.sh` owns the quality-gate-outcome
  event (Capability Coverage is a quality-gate common check item,
  decision doc §3.1, already driven end-to-end by that suite, INV-005 —
  AC-010/AC-025), while `tests/loop-consistency.tests.sh` owns the
  skill-invocation-order, review-loop-presence, and approval-checkpoint
  events (that suite already drives all four review rounds end-to-end via
  the shared driver, INV-005 — AC-032) — both suites compare against the
  identical canonical schema from (a), so this remains one oracle, not
  two competing ones.
- **REQ-004** (Formal compatibility requirement decomposition): decompose
  decision doc §4's exact requirement text — "Project Context不在時、決定
  論的成果物と制御フローはbyte-identicalまたはevent-identicalであり、LLM
  生成仕様は既存のschema・構造・必須見出しと互換であること" — into
  independently verifiable acceptance criteria, so the requirement itself
  is testable rather than only its three named test kinds. Clause (b)'s
  "registered event vocabulary" is REQ-003's own canonical trace schema;
  an exclusive observable×fixture-state judgment table (design.md) fixes
  which observable is byte-compared and which is event-compared, so no
  observable is ever eligible for both simultaneously (AC-029).
- **REQ-005** (Fixture matrix + cross-runtime pairing): specify a fixture
  matrix covering every valid row of decision doc §6's combination matrix
  — the eight rows that are not one of §6's two explicitly-marked `無効な
  組合せ` (invalid-combination) rows: (F1) Context absent, default track
  (`full`/`legacy-seven-layer`/non-active); (F2) Context absent,
  `AGENTS.md` `spec_profile: lite` marker
  (`lite`/`lite-three-file`/non-active); (F3) Context present,
  `full`/`legacy-seven-layer`/`advisory`; (F4) Context present,
  `full`/`legacy-seven-layer`/`required`; (F5) Context present,
  `lite`/`lite-three-file`/`advisory`; (F6) Context present,
  `lite`/`lite-three-file`/`required`; (F7) Context present,
  `full`/`facet-hybrid`/`required`; (F8) Context present,
  `full`/`facet-native`/`required` (INV-011; decision doc §6). F1–F4 are
  this package's own fixture-builder targets (AC-014); F5/F6 are named
  `SKIP` until Epic A1's schema and Epic A6's Lite integration both merge
  (REQ-007); F7/F8 additionally require Epic A4/A5 output and are
  recorded `N/A` — no Foundation epic (A0–A9, decision doc §19) produces
  `facet-native` at all, and `facet-hybrid` is reached only after
  `facet-hybrid` "has an operational track record" (ADR-0016 Decision
  item 2), i.e. after this epic's own Phase 3 — so F7/F8 are documented
  rows carrying a stated non-coverage rationale, never silently omitted
  cells (AC-028). Each of the F3/F4 rows additionally requires a
  `PROJECT_CONTEXT_INVALID` negative variant (F3-invalid, F4-invalid —
  Edge Cases, below; AC-019–AC-021), resolving OQ-002. The Context-absent
  rows (F1/F2) are additionally decomposed into a CLI
  `none`/`--full`/`--lite` × `AGENTS.md`-marker `present`/`absent`
  submatrix (six cells) exercising the unchanged compatibility-fallback
  priority order CLI flag → `AGENTS.md` marker → default (ADR-0023 item
  2; `PLUGIN-CONTRACTS.md:63-66`), so F1/F2 are each one cell of that
  submatrix (no-flag/no-marker and no-flag/marker respectively), not the
  submatrix's full coverage by themselves. Every REQ-001 through REQ-003
  test consumes the relevant matrix cells (AC-028 fixes the exhaustive
  cell-to-AC/TEST/SKIP/N-A mapping); each new/extended suite ships as a
  `.sh`/`.ps1` pair per this repository's existing convention (INV-005,
  INV-007), registered in `tests/run-all.sh`, `tests/run-all.ps1`, and
  `.github/workflows/test.yml` (INV-005 pattern).
- **REQ-006** (Golden baseline governance): specify (a) the golden
  baseline's exact capture script name/path/location, its manifest
  format, and the exact command that runs it (API / Contract Plan,
  design.md); (b) that the baseline is captured once against a **fixed,
  named pre-capability commit** — the merge-base commit that predates
  Epic A1's own first merge to `main`, recorded by exact SHA in the
  manifest (AC-018) — never "whatever `main` is when Phase 2 begins"
  (INV-022), so a legacy regression an already-merged upstream epic
  introduces before this epic's own Phase 2 starts can never be silently
  canonized as the new baseline; and (c) a two-stage update procedure
  that structurally separates a locally-regenerable **candidate**
  baseline (unreviewed, gitignored, produced by the same script's
  `--write-candidate` mode) from the committed **canonical** one: a
  candidate is promoted to canonical only via a dedicated pull request
  whose diff a human maintainer reviews and approves (Roles and
  Permissions; Security Boundaries B1) — the default (no-flag) invocation
  of the capture script is read-only (diff-against-canonical-only) in
  every context including CI, and CI is never the actor that writes the
  canonical baseline (Roles and Permissions).
- **REQ-007** (Forward-compatibility / staged activation): specify (a)
  how every "Context present" assertion, and every Context-absent
  assertion whose own target process does not exist yet (e.g. AC-004's
  Resolver-absence spy, meaningful only once Epic A5's Resolver process
  exists to be absent-checked against, INV-015), behaves before its
  upstream dependency (Epic A1 Project Context, Epic A2 Registry, Epic A3
  path ownership, Epic A4 Facet Manifest, Epic A5 Resolver, Epic A6 Lite
  integration — INV-023) is merged to `main` — a named, auditable `SKIP`,
  never a silent pass and never a hard failure that blocks Epic A0's own
  stated build order (decision doc §20); and (b) a single allowlist
  manifest (design.md) mapping every such assertion to
  {epic/issue, expected-contract fingerprint, machine-detectable
  activation condition} that the suite reads to emit each `SKIP` line, so
  that (i) a `SKIP` for an assertion whose activation condition is
  already true (its dependency has merged) is a hard failure, not a
  silent pass; (ii) any `SKIP`-shaped output not present in the allowlist
  is a hard failure (unknown SKIP); and (iii) an allowlisted assertion
  whose recorded contract fingerprint no longer matches its cited
  upstream epic's current spec is a hard failure (fingerprint drift) —
  closing the fail-open direction INV-023 identifies.

## Non-goals

- Implementing Epic A1 (`project-context.yaml`), Epic A2 (Capability
  Registry), Epic A3 (path ownership), Epic A4 (Facet Manifest), Epic A5
  (Capability Resolver), or Epic A6 (Lite integration) themselves. This
  epic tests compatibility around their eventual presence; it does not
  build them.
- Authoring the actual test code, fixtures, or registry/driver/run-record
  edits. Those are Phase 2/3 deliverables of a later task once this
  package passes `spec-review-loop`/`impl-review-loop`. (See the
  Overview's dated amendment note and `investigation.md` `## Amendment
  Re-Review Context`: this deferral described authoring time; the
  later-phase deliverables it deferred are cited there by commit and
  SHA-256.)
- Registering a new `loop-inventory/v1` loop `id` (a ninth loop). Per
  decision doc §4.3/§19 and INV-002, capability events extend existing
  entries; if a genuinely new loop-shaped surface (its own cap/round/
  terminal state) is discovered during Phase 2 design, that is an ADR-0010
  vocabulary-revision decision outside this epic's scope, recorded as an
  Open Question below.
- Re-specifying Epic A5's own deferred `resolve-project-context-caller-contract`
  suite (INV-016) in full, or its remaining fixture assertions this
  package does not adopt. This package specifies exactly the three
  fixture-level assertions A5's own `design.md` item 10(a)/(b)/(c) already
  fixes — anchor-fingerprint drift, Context-absent Resolver-non-invocation,
  and Block-surfaces-not-fallback — as `TEST` cases inside this epic's own
  existing suite once Epic A5's caller insertion point is implemented
  (AC-036, AC-004/AC-021, AC-037; OQ-001, resolved), so Phase 2/3 has no
  remaining suite-placement ambiguity to guess at.
- Any change to `plugins/**`, `scripts/**`, `.github/**`, `tests/**`,
  `contracts/**`, or `docs/**` in this task.

## User Stories

As a maintainer merging Epic A1's Project Context schema, I can run a
named compatibility suite before merging and know, with byte-level
certainty, that every project without a Project Context still behaves
exactly as it did before Epic A1 existed. As a maintainer merging Epic A5's
Resolver, I can run the orchestration-event suite and see, in a reviewable
event trace, that the Resolver is invoked exactly where the caller-
integration contract says it should be and nowhere else. As an Epic A2/A3/
A5 implementer, I can read this package's REQ-003 and design.md to know
exactly which fields to add to the shared registry/driver/run-record for
my own epic's capability events to become visible to this suite, without
guessing at an undocumented convention.

## Acceptance Criteria

- AC-001: A documented golden-baseline fixture set exists (REQ-006) whose
  capture procedure is fully scripted (no manual/undocumented steps) and
  whose location is the single, named path
  `specs/epic-195-a7-compatibility/verification/golden-baseline/`
  (design.md Design Decisions, resolving OQ-003 as a closed decision, not
  a recommendation).
- AC-002: The byte-identical test (REQ-001) fails, in at least one
  deliberately mutated fixture (a negative self-check, matching the
  pattern already established by `loop-inventory.tests.sh`'s own negative
  self-checks — INV-002), when a single byte of the golden baseline
  differs from a fresh run's output.
- AC-003: The byte-identical test's Context-absent fixture asserts, for at
  least one representative script per category named in decision doc
  §4.1 and in the REQ-001 canonical target inventory (design.md, AC-038)
  — deterministic script output, exit code, stdout/stderr, template copy,
  schema validator, install, uninstall, generated directory listing, and
  plugin manifest — that output is byte-for-byte identical across two
  independent invocations against the identical fixture and a fixed,
  normalized environment (`TZ`, `LC_ALL`, no ambient `SDD_*` environment
  variables). The same fixed environment/two-invocation check also covers
  the Context-absent CLI `none`/`--full`/`--lite` × marker submatrix
  (REQ-005): the CLI-flag → `AGENTS.md`-marker → default track-selection
  priority order itself is one of this AC's own byte-identical assertions
  (ADR-0023 item 2).
- AC-004: The byte-identical test's Context-absent fixture asserts that no
  process under test invokes a capability-machinery subprocess (Resolver,
  Registry discovery, Facet generation) — the "resolver を呼ばない旧コー
  ドパス" target of decision doc §4.1 — via a spy/absence check, not by
  merely observing that the (currently nonexistent) subprocess happens not
  to exist. This is the identical spy-harness fixture Epic A5's own
  `design.md` item 10(b) already fixes for
  `resolve-project-context-caller-contract` (INV-016); this package adopts
  it directly rather than redesigning an equivalent check. It is a named
  `SKIP` entry in REQ-007's allowlist manifest (AC-034) until Epic A5
  lands, citing the tracking issue — the activation condition is "Epic A5
  merged to `main`," at which point a surviving `SKIP` here is a hard
  failure (AC-035).
- AC-005: The structural compatibility test (REQ-002) asserts, for a
  Context-absent LLM-generation fixture, that generated artifacts contain
  exactly the fixture's own **track-appropriate** file set — never a
  single, track-generic set, correcting an earlier draft's F2
  Compatibility Matrix row, which mistakenly cited this AC's `full`-track
  clause for the `lite` track (design.md, "Compatibility Matrix"):
  - **`full`-track clause (F1)**: exactly the legacy-seven-layer file set
    (INV-018) — no `facet-manifest.yaml`, no `capability-summary.yaml`,
    no per-Facet file — every generated Markdown file's required headings
    and status field names matching the existing templates under
    `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/`
    unchanged.
  - **`lite`-track clause (F2)**: exactly the three-file
    `requirements.md`/`design.md`/`tasks.md` set `plugins/sdd-lite/skills/lite-spec/SKILL.md:58-61`
    already fixes as the LITE track's own current generation output
    (INV-024) — the identical no-Facet/no-capability-file assertion,
    every generated file's required headings and status field names
    matching `plugins/sdd-lite/templates/requirements-lite.md`/
    `design-lite.md`/`tasks-lite.md` unchanged. This clause is assertable
    now (ASSERT, not `SKIP`): the LITE track's three-file generation is
    existing, unmerged-epic-independent behavior (INV-024;
    `PLUGIN-CONTRACTS.md:64-65,72` confirms LITE track selection routes
    generation to `lite-spec`, not `sdd-bootstrap-interviewer`), not a
    forward-looking capability-machinery target.

  Both clauses are independently checkable and neither is ever
  substituted for the other.
- AC-006: The structural compatibility test asserts `REQ-NNN`/`AC-NNN`
  identifier format (`^(REQ|AC)-[0-9]{3}$` or the exact pattern
  `design.md` fixes) is unchanged in Context-absent generation output.
- AC-007: The structural compatibility test asserts that a Context-present,
  `full`-track/legacy-seven-layer, `capability_enforcement: required`
  fixture (**F4 only** — never F6, the `lite`-track/lite-three-file
  counterpart design.md's own Compatibility Matrix scopes separately and
  gates on a different, compound Epic A1+A6 dependency, AC-043 below)'s
  generated artifacts contain no Facet reference in a project that
  legacy-mode-generates (cross-referencing INV-014's truthful-non-evaluation
  principle: presence of capability wiring, absence of Facet content, are
  two independently checkable claims) — a named `SKIP` entry in REQ-007's
  allowlist manifest (AC-034) until Epic A4's Facet Manifest exists,
  activation condition "Epic A4 merged to `main`" (REQ-007).
- AC-008: `tests/loops/loop-inventory.json`'s entry count remains exactly
  8 after this epic's Phase 2/3 implementation (INV-002); any new field
  this epic's design proposes is additive and optional, verified by a
  schema-validation check that a pre-epic copy of the registry (no new
  fields) still validates against the (still `loop-inventory/v1`, not
  bumped) schema.
- AC-009: The existing `quality-gate` `loop-inventory` entry (design.md
  Design Decisions) carries a new, additive `capability_applicability`
  field enumerating that entry's own capability-applicability outcomes
  (`disabled-legacy` / `advisory` / `required`, INV-014, scoped to the
  component-coverage Gate shape, AC-039). `assert_artifacts_schema`
  (`tests/lib/loop-driver.sh`, INV-004) remains fully unmodified;
  `assert_terminal`'s observable behaviour and signature (parameters,
  `expected`/`observed` comparison semantics, return contract) are
  locked byte-identical at the re-baselined function-body hashes
  TEST-009 (acceptance-tests.md) records, whose one sanctioned change
  is the `_loop_trace_emit done-transition:assert-terminal` call
  design.md's per-kind producer table — and AC-026 below — places
  inside `assert_terminal`. The new field itself is read by a new,
  dedicated `assert_capability_applicability` helper (API / Contract
  Plan, design.md), not by either existing function; this corrects a
  prior draft's inaccurate "existing helpers read it with no code
  change" framing (INV-002's caveat, above).
- AC-010: A new numbered case, `TEST-019`, is added to
  `tests/loop-escalation.tests.sh` (design.md Design Decisions) asserting
  that the quality-gate-outcome event kind (capability-applicability
  observation) a Context-present round drive produces is identical to the
  recorded golden-trace value for that fixture state's canonical
  `compatibility-event-trace/v1` value (REQ-003) — no new suite file is
  created (INV-005). A named `SKIP` entry in REQ-007's allowlist manifest
  (AC-034) until Epic A1's Project Context schema exists, activation
  condition "Epic A1 merged to `main`" (REQ-007). AC-032 is this
  criterion's `loop-consistency`-owned counterpart for the
  skill-invocation-order, review-loop-presence, and approval-checkpoint
  event kinds.
- AC-011: `emit-run-record.sh`'s no-flag output remains byte-identical to
  today's `sdd-run-record/v1` shape after this epic's Phase 2/3
  implementation (the same invariant its own `v1`/`v2` branch already
  documents, INV-006) — verified by re-running that script's own existing
  fixture (or an equivalent) unmodified and diffing output against a
  pre-epic capture.
- AC-012: A new, explicitly-flagged capability-event sibling object (name
  fixed by design.md, following the `effort` object's existing
  `main`/`reviewers` shape convention, INV-006) appears in
  `emit-run-record.sh` output only when a new capability-related flag is
  supplied, mirroring the existing `emit_v2` gating exactly.
- AC-013: The formal compatibility requirement (REQ-004; decision doc §4's
  exact sentence) is restated as a conjunction of at least three
  independently checkable clauses — (a) Context-absent determinism is
  byte-identical, (b) Context-present deviation is event-identical against
  a registered event vocabulary, (c) generated specs remain
  schema/structure/heading-compatible — each clause traced to at least one
  AC above in `traceability.md` (future phase), and clause (a)/(b)'s own
  boundary is fixed exhaustively and exclusively by the
  observable×fixture-state judgment table AC-029 requires, so no
  observable is ever simultaneously eligible for both a byte-identical
  and an event-identical assertion.
- AC-014: F1–F4 (REQ-005) are constructible by a single, named
  fixture-builder contract (design.md fixes its signature) accepting a
  `project-context.yaml`-absent-or-present, `AGENTS.md`-marker-present-or-
  absent, `capability_enforcement`-valued, and (for F3/F4) a
  valid-or-`PROJECT_CONTEXT_INVALID`-variant parameter, as decision doc
  §6's combination-matrix rows require (INV-011); the same contract also
  constructs the Context-absent CLI `none`/`--full`/`--lite` ×
  `AGENTS.md`-marker submatrix (REQ-005) as a `track_flag` parameter
  independent of the other three.
- AC-015: Every new or extended suite this epic's future tasks add ships
  as a `.sh`/`.ps1` pair (INV-005, INV-007 convention) and is registered
  in `tests/run-all.sh`, `tests/run-all.ps1`, and
  `.github/workflows/test.yml` — this package's design.md names the exact
  registration lines to add to, without editing them now.
- AC-016: Every assertion in REQ-001–REQ-003 that depends on an unmerged
  upstream epic (A1/A2/A3/A4/A5/A6, INV-023) — whether a Context-present
  assertion or a Context-absent spy/absence assertion whose own target
  does not exist yet (AC-004) — degrades to a named `SKIP` line (matching
  the existing `LOOP_VALIDATOR_CAPABILITY` degradation pattern,
  `tests/lib/loop-driver.sh:460-519`) citing the specific tracking issue
  and reading its entry from the REQ-007 allowlist manifest (AC-034),
  rather than failing the suite or silently passing, until that upstream
  epic merges.
- AC-017: This package cites file:line evidence (WFI-011) for every
  checkable factual claim about current repository behavior; `spec-review`
  is expected to reject an uncited claim as a structural gap (AGENTS.md
  rule, INV-019).
- AC-018: The Golden baseline (REQ-006/AC-001) capture procedure records,
  at minimum, the exact pre-capability merge-base commit SHA it was
  captured against (INV-022 — never "`main` at Phase 2 start"), the exact
  fixed environment variables used, and the exact script versions (file
  sha256) it pins — an update to the baseline is only valid when produced
  as a `candidate` (REQ-006c), promoted to `canonical` via a dedicated
  pull request carrying a human-reviewed diff explaining why legacy
  behavior intentionally changed, and never written directly by CI or by
  an unreviewed regeneration.
- AC-019: A `sdd/project-context.yaml` that is physically present but
  fails Epic A1's own validator (REQ-009, `PROJECT_CONTEXT_INVALID` —
  `specs/epic-189-a1-project-context/requirements.md:891-908,1836-1847`)
  causes the orchestration-event trace to record a distinct
  `PROJECT_CONTEXT_INVALID` stop event — the `skip-stop-message` kind's
  own `stop` producer, uniquely assigned and never shared with
  `quality-gate-outcome` (design.md Data Plan) — for both the F3-invalid
  and F4-invalid fixture variants (REQ-005) — never the F1/F2
  compatibility-fallback event and never a valid-F3/F4 event trace. Named
  `SKIP` in REQ-007's allowlist manifest until Epic A1 merges.
- AC-020: The F3-invalid/F4-invalid fixture variants' own event trace
  never reaches the Context-absent compatibility-fallback path (CLI-flag
  → `AGENTS.md`-marker → default priority order, ADR-0023 item 2) — only
  a `sdd/project-context.yaml` that is physically **absent** reaches that
  fallback (`specs/epic-189-a1-project-context/requirements.md:891-921`),
  so F3-invalid/F4-invalid and F1/F2 must be asserted as producing
  genuinely different event traces, not the same fallback trace reused
  for both. Named `SKIP` until Epic A1 merges (REQ-007).
- AC-021: The F3-invalid/F4-invalid fixture variants' event trace asserts
  the Resolver subprocess is never invoked (identical spy/absence
  mechanism to AC-004) — a present-but-invalid Context must fail closed
  before any capability machinery runs, not merely before it succeeds.
  Named `SKIP` until Epic A1 **and** Epic A5 both merge (REQ-007;
  Resolver-invocation-avoidance depends on A5 existing to be spied on).
- AC-022: The skill-invocation-order event kind (canonical trace schema,
  REQ-003) has its own producer, ordering rule, and value-normalization
  fixed in design.md, and `TEST-018` in `tests/loop-consistency.tests.sh`
  (AC-032) asserts a Context-absent round drive's observed
  skill-invocation-order sequence is identical to a recorded golden-trace
  value for that event kind alone.
- AC-023: The review-loop-presence event kind has its own producer,
  ordering rule, and value-normalization fixed in design.md, and the same
  `TEST-018` case (AC-032) asserts the observed set of loop entries/rounds
  actually driven for a given fixture state is identical to the recorded
  golden-trace value for this event kind.
- AC-024: The approval-checkpoint event kind has its own producer (the
  shared driver's `_loop_reserve_review_context`/ledger-write call sites,
  INV-003), ordering rule, and value-normalization (ledger hash fields
  excluded/canonicalized per design.md) fixed, and is asserted against
  the golden trace by the same `TEST-018` case AC-032 names.
- AC-025: The quality-gate-outcome event kind has its own **two** named
  producers — an escalation-decision producer
  (`check-quality-gate-cycle-limit.sh`/`select-agent-model.sh` escalation
  decisions, INV-005) and a capability-applicability producer (the new
  `capability_applicability` observation, INV-014, always the last
  `quality-gate-outcome` event when both fire, design.md Data Plan) —
  each with its own ordering rule and value-normalization fixed, and is
  asserted against the golden trace by `TEST-019` in
  `tests/loop-escalation.tests.sh` (AC-010).
- AC-026: The Done-transition event kind has its own producer
  (`assert_terminal`'s own comparison call, firing at terminal-state-
  assertion time — a state-transition record capturing the round's own
  pre-round non-terminal state to the newly-observed terminal state,
  never a separately-sampled final value, design.md Data Plan; INV-004),
  ordering rule (always last in a round's own event sub-sequence), and
  value-normalization fixed, and is asserted against the golden trace by
  the same `TEST-018`/`TEST-019` cases AC-022/AC-025 name, split by which
  suite drives the round in question.
- AC-027: The skip/stop-message event kind has its own **two** named
  producers — a `skip` producer (`loop_validator_skip`'s existing
  named-SKIP pattern, INV-005, `tests/lib/loop-driver.sh:460-519`,
  extended by REQ-007's allowlist manifest, AC-034) and a `stop` producer
  (the fixture drive's own fail-closed Context-validation guard, design.md
  Data Plan) — each with its own fixed value-normalization (the `skip`
  producer's cited-issue-number template; the `stop` producer's fixed
  `PROJECT_CONTEXT_INVALID` template, AC-019) fixed; `PROJECT_CONTEXT_INVALID`
  is uniquely assigned to this kind's `stop` producer, never to
  `quality-gate-outcome` (design.md Data Plan, resolving an earlier
  draft's dual-kind ambiguity) — asserted against the golden trace's own
  skip/stop value wherever either producer fires within a driven round.
- AC-028: A single compatibility matrix (design.md) enumerates every
  valid decision doc §6 row (F1–F8, REQ-005) crossed with each of
  REQ-001/REQ-002/REQ-003's three test kinds. Every AC cited in a cell
  carries its own single, explicit disposition — `ASSERT` (cites the
  AC/TEST that covers it, assertable now), `SKIP-with-activation` (cites
  the REQ-007 allowlist-manifest entry gating it, degrading to a named
  `SKIP` until that entry's own `activation_condition` evaluates true —
  never a bare `SKIP` with no machine-checkable unblocking condition), or
  `N/A` (cites the stated non-coverage rationale, e.g. F7/F8's "no
  Foundation epic produces this state") — never a cell-level label
  spanning two ACs with different gating states (design.md, "Disposition
  legend"). The Context-absent CLI `none`/`--full`/`--lite` × marker
  submatrix (REQ-005) is included as its own six-cell block within the
  same table, each of its six cells individually cited `ASSERT (AC-003,
  AC-014)`.
- AC-029: A single observable×fixture-state judgment table (design.md)
  fixes, for every observable this package names — the nine REQ-001
  byte-identical targets, REQ-002's generated-artifact-structure
  observable, and REQ-003's six event-kind observables — crossed with
  every matrix row (AC-028, F1–F8), whether that observable is compared
  **byte-identical**, **structural**, or **event-identical** for that row
  — three mutually exclusive, jointly exhaustive classes (never a
  two-way byte/event choice, correcting an earlier draft's own AC-029
  text) — each cell carries exactly one marking, including every `N/A`
  cell, and the table's own coverage is exhaustive over the full
  observable×row cross-product, never only the `ASSERT` cells.
- AC-030: The structural compatibility test's LLM-generation fixtures
  inject a versioned, recorded model response through a fixed
  deterministic seam — an anchor-fingerprint against
  `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md`'s own
  `## Required Outputs` section (design.md Design Decisions,
  "Structural-comparison seam," names the exact anchor window and its
  recorded sha256 digest, identical algorithm to Epic A5's own
  anchor-fingerprint technique) — rather than invoking a live model, read
  from a versioned `structural-fixture-corpus/v1` record corpus (design.md
  fixes the schema) whose parse failure is itself a hard suite failure,
  never a silent skip, and every generated Markdown/frontmatter artifact
  is compared through a fixed AST canonicalizer whose own frontmatter-
  key-sort (unordered), heading-order (ordered), and whitespace-
  normalization algorithm design.md fixes concretely — REQ-002's own
  gating suite runs fully offline and deterministically against this
  seam, never against a live model call.
- AC-031: A separate, explicitly non-gating test exercises the structural
  compatibility assertions against a live model call (recorded-response
  corpus refresh) — its own result is never required for the
  compatibility suite's own pass/fail verdict and it is never registered
  in the gating `tests/run-all.sh`/`.github/workflows/test.yml` entries
  AC-015 requires for the gating suite.
- AC-032: A new case, `TEST-018`, in `tests/loop-consistency.tests.sh`
  (design.md Design Decisions; that suite's own next available case
  number after `TEST-017`, INV-005) asserts that a Context-absent round
  drive's skill-invocation-order, review-loop-presence, and
  approval-checkpoint event-kind values (AC-022–AC-024) are identical to
  the recorded golden trace — no new suite file is created (REQ-003).
- AC-033: `emit-run-record.sh`'s four `--effort-*`/
  `--capability-enforcement` flag combinations each produce the exact
  JSON shape design.md fixes: no-flag → unchanged `sdd-run-record/v1`
  heredoc (AC-011); `--effort-*` only → current `sdd-run-record/v2` with
  the `effort` object, no `capability` object; `--capability-enforcement`
  only (no `--effort-*`) → a usage error (non-zero exit, no `$out` file
  written), matching the script's own existing
  `require_effort_control_value`-style fail-closed argument validation
  (`plugins/sdd-quality-loop/scripts/emit-run-record.sh:45-54`); both
  flag families → `sdd-run-record/v2` with both the `effort` object and
  the additive `capability` object (AC-012). A golden negative test
  asserts the capability-only combination's own non-zero exit and absent
  output file.
- AC-034: A single allowlist manifest (design.md; REQ-007;
  `skip-allowlist-manifest/v1`) lists every upstream-dependent assertion
  this package names as a `SKIP` candidate — AC-004, AC-007, AC-019–
  AC-021, AC-036, AC-037, AC-042, AC-043, and any Context-present REQ-003
  assertion — each row's own
  `dependencies` field an **array** of `{epic, issue, fingerprints}`
  objects (never a single flat `{epic, issue}` pair), so one assertion
  can cite more than one upstream epic (AC-021's own compound Epic A1
  **and** Epic A5 dependency is the package's own worked example,
  design.md Data Plan); each dependency's own `fingerprints` is itself an
  array of `{source, line_range, algorithm, digest, quote}` objects (a
  canonical-window sha256 digest, never a `path:line-range#item`
  locator); and a machine-detectable `activation_condition` — a boolean
  expression over exactly the two primitive predicates `merged(<epic-id>)`
  and `fingerprint_match(<dependency-index>)`, combined only by
  `AND`/`OR` (design.md Data Plan fixes the grammar and evaluator).
- AC-035: The suite fails — not `SKIP`s, not passes — when (a) an
  allowlisted assertion's `merged(...)` predicate (AC-034) evaluates true
  but the assertion still emits `SKIP` (dependency-present SKIP); (b) any
  `SKIP`-shaped line in suite output does not match an allowlist entry
  (unknown SKIP); or (c) `merged(...)` evaluates true but
  `fingerprint_match(...)` evaluates false for any of that entry's own
  `fingerprints[]` — i.e. recomputing the cited window's own sha256
  digest against the upstream epic's current HEAD no longer equals the
  recorded `digest` value (fingerprint drift, evaluated independently of
  and in addition to `merged(...)`) — closing the fail-open direction
  INV-023 identifies.
- AC-036: A `TEST-0NN` case inside this epic's own existing suite
  (design.md; not a new suite file) recomputes, against the live
  `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md`, the
  sha256 of the fixed line window and the target heading's own ordinal
  position Epic A5's `design.md` item 10(a) already records (`FP-A5-CALLER-CONTRACT-10`,
  design.md Design Decisions "Cross-epic fingerprint citations" —
  `specs/epic-193-a5-capability-resolver/design.md:1886-1915`, `sha256:
  9b549be9c9d8897c9efd1badbab8a5d4184086649e98a3c31325ef3210561bff`),
  failing loudly on drift — resolving OQ-001's suite-ownership half for
  this specific assertion.
- AC-037: A `TEST-0NN` case inside this epic's own existing suite asserts
  that a REQ-002 Block (Epic A5's own diagnostic taxonomy, `FP-A5-BLOCK-REQ002`,
  design.md Design Decisions "Cross-epic fingerprint citations" —
  `specs/epic-193-a5-capability-resolver/requirements.md:341-343`, `sha256:
  4e02ad4f1f9095fcc73db9f2478c8c487366b6d11ed6c25b73e92e672df9ba62`)
  surfaces as a visible stop/error event in the orchestration-event trace
  rather than silently falling back to legacy generation — the third of
  Epic A5's `design.md` item 10 fixture assertions (`FP-A5-CALLER-CONTRACT-10`,
  above), owned by this epic's own existing suite, resolving OQ-001 in
  full together with AC-004/AC-021 and AC-036.
- AC-040: A static check (design.md Test Strategy item 9) scans the
  committed `.github/workflows/test.yml` text for the literal strings
  `promote-golden-baseline.sh` and `--write-candidate`, hard-failing the
  suite if either appears anywhere in that file — the automated,
  structural verification that CI's own job registration never
  references either mutation-capable golden-baseline invocation
  (Security Boundaries B1), independent of and in addition to
  `promote-golden-baseline.sh`'s own `CI`-environment-variable/
  `--approved-by` fail-closed guards (design.md API / Contract Plan).
- AC-041: `promote-golden-baseline.sh`'s own runtime refusal guard (Roles
  and Permissions; design.md API / Contract Plan) is exercised directly,
  not only inferred from AC-040's static CI-workflow-text scan: invoking
  the script with the `CI` environment variable set to any non-empty
  value exits non-zero immediately without reading or writing any file
  (even given a valid candidate path and a valid `--approved-by` value),
  and invoking it without `--approved-by` (or with an empty
  `--approved-by` value) also exits non-zero and writes nothing to the
  canonical path — two independent negative fixtures, neither condition
  satisfied by the other's absence.
- AC-038: REQ-001's target inventory is a single canonical table
  (design.md) pairing each target — deterministic script output, exit
  code, stdout/stderr, template-copy result, schema-validator result,
  install result, uninstall result, generated directory listing, and
  plugin manifest — 1:1 with an exact capture format (a status integer, a
  raw stdout/stderr byte-tuple, or a filesystem manifest) and an AC/TEST;
  the generated directory listing and plugin manifest (decision doc §4.1)
  are present in this table even though a prior draft's AC-003/
  capture-contract/Test Strategy text omitted both.
- AC-039: INV-014's three-state Gate-applicability pattern is documented
  as scoped to the `check-component-coverage` Gate shape only (not every
  future capability-derived Gate); a per-component table (design.md)
  fixes each component's own `disabled-legacy` expectation independently
  — `check-component-coverage`: an evidence event present with
  `state: "not-applicable (disabled-legacy)"`; Resolver (Epic A5): no
  invocation event at all — so the orchestration-event trace's own
  fixture assertions never require the two to share one shape.
- AC-042: The structural compatibility test (REQ-002) asserts that a
  Context-present, `capability_enforcement: advisory` fixture (F3)'s
  generated artifacts remain structurally identical to the Context-absent
  `full`-track legacy-seven-layer file set AC-005's own full-track clause
  fixes (INV-018) — identical required-file count, frontmatter, required
  headings, and status field names, matching the existing templates under
  `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/`
  unchanged — because Project Context presence alone, independent of
  `capability_enforcement`'s advisory value, does not itself alter
  generation structure while the project's own facet-track selection
  remains `full`/legacy-seven-layer (design.md Compatibility Matrix, F3
  row/REQ-002 column; design.md Observable×fixture-state judgment table,
  "Generated-artifact structure" row, F3 column: `structural`). A named
  `SKIP` entry in REQ-007's allowlist manifest (AC-034) until Epic A1's
  Project Context schema exists, activation condition "Epic A1 merged to
  `main`" (REQ-007) — matching the exact gating condition design.md's own
  Compatibility Matrix F3/REQ-002 cell already names.
- AC-043: The structural compatibility test (REQ-002) asserts that
  Context-present, `lite`-track/lite-three-file fixtures — F5 (advisory)
  and F6 (required) — generated artifacts remain structurally identical to
  the Context-absent `lite`-track file set AC-005's own lite-track clause
  fixes (INV-024): identical required-file count, frontmatter, required
  headings, and status field names, matching
  `plugins/sdd-lite/templates/requirements-lite.md`/`design-lite.md`/
  `tasks-lite.md` unchanged — because Project Context presence, and
  `capability_enforcement`'s advisory-or-required value, do not themselves
  alter generation structure while the project's own facet-track selection
  remains `lite`/lite-three-file (design.md Compatibility Matrix, F5/F6
  rows, REQ-002 column — both already cite "the allowlist manifest's own
  A1+A6 compound entry"). A named `SKIP` entry in REQ-007's allowlist
  manifest (AC-034) until Epic A1's Project Context schema **and** Epic
  A6's Lite integration both merge, activation condition "Epic A1 merged
  to `main` AND Epic A6 merged to `main`" (REQ-007) — the identical
  compound-dependency shape AC-021 already establishes for its own Epic A1
  + Epic A5 pair.
  - **F5 clause (advisory)**: `capability_enforcement: advisory`.
  - **F6 clause (required)**: `capability_enforcement: required`.

  Both clauses are independently checkable and neither is ever substituted
  for the other, mirroring AC-005's own full-track/lite-track discipline.

## Field Definitions

- **Context-absent fixture**: a fixture tree with no `sdd/project-context.yaml`
  file and no `spec_profile: lite` marker in `AGENTS.md` — the
  `full`/`legacy-seven-layer`/`disabled-legacy` matrix row (INV-011).
- **Context-absent-lite fixture**: identical, but `AGENTS.md` carries
  `spec_profile: lite` — the `lite`/`lite-three-file`/`disabled-legacy`
  matrix row (INV-011).
- **Context-present-advisory fixture**: a fixture tree with a syntactically
  and semantically valid `sdd/project-context.yaml` whose
  `workflow.capability_enforcement` is `advisory`.
- **Context-present-required fixture**: identical, with
  `workflow.capability_enforcement: required`.
- **Context-present-invalid variant**: a Context-present-advisory or
  Context-present-required fixture (above) whose `sdd/project-context.yaml`
  is physically present but fails Epic A1's own validator (REQ-009,
  `specs/epic-189-a1-project-context/requirements.md:891-921`) — the
  required negative variant of each present state (REQ-005; AC-019–
  AC-021), distinguished in the orchestration-event trace from both the
  Context-absent fallback and a valid Context-present run by a distinct
  `PROJECT_CONTEXT_INVALID` stop event (Edge Cases, below; resolves
  OQ-002).
- **Event-identical**: two orchestration event traces are event-identical
  when every event kind the `compatibility-event-trace/v1` schema
  (design.md; REQ-003) defines — skill-invocation order, review-loop
  presence, approval-checkpoint, quality-gate outcome, Done-transition,
  and skip/stop message (decision doc §4.3) — matches per that schema's
  own required/ignored-field list, ordering rule, and value-normalization
  rule for that kind, even when byte-level artifact content differs
  (decision doc §4's own distinction between byte-identical and
  event-identical compatibility). Which observable is byte-compared,
  **structurally**-compared, or event-compared for a given fixture-matrix
  row is fixed exhaustively and exclusively by the observable×
  fixture-state judgment table AC-029 requires (three mutually exclusive
  classes, never a two-way byte/event default).
- **Canonical event kind**: one of the six named, independently-defined
  members of the `compatibility-event-trace/v1` schema (REQ-003):
  `skill-order`, `review-loop-presence`, `approval-checkpoint`,
  `quality-gate-outcome`, `done-transition`, `skip-stop-message`. Each
  kind is asserted by its own AC (AC-022–AC-027) and traced to its own
  producer(s) in design.md — `quality-gate-outcome` and
  `skip-stop-message` each have **two** independently named producers
  (design.md Data Plan), every other kind has exactly one.
- **Capability event**: any orchestration-observable fact whose presence,
  absence, or value depends on `workflow.capability_enforcement`'s derived
  state (`disabled-legacy` / `advisory` / `required`, ADR-0016) — e.g. "the
  Resolver subprocess was invoked", "a `disabled-legacy` non-evaluation
  record was emitted" (INV-014), "a `PROJECT_CONTEXT_INVALID` stop
  occurred" (INV-013).

## Roles and Permissions

- **Maintainer**: authors the golden baseline's initial canonical capture
  (REQ-006) against the fixed pre-capability merge-base commit (AC-018),
  reviews and approves every later candidate→canonical promotion PR
  (REQ-006c), and is the sole approver of any task that touches
  `tests/loops/loop-inventory.json` (a shared, cross-epic registry —
  INV-001) or `emit-run-record.sh` (INV-006).
- **Epic A1/A2/A3/A4/A5/A6 implementer**: consumes this package's REQ-003/
  design.md contract to know which fields/events their own epic's Phase
  2/3 tasks must add; does not redesign the shared registry/driver
  contract unilaterally.
- **CI**: runs every REQ-005 fixture-matrix state on every push, using the
  named `SKIP` degradation (AC-016) for states whose upstream dependency
  is not yet merged. CI never writes the golden baseline (REQ-006/AC-018)
  in either its `candidate` or `canonical` form — the capture script's own
  default (no-flag) invocation is read-only, and `--write-candidate`
  output is never committed by an automated job; only a human-reviewed
  pull request promotes a candidate to canonical (Security Boundaries B1).
  This is now structurally enforced, not only an operational convention:
  `promote-golden-baseline.sh` itself refuses to run whenever the `CI`
  environment variable is set or when no `--approved-by <human-identifier>`
  flag is supplied (design.md API / Contract Plan), and AC-040's static
  check independently verifies CI's own `.github/workflows/test.yml`
  never references either mutation-capable command. AC-041 additionally
  exercises the script's own runtime refusal directly (two independent
  negative fixtures: `CI` set, and `--approved-by` omitted), rather than
  relying solely on AC-040's static text scan of CI's job definition.

## Main Workflows

1. A future Phase 2/3 task reads this package, captures the REQ-006 golden
   baseline against the fixed pre-capability merge-base commit (AC-018,
   never "current `main` HEAD"), and commits it as the initial canonical
   baseline. Before this task's own Phase 2 begins, a preflight
   `check-sdd-structure.sh` run against this directory is expected to fail
   with the six `missing:` lines Risks (Medium) already records — Phase
   2's own first commit is the one that finally generates those files,
   making the Phase-1 deviation self-closing rather than silently
   permanent.
2. That task extends `tests/loops/loop-inventory.json` with the additive
   `capability_applicability` field on the `quality-gate` entry (design.md
   Data Plan), adds `TEST-019` to `tests/loop-escalation.tests.sh`
   (AC-010/AC-025), and adds `TEST-018` to `tests/loop-consistency.tests.sh`
   (AC-032/AC-022–024).
3. That task extends `emit-run-record.sh` with the new, flag-gated
   `capability` sibling object across all four flag combinations
   (AC-033), following the `effort` object's exact pattern (INV-006).
4. That task builds the REQ-007 allowlist manifest (AC-034) and wires
   AC-035's three hard-fail checks (dependency-present SKIP, unknown
   SKIP, fingerprint drift) into the suite run itself.
5. CI runs every REQ-005 matrix cell (AC-028); cells depending on
   unmerged upstream epics report a named `SKIP` per the allowlist
   manifest until each epic merges, and CI never writes the golden
   baseline (Roles and Permissions).
6. As Epic A1 merges, a follow-up task un-skips the assertions that
   depended only on Epic A1 (verifying the allowlist's activation
   condition first, AC-035); the same repeats for A2/A3/A4/A5/A6
   independently, each unblocking only the assertions that name it.
7. Any baseline update after step 1 follows REQ-006c: a `candidate`
   capture, a dedicated pull request carrying a human-reviewed diff, and
   only then a promotion to `canonical` — never a direct commit.

## Edge Cases

- A Context-present fixture whose `sdd/project-context.yaml` fails
  Epic A1's own validation (REQ-009, INV-013) is distinguishable, in the
  orchestration-event trace, from both the Context-absent fallback and a
  valid Context-present run — it is the third, `PROJECT_CONTEXT_INVALID`
  outcome, now a named Field Definition (Context-present-invalid variant,
  above) and the required negative variant of each Context-present matrix
  row (F3-invalid/F4-invalid, REQ-005; AC-019–AC-021), resolving OQ-002.
- A golden baseline captured against one `main` commit must not silently
  validate against a later commit whose legacy behavior has genuinely and
  intentionally changed (e.g. a bug fix in `install.sh`) — AC-018's
  commit-SHA pinning exists specifically to force a human decision at that
  point rather than a false byte-identical pass or an unreviewable
  baseline auto-refresh.
- A capability-event field added to one `loop-inventory` entry but not
  others (e.g. only `quality-gate`, not `spec-review`) is valid — not
  every loop necessarily has a capability-relevant event; `design.md`
  documents exactly which entries the epic proposes to extend and why.

## Security Boundaries

| Trust Boundary | Auth/Authz Requirement | PII / Data Classification | Regulatory Constraints |
|---|---|---|---|
| B1: golden baseline capture/update | maintainer-authored initial canonical capture against a fixed pre-capability merge-base commit (REQ-006/AC-018); every later update is a `candidate` (agent-producible) promoted to `canonical` only via a maintainer-reviewed pull request (REQ-006c) — CI and an unreviewed agent commit can never write the canonical file directly (Roles and Permissions); `promote-golden-baseline.sh` itself structurally refuses to run under a set `CI` environment variable or without an explicit `--approved-by` flag, and AC-040's static check independently verifies CI's own workflow file never references either mutation-capable command | none (repository fixtures/scripts only) | none identified |
| B2: shared registry/driver/run-record edits (`tests/loops/loop-inventory.json`, `tests/lib/loop-driver.sh`, `emit-run-record.sh`) | cross-epic shared surface (INV-001, INV-006); any Phase 2/3 edit requires the same review rigor as a protected-file change even though these are not formally protected files today, because Epic A2/A3/A5's own suites depend on their stability | none | none identified |

This is internal test-infrastructure specification work with no
user-facing entry point; the UI Integration Checklist is not applicable.

## Assumptions

- Epics A1 (`sdd-forge-wt-epic-189`), A3 (`sdd-forge-wt-epic-191`), and A5
  (`sdd-forge-wt-epic-193`) remain unmerged and in active spec/task-review
  through this epic's own Phase 1; A4 (`sdd-forge-wt-epic-192`) has passed
  `spec-review-loop` but is also unmerged; A6 (`sdd-forge-wt-epic-194`) is
  in active spec-review. Any REQ-007-cited fact from any of them may shift
  before that epic reaches `impl-review-loop`/merge — this is the exact
  drift AC-035's fingerprint-mismatch hard-fail (REQ-007) is designed to
  catch, not merely tolerate. This package re-verifies before Phase 2/3
  begins, per investigation.md's Safety constraints.
- `docs/ai-dlc-foundation-decision-v2.md` and ADR-0010/0016/0023 remain the
  authoritative, unrevised source of the compatibility requirement and the
  loop-inventory/track-selection contracts respectively; this package adds
  no new design judgment beyond what they already fix.
- `jq`, `bash`, and PowerShell remain the deterministic runtimes this
  repository's existing suites already assume (INV-005, INV-007); this
  epic introduces no new runtime dependency.

## Open Questions

- OQ-001 (resolved): Epic A5's deferred
  `resolve-project-context-caller-contract` fixture assertions (INV-016)
  are authored as `TEST` cases inside this epic's own existing suite
  (AC-036, AC-004/AC-021, AC-037), not a new suite file and not a
  distinct future task — decided in this package (Non-goals; design.md
  Design Decisions).
- OQ-002 (resolved): `PROJECT_CONTEXT_INVALID` is folded into the
  Context-present states as a required negative variant (Field
  Definitions "Context-present-invalid variant"; REQ-005; AC-019–AC-021),
  not a fifth top-level fixture-matrix state — decided in this package.
- OQ-003 (resolved): The REQ-006 golden baseline fixture set's physical
  path is fixed at `specs/epic-195-a7-compatibility/verification/golden-baseline/`
  (`canonical/` + gitignored `candidate/`), matching this repository's
  existing per-feature `verification/` convention — decided in this
  package (design.md Design Decisions). A future maintainer proposing the
  alternative shared `tests/fixtures/compatibility-baseline/` location
  does so via an explicit revision to that Design Decisions paragraph, not
  a silent Phase-2 substitution.

## Risks

- Critical: specifying "Context present" orchestration-event assertions
  against Epic A1/A2/A3/A4/A5/A6 specs that are still unmerged and under
  active review (INV-013–INV-016, INV-023) risks the assertions drifting
  from what those epics actually ship; REQ-007's named-`SKIP`/allowlist
  design (AC-034/AC-035) and this package's OQ-001/OQ-002 resolutions are
  this package's mitigation, not an elimination of the risk — the
  fingerprint-drift hard-fail (AC-035c) is what turns a silent drift into
  a loud one once it actually occurs.
- High: extending a cross-epic shared surface (`loop-inventory.json`,
  `loop-driver.sh`, `emit-run-record.sh` — INV-001, INV-003, INV-006) is
  higher-blast-radius than a feature-local change; an incorrect additive
  field could silently break an Epic A2/A3/A5 task that reads the registry
  before this epic's own field-naming is finalized. Mitigated by fixing
  the exact field names and shapes in design.md before any Phase 2/3 task
  starts.
- Medium: this package's deliberate 4-file (no layer-spec, no Phase-2)
  scope deviates from `check-sdd-structure.sh`'s own full-profile
  expectation (INV-018); a future automated preflight run against this
  directory with the feature name supplied would report six `missing:`
  lines. This is intentional per this task's explicit Phase-1-only mandate
  and is not a defect to silently "fix" by generating placeholder layer
  files. A Phase 2 kickoff gate closes this deliberately rather than
  leaving it open-ended: Phase 2's own first commit is expected to be the
  one that finally generates the six missing files (layer specs +
  `tasks.md`/`traceability.md`), and a `check-sdd-structure.sh` run
  failing before that commit is the expected, self-documenting signal
  that Phase 2 has not yet started — never silence (Main Workflows step
  1).
