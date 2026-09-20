# Issue350: three structural pilot records

These are one preserved historical record and two new standalone pilots, not
three new runs or formal SDD gate approvals. All use
`adversarial-review-evaluation.v1`. Paths below are beneath
`reports/adversarial-review/`, with `/evaluation.json` appended.

| Pilot directory | Launches | Phase1 findings | Adopted after synthesis | Phase R |
|---|---:|---:|---:|---|
| feat-adversarial-review-enhancements | 2 | 5 | 5 | not run, reason recorded |
| fix-pr402-guard-mirrors | 2 | 0 | 0 | unnecessary: no fixes |
| fix-issue-289-traceability | 3 | 2 | 1 | one consolidated fix verified |

The original record is unchanged, including its unresolved PhaseR note and
fresh-fallback continuation. New runs resumed both reviewers. Duplicate
PR407 findings were consolidated, not counted as two repaired bugs.

## Validation actually executed

PowerShell `Test-Json -SchemaFile
contracts/adversarial-review-evaluation.v1.schema.json` accepted all three
records. Node/Ajv accepted both new records. `jq` and PowerShell
`ConvertFrom-Json` independently selected the same fields and produced the
following identical compact JSON lines, in this order:

```json
{"slug":"feat-adversarial-review-enhancements","launches":2,"phase1":5,"adopted":5,"phase_r":false,"tokens":null,"duration":null}
{"slug":"fix-pr402-guard-mirrors","launches":2,"phase1":0,"adopted":0,"phase_r":false,"tokens":null,"duration":null}
{"slug":"fix-issue-289-traceability","launches":3,"phase1":2,"adopted":1,"phase_r":true,"tokens":null,"duration":null}
```

Historical telemetry fields are absent; the comparison renders absence as
null without rewriting history. Each new record explicitly stores null and
an unavailable reason for total tokens. No complete-run clock was captured;
duration is null, never an estimate or zero. No performance or cost-saving
claim follows from these structural observations.

## Integrity and limitations

Externally captured publication hashes (also held in the task checkpoint):

- PR402 report SHA256:
  `1d04c303a1de274cf30b3a0ea39bb8a9dd3e806a62180f99b4e0e020d273d6c9`.
- PR407 report SHA256:
  `352a160ecf2de7a64b47a849482bebfbec20753f8f0ea6cdca8b2c7085f43c37`.

PR402's report passed the existing currentness checker against the target
worktree and that independently held hash. PR407 deliberately retains its
original reviewed SHA after a separately verified fix; it must report stale
against the new HEAD. Neither report uses SDD identity-ledger reservations.
PR407 has explicit Issue-based scope but no invented REQ IDs; canonical
per-finding scope-schema compliance is not claimed. These limitations are
not erased by evaluation-schema validity.

This addresses the three-record comparison and reader-parity evidence gap.
It does not prove automatic triggering on every host, make metrics control
verdicts, authorize protocol promotion, replace required GitHub approval, or
close Issue350 before merge and main verification. Existing dependency and
triggering tests remain required; older failures and records are retained.
