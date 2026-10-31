# A8 AC-016 bounded candidate — 2026-10-06

Owner: `/Users/jrmag/.codex/worktrees/a8-release-sync-oct01/sdd-forge`.
HEAD: `495c88d67af44530687ecea3ce9fb0a90a336539`.
High-risk evidence/schema change; not a routine correction. Existing dirty work
is retained. No production validator, original specification, approval, status,
review result, reservation, installed plugin or Git history was changed.

## Exact candidate

`a8-ac016-amendment-batch-20261006.py` pins ten originals (nine A8 feature docs
plus ADR 0028), preserves their bytes, and appends dated superseding clauses.
One typed `consumer_inventory` field replaces ambiguous free text; it reuses the
existing five consumers, source map, five semantic cells and two-role JCS signing.
There are no extra native sessions, raw captures, signatures or ledgers. T-005
owns later validator work; T-008 retains its human-attested native evidence boundary.

Batch SHA-256: `fd3f4e8d49298db573f661bf1d987c675211928ae22d9820e2aecc1b195caadf`.
Experiment SHA-256: `9a9698e7ca6e738cb1d49eee6f51e97b96d5dc4eea34e04ff8e57b62a4d7caea`.
Generated patch SHA-256: `e3406e66713f549b4b0f51ea7a164b3e27c5f19bf2c60677bc6a5bbb76d8efa0`.
Candidate tree: `/var/folders/7z/hjmz6jdj4wb40srf64sl368w0000gn/T/a8-ac016-candidate-eipwlc7m`.

## Executed evidence

- `python3 -B reports/verification/a8-ac016-amendment-batch-20261006.py --emit-candidates`: exit 0; ten current pins matched; originals unchanged.
- `git apply --check <candidate tree>/candidate.patch`: exit 0.
- `python3 -B reports/verification/a8-ac016-minimal-contract-tests-20261006.py`: seven tests passed, 0.409 seconds. It reproduced the original validator's discharge without inventory (RED), verified the five actual Git source blobs, tested five candidate cells with the existing signature implementation, rejected 90 inventory/source mutations, checked signature tampering/re-signing, SKIP inventory nullness, and append-only original-byte preservation. An isolated copy injected failure on the second target write: the first copy remained amended, later copies remained original, all ten backup copies matched their originals, and the helper warned of partial application without restoring over other changes.

The candidate helper now follows the existing A8 human-apply pattern: verify all
target pins, verify every backup readback, recheck all targets before the first
write, verify every final readback, and distinguish a pre-write stop from possible
partial application. A write refusal or interruption is a stop; it is not a
reason to change executor or retry without inspecting all targets. This helper
does not make ten file writes atomic or replace the formal frozen-input
transition and protected-application requirements.

These are candidate-contract experiments, NOT a production v2 validator test.
The SKIP experiment checks only the new field, not all production SKIP conditions.
No genuine live records were signed; fixture keys and fixture records only.
Earlier per-consumer separate-file/duplicate-path experiments are superseded and
are not new acceptance requirements.

## Next safe operation

Parent reviews the exact append-only patch and coordinates the required scoped
human contract decision and sanctioned application route. The prepared helper
command (NOT executed here) is:

```sh
rtk proxy python3 -B /Users/jrmag/.codex/worktrees/a8-release-sync-oct01/sdd-forge/reports/verification/a8-ac016-amendment-batch-20261006.py --apply-human
```

It verifies owner HEAD and all ten original hashes, saves and verifies every
backup before any target write, rechecks all pins, applies each append, and reads
back exact candidate bytes. On failure it preserves backups and warns that the
application may be partial; it never automatically restores over another edit.
Stop on any mismatch; never reuse an older applied batch against changed files.
After adoption, use normal precheck and independently review changed inputs;
coordinate a new identity with the owner only then. No reservation is authorized
by this report. Implementation, production regressions, formal gates, native
verification, CI and merge remain pending.
