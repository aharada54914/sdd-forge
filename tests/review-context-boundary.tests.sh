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
grep -Fq 'Do not read any reviewer-b.json or integrated-summary.json from prior rounds.' "$REVIEWER_A" ||
  fail "impl-reviewer-a.md no longer forbids reading integrated-summary.json; update review-context-boundary.md"

grep -Fq 'persisted impl reviewer-a manifest is missing previous-round summary' "$PRECHECK" ||
  fail "impl-review-precheck no longer requires reviewer-a's previous-round summary; update review-context-boundary.md"

# --- every cited line number in the field table must still exist ---------------
# The table cites the validator as (`:NNN`). A citation past end-of-file is a
# certain drift signal and is cheap to catch.
validator_lines=$(wc -l < "$VALIDATOR" | tr -d '[:space:]')
while read -r cited; do
  (( cited >= 1 && cited <= validator_lines )) ||
    fail "review-context-boundary.md cites validate-review-context-set.sh:${cited}, past its ${validator_lines} lines"
done < <(grep -o '(`:[0-9]\+' "$DOC" | grep -o '[0-9]\+' | sort -un)

# --- the document must state the exemption it exists to state -----------------
grep -Fq 'identity_ledger_sha256' "$DOC" || fail "document no longer mentions identity_ledger_sha256"
grep -Fq 'do not re-verify' "$DOC" || fail "document no longer states the do-not-re-verify rule"

printf 'ok: review-context-boundary citations match the validator\n'
