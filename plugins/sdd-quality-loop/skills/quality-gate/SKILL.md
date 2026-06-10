---
name: quality-gate
description: Independently verify an Implementation Complete task with a Default-FAIL verification contract, deterministic checks, and an isolated critical reviewer, then decide whether it is Done.
disable-model-invocation: true
---

# Quality Gate

Use after `implement-task` has set a task to `Implementation Complete`.

## Required Reading

Read the task, implementation report, requirements, design, acceptance tests,
traceability, contracts, ADRs, Git diff, and all bundled references, including
`deterministic-check-policy.md` and `evaluation-rubric.md`.

## Process

1. Reject any target not in `Implementation Complete`.
2. Create the Default-FAIL verification contract for the task from
   `templates/verification-contract.template.json` following
   `deterministic-check-policy.md`. Treat the implementation report as a
   claim, not as evidence.
3. Compare the implementation and report with the approved task and source artifacts.
4. Detect and run all available CI-equivalent checks using `verification-policy.md`.
   Save real command output as evidence and update the contract.
5. Verify tests using `test-policy.md`.
6. Run the scripted gates: `check-placeholders` on changed production files
   and `check-task-state` on tasks.md (use `scripts/*.sh` or `scripts/*.ps1`).
7. For `refactor` and `bugfix` tasks with a `baseline-behavior.md`, apply
   `differential-test-policy.md` and classify every BL diff.
8. Run critical review with an isolated evaluator using `evaluation-rubric.md`.
   On Claude Code use the `sdd-evaluator` subagent. Elsewhere, perform the
   review in a fresh session or a clearly separated critical-review pass.
9. Classify findings as `Accepted`, `Rejected`, or `Deferred`.
10. Apply only safe fixes allowed by `auto-fix-policy.md`.
11. Repeat critical review for a maximum of 3 cycles.
12. For UI changes, use available browser or Playwright tooling to verify the
    rendered screen, DOM, and console, and when feasible perform the smoke
    run described in `deterministic-check-policy.md`.
13. Create review-ticket YAML for unresolved or non-auto-fixable findings.
14. Update traceability and detect drift using `integrity-policy.md`.
15. Create `reports/quality-gate/<timestamp>.md` naming the task id.

## Done Decision

Set the task to `Done` only when:

- `check-contract` passes: every required contract check is true with
  existing evidence files
- acceptance criteria have tests
- no unresolved Critical or Major finding remains
- required UI verification succeeds
- contracts and ADRs agree with the implementation
- traceability is current

Otherwise set the task to `Blocked` or retain `Implementation Complete`, and
create review tickets. Do not commit, push, or create a PR/MR unless explicitly
requested.
