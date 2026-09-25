# Design: epic-193-a5-capability-resolver

Impl-Review-Status: Passed
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
component) pair, and assembles this invocation's **track-exclusive**
output set — a **Full**-track resolve assembles a Facet Manifest, a
Context Projection, and Resolver Evidence; a **Lite**-track resolve
instead assembles a Capability Summary and Resolver Evidence only, never
a Facet Manifest and never a published Context Projection (Design
Decisions, below, "track-exclusive publication set" — this corrects an
earlier revision of this design that assembled both a Facet Manifest and
a Capability Summary on the Lite track, adversarial review "B4 Lite
publication") — each already validating against Epic A4's own schemas
before this invocation ever writes to a live path (Design Decisions,
below, "staged generation, single atomic commit"), plus one genuinely new
artifact, Resolver Evidence, whose shape no upstream contract fixes
(requirements.md REQ-004). Every evaluation this invocation performs —
every Registry Capability's `trigger` against every affected component,
and every matched Capability's `conditional_facets[].when` against every
affected component — runs to completion, and every Block condition this
invocation's inputs trigger is determined, **before** this invocation
commits any artifact to a live path (Design Decisions, "staged generation,
single atomic commit" — adversarial review "B1 atomicity"). The two
places this design makes a real, new decision rather than a mechanical
transcription are the multi-affected-component matching rule and the
cross-Capability facet-name aggregation rule (Design Decisions, below) —
`evaluate-predicate`'s own CLI takes exactly one component's properties
per call, and no upstream spec says how several per-component results
combine into one Feature-level match/no-match, or how two Capabilities
that happen to declare a `conditional_facets[]` entry under the identical
`facet` name combine into the one Facet Manifest entry Epic A4's own
facet-name-uniqueness rule requires.

## Architecture

```
                         project-context.yaml (A1)
                                   │
                    ┌──────────────┴───────────────┐
                    │ state derivation (REQ-003)     │  ── disabled-legacy
                    │  disabled-legacy? invalid       │     → immediate
                    │  workflow combination? (M3)     │     Block, no
                    └──────────────┬───────────────┘     staging area
                                   │ (advisory|required, valid combination)
                    ┌──────────────┴───────────────┐
                    │ canonicalize-sdd-yaml (A1)    │  ── snapshot: pin
                    │  pass 1: YAML → source_sha256 │     project-context.yaml
                    └──────────────┬───────────────┘     bytes in memory
                                   │ parsed structure     (B8 TOCTOU)
                    ┌──────────────┴───────────────┐
                    │ Context Projection assembly    │  ── A4 REQ-003
                    │  (re-key components by id;      │     generation
                    │   canonicalize-sdd-yaml pass 2  │     procedure,
                    │   → projection_sha256; STAGED,   │     verbatim;
                    │   not written to a live path yet) │   written only
                    └──────────────┬───────────────┘     at commit (below)
    --config/--source-rev/        │ staged Context Projection
    --target-rev/--include-       │
    untracked ────────────────────┤
                    ┌──────────────┴───────────────┐
                    │ resolve-component-paths (A3)  │  ── snapshot: pin
                    │  → affected_components[]       │     ownership-source
                    │  → ownership_digest             │     bytes/digest
                    └──────────────┬───────────────┘     (B8 TOCTOU)
                                   │
                    ┌──────────────┴───────────────┐
                    │ Registry discovery (A2, ADR-0025)│ ── snapshot: pin
                    │  → capability-registry.json      │    Registry bytes/
                    │  → registry_digest --whole       │    digest (B8 TOCTOU)
                    └──────────────┬───────────────┘
                                   │
                    ┌──────────────┴───────────────┐
                    │ step 6.5: Registry re-read    │ ── ruling C(1):
                    │  vs step-5 snapshot digest    │    detection-only;
                    │  mismatch → snapshot-          │    closes the
                    │  generation-mismatch Block    │    unbound-reads
                    └──────────────┬───────────────┘    window (AC-057)
                                   │
      for each Registry capability (declaration order) ×
      each affected_component (ascending lexicographic order),
      no short-circuit — every evaluation is performed and recorded,
      matched or not, WARN or not (B2/B6):
                    ┌──────────────┴───────────────┐
                    │ evaluate-predicate (A2)         │  ── per-component
                    │  trigger against component        │     fan-out +
                    │  properties (Context Projection)   │     union-match
                    └──────────────┬───────────────┘     (this feature's
                                   │ every result recorded     own rule,
                    ┌──────────────┴───────────────┐     Design Decisions)
                    │ evaluate-predicate (A2)         │
                    │  conditional_facets[].when          │
                    │  per matched capability, every        │
                    │  affected component (no short-circuit) │
                    └──────────────┬───────────────┘
                                   │
                    ┌──────────────┴───────────────┐
                    │ WARN check (B2): any evidence tree │ ── any evaluated
                    │  from ANY evaluation above          │    branch, matched
                    │  contains outcome:"warn"?            │    or unmatched,
                    └──────────────┬───────────────┘     any component (B2)
                                   │ (no WARN anywhere → continue)
                    ┌──────────────┴───────────────┐
                    │ track branch (B4), decided here, │ ── before any
                    │  before any publication:          │    publication —
                    │  full  → stage Facet Manifest      │    determines this
                    │  lite  → stage Capability Summary   │   invocation's own
                    │          (lite-check-source-        │   output SET
                    │           undefined check, REQ-002) │
                    └──────────────┬───────────────┘
                                   │
                    ┌──────────────┴───────────────┐
                    │ Resolver Evidence assembly       │  ── this feature's
                    │  (every capability, every         │     own new
                    │   diagnostic, both digests,        │     schema;
                    │   canonical dependency_pointers/    │    STAGED, not
                    │   resolver.version/rule_set_revision)│   yet committed
                    └──────────────┬───────────────┘
                                   │ every staged artifact schema-validated
                                   │ (output-schema-validation-failed, B3)
                    ┌──────────────┴───────────────┐
                    │ pre-publication snapshot recheck │ ── re-read/re-hash
                    │  (B8 TOCTOU): staged bytes/digest │    Context/ownership-
                    │  vs. invocation-start snapshot     │   source/Registry;
                    │  — mismatch → Block                │   mismatch →
                    │  (snapshot-generation-mismatch)     │   snapshot-
                    └──────────────┬───────────────┘     generation-mismatch
                                   │ (match → continue)
                    ┌──────────────┴───────────────┐
                    │ single atomic commit (B1): write   │ ── temp-file +
                    │  every staged artifact in this      │    fsync + rename
                    │  invocation's own track-exclusive    │   per file, or
                    │  output set to its live path,         │  none at all
                    │  or write none of them (all-or-        │  (artifact-
                    │  nothing across the whole set)          │ publication-
                    └──────────────┬───────────────┘         failed)
                                   ▼
   Full track:  specs/<feature>/facet-manifest.yaml
                generated/project-context.resolved.json
                specs/<feature>/resolver-evidence.yaml
   Lite track:  specs/<feature>/capability-summary.yaml
                specs/<feature>/resolver-evidence.yaml
                (no facet-manifest.yaml, no project-context.resolved.json)
   Every Block (any track, any diagnostic except disabled-legacy-
   invocation/project-context-validation-failed/workflow-combination-
   invalid, which short-circuit before a staging area exists at all):
                specs/<feature>/resolver-evidence.yaml only
```

Any Block (requirements.md REQ-002) prevents this invocation's own atomic
commit step from running at all — nothing this invocation staged (Facet
Manifest, Capability Summary, Context Projection) ever reaches a live
path; only Resolver Evidence, itself staged and validated like every other
artifact, participates in that Block's own commit (API / Contract Plan,
below, fixes the exact ordering and the staging-area/commit split this
diagram summarizes — adversarial review "B1 atomicity"). `disabled-legacy-
invocation`, `project-context-validation-failed`, and `workflow-
combination-invalid` are the only three diagnostics that fire before any
staging area exists — each writes a Resolver Evidence record directly,
with no earlier staged artifact to discard (API / Contract Plan step 1,
below).

## Components

| Component | Responsibility | Technology | New/Existing | Protected? |
|---|---|---|---|---|
| `contracts/resolver-evidence.schema.json` | schema for this feature's own new Resolver Evidence artifact (`sdd-resolver-evidence/v1`) | JSON Schema | new | no |
| `plugins/sdd-quality-loop/scripts/resolve-project-context.py` | Python master: orchestrates canonicalizer, Context Projection assembly, `resolve-component-paths`, Registry discovery, per-component `evaluate-predicate` fan-out, Facet Manifest/Capability Summary/Resolver Evidence assembly, REQ-002 Block taxonomy | Python | new (path already reserved-protected by Epic A1, investigation.md INV-003) | **YES (already reserved by A1)** |
| `plugins/sdd-quality-loop/scripts/resolve-project-context.sh` / `.ps1` | thin dispatchers, `python3`/`python` resolution only — no native fallback, matching `canonicalize-sdd-yaml`'s own dispatch shape (Epic A1 precedent) | POSIX sh / PowerShell | new (path already reserved-protected by Epic A1) | **YES (already reserved by A1)** |
| `plugins/sdd-quality-loop/scripts/generated/project-context.resolved.json` | Context Projection instance, one per repository; computed internally on every Resolver invocation (both tracks, for predicate evaluation) but **published to this path only on a Full-track resolve** (Design Decisions, "track-exclusive publication set", B4) — a Lite-track resolve never writes this path; the running Resolver process is this path's sole writer, via the guarded atomic publication mechanism (Design Decisions, "staged generation, single atomic commit"), never a human-copy content-population target (M7 correction, below) | JSON | new (path already reserved-protected by Epic A1) | **YES (already reserved by A1)** |
| `plugins/sdd-quality-loop/scripts/validate-resolver-evidence.py` / `.sh` / `.ps1` | schema-conformance validator for this feature's own new artifact, matching Epic A4's own three-validator precedent | Python + sh/ps1 wrappers | new | no |
| `specs/<feature>/facet-manifest.yaml` | per-Feature Facet Manifest instance, schema `sdd-facet-manifest/v1` (Epic A4) | YAML | new instances only (schema is Epic A4's) | no (agent-writable only via the Resolver, matching Epic A4's own convention) |
| `specs/<feature>/capability-summary.yaml` | per-Feature Capability Summary instance, Lite track only (written **instead of**, never alongside, `facet-manifest.yaml`/`project-context.resolved.json` on that track — Design Decisions, "track-exclusive publication set", B4), schema `sdd-capability-summary/v1` (Epic A4) | YAML | new instances only | no |
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
   `resolve-project-context.py`/`.sh`/`.ps1` **unprotected-first**, at a
   fully testable location (e.g. this package's own `specs/epic-193-
   a5-capability-resolver/` working tree, or any non-protected path), then
   stages the finished, tested *script content* under `specs/epic-193-a5-
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

**`generated/project-context.resolved.json` is deliberately *not* part of
either human-copy batch above (adversarial review "M7 human-copy
boundary")**, even though it shares the same protected-suffix reservation
as the three scripts. Human-copy, in every existing precedent this Epic
set establishes (Epic A1's own 24 concrete entries, this feature's own
scripts above), stages **immutable code or a registration candidate** —
content with one fixed, reviewable value at staging time. A generated
Context Projection has no such fixed "initial content": it is a pure,
Context-dependent function of whatever `project-context.yaml` a live
repository happens to carry at invocation time, recomputed by definition
on every Full-track resolve (Architecture, above). Treating it as a
human-copy target would either stage a stale, single fixture's worth of
content as if it were durable initial state (misleading — the very next
Full-track invocation overwrites it) or leave the human-copy step with
nothing meaningful to stage at all. This feature's design therefore
governs this path, and every other per-Feature generated artifact this
Resolver writes (`specs/<feature>/facet-manifest.yaml`/`capability-
summary.yaml`/`resolver-evidence.yaml`), under a **separate contract**:
guarded atomic publication (Architecture/Design Decisions, "staged
generation, single atomic commit") by the running Resolver process
itself, the sole writer, at a path resolved the same **cwd-independent**
way every other artifact this feature's scripts locate is resolved —
script-relative-then-git-root-fallback (ADR-0025, Discovery contract,
below) for the repository-scoped `generated/project-context.resolved.json`
path, and `<git-root>/specs/<feature>/` (never a `cwd`-relative guess,
matching REQ-001's own `--feature`-must-be-explicit rationale,
requirements.md REQ-001) for every per-Feature path. No implementation
task ever stages a fixed instance of any of these four paths under
`human-copy/` — only the three scripts above (and, per the Protected-File
Statement's own registration/content-population distinction, the guard-
invariants.json registration content-population that already occupies
`generated/project-context.resolved.json`'s and the three scripts' *path
reservation*, not their *runtime content*) are ever human-copy targets.

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

| Layer | Summary | Canonical Detail | Owner | Status |
|---|---|---|---|---|
| UX | N/A — no user-facing surface; deterministic CLI script family + validator + schema + documented (not implemented) caller-integration contract only | ux-spec.md (N/A content — no UI to specify) | — | N/A |
| Frontend | N/A — no browser/client UI, no new runtime service; new stdlib-only Python scripts + `sh`/`ps1` wrappers recorded for completeness | frontend-spec.md (N/A content — no browser/frontend surface) | — | N/A |
| Infrastructure | No new runtime deployment; ten new CI test-suite pairs specified at contract level, of which the **nine** this package's `tasks.md` schedules are registered in `tests/run-all.sh`/`.ps1` and the tenth (`resolve-project-context-caller-contract`) is deferred with its authoring and registration (scoped 2026-08-27, human-approved, ruling D(2), matching AC-026's own narrowing and `tasks.md`'s "Deferred, not scheduled"), a staged `test.yml` human-copy candidate, and one new vendored-copy `--check` drift entry (`resolver-evidence.schema.json`) | infra-spec.md (expands this document's Deployment / CI Plan) | Implementation task owner | Planned |
| Security | No new trust boundary beyond this feature's own transactional-publication/snapshot-recheck/provenance-binding rules (Security Boundaries, below); two already-reserved protected paths inherited from Epic A1 (Protected-File Statement, above) | security-spec.md (expands this document's Security Boundaries / Protected-File Statement) | Implementation task owner | Planned |

Added at impl-review-prep time (investigation.md INV-015 already
anticipated this step, matching Epic A2's and Epic A4's own identical
precedent of adding these four files after the Phase 1 spec-review
commit, not as part of it) — this feature ships no UI and no
infrastructure beyond existing repository scripts; every one of the four
files above is a reorganization of this document's own already-fixed
content into the review harness's canonical layer-file shape, introducing
no new design judgment of its own.

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
  Risks, below, for why `required`-enforcement consumption specifically
  (not Epic A6 Lite consumption as a whole, cross-epic addendum, Epic A6
  adversarial verification finding B5) is currently blocked by
  investigation.md INV-019's Registry-schema gap, independent of this
  feature's own completeness; `advisory`-enforcement consumption is not
  blocked by this gap.
- **Downstream (anticipated future consumer)**: a future epic (plausibly
  A6/A8) is the anticipated caller of Epic A4's `compare-facet-manifest-
  staleness` against two of this feature's own Facet Manifest outputs
  (investigation.md OQ-002) — this feature's own output shape (stable-
  sorted semantic-output arrays, requirements.md REQ-005) is designed so
  that future caller's comparison is well-defined without requiring any
  change to this feature's own contract.
- **A4 addendum needed (B7, flagged here, not acted on — this package does
  not edit Epic A4's own files, this task's own hard boundary and Epic
  A4's own post-review content freeze)**: Epic A4's own `design.md:413-422`
  prose ("the whole array is copied verbatim from the evaluator's own
  output") describes `conditional_facets[].evidence` as a single `evaluate-
  predicate` invocation's own verbatim output. This feature's own
  cross-Capability facet-name aggregation rule (Design Decisions,
  "facet-name aggregation", B7, above) can make that field the
  **concatenation** of several such invocations' own output instead, when
  more than one matched Capability declares a `conditional_facets[]` entry
  under the identical `facet` name. The concatenated array still satisfies
  A4's own JSON Schema (an array of `#/definitions/evidenceNode` elements,
  of whatever length) — only A4's own *prose* describes a narrower,
  single-invocation case than this feature's own design can now produce.
  This is named in this package's own final report as an item a future A4
  addendum should reconcile (a one-sentence prose broadening, not a schema
  change) — this package takes no further action on it itself.
- **A2 addendum candidate (B7, flagged here, not acted on — this package
  does not edit Epic A2's own files, this task's own hard boundary)**:
  Epic A2's own `capabilities[].conditional_facets[]` schema neither
  requires `facet` uniqueness *within* one Capability's own declaration
  nor states, in prose, whether a same-Capability, same-`facet`-name
  duplicate declaration is an intentionally-supported authoring pattern
  or an oversight (`specs/epic-190-a2-capability-registry/requirements.
  md:169-173`, no `uniqueItems`-style constraint stated either way). This
  feature's own predicate-instance-keyed aggregation rule (Design
  Decisions, "facet-name aggregation, predicate-instance keyed", B7,
  above) handles both the intentional and the oversight readings
  identically and correctly (every declaration, same-Capability or
  cross-Capability, is its own independent predicate instance), so this
  gap does not block this feature's own spec — but a future A2 addendum
  adding explicit prose (permitting or forbidding the pattern) would
  remove the ambiguity for a future Registry author. This is named in
  this package's own final report, alongside the existing A4-addendum
  item immediately above, as a second item a future addendum should
  reconcile — this package takes no further action on it itself.

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
precedence, that remains Epic A1's own REQ-009 scope), and
`docs/adr/0025-registry-discovery-contract.md` (the discovery procedure
this feature reuses unmodified, investigation.md INV-005 — **Accepted in
the Epic A2 worktree, 2026-07-21; not yet present on this worktree's own
`docs/adr/` branch state at this package's own design-authoring time**
(`ls docs/adr/` here returns only 0001-0024 plus README.md), cited as an
Accepted cross-Epic ADR regardless, per investigation.md INV-005/INV-020/
INV-021 — a reader of this worktree can consult this design's own
verbatim restatement of ADR-0025's three-step discovery procedure,
Discovery contract below, without needing the file present locally) —
this design implements those seven ADRs' decisions, plus six new,
not-independently-ADR-worthy decisions this design records below (Design
Decisions), narrowed from an earlier revision's two after adversarial
review found the earlier "representative-evidence-selection" decision
itself unsound (findings "M1 stale evidence"/"M2 undefined trigger
representative") and required several additional orchestration rules no
upstream contract fixes:

1. the multi-affected-component matching rule (union-match, unchanged from
   the earlier revision);
2. the cross-Capability facet-name aggregation rule (replaces the removed
   representative-evidence-selection rule — Design Decisions, "facet-name
   aggregation");
3. the any-branch WARN-Block scope rule (widened from the earlier
   revision's representative-branch-only scope — Design Decisions, "WARN
   scope");
4. the staged-generation/single-atomic-commit publication rule and its
   companion invocation-start-snapshot/pre-publication-recheck rule
   (Design Decisions, "staged generation, single atomic commit");
5. the track-exclusive publication-set rule (Design Decisions,
   "track-exclusive publication set");
6. the `dependency_pointers`/`resolver.version`/`rule_set_revision`
   canonical-preimage rules (Design Decisions, "provenance canonicalization").

Every one of the six is a narrow, mechanical extension of an
already-fixed upstream CLI shape or an already-fixed upstream ADR
principle (`evaluate-predicate`'s own single-component CLI shape,
investigation.md INV-012, for 1-3; ADR-0021's own full-input-binding
principle, investigation.md INV-009, for 4/6; A4's own track-exclusive
Capability Summary contract, investigation.md INV-004, for 5), not a new
architectural axis on the scale ADR-0016/0020/0021 already establish — if
impl-review disagrees, promoting any of the six to its own ADR is a
low-cost follow-up (matching Epic A1's own identical "resolved-but-
revisitable choice, not a gap" framing for its `approver-registry.yaml`,
Epic A1 `design.md:291-297`).

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
  `rule_set_revision`), `capability_evaluations[]` (**exactly** one entry
  per Registry Capability — cardinality bound to the discovered Registry's
  own `capabilities[]` length, not merely "no duplicates" — adversarial
  review "B6 Evidence completeness": `{capability_id, matched: boolean,
  trigger_evaluations: [{component_id, result: boolean, evidence:
  [<Epic-A2-Evidence-node-shape, embedded structurally like Epic A4's own
  evidenceNode>]}]}` with **exactly** one `trigger_evaluations[]` element
  per `affected_components[]` entry (exact-set bound to the invocation's
  own affected-component set, not merely non-empty — B6; the sole
  exception is the zero-affected-component Edge Case, where `affected_
  components` itself is `[]` and every Capability's own `trigger_
  evaluations[]` is therefore also `[]`, still exact-set-correct for a
  zero-length governing set, requirements.md Edge Cases, "M9
  zero-component correction"; both halves of this rule are AC-018 — an
  **unmatched**
  Capability's own entry is present all the same, carrying `matched:
  false` and a full one-element-per-affected-component `trigger_
  evaluations[]`, and the zero-affected-component case's own `[]` is
  legitimate rather than incomplete), and, only when `matched: true`,
  `conditional_facet_
  evaluations: [{facet, declaration_index (integer, 0-based, NEW, B7),
  applied: boolean, evaluations: [{component_id,
  result, evidence}]}]` with **exactly** one `conditional_facet_
  evaluations[]` element per that Capability's own `conditional_facets[]`
  array *entry* — keyed by `declaration_index` (array position),
  **never** by distinct `facet` value (B7 predicate-instance keying,
  revised — Epic A2's own Registry schema does not forbid two entries
  sharing one `facet` name within a single Capability's own declaration,
  `specs/epic-190-a2-capability-registry/requirements.md:169-173`, so a
  Capability declaring the identical `facet` twice produces **two**
  Evidence entries here, `declaration_index: 0` and `declaration_index:
  1`, never collapsed to one by name) — cardinality bound to that
  Capability's own `conditional_facets[]` array *length*, not its own
  distinct-facet-name count — and,
  within each, exactly one `evaluations[]` element per affected component
  (the identical exact-set rule, one level deeper; an **unmatched**
  Capability's own entry omits the `conditional_facet_evaluations` key
  entirely, enforced by this schema's own `if`/`then` clause below —
  AC-019) — `matched: true` iff
  at least one `trigger_evaluations[].result` is `true` **and** `matched:
  false` iff every `trigger_evaluations[].result` is `false` (bidirectional
  — B6; a semantic validator, not this JSON Schema document alone, enforces
  every exact-set/cardinality/bidirectional/nested-uniqueness rule this
  paragraph states, since JSON Schema draft-07 cannot itself express
  "array length equals an externally-discovered Registry's own array
  length" — `validate-resolver-evidence` contract, below), `diagnostics[]`
  (`{id: <REQ-002's own closed, sixteen-value enum, requirements.md
  REQ-002>,
  detail: string, severity: "block"|"warn"}`). `additionalProperties:
  false` at every level, matching every other `contracts/*.schema.json` in
  this repository.
- **`specs/<feature>/facet-manifest.yaml`**, **`specs/<feature>/
  capability-summary.yaml`**, **`generated/project-context.resolved.
  json`**: Epic A4's own already-fixed shapes (requirements.md
  Dependencies) — this feature reads none of them as input to any other
  step; each is a pure output this feature's Resolver writes once per
  invocation, and never more than one of `facet-manifest.yaml`/
  `capability-summary.yaml` in the same invocation (track-exclusive,
  Design Decisions "track-exclusive publication set", B4).
- **`facet-manifest.yaml`'s own `conditional_facets[]` — this feature's
  computation of an A4-owned field (facet-name cross-Capability
  aggregation, B7)**: Epic A2's own Registry schema does not require
  `conditional_facets[].facet` uniqueness *within* one Capability's own
  declaration, and does not forbid two *different* Capabilities from each
  declaring a `conditional_facets[]` entry under the identical `facet`
  name — while Epic A4's `facet-manifest.schema.json` requires
  `conditional_facets[].facet` to be unique **Manifest-wide**
  (investigation.md, citing `specs/epic-192-a4-facet-manifest/
  requirements.md:220-235`). This feature's Resolver therefore aggregates,
  per distinct `facet` name, across every **predicate instance** —
  every `(capability_id, declaration_index)` pair, Registry-wide, across
  every **matched** Capability, whose own `conditional_facets[declaration_
  index].facet` equals that name, including more than one such pair from
  the *same* Capability (Design Decisions, "facet-name aggregation,
  predicate-instance keyed", B7, revised, below, gives the exact
  `applied`/`evidence`/`reason` combination rule) — this is a computation
  this feature's own orchestration performs to satisfy an already-fixed A4
  field constraint, not a redefinition of that constraint.
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
- **`context_binding.dependency_pointers[]` — canonical derivation rule
  (B9, no upstream rule fixed this)**: exactly `/workflow`, plus one
  `/components/<id>` pointer per **affected** component (never every
  component the Project Context declares — only the ones this invocation
  actually evaluated a predicate against), each `<id>` RFC 6901-escaped
  (`~` → `~0`, `/` → `~1`, applied before any other pointer construction,
  matching A4's own `dependency_pointers[].pattern`,
  `^/(workflow|components|shared_paths)(/([^/~]|~0|~1)*)*$`, investigation.
  md INV-004), the resulting set stable-sorted (lexicographic, by the
  pointer string itself) and de-duplicated (a Feature can only be affected
  by a given component `id` once, but the rule is stated for defensiveness
  regardless). `/workflow` is always present — `workflow.spec_profile`/
  `capability_enforcement`/`artifact_layout` gate REQ-002's own `disabled-
  legacy`/`workflow-combination-invalid` checks and this invocation's own
  `state`, so every invocation's semantic output structurally depends on
  it. `/shared_paths` is never included — a `trigger`/`when` predicate's
  own `scope: affected_component` never reads a `shared_paths` entry
  directly (Data Plan, "Context Projection read set", above), and
  `shared_paths`'s own contribution to `affected_components` is entirely
  Epic A3's own `ownership_digest`-bound concern, a separate digest this
  schema already carries independently.
- **`resolver.version`/`resolver.rule_set_revision` — single-source-of-
  truth and canonical-preimage rules (B9, no upstream rule fixed this)**:
  `resolver.version` is read from one `RESOLVER_VERSION` string constant
  defined once, at the top of `resolve-project-context.py` (the Python
  master) — the `.sh`/`.ps1` dispatchers never read, duplicate, or
  independently derive this value; they invoke the Python master, which
  alone emits it into Resolver Evidence, so `.py`/`.sh`/`.ps1` parity
  (REQ-005/AC-023) is structural, not independently maintained per
  runtime, and mutated only via `scripts/bump-version.sh`
  (REQ-008/AC-034). `resolver.rule_set_revision` is the sha256 hex digest,
  `sha256:<64-hex>`, of one fixed, versioned canonical UTF-8 string
  constant (e.g. `"sdd-resolver-rule-set/v1"`) defined identically
  alongside `RESOLVER_VERSION` — this feature's own orchestration rules
  (union-match, WARN-Block scope, facet-name aggregation, the REQ-002
  Block taxonomy) have no upstream file `rule_set_revision` could
  otherwise be a digest *of*; the canonical string is instead this
  feature's own fixed statement of *which revision of its own rule set*
  produced a given Resolver Evidence instance, bumped in lockstep with any
  future change to one of those rules (never independently derived per
  runtime, never a hash of any *input* file — a hash of a fixed, versioned
  constant this feature's own source carries, so `rule_set_revision` is
  identical across every invocation of the same Resolver revision,
  regardless of which Feature, Registry, or Project Context it is run
  against).
- **Invocation-start snapshot / pre-publication recheck / post-
  publication verification (B8, revised — no upstream rule fixed this)**:
  at the moment each of the three externally-sourced byte sequences this
  invocation's own digests are computed from is first read —
  `project-context.yaml`'s own canonicalized bytes (`source_sha256`),
  the ownership-source bytes `resolve-component-paths` itself read to
  compute `ownership_digest` (this feature does not re-read the
  underlying `paths`/`shared_paths` declarations a second time; it pins
  the `ownership_digest` value `resolve-component-paths` itself already
  returned), and the discovered Registry's own bytes (`registry_digest`)
  — this invocation retains that exact byte sequence (or, for `ownership_
  digest`, that exact already-computed digest value), **and** the
  `affected_components` set `resolve-component-paths` returned (NEW, B8
  correction, below), in memory as its own fixed snapshot, never
  re-reading any of the three paths from disk again except for the three
  rechecks below. **First (step 6.5 — ruling C(1), human-approved
  2026-08-26, sanctioning the detection recheck two independent
  cross-model panels converged on): a detection-only Registry recheck
  immediately after `validate-capability-registry` and
  `generate-registry-digest --whole` complete. Neither dependency
  accepts a path/bytes argument binding it to this invocation's own
  step-5 read — each independently re-discovers and re-reads the
  Registry — so this invocation re-reads the identical `registry_path`
  and compares the fresh bytes' digest against the raw-bytes digest
  retained at step 5's own first read; any difference, including the
  re-read itself failing, Blocks `snapshot-generation-mismatch`
  (REQ-002's amended second trigger site; AC-057's own dedicated
  `registry-swapped-during-validation` fixture locks exactly this
  site).** Immediately before
  publication (step 13), this
  invocation re-reads the same three paths and re-invokes `resolve-
  component-paths` with the identical flags a second time — **now for
  both a fresh `ownership_digest` and a fresh `affected_components` set**
  (an earlier revision of this recheck obtained only `ownership_digest`,
  reasoning it alone would catch relevant drift; adversarial review "B8"
  found this false: `ownership_digest` is Epic A3's own blunt,
  project-wide "the ownership *config* changed" signal, `specs/
  epic-191-a3-path-ownership/requirements.md:530-569`, REQ-005, and does
  **not** change when only the underlying *diff* — the worktree/index/
  untracked state a second concurrent commit or edit could shift between
  this invocation's own two `resolve-component-paths` calls — changes
  which components that diff actually touches, config unchanged) — and
  recomputes each of the three digests plus compares the fresh
  `affected_components` set against the invocation-start one,
  element-for-element; any digest mismatch, **or** any `affected_
  components` set difference (even with every digest, including
  `ownership_digest`, still matching) → Block, `snapshot-generation-
  mismatch` (REQ-002), even though every earlier step in this invocation
  already succeeded — publication never runs on a generation-mixed input
  set. **Post-publication verification (NEW, B8 — the "Resolver
  publication transactional bundle contract" subsection, API / Contract
  Plan, gives the exact mechanism)**: this identical three-digest-plus-
  affected-components comparison runs a **third** time, immediately after
  every rename in the publication transaction's own Commit phase
  succeeds but before its own Complete phase deletes the journal — this
  closes the remaining "post-recheck race," the window between the
  pre-publication recheck immediately above and the last rename actually
  completing, during which the identical class of drift could occur a
  *second* time. A mismatch here → Block, `post-publication-generation-
  mismatch` (REQ-002, NEW) — and, unlike the pre-publication recheck
  above (which never touches a live path), this invocation must now roll
  back every already-committed rename to its own PRE-transaction state
  via the transactional bundle contract's own journal before returning
  that exit code, since the artifacts in question are, at the moment of
  this check, already live.

Existing Data Affected: none written; two existing artifacts read only —
the **Registry Capability read set** and the **Context Projection read
set** (both defined above, in this same Data Plan) are the only existing,
already-`Spec-Review-Status: Passed` sibling-epic artifacts this
feature's Resolver ever reads (`capability-registry.json`, Epic A2, via
`gate_ids`/`capabilities[]` referential lookup; the Resolver's own
internally-computed Context Projection, Epic A4's REQ-003 generation
procedure applied to `project-context.yaml`'s own already-approved
content, Epic A1). Neither is ever modified by this feature — this
feature's Resolver performs no write of any kind against
`capability-registry.json`, `project-context.yaml`, or any other Epic
A1/A2/A3/A4 artifact (Cross-Layer Dependencies, above, "this package does
not edit Epic A4's/A2's own files, this task's own hard boundary"; API /
Contract Plan step 5, "Registry discovery ... read not redefined").
`generated/project-context.resolved.json` is this feature's own new
output, not an existing artifact this feature affects — see Data Entities,
above, and Protected-File Statement.

Migration Strategy: none. No database, no runtime storage, no schema
migration anywhere in this feature — the same "no database, no migration,
no runtime storage" statement every sibling epic's own `infra-spec.md`
(not authored at this phase, Layer Specifications above) would otherwise
record. `contracts/resolver-evidence.schema.json`,
`specs/<feature>/resolver-evidence.yaml`, and the one content-population
target (the `resolve-project-context.{py,sh,ps1}` script family) this
feature's own future implementation stages under human-copy are each a
net-new, additive artifact with no prior version to migrate from —
`generated/project-context.resolved.json` is never a human-copy target at
all (Protected-File Statement, "M7 human-copy boundary", above).

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

**Processing order** (adversarial-review-revised — findings "B1
atomicity"/"B2 WARN"/"B3 taxonomy"/"B4 Lite publication"/"B8 TOCTOU"/"M3
invalid workflow combination"/"M4 CLI misuse"/"M8 stderr parity"/"M9
zero-component". This revision's central structural change: **nothing
this invocation computes is written to a live path until every Block
condition this invocation's own inputs could trigger has already been
determined** — steps 7-9 (evaluation) always run to completion before
steps 10-14 (assembly/validation/publication) begin, and steps 10-14
themselves stage every artifact and validate it before the single atomic
commit step (14) ever touches a live path. Each step's own failure maps
to exactly one REQ-002 diagnostic; a step's own success is a
precondition for the next, except that steps 7 and 8 never short-circuit
internally — every capability/component (7) and every matched-capability/
facet/component (8) combination is evaluated and recorded regardless of
any individual combination's own result):

0. **Argument validation.** All required flags present, `--feature`
   matches its own pattern. Failure → exit 2 (usage error), no
   diagnostic-id line (this is not a Block; it never reaches REQ-002's
   own enum) — mirroring Epic A4's own `compare-facet-manifest-staleness`
   precedent of a separate, non-verdict error channel (Epic A4
   `design.md:894-916`).

   **Crash-recovery scan (mandatory, runs on every invocation immediately
   after step 0 succeeds and before step 1 begins — B1, "Resolver
   publication transactional bundle contract" below gives the exact
   mechanism).** Scan `specs/<feature>/.resolver-staging/*/TRANSACTION.
   json` (scoped to this invocation's own `--feature` value only) for a
   journal a prior, interrupted invocation against the identical Feature
   left behind. Absent → proceed to step 1, no diagnostic. Present →
   recover to one of the two terminal states (fully-applied or
   fully-reverted) exactly as the transactional bundle contract
   specifies, then proceed to step 1. If recovery itself cannot safely
   complete → Block, `publication-journal-recovery`, exit 1, before any
   Registry/ownership/Context-Projection work begins — the sole
   diagnostic this invocation can emit at this point, alongside
   `disabled-legacy-invocation`.
1. **State derivation** (requirements.md REQ-003). Attempt to read
   `--config`'s target path. Absent, or the AGENTS.md-marker/default
   fallback derives `disabled-legacy` per ADR-0016 item 4 → Block,
   `disabled-legacy-invocation`, write a minimal Resolver Evidence record
   directly (no staging area exists yet — Data Plan: `schema`, `feature`,
   `state: "disabled-legacy"`, `context_binding` and `resolver` blocks
   both absent — there is nothing to bind, since no Registry/ownership/
   projection step ever ran — `capability_evaluations: []`, `diagnostics:
   [{id: "disabled-legacy-invocation", detail: <path attempted>,
   severity: "block"}]`), exit 1. This Block is reached at step 1 —
   **before** step 3's Context Projection assembly, step 4's `resolve-
   component-paths` invocation, and step 5's Registry discovery — so no
   ownership, Registry-discovery, or Context-Projection subprocess is
   ever spawned in this branch at all (AC-015). **This diagnostic exists
   as a defense-
   in-depth guard against a caller-contract violation, never as a designed
   pipeline state of its own** (M4 correction, below, and Security
   Boundaries) — REQ-007's own compatible-caller contract requires
   `sdd-bootstrap-interviewer` to never invoke this Resolver's process at
   all while a Project Context is absent or derives `disabled-legacy`
   (ADR-0016 item 4 names the Resolver itself, alongside the Registry and
   Gate machinery, as outside `disabled-legacy`'s own computational domain,
   investigation.md INV-013); a caller that invokes this Resolver anyway
   is misusing its CLI, and this diagnostic is this feature's own fail-
   closed response to that misuse, not evidence the Resolver has a
   meaningful "disabled-legacy mode" of its own. Present but fails Epic
   A1's own content-schema validation surface → Block, `project-context-
   validation-failed`, exit 1 (a normal, full Resolver Evidence record is
   written directly here too — Registry/ownership discovery has not yet
   run, so no staging area exists yet either — `state` is omitted, since
   none of the three values applies to a schema-invalid Context).
   Otherwise, `workflow.capability_enforcement` (`advisory` or `required`)
   is read and recorded as this invocation's `state`, and `workflow.
   spec_profile`/`workflow.artifact_layout` are checked against decision
   document v2 §6's own combination matrix: `spec_profile == "lite"` with
   `artifact_layout != "lite-three-file"`, or `spec_profile == "full"`
   with `artifact_layout == "lite-three-file"`, is one of that matrix's
   own two explicitly-named "無効な組合せ" (invalid combination) rows →
   Block, `workflow-combination-invalid`, exit 1, a normal full Resolver
   Evidence record written directly (no staging area exists yet — this
   check runs immediately after the schema-validity check above and
   immediately before any Registry/ownership/projection work begins, M3
   correction). Every other named combination in that same matrix
   (including both `disabled-legacy` fallback rows, already handled
   above, and every named valid full/lite combination) proceeds to step 2.
2. **Project Context canonicalization** (Epic A1). Invoke
   `canonicalize-sdd-yaml` (YAML mode) over `--config`'s target →
   `source_sha256` (= `context_binding.full_context_revision`); its
   canonical-JSON stdout is separately `json.loads()`-parsed. A
   canonicalizer subprocess non-zero exit here → Block, `canonicalizer-
   invocation-failed`, exit 1. A zero exit whose stdout does not parse as
   valid JSON (or valid canonical-UTF-8 text, per the invoked mode) →
   Block, `dependency-output-malformed`, exit 1 (B3 — distinct from a
   non-zero exit, since a subprocess that exits 0 with unparseable output
   is a different failure mode, not previously named by any diagnostic
   row). **Snapshot (B8):** this invocation retains `--config`'s own
   target-path bytes (as canonicalized above) in memory as this
   invocation's own fixed Project Context snapshot; no later step re-reads
   this path from disk except the pre-publication recheck, step 13, below.
3. **Context Projection assembly** (Epic A4's own REQ-003 generation
   procedure, verbatim — Data Plan, above): substitute `components: []`/
   `shared_paths: []` for either omitted key; re-key `components` by
   `id`; feed the re-keyed structure back through `canonicalize-sdd-yaml`
   (JSON mode) → `projection_sha256`. This is Epic A4's own REQ-003
   two-pass-canonicalizer generation procedure applied **verbatim**, not
   a variant of it, and the Projection it produces is computed on
   **every** track (matched-Capability evaluation needs it regardless)
   while being published to `generated/project-context.resolved.json`
   only on the Full track — a Lite-track resolve never writes that path
   (AC-003; Design Decisions, "track-exclusive publication set", below).
   **Staged, not written to a live
   path yet** (B1/B4 — the earlier revision of this design wrote this
   artifact directly to `generated/project-context.resolved.json` at this
   point, before any later step's own Block condition could be known;
   this revision defers every live-path write to the single atomic commit
   step, 14, below). A second canonicalizer non-zero exit here → identical
   `canonicalizer-invocation-failed` Block; a zero exit with unparseable
   stdout → identical `dependency-output-malformed` Block (B3).
4. **Affected-component resolution** (Epic A3). Invoke
   `resolve-component-paths --config <same --config value>
   [--source-rev <same value>] --target-rev <same value>
   [--include-untracked] --json`. Non-zero exit → `affected-component-
   resolution-failed` Block, exit 1 — this Block's own `detail` is a
   **canonical diagnostic this feature constructs itself** (M8
   correction, below): `"resolve-component-paths exited <code> resolving
   <repo-relative --config path>; see resolve-component-paths
   diagnostics"` — **never** the underlying script's own raw stderr text
   quoted verbatim (an earlier revision of this design did exactly that;
   adversarial review "M8 stderr parity" found that upstream stderr's own
   path-separator/quoting/runtime-wording differences across `.py`/`.sh`/
   `.ps1` are outside this feature's own control and cannot satisfy
   REQ-005's own byte-identical dual-runtime parity requirement — the
   underlying script's own stderr remains visible to a human operator on
   the terminal, exactly as `resolve-component-paths` itself already
   writes it; it is simply never copied into this Resolver's own
   structured `detail` field). A zero exit whose stdout does not parse as
   the JSON shape `resolve-component-paths --json` itself already
   contractually promises (Epic A3) → Block, `dependency-output-
   malformed`, exit 1 (B3). A zero exit with well-formed JSON stdout →
   `affected_components[]` and `ownership_digest` consumed from it —
   exactly those two outputs, never a subset of either and never a
   caller-supplied override of either, invoked with the `--config`/
   `--source-rev`/`--target-rev`/`--include-untracked` values this
   invocation itself received, byte-for-byte (CLI contract, above)
   (AC-004).
   **Snapshot (B8):** this invocation retains this exact `ownership_
   digest` value (this feature never re-reads the underlying `paths`/
   `shared_paths` declarations directly — Data Plan, above) as this
   invocation's own fixed ownership-source snapshot.
5. **Registry discovery** (Epic A2, via ADR-0025). Resolve
   `capability-registry.json` and `capability-registry.schema.json` per
   the script-relative-then-git-root-fallback procedure (investigation.md
   INV-005); a resolution or version-check failure at this step →
   `contract-discovery-failed` Block. Run Epic A2's own `validate-
   capability-registry` checks against the located Registry; a failure →
   `registry-validation-failed` Block. Both are exit 1. **Snapshot (B8):**
   this invocation retains the located Registry's own canonicalized bytes
   in memory as this invocation's own fixed Registry snapshot.
6. **`registry_digest`.** Invoke `generate-registry-digest --whole`
   (Epic A2) against the located Registry → `context_binding.
   registry_digest` — always `--whole`, never a `--capability-ids`/
   `--gate-ids` fragment (AC-005; Epic A4's own already-fixed choice,
   requirements.md Dependencies, not this feature's to re-decide). A
   canonicalizer failure inside that invocation →
   `canonicalizer-invocation-failed` Block (this feature's own diagnostic
   surface treats every canonicalizer subprocess failure, regardless of
   which upstream step invoked it, identically — Design Decisions,
   below). A non-zero exit from `generate-registry-digest` itself, for a
   reason other than an internal canonicalizer failure (a defensive,
   should-never-occur case against an already-validated Registry) →
   Block, `dependency-subprocess-failed` (B3 — this feature's own closed-
   enum catch-all for a dependency subprocess's own generic, otherwise-
   unnamed non-zero exit; used again in step 7/8 below for `evaluate-
   predicate`'s own equivalent case). A zero exit whose stdout is not a
   well-formed `sha256:<64-hex>` digest string → `dependency-output-
   malformed` Block (B3).
6.5. **Detection-only Registry recheck (ruling C(1), human-approved
   2026-08-26 — the Data Plan's sanctioned third recheck; AC-057).**
   Immediately after steps 5-6's two dependency invocations
   (`validate-capability-registry`, `generate-registry-digest --whole`)
   complete — each of which independently re-discovers and re-reads the
   Registry with no binding to this invocation's own step-5 read — this
   invocation re-reads the identical `registry_path` and compares the
   fresh bytes' digest against the raw-bytes digest retained at step 5's
   own first read. Any difference, including the re-read itself failing
   (at least as suspicious as a byte difference), → Block,
   `snapshot-generation-mismatch` (REQ-002's amended second trigger
   site) — before any step-7 evaluation result can come to depend on
   unverified Registry bytes. Detection-only: this recheck cannot
   observe what bytes the two subprocesses themselves read inside their
   own processes (the Data Plan's honesty limitation), only that
   `registry_path`'s bytes are unchanged across the window.

7. **Per-component, per-Capability trigger evaluation — every Registry
   Capability, matched or not, evaluated in full (B2/B6).** For each
   Registry `capabilities[]` entry, **in Registry-declaration order**
   (Registry `capabilities[]` is Epic A2's own already-author-ordered
   array — this feature does not re-sort the Registry's own read order,
   only its own *output* arrays, per REQ-005/AC-024), and for each
   `affected_components[]` entry **in ascending lexicographic order**
   (or, when `affected_components` is the empty array, the zero-iteration
   case — M9 correction, below), invoke `evaluate-predicate --predicate
   <this capability's trigger> --component-properties <this affected
   component's Context-Projection entry>`. **An `affected_components[]`
   entry naming a component id absent from the Context Projection Blocks
   `dependency-output-malformed` before any predicate evaluation of that
   entry — never a defaulted-empty-properties evaluation (ruling C(2),
   human-approved 2026-08-26; REQ-002's amended row; AC-058's own
   dedicated `affected-component-absent-from-context` fixture locks
   exactly this path).** A `PREDICATE_SCHEMA_ERROR`
   exit here (a malformed predicate — should never occur against an
   already-`validate-capability-registry`-passed Registry, but checked
   defensively) → `registry-validation-failed` Block (a malformed
   predicate is, by construction, a Registry validation defect this
   feature did not itself introduce). Any other non-zero exit →
   `dependency-subprocess-failed` Block (B3). A zero exit whose stdout
   does not parse as the `{result, evidence}` JSON shape Epic A2's own
   evaluator contract promises → `dependency-output-malformed` Block
   (B3). Every result (`result`, `evidence[]`) is recorded in this
   invocation's own in-memory evaluation set, keyed
   `capability_evaluations[<this capability>].trigger_evaluations[]`,
   **regardless of outcome** — no short-circuit, matching ADR-0020's own
   "every predicate is evaluated" discipline extended by this feature to
   its own per-component fan-out (Design Decisions), and regardless of
   whether this Capability turns out matched or unmatched (B6 — Resolver
   Evidence's own exact-set completeness rule, Data Plan, above, requires
   every Registry Capability's own `trigger_evaluations[]` recorded in
   full, not only a matched subset's). A Capability is **matched** iff at
   least one `trigger_evaluations[]` entry's `result` is `true` (the
   union-match rule, Design Decisions) — this feature computes, but does
   not yet act on, `matched` here; no Block or assembly decision depends
   on any individual evaluation's own outcome until step 9.
8. **Matched-Capability conditional-facet evaluation — every
   `conditional_facets[]` entry a matched Capability declares, evaluated
   in full (B2/B6).** For each Capability step 7 determined **matched**,
   and each of its `conditional_facets[]` entries, repeat step 7's
   per-affected-component fan-out (identical error handling: `PREDICATE_
   SCHEMA_ERROR` → `registry-validation-failed`; other non-zero exit →
   `dependency-subprocess-failed`; unparseable zero-exit stdout →
   `dependency-output-malformed`) against that entry's own `when`
   predicate, recording every result in this invocation's own in-memory
   evaluation set, `capability_evaluations[<capability>].conditional_
   facet_evaluations[<declaration_index>].evaluations[]` — keyed by that
   `conditional_facets[]` entry's own array position (`declaration_
   index`), **not** by `facet` name (B7 predicate-instance keying,
   revised — a Capability declaring the identical `facet` name at two
   different `declaration_index` positions produces two independent
   entries here, never one collapsed entry) — again with no short-circuit.
   A given Capability's own `conditional_facets[].facet` entry is
   `applied: true`, **for that Capability's own Resolver-Evidence-scoped
   record**, iff at least one of *that Capability's own* per-component
   evaluations' `result` is `true` (the identical union-match rule,
   reused for facet-level, not only capability-level, matching — this is
   distinct from, and computed before, the cross-Capability facet-name
   aggregation step 10a performs for the Facet Manifest's own
   `conditional_facets[]`, Design Decisions "facet-name aggregation", B7,
   below).
9. **Any-branch WARN check (B2, widened scope).** Across **every**
   evaluation this invocation performed in steps 7 and 8 — every Registry
   Capability's own `trigger_evaluations[]`, matched or unmatched, and
   every matched Capability's own `conditional_facet_evaluations[].
   evaluations[]` — if **any** evaluation's own Evidence tree contains an
   `outcome: "warn"` node **anywhere**, on **any** branch → `dsl-warn-on-
   matched-capability` Block, exit 1 (the diagnostic-id string is
   retained unchanged from the earlier, narrower-scoped revision for
   enum stability across this feature's own schema/validator/fixture
   surface; its condition is no longer scoped to a "representative" or
   "matched-capability-only" branch — an earlier revision of this design
   Blocked only on a single, deterministically-chosen "representative"
   evaluation per matched Capability, and never inspected an unmatched
   Capability's own trigger Evidence at all; adversarial review "B2 WARN"
   found this let a WARN-producing, potentially-false-negative evaluation
   on any other branch silently aggregate into a clean `false`/`applied:
   false` outcome, under-resolving the Feature). A full Resolver Evidence
   record is written here, including every evaluation this invocation
   already performed through step 8 — this Block fires only after all
   evaluation work is complete, so the record is maximally informative
   for the caller diagnosing it. No WARN anywhere → continue.
10. **Track branch, decided here, before any publication (B4).**
    `workflow.spec_profile` (already read, step 1) selects exactly one of:
    - **(10a) Full track — Facet Manifest assembly.** Collect every
      matched Capability's `required_facets`/`gate_ids` (resolved to
      `{id, stage, blocking}` via the Registry-side lookup, Data
      Plan)/`lite_policy`/`minimum_enforcement`; compute `conditional_
      facets[]` via the cross-Capability facet-name aggregation rule
      (Design Decisions "facet-name aggregation", B7 — this is the step
      that combines step 8's own per-Capability `conditional_facet_
      evaluations[]` records into Epic A4's facet-name-unique Manifest
      field); assemble every other Epic-A4-defined field. Two of those
      "every other" fields are fed directly by this step's own collection
      above, and are named here rather than left to the catch-all
      (AC-007): **`capability_minimum_enforcement`** is the `max()` (i.e.
      logical OR, `"required"` being the only non-absent value Epic A2's
      Registry schema defines) of every matched Capability's own
      `minimum_enforcement`, and **`lite_eligibility`**
      (`{eligible, upgrade_reasons[]}`) is Epic A4's own aggregation over
      every matched Capability's own `lite_policy`. **Neither is
      redefined here.** This feature populates
      `required_facets`/`conditional_facets`/`resolved_gates`/
      `capabilities`/`capability_minimum_enforcement`/`lite_eligibility`
      per Epic A4's own field-by-field semantics verbatim, adds no field
      Epic A4's schema does not define, and omits no field it requires
      (requirements.md Dependencies and Field Definitions fix those
      semantics; this feature's Non-goals exclude decision document v2
      §10's full effective-enforcement computation, of which
      `capability_minimum_enforcement` is only the Registry-derived
      term). The zero-matched-Capability path is the degenerate case of
      the same rules: `capability_minimum_enforcement` absent,
      `lite_eligibility: {eligible: true, upgrade_reasons: []}`
      (requirements.md Edge Cases, "zero affected components"). Then
      stable-sort every semantic-output array (Epic A4's own rule,
      requirements.md REQ-005/AC-024). **Stage** (do not yet write)
      `specs/<feature>/
      facet-manifest.yaml` and the Context Projection staged in step 3.
      No Capability Summary is staged on this track (B4 — Epic A4's own
      track-exclusive contract, investigation.md INV-004, names only a
      Facet Manifest for the Full track).
    - **(10b) Lite track — Capability Summary assembly.** `capabilities`
      = the matched-Capability-id set step 7 determined;
      `full_upgrade_required` = `!lite_eligibility.eligible` (the
      identical aggregate signal 10a would compute, requirements.md Field
      Definitions, computed here directly since 10a does not run on this
      track); `required_lite_checks` — **narrowed by cross-epic addendum
      (Epic A6 adversarial verification finding B5, requirements.md
      Dependencies)**: for each matched Capability, attempt to source its
      own contribution from that Capability's own Registry entry's
      `lite_policy.required_lite_checks` key. If that key is **present**
      (including present-and-empty), its own value (or `[]`) is that
      Capability's own contribution — valid, non-Blocking, regardless of
      enforcement state. If that key is **absent**, the contribution
      depends on `state` (step 1, REQ-003): under `advisory`, the absent
      key contributes an empty `[]` and processing continues; under
      `required`, the absent key → `lite-check-source-undefined` Block,
      exit 1 — nothing from step 3 or this step was ever written to a
      live path (no staging-area artifact reaches commit), so this Block
      never leaves a partial `capability-summary.yaml` either. Zero
      matched Capabilities is vacuously non-Blocking under either
      enforcement state (no Capability's own key is ever consulted).
      These are exactly three non-Blocking states — **advisory-missing**,
      **required-present-empty**, and **zero-match** — and in each of
      them this invocation stages a `capability-summary.yaml` that passes
      step 12's own `validate-capability-summary` self-check against Epic
      A4's `contracts/capability-summary.schema.json` before publication,
      and writes neither `facet-manifest.yaml` nor `project-context.
      resolved.json` (AC-009; the track-exclusive output set immediately
      below, B4). On a
      resolvable source (today: any `advisory`-enforcement Lite resolve;
      any `required`-enforcement Lite resolve where every matched
      Capability's own key is present, including present-and-empty; or
      the zero-matched-Capability case, requirements.md Edge Cases, "zero
      affected components" — Test Strategy item 4's own
      track-exclusive-output-set
      fixture, B5 correction below), **stage** (do not yet write)
      `specs/<feature>/
      capability-summary.yaml` only — no
      `facet-manifest.yaml` and no `project-context.resolved.json` are
      staged or written on this track (B4 — this corrects an earlier
      revision that assembled a Facet Manifest in a Full-track-shaped
      step *before* branching on track, then additionally staged a
      Capability Summary on the Lite track, producing both; Epic A4's own
      contract names Capability Summary as the Lite track's **only**
      output, never a Facet-Manifest-plus-Summary pair).
11. **Resolver Evidence assembly.** Assemble (stage, do not yet write)
    `specs/<feature>/resolver-evidence.yaml` — every `capability_
    evaluations[]` entry from steps 7-8 in full (B6 — every Registry
    Capability, matched or not; every affected component; every matched
    Capability's own declared `conditional_facets[]`, in full, regardless
    of which track branch 10 took — Resolver Evidence's own completeness
    guarantee is track-independent, REQ-004), `diagnostics: []` (no Block
    condition fired through step 10), `context_binding` (`dependency_
    pointers[]`/`resolver.version`/`rule_set_revision` per the canonical
    derivation rules, Data Plan "B9", above; `registry_digest`/
    `ownership_digest`/`full_context_revision`/`projection_sha256` from
    steps 2-6), `resolver` (`version`/`rule_set_revision`, Data Plan
    "B9"), `state` from step 1.
12. **Output schema self-validation (B3).** Every artifact staged through
    steps 3/10/11 is validated against its own governing schema (`Facet
    Manifest`/`Capability Summary`/`Context Projection` against Epic A4's
    three schemas; `Resolver Evidence` against this feature's own
    `contracts/resolver-evidence.schema.json`) using the same hand-rolled
    validators (`validate-facet-manifest`/etc., Epic A4;
    `validate-resolver-evidence`, this feature, below) a downstream
    caller would otherwise run separately — a defensive self-check, since
    every field above is already assembled from already-validated inputs
    and should never fail this check in practice, but a schema-conformance
    defect in this feature's own assembly logic must never reach a live
    path. Any failure → Block, `output-schema-validation-failed`, exit 1
    — Resolver Evidence (already staged, step 11) is itself re-validated
    first; **if Resolver Evidence itself is the artifact that fails this
    check, this invocation writes NOTHING to any live path, including
    Resolver Evidence's own path (B3 — this reverses an earlier revision's
    "write the best-effort Resolver Evidence it can assemble" rule).** A
    fields-omitted, self-assembled "best-effort" Evidence instance carries
    no guarantee of re-conforming to `contracts/resolver-evidence.schema.
    json` itself, and would therefore itself be exactly the schema-invalid
    live artifact this check exists to keep off a live path — writing it
    anyway to satisfy REQ-004's own "written on every invocation" rule
    would defeat the purpose of this check. This is therefore the **sole**
    exception to that rule (the other named exception, `disabled-legacy-
    invocation`, writes a minimal but fully schema-valid record, never a
    partial one, step 1, above) — this invocation's only signal in this
    one case is its own `capability-resolver: output-schema-validation-
    failed: ...` stderr line and non-zero exit code, never a live artifact
    of any kind. If instead a *different* staged artifact (Facet Manifest,
    Capability Summary, or Context Projection) is what fails this check,
    Resolver Evidence itself (already independently schema-valid) is
    still written normally as this Block's own record, unaffected by this
    exception. These two sub-cases of the one diagnostic id are
    independently triggerable and are locked separately — the
    Evidence-itself-fails case writing nothing to any live path, the
    non-Evidence-artifact-fails case still writing Evidence (AC-012's own
    general rule) while withholding the failing artifact (AC-011) —
    AC-055.
13. **Pre-publication snapshot recheck (B8 TOCTOU, Data Plan above gives
    the digest-derivation mechanism).** Re-read `--config`'s target, the
    Registry discovery resolved in step 5, and re-invoke `resolve-
    component-paths` with this invocation's own identical flags a second
    time — this time for a fresh `ownership_digest` **and** a fresh
    `affected_components` set (B8 correction: an earlier revision of this
    step re-invoked `resolve-component-paths` solely for `ownership_
    digest`, never re-deriving `affected_components`, on the reasoning
    that `ownership_digest` alone would catch any relevant generation
    drift; adversarial review "B8" found this false — `ownership_digest`
    is Epic A3's own blunt, project-wide "the ownership config changed"
    signal, REQ-005, `specs/epic-191-a3-path-ownership/requirements.md:
    530-569`, and does **not** itself change when only the *diff* (the
    worktree/index/untracked state between this invocation's own
    `--source-rev`/`--target-rev`, unrelated to any ownership-config edit)
    changes between this invocation's own step-4 snapshot and this
    recheck — a second concurrent commit or worktree edit could shift
    which components are actually affected while `ownership_digest`
    itself stays byte-identical, silently publishing output bound to a
    stale affected-component set). Recompute all three digests, **and**
    compare the freshly re-derived `affected_components` set against this
    invocation's own step-4 snapshot set, element-for-element. Any digest
    mismatch, **or** any difference between the two `affected_components`
    sets (even when every digest, including `ownership_digest`, still
    matches) → Block, `snapshot-generation-mismatch`, exit 1 — even though
    every earlier step already succeeded, this invocation's own staged
    artifacts reflect a generation-mixed input set and must never be
    committed. (This step's own re-invocation of `resolve-component-
    paths` is used **only** for this comparison — the `affected_
    components`/`ownership_digest` values this invocation actually
    evaluated against and will publish, if this check passes, remain
    exactly the step-4 values; a passing recheck changes nothing this
    invocation has already computed.)
14. **Publication (B1/B8 — "Resolver publication transactional bundle
    contract", below, gives the exact Prepare/Journal/Commit/Post-
    publication-verification/Complete mechanism, applying Epic A1's own
    already-fixed multi-target transactional bundle contract
    isomorphically).** Every artifact staged in steps 3/10/11 that
    belongs to this invocation's own track-exclusive output set (10a:
    Facet Manifest + Context Projection + Resolver Evidence; 10b:
    Capability Summary + Resolver Evidence), or (on any Block reached at
    step 1/9/10/12/13, above) Resolver Evidence alone, is published via
    that journaled transaction — Resolver Evidence is a member of
    **both** track sets, so a fully successful run publishes it exactly
    as every Block does; it is never conditionally omitted on success
    (AC-020, REQ-004's own always-emit rule, whose two named
    diagnostic-id exceptions are step 1's minimal
    `disabled-legacy-invocation` record and step 12's
    Evidence-itself-fails no-write case, both above — a count bounded by
    ruling (a)'s non-diagnostic containment refusal per requirements.md's
    Ruling Annotations rule; annotated 2026-09-03, human-approved,
    ruling (G)) — never via a
    bare per-file `rename()`
    with no cross-file atomicity and no crash-safe rollback (the exact
    gap adversarial review "B1" found in an earlier revision of this
    step). Every rename succeeding, with no earlier Block and no
    post-publication-verification mismatch, is this invocation's own
    success path, exit 0. A write/fsync/rename failure caught in-process,
    or a post-publication-verification mismatch, each map to their own
    diagnostic (`artifact-publication-failed`, `post-publication-
    generation-mismatch`) exactly as the transactional bundle contract,
    below, defines — never a bare `unlink`-based best-effort rollback
    with no restore of pre-existing live bytes.

**Exit codes**: `0` = success (step 14's own transaction, including its
own post-publication verification, completed with no earlier Block); `1`
= any REQ-002 Block (the crash-recovery scan, steps 1, 2/3/6/7/8, 4, 5,
6.5, 9, 10, 12, 13, 14); `2` = CLI usage error (step 0) — fixed, three-way, matching
this Epic set's own established "a fixed, small exit-code enum a caller
can branch on without parsing stdout" convention (AC-013; Epic A4's `compare-
facet-manifest-staleness`, investigation.md INV-004, uses the identical
pattern for its own, differently-shaped verdict set).

**Diagnostic line format**: `capability-resolver: <check-id>: <detail>`,
one line per diagnostic, to stderr — matching Epic A2's `registry: <check-
id>: <detail>` and Epic A4's `facet-manifest: <check-id>: <detail>`
conventions exactly (requirements.md REQ-002). Every `<detail>` this
feature's own scripts construct is a **canonical, Resolver-owned
sentence** built from fixed fields (repo-relative paths, upstream script
names, upstream exit codes, this feature's own check-id) — never upstream
stderr text quoted verbatim (M8 correction, above) — so `<detail>` itself
participates in REQ-005's own dual-runtime byte-identity guarantee
without needing to normalize any dependency script's own OS-specific
wording.

### Resolver publication transactional bundle contract (REQ-001/REQ-002,
NEW — closes B1's "crash between renames leaves a mixed generation
standing, and a caught write/rename failure destroys pre-existing live
bytes via a bare `unlink` with no restore" gap, and B8's "post-recheck
race" gap, by applying Epic A1's own already-fixed multi-target
transactional bundle contract isomorphically — Epic A1 `design.md:
927-1016`, "Human-copy publisher transactional bundle contract")

Every publication this feature's Resolver performs (step 14, above) spans
MORE THAN ONE live target on a successful Full-track run (`facet-
manifest.yaml`, `generated/project-context.resolved.json`, `resolver-
evidence.yaml`) or a successful Lite-track run (`capability-summary.
yaml`, `resolver-evidence.yaml`), and exactly one target (`resolver-
evidence.yaml` alone) on a Block reached at step 1/9/10/12/13. A crash
between renaming target 1 and target 2 must never be observable as
"target 1 advanced, target 2 did not" — the identical "the anchor
publishes but the sidecar doesn't" class of gap Epic A1's own REQ-007
already closed for its own multi-target human-copy batches (Epic A1
`design.md:937-940`). This feature's Resolver therefore applies every
commit as a single, journaled, multi-target transaction, reusing Epic
A1's own already-fixed protocol shape rather than inventing a second one:

1. **Prepare.** Every target this invocation's own track-exclusive output
   set requires is already staged (steps 3/10/11 having assembled it,
   step 12 having schema-validated it — B3, above). Immediately before
   entering the commit phase, this invocation re-hashes every staged
   candidate TOGETHER, as one step (closing any intra-batch TOCTOU window
   between validating the first staged target and the last). For every
   target that already has live content (a re-resolve of a Feature this
   Resolver has already published for), this invocation additionally
   copies that PRE-transaction live content, byte-exact, into this
   batch's own staging subdirectory — `specs/<feature>/.resolver-
   staging/<batch-nonce>/pre/<target-basename>` (an unprotected staging
   area, this feature's own equivalent of Epic A1's own `sdd/.staging/`
   convention) — this is what makes a full rollback possible without
   needing the live filesystem to still hold the old bytes.
2. **Journal.** Before ANY live rename, this invocation writes a
   transaction journal — `specs/<feature>/.resolver-staging/<batch-
   nonce>/TRANSACTION.json` — listing, in commit order, each target's
   live path, its PRE-transaction hash (or `"ABSENT"`), its POST-
   transaction (staged-candidate) hash, this batch's own nonce, and
   `status: "in-progress"`. The journal itself is written via the
   identical temp-then-rehash-then-atomic-rename discipline as every
   other file this feature writes, so the journal's own existence is
   itself all-or-nothing — it either fully exists with complete, correct
   content, or does not exist at all; there is no torn-journal case.
3. **Commit.** Rename each target from its staged candidate to its live
   path, atomically, one target at a time, in the journal's own recorded
   order (temp file + `fsync` + `rename`, the same single-file primitive
   an earlier revision of step 14 already used, unchanged in itself —
   only the surrounding journal/verify/recovery discipline is new).
4. **Post-publication verification (B8, NEW — closes the "post-recheck
   race," the window between step 13's own pre-publication recheck and
   this step's own last rename completing).** Immediately after every
   rename in step 3 has succeeded — the journal is still present, not yet
   deleted — this invocation re-reads the same three sources step 13
   rechecked (`--config`'s target, the Registry step 5 discovered, and
   re-invokes `resolve-component-paths` a **third** time, again for a
   fresh `ownership_digest` and a fresh `affected_components` set) and
   recomputes all three digests plus the fresh `affected_components` set
   one final time, comparing each against step 13's own recheck snapshot.
   Every comparison matching → proceed to step 5 (Complete), below. Any
   mismatch → this invocation's own artifacts, though now fully live,
   reflect a generation the source has already moved past since step
   13's own recheck; Block, `post-publication-generation-mismatch`, exit
   1 — and, before returning that exit code, this invocation itself rolls
   every just-completed rename **of a publication artifact** BACK to its
   own PRE-transaction state via
   the journal's own `pre/<target-basename>` backups, never
   `resolver-evidence.yaml`, which instead receives this Block's own
   record written directly after that rollback completes (REQ-001 step
   (m)'s rollback-and-no-write scope rule, AC-012/AC-049; scoped
   2026-08-27, human-approved, ruling D(2)) (the identical
   mechanism the crash-recovery scan, below, uses — run in-process here
   since this invocation is still alive to do it itself, rather than
   deferring to the next invocation's own recovery scan) until every
   target is confirmed back at PRE, then the journal is deleted, then
   this invocation exits 1. (If this invocation itself crashes
   mid-rollback, the next invocation's own crash-recovery scan safely
   completes it — the journal is still present, and this in-process
   rollback uses the identical atomic-rename-per-target primitive the
   crash-recovery scan itself uses, so a crash at any point during this
   step is itself recoverable, never a new, unhandled failure mode.)
5. **Complete.** Once every rename has succeeded AND step 4's own final
   verification has passed (the ordinary, no-mismatch path), delete the
   journal (an ordinary `unlink`; a delete failure here just leaves a
   stale-but-fully-applied journal, trivially resolved by the
   crash-recovery scan below). This is this invocation's own success
   path, exit 0.

A `write`/`fsync`/`rename` failure caught **in-process** during steps 1-3
(as distinct from a later, uncaught crash) → Block, `artifact-
publication-failed`, exit 1 — this invocation does **not** attempt an
in-process best-effort `unlink` of an already-completed rename (the exact
gap adversarial review "B1" found: an unlink-based rollback that destroys
pre-existing live bytes with no restore path). Instead: if the journal
(step 2) had not yet been written when the failure occurred, no rename
has yet occurred either, so nothing needs rolling back, and this
invocation's own diagnostic simply records that no target reached a live
path. If the journal HAD already been written, this invocation attempts
the identical journal-based rollback step 4 uses (rolling every
already-committed **publication artifact** target back to PRE, never
`resolver-evidence.yaml` — REQ-001 step (m)'s rollback-and-no-write scope
rule, AC-012), and — whether or not that
in-process rollback fully succeeds — the next invocation's own
crash-recovery scan is the durable backstop that guarantees convergence
to a terminal state regardless (the rollback attempt, and any failure
encountered in it, is recorded in this same diagnostic's own `detail`,
never silently swallowed — AC-039, whose companion fixture is a batch
carrying a second, already-completed rename that must be restored from
this journal's own `pre/<target-basename>` backup rather than
`unlink`ed — but does not introduce a seventeenth diagnostic-id value of
its own — an in-process failure and a hard crash are two triggers for the
identical downstream recovery mechanism, never two different ones).

**Crash-recovery scan (mandatory; runs on every invocation, immediately
after step 0's own argument validation succeeds and before step 1
begins, API / Contract Plan above).** Scan `specs/<feature>/.resolver-
staging/*/TRANSACTION.json` (this invocation's own `--feature` value
scopes the scan — a stale journal under a *different* Feature's own
staging directory is that Feature's own concern, never inspected or
touched by this invocation) for any journal still present. Absent →
proceed directly to step 1, no diagnostic. Present → re-hash every
journal-listed target's CURRENT live bytes (or note `"ABSENT"`):

- Every target's current hash equals its journal-recorded POST value ⇒
  the transaction had, in fact, fully committed before an earlier crash
  (the crash landed between the last rename and the journal delete, or
  during step 4's own post-publication verification after it had already
  passed) — SAFE completion: delete the stale journal, then proceed to
  step 1 (this new invocation's own separate, fresh work).
- Every target's current hash equals its journal-recorded PRE value (or
  both are `"ABSENT"`) ⇒ the transaction never began committing, or step
  4's own rollback had already fully completed before the crash — SAFE
  abandonment: delete the stale journal, then proceed to step 1.
- A MIX (at least one target already at its POST hash, at least one other
  still at its PRE hash or absent) ⇒ the exact partial-publish state this
  design must never leave standing. Roll **every** journal member,
  `resolver-evidence.yaml` included,
  BACK to its PRE-transaction state — this branch is a **recoverable**
  MIX that converges and then proceeds into its own fresh resolve, so no
  Block is raised here and no Block record is written; REQ-001 step (m)'s
  rollback-and-no-write scope rule governs Blocks, and this branch is not
  one (corrected 2026-08-27: the ruling-D(2) sweep applied that rule here
  mechanically, inserting a "receives the Block's own record" clause into
  a branch that raises no Block, which contradicted AC-047's own
  every-target-back-to-PRE requirement; the direct Evidence Block record
  belongs only to the unrecoverable branch immediately below, which does
  Block) —
  using the journal's own
  `pre/<target-basename>` backup via the same atomic-rename primitive (or
  deleting the live file, if its own PRE state was `"ABSENT"`) — until
  every target is confirmed back at PRE. Only then is the journal
  deleted, and only then does this invocation proceed to step 1.
- If recovery itself cannot safely complete — the journal names a
  `pre/<target-basename>` backup file that is itself missing or
  unreadable, or a target's current live hash matches NEITHER its
  journal-recorded PRE nor POST value (an unrecoverable third state no
  automatic recovery can resolve) — this invocation does **not** proceed
  to step 1; Block, `publication-journal-recovery`, exit 1, pending
  manual operator intervention. The live-state obligation here is per
  target, not global (amended 2026-08-27, human-approved, ruling D(2),
  aligning this clause with AC-012/TEST-012's own always-emitted rule
  after attempt 6 round 2 found the earlier global "leaving the live
  state exactly as found" wording contradicted it): **every interrupted
  target other than `resolver-evidence.yaml` is left exactly as found** —
  once recovery declares the journal unconvergeable it attempts no
  partial rollback and no repair, in deliberate contrast to the
  converging branch above, which does restore its targets — **and
  `resolver-evidence.yaml` itself receives this invocation's own Block
  record**, written directly (`temp file + fsync + rename`, no staging
  area, no journal — REQ-001 step (m); opening a second journal against
  the very Feature whose existing journal this invocation has just
  declared unconvergeable would be incoherent), exactly as on the
  step-1 Block branches above.

Recovery is itself idempotent and re-entrant — every comparison is
current-vs-journaled, never assumes prior recovery progress — so a crash
DURING recovery is itself safely resumed by the next invocation (mirrors
Epic A1's own recovery contract verbatim, Epic A1 `design.md:998-1003`).

**Reader-side generation-consistency check.** Any script reading more
than one of a given Feature's own Resolver-published targets together,
and depending on them being mutually consistent (a future Epic A6
consumer, or `validate-resolver-evidence` itself, below), checks for a
live journal naming a path it is about to read
(`RESOLVER_PUBLICATION_IN_PROGRESS`, this feature's own equivalent of
Epic A1's own `HUMAN_COPY_PUBLISH_IN_PROGRESS`) and fails closed rather
than risk reading torn cross-file state.

**Single-writer assumption (mirroring Epic A3's own "single-writer /
snapshot" contract, Epic A3 `design.md:351-371`).** This feature's
Resolver assumes a single writer to a given `--feature` value's own
Resolver-owned output paths, and to the Project Context/ownership-source/
Registry sources it reads, across one invocation's own multi-step
sequence. A concurrent second invocation of this Resolver against the
identical `--feature` value, or a concurrent human/tool edit to the same
live output paths outside this Resolver's own transactional commit, is
out of this feature's own scope (a future epic's own file-locking
concern, Non-goals) — it is exactly the class of interference the
crash-recovery scan and the `snapshot-generation-mismatch`/
`post-publication-generation-mismatch` Blocks exist to detect and fail
closed on, never to serialize or prevent by themselves.

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
            "required": ["facet", "declaration_index", "applied", "evaluations"],
            "properties": {
              "facet": { "type": "string", "minLength": 1 },
              "declaration_index": { "type": "integer", "minimum": 0 },
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
          "enum": ["disabled-legacy-invocation", "publication-journal-recovery",
                   "workflow-combination-invalid",
                   "project-context-validation-failed",
                   "affected-component-resolution-failed", "registry-validation-failed",
                   "contract-discovery-failed", "canonicalizer-invocation-failed",
                   "dependency-subprocess-failed", "dependency-output-malformed",
                   "dsl-warn-on-matched-capability", "lite-check-source-undefined",
                   "output-schema-validation-failed", "snapshot-generation-mismatch",
                   "artifact-publication-failed", "post-publication-generation-mismatch"]
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
enum carries all **sixteen** REQ-002 diagnostic-id values, listed here in
the identical order requirements.md's REQ-002 table itself now lists them
(Minor "Block count" correction, below — an earlier revision of this
schema and requirements.md's own table disagreed, seven table rows plus
one inline versus eight in this schema; this revision closes that gap by
giving requirements.md's REQ-002 table its own explicit row for every one
of the sixteen values below, none inline-only — fourteen carried forward
from the prior revision, plus `publication-journal-recovery` and
`post-publication-generation-mismatch`, both NEW, B1/B8): `disabled-legacy-
invocation`, `publication-journal-recovery` (B1, NEW), `workflow-
combination-invalid` (M3), `project-context-
validation-failed`, `affected-component-resolution-failed`, `registry-
validation-failed`, `contract-discovery-failed`, `canonicalizer-
invocation-failed`, `dependency-subprocess-failed` (B3), `dependency-
output-malformed` (B3), `dsl-warn-on-matched-capability` (B2, scope
widened), `lite-check-source-undefined`, `output-schema-validation-failed`
(B3, revised — see the "Resolver publication transactional bundle
contract" step-12 cross-reference, above, for the self-referential
no-write exception), `snapshot-generation-mismatch` (B8, revised — now
also fires on an `affected_components` set mismatch, not only a digest
mismatch; and at the step-6.5 mid-pipeline Registry recheck, ruling
C(1)), `artifact-publication-failed` (B1/B3, revised — journal-based
rollback, never a bare `unlink`), `post-publication-generation-mismatch`
(B8, NEW). This schema's own `capability_evaluations[]`/`trigger_
evaluations[]`/`conditional_facet_evaluations[]`/`evaluations[]` arrays
are intentionally left `minItems`-unconstrained at the JSON Schema level:
draft-07 cannot express "this array's own length equals an externally-
discovered Registry's own `capabilities[]` length" (or the current
invocation's own `affected_components[]` length, or a Capability's own
`conditional_facets[]` declaration count, B7) — the exact-set/
cardinality/bidirectional-consistency/provenance-binding rules Data Plan
(above, "B6 Evidence completeness") and this section, below ("B6
provenance binding", "B7 predicate-instance keying"), state are enforced
by `validate-resolver-evidence`'s own semantic checks, below, never by
this schema document alone. `conditional_facet_evaluations[].
declaration_index` (NEW, B7) is the 0-based position of the Registry
Capability's own `conditional_facets[]` array entry this evaluation
corresponds to — **not** a re-derivation of `facet`, and never assumed
unique by `facet` value: Epic A2's own Registry schema does not forbid
two entries sharing one `facet` name within a single Capability's own
declaration (`specs/epic-190-a2-capability-registry/requirements.md:
169-173`, no `uniqueItems`-style constraint on `conditional_facets[].
facet`), so this feature's own Evidence must be able to represent, and
this array's own cardinality must be bound to, the Capability's own
*declaration count*, not its own *distinct-facet-name count* — see "B7
predicate-instance keying", below, and Design Decisions, "facet-name
aggregation, predicate-instance keyed."

### `validate-resolver-evidence.{py,sh,ps1}` contract (REQ-004)

`validate-resolver-evidence.py --evidence <path> [--registry <capability-
registry.json path>] [--affected-components <comma-separated id list, or
a `--context <resolved-context-projection-path>`-derived equivalent>]
[--manifest <facet-manifest.yaml path>]` → exit 0 (conformant) or
non-zero with `resolver-evidence: <check-id>: <detail>` lines, one per
failed check — matching Epic A4's own three-validator diagnostic-line
convention exactly, but drawing `<check-id>` from **this script's own
closed enum, independent of `resolve-project-context`'s own REQ-002
enum** (Minor "diagnostic namespace" correction — an earlier revision of
this design left `validate-resolver-evidence`'s own check-ids
undifferentiated from REQ-002's Block taxonomy in places this feature's
own AC-014 could be misread to constrain; AC-014, requirements.md, is
corrected to scope its own `<check-id>`-drawn-only-from-REQ-002's-enum
claim to `resolve-project-context`'s own diagnostic lines alone).
`validate-resolver-evidence`'s **exact-set/cardinality inputs** are why
this validator, unlike Epic A4's three structural-only validators, takes
more than a bare `--evidence`/`--manifest` path: B6's own exact-set rules
(Data Plan, above) are checkable only against the Registry and
affected-component set a given Resolver Evidence instance itself claims
to be *about* — a purely structural, schema-only check cannot detect a
*missing* Capability entry, only a malformed *present* one.

**Provenance binding (B6, revised — closes "the validator trusts a
caller-supplied `--registry`/`--affected-components` as ground truth,
letting a self-consistent-but-wrong Evidence instance pass by supplying
matching, equally-wrong CLI arguments").** `--registry` and
`--affected-components` are now **optional overrides**, never the sole
source of exact-set ground truth:

- **Registry.** Default (`--registry` omitted): this validator
  self-resolves the Registry via ADR-0025's own discovery contract —
  the identical procedure `resolve-project-context` itself uses
  (Discovery contract, below) — never a caller-supplied path trusted
  blindly. Whether self-resolved or supplied as an explicit `--registry`
  override, this validator always computes `generate-registry-digest
  --whole` over the Registry file it ends up using and requires that
  computed digest to equal the Evidence's own `context_binding.
  registry_digest` field verbatim, **before** running any exact-set check
  against that Registry's own `capabilities[]` — a mismatch (self-resolved
  or override) → `registry-digest-unbound` (NEW check-id, below), fired
  first, since an exact-set check against a Registry that is not provably
  the one this Evidence instance itself claims to be about is meaningless.
  Only once this binding check passes does that Registry's own
  `capabilities[].id` set become `capability-set-mismatch`'s own ground
  truth. This closes the "point the validator at a different, smaller
  Registry" attack directly: a caller can no longer substitute an
  arbitrary Registry file independently of what this Evidence instance's
  own `registry_digest` cryptographically commits it to.
- **Affected components.** Default (`--affected-components`/`--context`
  omitted): this validator derives the affected-component set directly
  from the Evidence instance's own `context_binding.dependency_pointers[]`
  field (B9's own canonical `/components/<id>` RFC-6901-pointer encoding,
  one pointer per affected component, AC-044) — Evidence's **own**,
  independently-populated claim, populated by a different code path
  (provenance canonicalization, Data Plan "B9") than `capability_
  evaluations[].trigger_evaluations[]` is. When a co-located Facet
  Manifest is discoverable (`--manifest`, or, absent that flag, the
  sibling `facet-manifest.yaml` beside the `--evidence` path on a
  Full-track Evidence instance), this validator additionally reads that
  Manifest's own `context_binding.dependency_pointers[]` (Epic A4's own,
  independently-populated `contextBinding`, sourced from the *same*
  single invocation's own `resolve-component-paths` call, Epic A4
  `requirements.md:296-318`) and requires it to be **set-identical** to
  the Evidence instance's own — a mismatch between these two
  independently-populated, sibling-artifact claims → `affected-component-
  provenance-mismatch` (NEW check-id, below). An explicit
  `--affected-components`/`--context` override, if supplied, must ITSELF
  be set-identical to the `dependency_pointers[]`-derived set (the
  identical check-id fires on a divergence there too) — an override can
  *substitute for* the derivation (e.g. a Lite-track Evidence instance has
  no sibling Manifest to cross-check against, or an isolated unit-test
  fixture has no live `dependency_pointers[]` to read from a real
  invocation), but can never *contradict* it. This closes the "supply an
  arbitrary affected-component subset" attack the identical way the
  Registry binding above closes its own analogous gap: the ground truth
  is always something this Evidence instance (and, where available, its
  sibling Manifest) is itself cryptographically bound to via B9's own
  provenance fields, never a bare CLI list a caller could substitute
  independently.

**`validate-resolver-evidence`'s own closed check-id enum (now
**twelve** values, up from ten — two NEW, both B6):**

- `schema-invalid`: fails `contracts/resolver-evidence.schema.json`
  conformance, using the identical hand-rolled, stdlib-only draft-07
  subset Epic A4's own `validate-facet-manifest.py` already implements —
  no third-party `jsonschema` dependency (investigation.md INV-011).
- `registry-digest-unbound` (B6, NEW): the Registry this validator ends
  up using (self-resolved via ADR-0025, or the `--registry` override)
  produces a `generate-registry-digest --whole` value that does not equal
  the Evidence instance's own `context_binding.registry_digest` — checked
  **before** `capability-set-mismatch`, below, which depends on this
  check having already passed for its own ground truth to be meaningful.
- `capability-set-mismatch` (B6): the set of `capability_evaluations[].
  capability_id` values is not exactly the provenance-bound Registry's
  own `capabilities[].id` set (a missing Capability, an extra one, or a
  `capability_id` naming a Capability the Registry does not declare).
- `capability-evaluation-id-duplicate` (nested uniqueness, B6): the same
  `capability_id` appears more than once in `capability_evaluations[]`.
- `affected-component-provenance-mismatch` (B6, NEW): the
  `dependency_pointers[]`-derived affected-component set (Evidence's own,
  the co-located Manifest's own if present, and any `--affected-
  components`/`--context` override supplied) are not all set-identical
  to one another.
- `trigger-evaluation-set-mismatch` (B6): a `capability_evaluations[]`
  entry's own `trigger_evaluations[].component_id` set is not exactly the
  provenance-bound affected-component set (missing, extra, or foreign
  `component_id`), for **any** entry, matched or unmatched.
- `component-evaluation-id-duplicate` (nested uniqueness, B6): the same
  `component_id` appears more than once in one `trigger_evaluations[]`
  array, or in one `conditional_facet_evaluations[].evaluations[]` array.
- `matched-result-contradiction` (B6, bidirectional): `matched: true`
  with no `trigger_evaluations[].result: true` member, **or** `matched:
  false` with at least one `trigger_evaluations[].result: true` member —
  both directions checked, not only the first (an earlier revision of
  this validator, under the retired name `matched-without-evidence`,
  checked only the first direction).
- `conditional-facet-set-mismatch` (B6, **redefined**, B7 predicate-
  instance keying): a matched Capability's own `conditional_facet_
  evaluations[]` array is not exactly **positionally** (by
  `declaration_index`, 0-based, NEW field) identical in cardinality and
  per-position `facet` value to that Capability's own `conditional_
  facets[]` array, per the provenance-bound Registry — **not** a bare
  comparison of the *set of distinct `facet` names* (an earlier revision
  of this check compared sets of names, which cannot distinguish "this
  Capability declared `F` twice" from "this Capability declared `F`
  once," silently accepting a collapsed or duplicated Evidence instance
  for a Capability whose own `conditional_facets[]` legitimately declares
  the identical `facet` name more than once — Epic A2's own Registry
  schema does not forbid this within one Capability's own declaration,
  `specs/epic-190-a2-capability-registry/requirements.md:169-173`; see
  Design Decisions, "facet-name aggregation, predicate-instance keyed,"
  below). A missing index, an extra index, or an index whose own `facet`
  value does not match the Registry's own declaration at that same index
  → this check-id.
- `conditional-facet-evaluation-set-mismatch` (B6): a `conditional_facet_
  evaluations[]` entry's own `evaluations[].component_id` set is not
  exactly the provenance-bound affected-component set.
- `applied-result-contradiction` (B6, bidirectional, facet-level
  equivalent of `matched-result-contradiction`): `applied: true` with no
  `evaluations[].result: true` member, or `applied: false` with at least
  one `evaluations[].result: true` member, within one `conditional_facet_
  evaluations[]` entry.
- `array-not-stable-sorted`: `capability_evaluations[]` not sorted by
  `capability_id`, or `diagnostics[]` not sorted by `(id, detail)` (REQ-
  005/AC-024's own stable-sort mandate for this feature's new arrays,
  mirroring Epic A2/A4's own identically-named check).

This validator does not re-run any predicate evaluation itself — every
check above is a structural/set-membership/provenance-binding check
against the recorded evidence and the provenance-bound Registry/
affected-component inputs, never a semantic re-derivation of any
`result`/`evidence[]` value. Before reading `--evidence` (or any
`--manifest` sibling), this validator itself performs the reader-side
generation-consistency check the transactional bundle contract (above)
defines — a live `RESOLVER_PUBLICATION_IN_PROGRESS` journal naming the
path it is about to read fails this validator closed, never a silent read
of possibly-torn cross-file state — including, specifically, a live
journal naming the very `resolver-evidence.yaml` path this validator was
invoked against (AC-054). Discovery via ADR-0025, identical to
every other script in this feature and in Epic A2/A4 (investigation.md
INV-005/INV-011).

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
following the identical pattern) — this one procedure is reused,
unmodified, for **every** `contracts/*` artifact this feature's scripts
locate, this feature's own `resolver-evidence.schema.json` included
(AC-002). A release-gating `--check` mode on this
feature's own vendoring step (Deployment / CI Plan, below) compares
`contracts/resolver-evidence.schema.json`'s canonical sha256 against its
vendored `plugins/sdd-quality-loop/contracts/resolver-evidence.schema.
json` counterpart, mirroring Epic A2's and Epic A4's own identical check.
This same three-step procedure is also what the pre-publication snapshot
recheck (API / Contract Plan step 13, B8) re-runs against the Registry
path specifically — no second, divergent discovery algorithm for the
recheck.

## Test Strategy

New `tests/*.tests.sh`/`.tests.ps1` pairs and fixture data under
`tests/fixtures/capability-resolver/` (requirements.md REQ-006), designed
here at contract level (authored at Phase 2). Items 1-10 below are, in
aggregate, the full fixture matrix REQ-006's own items (a)-(h) require;
every fixture named in them lives under that one directory and is
independently invocable (AC-027):

1. `resolve-project-context-cli` — argument-validation matrix (AC-001):
   one fixture per required flag, deleted; `--source-rev` omission
   defaults to `HEAD`.
2. `resolve-project-context-block` — one fixture per REQ-002 diagnostic-id
   row (**sixteen** total — Minor "Block count" correction, below), each
   independently triggerable and each asserting (a) the correct exit code,
   (b) the correct diagnostic line — for `affected-component-resolution-
   failed`, `dependency-subprocess-failed`, and `dependency-output-
   malformed`, a fixture confirms the line is this feature's own canonical
   sentence, never the upstream dependency's own raw stderr text (M8,
   AC-014), (c) no `facet-manifest.yaml`/`capability-summary.yaml`/
   `project-context.resolved.json` written or changed (AC-011), (d) the
   correct Resolver Evidence content (AC-010..AC-012); a further shipped
   fixture in this same suite, `publication-staging-parent-symlink
   [feature-dir-symlinked]`, verifies ruling (a)'s non-diagnostic
   containment refusal — a `specs/<feature>` directory that is itself a
   symlink Blocks on the original diagnostic with NO Evidence record
   written (annotated 2026-09-03, human-approved, ruling (G)); plus one `workflow-
   combination-invalid` fixture per invalid row of decision document v2
   §6's own combination matrix (both named invalid rows — `lite` ×
   {`legacy-seven-layer`,`facet-hybrid`,`facet-native`}, and `full` ×
   `lite-three-file` — M3, AC-041, each Blocking at step 1 before any
   Registry/ownership/projection work begins); plus one
   `snapshot-generation-mismatch`
   fixture (B8, AC-040) that mutates the Registry (or Project Context, or
   ownership-source declarations) between this invocation's own step-4/5
   snapshot and its step-13 recheck (a test-harness-only hook simulates
   the TOCTOU window; the fixture's own assertion is that the mismatch
   Blocks and nothing from steps 3/10/11 reaches a live path); plus a
   **second** `snapshot-generation-mismatch` fixture (B8, NEW, AC-048;
   AC-040's own second half)
   that leaves every digest — including `ownership_digest` — byte-
   identical between step-4 and step-13, but mutates only the
   worktree/index/untracked state so that a re-invoked `resolve-
   component-paths` returns a *different* `affected_components` set at
   step 13 than it did at step 4, asserting the mismatch is caught by the
   `affected_components` set comparison alone (proving `ownership_digest`
   parity is not sufficient by itself, the exact gap adversarial review
   "B8" found); plus one `post-publication-generation-mismatch` fixture
   (B8, NEW, AC-049) that injects the identical class of mutation *after*
   step 13's own recheck has already passed but *before* step 14's own
   post-publication verification (Resolver publication transactional
   bundle contract, step 4) runs, asserting (i) the Block fires only
   after every rename in step 14's own commit sub-step has already
   succeeded, (ii) every one of those just-completed renames **of a
   publication artifact** is rolled
   back to its own PRE-transaction state via the journal before this
   invocation exits, **and** `resolver-evidence.yaml` is not rolled back
   but carries this Block's own record at exit — both halves required of
   the one fixture, per REQ-001 step (m)'s rollback-and-no-write scope
   rule and AC-012 (scoped 2026-08-27, human-approved, ruling D(2)),
   (iii) a fixture-only hook confirms the rollback
   used the journal's own `pre/<target-basename>` backups, never a bare
   `unlink`; plus one `artifact-publication-failed` fixture (B1/B3,
   revised) that denies write/rename permission on one of this
   invocation's own staged output paths after every earlier step already
   succeeded, asserting (i) the Block fires, (ii) if the journal had
   already been written before the injected failure, any already-
   completed rename **of a publication artifact** in that same commit
   sub-sequence is rolled back to
   its own PRE-transaction state via the journal — never
   `resolver-evidence.yaml`, which carries this Block's own record
   instead (REQ-001 step (m)'s rollback-and-no-write scope rule,
   AC-012/AC-039) — (**never** a bare
   `unlink` with no restore — B1's own "existing bytes destroyed with no
   restore" gap, closed), (iii) no live artifact this invocation was not
   already committed to writing survives partially written; plus one
   `publication-journal-recovery` fixture (B1, NEW, AC-047) that
   simulates a hard crash between two renames of a multi-target Full-track
   commit (test-harness-only hook: kill the process after the first
   rename, before the second) and asserts the **next** invocation's own
   crash-recovery scan, run before that next invocation's own step 1,
   converges every target back to its own PRE-transaction bytes (no mixed
   generation carried forward on this branch), then proceeds to complete
   its own,
   separate resolve normally; a companion fixture corrupts the journal's
   own recorded `pre/<target-basename>` backup (simulating an
   unrecoverable third state) and asserts the next invocation Blocks,
   `publication-journal-recovery`, before any Registry/ownership/
   Context-Projection work begins, with the live-state obligation stated
   per target rather than globally (amended 2026-08-27, human-approved,
   ruling D(2), matching AC-047/TEST-047's own amended wording): every
   interrupted target other than `resolver-evidence.yaml` byte-identical
   to its pre-invocation state — no partial rollback and no repair is
   attempted once the journal is declared unconvergeable, which is why
   this branch's mixed generation deliberately stands, unattended by any
   automatic repair, behind a fail-closed Block — and
   `resolver-evidence.yaml` itself carrying this invocation's own Block
   record for that diagnostic, written directly per REQ-001 step (m);
   plus the **abort-exception** fixture AC-056 names by name,
   `evaluate-predicate-failure-after-warn` — one `outcome: "warn"` node
   collected during the step-7 sweep, then the *next* `evaluate-
   predicate` call's own dependency failure aborting that same sweep with
   `dependency-subprocess-failed` — asserting the forwarded `severity:
   "warn"` entry appears alongside that different-id `severity: "block"`
   summary entry, with **no** same-id summary entry and no repeated
   `(id, detail)` pair (AC-056; Design Decisions, "`diagnostics[]`
   warn/block cardinality", below, fixes the rule this fixture locks);
   plus the two ruling-C fixtures (human-approved 2026-08-26):
   `registry-swapped-during-validation` (AC-057/TEST-057) — its
   `generate-registry-digest` stub overwrites the discovered Registry in
   place as a side effect of step 6's own dependency invocation, and the
   step-6.5 recheck must Block `snapshot-generation-mismatch` with an
   empty `capability_evaluations` array in the `resolver-evidence.yaml`
   that Block does write (AC-012), and no publication artifact
   (`facet-manifest.yaml`, `capability-summary.yaml`,
   `generated/project-context.resolved.json`) on any live path (scoped
   2026-08-27, human-approved, ruling D(2), matching AC-057/TEST-057's own
   amended wording) — and
   `affected-component-absent-from-context` (AC-058/TEST-058) — its
   `resolve-component-paths` stub returns a component id absent from the
   fixture's own Context Projection alongside one present-and-valid id,
   and step 7's entry check must Block `dependency-output-malformed`
   BEFORE any predicate evaluation, never a defaulted-empty-properties
   evaluation.
3. `resolve-project-context-match` — the full match/no-match/conditional/
   WARN fixture matrix (REQ-006 items a-d, expanded per M10 "metamorphic
   completeness" below): a two-affected-component fixture where only one
   component's properties satisfy a Capability's `trigger` (AC-006); a
   matched Capability with one applied and one N/A `conditional_facets[]`
   entry, the N/A entry's own `reason` naming every contributing
   Capability (B7); a WARN on an **unmatched** Capability's own `trigger`
   evaluation (Blocked, `dsl-warn-on-matched-capability`, per B2's widened
   scope — this exact fixture did **not** Block under the earlier,
   representative-branch-only revision of this design, and is the
   regression fixture that proves B2's fix); a WARN on a matched
   Capability's own **non-determining** affected-component branch
   (**also** now Blocked, B2 — under the earlier revision this branch was
   the accepted, non-Blocking case; there is no longer an accepted-WARN
   fixture anywhere in this suite, since B2 removed the only branch that
   was ever exempt); a same-`facet`-name-across-two-Capabilities fixture
   (B7) whose own `applied`/`evidence`/`reason` match the OR-aggregation
   rule (Design Decisions, "facet-name aggregation") exactly; a
   **same-Capability, same-`facet`-name, two-declaration** fixture (B7,
   NEW, AC-052) — a single Registry Capability whose own `conditional_
   facets[]` array declares the identical `facet` name at two different
   `declaration_index` positions with two *different* `when` predicates —
   asserting Resolver Evidence records **two** `conditional_facet_
   evaluations[]` entries for that Capability (one per `declaration_
   index`, never collapsed to one by `facet` name), and that the Facet
   Manifest's own single, facet-name-unique output entry aggregates both
   declaration indices' own contributions by the identical `(capability_
   id, declaration_index, component_id)`-keyed OR/concatenation rule the
   cross-Capability case uses (Design Decisions, "facet-name aggregation,
   predicate-instance keyed"); a **Context Projection byte-identity**
   fixture pair (AC-003) — the identical `project-context.yaml` fixture's
   own Context Projection computed once by hand per Epic A4's own REQ-003
   procedure and once by invoking the Resolver on the Full track —
   asserting the two are byte-identical (`source_sha256` and
   `projection_sha256` both matching), the Lite-track
   never-written half of that same criterion being covered by item 4's
   own track-exclusive output-set fixtures below; and a **Facet Manifest
   schema-conformance** fixture (AC-008) asserting the `facet-manifest.
   yaml` this Resolver actually writes validates via `validate-facet-
   manifest` (Epic A4) against `contracts/facet-manifest.schema.json`,
   for a representative multi-Capability, multi-affected-component input;
   and an **enforcement-byte-identity** fixture pair (AC-016) —
   two inputs identical except `workflow.capability_enforcement`
   (`advisory` vs. `required`) — asserting byte-identity across this
   invocation's own track-exclusive output set with the enforcement-
   derived fields excluded wherever they occur (Resolver Evidence's own
   `state`; `context_binding.full_context_revision` and
   `context_binding.projection_sha256` in every artifact whose schema
   carries them, which on the Full track means `facet-manifest.yaml` too;
   and, in `generated/project-context.resolved.json`, its `workflow`
   block and `source_sha256` — widened 2026-08-27, human-approved, ruling
   D(2), from a three-field list that made this fixture pair impossible
   to construct on the Full track), plus a
   non-vacuity assertion that those two digests genuinely **do** differ
   (Design Decisions, "`advisory` and `required` produce byte-identical
   output", below, fixes why they must). Every fixture pair in this suite
   is constructed so that, on the Lite track, no matched Capability's own
   `lite_policy.required_lite_checks` key is absent — the one branch that
   diverges by design between the two enforcement states, covered instead
   by items 2 and 4 (cross-epic addendum, Epic A6 adversarial
   verification finding B5).
4. `resolve-project-context-lite` — the Lite-track path, **narrowed and
   expanded by cross-epic addendum (Epic A6 adversarial verification
   finding B5)**: confirms `lite-check-source-undefined` fires for the
   current, real Registry shape (investigation.md INV-019) only under the
   **required-missing** state — a `required`-enforcement fixture whose
   Registry Capability declares `lite_policy.eligible: true` and whose
   `required_lite_checks` key is absent — proving the Block fires
   structurally, on that narrower conjunction, rather than by an
   accidental fixture gap; the otherwise-identical **advisory**-enforcement
   fixture is a companion, non-Blocking case (below). **No
   forward-compatibility fixture exercises a hypothetical Registry
   extension that supplies a resolvable `required_lite_checks` source**
   (B5 correction, removing the earlier revision's synthetic-Registry-
   extension fixture) — such a fixture's own Registry instance would not
   itself pass `validate-capability-registry` (Epic A2's own `lite_policy`
   sub-schema is `additionalProperties: false`, sub-keys `{eligible,
   upgrade_reasons}` only, and content-frozen, investigation.md
   INV-019/B5), so it never exercised a Registry state any real
   `validate-capability-registry`-passing input could ever reach — this is
   also why **required-present-empty** has no fixture in this suite: it is
   a documented, non-Blocking rule (API / Contract Plan step 10b,
   requirements.md REQ-002) but not yet a reachable real-Registry state,
   pending a future Epic A2 schema revision that adds the key itself; this
   suite instead adds two **track-exclusive output-set** fixtures (B4)
   that each confirm a successful (non-Blocked) Lite resolve writes
   exactly `capability-summary.yaml` + `resolver-evidence.yaml` and
   **never** `facet-manifest.yaml`/`project-context.resolved.json` — an
   **advisory-missing** fixture (a matched Capability whose key is absent,
   under `advisory` enforcement, contributing `[]`, reachable with any
   real Registry today) and the original **zero-match** fixture (zero
   matched Capabilities, e.g. the zero-affected-component Edge Case, M9,
   reachable under either enforcement state) — this remains an accurate,
   honestly-scoped set of fixtures against the current cross-epic state,
   not a fabricated forward-compatibility one.
5. `resolve-project-context-parity` — `.py`/`.sh`/`.ps1` byte-identical
   output across every fixture above, plus a repeated-invocation
   determinism proof (REQ-005/AC-022/AC-023); includes at least one
   Windows-style (`\`-separated) path argument, matching Epic A4's own
   parity-suite convention (Epic A4 `design.md`, "Diagnostic determinism
   contract"). The parity oracle (M8 correction) compares only this
   feature's own emitted lines/artifact bytes across runtimes — any
   dependency script's own raw stderr (never embedded in this feature's
   own `detail` fields, API / Contract Plan step 4, M8) is explicitly out
   of this suite's own comparison scope.
6. `resolve-project-context-discovery` — three fixtures (one per runtime)
   simulating a standalone-installed-plugin layout, for every `contracts/*`
   artifact this feature's scripts locate (Registry + its schema, Epic
   A4's three schemas, this feature's own `resolver-evidence.schema.
   json`) — matching Epic A2's own three-fixture discovery pattern
   (AC-028); the fixture-count identity is stated explicitly (Minor
   "discovery fixture count" correction, below) as the **direct product**
   of `{one installed-standalone-plugin layout case}` × `{three
   runtimes}` × `{one artifact set per runtime}` = three fixtures total,
   one per runtime, each exercising every artifact this feature's scripts
   locate within that one runtime's own invocation — never nine, and
   never ambiguous between "three total" and "three per runtime."
7. `resolver-evidence-schema` — `contracts/resolver-evidence.schema.json`
   existence/`$id`-convention/required-field-matrix fixtures, matching
   Epic A4's own `facet-manifest-schema` suite's own structure: the
   schema fixed verbatim above exists, is valid draft-07, and carries an
   `$id` following every other `contracts/*.schema.json`'s own convention
   (AC-017).
8. `validate-resolver-evidence` — one fixture per `validate-resolver-
   evidence` diagnostic-id row (AC-021, the **twelve**-value enum above,
   B6), including the two NEW provenance-binding rows: a
   `registry-digest-unbound` fixture (AC-050) supplies a `--registry`
   override pointing at a Registry file whose own `generate-registry-
   digest --whole` value does not equal the fixture Evidence's own
   `context_binding.registry_digest`, asserting the Block fires before
   any `capability-set-mismatch` check even runs, and a companion fixture
   confirms the *default* (no `--registry`) self-discovery path performs
   the identical binding check against the ADR-0025-discovered Registry;
   an `affected-component-provenance-mismatch` fixture (AC-051) pairs an
   Evidence instance with a co-located Facet Manifest whose own
   `dependency_pointers[]` names a different component set than the
   Evidence's own, asserting the Block fires without needing any
   `--affected-components` CLI argument at all, and a companion fixture
   supplies an explicit `--affected-components` override that contradicts
   both sibling artifacts' own `dependency_pointers[]`, asserting the
   identical check-id fires for the override case too.
9. `resolve-project-context-metamorphic` (new, M10) — the completeness/
   invariance suite an earlier revision of this design left unfixtured;
   sub-items (a), (b), (c) and (f) below are, in that order, AC-045's own
   four named locks:
   (a) all four true/false combinations of a 2-affected-component
   Feature's own `trigger` result (TT/TF/FT/FF), asserting `matched`
   exactly per the union-match rule in every case; (b) the identical
   fixture's own `affected_components[]` fed to the Resolver in each of
   its 2 possible orderings, asserting byte-identical output regardless
   (this invocation's own ascending-lexicographic evaluation order and
   stable-sort discipline make output order-invariant of input order —
   REQ-005); (c) a 3-affected-component fixture where more than one
   component's own evaluation is `true`, asserting the Capability is
   still recorded exactly once in `capabilities[]` (no duplication); (d)
   an `applied: false` `conditional_facets[]` fixture whose `reason`
   content is asserted verbatim against the exact template this feature's
   design fixes; (e) one fixture per WARN branch this feature's own
   evaluation model can produce — matched-capability-trigger-WARN,
   unmatched-capability-trigger-WARN, matched-capability-conditional-
   facet-WARN — each independently Blocking (B2); (f) a nested-array-
   completeness fixture asserting, for a multi-Capability/multi-component/
   multi-facet fixture, that every level of Resolver Evidence's own
   nesting (`capability_evaluations[]`, `trigger_evaluations[]`,
   `conditional_facet_evaluations[]`, `evaluations[]`) carries exactly the
   cardinality its own governing set requires (B6), asserted via
   `validate-resolver-evidence`'s own exact-set checks passing and an
   intentionally-corrupted (one entry deleted) copy of the same fixture
   failing the matching check-id; (g) a dependency-invocation-order spy
   fixture (OK-2 reinforcement) asserting this invocation's own subprocess
   call order is exactly canonicalize-sdd-yaml (Project Context pass) →
   canonicalize-sdd-yaml (Context Projection pass) → resolve-component-
   paths → Registry discovery → generate-registry-digest → evaluate-
   predicate (trigger fan-out) → evaluate-predicate (conditional-facet
   fan-out), and that a forced non-zero exit injected at each position in
   turn Blocks with that position's own correct diagnostic id and invokes
   no later-ordered subprocess at all.
10. `resolve-project-context-caller-contract` (new, M6) — a contract test
    against the **live** `plugins/sdd-bootstrap/skills/sdd-bootstrap-
    interviewer/SKILL.md` (Design Decisions, "caller insertion point",
    below, fixes the exact anchor): (a) an **anchor-fingerprint** drift
    check (M6, revised — AC-053, below, replacing an earlier revision's
    bare "heading text still exists verbatim" check, which could not
    detect the heading moving to a different position in the file while
    its own text stayed unchanged) recomputes, against the live file,
    (i) the sha256 of the fixed 11-line window `SKILL.md:54-64` (LF-
    normalized, this package's own recorded fingerprint is `sha256:
    d969fa163169ee5a9b5941600382b86b75929d6cd90d223dbe991e1dc234fb64`,
    Design Decisions "caller insertion point" gives the exact window
    bounds and recomputation procedure) and (ii) the `### Full-Profile
    Layer Interview` heading's own 1-based ordinal position among every
    `##`/`###`-level heading in the live file in document order (this
    package's own recorded value: `3`), failing loudly if either value no
    longer matches this package's own recorded citation — a heading-text-
    only regression fixture (moving the identical heading text to a
    different position in the file without changing its own immediate
    neighboring lines) is the fixture that proves this revision's own fix
    over the earlier, text-existence-only check; (b) a spy-harness fixture
    confirming the interviewer never invokes `resolve-project-context`'s
    own subprocess at all — **neither** while a Project Context is absent
    (REQ-007(a), event-identical to today's flow) **nor** while a present
    Context derives `disabled-legacy` (REQ-003); the second sub-case is a
    caller-side check on the derived state, distinct from and additional
    to AC-015's own narrower Resolver-side "spawns no further subprocess
    in this branch" check (AC-042); (c) a fixture confirming a REQ-002
    Block surfaces to the interview session (REQ-007(d)) rather than
    silently falling back; (d) a fixture confirming **exactly one**
    `resolve-project-context` invocation per capability interview phase
    run (REQ-007(b)) — never zero on a Context-present, non-`disabled-
    legacy` run, and never a second invocation later in that same run.
    These four sub-items are AC-046's own four lettered locks under a
    different lettering: this item's (b) is AC-046(a), this item's (d) is
    AC-046(b), this item's (c) is AC-046(c), and this item's (a) is
    AC-046(d) (AC-046). This test suite is itself authored once the
    capability interview phase is actually implemented (a future task,
    Non-goals) — its own fixture-level contract is fixed here, at design
    time, so that implementation task has no remaining insertion-point
    ambiguity to resolve (M6).

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

**Facet-name aggregation for `conditional_facets[]` (Facet Manifest, Epic
A4's own field), predicate-instance keyed (B7, revised — closes "the
aggregation unit was a Capability set, `{C_1, ..., C_n}`, which cannot
represent two same-named-facet declarations *within one Capability*"):
OR-aggregation, evidence concatenation, contributing-predicate-instance-
enumerated `reason`, all keyed by `(capability_id, declaration_index)`
"predicate instance" — not by bare `capability_id`.** This decision
*replaces* an earlier revision's "representative-evidence selection"
decision (adversarial review "M1/M2 representative selection removed"
found that decision unsound in its own right — a "representative" branch
concept applied inconsistently between facet-level and trigger-level
Evidence; Design Decisions below no longer defines any representative-
selection rule of any kind, trigger or facet), and *generalizes* an
earlier revision of **this** decision, which keyed contribution by bare
`capability_id` and could therefore only represent *cross*-Capability
same-facet-name collisions, not a *single* Capability declaring the
identical `facet` name more than once in its own `conditional_facets[]`
array (adversarial review "B7 same-Capability duplicate," a gap the
earlier revision left open even after M1/M2's own fix). Epic A2's own
Registry schema neither requires `conditional_facets[].facet` uniqueness
*within* one Capability's own declaration, nor forbids two *different*
Capabilities from declaring a `conditional_facets[]` entry under the
identical `facet` name (`specs/epic-190-a2-capability-registry/
requirements.md:169-173`, no `uniqueItems`-style constraint on `facet`)
— so both collision shapes are legitimate Registry inputs this feature
must handle identically, not two different rules. **A future Epic A2
addendum candidate**: A2's own spec is silent on whether same-Capability,
same-`facet`-name duplicate declarations are an intentionally-supported
authoring pattern or an oversight; this package names the gap (Risks,
below, Cross-Layer Dependencies, and this package's own final report)
without acting on Epic A2's own content-frozen files (this task's own
hard boundary) — this feature's own handling below is correct and
complete regardless of which way that future prose lands, since it
already treats every declaration as its own independent predicate
instance. Epic A4's own Facet Manifest schema *does* require `conditional_
facets[].facet` Manifest-wide uniqueness (Data Plan, "B7", above). This
design resolves the resulting many-to-one mapping as follows, per
distinct `facet` name `F`, across the set of **predicate instances**
`{(C_1, i_1), ..., (C_n, i_n)}` — every `(capability_id, declaration_
index)` pair, Registry-wide, across every matched Capability, whose own
`conditional_facets[declaration_index].facet == F` — a set of exactly one
predicate instance is the common case and degenerates to this rule's own
base case unchanged; two predicate instances sharing one `capability_id`
(the same-Capability-duplicate case, above) are simply two distinct
members of this same set, handled by the identical rule as two predicate
instances from two different Capabilities. The **cross**-Capability
instance of the three bullets below is AC-043; the **same**-Capability
instance is AC-052, and they are deliberately the same rule:

- **`applied`**: `true` iff **any** predicate instance `(C_i, i_i)`'s own
  per-component evaluation of its own `F`-named `when` predicate (step 8's
  own per-Capability, per-declaration union-match result, API / Contract
  Plan) is `true` for **any** affected component — an OR of ORs, matching
  this feature's own union-match soundness argument (immediately above)
  applied one level higher: no contributing predicate instance's own
  genuine match can be soundly discarded merely because a *different*
  contributing predicate instance's own evaluation of the same-named
  facet happened to be `false` — regardless of whether that other
  instance belongs to the same Capability or a different one.
- **`evidence`**: the **concatenation** of every `(C_i, i_i, component)`
  triple's own evaluation-node array that contributed to this
  determination, ordered first by `capability_id` ascending, then by
  `declaration_index` ascending **within** that `capability_id`, then by
  `component_id` ascending within each predicate instance (a stable,
  fully deterministic total order, REQ-005) — **never** a single
  representative node array, and never collapsed to one entry per
  `capability_id` when that Capability itself contributes more than one
  predicate instance. This remains a structurally valid
  `#/definitions/evidenceNode` array under Epic A4's own schema (an array
  of evidence nodes, of whatever length, Data Plan "B7", above) even
  though it is now several `evaluate-predicate` invocations' own output
  concatenated together rather than one invocation's own verbatim output
  — **Epic A4's own prose** ("the whole array is copied verbatim from the
  evaluator's own output", Epic A4 `design.md:413-422`) describes only
  the single-contributing-invocation case and does not anticipate this
  multi-predicate-instance concatenation; this design flags that prose
  (not the schema itself, which this concatenation satisfies unmodified)
  as needing a future A4 addendum (Risks, below, and this package's own
  final report) — this package does not edit A4's own files (this task's
  own hard boundary).
- **`reason`** (present iff `applied: false`, matching Epic A4's own
  optional-`reason`-only-on-N/A field shape): a fixed template naming
  every contributing predicate instance as a `capability_id[declaration_
  index]` pair, e.g. `"no contributing predicate instance's conditional
  facet matched any affected component (contributing: cap-a[0],
  cap-a[2], cap-b[1])"`, with the contributing-predicate-instance list
  itself stable-sorted by the identical `(capability_id, declaration_
  index)` ascending order `evidence` uses — so a human reading an N/A
  facet always sees exactly which *declarations* (not merely which
  Capabilities) were even in play, including distinguishing two
  same-Capability declarations from one another.

**Resolver Evidence's own `conditional_facet_evaluations[]` cardinality/
identity is `declaration_index`-keyed, never `facet`-name-keyed (B7,
Data Plan and `contracts/resolver-evidence.schema.json`, above give the
schema; `validate-resolver-evidence`'s own `conditional-facet-set-
mismatch` check, above, gives the validator-side enforcement).** A
matched Capability's own Resolver Evidence entry carries **exactly** one
`conditional_facet_evaluations[]` element per that Capability's own
`conditional_facets[]` array *entry* — by array position (`declaration_
index`), not by distinct `facet` value — so a Capability declaring the
identical `facet` name twice produces **two** Evidence entries, sharing
`facet` but carrying `declaration_index: 0` and `declaration_index: 1`
respectively, each independently `applied`/`evidence`-populated from its
own `when` predicate's own evaluation. This is what makes the
Facet-Manifest-level aggregation above soundly able to treat "this
Capability's own declaration 0" and "this Capability's own declaration 2"
as two independent predicate instances: Resolver Evidence itself never
merges them first.

**Any-branch WARN-Block scope (widened from an earlier revision's
representative-branch-only scope, B2).** `dsl-warn-on-matched-capability`
now Blocks on an `outcome: "warn"` node found **anywhere** in **any**
evaluation this invocation performs in steps 7-8 (API / Contract Plan) —
every Registry Capability's own `trigger_evaluations[]`, matched or
unmatched, and every matched Capability's own `conditional_facet_
evaluations[].evaluations[]` — never only a single "representative"
branch. The earlier, representative-branch-only revision existed *because*
of the now-removed representative-evidence-selection decision above (a
WARN only mattered, that revision reasoned, on the one branch the Facet
Manifest actually embedded) — with that concept removed (B7's own
evidence-concatenation rule embeds **every** contributing branch, not one
representative), the WARN-Block condition's own scope naturally widens to
match: since **every** evaluated branch can now influence the aggregated
`applied`/`matched` outcome the Facet Manifest exposes (union-match, both
levels), a WARN on **any** branch is a genuine "the field allowlist
expects Project-Context data the current Context does not (yet) provide,
for an evaluation that could determine a real, consequential outcome" —
including an unmatched Capability's own trigger WARN, which an earlier
revision never inspected at all (adversarial review's own worked example:
a WARN-producing missing-path evaluation collapsing to `false` on a
Capability that consequently reads as cleanly "unmatched," silently
under-resolving the Feature).

**`diagnostics[]` warn/block cardinality, and its evaluation-abort
exception (REQ-004/AC-056 — amended 2026-08-24, human-approved).** This
decision states, at design level, an amendment that until this revision
of `design.md` existed only in `requirements.md`'s REQ-004/AC-056 and
`acceptance-tests.md`'s own AC-056/TEST-056 row. That row's exception
clause, verbatim:

> Exception (amended 2026-08-24, human-approved, mirroring REQ-004's
> amended sentence): `severity: "warn"` entries already collected before
> an evaluation abort — a REQ-002 Block raised from within this
> invocation's own single steps (f)–(g) evaluation sweep before step (h),
> the identical sweep that produced the warns ("jointly caused") —
> lawfully appear alongside that abort's own **different-id**
> `severity: "block"` summary entry with no same-id summary entry; an
> abort-exception fixture (`tests/resolve-project-context-block.tests.
> sh`/`.ps1`, `evaluate-predicate-failure-after-warn`) locks exactly that
> shape.

requirements.md's REQ-001 steps (f)/(g)/(h) are this document's own API /
Contract Plan steps 7/8 and step 9 respectively. Two shapes follow:

- **Ordinary shape (no abort).** This invocation records one
  `diagnostics[]` entry with `severity: "warn"` and id `dsl-warn-on-
  matched-capability` per **individual** `outcome: "warn"` node
  encountered anywhere in steps 7-8 — each such entry's own `detail`
  naming that one node's own `capability_id`/`component_id`/
  (`declaration_index`, only for a `conditional_facets[].when` node)
  location, so no two `severity: "warn"` entries ever share a `detail` —
  **plus exactly one** additional entry carrying the identical id with
  `severity: "block"`, whose own `detail` is this feature's own fixed
  summary sentence, emitted by step 9's any-branch WARN check
  immediately above. The count scales 1:1 with node count plus that one
  summary entry: never fewer warn entries than warn nodes, never a
  second summary entry, and never a repeated `(id, detail)` pair
  (AC-024's own stable-sort/uniqueness rule for this array). Every other
  id in REQ-002's sixteen-value enum appears **at most once**, always
  with `severity: "block"`; no id other than `dsl-warn-on-matched-
  capability` ever carries `severity: "warn"` at all.
- **Abort exception.** A REQ-002 Block raised from *within* the steps 7-8
  sweep itself — `registry-validation-failed`, `dependency-subprocess-
  failed`, or `dependency-output-malformed` at an `evaluate-predicate`
  call (API / Contract Plan steps 7 and 8) — ends that sweep before step
  9 ever runs, so step 9's own same-id `severity: "block"` summary entry
  is never produced. The `severity: "warn"` entries that same sweep had
  **already** collected are not discarded: they are forwarded into that
  Block's own Resolver Evidence record, where they lawfully stand
  alongside the abort's own **different-id** `severity: "block"` entry,
  with **no same-id summary entry** — this invocation did not block
  *because of* the warn nodes, but the warns and the abort were jointly
  caused by that one sweep, and REQ-004's own "record every diagnostic-
  worthy condition this invocation encountered" mandate requires them
  recorded rather than dropped. "Jointly caused" is scoped exactly to
  that single steps-7-8 sweep: a warn entry is never carried over from
  any other invocation, any other sweep, or any other source.

**Staged generation, journaled transactional commit (B1, revised — no
upstream rule fixed the staging half of this; Epic A1's own already-fixed
multi-target transactional bundle contract fixes the commit half,
applied isomorphically).** Every artifact this invocation may write
(Context Projection, Facet Manifest **or** Capability Summary per the
track branch immediately below, Resolver Evidence) is assembled and
schema-validated in memory (API / Contract Plan steps 3/10/11/12) before
any of them is written to a live path — this staging half is unchanged
from an earlier revision's own fix. The earlier revision's own **commit**
half — a bare per-file `temp-file + fsync + rename`, with an in-process,
best-effort `unlink` of an already-completed rename as its only failure
response — is what this revision replaces: step 14's own commit is now
the full journaled, multi-target transaction (Prepare/Journal/Commit/
Post-publication-verification/Complete) the "Resolver publication
transactional bundle contract" subsection, API / Contract Plan above,
defines in full — never repeated here — closing two gaps the earlier
revision's own bare-rename commit left standing: (1) a crash **between**
two renames of a multi-target batch could leave a mixed generation
standing with no recovery path, and (2) an in-process write/rename
failure's own `unlink`-based rollback destroyed pre-existing live bytes
with no restore, on a Feature this Resolver had already published for
once before (adversarial review "B1 atomicity", both points). This
replaces an earlier-still revision's incremental-write ordering (Context
Projection written at roughly the procedure's own step 3, Facet Manifest
at roughly step 10, *before* a later step's own Block condition — e.g.
`lite-check-source-undefined`, knowable only after Facet-Manifest-
equivalent assembly work — could be known), which let a Blocked
invocation leave an already-live Context Projection or Facet Manifest
behind, violating AC-011's own "never a partial artifact" rule. A Block
reached only **after** this invocation has already staged the Context
Projection and/or the Facet Manifest/Capability Summary in memory —
`lite-check-source-undefined` (step 10b), `output-schema-validation-
failed` (step 12), `snapshot-generation-mismatch` (steps 6.5 and 13,
ruling C(1)) — therefore
still leaves no earlier-staged **publication artifact** at any live path
at all — never `resolver-evidence.yaml`, which is itself staged earlier
and IS written on each of those Blocks per AC-012 — except
`output-schema-validation-failed`'s Evidence-itself-fails sub-case
(AC-055(a)), one of AC-012's two named diagnostic-id exceptions — a
count bounded by rulings (a)/(A)/(B) per requirements.md's own Ruling
Annotations rule: ruling (a) (2026-08-28) adds a third, NON-diagnostic
no-write condition, the Evidence-target containment refusal (amended here
2026-09-03, human-approved, ruling (G)) — which writes nothing at all,
so the fixture for that id here is AC-055(b)'s — (REQ-001 step (m)'s
rollback-and-no-write scope rule; scoped 2026-08-27, human-approved,
ruling D(2), matching AC-038/TEST-038's own amended wording); this
staged-generation/journaled-publication lock is additive to AC-011's own
per-path statement over the same three artifacts, differing in that it
holds for Blocks reached only after staging rather than for Blocks
generally (AC-038).

**Track-exclusive publication set (B4, Epic A4's own already-fixed
contract, this feature's own processing-order consequence of it).** The
track branch (API / Contract Plan step 10) is decided, and every
subsequent artifact staged accordingly, **before** any publication step
runs: a Full-track resolve's own output set is `{facet-manifest.yaml,
project-context.resolved.json, resolver-evidence.yaml}`; a Lite-track
resolve's own output set is `{capability-summary.yaml, resolver-
evidence.yaml}` — **never** both a Facet Manifest and a Capability
Summary in the same invocation, and never a Context Projection published
on the Lite track (Context Projection is still **computed** internally on
every track, since matched-Capability evaluation needs it regardless of
track, but only **published** to `generated/project-context.resolved.
json` on the Full track). This corrects an earlier revision that
assembled a Full-track-shaped Facet Manifest unconditionally, then
additionally staged a Capability Summary on the Lite track — producing
both outputs on a Lite resolve, contradicting Epic A4's own track-
exclusive Capability Summary contract (`specs/epic-192-a4-facet-manifest/
requirements.md:1214-1217`, investigation.md INV-004).

**`advisory` and `required` produce byte-identical output, with a named,
closed set of enforcement-derived exceptions (REQ-003/AC-016 — amended
2026-08-24, widened 2026-08-27, both human-approved).** This decision
states, at design level, an amendment
that until this revision of `design.md` existed only in
`requirements.md`'s REQ-003/AC-016 and `acceptance-tests.md`'s own
AC-016/TEST-016 row. That row, in substance:

> a fixture pair identical except `workflow.capability_enforcement`
> (`advisory` vs. `required`) produces byte-identical output across this
> invocation's own track-exclusive output set; only the
> enforcement-derived fields REQ-003/AC-016 enumerate differ, wherever
> they occur in that set — Resolver Evidence's own `state`; the
> `context_binding` digests `full_context_revision`/`projection_sha256`
> in **every** artifact whose schema carries them, which on the Full
> track means `facet-manifest.yaml` as well as Resolver Evidence; and,
> in `generated/project-context.resolved.json`, its `workflow` block and
> `source_sha256`.

The 2026-08-24 amendment scoped those digest exceptions to "Resolver
Evidence's own" copies, which left the identical impossibility asserted
of the two sibling Full-track artifacts and made the Full-track half of
AC-016 unsatisfiable; attempt 8's two spec reviewers found that
independently. Ruling D(2) widened the set on 2026-08-27. The widened
scope is derivable from investigation.md INV-004's own schema field lists
and adds no behaviour, and the **Lite track is untouched**, since
`capability-summary.yaml` carries no `context_binding` at all.

Three consequences for this design, none of them previously stated in
this document:

1. **No assembly step branches on `capability_enforcement`, with step 10b
   the one named exception.** (Scoped 2026-08-27, human-approved, ruling
   D(2): step 10b is itself an assembly step and does branch on
   `capability_enforcement` — under `required` an absent matched-Capability
   `lite_policy.required_lite_checks` key raises the
   `lite-check-source-undefined` Block, under `advisory` it contributes
   `[]` — so the unqualified claim, read literally, would erase a required
   fail-closed rule. AC-016's fixture-domain exclusion limits what the
   byte-identity test covers but does not repair this global
   implementation statement, which is why it is scoped here instead.)
   `workflow.capability_enforcement` is read exactly once (API / Contract
   Plan step 1) and recorded in Resolver Evidence's own `state` field for
   downstream auditability. Steps 3 and 7-11 **other than step 10b** are
   the identical code path
   under either value: the Context Projection, the per-Capability and
   per-conditional-facet evaluation sweep, the track branch, and the
   Facet Manifest/Capability Summary/Resolver Evidence assembly all
   consume the value only as an opaque `state` string. Step 10b is the
   one exception this item names above and it genuinely branches
   (corrected 2026-08-27, human-approved, ruling D(2): the range "3 and
   7-11" contains 10b, so the unqualified sentence re-erased the
   fail-closed exception the item's own heading had just carved out).
   This invocation's
   own track-exclusive output set (Design Decisions, "track-exclusive
   publication set", above) is therefore byte-identical across an
   otherwise-identical `advisory`/`required` fixture pair, except for the
   fields item 2 names — and, for step 10b, only within AC-016's own
   fixture domain, which excludes the absent-`required_lite_checks`
   branch by construction.
2. **`full_context_revision` and `projection_sha256` must differ, and
   are the only digest fields that may.** `context_binding.full_context_
   revision` is step 2's `source_sha256` over the canonical Project
   Context text, and `context_binding.projection_sha256` is step 3's
   digest over the canonical Context Projection text, which copies
   `workflow` verbatim (Data Plan, "Context Projection read set").
   `workflow.capability_enforcement` is inside both preimages, so both
   digests **structurally encode** it: an implementation in which they
   did not differ across such a pair would be incorrect, not more
   deterministic. The same argument reaches every artifact carrying those
   digests, not only Resolver Evidence: on the Full track
   `facet-manifest.yaml`'s own `context_binding` carries both (Data Plan
   "B9"; investigation.md INV-004), and
   `generated/project-context.resolved.json` **is** the canonical
   Projection text whose `workflow` block is copied verbatim, so it
   differs in that block and in its own `source_sha256`. `state`, those
   two digests **wherever they occur**, and the Projection's `workflow`
   and `source_sha256` together form the **complete and
   closed** exception set — every other byte of every artifact in the
   set, `registry_digest`/`ownership_digest`/`dependency_pointers[]`/
   `resolver.version`/`resolver.rule_set_revision`/`capability_
   evaluations[]`/`diagnostics[]` included, is identical across the pair.
   On the Lite track the set reduces to `state` plus Resolver Evidence's
   two digests exactly as before, since `capability-summary.yaml` carries
   no `context_binding` (widened 2026-08-27, human-approved, ruling
   D(2)).
3. **One behavioural divergence is excluded from this criterion's own
   scope.** REQ-002's `lite-check-source-undefined`, as narrowed by the
   cross-epic addendum (Epic A6 adversarial verification finding B5, API
   / Contract Plan step 10b, above), is itself keyed to
   `capability_enforcement == required`. A Lite-track pair that is
   otherwise identical **and** has a matched Capability's `lite_policy.
   required_lite_checks` key absent therefore diverges by design — the
   `required` member Blocks while the `advisory` member resolves,
   contributing `[]`. That pair is covered by AC-009/AC-010's own
   three-non-Blocking-plus-one-Blocking matrix, never by this criterion;
   Test Strategy item 3's own `advisory`/`required` fixture pairs are
   accordingly constructed so no matched Capability's key is absent on
   the Lite track.

**`context_binding.dependency_pointers[]`/`resolver.version`/`resolver.
rule_set_revision` canonicalization (B9, no upstream rule fixed this) —
full derivation rules stated once, in Data Plan above ("B9"), not
repeated here.**

**Caller insertion point for `sdd-bootstrap-interviewer`'s capability
interview phase (M6, resolving OQ-003 to a concrete, file:line-cited
anchor).** The live `plugins/sdd-bootstrap/skills/sdd-bootstrap-
interviewer/SKILL.md` (read directly, this worktree, at this package's own
design-authoring time) has no "track detection" step named as such, but
its own existing flow already branches on track by the point its `###
Full-Profile Layer Interview` heading (`SKILL.md:60`) is reached — that
section's own first sentence ("For non-LITE work, use `references/
interview-question-bank.md`...") and its own closing line ("LITE excludes
this section and produces no layer documents", `SKILL.md:92`) both
presuppose the track is already known by that point, sourced today from
`AGENTS.md`'s `spec_profile` marker (the same source the file's own
Specification/Implementation Policy Review Gates already read,
`SKILL.md:147,159`). The capability interview phase's own insertion point
is therefore **immediately before `SKILL.md:60`'s `### Full-Profile Layer
Interview` heading** — after `## Intake And Investigation`'s own step 8
(`SKILL.md:58`, the last numbered step before that heading) and before any
Facet-dependent layer generation the following section performs (REQ-007's
own "after track detection, before any Facet-dependent layer is
generated" ordering, requirements.md). A new `### Capability Interview
Phase` subsection, inserted at that exact point, is where a future
implementation task's own Resolver invocation (REQ-001, once) and
Capability-relevant-unknowns-only interviewing (REQ-007(c)) belong. This
insertion point is a **design-time citation**, not an edit — this
package's own commits never touch `plugins/**` (this task's own hard
boundary, Non-goals) — and Test Strategy item 10, above, fixes a drift
check against this exact anchor text so a future, unrelated edit to
`SKILL.md` cannot silently invalidate this citation without that check
failing first.

**The capability interview phase's own interviewing rules, Context-absent
behaviour, and on-Block behaviour (REQ-007(a)/(c)/(d)).** The insertion
point above fixes *where* the phase goes; the three rules below fix *how
it behaves* once inserted. All three are documented here only — this
package edits no file under `plugins/**` (Constraint Compliance, below).

- **Question budget, Open-Questions persistence, resumability
  (AC-029).** The phase asks the interviewer's own questions only for
  Capability-relevant unknowns this Resolver's own output could not
  itself determine, under decision document v2 §18.4's own rule set,
  cited directly and adopted verbatim: 「質問は既知情報を再質問しない /
  適用 Capability だけ / 1 pass 最大 15 問 / 未解決は Open Questions 保存
  / 再開可能」 (decision document v2 §18.4). In this design's own terms:
  never re-ask information already known to the session or already
  determined by the Resolver's own output; ask only about Capabilities
  that actually apply to this Feature (the matched set, API / Contract
  Plan step 7); ask **at most 15 questions in any one pass**; **persist
  every still-unresolved item to the session's own Open Questions**
  rather than blocking the pass on it; and make the phase **resumable**,
  a later pass continuing from those persisted Open Questions rather
  than restarting the interview from the beginning. This design narrows
  none of the five and extends none of them.
- **Context-absent behaviour (AC-030).** When no Project Context is
  present, the capability interview phase is **not reachable at all** —
  no step of the contract above executes, and no `resolve-project-
  context` process is spawned (AC-042, above, is the spy-harness lock on
  exactly this). The existing bootstrap flow proceeds exactly as it does
  today: **event-identical** to pre-integration behaviour, the condition
  decision document v2 §4.3's own Orchestration Compatibility Test
  states and issue #193's own Done condition repeats
  (「interviewer 統合後も既存 bootstrap フロー（Context 不在時）が
  event-identical であるテスト」). Integrating this phase adds no event,
  no prompt, and no subprocess to that flow.
- **On-Block behaviour (AC-031).** On any REQ-002 Block, the caller
  surfaces this Resolver's own `capability-resolver: <check-id>:
  <detail>` diagnostic line to the interview session and stops there; it
  **never** silently degrades to a non-Capability-aware flow, and never
  substitutes a Capability-less default for the resolution it failed to
  obtain. This is decision document v2 §7's own fail-closed principle
  for a 非対応 runtime — 「legacy mode へ黙ってフォールバックしてはならない」
  — applied by the same "never silently degrade" logic to a Resolver
  Block rather than to a missing-runtime condition specifically. It is
  the caller-side counterpart of this design's own Resolver-side
  fail-closed posture (Security Boundaries, below).

**Anchor fingerprint (M6, revised — AC-053, replacing the earlier
revision's "heading text still exists verbatim" check with a
position-sensitive one).** A bare "does this heading text still exist
somewhere in the file" check cannot detect the heading *moving* — a
future, unrelated `SKILL.md` edit could relocate `### Full-Profile Layer
Interview` to a different position in the document (e.g. reordering
sections) while leaving its own literal text untouched, and the earlier
check would report no drift even though this package's own "immediately
before this heading" insertion-point citation would now be wrong. This
revision instead defines and records two independent, recomputable
signals, both taken against the live `SKILL.md` at this package's own
design-authoring time (this worktree, commit `c682f09587432e566dba652a
243cda893c3ff5b1`):

- **Anchor window fingerprint**: the sha256 of `SKILL.md`'s own literal
  lines 54-64 (inclusive) — the six lines immediately preceding the `###
  Full-Profile Layer Interview` heading, including its own preceding
  blank line (`## Intake And Investigation`'s own step 8, `SKILL.md:
  54-58`, plus the blank line at `SKILL.md:59`), through the four lines
  immediately following it, including its own following blank line
  (`SKILL.md:60-64`) — joined by a single `\n` between lines (LF-
  normalized; no other content transformation, so this is a literal
  transcription check, not a canonicalization), UTF-8 encoded. This
  package's own recorded value: `sha256:d969fa163169ee5a9b5941600382b86b
  75929d6cd90d223dbe991e1dc234fb64`. A future, unrelated edit to any line
  within this window — including the heading's own text, or either
  neighboring paragraph's own wording — changes this fingerprint,
  detecting drift a bare "the heading text still exists" check would
  miss (a content change *inside* the window that leaves the heading
  string itself untouched).
- **Section order index**: the 1-based ordinal position of the `###
  Full-Profile Layer Interview` heading among every `##`/`###`-level
  Markdown heading in `SKILL.md`, in document order. This package's own
  recorded value: `3` (1. `## Invocation`, `SKILL.md:13`; 2. `##
  Intake And Investigation`, `SKILL.md:29`; 3. `### Full-Profile Layer
  Interview`, `SKILL.md:60`). A future, unrelated edit that *relocates*
  the heading — even one that, by coincidence, leaves this package's own
  11-line window fingerprint unchanged (e.g. an edit far enough away that
  the immediate neighbors are undisturbed but an intervening heading is
  inserted or removed elsewhere in the document) — changes this index,
  the second, independent drift signal.

Test Strategy item 10's own drift check (above) recomputes both signals
against the live file and fails loudly if either no longer matches this
package's own recorded value, superseding the earlier revision's
existence-only check. **Update procedure (for a future, *intentional*
`SKILL.md` revision — e.g. the future implementation task that actually
inserts the `### Capability Interview Phase` subsection this insertion
point names):** that same commit's own diff is required to update this
package's own recorded fingerprint/index citation, in this same
paragraph, in the identical commit — never a follow-up commit — mirroring
Epic A4's own `compare-facet-manifest-staleness` discipline that a digest
and the content it describes must move together (Epic A4 `design.md`,
Test Strategy). The drift-check fixture (AC-053) is itself the
implementer's own signal to do so: it fails the moment `SKILL.md` changes
without this citation changing with it, converting a silent staleness
risk into a build-time (or spec-review-time) failure.

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
- REQ-002's own diagnostic-id enum is closed at **sixteen** values
  (API / Contract Plan, above; requirements.md REQ-002; fourteen carried
  forward, plus `publication-journal-recovery` and `post-publication-
  generation-mismatch`, both NEW, B1/B8) — no code path in this feature's
  own scripts emits a `diagnostics[].id`/exit-1 condition outside that
  enum; `validate-resolver-evidence`'s own, independent check-id enum
  (`validate-resolver-evidence` contract, above) is closed at **twelve**
  values (ten carried forward, plus `registry-digest-unbound` and
  `affected-component-provenance-mismatch`, both NEW, B6), and the two
  enums never share a member (Minor "diagnostic namespace" correction).

## Security Boundaries

- This feature's Resolver never reads a credential, never contacts a
  network endpoint, never invokes a Provider API, and **never reads the
  clock** — no `datetime.now()`/`time.time()`-derived value anywhere in
  its own orchestration logic, and no environment-variable-derived
  nondeterminism beyond the fixed discovery-contract fallback ADR-0025
  itself specifies (REQ-005) — matching ADR-0020's
  own DSL-layer Provider-neutrality boundary, extended by this feature's
  REQ-005 to its own orchestration layer (requirements.md Security
  Boundaries).
- **The no-clock/no-network/no-Provider-API guarantee immediately above
  is checkable, not merely asserted (AC-025).** A repository-wide,
  grep-based self-check over this feature's own Resolver-owned scripts —
  `plugins/sdd-quality-loop/scripts/resolve-project-context.{py,sh,ps1}`
  and `plugins/sdd-quality-loop/scripts/validate-resolver-evidence.
  {py,sh,ps1}` — confirms none of them calls `datetime.now()`,
  `time.time()`, any network primitive, or any provider-API client.
  Epic A2's own `evaluate-predicate` DSL evaluator is explicitly **out
  of scope** for this check: its purity is ADR-0020 item 6's own
  already-fixed guarantee, owned by Epic A2, and this feature neither
  re-verifies nor re-states it (requirements.md AC-025's own carve-out).
- **The approval-surface non-participation guarantee is checkable too,
  by the same means (AC-059, NEW 2026-08-28, human-approved, ruling E).**
  `requirements.md`'s Security Boundaries bullet 2, and the `B6`
  boundary in `security-spec.md`, both state that the Resolver never
  writes to any `*.approval.json` sidecar, any `sdd/.approved-context/`
  anchor, or `guard-invariants.json` itself. Until AC-059 that guarantee
  was asserted and never locked: `B6`'s Acceptance Criteria column named
  only AC-015 and AC-032, which lock premature subprocess invocation and
  the `git diff` path scope respectively, and neither constrains a write
  set in either direction. AC-059 is the deny-list counterpart to
  AC-025's grep, over the identical script set and at the identical
  cadence (registration-time and CI-gated), so it introduces no suite
  file and leaves this document's own ten-item Test Strategy — and the
  nine items `tasks.md` schedules — unchanged. The gap dates from this
  package's original 2026-07-22 revision rather than from any later
  amendment; it was found by spec review at attempt 8 round 3
  (`APPROVAL-BOUNDARY`), which is also why it is stated here rather than
  only in the requirements: an implementation reviewer reading this list
  would otherwise see one boundary locked and its neighbour not.
  **Scanned set corrected 2026-08-28, same ruling — closing an
  attempt-11 `DEPENDENCY-OVERLAP` finding and an attempt-6
  `VERIFICATION-PATH-CONCRETE` finding.** As first written the check also
  scanned `validate-resolver-evidence.*`, and that was wrong twice over.
  It contradicted `requirements.md`'s own Field Definitions, where
  **Resolver** is `resolve-project-context.{py,sh,ps1}` and "never refers
  to a different script anywhere in this package" — the validator is not
  the Resolver, and the boundary this check locks has the Resolver alone
  as its subject. It was also unverifiable by the owning task: T-008
  authors the validator *after* T-007, and the bridge first proposed —
  treating the registered check as a per-commit CI gate that would cover
  the validator when T-008's commit landed — is contradicted by this
  document's own Deployment / CI Plan, which states that this Phase 1
  package performs no CI wiring and that GitHub-Actions gating waits on a
  separately staged, human-applied `test.yml` patch. The scanned set is
  therefore the Resolver alone, which T-007 itself authors, giving this
  check the property that makes AC-025 sound: its owner verifies the
  whole scanned set by direct execution at its own gate, depending on no
  later task and no later human action. AC-025 legitimately scans both
  families because REQ-005's determinism guarantee names both. The
  validator's own write scope stays governed by Epic A1's
  `guard-invariants.json` suffix enforcement at write time and by the
  boundary prose above, and is left to a future criterion rather than
  asserted here in a form no task could discharge.
- **Ruling C(2)'s absent-component fail-closed rule is itself a security
  boundary (AC-058).** A dependency-returned `affected_components[]`
  entry naming a component id absent from this invocation's own Context
  Projection is a dependency result inconsistent with the canonical
  Context it was derived against; steps (f)-(g) never evaluate such an
  entry against an empty or defaulted properties document — the
  inconsistency Blocks `dependency-output-malformed` before any
  predicate evaluation of that entry. This closes the fail-open the
  cross-model panel identified (a predicate silently evaluated against
  `{}` can mask a broken affected-component-to-Context binding and
  misclassify a Capability), and is the caller-facing counterpart of the
  step-6.5 Registry recheck's generation-consistency posture (ruling
  C(1), AC-057).
- This feature's Resolver never writes to any `*.approval.json` sidecar,
  any `sdd/.approved-context/` anchor, or `guard-invariants.json` itself —
  it only *reads* `project-context.yaml`'s already-approved content via
  the canonicalizer (Epic A1's own already-approved-content boundary,
  investigation.md INV-007), it never participates in, and never bypasses,
  the approval-sidecar workflow.
- A `disabled-legacy-invocation` Block is fail-closed by construction —
  there is no code path in this design that reaches step 10 (track branch/
  Facet Manifest or Capability Summary assembly) while state derivation
  (step 1) has resolved `disabled-legacy` (Design Decisions/API Contract
  Plan, above). This diagnostic is itself a **CLI-misuse guard**, not a
  designed pipeline state (M4 correction, API / Contract Plan step 1,
  above) — a compatible caller (REQ-007) never invokes this Resolver's
  process at all while a Project Context is absent or derives `disabled-
  legacy`; this Block exists solely to fail loudly if a caller does so
  regardless, matching ADR-0016 item 4's own framing of the Resolver as a
  thing with no defined behavior in that state, not a thing that runs and
  gracefully no-ops in it (investigation.md INV-013).
- **No artifact this invocation stages ever reaches a live path except via
  the journaled publication transaction (B1, API / Contract Plan step 14,
  "Resolver publication transactional bundle contract")** — this is a
  rule about **staged** artifacts in the on-disk
  `.resolver-staging/<batch-nonce>/` sense, not the separate in-memory
  assembly and schema validation at API / Contract Plan steps 3/10/11/12
  ("Staged generation, journaled transactional commit", Design Decisions
  below), and when Resolver Evidence is a Block's whole
  write set **that write never passes through the on-disk area**:
  it is a direct
  `temp file + fsync + rename` with no staging area and no journal — note
  that whether the area EXISTS at such a Block is a separate question this
  sentence does not answer, since the two step-14 Blocks
  `artifact-publication-failed` and `post-publication-generation-mismatch`
  reach an Evidence-only write set only after the journaled transaction
  had already created it and rolled the publication artifacts back through
  it (AC-039, AC-049; corrected 2026-08-27 from a wider "never creates
  that on-disk area at all" claim that was false for exactly those two
  ids)
  (REQ-001 step (m), REQ-004; clarified 2026-08-27, human-approved,
  ruling D(2), with the two senses of "stage" distinguished because the
  first wording of this clarification read as false against those
  in-memory steps), so it sits outside this sentence's subject rather than
  being an exception to it. A process
  crash at any point (including mid-transaction, between two renames), a
  Block at the crash-recovery scan or any step 1-13, an in-process write/
  fsync/rename failure at step 14's own Commit phase, or a mismatch at
  step 14's own Post-publication verification phase, each leave every
  live path this invocation might have written either fully absent, fully
  unchanged from its pre-invocation state (converged there by the
  crash-recovery scan or the in-process rollback, never by a bare
  `unlink` with no restore), or — Resolver Evidence only, on any Block
  except the two REQ-002 names and, per ruling (a) (2026-08-28, mirrored
  here 2026-09-03 under ruling (G)), the non-diagnostic Evidence-target
  containment refusal, which likewise writes nothing — fully written, at
  whichever step that
  Block is reached, the step-14 Blocks `artifact-publication-failed` and
  `post-publication-generation-mismatch` included (widened 2026-08-27 from
  an "any step before publication" clause that did not cover those two,
  although REQ-001 step (m), REQ-004 and AC-012 all require Evidence
  there) — never a torn or
  partially-written file, at any of the four paths this feature's Resolver
  ever writes. A mixed generation across the batch likewise never stands
  **unattended**: the mandatory crash-recovery scan either converges it
  away before this invocation's own work begins, or — when the journal is
  unconvergeable — leaves **every interrupted target other than
  `resolver-evidence.yaml`** exactly as found, that one target receiving
  the Block's own record per AC-012 and AC-047 (scoped 2026-08-27: the
  unqualified "leaves it exactly as found" contradicted the same bullet's
  own "Resolver Evidence … fully written" clause two sentences earlier),
  and fails this invocation
  closed with `publication-journal-recovery` for manual operator
  intervention, which is the one state no automatic repair may touch
  (AC-047; scoped 2026-08-27, human-approved, ruling D(2), replacing an
  absolute that contradicted that branch's own no-repair obligation).
- **This feature's Resolver never embeds an upstream dependency script's
  own raw stderr text in any diagnostic line or Resolver Evidence
  `detail` field it emits (M8 correction, API / Contract Plan step 4,
  above)** — every `detail` this feature's own scripts construct is a
  canonical, Resolver-owned sentence built from fixed, repository-
  relative fields; this both closes a potential local-path/environment-
  detail leak into a committed artifact and is the mechanism that makes
  REQ-005's own dual-runtime byte-identity guarantee (AC-023) achievable
  at all for a Block whose underlying cause is a dependency subprocess's
  own OS-specific error text.
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
- **Per-task `CHANGELOG.md` discipline (REQ-008/AC-033).** Every
  implementation task this package's future task phase schedules lands
  **its own** `CHANGELOG.md` `## Unreleased` entry citing #193, inside
  that task's own diff. "Its own" is both per-task and in-diff: a single
  batched entry covering several tasks, or an entry added by a commit
  later than the task it describes, does not satisfy this rule. This is
  the documentation half of the same REQ-008 discipline whose versioning
  half this design already fixes (Data Plan, "`resolver.version`/
  `resolver.rule_set_revision`": no version string is mutated outside a
  `scripts/bump-version.sh` invocation, REQ-008/AC-034), and it binds the
  future Phase-2 implementation task in exactly the way this design
  already binds it elsewhere — the human-copy staging discipline
  (Protected-File Statement, above) and the `tests/run-all.sh`/`.ps1`
  registration rule (Test Strategy, above, AC-026). This Phase 1 package
  schedules no implementation task of its own and therefore lands no such
  entry itself; the rule is stated here so the future task phase inherits
  it from this design rather than rediscovering it.

## Constraint Compliance

- `AGENTS.md` Rules: "API changes require contract updates" — this
  feature's own new contract (`resolver-evidence.schema.json`) is authored
  in this same package; "architecture changes require ADRs" — this
  feature authors no new ADR because it makes no new architecture-level
  decision (ADR Change Log, above; its six genuinely new decisions are
  narrow, mechanical DSL-invocation-orchestration/publication rules, not a
  new axis).
- This task's own hard boundary (no edit to `plugins/**`/`scripts/**`/
  `.github/**`/`tests/**`/`contracts/**`/`docs/**`) is honored throughout
  this design — every concrete file this design names under those trees
  is described as a **future** artifact this Phase 1 package does not
  itself create; this package's own commits touch only
  `specs/epic-193-a5-capability-resolver/` and (in the registration
  commit) `AGENTS.md`'s Active Spec Directories list and `specs/
  workflow-state-registry.json`. In particular, **no file under
  `plugins/**` is modified by any commit this package makes** (AC-032) —
  including `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/
  SKILL.md`, which this package cites at design time and never edits
  (Design Decisions, "caller insertion point", above).
- **Security constraints** (impl-review round-1 remedy, closing a
  NO-REQ-CONTRADICTION Major finding on this section's own narrow scope):
  requirements.md's Security Boundaries bullet 1 ("never invokes a
  Provider API, reads a credential, or writes outside" a fixed path set)
  and REQ-005's no-clock/no-network/no-provider-API orchestration
  constraint are each honored — see this design's own `## Security
  Boundaries` section (above) and `## Global Constraints` (below) for the
  concrete, elaborated compliance statement; this Constraint Compliance
  section does not restate that content, only cross-references it.
- **Compatibility constraints**: every upstream Epic A1/A2/A3/A4 contract
  this feature reads is treated as already-fixed and content-frozen
  (Dependencies, requirements.md); no field, enum, or evaluation semantic
  any of those four already-`Spec-Review-Status: Passed` contracts fixes
  is redefined or narrowed by this design — see `## ADR Change Log`
  (above) for the full compatibility-preserving decision record.

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
and when). **OQ-003 is resolved by this revision** (M6, Design Decisions
"caller insertion point", above) to a concrete, file:line-cited anchor —
immediately before `SKILL.md:60`'s `### Full-Profile Layer Interview`
heading, in the live `sdd-bootstrap-interviewer/SKILL.md` at this
package's own design-authoring time — with Test Strategy item 10's own
drift check guarding against that anchor silently moving before the
future implementation task applies it; what remains genuinely open for
that future task is only the mechanical choice of direct-edit-vs.-human-
copy, gated on that file's then-current protection status
(investigation.md INV-017, requirements.md Assumptions), not the
insertion point itself.

Template fields for the two restated-open entries (added 2026-09-03,
human-approved, ruling (G); no behavioral change):

- OQ-001 — Owner: the future cadence-caller's own specification author
  (the Epic A6/A8 planning role). Blocks Implementation: no — this
  package's Resolver is invocation-scoped and complete with no cadence
  decision. Resolution Path: resolved by the first epic that schedules
  Resolver invocations, in that epic's own requirements.md.
- OQ-002 — Owner: the Epic A6/A8 planning role that owns
  `compare-facet-manifest-staleness`'s caller. Blocks Implementation:
  no — the comparison script ships in this package; naming its caller is
  an explicit Non-goal here. Resolution Path: the caller and its cadence
  are fixed in that future epic's own requirements.md.

## Risks

Restated and design-elaborated from requirements.md's own Risks section:

- **Lite-track resolution under `required` enforcement is effectively
  Blocked for every real, non-trivial invocation today;
  `advisory`-enforcement Lite resolution is not** (investigation.md
  INV-019, requirements.md Risks, narrowed by cross-epic addendum, Epic A6
  adversarial verification finding B5) — this design's own Test Strategy
  item 4 (revised, B5) makes this fact directly, mechanically testable
  using only fixtures that themselves pass `validate-capability-registry`
  (an earlier revision's synthetic-Registry forward-compatibility fixture
  did not, and is removed, B5) — a track-exclusive-output-set fixture (B4)
  is now reachable two ways: an `advisory`-missing fixture (any real
  Registry, any matched Capability, `advisory` enforcement) and a
  zero-matched-Capability fixture (either enforcement state), which
  together remain an honest, if still narrow for the `required` case,
  positive-path proof. **Epic A2 Registry-schema revision adding a
  `required_lite_checks` source is now recorded as an explicit, owned
  prerequisite for Epic A6's `required`-enforcement Lite path
  specifically** (requirements.md Dependencies, B5) — not merely a named
  risk this package could not act on, and not a blocker on Epic A6's
  `advisory`-enforcement Lite path.
- **The multi-component matching rule and the facet-name aggregation rule
  (Design Decisions, above) are this feature's own new decisions**, not
  upstream-fixed facts — both are narrow, citation-grounded, mechanical
  extensions of `evaluate-predicate`'s own already-fixed CLI shape, but a
  future spec-review pass may still find either needs to be an ADR of its
  own (ADR Change Log, above, already names this as a low-cost,
  anticipated follow-up rather than a gap).
- **A4 addendum needed for the facet-name aggregation rule's own evidence-
  concatenation consequence, and an A2 addendum candidate for same-
  Capability duplicate `facet` declarations** (Cross-Layer Dependencies,
  "A4 addendum needed" / "A2 addendum candidate", B7, above) — Epic A4's
  own schema already accommodates this feature's own concatenated-
  evidence output without a schema change, but Epic A4's own prose
  describing that field assumes a single-invocation case this feature's
  design can now exceed; Epic A2's own schema neither requires nor
  forbids same-Capability duplicate `facet` declarations, and states no
  prose either way. This package names both gaps and takes no further
  action on either Epic's own content-frozen files (this task's own hard
  boundary) — this feature's own design already handles both correctly
  regardless of how either future addendum lands.
- **`resolve-project-context.{py,sh,ps1}`'s reservation may not yet be
  live** when this feature's own Phase-2 implementation begins (Protected-
  File Statement, above, already gives the fallback sequencing for that
  case).
- **The staged-generation/journaled-transactional-commit/snapshot-
  recheck/post-publication-verification/provenance-binding rules (Design
  Decisions and API / Contract Plan, "Resolver publication transactional
  bundle contract", B1/B6/B8, above) add real implementation complexity**
  (journal read/write/rehash, byte-exact pre-image backup, a
  crash-recovery scan on every invocation, a *third* `resolve-component-
  paths` invocation for post-publication verification in addition to the
  pre-publication recheck's own second one, and `validate-resolver-
  evidence`'s own ADR-0025 self-discovery plus digest-binding logic) a
  future Phase-2 implementer must budget for — this is the direct,
  accepted cost of closing the atomicity/TOCTOU/provenance gaps
  adversarial review found in an earlier revision, not a design defect of
  this revision; Epic A1's own already-implemented (or concurrently
  implemented) transactional bundle contract is the reference
  implementation this feature's own future Phase-2 task should study
  first, rather than developing the journal/recovery mechanism from
  scratch (Epic A1 `design.md:927-1016`).
- **The anchor-fingerprint drift check (M6, Design Decisions, "anchor
  fingerprint", above) requires its own recorded citation to be updated
  in the same commit as any future, intentional `SKILL.md` edit that
  moves this package's own insertion point** — a future implementer who
  forgets this update is caught immediately by the drift-check fixture
  (AC-053) failing, not silently; this is the intended, low-cost
  trade-off of a position-sensitive check over the earlier revision's
  weaker, position-blind one.
