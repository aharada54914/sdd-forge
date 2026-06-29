#!/usr/bin/env bash
# task-review-precheck.sh
# Usage: task-review-precheck.sh <feature-slug> <attempt> <round>
#
# Generates precheck-result.json and dependency-graph.json for the task-review-loop.
# Outputs to: reports/task-review/<feature>/attempt-<M>/round-<N>/
#
# Exit codes:
#   0  — precheck passed (downstream reviewers may run)
#   1  — precheck failed (halt review loop; display error)

set -euo pipefail

FEATURE="${1:?Usage: task-review-precheck.sh <feature-slug> <attempt> <round>}"
ATTEMPT="${2:?Usage: task-review-precheck.sh <feature-slug> <attempt> <round>}"
ROUND="${3:?Usage: task-review-precheck.sh <feature-slug> <attempt> <round>}"

SPECS_DIR="specs/${FEATURE}"
REPORT_DIR="reports/task-review/${FEATURE}/attempt-${ATTEMPT}/round-${ROUND}"
TASKS_MD="${SPECS_DIR}/tasks.md"
REQS_MD="${SPECS_DIR}/requirements.md"
ACCEPT_MD="${SPECS_DIR}/acceptance-tests.md"
DESIGN_MD="${SPECS_DIR}/design.md"
SPEC_REPORT_ROOT="reports/spec-review/${FEATURE}"
IMPL_REPORT_ROOT="reports/impl-review/${FEATURE}"
CHECK_RISK_SCRIPT="plugins/sdd-quality-loop/scripts/check-risk.sh"
CALIBRATION_MD="plugins/sdd-review-loop/references/reviewer-calibration.md"
repo_root="$(cd "$(dirname "$0")/../../.." && pwd -P)"
calibration_sha256=""

