# Security specification: Research evidence foundation

DRAFT. REQ-005–REQ-012, REQ-014; AC-003–AC-011, AC-013, AC-015, AC-016.

## Trust boundaries

Metadata and external prose are untrusted input. The passive validator rejects
invalid shape, IDs, revisions, internal hashes, unsafe placement and the
bounded secret/URL patterns in design.md. It does not execute source prose,
fetch a URL, open original source/cache bytes, authenticate a human field,
validate legal permissions, or access identities/credentials/approval records.
Existing workflow approval and review stay authoritative.

Three hash meanings stay separate: raw fetched representation, exact extracted
text/quote UTF-8 bytes, and NFC-canonical metadata. History compares decoded
JSON values without NFC. A shape-valid invented content hash or forged
`verified` assertion is not verification; #607 must check real originals and
provenance, and existing independent review must assess meaning.

## Confidentiality and storage

Committed objects expose no private storage locator. Technical text/quote
caps and closed objects constrain accidental full-text inclusion but cannot
prove copyright compliance or detect original text disguised as a statement.
Actual rights checks and explicit export selection belong to human review,
#606 and #610. A public URL, retrieval success or claimed human permission is
never sufficient access authorization. Unknown rights remain reference-only
or blocked; inaccessible, revoked, expired, stale and retracted are not
collapsed into one successful state.

Search egress is allowed for ordinary research terms. Explicit no-send input
and secret-bearing input require the #606 masking/local-only/STOP branch.
No such egress occurs here. Synthetic negative fixtures cover G-11 secret
families and credential URLs; all diagnostics suppress offending values.

## Integrity and failure

Unknown fields, duplicate JSON keys, malformed UTF-8/BOM, symlink inputs and
extra entries in the records subtree fail closed. Missing schema/helpers do
not disable checks. Repository and history validation scopes appear in output;
file-only validation cannot claim cross-feature resolution. Inherited records
do not inherit permission or verification. Frozen records, reports, review
manifests and pending human-copy are never rewritten by this feature.

Source proof, live access/expiry/deletion, graph reachability and review
integration are downstream runtime obligations explicitly marked pending in
acceptance-tests.md. No safety guarantee is inferred from this draft's checks.
