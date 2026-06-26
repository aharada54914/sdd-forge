# Phase Review Checklist

Combined reference for all review checks used by `sdd-review-loop`.

- **Part 0** — `spec-review-loop`: 12 checks across spec-reviewer-a and spec-reviewer-b
- **Part 1** — `impl-review-loop`: 19 checks across impl-reviewer-a and impl-reviewer-b
- **Part 2** — `task-review-loop`: 23 checks across task-reviewer-a and task-reviewer-b

---

## Part 0: Specification Review Checklist (spec-review-loop)

Complete reference for all 12 checks in the spec-review-loop. Checks are split
across two reviewers: spec-reviewer-a (requirements and acceptance coverage, 6
checks) and spec-reviewer-b (ambiguity, contradiction, and downstream readiness,
6 checks).

### Check Types

- **TYPE-D** (Deterministic): Pass/fail can be determined by reading artifact
  content against explicit rules. No qualitative judgment required.
- **TYPE-H** (Heuristic): Requires judgment about ambiguity, scope, risk, or
  downstream readiness. The reviewer must cite concrete evidence and apply
  `references/spec-review-calibration.md`.

### Default Behavior

All checks **default to FAIL**. A reviewer emits PASS only when positive
evidence is found. Use SKIP only when the check declares an explicit skip
condition and the scoped surface is absent. Absence of evidence on an in-scope
surface is a finding, not a pass.

### Reviewer-A Checks (Requirements and Acceptance Coverage — 6 checks)

#### REQ-TESTABILITY

| Field | Value |
|---|---|
| Reviewer | spec-reviewer-a |
| Type | TYPE-H |
| Severity | Critical |
| Default | FAIL |

**Description:** Every in-scope requirement must be observable or measurable
enough to validate later.

**Pass condition:** Requirements name concrete actors, states, inputs, outputs,
or externally observable artifact changes.

**Fail condition:** A requirement is phrased only as intent, quality, or
internal desire with no observable outcome.

---

#### GOAL-AC-TRACE

| Field | Value |
|---|---|
| Reviewer | spec-reviewer-a |
| Type | TYPE-D |
| Severity | Major |
| Default | FAIL |

**Description:** Every stated goal must trace to at least one acceptance
criterion.

**Pass condition:** Each goal has an explicit or unambiguous matching AC.

**Fail condition:** A stated goal has no acceptance coverage.

---

#### AC-OBSERVABLE

| Field | Value |
|---|---|
| Reviewer | spec-reviewer-a |
| Type | TYPE-H |
| Severity | Major |
| Default | FAIL |

**Description:** Acceptance criteria must describe externally observable
behavior, state, or artifact changes.

**Pass condition:** Each AC can be verified by later automated test, manual
inspection, or quality-gate evidence.

**Fail condition:** An AC requires unverifiable judgment such as "works well"
without observable evidence.

---

#### SCOPE-BOUNDARY

| Field | Value |
|---|---|
| Reviewer | spec-reviewer-a |
| Type | TYPE-H |
| Severity | Major |
| Default | FAIL |

**Description:** Non-goals, exclusions, or out-of-scope boundaries must be
explicit where the feature could otherwise expand.

**Pass condition:** Scope boundaries are explicit or the feature is narrow
enough that no material expansion risk exists.

**Fail condition:** The requirements imply multiple plausible scopes and do not
state what is excluded.

---

#### CONSTRAINTS-EXPLICIT

| Field | Value |
|---|---|
| Reviewer | spec-reviewer-a |
| Type | TYPE-H |
| Severity | Major |
| Default | FAIL |

**Description:** Material data, compatibility, security, migration, governance,
or approval constraints must be stated when implied by the requirements.

**Pass condition:** Implied constraints are explicit or explicitly marked not in
scope.

**Fail condition:** A material constraint is implied but left unstated.

---

#### RISK-VALIDATION-SURFACE

| Field | Value |
|---|---|
| Reviewer | spec-reviewer-a |
| Type | TYPE-H |
| Severity | Major |
| Default | FAIL |
| Skip condition | No high-risk claim or risk surface is present |

