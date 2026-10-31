# Implementation Policy Review Report: workflow-state-integrity — Round 1 / Attempt 1

## Verdict: NEEDS_WORK

| Field | Value |
|---|---|
| Feature | workflow-state-integrity |
| Round | 1 of 3 |
| Attempt | 1 |
| Reviewer-A Verdict | NEEDS_WORK |
| Reviewer-B Verdict | NEEDS_WORK |
| Critical Findings | 0 |
| Major Findings | 3 |
| Minor Findings | 0 |
| Generated | 2026-06-27T03:08:10Z |

## Reviewer-A Findings (Structural Soundness)

- `ADR-PRESENT` (Major): the design introduces a repository-wide workflow-state
  model but does not reference its required ADR.

## Reviewer-B Findings (Implementability/Risk)

- `DEPLOYMENT-CONCRETE` (Major): there is no explicit deployment/CI section
  identifying rollout target, feature-flag decision, or CI secret requirements.
- `VERIFICATION-PATH-CONCRETE` (Major): the design does not name runnable tests,
  fixture locations, or retained evidence for the fail-closed security claims.

## Proposed Changes

1. Bring `design.md` onto the current design template and reference
   `docs/adr/0002-repository-workflow-state-integrity.md`.
2. Add a concrete Deployment / CI Plan and explicitly state that no feature
   flag, environment variables, secrets, or database migration are required.
3. Add a test strategy naming the shell/PowerShell suites, fixture locations,
   CI matrix, and quality-gate evidence.
4. Remove the latent REQ-004 ambiguity by requiring `tasks.md` to be absent
   until both predecessor reviews validly pass.
5. Make the migration registry deterministic by listing each existing feature,
   its profile, the cutoff commit, and its exact historical exceptions.

## Next Steps

Revise `specs/workflow-state-integrity/design.md`, then run attempt 1 round 2
with a human edit summary.
