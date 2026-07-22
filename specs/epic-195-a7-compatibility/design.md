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
| `tests/lib/loop-driver.sh` | shared source-style driver (INV-003) | add one new public assertion function, `assert_capability_applicability` (API / Contract Plan), alongside the existing `assert_terminal` (AC-009 — neither `assert_terminal` nor `assert_artifacts_schema` itself changes); add one new public comparison function, `assert_event_trace` (API / Contract Plan), that compares an observed `compatibility-event-trace/v1` value against a recorded golden trace | existing, extended (future task) |
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
| requirements.md | investigation.md INV-022 | golden baseline is captured once against a fixed pre-capability merge-base commit and updated only via a candidate→canonical PR | REQ-006 | AC-001, AC-018 |
| requirements.md | investigation.md INV-023 | the SKIP allowlist manifest closes the fail-open direction (dependency-present SKIP, unknown SKIP, fingerprint drift) and enumerates A1–A6 | REQ-007 | AC-004, AC-007, AC-016, AC-034, AC-035 |
| requirements.md | investigation.md INV-014 | the three-state Gate-applicability pattern is scoped to `check-component-coverage`; the Resolver's own disabled-legacy behavior is independently defined | REQ-003 | AC-009, AC-039 |
| requirements.md | investigation.md INV-016 | Epic A5's three deferred fixture assertions are owned by this epic's own existing suite, not a new suite | REQ-003 | AC-004, AC-021, AC-036, AC-037 |
| design.md Design Decisions | requirements.md OQ-001–OQ-003 | suite placement (split loop-consistency/loop-escalation), baseline location, and the A5 caller-contract suite's home (resolved) are fixed below; OQ-003 remains a recommendation, not a foreclosure | REQ-003, REQ-006 | AC-001, AC-010, AC-032, AC-036, AC-037 |

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
observed event, each carrying `{kind, producer, seq, value}`. `kind` is
one of the six Field-Definitions canonical event kinds
(requirements.md); `seq` is this trace's own 1-based ordinal position
(the ordering rule below); `value` is kind-specific and is compared after
the per-kind normalization rule fixes which of its own sub-fields are
required, ignored, or canonicalized:

| Event kind | Producer (existing, unless noted) | Ordering rule | Value-normalization |
|---|---|---|---|
| `skill-order` | the fixture drive's own invocation log (new: `assert_event_trace` records each `drive_review_round`/script-invocation call as it happens, `tests/lib/loop-driver.sh:1468-1488`) | one event per invocation, in call order | `value` = script/skill identifier only; working-directory-relative paths canonicalized, no timestamp |
| `review-loop-presence` | `drive_review_round`'s own `stage` dispatch (`tests/lib/loop-driver.sh:1478-1487`) | one event per stage actually driven, in dispatch order | `value` = `stage` name only (`spec\|impl\|task\|domain`); a stage never dispatched emits no event (absence is the signal, never a placeholder) |
| `approval-checkpoint` | the shared driver's review-context reservation/ledger-write call (`_loop_reserve_review_context`, INV-003) | one event per reservation call, in call order | `value` = `{stage, role}` only; `run_id`/`host_session_id`/ledger hash fields are ignored (fixture-random, never compared) |
| `quality-gate-outcome` | `check-quality-gate-cycle-limit.sh`/`select-agent-model.sh` escalation decision (INV-005) plus the new `capability_applicability` observation (`assert_capability_applicability`, INV-014/AC-039) | one event per escalation decision plus, when the fixture state is capability-aware, exactly one `capability_applicability` event, always last within this kind | `value` = `{next_tier}` or `{applicability}` only; wall-clock fields ignored |
| `done-transition` | `assert_terminal`'s own observed-vs-expected comparison (`tests/lib/loop-driver.sh:1512-1518`, INV-004) | always the last event in its own round's event sub-sequence | `value` = `.terminal.state` string only |
| `skip-stop-message` | `loop_validator_skip`'s existing named-SKIP pattern (`tests/lib/loop-driver.sh:460-519`, INV-005) extended by the REQ-007 allowlist manifest (below) | emitted wherever a `SKIP`-degraded assertion fires within the driven round, in fire order | `value` = the fixed, cited-issue-number template string only — never free text |

