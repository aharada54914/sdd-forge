# Requirements: second-approval-mask

Spec-Review-Status: Passed
Source Issues: docs/review-tickets/RT-20260712-003.yml (framework defect
discovered while completing the first critical-tier two-person approval,
epic-136-phase1-guards T-001/T-002)
Epic: https://github.com/aharada54914/sdd-forge/issues/136 (Phase 1 follow-up)

## Overview

Make the critical-tier two-person approval recordable. The workflow-state
provenance gate freezes each registered feature's `tasks.md` at task-review
time via a normalized hash that masks exactly three lifecycle line prefixes
(`Task-Review-Status:`, `Approval:`, `Status:`). The critical tier requires a
second distinct named human to record `Second Approval: Approved (<id> <ISO>)`
in `tasks.md` AFTER that freeze (agents are forbidden from writing it by the
hook guard), but the line is not masked, so recording it changes the
normalized hash and `check-workflow-state` fails the whole repository with
`stage-provenance: task plan hash is stale`. The two-person flow that the
enforcement chain mandates is therefore structurally impossible to complete.
This feature teaches the task-stage normalization in both validator twins to
treat `Second Approval:` lines as lifecycle state.

## Target Users

- Second human approvers recording critical-tier approvals in `tasks.md`.
- Orchestrating agents and humans running `check-workflow-state` (directly,
  in quality gates, or in CI) on repositories with critical-tier tasks.
- Future features with `Risk: critical` tasks in this repository.

## Problems

1. `normalized_hash` (sh) and `Get-NormalizedHash` (ps1) mask only
   `Task-Review-Status:`, `Approval:`, and `Status:` lines for the task stage.
   `Second Approval:` is a lifecycle field with the same post-freeze mutation
   pattern but is treated as frozen plan content.
2. Unlike the three masked fields, the `Second Approval:` line is ABSENT at
   freeze time and ADDED later. Value masking (the existing technique) cannot
   reconcile absence with presence; only line deletion can.
3. The failure is repository-wide and fail-fast: one feature recording its
   second approval blocks `check-workflow-state` for every registered feature,
   which in turn blocks every quality gate.

## Goals

- REQ-001: The task-stage normalized hash computed by
  `plugins/sdd-quality-loop/scripts/check-workflow-state.sh` and its
  PowerShell twin treats column-0 `Second Approval:` lines as lifecycle
  state by DELETING them (the entire line including its line terminator)
  before hashing, so that a `tasks.md` frozen without the line and the same
  file after a human records `Second Approval: Approved (<id> <ISO>)`
  normalize to byte-identical streams. The deletion applies to any value of
  the field (Pending, Approved, or otherwise), applies to LF and CRLF files
  alike, applies only to the task stage, and changes nothing else about the
  freeze: any other line added, removed, or edited in `tasks.md` must still
  trip `task plan hash is stale` exactly as today. The sh and ps1 twins must
  agree byte-for-byte on the normalized form and decision-for-decision on
  the validation outcome.

## Non-goals

