# Design: epic-195-a7-compatibility

Impl-Review-Status: Pending
Feature Type: test-infrastructure specification (Phase 1 — no code)

## Technical Summary

Epic A7 adds three compatibility test kinds around the eventual
capability machinery (Epics A1–A6) without building that machinery itself
and, per decision doc §4.3/§19, without building a parallel test harness.
This package's design is therefore a set of precise, additive extension
points onto four already-existing files
(`tests/loops/loop-inventory.json`, `tests/lib/loop-driver.sh`,
`tests/loop-consistency.tests.sh` or `tests/loop-escalation.tests.sh`,
`plugins/sdd-quality-loop/scripts/emit-run-record.sh` — investigation.md
INV-001–INV-006), a golden-baseline governance procedure, and a 4-state
fixture matrix. No file outside `specs/epic-195-a7-compatibility/` is
edited by this task; the extension points below are a specification for a
later Phase 2/3 task, cited by exact file:line insertion target where the
current file content makes that possible.

## Architecture

```mermaid
flowchart TB
  subgraph Fixture matrix (REQ-005)
    F1["Context absent\n(full/legacy-seven-layer/disabled-legacy)"]
    F2["Context absent + AGENTS lite marker\n(lite/lite-three-file/disabled-legacy)"]
    F3["Context present, advisory"]
    F4["Context present, required"]
  end

  F1 --> BI["Byte-identical test (REQ-001)"]
  F1 --> SC["Structural compatibility test (REQ-002)"]
  F2 --> BI
  F2 --> SC
  F3 --> OE["Orchestration event test (REQ-003)"]
  F4 --> OE
  F3 --> SC
  F4 --> SC

  BI --> GB["Golden baseline\n(REQ-006, human-reviewed)"]
  BI -.extends.-> INST["tests/install.tests.sh /\ntests/uninstall.tests.sh (INV-007)"]

  OE -.extends.-> LI["tests/loops/loop-inventory.json\n(INV-001, INV-002)"]
  OE -.extends.-> LD["tests/lib/loop-driver.sh\n(INV-003, INV-004)"]
  OE -.new TEST-0NN in.-> LE["tests/loop-escalation.tests.sh\n(INV-005)"]
  OE -.extends.-> ERR["emit-run-record.sh\n(INV-006, effort-object pattern)"]

  LI --> LIT["loop-inventory.tests.sh\nregistration forcing (INV-002)\n8-entry count unchanged (AC-008)"]
```

## Components

