# Acceptance tests: Research evidence foundation (#605)

DRAFT. These are future test obligations, not executed results. Spec/implementation reviews remain Pending.

The future local suite `tests/research-evidence.tests.py` uses small synthetic fixtures under `tests/fixtures/research-evidence/`, temporary feature trees and the documented passive CLI. It registers in the existing verification catalog. Secret-like inputs are synthetic and assembled from fragments (WFI-012); no real credentials or third-party originals are test fixtures. Each listed branch has its own concrete TEST row. Rows owned by downstream issues are contractual handoff obligations and remain pending those issues; they are not required runtime implementation by #605.

## Acceptance Criteria

| AC | Requirement | Observable outcome |
|---|---|---|
| AC-001 | REQ-001, REQ-002 | Ownership remains separated; existing INV/BL/traceability and authority are unchanged. |
| AC-002 | REQ-003 | Closed shape, schema discovery and supported-keyword limits fail closed. |
| AC-003 | REQ-004, REQ-005 | IDs, append-only revisions, location and inheritance have the documented validation scopes. |
| AC-004 | REQ-006 | Raw, extracted, quote and metadata hashes keep distinct meanings without silent normalization. |
| AC-005 | REQ-007 | Retrieval, currency and verification states remain distinct and internally consistent. |
| AC-006 | REQ-008 | Anchors and exact-quote budgets enforce their finite boundaries. |
| AC-007 | REQ-009 | Four storage modes and four rights states preserve unknowns and grant no authority. |
| AC-008 | REQ-007 | Claim evidence and semantic assessment have separate status/actor requirements. |
| AC-009 | REQ-010 | Record subtree and explicit exports preserve the original-text boundary. |
| AC-010 | REQ-011 | Secret/URL checks redact diagnostics; search permission and explicit no-send conditions remain distinct. |
| AC-011 | REQ-012 | Typed downstream references preserve ownership without a circular completion dependency. |
| AC-012 | REQ-013, NFR-001, NFR-002, NFR-003 | CLI scopes, errors, determinism, offline behavior and wrapper parity match design. |
| AC-013 | REQ-014 | Non-adopter Full/Lite/legacy compatibility and immutable historical evidence remain intact. |
| AC-014 | REQ-015 | Catalog, packaged schemas and documentation remain synchronized. |
| AC-015 | REQ-009, REQ-010, REQ-011 | Downstream runtime consumers enforce actual access/rights/expiry, safe storage and egress. |
| AC-016 | REQ-006, REQ-007, REQ-008, REQ-012 | Downstream verification/graph/review consumers validate actual material and bound references. |

## Test Matrix

