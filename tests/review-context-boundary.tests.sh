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
# The previous-round-summary requirement moved from impl-review-precheck.sh
# into the shared lib in the #325 require_persisted_pass consolidation; the
# precheck still enforces it by sourcing the lib.
PRECHECK="$ROOT/plugins/sdd-review-loop/scripts/lib/review-precheck-common.sh"
# The mode admission the document cites is still in the precheck itself, not in
# the lib, so the anchor table needs both as subjects.
IMPL_PRECHECK="$ROOT/plugins/sdd-review-loop/scripts/impl-review-precheck.sh"
REVIEWER_A="$ROOT/plugins/sdd-review-loop/agents/impl-reviewer-a.md"

fail() { printf 'not ok: %s\n' "$1" >&2; exit 1; }

for f in "$DOC" "$VALIDATOR" "$PRECHECK" "$IMPL_PRECHECK" "$REVIEWER_A"; do
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

# --- every citation must still land on the construct it names -----------------
# A bounds check ("the number is <= EOF") cannot catch the drift that actually
# happens: an insertion earlier in the subject file slides every later citation
# onto a different -- still existing, so still in bounds -- line. The bounds
# check this replaces passed throughout the WFI-037 work, which took the
# validator from 374 to 589 lines and left every citation in this document
# pointing at unrelated code.
#
# So pin each citation to text that must appear inside the line (or line range)
# it names.
#
# Rows are "<citation> <subject> <fixed string that must appear in it>", one row
# per required string; a citation may claim several, and all must hold.
# <subject> is explicit because the document's bare `:NNN` form does not always
# mean the validator.
#
# The citation text must match the document byte for byte. The loops below fail
# in both directions: a citation the document adds with no row here, and a row
# whose citation the document no longer makes.
anchors() {
  cat <<'ANCHORS'
# The flat contract predicates in the manifest jq filter.
:245 validator .schema == "review-context-invocation/v2"
:246 validator .input_mode == "file-manifest"
:247 validator .fallback_mode == "none"
:248 validator .read_only == true
:249 validator .feature | type == "string" and test(
:250 validator .sequence | type == "number" and floor == . and . >= 2
:251 validator .identity_ledger_path == "reports/review-context/identity-ledger.json"
:252 validator .identity_ledger_sha256 | type == "string" and test("^[0-9a-f]{64}$")
:235 validator .task_id | type == "string" and test("^T-[0-9]{3}$")

# The optional quality-stage gate-report declaration: presence gate and shape.
:236-241 validator if has("gate_report_declaration") then
:236-241 validator (keys | sort) == ["path", "sha256"]

# The declared gate report must be canonical, symlink-free, a regular file
# under reports/quality-gate/, and hash to the pinned value before any row is
# read from it.
:448-463 validator fail PATH "sdd-evaluator gate-report declaration traverses a symbolic link
:448-463 validator [[ "$(sha256_file "$gate_report_absolute")" == "$gate_report_declaration_sha256" ]]

# Its `## Post-Fix Artifacts` rows are the second authorization source.
:128-134 validator gate_report_output_is_declared() {
:128-134 validator '## Post-Fix Artifacts'

# stage/role must be an authorized pair. The identically-shaped `case` inside
# path_is_authorized is NOT this one, which is why the fail arm is pinned too.
:286-288 validator case "$stage:$role" in
:286-288 validator fail CONTRACT 'stage and role are not an authorized invocation pair'

# No rows for the ledger's global-uniqueness check or for the line that prints
# REVIEW_CONTEXT_OK. The document describes both -- the WFI-037 rewrite states
# the identity_unique=yes guarantee in prose -- but cites neither by line, and
# this table mirrors the document's citations rather than the validator's
# contents. Anchoring an uncited construct would make the reverse loop below
# fail on a document that is not wrong. If those claims should be pinned, the
# citation belongs in the document first.

# identity_ledger_sha256 equality: before the reservation, and again under the
# reservation lock.
:419 validator [[ "$actual_ledger_sha256" == "$bound_ledger_sha256" ]]
:555 validator [[ "$(sha256_file "$ledger")" == "$bound_ledger_sha256" ]]

# The chain position this invocation must occupy.
:421 validator [[ "$sequence" -eq "$expected_sequence"

# The record-hash construction a reviewer is told to recompute: the chain-walk
# copy the validator verifies existing records with, and the reservation copy it
# builds the new record with. The document cites both as "the same construction".
:344 validator "$record_sequence|$record_stage|$record_role|$record_run|$record_session|$record_previous"
:549 validator "$sequence|$stage|$role|$run_id|$host_session_id|$previous_record_sha256"

# task_id shape, and the implementation report that must carry it.
:428-441 validator if [[ "$stage:$role" == quality:sdd-evaluator ]]; then
:428-441 validator fail PATH 'sdd-evaluator implementation report task field does not match task ID'

# Manifest path admission: canonical, not a raw reviewer report, role-authorized,
# no symlink component. One row per clause the field table claims.
:480-493 validator is_canonical_path "$path"
:480-493 validator is_forbidden_review_output "$path"
:480-493 validator path_is_authorized "$stage" "$role" "$feature" "$path" "$expected_hash"

# Manifest hash equality against the file on disk.
:497 validator actual_hash=$(sha256_file "$candidate")

# The append.
:564-574 validator '.records += [{

# The two impl-review-precheck claims. The previous-round-summary requirement
# lives in the shared lib since the #325 consolidation; the mode admission is
# still in the precheck itself. Two subjects, so both are named.
review-precheck-common.sh:231 precheck fail "persisted impl reviewer-a manifest is missing previous-round summary"
impl-review-precheck.sh:69 impl-review-precheck [[ -z "$MODE" || "$MODE" == "--verify-inputs" || "$MODE" == "--provenance-rereview" ]]
ANCHORS
}

subject_path() {
  case "$1" in
    validator) printf '%s' "$VALIDATOR" ;;
    precheck)  printf '%s' "$PRECHECK" ;;
    impl-review-precheck) printf '%s' "$IMPL_PRECHECK" ;;
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

# ==============================================================================
# Reservation/verification boundary (TEST-RCB-001..010)
#
# validate-review-context-set.{sh,ps1} is invoked two ways: `--reserve` to
# claim the next ledger sequence and append it, and a bare invocation to
# verify a manifest. Three checks (identity_ledger_sha256 equality, "extends
# the tip", and "identity not yet persisted") were written for the reserve
# case only but ran unconditionally, so a manifest could never be verified
# again once its own reservation succeeded -- the ledger hash it bound is
# now stale by definition, it is no longer the tip once anything else is
# reserved, and its own identity is now "already persisted". A branch
# merge/re-chain landing later records on top of an already-reserved
# manifest hits exactly this and made every reserved manifest on that
# branch permanently unverifiable.
#
# The validator now keys off the ledger itself: an identity is "reserved"
# once some record's run_id AND host_session_id both match the manifest's.
# If so, this is verification of that identity -- the persisted record must
# match the manifest exactly, and the tip/hash checks that only make sense
# before a reservation happens are skipped. Otherwise it is a reservation,
# and today's checks apply unchanged. A record matching on only one of the
# two identity fields is a distinct third case (two launches colliding on
# one identity) and fails loudly regardless of which mode was requested.
#
# Every fixture below is a disposable temp directory -- never this
# repository's own reports/review-context/identity-ledger.json.
# ==============================================================================

VALIDATOR_PS1="$ROOT/plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1"
[[ -f "$VALIDATOR_PS1" ]] || fail "missing input: ${VALIDATOR_PS1#$ROOT/}"

RCB_TMP="$(mktemp -d)"
trap 'rm -rf "$RCB_TMP"' EXIT

rcb_sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else shasum -a 256 "$1" | awk '{print $1}'; fi
}
rcb_sha256_text() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'
  else shasum -a 256 | awk '{print $1}'; fi
}

