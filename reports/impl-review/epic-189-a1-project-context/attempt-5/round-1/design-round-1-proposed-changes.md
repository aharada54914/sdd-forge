# Implementation Policy Review Report: epic-189-a1-project-context — Round 1 / Attempt 5

## Verdict: NEEDS_WORK

Recorded: 2026-09-09. Run ID: `rt002-impl-a5-r1-20260909T130647Z`.

Two fresh independent Astra reviewers completed. Reviewer A returned BLOCKED
with three Major FAIL checks; reviewer B returned PASS with no FAIL checks.
The integrated result is NEEDS_WORK: Critical 0, Major 3, Minor 0. Neither
reviewer's conclusion supersedes the other's findings. Raw results and the
derived contract are retained in this directory.

## Reviewer-A findings and proposed changes

1. SECURITY-COVERAGE: design.md:789–790 calls
   `contracts/approver-registry.schema.json` protected, but the exhaustive
   inventory at design.md:277–287 omits it and design.md:306 and AC-021 fix
   the total at 28. Reconcile the canonical inventory and all derived counts,
   acceptance rows, layer declarations, generator inputs and mirrored inventory
   without silently removing the promised protection. Verify both registration
   and rejection of an omitted schema. Inventory changes require their own
   authorized application and fresh review; this proposal is not an applied fix.
2. ADR-PRESENT: the cited ADRs, including ADR-0025, were not admitted by the
   reserved input manifest. Complete the existing RT-20260908-004 contract
   repair, with exact path/hash binding and rejection fixtures, before admitting
   ADRs to a fresh review. Do not read undeclared files in the old reviewer
   contexts or treat historical pins as current verification. The finding does
   not claim that the ADR files are absent.
3. DESIGN-SYSTEM-CONFORMANCE: admitted inputs establish neither applicability
   nor the required exemption. Verify the actual project configuration and
   directory state, then bind that evidence in the next review's allowed inputs.
   Record `N/A — ds_profile: none` only if evidence supports that setting;
   otherwise supply the applicable design-system inputs and compliance section.
   Absence of a browser UI is not sufficient evidence for exemption.

## Reviewer-B findings

No FAIL findings: 10 PASS and one DOMAIN-CONFORMANCE SKIP. This does not waive
reviewer A's structural findings.

## Output correction audit

Reviewer A initially transcribed the acceptance-test hash with 62 characters.
That original response is preserved in `reviewer-a-original-invalid-manifest.json`.
The same reviewer, in the same reserved context, reread its invocation and
returned `reviewer-a.json` with the exact reserved manifest. The orchestrator
verified manifest equality and that checks and verdict were unchanged. This
was an output transcription correction, not a new substantive review, a new
identity reservation, or a cycle-count reset.

## Next steps and completion boundaries

Keep all previous evidence. Apply the reconciled amendments through the
authorized protected-file workflow, rerun affected specification review if
hash-frozen specification inputs change, and launch the next design round with
fresh precheck, current bound inputs, prior summary and reserved independent
identities. Task provenance review and RT002 implementation/native activation
verification remain downstream requirements.

The canonical feature workflow checker exits 1 with
`stage-provenance: impl integrated verdict is not a valid PASS` after this
contract is persisted. That is an unresolved gate, not successful verification.
The supporting specification review PASS and RT003 regression success do not
establish native hook activation, satisfy CI, close the ticket, or permit main
integration. No commit, push, merge or task-Done transition was performed.
