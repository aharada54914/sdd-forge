# T-005 implementation report

Task ID: T-005
Feature: shared-review-launch-repair
Run ID: T-005-01a11cbb-3dd3-7d92-9a8f-68016108fe85
Task Attempt Count: 2
Report Schema: implementation-report/v2

Snapshot Notice: Findings and hashes describe this immutable handoff and its staged output only. A later quality gate independently evaluates applied bytes; this report is not a gate verdict.

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

## Summary and files changed

Staged implementation is complete for parent review. Only `tests/unified-launch-order.tests.py` changes: it now exercises the real canonical validators on fixture ledgers, including postappend receipt mismatch and rejection of a subsequent same-identity reservation. Production already enforced the required stop; all production bytes are preserved. The old receipt case was preview-only and the old ledger was disconnected from the validator, so the RED is a test coverage gap, not a production defect.

`exercise` retains its existing default behavior for `tests/unified-task-launch.tests.py`; new optional validator-backed cases run Bash and PowerShell for spec/impl/task. They check exactly one launcher reservation, retained appended identity, no prompt or child on postappend mismatch, and byte-identical ledger after an explicit adversarial re-reservation attempt. The automatic launcher does not retry. Additional cases cover TEST-004/005a-g, ordered proof and conditional drift.

Source SHA-256: before `c75879828938c77d7a5ed52a987a739b96365fa7a469c5553bf1297ccc768ee4`; final `612c0b9194c014bf4cb07d8ac13d551c1243b2ade2b268c7c28be6d7e1aba50e`. `input-and-source-hashes.json` verifies all 606 snapshot inputs unchanged and only this staged input changed. Unchanged staging copies were removed from output/work; it contains only the changed test, this report and this task's evidence.

## Test evidence and regressions

- **Test Command**: `rtk proxy python3 -B tests/unified-launch-order.tests.py -v`; all exact regression commands follow below.
- **Test Result**: Local execution succeeded (exit 0); formal quality gate NOT RUN.
- **Test Evidence Path**: specs/shared-review-launch-repair/verification/T-005/attempt-2/README.md

All final commands below executed after rollback and reapply, in the disposable output/work. Each has `final-<label>.json` (exact command/cwd/environment/timestamps/exit) and `.log` (complete output). The output runner itself is archived under `harness/run.py`; exact outer runner commands are also in `execution-summary.json`.

| Label | Exact test command | Observed result |
|---|---|---|
| launch | `rtk proxy python3 -B tests/unified-launch-order.tests.py -v` | Exit 0; 9 tests, including 6 postappend runtime/stage cases and 20 canonical success/preappend cases. |
| conditional | `rtk proxy python3 -B tests/review-conditional-inputs.tests.py -v` | Exit 0; 16 tests, Bash and PowerShell validators. |
| spec-inputs | `rtk proxy python3 -B tests/spec-review-verify-inputs.tests.py -v` | Exit 0; 2 tests, Bash and PowerShell prechecks. |
| task-structured | `rtk proxy python3 -B tests/task-structured-output.tests.py -v` | Exit 0; 13 tests, pinned AJV dependencies. |
| task-launch | `rtk proxy python3 -B tests/unified-task-launch.tests.py -v` | Exit 0; 9 tests, helper-caller regression. |
| host-preflight | `rtk proxy python3 -B tests/host-review-preflight.tests.py -v` | Exit 0; 7 tests, T-001 regressions. |
| permissions | `rtk proxy python3 -B tests/quality-nontty-transport.tests.py -v` | Exit 0; 19 tests, T-001 argument/permission regressions and local CLI help. |
| boundary | `rtk proxy bash tests/review-context-boundary.tests.sh` | Exit 0; 32 citation anchors; 3 unittest tests; emitted check summaries 116/0, 84/0, 84/0 (success/failure), including Bash/PowerShell. |

No environment/platform SKIP was reported in these final executions. macOS 27.0.1 arm64; Python 3.14.5, Bash 5.3.9, PowerShell 7.6.2, Node 24.13.0, jq 1.7.1-apple, rtk 0.42.4. No dependency download. Windows execution is separately NOT RUN.

## RED, rollback and iteration record

Baseline launch: 8 tests, exit 0. `coverage-gap-red`: unchanged audit exits 1 because the old reservation-failure test runs no actual validator reserve. The identical audit in `coverage-gap-green` exits 0 after the test change. Preflight mismatch probes are intentionally failing commands; they are not reported as failed production behavior.

Implementation iteration 1: postappend tests succeed, but the conditional-drift fixture raises `FileExistsError` because its new domain directory already exists. Iteration 2: fix that fixture setup and assert specific rejection reasons; all focused tests succeed. Two implementation iterations used (maximum three). No model escalation.