A **golden trace** is a committed, versioned fixture of this schema's own
output for a given fixture-matrix cell (design.md Test Strategy). **Trace
identity** between an observed and a golden trace requires: identical
`kind` sequence (by `seq` order), identical per-event `value` after
normalization, and identical total event count — any extra, missing, or
reordered event is a mismatch, never silently ignored.

**Compatibility Matrix** (REQ-005/AC-028; every valid decision doc §6 row
crossed with each test kind):

| Row | Combination | REQ-001 (byte) | REQ-002 (structural) | REQ-003 (orchestration) |
|---|---|---|---|---|
| F1 | Context absent, `full`/legacy-seven-layer/non-active | ASSERT (AC-003, AC-004) | ASSERT (AC-005, AC-006) | ASSERT (AC-022–024, AC-032) |
| F2 | Context absent, `lite`/lite-three-file/non-active | ASSERT (AC-003) | ASSERT (AC-005, AC-006) | ASSERT (AC-022–024, AC-032) |
| F3 | Context present, `full`/legacy-seven-layer/advisory | N/A (byte-identical is a Context-absent-only target, REQ-001) | SKIP until A1 merges (AC-034) | SKIP until A1 merges (AC-034) — `capability_applicability` is a static translation of `workflow.capability_enforcement` alone, ADR-0016, not a Registry-derived value; F3-invalid variant ASSERT/SKIP per AC-019–021 |
| F4 | Context present, `full`/legacy-seven-layer/required | N/A (same as F3) | SKIP until A1+A4 merge (AC-007, AC-034) | SKIP until A1 merges (AC-034) — identical dependency to F3, only the asserted value differs; F4-invalid variant ASSERT/SKIP per AC-019–021 |
| F5 | Context present, `lite`/lite-three-file/advisory | N/A | SKIP until A1+A6 merge (AC-034) | SKIP until A1+A6 merge (AC-034) |
| F6 | Context present, `lite`/lite-three-file/required | N/A | SKIP until A1+A6 merge (AC-034) | SKIP until A1+A6 merge (AC-034) |
| F7 | Context present, `full`/facet-hybrid/required | N/A | N/A — no Foundation epic produces `facet-hybrid` before this epic's own Phase 3 (ADR-0016 item 2) | N/A — same rationale |
| F8 | Context present, `full`/facet-native/required | N/A | N/A — no Foundation epic (A0–A9) ever produces `facet-native` (decision doc §19) | N/A — same rationale |

Context-absent CLI submatrix (REQ-005; both cells of F1/F2 are members of
this six-cell block, ASSERT via AC-003/AC-014):

| CLI flag | `AGENTS.md` marker present | `AGENTS.md` marker absent |
|---|---|---|
| none | LITE (F2) | FULL (F1) |
| `--full` | FULL | FULL |
| `--lite` | LITE | LITE |

**Observable×fixture-state judgment table** (AC-029; byte vs. event,
mutually exclusive and exhaustive over the ASSERT cells above): script
output / exit code / stdout·stderr / template copy / schema validator /
install / uninstall / directory listing / plugin manifest are
**byte-identical** observables for every ASSERT cell in the F1/F2 columns
(REQ-001's own target list, decision doc §4.1) — never event-compared.
Skill-invocation order / review-loop presence / approval checkpoint /
quality-gate outcome / Done-transition / skip-stop message are
**event-identical** observables for every ASSERT cell across all rows
(REQ-003) — never byte-compared (their own underlying artifacts may
legitimately differ byte-for-byte, e.g. timestamps). Generated-artifact
structure (file count, frontmatter, headings, status, `REQ`/`AC` IDs) is a
**structural** observable (REQ-002, AC-030) — compared through the AST
canonicalizer, never raw bytes and never the event schema. No observable
appears in more than one of these three columns.

**`PROJECT_CONTEXT_INVALID` variant plan** (REQ-005/AC-019–021): the
fixture-matrix builder's `valid_or_invalid` parameter (API / Contract
Plan) produces, for F3/F4 only, a `sdd/project-context.yaml` that parses
as YAML but fails Epic A1's own schema/hash/HMAC validator by exactly one
deliberately-broken field (design.md's own future-task fixture chooses
which, e.g. a corrupted `content_hash`) — never a syntactically invalid
YAML file, so the failure is provably the validator's own semantic
rejection, not a parse error a different code path would also reject.

