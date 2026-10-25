# Design: Research evidence contract — external Source/Claim records (#605)

Impl-Review-Status: Pending

DRAFT. Not reviewed or approved. ADR-0041 is Proposed. This is a future
implementation contract; this packet creates no schema, validator or runtime.
G-n citations refer to the grounded existing behavior in requirements.md.

## Technical Summary and ownership

One closed JSON document per feature separates Sources, Claims and their
citations. A passive validator checks shape and declared consistency. It
neither acquires original bytes nor proves a claim, permission or gate PASS.

| Concern | Owner | Boundary |
|---|---|---|
| Source/Claim identity, revision, hash, status, storage and relation vocabulary | #605 | this contract and passive validation |
| acquisition, extractor, safe cache, actual authorization, expiry deletion, search egress | #606 | consumes #605; no collector added here |
| raw-byte and extracted-quote comparison, verification receipts | #607 | real material required; metadata alone insufficient |
| typed edges and graph validator/query | #612 | references records; never duplicates their bodies |
| external evidence into REQ/ADR and fixed review input | #609 | existing traceability and freeze remain authoritative |
| project skill and run observation | #594/#596 | no research fields added to their v1 schemas |
| task input admission, approval, Done | existing workflow | no authority conferred by this contract |

## Location and schema (REQ-003, REQ-004)

Record file: `specs/<feature>/research/records/research-evidence.json`.
`records/` contains only that ordinary file. Its parents and the file may
not be symlinks. #608/#612 may own sibling map/log/relation files outside
`records/`; no sibling is implicitly an export or validation input.

Schema: `contracts/research-evidence.schema.json`, `$id`
`https://github.com/aharada54914/sdd-forge/contracts/research-evidence.schema.json`,
byte-identical packaged copy under `plugins/sdd-quality-loop/contracts/`.
Use the existing packaged-first identity check (G-12) and the supported
subset of draft-07 (G-5). Every object is closed. All listed keys are
required, including nullable keys. Unsupported constraints are coded checks,
not ignored schema annotations. A missing `storage_mode` is invalid;
producers explicitly write the default `reference_only`.

## Contract research-evidence/v1

Shared types: `Feature = ^[a-z0-9][a-z0-9-]*$`; `Hash = ^[a-f0-9]{64}$`;
`Timestamp = YYYY-MM-DDTHH:MM:SSZ`, with valid calendar/time checked in code
(no leap-second value). Revision and line numbers are positive integers,
excluding booleans. Text is valid Unicode without lone surrogates. `Text`
means nonempty string of at most 2048 code points; null is explicit when
unknown. These caps are technical limits, never a copyright permission.

Root keys: `schema` const `research-evidence/v1`, `feature`, `sources[]`,
`claims[]`. Empty arrays are allowed (new unsearched record set). Arrays
are in nondecreasing ID/revision order (duplicate detection follows); same input yields stable diagnostics.

### Source record

| Field | Type / meaning |
|---|---|
| `source_id`, `record_revision` | `^SRC-[0-9]{3}$`, positive integer; identity local to root feature |
| `source_type` | `official-doc`, `standard`, `paper`, `author-implementation`, `repository`, `issue-tracker`, `article`, `other` |
| `title`, `authors` | Text; array of Text (empty means unknown authors) |
| `url`, `final_url` | requested public reference URL; final URL or null |
| `source_revision` | Text or null: publisher edition/commit/version, not our record revision |
| `retrieval_status` | `retrieved`, `unreachable`, `access-restricted`, `not-attempted` |
| `attempted_at`, `retrieved_at` | Timestamp or null; attempted_at also records failed attempts |
| `content_sha256`, `media_type` | Hash or null; Text or null |
| `extraction` | null or `{method: Text, extracted_sha256: Hash}`; method matches `^[a-z0-9-]+/v[0-9]+$` |
| `currency_status`, `currency_note` | `current`, `stale`, `retracted`, `unknown`; Text or null |
| `verification_status`, `verification_at` | `unverified`, `hash-verified`, `hash-mismatch`, `not-verifiable`; Timestamp or null |
| `storage_mode` | `reference_only`, `local_cache`, `licensed_shared`, `blocked` |
| `license_or_permission_basis` | `{status, basis, asserted_by}`: status `unknown`, `permitted`, `restricted`, `requires-human`; basis Text or null; asserted_by `human` or null |
| `storage_location_class` | `none`, `local-cache`, `shared-store`; never an actual path/URI |
| `retention_or_expiry` | null or `{expires_at: Timestamp, delete_when: [expiry, rights-revoked, feature-closed]}`; unique nonempty subset, always includes expiry and rights-revoked |
| `access_scope`, `access_scope_label` | `none`, `local-user`, `named-group`; opaque Text label or null |
| `inherited_from` | null or `{feature: Feature, source_id, record_revision, record_sha256: Hash}` |
| `uncertainty` | Text or null |

