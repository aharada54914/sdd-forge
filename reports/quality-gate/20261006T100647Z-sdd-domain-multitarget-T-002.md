# Quality Gate Report

Task ID: T-002
Feature: sdd-domain-multitarget
Run ID: 01a110a1-5589-7501-b440-8926b897e0a2
VERDICT: NEEDS_WORK
Critical: 1
Major: 0
Minor: 0

<!-- Identity header contract (WFI-020). Every line above is parsed by a     -->
<!-- deterministic consumer: Task ID by check-evidence-bundle and the         -->
<!-- run-record/cycle-limit counters (canonical task-identity field; the      -->
<!-- legacy separate `Task:` line is retired — do not add one); Feature by    -->
<!-- report selection and the exactly-one rule in check-evidence-bundle;      -->
<!-- Run ID by the retrospective's artifact rules (value = the evaluator run  -->
<!-- id reserved in the identity ledger for this gate run); Critical/Major/   -->
<!-- Minor by generate-evidence-bundle, which records zeros when absent.      -->
<!-- Keep each as a bare line before any prose, and never start a later line  -->
<!-- in the body with `Feature: ` or `Task ID: `.                             -->

## Target
Owner: `/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge`; branch `codex/issue423-boundary-checkpoint`; evaluated HEAD `3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9` with preserved pre-existing dirty changes. Scope: approved T-002 ownership/provider-neutral boundaries only; Risk medium, acceptance-first. T-001 remains Done; T-002 retains Implementation Complete; T-003 remains Blocked.

- Model: gpt-6-astra
- Effort: medium

Evaluator: shipped `sdd-evaluator`, canonical agent `/root/issue423_t002_evaluator`, fresh isolated context. Caller/native session `01a1109f-c67e-75f1-8682-b4b4ba72ffc6`; implementation native session `01a06d01-11b5-7bd3-83a3-7e29bb3c96cd`. Actual run/thread is the Run ID above. Selector drift: TOML reference `openai/gpt-5.2-codex/high`, live selector `gpt-6-astra/medium`; actual native metadata confirms live values. No role, host settings or installed baseline changed.

## Implementation Report Reviewed
`reports/implementation/sdd-domain-multitarget/T-002.md`, SHA-256 `3f2ae5bf8d85e7a28b87165f9f699068801562ca77b88ab4d8877c38e5a1d2b4`. Frozen implementation report and historical reports unchanged. Its current-adoption addendum supersedes historical pending claims within its declared scope; claims alone were not used for PASS.

## Verification Results
Normal preflight and atomic reservation both returned REVIEW_CONTEXT_OK, receipt `cb126f0453dc4b4cbf791d1378dc49c7e30326f6a9dc4e19a108b36bbd35dc1d`, sequence 1196, previous tip 1195. Invocation SHA-256 `f8b426977c765176d86f3af178cb6dc3fce4c5888947ca315ac7e949f8571085`; all 76 admitted input hashes matched before launch. Independent evaluator recomputed receipt/scratch hashes and checked real identities. One reservation only; the preimage ledger hash remains intentionally unchanged after append.

Fresh caller lint, strict typecheck, boundary suite (28), canonical Registry dispatcher (9 checks), and discovery suite (21) succeeded. Fresh risk, placeholders, full workflow-state, task-state and the previously admitted contract check succeeded. Component coverage emitted `not-applicable (disabled-legacy)` with zero evaluation: N/A, not PASS.

Independent evaluator reran the 28 boundary tests successfully, then directly observed four unhandled provider-key negative cases in memory. Current acceptance/regression completion therefore fails. The updated Default-FAIL current contract's final check exits 1 for acceptance-tests and regression; the first check's empty unittest stdout reference was corrected to its genuine non-empty stderr log, retaining both check outputs. Admitted contract bytes are archived unchanged at `reports/verification/issue423-t002-fresh-caller-01a1109f-c67e-75f1-8682-b4b4ba72ffc6/T-002.contract.admitted.json` (SHA-256 `ac635f41d70213d8e3efc7d364fea0d6f7d36954ddfb4d0c8b1349c75d5c3a22`); current contract is a gate outcome, not a retroactive evaluator input.

