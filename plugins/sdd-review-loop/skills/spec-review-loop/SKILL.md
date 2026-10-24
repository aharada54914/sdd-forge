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

## Managed allocation boundary

Affected policy roles: `spec-reviewer-a`, `spec-reviewer-b`.

Apply in the allocating parent before an unbound forked Skill/Agent, native role,
or fresh context receives work, and before any identity reservation. This
boundary takes precedence over later native/default launch guidance for these
roles. It does not add an availability or authority gate.

Keep an already admitted managed entry with its validated selection/controls and
matching role, host, run/session and workload. Keep a concretely known matching
batch startup and fixed generated Codex configuration under their original
contracts. An already bound worker continues its original procedure: do not
select again, allocate again, or run this refusal inside that same worker.
A bound parent does not bind a new child, role or session: each new allocation
needs its own admitted selection/carrier binding or takes the refusal below.

When this operation has no admitted binding of the selected model and effort to
its actual native carrier, substitute the next affected policy role and actual
host (`claude-code`, `codex-cli`, `copilot-cli`, or `gemini-cli`) and execute:

```bash
python3 -I -B "<installed-root>"/plugins/sdd-implementation/scripts/managed-model-entry.py unsupported-entry \
  --role "<policy-role>" --host "<host>"
```

Exit 2 with `model-policy-error/v1` / `model-unavailable` stops that allocation
before work or reservation. Do not fall through to an old model hint, alias,
unbound native default or another parent session; do not count allocation alone
as selection proof. This refusal does not assert host incapability and never
authorizes same-session reload. Original host-incapable-only implementation
fallback evidence and all review isolation requirements remain unchanged.

Apply separately to reviewer A or B before identity allocation and reservation. Keep the admitted managed Claude sequential launch and sanitized B input. Entered bound reviewers retain their readonly procedure without another selection.

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
role, feature, host-issued run/session IDs, canonical input paths and SHA-256
values, plus the current hash and final record hash of
`reports/review-context/identity-ledger.json`. The canonical identity ledger
must already contain the invoking host identity and every prior
review/evaluation reservation; if it is missing, stale, malformed, or has a
broken hash chain, stop. Never reconstruct history from caller-supplied ID
lists. Implementation actors are bound by their `task-input-manifest/v1` and
implementation report, not by host rows, and earlier specification authors are
not retroactively added to the ledger.

If the orchestrating host is a Claude Code session that is not yet in an existing
ledger, register it once, while that native session is stopped, with
`initialize-review-identity.py --register-existing --claude-result <captured result>
--claude-transcript <native transcript>` (first with `--check-only`), then resume the
same session ID. A fresh Copilot project instead uses `--copilot-events`. Accepted
evidence, supported scope, receipts and retry rules are in
`references/review-context-boundary.md` ("Registering a Claude host into an
existing ledger"). The registered host never acts as reviewer A or B.

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

### Local Claude CLI non-TTY route (opt-in)

For this route only, propose a fresh canonical UUIDv4 as both run and
host-session ID, absent from the ledger and native session location. Before
constructing the invocation, run
`python3 -B plugins/sdd-quality-loop/scripts/review-conditional-inputs.py --root <absolute-repository-root> --feature <feature> --stage spec`
and include every returned path/hash pair without duplicates. Persist the
complete one-role invocation, then call exactly once before any manual reserve:

```text
cd "<absolute-repository-root>" || exit $?
output="<output-dir>"
python3 -B plugins/sdd-implementation/scripts/managed-model-entry.py prepare \
  --role <role> --host claude-code --request "<policy-request>" --registry "<registry>" \
  --run-id <run-id> --session-id <session-id> --attempt <attempt> \
  --output-dir "$output" --require-actual-id false || exit $?
controls_sha=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["controls"]["sha256"])' "$output/validation.json") || exit $?
rtk proxy python3 -B plugins/sdd-review-loop/scripts/launch-impl-review.py \
  "<absolute-repository-root>" "<absolute-invocation-path>" "<absolute-round-directory>/launch-<UUID>" \
  --model-controls "$output/controls.json" --model-controls-sha256 "$controls_sha"
```

Use the invocation's exact role, run/session IDs and attempt in the preparation
arguments; both IDs must equal the proposed UUID. Supply the policy request and
registry paths relative to the repository root and a fresh output directory.
Stop on preparation failure. Forward the controls hash from its successful
validation; do not replace it with a fresh unchecked file hash.

The UUID is the proposed run/session ID and the launch directory must be new.
The launcher verifies inputs and native permissions before its single ledger
reservation, then pins dependencies, launches and checks delivery. Require its
exact `REVIEW_CONTEXT_OK` receipt and postflight proof; do not reserve
separately, retry with altered IDs, or treat delivery as a review verdict.
Its read-only `preflight-host-review.py` step must emit
`HOST_REVIEW_PREFLIGHT_OK` before reservation.
Other host routes retain the sequential launch boundary above.

1. Build a stage `spec` allowed-input manifest from the precheck result. Include
   only canonical requirements, acceptance tests, optional investigation,
   `plugins/sdd-review-loop/references/spec-review-calibration.md`, and
   precheck-result paths with hashes.
2. Obtain fresh host-issued run/session identities for `spec-reviewer-a`.
   If the host issues them only when allocating a context, allocate an empty,
   idle context without starting a model turn or supplying review inputs or
   inherited conversation. Persist the host's identity receipt. This allocation
   is not a reviewer launch and must not produce findings or consume inputs.
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
the host's actual run and session identities and show that review execution has
not started. Reservation failure must leave that context idle: no reviewer turn,
no findings, no retry by changing IDs in its receipt. A failed first turn after
reservation does not release the consumed identity; preserve the reservation
and receipt and use a new context for a later permitted attempt. Both reviewers
remain read-only and separately isolated. This ordering does not authorize a
blocked shell launcher, a same-session fallback, or any guard bypass. Fixture
tests do not establish that a particular live host implements this lifecycle.

## Upstream concept issues

When DOMAIN-CONFORMANCE identifies `UPSTREAM_CONCEPT_ISSUE`, retain its concept
ID and exact record/spec evidence. Before invoking `domain-model update`, run
`python3 plugins/sdd-domain/scripts/record-upstream-concept-issue.py --root <project-root> --stage spec
--feature <feature> --attempt <current-attempt> --concept <CONCEPT-ID> --evidence "<record/spec evidence>"`
as one command. Pass evidence as a literal argument through the host argument-array
API or proper shell quoting; never evaluate artifact text as shell code. The first occurrence permits one update handoff, subject to the
existing approval requirements; a repeated occurrence returns
`requires_human_decision` and stops automatic reopening. Nonzero results also
stop the handoff. Keep the attempt's record across rounds and sessions, then
regenerate the feature Concept Test and rebind review inputs after an upstream
change. Never reset a review attempt solely to evade the limit.
