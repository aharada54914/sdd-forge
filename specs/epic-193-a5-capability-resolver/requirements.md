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
(INV-001..INV-019; OQ-001..OQ-003)

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

- **Epic A1 (Project Context) — schema shape, canonicalizer CLI, and the
  reserved Resolver script path (hard, already-`Passed` dependencies)**:
  `contracts/project-context.schema.json`'s `workflow`/`components`/
  `shared_paths` shapes (investigation.md INV-007) are read, never
  redefined, by this feature. `canonicalize-sdd-yaml`'s stdin/stdout-only,
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
  discovery algorithm.
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
  procedure): (a) derive the `disabled-legacy`/`advisory`/`required` state
  (REQ-003) from `--config` and refuse immediately if `disabled-legacy`
  (REQ-002); (b) invoke `canonicalize-sdd-yaml` (Epic A1) to obtain
  `source_sha256` and a parsed Project Context structure; (c) build the
  Context Projection via Epic A4's own two-pass-canonicalizer generation
  procedure, verbatim, and write it to `generated/project-context.
  resolved.json`; (d) invoke `resolve-component-paths` (Epic A3) with the
  identical `--config`/`--source-rev`/`--target-rev`/`--include-untracked`
  values this invocation received, to obtain `affected_components` and
  `ownership_digest`; if it exits non-zero, Block (REQ-002); (e) discover
  and validate the Registry (Epic A2, via ADR-0025) and compute
  `registry_digest --whole`; (f) for each affected component (in
  ascending lexicographic `id` order) and each Registry Capability,
  evaluate that Capability's `trigger` via `evaluate-predicate` against
  that component's Context-Projection properties (REQ-001's own
  multi-component matching rule, design.md Design Decisions); a Capability
  is "matched" (included in the Feature's `capabilities[]`) iff at least
  one affected component's evaluation returns `result: true`; (g) for each
  matched Capability, evaluate its `conditional_facets[].when` predicates
  the same way, and collect its `required_facets`/`gate_ids`/
  `lite_policy`/`minimum_enforcement`; (h) assemble the Facet Manifest
  (every field REQ-001 above and Epic A4's schema name), stable-sorting
  every semantic-output array (Epic A4's own REQ-001 mandate, reused
  verbatim); (i) if `workflow.spec_profile == lite`, additionally assemble
  the Capability Summary — subject to REQ-002's `lite-check-source-
  undefined` Block condition (investigation.md INV-019); (j) write
  `facet-manifest.yaml` (and, on the lite track, `capability-summary.
  yaml`) to `specs/<feature>/`, matching Epic A4's own REQ-007 storage
  location, and Resolver Evidence (REQ-004) alongside it.

- **REQ-002** (Ambiguous-input Block taxonomy — decision v2 §19's "曖昧な
  場合は Block", issue #193's own "曖昧なケースの Block 動作テスト" Done
  condition): Enumerate every condition under which the Resolver refuses
  to produce a Facet Manifest/Capability Summary/Context Projection,
  fail-closed, as a fixed, machine-readable diagnostic-id table (no
  fail-open path exists anywhere in this list):

  | Diagnostic ID | Trigger condition |
  |---|---|
  | `disabled-legacy-invocation` | The `--config` target is absent (or the AGENTS.md-marker/default fallback derives `disabled-legacy`, ADR-0016 item 4) — the Resolver refuses before touching Registry/ownership/Context-Projection machinery at all (investigation.md INV-013) |
  | `project-context-validation-failed` | `--config`'s target file exists but fails Epic A1's own content-schema validation surface (a present-but-invalid Context, distinct from an absent one) |
  | `affected-component-resolution-failed` | `resolve-component-paths` (Epic A3) exits non-zero for any reason (config-shape error, unresolvable rev, unattainable merge-base, NFC-collision, exceeded rename limit, TOCTOU mismatch) — an UNOWNED/OVERLAP classification present in a *successful* `resolve-component-paths` exit is data, not this condition, per Epic A3's own "classification results are data, not failure by themselves" rule; this feature does not reimplement `check-component-coverage`'s own Fail-condition logic |
  | `registry-validation-failed` | The located Registry fails Epic A2's own `validate-capability-registry` checks |
  | `contract-discovery-failed` | Any `contracts/*` artifact this feature's scripts need (Registry, its schema, any of Epic A4's three schemas, this feature's own `resolver-evidence.schema.json`) fails ADR-0025's discovery procedure (neither the script-relative packaged copy nor the git-root fallback resolves, or the artifact's own version check fails) |
  | `canonicalizer-invocation-failed` | Any `canonicalize-sdd-yaml` subprocess invocation this feature's Resolver makes (Project Context canonicalization, Context Projection's second pass, Registry-fragment/ownership-fragment digest inputs) exits non-zero |
  | `dsl-warn-on-matched-capability` | A matched Capability's own `trigger` Evidence, or a matched Capability's own `conditional_facets[].when` Evidence, contains at least one `outcome: "warn"` node anywhere in its evidence tree (design.md Design Decisions states the rationale and scope of this Resolver-level policy, layered on top of, and never contradicting, ADR-0020's own DSL-evaluator-level "WARN is not an error" rule) |
  | `lite-check-source-undefined` | `workflow.spec_profile == lite` and at least one matched Capability would need to contribute to `required_lite_checks`, but the Registry (Epic A2, content-frozen) carries no field this feature can source that list from (investigation.md INV-019) |

  Every Block exits non-zero (REQ-002's own exit-code contract, design.md)
  and writes **no** `facet-manifest.yaml`, `capability-summary.yaml`, or
  `project-context.resolved.json` — never a partial or schema-invalid
  instance of any of the three. Resolver Evidence (REQ-004) is still
  written on every Block (except `disabled-legacy-invocation`, whose own
  Evidence record is minimal by construction, recording only the fact of
  the out-of-contract invocation itself), mirroring `check-component-
  coverage`'s own NEW-001 "always emit an evidence record, never a bare
  skip line" discipline (investigation.md INV-006). Diagnostic lines follow
  this Epic set's own established `<producer>: <check-id>: <detail>`
  format (Epic A2's `registry: <check-id>: <detail>`, Epic A4's
  `facet-manifest: <check-id>: <detail>`): `capability-resolver:
  <check-id>: <detail>`.

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
  A3's). `advisory` and `required` are **not** distinguished by this
  feature's own Resolver output content — the same inputs under either
  state produce byte-identical `facet-manifest.yaml`/`capability-summary.
  yaml`/`project-context.resolved.json`/Resolver Evidence content (only
  `capability_minimum_enforcement`'s downstream interpretation at
  Gate-execution time differs, and that computation is explicitly out of
  this feature's own scope per A4's own Field Definitions, Dependencies
  above) — this feature's state-awareness therefore collapses, for its
  own purposes, to a two-way branch: `disabled-legacy` (refuse) vs.
  `{advisory, required}` (resolve normally, recording which of the two
  applied in Resolver Evidence's own `state` field for downstream
  auditability, even though it does not change this invocation's own
  output content).

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
  A2's Evidence-node shape, investigation.md INV-004), `resolver`
  (identical shape to Epic A4's own `resolverBlock` definition:
  `{version, rule_set_revision}`), `capability_evaluations` (array, one
  entry per Registry Capability **regardless of whether it matched** —
  "評価した全 capability... の記録" (issue #193) means every Capability the
  Resolver actually evaluated, not only the matched subset — each entry
  `{capability_id, matched: boolean, trigger_evaluations: [{component_id,
  result, evidence[]}, ...]}`, one `trigger_evaluations[]` element per
  affected component in ascending lexicographic order, and, for a matched
  Capability only, an additional `conditional_facet_evaluations: [{facet,
  applied, evaluations: [{component_id, result, evidence[]}, ...]}]`),
  and `diagnostics` (array of `{id (REQ-002's own enum), detail, severity:
  "block"|"warn"}`, recording **every** diagnostic-worthy condition this
  invocation encountered, not only the first/fatal one, mirroring
  ADR-0020's own "no short-circuit, every result recorded" discipline
  extended by this feature to its own diagnostic surface). Resolver
  Evidence is written on **every** invocation, success or Block
  (REQ-002), mirroring `check-component-coverage`'s own always-emit
  discipline (investigation.md INV-006). Design three deterministic,
  stdlib-only-Python-master-plus-`sh`/`ps1`-wrapper companion scripts
  (matching Epic A4's own `validate-facet-manifest`/etc. precedent,
  investigation.md INV-011): `validate-resolver-evidence.{py,sh,ps1}`
  (schema-conformance check, no `.js` wrapper — a structural validator,
  not a cross-runtime-hashed digest primitive).

- **REQ-005** (Idempotency and determinism — decision v2 §19's own
  "同一入力 → 同一出力（byte-identical）の決定論保証" and ADR-0020 item 6's
  Resolver-purity requirement, extended by this feature from the DSL layer
  to the whole Resolver): The same `--config`/`--source-rev`/`--target-rev`/
  `--feature` input, against the same repository state, produces
  byte-identical `facet-manifest.yaml`, `capability-summary.yaml` (when
  applicable), `project-context.resolved.json`, and Resolver Evidence
  output — across repeated invocations of the same runtime, and across
  `.py`/`.sh`/`.ps1` invocations of the identical input (dual-runtime
  parity, matching every other cross-runtime primitive this Epic set
  already establishes). Every semantic-output array this feature's
  Resolver writes is stable-sorted (Epic A4's own REQ-001 mandate, reused
  verbatim — Dependencies, above); `capability_evaluations[]` and
  `diagnostics[]` (REQ-004, this feature's own new arrays, not covered by
  Epic A4's mandate since they live in a schema Epic A4 does not define)
  are likewise stable-sorted (`capability_evaluations[]` by
  `capability_id`, `diagnostics[]` by `(id, detail)` tuple). This feature's
  Resolver reads the clock, the network, and no provider API anywhere in
  its own orchestration logic — the identical "no code path can read the
  clock, the network, or invoke a provider API" guarantee ADR-0020 already
  establishes for the DSL evaluator itself extends to this feature's own
  orchestration layer wrapping it (no `datetime.now()`-derived value, no
  environment-variable-derived nondeterminism beyond the fixed, documented
  discovery-contract fallback ADR-0025 already specifies).

- **REQ-006** (Tests — decision v2 §19's own "同一 fixture での sh/ps1
  出力 byte-identical テスト" and "曖昧ケースの Block 動作テスト" Done
  conditions): Design `tests/*.tests.sh`/`.tests.ps1` pairs and fixture
  data under `tests/fixtures/capability-resolver/`, covering, at minimum:
  a full match/no-match/conditional/WARN/Block fixture matrix — (a) a
  Capability whose `trigger` matches at least one affected component
  (match); (b) a Capability whose `trigger` matches none (no-match); (c) a
  matched Capability with a `conditional_facets[].when` that itself
  matches (`applied: true`) and one that does not (`applied: false`,
  `reason` present); (d) a matched Capability whose `trigger`/`when`
  evaluation contains a `WARN` node whose own outcome is *not*
  determining (accepted, recorded, not Blocked) and, separately, one
  whose own outcome *is* determining for a matched Capability (Blocked,
  `dsl-warn-on-matched-capability`); (e) one fixture per REQ-002
  diagnostic-id row, each independently testable; plus REQ-005's own
  dual-runtime parity suite and REQ-003's `disabled-legacy`/
  `{advisory,required}`-byte-identical-content proof. Discovery-contract
  fixtures (installed-standalone-plugin layout, one per runtime) reuse
  Epic A2's own three-fixture pattern (investigation.md INV-005), applied
  to this feature's own new `resolver-evidence.schema.json` in addition to
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
  detection and before any Facet-dependent layer is generated; (c) asks
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
| AC-003 | REQ-001 | The Context Projection this feature's Resolver writes to `generated/project-context.resolved.json` is produced by Epic A4's own two-pass-canonicalizer generation procedure, verbatim — a fixture pair (one hand-computed via the documented procedure, one produced by invoking the Resolver against the identical `project-context.yaml`) is byte-identical |
| AC-004 | REQ-001 | The Resolver invokes `resolve-component-paths` with the identical `--config`/`--source-rev`/`--target-rev`/`--include-untracked` values it itself received, and consumes exactly its `affected_components` and `ownership_digest` output — never a subset, never a caller-supplied override |
| AC-005 | REQ-001 | `context_binding.registry_digest` is bound via `generate-registry-digest --whole`, never a `--capability-ids`/`--gate-ids` fragment |
| AC-006 | REQ-001 | For a Feature with two affected components where only one component's properties satisfy a Capability's `trigger`, that Capability is included in `capabilities[]` (the union-match rule, design.md Design Decisions) |
| AC-007 | REQ-001 | `required_facets`/`conditional_facets`/`resolved_gates`/`capabilities`/`capability_minimum_enforcement`/`lite_eligibility` are each populated per Epic A4's own field-by-field rules (Dependencies, above) with no additional field and no field omitted that Epic A4's schema requires |
| AC-008 | REQ-001 | The written `facet-manifest.yaml` validates successfully against `contracts/facet-manifest.schema.json` (Epic A4) for a representative multi-Capability, multi-affected-component fixture |
| AC-009 | REQ-001 | On the Lite track (`workflow.spec_profile == lite`) with a source able to populate `required_lite_checks`, the written `capability-summary.yaml` validates successfully against `contracts/capability-summary.schema.json` (Epic A4) |
| AC-010 | REQ-002 | Each of the seven REQ-002 diagnostic-id rows has its own independently-triggerable fixture; no other condition produces a non-zero exit |
| AC-011 | REQ-002 | On any Block, no `facet-manifest.yaml`, `capability-summary.yaml`, or `project-context.resolved.json` is written or left partially written (a fixture asserts none of the three paths exists, or is unchanged from its pre-invocation state, after a Blocked run) |
| AC-012 | REQ-002 | Resolver Evidence is written on every Block except `disabled-legacy-invocation`, whose own minimal Evidence record is written instead of the full form |
| AC-013 | REQ-002 | Exit code contract: `0` on success, `1` on any REQ-002 Block, `2` on a CLI usage error (AC-001) — fixed, tested per value |
| AC-014 | REQ-002 | Every diagnostic line this feature's scripts emit follows the `capability-resolver: <check-id>: <detail>` format, `<check-id>` drawn only from REQ-002's own enum |
| AC-015 | REQ-003 | `disabled-legacy` (absent `--config` target, or the AGENTS.md-marker/default fallback deriving it) produces `disabled-legacy-invocation` before any Registry/ownership/Context-Projection work is attempted (a fixture confirms no `resolve-component-paths`/Registry-discovery subprocess is ever invoked in this branch) |
| AC-016 | REQ-003 | A fixture pair identical except for `workflow.capability_enforcement` (`advisory` vs. `required`) produces byte-identical `facet-manifest.yaml`/`capability-summary.yaml`/`project-context.resolved.json` content; only Resolver Evidence's own `state` field differs |
| AC-017 | REQ-004 | `contracts/resolver-evidence.schema.json` exists, is valid draft-07, and its `$id` matches every other `contracts/*.schema.json`'s convention |
| AC-018 | REQ-004 | `capability_evaluations[]` includes one entry for **every** Registry Capability, not only matched ones — a fixture with an unmatched Capability confirms its own entry is present with `matched: false` and a non-empty `trigger_evaluations[]` |
| AC-019 | REQ-004 | A matched Capability's `capability_evaluations[]` entry carries a `conditional_facet_evaluations[]` entry per `conditional_facets[]` the Registry declares for it; an unmatched Capability's entry carries none |
| AC-020 | REQ-004 | Resolver Evidence is written on a fully successful run as well as on every Block (AC-012) — never conditionally omitted on success |
| AC-021 | REQ-004 | `validate-resolver-evidence.{py,sh,ps1}` exits 0 on a schema-conformant fixture and non-zero (with a `resolver-evidence: <check-id>: <detail>` diagnostic) on a fixture missing any required field |
| AC-022 | REQ-005 | Two invocations of the identical `.py` Resolver against the identical input produce byte-identical `facet-manifest.yaml`/`capability-summary.yaml`/`project-context.resolved.json`/Resolver Evidence output |
| AC-023 | REQ-005 | `.py`/`.sh`/`.ps1` invocations of the identical input produce byte-identical output across all four written artifacts, and identical stdout/stderr/exit code |
| AC-024 | REQ-005 | `capability_evaluations[]` is stable-sorted by `capability_id`; `diagnostics[]` is stable-sorted by `(id, detail)`; every Epic-A4-mandated Facet Manifest array (Dependencies, above) is stable-sorted per Epic A4's own rule |
| AC-025 | REQ-005 | A repository-wide grep confirms no Resolver-owned script reads `datetime.now()`/`time.time()`/any network call/any provider-API call anywhere in its own orchestration logic (the DSL evaluator itself, Epic A2's own scope, is out of this check) |
| AC-026 | REQ-006 | Each new `tests/*.tests.sh`/`.tests.ps1` pair this feature's future task phase authors is registered directly (unprotected) in `tests/run-all.sh`/`.ps1`, matching Epic A2/A4's own precedent |
| AC-027 | REQ-006 | The fixture matrix (REQ-006's own five items a-e) is present under `tests/fixtures/capability-resolver/`, each fixture independently invocable |
| AC-028 | REQ-006 | Three discovery-contract fixtures (one per runtime) confirm a standalone-installed-plugin layout (only the packaged `plugins/sdd-quality-loop/contracts/*` copy present, no monorepo `contracts/`, no reachable `.git`) resolves and validates correctly for every artifact this feature's scripts locate |
| AC-029 | REQ-007 | This package's `design.md` documents the capability interview phase's exact insertion point relative to `sdd-bootstrap-interviewer`'s existing steps, its question-budget rule (≤15 per pass), its Open-Questions-persistence rule, and its resumability rule, each citing decision document v2 §18.4 directly |
| AC-030 | REQ-007 | This package's `design.md` documents the Context-absent case as producing the identical bootstrap flow existing today (event-identical, no capability-phase step reachable) |
| AC-031 | REQ-007 | This package's `design.md` documents the on-Block behavior (surface the diagnostic, never silently degrade to a non-Capability-aware flow) with an explicit citation to decision document v2 §7's own "legacy mode へ黙ってフォールバックしてはならない" principle |
| AC-032 | REQ-007 | No file under `plugins/**` is modified by this package's own commits |
| AC-033 | REQ-008 | A future implementation task's diff carries its own `CHANGELOG.md` `## Unreleased` entry citing #193 |
| AC-034 | REQ-008 | A repository-wide grep-based self-check confirms no version string is mutated anywhere in this feature's diff outside a `scripts/bump-version.sh` invocation |
| AC-035 (Global) | — | `check-workflow-state.sh --feature epic-193-a5-capability-resolver` exits 0 after this package's registration commit lands, with no `tasks.md`/`traceability.md` present and `requirements.md`'s `Spec-Review-Status: Pending`/`design.md`'s `Impl-Review-Status: Pending` headers intact |
| AC-036 (Global) | — | `check-sdd-structure.sh` (no feature argument) exits 0 after this package's registration commit, run as `sh scripts/check-sdd-structure.sh .` |
| AC-037 (Global) | — | `specs/workflow-state-registry.json`'s new entry is exactly `{"feature": "epic-193-a5-capability-resolver", "profile": "full"}`, no additional keys, appended to this worktree's own `entries` array |

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
  Block always means "this invocation produced no Facet Manifest/
  Capability Summary/Context Projection at all," never a partial or
  degraded one.
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
  actual content — staged under `specs/epic-193-a5-capability-resolver/
  human-copy/` for human application via `apply-human-copy` (Epic A1's own
  publisher), since the target path is already protected before this
  feature's own first write (investigation.md INV-003) — never a direct
  agent write to the live path.
- **A future Resolver invocation (any caller)**: the sole intended writer
  of live `facet-manifest.yaml`/`capability-summary.yaml`/`project-
  context.resolved.json`/Resolver Evidence instances for a real Feature —
  this feature's own contract states these are agent-writable-only-via-
  the-Resolver artifacts (matching Epic A4's own Roles and Permissions
  statement, Dependencies, above), never hand-edited.
- **A future implementation task touching `sdd-bootstrap-interviewer`'s
  `SKILL.md`**: re-verifies that file's then-current protection status
  before choosing a direct edit or a human-copy application
  (investigation.md INV-017).

## Main Workflows

1. **Successful full-track resolve**: caller invokes
   `resolve-project-context --config sdd/project-context.yaml
   --target-rev main --feature my-feature` → state derives `advisory` or
   `required` → Context Projection generated → `resolve-component-paths`
   returns `affected_components: [component-a, component-b]` and an
   `ownership_digest` → Registry discovered, `registry_digest --whole`
   computed → each Registry Capability's `trigger` evaluated against
   `component-a` then `component-b` → matched Capabilities' facets/gates/
   lite-policy collected → `facet-manifest.yaml` written to
   `specs/my-feature/`, `project-context.resolved.json` written to
   `generated/`, Resolver Evidence written alongside `facet-manifest.
   yaml` → exit 0.
2. **Successful lite-track resolve with a resolvable check source**: as
   above, but `workflow.spec_profile == lite` and every matched Capability
   contributing to `required_lite_checks` has a resolvable source →
   `capability-summary.yaml` additionally written → exit 0. (Given
   investigation.md INV-019's confirmed gap, this workflow currently has
   no real-world instance — see Risks.)
3. **Lite-track resolve, unresolvable check source**: as workflow 2, but
   at least one matched Capability's `required_lite_checks` contribution
   cannot be sourced from the Registry → Block,
   `lite-check-source-undefined`, Resolver Evidence written recording the
   diagnostic, no `capability-summary.yaml` (or `facet-manifest.yaml`)
   written → exit 1.
4. **`disabled-legacy` invocation**: caller invokes the Resolver against a
   project with no `project-context.yaml` (or the AGENTS.md-marker/
   default fallback derives `disabled-legacy`) → Block,
   `disabled-legacy-invocation`, before any other work begins → minimal
   Resolver Evidence written → exit 1.
5. **`sdd-bootstrap-interviewer` capability interview phase**: after track
   detection, if a Project Context is present and its state is not
   `disabled-legacy`, the interviewer invokes the Resolver once (workflow
   1/2/3, above); on exit 0, the interviewer proceeds to facet generation
   using the written `facet-manifest.yaml`; on exit 1 (Block) or 2
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
  forces an upgrade). This is distinct from `affected-component-
  resolution-failed` (REQ-002), which fires only on `resolve-component-
  paths`'s own non-zero exit, never on a legitimately-empty
  `affected_components` array from a successful exit.
- **A Capability's `trigger` WARNs on one affected component but matches
  cleanly on another**: the Capability is matched (union-match, AC-006);
  its `capability_evaluations[]` entry (Resolver Evidence) records both
  per-component evaluations in full; whether `dsl-warn-on-matched-
  capability` fires depends only on whether the WARN-producing
  component's own evaluation is the representative one this feature's
  Facet Manifest embeds for a given `conditional_facets[].evidence` entry
  (design.md Design Decisions fixes the representative-selection rule) —
  a WARN on a non-representative, non-determining branch is recorded, not
  Blocked, matching ADR-0020's own "WARN is not an error" principle at the
  DSL-evaluator layer; a WARN on the representative, determining branch of
  a matched Capability's own evaluation is Blocked (REQ-002), per this
  feature's own Resolver-level policy layered on top of that DSL-layer
  rule.
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
  Resolver still recomputes and re-writes a fresh `facet-manifest.yaml`
  reflecting the new `registry_digest` (REQ-001/REQ-005's own
  determinism-from-current-inputs rule) — whether that change makes the
  Feature "stale" is `compare-facet-manifest-staleness`'s own concern
  (Epic A4, Non-goals), not this feature's; this feature never itself
  decides staleness.

## Security Boundaries

- The Resolver's own orchestration logic never invokes a Provider API,
  reads a credential, or writes outside `specs/<feature>/facet-manifest.
  yaml`/`capability-summary.yaml`, `generated/project-context.resolved.
  json`, and its own Resolver Evidence path — matching ADR-0020's own
  Provider-neutrality boundary for the DSL layer, extended by this
  feature's REQ-005 to its own orchestration layer.
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
  a Facet Manifest while the capability pipeline is derived-inactive.

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
- OQ-003 (investigation.md): the exact numbered-step insertion point for
  the capability interview phase within `sdd-bootstrap-interviewer`'s
  live `SKILL.md` — left to the future implementation task that actually
  edits that file.

## Risks

- **Lite-track resolution is effectively Blocked for every real
  invocation today** (investigation.md INV-019): because Epic A2's own,
  already-content-frozen Registry schema carries no field
  `required_lite_checks` can be sourced from, REQ-002's
  `lite-check-source-undefined` condition fires for essentially any
  Lite-track Feature with at least one matched Capability that would
  otherwise need to contribute a Lite check. This is the correct,
  fail-closed consequence of a real, confirmed cross-epic gap — not a
  design flaw of this feature — but it means Epic A6 (Lite統合) cannot
  usefully build on this feature's Capability Summary output until either
  a future Epic A2 Registry-schema revision adds the missing field, or a
  future ADR names a different source. This package surfaces the gap
  explicitly (investigation.md INV-019, this section) rather than
  papering over it with a fabricated source, so that the Registry-schema
  revision this fix actually requires is visible at Epic A5's own
  spec-review time, not discovered later during Epic A6's own work.
- **The multi-component trigger-matching rule (REQ-001/AC-006) is this
  feature's own new orchestration decision**, not something any upstream
  ADR or sibling spec fixes (investigation.md INV-012). If a future
  Registry Capability author's intuition about "does this Capability apply
  to my multi-component Feature" diverges from the union-match rule this
  feature adopts, that divergence surfaces as a spec-review finding on
  this package, not as a silent behavioral surprise at implementation
  time — this package states the rule, and its citation-grounded
  rationale, explicitly (design.md Design Decisions) precisely so
  spec-review can evaluate it before implementation begins.
- **`resolve-project-context.{py,sh,ps1}`'s protected-suffix reservation
  may not yet be live** when this feature's own Phase-2 implementation
  begins, depending on Epic A1's own landing schedule (Assumptions,
  above) — the future implementation task must re-verify this before
  choosing its own staging sequencing.
