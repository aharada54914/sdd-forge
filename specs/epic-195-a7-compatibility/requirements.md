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
no parallel test harness.

This package is Phase 1 (specification) only: `investigation.md`,
`requirements.md`, `design.md`, `acceptance-tests.md`. No test code,
fixtures, or registry edits are produced by this task; `tasks.md` and
`traceability.md` follow in a later phase once this package passes
`spec-review-loop`.

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
  three states decision doc §6 names — absent-with-lite-marker,
  present-advisory, present-required (INV-011) — have no test surface at
  all, on `main` or on any unmerged Epic A branch.
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
  fixture harness.
- **REQ-002** (Structural compatibility test): specify a test kind that
  compares LLM-generated specification artifacts structurally —
  required-file count, frontmatter, required headings, status fields,
  `REQ-NNN`/`AC-NNN` identifier format, absence of Facet-Manifest
  references in legacy mode, and absence of any capability-related
  generated file in legacy mode (decision doc §4.2).
- **REQ-003** (Orchestration event test — capability-event extension):
  specify the exact additive fields/events this epic adds to
  `tests/loops/loop-inventory.json`, `tests/lib/loop-driver.sh`,
  `tests/loop-consistency.tests.sh`, `tests/loop-escalation.tests.sh`, and
  `emit-run-record.sh` (INV-001–INV-006) to make skill-invocation order,
  review-loop presence, approval checkpoints, quality-gate outcomes,
  Done-transitions, and skip/stop messages comparable as an event trace
  (decision doc §4.3), without registering a new loop `id` and without
  creating a new `tests/*.tests.sh` file.
- **REQ-004** (Formal compatibility requirement decomposition): decompose
  decision doc §4's exact requirement text — "Project Context不在時、決定
  論的成果物と制御フローはbyte-identicalまたはevent-identicalであり、LLM
  生成仕様は既存のschema・構造・必須見出しと互換であること" — into
  independently verifiable acceptance criteria, so the requirement itself
  is testable rather than only its three named test kinds.
- **REQ-005** (Fixture matrix + cross-runtime pairing): specify a 4-state
  fixture matrix (Context absent / Context absent + `AGENTS.md`
  `spec_profile: lite` marker / Context present + `advisory` / Context
  present + `required` — decision doc §6, INV-011) that every REQ-001
  through REQ-003 test consumes, each new/extended suite shipped as a
  `.sh`/`.ps1` pair per this repository's existing convention (INV-005,
  INV-007), registered in `tests/run-all.sh`, `tests/run-all.ps1`, and
  `.github/workflows/test.yml` (INV-005 pattern).
- **REQ-006** (Golden baseline governance): specify where the REQ-001
  golden baseline lives, how it is captured for the first time, and the
  exact procedure and required approval for updating it — an unreviewable,
  agent-writable golden baseline would defeat the byte-identical test's
  own purpose.
- **REQ-007** (Forward-compatibility / staged activation): specify how
  every "Context present" assertion in REQ-001–REQ-003 behaves before its
  upstream dependency (Epic A1 Project Context schema, Epic A2 Registry,
  Epic A3 path ownership, Epic A5 Resolver) is merged to `main` — a named,
  auditable `SKIP`, never a silent pass and never a hard failure that
  blocks Epic A0's own stated build order (decision doc §20).

## Non-goals

- Implementing Epic A1 (`project-context.yaml`), Epic A2 (Capability
  Registry), Epic A3 (path ownership), Epic A4 (Facet Manifest), Epic A5
  (Capability Resolver), or Epic A6 (Lite integration) themselves. This
  epic tests compatibility around their eventual presence; it does not
  build them.
- Authoring the actual test code, fixtures, or registry/driver/run-record
  edits. Those are Phase 2/3 deliverables of a later task once this
  package passes `spec-review-loop`/`impl-review-loop`.
