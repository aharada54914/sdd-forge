# Issue #311 CI wiring candidate

## Scope

The current `origin/main` already contains the evaluator scratch-root
validator and `tests/issue311-scratch-isolation.tests.py`. The missing piece is
execution wiring: the Python regression is not part of `tests/run-all.sh` and
is not an explicit step in the Ubuntu POSIX regression job.

## Candidate

`issue311-ci-wiring-candidate-20260924.patch` adds exactly two executions:

- an independent Python invocation in `tests/run-all.sh`, with a skip when
  either required runtime is unavailable;
- an explicit Ubuntu POSIX workflow step using `$GITHUB_WORKSPACE`.

The Bash inventory is unchanged because it only accepts `.tests.sh` suites.

## Verification

- `git apply --check` against clean `origin/main`: PASS
- candidate `run-all.sh`: `bash -n`: PASS
- `tests/issue311-scratch-isolation.tests.py --repo <clean-origin-main>`:
  `PASS: 28; FAIL: 0` (14 Bash + 14 PowerShell)
- capability registry parity: Bash `22/22`, PowerShell `22/22`

Protected runner/workflow files were not modified by the agent. Human apply is
available through `issue311-ci-wiring-human-apply-20260924.sh`; set
`ISSUE311_REPO` to a clean `origin/main` worktree and
`ISSUE311_SOURCE_ROOT` to the checkout containing this report when they differ.

## Remaining acceptance work

The issue still requires five genuine isolated quality-gate evaluator runs
with auditable `scratch_root` evidence. The synthetic 28-case suite does not
count toward those runs.
