# ADR-0041: Separate external Source/Claim evidence from code investigation and gate authority

Status: Proposed
Date: 2026-10-22
Issue: #605 (parent #604)

## Context

External citations need stable source versions, acquisition and permission
states, and exact excerpt anchors. Existing INV/BL findings describe code and
observed behavior, existing traceability owns REQ→AC→TEST→evidence, and task
input manifests bind explicit path/raw-hash inputs. The current schema helper
is a draft-07 subset; the canonicalizer applies NFC to strings. These grounded
facts and file:line citations are recorded in
`specs/research-evidence/requirements.md` G-1–G-13.

## Proposed decision

Use one closed `research-evidence/v1` record document at
`specs/<feature>/research/records/research-evidence.json`. #605 owns source,
claim, citation, version/status/hash/storage vocabulary and passive consistency
validation. Preserve three hash meanings: raw fetched bytes, exact extracted
text/quote, and canonical metadata. Check append-only history using decoded
JSON values without Unicode normalization. Explicit scopes expose when
repository/history checks were not performed.

Keep record storage separate from original material. Default reference-only
retains metadata and lawful short excerpts. Unknown rights never authorize
cache/shared storage; even a human assertion is not live permission proof.
#606 owns acquisition/access/cache/deletion/egress, #607 original comparison,
#612 typed edges/query, #609 review/traceability binding, #610 display/export.
#594 remains an interface partner using existing run-input pins, not a blocker
or another research authority. No runner, approval system or eighth plugin.

Ordinary public search terms may leave the system without repeated permission
requests; secrets and explicit no-send instructions require masking/local-only
or STOP at the acquisition boundary. External instructions remain inert data.
Source/Claim status, verified assertions and schema VALID cannot produce gate
PASS, legal authorization or human judgment. Independent review remains needed.

## Alternatives and consequences

Adding external facts as INV rows or arbitrary existing-schema fields changes
established contracts. Copying source/claim bodies into a graph creates two
owners. Using NFC metadata hashes for exact quotes hides raw-text distinctions.
These alternatives are rejected in the proposal.

The passive contract can be completed before its runtime consumers, provided
downstream acceptance remains explicitly pending. Closed record subtrees and
technical quote caps reduce accidental leakage but do not establish lawful
quotation or prevent disguised full text; actual authorization and export
controls remain separate. Live availability and rights cannot be invented.

## Numbering and status

0039 is reserved by #614 PR631 and 0040 by #594 PR633 in concurrent drafts.
Recheck the shared ADR files/index and current integration state at each review
and immediately before integration; renumber only this feature if needed.
This file remains Proposed and confers no task approval or passed review.
