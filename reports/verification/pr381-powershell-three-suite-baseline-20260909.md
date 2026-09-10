# PR381 PowerShell registration baseline — 2026-09-09

Checkout: `/Users/jrmag/.local/share/sdd-forge-pr381-recovery-20260908`, base `3971c93a5705dc15f86ba56cc62118613e4b19db`, preserving existing recovery changes. These are new actual macOS PowerShell executions, not native Windows results or formal quality-gate verdicts.

Commands: `rtk proxy pwsh -NoProfile -File tests/<suite>.tests.ps1`.

| Suite | Passed | Failed | Exit | Terminal handle |
|---|---:|---:|---:|---:|
| loop-inventory | 67 | 4 | 1 | 43349 |
| ownership-digest | 12 | 1 | 1 | 38807 |
| facet-manifest-parity | 323 | 6 | 1 | 22045 |

All three handles are terminal; do not poll or restart them. Output was inspected in tool results, not saved as a separate complete raw-log file. Counts do not represent whole-repository coverage.

Failures are confined to registration assertions in these executions:

- `loop-inventory.tests.ps1:346`: TEST-004.1 searches runner source for four loop-suite names. Live CI names all four at workflow lines 369/379/389/399.
- `ownership-digest.tests.ps1:322`: TEST-041 requires an indented literal in runner source. Its five-way wiring count and mutation control must be preserved, not reduced to four.
- `facet-manifest-parity.tests.ps1:377-380`: TEST-033 searches runner source for six suites. Runtime parity, installed-layout discovery, missing-contract canary, staged manifest hash and other checks completed without counted failures.

Read-only `rtk proxy bash tests/run-all.sh --list` exited 0 and listed all eleven named registrations exactly. The runner uses an inventory; source-text absence is not runtime absence. This complements the previously reproduced standing-consent TEST-053 failure, not the genuinely missing CI reachability in deferred TEST-054.

## Source hashes

```text
2b971e92e512c8c97dbb00e9c62a4a55093de42fc704274a22d26b2216e09a54  tests/loop-inventory.tests.ps1
3c8163ec487b8426b13da24e9078f1e8948d428667509ba51ee62a0576962695  tests/ownership-digest.tests.ps1
844e17b954f433452f25a986cac0efd5b51cb50d091212ba180e35b1107bea1e  tests/facet-manifest-parity.tests.ps1
6dc9e4973ed8d7bf18b262e4c9838304b617b1fc9245da2fe76ded6a9fcbe7e7  tests/run-all.sh
fa61cd91946c7f17c440b255d6ba234825766b714f148e5e1bfd0f24a6565901  tests/suite-inventory.posix
```

## Scoped repair to authorize/bind

Include these three PowerShell consumers and `design-sync-standing-consent.tests.ps1` in the current CI remediation ticket scope. Change only the stale Bash-registration predicates to require successful executable `--list` output and case-sensitive exact full-path membership. Preserve all neighboring PowerShell, CI, design, count, order and mutation checks. Add actual-predicate controls for missing, near-match, mis-cased and nonzero listing with correct stdout, plus each retained conjunction. Do not substitute mocks for real full-suite reruns. Do not reopen resolved historical RT-20260808-001 or rewrite its PASS evidence.

The inspected CI-performance design authorizes isolated fixture-copy optimization, not an unlimited reopening of completed feature tests (`ci-performance-research-20260906.md:61-68`). Phase3 T-003 scope likewise does not itself own these four consumer files. Existing broad remediation authorization is not a fabricated task-contract amendment. No test implementation was edited this turn.

Separately, RT-20260909-001 still requires explicit approval to supersede frozen byte-unchanged `needs` with preservation of all existing dependencies plus mandatory POSIX success, followed by formal re-review. This report neither grants that approval nor marks any task Done. No commit, push, merge or issue closure occurred.
