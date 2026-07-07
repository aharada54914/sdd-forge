#!/usr/bin/env bash
# Validate a domain-review transition before any reviewer receives input or
# evidence is written. The orchestrating skill owns reviewer invocation and
# status mutation; this script owns deterministic preconditions, provenance,
# and AC-014 post-approval drift detection.
set -euo pipefail

usage() {
  echo "Usage: domain-review-precheck.sh <attempt> <round> [--edit-summary=<text>] [--reset]" >&2
  exit 1
}

fail() { echo "ERROR: domain-review-precheck: $*" >&2; exit 1; }
sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}';
  else shasum -a 256 "$1" | awk '{print $1}'; fi
}
sha256_text() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}';
  else shasum -a 256 | awk '{print $1}'; fi
}
canonical_dir() { (cd "$1" && pwd -P); }
is_sha256() { [[ "$1" =~ ^[0-9a-fA-F]{64}$ ]]; }

[[ $# -ge 2 ]] || usage
attempt="$1"; round="$2"; shift 2
edit_summary=""; reset=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --edit-summary=*) edit_summary="${1#*=}" ;;
    --reset) reset=true ;;
    *) usage ;;
  esac
  shift
done

[[ "$attempt" =~ ^[1-9][0-9]*$ ]] || fail "attempt must be a positive integer"
[[ "$round" =~ ^[1-9][0-9]*$ ]] || fail "round must be a positive integer"
[[ "$round" -le 3 ]] || fail "round must be between 1 and 3"
[[ -z "$edit_summary" || "$round" -gt 1 ]] || fail "--edit-summary is valid only after round 1"
if [[ "$round" -gt 1 ]]; then
  [[ -n "${edit_summary//[[:space:]]/}" ]] || fail "rounds 2 and 3 require a non-empty --edit-summary"
fi
if [[ "$reset" == true ]]; then
  [[ "$attempt" -gt 1 && "$round" -eq 1 ]] || fail "--reset starts only attempt N+1 round 1"
else
  [[ "$attempt" -eq 1 || "$round" -gt 1 ]] || fail "a new attempt requires --reset"
fi

repo_root="$(cd "$(dirname "$0")/../../.." && pwd -P)"
domain_dir="${repo_root}/domain"
reports_root="${repo_root}/reports"
reports_base="${reports_root}/domain-review"
context_map="${domain_dir}/context-map.md"
calibration="${repo_root}/plugins/sdd-domain/references/domain-review-calibration.md"
domain_contract="${domain_dir}/domain-contract.json"
report_dir="${reports_base}/attempt-${attempt}/round-${round}"
fingerprint_path="${reports_base}/last-approved-fingerprint.json"

# Canonical domain/ artifact set (AC-002's seven Markdown paths plus the
# machine-readable contract). Aggregates are variadic (one per aggregate);
# every *.md file directly under domain/aggregates/ is included.
declare -a canonical_paths=(
  "${domain_dir}/domain-story.md"
  "${domain_dir}/event-storming.md"
  "${domain_dir}/ubiquitous-language.md"
  "${domain_dir}/context-map.md"
  "${domain_dir}/message-flow.md"
  "${domain_dir}/c4-container.md"
  "${domain_contract}"
)

[[ -d "$repo_root" && ! -L "$repo_root" ]] || fail "repository root must be a real directory"
[[ -d "$domain_dir" && ! -L "$domain_dir" ]] || fail "domain/ directory must exist and not be a symlink"
[[ "$(canonical_dir "$domain_dir")" == "$domain_dir" ]] || fail "domain/ directory escapes repository"
for p in "${canonical_paths[@]}"; do
  [[ -f "$p" && ! -L "$p" ]] || fail "missing canonical domain/ artifact: ${p#$repo_root/}"
