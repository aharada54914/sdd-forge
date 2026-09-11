# RT004 raw JSON member candidate — 2026-09-09

Approved scope remains RT-20260908-004. Protected runtime files are unchanged.
Previous turn made progress: two raw duplicate-key fixtures added and four
new failures observed through original validators. Latest runtime baseline is
still 6 passed / 24 failed, session 29345 terminal exit 1; it is not a live wait.

## Candidate

`adr-workflow-powershell-json-members-candidate-20260909.patch` adds 74 lines
as unapplied DATA only. SHA-256:
`6178f24ca54191d1ef0eec5f8ccaf239fa32964b6ae60fc56c538fa4287b0e88`.

`Assert-AdrJsonMembers` scans strict JSON tokens before whole-object parsing.
An explicit frame stack tracks root/object/array grammar; each object owns an
Ordinal key set. Key decoding uses ConvertFrom-Json on one isolated string in
an array, never on a duplicate-bearing object. Escaped-equivalent names collide;
separate sibling objects do not share key sets. No new dependency or explicit
recursion-depth cap is introduced. This is a string validator, not a safe file
reader: its caller must supply text decoded from the same checked byte snapshot
whose raw digest is bound, and must propagate every exception as failure.

## Root static review, not independent approval

Checked transitions: empty containers; key/colon/value/separator order;
required value/key after comma; mismatched close; root trailing content;
incomplete root/container; whitespace restricted to JSON whitespace; raw
control characters and unrecognized escapes; object-local exact decoded keys.
No Critical defect identified in this bounded static review. The full-file
consumer must still enforce object schema and ADR contracts after this check.
The helper must run before any parsed-object extension/absence decision.

Warning: raw UTF-8 decoding, lone-surrogate behavior, PS5.1 isolated-string
decoding and downstream snapshot wiring are not runtime-verified. Add nested
duplicate and sibling-positive fixtures, malformed separator controls, and
empty/escaped-key controls before declaring the complete implementation tested.
The existing duplicate-root and escaped-root regressions remain RED. Do not
claim the newly authored helper passes them without permitted execution.

## Verification and remaining work

`git apply --numstat` exited 0 (74 additions): patch format only, not application
or PowerShell parsing. `git diff --check` exited 0. Candidate extraction,
execution and protected application were not performed. TDD GREEN is pending
the completed independent review and human application required by the boundary.

Next: finish the equivalent Bash raw-member validation candidate, safe byte
snapshots and both callers; compose all slices into one coherent patch, complete
the scoped tests, then obtain independent security/contract review before human
application. Existing candidate slices share insertion anchors and must NOT be
blindly concatenated or applied one at a time. No task status, review verdict,
commit, push, merge or Issue closure changed.

## Follow-up: strict UTF-8 snapshot, 2026-09-09

The earlier 74-line candidate hash above identifies the earlier version only.
The current candidate contains 93 additions, SHA-256
`e8ff2e9b7e163bcc76762fa768e8cf5e419bc0e2843ac287af3b29cf26e6b1bf`.
It adds `Read-AdrJsonSnapshot`: read bytes once, decode with throwing UTF-8,
validate raw JSON members, and hash those exact bytes. The returned text and
digest come from that one snapshot. A leading BOM is removed only from parser
text, not from the digest. SHA resources are disposed in a finally block.
No candidate code was applied, extracted, parsed or executed.

Before authoring this helper, the new `invalid-utf8` fixture showed both actual
validators accept a contract with byte FF in a JSON string. The final fixture
checks iconv availability and its acceptance of the original valid file before
asserting rejection of the mutated bytes; an absent tool cannot count as proof.
This does not mutate ADR pins or break JSON punctuation. It tests the actual
workflow opening path, not the new helper in isolation.

Final command: `bash tests/impl-review-adr-inputs.tests.sh --workflow-only`,
captured with pipefail and tee. Session 2534 terminated with exit 1:
**6 passed / 28 failed**, all 34 cases reached. The two UTF-8 negatives returned
exit 0 / workflow-state ok, while the previous 26 failures remain unresolved.
Log: `/tmp/rt004-encoding-final.3ujcOk`, SHA-256
`1a1e773563b14eb90d6cea804e61eaa44df77cc2731283408a08d93aad820047`.
Test SHA-256:
`651a79737ac20fc16a13b5559f4c89759eb6c8752c904a36ffd8e74950526b51`.
The first encoding run (70191, terminal exit 1) has the same output hash;
its final successor additionally validates the iconv prerequisite.

Root static review: the helper does not reopen the file for hashing and cannot
silently replace invalid UTF-8. It intentionally returns text rather than a
whole-object conversion that could unwrap a singleton array in PowerShell.
Caller schema checks must enforce the raw object root before object conversion.
Warnings remain: canonical path/reparse checks and their race boundary are not
implemented by this reader; current-evidence stability must be checked by the
caller; BOM, non-ASCII, root-array and PS5.1 controls still need coverage. This
is not an independent security review, nor a claim of race-free file access.

Bash syntax, whitespace and candidate patch-format checks exited 0. Protected
validator hashes remain the previously recorded values. No TDD GREEN, native
Windows result, formal review PASS, commit, push, merge or issue closure.
Next: complete safe path/caller integration and the Bash snapshot equivalent,
combine the candidate slices coherently, then independent review and human
application. Fresh GitHub queries still show seven open PRs and no active
CheckRuns; PR245's lack of failing Actions is not evidence of successful CI.
