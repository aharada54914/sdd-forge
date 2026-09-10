# PR381 component ownership parity registration repair

Checkout: `/Users/jrmag/.local/share/sdd-forge-pr381-recovery-20260908`
Base: `3971c93a5705dc15f86ba56cc62118613e4b19db`
Changed file: `tests/component-path-ownership-parity.tests.sh`
Final SHA256: `186c403c40b1aa6a6c15cafc7bbe1404200de40e04813e1dc642d8e04e58bd5f`

Within the approved actual-runner CI registration-consumer repair, the audit now requires successful `bash run-all.sh --list` and counts exact full-path lines. The existing count of exactly one, all PowerShell/live CI checks, frozen-spec-derived inventory, runtime parity and historical evidence checks are retained. Self-registration uses the same audit. The existing missing-suite mutation now removes the exact entry from actual output rather than a nonexistent source literal. Its positive baseline must pass, fixture creation must succeed, and the disposable runner must successfully emit precisely the intended mutated listing before a rejection is accepted.

TDD diagnostic `pr381-parity-registration-controls-20260909.cjs` extracts the actual audit function. Before repair: 6 passed / 2 failed (real and exact dynamic listings wrongly rejected). After repair: 8 passed / 0 failed; missing, near-match, duplicate, failed-list-with-matching-output, missing PowerShell and missing CI cases rejected. These are standalone diagnostic controls, not inventory-wired new regression suites.

Primary review identified and corrected a false-positive risk in the disposable mutant's own execution; its successful listing and output equality are now prerequisites. Remaining primary Critical findings: 0. This primary review is not independent formal QG.

Verification commands in recovery checkout:
- `rtk proxy bash -n tests/component-path-ownership-parity.tests.sh`: exit 0.
- `rtk proxy bash tests/component-path-ownership-parity.tests.sh`: final 21 passed / 0 failed, exit 0. Log `/tmp/pr381-posix-20260909.WaPopD/component-path-ownership-parity-after-registration-final.log`. Sessions 4056 and 54526 are terminal, not live waits.
- `rtk proxy git diff --check`: exit 0.

Six original baseline failures remain: human-copy-mirror-freshness, deterministic-lane-selfcheck, design-system-contract, design-sync-standing-consent, human-copy-runner-contract, generate-registry-digest. Full baseline rerun, formal review/QG and native mandatory CI remain outstanding. Prior failures are retained, not reclassified as passes.

GitHub recheck: seven open PRs with unchanged heads; no pending CheckRuns. PRs 401, 394, 390, 381 and 371 retain failed checks. No failed CheckRuns on PR400 does not resolve its formal-review findings; PR245's empty failure list does not establish successful Actions. No commit, push, merge, issue closure or Done transition performed.
