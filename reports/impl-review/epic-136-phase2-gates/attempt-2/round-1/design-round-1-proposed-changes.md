# Design Round 1 Proposed Changes

Round 1 verdict: NEEDS_WORK (Critical 1, Major 3).

1. Add an explicit statement to the API / Contract Plan that this feature adds,
   changes, deprecates, or removes no network endpoint, RPC, or event contract.
2. Replace the stale ADR Change Log statement with a reference to ADR 0011 and
   summarize its root-handle-relative publication decision and rejected
   path-based copy alternative.
3. Ground the `constant-parity.tests.sh` protection-state assumption with an
   explicit human-accepted repository fact and make the consequence fail-closed
   if that protected state changes.
4. Expand Constraint Compliance so every normative constraint in REQ-001
   through REQ-005 is explicitly mapped, including cross-runtime ambiguity
   denial, byte-equivalent evidence diagnostics, UTF-8/NUL handling, local
   NTFS/FullLanguage capability, anchored publication, deterministic prefix
   state, and complete rollback.

No implementation work may begin until a fresh round independently passes.
