# PR381 compound registration — 2026-09-09

Checkout: `/Users/jrmag/.local/share/sdd-forge-pr381-recovery-20260908`, preserved recovery base `3971c93a5705dc15f86ba56cc62118613e4b19db`.

Scope: approved CI registration repair. Changed only POSIX membership in component-path-resolver, component-path-diff-basis and check-component-coverage. Require a successful actual runner `--list` and exact full-path match, while retaining each original PowerShell conjunct unchanged. Historical baseline FAIL is retained.

Primary review: Critical 0. Complete three-file diff inspected; no product/CI/spec changes or sibling assertion removal. This is not formal independent SDD QG.

Actual-block diagnostic extended with an isolated PowerShell-missing condition, leaving files untouched. All eighteen controls passed: real runner, exact path, omission, near-match, failed listing despite correct stdout, and missing PowerShell registration. Existing default three-suite diagnostic also reran: fifteen passed, zero failed. This diagnostic does not claim inventory-wired regression coverage.

Full suites (session 71252 terminal exit 0):

- component-path-resolver: 73 passed, 0 failed.
- component-path-diff-basis: 18 passed, 0 failed.
- check-component-coverage: 46 passed, 0 failed.

Each ran after successful `bash -n`. Full output retained at `/tmp/pr381-posix-20260909.WaPopD/<suite>-after-compound-registration.log`. Recovery `git diff --check` passed.

Source SHA256:

- component-path-resolver: a45feff95d674f9030ad00a8ac4e92a778f32831b0d83ad17ae4a129dd739f60
- component-path-diff-basis: 9fdcc8a643af645b745cc7225bd05d1d1ec5df3d60aa76b1302375f1dd674e55
- check-component-coverage: 8a9cef0ec153b4258b0c4e51e7e79b3811d87de698f2f077158becb4fbac4835

Sixteen original baseline failing suites remain unresolved. No fresh whole-repository PASS, formal QG, commit/push/merge or issue closure. Current GitHub query still has seven open PRs and no pending CheckRuns; failed checks remain on PR401/394/390/381/371. No failed check on PR400 does not resolve its formal review. PR245's empty Actions set is not success evidence.

Next: remaining compound/ordering/uniqueness registration consumers, then mirror freshness, deterministic candidate job-set and CI reachability failures; preserve all mandatory gates.
