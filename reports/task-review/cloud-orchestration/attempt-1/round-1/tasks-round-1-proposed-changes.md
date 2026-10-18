# Task review: cloud-orchestration

Attempt: 1
Round: 1
Verdict: NEEDS_WORK

- Reviewer b, TASK-SIZE (Major): specs/cloud-orchestration/tasks.md T-006 Goal, Planned Files and Done When combine both provider collectors, verification reduction, dependency receipt orchestration, protected registry/evaluator dispatch, schema mirrors and guard projections. This exceeds three distinct implementation areas and is not a realistic single focused session; a single completion gate conflates independently testable security-sensitive changes. Split observation/reduction, protected profile dispatch and dependency orchestration into bounded tasks with explicit contracts and blockers.

## Applied correction

Split T-006 into observation/reduction, T-009 protected profile dispatch and T-010 dependency receipts.

These decomposition corrections preserve the user-approved scope, risk tiers and
acceptance requirements. They do not waive findings or approve cloud operations.
All subsequent reviews use fresh reserved native contexts.
