# T-004 unresolved formal evaluation, 2026-10-11

This is a non-frozen status addendum, not a verdict, approval or task transition.
Historical reports and failed results remain unchanged.

## Current evidence

- Public candidate: PR #558, head `2f1ea5bab59609af66323f053a356a45f0666e49`.
- Latest API check: run 38128074675 completed successfully, all 37 jobs
  successful. The PR remains draft, blocked and review-required; no merge or
  post-merge verification has occurred.
- Public checkout was clean. Its host-review-preflight suite passed 19 tests
  in 14.751 seconds, including registration-removal rejection.
- Owner/public task-plan comparison found the T-004 status difference
  (Implementation Complete versus In Progress); this is not evidence of a
  different approval or task body. Neither copy was changed to satisfy review.
- Formal evaluation remains NEEDS_WORK:
  `reports/quality-gate/launch-e2fb3456-6c6a-4b96-9cfa-8612f901a914/wrapper.json`.
  Its reviewer did not complete the required specification/AC input inspection.
  A subsequent evaluation must inspect the full admitted input set.

## Decisions that cannot be replaced by another successful retry

1. The original full PowerShell run reported one matrix failure, but the
   detailed assertion was lost from the available output. Searches and later
   successful runs have not established the cause. The candidate adds failure
   diagnostics; it is not a demonstrated fix for that original failure.
   The formal evaluator requires either causal evidence or explicit acceptance
   of this residual risk. General permission to repair and merge does not prove
   the cause or supply that acceptance.
2. `tasks.md` Done When requires review findings to be resolved before merge,
   and merge/post-merge evidence before completion. The latest evaluator treats
   missing post-merge evidence as a pre-merge blocker. Resolve the sequencing
   explicitly: independently evaluate pre-merge technical readiness first,
   retain the task as not Done, then require successful post-merge evidence for
   the final quality-gate decision. This must not deem future checks satisfied
   or bypass required CI, review, approval or branch protection.

The governing calibration's Cannot-Verify Handling and Loop Stop Conditions
prohibit declaring Done when required evidence is unavailable or when a human
decision remains. No new reservation or repeated formal launch was made merely
to seek a different verdict. The approved four-part architecture remains
sequenced after this delivery and has not been started.