Rollback: applied `rollback.apply_patch` to the disposable staged test, verified exact before bytes/hash, then reran affected baseline suites (8 launch + 9 task-launch tests; exit 0). Applied `reapply.apply_patch`, verified exact final bytes/hash, then reran all eight suites above. `rollback-restored-hash.json`, `reapply-check.json`, before/final images and exact patches retain the evidence. Initial rollback patch syntax was rejected on context matching without writing; corrected hunk headers succeeded. No permission refusal occurred. No ledger, frozen artifact, approval or history was restored/truncated.

## Iteration And Escalation

- **Task Attempt Count**: 2
- **Escalation Prior Tier**: None
- **Escalation Next Tier**: None
- **Escalation Failure Class**: None (no escalation; one fixture setup correction).
- **Escalation Attempt Number**: None
- **Escalation Reason**: None; stayed on the authorized gpt-6-astra/high/strong model.

## Specification differences

None. Requirements, design, acceptance tests, layers, task plan and traceability remain byte-identical. Coverage mapping belongs to this non-frozen verification addendum. `spec_revision` is the exact manifest-bound artifact hash map in `execution-summary.json`. Live HEAD was outside the input boundary; the manifest snapshot is the exact base. Historical authority pre-edit HEAD is identified as historical in the addendum.

## Unresolved items and quality-gate focus

Parent apply: NOT RUN. Independent diff review: NOT RUN. Formal quality gate: NOT RUN. Current-head CI: NOT RUN. Native model permission/launch execution: NOT RUN. Windows: NOT RUN. These belong to parent review/gates and T-004 delivery; no Done state or formal PASS is claimed.

The added driver mocks transport manifest loading, stage prechecks, native/model permission probe, CLI launch and postflight. It executes the real shared launcher logic, conditional resolver, receipt binding and Bash/PowerShell canonical validators. The success fixture has a hash-bound skipped/Draft conditional domain; active-domain/design-system cases run in the separate conditional suite. The six actual append/no-child/re-reservation observations and full fixture ledger hashes are in `fixture-receipts.json`. Reviewer focus: distinguish real canonical append evidence from the mocked native/model transport, confirm the sole test diff and unchanged production inputs, and independently rerun against parent-applied bytes.

## Working notes

No delegation or new agents. Implement-task, implement-tasks and their bound policies/template were read from admitted snapshot copies. The parent supplied successful structure and task-input prechecks; these were not re-executed against undeclared files. A template lookup initially used a nonexistent path and returned no file; the manifest-listed template was then used. No undeclared file content was consumed. Shell calls used rtk proxy and login=false; all edits/scratch/cache stayed beneath output.

## Session handoff

- **Current Status**: Implementation Complete (staged only; owner lifecycle unchanged).
- **Next Action**: Parent verifies before/final hashes, applies the one test change and report/evidence, then performs independent review, quality gate and CI.
- **Unresolved Items**: The NOT RUN items above; no observed local regression remains.

## Outputs

The table below binds every delivered source/evidence file. This report is the table's container and has no self-referential hash; its final digest is recorded separately in output/delivery-index.json. Only listed staged artifacts are the apply payload, not output scratch/cache directories.

