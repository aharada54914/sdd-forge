# Implementation Policy Review — Round 1 Proposed Changes: epic-136-phase1-rce

- Verdict: NEEDS_WORK (round 1 of 3, attempt 1)
- Findings: Critical 0 / Major 1 / Minor 0
- Reviewer A (structural soundness): PASS — 10 PASS, 1 SKIP; the frontend/backend check is not applicable.
- Reviewer B (implementability/risk): NEEDS_WORK — 1 Major FAIL.

## FAIL Finding

### NO-REQ-CONTRADICTION (Major, reviewer B)

REQ-005 and AC-005 designate `security-spec.md` as the canonical description
of the PowerShell .NET HMACSHA256 byte-array safety difference. At review time,
the document did not make the UTF-8 byte-array conversion or source-boundary
rule explicit, so the PowerShell verification path was underspecified.

## Applied Change

The user authorized specification updates. `security-spec.md` now records that
PowerShell reads fields as data, converts the key and canonical message to
UTF-8 byte arrays for `HMACSHA256`, and never constructs executable source from
token data. `design.md` now makes that detail and TEST-005's acceptance and
tamper-denial evidence explicit.

## Next Step

Run implementation-policy review round 2 against the amended design and layer
specification.
