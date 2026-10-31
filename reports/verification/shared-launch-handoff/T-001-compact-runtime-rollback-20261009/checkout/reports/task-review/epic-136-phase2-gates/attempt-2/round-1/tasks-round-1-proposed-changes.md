# Task Round 1 Proposed Changes

Round 1 verdict: NEEDS_WORK (Major 1).

Split issue #122 into two dependency-ordered implementation units without
changing the one-issue-per-commit policy:

- T-005 retains canonical schema, deterministic generation, four native
  modules, fixed runtime loaders, CI drift enforcement, and TEST-010..012 plus
  cross-runtime regression.
- T-006 owns the Windows handle-relative human-copy publication runner,
  adversarial namespace/hard-link tests, deterministic partial-install state,
  complete rollback, and TEST-013. It depends on T-005.

Both remain in the same #122 commit. Traceability and non-frozen evidence paths
must identify their separate quality-gate decisions.
