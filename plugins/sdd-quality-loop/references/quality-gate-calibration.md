# Quality Gate Calibration

Calibration rules for `quality-gate` and the isolated evaluator. Apply these
rules before accepting a task as Done.

## Gate Responsibility

The quality gate verifies an `Implementation Complete` task after code exists.
It may inspect code, run repository commands, compare contracts and ADRs, and
read evidence files. It must not redesign requirements, rewrite task scope, or
silently apply broad workflow changes.

## Evidence Ladder

Rank evidence in this order:

1. Deterministic command output saved to a repository-relative evidence file.
2. Scripted gate output from bundled `scripts/check-*.sh` or `.ps1` tools.
3. Line-level source, contract, ADR, traceability, or acceptance-test inspection.
4. Manual verification artifact such as a screenshot or recorded observation.
5. Implementation report statements.

Items 1-4 may support PASS when they match the task risk tier. Item 5 is a
claim only and never supports PASS by itself.

## Cannot-Verify Handling

If the evaluator or orchestrator cannot verify an in-scope requirement,
contract, acceptance criterion, or risk surface:

- Do not mark the task Done.
- Keep the contract check at `passes: false` or create a review ticket.
- Use a waiver only when the surface is demonstrably out of scope and the check
  is optional.
- Record the missing command, artifact, path, or line-level evidence needed to
  verify it.

## Differential Verification

For bugfix and refactor tasks, compare behavior against `baseline-behavior.md`
or equivalent captured behavior when present. A PASS needs evidence that:

- the reported symptom or target behavior was reproduced or inspected,
- the changed behavior matches the approved BL disposition,
- regression evidence exists for the fixed or preserved behavior.

When no baseline exists, do not block for differential reasons alone. Verify the
changed behavior through the approved specification, tests, contracts, and source
inspection. Record a finding or ticket only when the task explicitly requires a
baseline artifact or the preservation/fix cannot otherwise be verified.

## Domain Surface Triggers

Load domain checklists only when the change touches the surface:

- Security: user input, auth/authz, secrets, external systems, AI/LLM calls,
  private data, permissions, or policy enforcement.
- Performance: data access, hot loops, rendering paths, concurrency, caching,
  large files, or task-critical latency.
- Accessibility: user-facing UI, keyboard interaction, focus management,
  semantics, color contrast, or screen-reader-visible state.

If a domain is not touched, record it as out of scope rather than spending review
context on irrelevant checks.

## Loop Stop Conditions

Run at most three critical-review cycles. Stop earlier when:

- there are zero Critical and zero Major findings,
- unresolved findings require human decision,
- required evidence cannot be produced by the agent,
- the next action belongs to `fix-by-review-ticket` or an upstream review loop.

Do not downgrade a finding to end the loop. Downgrades require explicit
line-level or command evidence in the quality report.
