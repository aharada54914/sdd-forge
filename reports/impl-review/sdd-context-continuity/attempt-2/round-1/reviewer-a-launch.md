Native independent reviewer A launched after input verification and reservation.

Thread: 01a0e0fe-9fa8-7a63-8939-a5c5d49d46ac
Turn: 01a0e101-f230-7792-be35-d0367b407c23
Ledger sequence: 1198
Reservation receipt: 0c2107d3e10cdeceee8832c9287b9c77059e3c21e31ff017f106cd16ff4e6410
Invocation: reports/review-context/sdd-context-continuity-impl-a2r1-a-invocation.json

The first turn stopped before substantive review because the caller omitted the full reservation receipt. Its actual response is preserved in reviewer-a-launch-deficiency.json. No new reservation was made.

Resumed turn: 01a0e103-8c96-7bb1-8750-9d5705c33aa6. The full original receipt, predecessor and pre-append tip were supplied; the reviewer verified the unchanged inputs and completed the review. Actual result in reviewer-a.json: NEEDS_WORK, 8 PASS / 2 SKIP / 1 Major FAIL (API-COVERAGE). The earlier launch deficiency is not substituted for this substantive result.
