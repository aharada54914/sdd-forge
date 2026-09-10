# PR381 ownership registration verification — 2026-09-09

Checkout: `/Users/jrmag/.local/share/sdd-forge-pr381-recovery-20260908`
Base: `3971c93a5705dc15f86ba56cc62118613e4b19db`

Only the Bash registration predicate in `tests/ownership-digest.tests.sh` changed: successful actual `run-all.sh --list` plus exact full-line matching replaces inspection of a literal in the runner source. All four sibling PowerShell, live CI and design-inventory predicates, the five-registration requirement and the existing mutation remain intact.

Source SHA256: `9482d8bbdaf561a60834732301ed884d3920ae7217cab7c6619ef63b75485a66`

Verification:
- Full suite: 13 passed / 0 failed, exit 0; session 86563 terminal. Log: `/tmp/pr381-posix-20260909.WaPopD/ownership-digest-after-registration.log`.
- Actual assertion-block controls: 8 passed / 0 failed. Real listing and exact listing accepted; missing member, near match, failed listing with matching output, missing PowerShell registration, missing CI registration and missing design inventory rejected. These are standalone diagnostic controls, not new inventory-wired regression tests or independent whole-repository mutations.
- Existing `T003_ONLY=TEST-041 T003_MUTATE_ASSERTION=TEST-041` mutation: 0 passed / 1 failed, exit 1 as required. Removing one observed registration is still rejected.
- Bash syntax and recovery checkout `git diff --check`: exit 0.

Primary diff review: all five wiring requirements remain enforced; no product verifier, workflow, frozen specification or verdict was edited. This is not a formal independent quality-gate verdict.

Seven original baseline failures remain unresolved: human-copy-mirror-freshness, deterministic-lane-selfcheck, design-system-contract, design-sync-standing-consent, human-copy-runner-contract, generate-registry-digest, component-path-ownership-parity. The original baseline FAIL log is retained; the complete baseline has not yet been rerun. Formal independent review/QG and mandatory native CI remain pending. No commit, push, merge, issue closure or task Done transition occurred.