URLs are parsed, not just matched: scheme http/https, nonempty hostname,
no userinfo, backslash, control or whitespace, no credential query parameters.
Reject case-insensitive percent-decoded query keys `token`, `access_token`,
`api_key`, `password`, `secret`, `signature`, `x-amz-signature`, and secret
patterns below after URL decoding. This is data validation, not #606's DNS,
redirect or SSRF authorization. Valid public URLs do not imply storage rights.

### Claim and citation records

| Claim field | Type / meaning |
|---|---|
| `claim_id`, `record_revision` | `^CLM-[0-9]{3}$`, positive integer |
| `statement` | Text: author's claim, not an original-text storage channel |
| `evidence_status` | `cited`, `conflicting`, `searched-not-found`, `not-searched`, `unreachable` |
| `search_record` | null or `{searched_at: Timestamp, scope: Text}` |
| `citations` | array of citation objects below |
| `semantic_status` | `unassessed`, `supported`, `not-supported`, `disputed` |
| `semantic_assessed_by` | `human`, `independent-review`, or null |
| `semantic_note`, `uncertainty` | Text or null; note cites the actual assessment when assessed |

Citation keys: `source_id`, `source_record_revision`, `relation`
(`supports`, `contradicts`, `context`), `anchor`, `quote_status`
(`unverified`, `verified`, `mismatch`, `not-checkable`),
`quote_verified_at` (Timestamp or null).
Anchor is null or `{line_start, line_end, quote, quote_sha256: Hash}`.
Identical `(source_id, source_record_revision, relation, anchor)` citations
within one claim revision are rejected. A source may support many claims and
a claim may cite many sources; citing the same source with different relations
is representable, not silently collapsed.

The issue's overloaded `verified` claim vocabulary is deliberately split:
`cited` records supporting material; byte/quote verification has separate
fields; meaning has `semantic_status`. None is a task or quality state.

## Hashes, revisions and anchoring (REQ-005, REQ-006, REQ-008)

1. `content_sha256`: SHA-256 of response representation bytes after removal
   of transfer/content encoding, before charset conversion, text extraction
   or newline normalization. #606 records these bytes; #607 compares them.
2. `extracted_sha256`: SHA-256 of the exact UTF-8 extraction output of the
   named versioned method. Split lines only on LF; CR remains a character.
3. `quote_sha256`: SHA-256 of UTF-8 encoding of the JSON-decoded `quote`,
   with no NFC, case or whitespace folding. #605 recomputes this hash.
   #607 checks its exact substring in the joined inclusive line range of
   the extraction whose hash was independently checked.
4. `record_sha256`: derived, not stored on the record itself. Run existing
   `canonicalize-sdd-yaml.py --input-format json --hash-only` over the
   individual object and strip `sha256:`. The helper applies NFC (G-6).
   NFC/NFD strings alone can canonicalize identically, but a changed quote
   with its correctly recomputed `quote_sha256` changes the record hash.
   This metadata identity is not a raw-text comparison or permission proof.