**REQ-007 SKIP allowlist manifest** (AC-034/AC-035): a single JSON array,
one entry per upstream-dependent assertion:

```jsonc
[
  {
    "assertion_id": "AC-004",
    "epic": "A5",
    "issue": 193,
    "contract_fingerprint": "specs/epic-193-a5-capability-resolver/design.md:1861-1890#item-10b",
    "activation_condition": "spec_review_status(epic-193) != Pending AND branch_merged(feature/epic-193-a5-capability-resolver)"
  }
]
```

The suite reads this manifest to emit every `SKIP` line (never a free-text
message composed ad hoc); AC-035's three hard-fail checks (dependency-
present SKIP, unknown SKIP, fingerprint drift) are computed directly
against this manifest's own recorded `activation_condition` and
`contract_fingerprint` fields.

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

**`assert_event_trace <golden-trace-path> <observed-trace-json>`**
(proposed new public function, `tests/lib/loop-driver.sh`, alongside
`assert_capability_applicability`): compares an observed
`compatibility-event-trace/v1` value (accumulated by the calling suite as
it drives a round, per the Data Plan producer table above) against a
committed golden-trace fixture, applying each event kind's own
value-normalization rule before comparison, and fails on any `kind`-
sequence, `value`, or event-count mismatch (Data Plan "Trace identity").
This is the single function both `TEST-018` (`loop-consistency`) and
`TEST-019` (`loop-escalation`) call, so both suites compare against one
oracle (REQ-003c).

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
16-value Block-diagnostic-id enum (`specs/epic-193-a5-capability-resolver/requirements.md:334-349`)
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
2. `promote-golden-baseline.sh <candidate-path>` — copies a candidate to
   the canonical path, run only inside a dedicated pull request a human
   maintainer reviews and merges (REQ-006c); never invoked by CI
   (Security Boundaries B1).

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
   (INV-018), run through the deterministic recorded-response seam and
   AST canonicalizer (AC-030) — never a live model call in this gating
   suite (a separate, non-gating live-model refresh test is authored
   independently, AC-031) — asserting the Context-present states produce
   zero capability/Facet artifacts until Epic A4 lands (named `SKIP`,
   AC-007).
5. Canonical event-trace schema implementation (REQ-003, Data Plan): the
   `capability_applicability` field added to `quality-gate`'s own
   `loop-inventory` entry; `assert_capability_applicability` and
   `assert_event_trace` added to the shared driver; `TEST-019` added to
   `tests/loop-escalation.tests.sh` (quality-gate-outcome kind) and
   `TEST-018` added to `tests/loop-consistency.tests.sh`
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
   registration set.

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

**OQ-001 resolved: Epic A5's three deferred `resolve-project-context-caller-contract`
fixture assertions are owned by this epic's own existing suite.** A5's
own `design.md` item 10 already fixes the fixture-level contract for (a)
anchor-fingerprint drift, (b) Context-absent Resolver-non-invocation, and
(c) Block-surfaces-not-fallback (`specs/epic-193-a5-capability-resolver/design.md:1861-1890`,
read from sibling worktree `sdd-forge-wt-epic-193`). None of the three
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
(`specs/epic-193-a5-capability-resolver/requirements.md:334-349`) already
exists as a citable source of truth — there is no remaining unknown this
package would need a later "if Phase 2 needs it" escape hatch for.

