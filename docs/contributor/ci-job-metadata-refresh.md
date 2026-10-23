# CI job metadata refresh in required-checks collection

## Incident (PR 629)

Required-checks run 39809890748 attempt 1 failed only on 78 version-gates
obligations recorded `evidence-missing` with null `job_id` and
`source_attempt`; 370 obligations passed and one was an expected skip, and every
native job passed. The collector had read each attempt's jobs list once. The
original observation bytes were not retained, so a stale `in_progress`
version-gates row is the probable cause, not an established one. Later reads by
the parent showed the individual job endpoint fresher than the jobs list, but
those were different reads at different times from the one the collector made.

A one-time failed-job-only rerun of the same run (attempt 2) reacquired the
metadata. It aggregated the same merge revision `e59a7b33` to PASS: 448
verified obligations and 1 expected skip, all sourced from successful attempt-1
executions. No native assertion was rerun, and the attempt-1 failure remains in
the run history. That rerun used the unchanged collector at
`6dab8f7035336d2ddcc92d8b487a1cbfc231a3ea`. It is not evidence for the refresh
described below.

## Behaviour

`tests/verification-ci.py collect` re-reads, by individual read-only GET
`/actions/jobs/<id>`, only rows that the jobs list reports in a nonterminal status
(`queued`, `in_progress`, `waiting`, `requested`, `pending`). The `required-checks`
row is excluded, so the verifier never waits on itself. Terminal rows, including
failures, are never re-read. Each response must keep the original job ID, run ID,
run attempt, head SHA and name. Otherwise collection fails without publishing
`collection.json`. The actual response replaces the row in the persisted page and
is hashed as usual. Rows with no status, and job names absent from the list, are
not re-read or inferred.

## Refresh budget

All refresh work shares one monotonic deadline of 60 seconds
(`REFRESH_BUDGET_SECONDS`). There are at most 5 rounds (`REFRESH_ROUNDS`), with
10 seconds (`REFRESH_DELAY_SECONDS`) between rounds:

- Each read's subprocess timeout is the smaller of the usual 60 seconds and the
  time left before the deadline.
- A read is not started once the deadline has passed.
- A sleep is not started unless more than one delay remains.

The refresh can therefore add at most about 60 seconds, plus the brief cleanup
of a read that is killed at its capped timeout. This bounds only the
refresh. It does not guarantee that the whole `required-checks` job, including
checkout, dependency install, plan download, collection and aggregation, fits
its 5-minute timeout.

When the rounds or the deadline run out, the last actual unfinished response is
persisted. Aggregation is unchanged: such a row yields no execution origin and
fails closed. A receiptless missing origin yields `evidence-missing`; a receipt
bound to a missing original execution can yield global `evidence-mismatch`. An
earlier attempt's success cannot stand in for a later actual execution. A read that fails or times out is the existing typed transport failure: the
collection exits 2 with the fixed error envelope, and no manifest is published.

## Limits

- **No diagnostics retention.** The observations directory and the result are
  still not uploaded. Within a run, the first list row is replaced in memory
  before persistence, so only the final observation survives. The
  `required-checks` step shape is fixed exactly by `prepared_verifier_job` in
  `tests/verification-workflow.py`, and on pull requests the plan is rebuilt by
  the trusted base planner. Adding an upload step changes that planner policy and
  its adoption path, which is beyond this bounded fix. Until that is designed
  separately, a future failure of this kind still cannot be diagnosed from
  retained bytes.
- **Not yet validated natively.** Whether the 60-second budget covers GitHub's
  list lag is unproven. The refresh is covered by deterministic fixture tests
  only; it has not yet run in a native required-checks job.

## Repeated incident on PR #630

Run 39816487341 at source `3f1eb52a` and merge `a424196c` failed aggregation
on both attempt 1 and one failed-job-only retry: 450 `evidence-mismatch` rows.
The current attempt-1 endpoint still reported original shard job `119966794979`
as running, while attempt 2 exposed completed copied job `119991041684`. The
original receipt remained correctly bound to attempt 1. Running the existing
lineage resolver on those authentic observed rows chose the copied row as its
origin, which cannot satisfy that receipt. Original collection bytes were not
retained, so this reproduces the current contradiction rather than proving the
exact historical collection. This patch refreshes incomplete rows in every
collected attempt, including the original, while preserving original identities.
It was applied to PR #630 after the retry; native validation at the patched
revision is recorded separately. No additional unchanged-code retry was made.
