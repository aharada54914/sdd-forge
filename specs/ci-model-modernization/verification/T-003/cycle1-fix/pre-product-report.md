# Implementation Report: T-003

- Task ID: T-003
- Model: gpt-6-astra (configured; no backend telemetry claim)
- Effort: high

Report Schema: implementation-report/v2
Run ID: work-agent:root:t003_implementation
Task Attempt Count: 1
Input manifest: `specs/ci-model-modernization/verification/T-003/cycle1-fix/task-input-manifest.json`, SHA-256 `458a7d3efc8a4e0e1b0e511fc4d44ec6fc7d2e008ead5f73c1aa30b84b1e4bbd`

**Snapshot Notice**: Cycle1-fix supplemental PRE-PRODUCT record. The frozen primary V2, actual NEEDS_WORK cycle1 result (Critical2/Major1), its185-file review admission and earlier evidence remain unchanged. This is not a passing bundle or task acceptance.

## Target

RT-20261019-015 and RT-20261019-016: fix receipt upload selection and first-adoption dispatch within the existing approved T003 workflow integration. RT017 concerns caller-owned performance review admission; the checklist is now admitted, and fresh independent review remains required.

## Summary

Verified the raw fix manifest and all125 snapshot hashes before use. Added meaningful regression tests against the CURRENT182-test candidate baseline. Product files are unchanged. Actual Red reproduces nonproducer/unselected uploads and failure to execute FULL adoption over a present released shadow-only planner. The sentinel now executes before the terminating main guard; forced wrong subject dispatch demonstrably exits96 without publishing a plan, while the old appended sentinel exits0 and publishes a plan.

## Files Changed

Only tests/verification-catalog.tests.py, tests/verification-ci.tests.py and this cycle1-fix evidence directory. No workflow/P/C/R/W/helper/catalog/schema/owner-test/primary-report changes, no shared-repository Git/status/ledger edits. All13 protected/current source pins match the admitted baseline.

## Tests Added Or Updated

Two RT015 methods audit all six upload jobs/16 expanded rows and reject hidden/disabled/missing-receipt escape mutations. All14 full producer rows and both full nonproducer rows are covered, plus true/false/missing plan outputs, predecessor success/failure and present/absent receipt fixtures. Native always-running wrappers correctly require no upload when no receipt producer is selected. Missing required receipts must still use if-no-files-found:error. The existing per-producer test now accepts only a bounded always-preserving producer condition rather than incorrectly demanding unconditional upload.

Three RT016 methods cover the actual released5968-byte shadow source at2aaac49, reachable sentinel sensitivity and exact API-head versus distinct tested-merge binding. The existing modern-base sentinel was moved before __main__. Absent-base, modern trusted base, all non-PR events and force-full variants remain covered by the existing methods. The actual workflow shell/env/output comparison remains intact; the fixture gained only explicit override/tested-revision/expected-exit support for negative origin testing.

The receipt fixture interprets only always() plus the already-bounded W predicates; it is not a general Actions interpreter or hosted upload execution. The action’s missing-file error setting is asserted, never replaced with a local success claim.

## Outputs

| Path | SHA-256 |
|---|---|
| `tests/verification-catalog.tests.py` | `be165d07329c0f7177d1f7333e11bc1d61f8183a65276aa811ca81c1beb6510b` |
| `tests/verification-ci.tests.py` | `f10abbbd3f94b3e926cf5568a9d3a4c4672b698a88df464fae56b8034c99b85a` |
| `specs/ci-model-modernization/verification/T-003/cycle1-fix/receipt-red.log` | `7500a0b846809cb2455517a66f5a65fd1a31f7a9ab0e9cdd675b353026e0efa2` |
| `specs/ci-model-modernization/verification/T-003/cycle1-fix/planner-red.log` | `74342ac3fe6a4aff830047520e20e17bece276efb070431d2a23a8948c72eade` |
| `specs/ci-model-modernization/verification/T-003/cycle1-fix/red-executions.json` | `a7f87ad227b65052478abc2b1cd5aa4ca5fa272d7292138aee94ee32faaf2290` |
| `specs/ci-model-modernization/verification/T-003/cycle1-fix/sentinel-sensitivity.py` | `2f7f046de4fbe1e8a693552ff52f7cc8cf799868aef15851b55fa2745c4e6c8c` |
| `specs/ci-model-modernization/verification/T-003/cycle1-fix/sentinel-sensitivity.json` | `167eb2cf29f98aa4778ec17c320f13175df6da342f0c0305c3fc64fda0adaf68` |
| `specs/ci-model-modernization/verification/T-003/cycle1-fix/sentinel-sensitivity.log` | `86519ea5425fdffbf0fb43605368c735f0bfd2e37b115db8be0fcdb994eac356` |
| `specs/ci-model-modernization/verification/T-003/cycle1-fix/red-source-preservation.json` | `ed211c959d0c6f299cc7ebc350aa3f31a55f48a6c267bd15c4632486f4fcf05c` |
| `specs/ci-model-modernization/verification/T-003/cycle1-fix/field-counterpart-preflight.md` | `ce543a1c46d176b5b793d2b24154618b43401e75cbb063fe75c5e81ae4b85b14` |
| `specs/ci-model-modernization/verification/T-003/cycle1-fix/red-tests-ruff.log` | `82b3e6a6c090a57601d22943bd23fca9218d1031dbe5a7b754092f9a156b4f18` |
| `specs/ci-model-modernization/verification/T-003/cycle1-fix/red-tests-mypy.log` | `f9b031e5c45aa702cd4fef028d465551cb20a2c4698e0913c7b00766b20ac4d8` |
| `specs/ci-model-modernization/verification/T-003/cycle1-fix/red-test-static.json` | `dadcdab6ce927409cc76e90323c8f04004016cc3066dd0f91710f1dead937fef` |

