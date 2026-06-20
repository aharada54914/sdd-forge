# Implementation Policy Review Checklist

Complete reference for all 18 checks in the impl-review-loop. Checks are split
across two reviewers: impl-reviewer-a (structural soundness, 9 checks) and
impl-reviewer-b (implementability/risk, 9 checks).

## Check Types

- **TYPE-D** (Deterministic): Pass/fail can be determined by reading artifact
  content against explicit rules. No qualitative judgment required.
- **TYPE-H** (Heuristic): Requires judgment about intent, scope, or adequacy.
  The reviewer must cite specific evidence and apply the rubric in
  `references/impl-review-rubric.md`.

## Default Behavior

All checks **default to FAIL**. A reviewer emits PASS only when positive
evidence is found. Absence of evidence is a finding, not a pass.

## Legacy Design Mode

When `legacy_design: true` in precheck-result.json, impl-reviewer-a downgrades
absent template fields from Major/Critical to Minor `[LEGACY COMPAT]` advisories.

---

## Reviewer-A Checks (Structural Soundness — 9 checks)

### ARCH-COVERAGE

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

### NO-CIRCULAR-DEPS

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

### DATA-COVERAGE

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

### API-COVERAGE

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

### SECURITY-COVERAGE

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

### FRONTEND-BACKEND-CONSISTENCY

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

### TEST-STRATEGY-COVERAGE

| Field | Value |
|---|---|
| Reviewer | impl-reviewer-a |
| Type | TYPE-D |
| Severity | Major |
| Default | FAIL |

**Description:** `## Test Strategy` must cover unit, integration, and acceptance
test scopes.

**Pass condition:** All three test levels addressed with scope descriptions.

**Fail condition:** Section absent; or only one or two test levels addressed.

---

### NO-UNDEFINED-COMPONENT

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

### ADR-PRESENT

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

## Reviewer-B Checks (Implementability/Risk — 9 checks)

### DECISION-JUSTIFIED

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

### OPEN-QUESTIONS-RESOLVABLE

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

### ASSUMPTIONS-VALID

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

### NO-REQ-CONTRADICTION

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

### PERF-ADDRESSED

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

### DEPLOYMENT-CONCRETE

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

### MIGRATION-PLANNED

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

### INTEGRATION-IDENTIFIED

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

### DESIGN-WITHIN-SCOPE

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
