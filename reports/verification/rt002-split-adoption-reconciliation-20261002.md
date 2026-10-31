# RT002 split-plan adoption reconciliation

This read-only audit corrects the earlier conclusion that the split plan still
requires the same human adoption. It changes no frozen artifact, approval,
status, identity reservation, or verdict.

The human supplied the successful output of the two-task adoption batch, then
the one-line Blockers-format batch. Current source-checkout hashes match that
chain:

| Artifact | Current SHA-256 |
|---|---|
| `specs/epic-189-a1-rt002-repair/tasks.md` | `1bd1d9a760d447783b6d10a38b1f8cfbf68567b31f9ef40ff72ce45172204395` |
| `specs/epic-189-a1-rt002-repair/traceability.md` | `0d19c24ab9d585f6649bdbc617ebace191d0c3d312a9f10f518b76784703e2b6` |

The initial adopted task hash was
`ca29e616c4f74aefa5df6f429f1c77a88cef671ae340a9a5b33474866f84c6bc`.
The follow-up changed only Blockers formatting and retained approval/status.
`reports/task-review/epic-189-a1-rt002-repair/attempt-2/round-2/`
contains the precheck binding and independent plan PASS for the current inputs.
The parent re-read the current hashes and review report; independent auditor
`rt002_delivery_audit_oct02` also checked the application scripts and precheck.

Consequently, the proposal/re-approval wording remaining in `tasks.md` is not
evidence that the documented human adoption did not happen. Do not request that
same adoption again. T-001 remains Approved/In Progress; T-002 remains
Draft/Planned and is not authorized by this reconciliation.

## Actual remaining delivery work

- Bind the current candidate to complete original-path regression evidence and
  installed activation/backup/restoration evidence. Old installed hashes or a
  fixture success cannot substitute for the current installed candidate.
- Complete the canonical T-001 implementation report, current spec revision,
  component coverage, and task-scoped evidence inventory. Existing preflight and
  historical failure records remain intact.
- Obtain the independent quality-gate decision through the permitted launch
  path. The refused sentinel probe must not be rerouted.
- T-002 approval, release acceptance, safe merge, and post-merge verification
  remain separate pending conditions. This note is not a quality-gate PASS.
