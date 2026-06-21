---
name: quality-gate
description: Independently verify an Implementation Complete task with a Default-FAIL verification contract, deterministic checks, and an isolated critical reviewer, then decide whether it is Done.
disable-model-invocation: true
---

> **Caller**: This skill is invoked by `sdd-ship`. Do not invoke directly.
> Results are returned to the caller; no downstream skill is auto-invoked.

# Quality Gate

Use after `implement-task` has set a task to `Implementation Complete`.

## Preconditions

If `AGENTS.md` is absent at the repository root, stop immediately and direct
the user to run `/sdd-bootstrap:sdd-adopt`; do not proceed without it.
Missing `reports/quality-gate/` or `docs/review-tickets/` directories may be
created on the fly before continuing.

## Required Reading

Read the task, implementation report, requirements, design, acceptance tests,
traceability, contracts, ADRs, Git diff, and all bundled references, including
`deterministic-check-policy.md`, `evaluation-rubric.md`, `risk-gate-matrix.md`,
and `risk-classification-policy.md`.

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
6. Run the scripted gates with `scripts/*.sh` or `scripts/*.ps1`, in this order:
   - `check-risk` on the task: confirms a valid `Risk:` tier, a non-empty
     `Risk Rationale:`, and — for `high`/`critical` — `Required Workflow: tdd`.
     The tier selects the required-check set per `risk-gate-matrix.md`.
   - `check-placeholders` on the changed production files only.
   - `check-task-state` on tasks.md.
   - `check-contract` on the task contract: enforces the tier-minimum required
     set (superset rule) and, when `required_workflow` is `tdd`, non-empty
     `red_evidence` + `green_evidence` for every test-type check.
   - `check-traceability` on `specs/<feature>/traceability.json`: every
     REQ → AC → TEST → evidence chain is intact (required for `high`/`critical`).
   For `Done` tasks, validate
   `specs/<feature>/verification/<task-id>.evidence.json` with
   `check-evidence-bundle.(sh|ps1)` so the report, contract, and passing
   evidence artifacts are all bound together. For `high`/`critical` the bundle
   must carry `spec_revision`, `build_env`, and `review_verdict.verdict == PASS`;
   for `critical` it must additionally carry a verifiable HMAC `signature` and a
   clean tree (`git_generated_dirty == true` is a hard fail). Always produce the
   bundle with `generate-evidence-bundle.(sh|ps1)` — never hand-author sha256
   fields or the `git_commit` field. The runner binds the bundle to the current
   git commit and computes digests automatically.
7. For `refactor` and `bugfix` tasks with a `baseline-behavior.md`, apply
   `differential-test-policy.md` and classify every BL diff.
8. Run critical review with an isolated evaluator using `evaluation-rubric.md`.
   When the change touches the relevant surface, the evaluator also applies the
   on-demand domain checklists — `security-checklist.md` (user input, auth,
   secrets, external systems, AI/LLM), `performance-checklist.md` (data access,
   hot paths, rendering), and `accessibility-checklist.md` (user-facing UI).
   Load a checklist only when its domain is in scope, to keep review context lean.
   On Claude Code use the `sdd-evaluator` subagent. On Codex use the shipped
   `sdd-evaluator` TOML agent; do not create new agent role files under
   `~/.codex/agents/`. Elsewhere, perform the review in a fresh session or a
   clearly separated critical-review pass. For `high`/`critical` tasks, record
   the evaluator's verdict as `review_verdict` in the evidence bundle;
   `check-evidence-bundle` requires `review_verdict.verdict == PASS`.
9. Classify findings as `Accepted`, `Rejected`, or `Deferred`.
10. Apply only safe fixes allowed by `auto-fix-policy.md`.
11. Repeat critical review for a maximum of 3 cycles.
12. For UI changes, use available browser or Playwright tooling to verify the
    rendered screen, DOM, and console, and when feasible perform the smoke
    run described in `deterministic-check-policy.md`.
13. Create review-ticket YAML for unresolved or non-auto-fixable findings.
14. Update traceability and detect drift using `integrity-policy.md`.
15. Create `reports/quality-gate/<timestamp>.md` naming the task id.

### Sudo Mode

