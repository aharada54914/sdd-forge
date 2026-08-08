# Traceability: design-sync-standing-consent

Authored at Phase 2, alongside `tasks.md`. Every row below is transcribed
from `requirements.md`, `acceptance-tests.md` and `design.md`; no mapping is
invented here.

**Cross-namespace Test ID note (see `tasks.md` Global Constraints).** This
feature's own `acceptance-tests.md` reuses small integers (`TEST-010`,
`TEST-015`, `TEST-018`, `TEST-026`, `TEST-040`) both for its own Test Matrix
rows *and*, inside AC-025/AC-026's own text, to cite DS-29's **different**
rows of the same numbers inside `tests/design-system-contract.tests.sh`.
Every citation below to a DS-29-suite row is written as "DS-29's `TEST-NNN`
(`tests/design-system-contract.tests.sh`)"; a bare `TEST-NNN` always means
this feature's own `acceptance-tests.md` numbering.

## Requirement Coverage

The Layer Spec column names the layer document that carries this
requirement's normative refinement, by anchor. `N/A` is used where a
requirement's canonical detail is that a prior feature's layer content is
preserved unmodified rather than restated, with the reason given rather than
left blank.

| Requirement | Summary | Layer Spec | AC | Test ID | Task |
|---|---|---|---|---|---|
| REQ-001 | `ds_upload_consent` is a three-valued project setting in `AGENTS.md`'s new `## Project Settings` section; two absence branches and one out-of-domain branch each independently resolve to `per-feature` | security-spec.md#under-whose-consent | AC-001, AC-002, AC-003, AC-004, AC-031 | TEST-001 – TEST-005, TEST-055, TEST-056 | T-001, T-002 |
| REQ-002 | The setting means the same thing on every host `design-sync-loop` can run on, including one without the `DesignSync` tool today; the forbiddance under `off` is a property of the setting, not of tool presence | security-spec.md#stride-analysis | AC-005, AC-006 | TEST-006, TEST-007 | T-001, T-002, T-003 |
| REQ-003 | `standing`: the per-feature confirmation at step 3 is skipped; exactly one audit record is written per (feature, destination), the first time, as `granted` | security-spec.md#trust-boundaries | AC-007, AC-008, AC-009, AC-030, AC-010 | TEST-008 – TEST-012 | T-001, T-003 |
| REQ-004 | `off`: the upload is forbidden; step 3 always resolves to its existing "not permitted" outcome, persistently, on every host | security-spec.md#stride-analysis | AC-011, AC-012, AC-013, AC-014 | TEST-013 – TEST-018 | T-001, T-003 |
| REQ-005 | The default, `per-feature`, is exactly DS-29's shipped behaviour — an outer branch selector wraps step 3 without rewriting 3(a)/(b)/(c), step 4, step 5, step 6 or step 7's own content | N/A — cross-layer only: this requirement's canonical detail is that DS-29's own step-3/4 content and record rules are preserved unmodified (BL-001), verified structurally per span rather than by a new layer citation | AC-015 | TEST-019 – TEST-025 | T-001, T-003 |
| REQ-006 | The setting value and the audit fact are both reflected in `Design-Source`, via three fields DS-29 pre-declared a slot for, populated on every record-producing occasion this skill's behaviour defines | security-spec.md#trust-boundaries | AC-016, AC-017, AC-018, AC-019, AC-029 | TEST-026 – TEST-043 | T-001, T-003 |
| REQ-007 | The setting governs step 3 by its current value, re-read at every resolution; a record's own history never overrides it | security-spec.md#stride-analysis | AC-020, AC-021 | TEST-044, TEST-045 | T-001, T-003 |
| REQ-008 | The manual fallback states, via an indirect reference that never spells out the setting's own key name, that the setting's value and its audit consequence survive being the actual path taken | security-spec.md#stride-analysis | AC-022, AC-023, AC-024 | TEST-046 – TEST-050 | T-001, T-004 |
| REQ-009 | Every DS-29 invariant this feature's edit surface touches is verified against a documented pre-change baseline, not merely assumed unbroken | security-spec.md#security-tests | AC-025, AC-026 | TEST-051, TEST-052 | T-001, T-003, T-004 |
| REQ-010 | This feature's own criteria are executed by a new suite, registered locally; CI registration is a separately staged, non-blocking patch | infra-spec.md#cicd-sequence | AC-027, AC-028 | TEST-053, TEST-054 (Deferred) | T-001, T-005 |

