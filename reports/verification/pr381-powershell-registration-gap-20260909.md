# PR381 PowerShell registration gap — 2026-09-09

Checkout: `/Users/jrmag/.local/share/sdd-forge-pr381-recovery-20260908`, base `3971c93a5705dc15f86ba56cc62118613e4b19db` with existing approved repairs.

## Newly executed evidence

Both commands ran on macOS with PowerShell, not native Windows:

- `rtk proxy pwsh -NoProfile -File tests/design-system-contract.tests.ps1`: terminal exit 1. Initial DS-001..017 checks passed; consent section 50 passed, 1 failed at TEST-039 (actual CI registration still missing).
- `rtk proxy pwsh -NoProfile -File tests/design-sync-standing-consent.tests.ps1`: handle 86657 terminal exit 1. 54 counted passes, 1 counted failure TEST-053; deferred TEST-054 also prints FAIL outside totals. Do not poll terminal handle.

`rtk proxy bash tests/run-all.sh --list` exited 0 and emitted the exact `tests/design-sync-standing-consent.tests.sh` entry. Its PowerShell counterpart still reads `run-all.sh` source then calls Contains at lines 746–749, although the runner now loads an inventory. This is a stale consumer, not proof that the suite is absent. The Bash counterpart had been repaired, but that did not repair its PowerShell consumer.

## Broader investigation, not a completed failure census

Read-only `rg -n 'runAllShText|run-all\.sh|RunAllSh|runAllShPath' tests --glob '*.ps1'` finds many further source-based registration consumers. Examples with confirmed predicates:

- `design-sync-scan.tests.ps1:825–827` uses source Contains.
- `loop-inventory.tests.ps1:346–349` uses Select-String on source.
- `ownership-digest.tests.ps1:322` requires an indented literal in runner source.
- `validate-approval-sidecar.tests.ps1:1021–1022` uses source regex.
- `facet-manifest-parity.tests.ps1:377–380` uses source Contains for multiple suites.
- `agent-model-routing.tests.ps1:1020` uses source Select-String.

These are investigation candidates, not claims that their full suites have been run or that every match is defective. `human-copy-runner-contract.tests.ps1:98–105` already uses successful executable listing and order checks; retain that repair. No blanket text replacement is justified.

## Next action and boundaries

The earlier complete POSIX run's 43-to-3 improvement remains valid only for that inventory. It does not establish PowerShell or native Windows completeness. Audit remaining PowerShell consumers, preserve exact case-sensitive membership, command failure rejection, existing PowerShell/CI conjunctions, ordering and mutation controls. Reuse existing approved CI-registration repair scope only where the governing task permits it; do not reopen resolved historical ticket RT-20260808-001 or rewrite its PASS record. Frozen contract change RT-20260909-001 remains separately awaiting approval.

This diagnostic turn made no source changes, weakened no test, changed no verdict, and performed no commit/push/merge/issue closure.
