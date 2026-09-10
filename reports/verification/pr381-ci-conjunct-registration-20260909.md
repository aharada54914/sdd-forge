# PR381 CI-conjunct registration repair — 2026-09-09

Checkout: `/Users/jrmag/.local/share/sdd-forge-pr381-recovery-20260908`, base `3971c93a5705dc15f86ba56cc62118613e4b19db` with preserved recovery changes.

Approved CI repair continued for design-sync-scan, hitl-wfi-terminal, check-placeholders-brownfield and release-loop-gate. Only the POSIX membership predicate changed: successful actual runner `--list` followed by exact full-path matching. Existing PowerShell and live workflow conjunctions and sibling assertions remain unchanged.

Primary review: complete four-file diff inspected, Critical 0. No production, workflow, inventory or frozen specification changes. This is not independent SDD QG.

Standalone actual-block diagnostic: 24 passed, zero failed. Cases include correct membership, omission, near-match, failed listing with correct stdout, and missing required PowerShell/CI conjunct. Utility supports indented blocks and supplies actual workflow/PowerShell paths. No protected runner was modified by controls; these are not claimed as inventory-wired tests.

Full four-suite run and preceding syntax checks: session 23370 terminal exit 0, each suite reported PASS. Complete logs: `/tmp/pr381-posix-20260909.WaPopD/<suite>-after-compound-registration.log`. Diff whitespace check exit 0.

Source hashes:

- design-sync-scan: 5b34abe81eeddd9a9ed9bce81410f20fe16e76b8d569e6ae7ff141128f70b7e7
- hitl-wfi-terminal: 0635b8e9182b221354b87e0a6669a72ba1037599f98d02baa12d6347a872ae1a
- check-placeholders-brownfield: 9587dc4c79236958dee019ac8c7d4b7e1f6820a25829c4ac0f61d8f165bf93d9
- release-loop-gate: 4b948b60009ac63c337b26fa6342f0e68306483ab71d6da7d291a780d2cb0f63

Twelve original baseline failing suites remain unresolved. Historical whole-run FAIL is preserved. No fresh whole-run PASS, formal QG, native CI success, commit/push/merge or issue closure.

Next: facet-manifest-parity six-suite loop and self-check, model-freshness, structural-compatibility, standing consent, ownership uniqueness/order checks and hook boundary loop. Then three non-registration failures (mirror freshness, candidate job set, design-system CI reachability). Do not weaken conjuncts, multiplicity, order or CI requirements.
