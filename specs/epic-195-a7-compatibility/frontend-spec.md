# Frontend Specification: epic-195-a7-compatibility

N/A — no change: this feature introduces no browser/client UI and no new
runtime service (design.md Layer Specifications: "Frontend: N/A — no
browser or frontend application; every future-task deliverable is Bash/
PowerShell/JSON"). This document instead records the script/runtime
inventory this design's own future-task edits actually use, since
design.md's Components and API / Contract Plan sections already own that
content and this file restates it in the layer-file shape the review
harness expects.

## Technology Stack

| Layer | Technology | Version | Rationale | Constraint |
|---|---|---|---|---|
| Shared test driver extension | Bash (`tests/lib/loop-driver.sh`) | repository-standard | new private collector `_loop_trace_emit`, new public comparator `assert_event_trace`, new public `assert_capability_applicability` (design.md API / Contract Plan) — collection and comparison stay two distinct functions, never one function playing both roles | `assert_artifacts_schema` is itself unmodified, and `assert_terminal` is unmodified apart from its one sanctioned `_loop_trace_emit done-transition:assert-terminal` producer call (AC-009; design.md Data Plan and Constraint Compliance); no new source file, only additive functions in the existing driver |
| Suite extensions | Bash (`tests/loop-consistency.tests.sh`, `tests/loop-escalation.tests.sh`, `tests/install.tests.sh`, `tests/uninstall.tests.sh`) | repository-standard | `TEST-018` (skill-order/review-loop-presence/approval-checkpoint kinds) and `TEST-019` (quality-gate-outcome kind) both call the identical `assert_event_trace` oracle (design.md Design Decisions, "Suite placement"); install/uninstall gain fixture cases only | no new suite file — REQ-003's Constraint Compliance row: "No new test-suite file" |
| Loop registry data | JSON (`tests/loops/loop-inventory.json`) | repository-standard | one additive, optional field (`capability_applicability`) on the existing `quality-gate` entry only (design.md Data Plan) | entry count stays 8 (AC-008); no new `id` |
| Run-record emitter extension | Bash/PowerShell (`plugins/sdd-quality-loop/scripts/emit-run-record.sh`) | repository-standard | `--capability-enforcement`/`--capability-block-id` flags, gated by a new `emit_capability` flag independent of `emit_v2`, mirroring `--effort-main`'s exact gating pattern (design.md API / Contract Plan) | no-flag output stays byte-identical (AC-011); capability-only (no `--effort-*`) is a usage error, never a silent third schema version |
| Golden-baseline capture/promote | Bash/PowerShell, new scripts (`capture-golden-baseline.sh`, `promote-golden-baseline.sh`) | repository-standard | candidate/canonical separation; `promote-golden-baseline.sh` structurally refuses to run when `CI` is set or `--approved-by` is omitted (design.md API / Contract Plan, Security Boundaries B1) | CI never references either command (AC-040 static scan); the promote command exits non-zero before touching any file when its guards are not satisfied (AC-041) |
| Canonical event-trace schema | JSON (inline schema, `compatibility-event-trace/v1`) | new, this package's own addition | single ordered array, one element per event, `{kind, producer, seq, value}` (design.md Data Plan) | `producer` is an identity-compared field, never documentation-only prose |
| REQ-007 SKIP allowlist manifest | JSON (`skip-allowlist-manifest/v1`, new) | new, this package's own addition | assertion→dependency(epic/issue/fingerprints)→activation-condition table (design.md Data Plan) | `fingerprints[]` uses sha256 canonical-window digests, never a bare `path:line-range` locator (closes NEW-001) |
| Structural-comparison record corpus | JSON (`structural-fixture-corpus/v1`, new) | new, this package's own addition | recorded-response fixtures substituted for live model calls in the gating suite (design.md Design Decisions, "Structural-comparison seam") | a canonicalizer parse failure is itself a suite failure, never a silent skip |

design.md's Components table names no new plugin and no new browser or
client-side artifact of any kind — every touched file is an existing
Bash/PowerShell test-infrastructure script or a JSON/Markdown data
artifact under `tests/`, `plugins/sdd-quality-loop/`, or this feature's
own `specs/epic-195-a7-compatibility/verification/` tree (Design
Decisions, "Golden-baseline location").

## Component Tree / State Shape / Routes / API Client / Code Splitting / Performance Budget / Empty-Loading-Error-Success

N/A — no change: no browser UI, no client-side state, no routes, and no
API client of this feature's own. The closest analog — the
`capture-golden-baseline.sh`/`promote-golden-baseline.sh` CLI contract
and the `assert_event_trace`/`assert_capability_applicability` function
signatures — is fully specified in design.md's API / Contract Plan, not
duplicated here.

## Dependencies

| Dependency | Status | Purpose | Alternative | License / Supply-Chain Note |
|---|---|---|---|---|
| Epic A1 Project Context / `PROJECT_CONTEXT_INVALID` semantics | unmerged, in active spec/task-review at this design's authoring time (design.md Assumptions) | Context-present fixture rows (F3/F4) and the negative `PROJECT_CONTEXT_INVALID` variant depend on A1's own validator behavior | none — this package cites, never re-derives, A1's own semantics | Internal (same repository); no external package |
| Epic A2 Registry schema / `capability_enforcement` field | not yet shipped at this design's authoring time | `quality-gate`'s `capability_applicability` field and the future Capability Coverage check item read `workflow.capability_enforcement`, an A2-defined field (design.md Design Decisions) | none | Internal (same repository); no external package |
| Epic A4 Facet Manifest / Capability Summary schema | `Spec-Review-Status: Passed`, unmerged | F3/F4 structural-compatibility assertions and the AC-007 named `SKIP` cite A4's own schema | none | Internal (same repository); no external package |
| Epic A5 Capability Resolver contract (`resolve-project-context-caller-contract`, Block-diagnostic-id enum) | `Impl-Review-Status: Pending` at this design's authoring time (fingerprints recorded against sibling worktree HEAD `748f40ccb713`) | REQ-003's Epic A5 deferred fixture assertions (anchor-fingerprint drift, Resolver-non-invocation, Block-surfaces-not-fallback) cite A5's own fixed text via sha256 fingerprint, never a bare line-number locator | none | Internal (same repository); no external package |
| Epic A6 Lite-track Resolver / Compatibility Matrix rows F5/F6 | in active spec-review at this design's authoring time | a future F5/F6 assertion's own manifest entry cites A6's own `requirements.md:217-219` fingerprint | none | Internal (same repository); no external package |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md`'s `## Required Outputs` anchor | existing, live | the deterministic recorded-response injection seam for the structural-comparison suite attaches here (design.md Design Decisions, "Structural-comparison seam"), fingerprinted at this worktree's HEAD `68130efd048f` | none — this design does not invent a new interception point | Internal (same repository); no external package |

No new external (npm/pip/etc.) package is introduced by this feature —
every future-task edit is either a JSON/JSON-Schema data file or an
additive extension of existing Bash/PowerShell test-infrastructure
scripts (design.md Global Constraints: no edits to `plugins/**`,
`scripts/**`, `.github/**`, `tests/**`, `contracts/**`, or `docs/**` in
*this* task). See security-spec.md's SBOM and Supply Chain section for
the full statement.

## Testing

No `tests/*.tests.sh`/`.tests.ps1` file is authored by this package
itself — this task's own change set is exactly the four Phase 1 spec
files plus the two named registration exceptions (Protected-File
Statement). design.md's Test Strategy names nine ordered future-task
items (fixture-matrix builder, golden-baseline capture, byte-identical
suite extension, structural-compatibility suite extension, canonical
event-trace schema implementation, Epic A5 deferred fixture assertions,
`emit-run-record.sh` extension, REQ-007 allowlist manifest, and CI
registration) that a Phase 2/3 implementation task authors. No browser/
UI test tooling applies — no UI exists for this feature.

## Open Questions

- None.
