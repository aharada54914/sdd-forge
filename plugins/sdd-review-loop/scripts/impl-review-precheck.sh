#!/usr/bin/env bash
# impl-review-precheck.sh
# Usage: impl-review-precheck.sh <feature-slug> <attempt> <round> [--verify-inputs|--provenance-rereview]
#
# Generates precheck-result.json for the impl-review-loop.
# Outputs to: reports/impl-review/<feature>/attempt-<M>/round-<N>/
#
# Exit codes:
#   0  — precheck passed (downstream reviewers may run)
#   1  — precheck failed (halt review loop; display error)

set -euo pipefail

FEATURE="${1:?Usage: impl-review-precheck.sh <feature-slug> <attempt> <round>}"
ATTEMPT="${2:?Usage: impl-review-precheck.sh <feature-slug> <attempt> <round>}"
ROUND="${3:?Usage: impl-review-precheck.sh <feature-slug> <attempt> <round>}"
MODE="${4:-}"

SPECS_DIR="specs/${FEATURE}"
REPORT_DIR="reports/impl-review/${FEATURE}/attempt-${ATTEMPT}/round-${ROUND}"
DESIGN_MD="${SPECS_DIR}/design.md"
REQS_MD="${SPECS_DIR}/requirements.md"
ACCEPT_MD="${SPECS_DIR}/acceptance-tests.md"
SPEC_REPORT_ROOT="reports/spec-review/${FEATURE}"
IMPL_REPORT_ROOT="reports/impl-review/${FEATURE}"
CALIBRATION_MD="plugins/sdd-review-loop/references/reviewer-calibration.md"
REGISTRY="specs/workflow-state-registry.json"
LAYER_FILES=("ux-spec.md" "frontend-spec.md" "infra-spec.md" "security-spec.md")
repo_root="$(cd "$(dirname "$0")/../../.." && pwd -P)"
calibration_sha256=""