Own native hook canary write executed. Verification returned Exit 63 WRITE_EXECUTED/CAPABILITY_RUNTIME_UNAVAILABLE; no HOOK_ACTIVE claim. The canary was removed and cleanup confirmed. An initial raw-result formatting rejection (Exit 62) remains historical; the actual result envelope was corrected without repeating the write. This handshake occurred after evaluation admission, so this report does not claim the prescribed ship startup order was satisfied. Project Context is physically absent: G4 disabled-legacy permits legacy flow. No plugin reinstallation or protected code application occurred.

## Evidence Matrix

| Surface | Evidence Type | Evidence Path Or Command | Result | Notes |
|---|---|---|---|---|
| Provider-key boundary | command_output + line_inspection | `reports/verification/issue423-t002-fresh-caller-01a1109f-c67e-75f1-8682-b4b4ba72ffc6/evaluator-negative-experiment.json`; `evaluator-negative-reproduction.sh` | FAIL | Four schema-valid key cases accepted; RT-20261006-002 |
| Admitted isolated evaluation | manual_artifact + command_output | `reports/verification/issue423-t002-fresh-caller-01a1109f-c67e-75f1-8682-b4b4ba72ffc6/evaluator-invocation.json`, `reservation.txt`, `evaluator-result.txt` | NEEDS_WORK | Real identities; 76 exact inputs; receipt chain checked |
| Lint / strict typecheck | command_output | `reports/verification/issue423-t002-fresh-caller-01a1109f-c67e-75f1-8682-b4b4ba72ffc6/lint.stdout.txt`, `typecheck.stdout.txt` | PASS | Current validator/helper scope |
| Existing boundary suite / discovery | command_output | `reports/verification/issue423-t002-fresh-caller-01a1109f-c67e-75f1-8682-b4b4ba72ffc6/boundary-tests.stderr.txt`, `registry-discovery.stdout.txt` | PASS | 28 tests and 21 checks; does not cover new finding |
| Canonical Registry | command_output | `reports/verification/issue423-t002-fresh-caller-01a1109f-c67e-75f1-8682-b4b4ba72ffc6/registry.stdout.txt` | PASS | 9 checks; current content only |
| Risk / placeholder / workflow / task | scripted_gate | `reports/verification/issue423-t002-fresh-caller-01a1109f-c67e-75f1-8682-b4b4ba72ffc6/caller-checks.json` and associated logs | PASS | Full workflow-state, not feature-filtered; old T-001 dirty warning |
| Current verification contract | scripted_gate | `reports/verification/issue423-t002-fresh-caller-01a1109f-c67e-75f1-8682-b4b4ba72ffc6/contract-final-check.log`; `specs/sdd-domain-multitarget/verification/T-002.contract.json` | FAIL | Required acceptance/regression false |
| Component coverage | scripted_gate | `reports/verification/issue423-t002-fresh-caller-01a1109f-c67e-75f1-8682-b4b4ba72ffc6/component-coverage.stdout.txt` | N/A | disabled-legacy, zero evaluation |
| Installed payload build | manual_artifact | `specs/sdd-domain-multitarget/verification/T-002/qg-prep-20261003/current-build-and-checks.md`; `reports/verification/issue423-t002-fresh-caller-01a1109f-c67e-75f1-8682-b4b4ba72ffc6/build-byte-readback.json` | PASS (scoped historical reuse) | Same validator/helper and genuine human log hashes; no current complete installation claim |
| ci-mcp readonly | manual_artifact + line_inspection | `reports/verification/issue423-t002-ci-readonly-current-20261005.log`; admitted implementation | Historical PASS | 34 tests; independent rerun not claimed |
| Current HEAD CI | command_output | `reports/verification/issue423-t002-fresh-caller-01a1109f-c67e-75f1-8682-b4b4ba72ffc6/ci-head-query.log` | PASS for public HEAD only | Run 36882890633; dirty recovered candidate CI NOT RUN |
| Native hook handshake | manual_artifact + command_output | `reports/verification/issue423-t002-fresh-caller-01a1109f-c67e-75f1-8682-b4b4ba72ffc6/hook-handshake.stdout.txt`, `hook-cleanup-result.json` | NOT VERIFIED | Write executed, capability unavailable; cleanup confirmed |