5. Run input binding uses the full file's raw-byte SHA-256 (G-10). Source
   inheritance pins the named source record's canonical hash, not the whole
   file and not the original's content hash.

Revisions per ID are contiguous from 1; update by appending a revision.
Existing records remain present and JSON-value-identical to `--previous`,
including exact decoded strings and quote hashes (no canonical/NFC equality
for history). Whitespace/key-order changes in the outer JSON are harmless
for history but still change a run's raw-file pin. `--previous` must have the
same feature and itself pass file-level validation. The caller's true
historical version remains the existing workflow's responsibility.

An inherited reference must name a different feature, resolve to its ordinary
record file under the supplied root, and match a valid source revision/hash.
The target document receives file-level validation, without recursively
following its inheritance. Inheritance records lineage only, never transfers
permission or verification: a new local record starts rights `unknown`, byte
verification `unverified`, mode `reference_only` or `blocked`. Its own later
revision may record independently obtained assessments. No graph traversal
or inherited authority is introduced.

Anchors: 1 ≤ start ≤ end; at most five inclusive lines; quote length 1–300
code points. For each source ID across all its revisions, the sum of **unique
exact quote strings** referenced by all claim revisions is ≤1500 code points.
Repeating a historical quote does not exhaust the budget again; overlapping
but unequal quotes count separately. These bounds do not prove lawful use
or that a short work was not reproduced in full. Human rights review remains
required. Unretrieved sources have null anchors; retrieved citations require
an anchor and non-null extraction. Extracted bytes are never read by #605.

## Status consistency (REQ-007, REQ-009)

| Axis | Required consistency |
|---|---|
| retrieval | retrieved: hash/final URL/attempted_at/retrieved_at non-null and attempted_at ≤ retrieved_at; not-attempted: these and extraction/media_type null; unreachable/access-restricted: attempted_at set, hash/final URL/retrieved_at/extraction/media_type null |
| extraction | non-null only for retrieved; media_type non-null for retrieved |
| currency | stale/retracted require a nonempty currency_note; current/unknown allow null; no automatic clock-based promotion |
| byte verification | unverified iff verification_at null; hash-verified/hash-mismatch require retrieved; not-verifiable is distinct from a successful comparison; dated verification cannot precede retrieved_at when present |
| rights | unknown requires null basis/actor; restricted/requires-human may record a reason; permitted requires basis and human assertion; only permitted may request cache/shared mode |
| reference_only/blocked | class none, retention null, scope none, label null; original bytes are not persisted |
| local_cache | permitted, local-cache class, local-user scope, null label, retention set |
| licensed_shared | permitted, shared-store class, named-group scope and label, retention set |
| expiry | expiry must be after retrieved_at when present; #605 reads no clock; #606/#610 must separately block current expired/revoked access and delete as required |
| cited | at least one supports citation to retrieved source; no contradicts citation |
| conflicting | at least one supports and one contradicts to retrieved sources; disagreement retained |
| searched-not-found | no citations and non-null search_record |
| not-searched | no citations and null search_record |
| unreachable | at least one citation; all cited sources unreachable/access-restricted |
| semantic | assessed statuses require actor and nonempty note; unassessed requires both null; actor/note are assertions, not authentication or proof of independence |
| quote | unverified iff quote_verified_at null; verified/mismatch require anchor and source hash-verified; not-checkable is distinct; dated checks cannot precede retrieved_at when present |

Unknown actual rights/access/assessment remain unknown. A field claiming
`human` or `independent-review`, or even `verified`, is never trusted solely
because #605 returns VALID. #607 and existing independent review verify
provenance before consuming such assertions. Drafting agents cannot claim an
assessment or permission that did not occur. Retraction/staleness preserves
historical verification but prevents consumers calling it current proof.

## Storage and export boundary (REQ-010, REQ-011)

- #605 enforces its closed `records/` subtree, closed objects, text/quote
  budgets and absence of storage locators. It does not classify the copyright
  status of arbitrary prose or guarantee that metadata was authored honestly.
