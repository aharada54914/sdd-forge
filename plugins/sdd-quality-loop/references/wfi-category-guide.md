# WFI Category Guide

This reference defines the WFI categories (the scope axis), the mechanism axis, their
classification criteria, and their language rules. Read this document before drafting
any WFI.

## Section 1 — Classification Flowchart (scope axis)

```
Does the Proposed Change touch graders, gate thresholds, retrospective or
audit logic, or run-record definitions (anything that MEASURES the workflow)?
      │
      ├─ YES → Category: measurement  +  Meta-Change: true
      │         Strict audit lane (Section 5). Language rules follow the
      │         underlying target (generic if plugin-side, concrete if
      │         project-side).
      │
      └─ NO
          │
          Does the change alter approval policy, escalation rules, or what
          humans review (rather than what agents do)?
              │
              ├─ YES → Category: human-process
              │         Application is always a human action.
              │
              └─ NO
                  │
                  Is the friction evidence drawn from the "Review Gate Metrics"
                  table (spec_review_rounds, spec_review_blocked_rate,
                  impl_review_rounds, task_review_blocked_rate,
                  impl_review_blocked_rate, impl_review_legacy_design_rate) or
                  does it involve cross-plugin handoff transitions (e.g., design
                  review → task decomposition → implementation flow)?
                        │
                        ├─ YES → Category: plugin-improvement
                        │         Use generic workflow terminology (Section 2).
                        │         A GitHub Issue will be created after audit
                        │         completion.
                        │
                        └─ NO  → Category: app-dev-efficiency
                                  Use project-specific concrete detail
                                  (Section 3). No GitHub Issue is created.
```

**Examples of plugin-improvement friction:**
- `impl_review_rounds_per_feature` averages 2.8 over 4 features (design review gate cycles)
- `spec_review_blocked_rate` is 33% (specification review gate blocked rate)
- `task_review_blocked_rate` is 50% (task decomposition review gate blocked rate)
- Cross-plugin handoff: designs consistently require rework before the task decomposition
  review gate accepts them

**Examples of app-dev-efficiency friction:**
- Feature `user-auth`: T-003, T-005, T-007 each generated `edge-case` review tickets
- Acceptance tests regularly lack negative-path scenarios (review ticket type: `test-gap`)
- Task sizing in feature `payment-flow` produced tasks too large for single-session impl

---

## Section 2 — plugin-improvement: Generic Language Rules

For `Category: plugin-improvement` WFIs, the following sections **must** use only
generic workflow terms:
- `## Root Cause Hypothesis`
- `## Proposed Change` (Change Description column)
- `## Expected Effect`

The `## Problem Evidence` section **may** cite raw metric names and report paths as
they appear in retrospective reports (they are direct evidence, not prose description).

### Forbidden Terms → Required Generic Substitutions

| Forbidden Term | Required Generic Term |
|---|---|
| `sdd-impl-review`, `impl-review-loop`, `impl-reviewer-a`, `impl-reviewer-b` | `design review gate` |
| `sdd-task-review`, `task-review-loop`, `task-reviewer-a`, `task-reviewer-b` | `task decomposition review gate` |
| `quality-gate`, `sdd-quality-loop` (when describing the gate concept) | `quality verification gate` |
| `sdd-bootstrap-interviewer` | `specification generator` |
| `spec-review-loop`, `spec-reviewer-a`, `spec-reviewer-b` | `specification review gate` |
| `implement-task`, `implement-tasks` | `implementation phase` |
| `workflow-retrospective` | `retrospective analysis` |
| `spec_review_rounds`, `impl_review_rounds`, `task_review_rounds` | `review gate round count` |
| `spec_review_blocked_rate`, `impl_review_blocked_rate`, `task_review_blocked_rate` | `review gate blocked rate` |
| `impl_review_legacy_design_rate` | `design document maturity rate` |
| `legacy_design` flag | `design document maturity` |
| `sdd-sudo`, `sdd-lite`, `sdd-adopt` | `workflow bypass mode`, `lightweight track`, `project setup` |
| `sdd-review-loop` (plugin name) | `review gate plugin` |

### Generic Language Examples

**WRONG (plugin-specific):**
> Root Cause: The `impl-review-loop` requires 2–3 rounds because `sdd-bootstrap-interviewer`
> does not produce a `## Data Plan` section that meets `impl-reviewer-a`'s DATA-COVERAGE check.

**CORRECT (generic):**
> Root Cause: The design review gate requires multiple rounds because the specification
> generator produces designs that lack a data plan section, causing the gate to flag
> missing data coverage on the first attempt.

**WRONG:**
> Expected Effect: Reduce `impl_review_rounds_per_feature` from 2.8 to ≤1.5.

**CORRECT:**
> Expected Effect: Reduce the average review gate round count from 2.8 to ≤1.5 over
> the next three features.

### Generic Metric Names for Expected Effect and Verification Plan

