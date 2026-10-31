# Traceability freeze contract reconciliation

Scope: A7 owner checkout, item 5 of the unified launch/preflight repair.
Owner: `a7-t005-intake/sdd-forge`; starting HEAD
`25813ee4baf8ae8fff344a6c979da61fbd23d2c7`.
The checkout already has extensive unrelated changes, including AGENTS.md and
launch/recovery work. Preserve all of them. This repair changes only the narrow
AGENTS freeze paragraph, a new dedicated regression driver, and this report.

Risk: evidence-contract clarification (high); no validator or historical artifact
change. The latest scoped implementation approval covers local verification only.
No reservation, verdict, approval, lifecycle, installation, Git publication or
ledger mutation is authorized by this report.

## Original authority

Owner approval commit `74d6ae3624538dae693311e295102a3b7cfd6c86`
(`docs(wfi): WFI-030 Status: Draft -> Approved (human decision)`, 2026-08-19)
changes WFI-030's status only. Its commit message explicitly records owner
approval despite the audit cycles not having run. The Proposed Change in the
document at that commit already defines raw-or-normalized task-stage hashes,
the exact five-value REQ final-cell vocabulary, and preservation of every other
byte. Approval is not test evidence. Implementation subsequently landed in
`9800296d144069676f372541991e1dba302f1a61` (#305).

The current WFI document's Applied/Result inconsistency is not authority for new
behavior and is not repaired here. Historical records and verdicts stay unchanged.

## Boundaries and preflight

| Evidence field | Counterpart | Required negative check |
|---|---|---|
| Persisted traceability digest | precheck, contract and reviewer manifest | unknown/case variant status and non-status bytes rejected |
| Current traceability input | task precheck raw digest | any changed status rejected after snapshot |
| Lifecycle claim | existing task state/quality gate | normalization grants no approval, Done, or new PASS |

Existing implementation: `check-workflow-state.sh:969-979,1731-1742,1765-1776`
and `check-workflow-state.ps1:324-343` implement the persisted exception.
`task-reviewer-a.md:257-261` describes it. `task-review-precheck.sh:119` retains
raw launch verification (PowerShell counterpart near line 628).
These paths are relative to their plugin scripts/agents directories.

## Current verification

`rtk proxy python3 -B tests/traceability-freeze-contract.tests.py` completed
successfully: 2 unittest methods, 40.363 seconds, exit 0. They exercise 24
validator outcomes: the five exact statuses accepted in both runtimes; unknown,
lowercase, annotated status, body and Evidence changes rejected in both; and raw
prelaunch verification accepting unchanged inputs and rejecting a status change
in both runtimes. This is digest compatibility, not permission for lifecycle
transitions or a quality-gate verdict.

The driver reuses existing WFI-030 fixture helpers and invokes the owner Bash
and PowerShell workflow validators. The PowerShell prelaunch check derives its
repository from its script location, so that check runs a byte-verified copy of
the script tree in a disposable fixture. Its success is isolated script behavior,
not installed/native-host proof. The first test run exposed two fixture mistakes
(Evidence column absent and PowerShell script-root resolution); only this new
driver was corrected before the successful rerun.
Formal reservation, independent review, CI and native-host execution are not
performed by this bounded repair.
