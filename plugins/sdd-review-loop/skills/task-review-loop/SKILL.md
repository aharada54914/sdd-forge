---
name: task-review-loop
description: Orchestrator for the SDD task decomposition review loop. Runs up to three rounds of dual-reviewer checks on tasks.md. Coordinates task-reviewer-a (structural coverage) and task-reviewer-b (quality/risk), merges verdicts, and manages round/attempt state. Human edits are required between rounds when findings exist.
disable-model-invocation: true
user-invocable: false
---

# Task Review Loop

Run the structural and quality review gate on a feature's tasks.md. This skill
coordinates two independent reviewers, merges their findings, and manages the
round/attempt state machine.

## Invocation

Codex:
```
Use the task-review-loop skill for feature <slug>
```

Claude Code:
```
/sdd-review-loop:task-review-loop --feature <slug> [--reset] [--edit-summary "<text>"]
```

Flags:
- `--feature <slug>`: required; identifies `specs/<slug>/tasks.md`.
- `--reset`: archive the current attempt and start a new attempt from round 1.
- `--edit-summary "<text>"`: required when re-invoking after human edits (rounds
  2 and 3). Summarises what the human changed. Stored in task-review-contract.json.

## Preconditions

Before running:
1. `specs/<feature>/tasks.md` must exist.
2. `specs/<feature>/requirements.md` must exist.
3. The spec-review-loop for this feature must have passed (check for
   `Spec-Review-Status: Passed` in requirements.md header, or equivalent gate
   record). Do not run task-review-loop if spec-review-loop has not passed.
4. The impl-review-loop for this feature must have passed (check for
   `Impl-Review-Status: Passed` in design.md header). Do not run task-review-loop
   if impl-review-loop has not passed.

## LITE-SKIP

If `specs/<feature>/acceptance-tests.md` is absent, the task review loop is not
applicable:
- Print: "task-review-loop: LITE-SKIP — acceptance-tests.md absent for feature
  <slug>. Returning PASS immediately."
- Write no files; return without further processing.

## Process (State Machine)

Determine the current attempt and round by inspecting the
`reports/task-review/<feature>/` directory. If no prior run exists, start at
attempt-1/round-1.

### STEP 1 — Precheck

Run `plugins/sdd-review-loop/scripts/task-review-precheck.sh <feature> <attempt> <round>`
(add `--provenance-rereview` / `-ProvenanceRereview` only for a
post-implementation provenance re-review; see the section below).

This script produces:
- `reports/task-review/<feature>/attempt-<M>/round-<N>/precheck-result.json`
- `reports/task-review/<feature>/attempt-<M>/round-<N>/dependency-graph.json`

For a registered full-profile feature, the precheck requires and hash-binds
`design.md`, `traceability.md`, `ux-spec.md`, `frontend-spec.md`,
`infra-spec.md`, and `security-spec.md`. It rejects invalid Layer Spec cells
before reviewer
invocation. Immediately before each reviewer starts, run the same precheck with
`--verify-inputs` (or `-VerifyInputs`) so post-precheck substitutions and
content changes fail closed.

If the script exits non-zero, halt and display its stderr output. Do not proceed
to reviewer invocation.

### STEP 2 — Invoke task-reviewer-a

Spawn task-reviewer-a as a fresh agent (no shared context) with:
- Feature slug, attempt number, round number.
- Path to precheck-result.json.
- Hash-verified allowed-input manifest including
  `design.md`, `traceability.md`, and
  `plugins/sdd-review-loop/references/reviewer-calibration.md`. For a
  registered full-profile feature the manifest MUST additionally include all
  four layer specs (`ux-spec.md`, `frontend-spec.md`, `infra-spec.md`,
  `security-spec.md`) with current hashes: the persisted-state validator
  (`check-workflow-state.sh`) rejects task-stage evidence whose reviewer
  manifests omit any layer input.

The agent reads inputs itself and writes:
`reports/task-review/<feature>/attempt-<M>/round-<N>/reviewer-a.json`

task-reviewer-a is read-only. It must not modify any spec file.
Immediately before launch, persist a one-role
`review-context-invocation/v2` manifest bound to the current hash/final record
of `reports/review-context/identity-ledger.json`. Run
`plugins/sdd-quality-loop/scripts/validate-review-context-set.sh
<invocation-manifest> <repository-root> --reserve` or the PowerShell equivalent
with `-Reserve`, and require `REVIEW_CONTEXT_OK`. Missing/stale ledger state,
caller-omitted history, or any non-zero result blocks launch.

