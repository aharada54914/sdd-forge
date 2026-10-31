# T-005 isolated implementation evidence

Run ID: T-005-01a11cbb-3dd3-7d92-9a8f-68016108fe85
Task Attempt Count: 2
Native session_id / agent_instance_id: 01a11cbb-3dd3-7d92-9a8f-68016108fe85
Model: gpt-6-astra / high / strong

This addendum records local fixture execution, not a quality-gate verdict. No task lifecycle, owner source, real identity ledger, approval or historical evidence was modified. Attempt 1 was environment-only and is not an implementation iteration.

## Inputs and exact change

Manifest: `reports/verification/shared-launch-handoff/T-005/attempt-2/manifest.json`, SHA-256 `347c102120352a273c7f83cb1785824ed1cd53837bf451c958a76b9cbcf09218`.

`input-and-source-hashes.json` records all 606 admitted paths and their snapshot/staged hashes. Every snapshot hash still matches the manifest. The only changed admitted file is `tests/unified-launch-order.tests.py`. All production scripts and frozen artifacts retain their original bytes. Staged shell scripts were made executable locally to run baseline suites; those mode-only setup copies are excluded from the delivery tree.

| Task-owned path | Before SHA-256 | Final SHA-256 |
|---|---|---|
| tests/unified-launch-order.tests.py | c75879828938c77d7a5ed52a987a739b96365fa7a469c5553bf1297ccc768ee4 | 612c0b9194c014bf4cb07d8ac13d551c1243b2ade2b268c7c28be6d7e1aba50e |

The immutable manifest digest is the exact task base. Live Git HEAD was not admitted and was not read. `authority.md:6` names historical pre-edit HEAD `9ce19abe90df0cb83e385f96855e4843318a8807`; this is not asserted to be the current handoff HEAD. `spec_revision` is the manifest-bound requirements/design/acceptance/tasks hash set in `input-and-source-hashes.json`, not a guessed Git revision.

## Independently checked coverage gap

Before change, `tests/unified-launch-order.tests.py:77-81,103-109,126-127,210-211` created a disconnected `root/identity-ledger.json`, threw the mock reservation error before any append, and changed the second preview for `failure='receipt'`. Its 8 tests succeeded, but none executed the canonical validator for the purported reservation failure. `coverage-gap-red.log` records the actual audit failure: zero real reserve calls.

Production already compares the returned reservation receipt with the preview before generating the prompt or invoking the child (`plugins/sdd-review-loop/scripts/launch-impl-review.py:368-379`). Canonical validators reject re-reservation of an already persisted identity (Bash validator at `validate-review-context-set.sh:648`; exercised in both runtimes). The defect is missing regression coverage, not a demonstrated production defect.

The updated helper builds a real invocation/v2 and canonical **fixture** `reports/review-context/identity-ledger.json`. Its runtime adapter executes the admitted Bash or PowerShell validator for both previews and reservation, and uses real `receipt_control`. Only after successful append does it alter the returned receipt. No validator code or production ordering changed.

## AC-002 coverage against actual behavior

| Acceptance row | Existing evidence / gap | Final evidence and assertion |
|---|---|---|
| TEST-004 | Mock success checked order/proposal but could not prove a ledger append. | `test_canonical_admission_and_preappend_failures`, authorized spec fixture in both runtimes: complete required set, real conditional resolver with hash-bound Draft context map, raw invocation pin, ordered proof and real receipt validation; exactly one automatic reserve and one mock child event. Actual ledger grows from 1 to 2. |
| TEST-005a | Missing required set rejected, disconnected ledger only. | `missing-required`: omitted required conditional path rejects specifically as missing/stale; actual canonical fixture ledger remains byte-identical, zero reserve/child. Existing stage-specific set tests retained. |
| TEST-005b | Dependency drift mocked; no real canonical input-digest mismatch in this driver. | `changed-digest`: actual validator rejects requirements digest, exact hash-mismatch assertion, canonical fixture ledger byte-identical, zero reserve/child. |
| TEST-005c | Case-alias path rejection existed. | `case-alias`: shared path checker rejects exact case alias, canonical fixture ledger byte-identical, zero reserve/child. |
| TEST-005d | Symlink rejection existed. | `symlink-path`: shared path checker rejects symbolic link, canonical fixture ledger byte-identical, zero reserve/child. |
| TEST-005e | Out-of-scope/unsafe paths rejected. | `extra-path`: actual regular `bin` outside role set rejects; canonical fixture ledger byte-identical, zero reserve/child. Existing absolute/traversal tests retained. |
| TEST-005f | Native proof hash mismatch existed; external raw pin was not passed by this helper. | `raw-pin`: wrong external raw invocation hash rejects at entry; canonical fixture ledger byte-identical, zero reserve/child. Existing source-read/proof checks retained. |
| TEST-005g | `receipt` changed preview-before-reserve only. | `receipt`: both real previews succeed, second returned receipt is altered; specific admission-changed error, canonical fixture ledger byte-identical, zero reserve/child. |
| TEST-005h | Mock reservation exception occurred before append; not coverage of consumed identity. | `test_reservation_failure_never_launches`: spec/impl/task × Bash/PowerShell, actual append succeeds, changed returned receipt triggers exact no-retry error. Original record unchanged, exactly one new bound record retained, no prompt or child. Explicit subsequent adversarial validator call rejects same identity and leaves appended ledger bytes unchanged. |