**Description:** High-risk claims must have a planned validation surface.

**Pass condition:** The claim maps to an AC, manual inspection target, or later
quality-gate evidence path.

**Fail condition:** A high-risk claim is made with no way to validate it later.

---

### Reviewer-B Checks (Ambiguity and Downstream Readiness — 6 checks)

#### AMBIGUITY

| Field | Value |
|---|---|
| Reviewer | spec-reviewer-b |
| Type | TYPE-H |
| Severity | Major |
| Default | FAIL |

**Description:** Terms, actors, states, inputs, and outputs must be concrete
enough that two implementers would not reasonably build different behavior.

**Pass condition:** Material terms are defined by context or explicit wording.

**Fail condition:** A material term or state allows incompatible
interpretations.

---

#### CONTRADICTION

| Field | Value |
|---|---|
| Reviewer | spec-reviewer-b |
| Type | TYPE-D |
| Severity | Critical |
| Default | FAIL |

**Description:** Requirements, ACs, constraints, and non-goals must not directly
conflict.

**Pass condition:** No direct conflict is present.

**Fail condition:** Any pair of statements cannot both be true.

---

#### EDGE-CASE-COVERAGE

| Field | Value |
|---|---|
| Reviewer | spec-reviewer-b |
| Type | TYPE-H |
| Severity | Major |
| Default | FAIL |

**Description:** Acceptance tests must cover material negative paths, empty
states, boundary states, or failure modes implied by the requirements.

**Pass condition:** Material edge cases are covered or explicitly out of scope.

**Fail condition:** The requirements imply an edge case but ACs omit it.

---

#### ASSUMPTIONS-RESOLVABLE

| Field | Value |
|---|---|
| Reviewer | spec-reviewer-b |
| Type | TYPE-H |
| Severity | Major |
| Default | FAIL |

**Description:** Assumptions must be resolved by investigation or marked as
decisions needed before design/task decomposition.

**Pass condition:** Each material assumption is resolved, bounded, or explicitly
queued as a decision.

**Fail condition:** A material assumption remains hidden or unresolved.

---

#### APPROVAL-BOUNDARY

| Field | Value |
|---|---|
| Reviewer | spec-reviewer-b |
| Type | TYPE-H |
| Severity | Critical |
| Default | FAIL |
| Skip condition | No human approval, governance, or irreversible-change boundary is in scope |

**Description:** Human approval, governance, or irreversible-change boundaries
must be testable when implied by the requirements.

**Pass condition:** The boundary and approval point are explicit and observable.

**Fail condition:** The feature can cross an approval or governance boundary
without a stated check.

---

#### DOWNSTREAM-READINESS

| Field | Value |
|---|---|
| Reviewer | spec-reviewer-b |
| Type | TYPE-H |
| Severity | Major |
| Default | FAIL |

**Description:** The specification must be ready for implementation-policy
review without requiring the design reviewer to invent missing product behavior.

**Pass condition:** Open questions are either resolved, bounded, or explicitly
assigned before the next gate.

**Fail condition:** The next gate would have to decide product behavior rather
than design implementation policy.

---

## Part 1: Implementation Policy Review Checklist (impl-review-loop)

Complete reference for all 19 checks in the impl-review-loop. Checks are split
across two reviewers: impl-reviewer-a (structural soundness, 9 checks) and
impl-reviewer-b (implementability/risk, 10 checks).

### Check Types

- **TYPE-D** (Deterministic): Pass/fail can be determined by reading artifact
  content against explicit rules. No qualitative judgment required.
- **TYPE-H** (Heuristic): Requires judgment about intent, scope, or adequacy.
  The reviewer must cite specific evidence and apply the rubric in
  `references/impl-review-rubric.md`.

### Default Behavior

All checks **default to FAIL**. A reviewer emits PASS only when positive
evidence is found. Absence of evidence is a finding, not a pass.

### Legacy Design Mode

When `legacy_design: true` in precheck-result.json, impl-reviewer-a downgrades
absent template fields from Major/Critical to Minor `[LEGACY COMPAT]` advisories.

---

### Reviewer-A Checks (Structural Soundness — 9 checks)

