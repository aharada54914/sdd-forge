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
  else shasum -a 256 "$1" | awk '{print $1}'; fi
}
reviewed_sha256() {
  local file="$1" status_field="$2" reviewed_status="$3"
  local replacement="${status_field}: ${reviewed_status}"
  if LC_ALL=C grep -q "^${status_field}:.*"$'\r$' "$file"; then
    replacement+=$'\r'
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    sed "s/^${status_field}:[[:space:]]*.*/${replacement}/" "$file" |
      sha256sum | awk '{print $1}'
  else
    sed "s/^${status_field}:[[:space:]]*.*/${replacement}/" "$file" |
      shasum -a 256 | awk '{print $1}'
  fi
}
# A round's verdict belongs to the text its two reviewers actually read.
# Elsewhere the manifest checks accept either the contract's recorded hash or the
# current file hash, which is right for tolerating an untouched file but leaves a
# real gap: a contract written after a remediation edit can record a hash neither
# reviewer ever saw, and the round's verdict is then attributed to text that was
# never reviewed. That happened on epic-136-phase4-docs attempt 2 round 2, and
# surfaced only because the next round's precheck happened to refuse.
#
# Close it directly: the two reviewers must have pinned the same hash for each
# reviewed document, and the contract must record that hash and no other.
assert_contract_reviewer_agreement() {
  local contract="$1" stage="$2"
  local role_a="${stage}-reviewer-a" role_b="${stage}-reviewer-b"
  local doc doc_key hash_a hash_b hash_contract
  pinned_hash() {
    jq -r --arg role "$1" --arg path "$2" --arg repo "${repo_root}/" '
      def relative_path:
        if startswith($repo) then .[($repo | length):]
        elif startswith("/") then ((capture("^.*/(?<tail>(specs|reports|plugins)/.+)$") | .tail) // .)
        else . end;
      [.reviewers[]? | select(.role == $role) | .allowed_input_manifest[]?
       | select((.path | relative_path) == $path) | .sha256] | first // ""
    ' "$contract"
  }
  for doc in requirements.md acceptance-tests.md design.md; do
    case "$doc" in
      requirements.md)     doc_key=requirements_sha256 ;;
      acceptance-tests.md) doc_key=acceptance_sha256 ;;
      design.md)           doc_key=design_sha256 ;;
    esac
    hash_a=$(pinned_hash "$role_a" "specs/${FEATURE}/${doc}")
    hash_b=$(pinned_hash "$role_b" "specs/${FEATURE}/${doc}")
    [[ -n "$hash_a" && -n "$hash_b" ]] || continue
    [[ "$hash_a" == "$hash_b" ]] ||
      fail "persisted ${stage} contract: reviewer-a and reviewer-b pinned different ${doc}; they did not review the same text"
    hash_contract=$(jq -r --arg k "$doc_key" '.[$k] // ""' "$contract")
    if [[ -n "$hash_contract" && "$hash_contract" != "$hash_a" ]]; then
      fail "persisted ${stage} contract records a ${doc} hash neither reviewer read; the verdict does not belong to that text"
    fi
  done
}

