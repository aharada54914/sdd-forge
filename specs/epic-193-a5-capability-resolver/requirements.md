# Requirements: epic-193-a5-capability-resolver

Spec-Review-Status: Pending
Source Issues: https://github.com/aharada54914/sdd-forge/issues/193,
https://github.com/aharada54914/sdd-forge/issues/187
Epic: https://github.com/aharada54914/sdd-forge/issues/187 (AI-DLC
Foundation tracking) — Epic A5 (Capability Resolver), issue #193, per
`docs/ai-dlc-foundation-decision-v2.md` §19 ("Resolver 本体より先に正本・
承認・条件言語・path ownership を固定する" — this Epic is the last of the
five Foundation epics that must land before Epic A6 (Lite統合) begins)
Investigation: specs/epic-193-a5-capability-resolver/investigation.md
(INV-001..INV-020; OQ-001..OQ-003, OQ-003 resolved by INV-020)

## Overview

`docs/ai-dlc-foundation-decision-v2.md` §19 fixes Epic A5's inputs
("Project Context / Affected Components — Epic A3 の決定論的導出のみ,
v1 の「Change Characteristics」は削除済み / Registry"), outputs ("Facet
Manifest / Capability Summary / Context Projection / Resolver Evidence"),
and its one governing rule ("曖昧な場合は Block"). Four sibling epics —
A1 (Project Context, schema/canonicalizer/approval-defense), A2 (Capability
Registry, schema/DSL evaluator/`registry_digest`), A3 (Component Path
Ownership, `resolve-component-paths`/`ownership_digest`), and A4 (Facet
Manifest, the three output schemas this feature must produce) — are each
already `Spec-Review-Status: Passed` (investigation.md INV-002) and
content-frozen. This feature is the one that wires those four already-
fixed contracts together into one deterministic script family
(`resolve-project-context.{py,sh,ps1}`, a name Epic A1 already reserved as
protected, investigation.md INV-003) that produces a Feature's Facet
Manifest, (Lite-track) Capability Summary, repository-wide Context
Projection, and this feature's own new Resolver Evidence artifact, and
that is subsequently integrated as a deterministic-script call from
`sdd-bootstrap-interviewer`'s capability interview phase (decision
document v2 §7/§18.4).

## Target Users

- **Epic A5's own future implementation-task author**: the direct consumer
  of this package's `design.md` API / Contract Plan when authoring
  `resolve-project-context.{py,sh,ps1}` and its companion scripts.
- **`sdd-bootstrap-interviewer` maintainers (future Epic A5/A6
  implementation task)**: the direct consumer of REQ-007's caller-side
  integration contract when wiring the capability interview phase.
- **A future Gate-chain or CI caller** that decides when to re-invoke the
  Resolver and when to call A4's `compare-facet-manifest-staleness`
  against two of its outputs (investigation.md OQ-002) — this feature's
  Resolver Evidence output is designed to serve that future caller without
  requiring a second Resolver invocation merely to inspect the first's
  provenance.
- **A project maintainer adopting `capability_enforcement: required`**,
  who needs the Resolver to fail loudly (Block) rather than silently
  publish an under-specified Facet Manifest whenever its own inputs are
  incomplete, contradictory, or malformed.

## Problems

- Without this feature, Epic A4's three schemas (investigation.md INV-004)
  have no producer: nothing in this repository can turn a
  `project-context.yaml` + a Registry + a git diff into a schema-conformant
  `facet-manifest.yaml`. `sdd-bootstrap-interviewer` cannot integrate
  Capability-aware facet generation (decision document v2 §7) without a
  deterministic script to call.
- Epic A1 already reserved a protected script path (`resolve-project-
  context.{py,sh,ps1}`) specifically for this Resolver (investigation.md
  INV-003) — until this feature fixes that script's contract, that
  reservation is an unfillable placeholder and Epic A1's own
  "forced handoff to A2/A5" language (design.md:195-196) is unresolved.
- Decision document v2 §19's "曖昧な場合は Block" instruction has no
  concrete enumeration anywhere upstream: no sibling epic's spec, and no
  ADR, lists the specific conditions under which a Capability Resolver
  should refuse to produce output. Without this feature's REQ-002, a
  future implementer would have to invent that enumeration ad hoc, at
  implementation time, with no spec-time review of its completeness.
- Epic A2's own Registry schema has no field a Lite Capability Summary's
  `required_lite_checks` could be sourced from (investigation.md INV-019)
  — without this feature naming that gap explicitly, a future
  implementation task could silently invent a source (a fabricated
  constant, or a field added to A2's already-reviewed schema without
  going back through A2's own review), each of which would either violate
  decision document v2 §13's Registry-as-sole-source-of-truth rule or
  bypass Epic A2's own change-review process.
- `evaluate-predicate`'s CLI accepts exactly one component's properties
  per call (investigation.md INV-005/INV-012); no sibling epic's spec
  defines how a Feature with more than one affected component should
  combine several per-component evaluations of the same `trigger`/`when`
  predicate into one Feature-level match/no-match. Without this feature
  fixing that rule, two independent implementations of the Resolver could
  disagree on which Capabilities apply to the identical Feature, breaking
  the determinism ADR-0020 item 6 requires of the DSL layer it is built
  on.

## Dependencies

- **Epic A1 (Project Context) — schema shape, canonicalizer CLI, the
  reserved Resolver script path, and (B1) the multi-target transactional
  bundle contract pattern (hard, already-`Passed` dependencies)**: this
  feature's own journaled publication transaction (design.md "Resolver
  publication transactional bundle contract") applies Epic A1's own
  already-fixed `apply-human-copy` multi-target transactional bundle
  contract isomorphically (Epic A1 `design.md:927-1016`) — a design-
  pattern reuse, not a runtime dependency on `apply-human-copy` itself
  (this feature's own journal governs its own Resolver-owned output
  paths, never a human-copy batch). `contracts/project-context.schema.
  json`'s `workflow`/`components`/
  `shared_paths` shapes (investigation.md INV-007) are read, never
  redefined, by this feature — including as this feature's own structural
  validation target for REQ-002's `project-context-validation-failed`
  diagnostic, below (this feature's own JSON-Schema-conformance check, not
  a separate Epic A1 CLI this feature does not otherwise depend on).
  `canonicalize-sdd-yaml`'s stdin/stdout-only,
  YAML-or-JSON-input CLI (no parsed-structure API) is the **only** path
  from YAML bytes to a structure this feature's Resolver ever uses — this
  feature's own Context Projection generation is Epic A1's canonicalizer
  invoked twice in the exact sequence Epic A4 already normatively fixes
  (investigation.md INV-004), never a reimplementation of YAML 1.2 parsing
  or RFC 8785 JCS. This feature's REQ-001 is blocked, in the same sense
  Epic A2's and Epic A4's own REQ-004/REQ-003 already record themselves as
  blocked, until Epic A1's canonicalizer contract's own implementation
  lands. `resolve-project-context.{py,sh,ps1}` and `generated/project-
  context.resolved.json` are Epic A1's own protected-suffix reservation
  (investigation.md INV-003) — this feature does not choose, and must not
  propose an alternative to, that script's name or path.
- **Epic A2 (Capability Registry) — schema shape, DSL evaluator CLI,
  `registry_digest` generator, and (via ADR-0025) the discovery contract
  (hard, already-`Passed` dependencies)**: `contracts/capability-
  registry.schema.json`'s `capabilities[]`/`gates[]` shapes and the shared
  `#/definitions/predicate` are the fixed vocabulary this feature resolves
  Facet Manifest fields from (investigation.md INV-005). This feature
  introduces no new Gate-stage enum value, no new predicate operator, and
  no new Evidence shape. `evaluate-predicate`'s single-component CLI shape
  is reused unmodified (INV-012); `generate-registry-digest --whole` is
  the fragment-selection Epic A4 already fixed on this feature's behalf
  (below). ADR-0025's script-relative-then-git-root-fallback discovery
  procedure is reused unmodified for every `contracts/*` artifact this
  feature's scripts locate, including this feature's own new
  `resolver-evidence.schema.json` — this feature does not invent a second
  discovery algorithm. **An explicit, owned prerequisite this Dependencies
  section records for Epic A6 (adversarial review "B5 lite checks"), not
  merely a Risk this package names and leaves unowned**: Epic A2's own
  Registry schema (content-frozen, `Spec-Review-Status: Passed`) carries
  no field `required_lite_checks` (decision document v2 §6) can be sourced
  from (investigation.md INV-019) — a **future Epic A2 Registry-schema
  revision** (owner: Epic A2's own maintainers, not this feature; scope: a
  new, additively-versioned `capabilities[]` field the current schema's
  `additionalProperties: false` does not yet admit; migration: existing
  Registry instances remain valid until a Capability author opts into the
  new field) is a **named prerequisite for Epic A6's `required`-enforcement
  Lite path to begin** (narrowed by cross-epic addendum, Epic A6
  adversarial verification finding B5, from an earlier revision's claim
  that this gap blocked Epic A6 Lite consumption as a whole — an
  `advisory`-enforcement Lite Feature is not blocked by this gap, Risks
  below), not merely for this feature's own Lite-track output to become
  non-trivial. Until that revision lands, this feature's own `lite-check-
  source-undefined` Block condition (REQ-002), as narrowed by that same
  addendum, is the correct, fail-closed, and *expected* outcome for
  essentially every real `required`-enforcement Lite-track Feature with at
  least one matched Capability (Risks, below) — an otherwise-identical
  `advisory`-enforcement Feature resolves normally instead, contributing
  `[]` (REQ-002, above). This feature does
  not itself propose that schema revision (Non-goals; out of this
  feature's own authority over an already-`Passed`, content-frozen A2
  contract), it only names the prerequisite explicitly, with an owner, so
  Epic A6 does not discover it mid-implementation.
- **Epic A3 (Component Path Ownership) — `resolve-component-paths` CLI,
  `affected_components` output shape, `ownership_digest` full-input
  binding, and the `workflow.capability_enforcement`/ADR-0016 three-state
  derivation rule (hard, already-`Passed` dependencies)**: this feature's
  only route to a Feature's affected components is
  `resolve-component-paths --config <project-context.yaml> [--source-rev
  <rev>] --target-rev <rev> [--include-untracked] --json`
  (investigation.md INV-006) — this feature does not accept, and per
  decision document v2 §19/investigation.md INV-010 must not accept, any
  other route (no self-reported override). This feature's REQ-003 reuses
  the identical `disabled-legacy`/`advisory`/`required` derivation rule
  `check-component-coverage` already implements, sourced from the same
  `workflow.capability_enforcement`/ADR-0016 axis — but this feature's own
  `disabled-legacy` *consequence* deliberately diverges from
  `check-component-coverage`'s graceful no-op (investigation.md INV-013;
  Edge Cases, below, states why).
- **Epic A4 (Facet Manifest) — the three output schemas, the Context
  Projection generation procedure, and the `registry_digest`/
  `ownership_digest` full-input-binding policy (hard, already-`Passed`
  dependencies, content-frozen per `AGENTS.md`'s post-review artifact
  freeze convention)**: `contracts/facet-manifest.schema.json`,
  `contracts/capability-summary.schema.json`, and `contracts/context-
  projection.schema.json` (investigation.md INV-004) are the exact shapes
  this feature's REQ-001 must produce — this feature adds no field to any
  of the three, and does not redefine `context_binding`'s meaning, `capability_
  minimum_enforcement`'s aggregation rule (`max()` of every resolved
  Capability's own `minimum_enforcement`, i.e. "required" iff any matched
  Capability declares it, per A4 Field Definitions), or the stable-sort
  discipline A4's own REQ-001 already mandates for every semantic-output
  array. Epic A4's REQ-003 Context Projection generation procedure
  (two-pass canonicalizer invocation) is "normative for Epic A5's future
  implementation" (A4 `design.md:610`) — this feature implements it
  verbatim, not a variant of it. Epic A4's own choice of
  `generate-registry-digest --whole` (never a `--capability-ids`/
  `--gate-ids` fragment) for `context_binding.registry_digest` is likewise
  already fixed by A4, not by this feature (investigation.md INV-005).
- **ADR-0016 (Workflow Axes Separation)**, **ADR-0017 (Gate Stage Model)**,
  **ADR-0019 (Approval Sidecar Protection, item 3's Resolver-protection
  reservation)**, **ADR-0020 (Conditional Predicate DSL, evaluation
  semantics)**, **ADR-0021 (Context Projection Staleness, `context_binding`
  shape and semantic-output definition)**, and **ADR-0023 (Track Selection
  Contract Migration)** are Accepted, not proposed by this feature; this
  feature transcribes their already-fixed rules into a concrete CLI/output
  contract, it does not re-decide any of them. **ADR-0025 (Registry
  Discovery Contract)** is Accepted in the Epic A2 worktree and explicitly
  names this feature's Resolver as its first anticipated future consumer
  (investigation.md INV-005) — this feature adopts it, it is not proposed
  by this feature.
- **A future epic (plausibly A6/A8) — the caller of `compare-facet-
  manifest-staleness` (soft dependency, explicitly out of this feature's
  own scope, investigation.md OQ-002)**: this feature's Resolver is a pure
  producer of one Facet Manifest instance per invocation; deciding when to
  re-invoke it, and when to diff two of its outputs via A4's
  `compare-facet-manifest-staleness`, is left to that future epic.

## Goals

- **REQ-001** (Resolver script family and pipeline — decision v2 §19 item 1,
  issue #193's own scope line): Author the CLI/orchestration contract (not
  the implementation itself — Phase 2, out of this package's own scope,
  per `AGENTS.md`'s Required Workflow) for `resolve-project-context.{py,
  sh,ps1}` (Python master + `sh`/`ps1` thin dispatchers, matching every
  other cross-runtime primitive this Epic set already establishes,
  investigation.md INV-005/INV-007), under `plugins/sdd-quality-loop/
  scripts/`, at the exact path Epic A1 already reserved
  (investigation.md INV-003):

  ```
  resolve-project-context.py \
    --config <project-context.yaml> \
    [--source-rev <rev>]   # default HEAD, matching resolve-component-paths
    --target-rev <rev> \   # required, matching resolve-component-paths
    [--include-untracked] \
    --feature <feature-slug>   # required — never inferred from cwd
  ```

  `--feature` is **required** and never defaulted or inferred, matching
  this Epic set's own established convention of never expressing a
  meaningful input by omission (A4's `compare-facet-manifest-staleness`
  precedent, investigation.md and A4 `design.md:842-854`) — a Resolver
  invocation with no explicit `--feature` cannot know which
  `specs/<feature>/facet-manifest.yaml`/`capability-summary.yaml` path to
  write, and silently guessing one from the current working directory
  would break the byte-identical-output determinism REQ-005 requires
  across differently-invoked-but-logically-identical runs.

  Processing (design.md's API / Contract Plan gives the full normative
  procedure — revised by adversarial-review findings B1/B2/B3/B4/B6/B7/B8/
  M3/M9; the central change from an earlier revision of this package:
  **every evaluation and every Block determination completes before any
  artifact reaches a live path** — nothing is written incrementally
  mid-procedure): (0) a mandatory crash-recovery scan runs first, on every
  invocation, converging any journal a prior interrupted invocation
  against the identical `--feature` left behind to one of two terminal
  states before any of the following steps begin (`publication-journal-
  recovery` below; design.md "Resolver publication transactional bundle
  contract"); (a) derive the `disabled-legacy`/`advisory`/`required`
  state (REQ-003) from `--config` and refuse immediately if `disabled-
  legacy` or if `workflow.spec_profile`/`workflow.artifact_layout` name
  one of decision document v2 §6's own two explicitly-invalid combination
  rows (REQ-002's `workflow-combination-invalid`); (b) invoke
  `canonicalize-sdd-yaml` (Epic A1) to obtain `source_sha256` and a parsed
  Project Context structure, retaining these bytes as this invocation's
  own fixed snapshot (REQ-002's `snapshot-generation-mismatch` recheck,
  below); (c) build the Context Projection via Epic A4's own two-pass-
  canonicalizer generation procedure, verbatim, **staged in memory, not
  yet written to any live path**; (d) invoke `resolve-component-paths`
  (Epic A3) with the identical `--config`/`--source-rev`/`--target-rev`/
  `--include-untracked` values this invocation received, to obtain
  `affected_components` and `ownership_digest` (retained as this
  invocation's own fixed ownership-source snapshot); if it exits
  non-zero, Block (REQ-002); (e) discover and validate the Registry (Epic
  A2, via ADR-0025), retain its bytes as this invocation's own fixed
  Registry snapshot, and compute `registry_digest --whole`; (f) for
  **every** Registry Capability (matched or not) and **every** affected
  component (in ascending lexicographic `id` order), evaluate that
  Capability's `trigger` via `evaluate-predicate` against that
  component's Context-Projection properties (REQ-001's own multi-
  component matching rule, design.md Design Decisions), recording every
  result with no short-circuit; a Capability is "matched" iff at least
  one affected component's evaluation returns `result: true`; (g) for
  each matched Capability, evaluate its own `conditional_facets[].when`
  predicates the same way, again with no short-circuit; (h) across
  **every** evaluation (f)/(g) performed — matched or unmatched Capability,
  any affected component — Block (`dsl-warn-on-matched-capability`,
  REQ-002) if **any** evaluation's own Evidence tree contains an
  `outcome: "warn"` node anywhere (this invocation's own scope, widened
  from an earlier revision's single-"representative"-branch scope — REQ-
  002, below, and design.md Design Decisions "WARN scope"); (i) branch on
  `workflow.spec_profile`, **before** staging either track's own output:
  on `full`, assemble (stage) the Facet Manifest, computing `conditional_
  facets[]` via the cross-Capability facet-name aggregation rule (design.md
  Design Decisions "facet-name aggregation") from every matched
  Capability's own (g) results, and collecting `required_facets`/
  `gate_ids`/`lite_policy`/`minimum_enforcement`, stable-sorting every
  semantic-output array (Epic A4's own REQ-001 mandate, reused verbatim)
  — **never** a Capability Summary on this track; on `lite`, assemble
  (stage) the Capability Summary only — subject to REQ-002's `lite-check-
  source-undefined` Block condition (investigation.md INV-019) —
  **never** a Facet Manifest or a published Context Projection on this
  track (design.md Design Decisions "track-exclusive publication set");
  (j) assemble (stage) Resolver Evidence (REQ-004) from every (f)/(g)
  result and this invocation's own digests/provenance fields; (k)
  schema-self-validate every staged artifact (REQ-002's `output-schema-
  validation-failed` — if Resolver Evidence itself is what fails this
  check, this invocation writes **nothing** to any live path, not even a
  best-effort Evidence instance, B3, below); (l) re-read the three
  snapshotted sources from (b)/(d)/(e), **also re-deriving
  `affected_components`** (not only `ownership_digest`, B8 correction —
  `ownership_digest` alone cannot detect a diff-only generation change),
  and recompute their digests, Blocking (`snapshot-generation-mismatch`,
  REQ-002) on any digest mismatch or any `affected_components` set
  difference against this invocation's own step-(b)/(d)/(e) snapshot; (m)
  publish this invocation's own entire track-exclusive output set —
  `{facet-manifest.yaml, generated/project-context.resolved.json,
  resolver-evidence.yaml}` on `full`, `{capability-summary.yaml,
  resolver-evidence.yaml}` on `lite` — via a single **journaled
  transaction** (Prepare/Journal/Commit/Post-publication-verification/
  Complete, REQ-002's `artifact-publication-failed` on an in-process
  write/fsync/rename failure, `post-publication-generation-mismatch`
  on a source-generation change detected between (l)'s own recheck and
  this step's own last rename completing — design.md "Resolver
  publication transactional bundle contract," applying Epic A1's own
  already-fixed multi-target transactional bundle contract
  isomorphically; B1 — this replaces an earlier revision's bare per-file
  `temp file + fsync + rename`, which left a crash between two renames
  unrecoverable and rolled back an in-process failure via a bare `unlink`
  that destroyed pre-existing live bytes with no restore), matching Epic
  A4's own REQ-007 storage location for every per-Feature path; on any
  Block at which **this invocation's own publication transaction leaves no
  publication artifact standing** — that is, none of the three was newly
  published by THIS invocation and left in place, whether because none was
  ever renamed or because every rename it did complete was rolled back;
  bytes a PRIOR successful resolve published and this invocation never
  touched do not count as left standing, and neither restricts the class.
  Every Block in REQ-002's sixteen-row taxonomy satisfies this predicate
  except the two REQ-002 names AC-012 excepts, the step-(m) Blocks
  `artifact-publication-failed` and `post-publication-generation-mismatch`
  included, since their own rollback is what leaves nothing standing
  (stated as a predicate rather than
  a step list 2026-08-27, human-approved, ruling D(2): the earlier list
  omitted every Evidence-only Block raised at steps (b)/(d)/(e) and inside
  the (f)–(g) sweep, including the ruling-C(1) and C(2) sites AC-057 and
  AC-058 govern; the rollback carve-out that first accompanied it is
  deleted, because it excluded exactly the two ids the same sentence's own
  step list included, and because REQ-004 states this predicate without
  it) — the invocation writes
  **only** Resolver Evidence's own record of that Block
  (except the self-referential schema-failure case at (k), B3, which
  writes nothing at all). **That one-member write set is published
  directly, not through the journaled transaction** (amended 2026-08-27,
  human-approved, ruling D(2)): a single `temp file + fsync + rename`
  onto `resolver-evidence.yaml`'s own live path, with no staging area and
  no journal. The journaled transaction exists to roll a **multi-target**
  rename sequence back as a unit (B1); a one-file write has no second
  target to be inconsistent with, so the bare rename that was unsafe for
  the output set is exactly sufficient here. On the (0) Block this is not
  merely sufficient but required: the journal that invocation found is
  the very artifact it has just declared unconvergeable, so opening a
  second journal against the same Feature is incoherent. This states
  explicitly what design.md's step-1 Block branches and Main Workflows 4
  below already specify in the same words ("written directly ... no
  staging area exists yet"), closing the AMBIGUITY finding attempt 6
  round 2 raised against the un-scoped earlier wording (approval
  evidence: investigation.md `## Amendment Re-Review Context` ›
  `### Rulings D(1)/D(2)`).
  **Rollback and no-write scope (this rule governs every such statement in
  this package; scoped 2026-08-27, human-approved, ruling D(2)).** Wherever
  this package says a rollback restores *every* rename or *every* target to
  its PRE-transaction state, or that a Block leaves *no* staged artifact and
  *no* artifact on a live path, the subject is the three **publication
  artifacts** — `facet-manifest.yaml`, `capability-summary.yaml`,
  `generated/project-context.resolved.json` — and never
  `resolver-evidence.yaml`. Evidence is excluded by construction rather than
  by exception: AC-012's always-emitted rule excepts exactly two diagnostic
  ids, so on every other Block this invocation leaves its own Block record
  standing at Evidence's live path, written directly per this step, **after**
  any rollback of the publication artifacts has completed. Rolling Evidence
  back would destroy the only record that the rolled-back publication was
  ever attempted, which is the audit obligation REQ-004 exists to guarantee.
  Never a partial Facet Manifest/Capability
  Summary/Context Projection (REQ-002's own "never a partial artifact"
  rule, unchanged in substance from an earlier revision, now enforced
  structurally by this ordering rather than by a per-step promise).