#### ARCH-COVERAGE

| Field | Value |
|---|---|
| Reviewer | impl-reviewer-a |
| Type | TYPE-D |
| Severity | Critical |
| Default | FAIL |

**Description:** `## Architecture` section must describe component boundaries,
feature integration with existing components, and technology choices per major
layer.

**Pass condition:** All three elements present in the Architecture section.

**Fail condition:** Any of the three elements is absent or described in fewer
than meaningful detail (one-sentence summary with no component interaction
description).

---

#### NO-CIRCULAR-DEPS

| Field | Value |
|---|---|
| Reviewer | impl-reviewer-a |
| Type | TYPE-D |
| Severity | Major |
| Default | FAIL |

**Description:** Component dependency graph must be acyclic.

**Pass condition:** No cycle detected in stated component dependencies.

**Fail condition:** Any cycle detected in component dependency declarations.

**Skip condition:** No explicit component dependency declarations present.

---

#### DATA-COVERAGE

| Field | Value |
|---|---|
| Reviewer | impl-reviewer-a |
| Type | TYPE-D |
| Severity | Major |
| Default | FAIL |

**Description:** `## Data Plan` must include `Data Entities:`, `Existing Data
Affected:`, and `Migration Strategy:` sub-fields.

**Pass condition:** All three sub-fields present. If no data changes, each
sub-field explicitly states "No data changes."

**Fail condition:** Any sub-field absent; section entirely absent.

---

#### API-COVERAGE

| Field | Value |
|---|---|
| Reviewer | impl-reviewer-a |
| Type | TYPE-D |
| Severity | Major |
| Default | FAIL |

**Description:** `## API / Contract Plan` must list all new/changed endpoints
with method, path, request schema, and response schema.

**Pass condition:** All endpoints documented; or "No API changes" explicitly
stated when no endpoints are affected.

**Fail condition:** API changes implied by requirements but not documented;
missing method, path, or schema for any endpoint.

---

#### SECURITY-COVERAGE

| Field | Value |
|---|---|
| Reviewer | impl-reviewer-a |
| Type | TYPE-D (primary) / TYPE-H (fallback) |
| Severity | Major |
| Default | FAIL |

**Description:** `## Security Boundaries` section must address trust boundaries,
auth/authz mechanisms, PII data classification, and relevant OWASP concerns.

**Pass condition (TYPE-D):** Security Boundaries section present and covers all
four required areas.

**Fail condition (TYPE-D):** Section present but missing one or more required
areas.

**Fallback (TYPE-H):** If section absent, scan User Stories for PII keywords.
PII keywords found → Major finding. No PII keywords → Minor advisory.

---

#### FRONTEND-BACKEND-CONSISTENCY

| Field | Value |
|---|---|
| Reviewer | impl-reviewer-a |
| Type | TYPE-D |
| Severity | Major |
| Default | FAIL |
| Skip condition | Feature Type is api-only, frontend-only, cli, or library |

**Description:** Frontend Plan API references must match API / Contract Plan
endpoints. Frontend component data fields must match API response schemas.

**Pass condition:** All frontend-referenced endpoints exist in API plan; all
displayed fields are covered by API response schemas.

**Fail condition:** Any mismatch between Frontend Plan and API / Contract Plan.

---

#### TEST-STRATEGY-COVERAGE

| Field | Value |
|---|---|
| Reviewer | impl-reviewer-a |
| Type | TYPE-D |
| Severity | Major |
| Default | FAIL |

**Description:** `## Test Strategy` must cover unit, integration, and acceptance
test scopes, plus planned verification evidence such as commands, report paths,
or artifact names when design.md identifies project tooling or CI. Fullstack
features with critical user journeys must name an E2E, user-journey, acceptance,
or manual verification evidence path.

**Pass condition:** All three test levels addressed with scope descriptions and
applicable planned verification evidence named.

**Fail condition:** Section absent; only one or two test levels addressed; or an
applicable critical user journey has no planned verification path.

---

#### NO-UNDEFINED-COMPONENT

| Field | Value |
|---|---|
| Reviewer | impl-reviewer-a |
| Type | TYPE-D |
| Severity | Critical |
| Default | FAIL |

