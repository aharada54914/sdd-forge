# Issue #620: CI aggregation diagnosis

The repeated aggregate failure on [PR #630](https://github.com/aharada54914/sdd-forge/pull/630)
is reproducible from a retained plan whose PR base differs from the actual tested
merge parent. This concerns normal CI; recovery of the weekly audit remains a
separate acceptance condition. All observations below are from 2026-10-22.

## Confirmed cause and replacement

Patched run [39827278860](https://github.com/aharada54914/sdd-forge/actions/runs/39827278860)
failed required-checks job `120014795895` at 18:39:45 UTC with 450
`evidence-mismatch` rows. Its retained plan (artifact `12448030235`, digest
`43674a42e384a17b2c26a00cc7e259c58647080b7a6c6e85001a31f3dc0760ac`)
recorded `reason: binding-invalid`, API/event base `07ed2e98` and tested merge
`213e09a0`. That merge's actual Git parents are `dadbe494` and source `f9b4b1ca`.

Rebuilding with the exact base planner and locked parser produced a plan
identical to the retained artifact. Calling the existing `a9_activation` on that
plan/tree raised `ValueError: inconsistent PR A9 activation context` at
`tests/verification-workflow.py:435–439`. This reproduces global rejection
without recovering the original observation directory or assuming API timing.
Current authentic job rows passed `validate_jobs`, and all 44 executed noncontrol
jobs passed `execution_signature` / `source_job`; those current rows did not
reproduce a stale-origin exception.

Earlier run `39816487341` tested merge `a424196c`, whose parents likewise were
`8818e33e` and source `3f1eb52a`, despite its planning/API base `07ed2e98`.
The initial API-only comparison had incorrectly dismissed base movement. Actual
Git parents establish that moving `work` while the PR retained its old base
snapshot was relevant. The stale job observations below were real, but did not
establish the primary cause. Strict provenance rejection was preserved.

[PR #634](https://github.com/aharada54914/sdd-forge/pull/634) replaces #630 with
unchanged source `f9b4b1cabbe6737ffe3e197675d428f93331ed81`. Its run
[39834531255](https://github.com/aharada54914/sdd-forge/actions/runs/39834531255)
uses fixed base `913573ca795b55a1c69b7762eb8e03169fa6aaea` and tested merge
`9d5b822f0f54f2084af75a1e6c4b50207cdbff05`, whose parents are exactly that
base and source. Actual plan artifact `12450830707` has reason `shared-change`,
450 obligations and digest
`8290214306a7755df6c2f689ceaa340ce97002ef259e56287b0fa9b217eb094c`.
The existing A9 activation function on the exact plan/tree returns `False`
(expected inactive), without the old context exception. Corrected binding alone is not test acceptance.

`work` stays fixed during validation. Progress is published separately on
`docs/issue-execution-results`. PR #630 is closed without merging and links to
#634; failed runs and artifacts remain intact. The
[compact reproduction record](issue-620-ci-plan-binding.json) preserves actual
plan file hashes, Git parents and old/new A9 function outcomes.

## Replacement attempt and targeted recovery

Replacement attempt 1 failed required-checks `120038874571` at 19:28:41 UTC:
446 PASS, one expected skip and three `evidence-missing` failures, all for
Windows MCP installer obligations (guard invariants, installer and Claude
registration). Verified rows all originate in attempt 1. This is distinct from
the old global mismatch: the corrected plan admitted and verified 446 rows.

The original Windows job `120019471372` still had no completion timestamp in
both list and individual-job API observations at 19:30:16 UTC, despite its
successful native integration log at 18:50:32 and final step at 18:50:56.
Those logs do not replace a completed execution origin. The aggregate failed
closed; original collector observations and exact refresh responses were not
uploaded, so later snapshots cannot establish their exact bytes.

The job-specific re-run API accepted a request to execute that Windows MCP
job again, including its dependent aggregate. This obtains a new genuine
execution rather than rewriting the old row or retrying only unchanged
aggregation. All other passing native suites and the frozen base/source remain
unchanged. Attempt 2 passed at 19:34:32 UTC, required-checks `120042008239`:
**449 PASS and one expected skip**. Exactly 446 verified obligations retain
attempt-1 origins; the three Windows MCP obligations use genuinely re-executed
job `120040903474` from attempt 2, completed at 19:33:13 UTC. Base, source,
tested merge and original plan digest stayed unchanged. No copied attempt-2
row was used as a new origin for other executions. The first aggregate and
metadata snapshots remain preserved separately from the successful result.

PR #634 is ready for review. PR #632 is closed without merging as superseded;
its identical collector code/tests are included in #634. PR #629 remains the
separate encoding fix. No Issue was closed and no PR was merged.

## Separate stale-metadata finding

Run [39816487341](https://github.com/aharada54914/sdd-forge/actions/runs/39816487341)
attempt 1 tested source `3f1eb52a1ad766ed658d18dab589f9851a4af142` through merge
`a424196cca3d7e0c940a2d6b63aa2ac31c4d0034`. Required-checks `119985730082`
failed with 450 mismatches and null origins; no nonaggregate job failure was
observed. The jobs endpoint reported shard `119966794979` as `in_progress`
without a completion timestamp, although its log ended successfully at 17:21:07
UTC and receipt `12445022365` was uploaded at 17:21:06 with the matching job-name
hash. Windows lite job `119966795228` had the same discrepancy despite its
successful lane log and cleanup at 17:29:05.

Exactly one failed-job-only rerun was requested after preserving the discrepancy;
native assertions were not requested to run again. Attempt 2 required-checks
`119991042077` failed at 17:53:13 UTC with the same 450 mismatches, source and
merge. Its plan digest was
`cd8f97fd89ca64697589a1cf0e6b75a70e6b28c5156978ee9ce3d40b0850aaf4`.
No further retry of that run was requested.

Subsequent historical endpoint reads still showed the original two jobs as
nonterminal, while attempt 2 returned completed copied rows `119991041684` and
`119991041982`. Applying unchanged `source_job` to those actual rows selected
copied shard ID `119991041684`; the original attempt-1 receipt could not match
that origin. This reproduces a current API contradiction, not the unavailable
original collection bytes. Raw observations from those attempts were not
uploaded. At 18:03 UTC even an individual-job request, including one credential-free
`Cache-Control: no-cache` read, still reported the original shard as incomplete.
Individual refresh is therefore not demonstrated to recover that historical row.

## Bounded metadata correction and validation

[PR #632](https://github.com/aharada54914/sdd-forge/pull/632) adds a refresh of
observed incomplete jobs across historical attempts under one shared 60-second
deadline. Individual responses must match the original job/run/attempt/head/name.
Terminal failures and the collecting aggregate are excluded. It does not infer
completion or relabel receipt identities, and remains fail-closed if the endpoint
stays incomplete. The correction was included in source `f9b4b1ca` before the
failed run `39827278860`; it cannot repair invalid plan identity.

Both the original correction and combined branch passed 89 collector and 54
planner tests. PR #632 native run
[39820601216](https://github.com/aharada54914/sdd-forge/actions/runs/39820601216)
attempt 1 passed at source `232e940f03b50b5611dd9b36f9bb5bb25e3bc1d1`, tested
merge `e2da7032b950b692d40cd1769ebb5ed39f3e418e`: 448 verified obligations plus
one expected skip, with execution origins from attempt 1. This validates the
patched collector overall; it does not prove the refresh branch was exercised
in that run or retrospectively repair failed historical evidence.

See the [execution plan](open-issue-execution-plan.md) for the replacement run's
final result and remaining genuine request/adoption prerequisites for weekly audit
recovery. Normal CI success alone cannot close #620.
