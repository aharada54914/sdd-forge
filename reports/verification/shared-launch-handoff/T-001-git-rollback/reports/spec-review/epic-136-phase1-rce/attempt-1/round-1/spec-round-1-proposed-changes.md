# Proposed Changes: epic-136-phase1-rce spec review attempt 1 round 1

## Change 1 — Independent invalid-token acceptance coverage

Update `specs/epic-136-phase1-rce/acceptance-tests.md` and the matching
requirements wording to add a test that uses a correctly signed fixture token
but independently makes each of nonce, TTL, and repository binding invalid.
Each case must exit non-zero and leave no output bundle. This verifies the
existing non-HMAC portions of the fail-closed consent decision rather than
only detecting a modified signature.

## Change 2 — Concrete PowerShell parity completion rule

Update `requirements.md`, `acceptance-tests.md`, and `security-spec.md` to name
the PowerShell test command or test artifact, its expected valid-token and
tampered-token outcomes, and the documentation target for its safe .NET
byte-array implementation. The change must not alter the PowerShell consent
rule or add a production dependency.

## Disposition

These are Major specification-coverage findings. They do not authorize source
implementation. A human must review and apply the Phase 1 edits before round 2.
