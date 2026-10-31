# T-004 CI dependency preparation

Observed: 2026-10-10
Owner: shared-review-launch-integration/sdd-forge
HEAD: 9ce19abe90df0cb83e385f96855e4843318a8807
Scope: read-only preparation; no task transition, implementation, reservation or CI execution.

The `posix-regression` job runs `tests/task-structured-output.tests.py`
(`.github/workflows/test.yml:64`). Its schema equivalence test invokes Node and
requires `./mcp/ci-mcp/node_modules/ajv`
(`tests/task-structured-output.tests.py:177-178`). This job has no dependency
installation. The existing `npm ci --prefix mcp/ci-mcp --ignore-scripts` is in a
different job, `posix-unwired-sharded` (`.github/workflows/test.yml:95-108`), and
cannot supply this job's checkout. This is a static dependency finding, not an
observed hosted CI failure.

After T-003 completes and T-004 is admitted, reuse the existing locked npm
installation in the consuming job before the structured-output suite. Preserve
the real Ajv assertions and all required checks. Verify the dependency and test
in an isolated clean checkout, then confirm the exact final head in CI. Do not
reuse a developer checkout's installed node_modules as CI proof.

No workflow or test has been changed by this preparation. T-004 remains Planned
and depends on completion of T-003. The separate T-003 manifest path contract
blocker remains recorded in preparation-blocker.md.