**Description:** Every component referenced in Architecture, Frontend Plan,
Backend Plan, or API / Contract Plan must be defined in design.md or identified
as an established existing system component.

**Pass condition:** All referenced components are defined or identified.

**Fail condition:** Any component referenced but not defined in design.md and
not identifiable from investigation.md or requirements context.

---

#### ADR-PRESENT

| Field | Value |
|---|---|
| Reviewer | impl-reviewer-a |
| Type | TYPE-D |
| Severity | Major |
| Default | FAIL |

**Description:** Referenced ADR documents must exist at `docs/adr/NNNN-<slug>.md`.
New architectural decisions without ADRs must be flagged.

**Pass condition:** All referenced ADRs exist; or no ADRs referenced and no new
architectural decisions introduced.

**Fail condition:** Referenced ADR file missing; or new architectural decision
introduced with no ADR.

---

### Reviewer-B Checks (Implementability/Risk — 10 checks)

#### DECISION-JUSTIFIED

| Field | Value |
|---|---|
| Reviewer | impl-reviewer-b |
| Type | TYPE-H |
| Severity | Major |
| Default | FAIL |

**Description:** Every technology or architecture decision must include a stated
rationale.

**Pass condition:** All decisions have "because" / "since" / "due to" clauses or
reference an ADR that provides the rationale.

**Fail condition:** Any "We will use X" statement without rationale.

---

#### OPEN-QUESTIONS-RESOLVABLE

| Field | Value |
|---|---|
| Reviewer | impl-reviewer-b |
| Type | TYPE-H |
| Severity | Major |
| Default | FAIL |

**Description:** Open Questions must each have: an owner (role), a `Blocks
Implementation:` field, and a `Resolution Path:`.

**Pass condition:** All blocking questions have owners and resolution paths.
Non-blocking questions with owners are Minor if incomplete.

**Fail condition:** Any blocking question has no resolution path; any question
has no owner.

---

#### ASSUMPTIONS-VALID

| Field | Value |
|---|---|
| Reviewer | impl-reviewer-b |
| Type | TYPE-H |
| Severity | Major |
| Default | FAIL |

**Description:** Each assumption must be grounded in investigation.md, a
reasonable technical default, or accepted risk. If investigation.md is absent
and >1 non-trivial assumption exists, emit Major finding.

**Pass condition:** All assumptions are grounded or explicitly accepted as risks.

**Fail condition:** investigation.md absent with >1 non-trivial ungrounded
assumption; or any assumption contradicted by investigation.md findings.

---

#### NO-REQ-CONTRADICTION

| Field | Value |
|---|---|
| Reviewer | impl-reviewer-b |
| Type | TYPE-D (primary, Critical) / TYPE-H (fallback, Major) |
| Severity | Critical (primary) / Major (fallback) |
| Default | FAIL |

**Description:** Requirements constraints must be addressed in design.md.

**Pass condition (primary):** `## Constraint Compliance` present and covers all
requirements.md constraints.

**Fail condition (primary):** Constraint Compliance present but missing one or
more constraints → Critical.

**Fallback:** Section absent; scan requirements.md for constraints; any
unaddressed → Major.

---

#### PERF-ADDRESSED

| Field | Value |
|---|---|
| Reviewer | impl-reviewer-b |
| Type | TYPE-H |
| Severity | Major |
| Default | FAIL |

**Description:** Performance requirements (numeric SLAs) in requirements.md must
be addressed in design.md with a concrete strategy.

**Pass condition:** All performance requirements addressed with a design strategy;
or no performance requirements present.

**Fail condition:** Any numeric performance threshold in requirements.md with no
corresponding design strategy.

---

#### DEPLOYMENT-CONCRETE

| Field | Value |
|---|---|
| Reviewer | impl-reviewer-b |
| Type | TYPE-H |
| Severity | Major |
| Default | FAIL |

**Description:** `## Deployment / CI Plan` must specify deployment target, feature
flag strategy, CI changes, and migration execution order (for schema changes).

**Pass condition:** All required elements present; migration execution order stated
when schema changes exist.

