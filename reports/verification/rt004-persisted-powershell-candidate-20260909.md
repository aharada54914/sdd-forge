# RT004 PowerShell task predecessor — partial patch data

Date: 2026-09-09
Status: incomplete; no formal PASS, product application, commit, push or merge.

Candidate: `adr-persisted-powershell-candidate-20260909.patch`
SHA-256: `6125fa788b1cf93c755500f663def8f5547125fc64d9ed415bd1dc4cf57c3565`

Source inspected: `plugins/sdd-review-loop/scripts/task-review-precheck.ps1`.
The independent manifest allowlist is at line 101; Require-Pass begins at line
147 and invokes that allowlist at line 191. The existing consumer validates
contract identity and two reviewer roles before the candidate call at line 182.

The candidate adds impl predecessor ADR validation, not ADR access for task
reviewers. It pairs extension presence, checks canonical identity, core and layer
hash equality, exact raw precheck/design manifest entries for both reviewers,
complete sorted ADR sets and current design-derived ADR hashes. It preserves
the consumer's lifecycle-normalized design comparison and existing summary,
reviewer identity and non-ADR checks. Legacy absence adds no authorized paths.
Filesystem and restricted lexical helpers remain inside the protected target;
no new writable helper is introduced. Current PASS logic is not reusable for
historical NEEDS_WORK validation.

## Review and verification limits

- Main review added contract component safety alongside precheck component
  safety. Both are checked before deriving or reading ADR contents.
- Three final hunk counts, cumulative offsets and removed-line source anchors
  matched the read source. This verifies patch data only.
- The actual target's git diff remained empty.
- A generic macOS PowerShell JSON round-trip confirmed integer fields decode as
  System.Int64 and an empty ADR array remains an array of count zero. The first
  diagnostic command failed shell quoting before JSON evaluation; a corrected
  command exited zero. No protected candidate was executed in either command.
- Warning: full legacy compatibility, raw-path negative cases, duplicate JSON
  properties and concurrent evidence replacement need real-consumer tests.
- Warning: inherited helper duplication and exact cross-runtime parity require
  independent review. This source was already larger than the general 500-line
  style preference; adding an unprotected helper would violate this ticket's
  security boundary and is not an authorized simplification.
- No syntax/runtime candidate test or native Windows test was run. These data
  checks are not evidence of an implementation-review or quality-gate PASS.

Remaining ticket work: workflow-state consumers, historical/ADR-only next-round
semantics, regression coverage of the complete consumer chain, independent
security review, then the complete human-application package. Existing admission
RED evidence remains unresolved; no failed verdict or frozen artifact is changed.
