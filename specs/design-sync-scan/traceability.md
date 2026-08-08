# Traceability: design-sync-scan

Authored at Phase 2, alongside `tasks.md`. Every row below is transcribed
from `requirements.md`, `acceptance-tests.md`, `design.md`, and
`security-spec.md`; no mapping is invented here.

## Requirement Coverage

The Layer Spec column names the layer document that carries this
requirement's normative refinement, by anchor, following
`security-spec.md`'s own Trust Boundaries table where it exists (that table
already groups REQ-001–REQ-003 under boundary B5 and REQ-004–REQ-007 under
the B5→B1 gate — the same grouping this table transcribes rather than
re-derives). `N/A — cross-layer only` is used where a requirement has no
single owning layer, with the reason stated rather than left blank.

| Requirement | Summary | Layer Spec | AC | Test ID | Task |
|---|---|---|---|---|---|
| REQ-001 | A runtime-neutral script pair scans a target directory's `*.html` files, recursively, for all three categories in one pass; the selection boundary excludes non-HTML files and is case-insensitive on extension | security-spec.md#trust-boundaries | AC-001, AC-002, AC-003, AC-004, AC-039 | TEST-001 – TEST-004, TEST-085, TEST-086 | T-001, T-002 |
| REQ-002 | The exit-code contract is exactly three-valued and fail-closed: 0 clean, 1 findings (overridable, once, against exactly what was disclosed), 2 tool error (fail-closed, no override path at all) | security-spec.md#trust-boundaries | AC-005, AC-006, AC-007, AC-008, AC-037 | TEST-005 – TEST-013, TEST-055, TEST-056 | T-001, T-002, T-003 |
| REQ-003 | The three detection categories — placeholder (reused verbatim), secret (S1–S7), PII (P1, P2) — are named and enumerated in `design.md`, each with a POSIX ERE and `.NET` dual form where a boundary construct is needed | security-spec.md#trust-boundaries | AC-009, AC-010, AC-011, AC-012, AC-038 | TEST-014 – TEST-025, TEST-057 – TEST-062, TEST-080 – TEST-084 | T-001, T-002 |
| REQ-004 | A detection blocks the upload; findings are presented with file:line, masked for secret/PII, shown in full for placeholder; the script itself is non-interactive | security-spec.md#trust-boundaries | AC-013, AC-014, AC-015, AC-016 | TEST-026 – TEST-031, TEST-063 | T-001, T-002, T-003 |
| REQ-005 | A clean scan does not impede the DS-29 flow; the check makes no quality judgment, stated in both the skill and the script header; the Loop's step order is structurally unchanged | security-spec.md#trust-boundaries | AC-017, AC-018, AC-019 | TEST-032 – TEST-035 | T-001, T-002, T-003 |
| REQ-006 | The false-positive override is explicit, human-gated, and scoped to the single scan that disclosed the findings — it does not carry forward across regeneration, even for identical findings; the outcome is recorded in `Design-Source` | security-spec.md#trust-boundaries; security-spec.md#under-whose-consent | AC-020, AC-021, AC-022, AC-023, AC-024, AC-025 | TEST-036 – TEST-043, TEST-064 – TEST-068 | T-003 |
| REQ-007 | Step 5 stays the single named point every upload path passes through; existing `design-system-contract` invariants (including `design-sync-consent`'s own structural assertions) survive with zero new failures | security-spec.md#trust-boundaries | AC-026, AC-027, AC-028 | TEST-044 – TEST-046 | T-003 |
| REQ-008 | The scan is independently runnable as a manual pre-fallback check on a host without `DesignSync` (Codex), using the identical script, patterns, and exit-code contract — no host- or runtime-conditional branch exists | infra-spec.md#deployment-topology | AC-029, AC-030 | TEST-047, TEST-048, TEST-069 | T-001, T-002, T-004 |
| REQ-009 | Both runtimes return identical verdicts (exit code, category, file:line) on identical input — a stronger claim than each runtime independently passing its own suite | N/A — cross-layer only: cross-runtime agreement is a property of this feature's own verification design, stated in `design.md`'s Test Strategy ("Cross-runtime parity is its own test category") rather than normatively owned by any single ux/frontend/infra/security layer document | AC-031, AC-032, AC-033 | TEST-049 – TEST-051, TEST-070 – TEST-079, TEST-084 | T-002 |
| REQ-010 | The feature's tests are a new suite (`tests/design-sync-scan.tests.{sh,ps1}`), registered for local execution in `run-all`; CI registration is staged separately, out of this decomposition | infra-spec.md#cicd-sequence | AC-034, AC-035, AC-036 | TEST-052, TEST-053, TEST-054 (Deferred) | T-001, T-004, T-005 (AC-036/TEST-054: no task — separately staged, human-applied patch) |

`ux-spec.md` and `frontend-spec.md` are recorded N/A for this feature and
are therefore not cited above. `design.md`'s own Layer Specifications table
states the reason directly: the feature ships a script pair, a targeted
skill-text edit, and one documentation edit, with a terminal/agent-session
finding report and an override decision point as its only human-perceivable
surface (`ux-spec.md#scope-and-user-journeys`: no view, dialog, menu item or
context action). `acceptance-tests.md`'s own UI Integration Checklist
records the same finding as N/A rather than omitting the section, matching
`design-sync-consent/acceptance-tests.md`'s treatment of the identical
question for the same loop.

## Acceptance Mapping

| AC | Test ID | Test Type | Target | Task |
|---|---|---|---|---|
| AC-001 | TEST-001 | unit | `design-sync-scan.sh`, `.ps1` | T-001, T-002 |
| AC-002 | TEST-002 | unit (fixture) | same | T-001, T-002 |
| AC-003 | TEST-003 | unit (fixture) | same | T-001, T-002 |
| AC-004 | TEST-004 | unit (fixture) | same | T-001, T-002 |
| AC-005 | TEST-005 | unit (fixture) | same | T-001, T-002 |
| AC-006 | TEST-006, TEST-007, TEST-008, TEST-009 | unit (fixture) | same | T-001, T-002 |
| AC-007 | TEST-010, TEST-011, TEST-012, TEST-056 | unit (fixture) | same | T-001, T-002 |
| AC-008 | TEST-013 | regression | same | T-001, T-002 |
| AC-009 | TEST-014 | unit (fixture) | same | T-001, T-002 |
| AC-010 | TEST-015, TEST-016, TEST-017, TEST-018, TEST-019, TEST-020, TEST-021, TEST-083 | unit (fixture) | same | T-001, T-002 |
| AC-011 | TEST-022, TEST-023, TEST-024, TEST-057, TEST-058, TEST-059, TEST-060, TEST-061, TEST-062, TEST-080, TEST-081, TEST-082 | unit (fixture) | same | T-001, T-002 |
| AC-012 | TEST-025 | unit (fixture) | same | T-001, T-002 |
| AC-013 | TEST-026 | unit (fixture) | same | T-001, T-002 |
| AC-014 | TEST-027, TEST-028, TEST-029, TEST-063 | unit (fixture) | same | T-001, T-002 |
| AC-015 | TEST-030 | unit | same | T-001, T-002 |
| AC-016 | TEST-031 | document conformance | `design-sync-loop/SKILL.md` | T-003 |
| AC-017 | TEST-032 | document conformance | same | T-003 |
| AC-018 | TEST-033, TEST-034 | document conformance | `design-sync-loop/SKILL.md` (TEST-033); `design-sync-scan.sh` / `.ps1` header comment (TEST-034) | T-003 (TEST-033); T-001, T-002 (TEST-034) |
| AC-019 | TEST-035 | document conformance (structural) | `design-sync-loop/SKILL.md` | T-003 |
| AC-020 | TEST-036 | document conformance | same | T-003 |
| AC-021 | TEST-037, TEST-038 | document conformance | same | T-003 |
| AC-022 | TEST-039, TEST-040 | document conformance | same | T-003 |
| AC-023 | TEST-041, TEST-064 | document conformance | same | T-003 |
| AC-024 | TEST-042, TEST-065, TEST-066, TEST-067, TEST-068 | regression | same | T-003 |
| AC-025 | TEST-043 | document conformance | same | T-003 |
| AC-026 | TEST-044 | document conformance | same | T-003 |
| AC-027 | TEST-045 | document conformance (positional) | same | T-003 |
| AC-028 | TEST-046 | regression (baseline-relative) | `tests/design-system-contract.tests.{sh,ps1}` | T-003 |
| AC-029 | TEST-047 | document conformance | `claude-design-workflow.md` (or its referring section) | T-004 |
| AC-030 | TEST-048, TEST-069 | static (finite identifier set); representative-caller parity | `design-sync-scan.sh` / `.ps1` source | T-001, T-002 |
| AC-031 | TEST-049, TEST-070, TEST-071, TEST-072, TEST-073, TEST-074, TEST-075, TEST-076 | cross-runtime parity | `design-sync-scan.sh` vs `.ps1` | T-002 |
| AC-032 | TEST-050, TEST-077, TEST-078, TEST-079 | cross-runtime parity | same | T-002 |
| AC-033 | TEST-051 | case-sensitivity sweep | `design-sync-scan.ps1` | T-002 |
| AC-034 | TEST-052 | traceability manifest | `acceptance-tests.md` (this file, transcribed) | T-001 (authors the check); full coverage claim completed by T-004 |
| AC-035 | TEST-053 | registration conformance | `tests/run-all.{sh,ps1}` | T-005 |
| AC-036 | TEST-054 (Deferred) | CI-registration conformance | `.github/workflows/test.yml` | none — separately staged, human-applied patch, out of this decomposition |
| AC-037 | TEST-055 | document conformance | `design-sync-loop/SKILL.md` | T-003 |
| AC-038 | TEST-084 | cross-runtime parity | `design-sync-scan.sh` vs `.ps1` (dual-form specific) | T-001 (POSIX ERE forms), T-002 (`.NET` forms + parity assertion) |
| AC-039 | TEST-085, TEST-086 | unit (fixture, negative boundary); unit (fixture) + cross-runtime parity | `design-sync-scan.sh`, `.ps1` | T-001 (`.sh` half of both rows), T-002 (`.ps1` half + the cross-runtime comparison TEST-086 itself requires) |

All 39 acceptance criteria and all 86 tests (85 blocking, 1 Deferred) are
claimed by at least one task, or explicitly marked as claimed by none because
the corresponding patch is outside any agent's authority (AC-036/TEST-054).
The mapping was produced by a mechanical sweep of every `AC-` and `TEST-`
identifier in `acceptance-tests.md`'s Test Matrix and Deferred section
against `requirements.md`'s `#### AC-NNN` headings and `design.md`'s Test
Strategy Coverage table, not by reading the task list and writing down what
it appeared to cover — the same discipline `design-sync-consent/traceability.md`
states for itself, citing the `epic-136-phase4-docs` incident where the
reverse direction lost AC-013 and AC-012 from a design plan and cost that
feature's impl review a BLOCKED attempt.

## Task Mapping

| Task | Requirements | Shares |
|---|---|---|
| T-001 | REQ-001 – REQ-005 (script-behavior legs), REQ-008 (`.sh` half), REQ-003's AC-038 (POSIX ERE authoring), REQ-010's AC-034 (suite authored, initial contribution) | `plugins/sdd-bootstrap/scripts/design-sync-scan.sh`, `tests/design-sync-scan.tests.sh` (created; later appended to by T-003, T-004) |
| T-002 | REQ-001 – REQ-005 (`.ps1` port), REQ-008 (`.ps1` half), REQ-009 (all — no cross-runtime claim is checkable before this task) | `plugins/sdd-bootstrap/scripts/design-sync-scan.ps1`, `tests/design-sync-scan.tests.ps1` (created; later appended to by T-003, T-004) |
| T-003 | REQ-002 (AC-037), REQ-004 (AC-016), REQ-005 (AC-017, the `SKILL.md` half of AC-018, AC-019), REQ-006 (all), REQ-007 (all) | `plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md`; appends to `tests/design-sync-scan.tests.sh`, `.ps1` |
| T-004 | REQ-008 (AC-029) | `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/references/claude-design-workflow.md`; appends to `tests/design-sync-scan.tests.sh`, `.ps1` |
| T-005 | REQ-010 (AC-035 — local `run-all` reachability leg only) | `tests/run-all.sh`, `tests/run-all.ps1` |

Unlike `design-sync-consent`, whose five tasks touched five fully disjoint
file sets, this feature's `tests/design-sync-scan.tests.{sh,ps1}` pair is a
single shared, append-only artifact that T-001 and T-002 create and T-003
and T-004 each subsequently append new assertion blocks to, one task at a
time (`tasks.md`'s Global Constraints → Shared-Suite Append Discipline, and
the `T-004 <- T-003` append-ordering edge). Every other file — the two
scripts, `design-sync-loop/SKILL.md`, `claude-design-workflow.md`, and the
two `run-all` files — is touched by exactly one task. `design-sync-loop/SKILL.md`
is additionally shared with `specs/design-sync-standing-consent/`'s own task
decomposition (a different feature, not this file), at a disjoint step,
serialized at implementation time per that feature's own Non-goals section
(`tasks.md`'s T-003 header note).

## Baseline Constraints

| Constraint | Where it is checked | Task |
|---|---|---|
| BL-001 — the pre-upload check point is not duplicated or relocated | `design-sync-loop/SKILL.md` step 5 remains the single named point (AC-026, AC-027) | T-003 |
| BL-002 — `design-sync-consent`'s consent model is unmodified | the five existing `Design-Source` fields, the feature∧session scope rule, expiry, withdrawal, the transient-decline rule, and the push-failure rule are all untouched, verified by diff and by regression (AC-024, TEST-042, TEST-065–068) | T-003 |
| BL-003 — the existing `tests/design-system-contract.tests.{sh,ps1}` suite introduces zero new failures against its documented baseline | (which already includes `design-sync-consent`'s TEST-039 as a designed red) — no source change to that suite is required by this feature (AC-028, TEST-046) | T-003 |
| BL-004 — `.github/workflows/test.yml` is protected and is not written by this feature's tasks | re-verified against `guard_invariants.py:4,18` in `tasks.md` → Protected Files; CI registration of the new suite is a separately staged, human-applied patch (AC-036) | none — explicitly out of scope for this decomposition |
| BL-005 — `specs/workflow-state-registry.json` needs an entry for this feature | pre-satisfied — observed present at Phase 2 authoring time (`tasks.md` → Predecessor Gate Status); re-confirmed, not re-created, by T-005 | T-005 (confirmation only) |

## Self-Consistency Check

Recorded so a reviewer does not have to re-derive these counts by hand:

- **Every AC has at least one row.** All 39 acceptance criteria
  (AC-001–AC-039) appear in the Acceptance Mapping table above; none is
  skipped, and none is a placeholder row with an empty Task column except
  AC-036, whose empty Task column is itself the documented, intentional
  state (a separately staged patch, per REQ-010/`infra-spec.md`, mirroring
  `design-sync-consent`'s own AC-024/TEST-039 precedent).
- **Every TEST is assigned to exactly one task's coverage, or explicitly
  Deferred.** All 86 Test IDs (TEST-001–TEST-086) are named above; TEST-054
  is the one Deferred row and carries no task assignment, matching
  `acceptance-tests.md`'s own placement of it outside the blocking Test
  Matrix. Every other Test ID traces to at least one of T-001–T-005 through
  the AC it verifies.
- **`Status: Planned` count matches the task count.** Five tasks are
  authored in `tasks.md` (T-001 through T-005); all five carry that Status
  value and a pending Approval value — none is authored further along
  either field's progression.
- **No protected file is a live edit target.** `tasks.md` → Protected Files
  re-derives this from `guard_invariants.py` directly rather than citing
  `design.md`/`infra-spec.md`'s own snapshot of the same fact.