- Registering a new `loop-inventory/v1` loop `id` (a ninth loop). Per
  decision doc §4.3/§19 and INV-002, capability events extend existing
  entries; if a genuinely new loop-shaped surface (its own cap/round/
  terminal state) is discovered during Phase 2 design, that is an ADR-0010
  vocabulary-revision decision outside this epic's scope, recorded as an
  Open Question below.
- Re-specifying Epic A5's own deferred `resolve-project-context-caller-contract`
  suite (INV-016) in full; this package only decides where that suite's
  eventual home is (Open Questions) so Phase 2/3 tasks are not blocked
  guessing.
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
  whose location is a single, named path under `specs/epic-195-a7-compatibility/`
  or `tests/fixtures/` (design.md decides which, per this repository's
  existing fixture-location convention).
- AC-002: The byte-identical test (REQ-001) fails, in at least one
  deliberately mutated fixture (a negative self-check, matching the
  pattern already established by `loop-inventory.tests.sh`'s own negative
  self-checks — INV-002), when a single byte of the golden baseline
  differs from a fresh run's output.
- AC-003: The byte-identical test's Context-absent fixture asserts, for at
  least one representative script per category named in decision doc
  §4.1 (deterministic script output, exit code, stdout/stderr, template
  copy, schema validator, install, uninstall), that output is
  byte-for-byte identical across two independent invocations against the
  identical fixture and a fixed, normalized environment (`TZ`, `LC_ALL`,
  no ambient `SDD_*` environment variables).
- AC-004: The byte-identical test's Context-absent fixture asserts that no
  process under test invokes a capability-machinery subprocess (Resolver,
  Registry discovery, Facet generation) — the "resolver を呼ばない旧コー
  ドパス" target of decision doc §4.1 — via a spy/absence check, not by
  merely observing that the (currently nonexistent) subprocess happens not
  to exist (REQ-007; this assertion becomes meaningful once Epic A5 lands
  and is a named `SKIP` until then, citing the tracking issue, per
  REQ-007).
- AC-005: The structural compatibility test (REQ-002) asserts, for a
  Context-absent LLM-generation fixture, that generated artifacts contain
  exactly the legacy-seven-layer file set (INV-018) — no
  `facet-manifest.yaml`, no `capability-summary.yaml`, no per-Facet file —
  and that every generated Markdown file's required headings and status
  field names match the existing templates under
  `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/`
  unchanged.
- AC-006: The structural compatibility test asserts `REQ-NNN`/`AC-NNN`
  identifier format (`^(REQ|AC)-[0-9]{3}$` or the exact pattern
  `design.md` fixes) is unchanged in Context-absent generation output.
- AC-007: The structural compatibility test asserts that a Context-present,
  `capability_enforcement: required` fixture's generated artifacts contain
  no Facet reference in a project that legacy-mode-generates
  (cross-referencing INV-014's truthful-non-evaluation principle: presence
  of capability wiring, absence of Facet content, are two independently
  checkable claims) — named `SKIP` until Epic A4's Facet Manifest exists
  (REQ-007).
- AC-008: `tests/loops/loop-inventory.json`'s entry count remains exactly
  8 after this epic's Phase 2/3 implementation (INV-002); any new field
  this epic's design proposes is additive and optional, verified by a
  schema-validation check that a pre-epic copy of the registry (no new
  fields) still validates against the (still `loop-inventory/v1`, not
  bumped) schema.
- AC-009: At least one existing `loop-inventory` entry (design.md names
  which) carries a new, additive field enumerating the capability events
  that entry's own gate can emit once capability machinery exists (e.g.
  `disabled-legacy` / `advisory` / `required` applicability outcomes,
  INV-014), and `assert_artifacts_schema`/`assert_terminal`
  (`tests/lib/loop-driver.sh`, INV-004) require no code change to read it.
