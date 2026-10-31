# T-002 independent executable verification follow-up

Date: 2026-10-10
Feature: shared-review-launch-repair
Task: T-002
Owning checkout: /Users/jrmag/.codex/worktrees/shared-review-launch-integration/sdd-forge
Baseline source commit: 9ce19abe90df0cb83e385f96855e4843318a8807

This is non-frozen supplemental verification evidence, not a canonical implementation report, identity reservation, historical RED record, or quality-gate verdict. Parent owns task status, ledger and formal review. Risk/preflight and before-hash inventory remain in `implementation-inspection-20261010.md`. No source changes were made by this follow-up.

## Executed commands and results

Commands ran with `login=false` through `rtk proxy` from the owning checkout unless an evidence row specifies the disposable checkout.

- `rtk proxy python3 specs/shared-review-launch-repair/verification/T-002/verify-disposable.py`: retained three runs. First fixture failed because the registry schema was missing; second failed because the minimal nested copy inherited inappropriate parent Git-path behavior. Third fixture uses `git clone --shared --no-checkout` for correct history lookup and retained output under `current-restoration-z04ertpw/`. It completed the exact-byte restoration and before/after regressions, then exited 1 at downstream parity because unrelated registry-listed specification directories were absent. These are present-time fixture setup failures, not authentic historical implementation RED.
- In `current-restoration-z04ertpw/checkout`, `rtk proxy pwsh -NoProfile -File tests/review-hash-normalization.tests.ps1`: exit 0 before mutation and after restoration.
- In that checkout, `rtk proxy python3 tests/traceability-freeze-contract.tests.py`: exit 0, two tests before mutation and two tests after restoration.
- In that checkout, `rtk proxy bash tests/downstream-review-precheck-parity.tests.sh`: exit 1, registry-dangling-entry diagnostics caused by absent unrelated spec directories. This fixture result is not promoted to success. The prior owning-checkout run exited 0, as separately recorded in the inspection record.
- `rtk proxy python3 specs/shared-review-launch-repair/verification/T-002/finish-independent-checks.py`: exit 0. It invokes the exact unreadable-file command persisted in `independent-checks.json`, compares the old recipe against both `git show 9ce19abe90df0cb83e385f96855e4843318a8807:<precheck-path>` outputs, and rechecks owner and restored hashes.

## Actual observations

Eight current dirty candidate files were copied and individually SHA-256 hashed; every disposable copy was then changed with a sentinel, verified different, restored from its byte backup, and verified equal. Tests above passed before and after restoration. `before-hashes.json`, `mutated-hashes.json`, `restored-hashes.json` and `before/` preserve the evidence. This validates restoration of the current candidate, not rollback of an installed baseline or reconstruction of the original pre-fix state.

The unreadable fixture is an existing regular file. A .NET FileStream with `FileShare.None` caused both `Get-BaselineReviewedHash` and `Get-ReviewedHash` to throw `System.IO.IOException`. After releasing the stream, both returned identical hashes; file bytes were unchanged. No permission changes were needed. Exact stdout is `unreadable-equivalence.log`.

The test's baseline recipe, with only its function name normalized, exactly matches the old function in both implementation-policy and task prechecks at the stated commit. Current parity testing therefore exercises a source-proven pre-extraction recipe, including existing invalid path cases and the additional real read denial. It does not establish installed-host baseline trust.

All eight owning candidate hashes still match the saved before-hashes after execution. Outputs are limited to this T-002 verification directory. No source/task/ledger edits, reservations, installs, commits, pushes, merges or formal status transitions were performed.

## Remaining acceptance boundary

Authentic pre-fix T-002 RED evidence is still not located; none of these present-time checks is relabeled as that evidence. T-001's separate substitute authorization is not used. Native/installed rollback, CI for a final head, implementation contract/snapshot admission, and independent quality-gate verification are not claimed here. Parent must resolve the applicable acceptance requirements and provenance through the approved workflow; this document does not declare Implementation Complete, Done, or formal PASS.

## Evidence locations

- `current-restoration-z04ertpw/results.json`: command/cwd/exit-code records for the five before/after suite invocations.
- `current-restoration-z04ertpw/independent-checks.json`: unreadable command, baseline recipe identity, owner/readback checks and explicit claim exclusions.
- `current-restoration-z04ertpw/*-hashes.json`, `before/`, suite logs and `unreadable-equivalence.log`: retained concrete observations.
- `current-restoration-m1fx2ig8/` and `current-restoration-94l7hf0y/`: retained setup-failure outputs.
- `verify-disposable.py`, `unreadable-equivalence.ps1`, `finish-independent-checks.py`: scoped verification drivers; the original harness's downstream fixture limitation remains explicit.