**Fail condition:** Section absent; or migration execution order missing for schema-
changing feature.

---

#### MIGRATION-PLANNED

| Field | Value |
|---|---|
| Reviewer | impl-reviewer-b |
| Type | TYPE-D |
| Severity | Major |
| Default | FAIL |

**Description:** Features with schema changes must document migration file
naming, rollback strategy, and performance impact acknowledgement (for tables
>10k rows).

**Pass condition:** Migration plan complete for all schema changes; or "No data
changes" stated.

**Fail condition:** Schema changes declared with no migration file path, no
rollback strategy, or no performance acknowledgement for large tables.

---

#### INTEGRATION-IDENTIFIED

| Field | Value |
|---|---|
| Reviewer | impl-reviewer-b |
| Type | TYPE-H |
| Severity | Major |
| Default | FAIL |

**Description:** Every external integration must be listed with name, contract
version, and failure behaviour.

**Pass condition:** All integrations documented with required detail.

**Fail condition:** Any integration mentioned without contract version or failure
behaviour; or integration implied by requirements but undocumented.

---

#### DESIGN-WITHIN-SCOPE

| Field | Value |
|---|---|
| Reviewer | impl-reviewer-b |
| Type | TYPE-H |
| Severity | Major |
| Default | FAIL |

**Description:** Design must not introduce unRequested components (scope creep)
and must not omit required capabilities (under-scope).

**Pass condition:** Design covers all Goals and User Stories; no extra capabilities
introduced without requirement backing.

**Fail condition:** Any design element with no requirement backing; any requirement
capability absent from design.

---

#### VERIFICATION-PATH-CONCRETE

| Field | Value |
|---|---|
| Reviewer | impl-reviewer-b |
| Type | TYPE-H |
| Severity | Major |
| Default | FAIL |
| Skip condition | No high-risk design claim or risk surface requiring a separate verification path |

**Description:** High-risk design claims or risk surfaces not already fully
covered by performance, deployment, or migration checks must name a concrete
validation path.

**Pass condition:** Each applicable high-risk surface names a command, CI job,
metric target, acceptance test artifact, E2E/user-journey evidence artifact,
rollout monitor, or review artifact.

**Fail condition:** Security/authz, PII, payment, external contract, integration
failure behaviour, or critical fullstack user journey risk exists with no
concrete validation path.

**Skip condition:** No high-risk design claim or risk surface requires a
separate verification path.

---

## Part 2: Task Review Checklist (task-review-loop)

Complete reference for all 23 checks in the task-review-loop. Checks are split
across two reviewers: task-reviewer-a (structural coverage, 14 checks) and
task-reviewer-b (quality/risk, 9 checks).

### Check Types

- **TYPE-D** (Deterministic): Pass/fail can be determined by reading artifact
  content against explicit rules. No qualitative judgment required.
- **TYPE-H** (Heuristic): Requires judgment about intent, scope, or adequacy.
  The reviewer must cite specific evidence and apply the rubric in
  `references/task-review-rubric.md`.

### Default Behavior

All checks **default to FAIL**. A reviewer emits PASS only when positive
evidence is found. Absence of evidence is a finding, not a pass.

---

### Reviewer-A Checks (Structural Coverage — 14 checks)

#### PREREQ-AC-IDS

| Field | Value |
|---|---|
| Reviewer | task-reviewer-a |
| Type | TYPE-D |
| Severity | Critical |
| Default | FAIL |

**Description:** Every AC-NNN identifier referenced in a task's `Requirements:`
field must resolve to an actual criterion in `acceptance-tests.md`.

**Pass condition:** All referenced AC IDs exist verbatim in acceptance-tests.md.

**Fail condition:** Any AC-NNN in tasks.md does not appear in acceptance-tests.md
(dangling reference).

---

#### BLOCKERS-FORMAT

| Field | Value |
|---|---|
| Reviewer | task-reviewer-a |
| Type | TYPE-D |
| Severity | Major |
| Default | FAIL |

**Description:** Each task's `Blockers:` field must use canonical format: either
`None` or a comma-separated list of `T-NNN` IDs.

