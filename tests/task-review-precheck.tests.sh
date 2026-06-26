#!/usr/bin/env bash
# Regression tests for task-review-precheck.sh.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FEATURE="task-review-precheck-fixture"
SPEC_DIR="${REPO_ROOT}/specs/${FEATURE}"
REPORT_DIR="${REPO_ROOT}/reports/task-review/${FEATURE}"
SPEC_REPORT_DIR="${REPO_ROOT}/reports/spec-review/${FEATURE}"
IMPL_REPORT_DIR="${REPO_ROOT}/reports/impl-review/${FEATURE}"

cleanup() {
  rm -rf "${SPEC_DIR}" "${REPORT_DIR}" "${SPEC_REPORT_DIR}" "${IMPL_REPORT_DIR}"
}
trap cleanup EXIT

mkdir -p "${SPEC_DIR}"
cat > "${SPEC_DIR}/requirements.md" <<'EOF'
Spec-Review-Status: Passed
EOF
cat > "${SPEC_DIR}/design.md" <<'EOF'
Impl-Review-Status: Passed
EOF
cat > "${SPEC_DIR}/acceptance-tests.md" <<'EOF'
# Acceptance Tests
EOF

sha256() {
  shasum -a 256 "$1" | awk '{print $1}'
}

write_pass_artifacts() {
  local stage="$1"
  local output_dir="$2"
  local requirements_hash acceptance_hash design_hash calibration_hash
  requirements_hash="$(sha256 "${SPEC_DIR}/requirements.md")"
  acceptance_hash="$(sha256 "${SPEC_DIR}/acceptance-tests.md")"
  design_hash="$(sha256 "${SPEC_DIR}/design.md")"
  calibration_hash="$(sha256 "${REPO_ROOT}/plugins/sdd-review-loop/references/reviewer-calibration.md")"
  mkdir -p "${output_dir}"

  if [[ "${stage}" == "spec" ]]; then
    jq -n --arg feature "${FEATURE}" '{schema:"spec-review-integrated-verdict/v1",stage:"spec",feature:$feature,attempt:1,round:1,verdict:"PASS",reviewer_a_run_id:"spec-a-run",reviewer_b_run_id:"spec-b-run",reviewer_a_host_session_id:"spec-a-session",reviewer_b_host_session_id:"spec-b-session",finding_count:0,warning_count:0}' > "${output_dir}/integrated-verdict.json"
  else
    jq -n --arg feature "${FEATURE}" --arg stage "${stage}" '{schema:"integrated-verdict/v1",stage:$stage,feature:$feature,attempt:1,round:1,run_id:($stage + "-contract-run"),verdict:"PASS"}' > "${output_dir}/integrated-verdict.json"
  fi

  jq -n \
    --arg stage "${stage}" \
    --arg feature "${FEATURE}" \
    --arg requirements_hash "${requirements_hash}" \
    --arg acceptance_hash "${acceptance_hash}" \
    --arg design_hash "${design_hash}" \
    --arg calibration_hash "${calibration_hash}" \
    '{schema:($stage + "-review-contract/v1"),stage:$stage,feature:$feature,attempt:1,round:1,run_id:($stage + "-contract-run"),verdict:"PASS",reviewers:[
      {role:($stage + "-reviewer-a"),run_id:($stage + "-a-run"),host_session_id:($stage + "-a-session"),allowed_input_manifest:[
        {path:("specs/" + $feature + "/requirements.md"),sha256:$requirements_hash},
        {path:("specs/" + $feature + "/acceptance-tests.md"),sha256:$acceptance_hash}
      ]},
      {role:($stage + "-reviewer-b"),run_id:($stage + "-b-run"),host_session_id:($stage + "-b-session"),allowed_input_manifest:[
        {path:("specs/" + $feature + "/requirements.md"),sha256:$requirements_hash},
        {path:("specs/" + $feature + "/acceptance-tests.md"),sha256:$acceptance_hash}
      ]}
    ]}
    | if $stage == "impl" then .reviewers |= map(.allowed_input_manifest += [
        {path:("specs/" + $feature + "/design.md"),sha256:$design_hash},
        {path:"plugins/sdd-review-loop/references/reviewer-calibration.md",sha256:$calibration_hash}
      ]) else . end' > "${output_dir}/${stage}-review-contract.json"
}

mkdir -p "${SPEC_REPORT_DIR}/attempt-1/round-1" "${IMPL_REPORT_DIR}/attempt-1/round-1"
write_pass_artifacts spec "${SPEC_REPORT_DIR}/attempt-1/round-1"
write_pass_artifacts impl "${IMPL_REPORT_DIR}/attempt-1/round-1"
cat > "${SPEC_DIR}/tasks.md" <<'EOF'
# Tasks

## T-001 First
Risk: low
Risk Rationale: Fixture coverage for dependency graph parsing.
Required Workflow: test-after
### Blockers
None

## T-002 Second
Risk: low
Risk Rationale: Fixture coverage for dependency graph parsing.
Required Workflow: test-after
### Blockers
T-001
EOF

(
  cd "${REPO_ROOT}"
  bash plugins/sdd-review-loop/scripts/task-review-precheck.sh "${FEATURE}" 1 1 >/dev/null
)

edges="$(jq -c '.edges' "${REPORT_DIR}/attempt-1/round-1/dependency-graph.json")"
if [[ "${edges}" != '[{"from":"T-002","to":"T-001"}]' ]]; then
  echo "expected dependency edge T-002 -> T-001; got ${edges}" >&2
  exit 1
fi

echo "ok: task review precheck records heading-style blocker dependencies"
