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
spec-review-loop <feature-slug> [--edit-summary="..."] [--reset] [--recover-interrupted | --fresh-review-contract=<path>]
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

For a specifically authorized first-round launch interruption following a
validated reset, `--reset --recover-interrupted` may open only the next attempt's
round 1. It requires the interrupted prior round's original precheck, host
allocation, blocker note, reviewer-A invocation and valid persisted reservation,
with no reviewer or integrated output or reviewer-B invocation. It revalidates
the attempt *before* the interruption as terminal PASS/BLOCKED and preserves
all interrupted evidence. It does not grant a terminal verdict to the
interrupted attempt, release its reviewer identity, or permit a replay. An
attempt-1 interruption without an earlier terminal attempt is outside this
limited recovery path. New reviewers require fresh identities and the ordinary manifest reservation
sequence below. The host-issued idle allocation route remains the default; the
separately gated non-TTY caller-proposed UUID route is defined below.

## Separately authorized invalidated first-turn recovery

After a BLOCKED first turn has ended, a later turn in that same reserved context
cannot supply admissible review evidence. Preserve its output and reservation.
Do not start B from it, release its identity, or loosen `--recover-interrupted`.

For an explicitly authorized history with a terminal attempt followed by
incomplete reviewer-A attempts, the orchestrator may use
`--reset --fresh-review-contract=<path>` (PowerShell:
`-Reset -FreshReviewContract <path>`) to open only the next attempt, round 1.
The `spec-fresh-review-recovery/v2` contract quarantines all historical outputs
as diagnostic-only and records intervening transition legality as not-established.
It does not retroactively legalize an interruption or adopt a resumed PASS.
The original v2 key set remains limited to the terminal → no-output →
reviewer-A-output shape. A longer contiguous history must add both
`terminal_attempt` and `partial_attempts`: the latter lists every attempt
from the anchor plus one through the immediately preceding attempt, in order,
with no omissions. Each partial attempt must have exactly its precheck,
reviewer-A host allocation, and either a launch-blocker note or reviewer-A
output; no B or integrated verdict is admitted. Pin current Pending input
hashes, the complete required historical inventory, every original
reviewer-A invocation manifest, the diagnostic transcript, and a scoped
approval audit record transcribed by the orchestrator from the actual user
conversation. Label that record as an orchestrator transcription: it is not a
human-authored signature, registered approver sidecar, or sudo-mode grant.
An opt-in `failed_final_round` of 2 or 3 permits the immediately preceding
attempt to retain earlier complete NEEDS_WORK rounds followed by one failed
reviewer-A first turn. For an earlier attempt in the contiguous partial chain,
an opt-in `historical_failed_rounds` list names each such attempt exactly once
in increasing order, with its `failed_final_round` and `failed_turn` binding;
all unlisted partial attempts must retain the original round-1-only shape.
The top-level transcript must name the last historical failed multi-round
turn when the immediately preceding attempt is round-1-only. Pin every
complete-round file, both reviewer invocation manifests and reservations,
the failed-round precheck/host allocation/A
invocation/blocker, and the retained local host transcript showing `end_turn`.
Both runtime prechecks validate the complete-round contracts with their existing
contract validators. This is record integrity, not retrospective review approval.

For `failed_turn.failure_mode: native-nontty-malformed-result` only, the
failed final round may lack its original allocation/proposal record; preserve
that absence and never manufacture or backfill host evidence. This diagnostic
branch requires the exact failed-round regular-file inventory, original A
invocation and reservation, byte-exact expected prompt/receipt/native transcript
matching, a completed `end_turn` with no later user record, and a CLI wrapper
whose string result is malformed raw JSON. The scoped approval audit must bind
`failed_turn_sha256`: SHA-256 of `failed_turn` serialized as UTF-8 JSON with
sorted keys, compact separators and unescaped Unicode. Existing manifest,
canonical-ledger-chain, current-input, historical-input and complete-round
contract checks remain mandatory. Historical output stays diagnostic-only,
transition legality stays not-established, and no result is adopted as a review.
Ordinary launches and completed rounds still require their original allocation
or non-TTY proposal/preflight evidence; this exception admits only preservation
of the failed turn for a separately authorized fresh attempt, never a replay.

