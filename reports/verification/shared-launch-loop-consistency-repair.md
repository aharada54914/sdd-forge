# Shared-launch conditional-input regression repair

## Scope and ownership

- Task: shared-review-launch-repair T-004; approved bounded integration repair.
- Owner: shared-review-launch-integration checkout; base HEAD `9ce19abe90df0cb83e385f96855e4843318a8807`.
- Classification: high-risk, because persisted review-input admission is affected.
- Existing dirty implementation, frozen reviews, approvals and ledger history are retained. This supplement is not a review verdict or task transition.

## Cause and correction

The launcher admitted selected conditional inputs, while downstream workflow and review-precheck consumers still enforced only their static input lists. The consumers now reuse the existing conditional-input resolver and require exact selected paths and current hashes. Conditional-free legacy manifests retain their existing behavior; task-stage input scope is not expanded.

Independent review identified a false conditional classification when a repository parent or feature was named `domain` or `design-system`. Classification now occurs after path normalization and is anchored to the repository-relative conditional root. No general directory allowance was added.

Affected production consumers: `check-workflow-state.sh`, `check-workflow-state.ps1`, `lib/review-precheck-common.sh`, `impl-review-precheck.ps1`, and `task-review-precheck.ps1`. Test preparation changes are in both loop-driver fixtures. The permanent regression is `tests/workflow-conditional-inputs.tests.py`, registered in both run-all entrypoints; the PowerShell dispatcher fixture expectation includes that registration.

## Observed verification

- Conditional-input regression: 9 passed, including valid stage progression, path/hash rejection, conditional-free legacy feature names and parent directory names.
- Bash loop-driver regression: 26 passed, 0 failed.
- Bash loop-consistency regression: 34 passed, 0 failed.
- PowerShell loop-consistency regression: 38 passed, 0 failed.
- Bash and PowerShell downstream precheck suites exited 0 before the final path-classification correction; the 9-case conditional regression exercised that final correction afterward.
- PowerShell Python-dispatch fixture: 4 passed; deliberately failing child commands are part of its assertions.
- Independent diff review: the path-classification Major finding was resolved; reviewer reported no remaining Critical or Major finding. This is not the formal quality evaluation.
- `git diff --check`: exit 0.

## Remaining delivery checks

### Release-fixture cleanup repair

The owner remains at the base HEAD above with 193 dirty/untracked entries before this repair. The release parity suite was unchanged before this correction. Its eight behavioral assertions passed in `/tmp/shared-launch-release.rmp7XZ`, but its EXIT trap failed to remove copied read-only historical snapshot directories. The observed suite exit was 1, not PASS. This repair changes only temporary-fixture cleanup, not release validation, evidence admission or original snapshot permissions. The callers are the POSIX suite inventory/run-all entrypoint and direct suite execution. Required checks: synthetic read-only-directory cleanup with an external symlink, complete release parity rerun, and independent diff review.

The repaired trap passed the synthetic check: copied read-only directories were removed, while the external symlink target remained with its original mode. The complete rerun at `/tmp/shared-launch-release.dgNT3i/release.log` passed all 8 checks and exited 0, including cleanup. Independent diff review found no Critical or Major issue; it confirmed the temporary-root scope, no symlink traversal, and preservation of test failure status. This diff review is not the formal quality verdict.

Additional observed results: facet-manifest parity 329 passed; resolver parity 70 passed; capability-registry parity 22 passed; installed-plugin-drift checks passed. Ownership-digest initially failed because the disposable fixture lacked the required six historical commits; after fetching those commits without changing the fixture tree, all 13 checks passed. Canonical-owner PowerShell repository validation exited 0. These local results do not establish formal review or CI success.

The targeted clean fixture at `/tmp/shared-launch-regressions.McB0JW` contains tracked files and untracked production/test/contracts files, excluding special files and untracked historical evidence. It is suitable for the selected regression suites only, not a complete release snapshot. Its local fixture commit is not a delivery commit.