| Path | SHA-256 |
|---|---|
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/README.md` | `07c62a9bb01b8ed8fd2d1daf4494294c3ab7970c2e46d63b79bd1274aa71169e` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/T-005.patch` | `6f18baa1a633d6f5e66d581f4604f8a7a1f70e0ba2df91afec9b6a5881d1ba0b` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/baseline-boundary.json` | `5ff144eaa239c1190f5da324ac79e8c7b4db41006a51721353dc50b0a38801ac` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/baseline-boundary.log` | `e172866fec189d1cc1408e7f4de524297514aeda761e7b4b6eddcaeea9003bb4` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/baseline-conditional.json` | `58dee5a04864a1647352a839720870975afaa7a3f66457d229799040ad7d4021` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/baseline-conditional.log` | `6460f9243685b562f7c896aa2f10cc492eb753eb85364fc0eb6eb972a3192057` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/baseline-host-preflight.json` | `314c0870f2caa2a22fe728477c60979246bfd111462de24de0d6b7f6d65a4c95` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/baseline-host-preflight.log` | `e6bf6082b49bafaaa4fa9d95fe33455d702e2d750004d6796bf012ec24669103` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/baseline-launch.json` | `17e5107fd9785e0282cc38619376aa4f2e19ea0c1a29892009313aa8dbeb82c5` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/baseline-launch.log` | `059d00c8b64fa2c922c9720784aaa7a8e581a3b8ba4e5c989d286f48768b203e` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/baseline-permissions.json` | `1f6e36f0f564f0af479df642afa7d61ecd44eba0b00dca6191f8c03bcb17750c` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/baseline-permissions.log` | `5710e5ab27ee8ab75b8da490698ea40363a2d542f0ffaa40d72842ac8e53a011` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/baseline-spec-inputs.json` | `3a07d713f9b25c1f003610e12d2e3a4b5764d0fba8e358aadfbe454505ea2f5a` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/baseline-spec-inputs.log` | `419df51c35f10a809333561f737487f307a4092f3b0a517d3abe5fa36a126487` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/baseline-task-launch.json` | `bd6f2ab2c9fb1d1c2f4df4777b62a32c9a7b809d5a15d49b6bf90443d4e7bdea` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/baseline-task-launch.log` | `989532f92747b90acf6690cd83d4008d0e3434bf3a85a2352fbddc13354fe2b3` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/baseline-task-structured.json` | `e0f5a514919d84c46ef63565ceb1be94b9e5f55103746e61bea549d1b10d08c0` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/baseline-task-structured.log` | `934322042e56616577d07367587ceeedd18804ee4fecbfba77df452c291eb773` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/before/tests/unified-launch-order.tests.py` | `c75879828938c77d7a5ed52a987a739b96365fa7a469c5553bf1297ccc768ee4` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/before-image.json` | `9cdd0aa3107215dafcfa24792fd40f78fd6b6f0834d9683bc362f8fc2953ab50` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/coverage-gap-green.json` | `1b97e8b109feb31b6e33d11b5066b7dffc560aac591c22a6298e441f51c41262` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/coverage-gap-green.log` | `06f4fc7fbdee21b7cd68577864b1a05901e191efddf52eb034ade835a8295b3a` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/coverage-gap-red.json` | `a7b1e330771ff24c9efa82199d74e642bec36871d16571bd9b651da66ddfeb08` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/coverage-gap-red.log` | `502d2ebb122e27e5e8f851f9cfd0598ea2c9586070e83cd0b81bf19419c736eb` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/delivery-shape.json` | `4ef75e149fed7494ba7a5d8f3e3419bf8b6a2e1edda44b2e5d3203b3875dd1c4` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/environment.json` | `fffc01c21d4dc02a50660e18a74b42e5f4f1909fa0f393aee57aa2606c032803` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/environment.log` | `3ad5dd79279c4a177e25619c7efd530f7a0dc1ee26fea8afdbfff04837f6ea39` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/execution-summary.json` | `88694f71c9c54380e215b37f891703471671cbaf3202b4e2dff06c47b279cb58` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/final/unified-launch-order.tests.py` | `612c0b9194c014bf4cb07d8ac13d551c1243b2ade2b268c7c28be6d7e1aba50e` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/final-boundary.json` | `358f34357b1c39e1e0a576a15f7968f5bcab43a41c74711af56a9be289d32761` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/final-boundary.log` | `f59ef1e1c066475aeb592777c326c6e19906caa2598c6e5d07e385c74dd572e3` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/final-conditional.json` | `f186fcffbc2366e5388d3f176de46439583fecb7455e6d5515af4332e74c3010` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/final-conditional.log` | `31a02deaf3c1e4c0bd11a0113c820514d6671a93088f869d5973d40024b14ef0` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/final-host-preflight.json` | `27e336b311747b1c1a40baf8a684dd8c938f59a49293cb31f8a2bda4fdc232e6` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/final-host-preflight.log` | `72137384eadc926a51dd84c3cb4782e177517493508c613179dbb2c39c6c3405` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/final-launch.json` | `dbf7654d51650033e9675657b31ded568d78fffdab51e9413822750f02813b54` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/final-launch.log` | `b84db2107b333c680156ea1a08883802540fcccd9e3b7d25cc09d7c32980c312` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/final-permissions.json` | `44e195f25595f6a7431f2b3b3055287c9dc107d1d86ba0489f8786d1a992745a` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/final-permissions.log` | `afaeea97a93dd0538c7a06fe3ba56de38cf2407f543ba758423bd1ce92584a1f` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/final-source-hash.json` | `9ad407031a97a73e3c3138be0eb484b306fb4d2d743bc05150dc81631ec5b5db` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/final-spec-inputs.json` | `8319a0f62c0e70b0206f57ed68eddf824574112ea1fab2c6b1d8f92a84ce9691` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/final-spec-inputs.log` | `925f170b7cc07692462d6bb02825b316dcea9fe563e513f5456b751ab084b5e9` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/final-task-launch.json` | `7946de1c44eaeb0729e8a7b8d8b2b9a669bef2a9d3132caf0516386c75b9fa14` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/final-task-launch.log` | `2240ff379bb3eef5eadec9b3f75ab4db498c07d562eecf475a0fab13245350c5` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/final-task-structured.json` | `4a692c8d0f3fc86001e20b8b2d1fc7260ebf226160873306d185d8f7fe3b9a87` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/final-task-structured.log` | `3ed99e31dc377de3edb0234b40872925270cd353492f03cd12f493bf2eafb15c` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/fixture-receipts.json` | `b6efe2251669123f1435f9682e8e7019159794c69538b8c36b8585c298da02d0` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/focused-green-iteration1.json` | `246a4df033c8d933e4f61f13b8c1ace214a149c0a71e66a19f2b302f9c8d4c3d` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/focused-green-iteration1.log` | `d8ccf170761902221df5f00040f94a31c841a49d179c425b0220c98270804e25` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/focused-green-iteration2.json` | `50c73d6854a4682e44c2f6e75d29a447126e482e4c5c621aeb17f35075ddbb5f` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/focused-green-iteration2.log` | `15b3f5abd96dc977a93088c2459abbf0a659cbc67ed340e37d77ce39800ed74b` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/harness/environment.py` | `411d909c964597db7f2fa906ec849f4d49b9073feb2a08f79104bb5f8b15fd16` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/harness/finalize_evidence.py` | `9585ad9957bf2b0397708dddef595c9104a569386d908f3aa14241b3256b9678` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/harness/gap_red.py` | `e5ea369eb08927047859c0b931c0d97752a66f36ac52e29cabc9d247afe3d74b` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/harness/observe_receipts.py` | `777542b201efd95f6192156be64f3f067b2f65eebdc24d2588866a01e80005a6` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/harness/preflight_mismatches.py` | `f94d0e5ed5dffe62a5515d7c61f368f97b4d07898e984d42fc8b19240e99c6a0` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/harness/run.py` | `4b0035baf56a4d8233bf52f16a01d82bf501739597807cb97e0bd63f98f02c62` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/input-and-source-hashes.json` | `d7233e40828913a391f672a9b9c480edadecdf7ba1fcb0ddd041463f5903a3e2` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/observed-postappend.json` | `e842fadcc8a340adb969d6369f5ae3a04d47bc5c0b035cd4020ba1b02810d5c8` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/observed-postappend.log` | `5a3165d83715b7a5556892a9af8747b681e5156223f5680635f08240a7fd71d0` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/preflight-before-edit.md` | `b86b378fb23be958b26828888e77dfd22edacda75dd0cad22346caef82f284be` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/preflight-mismatch-corrected-red.json` | `2a5766ce046635c718e7d39696a6ae445aca5c0149e09b4532618246481f57bb` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/preflight-mismatch-corrected-red.log` | `3c957ec2528d8b12f00ff0eb31092cfb59b6cb2b18fac74327a0a117759dd446` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/preflight-mismatch-red.json` | `fae9f6879b2952bf2a732f4feedf0cab5c2ec211fcf1c60875dfd4f8369daa08` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/preflight-mismatch-red.log` | `d59a0674054dd617f342766fc01975b42c3706e0ac8085a8844402b2435ce5fd` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/reapply-check.json` | `83264ddcc99f0a97a7e3554e7e07cea39a8e1bdd2b6d936834c48a4f424e17af` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/reapply.apply_patch` | `e247109f33ec32de1b2032f873de250ffe16dcd4b48b81d0fbb264f9ab5d34f6` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/rollback-restored-hash.json` | `f14d9b5b82cb932ba94a4adb63e20cfa8729810b9fff80e7e8c3e02fd7d7d958` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/rollback-unified-launch-order.json` | `683291a83183d569d3db576428eb2640f869e92c65456e91d5217451232bbfe1` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/rollback-unified-launch-order.log` | `f93642d3988d792cfdd5bb7b167551f0715805bd56ced7d6cbfa3a80c00c715f` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/rollback-unified-task-launch.json` | `38fa1b0f226e966fa725e87a289cdbb9721a9c7186e2e687615b1da067fdbbeb` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/rollback-unified-task-launch.log` | `02f6600cd5bdedece74e2c57c34620486e14a86787eb1c43cfb3b4ea6ef804fb` |
| `specs/shared-review-launch-repair/verification/T-005/attempt-2/rollback.apply_patch` | `a51eb940dece2dc730600bad3a9c6a6c206b5fb65b30a290a0e30ef3bf5dafb4` |
| `tests/unified-launch-order.tests.py` | `612c0b9194c014bf4cb07d8ac13d551c1243b2ade2b268c7c28be6d7e1aba50e` |
