# RT004 PowerShell saved reviewer output candidate

Status: partial unapplied patch DATA; not Implementation Complete or PASS.
Governing plan and protection boundary remain unchanged.

Candidate: `adr-workflow-powershell-output-binding-candidate-20260909.patch`
SHA-256: `7de693bcc2b83168c02252b47d812882d6cc50794a6bfd08222815baba93695f`.
`git apply --numstat` exits 0, reporting 116 additions and no deletions.
This proves patch format only, not applicability, PowerShell parsing or runtime
behavior. No candidate function was extracted, applied, copied or executed.

## Implemented candidate slice

`Test-AdrHistoryOutputs` checks contract/integrated identity, distinct A/B
reservation run and session IDs, exact actual output identity against each
reservation, canonical schema/stage/role, nonempty unique check IDs, valid
case-exact result/severity vocabulary, per-reviewer verdict, aggregate counts
derived from both actual outputs, and integrated verdict including the existing
round-3 Minor-only PASS-with-warnings rule. Critical still yields BLOCKED.
It returns A's ID set and result counters for a subsequent summary binding.

Field names and string comparisons are Ordinal. Hash sets use Ordinal identity.
Numeric matching rejects null, bool and string coercion. Hashtables are only
indexed after case-exact vocabulary validation. Array field returns preserve
empty/singleton arrays using the existing PowerShell 5.1-compatible approach.

Root static review compared these checks with the Bash candidate's review and
integrated aggregation predicates. No Critical finding in this bounded slice;
the initially named local variable was changed to `exactProperties` to avoid
PowerShell's automatic Matches variable. This is not independent review.

## Remaining mandatory work

- Current and previous summary shape and A-output counter/ID correspondence.
- Safe strict JSON snapshots and complete caller integration, including
  pre-opening validation before the existing early return.
- Current declaration lexer/hash verification and complete coherent assembly
  with core, manifest and shared-layer candidates. Existing insertion slices
  share an anchor and must not be concatenated as independent applied patches.
- Full independent security/contract review, then human application and real
  regression execution, including native Windows where required.

The existing original PowerShell validator remains at SHA-256
`7a4663e154e7877362d43916087986849dd7625121d5c058332d3e27eb7b2644`.
The last runtime baseline is still 6 passed / 16 failed, documented in
`rt004-output-binding-red-20260909.md`. Do not claim this candidate fixes those
failures until the corrected complete consumer actually executes successfully.
No review verdict, task state, PR or issue state was changed.
