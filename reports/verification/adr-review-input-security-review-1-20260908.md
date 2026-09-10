# ADR input contract — independent pre-implementation review 1

Ticket: RT-20260908-004
Reviewer: /root/adr_contract_security_review
Model requested: gpt-6-astra; reasoning high; fresh context
Scope: read-only design security/contract review, not a formal SDD gate
Verdict: NEEDS_WORK
Product changes applied: none

Independent findings (all require resolution before implementation):

1. Launch raw design-hash equality cannot be reused after Pending-to-Passed;
   preserve existing lifecycle normalization and verified re-review freshness
   rules. Do not tolerate omission or inconsistent A/B/precheck/contract pins.
2. Existing next-round prechecks require a changed design hash. Explicitly
   support ADR-only changes for ADR-bound prior rounds and still reject an
   unchanged full input set. Keep legacy design-only progress semantics.
3. Anchor and escape the canonical path regex and specify deterministic lexical
   handling of longer backtick spans, fences, indentation and escapes. Use
   shared expected extraction fixtures in Bash and PowerShell.

Additional conditions: extension presence agrees between precheck and contract;
ADR raw paths are validated before legacy relocation/normalization; PowerShell
checks every component's ReparsePoint attribute and Ordinal actual-name equality.
Identity-ledger hashes do not authenticate input manifests; do not claim they do.

Root disposition: incorporated explicit clauses for all findings in
adr-review-input-contract-plan-20260908.md. This is an author response, not an
independent PASS. Re-review and new ADR regression tests remain pending.
Existing baseline boundary suite passed 22 runtime cases plus 31 citation anchors;
that baseline does not test the proposed ADR correction.