rcb_run_bash() { "$VALIDATOR" "$@"; }
rcb_run_pwsh() {
  local manifest=$1 repository=$2
  shift 2
  if [[ ${1:-} == --reserve ]]; then
    pwsh -NoLogo -NoProfile -File "$VALIDATOR_PS1" \
      -Manifest "$manifest" -RepositoryRoot "$repository" -Reserve
  else
    pwsh -NoLogo -NoProfile -File "$VALIDATOR_PS1" \
      -Manifest "$manifest" -RepositoryRoot "$repository"
  fi
}

# Fresh single-genesis-record ledger, plus one spec-reviewer-a manifest at
# sequence 2 (run RCB-run-2 / session RCB-session-2) that correctly extends
# it. feature "rcb"; the only allowed input is specs/rcb/requirements.md,
# which is authorized for both spec and impl stage reviewers, so tampering
# .stage in the tests below never trips path authorization first.
rcb_new_fixture() {
  local dir=$1
  mkdir -p "$dir/reports/review-context" "$dir/specs/rcb"
  local run1=RCB-run-1 session1=RCB-session-1
  local h1
  h1=$(printf '%s' "1|spec|spec-reviewer-a|${run1}|${session1}|" | rcb_sha256_text)
  cat > "$dir/reports/review-context/identity-ledger.json" <<EOF
{"schema":"review-identity-ledger/v1","records":[{"sequence":1,"stage":"spec","role":"spec-reviewer-a","run_id":"${run1}","host_session_id":"${session1}","previous_record_sha256":"","record_sha256":"${h1}"}]}
EOF
  printf 'rcb fixture requirements\n' > "$dir/specs/rcb/requirements.md"
  local ledger_hash req_hash
  ledger_hash=$(rcb_sha256_of "$dir/reports/review-context/identity-ledger.json")
  req_hash=$(rcb_sha256_of "$dir/specs/rcb/requirements.md")
  cat > "$dir/manifest.json" <<EOF
{
  "schema": "review-context-invocation/v2",
  "input_mode": "file-manifest",
  "fallback_mode": "none",
  "read_only": true,
  "stage": "spec",
  "role": "spec-reviewer-a",
  "feature": "rcb",
  "run_id": "RCB-run-2",
  "host_session_id": "RCB-session-2",
  "sequence": 2,
  "identity_ledger_path": "reports/review-context/identity-ledger.json",
  "identity_ledger_sha256": "${ledger_hash}",
  "previous_record_sha256": "${h1}",
  "allowed_input_manifest": [
    {"path": "specs/rcb/requirements.md", "sha256": "${req_hash}"}
  ]
}
EOF
}