fail() { echo "ERROR: task-review-precheck: $*" >&2; exit 1; }
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
  contract_dir="$(dirname "$verdict")"; contract="${contract_dir}/${stage}-review-contract.json"
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
    def relative_path:
      if startswith($repo) then .[($repo | length):] else . end;
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
          (.path | type == "string" and ((startswith($repo)) or (startswith("/") | not))) and
          (.path | relative_path) as $path |
          ($path | test("(^|/)\\.\\.?(/|$)") | not) and
          allowed_input($role; $path; $attempt; $round) and
          (.sha256 | type == "string" and test("^[0-9a-f]{64}$"))
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
  manifest_has() {
    local role="$1" path="$2" hash_one="$3" hash_two="${4:-}"
    jq -e --arg role "$role" --arg path "$path" --arg absolute "${repo_root}/${path}" \
      --arg hash_one "$hash_one" --arg hash_two "$hash_two" '
      any(.reviewers[]?;
        .role == $role and
        any(.allowed_input_manifest[]?;
          (.path == $path or .path == $absolute) and
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
    if [[ -f "${repo_root}/${investigation_path}" ]]; then
      manifest_has "$role" "$investigation_path" "$(sha256 "${repo_root}/${investigation_path}")" ||
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

[[ "$FEATURE" =~ ^[a-z0-9][a-z0-9-]*$ ]] || fail "invalid feature slug"
[[ "$ATTEMPT" =~ ^[1-9][0-9]*$ ]] || fail "attempt must be a positive integer"
[[ "$ROUND" =~ ^[1-9][0-9]*$ ]] || fail "round must be a positive integer"
[[ ! -e "$REPORT_DIR" && ! -L "$REPORT_DIR" ]] || fail "round destination already exists (replay is forbidden)"
[[ -d "$SPECS_DIR" && ! -L "$SPECS_DIR" ]] || fail "feature specification directory must be a real directory"
[[ "$(cd "$SPECS_DIR" && pwd -P)" == "$repo_root/specs/$FEATURE" ]] || fail "feature specification directory escapes repository"
bash "$repo_root/plugins/sdd-quality-loop/scripts/check-workflow-state.sh" --feature "$FEATURE" ||
  fail "canonical workflow-state validation failed"

# ──────────────────────────────────────────────────────────────────────────────
# STEP 1: Verify required input files exist
# ──────────────────────────────────────────────────────────────────────────────

missing_files=()
for f in "${TASKS_MD}" "${REQS_MD}" "${ACCEPT_MD}" "${DESIGN_MD}"; do
  if [[ ! -f "${f}" || -L "${f}" ]]; then
    missing_files+=("${f}")
  fi
done

if [[ ${#missing_files[@]} -gt 0 ]]; then
  echo "ERROR: task-review-precheck: missing required files:" >&2
  for f in "${missing_files[@]}"; do
    echo "  - ${f}" >&2
  done
  exit 1
fi

spec_review_status=$(sed -n 's/^Spec-Review-Status:[[:space:]]*//p' "${REQS_MD}" | head -n 1 | tr -d '[:space:]')
impl_review_status=$(sed -n 's/^Impl-Review-Status:[[:space:]]*//p' "${DESIGN_MD}" | head -n 1 | tr -d '[:space:]')
[[ "$spec_review_status" == "Passed" ]] || fail "requirements.md must declare Spec-Review-Status: Passed"
[[ "$impl_review_status" == "Passed" ]] || fail "design.md must declare Impl-Review-Status: Passed"

# ──────────────────────────────────────────────────────────────────────────────
# STEP 2: Run risk check on tasks.md
# ──────────────────────────────────────────────────────────────────────────────

workflow_match_precheck="PASS"

if [[ -x "${CHECK_RISK_SCRIPT}" ]]; then
  if ! bash "${CHECK_RISK_SCRIPT}" "${TASKS_MD}" >/dev/null 2>&1; then
    workflow_match_precheck="FAIL"
  fi
else
  echo "WARNING: task-review-precheck: ${CHECK_RISK_SCRIPT} not found or not executable; skipping risk check." >&2
  workflow_match_precheck="SKIP"
fi

# Additional check: Risk: medium AND Required Workflow: test-after is forbidden
# (medium must use acceptance-first per risk-gate-matrix)
if grep -Eq '^Risk:[[:space:]]*medium' "${TASKS_MD}" 2>/dev/null; then
  if grep -Eq '^Required Workflow:[[:space:]]*test-after' "${TASKS_MD}" 2>/dev/null; then
    echo "ERROR: task-review-precheck: found Risk: medium with Required Workflow: test-after." \
      "Medium risk requires acceptance-first workflow." >&2
    workflow_match_precheck="FAIL"
  fi
fi

[[ "${workflow_match_precheck}" != "FAIL" ]] || fail "Risk/Required Workflow mismatches must be fixed before creating evidence"

# ──────────────────────────────────────────────────────────────────────────────
# STEP 3: Parse Blockers fields and build dependency-graph.json
# ──────────────────────────────────────────────────────────────────────────────

blockers_format_valid=true
declare -a graph_nodes=()
declare -a graph_edges_from=()
declare -a graph_edges_to=()

# Extract all task IDs (## T-NNN lines)
while IFS= read -r line; do
  if [[ "${line}" =~ ^##[[:space:]]+(T-[0-9]{3})([[:space:]]|$) ]]; then
    task_id="${BASH_REMATCH[1]}"
    graph_nodes+=("${task_id}")
  fi
done < "${TASKS_MD}"

# Parse Blockers fields per task
current_task=""
expecting_blockers_value=false

record_blockers() {
  local blockers_raw="$1"
  local blockers_value="${blockers_raw// /}"  # strip spaces for analysis

  if [[ "${blockers_value}" == "None" ]] || [[ -z "${blockers_value}" ]]; then
    # No dependencies — valid
    return
  elif [[ "${blockers_raw}" == *..* ]]; then
    # Range notation detected — invalid
    echo "ERROR: task-review-precheck: ${current_task} Blockers uses range notation: ${blockers_raw}" >&2
    blockers_format_valid=false
  elif [[ "${blockers_raw}" =~ ^(T-[0-9]{3})(,[[:space:]]*T-[0-9]{3})*$ ]]; then
    # Valid comma-separated T-NNN list — extract edges
    while IFS=',' read -ra ids; do
      for id in "${ids[@]}"; do
        trimmed_id="${id// /}"
        if [[ -n "${trimmed_id}" ]]; then
          graph_edges_from+=("${current_task}")
          graph_edges_to+=("${trimmed_id}")
        fi
      done
    done <<< "${blockers_raw}"
  else
    # Prose or other invalid format
    echo "ERROR: task-review-precheck: ${current_task} Blockers has invalid format: ${blockers_raw}" >&2
    blockers_format_valid=false
  fi
}

while IFS= read -r line; do
  # Detect task section header
  if [[ "${line}" =~ ^##[[:space:]]+(T-[0-9]{3})([[:space:]]|$) ]]; then
    if [[ "${expecting_blockers_value}" == "true" ]]; then
      echo "ERROR: task-review-precheck: ${current_task} Blockers value is missing." >&2
      blockers_format_valid=false
    fi
    current_task="${BASH_REMATCH[1]}"
    expecting_blockers_value=false
    continue
  fi

  # Support both legacy inline fields and the task template's heading/value form.
  if [[ -n "${current_task}" ]] && [[ "${line}" =~ ^Blockers:[[:space:]]*(.*) ]]; then
    record_blockers "${BASH_REMATCH[1]}"
    expecting_blockers_value=false
    continue
  fi

  if [[ -n "${current_task}" ]] && [[ "${line}" =~ ^###[[:space:]]+Blockers[[:space:]]*$ ]]; then
    expecting_blockers_value=true
    continue
  fi

  if [[ "${expecting_blockers_value}" == "true" ]]; then
    if [[ -z "${line//[[:space:]]/}" ]]; then
      continue
    fi
    record_blockers "${line}"
    expecting_blockers_value=false
  fi
done < "${TASKS_MD}"

if [[ "${expecting_blockers_value}" == "true" ]]; then
  echo "ERROR: task-review-precheck: ${current_task} Blockers value is missing." >&2
  blockers_format_valid=false
fi

[[ "$blockers_format_valid" == "true" ]] || fail "Blockers format is invalid"
for target_task in "${graph_edges_to[@]}"; do
  known_task=false
  for task_id in "${graph_nodes[@]}"; do
    [[ "$task_id" == "$target_task" ]] && known_task=true && break
  done
  [[ "$known_task" == "true" ]] || fail "Blockers references unknown task ${target_task}"
done
declare -a graph_visit_nodes=()
declare -a graph_visit_states=()
graph_visit_state() {
  local node="$1" i
  for ((i=0; i<${#graph_visit_nodes[@]}; i++)); do
    [[ "${graph_visit_nodes[$i]}" == "$node" ]] && { echo "${graph_visit_states[$i]}"; return; }
  done
  echo 0
}
set_graph_visit_state() {
  local node="$1" state="$2" i
  for ((i=0; i<${#graph_visit_nodes[@]}; i++)); do
    if [[ "${graph_visit_nodes[$i]}" == "$node" ]]; then graph_visit_states[$i]="$state"; return; fi
  done
  graph_visit_nodes+=("$node"); graph_visit_states+=("$state")
}
graph_has_cycle_from() {
  local node="$1" i next state
  state="$(graph_visit_state "$node")"
  [[ "$state" != "1" ]] || return 0
  [[ "$state" != "2" ]] || return 1
  set_graph_visit_state "$node" 1
  for ((i=0; i<${#graph_edges_from[@]}; i++)); do
    if [[ "${graph_edges_from[$i]}" == "$node" ]]; then
      next="${graph_edges_to[$i]}"
      graph_has_cycle_from "$next" && return 0
    fi
  done
  set_graph_visit_state "$node" 2
  return 1
}
for task_id in "${graph_nodes[@]}"; do
  graph_has_cycle_from "$task_id" && fail "Blockers dependency graph contains a cycle"
done

# ──────────────────────────────────────────────────────────────────────────────
# STEP 4: Compute sha256 for each input file
# ──────────────────────────────────────────────────────────────────────────────

tasks_sha256=$(sha256 "${TASKS_MD}")
requirements_sha256=$(sha256 "${REQS_MD}")
acceptance_sha256=$(sha256 "${ACCEPT_MD}")
design_sha256=$(sha256 "${DESIGN_MD}")
[[ -f "${CALIBRATION_MD}" && ! -L "${CALIBRATION_MD}" ]] || fail "${CALIBRATION_MD} not found"
calibration_sha256=$(sha256 "${CALIBRATION_MD}")
spec_review_requirements_sha256="$(reviewed_sha256 "$REQS_MD" "Spec-Review-Status" "Pending")"
impl_review_design_sha256="$(reviewed_sha256 "$DESIGN_MD" "Impl-Review-Status" "Pending")"
require_persisted_pass "$SPEC_REPORT_ROOT" spec "$spec_review_requirements_sha256" "$acceptance_sha256" "" "$requirements_sha256" ""
require_persisted_pass "$IMPL_REPORT_ROOT" impl "$requirements_sha256" "$acceptance_sha256" "$impl_review_design_sha256" "$requirements_sha256" "$design_sha256"

# ──────────────────────────────────────────────────────────────────────────────
# STEP 5: Round > 1 — verify tasks.md changed and edit summary will be provided
# ──────────────────────────────────────────────────────────────────────────────

if [[ "${ROUND}" -gt 1 ]]; then
  prior_round=$((ROUND - 1))
  prior_contract="reports/task-review/${FEATURE}/attempt-${ATTEMPT}/round-${prior_round}/task-review-contract.json"

  if [[ -f "${prior_contract}" ]]; then
    prior_tasks_sha256=$(python3 -c "import json,sys; d=json.load(open('${prior_contract}')); print(d.get('tasks_sha256',''))" 2>/dev/null || echo "")

    if [[ "${tasks_sha256}" == "${prior_tasks_sha256}" ]]; then
      echo "ERROR: task-review-precheck: tasks.md sha256 is unchanged from round ${prior_round}." \
        "Edit tasks.md before re-invoking, then provide --edit-summary." >&2
      exit 1
    fi
  fi
fi

# ──────────────────────────────────────────────────────────────────────────────
# STEP 6: Validate the shared portable contract before creating output evidence.
# ──────────────────────────────────────────────────────────────────────────────

input_sha256="$(printf '%s:%s:%s' "$tasks_sha256" "$requirements_sha256" "$acceptance_sha256" | if command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'; else shasum -a 256 | awk '{print $1}'; fi)"
foundation_contract="$(mktemp)"
trap 'rm -f "$foundation_contract"' EXIT
jq -n --arg feature "$FEATURE" --argjson attempt "$ATTEMPT" --argjson round "$ROUND" --arg input_sha256 "$input_sha256" \
  '{schema:"review-contract/v1",stage:"task",feature:$feature,attempt:$attempt,round:$round,input_sha256:$input_sha256,run_id:"task-precheck",verdict:"PASS"}' > "$foundation_contract"
mkdir -p "reports/task-review"
"${repo_root}/plugins/sdd-review-loop/scripts/review-contract-validate.sh" --feature "$FEATURE" --attempt "$ATTEMPT" --round "$ROUND" --stage task --report-root "reports/task-review/${FEATURE}" --contract "$foundation_contract" >/dev/null

# ──────────────────────────────────────────────────────────────────────────────
# STEP 7: Create output directory and write precheck-result.json
# ──────────────────────────────────────────────────────────────────────────────

mkdir -p "${REPORT_DIR}"

generated_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Build nodes JSON array
nodes_json="["
first=true
for node in "${graph_nodes[@]}"; do
  if [[ "${first}" == "true" ]]; then
    first=false
  else
    nodes_json+=","
  fi
  nodes_json+="\"${node}\""
done
nodes_json+="]"

# Build edges JSON array
edges_json="["
first=true
edge_count=${#graph_edges_from[@]}
for ((i=0; i<edge_count; i++)); do
  if [[ "${first}" == "true" ]]; then
    first=false
  else
    edges_json+=","
  fi
  edges_json+="{\"from\":\"${graph_edges_from[$i]}\",\"to\":\"${graph_edges_to[$i]}\"}"
done
edges_json+="]"

# Write dependency-graph.json
cat > "${REPORT_DIR}/dependency-graph.json" <<EOF
{
  "schema": "dependency-graph/v1",
  "feature": "${FEATURE}",
  "attempt": ${ATTEMPT},
  "round": ${ROUND},
  "nodes": ${nodes_json},
  "edges": ${edges_json},
  "generated_at": "${generated_at}"
}
EOF

# Write precheck-result.json
cat > "${REPORT_DIR}/precheck-result.json" <<EOF
{
  "schema": "task-review-precheck/v1",
  "feature": "${FEATURE}",
  "attempt": ${ATTEMPT},
  "round": ${ROUND},
  "workflow_match_precheck": "${workflow_match_precheck}",
  "blockers_format_valid": ${blockers_format_valid},
  "tasks_sha256": "${tasks_sha256}",
  "requirements_sha256": "${requirements_sha256}",
  "acceptance_sha256": "${acceptance_sha256}",
  "generated_at": "${generated_at}"
}
EOF

echo "task-review-precheck: complete. Output written to ${REPORT_DIR}/"

exit 0