- No change to `check-task-state` (its Second Approval format/distinctness
  validation at Done is already correct and stays the enforcement point for
  the field's CONTENT).
- No change to the hook guard's rule that agents must not write
  `Second Approval:` lines.
- No change to spec-stage or impl-stage normalization, the identity ledger,
  registry schema, or any other validator.
- No retroactive re-hashing of existing task-review contracts.

## User Stories

- As a second human approver, I record `Second Approval: Approved (Harada2
  <ISO>)` under a critical task and `check-workflow-state` still reports
  `workflow-state: ok`, so the quality gate can proceed to Done.
- As an orchestrator, I rely on the freeze to detect any other post-review
  edit to `tasks.md` (scope text, checkboxes, new lines), and this fix does
  not weaken that detection.

## Acceptance Criteria

- AC-001 (REQ-001): Given a registered feature whose task-review contract
  froze `tasks.md` without a `Second Approval:` line, when a
  `Second Approval: Approved (<id> <ISO>)` line is added under a task after
  the freeze, then `check-workflow-state` exits 0 with `workflow-state: ok`
  under BOTH the sh and ps1 twins. The corpus includes a MULTI-OCCURRENCE
  variant — the field recorded under TWO critical tasks in the same
  `tasks.md` (the RT-20260712-003 originating shape, epic-136-phase1-guards
  T-001/T-002; exercises the multiple-lines edge case) — with the same
  expected outcome. (TEST-001)
- AC-002 (REQ-001): Given the same fixture, when any OTHER modification is
  made to `tasks.md` after the freeze — (a) an added arbitrary line, (b) a
  `- [ ]` checkbox flipped to `- [x]`, or (c) an added INDENTED/bulleted
  line that merely mentions the field (e.g. `  Second Approval: pending
  discussion` or `- [ ] record Second Approval`), which must NOT match the
  column-0 mask — then both twins still fail with `stage-provenance` /
  `task plan hash is stale` semantics and a nonzero exit — the freeze is not
  weakened beyond the single column-0 field line. Sub-case (c) is the
  anchoring negative control demanded by Risks (over-broad masking).
  (TEST-002)
- AC-003 (REQ-001): AC-001 and AC-002 hold for a CRLF-terminated `tasks.md`
  exactly as for LF: the deletion removes the whole line including its CRLF
  terminator, and the sh and ps1 normal forms remain byte-identical. The
  corpus includes a fixture where the `Second Approval:` line is the FINAL
  line without a trailing newline (Edge Case #5), asserting both twins agree
  and their normal forms are byte-identical for it. (TEST-003)
- AC-004 (REQ-001): For the full new fixture corpus, the sh and ps1 twins
  produce identical exit statuses and identical first diagnostic rule IDs
  (parity), and the suite is registered in `tests/run-all.sh` so it runs
  with the repository suite. (TEST-004)
- AC-005 (REQ-001): The fixed twins reach their live protected paths only
  via the human-copy procedure: agents stage both files under
  `specs/second-approval-mask/human-copy/` with a SHA-256 MANIFEST (the
  hook guard's R-10 protected-suffix rule denies agent writes to the live
  paths — the enforcement mechanism), and the quality gate records
  deterministic evidence that each live file's SHA-256 equals the staged
  MANIFEST hash. (TEST-005 — gate-phase evidence check, not a shell-suite
  case)

## Field Definitions

- `Second Approval:` — existing critical-tier tasks.md field (defined by
  check-task-state and ship/SKILL.md): set only by a second distinct named
  human as `Second Approval: Approved (<id> <ISO8601>)`. This feature only
  changes how the workflow-state freeze treats the LINE, not the field's
  meaning, format, or authorization.

## Roles and Permissions

- Only humans may write `Second Approval:` lines (enforced by the hook
  guard; unchanged).
- Only humans may apply the fixed validator twins to their live protected
  paths (enforced by the hook guard's R-10 protected-suffix rule, which
  denies agent writes to `check-workflow-state.{sh,ps1}`; agents stage under
  `specs/second-approval-mask/human-copy/` with a SHA-256 MANIFEST, and
  AC-005 requires the quality gate to record live==staged hash evidence).

## Main Workflows

1. Task-review freezes `tasks.md` (no `Second Approval:` line) — normalized
   hash H recorded in the task-review contract.
2. Implementation completes; gate runs; a second human records
   `Second Approval: Approved (<id> <ISO>)`.
3. `check-workflow-state` normalizes the current `tasks.md`: lifecycle values
   masked, `Second Approval:` lines deleted → hash equals H → `ok`.
4. Any other tampering with `tasks.md` → hash differs from H → fail-fast
   diagnostic, unchanged from today.

## Edge Cases

- `Second Approval:` occurring at column 0 inside quoted/template text in
  `tasks.md` is also deleted by the mask. This mirrors the existing masks
  (`Status:`/`Approval:` have the same property) and is accepted: the
  normalization is a line-prefix rule, not a parser.
- Indented or bulleted mentions (e.g. `- [ ] ... Second Approval ...` in
  Done When lists) do NOT start at column 0 with the prefix and are NOT
  deleted — they remain frozen content.
- Multiple `Second Approval:` lines (one per critical task) are all deleted.
- A `Second Approval:` line already present at freeze time (future
  bootstraps may template it) is deleted on both sides of the comparison,
  so freeze-time presence is also safe.
- Final line without trailing newline: deletion semantics must match between
  sed (`/^Second Approval:/d`) and the ps1 regex so the normal forms stay
  byte-identical.

## Security Boundaries

- The change deliberately removes ONE line class from tamper evidence. The
  field's integrity is still enforced by: (a) the hook guard denying agent
  writes of the line (fail-closed, sudo-proof), and (b) `check-task-state`
  requiring a well-formed, named, distinct second approver at critical Done.
  Deleting a recorded approval would un-satisfy (b), not forge anything.
- The mask must be anchored to column 0 and the exact `Second Approval:`
  prefix so no broader content class escapes the freeze (AC-002 guards this).

## Assumptions

- `pwsh` 7.x is available on hosts that run the ps1 twin (existing repo
  assumption; parity suites already require it).
- The `--registry` test entry point of both twins remains available for
  fixture-based testing (used by tests/workflow-state-parity.tests.sh today).

## Open Questions

None. The deletion-vs-masking decision is fixed by the absence-at-freeze
property (Problems #2); the enforcement points for field content are
explicitly out of scope (Non-goals).

## Risks

- Over-broad masking would silently weaken the task-plan freeze repo-wide.
  Mitigation (Critical): AC-002 negative controls MUST prove that arbitrary
  line additions and checkbox flips still trip staleness in both twins, and
  the fixture corpus must include them from the RED stage.
- sh/ps1 normal-form divergence would make the parity twins disagree on
  Windows. Mitigation: AC-003/AC-004 require byte-identical normal forms and
  decision parity across LF and CRLF fixtures.
- The validators are protected gate scripts; a botched live apply would
  break every gate. Mitigation: TDD against staged copies, human-copy with
  SHA-256 manifest verified as gate evidence (AC-005), and the existing
  workflow-state suites re-run at the gate.
