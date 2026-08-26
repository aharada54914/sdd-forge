#!/usr/bin/env bash
# task-review-precheck.sh
# Usage: task-review-precheck.sh <feature-slug> <attempt> <round> [--verify-inputs|--provenance-rereview]
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
MODE="${4:-}"

SPECS_DIR="specs/${FEATURE}"
REPORT_DIR="reports/task-review/${FEATURE}/attempt-${ATTEMPT}/round-${ROUND}"
TASKS_MD="${SPECS_DIR}/tasks.md"
REQS_MD="${SPECS_DIR}/requirements.md"
ACCEPT_MD="${SPECS_DIR}/acceptance-tests.md"
DESIGN_MD="${SPECS_DIR}/design.md"
TRACEABILITY_MD="${SPECS_DIR}/traceability.md"
SPEC_REPORT_ROOT="reports/spec-review/${FEATURE}"
IMPL_REPORT_ROOT="reports/impl-review/${FEATURE}"
CHECK_RISK_SCRIPT="plugins/sdd-quality-loop/scripts/check-risk.sh"
CALIBRATION_MD="plugins/sdd-review-loop/references/reviewer-calibration.md"
REGISTRY="specs/workflow-state-registry.json"
LAYER_FILES=("ux-spec.md" "frontend-spec.md" "infra-spec.md" "security-spec.md")
repo_root="$(cd "$(dirname "$0")/../../.." && pwd -P)"
calibration_sha256=""

