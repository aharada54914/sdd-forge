# PR 426 specification review launch readiness

Date: 2026-09-14
Subject head: `23e94ffff4498ce8ac5cf88b81282ab16ca7da75`
Feature: `review-cross-critique`

The canonical specification precheck was run for attempt 1, round 1 and
returned exit 0. Its original output is preserved at
`reports/spec-review/review-cross-critique/attempt-1/round-1/precheck-result.json`.
This is a precheck result only, not an independent reviewer verdict.

Before reserving any reviewer, the sequential launch boundary was checked.
The installed spec-review-loop skill requires the canonical ledger to contain
the invoking host identity and all prior reservations, and explicitly requires
stopping on stale history. No reviewer was reserved or launched.

Read-only comparisons found:

- This worktree has 959 ledger records, with final record hash
  `bfba486d3d7ffd5b94db7b2388594d37cb118c4d5221bcd88e9347139b666f29`.
- `/Users/jrmag/sdd-forge` has 979 records. Its first 959 records exactly equal
  this worktree's records. Its subsequent records include the invoking host
  `01a06d01-11b5-7bd3-83a3-7e29bb3c96cd`, absent from this worktree's ledger.
- The PR 409 worktree has 967 records, but its history differs from the root
  worktree starting at array index 959 (sequence 960). Therefore copying the
  longest ledger would not preserve all known reservations. The PR 409 final
  record is the consumed, unlaunched reviewer reservation at sequence 967,
  hash `bef9b0f074c3b388aac4966fcd553479f6caa4835ac98866cafa977be4197a7a`.

Counts and exact record equality were computed with jq against the original
JSON files. No hash-chain validity is inferred merely from those comparisons.
No ledger, old review evidence, task status, or review verdict was modified.

Resume requires a sanctioned reconciliation that preserves both histories and
their existing bindings; do not replace a divergent ledger, fabricate host IDs,
or rewrite old record hashes. Retain the successful precheck and reverify its
input hashes before a permitted reviewer launch. Do not replay the existing
attempt-1/round-1 destination. Requirements remain Pending; Issue 345 remains
open and PR 426 remains draft pending independent review and current-head CI.

Current-head CI handle: GitHub Actions run `34768207007`. At the latest poll
during this inspection it was in progress (17 completed successful jobs, no
failed jobs returned, seven jobs running). This is not a final CI result.

## Full worktree inventory and existing reconciliation precedent

A subsequent read-only inventory examined the ledger in each existing worktree
reported by `git worktree list --porcelain`: 30 ledgers were present. Missing
temporary worktrees were not treated as inspected repositories. For each ledger,
all sequences and predecessor links were checked, each record digest was
recomputed from the six pipe-separated identity fields, and duplicate run/session
IDs were rejected within that ledger. All 30 passed these specific checks.
Across them there were 1,152 distinct run IDs and 1,152 distinct session IDs,
with no conflicting stage/role/run/session tuple for a shared run or session.
This establishes that an identity-preserving union is possible at the semantic
level; it does not validate invocation replay or prove reviewer execution.

The prior report `reports/verification/a8-review-ledger-divergence-20260908.md`
documents an already-used archival reconciliation: preserve original ledgers
and old/new mappings, retain the destination prefix, append source-only
identities, and retain historical invocation pins unchanged against their
original archived chain. Thus ledger divergence is not, by itself, proof that
a validator redesign or a new human decision is required. The next technical
step is to apply that precedent with preserved source evidence and check its
consumers, not to invent a new approval requirement.

Current source inspection confirms why the archival qualification matters:
`validate-review-context-set.sh:377-391` rejects a persisted invocation whose
sequence or predecessor differs from the current record. No call/reference to
that validator or `identity-ledger` was found in the four current Bash and
PowerShell specification-precheck/workflow-state files. This is a bounded
consumer inspection, not proof that no other consumer replays invocations.

At that inspection point, no reconciliation had been applied. A migration must preserve all known
identities (not only the root worktree's 979), original bindings, and the existing
959-record destination prefix. Chain validity, archived replay, current-stage
validation, and a fresh permitted reviewer launch remain separate checks.

## Archival reconciliation applied and checked

Applied the existing archival procedure to this worktree only. The first 959
records are unchanged, followed by 193 source-only identities (1,152 total).
No reviewer identity was invented or newly reserved, and no historical invocation,
output, verdict or task status was edited. Source reservations without a launched
reviewer remain reservations, not reviews.

`pr426-ledger-reconciliation-20260914.json` preserves the nine distinct original
ledgers as their shared prefix against committed base
`23e94ffff4498ce8ac5cf88b81282ab16ca7da75` plus their exact original tails.
It gives the complete restoration algorithm and all 266 source-tail mappings.
Read-back verification reconstructed all nine original byte streams and matched
their SHA-256 values; all other 29 extant worktree ledgers remained byte-unchanged.
The base prefix comparison, complete chain recomputation, unique run/session
checks, semantic mapping checks and invoking-host membership check passed.

Destination SHA-256:
`1227634754c2d8576b4797c15bf3fad81341e7dcc15e6a92c8ba5bfa6ca2966f`.

The archive contains only the canonical seven record fields, source locations,
hashes and restoration/mapping metadata. This was a scoped data-diff review,
not an independent specification verdict or a whole-repository security audit.
Imported historical invocations are still archival against their original chain;
their exact sequence/predecessor pins do not become replayable against this chain.

Verification after application:

- `bash tests/review-context-boundary.tests.sh`: exit 0; 31 citation anchors and
  TEST-RCB-001 through TEST-RCB-010, including 005b, passed in Bash and PowerShell.
  These include repeated-reservation rejection, mismatch rejection, and
  verification after ledger growth. They are fixtures, not live reviewer launches.
- All three original precheck-bound input hashes still match; precheck was not
  rerun into its immutable destination.
- `git diff --check`: exit 0.
- `bash tests/workflow-state.tests.sh`: exit 0, shell workflow-state validation
  fixtures passed against the reconciled worktree.

Formal review remains unlaunched. A new manifest must use a genuinely fresh
host-issued reviewer identity and the current ledger tip, and pass reservation
before the named reviewer is launched. This reconciliation does not authorize
retrying the previously denied PR409 launch through another interpreter or
weakening protected-write rejection. Requirements remain Pending.
