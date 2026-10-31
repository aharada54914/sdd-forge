# T-005 attempt 3 current revalidation evidence

Run ID: T-005-01a11d02-3d61-7681-b3e6-3815b8ac79bc
Task Attempt Count: 3
Input manifest: `handoffs/shared-review-launch-repair-T-005-attempt-3/manifest.json`, SHA-256 `a20263eec7b1732c48c837b38e649083c87ab3d2581fd48cc01c5e91006648bd`

This is a fresh bounded execution of existing admitted bytes. It is BLOCKED after a real execution refusal, not a formal review verdict or task-state transition. No production source or tests were edited. All 607 admitted files were copied byte-for-byte into output/work; immutable snapshot modes were retained by copy2.

## Current results

All commands ran from output/work through rtk proxy, with login=false on the outer shell and stdin=DEVNULL for the child. `run.py` records commands, timestamps, environment overrides, separate raw stdout/stderr and child exit status for completed processes. A successful harness exit does not imply a successful child test.

| Command | Current observation |
|---|---|
| `rtk proxy python3 -B tests/unified-task-launch.tests.py -v` | Exit 0; 9 tests, OK. |
| `rtk proxy python3 -B tests/task-structured-output.tests.py -v` | Exit 0; 13 tests, OK. |
| `rtk proxy python3 -B tests/quality-nontty-transport.tests.py -v` | Exit 0; 19 tests, OK; includes real installed Claude CLI help, without a model session. |
| `rtk proxy python3 -B tests/spec-review-verify-inputs.tests.py -v` | Exit 1; 2 tests run, 4 failing Bash subtests. Direct invocation of review-contract-validate.sh returned Permission denied. |
| `rtk proxy python3 -B tests/host-review-preflight.tests.py -v` | Exit 0; 7 tests, OK. |
| `rtk proxy python3 -B tests/unified-launch-order.tests.py -v` | Started, then interrupted on refusal; outer exit 130, child result unknown. |
| `rtk proxy python3 -B tests/review-conditional-inputs.tests.py -v` | Started, then interrupted on refusal; outer exit 130, child result unknown. |
| `rtk proxy bash tests/review-context-boundary.tests.sh` | Exit 1; 32 anchors verified, then TEST-RCB-001 could not directly execute validate-review-context-set.sh (Permission denied). Later boundary regressions did not execute. |

The request labels task-structured-bindings, unified-quality-launch and host-launch-profile are not literal admitted filenames. The corresponding existing evidence commands above use task-structured-output, quality-nontty-transport and host-review-preflight. No absent test file was created or read; no additional coverage is claimed from the naming correspondence.

## Refusal and incomplete evidence

Both refused files have mode 0444 in snapshot and work. Raw errors are preserved in the relevant stderr logs. The first observed refusal was returned by the boundary suite. Stop signals were then sent to the three outstanding exec sessions: spec-review-verify-inputs had already finished with child exit 1; the other two returned outer exit 130. Their runner-buffered streams were not persisted before interruption, so interrupted-executions.json records only tool-observed facts. No counts, success or child completion identity were reconstructed.

No chmod or alternate-executor retry was performed. There is no new RED-to-GREEN cycle: current failures are execution refusals, not a manufactured pre-implementation RED. No rollback was performed because this run changes no production or test source.

## Provenance boundary

Historical input: `reports/verification/shared-launch-handoff/T-005/attempt-2/output/work/reports/implementation/shared-review-launch-repair/T-005.md`, SHA-256 `33e2cc787f23b0e06af18a2e83bee5c51c309182623e9d97e33a25b6b05d7216`. Its RED, implementation, rollback, eight-suite success and detailed attempt-2 evidence are historical claims. The attempt-2 raw evidence files are not separately admitted; they were not accessed or rerun by attribution. The current admitted unified-launch-order source hash is `612c0b9194c014bf4cb07d8ac13d551c1243b2ade2b268c7c28be6d7e1aba50e`, matching the historical report's final source digest; this does not prove the owner tree's current HEAD.

input-hashes-before.json, copied-input-hashes.json and input-hashes-after.json record current manifest/snapshot/work checks. Staged unchanged inputs, dependencies, fixtures and caches are not an apply payload. Deliver only the current implementation report and this attempt-3 evidence directory, subject to parent review.

Native environment observed: macOS 27.0.1 arm64; Python 3.14.5; Bash 5.3.9; PowerShell 7.6.2; Node v24.13.0; jq 1.7.1-apple; rtk 0.42.4; Claude Code 2.1.292. Version logs are current. Native model launch/permission proof, Windows execution, independent review, quality gate and CI: NOT RUN. No native launcher was invoked and no native run identity was inferred; the report identity is the caller-supplied manifest identity.

Model route: strong/openai/gpt-6-astra/high, as supplied. USD 48.22 is the manifest's HISTORICAL API-equivalent estimate at 2026-09-28T05:01:53Z, based on a historical Sol/high preflight workload; it is not current measured cost, billing, or a cost ceiling.
