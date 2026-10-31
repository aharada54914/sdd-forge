# RT002 shared-launch two-stage human batch — 2026-10-04

Status: prepared and fixture-tested; **not applied** to the RT002 owner. This
record is not an SDD review verdict, task status change, or release evidence.

## Fixed batch and change since prior root review

- Batch: `reports/verification/rt002-shared-launch-human-apply-20261004.py`
- Current SHA-256: `5845b1b57c8fc1848386a250e80185725760f239ca670fa824e862d36c731098`
- The earlier root-reviewed `3cb462…` version was changed only at the backup
  parent boundary: `no_follow_directory()` now checks each component of
  `reports/verification` with `lstat()` and requires a real directory before
  `tempfile.mkdtemp()` creates a backup. The fixed patch descriptors, candidate
  hashes, 11 target hashes, apply order, and readback checks were not changed.
  The earlier full digest is not asserted here because only its `3cb462…`
  prefix is available in this handoff.
- Isolated test: `reports/verification/rt002-shared-launch-human-apply.tests.py`
  SHA-256 `bd94ce53ba559e276354b5a082a421516cea0e03b965b84486c0870d7f6c7236`.

## Observed verification

The isolated test uses synthetic files and mock git in temporary directories
under `reports/verification`; it does not invoke real patches or mutate the
11 protected owner targets. The six cases passed with exit 0: two-stage
success; before-byte mismatch with no write; seven-link intermediate chain
mismatch with no write; stage-2 apply failure retaining the backup and no
automatic retry; stage-1 readback mismatch stopping before stage-2 check or
apply; and stage-2 readback mismatch stopping with the original-byte backup
retained. The root owner independently reran the six cases and reported 6/0.

The batch's default read-only precheck on the actual RT002 owner also exited 0:
fixed patch and manifest hashes, 11 before hashes, seven intermediate links,
and stage-1 applicability. It printed that stage-2 applicability and final
hashes require permitted application. This is a precheck, not the second-stage
application or original-path regression result.

## Human-only next operation and remaining evidence

The `--apply` mode has **not** been run. Only the maintainer's permitted human
path may run the following exact command after verifying the owner checkout,
current batch digest, fixed patch digests and unchanged HEAD. A protection
refusal is a stop; do not retry via another executor or copied target.

```sh
cd /Users/jrmag/.codex/worktrees/rt002-bounded-integration/sdd-forge && rtk proxy python3 reports/verification/rt002-shared-launch-human-apply-20261004.py --apply
```

After any permitted application, independently inspect the backup/readback and
run the required original-path boundary and scratch-isolation regressions from
`specs/epic-189-a1-rt002-repair/verification/T-001/provenance-recovery-candidate-20261004/recovery-readiness.md`.
Those regressions, fresh implementation provenance, independent evaluator,
formal gate, current-head CI and merge are not proven by this batch record.