- #606 must place protected caches outside its configured repository/worktree
  roots, CI workspace, CI temp and artifact staging roots; check resolved
  paths and symlink aliases before each write. It must enforce ACL/scope,
  actual permission, expiry/deletion and atomic failure without replacing
  old originals. `.gitignore` alone is never the security boundary. A
  backstop `.sdd-research-cache/` ignore entry may be added at implementation;
  it does not authorize a cache inside a repository.
- #606 and #610 own export selection: allowlisted metadata/receipt paths and
  licensed short excerpts only, with per-export rights/expiry checks. Never
  recurse over research/ or cache roots. Reject full-text cache entries even
  when an arbitrary CI staging glob would match them. #605 defines negative
  fixtures/consumer obligations; it does not implement these exporters.
- #605 compatibility tests pin current bundle/review explicit-path behavior
  and verify no workflow upload glob changes. A textual ban on the word
  `research` in a CI path is not a leak prevention mechanism (G-8/G-9).
- Ordinary public technical search terms are permitted without per-send
  confirmation. #606 applies masking/local-only/STOP for secret input or an
  explicit no-send condition. The passive validator performs no searches.
- The validator scans decoded strings for the existing G-11 S1–S7 secret
  families with matching case behavior. Test cases are synthetic, assembled
  from fragments. It also checks credential-bearing URLs above. Secret
  recognition is bounded, not a guarantee that all possible secrets are
  identifiable. No offending value is printed. External prose is inert data;
  instructions in it are never executed or used to change authorization.

## Reference interfaces without completion cycles (REQ-012)

#594's proposed v1 schemas receive no extra research keys. A using run admits
only the record metadata file as an existing `allowed_inputs` path/raw hash.
#594's runner observations retain their own provenance and authority limits.
No cross-issue completion dependency is created.

#605 defines typed endpoints and relations for #612: source/claim references
are `{kind: SRC|CLM, feature, id, record_revision, record_sha256}`; REQ is
`{kind: REQ, feature, id: REQ-NNN, document_sha256}` pointing to that feature's
requirements.md; ADR is `{kind: ADR, id: ADR-NNNN, path, document_sha256}`
pointing to an ordinary matching `docs/adr/NNNN-*.md`. REQ/ADR are document
pins, not invented Source/Claim record revisions.

Relations: SRC→CLM `supports|contradicts|context` derive from this document's
citations; #612 reads them without storing a second copy. CLM→REQ/ADR uses
`justifies|constrains`, CLM→CLM uses `depends-on`. #612 owns edge storage,
unknown type/endpoint rejection, reference existence and hash checks, and
cycle-safe queries; #605 supplies contract fixtures for these vocabularies.
#609 owns matching REQ declarations and ADR paths into actual review input.
Neither graph nor this contract duplicates REQ→AC→TEST→evidence.

#606/#607 append new revisions for acquisition/verification results. They
must meet the explicit downstream test rows in acceptance-tests.md. Those
runtime rows remain pending their implementation and are not #605 PASS claims.

## Passive validator (REQ-013)

Future entry: `plugins/sdd-quality-loop/scripts/validate-research-evidence.py`
with argument-transparent `.sh`/`.ps1` wrappers. Reuse G-5/G-6/G-12 helpers.

```
validate-research-evidence --file FILE [--repo-root DIR] [--previous FILE]
```

File mode validates record structure, references inside the file and statuses.
Repository mode additionally validates exact placement, directory closure and
inheritance. File mode with inheritance is permitted but explicitly unbound.
`--previous` additionally checks history. Never read a clock/network, originals,
credentials or approval/identity records. Inputs are read-only; canonicalizer
scratch files contain metadata only, are private and removed on failure/success.
A symlink input is rejected, including previous files and traversed parents.

