# PR 371 / 381: read-only CI failure triage

Observed: 2026-09-10. No CI rerun, source change, push, merge, or verdict change was performed for these PRs in this triage. These are historical runs attached to the PRs, not tests of the current dirty local worktree.

## PR 371

Run 33256788058 (2026-08-29):

- Ubuntu MCP job 99111814881 and macOS MCP job 99111814858 fail the live shell comparison for `risk-adaptive-layer`: the shell exits 1 (`fail`), while `parseTaskState` returns `pass`. The failure is in `task-state-golden.test.js`, `assertParserMatchesShell`. Recorded-fixture success does not establish live parity.
- Windows job 99111814795 reports four near-boundary panelist completion failures under TEST-004(c): gpt iterations 3/4 and gemini iterations 2/4; the suite ends with 60 passes and 4 failures. Total elapsed time alone is not the timed child interval: some successful cases also exceed 2000 ms in total. Raising a timeout without locating wait/output/process boundaries is not a demonstrated repair.

Sources:

- https://github.com/aharada54914/sdd-forge/actions/runs/33256788058/job/99111814881
- https://github.com/aharada54914/sdd-forge/actions/runs/33256788058/job/99111814858
- https://github.com/aharada54914/sdd-forge/actions/runs/33256788058/job/99111814795

## PR 381

Run 34017386320 (2026-09-06):

- Ubuntu version-gates job 101443473166: `bump-version-gate.tests.sh` ends with 16 passes / 1 failure. TEST-006 (AC-006) reports missing registration in `tests/run-all.sh` and/or `.github/workflows/test.yml`.
- Ubuntu loops-routing job 101443472805: registration assertions fail for four Bash suites: loop-inventory, loop-driver, loop-consistency, and loop-escalation. Corresponding PowerShell registration assertions pass. The suite ends with 67 passes / 4 failures.
- This identifies the registration assertion / dispatch wiring boundary, but does not establish whether wiring is missing or the assertion cannot recognize existing wiring. Do not weaken checks or add marker-only text to satisfy them.
- Other failing jobs have not all been inspected; these observations do not explain every failure yet.

Sources:

- https://github.com/aharada54914/sdd-forge/actions/runs/34017386320/job/101443473166
- https://github.com/aharada54914/sdd-forge/actions/runs/34017386320/job/101443472805

## RT004 dependency and execution boundary

### Additional PR 381 inspection

The PR check query still points to run 34017386320. Ubuntu `test` job 101443473011 fails at PowerShell workflow-state validation: `wfi-034-scratch-isolation` is an unregistered specification directory. The amendment-growth notices are explicitly tolerated, not the error to suppress.

The complete POSIX inventory job 101443472822 finishes with **20 failed suites**. Its terminal inventory is:

```
impl-review-round2-contract.tests.sh
task-context-isolation.tests.sh
rollback-1.5.0.tests.sh
workflow-state-registry.tests.sh
workflow-state-registry-parity.tests.sh
second-approval-mask.tests.sh
human-copy-mirror-freshness.tests.sh
deterministic-lane-selfcheck.tests.sh
task-plan-binding-durability.tests.sh
review-context-boundary.tests.sh
design-system-contract.tests.sh
facet-manifest-schema.tests.sh
facet-manifest-semantics.tests.sh
capability-summary-schema.tests.sh
context-projection-schema.tests.sh
facet-manifest-staleness.tests.sh
facet-manifest-parity.tests.sh
design-sync-standing-consent.tests.sh
design-sync-scan.tests.sh
structural-compatibility.tests.sh
```

Observed failure groups and repair constraints:

1. Workflow registry mismatch also blocks task prechecks. Reconcile the actual spec directory with its registry and lifecycle evidence; do not bypass the precheck.
2. Windows simulation fails during ctypes initialization with `ModuleNotFoundError: No module named 'nt'`. This matches the class covered by the user's earlier authorization to initialize real-OS ctypes before the simulated OS switch; locate and verify that existing repair before creating another one.
3. Rollback fixture fails with `Author identity unknown` / `empty ident name`. The existing authorization is test-only Git author configuration in the temporary clone, not global user configuration.
4. Human-copy freshness and deterministic-lane job-list checks fail. Synchronization must retain every required job and bind the candidate to its own manifest.
5. `review-context-boundary.md` cites an obsolete validator line 245. Update only to verified current evidence under the approved citation repair; do not weaken the assertion.
6. Numerous aggregate/CI registration assertions fail. The inventory demonstrably invokes several of these suites, so their messages alone do not prove complete CI unreachability. Actual dispatch reachability and the intended registration contract must both be checked. Designed-red messages remain failures, not exceptions inferred from their labels.

These are run-specific findings, not proof that the current local tree still has every defect. Next implementation action is to reconcile existing approved repair artifacts with these failure groups after the recovery-entry prerequisite is cleared, then test the resulting exact commit.

- https://github.com/aharada54914/sdd-forge/actions/runs/34017386320/job/101443473011
- https://github.com/aharada54914/sdd-forge/actions/runs/34017386320/job/101443472822

### Active recovery prerequisite

The original-path workflow history suite passed 137/137 after the diagnostic patch. The expanded admission-path suite remains 24 passes / 20 failures. The lexical DATA candidate is partial and has only passed applicability checks; it must not be presented as a verified repair or applied as a complete solution.

A read-only runtime-dependency search including protected paths was refused by the active SDD guard. It was not retried through another executor or remote source retrieval. Human source evidence is needed before selecting a supported held-handle acquisition implementation. Temporary recovery-entry restrictions still prevent unrelated integration; remote read-only failure triage is not an integration approval.
