# T-001 current candidate isolated rollback attempt

Result: NOT VERIFIED — candidate application could not write the copied read-only target. This is a diagnostic record, not a formal gate verdict or reservation.

Owner: `/Users/jrmag/.codex/worktrees/shared-review-launch-integration/sdd-forge`
HEAD: `9ce19abe90df0cb83e385f96855e4843318a8807`
Risk: high; T-001 shared launch arguments and permissions. Source, owner ledger, approvals and historical evidence were not edited. `context.json` records the existing owner dirty state.

The old `T-001-git-rollback` disposable was copied to this directory's `checkout` with `rtk proxy cp -R`. All 26 pretask byte hashes were checked against the original `T-001-output/verification/T-001/before-hashes.json`, using the old restored-hash inventory only to select those 26 paths. All matched before and after the attempt. The copied baseline preserves existing dirty candidate inputs; it is not pristine HEAD.

`target-hashes.json` records exact baseline and current-owner SHA-256 values for 21 scoped targets, including the six Python sources, launch guard, T-001 instructions, focused tests, Python dependency/configuration files and FilesOnly build test. Null baseline hashes identify absent additions. `apply.patch` and `restore.patch` preserve the proposed byte changes. No CI workflow change was included because registration/integration changes belong to T-004 and the owner workflow contains mixed changes.

## Application outcome

The first full-file patch submission was rejected as invalid before application (`The first line of the patch must be '*** Begin Patch'`); the generated patch was then reduced to normal context hunks. The actual context-patch application through `apply_patch` failed at its first file:

```text
Failed to write file /Users/jrmag/.codex/worktrees/shared-review-launch-integration/sdd-forge/reports/verification/shared-launch-handoff/T-001-current-rollback/checkout/plugins/sdd-review-loop/scripts/launch-impl-review.py
```

Read-only inspection showed both the old disposable and copied target modes were `-r--r--r--`. No chmod, executor substitution, target deletion/recreation or alternate application was attempted. The candidate was not applied and no reverse patch was run. The filename `check-restored.json` / `restored-26-hashes.json` comes from the verification helper's mode name; these files establish unchanged baseline bytes, not a completed apply/reverse cycle.

## Executed verification

All shell commands used `rtk proxy`, `login=false`.

- `node reports/verification/shared-launch-handoff/T-001-current-rollback/verify.mjs prepare`: 26 baseline inputs matched; 21 target hashes and patch pair recorded.
- `node reports/verification/shared-launch-handoff/T-001-current-rollback/verify.mjs check-restored`: 26 baseline inputs and all 21 target baseline hashes matched; owner target hashes and old disposable target hashes remained unchanged, both before and after baseline tests.
- `node reports/verification/shared-launch-handoff/T-001-current-rollback/verify.mjs tests baseline`: ran the following in the copied checkout, with full logs retained beside this report:

| Command | Result |
|---|---|
| `rtk proxy python3 -B tests/quality-nontty-transport.tests.py` | 18 tests, exit 0 |
| `rtk proxy python3 -B tests/host-review-preflight.tests.py` | 7 tests, exit 0 |
| `rtk proxy python3 -B tests/unified-task-launch.tests.py` | 9 tests, exit 0 |
| `rtk proxy python3 -B tests/unified-launch-order.tests.py` | 8 tests, exit 0 |

Total current baseline regression: 42 passed. Current-candidate regression, lint/typecheck/build, actual reverse application, native/installed-host rollback, remote CI and formal quality evaluation were not run by this attempt. The baseline test success is not candidate rollback proof. Existing old evidence remains intact.

## Subsequent bounded apply/restore verification

The preceding section records the initial attempt, not the final outcome. Subsequently, only copied files in this disposable checkout were made writable; the owner and original disposable were unchanged. The scoped candidate was applied and later reversed using the saved patches. `candidate-results.json` records four focused suites passing (19 + 7 + 9 + 8 = 43 tests) and the FilesOnly build test passing. The conditional-input suite failed seven PowerShell cases: this isolated baseline does not include the T-005 PowerShell validator integration. Those failures are retained in `candidate-review-conditional-inputs.log`; this is not an all-green candidate result. The owning checkout's conditional-input suite passed all 16 cases, but that does not substitute for this isolated result.

After reverse application, `check-restored.json` confirms all 21 target baseline hashes, and `restored-26-hashes.json` confirms the 26 pre-task hashes. Owner and original disposable target hashes remained unchanged. `restored-results.json` and its four logs record 42 baseline tests passing after restoration. This proves the bounded local byte rollback, not installed-host rollback, formal evaluation, remote CI or release. T-005 must verify the conditional-input integration before delivery.
