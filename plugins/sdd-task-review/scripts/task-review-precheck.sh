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
CHECK_RISK_SCRIPT="plugins/sdd-quality-loop/scripts/check-risk.sh"

# ──────────────────────────────────────────────────────────────────────────────
# STEP 1: Verify required input files exist
# ──────────────────────────────────────────────────────────────────────────────

missing_files=()
for f in "${TASKS_MD}" "${REQS_MD}" "${ACCEPT_MD}"; do
  if [[ ! -f "${f}" ]]; then
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
if grep -qP '^Risk:\s*medium' "${TASKS_MD}" 2>/dev/null; then
  if grep -qP '^Required Workflow:\s*test-after' "${TASKS_MD}" 2>/dev/null; then
    echo "ERROR: task-review-precheck: found Risk: medium with Required Workflow: test-after." \
      "Medium risk requires acceptance-first workflow." >&2
    workflow_match_precheck="FAIL"
  fi
fi

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
while IFS= read -r line; do
  # Detect task section header
  if [[ "${line}" =~ ^##[[:space:]]+(T-[0-9]{3})([[:space:]]|$) ]]; then
    current_task="${BASH_REMATCH[1]}"
    continue
  fi

  # Detect Blockers field
  if [[ -n "${current_task}" ]] && [[ "${line}" =~ ^Blockers:[[:space:]]*(.*) ]]; then
    blockers_value="${BASH_REMATCH[1]// /}"  # strip spaces for analysis
    blockers_raw="${BASH_REMATCH[1]}"

    if [[ "${blockers_value}" == "None" ]] || [[ -z "${blockers_value}" ]]; then
      # No dependencies — valid
      :
    elif echo "${blockers_raw}" | grep -qP '\.\.'; then
      # Range notation detected — invalid
      echo "ERROR: task-review-precheck: ${current_task} Blockers uses range notation: ${blockers_raw}" >&2
      blockers_format_valid=false
    elif echo "${blockers_raw}" | grep -qP '^(T-[0-9]{3})(,\s*T-[0-9]{3})*$'; then
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
  fi
done < "${TASKS_MD}"

# ──────────────────────────────────────────────────────────────────────────────
# STEP 4: Compute sha256 for each input file
# ──────────────────────────────────────────────────────────────────────────────

tasks_sha256=$(sha256sum "${TASKS_MD}" | awk '{print $1}')
requirements_sha256=$(sha256sum "${REQS_MD}" | awk '{print $1}')
acceptance_sha256=$(sha256sum "${ACCEPT_MD}" | awk '{print $1}')

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
# STEP 6: Create output directory and write precheck-result.json
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

# Exit non-zero if workflow_match_precheck failed, so orchestrator can halt
if [[ "${workflow_match_precheck}" == "FAIL" ]]; then
  echo "ERROR: task-review-precheck: workflow_match_precheck=FAIL. Fix Risk/Required Workflow mismatches before continuing." >&2
  exit 1
fi

exit 0
