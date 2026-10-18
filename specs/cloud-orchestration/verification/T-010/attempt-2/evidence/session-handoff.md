# T-010 continuation handoff (attempt 2)

Implementation remains incomplete. No task status, approval or gate changed.
This session stops under implement-task implementation-policy.md and
agent-delegation-policy.md: compaction requires a persisted handoff and stop.

## Implemented candidate

Shared cloud_dependencies provides provider-independent bounded artifact acquisition,
protected original verify-producer authentication, fresh reducer replay, exact
consumer/request/unit/profile/provider bindings, deterministic graph ordering and
per-unit dispatch. Both provider governed modules delegate acquisition to shared code.
WriteBoundary requires admission at entry and immediately before write, then final
consumer metadata and local binding/expiry/freshness checks. Read-only verify policy
cannot be used as a write policy. Empty predecessor defaults remain intact.
No new signing authority, generic IaC engine or automatic resource rollback.

## Genuine chronological evidence

- Initial scoped verification: 78 run, zero failures, one PowerShell-unavailable skip.
  Historical preflight's reference to a schema-tool skip is superseded here.
- f1e8bf62 recorded initial Red; some setup errors meant it was not exhaustive.
- 499c15f3 recorded corrected per-field Red before production: 99 config/producer
  variants, consumer request/trust omission/addition, graph tests, and exact unchanged
  reducer cases named in preflight.md. Existing boundary blanket denial was genuine
  behavioral Red, not successful field validation. Graph absence remains component Red.
- Post-implementation field matrix and matched controls execute in current tests;
  guard-removal sensitivity is scoped in test_guards_are_sensitive_not_blanket_denial.
- cross-provider.log: AWS predecessor to Azure and Azure predecessor to AWS, both
  prepare/apply, foreign scope/provenance denials and restored controls: passed.
- final-boundaries.log: consumer revocation during second acquisition, guard sensitivity,
  standalone provider import/render: three tests passed. Synthetic protocol only.
- critical tests cover acquisition advancing time, reviewer stable ID, physical temp
  root, read-only verify policy and repeated write admission.
- three-unit-final.log: A/B/C isolated test passed. HOWEVER verification-final.log
  supersedes any global-green claim: 104 run, one failure, one skip. The A/B/C test fails
  at B case.prepare(), which returns AZURE_EXECUTION_BLOCKED. Root cause is not yet
  diagnosed. Do not claim A/B/C preservation across the full scoped suite until fixed.
- Ruff passed before last fixture annotation corrections; final-config mypy passed
  six files. Final static rerun remains required after any repair.

## Next session work

1. Read task, this report, initial manifest/snapshot and actual current code afresh.
2. Diagnose full-suite A/B/C B-prepare failure (verification tests line ~5085 calling
   execution fixture prepare line ~1029). It passed isolated. Check fixture/global/mock
   isolation and actual exception; do not weaken admission or assertions to make green.
3. Rerun offline full scoped verification plus needed execution/admission, routing,
   contracts regressions; NOT whole repository suite. Existing runner guards parent
   urllib and Python CLI children and exercises sentinel. No real cloud requests.
4. Run Ruff/mypy with tests/shared-launch-python/pyproject.toml explicitly and MYPYPATH
   set to quality-loop:azure-cloud:aws-cloud scripts as required by caller.
5. Perform exact disposable-checkout rollback experiment with initial dirty candidate
   bytes, not only git HEAD. No resource rollback. This experiment is NOT DONE.
6. Write concrete T008 owner configuration addendum: explicit predecessor trust pins,
   protected original workflow/run/job/code/profile scope, immutable artifact digest,
   read-only verification policy and access prerequisites. Newly reachable AWS verify
   job and Azure read-only verify policy have synthetic tests only; first live CI run
   remains pending. Missing sandbox remains live BLOCKED.
7. Refresh report outputs/hashes and manifest/report validation. Root owns final gate,
   task statuses, full suite, release. No push/tag/merge.

## Preserved paths and commands

Scratch root: /tmp/cloud-T010-01a14f3e-b525-78c0-9d78-d79635e2a5de
Initial inputs: scratch/snapshot, mapping evidence/initial-input-map.json.
Do not rerun snapshot.py (would overwrite initial inputs), implement.py or old report.py.
Evidence runner: python3 -B specs/cloud-orchestration/verification/T-010/attempt-2/evidence/run-scoped.py tests/cloud-orchestration-verification.tests.py
Initial base: f2d51e4a2d4b2c2f440222351684f3162ec88fc4; later commits are scoped Red only.
Historical setup/error logs are retained, not mislabeled Green. No raw transport logs
are public report outputs. No running test process remains at this handoff.