- AC-010: A new numbered `TEST-0NN` case is added to `tests/loop-consistency.tests.sh`
  or `tests/loop-escalation.tests.sh` (design.md decides which, backed by
  investigation.md's own reasoning) asserting that a Context-absent round
  drive produces an identical event trace (skill invocation order, loop
  presence/absence, terminal state) to a recorded golden trace — no new
  suite file is created (REQ-003, INV-005).
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
  AC above in `traceability.md` (future phase).
- AC-014: All four fixture-matrix states (REQ-005) are constructible by a
  single, named fixture-builder contract (design.md fixes its signature),
  each producing a `project-context.yaml`-absent-or-present,
  `AGENTS.md`-marker-present-or-absent, and
  `capability_enforcement`-valued tree as decision doc §6's combination
  matrix rows require (INV-011).
- AC-015: Every new or extended suite this epic's future tasks add ships
  as a `.sh`/`.ps1` pair (INV-005, INV-007 convention) and is registered
  in `tests/run-all.sh`, `tests/run-all.ps1`, and
  `.github/workflows/test.yml` — this package's design.md names the exact
  registration lines to add to, without editing them now.
- AC-016: Every "Context present" assertion in REQ-001–REQ-003 that
  depends on an unmerged upstream epic (A1/A2/A3/A5) degrades to a named
  `SKIP` line (matching the existing `LOOP_VALIDATOR_CAPABILITY`
  degradation pattern, `tests/lib/loop-driver.sh:460-519`) citing the
  specific tracking issue, rather than failing the suite or silently
  passing, until that upstream epic merges (REQ-007).
- AC-017: This package cites file:line evidence (WFI-011) for every
  checkable factual claim about current repository behavior; `spec-review`
  is expected to reject an uncited claim as a structural gap (AGENTS.md
  rule, INV-019).
- AC-018: The Golden baseline (REQ-006/AC-001) capture procedure records,
  at minimum, the exact commit SHA it was captured against, the exact
  fixed environment variables used, and the exact script versions
  (file sha256) it pins — an update to the baseline is only valid when
  accompanied by a human-reviewed diff explaining why legacy behavior
  intentionally changed (never an unreviewed regeneration).

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
- **Event-identical**: two orchestration event traces are event-identical
  when they name the identical ordered sequence of skill
  invocations/loop entries/terminal states, even when byte-level artifact
  content differs (decision doc §4's own distinction between
  byte-identical and event-identical compatibility).
- **Capability event**: any orchestration-observable fact whose presence,
  absence, or value depends on `workflow.capability_enforcement`'s derived
  state (`disabled-legacy` / `advisory` / `required`, ADR-0016) — e.g. "the
  Resolver subprocess was invoked", "a `disabled-legacy` non-evaluation
  record was emitted" (INV-014), "a `PROJECT_CONTEXT_INVALID` stop
  occurred" (INV-013).

## Roles and Permissions

- **Maintainer**: authors the golden baseline (REQ-006), approves baseline
  updates, and is the sole approver of any task that touches
  `tests/loops/loop-inventory.json` (a shared, cross-epic registry —
  INV-001) or `emit-run-record.sh` (INV-006).
- **Epic A1/A2/A3/A5 implementer**: consumes this package's REQ-003/
  design.md contract to know which fields/events their own epic's Phase
  2/3 tasks must add; does not redesign the shared registry/driver
  contract unilaterally.
- **CI**: runs every REQ-005 fixture-matrix state on every push, using the
  named `SKIP` degradation (AC-016) for states whose upstream dependency
  is not yet merged.

## Main Workflows

1. A future Phase 2/3 task reads this package, captures the REQ-006 golden
   baseline against the current `main` HEAD, and commits it.
2. That task extends `tests/loops/loop-inventory.json` with the additive
   capability-event field(s) this package's design.md names, and adds the
   corresponding `TEST-0NN` case(s) to the named existing suite.
3. That task extends `emit-run-record.sh` with the new, flag-gated
   capability sibling object, following the `effort` object's exact
   pattern (INV-006).
4. CI runs all four fixture-matrix states; the three states depending on
   unmerged upstream epics report a named `SKIP` until each epic merges.
5. As Epic A1 merges, a follow-up task un-skips the Context-present
   assertions that depended only on Epic A1; the same repeats for A2/A3/A5
   independently, each unblocking only the assertions that name it.

## Edge Cases

- A Context-present fixture whose `sdd/project-context.yaml` fails
  Epic A1's own validation (REQ-009, INV-013) must be distinguishable, in
  the orchestration-event trace, from both the Context-absent fallback and
  a valid Context-present run — it is the third, `PROJECT_CONTEXT_INVALID`
  outcome (Field Definitions omits it deliberately until Epic A1 defines
  its exact validator contract; recorded as an Open Question).
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
| B1: golden baseline capture/update | maintainer-authored and human-reviewed only (REQ-006/AC-018); an agent may propose a diff but never silently commit a baseline update | none (repository fixtures/scripts only) | none identified |
| B2: shared registry/driver/run-record edits (`tests/loops/loop-inventory.json`, `tests/lib/loop-driver.sh`, `emit-run-record.sh`) | cross-epic shared surface (INV-001, INV-006); any Phase 2/3 edit requires the same review rigor as a protected-file change even though these are not formally protected files today, because Epic A2/A3/A5's own suites depend on their stability | none | none identified |

This is internal test-infrastructure specification work with no
user-facing entry point; the UI Integration Checklist is not applicable.

## Assumptions

- Epics A1 (`sdd-forge-wt-epic-189`), A3 (`sdd-forge-wt-epic-191`), and A5
  (`sdd-forge-wt-epic-193`) remain unmerged and in active spec/task-review
  through this epic's own Phase 1; any REQ-007-cited fact from them may
  shift before those epics reach `impl-review-loop`/merge. This package
  re-verifies before Phase 2/3 begins, per investigation.md's Safety
  constraints.
- `docs/ai-dlc-foundation-decision-v2.md` and ADR-0010/0016/0023 remain the
  authoritative, unrevised source of the compatibility requirement and the
  loop-inventory/track-selection contracts respectively; this package adds
  no new design judgment beyond what they already fix.
- `jq`, `bash`, and PowerShell remain the deterministic runtimes this
  repository's existing suites already assume (INV-005, INV-007); this
  epic introduces no new runtime dependency.

## Open Questions

- OQ-001: Should the Epic A5-deferred `resolve-project-context-caller-contract`
  suite (INV-016) be authored as part of this epic's own orchestration-
  event package once Epic A5's caller insertion point is implemented, or
  remain a distinct future task owned by whichever epic implements the
  capability interview phase (Epic A6, per decision doc §19)? Owner:
  maintainers. Blocks Phase 2 design of the orchestration-event test's
  exact suite placement, not this Phase 1 package.
- OQ-002: Should the `PROJECT_CONTEXT_INVALID` outcome (Edge Cases, above)
  get its own named fixture-matrix state (a fifth state) once Epic A1
  defines its validator's exact error contract, or be folded into the
  Context-present states as a variant? Owner: maintainers, jointly with
  the Epic A1 implementer. Blocks Phase 2 fixture-builder design
  (AC-014), not this Phase 1 package.
- OQ-003: Where should the REQ-006 golden baseline fixture set physically
  live — `specs/epic-195-a7-compatibility/verification/` (matching this
  repository's existing per-feature `verification/` convention) or a
  shared `tests/fixtures/compatibility-baseline/`? Owner: maintainers.
  Blocks Phase 2 implementation, not this Phase 1 package; design.md
  records the tradeoff without deciding it exclusively.

## Risks

- Critical: specifying "Context present" orchestration-event assertions
  against Epic A1/A2/A3/A5 specs that are still unmerged and under active
  review (INV-013–INV-016) risks the assertions drifting from what those
  epics actually ship; REQ-007's named-`SKIP` design and OQ-001/OQ-002 are
  this package's mitigation, not an elimination of the risk.
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
  files.