Exit 0 stdout is exactly:
`research-evidence: VALID <feature> scope=<file|repository> history=<checked|unchecked> sources=<n> claims=<m>`.
Counts include all revisions. VALID means only checks in the named scope; it
never means rights/quote/gate PASS. There is no file-mode downgrade on errors.
Exit 1: stderr `research-evidence: INVALID: <code> <json-pointer>`, empty stdout.
Exit 2: usage error with empty stdout. An argparse error override emits only
a fixed usage message, never unknown argument values. Error values are never echoed.

Check precedence follows this table. Within a phase use sorted JSON pointers;
for whole-document errors use `/`. Unknown property names use their nearest
known parent pointer, so attacker-controlled key names cannot leak into diagnostics.
Missing helper/schema/invalid schema identity
fails closed, not a fallback to an unvalidated document.

| Code | Condition / owner |
|---|---|
| `dependency-unavailable` | missing/invalid governing schema or helper (#605) |
| `file-unreadable` | missing/nonregular/symlink/unreadable file, invalid UTF-8/BOM/JSON/duplicate key (#605) |
| `schema-invalid` | closed-shape validation failure (#605) |
| `value-invalid` | calendar date, positive integer, Unicode/text bound, array order, URL syntax/query rule (#605) |
| `secret-detected` | G-11 secret family (#605) |
| `id-duplicate` | repeated ID/revision or duplicate citation (#605) |
| `revision-gap` | revisions not exactly 1..n (#605) |
| `status-inconsistent` | source status rules (#605) |
| `rights-inconsistent` | permission assertion rules (#605) |
| `storage-inconsistent` | mode/class/scope/retention/expiry rules (#605) |
| `citation-unresolved` | absent source ID/revision (#605) |
| `quote-invalid` | quote self-hash, length, line bounds, extraction/anchor/status/time rules (#605) |
| `quote-budget-exceeded` | unique quote budget (#605) |
| `evidence-inconsistent` | claim evidence-status rules (#605) |
| `semantic-inconsistent` | semantic actor/note consistency (#605) |
| `location-mismatch` | repository-mode exact placement or parent symlink failure (#605) |
| `research-dir-unexpected-file` | repository-mode extra record subtree entry (#605) |
| `inheritance-unresolved` | repository-mode absent/invalid/self-feature target, pin mismatch, or inherited authority on first revision (#605; first-revision authority rule also checked in file mode) |
| `revision-rewritten` | invalid previous document, different feature, removed or changed prior decoded record (#605) |

Schema validation covers supported shape constraints only. Bounds, calendars,
conditional consistency, ID/revision existence and quote self-hashes are coded
checks. Original hash/quote correctness belongs to #607; rights/access to human
review and #606; meaning to independent review/human judgment; gate PASS to the
existing evaluator. File/history mode limitations must remain explicit.

## Compatibility and alternatives

No existing schema keys, task/approval state, mandatory check selection or
freeze changes. No automatic call from non-adopter Full/Lite/legacy flows.
Additive implementation files/register entries and contract docs only.
Reusing INV/BL was rejected because it changes their meaning (G-1/G-2).
One record document avoids a source/claim file-order dependency. Separate
metadata and byte hashes avoid treating NFC normalization as quote equality.
No storage locator avoids leaking private locations into normal exports.

## Layer Specifications

| Layer | Canonical Detail | Owner | Status |
|---|---|---|---|
| UX | ux-spec.md | sdd-quality-loop | Draft |
| Frontend | frontend-spec.md | no UI in this scope | Draft |
| Infra | infra-spec.md | sdd-quality-loop | Draft |
| Security | security-spec.md | sdd-quality-loop / downstream owners | Draft |

## Shared-state re-verification

ADR-0041 is proposed because concurrent #614 PR631 reserves 0039 and #594
PR633 reserves 0040. Recheck `docs/adr/`, its README index and current shared
integration state at each review and immediately before integration. Renumber
only this feature if needed. Recheck G-3/G-5/G-8/G-9/G-13 for current schema
support, collectors, upload globs and registrations before implementation.
