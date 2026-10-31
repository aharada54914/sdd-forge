# T-002 permanent equivalence follow-up

Owner: `/Users/jrmag/.codex/worktrees/shared-review-launch-integration/sdd-forge`
Base HEAD: `9ce19abe90df0cb83e385f96855e4843318a8807`

Scope: approved T-002, AC-005 TEST-010a preservation coverage. High-risk task;
this follow-up changes only the permanent PowerShell regression driver. Existing
dirty implementation, frozen reports, approvals, verdicts and ledger are retained.
RT-20261009-001's substitute-evidence exception is not applied to T-002.

The shared hash helper and its impl/task callers are unchanged. Add explicit
nonempty missing-status input and move the already exercised exclusive-read
failure assertion into permanent coverage. Compare both outputs/error types with
the frozen pre-extraction recipe, check unchanged bytes and successful reads after
release. A mismatching digest, accepted locked read, different exception type or
modified input must fail. No new acceptance or authorization semantics.

Required verification: run the permanent PowerShell driver; independent diff
review; admit the new evidence before a fresh formal evaluation. Native Windows,
CI, quality-gate PASS and merge are not established by this local follow-up.