# rcb_append_record <ledger> <sequence> <stage> <role> <run_id> <session>
# Appends a real, chain-valid record directly (simulating what a concurrent
# launch, or a branch merge/re-chain, leaves behind).
rcb_append_record() {
  local ledger=$1 sequence=$2 stage=$3 role=$4 run=$5 session=$6
  local tip hash
  tip=$(jq -r '.records[-1].record_sha256' "$ledger")
  hash=$(printf '%s' "${sequence}|${stage}|${role}|${run}|${session}|${tip}" | rcb_sha256_text)
  jq --arg h "$hash" --arg tip "$tip" --arg stage "$stage" --arg role "$role" \
    --arg run "$run" --arg session "$session" --argjson seq "$sequence" \
    '.records += [{sequence:$seq,stage:$stage,role:$role,run_id:$run,host_session_id:$session,previous_record_sha256:$tip,record_sha256:$h}]' \
    "$ledger" > "$ledger.tmp"
  mv "$ledger.tmp" "$ledger"
}

RCB_RUNTIMES=(bash:rcb_run_bash)
if command -v pwsh >/dev/null 2>&1; then
  RCB_RUNTIMES+=(pwsh:rcb_run_pwsh)
fi

# --- TEST-RCB-001: reserve, then verify the SAME manifest without --reserve.
for pair in "${RCB_RUNTIMES[@]}"; do
  runtime="${pair%%:*}"; run_fn="${pair##*:}"
  d="$RCB_TMP/rcb001-$runtime"
  rcb_new_fixture "$d"
  "$run_fn" "$d/manifest.json" "$d" --reserve >/dev/null ||
    fail "TEST-RCB-001 ($runtime): reservation of a fresh identity failed"
  "$run_fn" "$d/manifest.json" "$d" >/dev/null ||
    fail "TEST-RCB-001 ($runtime): verifying the just-reserved manifest without --reserve must pass"
  echo "ok: TEST-RCB-001 ($runtime) verify-after-reserve passes"
