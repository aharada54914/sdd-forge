# Task review: cloud-orchestration

Attempt: 1
Round: 2
Verdict: NEEDS_WORK

- Reviewer b, TASK-SIZE (Major): specs/cloud-orchestration/tasks.md T-007 combines provider skill/manifests packaging, bootstrap routing, cross-platform install/uninstall dependency management, CI/repository suite registration and native host evaluation. Its Goal, Planned Files and Done When therefore exceed three distinct implementation areas and do not form a realistic single focused session. Split packaging/install lifecycle from bootstrap routing and suite/host integration, with explicit dependencies and separate completion evidence.

## Applied correction

Split T-007 packaging/install lifecycle from T-011 bootstrap routing, suite registration and native host integration.

These decomposition corrections preserve the user-approved scope, risk tiers and
acceptance requirements. They do not waive findings or approve cloud operations.
All subsequent reviews use fresh reserved native contexts.