fail() { echo "ERROR: impl-review-precheck: $*" >&2; exit 1; }
sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}';
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}';
  else fail "neither sha256sum nor shasum is available"; fi
}
sha256_stream() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}';
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 | awk '{print $1}';
  else fail "neither sha256sum nor shasum is available"; fi
}
reviewed_sha256() {
  local file="$1" status_field="$2" reviewed_status="$3"
  local replacement="${status_field}: ${reviewed_status}"
  if LC_ALL=C grep -q "^${status_field}:.*"$'\r$' "$file"; then
    replacement+=$'\r'
  fi
  sed "s/^${status_field}:[[:space:]]*.*/${replacement}/" "$file" | sha256_stream
}
# RT-20260908-004: scoped declaration inputs, never caller-selected ADR reads.
adr_precheck_safe_file() {
  local relative=$1 current=$repo_root component entry found
  local -a components
  [[ "$relative" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*$ ]] || return 1
  [[ "$relative" != */ && "$relative" != *//* ]] || return 1
  IFS=/ read -r -a components <<< "$relative"
  for component in "${components[@]}"; do
    [[ "$component" != . && "$component" != .. ]] || return 1
    [[ -d "$current" && ! -L "$current" && -r "$current" && -x "$current" ]] || return 1
    found=false
    for entry in "$current"/* "$current"/.[!.]* "$current"/..?*; do
      if [[ "${entry##*/}" == "$component" ]]; then found=true; break; fi
    done
    [[ "$found" == true ]] || return 1
    current="$current/$component"
    [[ ! -L "$current" ]] || return 1
  done
  [[ -f "$current" && -r "$current" && ! -L "$current" ]]
}

# Same restricted byte grammar as admission; not general Markdown parsing.
adr_precheck_declared_paths() {
  LC_ALL=C awk '
    function width(s, i, ch, n) {
      n = 0
      while (substr(s, i + n, 1) == ch) n++
      return n
    }
    function escaped(s, i, n) {
      n = 0
      while (i > 1 && substr(s, i - 1, 1) == "\\") { n++; i-- }
      return n % 2
    }
    {
      line = $0
      sub(/\r$/, "", line)
      match(line, /^ */)
      indent = RLENGTH
      rest = substr(line, indent + 1)
      ch = substr(rest, 1, 1)
      if (fence != "") {
        if (indent <= 3 && ch == fence) {
          n = width(rest, 1, ch)
          if (n >= fence_width && substr(rest, n + 1) ~ /^[ \t]*$/) fence = ""
        }
        next
      }
      if (indent >= 4 || rest ~ /^\t/) next
      if (ch == "\140" || ch == "~") {
        n = width(rest, 1, ch)
        if (n >= 3) { fence = ch; fence_width = n; next }
      }
      i = 1
      while (i <= length(line)) {
        if (substr(line, i, 1) != "\140") { i++; continue }
        n = width(line, i, "\140")
        if (escaped(line, i)) { i += n; continue }
        j = i + n
        closed = 0
        while (j <= length(line)) {
          if (substr(line, j, 1) != "\140") { j++; continue }
          m = width(line, j, "\140")
          if (!escaped(line, j) && m == n) { closed = 1; break }
          j += m
        }
        if (!closed) break
        value = substr(line, i + n, j - i - n)
        if (n == 1 && value ~ /^docs\/adr\/[0-9][0-9][0-9][0-9]-[a-z0-9][a-z0-9-]*[.]md$/)
          print value
        i = j + n
      }
    }
  ' "$1" | LC_ALL=C sort -u
}

adr_precheck_collect() {
  local expected_design=$1 actual paths path digest result='[]'
  [[ "$expected_design" =~ ^[0-9a-f]{64}$ ]] || return 1
  adr_precheck_safe_file "$DESIGN_MD" || return 1
  actual=$(sha256 "$repo_root/$DESIGN_MD") || return 1
  [[ "$actual" == "$expected_design" ]] || return 1
  paths=$(adr_precheck_declared_paths "$repo_root/$DESIGN_MD") || return 1
  if [[ -n "$paths" ]]; then
    while IFS= read -r path; do
      adr_precheck_safe_file "$path" || return 1
      digest=$(sha256 "$repo_root/$path") || return 1
      [[ "$digest" =~ ^[0-9a-f]{64}$ ]] || return 1
      result=$(jq -c --arg path "$path" --arg sha256 "$digest" \
        '. + [{path:$path,sha256:$sha256}]' <<< "$result") || return 1
    done <<< "$paths"
  fi
  adr_precheck_safe_file "$DESIGN_MD" || return 1
  actual=$(sha256 "$repo_root/$DESIGN_MD") || return 1
  [[ "$actual" == "$expected_design" ]] || return 1
  printf '%s\n' "$result"
}

# Extension-only material: sorted layer keys, path/sha256 ADR key order,
# sorted ASCII paths, compact separators, and no trailing newline.
adr_precheck_input_hash() {
  local design=$1 requirements=$2 acceptance=$3 layers=$4 adrs=$5 material
  [[ "$design" =~ ^[0-9a-f]{64}$ && "$requirements" =~ ^[0-9a-f]{64}$ &&
     "$acceptance" =~ ^[0-9a-f]{64}$ ]] || return 1
  layers=$(jq -csSe '
    select(length == 1) | .[0] | select(type == "object") |
    select(length == 0 or keys ==
      ["frontend-spec.md","infra-spec.md","security-spec.md","ux-spec.md"]) |
    select(all(.[]; type == "string" and length == 64 and test("^[0-9a-f]{64}$")))
  ' <<< "$layers") || return 1
  if [[ "$layers" != '{}' ]]; then
    material=$(printf '%s:%s:%s:%s' "$design" "$requirements" "$acceptance" "$layers") || return 1
  else
    material=$(printf '%s:%s:%s' "$design" "$requirements" "$acceptance") || return 1
  fi
  printf '%s:adr_inputs/v1:%s' "$material" "$adrs" | sha256_stream
}

# Shared predecessor-verdict validation (require_persisted_pass and
# assert_contract_reviewer_agreement) lives in lib/review-precheck-common.sh,
# shared with the sibling precheck. It calls this script's fail/sha256/
# reviewed_sha256 helpers and reads FEATURE/repo_root/CALIBRATION_MD/
# LAYER_FILES, all defined above.
if ! . "$(cd "$(dirname "$0")" && pwd -P)/lib/review-precheck-common.sh"; then
  fail "lib/review-precheck-common.sh unavailable beside this script"
fi

command -v jq >/dev/null 2>&1 || fail "jq is required"
# Fail closed when no SHA-256 tool exists: with the bare else-shasum shape a
# host with neither tool captures an empty digest and empty == empty passes.
command -v sha256sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1 ||
  fail "neither sha256sum nor shasum is available"

[[ "$FEATURE" =~ ^[a-z0-9][a-z0-9-]*$ ]] || fail "invalid feature slug"
[[ "$ATTEMPT" =~ ^[1-9][0-9]*$ ]] || fail "attempt must be a positive integer"
[[ "$ROUND" =~ ^[1-9][0-9]*$ ]] || fail "round must be a positive integer"
[[ -z "$MODE" || "$MODE" == "--verify-inputs" || "$MODE" == "--provenance-rereview" ]] ||
  fail "unknown mode: $MODE"
profile="$(jq -r --arg feature "$FEATURE" '.entries[]? | select(.feature == $feature) | .profile' "$REGISTRY" | tail -n 1)"
full_profile=false
[[ "$profile" == "full" ]] && full_profile=true

if [[ "$MODE" == "--verify-inputs" ]]; then
  precheck="${REPORT_DIR}/precheck-result.json"
  adr_precheck_safe_file "$precheck" || fail "unsafe precheck evidence path"
  adr_precheck_safe_file "$DESIGN_MD" || fail "unsafe design input path"
  [[ -f "$precheck" && ! -L "$precheck" ]] || fail "precheck evidence is missing or substituted"
  for path in "$DESIGN_MD" "$REQS_MD" "$ACCEPT_MD"; do
    [[ -f "$path" && ! -L "$path" ]] || fail "review input is missing or substituted: $path"
  done
  jq -e --arg design "$(sha256 "$DESIGN_MD")" --arg requirements "$(sha256 "$REQS_MD")" \
    --arg acceptance "$(sha256 "$ACCEPT_MD")" --arg feature "$FEATURE" \
    --argjson attempt "$ATTEMPT" --argjson round "$ROUND" '
      .schema == "impl-review-precheck/v1" and
      .feature == $feature and .attempt == $attempt and .round == $round and
      .design_sha256 == $design and .requirements_sha256 == $requirements and
      .acceptance_sha256 == $acceptance
    ' "$precheck" >/dev/null || fail "core review inputs changed after precheck"
  bound_layer_count="$(jq -r '(.layer_sha256 // {}) | length' "$precheck")"
  if $full_profile || [[ "$bound_layer_count" -gt 0 ]]; then
    jq -e '(.layer_sha256 | keys) == ["frontend-spec.md","infra-spec.md","security-spec.md","ux-spec.md"]' \
      "$precheck" >/dev/null || fail "precheck layer manifest is incomplete"
    for name in "${LAYER_FILES[@]}"; do
      path="${SPECS_DIR}/${name}"
      [[ -f "$path" && ! -L "$path" ]] || fail "layer review input is missing or substituted: $path"
      jq -e --arg name "$name" --arg hash "$(sha256 "$path")" \
        '.layer_sha256[$name] == $hash' "$precheck" >/dev/null ||
        fail "layer review input changed after precheck: $path"
    done
  fi
  extension_present=$(jq -sr 'if length == 1 and (.[0] | type == "object")
    then .[0] | has("adr_inputs") else error("expected one precheck object") end' \
    "$precheck") || fail "cannot inspect ADR extension presence"
  if [[ "$extension_present" == true ]]; then
    # Presence is not truthiness: null and malformed values are rejected.
    recorded_adrs=$(jq -ce '
      .adr_inputs | select(type == "array") |
      select(all(.[]; type == "object" and keys == ["path","sha256"] and
        (.path | type == "string" and test("^docs/adr/[0-9]{4}-[a-z0-9][a-z0-9-]*[.]md$")) and
        (.sha256 | type == "string" and test("^[0-9a-f]{64}$")))) |
      select([.[].path] == ([.[].path] | sort | unique)) |
      map({path:.path,sha256:.sha256})
    ' "$precheck") || fail "invalid ADR input manifest"
    bound_design=$(jq -er '.design_sha256 | select(type == "string" and length == 64 and test("^[0-9a-f]{64}$"))' "$precheck") || fail "invalid design binding"
    actual_adrs=$(adr_precheck_collect "$bound_design") || fail "ADR collection failed"
    [[ "$recorded_adrs" == "$actual_adrs" ]] || fail "ADR inputs changed after precheck"
    bound_requirements=$(jq -er '.requirements_sha256 | select(type == "string" and length == 64 and test("^[0-9a-f]{64}$"))' "$precheck") || fail "invalid requirements binding"
    bound_acceptance=$(jq -er '.acceptance_sha256 | select(type == "string" and length == 64 and test("^[0-9a-f]{64}$"))' "$precheck") || fail "invalid acceptance binding"
    bound_layers=$(jq -c '.layer_sha256' "$precheck") || fail "missing layer binding"
    expected_input=$(adr_precheck_input_hash "$bound_design" "$bound_requirements" \
      "$bound_acceptance" "$bound_layers" "$actual_adrs") || fail "input hash calculation failed"
    jq -e --arg expected "$expected_input" \
      '.input_sha256 == $expected and ($expected | test("^[0-9a-f]{64}$"))' \
      "$precheck" >/dev/null || fail "ADR input material hash mismatch"
  fi
  echo "impl-review-precheck: inputs verified for reviewer invocation."
  exit 0
fi

[[ ! -e "$REPORT_DIR" && ! -L "$REPORT_DIR" ]] || fail "round destination already exists (replay is forbidden)"
[[ -d "$SPECS_DIR" && ! -L "$SPECS_DIR" ]] || fail "feature specification directory must be a real directory"
[[ "$(cd "$SPECS_DIR" && pwd -P)" == "$repo_root/specs/$FEATURE" ]] || fail "feature specification directory escapes repository"
if [[ "$MODE" == "--provenance-rereview" ]]; then
  # Post-implementation evidence re-binding. Mirrors task-review-precheck.sh's
  # mode of the same name, with the same guard: a prior persisted PASS at this
  # stage must already exist, so this mode can only ever re-bind evidence for a
  # design that genuinely passed -- it can never stand in for a first review.
  #
  # The canonical gate is advisory here rather than fatal, because a stale
  # impl-stage contract hash is exactly the condition this mode exists to
  # repair: requiring the gate to be green first would make the repair
  # unreachable from the state that needs it.
  prior_pass=false
  while IFS= read -r verdict_file; do
    if jq -e --arg feature "$FEATURE" \
      '.feature == $feature and .stage == "impl" and .verdict == "PASS"' \
      "$verdict_file" >/dev/null 2>&1; then
      prior_pass=true
      break
    fi
  done < <(find "$IMPL_REPORT_ROOT" -type f -name integrated-verdict.json ! -lname '*' -print 2>/dev/null)
  [[ "$prior_pass" == "true" ]] ||
    fail "provenance re-review requires a prior persisted impl-review PASS verdict"
  if ! bash "$repo_root/plugins/sdd-quality-loop/scripts/check-workflow-state.sh" --feature "$FEATURE" --opening "impl:${ATTEMPT}:${ROUND}"; then
    echo "NOTE: impl-review-precheck: canonical workflow-state validation failed;" \
      "proceeding under --provenance-rereview (impl-stage evidence re-binding in progress)." >&2
  fi
else
  bash "$repo_root/plugins/sdd-quality-loop/scripts/check-workflow-state.sh" --feature "$FEATURE" --opening "impl:${ATTEMPT}:${ROUND}" ||
    fail "canonical workflow-state validation failed"
fi

# ──────────────────────────────────────────────────────────────────────────────
# STEP 1: Check design.md exists and has Impl-Review-Status: Pending
# ──────────────────────────────────────────────────────────────────────────────

if [[ ! -f "${DESIGN_MD}" || -L "${DESIGN_MD}" ]]; then
  echo "ERROR: impl-review-precheck: ${DESIGN_MD} not found." >&2
  exit 1
fi

if [[ ! -f "${REQS_MD}" || -L "${REQS_MD}" ]]; then
  echo "ERROR: impl-review-precheck: ${REQS_MD} not found." >&2
  exit 1
fi

spec_review_status=$(sed -n 's/^Spec-Review-Status:[[:space:]]*//p' "${REQS_MD}" | head -n 1 | tr -d '[:space:]')
[[ "$spec_review_status" == "Passed" ]] || fail "requirements.md must declare Spec-Review-Status: Passed"

# Check for Impl-Review-Status field
impl_review_status=$(sed -n 's/^Impl-Review-Status:[[:space:]]*//p' "${DESIGN_MD}" | head -n 1 | tr -d '[:space:]')

if [[ -z "${impl_review_status}" ]]; then
  echo "ERROR: impl-review-precheck: design.md is missing 'Impl-Review-Status:' header field." \
    "Add 'Impl-Review-Status: Pending' to design.md before invoking impl-review-loop." >&2
  exit 1
fi

if [[ "$MODE" == "--provenance-rereview" ]]; then
  # The header stays Passed for the whole re-binding, deliberately. Flipping it
  # to Pending is not an option here: check-workflow-state.sh's task-lifecycle
  # rule requires every stage to read Passed once any task is Approved or past
  # Planned, so a Pending header on a feature that has already shipped trades
  # this stage's contradiction for a worse one.
  if [[ "${impl_review_status}" != "Passed" ]]; then
    echo "ERROR: impl-review-precheck: --provenance-rereview requires design.md to" \
      "declare 'Impl-Review-Status: Passed'; it declares '${impl_review_status}'." \
      "Without a prior pass there is no provenance to re-bind -- run an ordinary" \
      "attempt instead." >&2
    exit 1
  fi
elif [[ "${impl_review_status}" != "Pending" ]] && [[ "${impl_review_status}" != "pending" ]]; then
  echo "ERROR: impl-review-precheck: Impl-Review-Status is '${impl_review_status}', expected 'Pending'." \
    "If a previous review has already passed and this is an evidence re-binding," \
    "use --provenance-rereview." >&2
  exit 1
fi

# ──────────────────────────────────────────────────────────────────────────────
# STEP 2: Detect legacy_design
# Criteria: design.md predates new template if it lacks required template fields
# ──────────────────────────────────────────────────────────────────────────────

legacy_design=false
required_fields=(
  "## Components"
  "Feature Type:"
  "Data Entities:"
  "Existing Data Affected:"
  "## Security Boundaries"
)

missing_count=0
for field in "${required_fields[@]}"; do
  if ! grep -qF "${field}" "${DESIGN_MD}" 2>/dev/null; then
    missing_count=$((missing_count + 1))
  fi
done

# If 3 or more required template fields are missing, treat as legacy design
if [[ "${missing_count}" -ge 3 ]]; then
  legacy_design=true
fi

# ──────────────────────────────────────────────────────────────────────────────
# STEP 3: Compute sha256 for each input file
# ──────────────────────────────────────────────────────────────────────────────

adr_precheck_safe_file "$DESIGN_MD" || fail "unsafe design input path"
design_sha256=$(sha256 "${DESIGN_MD}")
adr_inputs=$(adr_precheck_collect "$design_sha256") || fail "cannot bind design ADR inputs"
requirements_sha256=$(sha256 "${REQS_MD}")

acceptance_sha256=""
[[ -f "${ACCEPT_MD}" && ! -L "${ACCEPT_MD}" ]] || fail "${ACCEPT_MD} not found"
acceptance_sha256=$(sha256 "${ACCEPT_MD}")
[[ -f "${CALIBRATION_MD}" && ! -L "${CALIBRATION_MD}" ]] || fail "${CALIBRATION_MD} not found"
calibration_sha256=$(sha256 "${CALIBRATION_MD}")
layer_sha256='{}'
if $full_profile; then
  for name in "${LAYER_FILES[@]}"; do
    path="${SPECS_DIR}/${name}"
    [[ -f "$path" && ! -L "$path" ]] || fail "layer review input is missing or substituted: $path"
    layer_sha256="$(jq -c --arg name "$name" --arg hash "$(sha256 "$path")" \
      '. + {($name): $hash}' <<<"$layer_sha256")"
  done
fi
spec_review_requirements_sha256="$(reviewed_sha256 "$REQS_MD" "Spec-Review-Status" "Pending")"
require_persisted_pass "$SPEC_REPORT_ROOT" spec "$spec_review_requirements_sha256" "$acceptance_sha256" "" "$requirements_sha256" ""

# ──────────────────────────────────────────────────────────────────────────────
# STEP 4: Round > 1 — verify design.md changed; check DESIGN-REQ-DRIFT
# ──────────────────────────────────────────────────────────────────────────────

design_req_drift=false

if [[ "${ROUND}" -gt 1 ]]; then
  prior_round=$((ROUND - 1))
  prior_contract="reports/impl-review/${FEATURE}/attempt-${ATTEMPT}/round-${prior_round}/impl-review-contract.json"

  if [[ -f "${prior_contract}" ]]; then
    # The prior round's own verdict must belong to the text its reviewers read.
    # This is the site where the epic-136-phase4-docs attempt-2 round-2 defect
    # lived: require_persisted_pass only inspects the spec contract, so without
    # this call an impl round-to-round handoff carries no such check at all.
    # A failed ADR-bound round is historical: validate its internal bindings,
    # not today's corrected ADR bytes. Legacy rounds keep design-only progress.
    prior_precheck="${prior_contract%/*}/precheck-result.json"
    prior_adr_inputs=null
    prior_extension=$(jq -sr 'if length == 1 and (.[0] | type == "object")
      then .[0] | has("adr_inputs") else error("invalid contract") end' "$prior_contract") || fail "invalid previous ADR contract"
    precheck_extension=false
    if [[ -e "$prior_precheck" || -L "$prior_precheck" ]]; then
      adr_precheck_safe_file "$prior_precheck" || fail "unsafe previous ADR precheck"
      precheck_extension=$(jq -sr 'if length == 1 and (.[0] | type == "object")
        then .[0] | has("adr_inputs") else error("invalid precheck") end' "$prior_precheck") || fail "invalid previous ADR precheck"
    fi
    [[ "$prior_extension" == "$precheck_extension" ]] || fail "one-sided previous ADR extension"
    if [[ "$prior_extension" == true ]]; then
      prior_a="${prior_contract%/*}/reviewer-a.json"
      prior_b="${prior_contract%/*}/reviewer-b.json"
      for evidence in "$prior_contract" "$prior_precheck" "$prior_a" "$prior_b"; do
        adr_precheck_safe_file "$evidence" || fail "unsafe previous ADR evidence"
      done
      prior_precheck_hash=$(sha256 "$prior_precheck") || fail "cannot hash previous ADR precheck"
      prior_a_hash=$(sha256 "$prior_a") || fail "cannot hash previous ADR reviewer A"
      prior_b_hash=$(sha256 "$prior_b") || fail "cannot hash previous ADR reviewer B"
      prior_adr_inputs=$(jq -nce --slurpfile cs "$prior_contract" --slurpfile ps "$prior_precheck" \
        --slurpfile aa "$prior_a" --slurpfile bb "$prior_b" --arg feature "$FEATURE" \
        --argjson attempt "$ATTEMPT" --argjson round "$prior_round" \
        --arg pc "$prior_precheck" --arg pch "$prior_precheck_hash" --arg repo "$repo_root/" '
        def hash: type == "string" and test("^[0-9a-f]{64}$") and length == 64;
        def adrs:
          type == "array" and all(.[]; type == "object" and keys == ["path","sha256"] and
            (.path | type == "string" and test("^docs/adr/[0-9]{4}-[a-z0-9][a-z0-9-]*[.]md$")) and
            (.sha256 | hash)) and ([.[].path] == ([.[].path] | sort | unique));
        def relative:
          if startswith($repo) then .[($repo | length):]
          elif startswith("/") then ((capture("^.*/(?<tail>(specs|reports|plugins)/.+)$") | .tail) // .)
          else . end;
        def pin($entries; $path; $hash):
          [$entries[] | select((.path | relative) == $path)] as $found |
          ($found | length) == 1 and $found[0].sha256 == $hash;
        select([$cs,$ps,$aa,$bb] | all(.[]; length == 1 and (.[0] | type == "object"))) |
        $cs[0] as $c | $ps[0] as $p |
        select($c.schema == "impl-review-contract/v1" and $c.stage == "impl" and
          $c.verdict == "NEEDS_WORK" and $p.schema == "impl-review-precheck/v1") |
        select([$c,$p] | all(.[]; .feature == $feature and .attempt == $attempt and .round == $round)) |
        select(($c.adr_inputs | adrs) and ($p.adr_inputs | adrs) and $c.adr_inputs == $p.adr_inputs) |
        select(all(["design_sha256","requirements_sha256","acceptance_sha256"][];
          . as $key | ($p[$key] | hash) and $c[$key] == $p[$key])) |
        select(($p.layer_sha256 | type == "object") and $c.layer_sha256 == $p.layer_sha256 and
          (($p.layer_sha256 | keys) == [] or ($p.layer_sha256 | keys) ==
            ["frontend-spec.md","infra-spec.md","security-spec.md","ux-spec.md"]) and
          ($p.layer_sha256 | all(.[]; hash))) |
        select(($c.reviewers | type == "array") and
          ([$c.reviewers[].role] | sort) == ["impl-reviewer-a","impl-reviewer-b"]) |
        select(all(["impl-reviewer-a","impl-reviewer-b"][]; . as $role |
          ($c.reviewers[] | select(.role == $role)) as $reservation |
          (if $role == "impl-reviewer-a" then $aa[0] else $bb[0] end) as $output |
          $output.schema == ($role + "/v1") and $output.stage == "impl" and $output.role == $role and
          all(["run_id","host_session_id"][]; . as $key |
            ($output[$key] | type == "string" and test("\\S")) and $output[$key] == $reservation[$key]) and
          all([$reservation,$output][]; .allowed_input_manifest as $entries |
            ($entries | type == "array") and
            all($entries[]; (.path | type == "string") and (.sha256 | hash)) and
            pin($entries; $pc; $pch) and
            pin($entries; ("specs/" + $feature + "/design.md"); $p.design_sha256) and
            pin($entries; ("specs/" + $feature + "/requirements.md"); $p.requirements_sha256) and
            pin($entries; ("specs/" + $feature + "/acceptance-tests.md"); $p.acceptance_sha256) and
            all($p.layer_sha256 | to_entries[]; pin($entries; ("specs/" + $feature + "/" + .key); .value)) and
            ([$entries[] | select(.path | relative | startswith("docs/adr/")) | {path,sha256}] | sort_by(.path)) == $p.adr_inputs
          ))) |
        $p.adr_inputs | map({path:.path,sha256:.sha256})
      ') || fail "previous ADR reviewer/contract binding mismatch"
      prior_input_hash=$(adr_precheck_input_hash \
        "$(jq -r .design_sha256 "$prior_precheck")" "$(jq -r .requirements_sha256 "$prior_precheck")" \
        "$(jq -r .acceptance_sha256 "$prior_precheck")" "$(jq -c .layer_sha256 "$prior_precheck")" \
        "$prior_adr_inputs") || fail "invalid previous ADR input material"
      [[ "$(jq -r .input_sha256 "$prior_precheck")" == "$prior_input_hash" ]] || fail "previous ADR input hash mismatch"
      for evidence in "$prior_precheck" "$prior_a" "$prior_b"; do
        adr_precheck_safe_file "$evidence" || fail "previous ADR evidence changed"
      done
      [[ "$(sha256 "$prior_precheck")" == "$prior_precheck_hash" &&
         "$(sha256 "$prior_a")" == "$prior_a_hash" &&
         "$(sha256 "$prior_b")" == "$prior_b_hash" ]] || fail "previous ADR evidence changed"
    else
      jq -e 'all(.reviewers[]?.allowed_input_manifest[]?;
        (.path | gsub("\\\\"; "/") | test("(^|/)docs/adr/") | not))' \
        "$prior_contract" >/dev/null || fail "legacy previous contract cannot admit ADR inputs"
      # No historical ADR permission is inferred from an absent extension.
    fi
    assert_contract_reviewer_agreement "${prior_contract}" impl

    prior_design_sha256=$(python3 -c "import json,sys; d=json.load(open('${prior_contract}')); print(d.get('design_sha256',''))" 2>/dev/null || echo "")

    if [[ "$design_sha256" == "$prior_design_sha256" &&
          ( "$prior_adr_inputs" == null || "$prior_adr_inputs" == "$adr_inputs" ) ]]; then
      echo "ERROR: impl-review-precheck: design and declared ADR inputs are unchanged from round ${prior_round}." \
        "A new round must review changed inputs." >&2
      exit 1
    fi

    # DESIGN-REQ-DRIFT: compare requirements_sha256 against round-1 stored value
    round1_contract="reports/impl-review/${FEATURE}/attempt-${ATTEMPT}/round-1/impl-review-contract.json"
    if [[ -f "${round1_contract}" ]]; then
      round1_req_sha256=$(python3 -c "import json,sys; d=json.load(open('${round1_contract}')); print(d.get('requirements_sha256',''))" 2>/dev/null || echo "")

      if [[ -n "${round1_req_sha256}" ]] && [[ "${requirements_sha256}" != "${round1_req_sha256}" ]]; then
        design_req_drift=true
        echo "WARNING: impl-review-precheck: requirements.md has changed since round 1 of this attempt." \
          "DESIGN-REQ-DRIFT detected. Reviewers will note this condition." >&2
      fi
    fi
  fi
fi

# AC coverage. Every AC-NNN in requirements.md must be named in design.md.
#
# This is deterministic work that was being paid for with reviewer rounds. On
# epic-136-phase4-docs, impl review spent rounds 2 and 3 of attempt 1 finding
# AC-013 and then AC-012 missing from the design plan, one per round, and the
# attempt escalated to BLOCKED. A later mechanical sweep found AC-001 and AC-014
# absent as well. Every one of them was an AC that spec review had added late as
# a gap-closer, which the design -- written against the REQ-* headings -- dropped
# silently. A design that does not name an AC cannot be audited for covering it.
#
# NARROW EXCEPTION (human ruling, 2026-08-24). Some acceptance criteria are
# structurally not design content, and no design document can honestly name
# them: epic-194's AC-023/AC-024 and epic-193's AC-035/AC-036/AC-037 are
# criteria about the SPEC PACKAGE'S OWN REGISTRATION COMMIT -- AC-024 requires
# both status headers to read `Pending` "at commit time", which is not a
# property any design plans for and is now historically false since both read
# `Passed`. Demanding a design citation for those is demanding a false
# statement.
#
# The exception keys on a property the requirements document states about
# ITSELF, never on a list of AC ids and never on "cited somewhere in the spec
# package". requirements.md's acceptance table gives every criterion a
# requirement-trace cell, and that cell is bimodal across this repository: it
# either names the REQ-NNN the criterion refines, or it declares the criterion
# process-and-registration scope rather than behaviour. Two spellings of the
# latter are in use -- `| AC-023 | Global |` (epic-194) and
# `| AC-035 (Global) | - |` (epic-193) -- and both are read here.
#
# This is narrow in the way that matters. The declaration is made in
# requirements.md, in the row that defines the criterion, where spec review
# reads and adjudicates it -- an author cannot quietly excuse a behaviour AC
# without visibly restating its scope in the document the spec reviewers are
# looking at. And it leaves the epic-136 class fully caught: those were
# gap-closer criteria added late under a REQ-* heading, so their rows carry a
# REQ trace and the gate still demands the design name them. Only the first
# cell and the trace cell of a criterion's OWN defining row are consulted;
# mentions of an AC id in prose or in another criterion's text are never a
# declaration of scope.
ac_scoped_global() {
  LC_ALL=C awk -v id="$1" '
    {
      line = $0
      sub(/\r$/, "", line)
      if (substr(line, 1, 1) != "|") next
      # Bracketed, not a bare "|": a one-character split separator is treated
      # literally by some awks and as an ERE by others, and "|" as an ERE is
      # empty alternation. [|] is unambiguous everywhere.
      n = split(line, cell, "[|]")
      if (n < 4) next
      c1 = cell[2]; c2 = cell[3]
      sub(/^[ \t]+/, "", c1); sub(/[ \t]+$/, "", c1)
      sub(/^[ \t]+/, "", c2); sub(/[ \t]+$/, "", c2)
      annotated = 0
      if (c1 ~ /\(Global\)$/) {
        annotated = 1
        sub(/\(Global\)$/, "", c1)
        sub(/[ \t]+$/, "", c1)
      }
      if (c1 != id) next
      if (annotated || c2 == "Global") { global = 1 }
      found = 1
      exit
    }
    END { exit (found && global ? 0 : 1) }
  ' "${REQS_MD}"
}
ac_missing=""
ac_global=""
if [[ -f "${REQS_MD}" && -f "${DESIGN_MD}" ]]; then
  while IFS= read -r ac_id; do
    [[ -n "${ac_id}" ]] || continue
    if ac_scoped_global "${ac_id}"; then
      ac_global+="${ac_id} "
      continue
    fi
    grep -Fq -- "${ac_id}" "${DESIGN_MD}" || ac_missing+="${ac_id} "
  done < <(grep -oE 'AC-[0-9]{3}' "${REQS_MD}" | sort -u)
fi
# Never silent: an exercised exception is reported whether or not the gate then
# fails, so a reader can see which criteria were excused and go check the rows
# that excused them.
if [[ -n "${ac_global}" ]]; then
  echo "NOTE: impl-review-precheck: not requiring design.md to name these criteria," \
    "which requirements.md scopes Global (process and registration, not design): ${ac_global% }" >&2
fi
if [[ -n "${ac_missing}" ]]; then
  echo "ERROR: impl-review-precheck: design.md never names these acceptance criteria: ${ac_missing% }" >&2
  echo "       Each appears in requirements.md without being scoped Global there -- so each states" >&2
  echo "       behaviour this design must plan for -- yet none of these strings occurs anywhere in" >&2
  echo "       design.md, so an implementer could satisfy the plan and still not deliver them." >&2
  exit 1
fi

# ──────────────────────────────────────────────────────────────────────────────
# STEP 5: Validate the shared portable contract before creating output evidence.
# ──────────────────────────────────────────────────────────────────────────────

input_sha256=$(adr_precheck_input_hash "$design_sha256" "$requirements_sha256" \
  "$acceptance_sha256" "$layer_sha256" "$adr_inputs") || fail "input hash calculation failed"
[[ "$input_sha256" =~ ^[0-9a-f]{64}$ ]] || fail "invalid input hash"
foundation_contract="$(mktemp)"
trap 'rm -f "$foundation_contract"' EXIT
jq -n --arg feature "$FEATURE" --argjson attempt "$ATTEMPT" --argjson round "$ROUND" --arg input_sha256 "$input_sha256" \
  '{schema:"review-contract/v1",stage:"impl",feature:$feature,attempt:$attempt,round:$round,input_sha256:$input_sha256,run_id:"impl-precheck",verdict:"PASS"}' > "$foundation_contract"
mkdir -p "reports/impl-review"
"${repo_root}/plugins/sdd-review-loop/scripts/review-contract-validate.sh" --feature "$FEATURE" --attempt "$ATTEMPT" --round "$ROUND" --stage impl --report-root "$IMPL_REPORT_ROOT" --contract "$foundation_contract" >/dev/null

# ──────────────────────────────────────────────────────────────────────────────
# STEP 6: Create output directory and write precheck-result.json
# ──────────────────────────────────────────────────────────────────────────────

mkdir -p "${REPORT_DIR}"

generated_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

cat > "${REPORT_DIR}/precheck-result.json" <<EOF
{
  "schema": "impl-review-precheck/v1",
  "feature": "${FEATURE}",
  "attempt": ${ATTEMPT},
  "round": ${ROUND},
  "impl_review_status_field": "${impl_review_status}",
  "legacy_design": ${legacy_design},
  "design_req_drift": ${design_req_drift},
  "design_sha256": "${design_sha256}",
  "requirements_sha256": "${requirements_sha256}",
  "acceptance_sha256": "${acceptance_sha256}",
  "layer_sha256": ${layer_sha256},
  "adr_inputs": ${adr_inputs},
  "input_sha256": "${input_sha256}",
  "generated_at": "${generated_at}"
}
EOF

echo "impl-review-precheck: complete. Output written to ${REPORT_DIR}/"

exit 0
