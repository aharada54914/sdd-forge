# PR381: exact integration decisions still required

This is a proposed change scope, not an approved specification, task, review
verdict, or authorization to edit protected files. Historical evidence stays
unchanged.

## Current-state checks

GitHub main: `4366438f3b243210a4ece5a17f873ca2d920600a`, protected.
PR381: `3971c93a5705dc15f86ba56cc62118613e4b19db`.
Fresh PR status query found seven open PRs and no unfinished CheckRun on their
current heads. PR381 has eleven failed checks including the complete POSIX
inventory and required-checks. This is not a live CI wait.

The approved two-line loop helper repair and four regression checks are already
present locally, at the hashes in pr381-helper-independent-review-20260909.md.
Repeating that approval does not change the following separate decisions.

## Decision A: mandatory POSIX coverage (RT-20260909-001)

Proposed replacement of the frozen equality condition:

> Preserve every existing mandatory dependency and its success assertion.
> Additionally, required-checks must depend on posix-regression and require its
> result to equal success. Failure, cancellation, skip, missing result and any
> unknown result must not permit success.

Keep every existing job, command, platform, timeout and dependency pin. Do not
require unrelated optional sibling workflows. Carry the amendment through the
BL-001/REQ-004/AC-017/TEST-017/needs references and a new formal review binding;
never revise historical PASS or FAIL evidence. Synchronize final candidate
manifests without overwriting unrelated staged changes.

Verification must include independent mutations deleting the dependency and
deleting its result assertion; the actual aggregator's result matrix; retention
of all previous mandatory assertions; candidate/mirror/generator checks; full
POSIX execution; and mandatory native CI. Protected changes require human
application if denied, not a bypass. The governing ticket remains awaiting the
explicit frozen-contract amendment decision.

## Decision B: cross-critique repair preparation (#347/#348)

Fresh `git log --all --format=%H -- specs/review-cross-critique/tasks.md` returned
no commits in current local refs. Current requirements.md:3 and design.md:3 both
remain Pending. This does not prove that no task exists on an un-fetched remote
ref, but no governing approved task has been established for these edits.

Proposed task coverage after required specification/design/task review:

1. Require proposed_severity for every PROPOSE-SEVERITY-CHANGE record while
   preserving the existing enum and basis requirements.
2. Require substantive scope evidence for in_scope, out_of_scope and unclear.
   Specify the producer and consumer responsible for resolving a reference
   against the exact reviewed input set; nonempty text alone cannot prove this.
3. Cover positive, missing, empty, whitespace-only and invalid-reference cases
   for all three assessments. Keep concern-only disposition restrictions,
   in-scope ID requirements, closed object shapes and no automatic Done reopen.

Existing reproduced evidence: pr381-cross-critique-missing-fields-20260909.md
(five expected rejection failures and five successful controls). Do not mark
these issues resolved based on helper-suite or syntax-only schema success.

## Separate human judgment (#346)

Fresh GitHub issue body still requires three comparable real-run records and a
human choice of plugin promotion, continued standalone use, or retirement.
Collect the comparison evidence before requesting that choice; broad merge
permission is not the choice. No gate/plugin modification belongs to #346.

## Execution boundary

No commit, push, merge, closure, approval field or review verdict was changed by
this assessment. Next: obtain Decision A explicitly, then perform the bounded
amendment and formal review before implementation. Decision B needs a legitimate
reviewed and approved task, not an invented Approved field.
