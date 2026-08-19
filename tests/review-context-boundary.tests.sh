#!/usr/bin/env bash
# review-context-boundary.md cites the validator by file:line. Those citations are
# load-bearing: a reviewer is told to trust the document instead of re-verifying
# identity_ledger_sha256 itself, so a stale citation would leave the one field the
# document exempts unexplained. These assertions fail when the cited lines stop
# saying what the document claims they say.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOC="$ROOT/plugins/sdd-review-loop/references/review-context-boundary.md"
VALIDATOR="$ROOT/plugins/sdd-quality-loop/scripts/validate-review-context-set.sh"
PRECHECK="$ROOT/plugins/sdd-review-loop/scripts/impl-review-precheck.sh"
REVIEWER_A="$ROOT/plugins/sdd-review-loop/agents/impl-reviewer-a.md"

fail() { printf 'not ok: %s\n' "$1" >&2; exit 1; }

for f in "$DOC" "$VALIDATOR" "$PRECHECK" "$REVIEWER_A"; do
  [[ -f "$f" ]] || fail "missing input: ${f#$ROOT/}"
done

# --- the ordering claim -------------------------------------------------------
# The document's central claim is that identity_ledger_sha256 is compared BEFORE
# the reservation is appended, which is why it is stale by the time a reviewer
# reads it. Assert the ordering holds in the script rather than trusting prose.

check_line=$(grep -n 'actual_ledger_sha256" == "\$bound_ledger_sha256' "$VALIDATOR" | head -1 | cut -d: -f1)
[[ -n "$check_line" ]] || fail "validator no longer compares identity_ledger_sha256 against the ledger"

lock_recheck_line=$(grep -n 'sha256_file "\$ledger")" == "\$bound_ledger_sha256' "$VALIDATOR" | head -1 | cut -d: -f1)
[[ -n "$lock_recheck_line" ]] || fail "validator no longer re-checks the ledger hash under the reservation lock"

append_line=$(grep -n '\.records += \[{' "$VALIDATOR" | head -1 | cut -d: -f1)
[[ -n "$append_line" ]] || fail "validator no longer appends a record to the ledger"

(( check_line < append_line )) ||
  fail "identity_ledger_sha256 is no longer compared before the append; review-context-boundary.md's staleness claim is wrong"
(( lock_recheck_line < append_line )) ||
  fail "the under-lock ledger re-check no longer precedes the append"

# --- the record-hash construction the document tells reviewers to recompute ----
# The document instructs reviewers to verify record_sha256 by recomputing
# sha256("<sequence>|<stage>|<role>|<run_id>|<host_session_id>|<previous>").
# If the validator's construction changes, that instruction becomes wrong.
grep -Fq '"$sequence|$stage|$role|$run_id|$host_session_id|$previous_record_sha256"' "$VALIDATOR" ||
  fail "validator's record-hash construction changed; the recompute recipe in review-context-boundary.md is stale"

# --- the contradiction the document documents ---------------------------------
# If either half of the impl-reviewer-a / precheck contradiction is resolved, the
# document's account of it becomes false and must be updated.
grep -Fq 'Issue #143' "$REVIEWER_A" ||
  fail "impl-reviewer-a.md lost the Issue #143 carve-out; update review-context-boundary.md"

grep -Fq 'persisted impl reviewer-a manifest is missing previous-round summary' "$PRECHECK" ||
  fail "impl-review-precheck no longer requires reviewer-a's previous-round summary; update review-context-boundary.md"

