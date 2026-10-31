# T-004 evaluation preparation repair

Owner: shared-review-launch-integration/sdd-forge; HEAD: 9ce19abe90df0cb83e385f96855e4843318a8807.
Scope: non-frozen evaluation preparation helper only. Existing dirty enforcement, CI, task and ledger files are preserved.

The public checkout has moved to the subsequent architecture work. Requiring its current HEAD and clean working tree prevents evaluating the already merged PR #558, although every source read uses the exact approved base/head commit IDs. Replace those two unrelated checkout checks with commit-object identity checks. Public commit/tree/blob proof, source SHA-256 checks, frozen implementation hashes, exact-head CI and merge checks, scratch readback, and ledger non-mutation remain unchanged.

Risk: evidence preparation; no admission, identity, approval, verdict or task-state semantics change. Validation required: exact commit resolution, rejection of an invalid revision, preparation/readback and ordinary launcher preflight. Formal evaluation and Done remain pending until separately observed.