**Golden-baseline location: `specs/epic-195-a7-compatibility/verification/golden-baseline/`,
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
two-stage update procedure. This resolves OQ-003 as this package's own
recommendation (requirements.md OQ-003 remains formally open for a
maintainer to override before Phase 2, but is not left undecided here).

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

**Left open (not resolved here):** OQ-003 (golden baseline's exact
physical path) — this design fixes a recommendation above but leaves the
tradeoff formally open per requirements.md, since it does not block this
Phase 1 package's own completion and a maintainer may still prefer the
shared `tests/fixtures/compatibility-baseline/` alternative before Phase
2 begins.

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
| B1: golden-baseline capture/update | `--write-candidate` produces only a gitignored candidate file (API / Contract Plan); the canonical file is written exclusively by `promote-golden-baseline.sh`, run only inside a maintainer-reviewed pull request (REQ-006c); CI never invokes the promote command | repository fixture/script output only, no secrets | Broken Access Control (unreviewed baseline drift) if the candidate/canonical separation or the promote-only-in-PR rule were ever bypassed |
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
read-only diff-check invocation. The AC-031 live-model structural-
comparison refresh test is registered as a separate, non-gating job (or
omitted from CI entirely and run manually), never inside the gating
`test.yml` entries above.

## Constraint Compliance

| Requirement Constraint | Design Response |
|---|---|
| No new loop-inventory entry (Non-goals) | `capability_applicability` is an additive field on the existing `quality-gate` entry only, justified by the independent-lifecycle argument, not the current `length == 8` value (Data Plan; Design Decisions) |
| No new test-suite file (REQ-003) | `TEST-019` extends `tests/loop-escalation.tests.sh`; `TEST-018` extends `tests/loop-consistency.tests.sh` (Design Decisions) — both existing files |
| `assert_terminal`/`assert_artifacts_schema` unmodified (AC-009) | the new `capability_applicability` field is read only by the new `assert_capability_applicability` helper (API / Contract Plan) |
| `emit-run-record.sh` no-flag output stays byte-identical (AC-011) | new `capability` object gated behind an independent `emit_capability` flag, mirroring `emit_v2`'s own proven isolation (INV-006); capability-only is a usage error, never a third schema version (Design Decisions) |
| Every upstream-dependent assertion has a named, auditable degradation (REQ-007) | `SKIP` lines are read from the single allowlist manifest (Data Plan), which AC-035's three hard-fail checks keep honest in both directions |
| `PROJECT_CONTEXT_INVALID` is distinguishable in the event trace (Edge Cases) | a dedicated `skip-stop-message`/`quality-gate-outcome`-kind event, asserted by AC-019–AC-021, never reused from the Context-absent fallback trace |
| Golden baseline cannot be silently regenerated (REQ-006) | `--write-candidate` never writes the canonical path; only `promote-golden-baseline.sh` inside a reviewed PR does (API / Contract Plan; Security Boundaries B1) |

## Assumptions

Same as requirements.md Assumptions: Epics A1/A3/A5 remain unmerged and in
active spec/task-review; A4 has passed `spec-review-loop` but is also
unmerged; A6 is in active spec-review; facts cited from any of them may
shift before Phase 2 — the exact drift AC-035's fingerprint-mismatch
hard-fail is designed to catch. ADR-0010/0016/0023 and decision doc
§4/§6/§19 remain authoritative and unrevised; `jq`/bash/PowerShell remain
the available deterministic runtimes.

## Open Questions

OQ-001 (Epic A5 caller-contract suite's home) and OQ-002
(`PROJECT_CONTEXT_INVALID` as a fifth fixture-matrix state) are resolved
by this design (Design Decisions, above) and by requirements.md's own
corresponding Open Questions entries. OQ-003 (golden baseline's exact
physical path) carries forward as a recommendation, not a foreclosure
(Design Decisions, above); owner: maintainers. It does not block this
Phase 1 package's own completion.

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
