# Design: epic-195-a7-compatibility

Impl-Review-Status: Pending
Feature Type: test-infrastructure specification (Phase 1 — no code)

## Technical Summary

Epic A7 adds three compatibility test kinds around the eventual
capability machinery (Epics A1–A6) without building that machinery itself
and, per decision doc §4.3/§19, without building a parallel test harness.
This package's design is therefore (a) a single versioned canonical
orchestration-event-trace schema (`compatibility-event-trace/v1`, Data
Plan) that gives "event-identical" a comparison oracle for the first
time (INV-021); (b) a set of precise, additive extension points onto five
already-existing files (`tests/loops/loop-inventory.json`,
`tests/lib/loop-driver.sh`, `tests/loop-consistency.tests.sh` **and**
`tests/loop-escalation.tests.sh` — split ownership, Design Decisions —
`plugins/sdd-quality-loop/scripts/emit-run-record.sh` — investigation.md
INV-001–INV-006), each producing or comparing that schema; (c) a governed,
candidate/canonical golden-baseline procedure pinned to a fixed
pre-capability commit (REQ-006, INV-022); (d) an eight-row fixture matrix
plus a Context-absent CLI submatrix and a `PROJECT_CONTEXT_INVALID`
negative variant (REQ-005); and (e) a SKIP allowlist manifest closing the
fail-open direction INV-023 identifies (REQ-007). This task's own change
set is exactly the four files under `specs/epic-195-a7-compatibility/`
plus the two named exceptions the Protected-File Statement below fixes
(`AGENTS.md`'s Active Spec Directories list, `specs/workflow-state-registry.json`'s
one new entry); the extension points below are a specification for a
later Phase 2/3 task, cited by exact file:line insertion target where the
current file content makes that possible.

## Architecture

```mermaid
flowchart TB
  subgraph Fixture matrix (REQ-005, F1-F4 built; F5-F8 SKIP/N-A)
    F1["F1 Context absent\n(full/legacy-seven-layer/disabled-legacy)"]
    F2["F2 Context absent + AGENTS lite marker\n(lite/lite-three-file/disabled-legacy)"]
    F3["F3 Context present, advisory\n(+ F3-invalid variant)"]
    F4["F4 Context present, required\n(+ F4-invalid variant)"]
  end

  F1 --> BI["Byte-identical test (REQ-001)"]
  F1 --> SC["Structural compatibility test (REQ-002)"]
  F2 --> BI
  F2 --> SC
  F3 --> OE["Orchestration event test (REQ-003)"]
  F4 --> OE
  F3 --> SC
  F4 --> SC

  BI --> GB["Golden baseline\n(REQ-006, pre-capability merge-base,\ncandidate/canonical)"]
  BI -.extends.-> INST["tests/install.tests.sh /\ntests/uninstall.tests.sh (INV-007)"]

  OE -.compares.-> SCHEMA["compatibility-event-trace/v1\n(canonical schema, Data Plan)"]
  OE -.extends.-> LI["tests/loops/loop-inventory.json\n(INV-001, INV-002)"]
  OE -.extends.-> LD["tests/lib/loop-driver.sh\n(INV-003, INV-004)"]
  OE -.new TEST-019 quality-gate-outcome.-> LE["tests/loop-escalation.tests.sh\n(INV-005)"]
  OE -.new TEST-018 skill-order/loop-presence/approval.-> LC["tests/loop-consistency.tests.sh\n(INV-005)"]
  OE -.extends.-> ERR["emit-run-record.sh\n(INV-006, effort-object pattern)"]

  LI --> LIT["loop-inventory.tests.sh\nregistration forcing (INV-002)\n8-entry count unchanged (AC-008)"]
```

F5–F8 (Context-present `lite`, `facet-hybrid`, `facet-native` rows) and
the Context-absent CLI `none`/`--full`/`--lite` submatrix are omitted from
this diagram for readability; the Compatibility Matrix table (below) is
the exhaustive, authoritative enumeration (AC-028).

## Components

| Component | Responsibility | Change | New/Existing |
|---|---|---|---|
| `tests/loops/loop-inventory.json` | single loop registry (INV-001) | add one additive, optional field on the `quality-gate` entry only (`capability_applicability`, Data Plan) — no new `id`, entry count stays 8 (AC-008) | existing, extended (future task) |
| `tests/lib/loop-driver.sh` | shared source-style driver (INV-003) | add one new public assertion function, `assert_capability_applicability` (API / Contract Plan), alongside the existing `assert_terminal` (AC-009 — neither `assert_terminal` nor `assert_artifacts_schema` itself changes); add one new private collector function, `_loop_trace_emit` (Data Plan, API / Contract Plan), called from each of the six event kinds' own named producer call sites; add one new public comparison function, `assert_event_trace` (API / Contract Plan), that only reads the collector's own finished trace and compares it against a recorded golden trace — collection and comparison are two distinct functions, never one function playing both roles | existing, extended (future task) |
| `tests/loop-escalation.tests.sh` | quality-gate escalation chain suite (INV-005) | add `TEST-019` (Design Decisions, below) driving a fixture-matrix state through the shared driver and asserting the quality-gate-outcome event kind (capability applicability) via `assert_event_trace` | existing, extended (future task) |
| `tests/loop-consistency.tests.sh` | four-review-round consistency suite (INV-005) | add `TEST-018` (Design Decisions, below) asserting the skill-invocation-order, review-loop-presence, and approval-checkpoint event kinds via `assert_event_trace` for a Context-absent round drive | existing, extended (future task) |
| `plugins/sdd-quality-loop/scripts/emit-run-record.sh` | deterministic run-record emitter (INV-006) | add `--capability-enforcement <disabled-legacy\|advisory\|required>` and `--capability-block-id <id>` (adopted now as an optional field, Data Plan — not deferred), gated by a new `emit_capability` flag independent of `emit_v2`; four flag-combination outcomes fixed in Data Plan/API Contract Plan (AC-033) | existing, extended (future task) |
| `tests/install.tests.sh` / `tests/uninstall.tests.sh` | existing byte-identical-style install/uninstall suites (INV-007) | add fixture cases asserting install/uninstall output is unaffected by `project-context.yaml` presence/absence (byte-identical target, decision doc §4.1) | existing, extended (future task) |
| golden-baseline capture/promote scripts (REQ-006, name/location fixed by Design Decisions below) | pinned byte-for-byte legacy output snapshot; separate `candidate`-capture and `canonical`-promotion commands (REQ-006c) | new | new (future task) |
| fixture-matrix builder (name/location fixed by Design Decisions below) | constructs F1–F4 plus the F3/F4-invalid variants and the Context-absent CLI submatrix (REQ-005) | new | new (future task) |
| `compatibility-event-trace/v1` schema (Data Plan) | versioned canonical definition of the six REQ-003 event kinds — producer, ordering, value-normalization per kind | new (specified inline in this document; not a new repository file in Phase 1) | new (future task authors the golden-trace fixture) |
| REQ-007 SKIP allowlist manifest (Data Plan) | assertion→epic/issue→fingerprint→activation-condition table every named `SKIP` reads from | new | new (future task) |
| `contracts/*.schema.json` (9 existing files, e.g. `workflow-state-registry.schema.json`) | existing schema validators cited as a byte-identical target (decision doc §4.1 "schema validator") | none — read-only compatibility target | existing, unmodified |
| `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/` | existing create-only layer templates cited as a byte-identical/structural target | none — read-only compatibility target | existing, unmodified |

## Protected-File Statement

This task modifies no protected file and no file outside
`specs/epic-195-a7-compatibility/`, `AGENTS.md` (Active Spec Directories
list only), and `specs/workflow-state-registry.json` (one new entry). The
Components table above names future-task targets, not files this task
edits. `docs/**`, `tests/**`, `plugins/**`, `scripts/**`, `contracts/**`,
and `.github/**` are out of scope for this task per its own assignment;
none is touched.

## Layer Specifications

This package deliberately ships four Phase 1 files
(`investigation.md`/`requirements.md`/`design.md`/`acceptance-tests.md`)
with no `ux-spec.md`/`frontend-spec.md`/`infra-spec.md`/`security-spec.md`
and no Phase 2 files, per this task's own explicit scope (requirements.md
Risks; investigation.md INV-018). The layer content that would normally
live in those four files is folded into this document instead:

- UX: N/A — no GUI, view, dialog, menu item, or human interactive shell
  surface. The only human-observable effects are suite pass/fail output
  and CI job status, governed by `acceptance-tests.md`.
- Frontend: N/A — no browser or frontend application; every future-task
  deliverable is Bash/PowerShell/JSON.
