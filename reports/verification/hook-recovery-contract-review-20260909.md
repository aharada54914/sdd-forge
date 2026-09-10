# RT-20260909-002 recovery contract review

Date: 2026-09-09
Scope: ordinary independent pre-implementation contract review, not a formal
SDD verdict, live activation proof, or task completion.
Reviewer: /root/hook_contract_security_review (independent from contract author).

## First review

Inputs: `hook-recovery-contract-review-inputs-20260909.sha256` preserves the
initial ticket, amendment, prior report, production source, wrappers and tests.
The reviewer verified the supplied ticket/amendment/source hashes.

- Major: entire acceptance envelope and emitted patch were not byte-specified.
- Warning: adapter selection versus shared cleanup loader scope was unclear.
- Warning: enumerated rejection branches were incomplete.

The explicit human approval resolved the earlier plugin-origin and exceptional
entry authorization objections; it did not itself resolve these technical gaps.

## Revision submitted for second review

- Amendment SHA-256:
  `2ca4125082c495724b0bbde33e7451edb21fc4042827c1e67b4354eb9215e79f`.
- Ticket SHA-256:
  `878942094199aa2ae34de1c91a5968cb3019a2c83672d0e762964be5fcd835ad`.
- Other initial-manifest inputs are unchanged. No new adapter candidate exists.
- Fixed both normative JSON string templates with nonce as sole substitution.
- Explicitly scoped adapter selection to verification, documented intentional
  duplicate-member rejection in both modes, and preserved valid cleanup behavior.
- Added missing selector/type/runtime/duplicate/extra-key/newline test branches.
- Clarified that repair-specific provenance review is included in the narrow
  recovery route; ordinary bootstrap remains unavailable until live exit.

Local read-only template validation: exit 0. Two JSON strings parse; each has
one nonce placeholder and no CR or final newline. The raw-response template
ends in the exact patch template. Replacing the new challenge content with the
historical empty content exactly reproduces the stored historical host response.
This is only template consistency, NOT a new host denial observation.

Second independent review: reviewer verified both revised hashes and reported
all three findings resolved, with no remaining contract blocker. The reviewer
performed no writes or validator execution. This is not a formal gate verdict.
Production application, new-adapter regression verification, scoped formal
provenance re-review and fresh installed-path host verification remain pending.
Historical Done/PASS evidence is unchanged.