### STEP 3 — Generate integrated-summary.json

Deterministically produce `integrated-summary.json` from reviewer-a.json.
This file contains check IDs and counts only — no verdict synthesis, no
qualitative assessment. It is used by task-reviewer-b to understand the
structural coverage landscape without being influenced by reviewer-a's verdict.

Schema:
```json
{
  "schema": "integrated-summary/v1",
  "round": 1,
  "attempt": 1,
  "reviewer_a_check_ids": ["PREREQ-AC-IDS", "BLOCKERS-FORMAT", ...],
  "reviewer_a_fail_count": 0,
  "reviewer_a_pass_count": 14,
  "reviewer_a_skip_count": 0,
  "generated_at": "<ISO8601>"
}
```

Write to: `reports/task-review/<feature>/attempt-<M>/round-<N>/integrated-summary.json`

### STEP 4 — Invoke task-reviewer-b

Spawn task-reviewer-b as a fresh agent (no shared context) with:
- Feature slug, attempt number, round number.
- Path to precheck-result.json.
- Path to integrated-summary.json.
- Hash-verified allowed-input manifest including
  `design.md`, `traceability.md`, and
  `plugins/sdd-review-loop/references/reviewer-calibration.md`. For a
  registered full-profile feature the manifest MUST additionally include all
  four layer specs (`ux-spec.md`, `frontend-spec.md`, `infra-spec.md`,
  `security-spec.md`) with current hashes: the persisted-state validator
  (`check-workflow-state.sh`) rejects task-stage evidence whose reviewer
  manifests omit any layer input.

task-reviewer-b has `disallowedPaths` covering reviewer-a.json. The agent reads
its own inputs and writes:
`reports/task-review/<feature>/attempt-<M>/round-<N>/reviewer-b.json`

task-reviewer-b is read-only. It must not modify any spec file.
Build a new one-role `review-context-invocation/v2` manifest from the ledger
state after reviewer A. Immediately before launch, run
`validate-review-context-set` with `--reserve` (Bash) or `-Reserve`
(PowerShell), require `REVIEW_CONTEXT_OK`, and launch exactly the reserved
role/run/session. No future evaluator context is required.

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

Write `reports/task-review/<feature>/attempt-<M>/round-<N>/integrated-verdict.json`:
```json
{
  "schema": "integrated-verdict/v1",
  "stage": "task",
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

Write `reports/task-review/<feature>/attempt-<M>/round-<N>/task-review-contract.json`
using the schema from `plugins/sdd-review-loop/templates/task-review-contract.template.json`.
For full-profile features, copy the precheck's exact `design_sha256`,
`traceability_sha256`, and four-entry `layer_sha256` map into the top-level
contract.
Its two reviewer entries must have distinct nonblank `run_id` and
`host_session_id` values and canonical, hash-verified allowed-input manifests.
Each reviewer manifest must include every input the reviewer is instructed to
read, including `plugins/sdd-review-loop/references/reviewer-calibration.md`.
Persist both artifacts in the same round directory; downstream prechecks reject
missing, stale, or incomplete predecessor contracts before creating evidence.

### STEP 6 — State Machine Outcome

#### Both reviewers PASS, 0 findings → PASS (clean)

- Update `specs/<feature>/tasks.md` header: add or update the line
  `Task-Review-Status: Passed`.
- Print: "task-review-loop PASSED (clean) — round <N> of attempt <M>."
- Halt.

#### Round == 3, only Minor findings remain → PASS-with-warnings

- Update `specs/<feature>/tasks.md` header: add `Task-Review-Status: Passed`.
- Append a `## Review Warnings` section to tasks.md listing every Minor finding
  with its check ID, task ID, and description.
- Print: "task-review-loop PASSED with warnings — <K> minor findings recorded."
- Halt.

#### Round < 3, Major or Critical findings → NEEDS_WORK

- Generate `reports/task-review/<feature>/attempt-<M>/round-<N>/tasks-round-<N>-proposed-changes.md`
  using `plugins/sdd-review-loop/templates/task-review-report.template.md`.
- Present the proposed changes file to the human.
- Print: "task-review-loop NEEDS_WORK — round <N> of 3. Review proposed changes
  and edit specs/<feature>/tasks.md. Then re-invoke with --edit-summary."
