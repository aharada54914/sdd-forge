# Design: epic-193-a5-capability-resolver

Impl-Review-Status: Pending
Feature Type: one new deterministic script family (`resolve-project-
context.{py,sh,ps1}`, at a path Epic A1 already reserved as protected)
plus companion validator scripts (`validate-resolver-evidence.{py,sh,
ps1}`), one new `contracts/resolver-evidence.schema.json` contract, and a
documented (not implemented) caller-side integration contract for
`sdd-bootstrap-interviewer`'s future capability interview phase. No new
plugin (reuses `plugins/sdd-quality-loop/`, matching Epic A2/A4's own
rejected-new-plugin precedent). No live Resolver implementation, and no
live Facet Manifest/Capability Summary/Context Projection/Resolver
Evidence instance, is built by this package (requirements.md Non-goals) —
this is a Phase 1, contract-fixing design.

## Technical Summary

Epic A5 is the last of five Foundation epics decision document v2 §19/§20
sequences before Epic A6 (Lite統合) can begin: A1 (Project Context) fixes
the input schema and canonicalizer; A2 (Capability Registry) fixes the
Registry schema, the Predicate DSL evaluator, and (via ADR-0025) the
cross-Epic discovery contract; A3 (Component Path Ownership) fixes the
only route to a Feature's affected components; A4 (Facet Manifest) fixes
the exact shape of three of this feature's four outputs, before this
feature's Resolver exists to produce them. This design's job is narrow and
almost entirely combinatorial: wire those four already-`Spec-Review-
Status: Passed`, content-frozen contracts together into one deterministic
CLI (`resolve-project-context`) that reads a Project Context, a Registry,
and a git-diff-derived affected-component set, evaluates the Predicate DSL
(unmodified) once per (Capability `trigger`, affected component) pair and
once per (matched Capability's `conditional_facets[].when`, affected
component) pair, and assembles a Facet Manifest (+ Context Projection, +
on the Lite track, a Capability Summary) that already validates against
Epic A4's own schemas — plus one genuinely new artifact, Resolver Evidence,
whose shape no upstream contract fixes (requirements.md REQ-004). The one
place this design makes a real, new decision rather than a mechanical
transcription is the multi-affected-component matching rule (Design
Decisions, below) — `evaluate-predicate`'s own CLI takes exactly one
component's properties per call, and no upstream spec says how several
per-component results combine into one Feature-level match/no-match.

## Architecture

```
                         project-context.yaml (A1)
                                   │
                    ┌──────────────┴───────────────┐
                    │ canonicalize-sdd-yaml (A1)    │
                    │  pass 1: YAML → source_sha256 │
                    └──────────────┬───────────────┘
                                   │ parsed structure
                    ┌──────────────┴───────────────┐
                    │ Context Projection assembly    │  ── A4 REQ-003
                    │  (re-key components by id;      │     generation
                    │   canonicalize-sdd-yaml pass 2  │     procedure,
                    │   → projection_sha256)          │     verbatim
                    └──────────────┬───────────────┘
                                   │ project-context.resolved.json
    --config/--source-rev/        │ (generated/, A1-reserved path)
    --target-rev/--include-       │
    untracked ────────────────────┤
                    ┌──────────────┴───────────────┐
                    │ resolve-component-paths (A3)  │
                    │  → affected_components[]       │
                    │  → ownership_digest             │
                    └──────────────┬───────────────┘
                                   │
                    ┌──────────────┴───────────────┐
                    │ Registry discovery (A2, ADR-0025)│
                    │  → capability-registry.json      │
                    │  → registry_digest --whole       │
                    └──────────────┬───────────────┘
                                   │
      for each affected_component × each Registry capability:
                    ┌──────────────┴───────────────┐
                    │ evaluate-predicate (A2)         │  ── per-component
                    │  trigger against component        │     fan-out +
                    │  properties (Context Projection)   │     union-match
                    └──────────────┬───────────────┘     (this feature's
                                   │ matched capability set    own rule,
                    ┌──────────────┴───────────────┐     Design Decisions)
                    │ evaluate-predicate (A2)         │
                    │  conditional_facets[].when          │
                    │  per matched capability               │
                    └──────────────┬───────────────┘
                                   │
                    ┌──────────────┴───────────────┐
                    │ Facet Manifest / Capability      │  ── A4 schemas,
                    │  Summary assembly + stable-sort   │     verbatim
                    └──────────────┬───────────────┘
                                   │
                    ┌──────────────┴───────────────┐
                    │ Resolver Evidence assembly       │  ── this feature's
                    │  (every capability, every         │     own new
                    │   diagnostic, both digests)        │     schema
                    └──────────────┬───────────────┘
                                   ▼
       specs/<feature>/facet-manifest.yaml
       specs/<feature>/capability-summary.yaml  (lite track only)
       generated/project-context.resolved.json
       specs/<feature>/... resolver-evidence path (Data Plan)
```

Any Block (requirements.md REQ-002) short-circuits this pipeline at the
step named in its own diagnostic-id row and skips every step after it —
`disabled-legacy-invocation` short-circuits before Context Projection
assembly even begins.

## Components

| Component | Responsibility | Technology | New/Existing | Protected? |
|---|---|---|---|---|
| `contracts/resolver-evidence.schema.json` | schema for this feature's own new Resolver Evidence artifact (`sdd-resolver-evidence/v1`) | JSON Schema | new | no |
| `plugins/sdd-quality-loop/scripts/resolve-project-context.py` | Python master: orchestrates canonicalizer, Context Projection assembly, `resolve-component-paths`, Registry discovery, per-component `evaluate-predicate` fan-out, Facet Manifest/Capability Summary/Resolver Evidence assembly, REQ-002 Block taxonomy | Python | new (path already reserved-protected by Epic A1, investigation.md INV-003) | **YES (already reserved by A1)** |
| `plugins/sdd-quality-loop/scripts/resolve-project-context.sh` / `.ps1` | thin dispatchers, `python3`/`python` resolution only — no native fallback, matching `canonicalize-sdd-yaml`'s own dispatch shape (Epic A1 precedent) | POSIX sh / PowerShell | new (path already reserved-protected by Epic A1) | **YES (already reserved by A1)** |
| `plugins/sdd-quality-loop/scripts/generated/project-context.resolved.json` | Context Projection instance, one per repository, regenerated on every Resolver invocation | JSON | new (path already reserved-protected by Epic A1) | **YES (already reserved by A1)** |
| `plugins/sdd-quality-loop/scripts/validate-resolver-evidence.py` / `.sh` / `.ps1` | schema-conformance validator for this feature's own new artifact, matching Epic A4's own three-validator precedent | Python + sh/ps1 wrappers | new | no |
| `specs/<feature>/facet-manifest.yaml` | per-Feature Facet Manifest instance, schema `sdd-facet-manifest/v1` (Epic A4) | YAML | new instances only (schema is Epic A4's) | no (agent-writable only via the Resolver, matching Epic A4's own convention) |
| `specs/<feature>/capability-summary.yaml` | per-Feature Capability Summary instance, Lite track only, schema `sdd-capability-summary/v1` (Epic A4) | YAML | new instances only | no |
| `specs/<feature>/resolver-evidence.yaml` (Data Plan, below) | per-Feature Resolver Evidence instance, schema `sdd-resolver-evidence/v1` (this feature) | YAML | new (schema is this feature's own) | no |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md` | future capability interview phase integration (REQ-007) — **documented, not edited, by this package** | Markdown (skill) | existing, unmodified by this package | no (per Epic A1's own investigation; re-verified at future implementation time, investigation.md INV-017) |

