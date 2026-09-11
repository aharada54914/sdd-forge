# A8 review launch: ledger divergence audit

This began as a read-only diagnostic addendum. The reconciliation follow-up
below records a subsequent ledger change; it is not a review verdict. No
reviewer was launched and no task status was changed.

## Current inputs

Worktree: `/Users/jrmag/.local/share/sdd-forge-a8-verify-20260905`.
Attempt 4 round 2 precheck remains present. Fresh SHA-256 verification
(tool output 3426eb) matches all three precheck-bound files: requirements,
acceptance tests and calibration. This is input integrity, not Spec PASS.

## Actual launch prerequisite

The installed spec-review-loop skill's Sequential launch boundary requires
the canonical ledger to include the invoking host and all prior reservations.
The A8 ledger does not contain the actual invoking CODEX_THREAD_ID
`01a06d01-11b5-7bd3-83a3-7e29bb3c96cd`.

Full-chain recomputation and uniqueness checks (45af6b, exit 0):

| Ledger | Records | SHA-256 |
| --- | ---: | --- |
| Current root | 965 | `7d533e81ba060620859c5f19ce90277d0571161dcd03ca25c75959d49ad8b74d` |
| A8 worktree | 902 | `bc404857b5a132a0eed85e27f5c1d40b1456abe7b7b12be27ba2486d120d715c` |

Both chains are valid. The first 900 records are identical. A8 has two
identities absent from root; root has 65 absent from A8. There are no shared
run/session identities with contradictory semantic identity fields.
Sequence 901 means A6 reviewer A in root but A8 reviewer A in the worktree.
Replacing one entire ledger with the other would lose history.

An in-memory union preserving all 902 A8 records and appending the 65 root-only
identities yields 967 identities and includes the actual invoking host. However,
all 65 imported sequence/previous-hash bindings change. No union was applied.

## Why a raw union is not yet sufficient

`plugins/sdd-quality-loop/scripts/validate-review-context-set.sh:380-391`
requires a persisted invocation's sequence and previous-record hash to equal
its ledger record. Therefore preserving run/session identity alone does not
preserve replay validity for imported invocation contracts. The existing
PR245 human integration procedure explicitly labels re-chained historical
invocation pins archival rather than replayable (its line 150); that caveat
must not be silently treated as passing workflow-state validation here.

Next action: inspect which A8 persisted-state consumers actually replay the
imported historical contracts, determine the supported provenance re-binding
path, and preserve both original chains and frozen evidence before publishing
any reconciliation. Do not discard the two A8 identities, append only the
current host while omitting known reservations, rewrite past verdicts, or
launch a same-session substitute review.

## Remote state

Fresh GitHub checks for PR400 (ff64a5) show all four required checks PASS at
head `8fa3eb8561d6f59b692ec574900f87e181145928`. The six open PR heads remain
unchanged (ea3ae3). This does not resolve PR400's formal review findings or
authorize marking any other PR green. No merge or issue closure occurred.

## Reconciliation applied after consumer inspection

Follow-up source scans (600248, a0af5b) of the actual A8 workflow-state,
review-precheck scripts and shared precheck library found no calls to the
invocation validator or identity-ledger references. Root reverse-reference
inspection (0ab9af, d75f80) distinguishes comments in implementation-report
and panelist-input validation from actual invocation replay. This supports
resuming a fresh reservation; it does not make imported historical invocation
pins valid or constitute a complete workflow-state PASS.

Applied an A8-prefix-preserving reconciliation with apply_patch. Preserved
both full original ledgers and all 65 old/new record mappings at
`reports/verification/a8-ledger-reconciliation-20260908/` in the main worktree.
The root canonical ledger remains unchanged. No historical invocation,
reviewer output, verdict, contract or specification was edited.

Independent read-back assertions (130309, exit 0) verified:

- exactly 967 records; all first 902 A8 records deeply equal the original;
- every root identity present with identical stage, role, run and session;
- every sequence, previous hash and computed record hash valid;
- no duplicate run or session; actual invoking host present;
- root canonical ledger bytes still equal its archived original.

New A8 ledger SHA-256:
`746b126d2209bc745348f6f9abb5e02d57681c66f37d54b544630618dd4f698f`.
A8 `git diff --check` passed (a22a2c). Imported historical invocation pins
remain archival against their preserved source ledger, not replayable against
this re-chained A8 ledger. Existing A8 invocation identity bindings remain
unchanged. The next fresh reviewer reservation must bind this new ledger tip
and use an actual fresh host-issued identity, after rechecking input hashes.
