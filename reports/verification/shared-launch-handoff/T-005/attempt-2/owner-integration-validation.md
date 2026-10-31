# T-005 owner integration and validation diagnostics

This is orchestration evidence, not a formal review or quality verdict. Owner task state, real identity ledger and Git state were not modified by the integration operator. All 75 files in output/delivery-index.json were applied using apply_patch and independently read back with exact indexed hashes. The test before hash was c75879828938c77d7a5ed52a987a739b96365fa7a469c5553bf1297ccc768ee4; after hash is 612c0b9194c014bf4cb07d8ac13d551c1243b2ade2b268c7c28be6d7e1aba50e. Existing non-test destinations were absent or identical. No production code was changed.

## Initial owner execution: failed driver, preserved result

Owner cwd: /Users/jrmag/.codex/worktrees/shared-review-launch-integration/sdd-forge. All commands used rtk proxy, login=false, Python -B. From 2026-10-08T18:39:07Z the driver used Node execFile with inherited default environment but left its stdin pipe open.

- unified-task-launch: 9 tests, exit 0.
- task-structured-output: 13 tests, exit 0.
- quality-nontty-transport: 19 tests, exit 0.
- spec-review-verify-inputs: 2 tests, exit 0.
- host-review-preflight: 7 tests, exit 0. An initial command misspelled its filename review-host-preflight and exited 2 before executing; the corrected exact path succeeded.
- review-conditional-inputs: 16 tests, 4 errors, exit 1 at 18:41:10Z; PowerShell validator calls exceeded their existing 30-second timeouts.
- unified-launch-order: five PowerShell subcase timeouts at the existing 60-second limit; ended by SIGTERM/exit 143 at 18:45:02Z after repeated identical failures. The test wrapper left some child processes orphaned; only positively identified children were terminated, then a process inventory confirmed no target remained.
- review-context-boundary: no suite deadline, stopped after identifying the stalled child; exit 143 at 18:42:20Z. Last output: 32 citation anchors verified; TEST-RCB-001 (bash) verify-after-reserve passes.

The failed run remains failed; later success does not replace it. Tool transcript retains initial failure output and exact argv/PID observations. No complete on-disk raw log of the first driver was produced; this note preserves the observed outcomes, not a claim of complete raw-log capture.

## Controlled diagnosis

The native execution had scoped TMPDIR/TMP/TEMP, HOME, XDG_CACHE_HOME/XDG_CONFIG_HOME/XDG_DATA_HOME, PYTHONDONTWRITEBYTECODE/PYTHONPYCACHEPREFIX and DOTNET_CLI_HOME. A single owner minimal case using all those known-success values still timed out after 20 seconds at 18:44:14Z, so environment variables alone did not explain the failure. A plain pwsh Write-Output probe succeeded.

The same retained spec fixture output/tmp/tmpl9oivsdn was then used with identical env, cwd and argv apart from the script path. Both validators were SHA-256 fa531054e8f95ad350b2c3ace9fe57f68f511cea3b069ca5a932ce7aacc8e072:

- Owner validator: 18:46:10.894–18:46:30.914Z, 20-second deadline, SIGTERM, empty stdout/stderr, ledger unchanged.
- Immutable snapshot validator: 18:46:30.915–18:46:50.939Z, same outcome, ledger unchanged.

Read-only sample of the snapshot pwsh PID 98129 (one second, output to /dev/stdout) observed main thread SystemNative_Read -> __read_nocancel in all 775 samples. No source or configuration was altered for sampling.

At 18:47:52.036–18:47:52.929Z the exact owner validator/fixture/env/argv was executed once with only stdin changed to EOF (Node stdio ignore). It completed exit 0 with REVIEW_CONTEXT_OK, sequence 2 and identity_unique=yes. This isolates the failure to the orchestration driver's open stdin pipe, not validator path/content or fixture acceptance. The comparison serves as the focused driver regression. EOF is the normal noninteractive contract for these argument-driven suites; no fixture input is supplied via stdin. No timeout extension or SKIP was introduced.

## Corrected owner execution

owner-validation-driver.cjs uses inherited default environment and stdio ['ignore', 'pipe', 'pipe']; all three suite commands and their production source paths are unchanged. Product test timeouts remain unchanged. Full final stdout/stderr and timestamps are captured separately in owner-validation-stdin-eof.jsonl after completion.

All three corrected suites completed exit 0. Launch: 9 tests in 22.280s; conditional: 16 tests in 25.468s; boundary: 18:48:20.234–18:50:51.502Z, 3 unittest tests, 32 citation anchors, separate check summaries 116/0, 84/0 and 84/0. Those nested check counts are not a unique-test total. Together with the five successful initial suites, owner Python suites total 75 tests, plus boundary checks. No SKIP reported. Applied 75-file hashes and git diff --check were rechecked successfully. Formal review, quality gate, current-head CI and Done decision remain parent responsibilities.
