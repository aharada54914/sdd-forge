# RT004 Bash snapshot composition — candidate only

Scope: approved ADR contract remediation; no protected implementation applied.
Candidate: adr-workflow-bash-snapshot-composed-candidate-20260909.patch
SHA256: 9df2f8f01b8008f59168ec38fbb6bd92c8426edc358ee089da7c01777523a958

The new composed patch retains the prior history/current-stage candidate and
inserts the raw JSON-member checker. History acquisition now uses a private
mktemp directory ending XXXXXX under umask 077 and a function subshell with an
EXIT cleanup trap. Allocation failure stops immediately. Cleanup names only the
seven known snapshot data files, then removes the empty temporary directory;
cleanup failure yields nonzero exit and never authorizes history.

Each present saved input is path-checked, copied as bytes to that private
directory, checked by strict iconv UTF-8 conversion and the raw member checker,
then hashed. The history JSON readers, core digest derivation and manifest hash
comparisons consume these snapshot files. Prior-round summary uses the same
sequence. The raw checker tolerates a leading BOM while the digest retains its
original bytes. No snapshot content is put through a shell variable, avoiding
NUL removal and trailing-newline stripping before validation.

The old legacy early return was removed: no-extension history still rejects
ADR-like manifest paths and returns an empty ADR set, but now reaches the same
source-path/hash stability recheck. Missing precheck remains permitted only
when extension pairing allows it. Existing linked/nonregular prechecks are not
treated as absent. Persistent source changes fail comparison with snapshot
hashes. This does not claim atomic no-follow acquisition or prevent a hostile
same-user actor from manipulating files concurrently.

Verification: git apply --numstat exited 0 (459 insertions / 11 deletions), and
git diff --check exited 0. These do not execute or syntax-check candidate code.
Protected original Bash SHA256 remains
15a4ef0a72c8be78c40b38e692ee7a46d8664d825e61ab99915086dae0f02d1e.
Historical actual-runtime result remains 6 passed / 28 failed; no GREEN claimed.

Independent bounded static review is in progress with
/root/rt004_snapshot_static_review; this is not a formal QG. Remaining checks:
iconv availability/behavior on supported systems, valid BOM and non-ASCII
controls, strict root-object controls, cleanup failure and interruption cases,
legacy compatibility, and caller-level snapshot continuity. The existing outer
stage validator still rereads evidence after this helper, so the whole stage
does not yet have the PowerShell candidate's snapshot-object continuity.
All-consumer integration, complete independent review and human application
remain mandatory. No commit/push/merge, issue closure or verdict change.

## Independent static review and bounded correction

/root/rt004_snapshot_static_review completed a read-only review of candidate
9df2f8f01b8008f59168ec38fbb6bd92c8426edc358ee089da7c01777523a958:
Critical 0, Major 1, Minor 0. The Major was inherited from the prior history
candidate: ADR-set path regex used ^/$ rather than absolute start/end, allowing
a possible final-newline match before opening's later filesystem validation.
This was a static finding, not a runtime reproduction.

The candidate's ADR-set grammar now uses absolute \\A/\\z anchors, matching the
PowerShell candidate's strict path grammar. Corrected candidate SHA256:
5e42535169df822c8e69fd41219301704055b6df65dd6ea09fd7dd8837f4d9a8.
Format numstat still exits 0 (459 insertions / 11 deletions). Bounded static
re-review requested; escaped-final-newline rejection fixture remains required.
The original review and its finding are retained, not retroactively marked PASS.

The same independent reviewer subsequently read the corrected line and confirmed
the static Major resolved, with no outstanding finding from this bounded review.
The reviewer explicitly did not certify runtime behavior or the full candidate.