If a valid `SDD_SUDO` flag file exists at the project root (see
`plugins/sdd-quality-loop/references/sudo-mode-policy.md`), routine **approval**
checkpoints auto-pass: record `Approval: Approved (sudo <ISO8601 UTC>)` in
tasks.md and continue. A `refactor`/`bugfix` BL diff classified `accepted` also
auto-passes (mark `(sudo <ISO8601 UTC>)` and update `baseline-behavior.md`).

Sudo never auto-passes genuine **judgment**: `requires_human_decision: true`
findings, architecture/auth/authz/breaking-API/security decisions, and a
`fix-required` baseline diff still stop the gate and require a human. All
deterministic gates apply; every check runs as normal.

## Done Decision

Set the task to `Done` only when:

- `check-risk` passes: valid tier + rationale, and `high`/`critical` declares
  `Required Workflow: tdd`
- `check-contract` passes: every required contract check (the tier-minimum
  superset) is true with existing evidence files; for `tdd`, test checks carry
  `red_evidence` + `green_evidence`
- `check-traceability` passes for `high`/`critical` (REQ → AC → TEST → evidence)
- `check-evidence-bundle` passes: the bundle names the report, contract, and
  contract-passing artifacts, with matching hashes and task id; for
  `high`/`critical` it carries `spec_revision`, `build_env`, and
  `review_verdict.verdict == PASS`; for `critical` it carries a verified HMAC
  `signature` over a clean tree
- for `critical`, a second distinct named approver recorded
  `Second Approval: Approved` (enforced by `check-task-state`; never sudo-bypassed)
- acceptance criteria have tests
- no unresolved Critical or Major finding remains
- required UI verification succeeds
- contracts and ADRs agree with the implementation
- traceability is current

Otherwise set the task to `Blocked` or retain `Implementation Complete`, and
create review tickets. Do not commit, push, or create a PR/MR unless explicitly
requested.

## Post-Done: Automatic Retrospective

When the task transitions to `Done` (all conditions in the Done Decision section
are met), automatically invoke the retrospective flow:

1. Confirm `reports/quality-gate/<timestamp>.md` has been written (step 15 must
   complete first so the new report is included in retrospective metrics).
2. Determine the feature path from the task's spec directory (e.g. `specs/<feature>`).
3. Check `tasks.md` for the feature: if any task with `Approval: Approved` is not
   yet `Status: Done`, append
   `[INFO] retrospective deferred: N approved task(s) still pending Done`
   to the quality-gate report and stop here. Invoke retrospective only when
   every approved task in the feature is `Done`.
4. Invoke `workflow-retrospective` for that feature path:
   - Claude Code: `/sdd-quality-loop:workflow-retrospective specs/<feature>`
   - Codex: `Use the workflow-retrospective skill for specs/<feature>`
5. The retrospective runs in read-only mode and does not affect `Done` status or
   any other task field.
6. If the feature path cannot be determined, skip the retrospective and append a
   `[WARN] retrospective skipped: feature path unknown` line to the quality-gate
   report.

Do **not** invoke this flow when the gate exits with `Blocked` or retains
`Implementation Complete`.

## Common Rationalizations

The gate exists because generators grade their own work generously. Reject
these excuses — each one launders a claim into a `Done`.

- "The report says all tests pass, so they pass" — the report is a claim; rerun
  the checks and read the output yourself (`evaluation-rubric.md`).
- "The checks are green, the review can be light" — green checks do not cover
  spec compliance, untested acceptance criteria, or completion-faking.
- "This finding is probably fine, downgrade it to Minor" — never weaken a
  severity without recording why in the report.
- "A check doesn't apply, I'll just delete it from the contract" — mark it
  `required: false` with a non-empty `waiver_reason`; never remove a check to pass.
- "The evidence file is missing but the result is obviously right" — Default-FAIL:
  no saved evidence means the check stays false.
- "sudo is on, so I can wave this through" — sudo auto-passes routine *approval*
  only; judgment findings and architecture/auth/security decisions still stop
  the gate.

## Red Flags

- Flipping a contract check to `passes: true` without a saved evidence path.
- A handler returning data shaped like the test fixture (completion-faking —
  `Critical`).
- Skipped/`todo`/`xit` tests covering in-scope behavior left unaddressed.
- An acceptance criterion with no test traced to it.
- Setting `Done` while a Critical or Major finding is unresolved.
- Running the critical review in the same context as the implementation.
