# PR371 to PR381 acceptance audit

Date: 2026-09-08
Disposition: unresolved acceptance gaps; not a formal quality-gate verdict.

Read-only review compared PR371 `9e39c396f4ca8f9abe3c9aabb090868ada17b53f`
with PR381 `3971c93a5705dc15f86ba56cc62118613e4b19db` and read the live
acceptance criteria for issues #345–#350. No implementation was changed and
no test was executed by this audit. Existing FAIL records remain unchanged.

## Major: #349 report integrity is not implemented by the schema hardening

At the PR381 endpoint, `contracts/adversarial-review-report.v1.schema.json`
requires commit IDs, diff digest, reviewer IDs, creation time and skill version,
but omits `report_sha256`. Its `additionalProperties: false` at line 16 also
rejects adding that field to an otherwise valid instance. Issue #349 explicitly
requires this field and rejection of report-body/digest mismatch.

The `x-stale-judgement-rules` at schema line 66 describe head/base/diff mismatch;
they are annotations, not executable currentness checks. In
`tests/adversarial-review-contracts.tests.mjs:27`, the keyword registration has
no validation function. The report tests at lines 80–92 validate shape and
reject abbreviated commit IDs and array-shaped reviewer IDs. They do not
exercise a changed HEAD, changed merge base or tampered report body against
current repository metadata. Therefore these schema tests cannot prove #349's
currentness or content-integrity acceptance criteria.

Required next work: reconcile an approved contract/task for the report digest
(including a defined non-self-referential hashing boundary), its producer and
consumer, plus HEAD/base/body-tamper negative fixtures and a matching positive
fixture. Do not invent a digest convention, mark the historical report current,
or close #349 on the strength of schema validation alone.

## Other acceptance boundaries

- #345: `specs/review-cross-critique/requirements.md:3` at this endpoint still
  says `Spec-Review-Status: Pending`; the issue requires Passed. Documentation
  presence is not evidence that the formal review condition is satisfied.
- #346: the endpoint contains one report/evaluation pair under
  `reports/adversarial-review/feat-adversarial-review-enhancements/`.
  `evaluation.json` calls itself Run-003 but records `phase_r.ran: false`.
  This pair alone does not establish the required three-run comparison matrix,
  verified non-findings and human disposition on standalone/plugin/retirement.
  This is an evidence limitation, not a claim that other evidence cannot exist.
- #347/#348: cross-critique schema changes add evidence/concern constraints
  and canonical scope-ID restrictions. Their presence is useful but not proof
  of all-host validator parity, unchanged blind inputs, or the required
  ticket-to-quality-gate route for adopted fixes. Those remain verification work.
- #350: evaluation-schema conditional constraints were strengthened. The
  inspected historical record is not a fresh non-trigger/trigger/unavailable
  execution matrix or proof of Bash/PowerShell parity and unavailable-cost
  null-plus-reason handling. Do not equate shape checks with those executions.

## Integration consequence

The six changed artifacts preserve and harden parts of PR371, but the inspected
PR381 endpoint does not establish completion of all six issues. PR371 is not
an ancestor of PR381, and the relevant Windows test/runner files are unchanged
between endpoints (see `pr371-mcp-failure-mapping-20260908.md`). Neither PR
should be closed as fully superseded or merged based only on this comparison.
No commit, push, merge, issue closure, or historical evidence mutation occurred.
