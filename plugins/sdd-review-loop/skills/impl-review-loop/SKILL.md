---
name: impl-review-loop
description: Orchestrator for the SDD implementation policy review loop. Runs up to three rounds of dual-reviewer checks on design.md. Coordinates impl-reviewer-a (structural soundness) and impl-reviewer-b (implementability/risk), merges verdicts, and manages round/attempt state. Human edits are required between rounds when findings exist.
disable-model-invocation: true
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
For full-profile features, both manifests must also include `ux-spec.md`,
`frontend-spec.md`, `infra-spec.md`, and `security-spec.md`, using the hashes
recorded in `precheck-result.json`; copy that map to the contract's
`layer_sha256` field.
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
4. Change `Impl-Review-Status:` in design.md header to `Pending`.
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
