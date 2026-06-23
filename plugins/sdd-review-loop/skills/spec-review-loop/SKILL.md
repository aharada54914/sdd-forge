---
name: spec-review-loop
description: Independently review Phase 1 requirements and acceptance tests before implementation-policy review. Persists a validated specification review verdict.
disable-model-invocation: true
---

# Specification Review Loop

Run this manually after Phase 1 artifacts exist and before `impl-review-loop`.
It is the only workflow mechanism permitted to change
`Spec-Review-Status: Pending` to `Spec-Review-Status: Passed`.

## Invocation

```text
/sdd-review-loop:spec-review-loop <feature-slug> [--edit-summary="..."] [--reset]
```

## Preconditions

Read `specs/<feature>/requirements.md` and `acceptance-tests.md`. The
requirements header must be `Spec-Review-Status: Pending`. Determine the next
attempt and round from persisted `reports/spec-review/<feature>/` evidence; do
not invent or replay a round. Invoke
`scripts/spec-review-precheck.sh <feature> <attempt> <round>` with the matching
`--edit-summary` or `--reset` option before creating reviewer input.

The precheck validates canonical paths, slug and positive counters, status,
input hashes, immutable destination, lock, and legal state transition. Stop on
any error; do not write a report or status field. It records canonical hashes
used by the shared review-contract validation foundation.

## Independent reviewer sequence

1. Build a stage `spec` allowed-input manifest from the precheck result. Include
   only canonical requirements, acceptance tests, optional investigation, and
   precheck-result paths with hashes.
2. Start `spec-reviewer-a` in a fresh host context with a new `run_id` and a
   host-session identifier that is distinct from every other reviewer session.
   Persist its returned raw JSON as `reviewer-a.json`; reviewers themselves have
   no write capability.
3. Create `integrated-summary.json` containing only check IDs, severities, and
   counts. It must not reproduce any raw finding text.
4. Start `spec-reviewer-b` in a separate fresh host context. Its allowed-input
   manifest contains only the canonical artifacts, precheck result, and that
   sanitized summary. It must never receive `reviewer-a.json`.
5. Validate both returned schemas, stage/role/run/session identity, allowed
   manifests, and input hashes. Derive the sanitized A summary from A's
   checks, then derive `integrated-verdict.json` from both outputs. Reject a
   duplicated or blank host-session ID, raw report path, altered input,
   malformed output, or a verdict/warning count that contradicts the checks.
6. Write `spec-review-contract.json` and the report from the supplied templates
   only after that validation. The contract must exactly repeat the derived
   verdict and `warningCount`; it is not an independent source of truth.

## State transition rules

| State | permitted invocation | result |
|---|---|---|
| Pending, no evidence | round 1 | PASS changes header to Passed; finding creates NEEDS_WORK |
| Pending, round 1/2 NEEDS_WORK | `--edit-summary`, next round | clean PASS changes header; otherwise writes NEEDS_WORK |
| Pending, round 2 NEEDS_WORK | `--edit-summary`, round 3 | Minor-only produces PASS with `warningCount > 0`; Major/Critical produces BLOCKED |
| Pending, blocked or completed attempt | `--reset`, next attempt round 1 | preserve prior evidence and retain Pending |
| Passed | any normal invocation | reject; reset first |

Never waive findings. Only a validated merged PASS may update the status. A
round-three Minor-only PASS remains a PASS for downstream predecessor checks.

## Required evidence

Each round directory contains `precheck-result.json`, reviewer output targets,
`integrated-summary.json`, `integrated-verdict.json`,
`spec-review-contract.json`, and a rendered report. Save only the orchestrator
summary across reviewer boundaries. The reviewer role files declare cross-stage
raw-report denial and are intentionally distinct from implementation-policy and
task-review roles.