- Infrastructure: CI registration of the future-task suites/fixtures is
  described in Deployment / CI Plan, below; no infrastructure topology
  change.
- Security: described in Security Boundaries, below (golden-baseline
  integrity, shared-registry blast radius).

## Design System Compliance

N/A — `ds_profile: none`. Not a UI application; no mockup applicable.

## Cross-Layer Dependencies

| From | To | Contract / Decision | REQ | AC |
|---|---|---|---|---|
| requirements.md | investigation.md INV-002 | 8-entry `loop-inventory` count is preserved; capability events are additive fields, not a new loop `id`, because they share `quality-gate`'s own lifecycle (no independent cap/round/terminal state) | REQ-003 | AC-008, AC-009 |
| requirements.md | investigation.md INV-021 | a versioned canonical event-trace schema is the comparison oracle every event kind is asserted against | REQ-003 | AC-022–AC-027, AC-032 |
| requirements.md | investigation.md INV-006 | `emit-run-record.sh` capability object follows the existing `effort` v1/v2 additive-flag pattern, with its own independent no-flag/effort-only/capability-only/both matrix | REQ-003 | AC-011, AC-012, AC-033 |
| requirements.md | investigation.md INV-011 | eight-row fixture matrix (F1–F8) plus a Context-absent CLI submatrix maps 1:1 to decision doc §6's combination-matrix rows | REQ-005 | AC-014, AC-028 |
| requirements.md | investigation.md INV-013 | `PROJECT_CONTEXT_INVALID` is a required negative variant of each Context-present row, distinct from the compatibility fallback | REQ-005 | AC-019–AC-021 |
| requirements.md | investigation.md INV-022 | golden baseline is captured once against a fixed pre-capability merge-base commit and updated only via a candidate→canonical PR | REQ-006 | AC-001, AC-018, AC-041 |
| requirements.md | investigation.md INV-023 | the SKIP allowlist manifest closes the fail-open direction (dependency-present SKIP, unknown SKIP, fingerprint drift) and enumerates A1–A6 | REQ-007 | AC-004, AC-007, AC-016, AC-034, AC-035 |
| requirements.md | investigation.md INV-014 | the three-state Gate-applicability pattern is scoped to `check-component-coverage`; the Resolver's own disabled-legacy behavior is independently defined | REQ-003 | AC-009, AC-039 |
| requirements.md | investigation.md INV-016 | Epic A5's three deferred fixture assertions are owned by this epic's own existing suite, not a new suite | REQ-003 | AC-004, AC-021, AC-036, AC-037 |
| design.md Design Decisions | requirements.md OQ-001–OQ-003 | suite placement (split loop-consistency/loop-escalation), baseline location, and the A5 caller-contract suite's home are all three resolved below (OQ-003 is a closed decision, not a recommendation) | REQ-003, REQ-006 | AC-001, AC-010, AC-032, AC-036, AC-037, AC-040 |

## ADR Change Log

No new ADR. `docs/**` is out of scope for this task. The governing
decisions are already fixed by ADR-0010 (loop-inventory/fixture
vocabulary), ADR-0016 (workflow axes / `disabled-legacy` derived state),
and ADR-0023 (track-selection contract migration), plus decision doc §4/
§6/§19 — all cited by file:line in investigation.md. If Phase 2/3
discovers a genuinely new loop-shaped surface that the "no ninth loop"
constraint (requirements.md Non-goals) cannot represent, that is an
ADR-0010 revision decision for the Phase 2 task to raise separately, not
a decision this package makes.

## Data Plan

Data Entities: none persisted by this task. The future-task additive
schema fields proposed below are documentation of an intended shape, not
data created by this task.

Existing Data Affected: none. `tests/loops/loop-inventory.json`'s 8
existing entries are unmodified by this task (INV-001 remains the current,
correct description of `main`'s state after this task).

Migration Strategy: No migration required. Every schema-shaped change
this design proposes for a future implementation task is additive and
optional with a documented backward-compatible default: the
`capability_applicability` field on the `quality-gate` loop-inventory
entry is absent-safe (this section, above); the `emit-run-record.sh`
`capability` object is gated behind an independent `emit_capability`
flag with the no-flag heredoc staying byte-identical (AC-011); the new
`compatibility-event-trace/v1`, `skip-allowlist-manifest/v1`, and
`structural-fixture-corpus/v1` schemas are net-new files with no prior
version to migrate from. No existing consumer of any touched file's
current shape is broken by these additions (Constraint Compliance,
below).

Proposed future-task additive field (`tests/loops/loop-inventory.json`,
`quality-gate` entry only, optional, absent = not capability-aware):

```jsonc
{
  "id": "quality-gate",
  // ... existing fields unchanged (INV-001) ...
  "capability_applicability": {
    "disabled-legacy": "not-applicable (disabled-legacy)",
    "advisory": "advisory",
    "required": "required"
  }
}
```

This mirrors the exact string shape `check-component-coverage.py`'s own
design already fixes for a *different* Gate (`state: "not-applicable
(disabled-legacy)"` — INV-014, scoped per AC-039 to the component-coverage
Gate shape, not generalized to every future capability-derived Gate), so
`quality-gate`'s own future Capability Coverage check item (decision doc
§3.1) reports applicability with the identical vocabulary rather than
inventing a second one. Only entries whose own gate reads
`workflow.capability_enforcement` at all get this field; today that is
provisionally `quality-gate` only (Design Decisions, below) — every other
entry stays exactly as INV-001 records it. This field is read by the new
`assert_capability_applicability` helper only (API / Contract Plan) —
`assert_terminal`/`assert_artifacts_schema` are themselves unmodified
(AC-009).

**Canonical orchestration-event-trace schema, `compatibility-event-trace/v1`**
(REQ-003, closes INV-021): a single ordered JSON array, one element per
observed event, each carrying `{kind, producer, seq, value}`, produced by
exactly one collector function (`_loop_trace_emit`, below) and compared by
a separate, single comparator function (`assert_event_trace`, API /
Contract Plan) — collection and comparison are two distinct
responsibilities, never one function playing both roles, as an earlier
draft's own description of `assert_event_trace` conflated them.

**Collector API (single function, trace-wide monotonic order).**
`tests/lib/loop-driver.sh` adds one new private function,
`_loop_trace_emit <kind> <producer> <value-json>`, that appends
`{kind, producer, seq, value}` to a suite-local accumulator array
(`_LOOP_EVENT_TRACE`, reset once per fixture drive by `loop_fixture_init`)
where `seq` is `_loop_trace_emit`'s own single, trace-wide,
monotonically-incrementing counter — incremented on every call regardless
of kind, never a separate per-kind counter. This is the only function any
of the six kinds' own producer call sites (below) ever call to record an
event; `assert_event_trace` itself never calls `_loop_trace_emit` — it
only reads the finished `_LOOP_EVENT_TRACE` array at the end of a round
drive and compares it against a committed golden-trace fixture (API /
Contract Plan, below).

**Per-kind producer call sites** (`producer` is a required,
identity-compared field of every event — never documentation-only prose a
future implementer could satisfy with any arbitrary string):

