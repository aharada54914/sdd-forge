# Quality Gate Report

Task ID: T-006
Feature: sdd-domain
VERDICT: PASS

## Target

Hook-guard extension across all four language twins
(`sdd-hook-guard.{js,py,ps1,sh}`): reject an agent-authored net increase of
`Domain-Model-Status: Approved` in `domain/context-map.md`, bypassable by a
valid `SDD_SUDO` token (same class as the tasks.md Approval guard, NOT the
never-bypassable WFI pattern). Applied to the real protected paths via the
scratchpad → human-`cp` procedure.

## Implementation Report Reviewed

`reports/implementation/sdd-domain/T-006.md` (heading, `- Task ID: T-006`,
`## Outputs` table with 5 hash-verified paths). Treated as claim only.

## Verification Results

- `specs/sdd-domain/verification/T-006.contract.json` — Default-FAIL contract.
  `check-contract.sh`: **"Verification contract passed for task T-006."**
- Deterministic gates run for real: `unit-tests`/`acceptance-tests`/
  `regression` (bash tests/guard-parity.tests.sh — 27 passed, 2 failed, both
  failures the documented pre-existing Windows/MSYS sudo-realpath quirk),
  `requirement-traceability` (11/11 links), `placeholder-scan` (exit 0),
  `task-state-check` (exit 0). `lint`/`typecheck`/`build` waived
  (`stack: shell`).
- Red/Green tdd evidence: documentary pointer to the implementation report's
  `## Test Evidence` RED/GREEN subsections (fresh re-execution impossible
  without editing self-protected files; flagged transparently in the
  contract).
- Independent `sdd-evaluator` (fresh context, ledger sequence 25, run_id
  `RUN-20260707T0000Z-sdd-evaluator-T-006`): **PASS**. Re-ran the parity
  suite itself (exactly 27/2, failure names verified), traced the sudo-bypass
  failure to `sudoActive()`'s realpath repo-binding check diverging under
  MSYS (pre-existing scenario 16 fails identically with untouched code —
  fault isolated to environment, not the new guard), verified regex/path-gate/
  net-increase/sudo-wiring/bilingual-message parity across `.js`/`.py`/`.ps1`
  by line-level inspection, confirmed `.sh` is a genuine dispatcher, and
  confirmed the harness exercises BOTH real JS and PY guards per scenario
  (no completion-faking; path-gate precision and non-Approved-transition
  scenarios rule out a blanket denier).

## Evidence Matrix

| Surface | Evidence Type | Evidence Path Or Command | Result | Notes |
|---|---|---|---|---|
| AC-007 rejection (Write/Edit/apply_patch/bash) | scripted_gate + command_output | `specs/sdd-domain/verification/T-006.unit-tests.log` | PASS | scenarios 23-26 green on both JS+PY twins |
| Path-gate precision / non-Approved transitions | scripted_gate | same log, scenarios 28-29 | PASS | non-context-map files and Pending→Reviewed unaffected |
| Sudo bypass | line_inspection + command_output | evaluator root-cause trace; scenarios 16+27 | PASS (env-limited) | both fail identically due to pre-existing MSYS realpath quirk; logic verified correct by inspection |
| Guard regression (kill-switch, approval, WFI, second-approval, agent-role, r10, sudo-protect, impl-review-status) | scripted_gate | same log, scenarios 1-22 | PASS | no regression across twins |
| Three-twin parity | line_inspection | evaluator source inspection (js:787-860, py:620-688, ps1:390-431) | PASS | identical semantics; .sh confirmed dispatcher |
| Traceability | scripted_gate | `specs/sdd-domain/verification/T-006.traceability.log` | PASS | 11/11 links |

## Cannot-Verify Items

| Surface | Missing Evidence | Blocking Ticket Or Resolution |
|---|---|---|
| Live sudo-bypass end-to-end on this host | environment realpath quirk (pre-existing) | Resolved by evaluator line-level inspection + isolation proof (untouched scenario 16 fails identically); non-blocking per calibration evidence ladder items 2-3 |

## Out-Of-Scope Waivers

| Surface | Why Out Of Scope | Waiver Reference |
|---|---|---|
| `lint`/`typecheck`/`build` | Non-code stack | `T-006.contract.json` (`stack: shell`) |
| integration/smoke/differential/UI/design-system | Hook script, not startable; net-new; no UI | `T-006.contract.json` waiver_reason fields |

## Critical Review Cycles

1 cycle. Evaluator PASS on first pass. Two Minor findings, neither blocking:

1. [Minor] Implementation report prose is stale relative to the applied
   state (says human `cp` is "pending"; the files are now applied and
   hash-bound). Documentation inaccuracy only.
2. [Minor] acceptance-tests.md's TEST-007/TEST-014 cite a test target
   filename (`tests/hooks/domain-approval-guard.Tests.ps1`) that does not
   exist; the behavior is actually covered by `tests/guard-parity.tests.sh`
   scenarios 23-29. Spec naming drift, flagged for a future spec cleanup.

## UI Verification

Not applicable — no UI surface.

## Traceability And Drift

REQ-005/T-006 → AC-007 mapping verified (AC-014 correctly owned by T-005's
precheck per T-006's Out of Scope). No drift.

## Review Tickets

None — no unresolved Critical or Major finding.

## Decision

**Done.** All required contract checks pass with real evidence, the
independent evaluator returned PASS with root-cause-level verification of
the only environment-limited surface, and no Critical/Major finding remains.
