# Task Review Checklist

Complete reference for all 22 checks in the task-review-loop. Checks are split
across two reviewers: task-reviewer-a (structural coverage, 14 checks) and
task-reviewer-b (quality/risk, 8 checks).

## Check Types

- **TYPE-D** (Deterministic): Pass/fail can be determined by reading artifact
  content against explicit rules. No qualitative judgment required.
- **TYPE-H** (Heuristic): Requires judgment about intent, scope, or adequacy.
  The reviewer must cite specific evidence and apply the rubric in
  `references/task-review-rubric.md`.

## Default Behavior

All checks **default to FAIL**. A reviewer emits PASS only when positive
evidence is found. Absence of evidence is a finding, not a pass.

---

## Reviewer-A Checks (Structural Coverage — 14 checks)

### PREREQ-AC-IDS

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

### BLOCKERS-FORMAT

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

### REQ-COVERAGE

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

### AC-COVERAGE

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

### ORPHAN-TASK

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

### ORPHAN-TEST

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

### INITIAL-STATE

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

### RISK-WORKFLOW-FORMAT

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

### NO-DUPLICATE-AC

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

### DEPENDENCY-COMPLETE

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

### DEPENDENCY-CYCLE

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

### SINGLE-CONCERN

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

### OBSERVABLE-DONE

| Field | Value |
|---|---|
| Reviewer | task-reviewer-a |
| Type | TYPE-H |
| Severity | Major |
| Default | FAIL |

**Description:** Every Done When item must be concrete and verifiable. Forbidden
verbs: "ensure", "consider", "update X" (no target), "verify is correct", "works
correctly", "review X" (no artifact outcome), "confirm X" (no specific result).

**Pass condition:** All Done When items name a concrete artifact, test result,
metric, or command output.

**Fail condition:** Any Done When item uses a forbidden verb or pattern.

See `references/task-review-rubric.md` for the full forbidden-verb list with examples.

---

### TRACEABILITY-SYNC

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

## Reviewer-B Checks (Quality/Risk — 8 checks)

### RISK-APPROPRIATE

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

### HIGH-CRITICAL-EVIDENCE

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

### TASK-SIZE

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

### EDGE-CASE-COVERAGE

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

### TEST-TYPE-MATCH

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

### ROLLBACK-PLAN

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

### SCOPE-DISJOINT

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

### DEPENDENCY-OVERLAP

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