# --- every citation must still land on the construct it names ------------------
# A bounds check ("the number is <= EOF") cannot catch the drift that actually
# happens: an insertion earlier in the subject file slides every later citation
# onto a different -- still existing, so still in bounds -- line. That is exactly
# how the four reservation-side citations went stale when the round-consistency
# block was inserted ahead of them, and the old bounds check passed throughout.
# So pin each citation to text that must appear inside the line (or line range)
# it names.
#
# Rows are "<citation> <subject> <fixed string that must appear in it>", one row
# per required string; a citation may claim several, and all must hold. <subject>
# is explicit because the document's bare `:NNN` form does not always mean the
# validator -- `:275` names impl-review-precheck.sh, which the old bounds check
# silently measured against the validator's length instead.
#
# The citation text must match the document byte for byte. The loops below fail
# in both directions: a citation the document adds with no row here, and a row
# whose citation the document no longer makes.
anchors() {
  cat <<'ANCHORS'
# The flat contract predicates in the manifest jq filter.
:157 validator .schema == "review-context-invocation/v2"
:158 validator .input_mode == "file-manifest"
:159 validator .fallback_mode == "none"
:160 validator .read_only == true
:161 validator .feature | type == "string" and test(
:162 validator .sequence | type == "number" and floor == . and . >= 2
:163 validator .identity_ledger_path == "reports/review-context/identity-ledger.json"
:164 validator .identity_ledger_sha256 | type == "string" and test("^[0-9a-f]{64}$")
:154 validator .task_id | type == "string" and test("^T-[0-9]{3}$")

# stage/role must be an authorized pair.
:189-192 validator case "$stage:$role" in
:189-192 validator fail CONTRACT 'stage and role are not an authorized invocation pair'

# identity_ledger_sha256 equality: before the reservation, and again under the lock.
:208 validator [[ "$actual_ledger_sha256" == "$bound_ledger_sha256" ]]
:348 validator [[ "$(sha256_file "$ledger")" == "$bound_ledger_sha256" ]]

# The ledger contract's global-uniqueness requirement, and the per-invocation
# check that this run_id / host_session_id is not already persisted.
:234-235 validator ([.records[].run_id] | unique | length) == (.records | length)
:234-235 validator ([.records[].host_session_id] | unique | length) == (.records | length)
:262-265 validator all(.records[]; .run_id != $run and .host_session_id != $session)
:262-265 validator fail IDENTITY 'run or host-session identity was already persisted'

# The chain position this invocation must occupy.
:260 validator [[ "$sequence" -eq "$expected_sequence" && "$previous_record_sha256" == "$expected_previous" ]]

# The record-hash construction a reviewer is told to recompute: the chain-walk
# copy the validator verifies existing records with, and the reservation copy it
# builds the new record with. The document cites both as "the same construction".
:245 validator "$record_sequence|$record_stage|$record_role|$record_run|$record_session|$record_previous"
:342 validator "$sequence|$stage|$role|$run_id|$host_session_id|$previous_record_sha256"

# task_id shape, and the implementation report that must carry it.
:268-282 validator if [[ "$stage:$role" == quality:sdd-evaluator ]]; then
:268-282 validator fail PATH 'sdd-evaluator implementation report task field does not match task ID'

# Manifest path admission: canonical, not a raw reviewer report, role-authorized,
# no symlink component. One row per clause the field table claims.
:284-301 validator is_canonical_path "$path"
:284-301 validator is_forbidden_review_output "$path"
:284-301 validator path_is_authorized "$stage" "$role" "$feature" "$path" "$expected_hash"
:284-301 validator fail PATH "$role input traverses a symbolic link: $path"

# Manifest hash equality against the file on disk.
:302-304 validator actual_hash=$(sha256_file "$candidate")
:302-304 validator [[ "$actual_hash" == "$expected_hash" ]]

# The append, and the line printing the value a reviewer compares its record to.
:353-368 validator '.records += [{
:353-368 validator mv "$temp_ledger" "$ledger"
:374 validator printf 'REVIEW_CONTEXT_OK %s\n' "$record_hash"

# impl-review-precheck.sh, not the validator.
impl-review-precheck.sh:251 precheck fail "persisted impl reviewer-a manifest is missing previous-round summary"
:275 precheck [[ -z "$MODE" || "$MODE" == "--verify-inputs" || "$MODE" == "--provenance-rereview" ]]
ANCHORS
}

subject_path() {
  case "$1" in
    validator) printf '%s' "$VALIDATOR" ;;
    precheck)  printf '%s' "$PRECHECK" ;;
    *) fail "anchor table names an unknown subject file: $1" ;;
  esac
}

anchor_rows() { anchors | grep -v '^[[:space:]]*#' | grep -v '^[[:space:]]*$'; }

# Citations as the document writes them: `:NNN`, `:NNN-MMM`, `file.sh:NNN`.
doc_citations() {
  {
    grep -oE '`:[0-9]+(-[0-9]+)?`' "$DOC"
    grep -oE '`[A-Za-z0-9._-]+\.(sh|ps1):[0-9]+(-[0-9]+)?`' "$DOC"
  } | tr -d '`' | sort -u
}

while read -r cited; do
  anchor_rows | awk -v c="$cited" '$1 == c { found = 1 } END { exit(found ? 0 : 1) }' ||
    fail "review-context-boundary.md cites ${cited} with no anchor in this suite; add a row stating what that line must contain, so the citation cannot silently slide"
done < <(doc_citations)

while read -r cited; do
  grep -Fq "\`${cited}\`" "$DOC" ||
    fail "this suite anchors ${cited}, which review-context-boundary.md no longer cites; drop the stale row"
done < <(anchor_rows | awk '{ print $1 }' | sort -u)

anchor_count=0
while read -r cited subject pattern; do
  subject_file=$(subject_path "$subject")
  subject_name=${subject_file##*/}
  span=${cited##*:}
  start=${span%%-*}
  end=${span##*-}
  (( start >= 1 && end >= start )) ||
    fail "anchor table has a malformed citation: ${cited}"
  # An empty pattern would match every line, so a two-field row would assert
  # nothing while still counting toward the total. Refuse it.
  [[ -n "$pattern" ]] ||
    fail "anchor table row for ${cited} has no pattern; a blank pattern asserts nothing"

  # grep -c '' counts lines the way sed addresses them, including a final
  # unterminated one, which wc -l would miss.
  subject_lines=$(grep -c '' "$subject_file")
  (( end <= subject_lines )) ||
    fail "review-context-boundary.md cites ${subject_name}:${span}, past its ${subject_lines} lines"

  sed -n "${start},${end}p" "$subject_file" | grep -Fq -- "$pattern" ||
    fail "review-context-boundary.md cites ${subject_name}:${span} for \"${pattern}\", but those lines no longer contain it; the citation has slid off the construct it describes"
  anchor_count=$((anchor_count + 1))
done < <(anchor_rows)

# --- the document must state the exemption it exists to state -----------------
grep -Fq 'identity_ledger_sha256' "$DOC" || fail "document no longer mentions identity_ledger_sha256"
grep -Fq 'do not re-verify' "$DOC" || fail "document no longer states the do-not-re-verify rule"

printf 'ok: review-context-boundary citations match the validator (%d anchors verified)\n' "$anchor_count"