Full integrated regressions, formal quality evaluation, exact-final-head mandatory CI (including required native Windows execution), merge and post-merge confirmation remain pending. No pending result is counted as PASS. Historical reports and ledger reservations were not rewritten by this repair.

### Special-file comparison and boundary citation repair

The installed-plugin-drift fixture's tree comparison opened FIFO entries as ordinary files, blocking the read-only comparison. The old helper timed out after two seconds against a FIFO. The repair retains special-file identity and mode without reading its stream; regular files, directories and symlinks retain their existing comparisons. Two focused tests passed, and both complete Bash and PowerShell installed-plugin-drift drivers exited 0 in the isolated candidate. Independent diff review found no Critical or Major findings and independently ran both focused tests. Native Windows execution remains pending.

The full owner POSIX run exited 1 with six failed suites (`/tmp/shared-launch-t004-posix-cleanup-final.log`): review-context-boundary, four clean-tree parity checks (facet-manifest, resolver, capability-registry and component-path-ownership), and installed-plugin-drift. The clean-tree checks must run against a committed candidate; their requirements were not weakened. Component-path-ownership subsequently passed 21 checks in the clean isolated fixture. The boundary failure was a stale source-line citation (490 versus 506); only that citation and its test expectation changed. Its owner-path rerun exited 0, including the final group of 84 passed and zero failed checks.

The isolated fixture commit `58d8b31b` includes the special-file helper, its new tests and the two citation edits. Its complete POSIX run exited 1 with 18 failed suites (`/tmp/shared-launch-regressions.McB0JW/full-posix.log`). This fixture excludes untracked historical evidence and preparation helpers and is not a delivery snapshot or formal review input. Its failures remain recorded separately from the corrected-history rerun below.

### Fixture prerequisite correction

That broader run exposed fixture preparation defects: missing Ajv dependencies, omitted evaluation-preparation helpers, an active registry entry whose new feature documents/review records had been omitted, and a synthetic Git root that prevented validation of historical calibration pins. These failures remain recorded; they are not waived and do not establish production defects. After installing the lockfile dependencies without lifecycle scripts, the adversarial review-contract suite passed. The owner-path evaluation-preparation suite passed all 16 cases; that does not prove the incomplete isolated fixture passes.

The dependency audit exited 1 with seven findings (one moderate, five high, one critical). A separate production-only audit identified vulnerable installed versions of `@modelcontextprotocol/sdk` (1.30.0), `proxy-addr` (2.0.7), and `ip-address` (10.4.0). The three MCP packages share those versions; their manifests, lockfiles and server source are unchanged from the integration base. Stdio usage narrows exposure but does not waive the mandatory production audit. Dependency remediation and subsequent audit success are not yet established; the audit record is `/tmp/shared-launch-history.BDfwRH/npm-audit.json`.

A second disposable fixture at `/tmp/shared-launch-history.BDfwRH/repo` preserves the owner's real Git ancestry, overlays the same candidate, and includes the new feature's documents and specification/design/task review records. No historical hashes or verdicts were rewritten. In this fixture:

- Canonical workflow-state validation exited 0.
- ADR workflow history passed 140 checks, failed 0 (`/tmp/shared-launch-history.BDfwRH/adr-history.log`).
- `downstream-review-precheck.tests.sh`, `spec-review-loop.tests.sh`, `impl-layer-review-inputs.tests.sh`, `task-review-precheck.tests.sh`, `impl-review-round2-contract.tests.sh`, and `downstream-review-precheck-parity.tests.sh` each exited 0; individual logs are in `/tmp/shared-launch-history.BDfwRH/`.
- The full POSIX rerun is running against isolated fixture commit `5c0863f9`, with output in `/tmp/shared-launch-history.BDfwRH/full-posix.log`. ADR downstream checks passed 32 cases with no failures or inconclusive results; overall completion is not yet established.
- Candidate staging detected trailing blank lines in two frozen task-review JSON artifacts. They were not rewritten; a clean staged whitespace check is not claimed.