`ux-spec.md` and `frontend-spec.md` are recorded N/A for this feature and are
therefore not cited above. That N/A is justified rather than assumed:
`design.md`'s own Layer Specifications table states it directly — the
feature ships prose edits to `AGENTS.md`, one `SKILL.md`, one reference
document, and shell/PowerShell test assertions, and *reduces* the one
human-perceivable surface DS-29 introduced (the consent prompt no longer
appears under `standing`/`off`) rather than adding one of its own
(`ux-spec.md#scope-and-user-journeys`: "no view, dialog, menu item, or
context action"). No browser, bundle, or build output exists anywhere in it
(`frontend-spec.md#technology-stack`). `acceptance-tests.md`'s own UI
Integration Checklist records the same finding as N/A rather than omitting
the section, matching DS-29's own convention.

## Acceptance Mapping

| AC | Test ID | Test Type | Target | Task |
|---|---|---|---|---|
| AC-001 | TEST-001 | document conformance | `AGENTS.md` | T-001, T-002 |
| AC-002 | TEST-002 | document conformance | same | T-001, T-002 |
| AC-003 | TEST-003, TEST-004 | document conformance (two independent absence branches) | same | T-001, T-002 |
| AC-004 | TEST-005 | document conformance | same | T-001, T-002 |
| AC-005 | TEST-006 | document conformance | same | T-001, T-002 |
| AC-006 | TEST-007 | document conformance | `design-sync-loop/SKILL.md` | T-001, T-003 |
| AC-007 | TEST-008 | document conformance | same | T-001, T-003 |
| AC-008 | TEST-009 | document conformance | same | T-001, T-003 |
| AC-009 | TEST-010 | document conformance | same | T-001, T-003 |
| AC-030 | TEST-011 | document conformance | same | T-001, T-003 |
| AC-010 | TEST-012 | document conformance | same | T-001, T-003 |
| AC-011 | TEST-013 | document conformance | same | T-001, T-003 |
| AC-012 | TEST-014, TEST-015, TEST-016 | document conformance (three independent clauses) | same | T-001, T-003 |
| AC-013 | TEST-017 | document conformance | same | T-001, T-003 |
| AC-014 | TEST-018 | document conformance (cross-file, `AGENTS.md` + `design-sync-loop/SKILL.md`) | both | T-001, T-002, T-003 |
| AC-015 | TEST-019, TEST-020, TEST-021, TEST-022, TEST-023, TEST-024, TEST-025 | regression, checked per span (step 3a/3b/3c/4/5/6/7) | `design-sync-loop/SKILL.md` | T-001, T-003 |
| AC-016 | TEST-026, TEST-027, TEST-028 | document conformance, one literal per row | same | T-001, T-003 |
| AC-017 | TEST-029 | document conformance | same | T-001, T-003 |
| AC-018 | TEST-030, TEST-031, TEST-032, TEST-033, TEST-034, TEST-035, TEST-036, TEST-037 | regression, eight independent branches | same | T-001, T-003 |
| AC-019 | TEST-038, TEST-039 | document conformance (`standing`, `off`, each its own row) | same | T-001, T-003 |
| AC-029 | TEST-040, TEST-041, TEST-042, TEST-043 | document conformance, four record-producing occasions | same | T-001, T-003 |
| AC-020 | TEST-044 | document conformance (executable oracle) | same | T-001, T-003 |
| AC-021 | TEST-045 | document conformance | same | T-001, T-003 |
| AC-022 | TEST-046, TEST-047 | regression (negative) + document conformance | `claude-design-workflow.md` | T-001, T-004 |
| AC-023 | TEST-048, TEST-049 | regression + regression (minimal diff) | same | T-001, T-004 |
| AC-024 | TEST-050 | regression (negative) | same | T-001, T-004 |
| AC-025 | TEST-051 | external-suite regression (baseline-relative) | `tests/design-system-contract.tests.{sh,ps1}` | T-001, T-003 |
| AC-026 | TEST-052 | external-suite regression (baseline-relative), DS-29's `TEST-021` specifically | same | T-001, T-004 |
| AC-027 | TEST-053 | registration conformance | `tests/run-all.sh`, `tests/run-all.ps1` | T-001 |
| AC-028 | TEST-054 (Deferred) | CI-registration conformance (deferred, non-blocking) | `.github/workflows/test.yml` | T-001, T-005 (stays red pending the human-applied staged workflow patch, out of this decomposition's own scope to apply) |
| AC-031 | TEST-055, TEST-056 | document conformance (two independent claims) | `AGENTS.md` | T-001, T-002 |

All 31 acceptance criteria and all 56 tests (`TEST-001` through `TEST-056`,
including the Deferred `TEST-054`) are claimed by at least one task. The
mapping was produced by a mechanical sweep of every `AC-` and `TEST-`
identifier in `acceptance-tests.md`'s Test Matrix and Deferred section, and
`design.md`'s own Coverage table, not by reading the task list and writing
down what it appeared to cover — that reverse direction is exactly how
AC-013 and AC-012 went missing from a design plan in a prior feature and
cost that feature's impl review a BLOCKED attempt
(`epic-136-phase4-docs/traceability.md`, carried forward as the same
discipline DS-29's own traceability.md records).

## Task Mapping

| Task | Requirements | Shares |
|---|---|---|
| T-001 | REQ-001 – REQ-010 (all 31 AC, as the assertion-authoring, `run-all`-registration and pre-edit-baseline task) | `tests/design-sync-standing-consent.tests.sh`, `tests/design-sync-standing-consent.tests.ps1`, `tests/run-all.sh`, `tests/run-all.ps1` |
| T-002 | REQ-001 (AC-001, AC-002, AC-003, AC-004, AC-031), REQ-002 (AC-005 — `AGENTS.md`-side host-neutrality leg) | `AGENTS.md` |
| T-003 | REQ-002 (AC-006 — `design-sync-loop/SKILL.md`-side host-neutrality leg), REQ-003, REQ-004, REQ-005, REQ-006, REQ-007, REQ-009 (AC-025) | `plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md` |
| T-004 | REQ-008, REQ-009 (AC-026) | `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/references/claude-design-workflow.md` |
| T-005 | REQ-010 (AC-028 — the CI-registration leg; the local `run-all` reachability leg, AC-027, is T-001's) | `specs/design-sync-standing-consent/verification/T-005/staged-workflow-candidate.draft.yml`, `specs/design-sync-standing-consent/human-copy/MANIFEST.sha256` |

T-001 is listed against every requirement because it is where every Test ID
in this feature is authored, registered locally, and given its pre-edit
baseline; the document content each assertion verifies is produced by T-002
(`AGENTS.md`), T-003 (`design-sync-loop/SKILL.md`) or T-004
(`claude-design-workflow.md`), per the Acceptance Mapping table above. No two
of T-002, T-003 and T-004 share an edited file (`tasks.md` Global
Constraints, SCOPE-DISJOINT). AC-014/`TEST-018` is the one criterion two
content tasks (T-002 and T-003) jointly satisfy, since it cross-references
both edited files. T-005 shares no edited file with any of T-001 through
T-004 — its own two artifacts (`verification/T-005/staged-workflow-candidate.draft.yml`
and `human-copy/MANIFEST.sha256`) are new, non-protected paths that stand in
for the protected `.github/workflows/test.yml` a human alone can write — see
`tasks.md` Global Constraints for the full dependency graph.

## Baseline Constraints

| Constraint | Where it is checked | Task |
|---|---|---|
| BL-001 — DS-29's egress gate, and its own internal rules for the `per-feature` regime, are not rewritten | `design-sync-loop/SKILL.md`'s step 3(a)/(b)/(c), step 4, step 5, step 6 and step 7 text is DS-29's, byte-for-byte, checked per span, not as one combined claim | T-001 (suite), T-003 (preservation) |
| BL-002 — DS-29's five `Design-Source` field names and `Egress-Consent`'s three-valued domain are unchanged | `## Ensure design-system/`-adjacent record table's five old field names and three old domain values, checked as eight independent literals | T-001 (suite), T-003 (preservation) |
| BL-003 — the manual fallback's zero-upload property, and its "no 'consent' substring" invariant, survive this feature's own edit, and the setting's literal key is never written there | `claude-design-workflow.md`'s existing no-upload statement (unmodified), the general "consent"-substring sweep, and the literal-key ban, plus DS-29's own `TEST-021` re-verified from this feature's suite | T-001 (suite), T-004 (edit) |
| BL-004 — no protected file is touched, live or staged, by any task in this decomposition | `tasks.md` Protected Files: re-derived by direct read against `guard_invariants.py:4,18` at authoring time — `AGENTS.md`, `design-sync-loop/SKILL.md` and `claude-design-workflow.md` are all unprotected; `.github/workflows/test.yml` is protected and touched only as a non-live, human-applied staged candidate | T-005 (stages, does not apply) |
| BL-005 — `specs/workflow-state-registry.json` needs an entry for this feature | pre-satisfied — observed present at Phase 2 authoring time (`tasks.md` Predecessor Gate Status; added by the Phase 1 authoring session per `infra-spec.md` Prerequisites item 1) | none — outside this decomposition |
| BL-006 — `AGENTS.md`'s `Active Spec Directories` list needs `specs/design-sync-standing-consent/` appended | re-verified absent at Phase 2 authoring time (`tasks.md` Predecessor Gate Status); explicitly deferred, non-blocking, gate-invisible per `infra-spec.md` Prerequisites item 2 | none — deliberately not performed by any task here |

## Self-Consistency Check

- Every `REQ-NNN` in `requirements.md` (`REQ-001` through `REQ-010`) appears
  in the Requirement Coverage table above.
- Every `AC-NNN` in `requirements.md` (`AC-001` through `AC-031`, 31 total)
  appears in the Acceptance Mapping table above, each with at least one Test
  ID and at least one Task.
- Every `TEST-NNN` in `acceptance-tests.md`'s Test Matrix (`TEST-001`
  through `TEST-053`, `TEST-055`, `TEST-056` — 55 rows) and its Deferred
  section (`TEST-054`) appears in the Acceptance Mapping table above, tied
  to the AC it verifies and the task(s) that author or satisfy it.
- Every task `T-001` through `T-005` in `tasks.md` appears in the Task
  Mapping table above with a non-empty Requirements column and a Shares
  column matching that task's own `Scope`/Done-When file list.
- Every `BL-NNN` in `requirements.md`'s own Baseline Constraints section
  (`BL-001` through `BL-006`) appears in the Baseline Constraints table
  above, each tied to where it is checked and, where applicable, the task
  responsible.
- No task in `tasks.md` claims the completed `Status` value or the
  human-only-settable `Approval` value; every task's `Status` reads
  `Planned` and every task's `Approval` reads `Pending`, matching
  `tasks.md`'s own Lifecycle section (Draft-equivalent, human approves by
  editing the file directly).
- Neither `tasks.md` nor this document names the sudo-mode override
  environment variable this repository's hook guard reads.
