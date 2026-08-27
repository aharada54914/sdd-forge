---
name: impl-review-loop
description: Orchestrator for the SDD implementation policy review loop. Runs up to three rounds of dual-reviewer checks on design.md. Coordinates impl-reviewer-a (structural soundness) and impl-reviewer-b (implementability/risk), merges verdicts, and manages round/attempt state. Human edits are required between rounds when findings exist.
disable-model-invocation: false
user-invocable: false
---

# Implementation Policy Review Loop

Run the structural soundness and implementability review gate on a feature's
design.md. This skill coordinates two independent reviewers, merges their
findings, and manages the round/attempt state machine.

## Invocation

Codex:
```
Use the impl-review-loop skill for feature <slug>
```

Claude Code:
```
/sdd-review-loop:impl-review-loop --feature <slug> [--reset] [--edit-summary "<text>"]
```

Flags:
- `--feature <slug>`: required; identifies `specs/<slug>/design.md`.
- `--reset`: archive the current attempt and start a new attempt from round 1.
- `--edit-summary "<text>"`: required when re-invoking after human edits (rounds
  2 and 3). Summarises what the human changed. Stored in impl-review-contract.json.

## Preconditions

Before running:
1. `specs/<feature>/design.md` must exist.
2. design.md must have an `Impl-Review-Status: Pending` header field. If the
   field is missing and acceptance-tests.md is also absent, emit a STOP warning
   (see LITE-SKIP below). If the field is missing but acceptance-tests.md
   exists, halt with: "design.md is missing Impl-Review-Status: Pending header
   field. Add the field before invoking impl-review-loop."
3. The spec-review-loop for this feature must have passed (check for
   `Spec-Review-Status: Passed` in requirements.md header or equivalent gate
   record). Do not run impl-review-loop if spec-review-loop has not passed.
4. For a feature registered with profile `full`, `ux-spec.md`,
   `frontend-spec.md`, `infra-spec.md`, and `security-spec.md` must exist as
   real files in the feature spec directory. The precheck hash-binds all four.
   Lite and legacy profiles retain their existing input contract.

## LITE-SKIP

If design.md has no `Impl-Review-Status:` field AND
`specs/<feature>/acceptance-tests.md` is absent:
- Print: "impl-review-loop: STOP — design.md has no Impl-Review-Status field
  and acceptance-tests.md is absent for feature <slug>. This appears to be a
  lite-profile feature. Add Impl-Review-Status: Pending to design.md to enable
  review, or use a lite spec profile."
- Write no files; halt without returning PASS (this is a warning, not a pass).

## Standalone Invocation Warning

