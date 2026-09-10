# PR381 bump-version registration repair — 2026-09-09

Checkout: /Users/jrmag/.local/share/sdd-forge-pr381-recovery-20260908
Base: 3971c93a5705dc15f86ba56cc62118613e4b19db
File: tests/bump-version-gate.tests.sh
SHA256: 10d8fa2211991b9957b829c7554ccbea04904978a0706ff1cf68eedf37d0240d

Scope: remaining approved PR381 executable-inventory registration consumer. No production release script, workflow, mandatory check, acceptance contract, or formal evidence status changed.

Extracted the existing source-text predicate unchanged, then added five controls before changing behavior. Old predicate failed the real registration and accepted misleading source comments for missing, near-match and failed-list cases; dynamic exact listing was rejected. Full suite command `rtk proxy bash tests/bump-version-gate.tests.sh` exited 1: pass=13 fail=5.

Minimal correction queries the real runner with --list, returns failure on nonzero exit even with matching stdout, and requires a complete exact tests/bump-version-gate.tests.sh line. Existing CI-text registration conjunct remains. Controls use the same predicate as the live assertion, require --list, exercise dynamic exact success and four negative cases (missing path, .bak near match, exit 7 with correct stdout, missing CI declaration). The runner source deliberately contains a misleading comment during negative controls.

Full suite repeated: exit 0, pass=18 fail=0. bash -n and git diff --check both exit 0. Existing TEST-001 GNU-sed mutation-success SKIP is retained on this macOS host and is not verified here. TEST-002 and TEST-003 retained nonzero release failure and empty Git porcelain assertions; TEST-004 no-bypass checks, TEST-005 ordering, and all existing TEST-006 checks passed.

Primary review: Critical 0. Scoped diff only introduces the shared predicate and controls. Temporary directory uses trailing XXXXXX and explicit allocation failure; cleanup uses the existing suite-owned cleanup list. No source-text membership extraction or weakening of exit-code checks. This is ordinary primary review, not formal independent QG.

No commit/push/merge or issue closure. Native CI and formal current-artifact gates remain required.