require_persisted_pass() {
  local root="$1" stage="$2" requirements_hash="$3" acceptance_hash="$4" design_hash="$5"
  local requirements_current_hash="$6" design_current_hash="$7" verdict="" contract contract_dir
  local stage_calibration stage_calibration_hash
  if [[ "$stage" == "spec" ]]; then
    stage_calibration="plugins/sdd-review-loop/references/spec-review-calibration.md"
  else
    stage_calibration="$CALIBRATION_MD"
  fi
  stage_calibration_hash="$(sha256 "${repo_root}/${stage_calibration}")"
  [[ -d "$root" && ! -L "$root" ]] || fail "missing ${stage} predecessor report root"
  local candidate candidate_dir relative_dir candidate_attempt candidate_round
  local latest_attempt=0 latest_round=0
  while IFS= read -r candidate; do
    candidate_dir="$(dirname "$candidate")"
    relative_dir="${candidate_dir#"${root}/"}"
    [[ "$relative_dir" =~ ^attempt-([1-9][0-9]*)/round-([1-9][0-9]*)$ ]] ||
      fail "persisted ${stage} verdict is outside a canonical attempt/round directory"
    candidate_attempt="${BASH_REMATCH[1]}"
    candidate_round="${BASH_REMATCH[2]}"
    if (( candidate_attempt > latest_attempt ||
          (candidate_attempt == latest_attempt && candidate_round > latest_round) )); then
      latest_attempt="$candidate_attempt"
      latest_round="$candidate_round"
      verdict="$candidate"
    fi
  done < <(find "$root" -type f -name integrated-verdict.json ! -lname '*' -print)
  [[ -n "$verdict" ]] || fail "missing persisted ${stage} PASS verdict"
  contract_dir="$(dirname "$verdict")"
  contract="${contract_dir}/${stage}-review-contract.json"
  [[ -f "$contract" && ! -L "$contract" ]] || fail "missing persisted ${stage} review contract"
  [[ "$contract_dir" =~ /attempt-([1-9][0-9]*)/round-([1-9][0-9]*)$ ]] ||
    fail "persisted ${stage} contract is outside a canonical attempt/round directory"
  local stored_attempt="${BASH_REMATCH[1]}" stored_round="${BASH_REMATCH[2]}"
  jq -e --arg feature "$FEATURE" --arg stage "$stage" '
    .feature == $feature and .stage == $stage and (.attempt | type == "number" and . > 0) and (.round | type == "number" and . > 0) and .verdict == "PASS" and
    (if $stage == "spec" then .schema == "spec-review-integrated-verdict/v1" and
      ([.reviewer_a_run_id, .reviewer_b_run_id, .reviewer_a_host_session_id, .reviewer_b_host_session_id] | all(type == "string" and length > 0)) and
      .reviewer_a_run_id != .reviewer_b_run_id and .reviewer_a_host_session_id != .reviewer_b_host_session_id
     else .schema == "integrated-verdict/v1" and (.run_id | type == "string" and length > 0) end)' "$verdict" >/dev/null ||
    fail "persisted ${stage} verdict is not a complete PASS contract"
  jq -e --arg feature "$FEATURE" --arg stage "$stage" --arg req "$requirements_hash" --arg req_current "$requirements_current_hash" \
    --arg accept "$acceptance_hash" --arg design "$design_hash" --arg design_current "$design_current_hash" \
    --arg repo "${repo_root}/" --arg calibration "$stage_calibration" --arg calibration_hash "$stage_calibration_hash" '
    # Contracts persisted by predecessor gates record absolute paths of the
    # checkout that generated them. Relativize against the known repository
    # anchors so evidence stays verifiable from any checkout (issue #61).
    def relative_path:
      if startswith($repo) then .[($repo | length):]
      elif startswith("/") then ((capture("^.*/(?<tail>(specs|reports|plugins)/.+)$") | .tail) // .)
      else . end;
    def allowed_input($role; $path; $attempt; $round):
      ($stage + "-reviewer-a") as $role_a |
      ($stage + "-reviewer-b") as $role_b |
      ("reports/" + $stage + "-review/" + $feature + "/attempt-" + ($attempt | tostring)) as $attempt_root |
      ($attempt_root + "/round-" + ($round | tostring)) as $round_root |
      (($path == ("specs/" + $feature + "/requirements.md")) or
       ($path == ("specs/" + $feature + "/acceptance-tests.md")) or
       ($stage == "spec" and $path == ("specs/" + $feature + "/investigation.md")) or
       ($stage == "impl" and
        ($path == ("specs/" + $feature + "/design.md") or
         $path == ("specs/" + $feature + "/ux-spec.md") or
         $path == ("specs/" + $feature + "/frontend-spec.md") or
         $path == ("specs/" + $feature + "/infra-spec.md") or
         $path == ("specs/" + $feature + "/security-spec.md") or
         $path == ("specs/" + $feature + "/investigation.md"))) or
       ($stage == "task" and
        ($path == ("specs/" + $feature + "/tasks.md") or
         $path == ("specs/" + $feature + "/traceability.md"))) or
       ($path == $calibration) or
       ($path == ($round_root + "/precheck-result.json")) or
       ($stage == "spec" and $role == $role_b and
        $path == ($round_root + "/integrated-summary.json")) or
       ($stage == "impl" and $role == $role_b and
        $path == ($round_root + "/integrated-summary.json")) or
       ($stage == "impl" and $role == $role_a and $round > 1 and
        $path == ($attempt_root + "/round-" + (($round - 1) | tostring) + "/integrated-summary.json")) or
       ($stage == "task" and $role == $role_a and
        $path == ($round_root + "/dependency-graph.json")) or
       ($stage == "task" and $role == $role_b and
        ($path == ($round_root + "/integrated-summary.json") or
         $path == "plugins/sdd-quality-loop/references/risk-gate-matrix.md" or
         $path == "plugins/sdd-quality-loop/references/risk-classification-policy.md")));
    .schema == ($stage + "-review-contract/v1") and .feature == $feature and .stage == $stage and
    (.attempt | type == "number" and . > 0) and (.round | type == "number" and . > 0) and
    (.run_id | type == "string" and length > 0) and .verdict == "PASS" and
    ([.reviewers[]? | .role] | sort) == [($stage + "-reviewer-a"), ($stage + "-reviewer-b")] and
    ([.reviewers[]? | .host_session_id] | (all(type == "string" and length > 0) and (unique | length == 2))) and
    ([.reviewers[]? | .run_id] | (all(type == "string" and length > 0) and (unique | length == 2))) and
    (.attempt as $attempt | .round as $round |
      all(.reviewers[]?;
        .role as $role |
        ([.allowed_input_manifest[]? | (.path | relative_path)] as $paths |
          ($paths | length) > 0 and ($paths | length) == ($paths | unique | length)) and
        all(.allowed_input_manifest[]?;
          .path as $raw_path |
          (($raw_path | type == "string") and
           (($raw_path | relative_path) as $path |
             (($path | startswith("/")) | not) and
             ($path | test("(^|/)\\.\\.?(/|$)") | not) and
             allowed_input($role; $path; $attempt; $round) and
             (.sha256 | type == "string") and
             (.sha256 | test("^[0-9a-f]{64}$"))))
        )
      )
    ) and
    (any(.reviewers[]?.allowed_input_manifest[]?; (.path | relative_path) == ("specs/" + $feature + "/requirements.md") and (.sha256 == $req or .sha256 == $req_current))) and
    (any(.reviewers[]?.allowed_input_manifest[]?; (.path | relative_path) == ("specs/" + $feature + "/acceptance-tests.md") and .sha256 == $accept)) and
    ($stage != "impl" or any(.reviewers[]?.allowed_input_manifest[]?; (.path | relative_path) == ("specs/" + $feature + "/design.md") and (.sha256 == $design or .sha256 == $design_current))) and
    all(.reviewers[]?; any(.allowed_input_manifest[]?; (.path | relative_path) == $calibration and .sha256 == $calibration_hash))
  ' "$contract" >/dev/null || fail "persisted ${stage} contract does not match canonical current inputs"
  [[ "$(jq -r '.attempt' "$contract")" == "$stored_attempt" &&
     "$(jq -r '.round' "$contract")" == "$stored_round" ]] ||
    fail "persisted ${stage} contract attempt/round does not match its directory"

  local role_a="${stage}-reviewer-a" role_b="${stage}-reviewer-b"
  local precheck_path="reports/${stage}-review/${FEATURE}/attempt-${stored_attempt}/round-${stored_round}/precheck-result.json"
  local summary_path="reports/${stage}-review/${FEATURE}/attempt-${stored_attempt}/round-${stored_round}/integrated-summary.json"
  local investigation_path="specs/${FEATURE}/investigation.md"
  # WFI-027: audit the record, not the current filesystem. A contract records the
  # input set that existed when its round ran. An investigation.md created after
  # that round cannot appear in it, and rewriting the contract to say otherwise
  # would assert that those reviewers read a file that did not yet exist. So the
  # trigger is what the contract declares, not what happens to be on disk now.
  # Completeness for a NEW round -- "the round about to run must see today's
  # investigation" -- is a reservation-time obligation, not an audit-time one.
  local investigation_declared investigation_recorded_hash investigation_current_hash=""
  investigation_declared="$(jq -r --arg path "$investigation_path" --arg repo "${repo_root}/" '
    def relative_path:
      if startswith($repo) then .[($repo | length):]
      elif startswith("/") then ((capture("^.*/(?<tail>(specs|reports|plugins)/.+)$") | .tail) // .)
      else . end;
    if any(.reviewers[]?.allowed_input_manifest[]?; (.path | relative_path) == $path)
    then "true" else "false" end' "$contract")"
  investigation_recorded_hash="$(jq -r --arg path "$investigation_path" --arg repo "${repo_root}/" '
    def relative_path:
      if startswith($repo) then .[($repo | length):]
      elif startswith("/") then ((capture("^.*/(?<tail>(specs|reports|plugins)/.+)$") | .tail) // .)
      else . end;
    [.reviewers[]?.allowed_input_manifest[]? | select((.path | relative_path) == $path) | .sha256]
    | unique | if length == 1 then .[0] else "" end' "$contract")"
  if [[ -f "${repo_root}/${investigation_path}" ]]; then
    investigation_current_hash="$(sha256 "${repo_root}/${investigation_path}")"
  fi
  manifest_has() {
    local role="$1" path="$2" hash_one="$3" hash_two="${4:-}"
    jq -e --arg role "$role" --arg path "$path" --arg repo "${repo_root}/" \
      --arg hash_one "$hash_one" --arg hash_two "$hash_two" '
      def relative_path:
        if startswith($repo) then .[($repo | length):]
        elif startswith("/") then ((capture("^.*/(?<tail>(specs|reports|plugins)/.+)$") | .tail) // .)
        else . end;
      any(.reviewers[]?;
        .role == $role and
        any(.allowed_input_manifest[]?;
          ((.path | relative_path) == $path) and
          (.sha256 == $hash_one or ($hash_two != "" and .sha256 == $hash_two))
        )
      )' "$contract" >/dev/null
  }
  for role in "$role_a" "$role_b"; do
    manifest_has "$role" "specs/${FEATURE}/requirements.md" "$requirements_hash" "$requirements_current_hash" ||
      fail "persisted ${stage} contract reviewer manifest is missing canonical requirements"
    manifest_has "$role" "specs/${FEATURE}/acceptance-tests.md" "$acceptance_hash" ||
      fail "persisted ${stage} contract reviewer manifest is missing canonical acceptance tests"
    manifest_has "$role" "$stage_calibration" "$stage_calibration_hash" ||
      fail "persisted ${stage} contract reviewer manifest is missing canonical calibration"
    manifest_has "$role" "$precheck_path" "$(sha256 "${repo_root}/${precheck_path}")" ||
      fail "persisted ${stage} contract reviewer manifest is missing canonical precheck evidence"
    if [[ "$stage" == "impl" ]]; then
      manifest_has "$role" "specs/${FEATURE}/design.md" "$design_hash" "$design_current_hash" ||
        fail "persisted impl contract reviewer manifest is missing canonical design"
    fi
    if [[ "$investigation_declared" == "true" ]]; then
      # Non-vacuity: a contract that binds only one reviewer, or that records two
      # different hashes for the same file, is still rejected here.
      [[ -n "$investigation_recorded_hash" ]] ||
        fail "persisted ${stage} contract records conflicting investigation hashes"
      manifest_has "$role" "$investigation_path" "$investigation_recorded_hash" "$investigation_current_hash" ||
        fail "persisted ${stage} contract reviewer manifest is missing investigation evidence"
    fi
  done
  manifest_has "$role_b" "$summary_path" "$(sha256 "${repo_root}/${summary_path}")" ||
    fail "persisted ${stage} reviewer-b manifest is missing canonical integrated summary"
  if [[ "$stage" == "impl" && "$stored_round" -gt 1 ]]; then
    local previous_summary="reports/impl-review/${FEATURE}/attempt-${stored_attempt}/round-$((stored_round - 1))/integrated-summary.json"
    manifest_has "$role_a" "$previous_summary" "$(sha256 "${repo_root}/${previous_summary}")" ||
      fail "persisted impl reviewer-a manifest is missing previous-round summary"
  fi

  assert_contract_reviewer_agreement "$contract" "$stage"
  jq -e --slurpfile verdict "$verdict" --arg stage "$stage" '
    . as $contract | $verdict[0] as $verdict |
    $contract.attempt == $verdict.attempt and
    $contract.round == $verdict.round and
    $contract.verdict == $verdict.verdict and
    (if $stage == "spec" then
       ($contract.reviewers | map({key: .role, value: {run_id: .run_id, host_session_id: .host_session_id}}) | from_entries) as $reviewers |
       $reviewers["spec-reviewer-a"].run_id == $verdict.reviewer_a_run_id and
       $reviewers["spec-reviewer-b"].run_id == $verdict.reviewer_b_run_id and
       $reviewers["spec-reviewer-a"].host_session_id == $verdict.reviewer_a_host_session_id and
       $reviewers["spec-reviewer-b"].host_session_id == $verdict.reviewer_b_host_session_id
     else $contract.run_id == $verdict.run_id end)
  ' "$contract" >/dev/null || fail "persisted ${stage} verdict and contract contradict each other"
}

command -v jq >/dev/null 2>&1 || fail "jq is required"

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
  if ! bash "$repo_root/plugins/sdd-quality-loop/scripts/check-workflow-state.sh" --feature "$FEATURE"; then
    echo "NOTE: impl-review-precheck: canonical workflow-state validation failed;" \
      "proceeding under --provenance-rereview (impl-stage evidence re-binding in progress)." >&2
  fi
else
  bash "$repo_root/plugins/sdd-quality-loop/scripts/check-workflow-state.sh" --feature "$FEATURE" ||
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

design_sha256=$(sha256 "${DESIGN_MD}")
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
    assert_contract_reviewer_agreement "${prior_contract}" impl

    prior_design_sha256=$(python3 -c "import json,sys; d=json.load(open('${prior_contract}')); print(d.get('design_sha256',''))" 2>/dev/null || echo "")

    if [[ "${design_sha256}" == "${prior_design_sha256}" ]]; then
      echo "ERROR: impl-review-precheck: design.md sha256 is unchanged from round ${prior_round}." \
        "A new round must review changed text; edit design.md, then re-invoke." >&2
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
ac_missing=""
if [[ -f "${REQS_MD}" && -f "${DESIGN_MD}" ]]; then
  while IFS= read -r ac_id; do
    [[ -n "${ac_id}" ]] || continue
    grep -Fq -- "${ac_id}" "${DESIGN_MD}" || ac_missing+="${ac_id} "
  done < <(grep -oE 'AC-[0-9]{3}' "${REQS_MD}" | sort -u)
fi
if [[ -n "${ac_missing}" ]]; then
  echo "ERROR: impl-review-precheck: design.md never names these acceptance criteria: ${ac_missing% }" >&2
  echo "       Each one is testable and traceable in requirements.md but absent from the design plan," >&2
  echo "       so an implementer could satisfy the plan and still not deliver them." >&2
  exit 1
fi

# ──────────────────────────────────────────────────────────────────────────────
# STEP 5: Validate the shared portable contract before creating output evidence.
# ──────────────────────────────────────────────────────────────────────────────

if $full_profile; then
  input_material="$(printf '%s:%s:%s:%s' "$design_sha256" "$requirements_sha256" "$acceptance_sha256" "$layer_sha256")"
else
  input_material="$(printf '%s:%s:%s' "$design_sha256" "$requirements_sha256" "$acceptance_sha256")"
fi
input_sha256="$(printf '%s' "$input_material" | if command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'; else shasum -a 256 | awk '{print $1}'; fi)"
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
  "input_sha256": "${input_sha256}",
  "generated_at": "${generated_at}"
}
EOF

echo "impl-review-precheck: complete. Output written to ${REPORT_DIR}/"

exit 0