| Component | Responsibility | Change | New/Existing |
|---|---|---|---|
| `tests/loops/loop-inventory.json` | single loop registry (INV-001) | add one additive, optional field per relevant entry (`capability_applicability`, Data Plan) — no new `id`, entry count stays 8 (AC-008) | existing, extended (future task) |
| `tests/lib/loop-driver.sh` | shared source-style driver (INV-003) | add one new public assertion function, `assert_capability_applicability` (API / Contract Plan), alongside the existing `assert_terminal` | existing, extended (future task) |
| `tests/loop-escalation.tests.sh` | quality-gate escalation chain suite (INV-005) | add `TEST-019` (Design Decisions, below, resolves REQ-003's suite-placement question) driving a fixture-matrix state through the shared driver and asserting the capability applicability event trace | existing, extended (future task) |
| `plugins/sdd-quality-loop/scripts/emit-run-record.sh` | deterministic run-record emitter (INV-006) | add `--capability-enforcement <disabled-legacy\|advisory\|required>` (and, if Phase 2 needs it, `--capability-block-id <id>`), gated exactly like `--effort-*` (`emit_v2`), emitting an additive `capability` sibling object only when supplied | existing, extended (future task) |
| `tests/install.tests.sh` / `tests/uninstall.tests.sh` | existing byte-identical-style install/uninstall suites (INV-007) | add fixture cases asserting install/uninstall output is unaffected by `project-context.yaml` presence/absence (byte-identical target, decision doc §4.1) | existing, extended (future task) |
| golden-baseline fixture set (REQ-006, location fixed by Design Decisions below) | pinned byte-for-byte legacy output snapshot + capture script | new | new (future task) |
| fixture-matrix builder (name/location fixed by Design Decisions below) | constructs the 4 named fixture states (REQ-005) | new | new (future task) |
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
| requirements.md | investigation.md INV-002 | 8-entry `loop-inventory` count is preserved; capability events are additive fields, not a new loop `id` | REQ-003 | AC-008, AC-009 |
| requirements.md | investigation.md INV-006 | `emit-run-record.sh` capability object follows the existing `effort` v1/v2 additive-flag pattern exactly | REQ-003 | AC-011, AC-012 |
| requirements.md | investigation.md INV-011 | 4-state fixture matrix maps 1:1 to decision doc §6's combination-matrix rows | REQ-005 | AC-014 |
| requirements.md | investigation.md INV-013–INV-016 | every Context-present assertion is a named `SKIP` until its cited upstream epic merges | REQ-007 | AC-004, AC-007, AC-016 |
| design.md Design Decisions | requirements.md OQ-001–OQ-003 | suite placement, baseline location, and the deferred A5 caller-contract suite's home are resolved or explicitly left open below | REQ-003, REQ-006 | AC-001, AC-010 |

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
per entry, optional, absent = not capability-aware):

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
(disabled-legacy)"` — INV-014), so `quality-gate`'s own future Capability
Coverage check item (decision doc §3.1) reports applicability with the
identical vocabulary rather than inventing a second one. Only entries
whose own gate reads `workflow.capability_enforcement` at all get this
field; today that is provisionally `quality-gate` only (Design Decisions,
below) — every other entry stays exactly as INV-001 records it.

## API / Contract Plan