**Pass condition:** Every Blockers field is `None` or matches `^T-\d{3}(,\s*T-\d{3})*$`.

**Fail condition:** Range notation (`T-001..T-005`), prose descriptions, missing
field, or any non-canonical format.

**Note:** DEPENDENCY-CYCLE is SKIP until this check PASS.

---

#### REQ-COVERAGE

| Field | Value |
|---|---|
| Reviewer | task-reviewer-a |
| Type | TYPE-D |
| Severity | Critical |
| Default | FAIL |

**Description:** Every REQ-NNN in requirements.md must appear in at least one
task `Requirements:` field or have a deferral entry in traceability.md.

**Pass condition:** All REQ-NNN IDs are accounted for across tasks or traceability.

**Fail condition:** Any REQ-NNN exists in requirements.md with no task reference
and no traceability.md deferral entry.

---

#### AC-COVERAGE

| Field | Value |
|---|---|
| Reviewer | task-reviewer-a |
| Type | TYPE-D |
| Severity | Critical |
| Default | FAIL |

**Description:** Every AC-NNN in acceptance-tests.md must be traceable to at
least one task.

**Pass condition:** All AC-NNN IDs are referenced in tasks or in traceability.md
with deferral rationale.

**Fail condition:** Any AC-NNN in acceptance-tests.md has no task reference and
no traceability.md deferral entry.

---

#### ORPHAN-TASK

| Field | Value |
|---|---|
| Reviewer | task-reviewer-a |
| Type | TYPE-D |
| Severity | Major |
| Default | FAIL |

**Description:** Every task must reference at least one REQ-NNN (or approved
pseudo-requirement INFRA/HOUSEKEEPING) in its `Requirements:` field.

**Pass condition:** All tasks have at least one requirement reference.

**Fail condition:** Any task has an empty or absent `Requirements:` field with no
recognised pseudo-requirement.

---

#### ORPHAN-TEST

| Field | Value |
|---|---|
| Reviewer | task-reviewer-a |
| Type | TYPE-D |
| Severity | Major |
| Default | FAIL |

**Description:** Every test task must reference at least one AC-NNN.

**Pass condition:** All test tasks (title contains "test"/"spec"/"verify" or
scope is exclusively test-file changes) reference at least one AC-NNN.

**Fail condition:** Any test task has no AC-NNN reference.

---

#### INITIAL-STATE

| Field | Value |
|---|---|
| Reviewer | task-reviewer-a |
| Type | TYPE-D |
| Severity | Major |
| Default | FAIL |

**Description:** In round 1 attempt 1, every task must have `Approval: Draft`
and `Status: Planned`. In later rounds, `Approval:` must not be `Approved`.

**Pass condition:** All tasks have correct Approval and Status field values for
the current round/attempt.

**Fail condition:** Any task has `Approval: Approved` (agent self-approval) or
missing/invalid status field.

---

#### RISK-WORKFLOW-FORMAT

| Field | Value |
|---|---|
| Reviewer | task-reviewer-a |
| Type | TYPE-D |
| Severity | Critical |
| Default | FAIL |

**Description:** Every task must declare matching `Risk:` and `Required Workflow:`
fields per the risk-gate-matrix: low → test-after; medium → acceptance-first;
high/critical → tdd.

**Pass condition:** All tasks have both fields present and correctly paired.

**Fail condition:** Any missing field, unrecognised value, or Risk/Workflow
mismatch.

---

#### NO-DUPLICATE-AC

| Field | Value |
|---|---|
| Reviewer | task-reviewer-a |
| Type | TYPE-D |
| Severity | Major |
| Default | FAIL |

**Description:** No AC-NNN may be the sole primary test target of more than one
task at the same test level.

**Pass condition:** Each AC-NNN appears as a primary test target in at most one
task per test level (unit/integration/e2e).

**Fail condition:** The same AC-NNN is claimed as the primary target by two tasks
with no scope differentiation.

---

#### DEPENDENCY-COMPLETE

| Field | Value |
|---|---|
| Reviewer | task-reviewer-a |
| Type | TYPE-D |
| Severity | Major |
| Default | FAIL |

