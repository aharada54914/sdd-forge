# Traceability: design-sync-consent

Authored at Phase 2, alongside `tasks.md`. Every row below is transcribed
from `requirements.md`, `acceptance-tests.md` and `design.md`; no mapping is
invented here.

## Requirement Coverage

The Layer Spec column names the layer document that carries this
requirement's normative refinement, by anchor. `N/A — cross-layer only` is
used where a requirement has no single owning layer, with the reason stated
rather than left blank.

| Requirement | Summary | Layer Spec | AC | Test ID | Task |
|---|---|---|---|---|---|
| REQ-001 | The egress consent unit is one per feature+session, not one per upload; expiry, withdrawal, a transient decline, and destination-binding are all stated | security-spec.md#under-whose-consent | AC-001, AC-002, AC-026, AC-027, AC-028, AC-030 | TEST-001 – TEST-004, TEST-041 – TEST-047, TEST-051 | T-001, T-002 |
| REQ-002 | The first-time consent prompt is informed: what leaves, where it goes, what happens there, what the consent covers, that coverage survives regeneration, that the pull direction also transmits, and what the operator is asserting | security-spec.md#what-leaves-the-machine | AC-003, AC-004, AC-005, AC-029 | TEST-005 – TEST-009, TEST-048 – TEST-050 | T-001, T-002 |
| REQ-003 | The flow order inverts (consent before push, claude.ai review after); local review is demoted to optional and the demotion's consequence is stated | security-spec.md#what-the-operator-gives-up | AC-006, AC-007, AC-008, AC-009 | TEST-010 – TEST-014 | T-001, T-002 |
| REQ-004 | The consent fact and the upload subject are recorded in `Design-Source`, in a named, minimal, additively-extensible shape, characterised as an audit trace and not an authorization | security-spec.md#trust-boundaries | AC-010, AC-011, AC-012 | TEST-015 – TEST-018 | T-001, T-002, T-004 |
| REQ-005 | The manual fallback and the non-blocking invariant survive unchanged; `ds_profile: none` performs no egress and asks no consent question | security-spec.md#stride-analysis | AC-013, AC-014, AC-015, AC-016 | TEST-019 – TEST-024 | T-001, T-002, T-003 |
| REQ-006 | The model leaves #139's pre-upload scan point and #140's three-valued consent outcome / extensible record implementable | security-spec.md#trust-boundaries | AC-017, AC-018, AC-019, AC-020 | TEST-025 – TEST-032 | T-001, T-002 |
| REQ-007 | Every live statement of the per-upload model is reconciled; the historical `CHANGELOG.md` record and the protected `lite-spec/SKILL.md` file are handled by their own rules | N/A — cross-layer only: reconciling four independent prose sites across two skill files and one guide is a repository-wide documentation-consistency requirement with no single owning ux/frontend/infra/security layer; `design.md`'s Components table, not a layer spec, is what enumerates the four sites | AC-021, AC-022, AC-023 | TEST-033 – TEST-038 | T-001, T-002, T-003, T-004 |
| REQ-008 | This feature's document-conformance assertions are executed by a suite `run-all` reaches locally; CI registration is a separately staged patch | infra-spec.md#cicd-sequence | AC-024, AC-025 | TEST-039, TEST-040 | T-001, T-002, T-005 |

`ux-spec.md` and `frontend-spec.md` are recorded N/A for this feature and are
therefore not cited above. That N/A is justified rather than assumed:
`design.md`'s own Layer Specifications table states it directly — the
feature ships prose edits to two `SKILL.md` files, one Markdown guide, and
shell/PowerShell test assertions, with a single agent-emitted consent prompt
as its only human-perceivable surface (`ux-spec.md#scope-and-user-journeys`:
"no view, dialog, menu item or context action"). No browser, bundle, or
build output exists anywhere in it (`frontend-spec.md#technology-stack`).
`acceptance-tests.md`'s own UI Integration Checklist records the same
finding as N/A rather than omitting the section, "so the omission is
visibly a judgement rather than an oversight."

## Acceptance Mapping

