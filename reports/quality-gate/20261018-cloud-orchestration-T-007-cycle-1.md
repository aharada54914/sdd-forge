# Quality Gate Report

Task ID: T-007
Feature: cloud-orchestration
Run ID: 01a14fb8-dc09-7670-8869-47edb320bb3c
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
REQ-011 / AC-011 / TEST-011 packaging: opt-in Azure/AWS manifests and public skills, explicit shared runtime dependency, installer materialization and retained-dependency uninstall.

- Model: openai/gpt-6-astra
- Effort: high

## Implementation Report Reviewed
Frozen canonical `reports/implementation/cloud-orchestration/T-007.md`; the exact input manifest, supplemental delivery and any declared post-fix inputs determine the bytes reviewed.

## Verification Results
All actual caller checks passed: 11 packaging tests; Bash/PowerShell installation, uninstall, idempotency and install-uninstall matrices; Claude-install regression; repository validation; strict Ruff/mypy on three test/evidence files; build/shell syntax, risk/placeholders, task/workflow state, traceability, legacy component checker and verification contract. Installed provider CLI tests cover 32 installed/cache invocations, canonical predecessor matched/restored route PASS, missing UNSAFE_OR_UNAVAILABLE_FILE and invalid CHECK_SET_MISMATCH, no-executor prepare/apply denial, installed module/registry/schema integrity and dependency controls. Real local PowerShell is exercised; shaped host caches are fixture layouts, not a native model trial. Isolated committed rollback proves final production restoration and 51 baseline installer cases; its earlier test bytes are explicitly qualified after a test-only coverage follow-up.

## Evidence Matrix

| Surface | Evidence Type | Evidence Path Or Command | Result | Notes |
|---|---|---|---|---|
| Caller checks | command_output | specs/cloud-orchestration/verification/T-007/quality-cycle-1/commands.json | PASS | Actual packaging and existing installer regressions |
| Final installed CLI controls | scripted_gate | specs/cloud-orchestration/verification/T-007/attempt-1/coverage-completion-packaging.log | PASS | Eleven tests; exact canonical predecessor error/control assertions |
| Rollback scope | scripted_gate | specs/cloud-orchestration/verification/T-007/attempt-1/coverage-completion-result.json | PASS | Final production bytes restored; subsequent test-only delta explicitly qualified |
| Independent evaluator | line_inspection | specs/cloud-orchestration/verification/T-007/quality-cycle-1/review/evaluator.txt | FAIL | Critical runtime retention finding |
| Delivery closure | scripted_gate | specs/cloud-orchestration/verification/T-007/root-delivery-check.json | PASS | 666 output hashes; no private native transport streams |

Implementation-report statements are claims, not evidence. Leave no in-scope
surface without a command, scripted gate, line inspection, or manual artifact.

## Cannot-Verify Items

| Surface | Missing Evidence | Blocking Ticket Or Resolution |
|---|---|---|
| Actual native model-host routing | Only installed CLI and shaped cache fixtures in T007 | T011 actual verify-codex trial pending |
| Native Windows/macOS and full release CI | Local Linux task scope | T011/T008 actual matching platform checks pending |
| Live cloud authorization/deployment | No owner sandbox | RT-20261018-CLOUD-SANDBOX remains open |

In-scope cannot-verify items block Done until evidence is collected or a review
ticket is created. Waivers are valid only for optional out-of-scope checks.

## Out-Of-Scope Waivers

| Surface | Why Out Of Scope | Waiver Reference |
|---|---|---|
| UI | No UI changes | N/A |
| Live cloud acceptance | Unavailable, not waived | RT-20261018-CLOUD-SANDBOX |

## Critical Review Cycles
First actual independent evaluator identified Critical1: subsequent differing installation selections erase the previously installed provider runtime. Existing fresh-destination tests did not cover sequential selections. Original review input set remains frozen; a bounded repair and fresh review are required. Actual independent evaluator 01a14fb8-dc09-7670-8869-47edb320bb3c; invocation SHA-256 2ceb1c0fff8ad3d97d3eb00510f634ebc9bacf75fda88a5a8a8b9d083fd79a47. Delivery hashes equal the launched input set and every read stayed within the allowlist.

## UI Verification
Not applicable; no UI.

## Traceability And Drift
Canonical report SHA-256 1e495b37972714f923600a9c75b8023fb2561d0e68fd0d36d88aeb665ac1ba25 binds 666 checked Outputs. Original native context 01a14f96-e637-7773-aa3b-74e44216f500 continued for stronger CLI receipt controls before review; first handoff and 113 historical evidence files remain unchanged. Current supplemental inputs bind actual reviewed bytes. REQ011 local packaging addendum distinguishes pending T011 routing/real-host trial and T008 native-platform/full-release work.

## Review Tickets
RT-20261018-CLOUD-INSTALL-SELECTION-RUNTIME opened for the Critical runtime retention defect. Existing user authorization covers this implementation fix; no human prerequisite exception is requested.

## Decision
Do not set T007 Done or proceed to T011. Preserve this NEEDS_WORK finding and the canonical implementation report. Repair sequential differing-selection installs, add real Bash/PowerShell regression and rollback evidence, then run a fresh independent gate.