done

# --- TEST-RCB-002: reserve, append two UNRELATED records, then verify the
# original manifest again. This is the case that fails without the fix: the
# manifest is no longer the tip and its identity_ledger_sha256 is stale.
for pair in "${RCB_RUNTIMES[@]}"; do
  runtime="${pair%%:*}"; run_fn="${pair##*:}"
  d="$RCB_TMP/rcb002-$runtime"
  rcb_new_fixture "$d"
  "$run_fn" "$d/manifest.json" "$d" --reserve >/dev/null ||
    fail "TEST-RCB-002 ($runtime): reservation failed"
  ledger="$d/reports/review-context/identity-ledger.json"
  rcb_append_record "$ledger" 3 impl impl-reviewer-a RCB-run-3 RCB-session-3
  rcb_append_record "$ledger" 4 impl impl-reviewer-b RCB-run-4 RCB-session-4
  "$run_fn" "$d/manifest.json" "$d" >/dev/null ||
    fail "TEST-RCB-002 ($runtime): verify must still pass once unrelated records have landed on top (merge/re-chain case)"
  echo "ok: TEST-RCB-002 ($runtime) verify survives unrelated ledger extension"
done

# rcb_tampered <runtime> <run_fn> <test-id> <jq-filter> <expected-diagnostic-substring>
# Reserves a fresh identity, then verifies a manifest COPY with one field
# changed -- the persisted ledger record is untouched and honest, so this
# exercises the "manifest disagrees with its own persisted record" check in
# isolation, not the whole-ledger chain-hash check.
rcb_tampered() {
  local runtime=$1 run_fn=$2 id=$3 jq_filter=$4 expected=$5
  local d="$RCB_TMP/${id}-${runtime}"
  rcb_new_fixture "$d"
  "$run_fn" "$d/manifest.json" "$d" --reserve >/dev/null ||
    fail "$id ($runtime): reservation failed"
  jq "$jq_filter" "$d/manifest.json" > "$d/tampered.json"
  local out
  if out=$("$run_fn" "$d/tampered.json" "$d" 2>&1); then
    fail "$id ($runtime): a manifest disagreeing with its persisted record must be rejected (got: $out)"
  fi
  [[ "$out" == *"$expected"* ]] ||
    fail "$id ($runtime): unexpected diagnostic: $out"
  echo "ok: $id ($runtime) rejected"
}

for pair in "${RCB_RUNTIMES[@]}"; do
  runtime="${pair%%:*}"; run_fn="${pair##*:}"
  # TEST-RCB-003: persisted record's stage no longer matches the manifest.
  rcb_tampered "$runtime" "$run_fn" TEST-RCB-003 \
    '.stage = "impl" | .role = "impl-reviewer-a"' \
    "invocation stage does not match the persisted identity-ledger record"
  # TEST-RCB-004: persisted record's previous_record_sha256 no longer
  # matches the manifest.
  rcb_tampered "$runtime" "$run_fn" TEST-RCB-004 \
    ".previous_record_sha256 = (\"f\" * 64)" \
    "invocation previous-record hash does not match the persisted identity-ledger record"
  # TEST-RCB-005: manifest sequence disagrees with the persisted record.
  rcb_tampered "$runtime" "$run_fn" TEST-RCB-005 \
    '.sequence = 999' \
    "invocation sequence does not match the persisted identity-ledger record"
  # Bonus: role alone (same stage, the other valid role for it) disagreeing
  # with the persisted record -- same field family the spec calls out
  # ("sequence, stage, role, run_id, host_session_id and
  # previous_record_sha256" must all match exactly).
  rcb_tampered "$runtime" "$run_fn" TEST-RCB-005b \
    '.role = "spec-reviewer-b"' \
    "invocation role does not match the persisted identity-ledger record"
done

