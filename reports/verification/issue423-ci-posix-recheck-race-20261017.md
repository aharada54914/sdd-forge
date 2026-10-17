# Issue 423: POSIX c2 completion race CI repair

The sections through "Final stable-source parent verification" preserve the
source-branch observations recorded with commit `021c1cde`, based on
`3bd33380`. Their runtime availability and test counts describe that source
environment, not the integration environment. Current integration observations
are recorded separately at the end of this report.

## Scope recorded before editing

Baseline `3bd33380ea35d00c6785ae764bdbb9713526c386`, clean, remote equal.
Run 39005610845: 35 successful checks; macOS job 117317673349 failed
`tests/cross-model.tests.sh` TEST-004(c2), gpt iteration 5, elapsed 3330 ms,
configured deadline 2000 ms, exit 1, no verdict; suite 75 passed / 1 failed.
The runner's timeout diagnostic preceded a stub JSON in the captured stream.
That stream is not evidence of a completed CLI: the stub still starts Python
after writing JSON, and its supervisor must then reap it and publish status.
No timing receipts for the failed iteration establish that those steps finished
before the real one-second settling re-check. Production failure is unproven.

Authorized scope: CI regression fixture only and this dedicated report. Preserve
production timeout, one-second settling, process-group termination, exit codes,
verdict requirements, frozen evidence, T-004 records and identity ledgers.
No real vendor CLI is invoked; all CLI paths in these tests are local stubs.

Contract references: `specs/epic-136-phase4-docs/acceptance-tests.md` TEST-004(c)
requires repeated successful completed-child re-checks, with every false timeout
failing; `requirements.md` Edge Case 6 requires checking completion after expiry.
The existing PowerShell c2 fixture coordinates actual child exit before the
observation rather than relying on scheduler luck (`tests/cross-model.tests.ps1`).

Plan: coordinate the existing POSIX observer at real expiry until the *real*
supervisor atomically publishes status; never fabricate time, exit codes or
status. Prove the original status/liveness re-check remains necessary using a
fixture-only mutation that removes it. Add nonzero/incomplete-output controls.
Missing receipts, bounds exceeded or unexpected results remain failures. This
is a test scheduling change, not a contract change or production RED claim.

## Repair and independent controls

Only `tests/cross-model.tests.sh` changes. Its existing Python launcher observer
records the real bounded-status location for this c2 case. At real expiry, the
date observer publishes the expiry receipt, then waits at most ten seconds for
that actual supervisor's atomically published exit status. It records the actual
status and returns the clock value it really observed; it does not write the
supervisor status, change time, increase the production timeout, or intercept
production sleep. This schedules child completion before the observation, like
the existing PowerShell debugger fixture. The original ten successful repeated
c2 cases, real process-death checks, JSON validation and receipt assertions stay.
Four added controls (both local stub families, nonzero exit and incomplete JSON)
require exit 1, no verdict, actual completed supervisor status, dead stub and no
false timeout diagnostic. Existing hung-child and signal-refusal tests continue
to prove actual wall-clock termination; c2 is not a wall-clock bound proof.

Conversation-isolated Codex reviewer `posix_c2_review` initially found a Major:
the observer's missing-status bound returned no clock, potentially causing
repeated numeric-comparison failures. The repair now returns the originally
observed real clock even on that bound, leaving the completion receipt absent
and letting production enforce expiry. This historical finding is preserved;
final independent review has Critical 0 / Major 0 / Minor 0 remaining.

Independent actual results:
- Full suite before the isolated missing-status correction: exit 0, 80 passed /
  0 failed (all ten c2 successes and four controls).
- Full copied-repository suite with only the production post-expiry status and
  liveness rechecks removed: exit 1, 66 passed / 14 failed. Every c2 success and
  negative control fails. This is a fixture-only mutation, not historical
  production RED and not an edit to the working repository's production files.
- Corrected actual observer extracted into a missing-supervisor-status fixture:
  enclosing assertions exit 0; returns numeric real clock in 9.185 seconds
  (integer-second ten-second bound), diagnostic present, completion receipt
  absent. No fabricated supervisor result is accepted.

An earlier exploratory parent suite was started before editing finished and
encountered a shell parse error while the source changed. It is excluded from
regression evidence. Only stable-source runs are accepted below.

## Final stable-source parent verification

- `bash tests/cross-model.tests.sh`: exit 0, **80 passed / 0 failed**, after
  the missing-status bound correction; all original checks retained.
- `bash -n tests/cross-model.tests.sh`: exit 0.
- `git diff --check`: exit 0.
- `git diff --exit-code -- plugins specs`: exit 0; production and canonical /
  frozen evidence bytes unchanged.
- No `pwsh`/`powershell` runtime is installed in this cloud environment. Native
  PowerShell observation is unavailable locally; its suite and production bytes
  are unchanged. Publication-head Actions results are separate observations.

Commit/push is user-authorized. No task status, T-004 plan/report, approval,
reservation, historic verdict, timeout value, protection or workflow changed.
The baseline failed CI is retained. A new exact-head CI is required; no rerun of
that failed run was requested or used to erase its result.

## Current integration verification

The test-only delta from `021c1cde` was applied to integration baseline
`f643a595`. The integration's zombie-state handling and independent process-state
regression remain byte-for-byte intact. Production scripts and the workflow
remain unchanged. PowerShell is available in this integration environment;
the source environment's earlier absence statement does not apply here.

- Integrated `bash tests/cross-model.tests.sh`: exit 0, **81 passed / 0 failed**,
  including the independent process-state regression, ten c2 success cases and
  four completed-child rejection controls.
- An isolated repository copy with only the production post-expiry status and
  liveness rechecks removed: exit 1, **67 passed / 14 failed**. Exactly the ten
  c2 success cases and four rejection controls failed; no unrelated failure was
  counted as evidence. The production working tree was not mutated.
- The actual date-observer body, extracted into a fixture with no supervisor
  status: returned the originally observed numeric clock in **9.16 seconds**,
  emitted the bounded-wait diagnostic and created no completion receipt.
- Shell syntax, whitespace checks and preservation of the integration-only
  process checks passed. Public report text was checked for local paths,
  personal information and credential values.

The integration CI for the preceding commit is not verification of this delta.
Exact-head CI after committing the change, including native platform jobs,
remains required before merge.
