# Genuine GitHub Actions PR-write and lifecycle observations

## Actual weekly recovery

Subsequent real weekly run
[40426096944](https://github.com/aharada54914/sdd-forge/actions/runs/40426096944)
at `4ac41d51` completed successfully in both `improve` and `finalize-recovery`.
The workflow itself verified completion and closed Issue #620 at
2026-10-27T00:30:26Z. `weekly-recovered.json` retains the actual run/job and Issue
state snapshot. The previous failed audit remains historical. This is recovery
of that candidate-branch execution, not proof that unmerged main or the separate
configured PAT has changed. The default-token PR-write proof below is distinct.

The owner-browser repair enabled repository Actions PR creation/approval while
preserving the existing read-only default permissions. A dedicated verification
branch (`verify/issue620-factory-adapter-20261027`, source `a6b082cc`) then used
the ordinary native `github.token` with job-scoped `pull-requests: write`.
Run [40424313355](https://github.com/aharada54914/sdd-forge/actions/runs/40424313355)
actually created Draft [PR #655](https://github.com/aharada54914/sdd-forge/pull/655)
as `github-actions[bot]`, reusing `auto/improve-20261026` at the pinned audited
source `ffa9edd8`. It compared the exact three lockfile paths before creation;
it did not merge, broaden default permissions or access secret token values.
This proves default-workflow-token PR writing after repair. It does not prove
that the separate configured session PAT has been repaired.

The two native runner jobs completed on attempt 1. Only logical job
`lifecycle (1)` was rerun: original job `121926160055`, attempt-2 job
`121926991947`, attempt-3 job `121928013214`. Cancellation was sent when the
API reported the child step running. Attempt 2 is terminal `cancelled` and
attempt 3 is terminal `success`, following an actual failed-job restart.
Unchanged/copied jobs are not counted as fresh executions or new PR creation.

Importantly, a zero-exit child artifact exists for the cancelled attempt too.
The observation cannot distinguish cancellation delivery delay from stale API
metadata, and it does not prove child-tree termination during that attempt.
It demonstrates why an artifact's exit code or mere existence is insufficient.
`replay.py` uses the existing CI origin reconciler over original native job
snapshots. It rejects the cancelled artifact both before and after restart,
and admits only the matching successful attempt-3 observation. No second gate
or imported PASS mechanism was added.

The actual artifact archives and decoded records, job/API snapshots, cancel
result, exact workflow and replay helper digest are retained. Run/attempt/head
bindings are original. These are development observations, not signed factory
work-order authority. GitHub Actions is now an observed external candidate for
bounded stateless jobs and fresh retries. Full #623 suitability still needs
work-order lease/deduplication, multi-resource reservation, human queue admission
and 2/4/8 comparisons. Native restart is not in-process session continuation.
No persistent dispatcher or unattended production executor was introduced.

The narrower dependency PR's first source subsequently failed CI because its
lockfile repair had not rebuilt the shipped bundles. The correction reuses
this same branch and PR, rebuilds all three bundles from their locked inputs,
and verifies type checks, 498 tests and zero audit findings. The earlier failed
run is retained; these local checks do not substitute for final-source CI.