**Description:** Every task ID referenced in any Blockers field must exist in
tasks.md. Must complete before DEPENDENCY-CYCLE.

**Pass condition:** All referenced Blocker IDs exist in dependency-graph.json
`nodes` array.

**Fail condition:** Any Blocker references a non-existent task ID.

---

#### DEPENDENCY-CYCLE

| Field | Value |
|---|---|
| Reviewer | task-reviewer-a |
| Type | TYPE-D |
| Severity | Critical |
| Default | FAIL |
| Precondition | BLOCKERS-FORMAT == PASS |

**Description:** The dependency graph must be acyclic. Cycles create
unresolvable execution ordering.

**Pass condition:** No cycle detected in dependency-graph.json edges.

**Fail condition:** Any cycle detected; report the cycle path (e.g. T-001 → T-003 → T-001).

**Skip condition:** BLOCKERS-FORMAT is not PASS (cannot build valid graph).

---

#### SINGLE-CONCERN

| Field | Value |
|---|---|
| Reviewer | task-reviewer-a |
| Type | TYPE-H |
| Severity | Major |
| Default | FAIL |

**Description:** Each task addresses one coherent concern. "And" is allowed only
for test/verification work tied to the primary clause, or mandatory housekeeping
(AGENTS.md, CLAUDE.md, traceability.md updates).

**Pass condition:** All tasks address a single coherent concern; any "and" clauses
fall into the allowed categories.

**Fail condition:** Any task title or scope joins two distinct feature concerns
with "and" (e.g. "Add user profile and implement notifications").

See `references/task-review-rubric.md` for examples.

---

#### OBSERVABLE-DONE

| Field | Value |
|---|---|
| Reviewer | task-reviewer-a |
| Type | TYPE-H |
| Severity | Major |
| Default | FAIL |

**Description:** Every Done When item must be concrete and verifiable. Forbidden
verbs: "ensure", "consider", "update X" (no target), "verify is correct", "works
correctly", "review X" (no artifact outcome), "confirm X" (no specific result).
Each non-documentation-only task must include at least one Done When item naming
a concrete verification command or evidence artifact. Documentation-only tasks
may instead name the exact file and section whose change proves completion.

**Pass condition:** All Done When items name a concrete artifact, test result,
metric, command output, or exact documentation file/section for documentation-only
tasks.

**Fail condition:** Any Done When item uses a forbidden verb or pattern, or a
non-documentation-only task lacks a verification command or evidence artifact.

See `references/task-review-rubric.md` for the full forbidden-verb list with examples.

---

#### TRACEABILITY-SYNC

| Field | Value |
|---|---|
| Reviewer | task-reviewer-a |
| Type | TYPE-D |
| Severity | Major |
| Default | FAIL |

**Description:** Every task ID in tasks.md must have a traceability.md entry.
Every requirement ID in traceability.md must exist in requirements.md.

**Pass condition:** Bidirectional consistency between tasks.md, traceability.md,
and requirements.md.

**Fail condition:** Any dangling reference in either direction.

---

### Reviewer-B Checks (Quality/Risk — 9 checks)

#### RISK-APPROPRIATE

| Field | Value |
|---|---|
| Reviewer | task-reviewer-b |
| Type | TYPE-H |
| Severity | Major |
| Default | FAIL |

**Description:** Each task's Risk tier must match its actual scope. Sentinel
surfaces (auth, payment, PII, data migration, external API contracts) require
Risk: high or critical. Pure UI/CSS/docs/test-only tasks must not be high/critical.

**Pass condition:** All task Risk tiers are consistent with their scope.

**Fail condition:** Under-classified sentinel surface (Risk low/medium with auth/
payment/PII/migration scope) or over-classified routine task (Risk high/critical
with UI-only scope).

See `references/task-review-rubric.md` for sentinel surface proximity examples.

---

#### HIGH-CRITICAL-EVIDENCE

| Field | Value |
|---|---|
| Reviewer | task-reviewer-b |
| Type | TYPE-D |
| Severity | Critical |
| Default | FAIL |

**Description:** Tasks with Risk: high or critical must include mandatory Done
When items: Red→Green evidence, independent review verdict, and (for critical)
second approver + signed evidence bundle.