# --- TEST-RCB-006: --reserve against an already-persisted identity fails
# with the double-reservation diagnostic, not the reservation-mode checks.
for pair in "${RCB_RUNTIMES[@]}"; do
  runtime="${pair%%:*}"; run_fn="${pair##*:}"
  d="$RCB_TMP/rcb006-$runtime"
  rcb_new_fixture "$d"
  "$run_fn" "$d/manifest.json" "$d" --reserve >/dev/null ||
    fail "TEST-RCB-006 ($runtime): initial reservation failed"
  out=$("$run_fn" "$d/manifest.json" "$d" --reserve 2>&1) &&
    fail "TEST-RCB-006 ($runtime): reserving an already-persisted identity must fail"
  [[ "$out" == *"cannot be reserved twice"* ]] ||
    fail "TEST-RCB-006 ($runtime): unexpected diagnostic: $out"
  echo "ok: TEST-RCB-006 ($runtime) double reservation is rejected"
done

# --- TEST-RCB-007/008: a record matching run_id but not host_session_id (or
# vice versa) is a distinct failure naming which field matched and which did
# not -- never silently treated as either a reservation or a verification.
for pair in "${RCB_RUNTIMES[@]}"; do
  runtime="${pair%%:*}"; run_fn="${pair##*:}"
  d="$RCB_TMP/rcb007-$runtime"
  rcb_new_fixture "$d"
  "$run_fn" "$d/manifest.json" "$d" --reserve >/dev/null ||
    fail "TEST-RCB-007 ($runtime): reservation failed"

  jq '.run_id = "RCB-run-2" | .host_session_id = "RCB-session-OTHER" | .sequence = 5' \
    "$d/manifest.json" > "$d/partial-run.json"
  out=$("$run_fn" "$d/partial-run.json" "$d" 2>&1) &&
    fail "TEST-RCB-007 ($runtime): a run_id-only match must be rejected"
  [[ "$out" == *"run ID matches a persisted identity-ledger record but host-session ID does not"* ]] ||
    fail "TEST-RCB-007 ($runtime): unexpected diagnostic: $out"
  echo "ok: TEST-RCB-007 ($runtime) run_id-only match names the mismatch"

  jq '.host_session_id = "RCB-session-2" | .run_id = "RCB-run-OTHER" | .sequence = 5' \
    "$d/manifest.json" > "$d/partial-session.json"
  out=$("$run_fn" "$d/partial-session.json" "$d" 2>&1) &&
    fail "TEST-RCB-008 ($runtime): a host-session-id-only match must be rejected"
  [[ "$out" == *"host-session ID matches a persisted identity-ledger record but run ID does not"* ]] ||
    fail "TEST-RCB-008 ($runtime): unexpected diagnostic: $out"
  echo "ok: TEST-RCB-008 ($runtime) host-session-id-only match names the mismatch"
done

# --- TEST-RCB-009/010: reservation-mode behaviour for a genuinely new
# identity (no ledger record matches it at all) is unchanged: a manifest
# that does not extend the tip still fails, and one that does still
# succeeds and appends.
for pair in "${RCB_RUNTIMES[@]}"; do
  runtime="${pair%%:*}"; run_fn="${pair##*:}"
  d="$RCB_TMP/rcb009-$runtime"
  rcb_new_fixture "$d"

  jq '.sequence = 99' "$d/manifest.json" > "$d/bad-sequence.json"
  out=$("$run_fn" "$d/bad-sequence.json" "$d" --reserve 2>&1) &&
    fail "TEST-RCB-009 ($runtime): a non-extending fresh manifest must not reserve"
  [[ "$out" == *"invocation does not extend the canonical identity ledger"* ]] ||
    fail "TEST-RCB-009 ($runtime): unexpected diagnostic: $out"
  echo "ok: TEST-RCB-009 ($runtime) non-extending fresh manifest is rejected"

  "$run_fn" "$d/manifest.json" "$d" --reserve >/dev/null ||
    fail "TEST-RCB-010 ($runtime): a correctly extending fresh manifest must reserve"
  [[ "$(jq '.records | length' "$d/reports/review-context/identity-ledger.json")" -eq 2 ]] ||
    fail "TEST-RCB-010 ($runtime): reservation did not append exactly one record"
  echo "ok: TEST-RCB-010 ($runtime) extending fresh manifest reserves and appends"
done

printf 'ok: validate-review-context-set reservation/verification boundary is idempotent through merges (TEST-RCB-001..010, bash+pwsh)\n'
