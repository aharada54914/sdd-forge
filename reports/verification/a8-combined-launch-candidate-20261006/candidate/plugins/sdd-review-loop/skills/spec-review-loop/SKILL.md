---
name: spec-review-loop
description: Independently review Phase 1 requirements and acceptance tests before implementation-policy review. Persists a validated specification review verdict.
disable-model-invocation: false
user-invocable: false
---

# Specification Review Loop

Run this after Phase 1 artifacts exist and before `impl-review-loop`. It is the
only workflow mechanism permitted to change `Spec-Review-Status: Pending` to
`Spec-Review-Status: Passed`.

## Invocation

```text
spec-review-loop <feature-slug> [--edit-summary="..."] [--reset]
```

Invoked internally by `sdd-bootstrap-interviewer` after Phase 1; not a
user-facing command (`user-invocable: false`, `disable-model-invocation: false`
-- a human cannot start it out of order, and the model must be able to reach it).
Reached by entering at `/sdd-bootstrap:bootstrap` and following this file. The
argument shape above is what the orchestrator supplies, not a slash command.

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

## Sequential launch boundary

Before each reviewer launch, persist one
`review-context-invocation/v2` manifest for that reviewer only. Bind its stage,
role, feature, fresh orchestrator-issued per-reviewer run ID and actual
host-issued session/thread ID, canonical input paths and SHA-256
values, plus the current hash and final record hash of
`reports/review-context/identity-ledger.json`. The canonical identity ledger
must already contain the invoking host/implementation identity and every prior
review/evaluation reservation; if it is missing, stale, malformed, or has a
broken hash chain, stop. Never reconstruct history from caller-supplied ID
lists.

Immediately before launching the named reviewer, reserve its identity with one
of:

```text
plugins/sdd-quality-loop/scripts/validate-review-context-set.sh <invocation-manifest> <repository-root> --reserve
plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1 -Manifest <invocation-manifest> -RepositoryRoot <repository-root> -Reserve
```

Require `REVIEW_CONTEXT_OK`, then launch exactly the role/run/session named in
that reserved manifest. A non-zero result blocks launch. Because reservation is
sequential, reviewer A never depends on a future reviewer B, implementation
review, task review, or evaluator context.

## Independent reviewer sequence

1. Build a stage `spec` allowed-input manifest from the precheck result. Include
   only canonical requirements, acceptance tests, optional investigation,
   `plugins/sdd-review-loop/references/spec-review-calibration.md`, and
   precheck-result paths with hashes.
2. Allocate a fresh host-issued session/thread identity for `spec-reviewer-a`
   in an empty, idle context without starting a model turn or supplying review
   inputs or inherited conversation. Persist the host allocation receipt and
   verify the actual child role, model, read-only configuration and absence of
   user/assistant turns and review inputs. Separately allocate a fresh
   orchestrator-issued run ID for this reviewer invocation and persist its
   correspondence with that host receipt; this is not a host-issued run ID or
   the integrated orchestration run ID. This allocation is not a reviewer
   launch and must not produce findings or consume inputs.
   Build and reserve its invocation manifest through the sequential launch
   boundary. Only after successful reservation and `REVIEW_CONTEXT_OK`, start
   the first reviewer turn in exactly that reserved context. If the host cannot
   separate identity allocation from execution, stop; do not fabricate IDs,
   start a provisional review, or reserve an already executed review afterwards.
   Persist its returned raw JSON as `reviewer-a.json`; reviewers themselves have
   no write capability.
3. Create `integrated-summary.json` containing only check IDs, severities, and
   counts. It must not reproduce any raw finding text.
4. Apply the same identity-allocation, reservation, then first-turn sequence
   to `spec-reviewer-b` in a separate fresh host context. Its allowed-input
   manifest contains only the canonical artifacts, calibration reference,
   precheck result, and that sanitized summary. It must never receive
   `reviewer-a.json`. Build and reserve a new invocation manifest against the
   ledger state produced by reviewer A immediately before launch.
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

## Calibration Boundaries

Reviewers must read `references/spec-review-calibration.md` before emitting
findings. The calibration keeps this gate focused on Phase 1 readiness:
requirements must be testable, acceptance criteria observable, scope and
constraints explicit, and risks connected to a future validation surface. The
gate must not require design sections, task breakdowns, command execution,
documentation-update workflows, checkpoint/learning workflows, or live eval
execution.

## Identity-allocation failure handling

An allocation receipt is host evidence, not a caller-chosen UUID. It must bind
the actual host-issued session/thread identity and show that review execution
has not started. A separate orchestrator record binds the fresh per-reviewer
run ID to that receipt; it must not claim host issuance of the run ID. Both IDs
remain independently subject to ledger uniqueness and exact output matching.
Reservation failure must leave that context idle: no reviewer turn,
no findings, no retry by changing IDs in its receipt. A failed first turn after
reservation does not release the consumed identity; preserve the reservation
and receipt and use a new context for a later permitted attempt. Both reviewers
remain read-only and separately isolated. This ordering does not authorize a
blocked shell launcher, a same-session fallback, or any guard bypass. Fixture
tests do not establish that a particular live host implements this lifecycle.

## Required spec reviewer digest capability

Before idle allocation, fix the invocation path under reports/review-context and
its `.json.receipt.txt` sidecar path. Pin the installed calculator/entrypoint bytes.
Provision only the exact calculation command described in the role, with dontAsk,
Read/Grep/Glob and restricted Bash capability. No wildcard/prefix shell allowance,
script writing, permission bypass or inferred inherited broad Bash access is allowed.
Confirm the effective host policy rejects changed argv, other paths, --reserve,
redirection, substitution and chained commands before formal dispatch. Unit/mocked
checks are not host proof. Do not execute a refused operation via another executor.

Run normal caller preflight/reservation unchanged. Save its successful stdout once
at the fixed receipt sidecar (never overwrite old evidence), quote that same line
to the reviewer, and preserve actual identity correspondence. The reviewer compares
the saved receipt/manifest/real identity and invokes only the restricted calculator.
Its result is not a replacement for any prior or subsequent required check.
If the installed tools or host policy cannot support this boundary, stop before
review input delivery; do not reserve a provisional or already-executed review.
