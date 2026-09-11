# PR381 cross-critique missing-field reproduction

Primary review and diagnostic execution, not an independent SDD gate verdict.
Target commit: `3971c93a5705dc15f86ba56cc62118613e4b19db`.
Issues #347 and #348 remain OPEN as confirmed by fresh GitHub body reads.

## Findings

1. Warning / acceptance gap: the schema describes `proposed_severity` as
   required for `PROPOSE-SEVERITY-CHANGE` but never requires that field.
   A proposal without its destination severity validates successfully.
   Evidence: `contracts/cross-critique.v1.schema.json`, `definitions.verdict_record`
   required list and conditional; the only conditional requires basis evidence.
   The existing prompt asks for a destination, but consumers cannot rely on
   schema validity to establish its presence. This does not prove that a
   persisted gate verdict has actually been changed incorrectly.

2. Warning / acceptance gap: `definitions.scope.required` contains only
   `assessment`, and `evidence` is an unconstrained optional string. All three
   assessments validate without scope evidence; an empty evidence string also
   validates. Issue #348 requires scope evidence to reference a reviewed
   artifact by file:line or ID. Its prompt supplies that field, but the schema
   does not enforce it. A requirement ID on an in-scope object may independently
   convey useful evidence; that does not make the wholly unsupported out-of-scope
   and unclear objects valid evidence of the required scope determination.

No Critical security/data-loss claim is made. Both are concrete validation
gaps to resolve before claiming the issues' acceptance conditions are complete.

## Reproduction

Run through `rtk proxy node -e` in the PR381 recovery checkout. Ajv was loaded
from the existing ci-mcp dependencies using the committed driver's settings
(strict mode, strictRequired/strictTypes disabled, format validation disabled).
The unchanged schema was read using `git show` at the pinned commit. An exact
endpoint diff confirms the recovery checkout's schema, reviewer prompts and
committed contract-test driver have no changes relative to that commit.

Base verdict:

```json
{
  "target_finding_id": "A-1",
  "critic_role": "reviewer-b",
  "verdict": "PROPOSE-SEVERITY-CHANGE",
  "proposed_severity": "Major",
  "basis": {
    "kind": "code_evidence",
    "citations": [{"path":"src/example.ts","line_start":1,"line_end":2,"claim":"observed condition"}]
  },
  "scope": {"assessment":"in_scope","related_requirements":["REQ-1"],"evidence":"REQ-1"}
}
```

Wrap in a complete `cross-critique.v1` annex with round_id `probe`, timestamp
`2026-09-09T00:00:00Z`, and a one-element verdicts array. Mutation checks
independently remove the severity destination; replace scope with each bare
assessment (retaining REQ-1 for in_scope); or set evidence to the empty string.
The negative controls replace basis with concern for PROPOSE-REJECT, use an
unknown basis enum, omit all IDs on in_scope, and add an unexpected record key.
No schema, gate, test file, frozen artifact, or verdict was modified.

Full output, exit 1:

```text
PASS: complete severity proposal; expected=true actual=true
FAIL: missing severity destination rejected; expected=false actual=true
FAIL: in_scope missing scope evidence rejected; expected=false actual=true
FAIL: out_of_scope missing scope evidence rejected; expected=false actual=true
FAIL: unclear missing scope evidence rejected; expected=false actual=true
FAIL: blank scope evidence rejected; expected=false actual=true
PASS: concern cannot reject; expected=false actual=false
PASS: unknown basis rejected; expected=false actual=false
PASS: in scope without IDs rejected; expected=false actual=false
PASS: extra record key rejected; expected=false actual=false
SUMMARY 5 passed; 5 failed; pinned=3971c93a5705dc15f86ba56cc62118613e4b19db
```

This is an actual current validation failure against the stated expectations,
not a five-case regression suite that passed and not a product implementation
attempt. Timestamp formats and real artifact reference resolution were not tested.

## Next repair scope

Require a canonical proposed severity for severity-change verdicts. Align the
scope producer/contract on a nonempty, review-artifact-bound evidence reference,
cover all three assessments with positive/negative fixtures, and preserve the
existing no-auto-disposition/no-direct-Done-reopening boundaries. A syntax-only
check cannot establish that an artifact or referenced line actually exists;
the specification must define where that resolution occurs.

Do not silently repair under an invented task: the main checkout currently has
no `specs/review-cross-critique/tasks.md` (the scoped search returned missing-file
exit 2). Restore the actual governing approved contract/task, or draft and
review the necessary task before production edits. The earlier broad issue work
authorization does not make a nonexistent/Draft task Approved.

The separate RT-20260909-001 POSIX contract amendment remains awaiting explicit
human approval. No commit, push, merge, issue closure, or task status change.
