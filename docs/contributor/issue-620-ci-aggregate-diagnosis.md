# Issue #620: CI aggregation diagnosis

Observed on 2026-10-22 for [PR #630](https://github.com/aharada54914/sdd-forge/pull/630).
This concerns normal CI evidence collection, not recovery of the weekly audit.

## Failed attempt

[Run 39816487341](https://github.com/aharada54914/sdd-forge/actions/runs/39816487341)
attempt 1 tested source `3f1eb52a1ad766ed658d18dab589f9851a4af142` through
merge `a424196cca3d7e0c940a2d6b63aa2ac31c4d0034`. Required-checks job
`119985730082` failed with 450 `evidence-mismatch` results and null origins.
No nonaggregate job failure was observed.

The jobs endpoint still reported POSIX unwired shard (3), job `119966794979`,
as `in_progress`, with no completion timestamp. Its actual log ended in
successful tests and cleanup at 17:21:07 UTC. Receipt artifact `12445022365`
had already been uploaded at 17:21:06; its canonical job-name hash matched.
Windows lite job `119966795228` likewise remained nonterminal in the list,
although its log explicitly recorded lane success and cleanup at 17:29:05.

If collection saw the same stale POSIX row, the aggregator would omit its
execution origin because `completed_at` was absent. Its existing receipt would
then fail origin validation, producing the observed global mismatch shape.
This is a supported explanation, not proof of the original collection: that
attempt's raw observation files were not uploaded and cannot be reconstructed.

Original planner logs and subsequently observed run/PR metadata agreed on base
`07ed2e984ec58160892e765d7c437c47d5daf332`, source and tested merge. That initial
API-only comparison was insufficient: the retained plan and actual Git parents
subsequently established the mismatch described below.

## Bounded follow-up

After preserving the failed aggregate and contradictory metadata, exactly one
failed-job-only rerun was requested. Native assertions were not requested to
run again. Attempt 2, required-checks job `119991042077`, also failed at
17:53:13 UTC with 450 `evidence-mismatch` results at the same source and merge.
Its plan hash was `cd8f97fd89ca64697589a1cf0e6b75a70e6b28c5156978ee9ce3d40b0850aaf4`.
No additional retry was requested. A subsequently terminal latest-jobs list
does not establish what the collector saw in each historical attempt endpoint.
The repeated failure remains unresolved pending that distinction and plan
reconstruction checks.

The separately proposed metadata-refresh fix in [PR #632](https://github.com/aharada54914/sdd-forge/pull/632)
is absent from this tested source. Its validation and #620's weekly operational
acceptance remain separate. See the [execution plan](open-issue-execution-plan.md)
for subsequent findings.

## Historical endpoint reproduction and correction

Subsequent reads of `/attempts/1/jobs` still reported original jobs
`119966794979` and `119966795228` as nonterminal; `/attempts/2/jobs` returned
completed copied rows `119991041684` and `119991041982`. Applying the unchanged
`source_job` function to those actual rows selected copied shard ID
`119991041684` as the origin because the original row lacked its completion
timestamp. The original attempt-1 receipt could not match that origin. This
reproduces the current API contradiction without claiming recovery of the
historical collection bytes.

The existing PR #632 correction refreshes incomplete IDs across all historical
attempts, so it was applied to PR #630 at `f9b4b1cabbe6737ffe3e197675d428f93331ed81`.
No receipt IDs or attempts were relabelled; provenance validation remains strict.
The combined branch passed 89 collector and 54 planner tests and started a fresh
full CI run, [39827278860](https://github.com/aharada54914/sdd-forge/actions/runs/39827278860).

At 18:03 UTC, a credential-free read of the original job's individual endpoint,
including one `Cache-Control: no-cache` request, still returned `in_progress`
and no completion timestamp. Thus individual refresh is not demonstrated to
recover this particular historical row. It correctly remains a failure when the
individual endpoint also stays incomplete. The new run tests the patched source;
it does not repair, reinterpret or erase either failed historical attempt.

## Confirmed plan/Git mismatch (supersedes the incomplete diagnosis)

The patched run 39827278860 also failed: required-checks job `120014795895`
reported 450 `evidence-mismatch` rows at 18:39:45 UTC. All native jobs finished.
Current authentic job rows passed `validate_jobs` and all 44 executed noncontrol
jobs passed `execution_signature` / `source_job`; those current rows did not
reproduce a stale-origin exception.

The actual retained plan was downloaded from artifact `12448030235`. Its digest
was `43674a42e384a17b2c26a00cc7e259c58647080b7a6c6e85001a31f3dc0760ac`, with
`reason: binding-invalid`, API/event base `07ed2e98`, and tested merge `213e09a0`.
The Git object for that merge has parents `dadbe494` and `f9b4b1ca`, not the
plan's base/head pair. Rebuilding with the exact base planner and locked parser
produced a plan identical to the retained artifact. Calling the existing
`a9_activation` on that exact plan/tree raised
`ValueError: inconsistent PR A9 activation context` at
`tests/verification-workflow.py:435–439`. The aggregate's global failure is
therefore reproducible from retained inputs without recovering its old
observation directory or guessing about API timing.

The earlier tested merge `a424196c` likewise has parents `8818e33e` and
`3f1eb52a`, while its planning/API base was `07ed2e98`. Moving `work` while the
PR retained its original base snapshot was relevant; the earlier dismissal
based only on API metadata is withdrawn. The stale job observations were real,
but did not establish the primary cause. The refresh correction remains a
bounded, separately validated mitigation, not a repair for invalid plan identity.

Keep the strict mismatch rejection. Publish this diagnosis, then hold the base
branch fixed and create a fresh PR snapshot for the unchanged reviewed source.
Validate both event/API base and actual merge parents before admitting the new
run. A replacement PR is linked from #630 when created; its native result is
authoritative. Further progress documentation must use a separate branch while
that validation is in flight. Failed runs and their artifacts remain intact.