done
aggregates_dir="${domain_dir}/aggregates"
[[ -d "$aggregates_dir" && ! -L "$aggregates_dir" ]] || fail "domain/aggregates/ must exist and not be a symlink"
shopt -s nullglob
aggregate_files=("$aggregates_dir"/*.md)
shopt -u nullglob
[[ ${#aggregate_files[@]} -ge 1 ]] || fail "domain/aggregates/ must contain at least one aggregate card"
for p in "${aggregate_files[@]}"; do
  [[ -f "$p" && ! -L "$p" ]] || fail "aggregate card is not a regular non-symlink file: ${p#$repo_root/}"
done
[[ -f "$calibration" && ! -L "$calibration" ]] || fail "domain review calibration reference must be a regular non-symlink file"
[[ -d "$reports_root" && ! -L "$reports_root" ]] || fail "reports root must be a real directory"
[[ "$(canonical_dir "$reports_root")" == "$reports_root" ]] || fail "reports root escapes repository"
if [[ -e "$reports_base" ]]; then
  [[ -d "$reports_base" && ! -L "$reports_base" ]] || fail "domain-review report base must not be a symlink"
  [[ "$(canonical_dir "$reports_base")" == "$reports_base" ]] || fail "domain-review report base escapes reports root"
fi
status="$(sed -n 's/^Domain-Model-Status:[[:space:]]*//p' "$context_map" | head -n 1 | tr -d '[:space:]')"
[[ "$status" =~ ^(Pending|Reviewed|Approved)$ ]] || fail "context-map.md must declare a recognized Domain-Model-Status"

command -v jq >/dev/null 2>&1 || fail "jq is required"

# --- Normalized-hash helper (mirrors spec-review-precheck.sh's pattern of
# substituting the mutable status field before hashing, applied here to
# Domain-Model-Status instead of Spec-Review-Status). ---
normalized_hash_of() {
  local path="$1"
  if [[ "$path" == "$context_map" ]]; then
    sed 's/^Domain-Model-Status:[[:space:]]*.*/Domain-Model-Status: NORMALIZED/' "$path" | sha256_text
  else
    sha256 "$path"
  fi
}

# --- AC-014 drift detection -------------------------------------------------
# This is a distinct precondition from the T-006 hook guard: the guard only
# rejects an *agent-authored* write of Approved; this step detects domain/
# content that changed *after* a human already approved it, and halts until
# the human resets the status field back to Pending.
#
# The hard-stop applies only while Domain-Model-Status is still Approved:
# once a human has reset the field (to Pending, or the loop has moved it to
# Reviewed), the model is no longer approved, the sanctioned re-review path
# is exactly what should run, and the stale fingerprint is removed so the
# next human Approval records a fresh one. Without this condition the
# documented recovery ("reset to Pending, then re-review") could never
# proceed: the non-status content still differs from the fingerprint, so
# the precheck would fail forever.
if [[ -f "$fingerprint_path" && ! -L "$fingerprint_path" && "$status" != "Approved" ]]; then
  rm -f -- "$fingerprint_path"
  printf 'domain-review-precheck: stale last-approved fingerprint cleared (Domain-Model-Status is %s, not Approved) -- re-review proceeds; the next human Approval records a fresh fingerprint\n' "$status" >&2
fi
if [[ -f "$fingerprint_path" && ! -L "$fingerprint_path" ]]; then
  jq -e 'type == "object" and (keys | sort) == ["files","schema"] and .schema == "domain-review-approved-fingerprint/v1" and (.files | type == "object")' \
    "$fingerprint_path" >/dev/null 2>&1 || fail "last-approved-fingerprint.json is malformed"
  drift_paths=()
  all_current_paths=("${canonical_paths[@]}" "${aggregate_files[@]}")
  # Compare every currently-recorded fingerprint path against its live hash.
  while IFS=$'\t' read -r rel_path recorded_hash; do
    abs_path="${repo_root}/${rel_path}"
    if [[ ! -f "$abs_path" ]]; then
      drift_paths+=("$rel_path (removed)")
      continue
    fi
    current_hash="$(normalized_hash_of "$abs_path")"
    [[ "$current_hash" == "$recorded_hash" ]] || drift_paths+=("$rel_path")
  done < <(jq -r '.files | to_entries[] | [.key, .value] | @tsv' "$fingerprint_path")
  # Also catch a newly-added aggregate card not present at approval time.
  for p in "${all_current_paths[@]}"; do
    rel="${p#$repo_root/}"
    jq -e --arg rel "$rel" '.files | has($rel)' "$fingerprint_path" >/dev/null 2>&1 || drift_paths+=("$rel (added)")
  done
  if [[ ${#drift_paths[@]} -gt 0 ]]; then
    fail "domain/ drift detected since last Domain-Model-Status: Approved (AC-014). Changed paths: $(IFS=,; echo "${drift_paths[*]}"). A human must reset Domain-Model-Status back to Pending in domain/context-map.md before re-review can proceed."
  fi
fi

if [[ "$status" == "Approved" && ! -f "$fingerprint_path" ]]; then
  # First observation of an Approved model: record its fingerprint now, so a
  # future invocation can detect drift relative to this moment. This is the
  # only place this script writes the fingerprint file; a reviewed-but-not-
  # yet-approved model never reaches this branch.
  mkdir -p "$reports_base"
  tmp_fp="${fingerprint_path}.tmp.$$"
  {
    printf '{"schema":"domain-review-approved-fingerprint/v1","files":{'
    first=true
    all_paths=("${canonical_paths[@]}" "${aggregate_files[@]}")
    for p in "${all_paths[@]}"; do
      rel="${p#$repo_root/}"
      h="$(normalized_hash_of "$p")"
      $first || printf ','
      first=false
      printf '"%s":"%s"' "$rel" "$h"
    done
    printf '}}'
  } | jq . > "$tmp_fp"
  mv "$tmp_fp" "$fingerprint_path"
fi

if [[ "$status" == "Approved" ]]; then
  fail "Domain-Model-Status is Approved; domain-review-loop does not re-review an approved model unless domain/ drift was just detected above. If domain/ was intentionally changed, a human must reset Domain-Model-Status to Pending first."
fi

if [[ "$reset" == true ]]; then
  [[ "$status" == "Pending" ]] || fail "context-map.md must declare a resettable Domain-Model-Status (Pending)"
else
  [[ "$status" == "Pending" ]] || fail "context-map.md must declare Domain-Model-Status: Pending"
fi
[[ ! -L "$reports_base" ]] || fail "report base must not be a symlink"
[[ ! -e "$report_dir" ]] || fail "round destination already exists (replay is forbidden)"

# --- Compute the composite input hash over the full canonical domain/ set --
input_parts=()
for p in "${canonical_paths[@]}" "${aggregate_files[@]}"; do
  input_parts+=("$(normalized_hash_of "$p")")
done
IFS=':'
input_sha="$(printf '%s' "${input_parts[*]}" | sha256_text)"
unset IFS
calibration_sha="$(sha256 "$calibration")"

if [[ "$round" -gt 1 ]]; then
  prior_dir="${reports_base}/attempt-${attempt}/round-$((round - 1))"
  prior_precheck="${prior_dir}/precheck-result.json"
  [[ -f "$prior_precheck" ]] || fail "prior round precheck result is required"
  prior_input_sha="$(jq -r '.input_sha256' "$prior_precheck")"
  [[ "$input_sha" != "$prior_input_sha" ]] || fail "reviewed domain/ artifacts are unchanged from the prior round"
fi

if [[ "$reset" == true ]]; then
  previous_attempt="${reports_base}/attempt-$((attempt - 1))"
  [[ -d "$previous_attempt" && ! -L "$previous_attempt" ]] || fail "previous attempt is required before reset"
  previous_round="$(find "$previous_attempt" -maxdepth 1 -type d -name 'round-*' -print | sed -n 's#.*/round-\([1-3]\)$#\1#p' | sort -n | tail -1)"
  [[ -n "$previous_round" ]] || fail "previous attempt has no terminal round"
  previous_dir="${previous_attempt}/round-${previous_round}"
  previous_verdict="$(jq -r '.verdict // empty' "${previous_dir}/domain-review-contract.json" 2>/dev/null || true)"
  [[ "$previous_verdict" == "PASS" || "$previous_verdict" == "BLOCKED" ]] || fail "reset requires a terminal PASS or BLOCKED contract"
fi

mkdir -p "$reports_base"
[[ ! -L "$reports_base" && "$(canonical_dir "$reports_base")" == "$reports_base" ]] || fail "domain-review report base escapes reports root"
report_root="${reports_base}"
lock_dir="${report_root}/.domain-review.lock"
if ! mkdir "$lock_dir" 2>/dev/null; then
  fail "another domain review transition holds the lock"
fi
trap 'rmdir "$lock_dir" 2>/dev/null || true' EXIT
[[ ! -e "$report_dir" ]] || fail "round destination already exists (replay is forbidden)"
mkdir -p "$report_dir"

generated_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
jq -n \
  --arg schema "domain-review-precheck/v1" \
  --argjson attempt "$attempt" --argjson round "$round" \
  --arg context_map_status "$status" \
  --arg calibration_sha256 "$calibration_sha" --arg input_sha256 "$input_sha" \
  --arg edit_summary "$edit_summary" --arg generated_at "$generated_at" \
  --argjson reset "$reset" \
  '{schema:$schema,stage:"domain",attempt:$attempt,round:$round,domain_model_status_field:$context_map_status,calibration_sha256:$calibration_sha256,input_sha256:$input_sha256,edit_summary:$edit_summary,reset:$reset,generated_at:$generated_at}' \
  > "${report_dir}/precheck-result.json"

echo "domain-review-precheck: complete. Output written to ${report_dir}/"