## Protected-File Statement

Verified directly against `plugins/sdd-quality-loop/references/guard-
invariants.json` (this worktree, at design-authoring time: `grep -n
"resolve-project-context" plugins/sdd-quality-loop/references/guard-
invariants.json` returns no match — the reservation is not yet live on
this worktree's own branch state, investigation.md INV-003) and against
Epic A1's own `design.md:143-144,195-196`, which already registers this
exact reservation as one of its own package's deliverables.

**This feature's own Protected-File situation is different in kind from
every sibling epic's.** Epic A3's own precedent (`resolve-component-
paths.*` is *not* protected — a component resolver that any agent may edit
directly) does **not** apply here: `resolve-project-context.{py,sh,ps1}`
and `generated/project-context.resolved.json` are **already** reserved,
protected-suffix-shaped placeholders, registered by an *upstream* epic
(Epic A1, via ADR-0019 item 3), not by this feature's own design decision
(unlike Epic A3's `check-component-coverage.*`, which A3 itself chose to
protect as part of *its own* design). This feature therefore inherits a
build-then-stage discipline it did not itself decide:

1. When this feature's future Phase-2 implementation task begins, it first
   confirms whether Epic A1's own `REQ-007` human-copy batch (which
   performs the live `guard-invariants.json` registration) has already
   landed on `main` — per issue #187's own stated Epic sequencing (A0 →
   A1-A3 → A4 → A5), it is expected to have landed by the time this
   feature's own implementation begins (requirements.md Assumptions).