- **REQ-002** (Ambiguous-input Block taxonomy — decision v2 §19's "曖昧な
  場合は Block", issue #193's own "曖昧なケースの Block 動作テスト" Done
  condition): Enumerate every condition under which the Resolver refuses
  to produce a Facet Manifest/Capability Summary/Context Projection,
  fail-closed, as a fixed, machine-readable diagnostic-id table — **closed
  at sixteen rows** (revised from an earlier revision's seven-table-rows-
  plus-one-inline, then fourteen, and from that same revision's incomplete
  coverage of subprocess/parse/output-validation/commit/journal-recovery/
  post-publication-race failures — adversarial review "B3 taxonomy"/"Minor
  Block count"/"B1 atomicity"/"B8 TOCTOU"; no fail-open path exists
  anywhere in this list):

  | Diagnostic ID | Trigger condition |
  |---|---|
  | `disabled-legacy-invocation` | The `--config` target is absent (or the AGENTS.md-marker/default fallback derives `disabled-legacy`, ADR-0016 item 4) — the Resolver refuses before touching Registry/ownership/Context-Projection machinery at all (investigation.md INV-013). **This is a CLI-misuse guard, not a designed pipeline state** (adversarial review "M4 CLI misuse"): a compatible caller (REQ-007) never invokes this Resolver's own process while a Project Context is absent or derives `disabled-legacy` (ADR-0016 item 4 names the Resolver itself as outside that state's own computational domain, investigation.md INV-013); this diagnostic exists purely as a fail-closed response to a caller that invokes it anyway |
  | `publication-journal-recovery` | **NEW (B1).** The mandatory crash-recovery scan every invocation runs before any Registry/ownership/Context-Projection work (REQ-001's own step 0, above) finds a stale transaction journal from a prior, interrupted invocation against the identical `--feature`, and that journal cannot be safely converged to either terminal state (a referenced pre-image backup file is itself missing/unreadable, or a target's current live hash matches neither its journal-recorded PRE nor POST value) — design.md "Resolver publication transactional bundle contract" gives the full recovery algorithm; a journal that *can* be safely converged (the common case) is silently resolved by that same scan and never reaches this diagnostic at all |
  | `workflow-combination-invalid` | `workflow.spec_profile`/`workflow.artifact_layout` name one of decision document v2 §6's own combination matrix's two explicitly-marked "無効な組合せ" rows — `spec_profile == lite` with `artifact_layout != lite-three-file`, or `spec_profile == full` with `artifact_layout == lite-three-file` — checked immediately after Context-schema validity, before any Registry/ownership/projection work (adversarial review "M3 invalid workflow combination") |
  | `project-context-validation-failed` | `--config`'s target file exists, but the structure this feature's Resolver obtains from it via `canonicalize-sdd-yaml` (Dependencies, above — this feature's only route from YAML bytes to a structure) fails **this feature's own** JSON-Schema-conformance check against Epic A1's already-fixed `contracts/project-context.schema.json` (spec-review round-1 remedy, closing a CONTRADICTION finding — a present-but-invalid Context, distinct from an absent one). This is the identical defensive re-validation mechanism this same table's `output-schema-validation-failed` row uses for this feature's own **output** artifacts, applied here to this feature's one **input** artifact; it is structural/shape conformance only — a semantic constraint the schema document itself cannot express (e.g. `components[].id` uniqueness) remains Epic A1's own responsibility at Context-authoring time (investigation.md INV-007) and is not re-checked by this diagnostic |
  | `affected-component-resolution-failed` | `resolve-component-paths` (Epic A3) exits non-zero for any reason (config-shape error, unresolvable rev, unattainable merge-base, NFC-collision, exceeded rename limit, TOCTOU mismatch) — an UNOWNED/OVERLAP classification present in a *successful* `resolve-component-paths` exit is data, not this condition, per Epic A3's own "classification results are data, not failure by themselves" rule; this feature does not reimplement `check-component-coverage`'s own Fail-condition logic. This diagnostic's own `detail` is a canonical, Resolver-owned sentence (repo-relative path, upstream exit code) — never the underlying script's own raw stderr text quoted verbatim (adversarial review "M8 stderr parity") |
  | `registry-validation-failed` | The located Registry fails Epic A2's own `validate-capability-registry` checks, or (defensively) `evaluate-predicate` returns `PREDICATE_SCHEMA_ERROR` against an already-validated Registry |
  | `contract-discovery-failed` | Any `contracts/*` artifact this feature's scripts need (Registry, its schema, any of Epic A4's three schemas, this feature's own `resolver-evidence.schema.json`) fails ADR-0025's discovery procedure (neither the script-relative packaged copy nor the git-root fallback resolves, or the artifact's own version check fails) |
  | `canonicalizer-invocation-failed` | Any `canonicalize-sdd-yaml` subprocess invocation this feature's Resolver makes (Project Context canonicalization, Context Projection's second pass, Registry-fragment/ownership-fragment digest inputs) exits non-zero |
  | `dependency-subprocess-failed` | Any other dependency subprocess this Resolver invokes (`evaluate-predicate`, `generate-registry-digest`) exits non-zero for a reason not already named by a more specific row above (adversarial review "B3 taxonomy" — the closed-enum catch-all for a generic, otherwise-unnamed dependency-subprocess failure) |
  | `dependency-output-malformed` | Any dependency subprocess this Resolver invokes exits zero but its stdout does not parse as the JSON/hex-digest shape that subprocess's own contract promises (non-JSON stdout, a JSON parse error, or well-formed JSON missing a contractually-required key) (adversarial review "B3 taxonomy"). **Also fires (ruling C(2), human-approved 2026-08-26, closing the cross-model panel's fail-open finding): when `resolve-component-paths` returns an `affected_components[]` entry naming a component id absent from this invocation's own Context Projection — a dependency result inconsistent with the canonical Context it was derived against. REQ-001 steps (f)-(g) MUST NOT evaluate such an entry against an empty or defaulted properties document; the inconsistency Blocks with this id before any predicate evaluation of that entry (AC-058; approval evidence: investigation.md `## Amendment Re-Review Context` › `### Rulings C(1)/C(2)`)** |
  | `dsl-warn-on-matched-capability` | **Any** evaluation this invocation performs — any Registry Capability's own `trigger` evaluation against any affected component, matched or unmatched, or any matched Capability's own `conditional_facets[].when` evaluation against any affected component — contains at least one `outcome: "warn"` node anywhere in its evidence tree (design.md Design Decisions states the rationale, layered on top of, and never contradicting, ADR-0020's own DSL-evaluator-level "WARN is not an error" rule). **This condition's own quantifier is "any evaluated branch," matched or unmatched, representative or not** — an earlier revision scoped this row to a single "representative" evaluation per matched Capability only; adversarial review "B2 WARN" found that scoping let a WARN-producing, potentially-false-negative evaluation on any other branch silently aggregate into a clean `false`/`applied: false` outcome, under-resolving the Feature. The diagnostic-id string itself is unchanged for enum stability |
  | `lite-check-source-undefined` | **Narrowed by cross-epic addendum (Epic A6 adversarial verification, finding B5 — requirements.md Dependencies, below).** `workflow.spec_profile == lite` **and** `workflow.capability_enforcement == required` (REQ-003's derived `state`) **and** at least one matched Capability's own Registry entry has its `lite_policy.required_lite_checks` key **absent** (investigation.md INV-019). This trigger is a conjunction of all three conditions, not merely "Lite track with an unsourceable matched Capability": under `advisory` enforcement, an absent `required_lite_checks` key contributes an empty `[]` to that Capability's own share instead of Blocking; a `required`-enforcement Capability whose key is **present** but whose own array is empty is a valid, explicit "no Lite checks required" declaration and does not Block; and zero matched Capabilities is non-Blocking under either enforcement state (Edge Cases, "zero affected components") — this diagnostic's own quantifier is deliberately narrower than REQ-002's other "any"-scoped rows |
  | `output-schema-validation-failed` | This invocation's own staged Facet Manifest/Capability Summary/Context Projection/Resolver Evidence fails a defensive re-validation against its own governing schema before publication (adversarial review "B3 taxonomy"). **If Resolver Evidence itself is the artifact that fails this check, this invocation writes NOTHING to any live path, not even a best-effort, fields-omitted Evidence instance** (B3, revised — an earlier revision wrote such a best-effort instance; adversarial review "B3 best-effort Evidence removed" found it carries no guarantee of re-conforming to its own schema, making it exactly the schema-invalid live artifact this check exists to prevent) |
  | `snapshot-generation-mismatch` | Immediately before this invocation's own publication, a re-read of the Project Context/ownership-source/Registry bytes this invocation snapshotted at steps (b)/(d)/(e) (REQ-001, above), **and a fresh re-derivation of `affected_components`**, no longer matches that snapshot — a generation-mixed input set. **Now fires on an `affected_components` set difference alone, even when every digest including `ownership_digest` still matches** (B8, revised — `ownership_digest` is a blunt, project-wide "the ownership *config* changed" signal, Epic A3 `requirements.md:530-569`, and does not itself change when only the underlying diff shifts which components are affected between this invocation's own two `resolve-component-paths` calls; adversarial review "B8 TOCTOU"). **Second trigger site (ruling C(1), human-approved 2026-08-26, sanctioning the detection recheck two independent cross-model panels converged on): detection-only and mid-pipeline — immediately after REQ-001 step (e)'s own two dependency invocations (`validate-capability-registry` and `generate-registry-digest --whole`) complete, before any step-(f) evaluation begins, a re-read of the Registry bytes alone no longer matching the raw-bytes digest retained at step 5's own first read (or that re-read itself failing, which is at least as suspicious as a byte difference) Blocks with this same id, closing the unbound-reads window in which each of those dependencies independently re-discovers and re-reads the Registry with no binding to this invocation's own snapshot (AC-057; approval evidence: investigation.md `## Amendment Re-Review Context` › `### Rulings C(1)/C(2)`)** |
  | `artifact-publication-failed` | A `write`/`fsync`/`rename` failure caught **in-process** during this invocation's own publication transaction's Prepare/Journal/Commit phases (design.md "Resolver publication transactional bundle contract"). **Rollback of any already-completed rename in the same commit sub-sequence is now journal-based, restoring that target's own PRE-transaction live bytes — never a bare `unlink`, which an earlier revision used and which destroyed pre-existing live bytes with no restore path** (B1, revised, closing that gap; a rollback failure, if the in-process attempt cannot itself fully complete, is recorded in this same diagnostic's own `detail` and safely completed by the next invocation's own crash-recovery scan instead — never a **seventeenth** diagnostic-id value of its own; the ordinal is corrected 2026-08-27 from a stale "nineteenth" that predated this enum's closure at sixteen rows, and names no new id either way) |
  | `post-publication-generation-mismatch` | **NEW (B8).** Immediately after every rename in this invocation's own publication transaction has succeeded — closing the "post-recheck race," the window between the pre-publication recheck (`snapshot-generation-mismatch`, above) and the last rename actually completing — a **final** re-read of the same three sources plus a fresh `affected_components` re-derivation no longer matches the pre-publication recheck's own snapshot. This invocation itself rolls every just-completed rename back to its own PRE-transaction state via the transaction's own journal before returning this Block — **the three publication artifacts only, per REQ-001 step (m)'s rollback-and-no-write scope rule; `resolver-evidence.yaml` is never rolled back and instead receives this Block's own record, written directly after the rollback completes (AC-012)** — (design.md "Resolver publication transactional bundle contract," Post-publication verification) — the sole diagnostic-id row whose own trigger condition is detected only *after* every live rename in the batch has already, if briefly, succeeded |

  Every Block exits non-zero (REQ-002's own exit-code contract, design.md)
  and writes **no** `facet-manifest.yaml`, `capability-summary.yaml`, or
  `project-context.resolved.json` — never a partial or schema-invalid
  instance of any of the three, and never any of the three left partially
  written (including, for `post-publication-generation-mismatch`, a
  written-then-rolled-back one — the journal-based rollback above restores
  the pre-invocation state before this invocation's own exit) even when
  the Block fires *after* this invocation began staging one of them
  (REQ-001's own staged-generation/journaled-transactional-publication
  ordering, above, is what makes this structurally true rather than a
  per-step promise this feature's own implementation could violate,
  adversarial review "B1 atomicity"). Resolver Evidence (REQ-004) is still
  written on every Block, with **two** named exceptions: `disabled-legacy-
  invocation` (whose own Evidence record is minimal by construction,
  recording only the fact of the out-of-contract invocation itself) and
  the self-referential `output-schema-validation-failed` case immediately
  above (which writes no live artifact of any kind, B3, revised) —
  mirroring `check-component-
  coverage`'s own NEW-001 "always emit an evidence record, never a bare
  skip line" discipline (investigation.md INV-006). Diagnostic lines follow
  this Epic set's own established `<producer>: <check-id>: <detail>`
  format (Epic A2's `registry: <check-id>: <detail>`, Epic A4's
  `facet-manifest: <check-id>: <detail>`): `capability-resolver:
  <check-id>: <detail>`, and every `<detail>` is a canonical, Resolver-
  owned sentence, never a verbatim quotation of any dependency
  subprocess's own stderr text (adversarial review "M8 stderr parity").

- **REQ-003** (State-awareness — decision v2 §2/§10, ADR-0016 item 4,
  issue #193's own dependency line "Epic A2（Registry/DSL）、A3（ownership
  導出）、A4（Manifest schema）"): Derive the identical three-state value
  (`disabled-legacy`/`advisory`/`required`) `check-component-coverage`
  already derives, from the identical source
  (`workflow.capability_enforcement`/the ADR-0016 file-absence fallback,
  investigation.md INV-006/INV-007) — never from file presence of any
  other kind (the anti-pattern ADR-0016 forbids). Unlike
  `check-component-coverage`, the Resolver's own `disabled-legacy`
  consequence is REQ-002's `disabled-legacy-invocation` Block, not a
  graceful no-op (investigation.md INV-013 states the ADR-0016-item-4-
  grounded reason this feature's own behavior deliberately diverges from
  A3's) — and, per REQ-002's own row above, that Block is itself framed as
  a CLI-misuse guard against a caller-contract violation, never a
  designed "disabled-legacy mode" this Resolver gracefully executes.
  `advisory` and `required` are **not** distinguished by this feature's
  own Resolver output content — the same inputs under either state
  produce byte-identical output across this invocation's own **track-
  exclusive output set** (REQ-001, REQ-005, below — the three Full-track
  artifacts `facet-manifest.yaml`/`project-context.resolved.json`/
  Resolver Evidence, or the two Lite-track artifacts `capability-summary.
  yaml`/Resolver Evidence, never all four named artifacts as if they
  co-existed in one invocation — adversarial review "M5 byte-identical
  scope"/"B4 Lite publication" correction to an earlier revision that
  named all four as if a single invocation ever produced all of them);
  within that set, only the following **enforcement-derived fields** —
  everywhere they occur, in whichever artifact of the set carries them —
  differ:
  Resolver Evidence's own `state` field; and, in **every** artifact whose
  schema carries them, the two enforcement-derived `context_binding`
  digest fields `full_context_revision` and `projection_sha256`; and, in
  `generated/project-context.resolved.json`, its `workflow` block and its
  `source_sha256`. (Amended 2026-08-24, human-approved: each digest is a
  hash of canonical bytes that themselves
  encode `workflow.capability_enforcement` — the canonical Project
  Context text and the canonical Context Projection text, which copies
  `workflow` verbatim — so their identity across the pair is internally
  impossible for any correct implementation. **Widened 2026-08-27,
  human-approved, ruling D(2)**: the 2026-08-24 wording scoped the
  exception to "Resolver Evidence's own" copies of those two digests,
  which left the same impossibility asserted of two sibling Full-track
  artifacts, so attempt 8's reviewers both independently found AC-016
  unsatisfiable on that track. The correct scope is derivable from
  investigation.md INV-004's own schema field lists and introduces no new
  behaviour: `facet-manifest.yaml`'s `context_binding` carries the
  identical two digests, and the Context Projection **is** the canonical
  text this very sentence says copies `workflow` verbatim, so it carries
  `workflow.capability_enforcement` itself plus `source_sha256`, the hash
  of the differing canonical Project Context. The **Lite track is
  untouched** by this widening: `capability-summary.yaml`'s schema carries
  no `context_binding` at all, so on that track the exception still
  reduces to Resolver Evidence's three fields exactly as before.
  Byte-identity is therefore scoped to everything except the
  enforcement-derived fields enumerated above.) — differ
  between the `advisory` and `required` fixture of an otherwise-identical
  pair (`capability_minimum_enforcement`'s downstream interpretation at
  Gate-execution time differs, and that computation is explicitly out of
  this feature's own scope per A4's own Field Definitions, Dependencies
  above) — this feature's state-awareness therefore collapses, for its
  own purposes, to a two-way branch: `disabled-legacy` (refuse) vs.
  `{advisory, required}` (resolve normally, recording which of the two
  applied in Resolver Evidence's own `state` field for downstream
  auditability, even though it does not change this invocation's own
  output content). **This byte-identical guarantee has exactly one named
  exception (cross-epic addendum, Epic A6 adversarial verification
  finding B5, requirements.md Dependencies, below): REQ-002's
  `lite-check-source-undefined` diagnostic, as narrowed by that addendum,
  is itself keyed to `capability_enforcement == required`, so a
  Lite-track fixture pair that is otherwise identical except for
  `advisory` vs. `required` and that also has at least one matched
  Capability's `lite_policy.required_lite_checks` key absent produces
  divergent output by design — the `required` member of that pair Blocks
  while the `advisory` member resolves normally. Every other
  otherwise-identical `advisory`/`required` fixture pair, including every
  fixture where no matched Capability's key is absent, remains
  byte-identical as stated above (AC-016/TEST-016 explicitly exclude this
  one diagnostic branch from their own scope).**

- **REQ-004** (Resolver Evidence — decision v2 §19's fourth output,
  investigation.md INV-018): Define `contracts/resolver-evidence.schema.
  json` (JSON Schema draft-07, matching every existing `contracts/*.
  schema.json`'s `$schema`/`$id` convention, investigation.md INV-011)
  fixing: `schema` (`const: "sdd-resolver-evidence/v1"`), `feature`
  (string, `^[a-z0-9][a-z0-9-]*$`, matching every other `feature`-typed
  field this Epic set already fixes), `state` (enum:
  `disabled-legacy`/`advisory`/`required`, REQ-003), `context_binding`
  (identical shape to Epic A4's own `contextBinding` definition, embedded
  by structural reference rather than redefined — the same
  reuse-not-redefine discipline Epic A4 itself already applies to Epic
  A2's Evidence-node shape, investigation.md INV-004 — `dependency_
  pointers[]`/`resolver.version`/`resolver.rule_set_revision` each follow
  a fixed, single-source-of-truth canonical-derivation rule design.md's
  Data Plan states in full, adversarial review "B9"), `capability_
  evaluations` (array, **exactly** one entry per Registry Capability
  **regardless of whether it matched** — "評価した全 capability... の記録"
  (issue #193) means every Capability the Resolver actually evaluated, not
  only the matched subset, and "exactly" means this array's own
  cardinality and `capability_id` set are bound to the discovered
  Registry's own `capabilities[]` set, not merely free of duplicates
  (adversarial review "B6 Evidence completeness" — an earlier revision of
  this REQ left this binding implicit) — each entry `{capability_id,
  matched: boolean, trigger_evaluations: [{component_id, result,
  evidence[]}, ...]}` with **exactly** one `trigger_evaluations[]` element
  per affected component (exact-set-bound to `affected_components`, in
  ascending lexicographic order — including the zero-affected-component
  case, where this array is `[]` for every Capability, Edge Cases below,
  "M9 zero-component correction"), and, for a matched Capability only, an
  additional `conditional_facet_evaluations: [{facet, declaration_index,
  applied, evaluations: [{component_id, result, evidence[]}, ...]}]` with
  exactly one element per that Capability's own declared `conditional_
  facets[]` array *entry* — **keyed by `declaration_index` (0-based array
  position), never by `facet` value** (B7 predicate-instance keying,
  revised: Epic A2's own Registry schema does not forbid two entries
  sharing one `facet` name within a single Capability's own declaration,
  so this array's own cardinality is bound to that Capability's own
  `conditional_facets[]` *length*, not its own distinct-facet-name count
  — a Capability declaring the identical `facet` name twice produces
  **two** entries here, `declaration_index: 0` and `declaration_index:
  1`), and, within each, exactly one `evaluations[]` element per affected
  component (the identical exact-set binding, one level deeper);
  `matched`/`applied` are each **bidirectionally** consistent with their
  own governing array (`matched: true` iff at least one `trigger_
  evaluations[].result` is `true`, and `matched: false` iff every one is
  `false` — both directions checked, not only the "at least one true"
  direction an earlier revision of this REQ's own validator checked, B6),
  and `capability_evaluations[]`'s own `capability_id` values, each
  entry's own nested `component_id` values, and each entry's own nested
  `declaration_index` values (**not** `facet` values, which are legitimately
  non-unique within one Capability, B7), are each unique within their own
  governing array (nested-ID uniqueness, B6); and
  `diagnostics` (array of `{id (REQ-002's own sixteen-value enum),
  detail, severity: "block"|"warn"}`, recording **every** diagnostic-
  worthy condition this invocation encountered, not only the first/fatal
  one, mirroring ADR-0020's own "no short-circuit, every result recorded"
  discipline extended by this feature to its own diagnostic surface).
  **This array's own `severity` value is closed and fully determined by
  which of REQ-002's sixteen ids is present, with exactly one exception**
  (spec-review round-1 remedy, closing an AMBIGUITY finding on this
  array's own warn/block cardinality): every id **except**
  `dsl-warn-on-matched-capability` appears **at most once**, always with
  `severity: "block"` (the one condition that itself caused, or jointly
  caused, this invocation's own fail-closed exit). `dsl-warn-on-matched-
  capability` alone can appear **more than once**: this feature's own
  "no short-circuit" evaluation records one `severity: "warn"` entry
  **per individual `outcome: "warn"` node** encountered anywhere in this
  invocation's own evaluation (ADR-0020's own DSL-evaluator-level "WARN
  is not an error" scope — each such entry's own `detail` names that one
  node's `capability_id`/`component_id`/(`declaration_index`, only for a
  `conditional_facets[].when` node) location, so no two `severity: "warn"`
  entries ever share an identical `detail`), **plus exactly one
  additional `severity: "block"` entry** with the identical id, whose own
  `detail` is this feature's own fixed summary sentence (never identical
  to any `severity: "warn"` entry's own per-node `detail`, preserving
  this array's own `(id, detail)` uniqueness, AC-024), recording that
  this invocation blocked overall because at least one such node exists.
  A `dsl-warn-on-matched-capability` id therefore never appears with
  **only** `severity: "warn"` entries and no `severity: "block"` summary
  entry — with exactly one exception (amended 2026-08-24, human-approved,
  reconciling this sentence with this REQ's own "recording **every**
  diagnostic-worthy condition this invocation encountered" mandate above,
  in the "or jointly caused" shape this REQ already uses for block-entry
  causation): `severity: "warn"` entries already collected before an
  evaluation abort lawfully appear alongside that abort's own
  **different-id** `severity: "block"` summary entry — with no same-id
  `severity: "block"` summary entry, since the invocation did not block
  because of the warn nodes — when the abort and the warns are jointly
  caused by the same evaluation pass. One "evaluation pass" here is
  exactly this invocation's own single steps (f)–(g) evaluation sweep
  (REQ-001, above — the one no-short-circuit `evaluate-predicate`
  traversal over every Registry Capability and affected component), an
  "evaluation abort" is a REQ-002 Block raised from within that sweep
  before step (h) is reached, and "jointly caused" means the
  already-collected warn nodes and the abort arose from that identical
  sweep — never warn nodes carried over from any other invocation or
  source. No other id ever carries `severity: "warn"` at all (AC-056).
  Resolver Evidence is written on **every** invocation, success or Block
  (REQ-002), **with the sole exception of a Block reached because
  Resolver Evidence itself fails its own schema self-validation** (B3,
  revised — that one case writes nothing at all, never a best-effort,
  fields-omitted instance, REQ-002's `output-schema-validation-failed`
  row above), mirroring `check-component-coverage`'s own always-emit
  discipline (investigation.md INV-006). (This "sole exception" and
  REQ-002's "two named exceptions" above are not in conflict and never
  were: this sentence enumerates the exceptions to writing an Evidence
  record **at all**, of which B3 is the only one, while REQ-002 enumerates
  the exceptions to writing the **full** form, of which
  `disabled-legacy-invocation` — which writes a minimal record rather than
  none — is the second. AC-012 states both scopes in one row.)
  **How Evidence reaches its live path depends on how many artifacts this
  invocation is publishing** (amended 2026-08-27, human-approved, ruling
  D(2), closing the AMBIGUITY finding attempt 6 round 2 raised; approval
  evidence: investigation.md `## Amendment Re-Review Context` ›
  `### Rulings D(1)/D(2)`). When Evidence is published **alongside** the
  rest of a track's output set, it travels through the identical staged-
  generation/journaled-transactional-publication mechanism REQ-001 fixes
  for every other artifact, and is not exempt from it merely because it is
  written on most every path (adversarial review "B1 atomicity"): a crash
  mid-sequence must not leave Evidence claiming a publication its
  siblings never completed. When Evidence is the **only** thing this
  invocation writes — any Block at which no publication artifact is left
  standing, except (k)'s self-referential case, stated as that predicate
  rather than a step list (2026-08-27, human-approved, ruling D(2); see
  REQ-001 step (m), which carries the same correction and the reason) —
  REQ-001 step (m) fixes a single
  `temp file + fsync + rename` directly onto its live path, with no
  staging area and no journal, because a one-member write set has no
  sibling to be inconsistent with. Design three deterministic, stdlib-only-Python-
  master-plus-`sh`/`ps1`-wrapper companion scripts (matching Epic A4's
  own `validate-facet-manifest`/etc. precedent, investigation.md
  INV-011): `validate-resolver-evidence.{py,sh,ps1}` (schema-conformance
  **and** exact-set/cardinality/bidirectional-consistency/**provenance-
  binding** check, against its own closed, **twelve**-value check-id
  enum, independent of REQ-002's own enum — adversarial review "Minor
  diagnostic namespace"/"B6 provenance binding"; design.md's own
  `validate-resolver-evidence` contract section lists every check-id — no
  `.js` wrapper — a structural validator, not a cross-runtime-hashed
  digest primitive). **This validator never trusts a caller-supplied
  `--registry`/`--affected-components` argument as ground truth by
  itself** (B6, revised — an earlier revision did, letting a caller pass
  a different, smaller Registry or an arbitrary affected-component subset
  alongside a self-consistent-but-wrong Evidence instance and have it
  pass): by default it self-resolves the Registry via ADR-0025 discovery
  and derives the affected-component set from the Evidence instance's own
  `context_binding.dependency_pointers[]` (cross-checked against a
  co-located Facet Manifest's own `dependency_pointers[]` when present),
  requiring any explicit `--registry`/`--affected-components` override to
  still match the Evidence instance's own recorded `registry_digest`/
  `dependency_pointers[]` — design.md's own `validate-resolver-evidence`
  contract section gives the full provenance-binding procedure.

- **REQ-005** (Idempotency and determinism — "**Python master equivalence
  + sh↔ps1 dual-runtime parity**", decision v2 §19's own "同一入力 → 同一
  出力（byte-identical）の決定論保証" and ADR-0020 item 6's Resolver-purity
  requirement, extended by this feature from the DSL layer to the whole
  Resolver, terminology sharpened per adversarial review "OK-3
  reinforcement"): The same `--config`/`--source-rev`/`--target-rev`/
  `--feature` input, against the same repository state, produces
  byte-identical output across this invocation's own **track-exclusive
  output set** (REQ-001/REQ-003, above — `facet-manifest.yaml`/
  `project-context.resolved.json`/Resolver Evidence on the Full track, or
  `capability-summary.yaml`/Resolver Evidence on the Lite track; never all
  four artifacts as a single set, since no one invocation ever produces
  more than one of `facet-manifest.yaml`/`capability-summary.yaml` — B4
  correction to an earlier revision) — across repeated invocations of the
  same runtime (**Python master equivalence**), and across `.py`/`.sh`/
  `.ps1` invocations of the identical input (**dual-runtime parity**,
  matching every other cross-runtime primitive this Epic set already
  establishes) — including every diagnostic line's own `<detail>` field,
  which is itself a canonical, Resolver-owned sentence never containing
  any dependency subprocess's own raw, potentially-OS-specific stderr
  text (adversarial review "M8 stderr parity" — a dependency subprocess's
  own stderr remains visible to a human operator on the terminal exactly
  as that subprocess itself already writes it, but never participates in
  this feature's own byte-identity comparison). Every semantic-output
  array this feature's Resolver writes is stable-sorted (Epic A4's own
  REQ-001 mandate, reused verbatim — Dependencies, above); `capability_
  evaluations[]` and `diagnostics[]` (REQ-004, this feature's own new
  arrays, not covered by Epic A4's mandate since they live in a schema
  Epic A4 does not define) are likewise stable-sorted
  (`capability_evaluations[]` by `capability_id`, `diagnostics[]` by
  `(id, detail)` tuple) — this invocation's own output is additionally
  **invariant to the input order** of `affected_components[]` (a
  metamorphic property, adversarial review "M10 metamorphic completeness"
  — since this feature's own evaluation order is fixed at ascending
  lexicographic `component_id`, feeding the identical affected-component
  set in a different order produces byte-identical output). This
  feature's Resolver reads the clock, the network, and no provider API
  anywhere in its own orchestration logic — the identical "no code path
  can read the clock, the network, or invoke a provider API" guarantee
  ADR-0020 already establishes for the DSL evaluator itself extends to
  this feature's own orchestration layer wrapping it (no
  `datetime.now()`-derived value, no environment-variable-derived
  nondeterminism beyond the fixed, documented discovery-contract fallback
  ADR-0025 already specifies).

- **REQ-006** (Tests — decision v2 §19's own "同一 fixture での sh/ps1
  出力 byte-identical テスト" and "曖昧ケースの Block 動作テスト" Done
  conditions): Design `tests/*.tests.sh`/`.tests.ps1` pairs and fixture
  data under `tests/fixtures/capability-resolver/`, covering, at minimum,
  the ten items design.md's own Test Strategy fixes at contract level
  (adversarial review-expanded from an earlier revision's eight — new
  items 9/10 add the metamorphic-completeness and live-caller-contract
  suites below; item 2's own Block matrix and item 3's own match/WARN
  matrix are individually expanded in place): a full match/no-match/
  conditional/WARN/Block fixture matrix — (a) a Capability whose `trigger`
  matches at least one affected component (match); (b) a Capability whose
  `trigger` matches none (no-match); (c) a matched Capability with a
  `conditional_facets[].when` that itself matches (`applied: true`) and
  one that does not (`applied: false`, `reason` naming every contributing
  Capability — REQ-001's own facet-name aggregation rule, design.md
  Design Decisions); (d) one fixture per **any-branch** WARN case this
  feature's evaluation model can produce — matched-Capability-trigger-
  WARN, **unmatched-Capability-trigger-WARN**, and matched-Capability-
  conditional-facet-WARN — each independently Blocking
  (`dsl-warn-on-matched-capability`, REQ-002's own widened quantifier; an
  earlier revision of this REQ described a non-Blocking "non-determining"
  WARN case, which no longer exists under REQ-002's own any-branch scope,
  adversarial review "B2 WARN"); (e) one fixture per REQ-002 diagnostic-id
  row (sixteen total, including the two NEW `publication-journal-
  recovery`/`post-publication-generation-mismatch` rows, B1/B8), each
  independently testable; (f) a predicate-instance same-`facet`-name
  aggregation fixture pair — one cross-Capability, one same-Capability
  (design.md Design Decisions "facet-name aggregation, predicate-instance
  keyed", adversarial review "B7"); (g) a zero-affected-component fixture
  confirming every Registry Capability's own `trigger_evaluations[]` is
  `[]` and `capabilities: []` results (Edge Cases, below, "M9
  zero-component correction"); (h) the all-true/false-
  combination, component-order-permutation, multiple-true, and nested-
  array-completeness metamorphic fixtures design.md's own Test Strategy
  item 9 fixes in full (adversarial review "M10 metamorphic completeness")
  — plus REQ-005's own dual-runtime parity suite, REQ-003's `disabled-
  legacy`/`{advisory,required}`-byte-identical-content proof, a
  journal-based crash-recovery fixture pair (B1) and a provenance-binding
  fixture pair for `validate-resolver-evidence` (B6, design.md Test
  Strategy items 2/8), and a live-`SKILL.md` caller-contract suite
  (design.md Test Strategy item 10, REQ-007, below, adversarial review
  "M6 caller integration") asserting non-invocation while Context-absent,
  single-invocation on Context-present, Block-surfacing on a REQ-002
  Block, and a position-sensitive anchor-fingerprint drift check against
  this package's own cited insertion-point anchor. Discovery-contract
  fixtures (installed-standalone-plugin layout, one per runtime — **three
  total, the direct product of one layout case × three runtimes**, never
  nine, adversarial review "Minor discovery fixture count") reuse Epic
  A2's own three-fixture pattern (investigation.md INV-005), applied to
  this feature's own new `resolver-evidence.schema.json` in addition to
  the artifacts Epic A2/A4 already cover.

- **REQ-007** (Caller-side integration contract — decision v2 §7/§18.4,
  issue #193's own "sdd-bootstrap-interviewer への統合" scope line and its
  Done condition "interviewer 統合後も既存 bootstrap フロー（Context 不在
  時）が event-identical であるテスト"): Document (design-only; this
  package does not edit `plugins/**`, this task's own hard boundary,
  investigation.md INV-017/OQ-003) the target integration contract for
  `sdd-bootstrap-interviewer`'s capability interview phase: (a) runs only
  when a Project Context is present and its derived state is not
  `disabled-legacy` (REQ-003) — when absent, the existing bootstrap flow
  is unchanged, event-identical to today's behavior (issue #193's own Done
  condition, decision document v2 §4.3's Orchestration Compatibility
  Test); (b) invokes `resolve-project-context` (REQ-001) once, after track
  detection and before any Facet-dependent layer is generated — **the
  concrete insertion point is the live `plugins/sdd-bootstrap/skills/
  sdd-bootstrap-interviewer/SKILL.md`'s own `### Full-Profile Layer
  Interview` heading (`SKILL.md:60` at this package's own design-
  authoring time), immediately after `## Intake And Investigation`'s own
  step 8 (`SKILL.md:58`) and before that heading's own Facet-dependent
  layer generation begins** (design.md Design Decisions "caller insertion
  point" gives the full file:line citation and rationale, resolving
  investigation.md OQ-003, adversarial review "M6 caller integration");
  (c) asks
  the interviewer's own questions only for Capability-relevant unknowns
  the Resolver's output could not itself determine (decision document v2
  §18.4: "質問は既知情報を再質問しない / 適用 Capability だけ / 1 pass 最大
  15 問 / 未解決は Open Questions 保存 / 再開可能"); (d) on a REQ-002 Block,
  surfaces the Resolver's own diagnostic to the interview session rather
  than silently falling back to a non-Capability-aware flow (mirroring
  decision document v2 §7's "非対応 runtime の扱い" fail-closed principle:
  "legacy mode へ黙ってフォールバックしてはならない", applied here to a
  Resolver Block rather than a missing-runtime condition specifically, by
  the same "never silently degrade" logic). No independent
  capability-interviewer or facet-generator skill is proposed (decision
  document v2 §7 explicitly retires that v1-era design: "廃止: 独立した
  capability-interviewer / 独立した facet-generator").

- **REQ-008** (Documentation/versioning discipline — matching every
  sibling epic's own REQ, e.g. Epic A3 REQ-008, Epic A4 REQ-008): every
  implementation task this package's future task phase schedules lands
  its own `CHANGELOG.md` `## Unreleased` entry citing #193; no new ADR is
  authored by this feature (ADR-0016/0017/0019/0020/0021/0023/0025
  already normatively cover this feature's entire scope — Dependencies,
  above); a grep-based self-check confirms no version string is mutated
  anywhere in this feature's diff outside a `scripts/bump-version.sh`
  invocation, matching Epic A3's own precedent.

## Non-goals

- Building `resolve-project-context.{py,sh,ps1}` (or any of its companion
  scripts) itself, or producing any live `facet-manifest.yaml`/
  `capability-summary.yaml`/`project-context.resolved.json`/Resolver
  Evidence instance for a real Feature — this package (`Spec-Review-
  Status: Pending`) fixes the contract only; implementation is Phase 2,
  scheduled by a future `tasks.md` this package does not author
  (`AGENTS.md`'s Required Workflow).
- Editing `contracts/facet-manifest.schema.json`,
  `contracts/capability-summary.schema.json`,
  `contracts/context-projection.schema.json`, `contracts/capability-
  registry.schema.json`, `contracts/project-context.schema.json`, or any
  other Epic A1/A2/A3/A4 contract file — this feature only reads their
  already-fixed shapes (Dependencies, above) and adds one new contract
  file of its own (`contracts/resolver-evidence.schema.json`, REQ-004).
- Adding a `required_lite_checks`-sourcing field to `contracts/
  capability-registry.schema.json` — investigation.md INV-019's gap is
  named and its consequence (a Block condition, REQ-002) is fixed by this
  feature; the field itself, if one is ever added, is Epic A2's own
  schema-revision decision, not this feature's.
- Implementing, or re-specifying, `check-component-coverage`'s own six
  Fail conditions — this feature's `affected-component-resolution-failed`
  Block condition (REQ-002) fires only on `resolve-component-paths`'s own
  non-zero exit, never on an UNOWNED/OVERLAP classification present in a
  successful exit (Dependencies, above); that classification's Gate-time
  consequence remains entirely `check-component-coverage`'s own,
  already-fixed responsibility (Epic A3).
- Implementing `compare-facet-manifest-staleness`'s caller, or deciding
  when it runs — Epic A4 owns the script itself; a future epic owns when
  it is invoked (investigation.md OQ-002).
- Computing decision document v2 §10's full "effective enforcement =
  max(approved project policy, capability minimum, runtime override)" —
  this feature computes only `capability_minimum_enforcement` (the
  Registry-derived term), matching Epic A4's own Field Definitions
  boundary verbatim (Dependencies, above); the full computation, combining
  this feature's output with `workflow.capability_enforcement` and any
  runtime override, is a Gate-execution-time computation, out of this
  feature's scope.
- Editing `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/
  SKILL.md`, or any other file under `plugins/**` — REQ-007 documents the
  target integration contract only; the actual edit is a future
  implementation task's own responsibility (investigation.md INV-017/
  OQ-003), applied as a staged, reviewed change regardless of the target
  file's then-current guard-protection status.
- Authoring a new ADR — ADR-0016/0017/0019/0020/0021/0023/0025 already
  normatively cover this feature's entire DSL-reuse, staleness-binding,
  discovery, and Resolver-protection surface; this feature transcribes
  them into a concrete contract, it does not re-decide them.
- Running `spec-review-loop`/`impl-review-loop` against this package, or
  authoring `tasks.md`/`traceability.md` — this spec package is Phase 1
  only (`Spec-Review-Status: Pending`, `Impl-Review-Status: Pending`);
  Phase 2 artifacts are authored after both reviews pass.

## User Stories

- As a future implementer of `resolve-project-context.{py,sh,ps1}`, I need
  this package's `design.md` API / Contract Plan to already fix the exact
  CLI flags, processing order, Block-diagnostic enumeration, and output
  shapes, so that I am implementing an already-reviewed contract rather
  than making architectural decisions at implementation time.
- As the future implementer of `sdd-bootstrap-interviewer`'s capability
  interview phase, I need REQ-007's contract to state precisely when the
  phase runs, what it asks, and how it reacts to a Resolver Block, so my
  edit to that file does not silently diverge from decision document v2
  §18.4's own question-budget and resumability rules.
- As a maintainer running the Resolver against a project whose Registry
  has drifted out of sync with its Project Context, I need the Resolver
  to Block with a named, specific diagnostic (REQ-002) rather than either
  crash uninformatively or silently publish an under-specified Facet
  Manifest.
- As the implementer of a future Gate-chain caller that needs to know
  whether a Feature's Facet Manifest is stale, I need Resolver Evidence
  (REQ-004) to already carry every digest and per-Capability evaluation
  record that caller needs, so it does not need to re-invoke the Resolver
  merely to reconstruct provenance the first invocation already computed.

## Acceptance Criteria

| Acceptance Criterion | Requirement | Description |
|---|---|---|
| AC-001 | REQ-001 | `resolve-project-context.{py,sh,ps1}` CLI rejects an invocation missing `--config`, `--target-rev`, or `--feature` as a usage error, before any resolution logic runs; `--source-rev` defaults to `HEAD` when omitted, matching `resolve-component-paths`'s own default |
| AC-002 | REQ-001 | The Resolver's own Registry/schema discovery reuses ADR-0025's script-relative-then-git-root-fallback procedure unmodified, for every `contracts/*` artifact it locates, including its own `resolver-evidence.schema.json` |
| AC-003 | REQ-001 | The Context Projection this feature's Resolver computes internally (every track) and publishes to `generated/project-context.resolved.json` (Full track only, B4) is produced by Epic A4's own two-pass-canonicalizer generation procedure, verbatim — a fixture pair (one hand-computed via the documented procedure, one produced by invoking the Resolver on the Full track against the identical `project-context.yaml`) is byte-identical; a separate fixture confirms this path is never written on a Lite-track resolve |
| AC-004 | REQ-001 | The Resolver invokes `resolve-component-paths` with the identical `--config`/`--source-rev`/`--target-rev`/`--include-untracked` values it itself received, and consumes exactly its `affected_components` and `ownership_digest` output — never a subset, never a caller-supplied override |
| AC-005 | REQ-001 | `context_binding.registry_digest` is bound via `generate-registry-digest --whole`, never a `--capability-ids`/`--gate-ids` fragment |
| AC-006 | REQ-001 | For a Feature with two affected components where only one component's properties satisfy a Capability's `trigger`, that Capability is included in `capabilities[]` (the union-match rule, design.md Design Decisions) |
| AC-007 | REQ-001 | `required_facets`/`conditional_facets`/`resolved_gates`/`capabilities`/`capability_minimum_enforcement`/`lite_eligibility` are each populated per Epic A4's own field-by-field rules (Dependencies, above) with no additional field and no field omitted that Epic A4's schema requires |
| AC-008 | REQ-001 | The written `facet-manifest.yaml` validates successfully against `contracts/facet-manifest.schema.json` (Epic A4) for a representative multi-Capability, multi-affected-component fixture |
| AC-009 | REQ-001 | On the Lite track (`workflow.spec_profile == lite`), across each of the three non-Blocking `required_lite_checks`-sourcing states the cross-epic addendum (Epic A6 adversarial verification finding B5) defines — **advisory-missing** (`capability_enforcement == advisory`, a matched Capability's key absent, contributing `[]`), **required-present-empty** (`capability_enforcement == required`, a matched Capability's key present with an empty array), and **zero-match** (no matched Capability, either enforcement state) — the written `capability-summary.yaml` validates successfully against `contracts/capability-summary.schema.json` (Epic A4), and this same invocation writes neither `facet-manifest.yaml` nor `project-context.resolved.json` (track-exclusive output set, B4) |
| AC-010 | REQ-002 | Each of the **sixteen** REQ-002 diagnostic-id rows has its own independently-triggerable fixture — for `lite-check-source-undefined` specifically, the **required-missing** state only (`capability_enforcement == required` and a matched Capability's `lite_policy.required_lite_checks` key absent), per the cross-epic addendum narrowing that row's own trigger (REQ-002, above; AC-009 covers this diagnostic's three sibling non-Blocking states) — no other condition produces a Block (exit `1`) — a closed enumeration of Block causes only, distinct from the CLI usage-error exit path (exit `2`) AC-013 separately fixes (spec-review round-2 remedy, closing a CONTRADICTION finding) |
| AC-011 | REQ-002 | On any Block, no `facet-manifest.yaml`, `capability-summary.yaml`, or `project-context.resolved.json` is written or left partially written (a fixture asserts none of the three paths exists, or is unchanged from its pre-invocation state, after a Blocked run) — including a Block reached only after this invocation had already staged one of the three in memory (REQ-001's own staged-generation/journaled-transactional-publication ordering, B1), and including `post-publication-generation-mismatch`, whose own journal-based rollback restores this same unchanged-from-pre-invocation state even though a rename briefly succeeded (B8) |
| AC-012 | REQ-002 | Resolver Evidence is written on every Block except `disabled-legacy-invocation` (whose own minimal Evidence record is written instead of the full form) and except `output-schema-validation-failed` when Resolver Evidence itself is the artifact that failed (which writes no live artifact of any kind, B3) |
| AC-013 | REQ-002 | Exit code contract: `0` on success, `1` on any REQ-002 Block, `2` on a CLI usage error (AC-001) — fixed, tested per value |
| AC-014 | REQ-002 | Every diagnostic line `resolve-project-context.{py,sh,ps1}` itself emits follows the `capability-resolver: <check-id>: <detail>` format, `<check-id>` drawn only from REQ-002's own sixteen-value enum, and `<detail>` is a canonical, Resolver-owned sentence never quoting a dependency subprocess's own raw stderr verbatim (M8) — this criterion is scoped to `resolve-project-context`'s own diagnostic lines only; `validate-resolver-evidence`'s own, independent check-id enum is AC-021's own concern (Minor "diagnostic namespace" correction) |
| AC-015 | REQ-003 | `disabled-legacy` (absent `--config` target, or the AGENTS.md-marker/default fallback deriving it) produces `disabled-legacy-invocation` before any Registry/ownership/Context-Projection work is attempted (a fixture confirms no `resolve-component-paths`/Registry-discovery subprocess is ever invoked in this branch) |
| AC-016 | REQ-003 | A fixture pair identical except for `workflow.capability_enforcement` (`advisory` vs. `required`) produces byte-identical output across this invocation's own track-exclusive output set (whichever of `{facet-manifest.yaml, project-context.resolved.json}` or `{capability-summary.yaml}` applies, plus Resolver Evidence); only the enforcement-derived fields REQ-003 enumerates differ, wherever they occur in that set — Resolver Evidence's own `state`; the `context_binding` digests `full_context_revision`/`projection_sha256` in **every** artifact whose schema carries them, which on the Full track means `facet-manifest.yaml` as well as Resolver Evidence; and, in `generated/project-context.resolved.json`, its `workflow` block and `source_sha256` (M5/B4 correction — an earlier revision of this row named all four artifacts as if a single invocation ever produced all of them; amended 2026-08-24, human-approved — those two digests hash canonical bytes that structurally encode `workflow.capability_enforcement`, the canonical Project Context text and the canonical Context Projection text which copies `workflow` verbatim, so their identity across the pair is internally impossible for any correct implementation; **widened 2026-08-27, human-approved, ruling D(2)** — the 2026-08-24 scoping said "Resolver Evidence's own" copies and thereby left this row asserting the identical impossibility of the Projection, which IS that canonical text, and of the Manifest, which carries the identical two digests, making the Full-track half of this criterion unsatisfiable; the widened set is derivable from investigation.md INV-004's own schema field lists and adds no behaviour, and the **Lite track is untouched**, `capability-summary.yaml` carrying no `context_binding`). **This criterion explicitly excludes the one diagnostic branch REQ-002's `lite-check-source-undefined` (as narrowed by the cross-epic addendum, Epic A6 adversarial verification finding B5) does not treat identically across the two states** — a Lite-track fixture pair with a matched Capability's `lite_policy.required_lite_checks` key absent diverges by design (`required` Blocks, `advisory` resolves), and is covered instead by AC-009/AC-010's own three-non-Blocking-plus-one-Blocking matrix |
| AC-017 | REQ-004 | `contracts/resolver-evidence.schema.json` exists, is valid draft-07, and its `$id` matches every other `contracts/*.schema.json`'s convention |
| AC-018 | REQ-004 | `capability_evaluations[]` includes **exactly** one entry for **every** Registry Capability, not only matched ones (exact-set, not merely non-duplicated, B6) — a fixture with an unmatched Capability confirms its own entry is present with `matched: false` and a `trigger_evaluations[]` entry for every affected component; a **separate** zero-affected-component fixture (M9 correction) confirms every Capability's own `trigger_evaluations[]` is legitimately `[]` in that one case, without contradicting this row's own general "one entry per affected component" rule |
| AC-019 | REQ-004 | A matched Capability's `capability_evaluations[]` entry carries **exactly** one `conditional_facet_evaluations[]` entry per `conditional_facets[]` array *entry* the Registry declares for it — keyed by `declaration_index` (0-based position), **never** collapsed by distinct `facet` name (B7 predicate-instance keying; a Capability declaring the identical `facet` twice produces two entries, exact-set/cardinality bound to declaration count), each with exactly one `evaluations[]` element per affected component; an unmatched Capability's entry carries the key omitted entirely; `matched`/`applied` are each bidirectionally consistent with their own governing array (B6) |
| AC-020 | REQ-004 | Resolver Evidence is written on a fully successful run as well as on every Block (AC-012) — never conditionally omitted on success |
| AC-021 | REQ-004 | `validate-resolver-evidence.{py,sh,ps1}` exits 0 on a schema-conformant, exact-set-complete, provenance-bound fixture and non-zero (with a `resolver-evidence: <check-id>: <detail>` diagnostic, `<check-id>` drawn from this script's own closed, **twelve**-value enum, design.md) on a fixture missing any required field, any Registry Capability, any affected component, a bidirectionally-inconsistent `matched`/`applied` value, a Registry whose digest does not match `context_binding.registry_digest` (`registry-digest-unbound`, B6), or an affected-component set that diverges between the Evidence instance's own `dependency_pointers[]`, a co-located Manifest's own, and any CLI override (`affected-component-provenance-mismatch`, B6) |
| AC-022 | REQ-005 | Two invocations of the identical `.py` Resolver against the identical input produce byte-identical output across this invocation's own track-exclusive output set |
| AC-023 | REQ-005 | `.py`/`.sh`/`.ps1` invocations of the identical input produce byte-identical output across this invocation's own track-exclusive output set, and identical stdout/stderr/exit code, restricted to this feature's own emitted content (M8 — never comparing a dependency subprocess's own raw stderr, which is out of this feature's own control and out of this comparison's own scope) |
| AC-024 | REQ-005 | `capability_evaluations[]` is stable-sorted by `capability_id`; `diagnostics[]` is stable-sorted by `(id, detail)`; every Epic-A4-mandated Facet Manifest array (Dependencies, above) is stable-sorted per Epic A4's own rule |
| AC-025 | REQ-005 | A repository-wide grep confirms no Resolver-owned script reads `datetime.now()`/`time.time()`/any network call/any provider-API call anywhere in its own orchestration logic (the DSL evaluator itself, Epic A2's own scope, is out of this check) |
| AC-026 | REQ-006 | Each new `tests/*.tests.sh`/`.tests.ps1` pair this feature's future task phase authors is registered directly (unprotected) in `tests/run-all.sh`/`.ps1`, matching Epic A2/A4's own precedent |
| AC-027 | REQ-006 | The full fixture matrix (REQ-006's own items a-h, design.md Test Strategy items 1-10) is present under `tests/fixtures/capability-resolver/`, each fixture independently invocable |
| AC-028 | REQ-006 | Three discovery-contract fixtures total — the direct product of one installed-standalone-plugin layout case × three runtimes (Minor "discovery fixture count" correction) — confirm that layout (only the packaged `plugins/sdd-quality-loop/contracts/*` copy present, no monorepo `contracts/`, no reachable `.git`) resolves and validates correctly for every artifact this feature's scripts locate, one fixture per runtime, each exercising every such artifact within that runtime's own invocation |
| AC-029 | REQ-007 | This package's `design.md` documents the capability interview phase's exact insertion point relative to `sdd-bootstrap-interviewer`'s existing steps, its question-budget rule (≤15 per pass), its Open-Questions-persistence rule, and its resumability rule, each citing decision document v2 §18.4 directly |
| AC-030 | REQ-007 | This package's `design.md` documents the Context-absent case as producing the identical bootstrap flow existing today (event-identical, no capability-phase step reachable) |
| AC-031 | REQ-007 | This package's `design.md` documents the on-Block behavior (surface the diagnostic, never silently degrade to a non-Capability-aware flow) with an explicit citation to decision document v2 §7's own "legacy mode へ黙ってフォールバックしてはならない" principle |
| AC-032 | REQ-007 | No file under `plugins/**` is modified by this package's own commits |
| AC-033 | REQ-008 | A future implementation task's diff carries its own `CHANGELOG.md` `## Unreleased` entry citing #193 |
| AC-034 | REQ-008 | A repository-wide grep-based self-check confirms no version string is mutated anywhere in this feature's diff outside a `scripts/bump-version.sh` invocation |
| AC-035 (Global) | — | `check-workflow-state.sh --feature epic-193-a5-capability-resolver` exits 0 after this package's registration commit lands, with no `tasks.md`/`traceability.md` present and `requirements.md`'s `Spec-Review-Status: Pending`/`design.md`'s `Impl-Review-Status: Pending` headers intact |
| AC-036 (Global) | — | `check-sdd-structure.sh` (no feature argument) exits 0 after this package's registration commit, run as `sh scripts/check-sdd-structure.sh .` |
| AC-037 (Global) | — | `specs/workflow-state-registry.json`'s new entry is exactly `{"feature": "epic-193-a5-capability-resolver", "profile": "full"}`, no additional keys, appended to this worktree's own `entries` array |
| AC-038 | REQ-001/REQ-002 | Staged-generation/journaled-transactional-publication lock (B1): a fixture that reaches a Block only after this invocation has already staged the Context Projection and/or Facet Manifest/Capability Summary in memory (e.g. `lite-check-source-undefined`, `output-schema-validation-failed`, `snapshot-generation-mismatch`) confirms no earlier-staged **publication artifact** ever reached a live path (REQ-001 step (m)'s rollback-and-no-write scope rule: the subject is the three publication artifacts, never `resolver-evidence.yaml`, which is itself staged at step (j) and **is** written on the `lite-check-source-undefined` and `snapshot-generation-mismatch` fixtures and on `output-schema-validation-failed`'s **non-Evidence sub-case (AC-055(b)) only** — its Evidence-itself-fails sub-case, AC-055(a), is one of AC-012's two exceptions and writes nothing at all, so this row's fixture for that id is AC-055(b)'s — scoped 2026-08-27, human-approved, ruling D(2), replacing an unscoped "artifact" that read against AC-012/AC-040/AC-055, with the sub-case split named because the first replacement wording over-generalised across it) — this criterion is additive to AC-011's own "no partial artifact" statement, over the same three artifacts, differing in that it holds for Blocks reached only after staging rather than for Blocks generally |
| AC-039 | REQ-002 | `artifact-publication-failed` lock (B1/B3, revised): an injected write/rename failure on one of this invocation's own staged output paths, after every earlier step already succeeded, Blocks with this diagnostic id; a fixture with a second, already-completed rename **of a publication artifact** in the same commit sub-sequence confirms that target is rolled back to its own PRE-transaction live bytes via the transaction's own journal — **never** a bare `unlink` with no restore path (B1, closing the "existing bytes destroyed" gap) — while `resolver-evidence.yaml` is not rolled back and instead carries this Block's own record (REQ-001 step (m)'s rollback-and-no-write scope rule, AC-012; scoped 2026-08-27, human-approved, ruling D(2)) — and the rollback attempt is itself recorded in this diagnostic's own `detail` |
| AC-040 | REQ-002 | `snapshot-generation-mismatch` lock (B8 TOCTOU, revised): a fixture that mutates the Project Context, ownership-source declarations, or Registry between this invocation's own invocation-start snapshot and its pre-publication recheck Blocks with this diagnostic id, and no **publication artifact** — `facet-manifest.yaml`, `capability-summary.yaml`, or `generated/project-context.resolved.json` — reaches a live path, while `resolver-evidence.yaml` itself **is** written recording this diagnostic (scoped 2026-08-27, human-approved, ruling D(2): the earlier unscoped "no artifact" wording contradicted AC-012's own always-emitted rule, which excepts two ids and not this one; AC-011 already used this scoped form); a **second** fixture leaves every digest (including `ownership_digest`) byte-identical but mutates only the worktree/index/untracked state so the re-derived `affected_components` set itself differs, confirming the Block fires on the set difference alone (B8 correction — `ownership_digest` parity is not by itself sufficient) |
| AC-041 | REQ-002 | `workflow-combination-invalid` lock (M3): one independently-triggerable fixture per decision document v2 §6's own two explicitly-invalid combination rows (`lite` × non-`lite-three-file`, `full` × `lite-three-file`), each Blocking before any Registry/ownership/projection work begins |
| AC-042 | REQ-003/REQ-007 | CLI-misuse framing lock (M4): a spy-harness fixture on `sdd-bootstrap-interviewer`'s own capability interview phase (REQ-007) confirms it never invokes `resolve-project-context`'s own subprocess at all while a Project Context is absent or derives `disabled-legacy` — distinct from, and in addition to, AC-015's own narrower "the Resolver itself invokes no further subprocess in this branch" check |
| AC-043 | REQ-001 | Cross-Capability facet-name aggregation lock (B7): a fixture where two *different*, matched Capabilities each declare a `conditional_facets[]` entry under the identical `facet` name confirms `applied` is the OR of both predicate instances' own per-component evaluations, `evidence` is the concatenation of every contributing `(capability_id, declaration_index, component_id)` triple's own evaluation nodes in `capability_id`-then-`declaration_index`-then-`component_id` ascending order, and (on `applied: false`) `reason` names every contributing predicate instance |
| AC-044 | REQ-004 | Provenance canonicalization lock (B9): a fixture confirms `dependency_pointers[]` is exactly `/workflow` plus one RFC-6901-escaped `/components/<id>` pointer per affected component, stable-sorted and de-duplicated (including a component `id` containing `/`/`~` to exercise escaping); `resolver.version`/`resolver.rule_set_revision` are identical across repeated invocations and across `.py`/`.sh`/`.ps1` of the same Resolver revision, and change only when that revision's own `RESOLVER_VERSION`/rule-set constant is bumped (`scripts/bump-version.sh`) |
| AC-045 | REQ-005/REQ-006 | Metamorphic completeness lock (M10): all four true/false combinations of a 2-affected-component `trigger` result; output invariance under affected-component input-order permutation; a >1-true-component fixture recording the matched Capability exactly once; and a nested-array-completeness fixture confirming every level of Resolver Evidence's own nesting carries exactly its governing set's cardinality (design.md Test Strategy item 9) |
| AC-046 | REQ-007 | Live-caller-contract lock (M6, revised): a contract-test suite against the live `sdd-bootstrap-interviewer/SKILL.md` confirms (a) no `resolve-project-context` invocation while Context-absent, (b) exactly one invocation per capability interview phase run, (c) a REQ-002 Block surfaces to the interview session rather than silently degrading, and (d) an **anchor-fingerprint** drift check (AC-053, below, gives the fingerprint mechanism) fails loudly if this package's own cited anchor no longer matches the live file, superseding an earlier revision's bare heading-text-existence check |
| AC-047 | REQ-002 | Journal-based crash recovery lock (B1, NEW): a fixture simulates a hard crash between two renames of a multi-target publication transaction (test-harness-only kill hook) and confirms the **next** invocation's own mandatory crash-recovery scan converges every target back to its own PRE-transaction bytes before proceeding with its own, separate resolve; a companion fixture corrupts the journal's own recorded pre-image backup (an unrecoverable state) and confirms the next invocation Blocks, `publication-journal-recovery`, before any Registry/ownership/Context-Projection work begins |
| AC-048 | REQ-002 | Pre-publication `affected_components` re-derivation lock (B8, NEW): a fixture mutates only the worktree/index/untracked state (no ownership-config edit) between this invocation's own step-4 snapshot and its step-13 recheck, confirming `snapshot-generation-mismatch` fires on the `affected_components` set difference even though `ownership_digest` itself stays byte-identical |
| AC-049 | REQ-002 | Post-publication verification / race lock (B8, NEW): a fixture injects the identical class of source mutation *after* the pre-publication recheck has already passed but *before* the publication transaction's own last rename completes, confirming (a) `post-publication-generation-mismatch` fires only after every rename in the transaction has already, briefly, succeeded, (b) every one of those renames **of a publication artifact** is rolled back to its own PRE-transaction state via the journal before this invocation exits, while `resolver-evidence.yaml` is **not** rolled back and instead carries this Block's own record at exit — both halves are required of this one fixture, exactly as AC-047's own row requires of its own: asserting only the first would contradict AC-012, which excepts two diagnostic ids and not this one, and asserting only the second would lose the rollback guarantee (REQ-001 step (m)'s rollback-and-no-write scope rule; scoped 2026-08-27, human-approved, ruling D(2)) — and (c) the rollback is journal-based, never a bare `unlink` |
| AC-050 | REQ-004 | `validate-resolver-evidence` Registry provenance-binding lock (B6, NEW): a fixture supplies a `--registry` override whose own `generate-registry-digest --whole` value does not equal the Evidence instance's own `context_binding.registry_digest`, confirming `registry-digest-unbound` fires before any `capability-set-mismatch` check runs; a companion fixture confirms the default (no `--registry`) self-discovery path performs the identical binding check against the ADR-0025-discovered Registry, never trusting an unverified caller-supplied path |
| AC-051 | REQ-004 | `validate-resolver-evidence` affected-component provenance-binding lock (B6, NEW): a fixture pairs an Evidence instance with a co-located Facet Manifest whose own `dependency_pointers[]` names a different affected-component set than the Evidence instance's own, confirming `affected-component-provenance-mismatch` fires without needing any `--affected-components` CLI argument at all; a companion fixture supplies an explicit `--affected-components` override that contradicts both sibling artifacts' own `dependency_pointers[]`, confirming the identical check-id fires for the override case too |
| AC-052 | REQ-001 | Same-Capability duplicate-facet predicate-instance lock (B7, NEW): a fixture where a single Registry Capability declares the identical `facet` name at two different `conditional_facets[]` array positions with two different `when` predicates confirms Resolver Evidence records two independent `conditional_facet_evaluations[]` entries (one per `declaration_index`, never collapsed by `facet` name), and the Facet Manifest's own single, facet-name-unique output entry aggregates both declaration indices' own contributions by the identical `(capability_id, declaration_index, component_id)`-keyed rule the cross-Capability case (AC-043) uses |
| AC-053 | REQ-007 | Anchor-fingerprint lock (M6, NEW): a fixture confirms the recomputed sha256 of the fixed `SKILL.md:54-64` window and the `### Full-Profile Layer Interview` heading's own 1-based ordinal position among every `##`/`###` heading in the live file both match this package's own recorded values (`sha256:d969fa163169ee5a9b5941600382b86b75929d6cd90d223dbe991e1dc234fb64` and `3` respectively); a regression fixture that relocates the identical heading text to a different position in the file, while its own immediate neighboring lines stay unchanged, confirms the drift check fails loudly — the exact case an earlier revision's bare "heading text still exists" check could not detect |
| AC-054 | REQ-001/REQ-004 | Resolver publication transaction reader-side lock (B1, NEW): a fixture confirms `validate-resolver-evidence` fails closed (never a silent read of possibly-torn cross-file state) when a live transaction journal names the `resolver-evidence.yaml` path it is about to read |
| AC-055 | REQ-002 | `output-schema-validation-failed` dual-artifact-scope lock (spec-review round-1 remedy, closing an EDGE-CASE-COVERAGE finding): two independently-triggerable fixtures — one where Resolver Evidence itself fails its own defensive schema self-validation (writes nothing to any live path, B3), and one where a non-Evidence staged artifact (Facet Manifest, Capability Summary, or Context Projection) fails the identical check while Resolver Evidence itself remains schema-valid (Resolver Evidence is still written recording this diagnostic, per AC-012's own general rule, and the failing non-Evidence artifact itself is not written, AC-011) |
| AC-056 | REQ-004 | `diagnostics[]` warn/block cardinality lock (spec-review round-1 remedy, closing an AMBIGUITY finding): a fixture confirms `diagnostics[]` carries exactly one `severity: "warn"` entry per individual `outcome: "warn"` DSL-evaluation node encountered anywhere in that invocation (each with a distinct `detail` naming that node's own `capability_id`/`component_id`/`declaration_index` location) plus exactly one additional `severity: "block"` entry sharing the identical `dsl-warn-on-matched-capability` id; a companion multi-node fixture confirms the entry count scales 1:1 with node count plus exactly one summary entry, never fewer, never a second summary entry, and that no `(id, detail)` pair repeats (AC-024). Exception (amended 2026-08-24, human-approved, mirroring REQ-004's amended sentence): `severity: "warn"` entries already collected before an evaluation abort — a REQ-002 Block raised from within this invocation's own single steps (f)–(g) evaluation sweep before step (h), the identical sweep that produced the warns ("jointly caused") — lawfully appear alongside that abort's own **different-id** `severity: "block"` summary entry with no same-id summary entry; an abort-exception fixture (`tests/resolve-project-context-block.tests.sh`/`.ps1`, `evaluate-predicate-failure-after-warn`) locks exactly that shape |
| AC-057 | REQ-002 | `snapshot-generation-mismatch` step-(e)-recheck site lock (ruling C(1), human-approved 2026-08-26; the ruling's own amendment added this row to `acceptance-tests.md` and `traceability.md` but not to this table, while amending the REQ-002 row above to cite it — that omission is corrected 2026-08-27, completing the same ruling's propagation and changing no other text): a dedicated fixture (`registry-swapped-during-validation`) whose `generate-registry-digest` stub overwrites the discovered Registry file in place as a side effect of step (e)'s own digest invocation isolates REQ-002's amended **second** trigger site for this id — detection-only, mid-pipeline, Registry bytes alone, immediately after step (e)'s two dependency invocations — from the row's pre-existing pre-publication-recheck trigger (AC-040/AC-048's own steps (l)/(m) window); the fixture asserts exit `1`, the canonical detail sentence naming the discovery-read-to-recheck window, an empty `capability_evaluations` array — read from the `resolver-evidence.yaml` this Block **does** write, per AC-012 — and no **publication artifact** (`facet-manifest.yaml`, `capability-summary.yaml`, `generated/project-context.resolved.json`) on any live path (scoped 2026-08-27, human-approved, ruling D(2): this row inherited an unscoped "no live artifact" clause that both contradicted AC-012 and was self-defeating, since `capability_evaluations` is a field of the very artifact that clause declared unwritten; sibling AC-058 never carried the clause) (approval evidence: investigation.md `## Amendment Re-Review Context` › `### Rulings C(1)/C(2)`) |
| AC-058 | REQ-002 | `dependency-output-malformed` absent-component fail-closed lock (ruling C(2), human-approved 2026-08-26; same un-propagated-row correction as AC-057, made 2026-08-27): a dedicated fixture (`affected-component-absent-from-context`) whose `resolve-component-paths` stub returns an `affected_components[]` entry naming a component id absent from that fixture's own Context Projection alongside one present-and-valid id isolates REQ-002's amended sub-trigger from the row's pre-existing malformed-stdout triggers; the fixture asserts the Block fires **before** any predicate evaluation of any entry (exit `1`, the canonical absent-component detail sentence, an empty `capability_evaluations` array), never a defaulted-empty-properties evaluation of the absent id (approval evidence: investigation.md `## Amendment Re-Review Context` › `### Rulings C(1)/C(2)`) |

## Field Definitions

- **Resolver**: this feature's own name for `resolve-project-context.{py,
  sh,ps1}` — the deterministic script family issue #193 and decision
  document v2 §7 both describe as "not an agent skill." This term never
  refers to a different script anywhere in this package.
- **Affected component**: a component `id` string present in
  `resolve-component-paths`'s own `affected_components` output
  (Dependencies, above) — this feature never derives this set by any
  other means (investigation.md INV-010).
- **Matched Capability**: a Registry `capabilities[]` entry whose
  `trigger` predicate evaluates `result: true` against at least one
  affected component's Context-Projection properties (REQ-001's own
  union-match rule).
- **`capability_minimum_enforcement`**: identical in meaning to Epic A4's
  own field of the same name (Dependencies, above) — the `max()` (i.e.
  logical OR, since `"required"` is the only non-absent value the Registry
  schema defines) of every matched Capability's own `minimum_enforcement`.
  This feature never computes decision document v2 §10's full effective
  enforcement (Non-goals).
- **Block**: this feature's own term for a REQ-002 fail-closed refusal —
  distinct from `check-component-coverage`'s own "Fail condition" (a
  *recorded*, and in `required` state *blocking*, evaluation outcome
  within a successful run) and distinct from ADR-0021's own "Policy
  Weakening → Block" (a `compare-facet-manifest-staleness` verdict, a
  different script this feature does not build, Non-goals). A REQ-002
  Block always means this invocation's own publication transaction
  (REQ-001) never *completes* leaving new content live: for every Block
  reached before publication begins, the transaction never runs at all,
  so this invocation produced no Facet Manifest/Capability Summary/
  Context Projection at all; for the one exception —
  `post-publication-generation-mismatch`, whose own detection point is
  necessarily *after* every rename has already, briefly, succeeded — this
  invocation itself rolls the transaction's own **publication artifacts**
  back to their PRE-transaction state before returning the Block — never
  `resolver-evidence.yaml`, which instead carries that Block's own record
  (REQ-001 step (m)'s rollback-and-no-write scope rule, AC-012) — so the
  *net* effect converges to the
  identical "no Facet Manifest/Capability Summary/Context Projection at
  all" outcome even though a live rename technically occurred in between
  (design.md "Resolver publication transactional bundle contract"). Never
  a partial or degraded artifact either way — a structural guarantee of
  REQ-001's own staged-generation/journaled-transactional-publication
  ordering (adversarial review "B1 atomicity"), not merely a per-step
  promise. **This definition no longer depends on any "representative
  branch" concept** — an earlier revision's `dsl-warn-on-matched-
  capability` Block condition, and its own Facet Manifest evidence
  embedding, both referenced a single deterministically-chosen
  representative evaluation per matched Capability; adversarial review
  "M1/M2 representative selection removed" found that concept itself
  unsound, and no term in this package still defines or depends on it
  (design.md Design Decisions, "facet-name aggregation"/"WARN scope").
- **Resolver Evidence**: this feature's own new artifact
  (`sdd-resolver-evidence/v1`, REQ-004) — distinct from, and a superset
  in scope of, the `evidence[]` arrays Epic A2's `evaluate-predicate`
  and Epic A4's `conditional_facets[].evidence` already carry (those
  are single-predicate, single-component records; Resolver Evidence
  aggregates every predicate evaluated, across every Registry Capability
  and every affected component, for one Resolver invocation).

## Roles and Permissions

- **Epic A5's own future Phase-2 implementer**: the sole intended writer
  of `resolve-project-context.{py,sh,ps1}` and its companion scripts'
  actual **code content** — staged under `specs/epic-193-a5-capability-
  resolver/human-copy/` for human application via `apply-human-copy`
  (Epic A1's own publisher), since the target path is already protected
  before this feature's own first write (investigation.md INV-003) —
  never a direct agent write to the live path. **This human-copy role is
  scoped to the three scripts' own immutable code only** (adversarial
  review "M7 human-copy boundary") — it is never the mechanism by which
  `generated/project-context.resolved.json` or any per-Feature generated
  artifact acquires content; those are governed by the next role, below.
- **A running Resolver process (any caller)**: the sole intended writer of
  live `facet-manifest.yaml`/`capability-summary.yaml`/`project-context.
  resolved.json`/Resolver Evidence instances for a real Feature, via the
  guarded publication mechanism REQ-001 fixes for the write set in hand —
  the journaled transaction (staged generation, journaled transactional
  commit) whenever this invocation publishes a track's output set, and the
  direct `temp file + fsync + rename` REQ-001 step (m) and REQ-004 fix
  whenever Resolver Evidence is the invocation's **whole** write set
  (scoped 2026-08-27, human-approved, ruling D(2); this sentence had
  named the journaled commit unconditionally, which the narrowing left
  behind) — in both cases with cwd-independent path
  resolution per ADR-0025 —
  never a human-copy content-population step, M7 correction to an earlier
  revision that treated `project-context.resolved.json`'s own "initial
  content" as a human-copy target, which is incoherent for a value that is
  recomputed by definition on every Full-track invocation) — this
  feature's own contract states these are agent-writable-only-via-the-
  Resolver artifacts (matching Epic A4's own Roles and Permissions
  statement, Dependencies, above), never hand-edited.
- **A future implementation task touching `sdd-bootstrap-interviewer`'s
  `SKILL.md`**: re-verifies that file's then-current protection status
  before choosing a direct edit or a human-copy application
  (investigation.md INV-017); design.md Design Decisions, "caller
  insertion point" (M6), already fixes *where* in that file the edit
  belongs — this role's own remaining decision is only *how* to apply it.

## Main Workflows

1. **Successful full-track resolve**: caller invokes
   `resolve-project-context --config sdd/project-context.yaml
   --target-rev main --feature my-feature` → state derives `advisory` or
   `required`, workflow-combination valid → Project Context canonicalized
   and snapshotted, Context Projection staged (not yet written) →
   `resolve-component-paths` returns `affected_components: [component-a,
   component-b]` and an `ownership_digest` (snapshotted) → Registry
   discovered and snapshotted, `registry_digest --whole` computed → every
   Registry Capability's `trigger` evaluated against `component-a` then
   `component-b`, in full, no short-circuit → every matched Capability's
   `conditional_facets[].when` evaluated the same way → no WARN found on
   any evaluated branch → track branch selects `full` → Facet Manifest
   staged (facets/gates/lite-policy collected, cross-Capability facet-name
   aggregation applied) → Resolver Evidence staged → every staged artifact
   schema-validated → pre-publication snapshot recheck (digests and
   `affected_components`) matches → the journaled publication transaction
   writes `facet-manifest.yaml` to `specs/my-feature/`,
   `project-context.resolved.json` to `generated/`, and Resolver Evidence
   alongside `facet-manifest.yaml`, verified once more immediately after
   the last rename (post-publication verification) → exit 0.
2. **Successful lite-track resolve with a resolvable check source**: as
   above through evaluation, but `workflow.spec_profile == lite`, the
   track branch selects `lite`, and every matched Capability contributing
   to `required_lite_checks` has a resolvable source → Capability Summary
   staged (**never** a Facet Manifest or a published Context Projection on
   this track, B4) → the journaled publication transaction writes
   `capability-
   summary.yaml` and Resolver Evidence only → exit 0. (Narrowed by
   cross-epic addendum, Epic A6 adversarial verification finding B5: a
   "resolvable source" now includes an **absent** key under `advisory`
   enforcement (contributes `[]`) and a **present-but-empty** key under
   `required` enforcement, in addition to the zero-matched-Capability
   case — this workflow therefore has a real-world instance whenever the
   invocation is `advisory`-enforcement, or is `required`-enforcement
   with no matched Capability whose key is absent — not only the
   zero-affected-component Edge Case, below; see Risks and Dependencies'
   own Epic A6 prerequisite, B5, for the one state that remains blocked.)
3. **Lite-track resolve, unresolvable check source**: as workflow 2, but
   `capability_enforcement == required` **and** at least one matched
   Capability's `lite_policy.required_lite_checks` key is absent
   (cross-epic addendum, Epic A6 adversarial verification finding B5,
   narrowing this workflow from an earlier revision's broader "any
   matched Capability lacking a source" trigger) → Block,
   `lite-check-source-undefined`, at the track-branch step, before any
   commit — Resolver Evidence written recording the diagnostic, no
   `capability-summary.yaml` (or `facet-manifest.yaml`/`project-context.
   resolved.json`) ever reaches a live path → exit 1. The
   otherwise-identical `advisory`-enforcement fixture does not reach this
   workflow at all — it resolves under workflow 2 instead, contributing
   `[]`.
4. **`disabled-legacy` invocation (a CLI-misuse condition, not a designed
   pipeline state — M4)**: a caller invokes the Resolver against a project
   with no `project-context.yaml` (or the AGENTS.md-marker/default
   fallback derives `disabled-legacy`) → Block, `disabled-legacy-
   invocation`, before any other work begins → minimal Resolver Evidence
   written directly (no staging area ever exists in this branch) → exit
   1. A **compatible** caller (REQ-007) never reaches this workflow at all
   in practice — it invokes the Resolver's process only when a Project
   Context is present and its derived state is not `disabled-legacy`; this
   workflow exists to document the Resolver's own fail-closed response
   to a caller that violates that contract, not a state the Resolver is
   designed to run in.
5. **`sdd-bootstrap-interviewer` capability interview phase**: after track
   detection — concretely, immediately before the live `SKILL.md`'s own
   `### Full-Profile Layer Interview` heading (design.md Design Decisions
   "caller insertion point", M6) — if a Project Context is present and its
   state is not `disabled-legacy`, the interviewer invokes the Resolver
   once (workflow 1/2/3, above); on exit 0, the interviewer proceeds to
   facet generation using the written `facet-manifest.yaml` (full track)
   or `capability-summary.yaml` (lite track); on exit 1 (Block) or 2
   (usage error), the interviewer surfaces the diagnostic and does not
   silently fall back to a non-Capability-aware flow (REQ-007).

## Edge Cases

- **Zero affected components** (a diff touching only cross-cutting
  `shared_paths` — Epic A3's own `affected_components` definition
  excludes these, Dependencies above): no Capability can match (there is
  no affected component's properties for any `trigger` to evaluate
  against) → this is a **legitimate, non-Block, empty resolution**, not an
  ambiguous condition — `capabilities: []`, `required_facets: []`,
  `conditional_facets: []`, `resolved_gates: []`,
  `capability_minimum_enforcement` absent, `lite_eligibility: {eligible:
  true, upgrade_reasons: []}` (vacuously eligible — no matched Capability
  forces an upgrade). **Resolver Evidence's own `capability_
  evaluations[].trigger_evaluations[]` is `[]` for every Registry
  Capability in this one case** (M9 correction — this is the sole
  exception to AC-018's own general "one `trigger_evaluations[]` element
  per affected component" rule, and remains exact-set-correct: the
  governing set, `affected_components`, is itself `[]`, so a `[]`
  `trigger_evaluations[]` has the correct cardinality, zero, not an
  incomplete one). This is distinct from `affected-component-resolution-
  failed` (REQ-002), which fires only on `resolve-component-paths`'s own
  non-zero exit, never on a legitimately-empty `affected_components`
  array from a successful exit.
- **Any evaluation this invocation performs — a matched Capability's
  `trigger`, an unmatched Capability's `trigger`, or a matched
  Capability's `conditional_facets[].when`, against any affected
  component — WARNs**: `dsl-warn-on-matched-capability` Blocks (REQ-002)
  regardless of which branch WARNed, whether that Capability ultimately
  matched, or whether that branch's own `result` agreed with the
  Capability's/facet's overall outcome (REQ-002's own any-branch
  quantifier, adversarial review "B2 WARN" — this corrects an earlier
  revision that Blocked only on a single, deterministically-chosen
  "representative" branch per matched Capability, and never inspected an
  unmatched Capability's own trigger Evidence at all; that narrower scope
  is removed together with the representative-evidence-selection concept
  it depended on, Field Definitions "Block", above). There is no longer an
  accepted-WARN case anywhere in this feature's own evaluation model.
- **Two or more predicate instances — `(capability_id, declaration_
  index)` pairs, whether from two *different* matched Capabilities or
  from the *same* Capability declaring the identical `facet` name more
  than once in its own `conditional_facets[]` array — share one `facet`
  name** (adversarial review "B7 facet aggregation", generalized to
  predicate-instance keying): the Facet Manifest's own single,
  facet-name-unique `conditional_facets[]` entry for that name aggregates
  every contributing predicate instance by OR (`applied: true` iff any
  contributing predicate instance's own evaluation, against any affected
  component, is `true`), concatenates every contributing `(capability_id,
  declaration_index, component_id)` triple's own evidence nodes in
  `capability_id`-then-`declaration_index`-then-`component_id` ascending
  order, and (on `applied: false`) names every contributing predicate
  instance in `reason` (design.md Design Decisions "facet-name
  aggregation, predicate-instance keyed" gives the exact rule). Resolver
  Evidence itself never aggregates across predicate instances — each
  matched Capability's own `conditional_facet_evaluations[]` array
  carries one entry per its own `conditional_facets[]` *declaration*
  (keyed by `declaration_index`, B7), regardless of `facet`-name
  collisions with any other declaration, same-Capability or not.
- **A Registry Capability with an empty `conditional_facets: []`**: its
  `capability_evaluations[]` entry (Resolver Evidence) carries an empty
  `conditional_facet_evaluations: []` if matched, and none at all if
  unmatched — never an omitted key.
- **`--source-rev` equal to `--target-rev`**: delegated entirely to
  `resolve-component-paths`'s own already-fixed behavior (Epic A3) — this
  feature does not add a special case; whatever `affected_components`
  Epic A3's script returns for that input is what this feature evaluates
  against.
- **A Feature re-resolved after its Registry's `registry_digest` changes
  but its `capabilities[]` match set is unchanged**: this feature's
  Resolver still recomputes and re-writes a fresh Facet Manifest
  reflecting the new `registry_digest` (REQ-001/REQ-005's own
  determinism-from-current-inputs rule) — whether that change makes the
  Feature "stale" is `compare-facet-manifest-staleness`'s own concern
  (Epic A4, Non-goals), not this feature's; this feature never itself
  decides staleness.
- **The Project Context, ownership-source declarations, Registry, or the
  underlying diff's own `affected_components` set change between this
  invocation's own snapshot and its pre-publication recheck** (a TOCTOU
  window — a concurrent commit, a concurrent second Resolver invocation
  against the same repository (out of scope by the single-writer
  assumption, below), or a filesystem race — adversarial review "B8
  TOCTOU", widened to also re-derive and compare `affected_components`,
  not only digests): `snapshot-generation-mismatch` Blocks (REQ-002),
  even though every earlier step in this invocation already succeeded;
  this invocation's own staged artifacts, which reflect the now-stale
  snapshot, are discarded rather than committed.
- **The identical class of change occurs again, *after* the
  pre-publication recheck immediately above has already passed but
  *before* the publication transaction's own last rename completes** (the
  "post-recheck race," adversarial review "B8 TOCTOU" — a narrower,
  later window the pre-publication recheck alone cannot close, since it
  is itself over by the time the transaction's own renames run):
  `post-publication-generation-mismatch` Blocks (REQ-002, NEW), and this
  invocation itself rolls every already-committed rename **of a
  publication artifact** back to its own
  PRE-transaction state via the publication transaction's own journal
  before returning that exit code, while `resolver-evidence.yaml` is not
  rolled back and instead carries that Block's own record (REQ-001 step
  (m)'s rollback-and-no-write scope rule, AC-012/AC-049) — the sole Edge
  Case in this feature
  where a live rename briefly succeeds before this invocation's own exit
  code reports a Block.
- **This invocation, or a prior invocation against the identical
  `--feature`, crashes between two renames of a multi-target publication
  transaction** (adversarial review "B1 atomicity"): the transaction's
  own journal, written before any rename in that transaction began,
  survives the crash; the next invocation against that same `--feature`
  detects it via the mandatory crash-recovery scan (REQ-001's own step 0)
  and converges every target back to one of the transaction's own two
  terminal states — fully-applied or fully-reverted — before proceeding
  with its own, separate work, **or, if that journal is itself
  unconvergeable** (a referenced pre-image backup missing or unreadable,
  or a target matching neither its recorded PRE nor POST value), attempts
  no repair at all and Blocks `publication-journal-recovery`, leaving
  **every interrupted target other than `resolver-evidence.yaml`** exactly
  as found for manual operator intervention — that one target still
  receives this invocation's own Block record, written directly, because
  AC-012's always-emitted rule excepts two ids and not this one, so the
  obligation is per target and never global (REQ-002 above; AC-047, whose
  own row states both halves and records that asserting the first alone
  would contradict AC-012; scoped 2026-08-27, human-approved, ruling
  D(2)). The guarantee is therefore not that a mixed
  generation never stands — the unconvergeable case is precisely one that
  does — but that **no invocation ever proceeds past one**: it is either
  converged away or it fails this invocation closed, never silently
  carried forward (scoped 2026-08-27, human-approved, ruling D(2); the
  earlier absolute wording predated the unconvergeable branch's own
  no-repair obligation and contradicted it) (design.md "Resolver
  publication transactional bundle contract").

## Security Boundaries

- The Resolver's own orchestration logic never invokes a Provider API,
  reads a credential, or writes outside `specs/<feature>/facet-manifest.
  yaml`/`capability-summary.yaml`, `generated/project-context.resolved.
  json`, its own Resolver Evidence path, and its own transient
  `specs/<feature>/.resolver-staging/` transaction-journal/pre-image area
  (B1, unprotected staging, never a live path itself) — matching
  ADR-0020's own Provider-neutrality boundary for the DSL layer, extended
  by this feature's REQ-005 to its own orchestration layer.
- The Resolver never writes to any `*.approval.json` sidecar, any
  `sdd/.approved-context/` anchor, or `guard-invariants.json` itself —
  those remain exclusively Epic A1's own protected-file surface
  (investigation.md INV-003/INV-007); this feature only reads
  `project-context.yaml`'s already-approved content via the canonicalizer,
  it never participates in the approval-sidecar workflow itself.
- A `disabled-legacy-invocation` Block (REQ-002) is a fail-closed refusal,
  never a silent success with degraded content — matching ADR-0016 item
  4's own "outside that computation's domain" framing (investigation.md
  INV-013): there is no code path in this feature's design that produces
  a Facet Manifest while the capability pipeline is derived-inactive. This
  Block is itself a **CLI-misuse guard** (REQ-002/REQ-003, above,
  adversarial review "M4"), not a pipeline state this Resolver is designed
  to execute — a compatible caller's own security posture (REQ-007) is to
  never invoke this Resolver's process at all in this state.
- **No artifact this invocation stages ever reaches a live path except via
  the journaled publication transaction** (REQ-001, above, adversarial
  review "B1 atomicity"/"B8 TOCTOU"). "Stages" here means the on-disk
  `.resolver-staging/<batch-nonce>/` area, not REQ-001's separate
  in-memory assembly of the artifacts that precedes any publication — a
  Block reached after that in-memory work has begun is still governed by
  this rule for anything it assembled, and by AC-011/AC-038 for the three
  publication artifacts. When Resolver Evidence is a Block's whole write
  set, **that write never passes through the on-disk area** — REQ-001
  step (m) and REQ-004 fix it as a direct `temp file + fsync + rename` —
  so it is outside this sentence's subject
  rather than an exception to it (clarified 2026-08-27, human-approved,
  ruling D(2); the two senses of "stage" are distinguished here because
  the earlier wording read as false against steps (c)/(i)/(j)). Note that
  whether the on-disk area **exists** at such a Block is a separate
  question this sentence does not answer: the two step-(m) Blocks
  `artifact-publication-failed` and `post-publication-generation-mismatch`
  reach an Evidence-only write set only after the journaled transaction
  had already created that area and rolled the publication artifacts back
  through it (AC-039, AC-049) — the invariant is about the Evidence write's
  own route, not about the area's existence (corrected 2026-08-27 from a
  wider "never creates that on-disk area at all" claim that was false for
  exactly those two ids). A crash at
  any point, including
  between two renames, a Block, an in-process publication failure, or a
  post-publication-verification mismatch each leave every live path this
  feature's Resolver could write either fully absent, fully unchanged
  (converged there by the crash-recovery scan or an in-process rollback,
  both journal-based, never a bare `unlink` with no restore), or —
  Resolver Evidence only, on any Block except the two REQ-002 names —
  fully written, at whichever step that Block is reached, the step-(m)
  Blocks `artifact-publication-failed` and
  `post-publication-generation-mismatch` included (widened 2026-08-27 from
  a "before publication" clause that did not cover those two, although
  REQ-001 step (m), REQ-004 and AC-012 all require Evidence there);
  never a torn or partially-written artifact. A mixed generation across a
  multi-target batch likewise never stands **unattended**: the mandatory
  crash-recovery scan either converges it away before this invocation's
  own work begins, or — when the journal is unconvergeable — leaves it
  exactly as found and fails this invocation closed with
  `publication-journal-recovery` for manual operator intervention, which
  is the one state no automatic repair may touch (AC-047; scoped
  2026-08-27, human-approved, ruling D(2), replacing an absolute that
  contradicted that branch's own no-repair obligation).
- **Every invocation runs a mandatory crash-recovery scan, scoped to its
  own `--feature` value, before any other work begins** (B1, above) — a
  stale transaction journal from a prior, interrupted invocation is
  always resolved (or, if unrecoverable, fails this invocation closed
  with `publication-journal-recovery`) before this invocation's own
  Registry/ownership/Context-Projection work is ever attempted, matching
  this feature's own general "fail closed, never proceed on unverified
  state" posture.
- **This feature assumes a single writer to a given `--feature` value's
  own Resolver-owned output paths, and to the Project Context/ownership-
  source/Registry sources it reads, across one invocation's own
  multi-step sequence** (mirroring Epic A3's own single-writer/snapshot
  contract) — a concurrent second invocation against the identical
  `--feature`, or a concurrent edit to the same live output paths outside
  this Resolver's own transaction, is out of this feature's own scope; it
  is exactly the class of interference `snapshot-generation-mismatch`/
  `post-publication-generation-mismatch`/the crash-recovery scan exist to
  detect and fail closed on, never to serialize or prevent by themselves.
- This feature's Resolver never embeds an upstream dependency subprocess's
  own raw stderr text (which may carry local, OS-specific path or
  environment detail) in any diagnostic line or Resolver Evidence
  `detail` field it writes to a committed artifact (REQ-002, adversarial
  review "M8 stderr parity") — every `detail` is a canonical, Resolver-
  owned sentence built from fixed, repository-relative fields.

## Assumptions

- Epic A1's `canonicalize-sdd-yaml`, Epic A2's `evaluate-predicate`/
  `generate-registry-digest`/ADR-0025 discovery procedure, and Epic A3's
  `resolve-component-paths` each land, unmodified from their own
  `Spec-Review-Status: Passed` contracts, before this feature's own
  Phase-2 implementation begins. If any of the four sibling contracts
  changes materially before that point, this package's own design.md API
  / Contract Plan requires a corresponding follow-up edit (mirroring Epic
  A4's own identical assumption regarding Epic A2's Evidence JSON Schema,
  investigation.md INV-004).
- `resolve-project-context.{py,sh,ps1}`'s protected-suffix reservation
  (investigation.md INV-003) is live in `guard-invariants.json` by the
  time this feature's own Phase-2 implementation begins, per issue #187's
  own stated Epic sequencing (A0 → A1-A3 → A4 → A5). If it is not yet
  live at that time, the future implementation task re-verifies the
  file's then-current protection status before choosing a direct
  unprotected-first-then-register sequencing (mirroring Epic A1's own
  precedent for its 24 concrete-but-not-yet-existing entries,
  investigation.md INV-003) instead of the content-population-only
  human-copy this package assumes.
- The `sdd-bootstrap-interviewer` `SKILL.md`'s current unprotected status
  (investigation.md INV-017) is a live-repository snapshot, re-verified at
  the future implementation task's own start time, not a permanent
  guarantee (mirroring Epic A3's own identical disclaimer for a different
  file set).

## Open Questions

- OQ-001 (investigation.md, inherited from Epic A4's own OQ-002): Context
  Projection regeneration cadence beyond "once per Resolver invocation" —
  left to a future caller's own contract.
- OQ-002 (investigation.md): which future epic/caller invokes
  `compare-facet-manifest-staleness` against two of this feature's own
  outputs, and on what trigger.
- **OQ-003 is resolved by this revision** (design.md Design Decisions
  "caller insertion point"/"anchor fingerprint", adversarial review
  "M6"): the capability interview phase's insertion point is fixed to a
  concrete, file:line-cited anchor in the live `sdd-bootstrap-interviewer/
  SKILL.md` (`SKILL.md:60`'s `### Full-Profile Layer Interview` heading,
  at this package's own design-authoring time), with a **position-
  sensitive anchor-fingerprint drift check** (design.md Test Strategy
  item 10, AC-053) — a recorded window sha256 plus heading-ordinal-index
  pair, revised from an earlier revision's bare "heading text still
  exists" check, which could not detect the heading relocating within
  the file — guarding that citation. What remains for the future
  implementation task is only the direct-edit-vs.-human-copy mechanical
  choice (Roles and Permissions, above), not the insertion point itself.

## Risks

- **Lite-track resolution under `required` enforcement is Blocked for
  every real, non-trivial invocation with an unsourced matched Capability
  today; `advisory`-enforcement Lite resolution is not** (investigation.md
  INV-019, narrowed by cross-epic addendum, Epic A6 adversarial
  verification finding B5): because Epic A2's own, already-content-frozen
  Registry schema carries no field `required_lite_checks` can be sourced
  from, a matched Capability's own `lite_policy.required_lite_checks` key
  is absent for essentially every real Registry entry today. Under
  `capability_enforcement == required`, REQ-002's `lite-check-source-
  undefined` condition fires on that absence — the correct, fail-closed
  consequence of a real, confirmed cross-epic gap, not a design flaw of
  this feature. Under `capability_enforcement == advisory`, the identical
  absence is **not** a Block — it contributes an empty `[]` to that
  Capability's own `required_lite_checks` share, and the invocation
  resolves normally (REQ-002, above) — so an `advisory`-enforcement Lite
  Feature can usefully exercise this feature's Capability Summary output
  today, before any Epic A2 Registry-schema revision lands; only a
  `required`-enforcement Lite Feature with at least one such matched
  Capability remains blocked until that revision (or a future ADR naming
  a different source) exists. **The Epic A2 Registry-schema revision
  remains an explicit, owned prerequisite for Epic A6's
  `required`-enforcement Lite path specifically, not for Epic A6 as a
  whole** (Dependencies, above, adversarial review "B5 lite checks") —
  this package surfaces the gap explicitly (investigation.md INV-019,
  Dependencies) rather than papering over it with a fabricated source
  (this package's own Test Strategy accordingly contains no
  synthetic-Registry-extension fixture that would not itself pass
  `validate-capability-registry`, B5), so that the Registry-schema
  revision this fix actually requires, and its scope narrowed to
  `required` enforcement only, is visible at Epic A5's own spec-review
  time, not discovered later during Epic A6's own work.
- **The multi-component trigger-matching rule and the cross-Capability
  facet-name aggregation rule (REQ-001/AC-006/AC-043) are this feature's
  own new orchestration decisions**, not something any upstream ADR or
  sibling spec fixes (investigation.md INV-012). If a future Registry
  Capability author's intuition about "does this Capability apply to my
  multi-component Feature" or "how do two same-named `conditional_
  facets[]` entries across Capabilities combine" diverges from the rules
  this feature adopts, that divergence surfaces as a spec-review finding
  on this package, not as a silent behavioral surprise at implementation
  time — this package states both rules, and their citation-grounded
  rationale, explicitly (design.md Design Decisions) precisely so
  spec-review can evaluate them before implementation begins.
- **A future Epic A4 addendum is needed for the facet-name aggregation
  rule's own evidence-concatenation consequence, and a future Epic A2
  addendum candidate exists for same-Capability duplicate `facet`
  declarations** (design.md Design Decisions "facet-name aggregation,
  predicate-instance keyed"/Cross-Layer Dependencies "A4 addendum
  needed"/"A2 addendum candidate", adversarial review "B7"): Epic A4's
  own `conditional_facets[].evidence` schema already accommodates this
  feature's concatenated, multi-predicate-instance-contributor output
  without any schema change, but Epic A4's own prose (`design.md:
  413-422` in the Epic A4 worktree, "the whole array is copied verbatim
  from the evaluator's own output") describes only the
  single-contributing-invocation case. Separately, Epic A2's own Registry
  schema (`specs/epic-190-a2-capability-registry/requirements.md:
  169-173`) neither requires nor forbids, and states no prose either way
  about, a single Capability declaring the identical `conditional_
  facets[].facet` name more than once — this feature's own
  predicate-instance-keyed design (above) handles that case correctly
  regardless of how a future addendum resolves the ambiguity. This
  package names both gaps and takes no further action on either Epic's
  own content-frozen files (this task's own hard boundary) — see this
  package's own final report for both addendum recommendations.
- **The staged-generation/journaled-transactional-publication/
  provenance-binding rules (REQ-001/REQ-002/REQ-004, above, adversarial
  review "B1 atomicity"/"B6 provenance binding"/"B8 TOCTOU") add real
  implementation complexity** a future Phase-2 implementer must budget
  for — transaction-journal read/write/rehash, byte-exact pre-image
  backup, a mandatory crash-recovery scan on every invocation, a *third*
  `resolve-component-paths` invocation for post-publication verification
  in addition to the pre-publication recheck's own second one, and
  `validate-resolver-evidence`'s own ADR-0025 self-discovery plus
  digest-binding logic. This is the direct, accepted cost of closing the
  atomicity/TOCTOU/provenance gaps adversarial review found in an earlier
  revision of this package, not a design defect of this revision — Epic
  A1's own already-fixed transactional bundle contract (`design.md:
  927-1016` in the Epic A1 worktree) is the reference implementation a
  future Phase-2 task should study first rather than developing the
  journal/recovery mechanism from scratch.
- **`resolve-project-context.{py,sh,ps1}`'s protected-suffix reservation
  may not yet be live** when this feature's own Phase-2 implementation
  begins, depending on Epic A1's own landing schedule (Assumptions,
  above) — the future implementation task must re-verify this before
  choosing its own staging sequencing.
- **The anchor-fingerprint drift check (M6, requirements.md REQ-007,
  design.md Design Decisions "anchor fingerprint") requires its own
  recorded citation to be updated in the same commit as any future,
  intentional `SKILL.md` edit that moves this package's own insertion
  point** — a future implementer who forgets is caught immediately by
  AC-053's own drift-check fixture failing, not silently; this is the
  intended, low-cost trade-off of a position-sensitive check over the
  earlier revision's weaker, position-blind one.