## Test Evidence

- **Test Command**: exact subprocess argv in red-executions.json; python3 -B specs/ci-model-modernization/verification/T-003/cycle1-fix/sentinel-sensitivity.py
- **Test Result**: FAIL
- **Test Evidence Path**: specs/ci-model-modernization/verification/T-003/cycle1-fix/red-executions.json

Receipt subset: three methods, actual exit1 with32 failing subcases and zero errors. Those failures are exactly the heavy compatibility/a9 nonproducer uploads and native wrappers with false/missing selected receipt output. Mutation negatives and matched selected producers pass. Planner subset: six methods, actual exit1 with one failure and zero errors; historical shadow CLI rejects --plan. The other five methods pass, including reachable sentinel sensitivity, absent planner, capable trusted base, non-PR/force-full and distinct tested-merge checks. Scoped ruff/mypy on both changed test files pass.

The independent counterfactual probe records old-after-main wrong-dispatch exit0/plan-created versus fixed-before-main exit96/no-plan. Neither probe changes the product workflow.

## Iteration And Escalation

- **Task Attempt Count**: 1
- **Escalation Prior Tier**: None
- **Escalation Next Tier**: None
- **Escalation Failure Class**: None
- **Escalation Attempt Number**: None
- **Escalation Reason**: None

## Isolation Evidence

- **Scratch Root**: /tmp/ci-t003-fix-ryhlrm9e
- **Run ID**: work-agent:root:t003_implementation
- **Session ID**: work-agent:root:t003_implementation
- **Agent Instance ID**: work-agent:root:t003_implementation
- **Isolation Mode**: fresh-agent
- **Fallback Reason**: None
- **Handoff Reload Evidence Hash**: None

Same authorized task context resumed with a refreshed125-input snapshot. No new Codex agent or external coding process was spawned by this actor. Root will delegate the narrowly bounded workflow product patch to a fresh actual Claude CLI context only after committing this Red checkpoint.

## Regression Tests Run

Only the targeted Red/mutation/origin tests and scoped static checks were necessary before product changes. The admitted baseline remains the182-test current candidate, not the pre-T003142-test tree. Full current regressions, inventory comparison and accepted-current-byte rollback will follow product GO and the delegated patch. No prior182-pass observation overrides actual cycle1 NEEDS_WORK.

## Specification Differences

None. Gate receipt uploads by declared producer selection rather than by file presence or assertion success. Preserve always() for selected producer failures and error on missing required receipts. Select capable trusted planners using the accepted P capability policy (verification-ci-plan/v1 and def plan_main markers); use the existing bootstrap for absent/historical shadow source. Preserve exact argv/env, original plan artifact identity, API head/tested merge bindings and all other workflow fields. No second planning algorithm, P/C/R/W change, new control exemption or category activation is authorized.

## Unresolved Items

Both product defects are intentionally still present for Root’s Red-only commit. Wait for explicit product GO; do not implement the workflow patch in this context. Root owns RT017 fresh-review input inclusion, statuses, tickets, commits and gate decisions. Frozen primary V2 remains SHA1e9480a383ee97319027924beddf515fe82cedcbd991cb4aac877dc0289eedc1.

## Quality Gate Focus

All producer/nonproducer matrix rows and affected native wrappers; required missing receipt errors after failures; actual present shadow-only source as well as absent source; executable-origin sentinel sensitivity; API-head/tested-merge separation; original-attempt artifacts; unchanged protected algorithms and exact prepared/A9 shapes. Fresh review must use the admitted performance checklist without inventing performance acceptance or hosted proof.

## Working Notes

The actual historical source and provenance were caller-prepared and admitted; no unadmitted git history was read. Source digest325aa985ddc0746c7276398235fe090700c118b7b0e088baf24e4cb944060ff3 is asserted before fixture use. Existing Ponytail/ECC/adapted pstack instructions remain applicable. The newly admitted performance checklist requires measurement before claims; these local fixes carry no hosted timing, cache-hit, p95 or activation claim.

## High-Risk Persisted-Field Preflight

See field-counterpart-preflight.md:18 fix-specific field/counterpart/mismatch rows, plus the complete94-field table retained from frozen V2 for unchanged contracts. This checklist was persisted before any product edit. New report/log identity, historical-source digest and origin-probe fields have explicit independent counterparts. Existing plan/result/observation/receipt field validators remain protected.

## Session Handoff

- **Current Status**: In Progress
- **Next Action**: Root inspect and commit these exact Red tests/evidence, then grant scoped product GO and delegate only the workflow patch to Claude.
- **Unresolved Items**: Product repairs and full post-fix validation pending; RT017 belongs to caller review admission; no acceptance claim.