- Halt and await human action.

#### Round == 3, Critical or Major findings remain → BLOCKED

- Print: "task-review-loop BLOCKED after 3 rounds in attempt <M>. Critical or
  Major findings remain unresolved. Use --reset to start a new attempt after
  addressing the root causes."
- Halt.

### STEP 7 — --reset handling

When `--reset` is provided:
1. Determine the current highest attempt number M from
   `reports/task-review/<feature>/`.
2. The existing attempt-M directory remains as-is (archive by convention).
3. Create `reports/task-review/<feature>/attempt-<M+1>/round-1/`.
4. Clear `Task-Review-Status:` from tasks.md header (set to `Pending`).
5. Proceed from STEP 1 with attempt = M+1, round = 1.

## Re-Invocation After Human Edits

When the human edits tasks.md and re-invokes without `--reset`:
- Increment round counter (round 2 or round 3).
- `--edit-summary` is required; reject without it:
  "task-review-loop: --edit-summary is required when re-invoking in round 2 or 3.
  Provide a brief description of the changes made to tasks.md."
- Proceed from STEP 1 with the incremented round.

## Post-Implementation Provenance Re-Review

When task-stage review evidence must be re-bound after the implementation
phase (evidence-schema drift, incomplete reviewer input manifests) under the
AGENTS.md "post-implementation provenance re-review" rule, run a new attempt
as follows. This is a re-binding of existing PASS evidence, never a first-time
review or a findings waiver.

1. Start a new attempt: attempt = M+1, round = 1. Do NOT clear
   `Task-Review-Status:` from tasks.md — it stays `Passed`. (Setting it to
   `Pending` would violate the validator's pending-review lifecycle rule once
   tasks carry approved/advanced states.)
2. Run the precheck with the re-review flag:
   `task-review-precheck.sh <feature> <M+1> 1 --provenance-rereview`
   (PowerShell: `-ProvenanceRereview`). The flag requires at least one prior
   persisted task-review PASS verdict for the feature and tolerates a failing
   canonical workflow-state validation — the stale evidence being re-bound is
   the reason the re-review runs. Every other precheck enforcement is
   unchanged.
3. Invoke both reviewers per STEP 2–4 with the complete input set: for a
   full-profile feature this includes `design.md`, `traceability.md`, and all
   four layer specs in each reviewer manifest. Declare the invocation a
   post-implementation provenance re-review so task-reviewer-a evaluates
   INITIAL-STATE by lifecycle validity (approved audit-marked approvals and
   `Implementation Complete`/`Done` statuses are valid).
4. Reviewers emit the validator-canonical output schemas exactly as documented
   in their role files. Merge verdicts and write the contract per STEP 5.
5. After the contract is persisted, run
   `plugins/sdd-quality-loop/scripts/check-workflow-state.sh --feature <slug>`
   and require exit 0 before reporting completion.

Controlled re-binding boundary: a provenance re-review re-binds review
evidence to the current artifact hashes; it does not license content changes
to frozen artifacts. Sanctioned post-review updates go to non-frozen addenda
per AGENTS.md (see ADR 0007).

## Boundaries

- Never self-approve any finding. Findings from reviewers are facts; the
  orchestrator counts them but does not waive or override them.
- Never write to `specs/<feature>/requirements.md` or `specs/<feature>/design.md`.
- Never write `Approval: Approved` in tasks.md. Only humans may approve tasks.
- Never invoke task-reviewer-a and task-reviewer-b in the same agent context.
  Each must run in a fresh, isolated context.
- Never pass reviewer-a output directly to reviewer-b. Use integrated-summary.json
  (counts and IDs only) as the only bridge.

## Sudo Mode

Sudo mode (SDD_SUDO) does not apply to this skill. The task-review-loop always
requires genuine findings resolution by a human. The `--edit-summary` requirement
is not waived by sudo.

## Report Format

Display findings to the human using:
`plugins/sdd-review-loop/templates/task-review-report.template.md`

Always show:
1. Verdict (PASS / PASS-with-warnings / NEEDS_WORK / BLOCKED)
2. Round and attempt numbers.
3. All reviewer-a findings that are FAIL.
4. All reviewer-b findings that are FAIL.
5. Proposed changes (if NEEDS_WORK).
6. Next steps instruction.