**Pass condition:** All high/critical tasks have all required Done When items.

**Fail condition:** Any high/critical task is missing one or more required Done
When items.

---

#### TASK-SIZE

| Field | Value |
|---|---|
| Reviewer | task-reviewer-b |
| Type | TYPE-H |
| Severity | Major |
| Default | FAIL |

**Description:** Tasks must be right-sized: completable in one focused session.
Oversized tasks span more than three implementation areas or have more than eight
Done When items. Fragmented tasks describe only a single-function or single-file
change with no integration context.

**Pass condition:** All tasks are neither oversized nor fragmented.

**Fail condition:** Any task shows signs of over-sizing or fragmentation per the
rubric.

---

#### EDGE-CASE-COVERAGE

| Field | Value |
|---|---|
| Reviewer | task-reviewer-b |
| Type | TYPE-H |
| Severity | Major |
| Default | FAIL |

**Description:** Every functional task must have at least one error-path or
edge-case acceptance criterion in acceptance-tests.md.

**Pass condition:** All functional tasks have at least one edge-case/error-path
AC in acceptance-tests.md.

**Fail condition:** Any functional task has only happy-path ACs with no
corresponding error-path test task.

---

#### TEST-TYPE-MATCH

| Field | Value |
|---|---|
| Reviewer | task-reviewer-b |
| Type | TYPE-H |
| Severity | Major |
| Default | FAIL |

**Description:** The declared test type (unit/integration/e2e/acceptance) must
match the actual scope of the test task.

**Pass condition:** All test tasks have a declared type consistent with their scope.

**Fail condition:** Any test task whose declared type does not match its scope
(e.g. "unit test" that involves two components).

---

#### ROLLBACK-PLAN

| Field | Value |
|---|---|
| Reviewer | task-reviewer-b |
| Type | TYPE-H |
| Severity | Major |
| Default | FAIL |

**Description:** Tasks with Risk: high or critical must include rollback
consideration: a feature flag, a migration rollback script reference, or an
explicit "Rollback procedure documented and tested" Done When item.

**Pass condition:** All high/critical tasks address rollback.

**Fail condition:** Any high/critical task has no rollback provision.

---

#### SCOPE-DISJOINT

| Field | Value |
|---|---|
| Reviewer | task-reviewer-b |
| Type | TYPE-H |
| Severity | Major |
| Default | FAIL |

**Description:** No two tasks may modify the same file for the same purpose
without a Blockers ordering between them.

**Pass condition:** All file-scope overlaps have a corresponding Blockers
relationship enforcing the order.

**Fail condition:** Two tasks claim to modify the same primary file with no
blocking relationship.

---

#### DEPENDENCY-OVERLAP

| Field | Value |
|---|---|
| Reviewer | task-reviewer-b |
| Type | TYPE-H |
| Severity | Major |
| Default | FAIL |

**Description:** Blocker relationships must reflect genuine logical dependencies.
Spurious blockers (no real dependency) and missing blockers (real dependency
undeclared) are both findings.

**Pass condition:** All Blocker relationships reflect genuine logical dependencies;
no spurious or missing blockers.

**Fail condition:** Any spurious blocker (inflates critical path) or missing
blocker (would cause integration failure).

---

#### BUGFIX-DIAGNOSTIC-PATH

| Field | Value |
|---|---|
| Reviewer | task-reviewer-b |
| Type | TYPE-H |
| Severity | Major |
| Default | FAIL |
| Skip condition | No bugfix or debugging task in scope |

**Description:** Bugfix, regression fix, debugging, failure diagnosis,
flaky-test, or incident remediation tasks must include a systematic diagnostic
path before implementation.

**Pass condition:** Each applicable task includes reproduction evidence or an
exact reproduction command/symptom, a diagnostic/root-cause investigation step,
and a regression test, verification command, or evidence artifact proving the
original failure is fixed.

**Fail condition:** Any applicable task starts directly with an implementation
change or lacks reproduction, diagnostic, or regression/verification evidence.

**Skip condition:** No bugfix/debugging task exists in tasks.md.