Implementation-report statements are claims, not evidence. Leave no in-scope
surface without a command, scripted gate, line inspection, or manual artifact.

## Cannot-Verify Items

| Surface | Missing Evidence | Blocking Ticket Or Resolution |
|---|---|---|
| Provider-key rejection | Failing regression and repaired-byte independent evaluation | RT-20261006-002 |
| Dirty candidate CI | Public HEAD success predates local recovered edits | Pending repair/current-head CI; no push authorized |
| Native hook activation | Canary write executed; capability runtime unavailable | Explicit limitation; legacy derived state does not prove activation |

In-scope cannot-verify items block Done until evidence is collected or a review
ticket is created. Waivers are valid only for optional out-of-scope checks.

## Out-Of-Scope Waivers

| Surface | Why Out Of Scope | Waiver Reference |
|---|---|---|
| UI / design system | No UI change; design-system directory absent | Current contract waiver |
| Domain conformance | domain directory absent | Physical directory probe |
| Differential baseline | No baseline-behavior.md or task differential requirement | Current contract waiver |
| Native Windows / registration / release | Ownership task, no new host installation or release | ADR-0017; historical payload evidence scope only |

## Critical Review Cycles
One fresh independent cycle; raw result preserved at `reports/verification/issue423-t002-fresh-caller-01a1109f-c67e-75f1-8682-b4b4ba72ffc6/evaluator-result.txt`. VERDICT NEEDS_WORK.

Accepted Critical finding RT-20261006-002: `validate-capability-registry.py:153-156` checks only credentials/state_authority dictionary keys, while lines 160-164 check provider vocabulary only in string values. For both trigger and conditional predicates, `{"azure":true}` and `{"metadata":{"aws":false}}` pass schema construction and provider check with no diagnostics. Equivalent string value azure is rejected. This violates REQ-002 and T-002 Done When. Actual experiment call `call_32bc8a7944fa4e178dd534990b16a5cf`, native transcript line 144; command and raw output saved separately.

No evaluator finding rejected or downgraded. Stop at cycle 1: repair belongs to the approved protected/fix-by-review-ticket path, not this evaluation. The source implementation chat has taken ownership of root-cause repair; evaluator and caller changed no production code. Existing reservation/verdict retained. No new reviewer launched.

## UI Verification
N/A: T-002 changes contract ownership and validator boundaries, with no UI surface.

## Traceability And Drift
REQ-001/REQ-002 -> AC-002/AC-012 -> TEST-002/TEST-012 reviewed against the task and actual tests. Existing 28-test coverage omits provider names in dictionary keys; T-002 ownership acceptance is not satisfied. Frozen traceability is retained; this non-frozen report records current lifecycle and coverage drift rather than altering passed review bytes. ADR-0016/0017 derived legacy and implementation-stage boundaries retained; ADR-0018 provider-binding separation exposes the identified mismatch. No architecture, approval or task scope changed.

## Review Tickets
New RT-20261006-002: open, Critical, accepted; shared recursive provider-key rejection and negative regression coverage required. Auto-fix disallowed in this evaluation.

Existing RT-20260930-001 and RT-20261006-001 remain open. Their old launch/Registry symptoms are not counted as new evaluator findings: current canonical Registry checks and normal admission succeed. Neither preparation recovery nor successful admission alone constitutes full T-002 acceptance or closes the tickets. Historical records preserved.

## Decision
NEEDS_WORK. T-002 retains Implementation Complete; no Done decision or evidence bundle is issued. T-003 remains Blocked. No frozen task/traceability edit, implementation fix, commit, push, PR, merge, or baseline/host installation change. Source repair must preserve this verdict and reservation, add actual failing regression evidence, use the sanctioned protected path, and rebind repaired bytes for a fresh independent gate. CI for the old public HEAD does not verify local recovered edits. No retrospective invoked.