An additional opt-in `interrupted_transport_inventories` list may preserve
round-1 transport diagnostics alongside `terminal_attempt`, `partial_attempts`
and `historical_failed_rounds`. It is mutually exclusive with the legacy
`interrupted_evidence_inventory` extension; old v2 inputs retain their meaning.
Each entry names one non-completed partial attempt and its exact regular-file
path/sha256 inventory, in increasing attempt order without duplicates. The
required filenames are `precheck-result.json`, `launch-blocker-note.md`,
`reviewer-a-host-allocation.json`, `reviewer-a-first-turn.txt`,
`reviewer-a-nontty-preflight.json`, `reviewer-a-reservation-receipt.txt`, and
`reviewer-a-role-config.json`. Only `reviewer-a-cli-stderr.txt`,
`reviewer-a-cli-wrapper.json`, `reviewer-a-delivery-proof.json`, and
`reviewer-a-reservation-stderr.txt` are optional. Unknown additions, omissions,
duplicate paths, non-regular files, path escapes and mismatched bytes are rejected.
All entries must also be pinned in the complete evidence set. Unlisted attempts
retain their existing strict shape; diagnostic output never becomes a verdict.
The scoped approval audit additionally binds `transport_inventories_sha256`:
SHA-256 of this list serialized as UTF-8 JSON with sorted keys, compact separators,
and unescaped Unicode. This pins the orchestrator's approval transcription, not
a signature or independent authentication. Existing next-attempt, current-input,
historical-invocation and canonical-ledger-chain checks remain mandatory.
Retain the immutable contract and approval record under `reports/verification/`.
The new precheck records both `fresh_review_contract_path` and
`fresh_review_contract_sha256`. This opt-in route alone requires Python 3.
The recovery helper validates every historical reservation against its pinned
precheck, manifest and identity-ledger chain, not against amended current files.
The precheck validates the historical terminal contract and current input hashes,
then repeats all admission checks under the transition lock. These checks establish
preserved-record integrity, not legality of the intervening transitions. Ordinary
new-review launch validation remains unchanged. Recovery does not reserve an
identity or produce a verdict.

Before allocating new reviewers, use a separate diagnostic context to confirm
read-only command permissions and host hook requirements. A hook-authorized
retry within the same first turn is permitted; after BLOCKED `end_turn`, use
only a new independent context in the later admitted attempt. Never pass
invalidated raw output or host transcript to fresh reviewers. Use only the
ordinary manifest inputs and reservation/first-turn sequence below.

## Sequential launch boundary

Before each reviewer launch, persist one
`review-context-invocation/v2` manifest for that reviewer only. Bind its stage,
role, feature, fresh run/session IDs from the selected launch mode, canonical input paths and SHA-256
values, plus the current hash and final record hash of
`reports/review-context/identity-ledger.json`. The canonical identity ledger
must already contain the invoking host/implementation identity and every prior
review/evaluation reservation; if it is missing, stale, malformed, or has a
broken hash chain, stop. Never reconstruct history from caller-supplied ID
lists.

In the ordinary host-issued route, immediately before launching the named
reviewer, first pin the invocation's raw SHA-256 outside the manifest and run
`python3 -B plugins/sdd-review-loop/scripts/preflight-host-review.py
<repository-root> <invocation-manifest> --manifest-sha256 <caller-pin>`.
Pass `--runtime powershell` when reserving through the PowerShell validator;
otherwise use the Bash default for both precheck and preview.
For a CLI host append `--host-cli <actual-executable>` and one
`--help-subcommand=<name>` for each launch subcommand (for example `exec`),
then `--required-flag=<flag>` for every flag the actual launch uses; a non-CLI app
has no CLI-help claim. Require `HOST_REVIEW_PREFLIGHT_OK`, whose output
explicitly does **not** prove effective host permissions or reserve an identity.
Keep the existing separate permission diagnostic and host receipt requirements;
do not represent either as this preflight's result. Recheck the caller pin and
run this same non-reserving preflight again immediately before each reservation,
including reviewer B, then reserve its identity with one of:

```text
plugins/sdd-quality-loop/scripts/validate-review-context-set.sh <invocation-manifest> <repository-root> --reserve
plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1 -Manifest <invocation-manifest> -RepositoryRoot <repository-root> -Reserve
```

Require `REVIEW_CONTEXT_OK`, then launch exactly the role/run/session named in
that reserved manifest. In the non-TTY route, the shared launcher below alone
performs this reservation; do not reserve it separately or retry the launcher
against the same invocation. A non-zero result blocks launch. Because
reservation is sequential, reviewer A never depends on a future reviewer B, implementation
review, task review, or evaluator context.

## Independent reviewer sequence

1. Build a stage `spec` allowed-input manifest from the precheck result. Include
   only canonical requirements, acceptance tests, optional investigation,
   `plugins/sdd-review-loop/references/spec-review-calibration.md`, and
   precheck-result paths with hashes.
2. Select exactly one launch mode before building the invocation.
   In the ordinary host-issued route, obtain fresh host-issued run/session
   identities for `spec-reviewer-a`. If the host issues them only when
   allocating a context, allocate an empty, idle context without starting a
   model turn or supplying review inputs or inherited conversation. Persist
   the host's identity receipt. Build and reserve its invocation manifest,
   then start the first reviewer turn in exactly that reserved context.
   Alternatively, the local Claude CLI non-TTY route below may propose one
   canonical UUIDv4 and use that **same** value for both `run_id` and
   `host_session_id`. It is a single proposed session identity represented in
   two required contract fields, not two host-issued IDs. Never fabricate an
   additional run ID or claim host allocation occurred before execution.
   Build the one-role invocation once, then use the shared non-TTY launcher
   below. It owns proposal/preflight, the single reservation, exact prompt,
   native first turn, and postflight. Do not pre-reserve or start a separate
   `claude` turn. Retain its wrapper and native transcript locally and require
   successful delivery proof before adopting any output.
   In either mode, a failure after reservation consumes it; no same-session retry,
   modified-ID replay, fallback, or reviewer B launch from an invalid A output.
   Persist only the validated returned raw JSON as `reviewer-a.json`; reviewers
   themselves have no write capability.
