# PR #390 / #394 Windows CI observation

Observed: 2026-09-09T13:01:46Z. Read-only GitHub inspection; no rerun, branch
update, commit, push or merge was performed.

- PR #390: 23 successful checks, Windows test and required-checks failed.
  Run 34008982110, Windows job 101421310980:
  https://github.com/aharada54914/sdd-forge/actions/runs/34008982110/job/101421310980
  Cross-model suite: 56 passed, 8 failed. All eight reported failures were
  TEST-004(c) near-boundary completion: GPT iterations 1–5 and Gemini
  iterations 2, 4, 5. Each reported exit=1, verdict=0, budget_ms=2000.
- PR #394: 23 successful checks, Windows test and required-checks failed.
  Run 34023439393, Windows job 101460103174:
  https://github.com/aharada54914/sdd-forge/actions/runs/34023439393/job/101460103174
  Cross-model suite: 62 passed, 2 failed. TEST-004(c) Gemini iterations 4
  and 5 reported exit=1, verdict=0, budget_ms=2000; stub launch measurements
  were 978 ms and 729 ms respectively.

These are recorded failure locations, not a proven root-cause diagnosis.
The local modified tests/cross-model.tests.ps1:644–714 now contain stage timing
and safe diagnostic output. Prior PR400 observation at
reports/verification/pr400-ci-stage-observation-20260906.md:125 records ten
successful boundary measurements on a different run; it does not erase these
failures or prove either dependency branch is currently valid.

Next: finish the approved recovery/provenance path, reconcile the exact
reviewed PR400 changes with each dependency head, then run every mandatory
check on the resulting head. Do not waive boundary tests or use review-approval
admin bypass to bypass CI. Recovery-entry restrictions remain in effect.

