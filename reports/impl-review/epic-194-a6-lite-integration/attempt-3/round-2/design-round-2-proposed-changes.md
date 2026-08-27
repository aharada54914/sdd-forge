# Implementation Policy Review Report: epic-194-a6-lite-integration — Round 2 / Attempt 3

## Verdict: NEEDS_WORK

Reviewer A: PASS (10 PASS, 1 SKIP). Reviewer B: NEEDS_WORK (1 Major).
Merged: 0 Critical / 1 Major / 0 Minor.

Round 1 two Major findings, both from reviewer A, are closed and reviewer A
verified both closures. Reviewer B, blind, found a third defect in the
remediation itself.

## Findings, verbatim

### VERIFICATION-PATH-CONCRETE (Major) — reviewer B

Two distinct gaps in the validation path for the Protected-File Statement's point 5 (per-target atomic publish, no cross-target transaction/rollback, live-state failure reporting, added by commit cf631ea748b86fc94f7570907669dc71ae563bfd), a high-risk surface (protected-file tampering / partial-batch data-integrity failure, security-spec.md's own B5 STRIDE row). (1) design.md Test Strategy item 17's 2026-08-25 extension names four of point 5's properties individually but omits the fifth: 'A failure before the copy phase begins reports instead that no live file was modified' (Protected-File Statement point 5, final sentence) has no corresponding named property in item 17's list. Item 17's own stated rationale for the extension -- 'a future implementation task could satisfy every traceable criterion for this runner and never build a fixture for the property point 5 exists to guarantee' -- applies identically to this omitted property: a future task can satisfy every criterion item 17 now names and still never build a fixture for the pre-copy-phase failure-reporting behavior. requirements.md AC-031 and acceptance-tests.md's AC-031 row are not independently extended either (both still describe only the exact-set/hash/post-copy-verification contract of points 1-4), relying entirely on their own cross-reference to design.md's Test Strategy item 17 -- which makes item 17's own completeness the sole guarantee, and it is incomplete by this one property. (2) security-spec.md's B5 STRIDE row (line 74) and Security Tests row (line 188, citing 'Test Strategy item 17') were last amended by commit 23fe659f57685c5e7dde304035ce8887658d86bc (2026-08-25, CI-workflow scoping), which predates cf631ea7 (the commit that added point 5 and extended item 17). Neither row mentions per-target atomic publish, the explicit no-rollback/non-transactional acknowledgment, or live-state failure reporting -- the B5 STRIDE row's mitigation text still reads only 'three-way exact-set verification, per-target hash verification before copy, and post-copy re-verification,' and the Security Tests row still describes item 17 using its pre-extension wording. B5 is explicitly the STRIDE row for 'a cp that silently fails partway, installs bytes that do not match the reviewed, hash-verified payload' -- precisely the scenario point 5 was added to mitigate -- so the security layer's own documented mitigation and validation path for this named Tampering risk is stale relative to design.md's current, human-ruled contract. A security reviewer or implementer working from security-spec.md alone would not learn that the runner must report installed/failed/not-attempted state on failure, nor that a fixture for that behavior is required.

## Proposed Changes

Not applied. Both parts verified independently by the orchestrator:

1. design.md Test Strategy item 17 extension names four of point 5 five
   properties and omits the fifth — that a failure BEFORE the copy phase
   begins reports instead that no live file was modified. This is the
   orchestrator own enumeration error: the extension was written naming four
   properties where point 5 states five.
2. security-spec.md B5 STRIDE row and Security Tests row predate cf631ea7
   and do not reflect point 5. Reviewer B attributed their last amendment to
   commit 23fe659f; git log shows ac7a2e64, which also predates cf631ea7, so
   the timing claim holds while the commit attribution does not.

Both land on frozen documents and need an upstream decision.

## Next Steps

1. Upstream ruling on the two parts above.
2. Round 3 is the last round of this attempt.
