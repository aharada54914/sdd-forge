# RT002 provenance recovery preparation — 2026-10-04

Status: candidate prepared, not applied; no formal gate verdict.

## Current review target (2026-10-04 clarification)

Do not review or apply the eight-file patch below as the complete repair.
`binding-followup-review.md` records subsequent corrections: the final
`binding-followup-integrated.patch` (SHA-256
`2b0fff67fbc907cf62a947fc887f7b776c26655e77a35535b093047b41997087`)
applies to the eight-file patch's proposed bytes. Review both patches together
and verify the intermediate hashes against `candidate-hashes.json` and
`binding-followup-hashes.json`. The follow-up preserves report-based source
authorization while fixing manifest binding and preflight validation. Its
recorded isolated results are not application or formal gate evidence.
The ordered work below therefore refers to the combined repair, not the
superseded eight-file-only candidate. No protected application is recorded.

## Completed in this run

- Preserved the existing canonical report by copying its exact bytes into
  `canonical-report-before-recovery.md`. Both hashes are
  `f3c151a105a1d0b1d0c90fb050f63a8b81005596d9484d95e158cb0490067533`.
  The former canonical path is recorded in `candidate-hashes.json`.
  No old report, historical handoff, task status or ledger was rewritten.
- Created `shared-launch-auth-preserving.patch` against the current RT002 owner.
  SHA-256: `df4578aba6b540b6e6d8156877a7311d2e090080837cc10ff68b58ff9e004404`.
  All eight before/after hashes are fixed in `candidate-hashes.json`.
- The candidate exactly matches the current #423 reference files, re-diffed after
  hashing. This is a new candidate; the two older 20261003 candidates remain
  historical and must NOT also be applied.
- `git apply --check` on this candidate: exit 0, no output, no application.
- Reference Bash validator syntax check: exit 0. No candidate behavior was executed.
- RT002 `git diff --check`: exit 0. Untracked candidate files are not covered by
  that command; textual patch applicability above is separately checked.

## Boundary preserved

The candidate admits the pinned implementation manifest itself but does not use
its allowed_inputs as evaluator authorization. Both runtime implementations retain
Outputs / Post-Fix Artifacts as the authorization source for source/test inputs.
The now-unused declaration helper definitions remain to keep an exact bounded
transfer of the reference repair; this preparation does not claim dead-code cleanup.

The eight-file candidate includes both existing caller migrations
(review-agent-isolation and review-scratch-history), the behavioral regression
driver, and line-reference updates. Splitting the tests away from the contract
change would leave incompatible fixtures, so this run prepared a coherent batch
instead of prematurely modifying live callers.

## Remaining ordered work

1. Independently review this exact candidate and hashes as the shared launch
   prerequisite repair. It is not the RT002 three-file production repair itself.
   Apply any protected member only via its permitted human application path;
   no refusal may be rerouted. Recheck all before hashes immediately beforehand.
2. After permitted application, verify all proposed hashes, then run the existing
   original-path issue311-scratch-isolation, review-scratch-history,
   review-agent-isolation and review-context-boundary suites in this owner.
   Prior #423 successes are reference evidence, not RT002 regression results.
   Do not rerun the previously hook-refused isolated experiment by another route.
3. Launch a fresh isolated implementation revalidation context, with real observed
   identity, a new task-input-manifest/v1 and canonical absolute scratch root.
   Pin current specs, original three implementation/test files and needed evidence
   BEFORE the revalidation. The current canonical report's report-assembly run
   and relative scratch declaration cannot be relabeled as that new execution.
4. Revalidate the T-001 scope using required original-path checks and truthful
   current results. Keep original historical RED/activation records distinct from
   newly executed results. Do not invent an implementation ledger reservation.
5. Create a NEW report outside the canonical path. Declare archive path/hash in
   Outputs if the evaluator needs it; pin manifest and report task/run/session.
   Independently compare archive and new report hashes before canonical adoption.
6. Only then prepare and reserve the independent evaluator according to the
   resulting owner launch contract. Recheck actual installed capabilities and
   keep current CI, native activation, formal review and Done distinct.

## Conditions already resolved / still open

The three formerly missing Must Read files exist. The T-001 scoped traceability
check previously rerun in this audit passed for five links; T-002 release-only
requirements remain outside that artifact. These do not repair provenance.

Current owner launch rules still lack the recovery mechanism, and current report
still lacks a valid fresh input-manifest/absolute-scratch execution binding.
No fresh run, reviewer reservation, independent acceptance, installed update,
CI result, canonical replacement or Done is asserted here.