3. Create `integrated-summary.json` containing only check IDs, severities, and
   counts. It must not reproduce any raw finding text.
4. Apply the same identity-allocation, reservation, then first-turn sequence
   to `spec-reviewer-b` in a separate fresh context/session. Its allowed-input
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
| Pending, specifically authorized interrupted reset round 1 with no reviewer output | `--reset --recover-interrupted`, next attempt round 1 | preserve the consumed identity and old evidence; rehash current inputs for a fresh attempt |
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

## Local Claude CLI non-TTY launch proof (opt-in)

This mode is confined to the local Claude CLI's documented `--session-id` and
`--print` options. Keep the ordinary hooks, deny rules, read-only tool set and
role source. The proposed UUID must be a new canonical UUIDv4 absent from the
canonical identity ledger and from the native session transcript location;
do not resume, fork, or attach a prior conversation. The caller-proposal record
must contain `kind: claude-nontty-caller-proposal`, `host_id` and
`host_session_id` both equal to that UUID, the role/feature/attempt/round,
`review_turn_started: false`, and the preflight verifier result/hash. This
record attests only the caller's checks, **not** prior host acceptance.

Before constructing each invocation, run
`python3 -B plugins/sdd-quality-loop/scripts/review-conditional-inputs.py --root <absolute-repository-root> --feature <feature> --stage spec`.
Add its `inputs` path/hash pairs to the ordinary required inputs without
duplicates. Failure stops before reservation; never omit a conditional input
to force admission. The launcher rechecks these inputs and the conditions
used to select them before reservation.

For each reviewer, after persisting its one-role invocation and before any
manual reservation, invoke only:

```text
rtk proxy python3 -B plugins/sdd-review-loop/scripts/launch-impl-review.py <absolute-repository-root> <absolute-invocation-path> <absolute-round-directory>/launch-<UUID>
```

`<UUID>` is the invocation's proposed `run_id` and `host_session_id`; the
output directory must not already exist. The shared launcher performs current
input verification, CLI/role and hook-policy checks, unreserved native
permission proof, dependency pin/readback and recheck, the ordinary validator's
single `--reserve`, strict helper-generated control prompt, one non-TTY first
turn, and postflight. Require its exact `REVIEW_CONTEXT_OK` receipt and delivery
proof. Keep the proposal/preflight record at the usual round-scoped
`reviewer-<a|b>-host-allocation.json` path, labelled as a caller proposal rather
than a host-issued receipt; `launch-<UUID>/caller-proposal.json` is the
launcher's source record. If either record is absent, stop before adoption.
Receipt authentication and ledger-chain checks remain the ordinary validator's
responsibility; template equality alone is not reservation proof. Postflight
must compare the CLI-returned `session_id` to the reserved UUID,
the native transcript's sole human user text byte-for-byte to the prompt
file and independently reconstructed complete template (invocation path/hash,
role and exact receipt), using `--receipt` for postflight, allowing only subsequent native tool-result
user records, and the reviewer JSON's stage/role/
run/session fields to the invocation. Then run the existing complete output,
manifest and hash validators. Any CLI refusal, API error, existing-session
collision, missing/truncated input, identity mismatch, extra user turn or
schema failure is **launch failure**, never a specification FAIL/PASS. Keep
diagnostic bytes local, preserve the consumed reservation, and use a later
separately admitted attempt. A model-echoed ID alone is not host acceptance.

This mode does not assert that the proposed ID was host-issued. Live host
success and an existing-session rejection must be observed in an unreserved
diagnostic context before using it for a formal review; synthetic fixtures
alone are insufficient.

## Identity-allocation failure handling

In the ordinary host-issued route, an allocation receipt is host evidence,
not a caller-chosen UUID. It must bind the host's actual run and session
identities and show that review execution has not started. The opt-in non-TTY
proposal record is deliberately not called a host receipt; acceptance is
established only by the post-launch CLI wrapper and native transcript checks.
Reservation failure forbids any launch: the ordinary context remains idle, and
the non-TTY proposal remains unused. No findings or retry by changing IDs are
permitted. A failed first turn after
reservation does not release the consumed identity; preserve the reservation
and receipt and use a new context for a later permitted attempt. Both reviewers
remain read-only and separately isolated. This ordering does not authorize a
blocked shell launcher, a same-session fallback, or any guard bypass. Fixture
tests do not establish that a particular live host implements this lifecycle.