fail() { echo "ERROR: task-review-precheck: $*" >&2; exit 1; }
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
# WFI-025: the STATUS-NORMALIZED task-plan digest — byte-for-byte the same
# recipe as check-workflow-state.sh normalized_hash() for the task stage
# (canonical form 1), which the accepting side already admits. Recorded
# instead of the raw digest when the plan's statuses are mixed, so the
# binding survives the lifecycle transitions the workflow is supposed to
# perform; every byte outside the lifecycle fields still binds.
tasks_normalized_hash() {
  local file="$1" cr=""
  LC_ALL=C grep -q $'^Task-Review-Status:.*\r$' "$file" && cr=$'\r'
  sed \
    -e "s/^Task-Review-Status:[[:space:]]*.*/Task-Review-Status: Pending${cr}/" \
    -e "s/^Approval:[[:space:]]*.*/Approval: Draft${cr}/" \
    -e "s/^Status:[[:space:]]*.*/Status: Planned${cr}/" \
    -e "/^Second Approval:/d" "$file" | sha256_stream
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
[[ -z "$MODE" || "$MODE" == "--verify-inputs" || "$MODE" == "--provenance-rereview" ]] || fail "unknown mode: $MODE"
profile="$(jq -r --arg feature "$FEATURE" '.entries[]? | select(.feature == $feature) | .profile' "$REGISTRY" | tail -n 1)"
full_profile=false
[[ "$profile" == "full" ]] && full_profile=true

if [[ "$MODE" == "--verify-inputs" ]]; then
  precheck="${REPORT_DIR}/precheck-result.json"
  [[ -f "$precheck" && ! -L "$precheck" ]] || fail "precheck evidence is missing or substituted"
  for path in "$TASKS_MD" "$REQS_MD" "$ACCEPT_MD" "$DESIGN_MD"; do
    [[ -f "$path" && ! -L "$path" ]] || fail "review input is missing or substituted: $path"
  done
  # WFI-025: verify the task plan against the digest FORM the precheck
  # declared. A normalized record tolerates the lifecycle flips it exists to
  # absorb; a body edit still changes the normalized digest and fails here.
  tasks_verify_hash="$(sha256 "$TASKS_MD")"
  if [[ "$(jq -r '.tasks_sha256_form // "raw"' "$precheck" | tr -d '\r')" == "normalized" ]]; then
    tasks_verify_hash="$(tasks_normalized_hash "$TASKS_MD")"
  fi
  jq -e --arg tasks "$tasks_verify_hash" --arg requirements "$(sha256 "$REQS_MD")" \
    --arg acceptance "$(sha256 "$ACCEPT_MD")" --arg design "$(sha256 "$DESIGN_MD")" \
    --arg feature "$FEATURE" \
    --argjson attempt "$ATTEMPT" --argjson round "$ROUND" '
      .schema == "task-review-precheck/v1" and
      .feature == $feature and .attempt == $attempt and .round == $round and
      .tasks_sha256 == $tasks and .requirements_sha256 == $requirements and
      .acceptance_sha256 == $acceptance and
      (if ((.layer_sha256 // {}) | length) > 0 then .design_sha256 == $design else true end)
    ' "$precheck" >/dev/null || fail "core review inputs changed after precheck"
  bound_layer_count="$(jq -r '(.layer_sha256 // {}) | length' "$precheck")"
  if $full_profile || [[ "$bound_layer_count" -gt 0 ]]; then
    [[ -f "$TRACEABILITY_MD" && ! -L "$TRACEABILITY_MD" ]] ||
      fail "traceability review input is missing or substituted"
    jq -e --arg hash "$(sha256 "$TRACEABILITY_MD")" '.traceability_sha256 == $hash' \
      "$precheck" >/dev/null || fail "traceability review input changed after precheck"
    python3 "${repo_root}/plugins/sdd-review-loop/scripts/validate-layer-traceability.py" \
      "$TRACEABILITY_MD" "$REQS_MD" || fail "traceability Layer Spec values are invalid"
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
  echo "task-review-precheck: inputs verified for reviewer invocation."
  exit 0
fi

[[ ! -e "$REPORT_DIR" && ! -L "$REPORT_DIR" ]] || fail "round destination already exists (replay is forbidden)"
[[ -d "$SPECS_DIR" && ! -L "$SPECS_DIR" ]] || fail "feature specification directory must be a real directory"
[[ "$(cd "$SPECS_DIR" && pwd -P)" == "$repo_root/specs/$FEATURE" ]] || fail "feature specification directory escapes repository"
if [[ "$MODE" == "--provenance-rereview" ]]; then
  prior_pass=false
  while IFS= read -r verdict_file; do
    if jq -e --arg feature "$FEATURE" \
      '.feature == $feature and .stage == "task" and .verdict == "PASS"' \
      "$verdict_file" >/dev/null 2>&1; then
      prior_pass=true
      break
    fi
  done < <(find "reports/task-review/${FEATURE}" -type f -name integrated-verdict.json ! -lname '*' -print 2>/dev/null)
  [[ "$prior_pass" == "true" ]] ||
    fail "provenance re-review requires a prior persisted task-review PASS verdict"
  if ! bash "$repo_root/plugins/sdd-quality-loop/scripts/check-workflow-state.sh" --feature "$FEATURE"; then
    echo "NOTE: task-review-precheck: canonical workflow-state validation failed;" \
      "proceeding under --provenance-rereview (task-stage evidence re-binding in progress)." >&2
  fi
else
  bash "$repo_root/plugins/sdd-quality-loop/scripts/check-workflow-state.sh" --feature "$FEATURE" ||
    fail "canonical workflow-state validation failed"
fi

# ──────────────────────────────────────────────────────────────────────────────
# STEP 1: Verify required input files exist
# ──────────────────────────────────────────────────────────────────────────────

missing_files=()
for f in "${TASKS_MD}" "${REQS_MD}" "${ACCEPT_MD}" "${DESIGN_MD}"; do
  if [[ ! -f "${f}" || -L "${f}" ]]; then
    missing_files+=("${f}")
  fi
done
if $full_profile; then
  for name in "${LAYER_FILES[@]}"; do
    path="${SPECS_DIR}/${name}"
    [[ -f "$path" && ! -L "$path" ]] || missing_files+=("$path")
  done
  [[ -f "$TRACEABILITY_MD" && ! -L "$TRACEABILITY_MD" ]] || missing_files+=("$TRACEABILITY_MD")
fi

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

[[ "${workflow_match_precheck}" != "FAIL" ]] || fail "Risk/Required Workflow mismatches must be fixed before creating evidence"

# ──────────────────────────────────────────────────────────────────────────────
# STEP 2b: Record Done When items that name a review-frozen artifact (WFI-030)
# ──────────────────────────────────────────────────────────────────────────────
# Detection only -- this never changes the exit code. The frozen-artifact rule
# in the task decomposition review gate's structural-coverage role is a Major
# finding evaluated by reviewer judgement alone; nothing deterministic backed
# it, and a review that reasoned past it sealed an unsatisfiable item into a
# hash-bound plan. Measured over this repository the trigger fires on 6 items,
# 3 of them real, so it records rather than fails; the reviewer adjudicates
# each entry.
# Items wrap across continuation lines, so lines are joined into whole items
# before matching: a line-at-a-time scan finds only 1 of the 3 known cases.
frozen_done_when_tsv="$(awk '
  function flush(   l) {
    if (item == "") return
    l = item
    if (l ~ /traceability\.md|design\.md|tasks\.md/ &&
        l ~ /(^|[^a-zA-Z])(record|records|update|updates|add|write|edit|append)([^a-zA-Z]|$)/)
      printf "%s\t%d\t%s\n", task, itemline, l
    item = ""
  }
  /^##[ \t]+T-[0-9]+/ { flush(); task = $2; sub(/[^A-Za-z0-9-].*$/, "", task); inblk = 0 }
  /Done When/ { flush(); inblk = 1; next }
  /^(##|###)[ \t]/ || /^[A-Za-z][A-Za-z ]*:/ { flush(); inblk = 0 }
  !inblk { next }
  /^- \[/ { flush(); item = $0; itemline = FNR; next }
  /^[ \t]+[^ \t]/ { if (item != "") { sub(/^[ \t]+/, " "); item = item $0 }; next }
  { flush() }
  END { flush() }
' "${TASKS_MD}")"
frozen_done_when_json="$(printf '%s' "${frozen_done_when_tsv}" |
  jq -R -s -c 'split("\n") | map(select(length > 0) | split("\t") | {task: .[0], line: (.[1]|tonumber), item: .[2]})')"
[[ -n "${frozen_done_when_json}" ]] || frozen_done_when_json='[]'

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
# Node-keyed lookups via derived variable names (graph_node_T_001=1,
# graph_adj_T_001="T-002 T-003"): bash-3.2 compatible (no associative arrays),
# and O(1) instead of the previous linear scans. Task IDs are already
# validated to T-NNN, so the derived names are safe.
# The namespaces must start empty: these lookups read shell variables, so an
# inherited/exported graph_node_T_999=1 could otherwise vouch for a task the
# parsed tasks.md never declared, and stale graph_adj_*/graph_visit_* values
# could corrupt the traversal. (graph_node_ does not prefix-match the
# graph_nodes/graph_edges_* arrays, which survive the sweep.)
for stale_graph_var in $(compgen -v graph_node_) $(compgen -v graph_adj_) $(compgen -v graph_visit_); do
  unset "$stale_graph_var"
done
for task_id in "${graph_nodes[@]}"; do
  printf -v "graph_node_${task_id//-/_}" 1
done
for ((i=0; i<${#graph_edges_from[@]}; i++)); do
  target_task="${graph_edges_to[$i]}"
  known_var="graph_node_${target_task//-/_}"
  [[ -n "${!known_var:-}" ]] || fail "Blockers references unknown task ${target_task}"
  adj_var="graph_adj_${graph_edges_from[$i]//-/_}"
  printf -v "$adj_var" '%s %s' "${!adj_var:-}" "$target_task"
done
# Recursive three-colour DFS over the Blockers graph (mirrored by the .ps1
# twin). Visit state lives in graph_visit_<node>: unset/0 = unvisited,
# 1 = on the current path (seeing it again means a cycle), 2 = fully
# explored. Depth is bounded by the task count (T-001..T-999), well inside
# bash's recursion budget. State is written with printf -v, never echoed
# from a subshell, so mutations survive the recursive calls.
graph_has_cycle_from() {
  local node="$1" next state_var adj_var
  state_var="graph_visit_${node//-/_}"
  [[ "${!state_var:-0}" != "1" ]] || return 0
  [[ "${!state_var:-0}" != "2" ]] || return 1
  printf -v "$state_var" 1
  adj_var="graph_adj_${node//-/_}"
  # Unquoted on purpose: successors are space-separated, all T-NNN validated.
  for next in ${!adj_var:-}; do
    graph_has_cycle_from "$next" && return 0
  done
  printf -v "$state_var" 2
  return 1
}
for task_id in "${graph_nodes[@]}"; do
  graph_has_cycle_from "$task_id" && fail "Blockers dependency graph contains a cycle"
done

# ──────────────────────────────────────────────────────────────────────────────
# STEP 4: Compute sha256 for each input file
# ──────────────────────────────────────────────────────────────────────────────

tasks_sha256=$(sha256 "${TASKS_MD}")
# WFI-025: a plan whose task statuses are MIXED has a raw digest that
# coincides with none of the accepting side's status-invariant forms, so a
# raw binding breaks on the next lifecycle flip of any task. Record the
# normalized digest for that case — and only that case: a uniform plan (all
# statuses equal, or no Status lines) keeps today's raw behaviour
# byte-for-byte. The recorded form travels in `tasks_sha256_form` so the
# reservation validator can cross-check which form the manifest may declare.
tasks_sha256_form="raw"
distinct_status_count=$(sed -n 's/^Status:[[:space:]]*//p' "${TASKS_MD}" | sed -e 's/\r$//' -e 's/[[:space:]]*$//' | sort -u | grep -c . || true)
if [[ "${distinct_status_count}" -gt 1 ]]; then
  tasks_sha256_form="normalized"
  tasks_sha256="$(tasks_normalized_hash "${TASKS_MD}")"
fi
requirements_sha256=$(sha256 "${REQS_MD}")
acceptance_sha256=$(sha256 "${ACCEPT_MD}")
design_sha256=$(sha256 "${DESIGN_MD}")
traceability_sha256=""
layer_sha256='{}'
if $full_profile; then
  traceability_sha256="$(sha256 "$TRACEABILITY_MD")"
  for name in "${LAYER_FILES[@]}"; do
    layer_sha256="$(jq -c --arg name "$name" --arg hash "$(sha256 "${SPECS_DIR}/${name}")" \
      '. + {($name): $hash}' <<<"$layer_sha256")"
  done
  python3 "${repo_root}/plugins/sdd-review-loop/scripts/validate-layer-traceability.py" \
    "$TRACEABILITY_MD" "$REQS_MD" || fail "traceability Layer Spec values are invalid"
fi
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
    prior_traceability_sha256=$(python3 -c "import json,sys; d=json.load(open('${prior_contract}')); print(d.get('traceability_sha256',''))" 2>/dev/null || echo "")

    # A later round must show progress on SOME reviewed artifact. tasks.md is
    # the usual target, but TRACEABILITY-SYNC findings are legitimately fixed
    # in traceability.md alone, so a traceability.md change (when both rounds
    # record its hash) also satisfies the progress requirement. Fail closed
    # when neither changed, or when the traceability hashes are unavailable
    # for comparison.
    if [[ "${tasks_sha256}" == "${prior_tasks_sha256}" ]] &&
       { [[ -z "${prior_traceability_sha256}" || -z "${traceability_sha256}" ]] ||
         [[ "${traceability_sha256}" == "${prior_traceability_sha256}" ]]; }; then
      echo "ERROR: task-review-precheck: neither tasks.md nor traceability.md changed from round ${prior_round}." \
        "Edit the artifact the prior round's findings target before re-invoking, then provide --edit-summary." >&2
      exit 1
    fi
  fi
fi

# ──────────────────────────────────────────────────────────────────────────────
# STEP 6: Validate the shared portable contract before creating output evidence.
# ──────────────────────────────────────────────────────────────────────────────

if $full_profile; then
  input_material="$(printf '%s:%s:%s:%s:%s:%s' "$tasks_sha256" "$requirements_sha256" "$acceptance_sha256" "$design_sha256" "$traceability_sha256" "$layer_sha256")"
else
  input_material="$(printf '%s:%s:%s' "$tasks_sha256" "$requirements_sha256" "$acceptance_sha256")"
fi
input_sha256="$(printf '%s' "$input_material" | sha256_stream)"
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
  "tasks_sha256_form": "${tasks_sha256_form}",
  "requirements_sha256": "${requirements_sha256}",
  "acceptance_sha256": "${acceptance_sha256}",
  "design_sha256": "${design_sha256}",
  "traceability_sha256": "${traceability_sha256}",
  "frozen_artifact_done_when": ${frozen_done_when_json},
  "layer_sha256": ${layer_sha256},
  "input_sha256": "${input_sha256}",
  "generated_at": "${generated_at}"
}
EOF

echo "task-review-precheck: complete. Output written to ${REPORT_DIR}/"

exit 0
