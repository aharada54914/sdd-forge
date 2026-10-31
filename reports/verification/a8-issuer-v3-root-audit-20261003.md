# A8 issuer v3 candidate audit

Scope: direct inspection of the complete v3 native-apply patch and its author
sweep. This is not a formal review verdict or permission to change frozen files.

The candidate separates A1 challenge generation from A8 ledger issuance,
preserves the existing signature domains and native proof requirement, and does
not claim that fixture issuance proves host activation. All added test rows are
Planned. No implementation or host-registration success is inferred.

Two implementation-relevant questions remain under source inspection before
adoption:

1. The broker section names wall-clock and monotonic deadlines, and TEST-067
   names an oversized input, without numeric limits in the added section.
   Locate binding existing definitions or define the missing limits in the
   candidate before implementation; do not invent them during coding.
2. Verify the proposed shared `PATH + ".lock"`, durability, and atomic-replace
   protocol against the actual consumption writer. Naming a shared lock is not
   evidence that both writers serialize correctly.

Frozen sources, task approvals, review verdicts, and identity reservations were
not changed by this audit. Applicability-in-memory is not an application result.