These targeted reruns do not turn the earlier full run into a PASS. Complete-candidate regression, formal quality evaluation, exact-head CI and delivery remain separate pending checks.

### Complete-fixture rerun

The history-preserving fixture's first full POSIX run exited 1: the evaluation-preparation suite could not find its two preparation helpers. The other suites completed without a reported suite failure. Both helpers were copied from the owner into this disposable fixture, and the preparation suite then passed all 16 tests (exit 0). The failed full log is retained at `/tmp/shared-launch-history.BDfwRH/full-posix.log`.

The corrected full POSIX run is writing `/tmp/shared-launch-history.BDfwRH/full-posix-corrected.log`. A separate history-preserving PowerShell fixture at `/tmp/shared-launch-pwsh.nSz20U/repo` includes both helpers, passed the same 16 preparation tests, and is writing `/tmp/shared-launch-pwsh.nSz20U/full-pwsh.log`. Both full runs are still in progress; neither is recorded as PASS. Fixture preparation did not change the owner's source files, task state, review results or ledger. Native Windows, formal evaluation, dependency-audit remediation and exact-head CI remain pending.

The PowerShell full run subsequently exposed a missing `origin/main` reference in its clone: the structural-compatibility suite reported 51 passed and one failed because it could not establish integration ancestry. No acceptance condition was changed. Re-running that suite with its existing `STRUCTURAL_COMPAT_EVIDENCE_REPO` option pointing to the history fixture (whose `origin/main` is `493ff5a84da4ab993dcdceb8cf5d07927ae45db1`) exited 0: 68 passed, zero failed. The named dependency-based skips and their allowlist audit remained active. This focused success does not supersede the failed full-run result; the complete PowerShell run must be repeated with the same explicit ancestry source after the current run finishes.

### Subsequent correction status

The first full PowerShell run finished with exit 1, also failing the cross-runtime handoff suite when its ancestry lookup could not resolve `origin/main`. The fixture reference was restored to the verified `493ff5a84da4ab993dcdceb8cf5d07927ae45db1`; no checks were weakened. The corrected full run is now writing `/tmp/shared-launch-pwsh.nSz20U/full-pwsh-corrected.log`. The corrected POSIX run above is also still running. Neither is a completed PASS.

The production dependency findings were subsequently repaired within the existing package ranges. All three MCP packages passed clean installation, build, typecheck, production audit (zero vulnerabilities), and 471 combined tests. Independent diff review found no blocking issue; details and reproducible bundle hashes are in `shared-launch-dependency-audit-repair.md`. The two running full-suite fixtures predate that dependency repair and must not be presented as full-suite validation of the new dependencies. Development-inclusive audit findings, formal evaluation, native Windows and exact-final-head CI remain separate limitations.

### Corrected POSIX completion

The corrected history-preserving POSIX run completed with exit 0 and `All POSIX regression tests passed.` in `/tmp/shared-launch-history.BDfwRH/full-posix-corrected.log`; its evaluation-preparation suite passed all 16 tests. This proves that fixture's complete POSIX regression, not the later dependency repair or current owner tree. The corrected PowerShell full run remains in progress. Formal evaluation, native Windows, exact-final-head CI and merge are not completed by this result.

### Corrected PowerShell completion

The corrected PowerShell full run subsequently completed with exit 0 and `All PowerShell regression tests passed.` in `/tmp/shared-launch-pwsh.nSz20U/full-pwsh-corrected.log`. Its final suites passed 19 boundary-reference cases, 9 conditional-input cases, 20 transport cases, 17 supplemental-declaration cases and 16 evaluation-preparation cases. Together with the POSIX result, this closes the two fixture full-run failures above without changing their historical records. Both fixtures predate the dependency repair: current-owner exact-head CI, native Windows, formal evaluation and merge remain unverified.