| Retrospective Table Column | Generic Name (use in Expected Effect / Verification Plan) |
|---|---|
| `spec_review_rounds_per_feature` | `average specification review gate round count` |
| `spec_review_blocked_rate` | `specification review gate blocked rate` |
| `task_review_rounds_per_feature` | `average task decomposition review gate round count` |
| `task_review_blocked_rate` | `task decomposition review gate blocked rate` |
| `impl_review_rounds_per_feature` | `average design review gate round count` |
| `impl_review_blocked_rate` | `design review gate blocked rate` |
| `impl_review_legacy_design_rate` | `design document maturity rate` |
| Avg QG Cycles per Task | `average quality verification gate cycles per task` |
| Total Blocked Count | `total gate-blocked count` |
| Auto-fix Rate | `review ticket auto-fix rate` |

---

## Section 3 — app-dev-efficiency: Specificity Rules

For `Category: app-dev-efficiency` WFIs, all sections **must** use project-specific
concrete detail. Generic language is insufficient.

**Required specificity:**
- Name the feature slug or task IDs where the friction appeared
  (e.g., `feature: user-auth`, `tasks: T-003, T-005, T-007`)
- Reference specific review ticket types and their IDs
  (e.g., `RT-0012 (edge-case)`, `RT-0019 (test-gap)`)
- In `## Proposed Change`, name the specific file and section to modify
  (e.g., `AGENTS.md § Task Sizing Guidelines` or `specs/templates/acceptance-tests.md`)
- In `## Expected Effect`, state the concrete improvement in the project's own terms
  (e.g., "Reduce edge-case tickets from 3/feature to ≤1/feature in the payment-flow area")

**Acceptable (app-dev-efficiency):**
> Root Cause: Features in the `payment-flow` area consistently produce tasks larger than
> one session (T-012, T-015, T-018 each took 3+ QG cycles). The task-splitting guideline
> in AGENTS.md does not cap task complexity for flows with external API dependencies.

**NOT acceptable (too vague for app-dev-efficiency):**
> Root Cause: Tasks are too large.

---

## Section 4 — GitHub Issue Template (plugin-improvement only)

When `wfi-audit-cycle` creates the GitHub Issue for a `plugin-improvement` WFI, use
this format:

**Title:**
```
WFI-NNN: <problem summary in generic terms>
```
Example: `WFI-003: Reduce design review gate round count across features`

**Body:**
```markdown
## Workflow Improvement Proposal

**WFI-ID:** WFI-NNN
**Category:** plugin-improvement
**Audit-Status:** Human-Pending (2 audit cycles complete)

## Problem

<2–3 sentence summary using only generic terms from Section 2.
Cite the specific metric values from Problem Evidence.>

## Proposed Change

| Target File | Change Description |
|---|---|
| <file> | <generic description> |

## Expected Effect

<Quantitative target using generic metric names from Section 2.>

## Verification

<Which retrospective metric rows will confirm improvement, and after how many features.>

---
*This issue was auto-generated by the SDD workflow-retrospective skill after
2 independent audit cycles. To approve: edit `docs/workflow-improvements/WFI-NNN.md`
and set `Status: Approved` (human action required; agent writes are blocked).*
```

**Labels:** `workflow-improvement`, `plugin-improvement`

---

## Section 5 — Mechanism Axis and the Meta-Change Strict Lane

### Mechanism axis (orthogonal to Category)

Every WFI also carries a `Mechanism:` field describing WHAT KIND of thing changes.
The scope axis (Category) says where the change lands; the mechanism axis feeds
aggregate analysis ("which mechanism's improvements actually get Verified?").

| Mechanism | Meaning | Typical targets |
|---|---|---|
| `instructions` | Prompt/guidance/rubric text | SKILL guidance referenced by AGENTS.md, review rubrics |
| `memory` | Persistent knowledge files | AGENTS.md, CLAUDE.md, spec templates |
| `tools` | Executable scaffolding | scripts, hooks, agent definitions, schemas |
| `architecture` | Process structure | gate ordering, reviewer counts, approval placement |
| `model-routing` | Model selection per stage | escalation tiers, per-agent model choices |

`memory`-mechanism WFIs have a known failure mode: additive-only growth dilutes
instructions over time (context bloat). The retrospective flags any memory-target
file that only ever grows; prefer consolidation over appending.

### Meta-Change strict lane

A WFI with `Meta-Change: true` (always the case for `Category: measurement`)
changes the instruments that decide whether improvements worked. Self-modifying
systems are demonstrably capable of gaming their own metrics, so these WFIs get
extra scrutiny:

1. **auditor-b anti-Goodhart check** — Cycle 2 must explicitly answer: "Does this
   change make any gate, grader, threshold, or metric easier to satisfy without
   improving the underlying outcome?" A YES is a BLOCKED verdict.
2. **Non-decreasing guard** — the number of gates, deterministic checks, tests,
   and audit criteria after the change must be greater than or equal to the count
   before it. Any decrease requires an explicit human-visible justification in
   the WFI.
3. **Human approval display** — the audit summary presented for human approval
   must lead with `Meta-Change: true` so the approver knows they are approving a
   change to measurement itself.