**`assert_capability_applicability <loop-id> <fixture-state> <observed>`**
(proposed new public function, `tests/lib/loop-driver.sh`, alongside the
existing `assert_terminal` at `tests/lib/loop-driver.sh:1453-1459`,
INV-004): reads `.loops[] | select(.id == $loop_id) | .capability_applicability[$fixture_state]`
from `$LOOP_INVENTORY_PATH` (identical lookup pattern to `assert_terminal`,
so no other driver code needs to change) and compares it to `$observed`.
`fixture_state` is one of `disabled-legacy \| advisory \| required`
(the Field Definitions vocabulary requirements.md fixes, matching
ADR-0016's derived-state naming exactly).

**`emit-run-record.sh` proposed flag** (mirrors `--effort-main`'s exact
gating, INV-006):

```
--capability-enforcement <disabled-legacy|advisory|required>
```

emits, only when supplied (setting a new `emit_capability=1` alongside the
existing `emit_v2` — the two are independent, so a run may supply neither,
either, or both):

```jsonc
"capability": {
  "enforcement": "advisory",
  "block_id": null
}
```

The no-flag path's heredoc is untouched (byte-identical, AC-011); this is
the same guarantee INV-006 already documents for the `effort` object's own
introduction, applied a second time for capability fields.

**Golden-baseline capture contract** (REQ-006/AC-001/AC-018; script name
and exact location fixed by Design Decisions, below): a single, idempotent
script that (a) runs every REQ-001 target (script output, install,
uninstall, template copy, schema validation) against a Context-absent
fixture built by the fixture-matrix builder, (b) records each target's
output plus its own sha256, the capturing commit SHA, and the fixed
environment variables used, and (c) writes nothing unless invoked with an
explicit `--write` flag — a bare invocation only diffs against the
existing committed baseline and exits non-zero on drift, so accidental
baseline regeneration during normal test runs is structurally impossible.

## Test Strategy

Phase 2/3 (not this task) implements, in this order:

1. Fixture-matrix builder (REQ-005/AC-014): four named builder functions,
   one per matrix state, following `loop_fixture_init`'s own
   `mktemp -d` + physical-path-normalization + outside-repo-root assertion
   pattern (`tests/lib/loop-driver.sh:106-141`) so fixtures never touch
   the real working tree.
2. Golden-baseline capture (REQ-006/AC-001/AC-018), captured once against
   the `main` commit current at that time, committed under the location
   Design Decisions fixes below.
3. Byte-identical suite extension (REQ-001): new fixture cases added to
   `tests/install.tests.sh`/`tests/uninstall.tests.sh` (INV-007) plus a
   diff-against-golden-baseline check for the remaining §4.1 targets
   (script output, template copy, schema validator) — negative self-check
   required (AC-002), matching every existing suite's own convention
   (INV-002, INV-005).
4. Structural compatibility suite extension (REQ-002): a new fixture-set
   comparison against the existing seven-file legacy template set
   (INV-018), asserting the Context-present states produce zero
   capability/Facet artifacts until Epic A4 lands (named `SKIP`, AC-007).
5. Orchestration-event extension (REQ-003): the `capability_applicability`
   field (Data Plan) added to `quality-gate`'s own `loop-inventory` entry;
   `assert_capability_applicability` added to the shared driver; `TEST-019`
   added to `tests/loop-escalation.tests.sh` (Design Decisions).
6. `emit-run-record.sh` extension (REQ-003/AC-011/AC-012): the
   `--capability-enforcement` flag and `capability` object, verified
   byte-identical on the no-flag path against a pre-change capture.
7. Registration: every new/extended `.sh` suite's `.ps1` twin, plus
   `tests/run-all.sh`/`tests/run-all.ps1`/`.github/workflows/test.yml`
   entries (INV-005 pattern) — `.github/workflows/test.yml` is a CI file
   this repository has, in at least one precedent (Epic A5's own
   `human-copy/` staging for a `test.yml` registration alongside a
   protected-file batch, investigation.md cross-epic finding), treated as
   requiring staged/reviewed application rather than a direct agent edit;
   Phase 2/3 confirms whether that precedent applies here or whether
   `test.yml` is a directly-editable file in this repository's actual
   protected-file list at that time.

## Design Decisions (resolving requirements.md's Open Questions where possible)

**Suite placement for the orchestration-event `TEST-0NN` case:
`tests/loop-escalation.tests.sh`, not `tests/loop-consistency.tests.sh`.**
Decision doc §3.1 places "Capability Coverage" among quality-gate's own
common Implementation-Gate check items, not among any of the four
independent review loops (spec/impl/task/domain) `loop-consistency.tests.sh`
drives (INV-005). `loop-escalation.tests.sh` already drives quality-gate's
own scripts end-to-end (`TEST-011`, INV-005) and already carries the
`TEST-017`/`TEST-018` numbering precedent this task's `TEST-019` follows.
This resolves requirements.md's suite-placement half of REQ-003; it does
not resolve OQ-001 (the Epic A5 caller-contract suite's home), which
concerns a different (Resolver-invocation) event, not the quality-gate
Capability Coverage event this decision addresses.

**Golden-baseline location: `specs/epic-195-a7-compatibility/verification/golden-baseline/`.**
This repository already places per-feature verification evidence under
`specs/<feature>/verification/` (e.g. `specs/epic-159-pillar-a/verification/`,
`specs/epic-136-phase1-guards/verification/` — both present in this
worktree's `specs/` tree today). A compatibility golden baseline is
feature-scoped evidence for this epic specifically, not a repository-wide
fixture shared by unrelated features, so the existing per-feature
convention applies directly rather than inventing a new shared-fixtures
top-level directory. This resolves OQ-003.

**`capability_applicability` starts on `quality-gate` only, not every
entry.** Per decision doc §3.1, Capability Coverage is a `quality-gate`
(Implementation Gate) common check item; none of the four review-loop
prechecks (`spec-review-precheck.sh` etc., INV-001) reads
`workflow.capability_enforcement` in any cited decision-doc or ADR text.
Extending every entry pre-emptively would assert a fact this package
cannot cite evidence for (WFI-011); Phase 2/3 revisits this once Epic A2's
Registry schema (which defines where else `capability_enforcement` is
consulted) merges.

**Left open (not resolved here):**

- OQ-001 (Epic A5 caller-contract suite's eventual home) — genuinely
  depends on Epic A5's own implementation timeline and Epic A6's
  capability-interview-phase scope, neither of which this package
  controls.
- OQ-002 (`PROJECT_CONTEXT_INVALID` as a fifth fixture-matrix state) —
  depends on Epic A1's own validator error contract, which is still under
  spec-review in `sdd-forge-wt-epic-189` and may change before this
  package's Phase 2 begins.

## Global Constraints

- No edits to `plugins/**`, `scripts/**`, `.github/**`, `tests/**`,
  `contracts/**`, or `docs/**` in this task.
- No new `loop-inventory` entry (`id`); the 8-entry count is a locked
  invariant this task's own design must not violate even prescriptively
  (Components table proposes field additions to existing entries only).
- No tasks.md/traceability.md in this Phase 1 package.

## Security Boundaries

| Trust Boundary | Auth/Authz Mechanism | Data Classification | OWASP Concerns |
|---|---|---|---|
| B1: golden-baseline capture/update | `--write` flag required for any baseline mutation (API / Contract Plan); default invocation is read-only diff-check | repository fixture/script output only, no secrets | Broken Access Control (unreviewed baseline drift) if the `--write` gate were ever bypassed |
| B2: shared-registry/driver/run-record extension | future-task edits reviewed with the same rigor as a protected-file change (requirements.md Security Boundaries B2) even though not formally protected today | none | Improper cross-epic coordination risk, not a traditional OWASP class |

## External Integrations

None. Every target in this package is internal to the repository
(existing scripts, schemas, templates, and the future golden baseline).

## Deployment / CI Plan

No CI change in this task. Phase 2/3's future registration (Test
Strategy, item 7) follows the exact pattern already used for the four
Pillar-A loop suites: `tests/run-all.sh` and `.github/workflows/test.yml`
for the `.sh` twin, `tests/run-all.ps1` and `.github/workflows/test.yml`
for the `.ps1` twin (investigation.md INV-005 citing the concrete
existing lines).

## Constraint Compliance

| Requirement Constraint | Design Response |
|---|---|
| No new loop-inventory entry (Non-goals) | `capability_applicability` is an additive field on the existing `quality-gate` entry only (Data Plan) |
| No new test-suite file (REQ-003) | `TEST-019` is added to the existing `tests/loop-escalation.tests.sh` (Design Decisions) |
| `emit-run-record.sh` no-flag output stays byte-identical (AC-011) | new `capability` object gated behind an independent `emit_capability` flag, mirroring `emit_v2`'s own proven isolation (INV-006) |
| Every Context-present assertion has a named degradation (REQ-007) | `SKIP` lines cite the specific tracking issue per upstream epic, matching the existing `LOOP_VALIDATOR_CAPABILITY` precedent (`tests/lib/loop-driver.sh:460-519`) |

## Assumptions

Same as requirements.md Assumptions: Epics A1/A3/A5 remain unmerged and
may shift before Phase 2; ADR-0010/0016/0023 and decision doc §4/§6/§19
remain authoritative and unrevised; `jq`/bash/PowerShell remain the
available deterministic runtimes.

## Open Questions

Carried forward from requirements.md, not resolved by this design:
OQ-001 (Epic A5 caller-contract suite's home) and OQ-002
(`PROJECT_CONTEXT_INVALID` as a fifth fixture-matrix state). Owner:
maintainers in both cases. Neither blocks this Phase 1 package's own
completion.

## Risks

Same three risks as requirements.md Risks section, with this design's own
added mitigation: the "shared-surface blast radius" risk (requirements.md
Risks, High) is narrowed by this design's own decision to touch exactly
one existing `loop-inventory` entry (`quality-gate`) and one existing
suite (`loop-escalation.tests.sh`) in Phase 2/3's first increment, rather
than every entry/suite at once — a smaller, independently reviewable
first change.