Additional `proof-order` and `conditional-presence` negatives reject reversed proof paths and changed conditional input after the native-proof stub. Existing conditional-input suite exercises active v1/v2 domains, aggregate selection and design-system dependencies with real validators in both runtimes; the new success fixture's domain selection is deliberately skipped/Draft, not claimed as an active-domain end-to-end launch.

`fixture-receipts.json` retains exact validator argv, stdout/stderr, return codes, full synthetic ledger records and before/after hashes for all six postappend cases. Each has two successful previews (unchanged ledger), one successful automatic reserve (1→2 records), then one explicit test-only re-reservation rejection (2→2, bytes unchanged). The latter is an adversarial test operation, not an automatic launcher retry.

## Preflight, RED and iterations

`preflight-before-edit.md` is the implementation report captured before editing the test. Its table maps persisted evidence fields to sibling contracts and executed failing mismatch cases. `preflight-mismatch-corrected-red` exits 1 with three intended exceptions (raw pin, admitted hash, receipt record hash). These demonstrate existing rejection behavior. The earlier probe log is preserved; its empty-input receipt case failed too early and is not counted as receipt-mismatch evidence.

The unchanged `gap_red.py` audit fails against baseline and succeeds against the final test. Initial implementation iteration 1 passed all six postappend cases but hit `FileExistsError` when a conditional-drift fixture recreated its existing directory. Iteration 2 uses `mkdir(exist_ok=True)` and verifies rejection reasons; all focused tests succeed. Two implementation iterations, within the maximum of three. No production fix was needed.

## Disposable rollback and reapply

1. Before edit, copied the task-owned bytes to `before/tests/unified-launch-order.tests.py`, hashed in `before-image.json`. Saved final bytes under `final/` and the minimal unified diff in `T-005.patch`.
2. Applied the recorded `rollback.apply_patch` using `apply_patch` to **output/work only**. First attempt used unsupported numbered hunk headings and failed context matching without changing bytes; using the same hunk content with `@@` headings succeeded. This was a patch-format error, not a permission refusal.
3. Compared restored bytes directly with the before image and required SHA-256 `c75879828938c77d7a5ed52a987a739b96365fa7a469c5553bf1297ccc768ee4`. `rollback-restored-hash.json` records the result.
4. Ran `rollback-unified-launch-order` (8 tests) and `rollback-unified-task-launch` (9 tests), both exit 0.
5. Applied `reapply.apply_patch` with `apply_patch`; verified byte equality with saved final bytes and SHA-256 `612c0b9194c014bf4cb07d8ac13d551c1243b2ade2b268c7c28be6d7e1aba50e` in `reapply-check.json`. Reran all eight focused/baseline suites under `final-*`.

No ledger, approval, reservation, historical review, frozen specification or production code was restored or truncated. This is a disposable task-scoped test rollback, not installed-host rollback evidence.

## Commands and reproduction

Every `*.log` has a paired JSON with exact argv, cwd, start/end time, exit code and scoped environment. All top-level shell calls used `login=false` and `rtk proxy`. From this attempt's output directory the common form was:

```text
rtk proxy python3 -B scratch/run.py <label> rtk proxy python3 -B tests/<suite>.tests.py -v
rtk proxy python3 -B scratch/run.py <label> rtk proxy bash tests/review-context-boundary.tests.sh
```

The runner executes in output/work and pins HOME/XDG/Python/.NET caches beneath output; TMPDIR/TMP/TEMP remain the native policy values at output/tmp. `harness/` archives the executed scratch scripts. To replay in a fresh disposable output layout, stage the exact manifest files in work, place those scripts in sibling scratch, restore the recorded environment, and apply `T-005.patch`. No dependencies were downloaded; AJV 8.20.0 and its dependency files came from admitted inputs.

Environment: macOS 27.0.1 arm64, Python 3.14.5, Bash 5.3.9, PowerShell 7.6.2, Node 24.13.0, jq 1.7.1-apple, rtk 0.42.4. `environment.log` gives exact version commands/output.

## Limits and handoff

The new tests use real canonical validators and ledger files; manifest transport, stage prechecks, CLI/model permission probe, child launch and postflight remain mocked in this orchestration driver. Separate baseline suites exercise actual spec prechecks, conditional validators, guard logic, structured schemas and local CLI help. These results do not prove a native model permission session or formal reviewer/evaluator delivery.

Independent diff review, quality gate, current-head CI, Windows execution, owner apply and installed-host/native model launch: **NOT RUN**. Parent owns apply and independent review/quality gates/CI. T-004 owns integrated delivery evidence. No Done state or formal PASS is claimed. No newly reachable production SKIP branch was introduced.
