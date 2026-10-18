# Task review: cloud-orchestration

Attempt: 1
Round: 3
Verdict: BLOCKED

- Reviewer b, TASK-SIZE (Major): tasks.md T-004 and T-005 each combine owner-aware routing/upstream locks, real IaC example synthesis, guarded prepare/apply and preview policy, and timeout/reconcile/no-op lifecycle implementation. Done When bullets 1–3 aggregate independently verifiable outcomes across AC-002/003/004/006/007/009. This prevents focused-session implementation and independently gated intermediate completion. Split each provider delivery into ordered routing/local-validation/example and execution/recovery units, with explicit ownership of shared tests.

## Applied correction

Split Azure/AWS local preparation (T-004/T-005) from governed execution and recovery (T-012/T-013). Begin a new attempt while retaining the blocked attempt and all identity reservations.

These decomposition corrections preserve the user-approved scope, risk tiers and
acceptance requirements. They do not waive findings or approve cloud operations.
All subsequent reviews use fresh reserved native contexts.
