# Issue 388: branch ownership and remaining runtime correction

Date: 2026-09-08
Disposition: open; investigation only, no implementation or approval change.

GitHub issue 388 identifies WFI-062 and remains OPEN. Its acceptance requires
an investigation-only round transition, unchanged-input rejection, a mutation
check, unchanged calibration coverage, and follow-up measurement over three
amendment-triggered attempts. Proposal audit completion is not implementation.

The proposal file is absent from the root working tree. Reading the exact
PR 245 head `54b1ff247081971e0560cf20d45f4369e01b5c0d` locates it at
`docs/workflow-improvements/WFI-062.md`, with `Status: Draft` and
`Audit-Status: Human-Pending`. Commit `798841e9` records the completed proposal
audits; `git branch -a --contains 798841e9` identifies the existing remote
`origin/feature/epic-193-a5-capability-resolver`. Do not create a duplicate
proposal or assume the missing root file means no existing work exists.

Current source confirms the still-unresolved mechanism:

- `plugins/sdd-review-loop/scripts/spec-review-precheck.sh:343` reads the
  prior requirements hash; line 344 reads acceptance; lines 345-346 reject
  when those two are unchanged, regardless of investigation changes.
- Lines 284-285 explicitly document that the precheck schema has no
  investigation hash. Lines 286-296 inspect optional reviewer investigation
  pins for agreement, but this is not the round-transition predicate.
- Line 227 enforces an exact contract key set. Consequently adding a hash
  field and changing only the transition disjunction is not sufficient:
  producer and all contract consumers must agree on the extension, including
  historical evidence semantics and PowerShell parity.

Next implementation work must follow the WFI approval and protected-file
workflow. Existing audit records and historical review contracts must remain
intact. No runtime regression was executed in this read-only triage; the
source observations are not a passing behavioral test. PR 245 integration
alone does not establish issue 388 completion or authorize closure.