| AC | Test ID | Test Type | Target | Task |
|---|---|---|---|---|
| AC-001 | TEST-001, TEST-002, TEST-003 | document conformance | `design-sync-loop/SKILL.md` | T-001, T-002 |
| AC-002 | TEST-004 | document conformance | same | T-001, T-002 |
| AC-003 | TEST-005, TEST-006, TEST-007 | document conformance | same | T-001, T-002 |
| AC-004 | TEST-008 | document conformance | same | T-001, T-002 |
| AC-005 | TEST-009 | document conformance | same | T-001, T-002 |
| AC-006 | TEST-010 | document conformance (ordered structure) | same | T-001, T-002 |
| AC-007 | TEST-011, TEST-012 | document conformance | same | T-001, T-002 |
| AC-008 | TEST-013 | document conformance | same | T-001, T-002 |
| AC-009 | TEST-014 | document conformance (ordered structure) | same | T-001, T-002 |
| AC-010 | TEST-015 | document conformance | same | T-001, T-002 |
| AC-011 | TEST-016, TEST-017 | document conformance | same (full leg) / staged `lite-spec/SKILL.md` candidate (lite leg) | T-001, T-002, T-004 |
| AC-012 | TEST-018 | document conformance | `design-sync-loop/SKILL.md` | T-001, T-002 |
| AC-013 | TEST-019, TEST-020 | document conformance | same | T-001, T-002 |
| AC-014 | TEST-021 | document conformance | `claude-design-workflow.md` | T-001, T-003 |
| AC-015 | TEST-022, TEST-023 | document conformance | `design-sync-loop/SKILL.md` | T-001, T-002 |
| AC-016 | TEST-024 | document conformance | `sdd-bootstrap-interviewer/SKILL.md` | T-001, T-003 |
| AC-017 | TEST-025, TEST-026 | document conformance / structural | `design-sync-loop/SKILL.md` | T-001, T-002 |
| AC-018 | TEST-027 | document conformance | same | T-001, T-002 |
| AC-019 | TEST-028, TEST-029, TEST-030 | document conformance | same | T-001, T-002 |
| AC-020 | TEST-031, TEST-032 | document conformance | same | T-001, T-002 |
| AC-021 | TEST-033, TEST-034, TEST-035, TEST-036 | document conformance | `design-sync-loop/SKILL.md` (frontmatter + Boundaries), `sdd-bootstrap-interviewer/SKILL.md`, `docs/workflow-guide.md` | T-001, T-002, T-003 |
| AC-022 | TEST-037 | regression (negative) | `CHANGELOG.md` | T-001, T-003 |
| AC-023 | TEST-038 | staging conformance | `lite-spec/SKILL.md` + `human-copy/MANIFEST.sha256` | T-001, T-004 |
| AC-024 | TEST-039 | CI-registration conformance | CI entry point → suite | T-001, T-005 (stays red pending the human-applied staged workflow patch, out of this decomposition — R-OQ-8 part 3) |
| AC-025 | TEST-040 | regression | `tests/design-system-contract.tests.{sh,ps1}` | T-001, T-002 |
| AC-026 | TEST-041, TEST-042, TEST-043 | document conformance | `design-sync-loop/SKILL.md` | T-001, T-002 |
| AC-027 | TEST-044, TEST-045 | document conformance | same | T-001, T-002 |
| AC-028 | TEST-046, TEST-047 | document conformance | same | T-001, T-002 |
| AC-029 | TEST-048, TEST-049, TEST-050 | document conformance | same | T-001, T-002 |
| AC-030 | TEST-051 | document conformance | same | T-001, T-002 |

All 30 acceptance criteria and all 51 tests are claimed by at least one
task. The mapping was produced by a mechanical sweep of every `AC-` and
`TEST-` identifier in `acceptance-tests.md`'s Test Matrix and `design.md`'s
Coverage table, not by reading the task list and writing down what it
appeared to cover — that reverse direction is exactly how AC-013 and AC-012
went missing from a design plan in a prior feature and cost that feature's
impl review a BLOCKED attempt (`epic-136-phase4-docs/traceability.md`).

## Task Mapping

| Task | Requirements | Shares |
|---|---|---|
| T-001 | REQ-001 – REQ-008 (all 30 AC, as the assertion-authoring task) | `tests/design-system-contract.tests.sh`, `tests/design-system-contract.tests.ps1` |
| T-002 | REQ-001, REQ-002, REQ-003, REQ-004 (full-profile leg), REQ-005 (AC-013, AC-015), REQ-006, REQ-007 (sites 1–2), REQ-008 (AC-025) | `plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md` |
| T-003 | REQ-005 (AC-014, AC-016), REQ-007 (sites 3–4, AC-022) | `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md`, `docs/workflow-guide.md`, `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/references/claude-design-workflow.md` (reviewed, expected no-op) |
| T-004 | REQ-004 (lite-profile leg), REQ-007 (AC-023) | `specs/design-sync-consent/verification/T-004/staged-lite-spec-candidate.draft.md`, `specs/design-sync-consent/human-copy/MANIFEST.sha256` |
| T-005 | REQ-008 (AC-024 — local `run-all` reachability leg only) | `tests/run-all.sh`, `tests/run-all.ps1` |

T-001 is listed against every requirement because it is where every
Test ID in this feature is authored; the document content each assertion
verifies is produced by T-002, T-003 or T-004, per the Acceptance Mapping
table above. No two of T-002, T-003 and T-004 share an edited file. T-005,
split out of T-001 at task-review round 1 to separate assertion-authoring
from `run-all` registration, shares no edited file with any of T-002,
T-003 or T-004 either (`tests/run-all.{sh,ps1}` only) — see `tasks.md`
Global Constraints for the full dependency graph, including the
`T-005 <- T-001` edge.

## Baseline Constraints

| Constraint | Where it is checked | Task |
|---|---|---|
| BL-001 — the egress gate is not removed, only its unit changes | `design-sync-loop/SKILL.md`'s Loop states a consent decision still gates every scope's first upload | T-001, T-002 |
| BL-002 — the manual fallback is behaviour-preserving | `claude-design-workflow.md` reviewed; no upload gained | T-001, T-003 |
| BL-003 — the non-blocking invariant is preserved | `## Boundaries` `:94-95`, `:96`, `:99-111` unchanged, verified by diff | T-002 |
| BL-004 — `plugins/sdd-lite/skills/lite-spec/SKILL.md` is never written live by an agent | draft candidate + `MANIFEST.sha256`, live file diffed unmodified | T-004 |
| BL-005 — `.github/workflows/test.yml` is also protected; its CI registration is a separate staged patch, out of this decomposition | re-verified against `guard_invariants.py:4,18` in `tasks.md` Protected Files; no task writes it | none — explicitly out of scope for this decomposition (R-OQ-8 part 3) |
| BL-006 — `CHANGELOG.md:1301` is not modified | verified by diff | T-003 |
| BL-007 — the seven `DS-006` literals survive the restructuring | `## Ensure design-system/` left byte-identical; re-verified by TEST-040 | T-001 (suite), T-002 (preservation) |
| BL-008 — dual-runtime parity | every assertion added to the `.sh` suite has a `.ps1` twin or a stated, documented asymmetry | T-001 |
| BL-009 — `specs/workflow-state-registry.json` needs an entry for this feature | pre-satisfied — observed present at Phase 2 authoring time (`tasks.md` Predecessor Gate Status); no task required | none |