| Test ID | AC | Scenario | Expected assertion | Owner |
|---|---|---|---|---|
| TEST-001 | AC-001 | owner table + existing artifacts | ADR Proposed; no new plugin/MCP/runner/approval fields; INV/BL and traceability inputs unchanged | #605 |
| TEST-002 | AC-002 | valid empty new feature document | VALID file scope with zero sources/claims; no acquisition asserted | #605 |
| TEST-003 | AC-002 | valid minimal retrieved source + cited claim | VALID; all required nested keys present and appropriate nulls preserved | #605 |
| TEST-004 | AC-002 | unknown property on root | schema-invalid; a separate valid control object remains accepted | #605 |
| TEST-005 | AC-002 | unknown property on source | schema-invalid; a separate valid control object remains accepted | #605 |
| TEST-006 | AC-002 | unknown property on extraction | schema-invalid; a separate valid control object remains accepted | #605 |
| TEST-007 | AC-002 | unknown property on permission | schema-invalid; a separate valid control object remains accepted | #605 |
| TEST-008 | AC-002 | unknown property on retention | schema-invalid; a separate valid control object remains accepted | #605 |
| TEST-009 | AC-002 | unknown property on inheritance | schema-invalid; a separate valid control object remains accepted | #605 |
| TEST-010 | AC-002 | unknown property on claim | schema-invalid; a separate valid control object remains accepted | #605 |
| TEST-011 | AC-002 | unknown property on search_record | schema-invalid; a separate valid control object remains accepted | #605 |
| TEST-012 | AC-002 | unknown property on citation | schema-invalid; a separate valid control object remains accepted | #605 |
| TEST-013 | AC-002 | unknown property on anchor | schema-invalid; a separate valid control object remains accepted | #605 |
| TEST-014 | AC-002 | invalid schema version | schema-invalid; no fallback or state write | #605 |
| TEST-015 | AC-002 | invalid required key | schema-invalid; no fallback or state write | #605 |
| TEST-016 | AC-002 | invalid enum value | schema-invalid; no fallback or state write | #605 |
| TEST-017 | AC-002 | invalid field type | schema-invalid; no fallback or state write | #605 |
| TEST-018 | AC-002 | invalid ID pattern | schema-invalid; no fallback or state write | #605 |
| TEST-019 | AC-002 | invalid hash shape | schema-invalid; no fallback or state write | #605 |
| TEST-020 | AC-002 | missing packaged and root schema | dependency-unavailable; stdout empty | #605 |
| TEST-021 | AC-002 | wrong schema identity | dependency-unavailable; stdout empty | #605 |
| TEST-022 | AC-002 | missing schema helper | dependency-unavailable; stdout empty | #605 |
| TEST-023 | AC-002 | missing canonicalizer | dependency-unavailable; stdout empty | #605 |
| TEST-024 | AC-002 | schema keyword inventory | Only G-5 supported constraint keywords used; unsupported allOf/maxLength/format never relied on | #605 |
| TEST-025 | AC-002 | invalid calendar timestamp | value-invalid; corresponding valid boundary accepted | #605 |
| TEST-026 | AC-002 | nonpositive revision | value-invalid; corresponding valid boundary accepted | #605 |
| TEST-027 | AC-002 | boolean revision | value-invalid; corresponding valid boundary accepted | #605 |
| TEST-028 | AC-002 | lone surrogate | value-invalid; corresponding valid boundary accepted | #605 |
| TEST-029 | AC-002 | Text above 2048 | value-invalid; corresponding valid boundary accepted | #605 |
| TEST-030 | AC-002 | out-of-order record array | value-invalid; corresponding valid boundary accepted | #605 |
| TEST-031 | AC-003 | duplicate source ID/revision | id-duplicate | #605 |
| TEST-032 | AC-003 | duplicate claim ID/revision | id-duplicate | #605 |
| TEST-033 | AC-003 | duplicate citation | id-duplicate; distinct relation remains representable | #605 |
| TEST-034 | AC-003 | source revision gap | revision-gap | #605 |
| TEST-035 | AC-003 | claim revision gap | revision-gap | #605 |
| TEST-036 | AC-003 | append source and claim revisions | history=checked; prior records unchanged | #605 |
| TEST-037 | AC-003 | remove previous source | revision-rewritten; history not accepted | #605 |
| TEST-038 | AC-003 | remove previous claim | revision-rewritten; history not accepted | #605 |
| TEST-039 | AC-003 | rewrite previous decoded source | revision-rewritten; history not accepted | #605 |
| TEST-040 | AC-003 | rewrite previous decoded claim | revision-rewritten; history not accepted | #605 |
| TEST-041 | AC-003 | NFD to NFC prior statement rewrite | revision-rewritten; history not accepted | #605 |
| TEST-042 | AC-003 | previous feature differs | revision-rewritten; history not accepted | #605 |
| TEST-043 | AC-003 | previous document invalid | revision-rewritten; history not accepted | #605 |
| TEST-044 | AC-003 | only JSON layout/key order changes | history=checked; raw file pin changes while decoded historical records remain equal | #605 |
| TEST-045 | AC-003 | repository file path + feature agree | scope=repository; closed records subtree accepted | #605 |
| TEST-046 | AC-003 | feature/path mismatch | location-mismatch | #605 |
| TEST-047 | AC-003 | source inheritance to valid other-feature revision/hash | repository scope validates target file and pin; no recursive authority transfer | #605 |
| TEST-048 | AC-003 | inherited target absent | inheritance-unresolved | #605 |
| TEST-049 | AC-003 | inherited target invalid | inheritance-unresolved | #605 |
| TEST-050 | AC-003 | inherited revision absent | inheritance-unresolved | #605 |
| TEST-051 | AC-003 | inherited pin differs | inheritance-unresolved | #605 |
| TEST-052 | AC-003 | inheritance names own feature | inheritance-unresolved | #605 |
| TEST-053 | AC-003 | first inherited record claims permission | inheritance-unresolved | #605 |
| TEST-054 | AC-003 | first inherited record claims byte verification | inheritance-unresolved | #605 |
| TEST-055 | AC-003 | file scope with external inheritance | scope=file explicitly; no claim of target existence or verified lineage | #605 |
| TEST-056 | AC-004 | valid exact quote self-hash | Accepted without reading original; still no quote-verification proof | #605 |
| TEST-057 | AC-004 | quote bytes changed but quote hash retained | quote-invalid | #605 |
| TEST-058 | AC-004 | NFC and NFD quote with respective correct hashes | Both self-consistent; different quote hashes and canonical record hashes; no automatic text normalization | #605 |
| TEST-059 | AC-004 | NFC and NFD nonquote metadata | May have equal canonical metadata hash; raw file pins differ; history still rejects rewrite | #605 |
| TEST-060 | AC-004 | CRLF versus LF quote | Different quote hashes; CR retained in line text contract | #605 |
| TEST-061 | AC-004 | well-shaped invented content hash marked unverified | File validity does not report hash-verified; downstream original comparison required | #605 |
| TEST-062 | AC-004 | content hash replaced by extracted hash | Contract example keeps separate fields; downstream false raw-byte match test required | #605 |
| TEST-063 | AC-005 | retrieved source | Accept all retrieved fields; null content_sha256 rejects status-inconsistent | #605 |
| TEST-064 | AC-005 | unreachable source | Accept attempt time with null original fields; nonnull final_url rejects status-inconsistent | #605 |
| TEST-065 | AC-005 | access-restricted source | Accept access-restricted attempt; nonnull content_sha256 rejects status-inconsistent | #605 |
| TEST-066 | AC-005 | not-attempted source | Accept all acquisition fields null; attempted_at set rejects status-inconsistent | #605 |
| TEST-067 | AC-005 | current currency | Accept current with null currency_note, without promoting unverified bytes | #605 |
| TEST-068 | AC-005 | stale currency | Accept stale with note; null note rejects status-inconsistent; prior verification remains historical | #605 |
| TEST-069 | AC-005 | retracted currency | Accept retracted with note; null note rejects status-inconsistent; retraction never becomes current proof | #605 |
| TEST-070 | AC-005 | unknown currency | Accept unknown with null note; no default promotion to current | #605 |
| TEST-071 | AC-005 | unverified byte verification | Accept null verification_at; nonnull timestamp rejects status-inconsistent | #605 |
| TEST-072 | AC-005 | hash-verified byte verification | Accept retrieved+timestamp; nonretrieved source rejects status-inconsistent | #605 |
| TEST-073 | AC-005 | hash-mismatch byte verification | Accept retrieved+timestamp as mismatch; null timestamp rejects status-inconsistent | #605 |
| TEST-074 | AC-005 | not-verifiable byte verification | Accept dated not-verifiable result without successful comparison; null timestamp rejects status-inconsistent | #605 |
| TEST-075 | AC-005 | verification timestamp precedes retrieval | status-inconsistent | #605 |
| TEST-076 | AC-005 | retrieved_at precedes attempted_at | status-inconsistent | #605 |
| TEST-077 | AC-005 | extraction present on failed acquisition | status-inconsistent | #605 |
| TEST-078 | AC-006 | one-line one-character quote | Accepted with matching self-hash and extraction | #605 |
| TEST-079 | AC-006 | 300-codepoint five-line quote | Accepted at exact caps | #605 |
| TEST-080 | AC-006 | empty quote | quote-invalid (empty quote may fail schema-invalid first); no original read | #605 |
| TEST-081 | AC-006 | 301-codepoint quote | quote-invalid (empty quote may fail schema-invalid first); no original read | #605 |
| TEST-082 | AC-006 | zero start line | quote-invalid (empty quote may fail schema-invalid first); no original read | #605 |
| TEST-083 | AC-006 | end before start | quote-invalid (empty quote may fail schema-invalid first); no original read | #605 |
| TEST-084 | AC-006 | six-line range | quote-invalid (empty quote may fail schema-invalid first); no original read | #605 |
| TEST-085 | AC-006 | retrieved citation without anchor | quote-invalid (empty quote may fail schema-invalid first); no original read | #605 |
| TEST-086 | AC-006 | anchor without extraction | quote-invalid (empty quote may fail schema-invalid first); no original read | #605 |
| TEST-087 | AC-006 | unretrieved citation with anchor | quote-invalid (empty quote may fail schema-invalid first); no original read | #605 |
| TEST-088 | AC-006 | 1500 unique codepoints per source | Accepted at exact budget | #605 |
| TEST-089 | AC-006 | 1501 unique codepoints per source | quote-budget-exceeded | #605 |
| TEST-090 | AC-006 | same exact quote repeated in later revisions | Count once; preserves append-only history | #605 |
| TEST-091 | AC-006 | overlapping but different quotes | Count both complete strings; enforce aggregate cap | #605 |
| TEST-092 | AC-006 | unverified quote status | Accept null quote_verified_at; nonnull timestamp rejects quote-invalid | #605 |
| TEST-093 | AC-006 | verified quote status | Accept anchored/hash-verified source+timestamp; unverified source rejects quote-invalid; success remains a provenance assertion | #605 |
| TEST-094 | AC-006 | mismatch quote status | Accept mismatch on anchored/hash-verified source+timestamp; missing timestamp rejects quote-invalid | #605 |
| TEST-095 | AC-006 | not-checkable quote status | Accept dated not-checkable on an unavailable source; null timestamp rejects quote-invalid | #605 |
| TEST-096 | AC-006 | quote check predates retrieval | quote-invalid | #605 |
| TEST-097 | AC-007 | unknown rights | Accept unknown with null basis/actor and reference_only; supplied actor rejects rights-inconsistent | #605 |
| TEST-098 | AC-007 | permitted rights | Accept permitted with human basis; absent basis or actor rejects rights-inconsistent | #605 |
| TEST-099 | AC-007 | restricted rights | Accept restricted with reason and blocked; local_cache request rejects rights-inconsistent | #605 |
| TEST-100 | AC-007 | requires-human rights | Accept requires-human with reason and reference_only; licensed_shared request rejects rights-inconsistent | #605 |
| TEST-101 | AC-007 | reference_only storage | Accept exact class/scope/label/retention mapping; mutate class or scope and reject storage-inconsistent | #605 |
| TEST-102 | AC-007 | blocked storage | Accept exact class/scope/label/retention mapping; mutate class or scope and reject storage-inconsistent | #605 |
| TEST-103 | AC-007 | local_cache storage | Accept exact class/scope/label/retention mapping; mutate class or scope and reject storage-inconsistent | #605 |
| TEST-104 | AC-007 | licensed_shared storage | Accept exact class/scope/label/retention mapping; mutate class or scope and reject storage-inconsistent | #605 |
| TEST-105 | AC-007 | missing storage_mode | schema-invalid; producer must serialize reference_only explicitly | #605 |
| TEST-106 | AC-007 | shared mode lacks group label | storage-inconsistent | #605 |
| TEST-107 | AC-007 | cache mode lacks retention | storage-inconsistent | #605 |
| TEST-108 | AC-007 | expiry not after retrieval | storage-inconsistent | #605 |
| TEST-109 | AC-007 | retention delete_when lacks expiry | storage-inconsistent | #605 |
| TEST-110 | AC-007 | retention delete_when lacks rights-revoked | storage-inconsistent | #605 |
| TEST-111 | AC-007 | retention includes optional feature-closed | Accepted; no auto-deletion by validator | #605 |
| TEST-112 | AC-007 | elapsed real time beyond declared expiry | No clock read or authorization claim; same deterministic output; downstream access must recheck time | #605 |
| TEST-113 | AC-008 | cited evidence | Accept supports citation to retrieved source; remove support or add contradiction and reject evidence-inconsistent | #605 |
| TEST-114 | AC-008 | conflicting evidence | Accept retrieved support+contradiction; remove either relation and reject evidence-inconsistent | #605 |
| TEST-115 | AC-008 | searched-not-found evidence | Accept no citations and search_record; null search_record rejects evidence-inconsistent | #605 |
| TEST-116 | AC-008 | not-searched evidence | Accept no citations and null search_record; supplied search_record rejects evidence-inconsistent | #605 |
| TEST-117 | AC-008 | unreachable evidence | Accept inaccessible source citation; cite retrieved source and reject evidence-inconsistent | #605 |
| TEST-118 | AC-008 | unresolved citation ID | citation-unresolved | #605 |
| TEST-119 | AC-008 | unresolved citation revision | citation-unresolved | #605 |
| TEST-120 | AC-008 | many sources/claims and both relation types | All distinct citations preserved; conflicting retained rather than selecting one winner | #605 |
| TEST-121 | AC-008 | unassessed semantic state | Accept null actor/note; nonnull actor or note rejects semantic-inconsistent | #605 |
| TEST-122 | AC-008 | supported semantic state | Accept supported with actual actor/note assertion; missing actor rejects semantic-inconsistent | #605 |
| TEST-123 | AC-008 | not-supported semantic state | Accept not-supported with actual actor/note assertion; missing note rejects semantic-inconsistent | #605 |
| TEST-124 | AC-008 | disputed semantic state | Accept disputed with actual actor/note assertion; missing actor rejects semantic-inconsistent | #605 |
| TEST-125 | AC-008 | independent-review actor | Recorded with note but cannot prove role independence or bypass existing review | #605 |
| TEST-126 | AC-008 | human actor | Recorded with note but not authenticated by VALID | #605 |
| TEST-127 | AC-009 | extra PDF in records subtree | research-dir-unexpected-file; original never printed | #605 |
| TEST-128 | AC-009 | extra directory in records subtree | research-dir-unexpected-file | #605 |
| TEST-129 | AC-009 | symlink file input | file-unreadable | #605 |
| TEST-130 | AC-009 | symlink parent under repository | location-mismatch | #605 |
| TEST-131 | AC-009 | extra symlink or special entry in records subtree | research-dir-unexpected-file | #605 |
| TEST-132 | AC-009 | sibling map/log/relations paths | Not rejected as owned records, not auto-read or exported | #605 |
| TEST-133 | AC-009 | unknown full-text content field | schema-invalid; bounded free prose still requires rights review | #605 |
| TEST-134 | AC-009 | explicit metadata/receipt fixture export | Selection includes only declared public metadata/receipt; cache not recursively included | #605 |
| TEST-135 | AC-009 | workflow upload contracts | Existing glob behavior unchanged; no acquisition introduced by #605 | #605 |
| TEST-136 | AC-010 | synthetic private-key header | secret-detected using G-11 case behavior; no value in stdout/stderr | #605 |
| TEST-137 | AC-010 | synthetic AWS access key | secret-detected using G-11 case behavior; no value in stdout/stderr | #605 |
| TEST-138 | AC-010 | synthetic GitHub ghp token | secret-detected using G-11 case behavior; no value in stdout/stderr | #605 |
| TEST-139 | AC-010 | synthetic GitHub github_pat token | secret-detected using G-11 case behavior; no value in stdout/stderr | #605 |
| TEST-140 | AC-010 | synthetic OpenAI token family | secret-detected using G-11 case behavior; no value in stdout/stderr | #605 |
| TEST-141 | AC-010 | synthetic Slack token family | secret-detected using G-11 case behavior; no value in stdout/stderr | #605 |
| TEST-142 | AC-010 | synthetic generic credential assignment | secret-detected using G-11 case behavior; no value in stdout/stderr | #605 |
| TEST-143 | AC-010 | URL userinfo | value-invalid; no value echoed | #605 |
| TEST-144 | AC-010 | file scheme | value-invalid; no value echoed | #605 |
| TEST-145 | AC-010 | URL control character | value-invalid; no value echoed | #605 |
| TEST-146 | AC-010 | URL backslash | value-invalid; no value echoed | #605 |
| TEST-147 | AC-010 | URL empty hostname | value-invalid; no value echoed | #605 |
| TEST-148 | AC-010 | URL credential query key | value-invalid; no value echoed | #605 |
| TEST-149 | AC-010 | percent-encoded credential query key | value-invalid; no value echoed | #605 |
| TEST-150 | AC-010 | encoded secret token in otherwise valid URL | secret-detected after decoding | #605 |
| TEST-151 | AC-010 | ordinary public technical URL and text | Accepted; no external request or per-send confirmation from validator | #605 |
| TEST-152 | AC-010 | malicious instruction in source quote | Remains inert text; no tool execution, approval or environment mutation | #605 |
| TEST-153 | AC-011 | #594 input reference | Admit record file using existing path/raw sha256; no research field in project-skill schema | #605 |
| TEST-154 | AC-011 | #612 endpoint/relation vocabulary fixture | Separate SRC/CLM revision/hash refs from REQ/ADR document pins; reject unsupported shape in contract fixture validation | #605 |
| TEST-155 | AC-011 | #609 ownership fixture | REQ/ADR identities refer to existing declarations; REQ→AC→TEST evidence remains existing traceability | #605 |
| TEST-156 | AC-011 | dependency inspection | No #594/#612/#609 completion prerequisite for #605; downstream runtime remains separately tracked | #605 |
| TEST-157 | AC-012 | missing or unknown CLI argument | exit 2, empty stdout, fixed usage message; unknown values never echoed | #605 |
| TEST-158 | AC-012 | file/repository and previous/no-previous cases | Four explicit scope/history combinations, exact stable output and counts | #605 |
| TEST-159 | AC-012 | missing input | file-unreadable; no content echoed | #605 |
| TEST-160 | AC-012 | BOM | file-unreadable; no content echoed | #605 |
| TEST-161 | AC-012 | invalid UTF-8 | file-unreadable; no content echoed | #605 |
| TEST-162 | AC-012 | invalid JSON | file-unreadable; no content echoed | #605 |
| TEST-163 | AC-012 | duplicate JSON key | file-unreadable; no content echoed | #605 |
| TEST-164 | AC-012 | multiple invalid fields | First phase then sorted pointer deterministic; stdout empty | #605 |
| TEST-165 | AC-012 | offline repeat and clock shift | Identical outputs; no network/clock/credential/identity reads or input writes | #605 |
| TEST-166 | AC-012 | canonicalization scratch cleanup | Private metadata-only scratch removed on success and subprocess failure | #605 |
| TEST-167 | AC-012 | Bash wrapper | argv/exit/stdout/stderr match Python on valid and invalid fixture | #605 |
| TEST-168 | AC-012 | PowerShell wrapper | argv/exit/stdout/stderr match Python; mis-cased invalid enum/pattern stays invalid | #605 |
| TEST-169 | AC-013 | non-adopter Full | Before/after artifacts, required set, exit codes and emitted events identical | #605 |
| TEST-170 | AC-013 | non-adopter Lite | Before/after artifacts, required set, exit codes and emitted events identical | #605 |
| TEST-171 | AC-013 | non-adopter legacy | Before/after artifacts, required set, exit codes and emitted events identical | #605 |
| TEST-172 | AC-013 | frozen evidence and pending human-copy | No edits; fixture checks byte-identical prior artifacts | #605 |
| TEST-173 | AC-013 | record claims approved/Done/required=false | Unknown authority field schema-invalid; no state writes | #605 |
| TEST-174 | AC-014 | packaged/root schema copies | Byte identical and identity exact | #605 |
| TEST-175 | AC-014 | catalog registration | Future suite path/runtime/ci_jobs match actual registrations; no new isolated test pipeline | #605 |
| TEST-176 | AC-014 | docs and ADR | Contract docs/changelog synchronized; ADR numbering rechecked; no automatic Accepted status | #605 |
| TEST-177 | AC-015 | reference_only temporary source | No original persists or enters Git/CI/review export; allowed metadata survives | #606/#610 pending |
| TEST-178 | AC-015 | local_cache permitted source | Actual permission + local ACL + expiry enforced; only owning local principal accesses | #606/#610 pending |
| TEST-179 | AC-015 | licensed_shared permitted source | Allowed group access works; unauthorized principal denied | #606/#610 pending |
| TEST-180 | AC-015 | unknown rights | No original persisted; reference_only/blocked with reason | #606/#610 pending |
| TEST-181 | AC-015 | rights revoked | Access/export stops and required deletion occurs without altering past receipt | #606/#610 pending |
| TEST-182 | AC-015 | expired source | Access/export stops and deletion policy executes | #606/#610 pending |
| TEST-183 | AC-015 | cache missing or access denied | Distinct unavailable result; never reuse old verification as fresh success | #606/#610 pending |
| TEST-184 | AC-015 | cache root inside repository/CI temp or symlink alias | Write refused before original material enters exportable root | #606/#610 pending |
| TEST-185 | AC-015 | cache file matches artifact staging glob | Export refuses original despite glob match | #606/#610 pending |
| TEST-186 | AC-015 | ordinary technical search terms | External search may run without per-send confirmation | #606/#610 pending |
| TEST-187 | AC-015 | explicit no-external-send condition | Local-only or STOP; no network request | #606/#610 pending |
| TEST-188 | AC-015 | secret-bearing search input | Mask/local-only/STOP before egress; no secret in logs | #606/#610 pending |
| TEST-189 | AC-016 | real original and correct hash | Actual bytes compared; genuine verification recorded | #607 pending |
| TEST-190 | AC-016 | invented well-shaped hash | Original comparison fails; no fresh verified result | #607 pending |
| TEST-191 | AC-016 | correct short quote/extraction | Extraction hash and exact line substring both compared | #607 pending |
| TEST-192 | AC-016 | paraphrased quote | Exact comparison fails despite semantically similar text | #607 pending |
| TEST-193 | AC-016 | same URL new revision | Old source binding cannot prove new bytes | #607 pending |
| TEST-194 | AC-016 | metadata-only handoff without source | not-verifiable/not-checkable; no fresh full verification | #607 pending |
| TEST-195 | AC-016 | reacquisition forbidden | Do not refetch; retain historical evidence and present inability | #606/#607 pending |
| TEST-196 | AC-016 | expired display permission | No original display even if quote previously verified | #610 pending |
| TEST-197 | AC-016 | unknown edge type or endpoint | Explicit rejection, no inferred relation | #612 pending |
| TEST-198 | AC-016 | unregistered REQ/ADR or wrong document pin | Explicit reference failure | #612/#609 pending |
| TEST-199 | AC-016 | cycle in relation graph | Terminates under graph policy; no state transition | #612 pending |
| TEST-200 | AC-016 | new research input after review | New review snapshot; previous frozen inputs unchanged | #609 pending |

## Execution state

All functional TEST rows are Planned and unexecuted. Draft validation checks document syntax, registration and references only. No tested support claim for Linux/macOS/Windows or Claude/Codex/Copilot follows from this packet. Runtime evidence belongs in a later non-frozen implementation/verification addendum.