2. If it has landed: this feature's own two reserved paths are already
   protected, with no file yet on disk at either path (a suffix match
   denies a write regardless of whether a file currently exists at that
   path — Epic A1's own `_validate_repo_path`, "checks path SHAPE only").
   This feature's implementation task therefore develops
   `resolve-project-context.py`/`.sh`/`.ps1` and the initial
   `project-context.resolved.json` content **unprotected-first**, at a
   fully testable location (e.g. this package's own `specs/epic-193-
   a5-capability-resolver/` working tree, or any non-protected path), then
   stages the finished, tested content under `specs/epic-193-a5-
   capability-resolver/human-copy/<repository-relative-path>` with a
   `MANIFEST.sha256` entry, for a human to apply via `apply-human-copy`
   (Epic A1's own publisher) — a **content-population** human-copy, never
   a suffix-registration one (Epic A1 already performed that
   registration; this feature's own task does not touch `guard-
   invariants.json` at all).
3. If it has not yet landed at that time: the future implementation task
   falls back to the sequencing Epic A1 itself used for its own 24
   concrete-but-not-yet-existing entries (`design.md:222-236` in the Epic
   A1 worktree) — author the scripts unprotected-first, then let Epic A1's
   own (still-pending) human-copy batch perform the registration in the
   same commit it already plans to, rather than this feature inventing a
   second, competing registration of the identical two paths.

`validate-resolver-evidence.{py,sh,ps1}` and `contracts/resolver-evidence.
schema.json` are **not** protected — matching Epic A4's own three schema
validators (Epic A4 `design.md`, "no `.js` wrapper — these are structural
validators, not cross-runtime-hashed digest primitives"), agent-editable
directly, with no human-copy step. `specs/<feature>/facet-manifest.yaml`/
`capability-summary.yaml`/`resolver-evidence.yaml` are per-Feature
generated instances, unprotected (matching Epic A4's own convention —
"agent-writable-only-via-the-Resolver," never hand-edited, the same
convention `tasks.md` establishes for a different generated-then-reviewed
artifact class) — protection would be meaningless for a per-Feature
artifact only the Resolver itself is ever expected to write.

No file this feature's future implementation touches, beyond the two
already-reserved paths above, is added to `PROTECTED_GATE_SUFFIXES` — this
feature does not introduce a new protection category the way Epic A3's
own `check-component-coverage.*` did (Epic A3 `design.md` situation 3);
its only interaction with the guard-invariants surface is filling in
content at a reservation an upstream epic already made.

## Layer Specifications

Not applicable — this feature has no `frontend-spec.md`/`ux-spec.md`/
`infra-spec.md`/`security-spec.md` at this phase (requirements.md
Non-goals; investigation.md INV-015 confirms this matches Epic A2's and
Epic A4's own precedent of adding those later, at impl-review-prep time,
not as part of the Phase 1 spec-review commit). This feature ships no UI,
no infrastructure beyond existing repository scripts, and its security
posture is covered directly in this document's own Security Boundaries
section below (matching Epic A2/A3/A4's own identical treatment for a
backend-only, script-producing feature).

## Design System Compliance

Not applicable — no UI surface.

## Cross-Layer Dependencies

- **REQ-001 → Epic A1's canonicalizer, Epic A4's Context Projection
  generation procedure**: blocked until both land (requirements.md
  Dependencies).
- **REQ-001 → Epic A3's `resolve-component-paths`**: blocked until it
  lands; this feature's own `affected-component-resolution-failed`
  diagnostic (REQ-002) is the only interface this feature has to that
  script's own non-zero-exit conditions — this feature never re-derives
  them.
- **REQ-001/REQ-005 → Epic A2's `evaluate-predicate`/`generate-registry-
  digest`/ADR-0025 discovery**: blocked until they land.
- **REQ-001 → Epic A4's three schemas**: blocked until they land;
  content-frozen once Epic A4 itself reaches `Spec-Review-Status:
  Passed` (already true, investigation.md INV-002), so this feature's own
  design does not need to track further Epic A4 churn, only implement
  against the frozen shape.
- **REQ-004 (this feature's own new schema) → no upstream dependency** —
  this is the one artifact this feature is free to shape itself
  (investigation.md INV-018), subject only to the repository-wide
  `contracts/*.schema.json` conventions (investigation.md INV-011).
- **REQ-007 → a future implementation task, not this package** — this
  package documents the target contract; the actual `SKILL.md` edit is
  out of this package's own scope (requirements.md Non-goals).
- **Downstream (anticipated future consumer)**: Epic A6 (Lite統合) is the
  anticipated consumer of this feature's Capability Summary output — see
  Risks, below, for why that consumption is currently blocked by
  investigation.md INV-019's Registry-schema gap, independent of this
  feature's own completeness.
- **Downstream (anticipated future consumer)**: a future epic (plausibly
  A6/A8) is the anticipated caller of Epic A4's `compare-facet-manifest-
  staleness` against two of this feature's own Facet Manifest outputs
  (investigation.md OQ-002) — this feature's own output shape (stable-
  sorted semantic-output arrays, requirements.md REQ-005) is designed so
  that future caller's comparison is well-defined without requiring any
  change to this feature's own contract.

## ADR Change Log

No new ADR is authored by this feature (requirements.md Non-goals).
Every design decision this package makes is already recorded in
`docs/adr/0016-workflow-axes-separation.md` (three-axis model,
`disabled-legacy` derivation), `docs/adr/0017-gate-stage-model.md` (Gate
stage enum this feature copies verbatim into `resolved_gates[]`),
`docs/adr/0019-approval-sidecar-protection.md` (item 3's Resolver-
protection reservation, this feature's own Protected-File Statement),
`docs/adr/0020-conditional-predicate-dsl.md` (the DSL this feature
evaluates, unmodified), `docs/adr/0021-context-projection-staleness.md`
(`context_binding` shape and semantic-output definition this feature
populates), `docs/adr/0023-track-selection-contract-migration.md` (cited
for context; this feature does not itself implement track-selection CLI
precedence, that remains Epic A1's own REQ-009 scope), and (in the Epic A2
worktree) `docs/adr/0025-registry-discovery-contract.md` (the discovery
procedure this feature reuses unmodified, investigation.md INV-005) — this
design implements those seven ADRs' decisions, plus two new,
not-independently-ADR-worthy decisions this design records below (Design
Decisions): the multi-affected-component matching rule, and the
representative-evidence-selection rule for a matched Capability's embedded
`conditional_facets[].evidence`. Both are narrow, mechanical extensions of
`evaluate-predicate`'s own already-fixed single-component CLI shape
(investigation.md INV-012), not new architectural axes on the scale
ADR-0016/0020/0021 already establish — if impl-review disagrees, promoting
either to its own ADR is a low-cost follow-up (matching Epic A1's own
identical "resolved-but-revisitable choice, not a gap" framing for its
`approver-registry.yaml`, Epic A1 `design.md:291-297`).

## Data Plan

Data Entities:

- **`contracts/resolver-evidence.schema.json`** (new, this feature's own):
  `schema` (`const: "sdd-resolver-evidence/v1"`), `feature` (string,
  `^[a-z0-9][a-z0-9-]*$`), `state` (enum: `disabled-legacy`/`advisory`/
  `required`), `context_binding` (identical shape to Epic A4's own
  `contextBinding` definition — `full_context_revision`,
  `dependency_pointers[]`, `projection_sha256`, `registry_digest`,
  `ownership_digest`, each a `sha256:<64-hex>` digest), `resolver`
  (identical shape to Epic A4's own `resolverBlock` — `version`,
  `rule_set_revision`), `capability_evaluations[]` (one entry per Registry
  Capability: `{capability_id, matched: boolean, trigger_evaluations:
  [{component_id, result: boolean, evidence: [<Epic-A2-Evidence-node-
  shape, embedded structurally like Epic A4's own evidenceNode>]}]`, and,
  only when `matched: true`, `conditional_facet_evaluations: [{facet,
  applied: boolean, evaluations: [{component_id, result, evidence}]}]`}),
  `diagnostics[]` (`{id: <REQ-002's own 7-value enum>, detail: string,
  severity: "block"|"warn"}`). `additionalProperties: false` at every
  level, matching every other `contracts/*.schema.json` in this
  repository.
- **`specs/<feature>/facet-manifest.yaml`**, **`specs/<feature>/
  capability-summary.yaml`**, **`generated/project-context.resolved.
  json`**: Epic A4's own already-fixed shapes (requirements.md
  Dependencies) — this feature reads none of them as input to any other
  step; each is a pure output this feature's Resolver writes once per
  invocation.
- **`specs/<feature>/resolver-evidence.yaml`** (new, this feature's own
  storage-location convention, REQ-004): placed directly alongside
  `facet-manifest.yaml`, matching Epic A4's own REQ-007 placement
  rationale verbatim (git-diff-reviewability by a human reading a PR;
  RFC 8785/YAML-1.2-core canonicalization applies uniformly regardless of
  source format, so choosing `.yaml` over `.json` carries no cross-
  runtime-hashing cost) — `.yaml`, not `.json`, for the identical reason
  Epic A4 chose `.yaml` for `facet-manifest.yaml`/`capability-summary.
  yaml` over the otherwise-more-natural `.json`.
- **Registry Capability read set** (Epic A2, read not redefined):
  `capabilities[].{id, trigger, required_facets, conditional_facets,
  gate_ids, lite_policy, minimum_enforcement}`; `gates[].{id, stage,
  blocking}` (resolved via `gate_ids` referential lookup, a Resolver-side
  join — Epic A2's own schema only constrains `gate_ids`'s own shape,
  array-of-unique-strings; this feature performs the actual `id` → `{stage,
  blocking}` lookup against the same discovered Registry instance,
  copying both fields verbatim into `resolved_gates[]`, regardless of
  `stage` value — `artifact`/`promotion`-stage gates a matched
  Capability names are recorded in `resolved_gates[]` exactly like
  `implementation`-stage ones; ADR-0017 item 1's "Foundation implements
  only stage: implementation" governs which Gates actually *execute*
  something at Gate-run time, downstream of this feature, not which ones
  this feature's Facet Manifest *records* — Epic A2's own projection
  generator, not this feature, is what already filters to
  implementation-stage-only when building the operational `gate-
  capabilities.json` projection `quality-gate` reads, matching Epic A2's
  own precedent exactly, `design.md:598-601` in the Epic A2 worktree).
- **Context Projection read set** (Epic A4, read not redefined, this
  feature's own generated instance): `components[<affected-component-id>]`
  is the exact `--component-properties` payload this feature passes to
  `evaluate-predicate` — the whole `projectedComponent` object (Epic A4's
  own definition), not a filtered subset, since a `trigger`/`when`
  predicate's own `field` allowlist (8 dotted paths, ADR-0020 item 5)
  already constrains which of that object's own fields any predicate can
  reference; this feature does not pre-filter the payload before passing
  it to `evaluate-predicate`.

Migration Strategy: none. No database, no runtime storage, no schema
migration anywhere in this feature — the same "no database, no migration,
no runtime storage" statement every sibling epic's own `infra-spec.md`
(not authored at this phase, Layer Specifications above) would otherwise
record. `contracts/resolver-evidence.schema.json`,
`specs/<feature>/resolver-evidence.yaml`, and the two content-population
targets this feature's own future implementation stages under human-copy
are each a net-new, additive artifact with no prior version to migrate
from.

## API / Contract Plan

### `resolve-project-context.{py,sh,ps1}` CLI contract (REQ-001)

```
resolve-project-context.py \
  --config <path-to-project-context.yaml> \
  [--source-rev <rev>]        # default: HEAD
  --target-rev <rev> \        # required
  [--include-untracked] \
  --feature <feature-slug>    # required, ^[a-z0-9][a-z0-9-]*$
```

Every flag above except `[--source-rev]` and `[--include-untracked]` is
**required** — an omission of `--config`, `--target-rev`, or `--feature`
is a usage error (exit 2, below), never a way to spell a default
(requirements.md REQ-001's own rationale: silently guessing `--feature`
from `cwd` would break REQ-005's byte-identical-output determinism across
differently-invoked-but-logically-identical runs). `--source-rev`/
`--target-rev`/`--include-untracked` are passed through to `resolve-
component-paths` (Epic A3) **verbatim**, byte-for-byte identical to the
values this invocation itself received — this feature's Resolver never
resolves a rev itself, never computes its own merge-base, and never
re-implements any part of Epic A3's own `git diff` basis (decision
document v2 §12's "merge-base + untracked + rename follow" rule remains
entirely Epic A3's own scope).

**Processing order** (each step's own failure maps to exactly one REQ-002
diagnostic; a step's own success is a precondition for the next):

0. **Argument validation.** All required flags present, `--feature`
   matches its own pattern. Failure → exit 2 (usage error), no
   diagnostic-id line (this is not a Block; it never reaches REQ-002's
   own enum) — mirroring Epic A4's own `compare-facet-manifest-staleness`
   precedent of a separate, non-verdict error channel (Epic A4
   `design.md:894-916`).
1. **State derivation** (requirements.md REQ-003). Attempt to read
   `--config`'s target path. Absent, or the AGENTS.md-marker/default
   fallback derives `disabled-legacy` per ADR-0016 item 4 → Block,
   `disabled-legacy-invocation`, write a minimal Resolver Evidence record
   (Data Plan: `schema`, `feature`, `state: "disabled-legacy"`,
   `context_binding` and `resolver` blocks both absent — there is nothing
   to bind, since no Registry/ownership/projection step ever ran —
   `capability_evaluations: []`, `diagnostics: [{id: "disabled-legacy-
   invocation", detail: <path attempted>, severity: "block"}]`), exit 1.
   Present but fails Epic A1's own content-schema validation surface →
   Block, `project-context-validation-failed`, exit 1 (a normal, full
   Resolver Evidence record is written here, since Registry/ownership
   discovery has not yet run but the state-derivation step itself did
   execute — `state` is omitted, since none of the three values applies
   to a schema-invalid Context). Otherwise, `workflow.capability_
   enforcement` (`advisory` or `required`) is read and recorded as this
   invocation's `state` (REQ-003: this value does not otherwise branch
   any subsequent step).
2. **Project Context canonicalization** (Epic A1). Invoke
   `canonicalize-sdd-yaml` (YAML mode) over `--config`'s target →
   `source_sha256` (= `context_binding.full_context_revision`); its
   canonical-JSON stdout is separately `json.loads()`-parsed. A
   canonicalizer subprocess failure here → Block,
   `canonicalizer-invocation-failed`, exit 1.
3. **Context Projection assembly** (Epic A4's own REQ-003 generation
   procedure, verbatim — Data Plan, above): substitute `components: []`/
   `shared_paths: []` for either omitted key; re-key `components` by
   `id`; feed the re-keyed structure back through `canonicalize-sdd-yaml`
   (JSON mode) → `projection_sha256`; write to `generated/project-
   context.resolved.json`. A second canonicalizer failure here →
   identical `canonicalizer-invocation-failed` Block.
4. **Affected-component resolution** (Epic A3). Invoke
   `resolve-component-paths --config <same --config value>
   [--source-rev <same value>] --target-rev <same value>
   [--include-untracked] --json`. Non-zero exit →
   `affected-component-resolution-failed` Block, exit 1, the underlying
   script's own stderr diagnostic quoted verbatim in this Block's own
   `detail`. Zero exit → `affected_components[]` and `ownership_digest`
   consumed from its JSON stdout.
5. **Registry discovery** (Epic A2, via ADR-0025). Resolve
   `capability-registry.json` and `capability-registry.schema.json` per
   the script-relative-then-git-root-fallback procedure (investigation.md
   INV-005); a resolution or version-check failure at this step →
   `contract-discovery-failed` Block. Run Epic A2's own `validate-
   capability-registry` checks against the located Registry; a failure →
   `registry-validation-failed` Block. Both are exit 1.
6. **`registry_digest`.** Invoke `generate-registry-digest --whole`
   (Epic A2) against the located Registry → `context_binding.
   registry_digest`. A canonicalizer failure inside that invocation →
   `canonicalizer-invocation-failed` Block (this feature's own diagnostic
   surface treats every canonicalizer subprocess failure, regardless of
   which upstream step invoked it, identically — Design Decisions,
   below).
7. **Per-component, per-Capability trigger evaluation.** For each Registry
   `capabilities[]` entry, **in Registry-declaration order** (Registry
   `capabilities[]` is Epic A2's own already-author-ordered array — this
   feature does not re-sort the Registry's own read order, only its own
   *output* arrays, per REQ-005/AC-024), and for each
   `affected_components[]` entry **in ascending lexicographic order**,
   invoke `evaluate-predicate --predicate <this capability's trigger>
   --component-properties <this affected component's Context-Projection
   entry>`. A `PREDICATE_SCHEMA_ERROR` exit here (a malformed predicate —
   should never occur against an already-`validate-capability-registry`-
   passed Registry, but checked defensively) →
   `registry-validation-failed` Block (a malformed predicate is, by
   construction, a Registry validation defect this feature did not itself
   introduce). Every result (`result`, `evidence[]`) is recorded in this
   invocation's Resolver Evidence `capability_evaluations[<this
   capability>].trigger_evaluations[]`, **regardless of outcome** — no
   short-circuit, matching ADR-0020's own "every predicate is evaluated"
   discipline extended by this feature to its own per-component fan-out
   (Design Decisions). A Capability is **matched** iff at least one
   `trigger_evaluations[]` entry's `result` is `true` (the union-match
   rule, Design Decisions).
8. **Matched-Capability conditional-facet evaluation.** For each matched
   Capability, and each of its `conditional_facets[]` entries, repeat step
   7's per-affected-component fan-out against that entry's own `when`
   predicate, recording every result in
   `capability_evaluations[<capability>].conditional_facet_evaluations[]`.
   A `conditional_facets[].facet` entry is `applied: true` iff at least
   one per-component evaluation's `result` is `true` (the identical
   union-match rule, reused for facet-level, not only capability-level,
   matching).
9. **Determining-WARN check.** For each matched Capability: inspect the
   representative evaluation this invocation selected (Design Decisions'
   representative-selection rule) for that Capability's own `trigger`, and
   for each of its `conditional_facets[]` entries' own `when` — if any
   representative evaluation's own Evidence tree contains an `outcome:
   "warn"` node anywhere → `dsl-warn-on-matched-capability` Block, exit 1
   (a full Resolver Evidence record is written here, including every
   evaluation this invocation already performed through step 8 — this
   Block fires only after all evaluation work is complete, so the record
   is maximally informative for the caller diagnosing it).
10. **Facet Manifest assembly.** Collect every matched Capability's
    `required_facets`/`gate_ids` (resolved to `{id, stage, blocking}`
    via the Registry-side lookup, Data Plan)/`lite_policy`/
    `minimum_enforcement`; assemble every Epic-A4-defined field; stable-
    sort every semantic-output array (Epic A4's own rule, requirements.md
    REQ-005/AC-024). Write `specs/<feature>/facet-manifest.yaml`.
11. **Capability Summary assembly (Lite track only).** If
    `workflow.spec_profile == lite`: `capabilities` = the same matched-
    Capability-id set as step 10's own `capabilities[]`;
    `full_upgrade_required` = `!lite_eligibility.eligible` (the identical
    aggregate signal step 10 already computed, requirements.md Field
    Definitions); `required_lite_checks` — for each matched Capability,
    attempt to source its own contribution; **no Registry field exists to
    source it from** (investigation.md INV-019) → `lite-check-source-
    undefined` Block, exit 1, **no** `facet-manifest.yaml` (already
    assembled in step 10) is written either — a lite-track resolve is
    all-or-nothing, never a Facet-Manifest-only partial success (REQ-002's
    own "never a partial artifact" rule, requirements.md AC-011, applies
    across *all* of this invocation's outputs together, not per-file).
12. **Resolver Evidence write, success path.** Assemble and write
    `specs/<feature>/resolver-evidence.yaml` — every `capability_
    evaluations[]` entry from steps 7-8, `diagnostics: []` (no Block
    condition fired), `context_binding`/`resolver` fully populated,
    `state` from step 1. Exit 0.

**Exit codes**: `0` = success (steps 10-12 all completed); `1` = any
REQ-002 Block (steps 1, 2/3/6, 4, 5, 9, 11); `2` = CLI usage error (step
0) — fixed, three-way, matching this Epic set's own established "a fixed,
small exit-code enum a caller can branch on without parsing stdout"
convention (Epic A4's `compare-facet-manifest-staleness`, investigation.md
INV-004, uses the identical pattern for its own, differently-shaped
verdict set).

**Diagnostic line format**: `capability-resolver: <check-id>: <detail>`,
one line per diagnostic, to stderr — matching Epic A2's `registry: <check-
id>: <detail>` and Epic A4's `facet-manifest: <check-id>: <detail>`
conventions exactly (requirements.md REQ-002).

### `contracts/resolver-evidence.schema.json` (REQ-004)

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://github.com/aharada54914/sdd-forge/contracts/resolver-evidence.schema.json",
  "title": "SDD Forge Resolver Evidence",
  "type": "object",
  "additionalProperties": false,
  "required": ["schema", "feature", "capability_evaluations", "diagnostics"],
  "properties": {
    "schema": { "const": "sdd-resolver-evidence/v1" },
    "feature": { "type": "string", "pattern": "^[a-z0-9][a-z0-9-]*$" },
    "state": { "enum": ["disabled-legacy", "advisory", "required"] },
    "context_binding": {
      "type": "object",
      "additionalProperties": false,
      "required": ["full_context_revision", "dependency_pointers", "projection_sha256", "registry_digest", "ownership_digest"],
      "properties": {
        "full_context_revision": { "$ref": "#/definitions/sha256Digest" },
        "dependency_pointers": { "type": "array", "minItems": 1, "items": { "type": "string" } },
        "projection_sha256": { "$ref": "#/definitions/sha256Digest" },
        "registry_digest": { "$ref": "#/definitions/sha256Digest" },
        "ownership_digest": { "$ref": "#/definitions/sha256Digest" }
      }
    },
    "resolver": {
      "type": "object",
      "additionalProperties": false,
      "required": ["version", "rule_set_revision"],
      "properties": {
        "version": { "type": "string", "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$" },
        "rule_set_revision": { "$ref": "#/definitions/sha256Digest" }
      }
    },
    "capability_evaluations": {
      "type": "array",
      "items": { "$ref": "#/definitions/capabilityEvaluation" }
    },
    "diagnostics": {
      "type": "array",
      "items": { "$ref": "#/definitions/diagnostic" }
    }
  },
  "definitions": {
    "capabilityEvaluation": {
      "type": "object",
      "additionalProperties": false,
      "required": ["capability_id", "matched", "trigger_evaluations"],
      "properties": {
        "capability_id": { "type": "string", "minLength": 1 },
        "matched": { "type": "boolean" },
        "trigger_evaluations": {
          "type": "array",
          "items": { "$ref": "#/definitions/componentEvaluation" }
        },
        "conditional_facet_evaluations": {
          "type": "array",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": ["facet", "applied", "evaluations"],
            "properties": {
              "facet": { "type": "string", "minLength": 1 },
              "applied": { "type": "boolean" },
              "evaluations": {
                "type": "array",
                "items": { "$ref": "#/definitions/componentEvaluation" }
              }
            }
          }
        }
      },
      "if": { "properties": { "matched": { "const": false } } },
      "then": { "not": { "required": ["conditional_facet_evaluations"] } }
    },
    "componentEvaluation": {
      "type": "object",
      "additionalProperties": false,
      "required": ["component_id", "result", "evidence"],
      "properties": {
        "component_id": { "type": "string", "minLength": 1 },
        "result": { "type": "boolean" },
        "evidence": {
          "type": "array",
          "items": { "$ref": "#/definitions/evidenceNode" }
        }
      }
    },
    "evidenceNode": {
      "type": "object",
      "additionalProperties": false,
      "required": ["operator", "path", "outcome"],
      "properties": {
        "operator": {
          "enum": ["all", "any", "not", "equals", "not_equals",
                   "contains", "in", "exists"]
        },
        "path": { "type": ["string", "null"] },
        "outcome": { "enum": ["match", "no-match", "warn"] },
        "reason": { "type": "string" },
        "children": {
          "type": "array",
          "items": { "$ref": "#/definitions/evidenceNode" }
        }
      },
      "if": { "properties": { "outcome": { "const": "warn" } } },
      "then": { "required": ["operator", "path", "outcome", "reason"] }
    },
    "diagnostic": {
      "type": "object",
      "additionalProperties": false,
      "required": ["id", "detail", "severity"],
      "properties": {
        "id": {
          "enum": ["disabled-legacy-invocation", "project-context-validation-failed",
                   "affected-component-resolution-failed", "registry-validation-failed",
                   "contract-discovery-failed", "canonicalizer-invocation-failed",
                   "dsl-warn-on-matched-capability", "lite-check-source-undefined"]
        },
        "detail": { "type": "string" },
        "severity": { "enum": ["block", "warn"] }
      }
    },
    "sha256Digest": {
      "type": "string", "pattern": "^sha256:[0-9a-f]{64}$"
    }
  }
}
```

`evidenceNode` is a structural transcription of Epic A2's own Evidence
JSON Schema, copied verbatim (identical to how Epic A4's own
`facet-manifest.schema.json` already transcribes it, investigation.md
INV-004/INV-005) — not a redefinition, and not a `$ref` across separately-
versioned `contracts/` files (the same coordination risk Epic A4's own
design explicitly avoids, Epic A4 `design.md:429-435`). `diagnostics[].id`'s
enum carries all eight REQ-002 diagnostic-id values including
`project-context-validation-failed` (present in this schema's own enum
even though requirements.md's REQ-002 table lists seven rows plus this one
inline in step 1's own processing text above — both this schema and
requirements.md's own table agree on the same eight-value set; the table
in requirements.md groups it under the same "state derivation" row
prose rather than a separate table row, since it shares that row's own
trigger condition family).

### `validate-resolver-evidence.{py,sh,ps1}` contract (REQ-004)

`validate-resolver-evidence.py --evidence <path>` → exit 0 (schema-
conformant) or non-zero with `resolver-evidence: <check-id>: <detail>`
lines, one per failed check — matching Epic A4's own three-validator
diagnostic-line convention exactly. Checks: schema conformance
(`schema-invalid`, against `contracts/resolver-evidence.schema.json`,
using the identical hand-rolled, stdlib-only draft-07 subset Epic A4's own
`validate-facet-manifest.py` already implements — no third-party
`jsonschema` dependency, investigation.md INV-011); `capability_id`
uniqueness across `capability_evaluations[]` (`capability-evaluation-
id-duplicate`); a `matched: true` entry whose `trigger_evaluations[]` has
no `result: true` member is a `matched-without-evidence` contradiction —
this validator does not re-run any predicate evaluation itself, it checks
only that the recorded evidence is internally consistent with the recorded
`matched`/`applied` booleans it accompanies. Discovery via ADR-0025,
identical to every other script in this feature and in Epic A2/A4
(investigation.md INV-005/INV-011).

### Discovery contract (REQ-001/REQ-004, every script in this feature)

Identical to Epic A2's own REQ-005 discovery contract (already promoted to
ADR-0025) — reused, not re-derived (investigation.md INV-005): (1)
script-relative real-path resolution, `../contracts/<filename>` packaged-
copy check; (2) git-root fallback; (3) fail closed with both attempted
paths named. Version check per artifact: `capability-registry.json`
(`schema == "capability-registry/v1"`, Epic A2's own check, reused
unmodified), `facet-manifest.schema.json`/`capability-summary.schema.
json`/`context-projection.schema.json` (`$schema` present + matching
`$id`, Epic A4's own checks, reused unmodified), `resolver-evidence.
schema.json` (`$schema` present + matching `$id`, this feature's own,
following the identical pattern). A release-gating `--check` mode on this
feature's own vendoring step (Deployment / CI Plan, below) compares
`contracts/resolver-evidence.schema.json`'s canonical sha256 against its
vendored `plugins/sdd-quality-loop/contracts/resolver-evidence.schema.
json` counterpart, mirroring Epic A2's and Epic A4's own identical check.

## Test Strategy

New `tests/*.tests.sh`/`.tests.ps1` pairs and fixture data under
`tests/fixtures/capability-resolver/` (requirements.md REQ-006), designed
here at contract level (authored at Phase 2):

1. `resolve-project-context-cli` — argument-validation matrix (AC-001):
   one fixture per required flag, deleted; `--source-rev` omission
   defaults to `HEAD`.
2. `resolve-project-context-block` — one fixture per REQ-002 diagnostic-id
   row (eight total, including `project-context-validation-failed`),
   each independently triggerable and each asserting (a) the correct exit
   code, (b) the correct diagnostic line, (c) no `facet-manifest.yaml`/
   `capability-summary.yaml`/`project-context.resolved.json` written or
   changed, (d) the correct Resolver Evidence content (AC-010..AC-012).
3. `resolve-project-context-match` — the full match/no-match/conditional/
   WARN fixture matrix (REQ-006 items a-d): a two-affected-component
   fixture where only one component's properties satisfy a Capability's
   `trigger` (AC-006); a matched Capability with one applied and one
   N/A `conditional_facets[]` entry; a WARN on a non-representative branch
   (accepted) vs. a WARN on the representative, determining branch of a
   matched Capability (Blocked, `dsl-warn-on-matched-capability`).
4. `resolve-project-context-lite` — the Lite-track path: confirms
   `lite-check-source-undefined` fires for the current, real Registry
   shape (investigation.md INV-019) via a synthetic fixture whose Registry
   Capability declares `lite_policy.eligible: true`, proving the Block
   fires structurally rather than by an accidental fixture gap; a
   forward-compatibility fixture (a hypothetical Registry extension
   supplying a resolvable source) proves the rest of the Lite pipeline
   (steps 10-12) is otherwise already correct, matching Epic A4's own
   "forward compatibility" fixture-pairing style for its own detector-
   absence handling (Epic A4 `acceptance-tests.md` AC-024's own
   sub-case (2)).
5. `resolve-project-context-parity` — `.py`/`.sh`/`.ps1` byte-identical
   output across every fixture above, plus a repeated-invocation
   determinism proof (REQ-005/AC-022/AC-023); includes at least one
   Windows-style (`\`-separated) path argument, matching Epic A4's own
   parity-suite convention (Epic A4 `design.md`, "Diagnostic determinism
   contract").
6. `resolve-project-context-discovery` — three fixtures (one per runtime)
   simulating a standalone-installed-plugin layout, for every `contracts/*`
   artifact this feature's scripts locate (Registry + its schema, Epic
   A4's three schemas, this feature's own `resolver-evidence.schema.
   json`) — matching Epic A2's own three-fixture discovery pattern
   (AC-028).
7. `resolver-evidence-schema` — `contracts/resolver-evidence.schema.json`
   existence/`$id`-convention/required-field-matrix fixtures, matching
   Epic A4's own `facet-manifest-schema` suite's own structure.
8. `validate-resolver-evidence` — one fixture per `validate-resolver-
   evidence` diagnostic-id row (AC-021).

Every new suite is registered directly (unprotected) in `tests/run-all.
sh`/`.ps1` (AC-026), matching Epic A2/A4's own precedent; a staged
candidate for `.github/workflows/test.yml` registration is staged under
`specs/epic-193-a5-capability-resolver/human-copy/` alongside the
content-population batch (Protected-File Statement, above) — matching
Epic A1's own precedent of staging CI-registration edits together with a
related protected-file batch rather than as a separate transaction.

## Design Decisions (resolving open questions)

**Multi-affected-component trigger/`when` matching rule: union-match
(any affected component satisfying the predicate makes the Capability/
facet apply).** `evaluate-predicate` (Epic A2) accepts exactly one
component's properties per invocation (investigation.md INV-012); no
upstream ADR or sibling spec defines how a Resolver with several affected
components should aggregate several per-component results. This design
adopts union-match — a Capability/facet applies iff **at least one**
affected component's evaluation matches — for the identical soundness
reason Epic A4's own INV-019 (this feature's own investigation.md,
citing Epic A4) already establishes for `registry_digest`/
`ownership_digest`'s own full-input-binding choice: "no proper subset...
can be soundly treated as not consumed." Applied here: if a Feature
touches a component with `characteristics.pii: true`, the PII-driven
Capability must apply to that Feature even if a second, also-affected
component has no PII — excluding it because *some other* touched
component lacks the property would silently under-resolve the Feature's
own real requirements. The rejected alternative — conjunctive matching
(*every* affected component must satisfy the predicate) — is inconsistent
with `lite_policy.upgrade_reasons`' own existing semantics (decision
document v2 §6: a single PII-handling component forces the whole Feature
to `full`, regardless of whether every other touched component also
handles PII) and would let a multi-component Feature silently omit a
Capability a single one of its components genuinely needs.

**Representative-evidence selection for `conditional_facets[].evidence`
(Facet Manifest, Epic A4's own field): the first affected component, in
ascending lexicographic order, whose own evaluation result equals the
facet's own `applied` value.** Epic A4 already fixes that this field is
"exactly what `evaluate-predicate` returned for that facet's governing
predicate" (Epic A4 `design.md:413-422`) — a **single** invocation's
output, not an array of per-component results. Given this feature's own
union-match rule can involve several per-component invocations for the
same predicate, this design picks one, deterministically: the first
(lexicographically, by `component_id`) whose own `result` agrees with the
facet's overall `applied` outcome — so the embedded evidence always
supports the stated outcome (never a component whose own evaluation
contradicts `applied`), and the choice is fully reproducible (REQ-005)
without depending on evaluation order or wall-clock timing. Resolver
Evidence (this feature's own, broader artifact, REQ-004) retains **every**
per-component evaluation regardless of which one Facet Manifest embeds, so
no information is lost — only the single-value field Epic A4 already fixed
needs a single representative, and Resolver Evidence is exactly the place
this feature's design puts the full record that field cannot carry.

**`dsl-warn-on-matched-capability`'s scope is the representative
evaluation only, not every per-component evaluation.** A WARN on a
non-representative branch (e.g. a second affected component whose
properties happen to be incomplete, but whose own evaluation was not the
one that determined the Capability's `matched`/`applied` outcome) is
recorded in Resolver Evidence and never Blocks — matching ADR-0020's own
"WARN is a normal, successful evaluation" principle at the DSL-evaluator
layer. Only a WARN on the branch this feature's own Facet Manifest
actually embeds (the representative one, immediately above) is
Block-worthy, because *that* branch's own outcome is what a human or
downstream Gate reading the Facet Manifest will actually see and rely on
— a WARN there means the field allowlist expects Project-Context data the
current Context does not (yet) provide, for the exact evaluation that
determined a real, consequential outcome.

**`resolved_gates[]` includes every matched Capability's referenced
Gates verbatim, at any `stage` value — this feature does not filter to
`stage: implementation` only.** ADR-0017 item 1 ("Foundation implements
only `stage: implementation`") governs *execution*, not *recording*; Epic
A2's own projection generator (`generate-gate-capabilities.py`) is already
the component that filters a Registry's Gates down to `stage:
implementation` when building the *operational* projection `quality-gate`
actually reads (Data Plan, above, cites the exact line). This feature's
Facet Manifest is a faithful record of what a Feature's matched
Capabilities reference, at whatever stage the Registry itself declares —
preserving forward compatibility for a future `sdd-delivery`/Promotion
epic without requiring this feature's own Resolver to be re-implemented
once `artifact`/`promotion` Gates gain real execution behavior.

## Global Constraints

- No third-party Python dependency anywhere in this feature's own scripts
  (investigation.md INV-011) — stdlib only, matching every existing
  script under `plugins/sdd-quality-loop/scripts/`.
- Every array this feature's own new schema (`resolver-evidence.schema.
  json`) defines that participates in this feature's own determinism
  guarantee (REQ-005) is written stable-sorted by this feature's Resolver
  before serialization — the schema itself does not enforce sort order
  (JSON Schema draft-07 cannot express it, matching every other
  stable-sort-mandated array in this Epic set), `validate-resolver-
  evidence`'s own semantic check does (mirroring Epic A2/A4's own
  `array-not-stable-sorted`-style check).
- UTF-8, no BOM, LF-only line endings on every runtime including the
  `.ps1` wrapper on Windows, for every diagnostic line this feature's
  scripts emit — matching Epic A4's own "Diagnostic determinism contract"
  verbatim (Epic A4 `design.md:956-985`), reused unmodified rather than
  re-derived.

## Security Boundaries

- This feature's Resolver never reads a credential, never contacts a
  network endpoint, and never invokes a Provider API — matching ADR-0020's
  own DSL-layer Provider-neutrality boundary, extended by this feature's
  REQ-005 to its own orchestration layer (requirements.md Security
  Boundaries).
- This feature's Resolver never writes to any `*.approval.json` sidecar,
  any `sdd/.approved-context/` anchor, or `guard-invariants.json` itself —
  it only *reads* `project-context.yaml`'s already-approved content via
  the canonicalizer (Epic A1's own already-approved-content boundary,
  investigation.md INV-007), it never participates in, and never bypasses,
  the approval-sidecar workflow.
- A `disabled-legacy-invocation` Block is fail-closed by construction —
  there is no code path in this design that reaches step 10 (Facet
  Manifest assembly) while state derivation (step 1) has resolved
  `disabled-legacy` (Design Decisions/API Contract Plan, above).
- The two-tier defense-claim scope ADR-0019 §4 already establishes
  (hook-layer-plus-deterministic-validator vs. protected-file-plus-
  external-key-HMAC adversarial resistance) applies unchanged to this
  feature's own two already-reserved protected paths (Protected-File
  Statement, above) — this feature makes no additional or different
  defense-scope claim than ADR-0019 itself already states.

## External Integrations

None — every input and output this feature touches is repository-local
(`project-context.yaml`, `capability-registry.json`, git, and the
`contracts/`/`specs/`/`generated/` filesystem paths already named above).

## Deployment / CI Plan

- `contracts/resolver-evidence.schema.json` is vendored into
  `plugins/sdd-quality-loop/contracts/resolver-evidence.schema.json` by
  the same vendoring/packaging step Epic A2/A4 already establish, gaining
  a `--check` drift-comparison entry the same way (Discovery contract,
  above).
- `resolve-project-context.{py,sh,ps1}`'s own CI registration (once
  implemented) is staged under `specs/epic-193-a5-capability-resolver/
  human-copy/` alongside its own content-population batch (Protected-File
  Statement, above) — this Phase 1 package does not itself perform any CI
  wiring, only records the future task's own staging discipline.
- No new CI job is required beyond registering this feature's own new
  `tests/*.tests.sh`/`.tests.ps1` suites in the existing `test.yml`
  workflow (Test Strategy, above) and the existing vendored-copy drift
  check (bullet one, above) — this feature introduces no new deployment
  topology.

## Constraint Compliance

- `AGENTS.md` Rules: "API changes require contract updates" — this
  feature's own new contract (`resolver-evidence.schema.json`) is authored
  in this same package; "architecture changes require ADRs" — this
  feature authors no new ADR because it makes no new architecture-level
  decision (ADR Change Log, above; its two genuinely new decisions are
  narrow, mechanical DSL-invocation-orchestration rules, not a new axis).
- This task's own hard boundary (no edit to `plugins/**`/`scripts/**`/
  `.github/**`/`tests/**`/`contracts/**`/`docs/**`) is honored throughout
  this design — every concrete file this design names under those trees
  is described as a **future** artifact this Phase 1 package does not
  itself create; this package's own commits touch only
  `specs/epic-193-a5-capability-resolver/` and (in the registration
  commit) `AGENTS.md`'s Active Spec Directories list and `specs/
  workflow-state-registry.json`.

## Assumptions

Restated from requirements.md's own Assumptions section for design-level
visibility: Epic A1/A2/A3/A4's own contracts land unmodified from their
`Spec-Review-Status: Passed` shapes before this feature's Phase-2
implementation begins; `resolve-project-context.{py,sh,ps1}`'s protected-
suffix reservation is live in `guard-invariants.json` by that same point,
per issue #187's own stated sequencing; `sdd-bootstrap-interviewer/
SKILL.md`'s current unprotected status is a live-repository snapshot,
re-verified at that future task's own start time.

## Open Questions

Restated from investigation.md: OQ-001 (Context Projection regeneration
cadence beyond "once per invocation"), OQ-002 (which future caller invokes
`compare-facet-manifest-staleness` against two of this feature's outputs,
and when), OQ-003 (the exact numbered-step insertion point for the
capability interview phase within `sdd-bootstrap-interviewer`'s live
`SKILL.md`).

## Risks

Restated and design-elaborated from requirements.md's own Risks section:

- **Lite-track resolution is effectively Blocked for every real
  invocation today** (investigation.md INV-019, requirements.md Risks) —
  this design's own Test Strategy item 4 makes this fact directly,
  mechanically testable (a synthetic-Registry forward-compatibility
  fixture proves the rest of the pipeline is otherwise correct) rather
  than leaving it as an assertion this package cannot verify.
- **The multi-component matching rule and the representative-evidence-
  selection rule (Design Decisions, above) are this feature's own new
  decisions**, not upstream-fixed facts — both are narrow, citation-
  grounded, mechanical extensions of `evaluate-predicate`'s own already-
  fixed CLI shape, but a future spec-review pass may still find either
  needs to be an ADR of its own (ADR Change Log, above, already names this
  as a low-cost, anticipated follow-up rather than a gap).
- **`resolve-project-context.{py,sh,ps1}`'s reservation may not yet be
  live** when this feature's own Phase-2 implementation begins (Protected-
  File Statement, above, already gives the fallback sequencing for that
  case).