| Event kind | Producer(s) — exact `_loop_trace_emit` call site | Ordering rule | Value-normalization |
|---|---|---|---|
| `skill-order` | `producer: "skill-order:invocation"` — `drive_review_round`'s own dispatch, immediately before each stage-script invocation (`tests/lib/loop-driver.sh:1478`, INV-003) | one event per invocation, call order | `value` = script/skill identifier only; working-directory-relative paths canonicalized, no timestamp |
| `review-loop-presence` | `producer: "review-loop-presence:stage-dispatch"` — `drive_review_round`'s own `stage` dispatch, immediately after a stage's own invocation completes (`tests/lib/loop-driver.sh:1478-1487`) | one event per stage actually driven, dispatch order | `value` = `stage` name only (`spec\|impl\|task\|domain`); a stage never dispatched emits no event (absence is the signal, never a placeholder) |
| `approval-checkpoint` | `producer: "approval-checkpoint:reserve"` — the shared driver's `_loop_reserve_review_context` call, at its own return (INV-003) | one event per reservation call, call order | `value` = `{stage, role}` only; `run_id`/`host_session_id`/ledger hash fields ignored (fixture-random, never compared) |
| `quality-gate-outcome` | **two** named producers, both required when both fire, always in this order: (1) `producer: "quality-gate-outcome:escalation"` — `check-quality-gate-cycle-limit.sh`/`select-agent-model.sh`'s own escalation-decision call site (INV-005), one event per decision, decision order; (2) `producer: "quality-gate-outcome:capability-applicability"` — `assert_capability_applicability`'s own comparison call (API / Contract Plan), exactly one event when the fixture state is capability-aware, always the last `quality-gate-outcome` event in the trace | escalation-decision events in decision order, then (if present) exactly one capability-applicability event, always last within this kind | `value` = `{next_tier}` (escalation producer) or `{applicability}` (capability-applicability producer) only; wall-clock fields ignored |
| `done-transition` | `producer: "done-transition:assert-terminal"` — `assert_terminal`'s own comparison call, firing exactly once per round at the instant it evaluates the freshly-read `.terminal.state` against the loop's expected terminal state (`tests/lib/loop-driver.sh:1512-1518`, INV-004); this recording is itself a state-transition record — the round's own invariant pre-round non-terminal state to the newly-observed terminal state, captured at terminal-state-assertion time — never a separately-sampled "final value" read after the comparison completes | always the last event in the round's own event sub-sequence | `value` = `.terminal.state` string only (the transition's own "to" side; "from" is invariantly non-terminal by construction and is not itself a compared field) |
| `skip-stop-message` | **two** named producers: (1) `producer: "skip-stop-message:skip"` — `loop_validator_skip`'s existing named-SKIP call site (`tests/lib/loop-driver.sh:460-519`, INV-005), extended by the REQ-007 allowlist manifest (below); (2) `producer: "skip-stop-message:stop"` — a new, dedicated fail-closed stop-detection call site in the fixture drive's own Context-validation guard (Test Strategy item 1, future task), firing the moment a `PROJECT_CONTEXT_INVALID` (or any other hard, non-SKIP stop) condition is detected, before any further stage dispatch. **`PROJECT_CONTEXT_INVALID` is uniquely assigned to this `stop` producer of `skip-stop-message`, never to `quality-gate-outcome` and never ambiguous between the two** (resolving an earlier draft's dual-kind framing) | emitted wherever either producer fires within the driven round, fire order | `value` = the fixed, cited-issue-number template string (`skip` producer) or the fixed `PROJECT_CONTEXT_INVALID` template string (`stop` producer) only — never free text, never either producer's template substituted for the other's |

**Cross-kind total order.** `seq` is `_loop_trace_emit`'s own single
global counter for the entire trace (not one counter per kind), so the
relative order between events of *different* kinds is exactly their real
emission order — the per-kind "ordering rule" column above is a same-kind
ordering guarantee only, never license to otherwise infer cross-kind order
from a kind's typical position.

A **golden trace** is a committed, versioned fixture of this schema's own
output for a given fixture-matrix cell (design.md Test Strategy). **Trace
identity** between an observed and a golden trace requires all four of:
identical `kind` sequence (by `seq` order), identical paired `producer`
sequence (by `seq` order — `producer` is an identity-compared field, not
documentation-only), identical per-event `value` after normalization, and
identical total event count — any extra, missing, reordered, or
wrong-producer event is a mismatch, never silently ignored.

**Compatibility Matrix** (REQ-005/AC-028; every valid decision doc §6 row
crossed with each test kind). **Disposition legend** (single-disposition
discipline, closing an earlier draft's cell-level ambiguity): every AC
cited in a cell below carries its own explicit disposition tag —
`ASSERT` (assertable now, unconditionally), `SKIP-with-activation → <AC-id>`
(a named `SKIP` degrading per that AC's own REQ-007 allowlist-manifest
entry, below, until its `activation_condition` evaluates true), or `N/A`
(does not apply to this row, with a stated rationale) — never a
cell-level label that silently spans two ACs with different gating
states. An earlier draft's `ASSERT (AC-003, AC-004)` framing for
F1×REQ-001 read as if AC-004 were assertable now; AC-004 is in fact always
a named `SKIP` until Epic A5 merges (REQ-007) — corrected below. Likewise,
`F3-invalid`/`F4-invalid` variants are never written as `ASSERT/SKIP` (an
earlier draft's own ambiguous shorthand): AC-019/AC-020/AC-021 are each
unconditionally `SKIP-with-activation` today, promoted to `ASSERT` only
once their own cited `activation_condition` is true, exactly like every
other `SKIP-with-activation` cell, never a state where both markings apply
simultaneously.

| Row | Combination | REQ-001 (byte) | REQ-002 (structural) | REQ-003 (orchestration) |
|---|---|---|---|---|
| F1 | Context absent, `full`/legacy-seven-layer/non-active | ASSERT (AC-003); SKIP-with-activation → AC-004 (until Epic A5 merges) | ASSERT (AC-005 full-track clause, AC-006) | ASSERT (AC-022–024, AC-026, AC-032) |
| F2 | Context absent, `lite`/lite-three-file/non-active | ASSERT (AC-003) | ASSERT (AC-005 lite-track clause, AC-006) — corrected from an earlier draft's mistaken citation of AC-005's `full`-track legacy-seven-layer clause for this `lite`-track row (INV-024) | ASSERT (AC-022–024, AC-026, AC-032) |
| F3 | Context present, `full`/legacy-seven-layer/advisory | N/A (byte-identical is a Context-absent-only target, REQ-001) | SKIP-with-activation → AC-034's F3/F4 entry (until Epic A1 merges) | SKIP-with-activation → AC-010, AC-025 (until Epic A1 merges) — `capability_applicability` is a static translation of `workflow.capability_enforcement` alone, ADR-0016, not a Registry-derived value; F3-invalid variant: SKIP-with-activation → AC-019, AC-020 (until Epic A1 merges), AC-021 (until Epic A1 **and** Epic A5 both merge) |
| F4 | Context present, `full`/legacy-seven-layer/required | N/A (same as F3) | SKIP-with-activation → AC-007 (until Epic A4 merges) | SKIP-with-activation → AC-010, AC-025 (until Epic A1 merges) — identical dependency to F3, only the asserted value differs; F4-invalid variant: identical disposition to F3-invalid (AC-019–021) |
| F5 | Context present, `lite`/lite-three-file/advisory | N/A | SKIP-with-activation → the allowlist manifest's own A1+A6 compound entry (until Epic A1 **and** Epic A6 both merge) | SKIP-with-activation → the identical A1+A6 compound entry |
| F6 | Context present, `lite`/lite-three-file/required | N/A | SKIP-with-activation → the identical A1+A6 compound entry | SKIP-with-activation → the identical A1+A6 compound entry |
| F7 | Context present, `full`/facet-hybrid/required | N/A | N/A — no Foundation epic produces `facet-hybrid` before this epic's own Phase 3 (ADR-0016 item 2) | N/A — same rationale |
| F8 | Context present, `full`/facet-native/required | N/A | N/A — no Foundation epic (A0–A9) ever produces `facet-native` (decision doc §19) | N/A — same rationale |

**Context-absent CLI submatrix** (REQ-005; both cells of F1/F2 are members
of this six-cell block): every one of the six cells below carries the
identical, individually-cited disposition `ASSERT (AC-003, AC-014)` — the
CLI-flag → `AGENTS.md`-marker → default priority order itself is a
byte-identical, Context-absent-only assertion (AC-003, ADR-0023 item 2),
and the fixture-builder's own `track_flag` parameter (AC-014) constructs
each of these six cells — resolving an earlier draft's gap where these
cells carried only a FULL/LITE track-selection outcome and no AC/TEST
citation of their own:

| CLI flag | `AGENTS.md` marker present | `AGENTS.md` marker absent | Disposition (all cells) |
|---|---|---|---|
| none | LITE (F2) | FULL (F1) | ASSERT (AC-003, AC-014) |
| `--full` | FULL | FULL | ASSERT (AC-003, AC-014) |
| `--lite` | LITE | LITE | ASSERT (AC-003, AC-014) |

**Observable×fixture-state judgment table** (AC-029; byte vs. structural
vs. event — three mutually exclusive, jointly exhaustive comparison
types, correcting an earlier draft's own AC-029 text, which named only a
two-way byte/event choice while this table and acceptance-tests.md both
already used a third, `structural`, class): the full cross-product of
every REQ-001/REQ-002/REQ-003 observable against every Compatibility
Matrix row (F1–F8), with every cell marked — including every `N/A` cell,
never left blank or described only in ASSERT-cell prose as an earlier
draft did:

| Observable | F1 | F2 | F3 | F4 | F5 | F6 | F7 | F8 |
|---|---|---|---|---|---|---|---|---|
| Deterministic script output | byte | byte | N/A | N/A | N/A | N/A | N/A | N/A |
| Exit code | byte | byte | N/A | N/A | N/A | N/A | N/A | N/A |
| stdout/stderr | byte | byte | N/A | N/A | N/A | N/A | N/A | N/A |
| Template-copy result | byte | byte | N/A | N/A | N/A | N/A | N/A | N/A |
| Schema-validator result | byte | byte | N/A | N/A | N/A | N/A | N/A | N/A |
| Install result | byte | byte | N/A | N/A | N/A | N/A | N/A | N/A |
| Uninstall result | byte | byte | N/A | N/A | N/A | N/A | N/A | N/A |
| Generated directory listing | byte | byte | N/A | N/A | N/A | N/A | N/A | N/A |
| Plugin manifest | byte | byte | N/A | N/A | N/A | N/A | N/A | N/A |
| Generated-artifact structure | structural | structural | structural | structural | structural | structural | N/A | N/A |
| Skill-invocation order | event | event | event | event | event | event | N/A | N/A |
| Review-loop presence | event | event | event | event | event | event | N/A | N/A |
| Approval checkpoint | event | event | event | event | event | event | N/A | N/A |
| Quality-gate outcome | event | event | event | event | event | event | N/A | N/A |
| Done-transition | event | event | event | event | event | event | N/A | N/A |
| Skip/stop message | event | event | event | event | event | event | N/A | N/A |

This table fixes comparison *type* only (byte/structural/event/N-A),
orthogonal to the Compatibility Matrix's own `ASSERT`/`SKIP-with-
activation`/`N/A` *activation-state* marking above — a `SKIP-with-
activation` cell in the Compatibility Matrix still has a fixed comparison
type here (the type its own assertion will use once its activation
condition is met); `N/A` here means the observable itself does not apply
to that row at all, matching the Compatibility Matrix's own N/A rationale
(F7/F8) or REQ-001's own Context-absent-only scope (byte-identical
observables, F3–F8) or REQ-002/REQ-003's own no-Foundation-epic rationale
(structural/event observables, F7/F8). No observable appears in more than
one comparison-type column for a given row.

**REQ-001 canonical target inventory** (AC-038; single table pairing
every REQ-001 target with its own exact capture format and AC/TEST — an
earlier draft's own prose target list, and its AC-003/Test Strategy text,
omitted the generated directory listing and plugin manifest rows this
table now includes):

| Target | Capture format | AC / TEST |
|---|---|---|
| Deterministic script output | raw stdout/stderr byte-tuple | AC-003 / TEST-003 |
| Exit code | status integer | AC-003 / TEST-003 |
| stdout/stderr | raw stdout/stderr byte-tuple | AC-003 / TEST-003 |
| Template-copy result | filesystem manifest (path → sha256) | AC-003 / TEST-003 |
| Schema-validator result | status integer | AC-003 / TEST-003 |
| Install result | filesystem manifest | AC-003 / TEST-003 (extends `tests/install.tests.sh`, INV-007) |
| Uninstall result | filesystem manifest | AC-003 / TEST-003 (extends `tests/uninstall.tests.sh`, INV-007) |
| Generated directory listing | filesystem manifest | AC-003 / TEST-003 |
| Plugin manifest | filesystem manifest (path → sha256, matching `contracts/*.schema.json`'s own byte-identical convention) | AC-003 / TEST-003 |

This table's own completeness and 1:1 pairing is itself independently
checked by AC-038/TEST-038 (a static/doc-review check that the table
exists and covers every named REQ-001 target exactly once) — distinct
from AC-003/TEST-003, the integration test that actually captures and
compares each row's own bytes. The "resolver not called" legacy code path
(decision doc §4.1) is deliberately **not** a row in this table: it is a
spy/absence check, not a byte-capture target, and is independently
specified by AC-004/TEST-004 (Compatibility Matrix, above).

**`PROJECT_CONTEXT_INVALID` variant plan** (REQ-005/AC-019–021): the
fixture-matrix builder's `valid_or_invalid` parameter (API / Contract
Plan) produces, for F3/F4 only, a `sdd/project-context.yaml` that parses
as YAML but fails Epic A1's own schema/hash/HMAC validator by exactly one
deliberately-broken field (design.md's own future-task fixture chooses
which, e.g. a corrupted `content_hash`) — never a syntactically invalid
YAML file, so the failure is provably the validator's own semantic
rejection, not a parse error a different code path would also reject.

**REQ-007 SKIP allowlist manifest** (AC-034/AC-035; schema
`skip-allowlist-manifest/v1`): a single JSON array, one entry per
upstream-dependent assertion. Each entry's `dependencies` field is itself
an array of `{epic, issue, fingerprints}` objects — never a single flat
`{epic, issue}` pair — so one assertion can cite more than one upstream
epic (e.g. AC-021's own Epic A1 **and** Epic A5 dependency, or a future
F5/F6 assertion's own Epic A1 **and** Epic A6 dependency); each
dependency's own `fingerprints` is itself an array of canonical-window
digests (never a `path:line-range#item` locator, closing finding 10's
"cannot hard-fail drift" gap and NEW-001's own worked-example failure —
see Design Decisions, "Cross-epic fingerprint citations," for the
identical digest algorithm applied to this package's own normative
citations of Epic A5):

```jsonc
[
  {
    "assertion_id": "AC-004",
    "dependencies": [
      {
        "epic": "A5",
        "issue": 193,
        "fingerprints": [
          {
            "source": "specs/epic-193-a5-capability-resolver/design.md",
            "line_range": "1886-1915",
            "algorithm": "sha256",
            "normalization": "lf-normalized, utf-8, lines joined by a single \n, no trailing newline",
            "digest": "sha256:9b549be9c9d8897c9efd1badbab8a5d4184086649e98a3c31325ef3210561bff",
            "quote": "10. `resolve-project-context-caller-contract` (new, M6) — a contract test"
          }
        ]
      }
    ],
    "activation_condition": "merged(A5)"
  },
  {
    "assertion_id": "AC-007",
    "dependencies": [
      {
        "epic": "A4",
        "issue": 192,
        "fingerprints": [
          {
            "source": "specs/epic-192-a4-facet-manifest/requirements.md",
            "line_range": "211-213",
            "algorithm": "sha256",
            "normalization": "lf-normalized, utf-8, lines joined by a single \n, no trailing newline",
            "digest": "sha256:b84bd60bfba1bc9741bb76096d0502a461343c6867efcaa4bc57986b02d11157",
            "quote": "- **REQ-001** (Facet Manifest schema — decision v2 §19 item 1, §16, §12):"
          }
        ]
      }
    ],
    "activation_condition": "merged(A4)"
  },
  {
    "assertion_id": "AC-021",
    "dependencies": [
      {
        "epic": "A1",
        "issue": 189,
        "fingerprints": [
          {
            "source": "specs/epic-189-a1-project-context/requirements.md",
            "line_range": "891-908",
            "algorithm": "sha256",
            "normalization": "lf-normalized, utf-8, lines joined by a single \n, no trailing newline",
            "digest": "sha256:0851c0920fdfc93deb792b1f322dbe89a1b6ed6cb6bfc2c9a361cba5f513955a",
            "quote": "**Presence/validity semantics (revised — closes the downgrade-via-"
          }
        ]
      },
      {
        "epic": "A5",
        "issue": 193,
        "fingerprints": [
          {
            "source": "specs/epic-193-a5-capability-resolver/design.md",
            "line_range": "1886-1915",
            "algorithm": "sha256",
            "normalization": "lf-normalized, utf-8, lines joined by a single \n, no trailing newline",
            "digest": "sha256:9b549be9c9d8897c9efd1badbab8a5d4184086649e98a3c31325ef3210561bff",
            "quote": "10. `resolve-project-context-caller-contract` (new, M6) — a contract test"
          }
        ]
      }
    ],
    "activation_condition": "merged(A1) AND merged(A5)"
  }
]
```

A future F5/F6 assertion's own manifest entry (Phase 2/3, once those
`TEST-0NN` cases are authored) follows the identical `AC-021`-style
compound shape with an `A1`+`A6` `dependencies` pair — Epic A6's own
`requirements.md:217-219` REQ-001 opening (`sha256:
185d9e88b4ef19fd86d4993dabc6446f5e1b2e5dc9a84b3bacbb81f823f25134`, this
package's own recorded fingerprint at `sdd-forge-wt-epic-194` HEAD
`32b8bf57b760`) is the fingerprint that entry cites, following this same
algorithm.

**`activation_condition` grammar and evaluator** (deterministic, no
free-form text): a boolean expression over exactly two primitive
predicates, combined only by `AND`/`OR`:

- `merged(<epic-id>)` — true iff the cited epic's own spec
  `Spec-Review-Status`/`Impl-Review-Status` front matter reads a
  non-`Pending` terminal value **and** its feature branch has been merged
  to `main` (git branch-ancestry check) — the two-part check AC-034
  already names, now given a single predicate name.
- `fingerprint_match(<dependency-index>)` — true iff recomputing the named
  dependency's own `fingerprints[]` entry's `digest` (identical algorithm:
  sha256 of the cited `source`/`line_range`'s own current literal lines,
  LF-normalized, UTF-8, joined by `\n`, no trailing newline) against the
  cited epic's own current HEAD equals the recorded `digest` value
  exactly.

The evaluator emits `SKIP` whenever this entry's own `activation_condition`
(evaluated with `merged(...)` alone) is false, and hard-fails per AC-035
whenever: (a) `merged(...)` is true but `SKIP` still fires (dependency-
present SKIP); (b) a `SKIP`-shaped line in suite output matches no
manifest entry (unknown SKIP); or (c) `merged(...)` is true but
`fingerprint_match(...)` is false for any of that entry's own
`fingerprints[]` (fingerprint drift) — `fingerprint_match` is evaluated
independently of, and in addition to, `merged`, so an entry whose epic has
merged but whose cited fingerprint no longer matches is a drift hard-fail
even when `merged(...)` alone would otherwise unblock it. This is exactly
the mechanism that would have caught NEW-001's own worked failure: an
earlier draft's `design.md:1861-1890` locator for Epic A5's item 10 had
already drifted to the wrong content by the time of that review, but a
locator is not a digest and cannot itself be recomputed and compared —
`fingerprint_match` recomputing this package's own recorded
`sha256:9b549be9c9d8897c9efd1badbab8a5d4184086649e98a3c31325ef3210561bff`
against Epic A5's own current HEAD would have produced a mismatch and
hard-failed the suite the moment that drift occurred, rather than silently
trusting a stale line-number citation.

## API / Contract Plan

**`assert_capability_applicability <loop-id> <fixture-state> <observed>`**
(proposed new public function, `tests/lib/loop-driver.sh`, alongside the
existing `assert_terminal` at `tests/lib/loop-driver.sh:1512-1518`,
INV-004): reads `.loops[] | select(.id == $loop_id) | .capability_applicability[$fixture_state]`
from `$LOOP_INVENTORY_PATH` (identical lookup pattern to `assert_terminal`,
so neither `assert_terminal` nor `assert_artifacts_schema` needs to
change, AC-009) and compares it to `$observed`. `fixture_state` is one of
`disabled-legacy \| advisory \| required` (the Field Definitions
vocabulary requirements.md fixes, matching ADR-0016's derived-state
naming exactly).

**`_loop_trace_emit <kind> <producer> <value-json>`** (proposed new
private function, `tests/lib/loop-driver.sh`, Data Plan): the single
collector every one of the six event kinds' own named producer call sites
calls to append `{kind, producer, seq, value}` to the round's own
`_LOOP_EVENT_TRACE` accumulator, `seq` assigned from this function's own
trace-wide monotonic counter (Data Plan "Collector API"). No other
function ever appends to `_LOOP_EVENT_TRACE`.

**`assert_event_trace <golden-trace-path>`** (proposed new public
function, `tests/lib/loop-driver.sh`, alongside `assert_capability_applicability`):
a pure comparator — it never calls `_loop_trace_emit` and never itself
records an event. It reads the round's own finished `_LOOP_EVENT_TRACE`
array (already fully populated by `_loop_trace_emit` calls made during the
round drive that just completed) and compares it against a committed
golden-trace fixture, applying each event kind's own value-normalization
rule before comparison, and fails on any `kind`-sequence, `producer`-
sequence, `value`, or event-count mismatch (Data Plan "Trace identity" —
`producer` is now an identity-compared field, not documentation-only).
This is the single function both `TEST-018` (`loop-consistency`) and
`TEST-019` (`loop-escalation`) call, so both suites compare against one
oracle (REQ-003c), and both suites drive rounds through the identical
`_loop_trace_emit` collector (Data Plan), so there is exactly one
collector API and exactly one comparator API for the entire schema.

**`emit-run-record.sh` proposed flags** (mirrors `--effort-main`'s exact
gating, INV-006, `plugins/sdd-quality-loop/scripts/emit-run-record.sh:62-77`):

```
--capability-enforcement <disabled-legacy|advisory|required>
--capability-block-id <id>
```

Each sets a new `emit_capability=1`, independent of the existing
`emit_v2` (`--effort-*`) flag family. `block_id` is adopted now, as an
**optional** field (never deferred to "if Phase 2 needs it") —
`null` when `--capability-block-id` is not supplied, matching A5's own
16-value Block-diagnostic-id enum (`FP-A5-BLOCK-REQ002`, Design
Decisions "Cross-epic fingerprint citations" — `specs/epic-193-a5-capability-resolver/requirements.md:341-343`,
`sha256:4e02ad4f1f9095fcc73db9f2478c8c487366b6d11ed6c25b73e92e672df9ba62`)
when it is. The four reachable flag combinations (AC-033) are fixed
exhaustively:

| `--effort-*` supplied | `--capability-enforcement` supplied | Result |
|---|---|---|
| no | no | `sdd-run-record/v1`, byte-identical heredoc (AC-011), unchanged from `plugins/sdd-quality-loop/scripts/emit-run-record.sh:283-304` |
| yes | no | `sdd-run-record/v2` with the `effort` object only, no `capability` key at all (current behavior, `:245-277`, unchanged) |
| no | yes | **usage error**: non-zero exit, diagnostic to stderr, no `$out` file written — matching the script's own existing `require_effort_control_value` fail-closed pattern (`:45-54`); a capability-only run without effort tracking is not a supported shape (Design Decisions, below) |
| yes | yes | `sdd-run-record/v2` with both the existing `effort` object and a new, additive `capability` sibling object |

```jsonc
"capability": {
  "enforcement": "advisory",
  "block_id": null
}
```

The no-flag path's heredoc is untouched (byte-identical, AC-011); this is
the same guarantee INV-006 already documents for the `effort` object's own
introduction, applied a second time for capability fields. A golden
negative test (AC-033) fixes the capability-only usage-error's exact exit
code and stderr text.

**Golden-baseline capture/promote contract** (REQ-006/AC-001/AC-018;
script name and exact location fixed by Design Decisions, below): two
named commands, never one script with a mutation flag:

1. `capture-golden-baseline.sh [--write-candidate]` — default (no-flag)
   invocation runs every REQ-001/AC-038 target against a Context-absent
   fixture built by the fixture-matrix builder and diffs the result
   against the **committed canonical** baseline, exiting non-zero on any
   drift; it never writes anything. `--write-candidate` additionally
   writes a **gitignored candidate** file (never the canonical path) —
   this is the only way any invocation, agent or human, produces new
   baseline bytes.
2. `promote-golden-baseline.sh <candidate-path> --approved-by <human-identifier>` —
   copies a candidate to the canonical path, run only inside a dedicated
   pull request a human maintainer reviews and merges (REQ-006c). This
   command is now **structurally**, not merely conventionally, blocked
   from CI (closing finding 2's "operational convention, not structural
   rejection" gap): it exits non-zero immediately, before reading or
   writing any file, whenever the `CI` environment variable is set to any
   non-empty value (the ambient signal every major CI runner — GitHub
   Actions, GitLab CI, CircleCI — sets unconditionally, `CI=true`), and it
   refuses to run at all without an explicit `--approved-by
   <human-identifier>` flag naming the reviewing maintainer (never
   inferred, never defaulted, never satisfied by an empty string) — so
   "CI never invokes the promote command" (Security Boundaries B1) is a
   fail-closed precondition the script itself enforces, not only an
   operational convention CI's own job definition happens to honor. A
   companion, purely static check (Test Strategy item 9; AC-040) scans
   the committed `.github/workflows/test.yml` text for the literal
   strings `promote-golden-baseline.sh` and `--write-candidate`,
   hard-failing if either string appears anywhere in that file, so a
   future CI job step referencing either command is caught at review time
   even before the `CI`-env-var/`--approved-by` guards above would ever
   run.

The manifest both commands read/write records, at minimum: the exact
pre-capability merge-base commit SHA (AC-018, INV-022), the fixed
environment variables used (`TZ`, `LC_ALL`, no ambient `SDD_*`), and each
captured target's own sha256 plus the capturing script's own sha256.

## Test Strategy

Phase 2/3 (not this task) implements, in this order:

1. Fixture-matrix builder (REQ-005/AC-014): named builder functions for
   F1–F4 plus a `valid_or_invalid` parameter (F3/F4-invalid, AC-019–021)
   and a `track_flag` parameter (Context-absent CLI submatrix, AC-014),
   following `loop_fixture_init`'s own `mktemp -d` +
   physical-path-normalization + outside-repo-root assertion pattern
   (`tests/lib/loop-driver.sh:106-141`) so fixtures never touch the real
   working tree. F5–F8 are documented `SKIP`/`N-A` rows (Compatibility
   Matrix, Data Plan) with no builder function in this increment.
2. Golden-baseline initial canonical capture (REQ-006/AC-001/AC-018),
   captured once against the fixed pre-capability merge-base commit
   (INV-022 — never "`main` at Phase 2 start"), committed under the
   location Design Decisions fixes below.
3. Byte-identical suite extension (REQ-001/AC-038): new fixture cases
   added to `tests/install.tests.sh`/`tests/uninstall.tests.sh`
   (INV-007) plus a diff-against-golden-baseline check for the remaining
   canonical-inventory targets (script output, template copy, schema
   validator, generated directory listing, plugin manifest) — negative
   self-check required (AC-002), matching every existing suite's own
   convention (INV-002, INV-005).
4. Structural compatibility suite extension (REQ-002): a new fixture-set
   comparison against the existing seven-file legacy template set
   (`full` track, INV-018) and the existing three-file `lite-spec` set
   (`lite` track, INV-024), run through the deterministic recorded-
   response injection seam fixed at the `SKILL.md:116-133` anchor
   (Design Decisions, "Structural-comparison seam") against the
   `structural-fixture-corpus/v1` record corpus and the fixed AST
   canonicalizer (Design Decisions; AC-030) — never a live model call in
   this gating suite (a separate, non-gating live-model refresh test is
   authored independently, AC-031) — asserting the Context-present states
   produce zero capability/Facet artifacts until Epic A4 lands (named
   `SKIP`, AC-007). A canonicalizer parse failure is itself a suite
   failure, never a silent skip (Design Decisions).
5. Canonical event-trace schema implementation (REQ-003, Data Plan): the
   `capability_applicability` field added to `quality-gate`'s own
   `loop-inventory` entry; `_loop_trace_emit`, `assert_capability_applicability`,
   and `assert_event_trace` added to the shared driver — `_loop_trace_emit`
   called from each of the six kinds' own named producer call sites (Data
   Plan), `assert_event_trace` reading the finished trace only; `TEST-019`
   added to `tests/loop-escalation.tests.sh` (quality-gate-outcome kind)
   and `TEST-018` added to `tests/loop-consistency.tests.sh`
   (skill-order/review-loop-presence/approval-checkpoint kinds) — both
   calling the identical `assert_event_trace` oracle (Design Decisions).
6. Epic A5 deferred fixture assertions (OQ-001, resolved): `TEST`
   sub-cases for anchor-fingerprint drift (AC-036), Resolver-non-
   invocation (AC-004/AC-021), and Block-surfaces-not-fallback (AC-037)
   added inside the same `TEST-018`/`TEST-019` cases or their own
   numbered follow-on cases in the same two suites — never a new suite
   file — once Epic A5's caller insertion point is implemented.
7. `emit-run-record.sh` extension (REQ-003/AC-011/AC-012/AC-033): the
   `--capability-enforcement`/`--capability-block-id` flags and
   `capability` object, verified against all four flag-combination
   outcomes (API / Contract Plan table) including the capability-only
   usage-error golden negative test.
8. REQ-007 allowlist manifest (AC-034) and its three hard-fail checks
   (AC-035) wired into the suite run itself, enumerating A1/A2/A3/A4/A5/A6.
9. Registration: every new/extended `.sh` suite's `.ps1` twin, plus
   `tests/run-all.sh`/`tests/run-all.ps1`/`.github/workflows/test.yml`
   entries (INV-005 pattern) — `.github/workflows/test.yml` is a CI file
   this repository has, in at least one precedent (Epic A5's own
   `human-copy/` staging for a `test.yml` registration alongside a
   protected-file batch, investigation.md cross-epic finding), treated as
   requiring staged/reviewed application rather than a direct agent edit;
   Phase 2/3 confirms whether that precedent applies here or whether
   `test.yml` is a directly-editable file in this repository's actual
   protected-file list at that time. The AC-031 live-model refresh test
   is registered separately and is never added to this gating
   registration set. A companion static check (AC-040) scans the
   committed `.github/workflows/test.yml` text for the literal strings
   `promote-golden-baseline.sh` and `--write-candidate`, hard-failing if
   either appears anywhere in that file — the automated verification that
   this registration step never wires either mutation-capable golden-
   baseline command into CI (Security Boundaries B1; API / Contract
   Plan). A second, integration-level negative-fixture pair (AC-041)
   invokes `promote-golden-baseline.sh` directly rather than scanning
   CI's own workflow text: once with `CI` set to a non-empty value and
   once with `--approved-by` omitted, asserting a non-zero exit and no
   write to the canonical path in both cases — exercising the script's
   own fail-closed guard (API / Contract Plan, above) rather than only
   its absence from CI's job definition.

## Design Decisions (resolving requirements.md's Open Questions where possible)

**Suite placement for the orchestration-event trace splits across two
existing suites, both driven by one shared `assert_event_trace` oracle.**
Decision doc §3.1 places "Capability Coverage" among quality-gate's own
common Implementation-Gate check items, not among any of the four
independent review loops (spec/impl/task/domain) `loop-consistency.tests.sh`
drives (INV-005); `loop-escalation.tests.sh` already drives quality-gate's
own scripts end-to-end (`TEST-011`, INV-005) and already carries the
`TEST-017`/`TEST-018` numbering precedent this task's `TEST-019` follows —
so the quality-gate-outcome event kind is `TEST-019` there. REQ-003 also
names skill-invocation order and review-loop presence, which are exactly
what `loop-consistency.tests.sh` already drives end-to-end across all four
review rounds via the shared driver (`TEST-008`, INV-005) — a single
suite that already exercises quality-gate's own local escalation builder
(`tests/loop-escalation.tests.sh:101-108`) is the wrong place to also own
those two event kinds, which have nothing to do with quality-gate
escalation. `tests/loop-consistency.tests.sh` therefore owns `TEST-018`
for those two kinds plus approval-checkpoint (a byproduct of the same
round drive). Both `TEST-018` and `TEST-019` call the identical
`assert_event_trace` function against the identical
`compatibility-event-trace/v1` schema (API / Contract Plan), so this
remains one comparison oracle, not two competing ones — resolving
REQ-003's full suite-placement question, not merely its quality-gate half.

**`capability_applicability`/the "no ninth loop" decision rests on
capability events sharing `quality-gate`'s own lifecycle, never on
`loop-inventory.tests.sh`'s current `length == 8` value.** A capability
event (Resolver invocation, `disabled-legacy` non-evaluation,
`PROJECT_CONTEXT_INVALID` stop) has no independent cap/round/terminal
state of its own (ADR-0010's loop-shape vocabulary, INV-008) — it is
always an outcome *of* an already-registered loop's own round drive
(quality-gate's Capability Coverage check item, decision doc §3.1; or a
review round's own approval-checkpoint sequence). That semantic fact —
not the current numeric value of `loop-inventory.tests.sh:129-133`'s
assertion — is why this package adds fields to existing entries instead
of registering a ninth loop (INV-002's caveat, above). AC-009 states this
precisely: the existing `assert_terminal`/`assert_artifacts_schema`
helpers are themselves unmodified; a new, dedicated
`assert_capability_applicability` helper reads the new field.

**Cross-epic fingerprint citations (replacing raw path:line locators —
NEW-001).** Every normative citation of Epic A5's own spec text below is
a fingerprint — `{source file, a fixed line range recorded at this
package's own authoring-time read of sibling worktree
sdd-forge-wt-epic-193 HEAD 748f40ccb713, the sha256 digest of that
range's own literal lines (LF-normalized, UTF-8, joined by a single `\n`,
no trailing newline — identical algorithm to Epic A5's own anchor-
fingerprint technique, `specs/epic-193-a5-capability-resolver/design.md:2181-2189`,
read from that same worktree), a short verbatim quote of the window's own
first line}` — never a bare line-number locator a later, unrelated
upstream edit can silently invalidate without this package's own
re-verification catching it. This corrects the exact failure NEW-001
found: an earlier draft's `design.md:1861-1890` locator for Epic A5's own
item 10 had already drifted to the wrong content (item 10 is now at
`design.md:1886-1915`) by the time of that review, and a bare locator
cannot itself be recomputed and compared the way a digest can. Two
fingerprints are recorded, each reused by every citation below that needs
it:

- **`FP-A5-CALLER-CONTRACT-10`**: `specs/epic-193-a5-capability-resolver/design.md:1886-1915`
  (item 10, `resolve-project-context-caller-contract`, its own full
  three-sub-item (a)/(b)/(c) body) — `sha256:
  9b549be9c9d8897c9efd1badbab8a5d4184086649e98a3c31325ef3210561bff` —
  quote: "10. `resolve-project-context-caller-contract` (new, M6) — a
  contract test".
- **`FP-A5-BLOCK-REQ002`**: `specs/epic-193-a5-capability-resolver/requirements.md:341-343`
  (REQ-002's own opening clause, the home of the sixteen-row
  Block-diagnostic-id table) — `sha256:
  4e02ad4f1f9095fcc73db9f2478c8c487366b6d11ed6c25b73e92e672df9ba62` —
  quote: "- **REQ-002** (Ambiguous-input Block taxonomy — decision v2
  §19's".
- **`FP-A5-DISABLED-LEGACY-ROW`**: `specs/epic-193-a5-capability-resolver/requirements.md:355`
  (the `disabled-legacy-invocation` diagnostic row specifically, AC-004's
  own SKIP target) — `sha256:
  4b776b1142cfd4a973a88706b43531f720bc0d9235fb4cc58abe21571d6c7129` —
  quote: "`disabled-legacy-invocation` | The `--config` target is
  absent".

A future Phase 2/3 task (or this package's own next re-verification pass,
requirements.md Assumptions) recomputes each digest against A5's own
then-current HEAD before relying on the citation; a mismatch is
fingerprint drift (AC-035c; the REQ-007 allowlist manifest's own
`fingerprint_match` evaluator, Data Plan, applies the identical check
mechanically wherever these fingerprints gate a named `SKIP`).

**Structural-comparison seam: anchor, record corpus, parser-failure, and
normalization algorithm (REQ-002, AC-030, closing finding 6).** The
deterministic recorded-response injection seam attaches at
`plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md`'s own
`## Required Outputs` section (`SKILL.md:116-133`; this package's own
recorded anchor-window fingerprint, identical algorithm to the Cross-epic
fingerprint citations above: `sha256:
075a42200327f735bf1e8627adee2736ad34aabd5cbf7f63f0db475f79f93504`, at
this worktree's own HEAD `68130efd048f`) — the section naming exactly the
`full`-track file set REQ-002's own structural assertions (AC-005/AC-006)
compare against. Phase 2/3's own test harness intercepts generation at
this point: rather than invoking a live model to actually produce Phase 1
artifact content, it substitutes a pre-recorded response from the record
corpus (below) for the fixture under test, so every REQ-002 structural
assertion this package's Test Strategy item 4 names runs fully offline.

*Record corpus schema*: `structural-fixture-corpus/v1` (new, this
package's own addition — no live corpus exists yet, INV-017) — a
versioned directory of recorded-response fixtures, one JSON file per
fixture-matrix cell this suite exercises (F1/F2 now; F3/F4 once Epic A1
merges), each carrying `{schema: "structural-fixture-corpus/v1",
fixture_state, recorded_at_model, recorded_at_commit, artifacts: [{path,
content}]}` — `artifacts[].content` is the exact Markdown/frontmatter text
the fixture asserts against, never a live-generated value. A
`refresh_procedure` field records how AC-031's own non-gating live-model
refresh test regenerates this corpus (never the gating suite).

*Parser failure is a hard fail*: if the AST canonicalizer (below) fails
to parse a recorded artifact's own frontmatter or Markdown structure
(malformed YAML frontmatter, a heading line the canonicalizer's own
grammar does not recognize), that is itself a suite failure — never a
silent skip, never a partial-comparison fallback — matching this
package's own "no observable silently degrades" discipline (Constraint
Compliance).

*Heading/order/frontmatter normalization algorithm* (AC-030's own "AST
canonicalizer," now specified): given a Markdown artifact's own raw text,
(1) parse YAML frontmatter (the `---`-delimited block) into a key-value
map and sort its own top-level keys lexicographically (byte-order, UTF-8)
before comparison — frontmatter key *order* in the raw file is never
itself compared, only the resulting sorted key/value map; (2) parse the
remaining Markdown body into a heading tree via `#`-level ATX headings
only (this package's own templates, INV-018/INV-024, use no Setext
headings) and compare heading *text* and *level* in document order —
heading order in the body IS compared (unlike frontmatter key order),
since REQ-002's own "required headings" target (decision doc §4.2) is
order-sensitive to the templates' own section sequence; (3) normalize
whitespace by collapsing every run of horizontal whitespace to a single
space and stripping trailing whitespace per line, and normalize line
endings to LF, before either the frontmatter or heading comparison —
never comparing raw, un-normalized bytes (that is REQ-001's own
byte-identical target, a disjoint comparison class, Data Plan
Observable×fixture-state table).

**OQ-001 resolved: Epic A5's three deferred `resolve-project-context-caller-contract`
fixture assertions are owned by this epic's own existing suite.** A5's
own `design.md` item 10 already fixes the fixture-level contract for (a)
anchor-fingerprint drift, (b) Context-absent Resolver-non-invocation, and
(c) Block-surfaces-not-fallback (`FP-A5-CALLER-CONTRACT-10`, above).
None of the three
needs its own cap/round/terminal lifecycle either — (a) is a static drift
check, (b) is the identical spy mechanism AC-004 already specifies, and
(c) is a stop-event assertion the canonical trace schema's
`skip-stop-message`/`quality-gate-outcome` kinds already represent. This
package therefore authors all three as `TEST` sub-cases inside
`TEST-018`/`TEST-019` (Test Strategy item 6) rather than deferring them to
Epic A6 or inventing a new suite — closing OQ-001 in this package, not
leaving it for a future task to guess at.

**OQ-002 resolved: `PROJECT_CONTEXT_INVALID` is a required negative
variant of each Context-present fixture row, never a fifth top-level
matrix state.** A1's own validator contract already fixes this outcome
precisely (`specs/epic-189-a1-project-context/requirements.md:891-921,1836-1847`,
read from sibling worktree `sdd-forge-wt-epic-189`): it is reached only
when `sdd/project-context.yaml` is physically present but fails
validation — a variant *of* the present states (F3/F4), never a distinct
combination row decision doc §6 itself does not name. Folding it into
F3-invalid/F4-invalid (rather than a hypothetical F9) keeps the matrix's
own row count anchored to decision doc §6's own eight rows (Compatibility
Matrix, Data Plan) while still giving the outcome independent AC/TEST
coverage (AC-019–AC-021).

**`emit-run-record.sh`'s capability-only combination is a usage error,
and `block_id` is adopted now.** A `capability` object with no `effort`
object would be the first `sdd-run-record/v2` shape this script ever
emits without effort data — but every existing `v2` consumer (WFI
attribution analysis, INV-006's own stated purpose) reads `effort` as
the primary v2 payload; a capability-only record would be a `v2`-shaped
file some consumers cannot meaningfully use. Treating it as a usage error
(API / Contract Plan table) rather than inventing a third schema version
keeps the version space at exactly `{v1, v2}` (INV-006), matching this
script's own existing fail-closed argument-validation style
(`require_effort_control_value`, `:45-54`). `block_id` is fixed as an
optional field now, not deferred, because A5's own 16-value enum
(`FP-A5-BLOCK-REQ002`, "Cross-epic fingerprint citations," above) already
exists as a citable source of truth — there is no remaining unknown this
package would need a later "if Phase 2 needs it" escape hatch for.

**Golden-baseline location (OQ-003, resolved): `specs/epic-195-a7-compatibility/verification/golden-baseline/`,
split into `canonical/` (committed) and a gitignored `candidate/`.**
This repository already places per-feature verification evidence under
`specs/<feature>/verification/` (e.g. `specs/epic-159-pillar-a/verification/`,
`specs/epic-136-phase1-guards/verification/` — both present in this
worktree's `specs/` tree today). A compatibility golden baseline is
feature-scoped evidence for this epic specifically, not a repository-wide
fixture shared by unrelated features, so the existing per-feature
convention applies directly rather than inventing a new shared-fixtures
top-level directory; the `canonical/`/`candidate/` split is this
package's own addition to that convention, implementing REQ-006c's
two-stage update procedure. This closes OQ-003 as a decision, not merely
a recommendation (correcting an earlier draft's "recommendation, not a
foreclosure" framing) — a future maintainer proposing the alternative
shared `tests/fixtures/compatibility-baseline/` location does so via an
explicit revision to this paragraph, the same discipline this package's
own fingerprint-citation update procedure already requires elsewhere
("Cross-epic fingerprint citations," above), never a silent Phase-2
substitution. The path's own structural protection from CI writes is
fixed by `promote-golden-baseline.sh`'s own `CI`-env-var/`--approved-by`
guards and the AC-040 CI-workflow-scan check (API / Contract Plan,
"Golden-baseline capture/promote contract").

**`capability_applicability` starts on `quality-gate` only, not every
entry.** Per decision doc §3.1, Capability Coverage is a `quality-gate`
(Implementation Gate) common check item; none of the four review-loop
prechecks (`spec-review-precheck.sh` etc., INV-001) reads
`workflow.capability_enforcement` in any cited decision-doc or ADR text.
Extending every entry pre-emptively would assert a fact this package
cannot cite evidence for (WFI-011); Phase 2/3 revisits this once Epic A2's
Registry schema (which defines where else `capability_enforcement` is
consulted) merges. This scoping is also the direct basis for AC-039's
per-component disabled-legacy table: only `quality-gate` carries this
field, so only `quality-gate`'s own event kind is asserted against it —
the Resolver's own disabled-legacy behavior (no invocation at all,
INV-009/INV-015) is defined independently and never forced into this same
shape.

**F7/F8 (`facet-hybrid`/`facet-native`) are `N/A`, not `SKIP`, in the
Compatibility Matrix.** A `SKIP` implies an activation condition that
will eventually become true and unblock the assertion (REQ-007's
allowlist manifest, AC-034); no Foundation epic (A0–A9, decision doc §19)
ever produces `facet-native`, and `facet-hybrid` is reached only after
`facet-hybrid` itself "has an operational track record" (ADR-0016
Decision item 2) — a condition this epic's own Phase 3 cannot make true
by merging anything. Marking these `N/A` with a stated rationale (rather
than a `SKIP` with no real activation condition, or silent omission) is
what AC-028 requires.

## Global Constraints

- No edits to `plugins/**`, `scripts/**`, `.github/**`, `tests/**`,
  `contracts/**`, or `docs/**` in this task.
- No new `loop-inventory` entry (`id`); capability events extend existing
  entries because they share `quality-gate`'s own lifecycle (Design
  Decisions, above) — this is the design's own basis for the constraint,
  never `loop-inventory.tests.sh`'s current `length == 8` assertion value
  (INV-002's caveat), which a future, unrelated loop-shaped surface could
  in principle still require revisiting via an ADR-0010 revision
  (requirements.md Non-goals).
- No tasks.md/traceability.md in this Phase 1 package.

## Security Boundaries

| Trust Boundary | Auth/Authz Mechanism | Data Classification | OWASP Concerns |
|---|---|---|---|
| B1: golden-baseline capture/update | `--write-candidate` produces only a gitignored candidate file (API / Contract Plan); the canonical file is written exclusively by `promote-golden-baseline.sh`, run only inside a maintainer-reviewed pull request (REQ-006c); CI is structurally, not merely conventionally, blocked from invoking the promote command — the script itself exits non-zero when the `CI` environment variable is set and refuses to run without an explicit `--approved-by <human-identifier>` flag (API / Contract Plan), AC-040's static check independently verifies `.github/workflows/test.yml` never references `promote-golden-baseline.sh`/`--write-candidate` at all, and AC-041 exercises the script's own `CI`/`--approved-by` runtime refusal directly rather than only inferring it from AC-040's static text scan | repository fixture/script output only, no secrets | Broken Access Control (unreviewed baseline drift) if the candidate/canonical separation, the `CI`-env-var/`--approved-by` guards, the AC-040 workflow scan, or the AC-041 runtime-refusal fixtures were ever simultaneously bypassed |
| B2: shared-registry/driver/run-record extension | future-task edits reviewed with the same rigor as a protected-file change (requirements.md Security Boundaries B2) even though not formally protected today | none | Improper cross-epic coordination risk, not a traditional OWASP class |
| B3: REQ-007 allowlist manifest integrity | the manifest itself is a versioned repository file reviewed like any other test-infrastructure change; AC-035's fingerprint-drift check is this boundary's own detection mechanism, not merely documentation | none | Silent scope drift (a `SKIP` outliving its own justification) if the manifest were edited without re-verifying its cited fingerprints |

## External Integrations

None. Every target in this package is internal to the repository
(existing scripts, schemas, templates, and the future golden baseline).

## Deployment / CI Plan

No CI change in this task. Phase 2/3's future registration (Test
Strategy, item 9) follows the exact pattern already used for the four
Pillar-A loop suites: `tests/run-all.sh` and `.github/workflows/test.yml`
for the `.sh` twin, `tests/run-all.ps1` and `.github/workflows/test.yml`
for the `.ps1` twin (investigation.md INV-005 citing the concrete
existing lines). CI's own job step never calls
`capture-golden-baseline.sh --write-candidate` or
`promote-golden-baseline.sh` (Security Boundaries B1) — only the default,
read-only diff-check invocation; AC-040's static check makes this a
verified property of the committed `test.yml` text itself, not only an
authoring intention. The AC-031 live-model structural-comparison refresh
test is registered as a separate, non-gating job (or omitted from CI
entirely and run manually), never inside the gating `test.yml` entries
above.

## Constraint Compliance

| Requirement Constraint | Design Response |
|---|---|
| No new loop-inventory entry (Non-goals) | `capability_applicability` is an additive field on the existing `quality-gate` entry only, justified by the independent-lifecycle argument, not the current `length == 8` value (Data Plan; Design Decisions) |
| No new test-suite file (REQ-003) | `TEST-019` extends `tests/loop-escalation.tests.sh`; `TEST-018` extends `tests/loop-consistency.tests.sh` (Design Decisions) — both existing files |
| `assert_terminal`/`assert_artifacts_schema` unmodified (AC-009) | the new `capability_applicability` field is read only by the new `assert_capability_applicability` helper (API / Contract Plan) |
| `emit-run-record.sh` no-flag output stays byte-identical (AC-011) | new `capability` object gated behind an independent `emit_capability` flag, mirroring `emit_v2`'s own proven isolation (INV-006); capability-only is a usage error, never a third schema version (Design Decisions) |
| Every upstream-dependent assertion has a named, auditable degradation (REQ-007) | `SKIP` lines are read from the single allowlist manifest (Data Plan), which AC-035's three hard-fail checks keep honest in both directions |
| `PROJECT_CONTEXT_INVALID` is distinguishable in the event trace (Edge Cases) | a dedicated `skip-stop-message`/`quality-gate-outcome`-kind event, asserted by AC-019–AC-021, never reused from the Context-absent fallback trace |
| Golden baseline cannot be silently regenerated (REQ-006) | `--write-candidate` never writes the canonical path; only `promote-golden-baseline.sh` inside a reviewed PR does, and that script structurally refuses to run under `CI` or without `--approved-by` (API / Contract Plan; Security Boundaries B1); AC-040 independently verifies CI's own workflow file never references either command, and AC-041 exercises the script's own runtime refusal directly |
| Cross-epic citations cannot silently drift undetected (finding 10, NEW-001) | every normative Epic A5 citation is a fingerprint (source, line range, sha256 digest, quote — Design Decisions "Cross-epic fingerprint citations"), recomputed by the REQ-007 allowlist manifest's own `fingerprint_match` evaluator (Data Plan) |

## Assumptions

Same as requirements.md Assumptions: Epics A1/A3/A5 remain unmerged and in
active spec/task-review; A4 has passed `spec-review-loop` but is also
unmerged; A6 is in active spec-review; facts cited from any of them may
shift before Phase 2 — the exact drift AC-035's fingerprint-mismatch
hard-fail is designed to catch. ADR-0010/0016/0023 and decision doc
§4/§6/§19 remain authoritative and unrevised; `jq`/bash/PowerShell remain
the available deterministic runtimes.

## Open Questions

OQ-001 (Epic A5 caller-contract suite's home), OQ-002
(`PROJECT_CONTEXT_INVALID` as a fifth fixture-matrix state), and OQ-003
(golden baseline's exact physical path) are all three resolved by this
design (Design Decisions, above) and by requirements.md's own
corresponding Open Questions entries — none carries forward as an open
recommendation; a future maintainer proposing a different golden-baseline
path does so via an explicit revision to the Design Decisions paragraph
that fixes it, not a silent Phase-2 substitution.

## Risks

Same three risks as requirements.md Risks section, with this design's own
added mitigation: the "shared-surface blast radius" risk (requirements.md
Risks, High) is narrowed by this design's own decision to touch exactly
one existing `loop-inventory` entry (`quality-gate`) and two existing
suites (`tests/loop-escalation.tests.sh`, `tests/loop-consistency.tests.sh`
— not every entry/suite at once) in Phase 2/3's first increment — a
smaller, independently reviewable first change. The Critical risk
(requirements.md Risks) is further mitigated by this design's own
allowlist-manifest fingerprint-drift check (Data Plan; AC-035c), which
converts an upstream epic's silent contract drift into a hard suite
failure rather than a passing `SKIP` nobody re-examines.
