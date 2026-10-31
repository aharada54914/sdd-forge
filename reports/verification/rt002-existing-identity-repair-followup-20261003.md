# RT002: existing identity repair reuse assessment

The existing Issue 423 recovery fixes the same contract contradiction: the
review ledger reserves reviewers, while implementation identity is established
by a hash-bound `task-input-manifest/v1` and its implementation report. It
rejects identity reuse rather than inventing an implementation ledger record.

On 2026-10-03 the coordinator executed the existing
`reports/verification/issue423-quality-launch-reserve-fixture.sh` in the Issue
423 owner worktree. Exit 0: all 14 negative cases passed in both Bash and
PowerShell; pinned archive authorization and normal reservation controls passed
in both shells. The script used disposable ledgers, not the production ledger.
This proves those fixture paths in that checkout, not RT002 adoption or review.

RT002 still lacks a matching fresh implementation handoff manifest and canonical
`reports/implementation/epic-189-a1-rt002-repair/T-001.md` report. Its historical
flat report must remain historical evidence, not be relabeled as a new run.
The smallest next repair is to reuse the existing paired validator/contract
change, then perform an authentic isolated implementation continuation and
report supersession before independent evaluation. Issue 423's hash-pinned
human apply commands target that checkout only; they must not be reused against
different RT002 bytes. No validator, ledger, verdict, or task status was changed
by this assessment.

## Candidate audit and caller migration check

The six-file `rt002-shared-launch-repair-candidate-20261003.patch` is NOT ready
for adoption. Its textual apply check passed, but it omits the existing Issue
423 migrations for `tests/review-agent-isolation.tests.sh` and
`tests/review-scratch-history.tests.py`.

Observed on 2026-10-03 using disposable fixture repositories:

- RT002's old scratch-history driver against Issue 423's current validators:
  exit 1, PASS 0 / FAIL 26. Both runtimes reported
  `REVIEW_CONTEXT_IDENTITY: new evaluator requires a pinned implementation manifest`.
  The negative cases also fail because they do not reach their intended path check.
- Issue 423's migrated scratch-history driver against those same validators:
  exit 0, PASS 26 / FAIL 0, including the snapshot and refusal assertions.

This is a caller migration requirement, not permission to remove assertions.
An independent read-only audit also identified that the shared change is outside
RT002 T-001's three-source-file scope and broadens evaluator input authorization
to paths pinned by the implementation manifest. The latter boundary needs
explicit review, including a manifest-pinned private-path case. Do not apply this
candidate or reserve an RT002 evaluator based on the earlier apply check alone.
Historical implementation identities and reports remain unchanged.

The two existing caller migrations are preserved separately in
`rt002-shared-launch-caller-migration-candidate-20261003.patch`. A combined
`git apply --check` of both candidates exited 0. Neither candidate was applied;
this resolves the extraction omission only, not scope or input-boundary review.
