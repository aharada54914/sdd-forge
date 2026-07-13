# Acceptance Tests: second-approval-mask

All shell-suite tests live in `tests/second-approval-mask.tests.sh` (new,
agent-editable) and drive BOTH validator twins via their public `--registry`
entry point against self-contained temp-repo fixtures (pattern copied from
`tests/workflow-state-parity.tests.sh`). RED must be captured against the
pre-fix live twins before the fix is staged.

Fixture skeleton (per case): a temp root containing
`specs/workflow-state-registry.json` (single-feature entry),
`specs/<feature>/tasks.md`, and the minimal task-review contract/precheck
artifacts the task-stage provenance check reads, with the contract's
`tasks_sha256` computed from the FROZEN `tasks.md` by replicating the
normalization exactly as `tests/workflow-state-parity.tests.sh` replicates it
today (sed for sh semantics), extended with the `Second Approval:` deletion.

The `Doc Status` column below is DOCUMENT-TRACKING metadata for this table
only (updated as tests are implemented and verified); it is NOT part of any
test's expected assertion, and no fixture inspects a `Status:` value as a
test oracle beyond what the scenario column states.

| Test ID | AC | Scenario | Expected | Doc Status |
|---|---|---|---|---|
| TEST-001 | AC-001 | Freeze tasks.md without a `Second Approval:` line; add `Second Approval: Approved (Harada2 2026-07-12T00:00:00Z)` under the critical task; run both twins with `--registry`. Two further variants in the same case: (i) freeze WITH the line present, then edit its value — also expected ok (deletion masks any value); (ii) MULTI-OCCURRENCE: a fixture tasks.md with TWO critical tasks (T-001 and T-002, the RT-20260712-003 originating shape) that gains one `Second Approval:` line under EACH after the freeze — also expected ok (all column-0 occurrences deleted). | Both twins exit 0; output contains `workflow-state: ok` (all variants) | Planned |
| TEST-002 | AC-002 | Same freeze; three independent tamper sub-cases: (a) append an arbitrary line `Extra: tampered`; (b) flip one `- [ ]` to `- [x]`; (c) add an indented/bulleted mention of the field that is NOT a column-0 field line (e.g. `  Second Approval: pending discussion`) | Both twins exit nonzero with the `stage-provenance` "task plan hash is stale" diagnostic for ALL THREE sub-cases (sub-case (c) proves the mask is column-0-anchored, per Risks) | Planned |
| TEST-003 | AC-003 | Repeat TEST-001 and TEST-002(a) with a CRLF-terminated tasks.md (and CRLF registry, as the parity suite does); plus a fixture where the `Second Approval:` line is the FINAL line without a trailing newline | Identical outcomes to LF; for every case the sh and ps1 normalized forms are byte-identical (asserted by hashing the replicated normal forms) | Planned |
| TEST-004 | AC-004 | Run the full corpus (TEST-001..003 cases) under sh and ps1; verify `tests/run-all.sh` lists the suite | Exit statuses and first diagnostic rule IDs identical per case; registration line present in tests/run-all.sh | Planned |
| TEST-005 | AC-005 | Gate-phase evidence check (NOT a shell-suite case): after the human applies the staged twins, the quality gate records each live file's SHA-256 and compares it to the staged human-copy MANIFEST hash | Recorded gate evidence shows live == staged for both twins (pattern: the epic-136 live-hash gate logs) | Planned (gate phase) |

Notes:
- TEST-001 is the RED anchor: against the pre-fix twins it MUST fail (both
  report staleness) — that failure is the recorded RED evidence.
- TEST-002 sub-cases must pass (i.e., still detect tampering) in both RED and
  GREEN runs; they are the guard against over-masking.
