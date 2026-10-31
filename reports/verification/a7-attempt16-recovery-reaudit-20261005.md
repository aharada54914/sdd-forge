# A7 attempt-16 recovery candidate — limited independent re-audit

Date: 2026-10-05

Non-formal candidate audit only. This is not an SDD review, gate verdict,
approval, or authorization to apply. No protected implementation, historical
record, reservation, or task status was changed. Temporary fixture copies were
used by the existing test driver and removed by that driver.

## Snapshot and scope

Rechecked only the two findings in
`reports/verification/a7-attempt16-recovery-audit-20261005.md` and their corrective
changes, using the reviewer skill. The original audit remains a record of its
older pinned snapshot.

- Patch: `reports/verification/a7-attempt16-recovery-candidate-20261005/mechanical-integration.patch`
- Independently verified patch SHA-256: `c618f47d1ebcbd66f7c1580a28e7583c8c4c3b5311faf8399555097efdc39fbd`
- Independently verified helper SHA-256: `f0172bcf8a5a4e1ae63741ab1566803075fc98ea782d2918469dbf5888cbf77a`
- Extracted the added helper from the patch in memory and confirmed exact byte
  equality with `failed-last-attempt.py.candidate`.

## Findings disposition

### M1 — resolved within this snapshot

`failed-last-attempt.py.candidate:88-129` now checks historical precheck hash
formats, constructs the complete requirements/acceptance/calibration/precheck
manifest from each historical precheck, includes investigation when recorded,
and includes that round's integrated summary for reviewer B. It checks exact
entry count, item shape, hashes and unique paths. Only the failed final round
is compared with current input hashes; earlier rounds are not compared with
revised current document bytes.

The common manifest validation runs for every invocation, including the failed
round. Six isolated mutations independently rejected at the intended manifest
diagnostic: precheck-only, missing input, extra input, mismatched hash, duplicate
input, and missing reviewer-B summary. These tests invoke the helper directly,
so ledger mismatch cannot mask the corrected semantic check. The outer ledger
validation is retained by the patch and was not re-executed in this re-audit.

### m1 — resolved within this snapshot

`failed-last-attempt.fixture.py:86-93` now recomputes the transcript pin after
removing end-turn events. Its shared error assertion (`:68-69`) and dispatch
(`:215-220`) require the missing-completion diagnostic. Independent execution
returned that diagnostic, not a transcript-hash mismatch.

## Independent execution

Ran the existing local fixture through `rtk proxy python3 -B` with the retained
host transcript as input. `-B` prevents bytecode-cache writes in the owner.
The private transcript path and raw content are intentionally not reproduced.

Exit code: 0. Results: 18/18 checks succeeded (one baseline acceptance and
17 negative cases).

```text
PASS accept real evidence copy
PASS reject changed verdict: completed last-attempt verdict changed
PASS reject unfinished first turn: failed first turn has no completed host transcript
PASS reject changed current input: failed-round inputs changed
PASS reject reused host session: last-attempt reviewer session reused
PASS reject unexpected reviewer output: unexpected last-attempt round-3 evidence inventory
PASS reject replayed round: unexpected last-attempt round inventory
PASS reject empty hashes: incomplete current input hashes
PASS reject partial hashes: incomplete current input hashes
PASS reject changed transcript pin: failed-turn transcript changed
PASS reject changed blocker pin: failed-turn diagnostic binding mismatch
PASS reject complete review prompt: first turn was not the pinned truncated input
PASS reject precheck only manifest: last-attempt manifest differs from its precheck
PASS reject missing manifest input: last-attempt manifest differs from its precheck
PASS reject extra manifest input: last-attempt manifest differs from its precheck
PASS reject mismatched manifest hash: last-attempt manifest differs from its precheck
PASS reject duplicate manifest input: last-attempt manifest differs from its precheck
PASS reject missing reviewer B summary: last-attempt manifest differs from its precheck
```

## Limits and conclusion

The prior Major and Minor are resolved at the pinned candidate bytes. No new
actionable defect was found in their corrective changes. This is not a renewed
whole-system audit or formal SDD acceptance. The reported existing 56 checks
and four Bash/PowerShell full-caller checks were not independently rerun here;
their success remains author-reported for this re-audit. No candidate was applied
to protected originals, and no real new attempt or reviewer was launched.