If AGENTS.md (or the feature's spec directory) declares `spec_profile: lite`,
emit a warning before running:
"WARNING: impl-review-loop invoked on a lite-profile feature. Lite profiles are
intended to skip impl-review. Continuing at human request."
Then proceed normally.

## Process (State Machine)

Determine the current attempt and round by inspecting the
`reports/impl-review/<feature>/` directory. If no prior run exists, start at
attempt-1/round-1.

### STEP 1 — Precheck

Run `plugins/sdd-review-loop/scripts/impl-review-precheck.sh <feature> <attempt> <round>`.

This script produces:
- `reports/impl-review/<feature>/attempt-<M>/round-<N>/precheck-result.json`

If the script exits non-zero, halt and display its stderr output. Do not proceed
to reviewer invocation.

### STEP 2 — Invoke impl-reviewer-a

Spawn impl-reviewer-a as a fresh agent (no shared context) with:
- Feature slug, attempt number, round number.
- Path to precheck-result.json.
- Hash-verified allowed-input manifest including
  `plugins/sdd-review-loop/references/reviewer-calibration.md`.
- `specs/<feature>/investigation.md` whenever that file exists. Reviewer A
  reads it as supporting evidence and carries its INV-xxx IDs forward; it is
  never authority over requirements.md. `task-review-precheck.sh` fails the
  task stage unless the persisted contract binds it in BOTH reviewer
  manifests, so omitting it produces evidence the next gate rejects.
- At round 2 and round 3 only: the PREVIOUS round's
  `reports/impl-review/<feature>/attempt-<M>/round-<N-1>/integrated-summary.json`.
  This is the Issue #143 exception stated in `impl-reviewer-a.md` — the file
  carries reviewer A's own check IDs and counts and no reviewer-b narrative,
  so binding it does not breach the A/B isolation this loop is built on.
  Reviewer A reads it as counts and check IDs only and must not reason from
  reviewer-b's findings. Both gates require it: `impl-review-precheck.sh`
  fails the round without it, and `task-review-precheck.sh` fails the task
  stage unless it appears in reviewer A's manifest specifically. Binding it
  to reviewer B instead is not a substitute — the contract allowlist admits
  the previous round's summary for reviewer A alone.

The agent reads inputs itself and writes:
`reports/impl-review/<feature>/attempt-<M>/round-<N>/reviewer-a.json`

impl-reviewer-a is read-only. It must not modify any spec file.
Immediately before invoking it, run the same precheck command with
`--verify-inputs`. Halt if any core or layer input differs from the persisted
precheck manifest.
Then persist a one-role `review-context-invocation/v2` manifest and bind it to
the current hash/final record of the canonical
`reports/review-context/identity-ledger.json`. Run
`plugins/sdd-quality-loop/scripts/validate-review-context-set.sh
<invocation-manifest> <repository-root> --reserve` or the PowerShell equivalent
with `-Reserve`. Require `REVIEW_CONTEXT_OK` before launch. Missing/stale ledger
state, identity reuse, or any other non-zero result blocks launch; never replace
persisted history with caller-supplied reserved-ID arrays.

### STEP 3 — Generate integrated-summary.json

Deterministically produce `integrated-summary.json` from reviewer-a.json.
This file contains check IDs and counts only — no verdict synthesis, no
qualitative assessment. It is used by impl-reviewer-b to understand the
structural soundness landscape without being influenced by reviewer-a's verdict.

Schema:
```json
{
  "schema": "integrated-summary/v1",
  "round": 1,
  "attempt": 1,
  "reviewer_a_check_ids": ["ARCH-COVERAGE", "NO-CIRCULAR-DEPS", ...],
  "reviewer_a_fail_count": 0,
  "reviewer_a_pass_count": 9,
  "reviewer_a_skip_count": 0,
  "generated_at": "<ISO8601>"
}
```

Write to: `reports/impl-review/<feature>/attempt-<M>/round-<N>/integrated-summary.json`

### STEP 4 — Invoke impl-reviewer-b

Spawn impl-reviewer-b as a fresh agent (no shared context) with:
- Feature slug, attempt number, round number.
- Path to precheck-result.json.
- Path to integrated-summary.json.
- Hash-verified allowed-input manifest including
  `plugins/sdd-review-loop/references/reviewer-calibration.md`.
- `specs/<feature>/investigation.md` whenever that file exists. Reviewer B
  reads it to check INV-xxx grounding. The task stage's precheck requires it
  in reviewer B's manifest too; a contract that binds it for only one reviewer
  is rejected.

impl-reviewer-b has `disallowedPaths` covering reviewer-a.json. The agent reads
its own inputs and writes:
`reports/impl-review/<feature>/attempt-<M>/round-<N>/reviewer-b.json`

impl-reviewer-b is read-only. It must not modify any spec file.
Immediately before invoking it, rerun the precheck with `--verify-inputs`.
This verification mode is read-only and must not replace review evidence.
Create a new one-role `review-context-invocation/v2` manifest using the ledger
state after reviewer A, then invoke `validate-review-context-set` with
`--reserve` (Bash) or `-Reserve` (PowerShell). Require `REVIEW_CONTEXT_OK`
before launching reviewer B. Reviewer B does not require any future task or
evaluator context.

### STEP 5 — Merge Verdicts

Read reviewer-a.json and reviewer-b.json. Compute:
- `findings_critical`: count of FAIL checks with severity Critical (across both).
- `findings_major`: count of FAIL checks with severity Major (across both).
- `findings_minor`: count of FAIL checks with severity Minor (across both).

Merged verdict:
- BLOCKED if `findings_critical > 0`.
- NEEDS_WORK if `findings_major > 0` and `findings_critical == 0`.
- PASS-with-warnings if `findings_minor > 0` and round == 3 and
  `findings_major == 0` and `findings_critical == 0`.
- PASS if `findings_critical == 0` and `findings_major == 0` and
  `findings_minor == 0`.

Write `reports/impl-review/<feature>/attempt-<M>/round-<N>/integrated-verdict.json`:
```json
{
  "schema": "integrated-verdict/v1",
  "stage": "impl",
  "feature": "<feature-slug>",
  "run_id": "<fresh-orchestrator-run-id>",
  "verdict": "PASS|PASS-with-warnings|NEEDS_WORK|BLOCKED",
  "round": 1,
  "attempt": 1,
  "findings_critical": 0,
  "findings_major": 0,
  "findings_minor": 0,
  "reviewer_a_verdict": "PASS",
  "reviewer_b_verdict": "PASS"
}
```

Write `reports/impl-review/<feature>/attempt-<M>/round-<N>/impl-review-contract.json`
using the schema from `plugins/sdd-review-loop/templates/impl-review-contract.template.json`.
Its two reviewer entries must have distinct nonblank `run_id` and
`host_session_id` values and canonical, hash-verified allowed-input manifests.
Each reviewer manifest must include every input the reviewer is instructed to
read, including `plugins/sdd-review-loop/references/reviewer-calibration.md`.
Whenever `specs/<feature>/investigation.md` exists, both manifests must include
it as well.
For full-profile features, both manifests must also include `ux-spec.md`,
`frontend-spec.md`, `infra-spec.md`, and `security-spec.md`, using the hashes
recorded in `precheck-result.json`; copy that map to the contract's
`layer_sha256` field.

Round-dependent manifest contract:
- Reviewer B's manifest binds the CURRENT round's `integrated-summary.json`,
  in every round.
- In rounds 2 and 3, reviewer A's manifest additionally binds the PREVIOUS
  round's `attempt-<M>/round-<N-1>/integrated-summary.json`. In round 1 it must
  not — there is none.
- That previous-round summary belongs to reviewer A alone. Binding it to
  reviewer B instead is rejected: the contract allowlist admits round N-1's
  summary for reviewer A only.
- A round > 1 contract that omits it is rejected by `task-review-precheck.sh`
  with "persisted impl reviewer-a manifest is missing previous-round summary",
  which strands the feature before task review even though this stage reported
  PASS. `tests/impl-review-round2-contract.tests.sh` holds this shape.

Persist both artifacts in the same round directory; downstream prechecks reject
missing, stale, or incomplete predecessor contracts before creating evidence.

### STEP 6 — State Machine Outcome

#### Both reviewers PASS, 0 findings → PASS (clean)

- Update `specs/<feature>/design.md` header: change
  `Impl-Review-Status: Pending` to `Impl-Review-Status: Passed`.
- Print: "impl-review-loop PASSED (clean) — round <N> of attempt <M>."
- Print: "Phase 2 (task decomposition) is now unblocked for feature <slug>."
- Halt.

#### Round == 3, only Minor findings remain → PASS-with-warnings

- Update `specs/<feature>/design.md` header:
  `Impl-Review-Status: Passed`.
- Append a `## Implementation Warnings` section to design.md listing every Minor
  finding with its check ID and description.
- Print: "impl-review-loop PASSED with warnings — <K> minor findings recorded."
- Print: "Phase 2 (task decomposition) is now unblocked for feature <slug>."
- Halt.

#### Round < 3, Major or Critical findings → NEEDS_WORK

- Generate `reports/impl-review/<feature>/attempt-<M>/round-<N>/design-round-<N>-proposed-changes.md`
  using `plugins/sdd-review-loop/templates/impl-review-report.template.md`.
- Present the proposed changes file to the human.
- Print: "impl-review-loop NEEDS_WORK — round <N> of 3. Review proposed changes
  and edit specs/<feature>/design.md. Then re-invoke with --edit-summary."
- Halt and await human action.

#### Round == 3, Critical or Major findings remain → BLOCKED

- Print: "impl-review-loop BLOCKED after 3 rounds in attempt <M>. Critical or
  Major findings remain unresolved. Use --reset to start a new attempt after
  addressing the root causes."
- Halt.

### STEP 7 — --reset handling

When `--reset` is provided:
1. Determine the current highest attempt number M from
   `reports/impl-review/<feature>/`.
2. The existing attempt-M directory remains as-is (archive by convention).
3. Create `reports/impl-review/<feature>/attempt-<M+1>/round-1/`.
4. Change `Impl-Review-Status:` in design.md header to `Pending` — but ONLY
   while `specs/<feature>/tasks.md` does not yet exist. Once it does,
   `check-workflow-state.sh` rejects a Pending impl status: its task-lifecycle
   rule requires every stage to read `Passed` once any task is Approved or past
   Planned, so `--reset` is unreachable for that feature and halts at
   `task-lifecycle`. Use the provenance re-review path below instead and leave
   the header at `Passed`.
5. Proceed from STEP 1 with attempt = M+1, round = 1.

## Re-Invocation After Human Edits

When the human edits design.md and re-invokes without `--reset`:
- Increment round counter (round 2 or round 3).
- `--edit-summary` is required; reject without it:
  "impl-review-loop: --edit-summary is required when re-invoking in round 2 or 3.
  Provide a brief description of the changes made to design.md."
- Proceed from STEP 1 with the incremented round.

## Phase 2 Unblock

When `Impl-Review-Status: Passed` is set in design.md, the task decomposition
phase (Phase 2) is unblocked. The sdd-bootstrap-interviewer will read this field
before generating tasks.md and halt if it is not Passed.

## Post-Implementation Provenance Re-Review

When impl-stage review evidence must be re-bound after Phase 2 has begun
(evidence-schema drift, an incomplete reviewer input manifest, a stale contract
hash), `--reset` is not the route: STEP 7 step 4 would write
`Impl-Review-Status: Pending`, which `check-workflow-state.sh` rejects once
`tasks.md` exists. Run a re-binding attempt instead. This re-binds existing PASS
evidence to the current artifact hashes; it is never a first-time review and
never a findings waiver.

1. Start a new attempt: attempt = M+1, round = 1. Do NOT clear
   `Impl-Review-Status:` from design.md — it stays `Passed`.
   `impl-review-precheck.sh` refuses `--provenance-rereview` unless design.md
   declares `Passed`, precisely so the header is not flipped.
2. Run the precheck with the re-review flag:
   `impl-review-precheck.sh <feature> <M+1> 1 --provenance-rereview`
   (PowerShell: `-ProvenanceRereview`). The flag requires at least one prior
   persisted impl-review PASS verdict for the feature, and downgrades the
   canonical workflow-state check from fatal to advisory — the stale evidence
   being re-bound is the reason the re-review runs. Every other precheck
   enforcement is unchanged.
3. Invoke both reviewers per STEP 2 and STEP 4 with the complete input set,
   including `investigation.md` when present and, for a full-profile feature,
   all four layer specs in each reviewer manifest. Declare the invocation a
   post-implementation provenance re-review.
4. Merge verdicts and write the contract per STEP 5.
5. After the contract is persisted, run
   `plugins/sdd-quality-loop/scripts/check-workflow-state.sh --feature <slug>`
   and require exit 0 before reporting completion.

TYPE-H convergence rule (provenance re-review only): a TYPE-H check that
would raise a NEW finding against content byte-identical — modulo
human-authorized status/approval/pointer lines — to content bound by a
prior attempt's persisted impl-review PASS evidence is recorded as PASS,
with the observation carried as an advisory inside the check's finding
text (citing the prior PASS evidence path), never as a FAIL finding of
any severity. TYPE-D checks are unaffected. Rationale: frozen content
cannot be edited to satisfy heuristic re-judgments, so fresh-instance
TYPE-H calibration variance would otherwise make the re-review
non-convergent (each round an independent draw, with round 3 terminal).
This is the same rule `task-review-loop`'s SKILL.md applies at the task
stage. It is stated here so the two stages do not differ silently: both
impl reviewer role files tag every check TYPE-H or TYPE-D, so the rule is
well-formed at this stage too. Note that flipping `Impl-Review-Status:`
between `Passed` and `Pending` changes design.md's SHA-256 without changing
its content — a status-line-only difference is exactly the case this rule
treats as byte-identical.

Controlled re-binding boundary: a provenance re-review re-binds review
evidence to the current artifact hashes; it does not license content changes
to frozen artifacts. Sanctioned post-review updates go to non-frozen addenda
per AGENTS.md (see ADR 0007).

## Boundaries

- Never self-approve any finding. Findings from reviewers are facts; the
  orchestrator counts them but does not waive or override them.
- Never write `Impl-Review-Status: Passed` directly — only the state machine
  outcome logic may set this field, and only after a genuine PASS verdict.
- Never write to `specs/<feature>/requirements.md` or `specs/<feature>/tasks.md`.
- Never invoke impl-reviewer-a and impl-reviewer-b in the same agent context.
  Each must run in a fresh, isolated context.
- Never pass reviewer-a output directly to reviewer-b. Use integrated-summary.json
  (counts and IDs only) as the only bridge.

## Sudo Mode

Sudo mode (SDD_SUDO) does not apply to this skill. The impl-review-loop always
requires genuine findings resolution by a human. The `--edit-summary` requirement
is not waived by sudo.

## Report Format

Display findings to the human using:
`plugins/sdd-review-loop/templates/impl-review-report.template.md`

Always show:
1. Verdict (PASS / PASS-with-warnings / NEEDS_WORK / BLOCKED)
2. Round and attempt numbers.
3. All reviewer-a findings that are FAIL.
4. All reviewer-b findings that are FAIL.
5. Proposed changes (if NEEDS_WORK).
6. Next steps instruction.
