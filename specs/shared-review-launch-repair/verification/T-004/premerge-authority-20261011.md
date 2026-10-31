# T-004 scoped human authority — 2026-10-11

The human explicitly approved both decisions in this conversation: preserve the
past failure as a cause-unconfirmed risk, and separate premerge evaluation from
postmerge Done. This addendum records that authority; it is not a review verdict.

## Unconfirmed historical failure

The original PowerShell run (session 98200, receipt 251cbc) reported 20 passed
and 1 failed. The failed assertion was not retained in the available output.
Its cause remains unknown. Subsequent passing runs and the added diagnostics do
not prove that the original cause was fixed. The human accepts this residual
risk for this delivery. Preserve the failed record and investigate any recurrence;
do not replace it with a PASS or attribute it to concurrent edits without proof.

## Premerge evaluation and final acceptance

Evaluate all required inputs, acceptance criteria, implementation, regression
evidence and exact-head CI before merging. Distinguish criteria already verified
from criteria that require the merge itself. An otherwise satisfactory technical
premerge evaluation may authorize proceeding to the merge; it is not a final
quality-gate PASS or permission to set T-004 Done.

After merge, confirm the actual merge commit, main contents and applicable
postmerge CI, then run the remaining final quality-gate checks and Done decision.
An unrelated failure, missing mandatory input, unresolved blocking finding or
failed required CI still blocks the corresponding stage. No check is removed.

The evaluated public candidate is PR #558 head
`2f1ea5bab59609af66323f053a356a45f0666e49`. CI run `38128074675` is
the evidence for that head only; recheck any changed head before merging.
The existing delivery addenda identify later evidence separately from frozen
implementation-report claims. Preserve all historical reports and verdicts.
The public task remains In Progress while the owning task is Implementation
Complete; neither is Done, and neither status is evidence of successful delivery.
