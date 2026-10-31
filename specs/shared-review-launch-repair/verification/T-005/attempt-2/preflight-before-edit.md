# T-005 implementation report

Task ID: T-005
Feature: shared-review-launch-repair
Run ID: T-005-01a11cbb-3dd3-7d92-9a8f-68016108fe85
Task Attempt Count: 2
Report Schema: implementation-report/v2

## Target and boundary

Approved T-005 / REQ-002 / AC-002 only. Implementation in an editable admitted-file copy; no owner apply, task-state change, real reservation, Git write or network. Attempt 1 was environment-only, blocked before implementation according to the supplied launch contract; its external logs were not read. This fresh native execution is attempt 2.

Input manifest: `reports/verification/shared-launch-handoff/T-005/attempt-2/manifest.json`; SHA-256 `347c102120352a273c7f83cb1785824ed1cd53837bf451c958a76b9cbcf09218`. Its 606 exact snapshot inputs were verified before staging. No live owner or memory inputs were used.

## High-risk preflight (recorded before changing test or production inputs)

Recorded 2026-10-08T18:23Z. Scope analysis: the only intended change is `tests/unified-launch-order.tests.py`; `tests/unified-task-launch.tests.py` imports its `exercise` helper and must retain existing behavior. No config, export, contract, production script or frozen specification requires editing. No user data is touched; reservations belong only to disposable fixture roots.

There are no newly persisted production fields. The following existing evidence fields are exercised and will support the verification addendum. Executed mismatch evidence below precedes implementation edits; expected rejecting exceptions are evidence of correct existing defenses, not production defects.

| Persisted field(s) | Sibling contract / traceability | Executed failing mismatch before implementation |
|---|---|---|
| Invocation SHA-256; native proof source_invocation_sha256 | Raw invocation bytes / TEST-005f | `preflight-mismatch-corrected-red.log`: `test_raw_invocation_pin` exits with `caller invocation pin mismatch`; baseline launch `wrong-proof` and `source-not-read` reject before reserve. |
| allowed_input_manifest[].path and sha256; dependency pins | Actual admitted bytes, complete stage/role and conditional selection / TEST-004,005a-e | `preflight-mismatch-corrected-red.log`: `test_input_hash` exits with `admitted input hash mismatch`; baseline launch missing, case, symlink, unsafe/extra path, dependency drift and conditional-presence cases reject. |
| Ordered permission-proof paths/counts and permission booleans | Ordered invocation manifest and T-001 permission contract / TEST-004 | Baseline launch `collision-not-rejected`, `wrong-proof` reject; baseline task-structured `test_enforced_control_prompt_numbers_every_exact_hash_in_required_order` and output schema mismatch tests execute reject assertions. No native permission proof is claimed. |
| Preflight status/session/invocation hash; allocation host_id/host_session_id/role/feature/attempt/round/review_turn_started and preflight_result_path/hash/result | Caller proposal equals persisted allocation and points to exact preflight / TEST-004 | Baseline launch `allocation-exists`, `preflight-exists`, `common-preflight`, `common-result` reject. Existing success assertions check all proposal counterparts. No new allocation schema. |
| Receipt sequence/previous_record_sha256/pre_append_tip_sequence/identity_unique and record digest | Canonical ledger sequence/stage/role/run_id/host_session_id/previous digest and ordered-input digest / TEST-005g,h | `preflight-mismatch-corrected-red.log`: `test_reserved_identity_receipt` reaches `receipt record hash mismatch`. Baseline launch `receipt` rejects a changed second preview. |
| TEST-005h coverage claim, ledger record count/bytes and no-retry/no-child observations | Actual validator append, canonical fixture ledger and shared launcher / REQ-002 | `coverage-gap-red.log`: audit of existing reservation-failure test finds zero actual validator reserve calls, fails `0 not greater than 0`. This is the actual test-gap RED. |

`preflight-mismatch-red.log` retains an initial scratch-probe error: its receipt case used an empty manifest and failed at the earlier nonempty-input check. It is not receipt-mismatch evidence. The corrected command executed all three intended mismatch boundaries before implementation.

All evidence is under `specs/shared-review-launch-repair/verification/T-005/attempt-2/`. Each command has a JSON record of exact argv, cwd, environment, timestamps and exit code plus an unabridged log. No formal PASS is asserted.

## Isolation evidence

- **Model**: gpt-6-astra
- **Effort**: high
- **Model Tier**: strong
- **Scratch Root**: reports/verification/shared-launch-handoff/T-005/attempt-2/output
- **Run ID**: T-005-01a11cbb-3dd3-7d92-9a8f-68016108fe85
- **Session ID**: 01a11cbb-3dd3-7d92-9a8f-68016108fe85
- **Agent Instance ID**: 01a11cbb-3dd3-7d92-9a8f-68016108fe85
- **Isolation Mode**: fresh-agent
- **Fallback Reason**: None
- **Handoff Reload Evidence Hash**: None

Parent-attested isolation: individual and batch TASK_INPUT_OK, fresh native host identity, output-only workspaceWrite, network=false, tmp exclusions, effective MCP disabled. Observed subprocess TMPDIR/TMP/TEMP all resolve to this output/tmp; HOME/XDG/.NET/Python cache paths are under output. Fixture model transport is mocked; no external model invocation.

## Current status

In Progress. Preflight and test-gap RED recorded; minimal test implementation follows. Independent review, quality gate, CI, Windows execution and parent apply are NOT RUN in this context. No lifecycle or ledger updates outside fixtures.
