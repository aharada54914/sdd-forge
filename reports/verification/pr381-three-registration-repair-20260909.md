# PR381 three registration consumers — 2026-09-09

Checkout: `/Users/jrmag/.local/share/sdd-forge-pr381-recovery-20260908`
Base: `3971c93a5705dc15f86ba56cc62118613e4b19db` plus preserved recovery changes.

Scope: continue the approved CI implementation and existing actual-runner registration repair pattern. Change only the POSIX membership predicate in agent-model-routing, agent-capabilities-v2 and render-agent-frontmatter. Keep every PowerShell, staged CI, manifest and live-byte-identity assertion. This is not a new formal verdict or authorization to edit frozen specifications.

Before: the full baseline log `/tmp/pr381-posix-20260909.WaPopD/full.log` records the three registration failures at lines 851, 860 and 887. `tests/run-all.sh` now reads `suite-inventory.posix`; executable `--list` contains all three exact paths. The old source-text predicates do not recognize that actual registration.

Fix: run the real runner with `--list`, require exit 0, then match the complete path with `grep -Fx`. Grep consumes all input; no early-close pipeline is introduced. No runner, inventory, production validator or CI workflow was modified in this slice.

Primary review: Critical 0. Inspected the complete three-file diff and unchanged neighboring assertions. Membership did not require uniqueness/order in these three predicates; do not apply this simplification to other consumers that do. This review is not independent SDD QG.

## Verification

All three full suites ran with `rtk proxy bash -o pipefail -c 'bash tests/<name>.tests.sh 2>&1 | tee /tmp/pr381-posix-20260909.WaPopD/<name>-after-registration.log'`:

- agent-model-routing: exit 0, `ok: turn-first model routing structure is defined`; no numerical assertion total emitted. Session 22537 terminal.
- agent-capabilities-v2: exit 0, 10 passed / 0 failed.
- render-agent-frontmatter: exit 0, 23 passed / 0 failed. Session 57489 terminal.

`reports/verification/pr381-three-registration-controls-20260909.cjs` extracts exactly one actual assertion block per suite and executes it against the real runner and four isolated outputs: exact path, omission, `.bak` near-match and exit-7 with correct stdout. All 15 outcomes met expectations. This is a standalone primary-run regression diagnostic, not an inventory-wired suite or independent whole-repository mutation test.

Command: `rtk proxy node reports/verification/pr381-three-registration-controls-20260909.cjs /Users/jrmag/.local/share/sdd-forge-pr381-recovery-20260908`.

Each `bash -n` and recovery `git diff --check`: exit 0.

Source SHA256:
- agent-model-routing: a2f81ae45b365607e6d03c3aa3980e68b893e493714ecfe04873cf25474b66a2
- agent-capabilities-v2: 0e6b1c4e6636a3056f4ddf0edff118d0ca548aac9948eb17fe8d35a9f58e2e07
- render-agent-frontmatter: 573ab5c938feb28913a910552a9c9d1c3ca439dc5a97b5857b1c3a8ff194ebe3

## Remaining work

The original 43-failure full run remains historical FAIL. Dependency and citation repairs previously resolved two suites; these three resolve three more: **38 original failing suites remain unresolved**. A new complete run has not passed. Formal review/QG and native CI remain pending; no commit/push/merge, issue closure or task Done change occurred.

Fresh GitHub observation: seven open PRs, no active CheckRuns. PR400 has 25 completed checks with no failure, but formal review remains unresolved; PR245 has no Actions checks, which is not a PASS. PR401/394/390/381/371 retain failed checks. Exact heads remain those reported by the current gh query; no CI rerun was issued.
