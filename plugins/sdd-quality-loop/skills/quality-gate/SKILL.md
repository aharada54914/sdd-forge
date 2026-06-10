---
name: quality-gate
description: Independently verify an Implementation Complete task, run critical review and repository checks, update traceability, and decide whether it is Done.
---

# Quality Gate

Use after `implement-task` has set a task to `Implementation Complete`.

## Required Reading

Read the task, implementation report, requirements, design, acceptance tests,
traceability, contracts, ADRs, Git diff, and all bundled references.

## Process

1. Reject any target not in `Implementation Complete`.
2. Compare the implementation and report with the approved task and source artifacts.
3. Detect and run all available CI-equivalent checks using `verification-policy.md`.
4. Verify tests using `test-policy.md`.
5. Prefer an independent agent for critical review. If unavailable, perform a
   clearly separated critical-review pass.
6. Classify findings as `Accepted`, `Rejected`, or `Deferred`.
7. Apply only safe fixes allowed by `auto-fix-policy.md`.
8. Repeat critical review for a maximum of 3 cycles.
9. For UI changes, use available browser or Playwright tooling to verify the
   rendered screen, DOM, and console.
10. Create review-ticket YAML for unresolved or non-auto-fixable findings.
11. Update traceability and detect drift using `integrity-policy.md`.
12. Create `reports/quality-gate/<timestamp>.md`.

## Done Decision

Set the task to `Done` only when:

- all required verification succeeds
- acceptance criteria have tests
- no unresolved Critical or Major finding remains
- required UI verification succeeds
- contracts and ADRs agree with the implementation
- traceability is current

Otherwise set the task to `Blocked` or retain `Implementation Complete`, and
create review tickets. Do not commit, push, or create a PR/MR unless explicitly
requested.
