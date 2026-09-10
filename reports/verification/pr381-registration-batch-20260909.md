# PR381 registration batch verification — 2026-09-09

Checkout: `/Users/jrmag/.local/share/sdd-forge-pr381-recovery-20260908`
Base: `3971c93a5705dc15f86ba56cc62118613e4b19db` with preserved uncommitted recovery changes.

This continues the approved CI repair. Nineteen membership-only POSIX predicates now require successful execution of `tests/run-all.sh --list` and exact full-path membership using `grep -Fx`. No runner, inventory, production validator or CI workflow was changed in this batch. Neighboring PowerShell and CI checks are retained. Compound, uniqueness and ordering predicates are excluded from this batch.

Suites: capability-summary-schema, detect-policy-weakening, guard-invariants-epic-a1, facet-manifest-staleness, registry-discovery, validate-capability-registry, capability-registry-parity, facet-manifest-schema, run-panelist-effort, check-hook-activation-handshake, quality-gate-cycle-limit, facet-manifest-semantics, canonicalize-sdd-yaml, evaluate-predicate, ship-track-selection-migration, validate-approval-sidecar, generate-approval-sidecar, plugin-contracts-track-selection, apply-human-copy.

Primary review: the complete patch changes only membership predicates. A failed listing cannot count as membership; matching consumes all input and requires the whole path. This is not an independent SDD quality verdict.

Verification:

- Actual assertion-block controls: 95 expected outcomes passed (real runner, exact member, missing member, near-match suffix, and correct stdout with failed listing for each suite). The existing standalone `pr381-three-registration-controls-20260909.cjs` accepts the nineteen names as optional arguments. These controls are not claimed as inventory-wired or independent full-repository mutation tests.
- All nineteen full suites and their preceding `bash -n` checks completed successfully. Session 94689 is terminal, exit 0, ending `BATCH_FAILURES 0`. Do not restart or poll it.
- Complete per-suite output: `/tmp/pr381-posix-20260909.WaPopD/<suite>-after-registration-batch.log`.
- Recovery checkout `git diff --check`: exit 0 after completion.

The original full baseline remains FAIL (43 failing suites). Five were resolved before this batch; nineteen additional suites now pass scoped reruns, leaving nineteen original failures unresolved. This count is not a fresh whole-repository PASS. Formal review/QG and mandatory native CI remain pending. No commit, push, merge, issue closure or task Done transition was performed.
